# 05_kde_and_hotspots.R
# Week 6 — descriptive spatial analysis.
#
# PART 1 (this block): Kernel density estimation (KDE), per species, on its own
#   grid. Puma 1 km, bobcat 500 m. spatstat.explore::density.ppp() with edge
#   correction. Bandwidth by a PRE-REGISTERED RULE (Decision 28), not hand-tuned.
#   Obscured-coordinate handling per Decision 29.
#
# PART 2 (appended in the next task): Getis-Ord Gi* hot spots + Q5 effort
#   cross-read. Not in this block.
#
# Decisions closed here:
#   28 — KDE bandwidth: compute three candidates, print, choose by a fixed rule
#        (not a post-hoc look). Home-range prior is the fallback when the data-
#        driven selectors fail the sub-cell / effort-collapse test.
#   29 — Obscured-coordinate handling. Published puma + bobcat KDE are
#        PRECISE-ONLY (obscured = FALSE). A separate, caveated obscured-puma
#        density companion is written for the Q5 effort/uncertainty read only —
#        it is NOT a distribution surface and NOT the published puma KDE.
#
# Conventions: EPSG:3310; continuous rasters bilinear, categorical near;
#   filenames end in the EPSG code; helpers from R/00_functions_*.R.
# ==============================================================================

# Prerequisites ----------------------------------------------------------------
library(sf)
library(terra)
library(dplyr)
library(spatstat.geom)     # owin, ppp, as.im
library(spatstat.explore)  # density.ppp, bw.diggle, bw.ppl

source("R/00_config.R")             # PATH, CRS_ANALYSIS, SPECIES, MIN_PUBLISH_RES_SENSITIVE_M
source("R/00_functions_io.R")       # read_layer, log_stage
source("R/00_functions_spatial.R")  # assert_publishable

# NOTE ON PACKAGES -------------------------------------------------------------
# spatstat.explore, spatstat.geom and sfdep are already declared in
# scripts/00_setup_environment.R and should already be in renv.lock. This script
# does NOT install anything. If renv reports them missing, resolve that in the
# environment step (renv::install() + renv::snapshot()), never inline here.

# ==============================================================================
# 0. Inputs
# ==============================================================================

boundary_path <- file.path(PATH$interim, "boundary_baydissolved_3310.gpkg")
occ_puma_path <- file.path(PATH$interim, "occ_puma_clean_3310.gpkg")
occ_bobc_path <- file.path(PATH$interim, "occ_bobc_clean_3310.gpkg")
grid_puma_path <- file.path(PATH$interim, "grid_puma_1km_3310.tif")
grid_bobc_path <- file.path(PATH$interim, "grid_bobc_500m_3310.tif")

boundary_sf <- read_layer(boundary_path)          # CRS asserted == 3310
occ_puma_sf <- read_layer(occ_puma_path)
occ_bobc_sf <- read_layer(occ_bobc_path)

grid_puma_r <- terra::rast(grid_puma_path)        # template: extent, res, NA land mask
grid_bobc_r <- terra::rast(grid_bobc_path)

stopifnot(
  terra::crs(grid_puma_r, describe = TRUE)$code == as.character(CRS_ANALYSIS),
  terra::crs(grid_bobc_r, describe = TRUE)$code == as.character(CRS_ANALYSIS)
)

# ==============================================================================
# 1. Observation window (owin) — the dissolved study-area boundary
# ==============================================================================
# density.ppp() needs a window. The study-area polygon is the correct window:
# edge correction only makes sense against the real boundary, not a bbox. A
# polygonal owin lets diggle=TRUE correct for cats that "leave" the study frame.

win_owin <- boundary_sf |>
  sf::st_union() |>
  sf::st_geometry() |>
  as.owin()   # spatstat.geom method for sfc

# ==============================================================================
# 2. Helper: sf points -> ppp inside the window
# ==============================================================================
# Points exactly on the boundary or (rarely) just outside after reprojection are
# dropped by ppp() with a warning; we report how many so it is never silent.

sf_to_ppp <- function(pts_sf, window) {
  xy <- sf::st_coordinates(pts_sf)
  p  <- spatstat.geom::ppp(
    x = xy[, 1], y = xy[, 2],
    window = window,
    checkdup = FALSE   # duplicated coords are legitimate repeat sightings
  )
  n_rejected <- sum(!spatstat.geom::inside.owin(xy[, 1], xy[, 2], window))
  if (n_rejected > 0) {
    message("  ", n_rejected, " point(s) outside window, dropped from ppp")
  }
  p
}

# ==============================================================================
# 3. Bandwidth selection — Decision 28 (PRE-REGISTERED RULE)
# ==============================================================================
# We compute THREE candidates and print them. The CHOICE is made by a fixed rule
# stated before looking at the numbers, so the final bandwidth is not a post-hoc
# pick:
#
#   Candidates:
#     A. bw.diggle(ppp)  — Diggle MSE selector (intensity estimation)
#     B. bw.ppl(ppp)     — likelihood cross-validation
#     C. sigma_home      — home-range prior (author prior; the fallback):
#                          puma  5000 m, bobcat 1500 m.
#
#   RULE (applied in order, decided in advance):
#     1. A candidate is REJECTED if sigma < output cell size (sub-cell smoothing
#        is meaningless at the publish grain and, for puma, would sit below the
#        1 km policy floor).
#     2. A candidate is REJECTED if sigma < sigma_home / 3, i.e. it has collapsed
#        toward the observer-cluster scale rather than the movement scale. On
#        effort-clustered opportunistic data bw.diggle in particular does this;
#        such a KDE maps where observers go, not where cats are (proposal Q5).
#     3. Among the SURVIVORS, take the SMALLEST sigma (least smoothing that still
#        passes 1+2 — preserves real structure without effort-chasing).
#     4. If NO candidate survives 1+2, use sigma_home (C). The home-range prior
#        is defensible from first principles: KDE bandwidth ~ the scale at which
#        one occurrence informs neighbouring space = the animal's movement scale.
#
# The rule, the three printed values, and the chosen sigma all go in
# methodology.md so the decision is reproducible and not a look-then-choose.

SIGMA_HOME <- c(puma = 5000, bobc = 1500)   # metres; author priors, recorded

choose_bandwidth <- function(ppp_obj, sigma_home, cell_m, label) {
  bw_diggle <- tryCatch(as.numeric(bw.diggle(ppp_obj)), error = function(e) NA_real_)
  bw_ppl    <- tryCatch(as.numeric(bw.ppl(ppp_obj)),    error = function(e) NA_real_)

  cand <- c(diggle = bw_diggle, ppl = bw_ppl, home = sigma_home)

  message("\n[", label, "] bandwidth candidates (m):")
  message("  bw.diggle : ", ifelse(is.na(bw_diggle), "failed", round(bw_diggle, 1)))
  message("  bw.ppl    : ", ifelse(is.na(bw_ppl),    "failed", round(bw_ppl, 1)))
  message("  home-range: ", sigma_home)
  message("  cell size : ", cell_m, "   |  effort-collapse floor (home/3): ",
          round(sigma_home / 3, 1))

  pass_cell   <- !is.na(cand) & cand >= cell_m
  pass_effort <- !is.na(cand) & cand >= sigma_home / 3
  survivors   <- cand[pass_cell & pass_effort]

  if (length(survivors) == 0) {
    chosen <- sigma_home
    reason <- "no candidate passed both tests; fell back to home-range prior (rule 4)"
  } else {
    chosen <- min(survivors)
    reason <- paste0("smallest surviving candidate: ",
                     names(survivors)[which.min(survivors)], " (rule 3)")
  }

  message("  -> CHOSEN sigma = ", round(chosen, 1), " m  [", reason, "]")
  list(
    candidates = cand, cell_m = cell_m, sigma_home = sigma_home,
    chosen = chosen, reason = reason,
    survivors = names(survivors)
  )
}

# ==============================================================================
# 4. KDE builder — precise-only, edge-corrected, snapped to the species grid
# ==============================================================================
# density.ppp():
#   sigma      = chosen bandwidth (m)
#   diggle     = TRUE  -> Jones-Diggle improved edge correction
#   eps        = target cell size, so the intensity image lands on the grid res
#   positive   = TRUE  -> clamp tiny negative values from edge correction to 0
# Output is intensity (points per m^2). We rasterize to the species grid template
# and MASK to the grid's land cells so ocean/out-of-boundary stays NA.

build_kde <- function(ppp_obj, sigma_m, template_r, cell_m, label) {
  im <- spatstat.explore::density.ppp(
    ppp_obj,
    sigma    = sigma_m,
    diggle   = TRUE,
    eps      = cell_m,
    positive = TRUE
  )

  # spatstat im -> terra raster. im$xcol / im$yrow are pixel CENTRES.
  m <- t(as.matrix(im))            # spatstat is column-major; transpose to row-major
  m <- m[nrow(m):1, , drop = FALSE]  # flip Y (spatstat y ascends, terra descends)
  r <- terra::rast(
    nrows = im$dim[1], ncols = im$dim[2],
    xmin = im$xrange[1], xmax = im$xrange[2],
    ymin = im$yrange[1], ymax = im$yrange[2],
    crs  = paste0("EPSG:", CRS_ANALYSIS),
    vals = as.vector(m)
  )

  # Align to the canonical species grid (identical origin/res/extent), then mask
  # to land cells. Continuous surface -> bilinear (convention).
  r_aligned <- terra::resample(r, template_r, method = "bilinear")
  r_masked  <- terra::mask(r_aligned, template_r)

  names(r_masked) <- paste0("kde_intensity_", label)
  r_masked
}

# ==============================================================================
# 5. PUMA — precise-only published surface  (Decision 29)
# ==============================================================================
occ_puma_precise <- dplyr::filter(occ_puma_sf, obscured == FALSE)
message("\nPuma: ", nrow(occ_puma_precise), " precise / ",
        nrow(occ_puma_sf), " total")
log_stage("kde_puma", "precise_points", nrow(occ_puma_precise))

ppp_puma_precise <- sf_to_ppp(occ_puma_precise, win_owin)

bw_puma <- choose_bandwidth(
  ppp_puma_precise, SIGMA_HOME["puma"],
  cell_m = SPECIES$puma$grid_res_m, label = "puma precise"
)

kde_puma_r <- build_kde(
  ppp_puma_precise, bw_puma$chosen, grid_puma_r,
  cell_m = SPECIES$puma$grid_res_m, label = "puma_precise"
)

# PUBLISH-FLOOR GATE — refuses to write if res < 1 km (policy §3).
assert_publishable(kde_puma_r, sensitive = TRUE)

kde_puma_out <- file.path(PATH$processed, "kde_puma_current_1km_3310.tif")
terra::writeRaster(kde_puma_r, kde_puma_out, overwrite = TRUE)
message("Wrote ", kde_puma_out)

# ==============================================================================
# 6. PUMA — obscured-only companion  (Decision 29; T2, effort/uncertainty read)
# ==============================================================================
# NOT a distribution surface, NOT the published puma KDE. ~28 km randomised
# coords smeared at sigma_home; useful only to see where obscured effort sits
# for the Q5 cross-read. Still >= 1 km and coarsened, so it clears policy §3,
# but it is labelled and dictionary-flagged as caveated.
occ_puma_obsc <- dplyr::filter(occ_puma_sf, obscured == TRUE)
message("\nPuma obscured companion: ", nrow(occ_puma_obsc), " points")

ppp_puma_obsc <- sf_to_ppp(occ_puma_obsc, win_owin)

# Home-range bandwidth ONLY here — the randomised coords carry ~28 km of noise,
# so a data-driven selector would be meaningless. Fixed, honest, caveated.
kde_puma_obsc_r <- build_kde(
  ppp_puma_obsc, SIGMA_HOME["puma"], grid_puma_r,
  cell_m = SPECIES$puma$grid_res_m, label = "puma_obscured_CAVEAT"
)
assert_publishable(kde_puma_obsc_r, sensitive = TRUE)

kde_puma_obsc_out <- file.path(
  PATH$processed, "kde_puma_obscured_caveat_1km_3310.tif"
)
terra::writeRaster(kde_puma_obsc_r, kde_puma_obsc_out, overwrite = TRUE)
message("Wrote ", kde_puma_obsc_out, "  [CAVEAT: effort/uncertainty read, not distribution]")

# ==============================================================================
# 7. BOBCAT — precise-only published surface  (Decision 29, consistent)
# ==============================================================================
occ_bobc_precise <- dplyr::filter(occ_bobc_sf, obscured == FALSE)
message("\nBobcat: ", nrow(occ_bobc_precise), " precise / ",
        nrow(occ_bobc_sf), " total")
log_stage("kde_bobc", "precise_points", nrow(occ_bobc_precise))

ppp_bobc_precise <- sf_to_ppp(occ_bobc_precise, win_owin)

bw_bobc <- choose_bandwidth(
  ppp_bobc_precise, SIGMA_HOME["bobc"],
  cell_m = SPECIES$bobc$grid_res_m, label = "bobc precise"
)

kde_bobc_r <- build_kde(
  ppp_bobc_precise, bw_bobc$chosen, grid_bobc_r,
  cell_m = SPECIES$bobc$grid_res_m, label = "bobc_precise"
)

# Bobcat is not sensitive; gate is a no-op but kept for symmetry / auditability.
assert_publishable(kde_bobc_r, sensitive = FALSE)

kde_bobc_out <- file.path(PATH$processed, "kde_bobc_current_500m_3310.tif")
terra::writeRaster(kde_bobc_r, kde_bobc_out, overwrite = TRUE)
message("Wrote ", kde_bobc_out)

# ==============================================================================
# 8. Record the chosen bandwidths for methodology.md (Decision 28)
# ==============================================================================
bw_record <- data.frame(
  species        = c("puma", "bobc"),
  n_precise      = c(ppp_puma_precise$n, ppp_bobc_precise$n),
  bw_diggle_m    = c(bw_puma$candidates["diggle"], bw_bobc$candidates["diggle"]),
  bw_ppl_m       = c(bw_puma$candidates["ppl"],    bw_bobc$candidates["ppl"]),
  sigma_home_m   = c(bw_puma$sigma_home,           bw_bobc$sigma_home),
  cell_m         = c(bw_puma$cell_m,               bw_bobc$cell_m),
  chosen_sigma_m = c(bw_puma$chosen,               bw_bobc$chosen),
  rule_outcome   = c(bw_puma$reason,               bw_bobc$reason),
  row.names = NULL
)
bw_csv <- file.path(PATH$tables, "tbl_09_kde_bandwidth_selection.csv")
utils::write.csv(bw_record, bw_csv, row.names = FALSE)
message("\nWrote bandwidth-selection record -> ", bw_csv)
print(bw_record)

# ==============================================================================
# End PART 1 (KDE).
# ==============================================================================


# ==============================================================================
# ==============================================================================
# PART 2 — Getis-Ord Gi* hot spots + Q5 effort cross-read (Decision 30)
# ==============================================================================
# ==============================================================================
#
# Decision 30 (CLOSED, pre-registered; NEIGHBOUR SCHEME + POINT-ASSIGNMENT
# revised after the first run exposed two problems — see methodology §6):
#
#   Grain      : CPAD unit — ONE tessellation. Matches the effort layer, the
#                occupancy frame, and unit_id joins. Not the grid (the effort
#                proxy exists only at unit grain; the GBIF background point
#                cloud was not retained).
#
#   Counts     : precise occurrence points per unit, per species, NEVER pooled
#                (Decision 3). Separate Gi* runs for puma and bobcat.
#
#   Neighbours : k-NEAREST NEIGHBOURS, k = 8, for BOTH species.
#                REVISION: the first run used queen contiguity, which stranded
#                485 / 1,129 units (43%) with NO neighbour and split the frame
#                into 630 sub-graphs — CPAD open-space units rarely share edges,
#                so contiguity is the wrong structure for this geometry. KNN k=8
#                gives every unit exactly 8 neighbours; none stranded. Gi* (star)
#                includes self via include_self(). Same k for both species:
#                home-range scaling lives in the KDE bandwidth, not the Gi* graph
#                (a fixed k is a neighbour COUNT, not a distance, so it is not a
#                per-species scale lever).
#
#   Point->unit: THREE-WAY assignment, grounded in the record's own coordinate
#                uncertainty (literature: ground the snap tolerance in the data's
#                positional error, ~26-31 m median here, NOT a 1-2 km round
#                number; a km-scale blanket snap would launder genuine matrix
#                detections into parks).
#                  1. INSIDE  — point falls within a unit (st_within).
#                  2. SNAPPED — else, if the nearest unit lies within the point's
#                     OWN coord_uncert_m, snap it in (boundary-jitter recovery).
#                  3. MATRIX  — else (incl. coord_uncert_m = NA), keep as a
#                     genuine outside-open-space occurrence. NA uncertainty is
#                     conservatively sent to MATRIX (never snapped on missing
#                     data). Matrix points are RETAINED as a separate finding
#                     (real signal for Q5 + connectivity), not discarded.
#
#   Inference  : local_gstar_perm() with conditional permutation; nsim recorded;
#                FDR (Benjamini-Hochberg) on the permutation p-values.
#
#   Q5 effort  : the retained unit x year mammal effort layer
#                (cov_effort_gbif_mammal_unityear_3310.gpkg), collapsed to a
#                per-unit surveyed-year count, used as a SHARED effort proxy for
#                both species.
#
# CAVEAT (recorded, not buried): the mammal effort layer was built bobcat-shaped
# (bobcat excluded, mammal target-group tuned to bobcat detectability). For PUMA
# it is a general "mammal-observer effort" proxy — defensible but looser than for
# bobcat. There is no puma-specific effort layer. Stated as an explicit asymmetry.

library(sfdep)
library(spdep)   # knearneigh/nbdists/knn2nb for the ~8-neighbour band diagnostic
library(tidyr)

set.seed(1310)          # reproducible permutations (3310 -> 1310)
GI_NSIM   <- 999        # permutations; recorded
GI_ALPHA  <- 0.05       # significance after FDR
GI_NB_TARGET <- 8       # target mean neighbours -> sizes the distance band
GI_MIN_NB    <- 8       # min-neighbour FLOOR: units below this get KNN top-up
                        # (Decision 30 rev 2: fixed distance band + floor, the
                        #  literature default for skewed count data; replaces the
                        #  earlier KNN k=8, which diluted dense clusters — bobcat
                        #  collapsed to 3 hot units because KNN reached across the
                        #  matrix into low-count units regardless of distance)

unit_frame_path <- file.path(PATH$interim, "openspace_cpad_bayarea_3310.gpkg")
effort_path     <- file.path(PATH$interim, "cov_effort_gbif_mammal_unityear_3310.gpkg")

units_sf  <- read_layer(unit_frame_path)     # 1,129 units, unit_id key
effort_sf <- read_layer(effort_path)         # unit x year, surveyed == 1

# ------------------------------------------------------------------------------
# 2.1 Per-unit effort proxy — collapse unit x year to a surveyed-year count
# ------------------------------------------------------------------------------
# Absence of a unit x year row = not surveyed (Decision 22 semantics). A unit
# never surveyed has effort 0 here. This is the Q5 denominator: "how much
# observer effort touched this unit".
effort_by_unit <- effort_sf |>
  sf::st_drop_geometry() |>
  dplyr::group_by(unit_id) |>
  dplyr::summarise(effort_years = dplyr::n_distinct(yr), .groups = "drop")

# ------------------------------------------------------------------------------
# 2.2 Assign precise occurrences to units — three-way, uncertainty-grounded
# ------------------------------------------------------------------------------
# Returns a list: $counts (n_occ per unit, INSIDE + SNAPPED) and $matrix (the
# genuine outside points, retained). Occurrences do NOT carry unit_id
# (dictionary confirmed) -> spatial assignment.
assign_points_to_units <- function(pts_sf, units_sf, label) {
  units_geom <- units_sf[, "unit_id"]

  # Step 1 — INSIDE (st_within)
  within_join <- sf::st_join(pts_sf, units_geom, join = sf::st_within)
  is_inside   <- !is.na(within_join$unit_id)

  inside_pts <- within_join[is_inside, ]
  inside_pts$assign <- "inside"

  # Candidates for snap/matrix = the points NOT inside any unit
  outside_pts <- pts_sf[!is_inside, ]

  # Step 2 — SNAPPED: nearest unit within the point's OWN coord_uncert_m.
  # NA uncertainty -> cannot test -> goes to matrix (never snapped).
  nearest_idx  <- sf::st_nearest_feature(outside_pts, units_geom)
  nearest_unit <- units_geom[nearest_idx, ]
  dist_to_unit <- as.numeric(
    sf::st_distance(outside_pts, nearest_unit, by_element = TRUE)
  )
  unc <- outside_pts$coord_uncert_m
  can_snap <- !is.na(unc) & !is.na(dist_to_unit) & dist_to_unit <= unc

  snapped_pts <- outside_pts[can_snap, ]
  if (nrow(snapped_pts) > 0) {
    snapped_pts$unit_id <- units_geom$unit_id[nearest_idx[can_snap]]
    snapped_pts$assign  <- "snapped"
  }

  matrix_pts <- outside_pts[!can_snap, ]
  matrix_pts$assign <- "matrix"

  n_na_unc <- sum(is.na(unc))
  message("[", label, "] point assignment: ",
          sum(is_inside), " inside, ",
          nrow(snapped_pts), " snapped (<= own coord_uncert_m), ",
          nrow(matrix_pts), " matrix (of which ", n_na_unc,
          " had NA uncertainty)")

  # Counts for Gi* = inside + snapped
  counts <- rbind(
    sf::st_drop_geometry(inside_pts[,  "unit_id", drop = FALSE]),
    if (nrow(snapped_pts) > 0)
      sf::st_drop_geometry(snapped_pts[, "unit_id", drop = FALSE])
  ) |>
    dplyr::count(unit_id, name = "n_occ")

  list(counts = counts, matrix = matrix_pts)
}

assign_puma <- assign_points_to_units(occ_puma_precise, units_sf, "puma")
assign_bobc <- assign_points_to_units(occ_bobc_precise, units_sf, "bobc")

occ_counts_puma <- assign_puma$counts
occ_counts_bobc <- assign_bobc$counts

# ------------------------------------------------------------------------------
# 2.2b Write matrix-occurrence layers (retained finding — Q5 + connectivity)
# ------------------------------------------------------------------------------
# PUMA matrix points are PRECISE puma coordinates (T2-source). They stay in
# data/interim/, are NOT published as points, and only counts/summaries may
# inform Q5 (sensitive-data-policy §2/§3). Bobcat is low-sensitivity.
matrix_puma_out <- file.path(PATH$interim,   "occ_puma_matrix_3310.gpkg")
matrix_bobc_out <- file.path(PATH$processed, "occ_bobc_matrix_3310.gpkg")
if (nrow(assign_puma$matrix) > 0) write_layer(assign_puma$matrix, matrix_puma_out)
if (nrow(assign_bobc$matrix) > 0) write_layer(assign_bobc$matrix, matrix_bobc_out)

# ------------------------------------------------------------------------------
# 2.3 Build the analysis table: every unit gets a count (0 where none) + effort
# ------------------------------------------------------------------------------
build_gistar_input <- function(units_sf, occ_counts, effort_by_unit) {
  units_sf |>
    dplyr::select(unit_id, unit_name) |>
    dplyr::left_join(occ_counts, by = "unit_id") |>
    dplyr::left_join(effort_by_unit, by = "unit_id") |>
    dplyr::mutate(
      n_occ        = tidyr::replace_na(n_occ, 0L),
      effort_years = tidyr::replace_na(effort_years, 0L)
    )
}

gi_puma_sf <- build_gistar_input(units_sf, occ_counts_puma, effort_by_unit)
gi_bobc_sf <- build_gistar_input(units_sf, occ_counts_bobc, effort_by_unit)

# ------------------------------------------------------------------------------
# 2.4 Neighbour graph — fixed distance band sized to ~8 neighbours + min floor
# ------------------------------------------------------------------------------
# Literature default for Gi* on skewed count data (ESRI; Getis & Ord): a FIXED
# DISTANCE BAND gives a natural spatial scale, sized so the mean unit has ~8
# neighbours (the "z-scores stay reliable under skew" rule of thumb). A distance
# band can leave sparse units with 0 neighbours, so we UNION in a KNN floor:
# any unit below GI_MIN_NB neighbours gets its nearest GI_MIN_NB added.
#
# The graph is built ONCE on the unit tessellation. The units are identical for
# puma, bobcat and effort — only the counts on them differ — so one shared
# neighbour graph is correct and keeps the three Gi* runs directly comparable.
# (This is why the band distance is NOT per species: the geometry is one frame.)

# ---- 2.4a Diagnostic: distance at which the mean unit has ~8 neighbours -------
# Per-unit distance to the GI_NB_TARGET-th nearest unit (ESRI "Calculate
# Distance Band From Neighbor Count" logic), summarised. Printed, then the mean
# is used as the band. Uses unit point-on-surface (matches sfdep's own handling).
unit_pts   <- sf::st_point_on_surface(sf::st_geometry(units_sf))
knn_target <- spdep::knearneigh(sf::st_coordinates(unit_pts), k = GI_NB_TARGET)
knn_dists  <- spdep::nbdists(spdep::knn2nb(knn_target), sf::st_coordinates(unit_pts))
d_kth      <- vapply(knn_dists, max, numeric(1))   # dist to the k-th neighbour

band_m <- as.numeric(mean(d_kth))
message("\n[neighbour band] distance to the ", GI_NB_TARGET,
        "th nearest unit (m): ",
        "min ",  round(min(d_kth)),
        " / median ", round(stats::median(d_kth)),
        " / mean ",   round(band_m),
        " / max ", round(max(d_kth)))
message("[neighbour band] BAND = mean = ", round(band_m),
        " m (sized to ~", GI_NB_TARGET, " neighbours; Decision 30 rev 2)")

# ---- 2.4b Build band + KNN floor, ONCE, shared across all three Gi* runs ------
nb_band <- sfdep::st_dist_band(sf::st_geometry(units_sf), upper = band_m)
nb_knn  <- sfdep::st_knn(sf::st_geometry(units_sf), k = GI_MIN_NB)

# Union band with KNN only where the band left a unit under the floor.
below_floor <- lengths(nb_band) < GI_MIN_NB
nb_final <- nb_band
if (any(below_floor)) {
  topped <- sfdep::nb_union(nb_band, nb_knn)   # element-wise union of the lists
  nb_final[below_floor] <- topped[below_floor]
}
n_topped <- sum(below_floor)
avg_links <- round(mean(lengths(nb_final)), 2)
message("[neighbour band] ", n_topped, " unit(s) below the ", GI_MIN_NB,
        "-neighbour floor -> KNN-topped; final mean links = ", avg_links)

nb_star <- sfdep::include_self(nb_final)             # Gi* includes the focal unit
wt_star <- sfdep::st_weights(nb_star, style = "B")   # binary weights (count data)

# ---- 2.4c Runner reuses the shared graph -------------------------------------
run_gistar <- function(gi_sf, value_col, label,
                       nb_star, wt_star, nsim = GI_NSIM, alpha = GI_ALPHA) {
  x  <- gi_sf[[value_col]]
  gi <- sfdep::local_gstar_perm(x, nb_star, wt_star, nsim = nsim)

  out <- gi_sf
  out$gistar_z     <- gi$gi_star
  out$gistar_p     <- gi$p_folded_sim          # folded permutation p (two-sided)
  out$gistar_p_fdr <- p.adjust(out$gistar_p, method = "BH")
  out$hotspot <- dplyr::case_when(
    is.na(out$gistar_z)                          ~ NA_character_,
    out$gistar_p_fdr <= alpha & out$gistar_z > 0 ~ "hot",
    out$gistar_p_fdr <= alpha & out$gistar_z < 0 ~ "cold",
    TRUE                                         ~ "ns"
  )

  n_hot  <- sum(out$hotspot == "hot",  na.rm = TRUE)
  n_cold <- sum(out$hotspot == "cold", na.rm = TRUE)
  message("[", label, "] Gi* (band ", round(band_m), " m + floor ",
          GI_MIN_NB, "): ", n_hot, " hot, ", n_cold,
          " cold units (FDR<=", alpha, ", nsim=", nsim, ")")
  out
}

hot_puma_sf <- run_gistar(gi_puma_sf, "n_occ", "puma", nb_star, wt_star)
hot_bobc_sf <- run_gistar(gi_bobc_sf, "n_occ", "bobc", nb_star, wt_star)

# ------------------------------------------------------------------------------
# 2.4d QC — Global G test (Getis-Ord General G), retained as an audit step
# ------------------------------------------------------------------------------
# Justifies NOT detrending. A global-gradient artifact would show as a
# significant Global G with near-zero LOCAL hot spots (the trend swamps local
# structure). Here both species have significant positive Global G AND real
# local hot spots (puma 47, bobc 6), so the local Gi* is behaving correctly and
# no detrending is warranted. The species differ in the SPATIAL ARRANGEMENT of
# their high-count units, not in whether clustering exists — that difference is
# signal (Decision 30). Same neighbours/weights as the local Gi*.
qc_global_g <- function(gi_sf, label) {
  gg <- sfdep::global_g_test(gi_sf$n_occ, nb_star, wt_star)
  message("[QC ", label, "] Global G: statistic ",
          format(gg$statistic, digits = 4),
          " | p ", format(gg$p.value, digits = 4),
          " | alt ", gg$alternative)
  invisible(gg)
}
qc_global_g(gi_puma_sf, "puma")
qc_global_g(gi_bobc_sf, "bobc")

# ------------------------------------------------------------------------------
# 2.5 Q5 EFFORT CROSS-READ (first-class, not a caveat) — the Ranthambore lesson
# ------------------------------------------------------------------------------
# A raw-count hot spot is partly an OBSERVER-EFFORT hot spot. We classify each
# occurrence hot-unit by whether it is ALSO an effort hot spot:
#   - Run Gi* a SECOND time on effort_years (same neighbours/weights).
#   - Cross the two hotspot classifications per unit.
# occ-hot AND effort-hot = effort-suspect (may be where people looked).
# occ-hot but NOT effort-hot = the more trustworthy signal.
# This LABELS the counts for honest reading; it does not "correct" them.
effort_hot_sf <- run_gistar(gi_puma_sf, "effort_years", "effort",
                            nb_star, wt_star)                     # effort geom
                                                                   # identical
                                                                   # across
                                                                   # species
effort_class <- effort_hot_sf |>
  sf::st_drop_geometry() |>
  dplyr::select(unit_id,
                effort_z = gistar_z,
                effort_hotspot = hotspot)

cross_read <- function(hot_sf, effort_class, label) {
  out <- hot_sf |>
    dplyr::left_join(effort_class, by = "unit_id") |>
    dplyr::mutate(
      q5_flag = dplyr::case_when(
        hotspot == "hot" & effort_hotspot == "hot" ~ "occ_hot_effort_hot_SUSPECT",
        hotspot == "hot" & effort_hotspot != "hot" ~ "occ_hot_effort_not_TRUSTED",
        hotspot == "hot" & is.na(effort_hotspot)   ~ "occ_hot_effort_NA",
        TRUE                                        ~ NA_character_
      )
    )
  tab <- table(out$q5_flag, useNA = "no")
  message("[", label, "] Q5 cross-read of occurrence hot spots:")
  for (nm in names(tab)) message("   ", nm, ": ", tab[[nm]])
  out
}

hot_puma_q5_sf <- cross_read(hot_puma_sf, effort_class, "puma")
hot_bobc_q5_sf <- cross_read(hot_bobc_sf, effort_class, "bobc")

# ------------------------------------------------------------------------------
# 2.6 Write hot-spot layers (unit polygons + Gi* fields + Q5 flag)
# ------------------------------------------------------------------------------
# hot_ theme. Both species are unit-grain; puma at unit grain already satisfies
# policy §3 (coarser than 1 km) and carries NO precise coordinate — only
# unit_id / unit_name / counts. The sensitive-data control here is that the
# geometry is the CPAD unit, never a point.
hot_puma_out <- file.path(PATH$processed, "hot_puma_gistar_unit_3310.gpkg")
hot_bobc_out <- file.path(PATH$processed, "hot_bobc_gistar_unit_3310.gpkg")
write_layer(hot_puma_q5_sf, hot_puma_out)
write_layer(hot_bobc_q5_sf, hot_bobc_out)

# ------------------------------------------------------------------------------
# 2.7 Record Gi* + Q5 parameters, point-assignment tallies, cross-read summary
# ------------------------------------------------------------------------------
gistar_record <- data.frame(
  species = c("puma", "bobc"),
  grain = "cpad_unit",
  neighbours = paste0("dist_band_", round(band_m), "m_floor",
                      GI_MIN_NB, "_include_self"),
  band_m = round(band_m),
  min_nb_floor = GI_MIN_NB,
  weights = "binary_B",
  nsim = GI_NSIM,
  fdr = "BH",
  alpha = GI_ALPHA,
  n_units = c(nrow(hot_puma_q5_sf), nrow(hot_bobc_q5_sf)),
  n_inside_plus_snapped = c(sum(gi_puma_sf$n_occ), sum(gi_bobc_sf$n_occ)),
  n_matrix = c(nrow(assign_puma$matrix), nrow(assign_bobc$matrix)),
  n_hot = c(sum(hot_puma_q5_sf$hotspot == "hot", na.rm = TRUE),
            sum(hot_bobc_q5_sf$hotspot == "hot", na.rm = TRUE)),
  n_cold = c(sum(hot_puma_q5_sf$hotspot == "cold", na.rm = TRUE),
             sum(hot_bobc_q5_sf$hotspot == "cold", na.rm = TRUE)),
  n_occ_hot_effort_suspect = c(
    sum(hot_puma_q5_sf$q5_flag == "occ_hot_effort_hot_SUSPECT", na.rm = TRUE),
    sum(hot_bobc_q5_sf$q5_flag == "occ_hot_effort_hot_SUSPECT", na.rm = TRUE)),
  n_occ_hot_effort_trusted = c(
    sum(hot_puma_q5_sf$q5_flag == "occ_hot_effort_not_TRUSTED", na.rm = TRUE),
    sum(hot_bobc_q5_sf$q5_flag == "occ_hot_effort_not_TRUSTED", na.rm = TRUE)),
  row.names = NULL
)
gistar_csv <- file.path(PATH$tables, "tbl_10_gistar_q5_crossread.csv")
utils::write.csv(gistar_record, gistar_csv, row.names = FALSE)
message("\nWrote Gi*/Q5 record -> ", gistar_csv)
print(gistar_record)

# ==============================================================================
# End PART 2 (Gi* + Q5 effort cross-read).
# ==============================================================================


# ==============================================================================
# ==============================================================================
# PART 3 — Unit-level summary statistics, per species (keyed on unit_id)
# ==============================================================================
# ==============================================================================
#
# One table PER SPECIES (never pooled, Decision 3): stats_puma_unit / stats_bobc_unit.
# Feeds story-site unit popups + the methods cross-check. Fields per unit_id:
#   - occurrence counts (precise inside+snapped; total incl. obscured)
#   - obscured fraction (FLAGGED low-meaning: obscured coords are randomised,
#     so a per-unit obscured fraction reflects where randomisation dropped points,
#     not a true property of the unit — kept per request, caveated in dictionary)
#   - effort-year count (from the shared mammal effort layer)
#   - KDE mean AND max within the unit (zonal, coverage-weighted)
#   - Gi* class + z (from the hot_ layers already built)
#   - bobcat only: bobc_detected — naive per-unit collapse of the detection
#     history (1 = a bobcat was recorded in the unit; 0 = surveyed, none; NA =
#     never surveyed). This is the NAIVE observable, NOT modelled occupancy psi
#     (psi is a study-wide fitted scalar, 0.464; not a per-unit quantity).

library(exactextractr)   # coverage-weighted zonal stats (project stack)

# ------------------------------------------------------------------------------
# 3.1 Obscured fraction per unit (BOTH species; total counts incl. obscured)
# ------------------------------------------------------------------------------
# Assign ALL points (precise + obscured) to units by st_within only (no snap:
# obscured coords are randomised, snapping them would be meaningless). Fraction
# = obscured / total among points that fall inside a unit.
obscured_fraction_by_unit <- function(occ_all_sf, units_sf, label) {
  j <- sf::st_join(occ_all_sf, units_sf[, "unit_id"], join = sf::st_within)
  j <- j[!is.na(j$unit_id), ]
  tab <- j |>
    sf::st_drop_geometry() |>
    dplyr::group_by(unit_id) |>
    dplyr::summarise(
      n_total    = dplyr::n(),
      n_obscured = sum(obscured, na.rm = TRUE),
      obscured_frac = n_obscured / n_total,
      .groups = "drop"
    )
  message("[", label, "] obscured fraction computed for ", nrow(tab),
          " units with >=1 point (incl. obscured)")
  tab
}
obsc_puma <- obscured_fraction_by_unit(occ_puma_sf, units_sf, "puma")
obsc_bobc <- obscured_fraction_by_unit(occ_bobc_sf, units_sf, "bobc")

# ------------------------------------------------------------------------------
# 3.2 Zonal KDE mean + max per unit (coverage-weighted)
# ------------------------------------------------------------------------------
# exact_extract handles partial-cell coverage at unit edges. Puma zonal stats
# use the PUBLISHED precise-only KDE (kde_puma_r); bobcat uses kde_bobc_r.
zonal_kde <- function(kde_r, units_sf, label) {
  vals <- exactextractr::exact_extract(
    kde_r, units_sf, fun = c("mean", "max"), progress = FALSE
  )
  out <- data.frame(
    unit_id  = units_sf$unit_id,
    kde_mean = vals$mean,
    kde_max  = vals$max
  )
  message("[", label, "] zonal KDE mean/max computed for ", nrow(out), " units")
  out
}
kde_zonal_puma <- zonal_kde(kde_puma_r, units_sf, "puma")
kde_zonal_bobc <- zonal_kde(kde_bobc_r, units_sf, "bobc")

# ------------------------------------------------------------------------------
# 3.3 Bobcat naive per-unit detection (observable, NOT modelled psi)
# ------------------------------------------------------------------------------
# detected = a precise bobcat point falls in the unit (inside or snapped).
# surveyed = the unit appears in the effort layer at all (any surveyed year).
#   bobc_detected = 1  if detected
#                 = 0  if surveyed but not detected
#                 = NA if never surveyed (never a fabricated 0, Decision 22/27)
bobc_detected_by_unit <- function(occ_counts_bobc, effort_by_unit, units_sf) {
  detected_ids <- occ_counts_bobc$unit_id[occ_counts_bobc$n_occ > 0]
  surveyed_ids <- effort_by_unit$unit_id[effort_by_unit$effort_years > 0]
  data.frame(unit_id = units_sf$unit_id) |>
    dplyr::mutate(
      bobc_detected = dplyr::case_when(
        unit_id %in% detected_ids ~ 1L,
        unit_id %in% surveyed_ids ~ 0L,
        TRUE                      ~ NA_integer_
      )
    )
}
bobc_detect <- bobc_detected_by_unit(occ_counts_bobc, effort_by_unit, units_sf)
message("[bobc] naive per-unit detection: ",
        sum(bobc_detect$bobc_detected == 1, na.rm = TRUE), " detected, ",
        sum(bobc_detect$bobc_detected == 0, na.rm = TRUE), " surveyed-not-detected, ",
        sum(is.na(bobc_detect$bobc_detected)), " never-surveyed (NA)")

# ------------------------------------------------------------------------------
# 3.4 Assemble the two per-species tables (keyed unit_id)
# ------------------------------------------------------------------------------
# Gi* fields come from the hot_ layers (n_occ, effort_years, gistar_z, hotspot,
# q5_flag already per unit). Drop geometry — these are tabular summaries (stats_
# theme, .csv). unit polygons remain joinable via unit_id.
build_unit_stats <- function(hot_sf, obsc_tbl, kde_zonal, units_sf,
                             extra = NULL) {
  base <- hot_sf |>
    sf::st_drop_geometry() |>
    dplyr::select(unit_id, unit_name, n_occ, effort_years,
                  gistar_z, hotspot, q5_flag)

  out <- units_sf |>
    sf::st_drop_geometry() |>
    dplyr::select(unit_id, county, hab_area_km2) |>
    dplyr::left_join(base, by = "unit_id") |>
    dplyr::left_join(
      dplyr::select(obsc_tbl, unit_id, n_total, n_obscured, obscured_frac),
      by = "unit_id"
    ) |>
    dplyr::left_join(kde_zonal, by = "unit_id") |>
    dplyr::mutate(
      n_occ        = tidyr::replace_na(n_occ, 0L),
      effort_years = tidyr::replace_na(effort_years, 0L),
      n_total      = tidyr::replace_na(n_total, 0L),
      n_obscured   = tidyr::replace_na(n_obscured, 0L)
      # obscured_frac left NA where n_total == 0 (no points -> undefined, honest)
    )
  if (!is.null(extra)) out <- dplyr::left_join(out, extra, by = "unit_id")
  out
}

stats_puma_unit <- build_unit_stats(
  hot_puma_q5_sf, obsc_puma, kde_zonal_puma, units_sf
)
stats_bobc_unit <- build_unit_stats(
  hot_bobc_q5_sf, obsc_bobc, kde_zonal_bobc, units_sf,
  extra = bobc_detect                # bobcat-only naive detection field
)

# ------------------------------------------------------------------------------
# 3.5 Write the two tables (stats_ theme, .csv, keyed unit_id)
# ------------------------------------------------------------------------------
stats_puma_out <- file.path(PATH$tables, "stats_puma_unit_3310.csv")
stats_bobc_out <- file.path(PATH$tables, "stats_bobc_unit_3310.csv")
utils::write.csv(stats_puma_unit, stats_puma_out, row.names = FALSE)
utils::write.csv(stats_bobc_unit, stats_bobc_out, row.names = FALSE)
message("\nWrote per-unit stats -> ", stats_puma_out)
message("Wrote per-unit stats -> ", stats_bobc_out)
message("[puma] stats table: ", nrow(stats_puma_unit), " units, ",
        ncol(stats_puma_unit), " fields")
message("[bobc] stats table: ", nrow(stats_bobc_unit), " units, ",
        ncol(stats_bobc_unit), " fields")

# ==============================================================================
# End PART 3 (unit-level summary statistics).
# ==============================================================================
