# =============================================================================
# 06_roads_traffic.R
#
# Week 5 — roads / traffic finalisation (Decision 14 open items 1 + 2).
#
# TASK 1  Tracks/paths permeability, per species (Decision 24).
#         OSM `track` (12,375 km) and `path` (6,452 km) are unpaved, low/no
#         traffic. Neither is a movement barrier for either felid, but the
#         REASONING differs per species (Decision 3 — never pooled):
#           - Puma (resistance/connectivity): functionally crossable; a puma
#             crosses a fire road without hesitation. Treating tracks/paths as
#             barriers would sever corridors that are actually connected. ->
#             permeable, ~background resistance.
#           - Bobcat (occupancy): also not a barrier; any human-recreation
#             disturbance signal they carry is ALREADY captured by gHM + housing
#             (Decision 23), so re-encoding them as barriers would double-count.
#             -> neutral.
#         Operationalised as a per-species `barrier_puma` / `barrier_bobc` flag
#         and a `road_class` grouping on the full road layer.
#
# TASK 2  AADT -> road-segment join (Decision 25).
#         Caltrans AADT is 2,423 POINT count stations, state-highway network
#         only, volumes stored as STRINGS (AHEAD_AADT / BACK_AADT per leg, commas
#         + ~8% blank). No route-number (`ref`) field survived the roads pull, so
#         the join is spatial: snap each station to the nearest MAJOR segment
#         within 100 m; per-station volume = max(AHEAD, BACK) leg; per-segment
#         volume = median of snapped stations. Segments with no station (all
#         off-state-network roads + gaps between stations) get an `fclass`-derived
#         FLOOR, flagged `aadt_source = "modelled"` vs "measured" so every
#         modelled value is auditable. The floor is a pre-registered placeholder
#         (Decision 25), not measured data.
#
# Inputs (EPSG:3310, data/interim/):
#   cov_roads_osm_3310.gpkg            (all classes; osm_id, fclass, name, maxspeed)
#   cov_roads_osm_major_3310.gpkg      (motorway->secondary barrier subset)
#   cov_aadt_caltrans_points_3310.gpkg (2,423 stations; AHEAD_AADT, BACK_AADT str)
#
# Outputs (EPSG:3310):
#   data/interim/cov_roads_traffic_3310.gpkg   (major roads + aadt + source flag + per-species barrier)
#   data/interim/cov_roads_classed_3310.gpkg   (ALL roads + road_class + per-species barrier/permeability)
#   outputs/tables/tbl_06_aadt_join.csv        (join diagnostics: matched, median, source split)
#   outputs/tables/tbl_06_road_class_summary.csv
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

library(sf)
library(terra)
library(tidyverse)
library(dplyr)

# -----------------------------------------------------------------------------
# 0. Parameters (pre-registered — Decisions 24 + 25)
# -----------------------------------------------------------------------------
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

SNAP_TOL_M <- 100          # AADT point -> segment snap tolerance (Decision 25)
LEG_FUN    <- max          # per-station volume from the two legs (max = peak
                           # traffic a crossing animal faces; conservative barrier)

# fclass-derived AADT FLOOR for off-network segments (Decision 25 — MODELLED,
# not measured). First-pass values; sign-off closes Decision 25. Vehicles/day,
# order-of-magnitude by class, well below the state-highway median (~68k).
AADT_FLOOR <- c(
  motorway      = 80000, motorway_link = 40000,
  trunk         = 40000, trunk_link    = 20000,
  primary       = 20000, primary_link  = 10000,
  secondary     =  8000, secondary_link = 4000,
  tertiary      =  3000, tertiary_link  = 1500,
  residential   =  1000, unclassified  = 1000,
  living_street =   300, service       =  200,
  track         =    20, path          =     5,   # permeable classes, token floor
  footway       =     5, cycleway      =    20, steps = 0, pedestrian = 50
)

# Road-class grouping for permeability (Task 1)
BARRIER_FCLASS <- c("motorway","motorway_link","trunk","trunk_link",
                    "primary","primary_link","secondary","secondary_link")
PERMEABLE_FCLASS <- c("track","path","footway","cycleway","steps","bridleway")

# -----------------------------------------------------------------------------
# 1. Load
# -----------------------------------------------------------------------------
f_roads <- file.path(PATH$interim, "cov_roads_osm_3310.gpkg")
f_major <- file.path(PATH$interim, "cov_roads_osm_major_3310.gpkg")
f_aadt  <- file.path(PATH$interim, "cov_aadt_caltrans_points_3310.gpkg")
stopifnot(file.exists(f_roads), file.exists(f_major), file.exists(f_aadt))

roads_sf <- read_layer(f_roads)
major_sf <- read_layer(f_major)
aadt_sf  <- read_layer(f_aadt)

log_stage("roads", "all_loaded",   nrow(roads_sf))
log_stage("roads", "major_loaded", nrow(major_sf))
log_stage("aadt",  "stations",     nrow(aadt_sf))

# =============================================================================
# TASK 1 — permeability classification, per species (Decision 24)
# =============================================================================
classify_roads <- function(x) {
  fc <- x$fclass
  road_class <- dplyr::case_when(
    fc %in% c("motorway","motorway_link","trunk","trunk_link")   ~ "highway",
    fc %in% c("primary","primary_link","secondary","secondary_link") ~ "arterial",
    fc %in% c("tertiary","tertiary_link","residential","unclassified",
              "living_street","service")                          ~ "local",
    fc %in% PERMEABLE_FCLASS                                       ~ "permeable",
    TRUE                                                          ~ "other"
  )
  x$road_class <- road_class
  # Per-species barrier flags. Both species: tracks/paths NOT barriers.
  # Puma barrier = highways + arterials (traffic barrier for a wide-ranging
  # disperser). Bobcat barrier = highways only (finer grain; arterials are
  # semi-permeable and disturbance is carried by gHM/housing).
  x$barrier_puma <- x$road_class %in% c("highway","arterial")
  x$barrier_bobc <- x$road_class %in% c("highway")
  x
}

roads_sf <- classify_roads(roads_sf)

road_class_tbl <- roads_sf |>
  sf::st_drop_geometry() |>
  dplyr::mutate(len_km = as.numeric(sf::st_length(roads_sf)) / 1000) |>
  dplyr::group_by(road_class) |>
  dplyr::summarise(n = dplyr::n(), len_km = round(sum(len_km), 1),
                   .groups = "drop") |>
  dplyr::arrange(dplyr::desc(len_km))
write.csv(road_class_tbl,
          file.path(PATH$tables, "tbl_06_road_class_summary.csv"),
          row.names = FALSE)
message("\n== Road class summary (permeability, Decision 24) ==")
print(road_class_tbl, row.names = FALSE)

# =============================================================================
# TASK 2 — AADT string parse + point-to-segment join (Decision 25)
# =============================================================================

# 2a. Parse the string AADT legs -> numeric, take the peak leg per station.
# Strip commas and any whitespace explicitly (do not rely on \s inside a TRE
# bracket expression, which is unreliable). Blanks -> NA via as.numeric.
parse_aadt <- function(v) {
  v <- gsub(",", "", as.character(v))
  v <- gsub("[[:space:]]", "", v)
  suppressWarnings(as.numeric(v))
}
ah <- if ("AHEAD_AADT" %in% names(aadt_sf)) parse_aadt(aadt_sf$AHEAD_AADT) else rep(NA_real_, nrow(aadt_sf))
bk <- if ("BACK_AADT"  %in% names(aadt_sf)) parse_aadt(aadt_sf$BACK_AADT)  else rep(NA_real_, nrow(aadt_sf))
aadt_sf$aadt_station <- mapply(function(a, b) {
  vals <- c(a, b); vals <- vals[is.finite(vals)]
  if (length(vals) == 0) NA_real_ else LEG_FUN(vals)
}, ah, bk)

n_parsed <- sum(is.finite(aadt_sf$aadt_station))
message(sprintf("\nAADT stations parsed: %d of %d have a finite volume (%.1f%% blank/NA)",
                n_parsed, nrow(aadt_sf),
                100 * (nrow(aadt_sf) - n_parsed) / nrow(aadt_sf)))

# 2b. Snap each station to the nearest MAJOR segment within SNAP_TOL_M.
aadt_use <- aadt_sf[is.finite(aadt_sf$aadt_station), ]
nidx <- sf::st_nearest_feature(aadt_use, major_sf)     # nearest segment index
dist_m <- as.numeric(sf::st_distance(aadt_use, major_sf[nidx, ], by_element = TRUE))
aadt_use$seg_row  <- nidx
aadt_use$snap_dist_m <- dist_m
aadt_use <- aadt_use[aadt_use$snap_dist_m <= SNAP_TOL_M, ]
n_snapped <- nrow(aadt_use)
message(sprintf("AADT stations snapped to a major segment within %d m: %d of %d parsed",
                SNAP_TOL_M, n_snapped, n_parsed))

# 2c. Tier 1 (measured): per-segment AADT = median of stations snapped to it.
major_sf$seg_row <- seq_len(nrow(major_sf))
seg_aadt <- aadt_use |>
  sf::st_drop_geometry() |>
  dplyr::group_by(seg_row) |>
  dplyr::summarise(aadt_measured = stats::median(aadt_station, na.rm = TRUE),
                   n_stations = dplyr::n(), .groups = "drop")

major_sf <- major_sf |>
  dplyr::left_join(seg_aadt, by = "seg_row")

# Working AADT + provenance flag. Start from measured; fill in tiers.
major_sf$aadt        <- major_sf$aadt_measured
major_sf$aadt_source <- ifelse(is.finite(major_sf$aadt), "measured", NA_character_)

# -----------------------------------------------------------------------------
# 2d. Tier 2 (name_fill): propagate measured AADT ALONG a named route.
#     OSM chops one highway into hundreds of short segments; a station only
#     stabs the segment it sits on, leaving the rest of the SAME road (same
#     traffic between interchanges) unmeasured. Assign every unmeasured segment
#     the median measured AADT of all same-`name` segments. Named routes only;
#     blank/NA names skip this tier.
# -----------------------------------------------------------------------------
name_key <- major_sf$name
has_name <- !is.na(name_key) & nzchar(trimws(name_key))
name_medians <- major_sf |>
  sf::st_drop_geometry() |>
  dplyr::filter(has_name & is.finite(aadt_measured)) |>
  dplyr::group_by(name) |>
  dplyr::summarise(aadt_name = stats::median(aadt_measured, na.rm = TRUE),
                   .groups = "drop")

major_sf <- major_sf |>
  dplyr::left_join(name_medians, by = "name")

fill2 <- is.na(major_sf$aadt) & is.finite(major_sf$aadt_name)
major_sf$aadt[fill2]        <- major_sf$aadt_name[fill2]
major_sf$aadt_source[fill2] <- "name_fill"

# -----------------------------------------------------------------------------
# 2e. Tier 3 (spatial_fill): remaining unmeasured segments take AADT from the
#     nearest MEASURED segment of the SAME road_class, within a distance cap.
#
#     Two anti-bias rules (added after v1 skewed spatial_fill HIGH — medians
#     above measured, because the donor pool clustered on busy station-rich
#     roads and because v1 also donated from name_fill, chaining inflation):
#       (1) Donate ONLY from `measured` segments — never from name_fill or a
#           prior spatial_fill. The donor is always ground truth, so values
#           cannot chain upward through inherited medians.
#       (2) Tighter cap (1 km, was 2 km) — a closer donor is a better traffic
#           analogue and reduces cross-road bleed.
#     Donor distances are captured for the diagnostic so the bias can be
#     re-checked, not assumed fixed.
# -----------------------------------------------------------------------------
SPATIAL_FILL_CAP_M <- 1000
major_sf <- classify_roads(major_sf)          # need road_class for the match

is_measured <- major_sf$aadt_source %in% "measured"   # donor pool = measured ONLY
still_open  <- !is.finite(major_sf$aadt)              # after measured + name_fill
major_sf$spatial_donor_dist_m <- NA_real_

for (rc in unique(major_sf$road_class[still_open])) {
  ti <- which(still_open & major_sf$road_class == rc)
  di <- which(is_measured & major_sf$road_class == rc)
  if (length(ti) == 0 || length(di) == 0) next
  nn   <- sf::st_nearest_feature(major_sf[ti, ], major_sf[di, ])
  dd   <- as.numeric(sf::st_distance(major_sf[ti, ],
                                     major_sf[di, ][nn, ], by_element = TRUE))
  ok   <- dd <= SPATIAL_FILL_CAP_M
  take <- ti[ok]
  src  <- di[nn[ok]]
  major_sf$aadt[take]               <- major_sf$aadt[src]   # src is measured -> ground truth
  major_sf$aadt_source[take]        <- "spatial_fill"
  major_sf$spatial_donor_dist_m[take] <- dd[ok]
}

# -----------------------------------------------------------------------------
# 2f. Tier 4 (modelled): whatever is still unresolved gets the fclass floor.
# -----------------------------------------------------------------------------
floor_for <- function(fc) {
  out <- AADT_FLOOR[fc]
  out[is.na(out)] <- AADT_FLOOR[["unclassified"]]
  as.numeric(out)
}
major_sf$aadt_floor <- floor_for(major_sf$fclass)
still_na <- !is.finite(major_sf$aadt)
major_sf$aadt[still_na]        <- major_sf$aadt_floor[still_na]
major_sf$aadt_source[still_na] <- "modelled"

# 2g. Diagnostics — split by provenance tier
src_tab <- table(factor(major_sf$aadt_source,
                 levels = c("measured","name_fill","spatial_fill","modelled")))
n_measured <- as.integer(src_tab[["measured"]])
n_name     <- as.integer(src_tab[["name_fill"]])
n_spatial  <- as.integer(src_tab[["spatial_fill"]])
n_modelled <- as.integer(src_tab[["modelled"]])
n_realdata <- n_measured + n_name + n_spatial   # anything traceable to a station
n_seg      <- nrow(major_sf)

join_tbl <- data.frame(
  stations_total       = nrow(aadt_sf),
  stations_parsed      = n_parsed,
  stations_snapped     = n_snapped,
  snap_tol_m           = SNAP_TOL_M,
  major_segments       = n_seg,
  seg_measured         = n_measured,
  seg_name_fill        = n_name,
  seg_spatial_fill     = n_spatial,
  seg_modelled_floor   = n_modelled,
  pct_station_traceable = round(100 * n_realdata / n_seg, 1),
  pct_modelled         = round(100 * n_modelled / n_seg, 1),
  aadt_measured_median = round(stats::median(major_sf$aadt_measured, na.rm = TRUE)),
  aadt_measured_max    = round(max(major_sf$aadt_measured, na.rm = TRUE))
)
write.csv(join_tbl, file.path(PATH$tables, "tbl_06_aadt_join.csv"),
          row.names = FALSE)
message("\n== AADT join diagnostics (Decision 25) ==")
print(join_tbl, row.names = FALSE)
message(sprintf(
  "  provenance: measured %d | name_fill %d | spatial_fill %d | modelled_floor %d",
  n_measured, n_name, n_spatial, n_modelled))
message(sprintf(
  "  %.1f%% of major segments carry a station-traceable AADT; %.1f%% fall to the fclass floor.",
  100 * n_realdata / n_seg, 100 * n_modelled / n_seg))

# 2h. Bias check — per road_class x source median. spatial_fill medians should
#     now sit NEAR measured, not above it (v1 failure mode). Written to a table
#     so the fix is auditable, not assumed.
bias_tbl <- major_sf |>
  sf::st_drop_geometry() |>
  dplyr::group_by(road_class, aadt_source) |>
  dplyr::summarise(n = dplyr::n(),
                   aadt_med = round(stats::median(aadt, na.rm = TRUE)),
                   .groups = "drop") |>
  dplyr::arrange(road_class, aadt_source)
write.csv(bias_tbl, file.path(PATH$tables, "tbl_06_aadt_bias_by_class.csv"),
          row.names = FALSE)
message("\n== spatial_fill bias check (median AADT by class x source) ==")
print(bias_tbl, row.names = FALSE)

# Donor-distance summary for spatial_fill (closer = better analogue)
sf_dist <- major_sf$spatial_donor_dist_m[major_sf$aadt_source == "spatial_fill"]
if (length(sf_dist) && any(is.finite(sf_dist))) {
  message(sprintf(
    "  spatial_fill donor distance (m): median %.0f | p90 %.0f | max %.0f (cap %d)",
    stats::median(sf_dist, na.rm = TRUE),
    as.numeric(stats::quantile(sf_dist, 0.90, na.rm = TRUE)),
    max(sf_dist, na.rm = TRUE), SPATIAL_FILL_CAP_M))
}

# =============================================================================
# 3. Write outputs
# =============================================================================
traffic_out <- file.path(PATH$interim, "cov_roads_traffic_3310.gpkg")
major_keep <- c("osm_id","fclass","name","road_class",
                "aadt","aadt_source","aadt_measured","aadt_floor","n_stations",
                "spatial_donor_dist_m","barrier_puma","barrier_bobc")
major_keep <- intersect(major_keep, names(major_sf))
write_layer(major_sf[, major_keep], traffic_out)

classed_out <- file.path(PATH$interim, "cov_roads_classed_3310.gpkg")
roads_keep <- c("osm_id","fclass","name","road_class","barrier_puma","barrier_bobc")
roads_keep <- intersect(roads_keep, names(roads_sf))
write_layer(roads_sf[, roads_keep], classed_out)

# =============================================================================
# 4. Console summary
# =============================================================================
message("\n================ 06_roads_traffic.R complete ================")
message("Traffic layer : data/interim/cov_roads_traffic_3310.gpkg (major + aadt + source flag)")
message("Classed roads : data/interim/cov_roads_classed_3310.gpkg (all + per-species barrier)")
message(sprintf("Tracks/paths: NOT barriers for either species (Decision 24). Permeable len: %s km",
                road_class_tbl$len_km[road_class_tbl$road_class == "permeable"]))
message("--> Review the fclass AADT floor values before they feed the puma resistance surface (Decision 25 sign-off).")


tr <- sf::st_read("data/interim/cov_roads_traffic_3310.gpkg", quiet = TRUE)
tr |> st_drop_geometry() |>
  group_by(road_class, aadt_source) |>
  summarise(n = n(), med = median(aadt), .groups = "drop") |>
  arrange(road_class, aadt_source) |> print(n = 30)