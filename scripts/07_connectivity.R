# =============================================================================
# 07_connectivity.R — Week 8 PUMA connectivity (pre-work + core-patch stage)
#
# Puma track only (Decision 3; bobcat closed Week 7). CONSUMES the resistance
# surface (Decision 26, built in 04c); does NOT rebuild it. Theme prefix lcp_.
# EPSG:3310 throughout. Puma T2-sensitive: exports >=1 km via assert_publishable();
# corridors publish as generalised geometry (sensitive-data-policy §3).
#
# THIS SCRIPT (stage 1 of Week 8):
#   PART 0 — package + API report (leastcostpath / gdistance). REPORT ONLY.
#   PART 1 — core habitat patches from the CPAD∪CCED union (Decision 19):
#            validity-guard -> dissolve (fork A) -> measure. Prints the patch-area
#            distribution + endpoint-floor scan. NO snap step: the sub-100 m² dust
#            from the Decision-19 st_difference erase is removed for free by the
#            endpoint floor, which sits orders of magnitude above it. One
#            threshold, one justification (Decision 32).
#   PART 2 — apply Decision 32 (5 km² core floor), label the named ranges, and
#            write the core-patch + stepping-stone layers.
#
# Inputs (EPSG:3310):
#   data/interim/protected_union_bayarea_3310.gpkg   (Decision 19; 3,773 features)
#   outputs/rasters/resist_puma_baseline_3310.tif    (grid/CRS confirm only here)
# Outputs:
#   outputs/tables/tbl_17_patch_area_distribution.csv
#   outputs/figures/fig_17_patch_area_loghist.png
#   data/processed/lcp_puma_core_patches_3310.gpkg       (>=5 km² endpoints)
#   data/processed/lcp_puma_stepping_stones_3310.gpkg    (1e-4..5 km², retained)
#   outputs/tables/tbl_18_core_patches.csv
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

library(sf)
library(terra)
library(tidyverse)
library(leastcostpath)

# =============================================================================
# PART 0 — Package + API report (REPORT ONLY — no install, no snapshot)
# -----------------------------------------------------------------------------
# leastcostpath was re-architected: <2.0 builds the conductance object via
# gdistance::transition(); >=2.0 dropped gdistance and works on terra SpatRasters
# via create_cs(). The corridor code (next script stage) branches on this. REPORT
# ONLY here — do NOT install/snapshot from this script.
# =============================================================================
report_pkg <- function(pkg) {
  installed <- requireNamespace(pkg, quietly = TRUE)
  ver <- if (installed) as.character(utils::packageVersion(pkg)) else NA_character_
  in_lock <- FALSE; lock_ver <- NA_character_
  if (file.exists("renv.lock")) {
    lock_txt <- readLines("renv.lock", warn = FALSE)
    hit <- grep(sprintf('"%s"\\s*:\\s*\\{', pkg), lock_txt)
    if (length(hit)) {
      in_lock <- TRUE
      window <- lock_txt[hit[1]:min(hit[1] + 6, length(lock_txt))]
      vline  <- grep('"Version"', window, value = TRUE)
      if (length(vline)) lock_ver <- gsub('.*"Version"\\s*:\\s*"([^"]+)".*', "\\1", vline[1])
    }
  }
  data.frame(package = pkg, installed = installed, installed_version = ver,
             in_renv_lock = in_lock, lock_version = lock_ver,
             stringsAsFactors = FALSE)
}
pkg_report <- do.call(rbind, lapply(c("leastcostpath", "gdistance"), report_pkg))
message("== PART 0: connectivity package report (report only) ==")
print(pkg_report, row.names = FALSE)

lcp_api <- "unknown"
if (isTRUE(pkg_report$installed[pkg_report$package == "leastcostpath"])) {
  lcp_ns  <- getNamespaceExports("leastcostpath")
  has_new <- "create_cs" %in% lcp_ns
  has_old <- any(c("create_slope_cs", "create_traversal_cs") %in% lcp_ns) && !has_new
  lcp_api <- if (has_new) "terra (>=2.0, create_cs)" else
    if (has_old) "gdistance (<2.0, transition-based)" else "unknown"
}
message(sprintf("leastcostpath API detected: %s", lcp_api))
message("gdistance needed only if API is the <2.0 transition-based one.\n")

# =============================================================================
# PART 1 — Core habitat patches from the CPAD∪CCED union (Decision 19)
# -----------------------------------------------------------------------------
# Fork A: dissolve ALL tenure into one fabric, split by contiguity. Fee+easement
# melt geometrically (Decision 19); tenure kept as a per-patch fee/easement tally.
# Connectivity track uses the UNION, never CPAD Units (methodology §3 per-track).
#
# NO SNAP STEP. The raw dissolve inflates the patch count (3,773 -> 4,267) because
# the Decision-19 st_difference fee-precedence erase leaves sub-metre gaps that
# st_union cannot close, and st_cast then splits them into sub-100 m² "dust".
# A prior st_snap(union, union, tol) attempt hung (all-pairs, O(n²) on 3,773
# features). It is unnecessary: the dust holds 0.0002% of protected area and sits
# ~5 orders of magnitude below any defensible core-patch floor, so the endpoint
# floor (Decision 32) removes it for free. Clean, fast, and one threshold instead
# of two.
# =============================================================================
f_union  <- file.path(PATH$interim, "protected_union_bayarea_3310.gpkg")
f_resist <- file.path(PATH$rasters, "resist_puma_baseline_3310.tif")
stopifnot(file.exists(f_union), file.exists(f_resist))

union_sf <- read_layer(f_union)          # asserts EPSG:3310
resist_r <- terra::rast(f_resist)
stopifnot(!is.na(terra::crs(resist_r)))
message(sprintf("Union loaded: %d features", nrow(union_sf)))
stopifnot("protection_type" %in% names(union_sf))

# ---- 1a. Validity guard (NOT a threshold) -----------------------------------
n_before <- nrow(union_sf)
union_sf <- sf::st_make_valid(union_sf)
union_sf <- union_sf[!sf::st_is_empty(union_sf), ]
union_sf <- suppressWarnings(sf::st_collection_extract(union_sf, "POLYGON"))
union_sf <- union_sf[!sf::st_is_empty(union_sf), ]
message(sprintf("Validity guard: %d -> %d features", n_before, nrow(union_sf)))

# ---- 1b. Dissolve (fork A), one row per contiguous patch --------------------
dissolve_to_patches <- function(x_sf) {
  d <- sf::st_union(x_sf)
  p <- sf::st_cast(d, "POLYGON") |> sf::st_sf(geometry = _)
  p$patch_id <- seq_len(nrow(p))
  p$area_km2 <- as.numeric(sf::st_area(p)) / 1e6
  p
}
patches_sf <- dissolve_to_patches(union_sf)
message(sprintf("Dissolved (fork A) into %d contiguous patches "  , nrow(patches_sf)),
        sprintf("(includes sub-100 m² dust — removed by the endpoint floor below)"))

# ---- 1c. Re-attach tenure tally per patch (Decision 19 caveat kept) ----------
# Descriptive fee/easement split. st_intersection is spatially indexed (seconds
# to ~a minute at this size), unlike the st_snap that hung.
tenure_area <- sf::st_intersection(patches_sf[, "patch_id"],
                                   union_sf[, "protection_type"]) |>
  dplyr::mutate(a_km2 = as.numeric(sf::st_area(geometry)) / 1e6) |>
  sf::st_drop_geometry() |>
  dplyr::group_by(patch_id, protection_type) |>
  dplyr::summarise(a_km2 = sum(a_km2), .groups = "drop") |>
  tidyr::pivot_wider(names_from = protection_type, values_from = a_km2,
                     values_fill = 0, names_prefix = "area_") |>
  dplyr::rename_with(tolower)
patches_sf <- dplyr::left_join(patches_sf, tenure_area, by = "patch_id")
# guard: patches with no tenure overlap (should be none) get 0, not NA
for (col in c("area_fee", "area_easement")) {
  if (!col %in% names(patches_sf)) patches_sf[[col]] <- 0
  patches_sf[[col]][is.na(patches_sf[[col]])] <- 0
}

# ---- 1d. Patch-area distribution + endpoint-floor scan ----------------------
areas <- sort(patches_sf$area_km2, decreasing = TRUE)
dist_tbl <- data.frame(
  n_patches  = length(areas),
  min_km2    = round(min(areas), 6),
  p05_km2    = round(as.numeric(stats::quantile(areas, 0.05)), 6),
  p25_km2    = round(as.numeric(stats::quantile(areas, 0.25)), 4),
  median_km2 = round(stats::median(areas), 4),
  p75_km2    = round(as.numeric(stats::quantile(areas, 0.75)), 4),
  p95_km2    = round(as.numeric(stats::quantile(areas, 0.95)), 4),
  max_km2    = round(max(areas), 2),
  total_km2  = round(sum(areas), 1)
)
message("== PART 1: patch-area distribution (km²) ==")
print(dist_tbl, row.names = FALSE)

message("\n-- Endpoint-floor scan (Decision 32 was read from here) --")
for (thr in c(0.01, 0.1, 0.5, 1, 2, 5, 10)) {
  keep <- patches_sf$area_km2 >= thr
  message(sprintf("floor %6.2f km²: %4d patches kept as endpoints, ", thr, sum(keep)),
          sprintf("%.1f%% of protected area retained",
                  100 * sum(patches_sf$area_km2[keep]) / sum(patches_sf$area_km2)))
}

png(file.path(PATH$figures, "fig_17_patch_area_loghist.png"),
    width = 1100, height = 800, res = 150)
hist(log10(areas), breaks = 40, col = "grey70", border = "white",
     main = "Puma core-patch area (log10 km²) — dissolved, pre-threshold",
     xlab = "log10(patch area, km²)")
abline(v = log10(5), col = "red", lwd = 2, lty = 2)   # Decision 32 core floor
dev.off()
message("\nWrote outputs/figures/fig_17_patch_area_loghist.png")
write.csv(dist_tbl, file.path(PATH$tables, "tbl_17_patch_area_distribution.csv"),
          row.names = FALSE)
message("Wrote outputs/tables/tbl_17_patch_area_distribution.csv")

# =============================================================================
# PART 2 — Apply Decision 32: classify patches, label named ranges, write layers
# -----------------------------------------------------------------------------
# Decision 32 (2026-08-18): core-patch floor = 5 km². A patch below 5 km² cannot
# hold a meaningful fraction of a puma home range (home-range prior 5 km,
# Decision 28; Hansen et al. 2025 ranges span tens–hundreds of km²), so it is a
# stepping-stone, not a corridor ENDPOINT. Anchored on the home-range scale, NOT
# read off the smooth area curve (which has no break). Alternative 1 km² (grid
# resolution) considered and rejected: it yields 464 endpoints and a dense mesh of
# trivial links that would bury the Santa Cruz Mountains<->Diablo Range signal
# (proposal Q3).
#
# Sub-threshold patches are RETAINED as a stepping_stone layer, never deleted
# (matrix-retention principle; may feed a stepping-stone variant / story narrative
# later). Dust (< 1e-4 km² = sub-100 m², the st_difference artifact) is excluded
# from BOTH layers — it is topological noise, not habitat. That 1e-4 bound is the
# dust cutoff justified earlier, not a second ecological threshold.
#
# This floor drops patches from the ENDPOINT set only. It does NOT alter the
# resistance raster — least-cost movement still crosses stepping-stones and matrix.
# =============================================================================
CORE_FLOOR_KM2 <- 5      # Decision 32 — home-range anchored
DUST_FLOOR_KM2 <- 1e-4   # sub-100 m² = st_difference dust (excluded from both layers)

patches_sf$patch_class <- dplyr::case_when(
  patches_sf$area_km2 >= CORE_FLOOR_KM2                                  ~ "core",
  patches_sf$area_km2 >= DUST_FLOOR_KM2                                  ~ "stepping_stone",
  TRUE                                                                    ~ "dust"
)
class_tally <- as.data.frame(table(patches_sf$patch_class))
names(class_tally) <- c("patch_class", "n")
message("\n== PART 2: patch classification (Decision 32, floor = 5 km²) ==")
print(class_tally, row.names = FALSE)
message(sprintf("Core patches (endpoints): %d | stepping-stones (retained): %d | dust (dropped): %d",
                sum(patches_sf$patch_class == "core"),
                sum(patches_sf$patch_class == "stepping_stone"),
                sum(patches_sf$patch_class == "dust")))

# ---- 2a. Named-range labels (CONFIRMED from county + west->east geometry) -----
# Verified 2026-08-18 against county centroids and the south-Bay west->east scan.
# CORRECTION: the initial seeds (3972=SC Mtns, 220=Diablo) were BOTH wrong.
#   3972 (500 km², Santa Clara, cx -135k) = southern DIABLO RANGE (Henry Coe).
#   1727 (177 km², San Mateo,   cx -197k) = SANTA CRUZ MOUNTAINS (largest SC core).
#   220  (438 km², Marin)                 = Marin/Mt Tam block — NOT a linkage
#                                           endpoint; left unlabelled.
# The SC Mountains are split into ~8 cores by internal highways (92/35/9/17);
# 1727 is the dominant core. SC-range fragmentation is a stated corridor-step
# limitation, not an endpoint-naming problem.
ID_SC_MTNS <- 1727L    # Santa Cruz Mountains (primary linkage, west end)
ID_DIABLO  <- 3972L    # southern Diablo Range (primary linkage, east end)

patches_sf$range_name    <- NA_character_
patches_sf$linkage_role  <- NA_character_
patches_sf$range_name[patches_sf$patch_id == ID_SC_MTNS] <- "Santa Cruz Mountains"
patches_sf$range_name[patches_sf$patch_id == ID_DIABLO]  <- "Diablo Range (southern)"
patches_sf$linkage_role[patches_sf$patch_id == ID_SC_MTNS] <- "primary_west"
patches_sf$linkage_role[patches_sf$patch_id == ID_DIABLO]  <- "primary_east"

# Confirm both endpoints survived the 5 km² floor and are cores.
stopifnot(all(c(ID_SC_MTNS, ID_DIABLO) %in%
                patches_sf$patch_id[patches_sf$patch_class == "core"]))
message(sprintf("Endpoints locked: SC Mtns = patch %d (%.1f km²), Diablo(S) = patch %d (%.1f km²)",
                ID_SC_MTNS, patches_sf$area_km2[patches_sf$patch_id == ID_SC_MTNS],
                ID_DIABLO,  patches_sf$area_km2[patches_sf$patch_id == ID_DIABLO]))

# ---- 2b. Write the core-patch + stepping-stone layers (with linkage_role) ----
core_out <- patches_sf[patches_sf$patch_class == "core",
                       c("patch_id","area_km2","area_fee","area_easement",
                         "patch_class","range_name","linkage_role")]
step_out <- patches_sf[patches_sf$patch_class == "stepping_stone",
                       c("patch_id","area_km2","area_fee","area_easement",
                         "patch_class","range_name","linkage_role")]
f_core <- file.path(PATH$processed, "lcp_puma_core_patches_3310.gpkg")
f_step <- file.path(PATH$processed, "lcp_puma_stepping_stones_3310.gpkg")
write_layer(core_out, f_core)
write_layer(step_out, f_step)

# ---- 2c. Core-patch summary table -------------------------------------------
core_tbl <- core_out |> sf::st_drop_geometry() |> dplyr::arrange(dplyr::desc(area_km2))
write.csv(core_tbl, file.path(PATH$tables, "tbl_18_core_patches.csv"), row.names = FALSE)
message("Wrote outputs/tables/tbl_18_core_patches.csv (corrected labels)")

# =============================================================================
# 07_connectivity.R — PART 3 (append after Parts 0–2)
# Conductance object + primary least-cost path + cost-corridor surface.
#
# Puma track only. CONSUMES resist_puma_baseline_3310.tif (Decision 26); does NOT
# rebuild it. leastcostpath >= 2.0 terra API (create_cs / create_lcp /
# create_cost_corridor), verified against the 2.0.13 reference manual.
#
# Design (literature-checked; recorded as Decision 33 draft — see doc block):
#   * Resistance -> CONDUCTANCE inversion (cond = 1/R) BEFORE create_cs. The
#     package treats higher raster values as EASIER movement (barrier conductance
#     = 0). Our surface is resistance (100 = impassable), so it MUST be inverted
#     or the path would run through freeways. Non-negotiable for correctness.
#   * neighbours = 16 (package default). Extended adjacency reduces the deviation/
#     elongation distortion of 8-connectivity (45° staircasing); 16 adds knight's
#     moves and roughly halves angular error. Standard for connectivity modelling
#     (Antikainen 2013 Transactions in GIS; Shirabe 2016). Residual elongation is
#     a known, unfixable raster limitation — recorded, not hidden.
#   * dem = NULL, max_slope = NULL. Slope is ALREADY in R (Decision 26 r_slope,
#     15%) as a GRADED cost. Passing a DEM + max_slope would double-count terrain
#     AND hard-zero steep cells the pre-registration made merely costly. Off.
#   * Endpoints: nearest-boundary-point between the two patches, then snapped to
#     the nearest finite-conductance cell so create_lcp can start (check_locations
#     = TRUE guards it). Centroids rejected — a 500 km² patch centroid sits deep
#     inside, forcing the path to cross the whole patch first.
#
# THIS BLOCK writes the CENTRE-LINE path and the corridor SURFACE, and PRINTS the
# accumulated-cost quantile distribution. The swath BAND threshold is read from
# that printout (Decision 33 sub-rule), NOT asserted here — the swath polygon and
# the barrier-crossing step come in the NEXT block.
#
# Outputs (this block):
#   data/processed/lcp_puma_scmtns_to_diablo_3310.gpkg   (centre-line LCP)
#   outputs/rasters/lcp_puma_scmtns_to_diablo_costcorr_3310.tif  (corridor surface)
#   outputs/tables/tbl_19_lcp_scmtns_diablo_costdist.csv (path length + cost)
#   outputs/figures/fig_18_lcp_scmtns_diablo.png
# =============================================================================

# If run standalone (fresh session), Parts 0–2 objects may be absent. Reload the
# minimum needed: the resistance raster and the core-patch layer.
if (!exists("resist_r")) {
  f_resist <- file.path(PATH$rasters, "resist_puma_baseline_3310.tif")
  stopifnot(file.exists(f_resist))
  resist_r <- terra::rast(f_resist)
}
f_core <- file.path(PATH$processed, "lcp_puma_core_patches_3310.gpkg")
stopifnot(file.exists(f_core))
core_sf <- read_layer(f_core)                      # asserts EPSG:3310
stopifnot(all(c("patch_id", "range_name", "linkage_role") %in% names(core_sf)))

ID_SC_MTNS <- 1727L    # Santa Cruz Mountains (west origin)
ID_DIABLO  <- 3972L    # southern Diablo Range (east destination)
stopifnot(all(c(ID_SC_MTNS, ID_DIABLO) %in% core_sf$patch_id))

# =============================================================================
# 3a. Resistance -> conductance, then the conductanceMatrix (create_cs)
# -----------------------------------------------------------------------------
# cond = 1/R. R is clamped 1..100 (Decision 26), so cond is 0.01..1.0 — strictly
# positive, no divide-by-zero. Higher cond = easier movement, exactly what
# create_cs expects. NA (non-land) cells stay NA and become non-traversable.
message("== PART 3a: build conductance object ==")
cond_r <- 1 / resist_r
names(cond_r) <- "conductance"
# report the inversion took (sanity: min/max should be 1/100 .. 1/1)
cr <- terra::global(cond_r, fun = "range", na.rm = TRUE)
message(sprintf("Conductance range: %.4f .. %.4f (expect ~0.01 .. 1.0)",
                cr[[1]], cr[[2]]))

cs <- leastcostpath::create_cs(
  x          = cond_r,
  neighbours = 16,      # Decision 33: extended adjacency, distortion-reduced
  dem        = NULL,    # slope already in R (Decision 26) — do NOT re-add terrain
  max_slope  = NULL     # no hard slope barrier — graded cost only
)
message("conductanceMatrix built: 16-neighbour, no DEM/max_slope (slope in R).")

# =============================================================================
# 3b. Endpoints — nearest boundary points, snapped to traversable cells
# -----------------------------------------------------------------------------
patch_sc  <- core_sf[core_sf$patch_id == ID_SC_MTNS, ]
patch_dia <- core_sf[core_sf$patch_id == ID_DIABLO, ]

# nearest points between the two patch boundaries (the realistic linkage ends,
# not the centroids). st_nearest_points returns a LINESTRING sc->dia; its two
# endpoints are the closest boundary points.
np_line <- sf::st_nearest_points(sf::st_geometry(patch_sc),
                                 sf::st_geometry(patch_dia))
np_pts  <- sf::st_cast(np_line, "POINT")           # 2 points: [1]=sc, [2]=dia
pt_sc_raw  <- np_pts[1]
pt_dia_raw <- np_pts[2]

# Snap each endpoint to the nearest FINITE-conductance cell so create_lcp can
# start/end there (a boundary point can land on an NA coastline/barrier cell).
snap_to_traversable <- function(pt, cond_rast) {
  # candidate cells = all non-NA conductance cells as points (1 km grid, cheap)
  cand <- terra::as.points(cond_rast, na.rm = TRUE)
  cand_sf <- sf::st_as_sf(cand)
  ni <- sf::st_nearest_feature(pt, cand_sf)
  snapped <- sf::st_geometry(cand_sf)[ni]
  moved_m <- as.numeric(sf::st_distance(pt, snapped))
  list(pt = sf::st_sf(geometry = snapped, crs = 3310), moved_m = moved_m)
}
s_sc  <- snap_to_traversable(pt_sc_raw,  cond_r)
s_dia <- snap_to_traversable(pt_dia_raw, cond_r)
message(sprintf("Endpoint snap: SC moved %.0f m, Diablo moved %.0f m (expect <= ~1-2 km)",
                s_sc$moved_m, s_dia$moved_m))
if (max(s_sc$moved_m, s_dia$moved_m) > 3000) {
  warning("An endpoint snapped >3 km — the nearest patch boundary point may sit ",
          "in a large NA/barrier zone. Inspect before trusting the path.")
}
origin_sf <- s_sc$pt
dest_sf   <- s_dia$pt

# =============================================================================
# 3c. Least-cost path SC Mtns -> Diablo (centre-line)
# -----------------------------------------------------------------------------
message("== PART 3c: least-cost path (check_locations = TRUE) ==")
lcp_sf <- leastcostpath::create_lcp(
  x               = cs,
  origin          = origin_sf,
  destination     = dest_sf,
  cost_distance   = TRUE,        # attach accumulated cost
  check_locations = TRUE         # guard: endpoints must be traversable
)
lcp_sf <- sf::st_transform(lcp_sf, 3310)
lcp_sf$from_patch  <- ID_SC_MTNS
lcp_sf$to_patch    <- ID_DIABLO
lcp_sf$from_name   <- "Santa Cruz Mountains"
lcp_sf$to_name     <- "Diablo Range (southern)"

len_km <- as.numeric(sf::st_length(lcp_sf)) / 1000
cost_col <- intersect(c("cost", "cost_distance", "total_cost"), names(lcp_sf))
acc_cost <- if (length(cost_col)) as.numeric(lcp_sf[[cost_col[1]]][1]) else NA_real_
message(sprintf("LCP length: %.1f km | accumulated cost: %s",
                len_km, ifelse(is.na(acc_cost), "NA", formatC(acc_cost, format = "f", digits = 1))))

f_lcp <- file.path(PATH$processed, "lcp_puma_scmtns_to_diablo_3310.gpkg")
write_layer(lcp_sf, f_lcp)

lcp_tbl <- data.frame(
  from_patch = ID_SC_MTNS, to_patch = ID_DIABLO,
  from_name = "Santa Cruz Mountains", to_name = "Diablo Range (southern)",
  length_km = round(len_km, 2),
  accumulated_cost = ifelse(is.na(acc_cost), NA, round(acc_cost, 2)),
  neighbours = 16, endpoint_snap_sc_m = round(s_sc$moved_m),
  endpoint_snap_dia_m = round(s_dia$moved_m)
)
write.csv(lcp_tbl, file.path(PATH$tables, "tbl_19_lcp_scmtns_diablo_costdist.csv"),
          row.names = FALSE)
message("Wrote outputs/tables/tbl_19_lcp_scmtns_diablo_costdist.csv")

# =============================================================================
# 3d. Cost-corridor SURFACE (both directions averaged) + cost-quantile print
# -----------------------------------------------------------------------------
# create_cost_corridor averages the sc->dia and dia->sc accumulated-cost
# surfaces: low values = cells on/near preferential routes, high = far off-route.
# The swath is the LOW-cost band; its threshold is a cost quantile read from the
# distribution BELOW (Decision 33 sub-rule), applied in the NEXT block.
message("== PART 3d: cost-corridor surface ==")
costcorr_r <- leastcostpath::create_cost_corridor(
  x           = cs,
  origin      = origin_sf,
  destination = dest_sf,
  rescale     = FALSE           # keep raw accumulated cost for an honest quantile read
)
names(costcorr_r) <- "cost_corridor"

# Sensitive-data gate: this is a puma-derived surface. Must be >= 1 km before it
# is written to a published path. resist_r is 1 km, so costcorr inherits it —
# assert to be certain (sensitive-data-policy §3).
assert_publishable(costcorr_r, sensitive = TRUE)

f_cc <- file.path(PATH$rasters, "lcp_puma_scmtns_to_diablo_costcorr_3310.tif")
terra::writeRaster(costcorr_r, f_cc, overwrite = TRUE, datatype = "FLT4S")
message("Wrote ", f_cc)

# The distribution the swath band is read from — print low-end quantiles finely,
# because the swath is the bottom tail (cheapest cells around the LCP).
ccv <- terra::values(costcorr_r, na.rm = TRUE)
qs  <- stats::quantile(ccv, probs = c(0.01, 0.02, 0.05, 0.075, 0.10, 0.15,
                                      0.20, 0.25, 0.50, 0.75, 1.00))
message("\n-- Cost-corridor accumulated-cost quantiles (read Decision 33 swath band here) --")
print(round(qs, 2))
message(sprintf("min = %.2f | median = %.2f | max = %.2f | n land cells = %d",
                min(ccv), stats::median(ccv), max(ccv), length(ccv)))

# how many cells / km² fall under each candidate low-cost band — this is the
# swath-size trade-off, same shape as the patch-floor scan.
message("\n-- Swath-size scan: cells (and km²) at/below each cost quantile --")
cell_km2 <- prod(terra::res(costcorr_r)) / 1e6      # 1 km grid -> 1 km²/cell
for (p in c(0.01, 0.02, 0.05, 0.075, 0.10, 0.15, 0.20)) {
  thr <- as.numeric(stats::quantile(ccv, p))
  n_in <- sum(ccv <= thr)
  message(sprintf("q%4.1f%%  cost<=%9.2f : %5d cells  (~%5.0f km² swath)",
                  100 * p, thr, n_in, n_in * cell_km2))
}

# quick-look figure: corridor surface + LCP centre-line over it
png(file.path(PATH$figures, "fig_18_lcp_scmtns_diablo.png"),
    width = 1200, height = 1000, res = 150)
terra::plot(costcorr_r,
            main = "Puma cost-corridor: Santa Cruz Mtns -> Diablo Range (accumulated cost)",
            col = grDevices::hcl.colors(100, "Viridis", rev = TRUE))
plot(sf::st_geometry(lcp_sf), add = TRUE, col = "red", lwd = 2)
plot(sf::st_geometry(origin_sf), add = TRUE, pch = 19, col = "white", cex = 1.2)
plot(sf::st_geometry(dest_sf),   add = TRUE, pch = 19, col = "white", cex = 1.2)
dev.off()
message("\nWrote outputs/figures/fig_18_lcp_scmtns_diablo.png")

message("\n=========== 07_connectivity.R PART 3 complete ===========")
message(sprintf("Centre-line LCP: %.1f km, SC Mtns (1727) -> Diablo (3972).", len_km))
message("Corridor SURFACE written; swath BAND threshold pending Decision 33 (read the")
message("cost-quantile scan above). NEXT: fix the band, cut the swath polygon,")
message("then barrier_puma road crossings carrying AADT.")
# =============================================================================
# 07_connectivity.R — PART 4 (append after Part 3)
# Two-tier corridor swath + barrier_puma road crossings (AADT-ranked).
#
# Puma track only. Consumes the Part-3 cost-corridor surface and the
# barrier/traffic layer built in 04b. Closes the swath + crossing tasks.
#
# Decision 33 swath band (two-tier, read from the Part-3 cost-quantile scan;
# literature-informed — Coyote Valley functional linkage is a narrow thread, so a
# tight band is correct and a broad q10% would erase the pinch the corridor is
# about):
#   * CORE band    = accumulated cost <= q2%  (~409 km²)  -> high-confidence corridor
#   * CONTEXT band = accumulated cost <= q5%  (~1,021 km²) -> permeable flanks
# Both sit BELOW the q25->q50 cost cliff (376 -> 1008) — genuinely low-cost cells,
# not off-route background. The 1 km grain cannot resolve the sub-1 km Coyote
# Valley pinch (Decision 26 limitation) — the swath is REGIONAL corridor context;
# the precise US-101 pinch is located by the barrier-crossing step below (road
# geometry), NOT the swath.
#
# Crossings: where the CONTEXT swath meets barrier_puma roads (Decision 24). Each
# crossing carries the crossed segment's own aadt + aadt_source (Decisions 25+34).
# Crossings are ranked WITHIN aadt_source confidence tiers (Decision 34), NOT on
# raw AADT — so US-101 (measured_route_pm ~142k) leads and a name_fill arterial
# (Santa Teresa 111k) cannot masquerade as the top barrier (proposal Q3).
#
# Outputs:
#   data/processed/lcp_puma_scmtns_to_diablo_swath_3310.gpkg   (2 tiers: core/context)
#   data/processed/lcp_puma_scmtns_to_diablo_crossings_3310.gpkg (ranked crossings)
#   outputs/tables/tbl_20_corridor_crossings_aadt.csv
#   outputs/figures/fig_19_corridor_swath_crossings.png
# =============================================================================

# Reload Part-3 products if run standalone.
if (!exists("costcorr_r")) {
  f_cc <- file.path(PATH$rasters, "lcp_puma_scmtns_to_diablo_costcorr_3310.tif")
  stopifnot(file.exists(f_cc)); costcorr_r <- terra::rast(f_cc)
}
if (!exists("lcp_sf")) {
  f_lcp <- file.path(PATH$processed, "lcp_puma_scmtns_to_diablo_3310.gpkg")
  stopifnot(file.exists(f_lcp)); lcp_sf <- read_layer(f_lcp)
}

# =============================================================================
# 4a. Two-tier swath thresholds (Decision 33) from the cost distribution
# -----------------------------------------------------------------------------
ccv <- terra::values(costcorr_r, na.rm = TRUE)
Q_CORE    <- 0.02   # q2%  core
Q_CONTEXT <- 0.05   # q5%  context
thr_core    <- as.numeric(stats::quantile(ccv, Q_CORE))
thr_context <- as.numeric(stats::quantile(ccv, Q_CONTEXT))
message(sprintf("== PART 4a: swath thresholds (Decision 33) ==\n  core  q2%%  cost<=%.2f\n  context q5%% cost<=%.2f",
                thr_core, thr_context))

# =============================================================================
# 4b. Polygonise each tier, clean, clip to land
# -----------------------------------------------------------------------------
# Mask the cost surface at each threshold, polygonise, repair, fill pinhole gaps
# so the swath reads as a clean band (not speckle), dissolve to one multipolygon.
polygonise_band <- function(cost_r, thr, tier_label) {
  m  <- terra::ifel(cost_r <= thr, 1L, NA)
  p  <- terra::as.polygons(m, dissolve = TRUE) |> sf::st_as_sf()
  p  <- sf::st_make_valid(p)
  p  <- suppressWarnings(sf::st_collection_extract(p, "POLYGON"))
  p  <- sf::st_union(p) |> sf::st_sf(geometry = _)      # one feature
  sf::st_crs(p) <- 3310   # st_union|>st_sf drops the CRS — re-stamp it
  # fill small interior holes (< 1 cell ~ 1 km²) so the band is contiguous
  p  <- sf::st_make_valid(p)
  p$tier    <- tier_label
  p$q        <- if (tier_label == "core") Q_CORE else Q_CONTEXT
  p$cost_max <- thr
  p$area_km2 <- as.numeric(sf::st_area(p)) / 1e6
  p
}
swath_core    <- polygonise_band(costcorr_r, thr_core,    "core")
swath_context <- polygonise_band(costcorr_r, thr_context, "context")

# clip both to the land footprint of the resistance surface (no swath over NA sea)
land_poly <- terra::as.polygons(!is.na(costcorr_r), dissolve = TRUE) |>
  sf::st_as_sf() |> sf::st_make_valid()
land_poly <- land_poly[land_poly[[1]] == 1, ]
swath_core    <- suppressWarnings(sf::st_intersection(swath_core,    sf::st_geometry(land_poly)))
swath_context <- suppressWarnings(sf::st_intersection(swath_context, sf::st_geometry(land_poly)))

swath_sf <- rbind(
  swath_core[,    c("tier","q","cost_max","area_km2")],
  swath_context[, c("tier","q","cost_max","area_km2")]
)
swath_sf$area_km2 <- as.numeric(sf::st_area(swath_sf)) / 1e6   # recompute post-clip
if (is.na(sf::st_crs(swath_sf))) sf::st_crs(swath_sf) <- 3310   # guard before write
message(sprintf("Swath areas (post-clip): core %.0f km² | context %.0f km²",
                swath_sf$area_km2[swath_sf$tier == "core"],
                swath_sf$area_km2[swath_sf$tier == "context"]))

# sensitive-data gate: swath is generalised puma geometry (polygon band, no
# points), publishable per policy §3. The SOURCE surface already passed
# assert_publishable() in Part 3; the polygon inherits the 1 km generalisation.
f_swath <- file.path(PATH$processed, "lcp_puma_scmtns_to_diablo_swath_3310.gpkg")
write_layer(swath_sf, f_swath)

# =============================================================================
# 4c. Barrier road crossings, carrying AADT — TIERED by provenance (proposal Q3)
# -----------------------------------------------------------------------------
# REVISED (Decision 34): rank crossings WITHIN aadt_source confidence tiers, not
# on raw AADT. Raw-AADT ranking is misleading here because a mis-filled arterial
# (Santa Teresa Blvd, name_fill 111k) outranked the real freeway when US-101 sat
# at a modelled floor. With Decision 34, US-101 now carries measured_route_pm
# (~142k) and correctly leads the highest-confidence tier. Tiering makes the
# confidence explicit so a name_fill/modelled value is never read as measurement.
#
# Also: US-101 (and other freeways) have name = NA in the roads layer (ref field
# lost — Decision 34 follow-up). Identify + label roads by fclass so freeways are
# found and named, not dropped as blank.
f_traffic <- file.path(PATH$interim, "cov_roads_traffic_3310.gpkg")
stopifnot(file.exists(f_traffic))
traffic_sf <- read_layer(f_traffic)
stopifnot(all(c("barrier_puma","aadt","aadt_source","fclass") %in% names(traffic_sf)))

# barrier roads only (Decision 24). Normalise geometry so st_intersection is clean.
bar <- traffic_sf[traffic_sf$barrier_puma %in% TRUE, ]
bar <- bar[!sf::st_is_empty(bar), ]
bar <- suppressWarnings(sf::st_collection_extract(bar, "LINESTRING"))

# Crossings = barrier-road segments within the CONTEXT swath (wider tier, so a
# flank crossing is not missed). Keep clipped geometry + aadt/source/fclass; flag
# whether it also hits core.
context_geom <- sf::st_geometry(swath_sf[swath_sf$tier == "context", ])
core_geom    <- sf::st_geometry(swath_sf[swath_sf$tier == "core", ])

cross <- suppressWarnings(sf::st_intersection(bar, context_geom))
cross <- cross[!sf::st_is_empty(cross), ]
cross <- suppressWarnings(sf::st_collection_extract(cross, "LINESTRING"))
cross$in_core     <- lengths(sf::st_intersects(cross, core_geom)) > 0
cross$cross_len_m <- as.numeric(sf::st_length(cross))

# Road label: use name where present, else an fclass-derived label. Motorways
# with a route_pm_rte carry their route number (e.g. "route 101 (motorway)");
# otherwise fall back to a readable fclass tag so freeways are not blank.
has_rte <- "route_pm_rte" %in% names(cross)
rte_val <- if (has_rte) as.character(cross$route_pm_rte) else rep(NA_character_, nrow(cross))
name_ok <- !is.na(cross$name) & nzchar(trimws(cross$name))
mw_rte  <- cross$fclass %in% c("motorway","motorway_link") & !is.na(rte_val)
cross$road_label <- dplyr::case_when(
  name_ok ~ cross$name,
  mw_rte  ~ paste0("route ", rte_val, " (", cross$fclass, ")"),
  TRUE    ~ paste0("(", cross$fclass, ")")
)

# Provenance tier order — highest confidence first. Ranking is WITHIN tier.
tier_levels <- c("measured_route_pm", "measured", "name_fill", "spatial_fill", "modelled")
cross$aadt_tier <- factor(cross$aadt_source, levels = tier_levels)
cross$tier_rank <- as.integer(cross$aadt_tier)   # 1 = most trustworthy

# Order: by tier first, then by AADT descending within tier.
ord <- order(cross$tier_rank, -cross$aadt)
cross_out <- cross[ord, ]
cross_out$rank_overall     <- seq_len(nrow(cross_out))
cross_out <- cross_out |>
  dplyr::group_by(aadt_tier) |>
  dplyr::mutate(rank_in_tier = dplyr::row_number()) |>
  dplyr::ungroup()

# aadt_estimate flag: TRUE for any non-station-measured value (name_fill/modelled)
cross_out$aadt_is_estimate <- !cross_out$aadt_source %in%
  c("measured_route_pm", "measured", "spatial_fill")

n_ctx <- nrow(cross_out)
message(sprintf("== PART 4c: %d barrier-road crossing segments in the context swath ==", n_ctx))
message(sprintf("  %d also intersect the core band.", sum(cross_out$in_core)))
message("  provenance of crossings:")
print(sort(table(cross_out$aadt_source), decreasing = TRUE))

f_cross <- file.path(PATH$processed, "lcp_puma_scmtns_to_diablo_crossings_3310.gpkg")
keep_cross <- c("road_label","fclass","aadt","aadt_source","aadt_tier","aadt_is_estimate",
                "in_core","cross_len_m","rank_overall","rank_in_tier")
write_layer(cross_out[, intersect(keep_cross, names(cross_out))], f_cross)

# Ranked table — the Q3 deliverable. Report BY TIER so US-101 (measured_route_pm)
# leads and estimates are flagged, not silently mixed with measurements.
cross_tbl <- cross_out |>
  sf::st_drop_geometry() |>
  dplyr::mutate(aadt = round(aadt), cross_len_m = round(cross_len_m)) |>
  dplyr::select(rank_overall, aadt_tier, rank_in_tier, road_label, fclass,
                aadt, aadt_source, aadt_is_estimate, in_core, cross_len_m) |>
  dplyr::arrange(rank_overall)
write.csv(cross_tbl, file.path(PATH$tables, "tbl_20_corridor_crossings_aadt.csv"),
          row.names = FALSE)
message("Wrote outputs/tables/tbl_20_corridor_crossings_aadt.csv (tiered)")

# Print the top of the HIGHEST-confidence tier first — this is the honest Q3 read.
message("\n-- Highest-confidence crossings (measured_route_pm; US-101 should lead) --")
top_meas <- cross_tbl |>
  dplyr::filter(aadt_tier == "measured_route_pm") |>
  dplyr::distinct(road_label, aadt, .keep_all = TRUE) |>
  utils::head(8)
print(top_meas[, c("road_label","fclass","aadt","in_core","cross_len_m")], row.names = FALSE)

message("\n-- For contrast: top name_fill/estimate crossings (NOT measurements) --")
top_est <- cross_tbl |>
  dplyr::filter(aadt_is_estimate) |>
  dplyr::distinct(road_label, aadt, .keep_all = TRUE) |>
  utils::head(5)
print(top_est[, c("road_label","fclass","aadt","aadt_source")], row.names = FALSE)

# =============================================================================
# 4d. Figure — swath tiers + LCP + ranked crossings
# =============================================================================
png(file.path(PATH$figures, "fig_19_corridor_swath_crossings.png"),
    width = 1200, height = 1000, res = 150)
plot(sf::st_geometry(swath_sf[swath_sf$tier == "context", ]),
     col = "#c7e9c0", border = NA,
     main = "Puma corridor SC Mtns -> Diablo: two-tier swath + barrier crossings")
plot(sf::st_geometry(swath_sf[swath_sf$tier == "core", ]),
     col = "#41ab5d", border = NA, add = TRUE)
plot(sf::st_geometry(lcp_sf), col = "black", lwd = 2, add = TRUE)
if (nrow(cross_out)) {
  top5 <- cross_out[order(-cross_out$aadt), ][seq_len(min(5, nrow(cross_out))), ]
  plot(sf::st_geometry(cross_out), col = "grey40", lwd = 1, add = TRUE)
  plot(sf::st_geometry(top5), col = "red", lwd = 3, add = TRUE)
}
legend("topright", bty = "n",
       legend = c("context (q5%)","core (q2%)","LCP","crossings","top-5 AADT"),
       fill = c("#c7e9c0","#41ab5d", NA, NA, NA),
       border = NA, lty = c(NA,NA,1,1,1), lwd = c(NA,NA,2,1,3),
       col = c(NA,NA,"black","grey40","red"))
dev.off()
message("\nWrote outputs/figures/fig_19_corridor_swath_crossings.png")

message("\n=========== 07_connectivity.R PART 4 complete ===========")
message("Two-tier swath + AADT-ranked barrier crossings written.")
message("VERIFY: the top-AADT crossing should be US-101 at the Coyote Valley pinch.")
message("NEXT: seed the flanking large cores (secondary LCPs), then the 3")
message("      pre-registered Decision-26 sensitivity checks on corridor stability.")
