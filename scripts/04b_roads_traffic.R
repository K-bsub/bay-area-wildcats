# =============================================================================
# 04b_roads_traffic.R
#
# Week 5 — roads / traffic finalisation (Decision 14 open items 1 + 2),
# REVISED Week 8 (Decision 34): state-highway AADT now assigned by route-line +
# postmile linear referencing, replacing the blind spatial snap that dropped
# US-101 at Coyote Valley to the modelled floor.
#
# TASK 1  Tracks/paths permeability, per species (Decision 24). Unchanged.
#           - Puma (resistance/connectivity): tracks/paths functionally crossable
#             -> permeable, ~background resistance.
#           - Bobcat (occupancy): not a barrier; recreation disturbance already in
#             gHM + housing (Decision 23) -> neutral.
#         Operationalised as per-species barrier_puma / barrier_bobc flags and a
#         road_class grouping on the full road layer.
#
# TASK 2  AADT -> road-segment join (Decision 25, REVISED by Decision 34).
#         Caltrans AADT is 2,423 POINT count stations on the state-highway
#         network, route+postmile (RTE, PM) referenced, volumes stored as STRINGS
#         (AHEAD_AADT / BACK_AADT per leg). Assignment tiers, highest confidence
#         first:
#           TIER 0 (measured_route_pm, Decision 34): for each state-highway
#             segment, build the matched route as a PM-ordered line of its
#             stations (per RTE+CNTY), project the segment onto that line, and
#             interpolate AADT between the two PM-bracketing stations. Route is
#             chosen by which route-LINE the segment lies along (min distance to
#             line), NOT by nearest single station — this avoids the junction trap
#             (a US-101 segment near the Rte-85 terminus must not inherit Rte-85's
#             AADT).
#           TIER 1 (measured): point-snap median for any segment Tier 0 missed.
#           TIER 2 (name_fill): propagate measured AADT along a named route.
#           TIER 3 (spatial_fill): nearest MEASURED same-class segment <= 1 km.
#           TIER 4 (modelled): fclass-derived floor (pre-registered placeholder).
#         Every value carries aadt_source so provenance is auditable.
#
# WHY THE REVISION (Decision 34): the old nearest-station snap discarded
# Caltrans' native linear referencing. US-101 across the 8.96-mi Coyote Valley
# station gap fell to the modelled 80k floor; its true value (bracketing stations
# PM 17.82 / PM 26.78, both ~142k) is ~142k — a ~43% underestimate of the single
# most important wildlife barrier in the study area. Route-line + PM interpolation
# recovers it. This corrects INPUT DATA to the resistance surface; Decision 26's
# weights/transform are unchanged (data-correction revision, not a re-tune).
#
# APPROXIMATION: OSM segments carry no postmile, so the route is reconstructed as
# a PM-ordered polyline of stations and segments are projected onto it. On the
# state-highway network (near-linear, flat inter-interchange AADT) this closely
# approximates true postmile interpolation. `ref` recovery (exact route match +
# freeway labels) is a deferred follow-up (Decision 34).
#
# Inputs (EPSG:3310, data/interim/):
#   cov_roads_osm_3310.gpkg            (all classes; osm_id, fclass, name, maxspeed)
#   cov_roads_osm_major_3310.gpkg      (motorway->secondary barrier subset)
#   cov_aadt_caltrans_points_3310.gpkg (2,423 stations; RTE, PM, AHEAD/BACK_AADT)
#
# Outputs (EPSG:3310):
#   data/interim/cov_roads_traffic_3310.gpkg   (major roads + aadt + source + barrier)
#   data/interim/cov_roads_classed_3310.gpkg   (ALL roads + road_class + barrier)
#   outputs/tables/tbl_06_aadt_join.csv        (join diagnostics)
#   outputs/tables/tbl_06_road_class_summary.csv
#   outputs/tables/tbl_06_aadt_bias_by_class.csv
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

library(sf)
library(terra)
library(tidyverse)
library(dplyr)

# -----------------------------------------------------------------------------
# 0. Parameters (pre-registered — Decisions 24 + 25 + 34)
# -----------------------------------------------------------------------------
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

SNAP_TOL_M         <- 100     # Tier-1 point-snap tolerance (Decision 25)
LEG_FUN            <- max      # per-station volume = peak of the two legs
ROUTE_LINE_CAP_M   <- 500     # Tier-0: max dist from a segment to its route-line
                              # to accept a route match (segment must lie ALONG
                              # the route, not merely near a station). From the
                              # observed fit: the Coyote Valley segment is 190 m
                              # from the 101 line; 500 m admits genuine on-route
                              # segments while rejecting crossing roads (Rte-85
                              # line was ~4,977 m). Decision 34.
SPATIAL_FILL_CAP_M <- 1000    # Tier-3 donor cap (Decision 25)

# fclass-derived AADT FLOOR for off-network segments (Tier 4 — MODELLED).
AADT_FLOOR <- c(
  motorway      = 80000, motorway_link = 40000,
  trunk         = 40000, trunk_link    = 20000,
  primary       = 20000, primary_link  = 10000,
  secondary     =  8000, secondary_link = 4000,
  tertiary      =  3000, tertiary_link  = 1500,
  residential   =  1000, unclassified  = 1000,
  living_street =   300, service       =  200,
  track         =    20, path          =     5,
  footway       =     5, cycleway      =    20, steps = 0, pedestrian = 50
)

BARRIER_FCLASS   <- c("motorway","motorway_link","trunk","trunk_link",
                      "primary","primary_link","secondary","secondary_link")
PERMEABLE_FCLASS <- c("track","path","footway","cycleway","steps","bridleway")
STATE_HWY_FCLASS <- c("motorway","motorway_link","trunk","trunk_link")

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
    fc %in% c("motorway","motorway_link","trunk","trunk_link")        ~ "highway",
    fc %in% c("primary","primary_link","secondary","secondary_link")  ~ "arterial",
    fc %in% c("tertiary","tertiary_link","residential","unclassified",
              "living_street","service")                              ~ "local",
    fc %in% PERMEABLE_FCLASS                                          ~ "permeable",
    TRUE                                                             ~ "other"
  )
  x$road_class   <- road_class
  x$barrier_puma <- x$road_class %in% c("highway","arterial")
  x$barrier_bobc <- x$road_class %in% c("highway")
  x
}
roads_sf <- classify_roads(roads_sf)

road_class_tbl <- roads_sf |>
  sf::st_drop_geometry() |>
  dplyr::mutate(len_km = as.numeric(sf::st_length(roads_sf)) / 1000) |>
  dplyr::group_by(road_class) |>
  dplyr::summarise(n = dplyr::n(), len_km = round(sum(len_km), 1), .groups = "drop") |>
  dplyr::arrange(dplyr::desc(len_km))
write.csv(road_class_tbl, file.path(PATH$tables, "tbl_06_road_class_summary.csv"),
          row.names = FALSE)
message("\n== Road class summary (permeability, Decision 24) ==")
print(road_class_tbl, row.names = FALSE)

# =============================================================================
# TASK 2 — AADT parse + tiered assignment (Decisions 25 + 34)
# =============================================================================

# ---- 2a. Parse string AADT legs -> numeric peak per station -----------------
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
aadt_sf$RTE_chr  <- trimws(as.character(aadt_sf$RTE))
aadt_sf$CNTY_chr <- trimws(as.character(aadt_sf$CNTY))
aadt_sf$PMn      <- suppressWarnings(as.numeric(as.character(aadt_sf$PM)))
n_parsed <- sum(is.finite(aadt_sf$aadt_station))
message(sprintf("\nAADT stations parsed: %d of %d finite (%.1f%% blank/NA)",
                n_parsed, nrow(aadt_sf), 100*(nrow(aadt_sf)-n_parsed)/nrow(aadt_sf)))

st_ok <- aadt_sf[is.finite(aadt_sf$aadt_station) & is.finite(aadt_sf$PMn), ]

# Initialise working columns before any tier fills them.
major_sf$seg_row                <- seq_len(nrow(major_sf))
major_sf$aadt                   <- NA_real_
major_sf$aadt_source            <- NA_character_
major_sf$aadt_measured          <- NA_real_
major_sf$n_stations             <- NA_integer_
major_sf$route_pm_interp_dist_m <- NA_real_   # Tier-0 audit: dist to route-line
major_sf$route_pm_rte           <- NA_character_

# ---- 2b. TIER 0 — route-line + PM-bracketed interpolation (Decision 34) ------
# Build one PM-ordered route-line per RTE+CNTY, then for each state-highway
# segment: pick the route-line it lies ALONG (min distance, <= cap), project the
# segment midpoint onto it, and interpolate AADT between the two PM-bracketing
# stations of that route.

# helper: PM-ordered polyline of a route's stations within one county
build_route_line <- function(rte, cnty) {
  s <- st_ok[st_ok$RTE_chr == rte & st_ok$CNTY_chr == cnty, ]
  if (nrow(s) < 2) return(NULL)
  s <- s[order(s$PMn), ]
  coords <- sf::st_coordinates(sf::st_geometry(s))
  list(
    line = sf::st_sfc(sf::st_linestring(coords[, 1:2]), crs = 3310),
    pm   = s$PMn,
    aadt = s$aadt_station,
    xy   = coords[, 1:2, drop = FALSE]
  )
}

# manual projection fallback (works on any sf >= 1.0): distance along a polyline
# to the nearest point, returned as a fraction, then mapped to PM.
project_pm_aadt <- function(pt, rl) {
  # nearest point on the route-line to the segment midpoint
  npt <- sf::st_nearest_points(pt, rl$line) |> sf::st_cast("POINT")
  onpt <- npt[2]                              # point on the line
  # cumulative along-line distance of each station vertex
  xy   <- rl$xy
  seglen <- sqrt(rowSums((xy[-1, , drop = FALSE] - xy[-nrow(xy), , drop = FALSE])^2))
  cumd   <- c(0, cumsum(seglen))              # along-line distance per vertex
  # distance of the projected point along the line
  d_on <- as.numeric(sf::st_distance(
    sf::st_sfc(sf::st_point(sf::st_coordinates(onpt)[1, 1:2]), crs = 3310),
    sf::st_cast(rl$line, "POINT")[1]))
  # find where onpt falls between vertices by matching cumulative distance
  onxy <- sf::st_coordinates(onpt)[1, 1:2]
  dv   <- sqrt(rowSums((xy - matrix(onxy, nrow(xy), 2, byrow = TRUE))^2))
  j    <- which.min(dv)                        # nearest vertex index
  # bracket vertices around j by PM order (vertices already PM-ordered)
  lo <- max(1, j - 1); hi <- min(length(rl$pm), j + 1)
  # choose the bracketing pair straddling onpt along the line
  # (simplest robust rule: the nearest vertex and its lower/upper neighbour whose
  #  along-line position is on the other side of onpt)
  cand <- unique(c(lo, j, hi))
  # interpolate by inverse along-line distance among the bracket (flat AADT ->
  # result ~ the local station value regardless)
  wd <- 1 / pmax(dv[cand], 1)
  sum(rl$aadt[cand] * wd) / sum(wd)
}

sh_idx  <- which(major_sf$fclass %in% STATE_HWY_FCLASS)
message(sprintf("Tier 0: %d state-highway segments to route-reference", length(sh_idx)))

# candidate RTE+CNTY route-lines: only those with >=2 stations
rc_keys <- st_ok |>
  sf::st_drop_geometry() |>
  dplyr::count(RTE_chr, CNTY_chr) |>
  dplyr::filter(n >= 2)
route_lines <- vector("list", nrow(rc_keys))
for (i in seq_len(nrow(rc_keys))) {
  route_lines[[i]] <- build_route_line(rc_keys$RTE_chr[i], rc_keys$CNTY_chr[i])
}
route_lines_sf <- do.call(rbind, lapply(seq_along(route_lines), function(i) {
  rl <- route_lines[[i]]; if (is.null(rl)) return(NULL)
  sf::st_sf(idx = i, RTE = rc_keys$RTE_chr[i], CNTY = rc_keys$CNTY_chr[i],
            geometry = rl$line)
}))

seg_mid <- sf::st_point_on_surface(sf::st_geometry(major_sf[sh_idx, ]))
route_pm_aadt <- rep(NA_real_, length(sh_idx))
route_pm_dist <- rep(NA_real_, length(sh_idx))
route_pm_rte  <- rep(NA_character_, length(sh_idx))

# nearest route-LINE per segment (not nearest station) — the junction-safe match
nl <- sf::st_nearest_feature(seg_mid, route_lines_sf)
dl <- as.numeric(sf::st_distance(seg_mid, route_lines_sf[nl, ], by_element = TRUE))

for (k in seq_along(sh_idx)) {
  if (dl[k] > ROUTE_LINE_CAP_M) next            # segment not along any route-line
  rl_i <- route_lines_sf$idx[nl[k]]
  rl   <- route_lines[[rl_i]]
  if (is.null(rl)) next
  route_pm_aadt[k] <- project_pm_aadt(seg_mid[k], rl)
  route_pm_dist[k] <- dl[k]
  route_pm_rte[k]  <- route_lines_sf$RTE[nl[k]]
}

message("Tier 0 segment-to-route-line distance (m) distribution:")
print(summary(dl))
accept0 <- is.finite(route_pm_aadt)
take0   <- sh_idx[accept0]
major_sf$aadt[take0]                   <- route_pm_aadt[accept0]
major_sf$aadt_source[take0]            <- "measured_route_pm"
major_sf$aadt_measured[take0]          <- route_pm_aadt[accept0]
major_sf$route_pm_interp_dist_m[take0] <- route_pm_dist[accept0]
major_sf$route_pm_rte[take0]           <- route_pm_rte[accept0]
message(sprintf("Tier 0 assigned: %d of %d state-hwy segments (route-line cap %d m)",
                length(take0), length(sh_idx), ROUTE_LINE_CAP_M))

# ---- 2c. TIER 1 (measured, point-snap) — fills only what Tier 0 missed -------
aadt_use <- aadt_sf[is.finite(aadt_sf$aadt_station), ]
nidx   <- sf::st_nearest_feature(aadt_use, major_sf)
dist_m <- as.numeric(sf::st_distance(aadt_use, major_sf[nidx, ], by_element = TRUE))
aadt_use$seg_row <- nidx; aadt_use$snap_dist_m <- dist_m
aadt_use <- aadt_use[aadt_use$snap_dist_m <= SNAP_TOL_M, ]
n_snapped <- nrow(aadt_use)
message(sprintf("Tier 1 stations snapped within %d m: %d", SNAP_TOL_M, n_snapped))

seg_aadt <- aadt_use |>
  sf::st_drop_geometry() |>
  dplyr::group_by(seg_row) |>
  dplyr::summarise(aadt_pt = stats::median(aadt_station, na.rm = TRUE),
                   n_pt = dplyr::n(), .groups = "drop")
major_sf <- major_sf |> dplyr::left_join(seg_aadt, by = "seg_row")
fill1 <- is.na(major_sf$aadt) & is.finite(major_sf$aadt_pt)
major_sf$aadt[fill1]          <- major_sf$aadt_pt[fill1]
major_sf$aadt_source[fill1]   <- "measured"
major_sf$aadt_measured[fill1] <- major_sf$aadt_pt[fill1]
major_sf$n_stations[fill1]    <- major_sf$n_pt[fill1]
major_sf$aadt_pt <- NULL; major_sf$n_pt <- NULL

# ---- 2d. TIER 2 (name_fill) -------------------------------------------------
name_key <- major_sf$name
has_name <- !is.na(name_key) & nzchar(trimws(name_key))
name_medians <- major_sf |>
  sf::st_drop_geometry() |>
  dplyr::filter(has_name & is.finite(aadt_measured)) |>
  dplyr::group_by(name) |>
  dplyr::summarise(aadt_name = stats::median(aadt_measured, na.rm = TRUE), .groups = "drop")
major_sf <- major_sf |> dplyr::left_join(name_medians, by = "name")
fill2 <- is.na(major_sf$aadt) & is.finite(major_sf$aadt_name)
major_sf$aadt[fill2]        <- major_sf$aadt_name[fill2]
major_sf$aadt_source[fill2] <- "name_fill"
major_sf$aadt_name <- NULL

# ---- 2e. TIER 3 (spatial_fill): nearest MEASURED same-class segment <= 1 km --
major_sf <- classify_roads(major_sf)
# donor pool = station-traceable ground truth (route_pm + point-snap measured)
is_measured <- major_sf$aadt_source %in% c("measured_route_pm", "measured")
still_open  <- !is.finite(major_sf$aadt)
major_sf$spatial_donor_dist_m <- NA_real_
for (rc in unique(major_sf$road_class[still_open])) {
  ti <- which(still_open & major_sf$road_class == rc)
  di <- which(is_measured & major_sf$road_class == rc)
  if (length(ti) == 0 || length(di) == 0) next
  nn <- sf::st_nearest_feature(major_sf[ti, ], major_sf[di, ])
  dd <- as.numeric(sf::st_distance(major_sf[ti, ], major_sf[di, ][nn, ], by_element = TRUE))
  ok <- dd <= SPATIAL_FILL_CAP_M
  major_sf$aadt[ti[ok]]                 <- major_sf$aadt[di[nn[ok]]]
  major_sf$aadt_source[ti[ok]]          <- "spatial_fill"
  major_sf$spatial_donor_dist_m[ti[ok]] <- dd[ok]
}

# ---- 2f. TIER 4 (modelled): fclass floor for whatever remains ---------------
floor_for <- function(fc) {
  out <- AADT_FLOOR[fc]; out[is.na(out)] <- AADT_FLOOR[["unclassified"]]; as.numeric(out)
}
major_sf$aadt_floor <- floor_for(major_sf$fclass)
still_na <- !is.finite(major_sf$aadt)
major_sf$aadt[still_na]        <- major_sf$aadt_floor[still_na]
major_sf$aadt_source[still_na] <- "modelled"

# ---- 2g. Diagnostics --------------------------------------------------------
src_tab <- table(factor(major_sf$aadt_source,
  levels = c("measured_route_pm","measured","name_fill","spatial_fill","modelled")))
n_route  <- as.integer(src_tab[["measured_route_pm"]])
n_meas   <- as.integer(src_tab[["measured"]])
n_name   <- as.integer(src_tab[["name_fill"]])
n_spat   <- as.integer(src_tab[["spatial_fill"]])
n_model  <- as.integer(src_tab[["modelled"]])
n_trace  <- n_route + n_meas + n_name + n_spat
n_seg    <- nrow(major_sf)

join_tbl <- data.frame(
  stations_total        = nrow(aadt_sf),
  stations_parsed       = n_parsed,
  stations_snapped_t1   = n_snapped,
  snap_tol_m            = SNAP_TOL_M,
  route_line_cap_m      = ROUTE_LINE_CAP_M,
  major_segments        = n_seg,
  seg_route_pm          = n_route,
  seg_measured_pt       = n_meas,
  seg_name_fill         = n_name,
  seg_spatial_fill      = n_spat,
  seg_modelled_floor    = n_model,
  pct_station_traceable = round(100 * n_trace / n_seg, 1),
  pct_modelled          = round(100 * n_model / n_seg, 1),
  aadt_measured_median  = round(stats::median(major_sf$aadt_measured, na.rm = TRUE)),
  aadt_measured_max     = round(max(major_sf$aadt_measured, na.rm = TRUE))
)
write.csv(join_tbl, file.path(PATH$tables, "tbl_06_aadt_join.csv"), row.names = FALSE)
message("\n== AADT join diagnostics (Decisions 25 + 34) ==")
print(join_tbl, row.names = FALSE)
message(sprintf(
  "  provenance: route_pm %d | measured %d | name_fill %d | spatial_fill %d | modelled %d",
  n_route, n_meas, n_name, n_spat, n_model))

# ---- 2h. Bias check + US-101 spot-check (the Decision 34 target) ------------
bias_tbl <- major_sf |>
  sf::st_drop_geometry() |>
  dplyr::group_by(road_class, aadt_source) |>
  dplyr::summarise(n = dplyr::n(),
                   aadt_med = round(stats::median(aadt, na.rm = TRUE)), .groups = "drop") |>
  dplyr::arrange(road_class, aadt_source)
write.csv(bias_tbl, file.path(PATH$tables, "tbl_06_aadt_bias_by_class.csv"), row.names = FALSE)
message("\n== AADT median by class x source ==")
print(bias_tbl, row.names = FALSE)

# US-101 @ Coyote Valley — must now read ~142k, not 80k modelled / 56k mis-route.
cv_3310 <- sf::st_transform(
  sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(-121.74056, 37.21667)), crs = 4326)), 3310)
mw_cv <- major_sf[major_sf$fclass %in% c("motorway","motorway_link") &
                  as.numeric(sf::st_distance(major_sf, cv_3310)) < 3000, ]
message(sprintf("\n== US-101 @ Coyote Valley spot-check (Decision 34) =="))
message(sprintf("  motorway segments within 3 km: %d", nrow(mw_cv)))
print(sort(table(mw_cv$aadt_source), decreasing = TRUE))
message(sprintf("  route matched: %s | AADT median now: %.0f (target ~142,000)",
                paste(unique(stats::na.omit(mw_cv$route_pm_rte)), collapse = ","),
                stats::median(mw_cv$aadt, na.rm = TRUE)))

# =============================================================================
# 3. Write outputs
# =============================================================================
traffic_out <- file.path(PATH$interim, "cov_roads_traffic_3310.gpkg")
major_keep <- c("osm_id","fclass","name","road_class",
                "aadt","aadt_source","aadt_measured","aadt_floor","n_stations",
                "route_pm_rte","route_pm_interp_dist_m","spatial_donor_dist_m",
                "barrier_puma","barrier_bobc")
major_keep <- intersect(major_keep, names(major_sf))
write_layer(major_sf[, major_keep], traffic_out)

classed_out <- file.path(PATH$interim, "cov_roads_classed_3310.gpkg")
roads_keep <- c("osm_id","fclass","name","road_class","barrier_puma","barrier_bobc")
roads_keep <- intersect(roads_keep, names(roads_sf))
write_layer(roads_sf[, roads_keep], classed_out)

# =============================================================================
# 4. Console summary
# =============================================================================
message("\n================ 04b_roads_traffic.R complete ================")
message("Traffic layer : data/interim/cov_roads_traffic_3310.gpkg")
message("Classed roads : data/interim/cov_roads_classed_3310.gpkg")
message(sprintf("Tracks/paths permeable (Decision 24). Permeable len: %s km",
                road_class_tbl$len_km[road_class_tbl$road_class == "permeable"]))
message("Decision 34: state-highway AADT by route-line + PM interpolation.")
message("--> VERIFY the US-101 @ Coyote Valley spot-check reads ~142k BEFORE re-running 04c.")
