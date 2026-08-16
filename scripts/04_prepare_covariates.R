# =============================================================================
# 04_prepare_covariates.R
#
# Week 5 covariate construction — human-footprint pair (gHM + housing density).
# Two pre-registered tasks, in order:
#
#   TASK 1  SILVIS HUDEN2020 transform (pre-registered in methodology.md §4.9):
#           cap raw density at study-area p99, then log1p, BEFORE rasterization.
#           Records the exact cap value and the count of affected blocks.
#           Rasterizes onto the puma 1 km and bobcat 500 m grids, and summarises
#           to CPAD units (area-weighted block->unit; safe for spans_gradient
#           units per Decision 17).
#
#   TASK 2  gHM x housing-density collinearity check (flagged Week 2):
#           both carry the urban-intensity gradient (Decision 12) and will
#           correlate. Correlation computed at THREE grains, per species, never
#           pooled (Decision 3): CPAD units, puma 1 km grid, bobcat 500 m grid.
#           Prints decision-ready numbers to close Decision 23 (keep both / drop
#           one). This script does NOT drop a layer — that is a logged decision.
#
# Pre-registration discipline: the transform is applied exactly as specified in
# §4.9 (log1p primary + p99 cap). No post-hoc transform choice. Record observed
# values (cap, affected blocks, correlations) in methodology.md when run.
#
# Inputs (all EPSG:3310, all in data/interim/ — scripts 01-02e write there):
#   openspace_cpad_bayarea_3310.gpkg   (1,129 units; unit_id, spans_gradient)
#   cov_housing_silvis_blocks_3310.gpkg (blocks; HUDEN2020, PUBFLAG)
#   cov_ghm_v3_2022_3310.tif            (300 m, 0-1 continuous)
#   grid_puma_1km_3310.tif              (1 km template)
#   grid_bobc_500m_3310.tif            (500 m template)
#
# Outputs (all EPSG:3310):
#   data/interim/cov_housing_logden_puma_1km_3310.tif
#   data/interim/cov_housing_logden_bobc_500m_3310.tif
#   data/interim/cov_ghm_puma_1km_3310.tif
#   data/interim/cov_ghm_bobc_500m_3310.tif
#   data/interim/cov_unit_footprint_3310.gpkg         (per-unit gHM + housing summaries)
#   outputs/tables/tbl_04_huden_transform.csv         (cap value, affected blocks)
#   outputs/tables/tbl_04_collinearity_footprint.csv  (per-species correlations)
#   outputs/figures/fig_04_huden_transform.png        (raw vs capped-log density)
#   outputs/figures/fig_04_ghm_housing_scatter.png    (per-grain scatter, per species)
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

library(sf)
library(terra)
library(tidyverse)
library(exactextractr)

# -----------------------------------------------------------------------------
# 0. Paths
# NOTE: scripts 01-02e write every layer below to data/interim/ (see change log
# 2026-08-03 / 2026-08-05 and data-dictionary.md "Storage" fields). Use literal
# interim paths, not build_path() with a guessed `where`.
# -----------------------------------------------------------------------------
f_units    <- file.path(PATH$interim, "openspace_cpad_bayarea_3310.gpkg")
f_housing  <- file.path(PATH$interim, "cov_housing_silvis_blocks_3310.gpkg")
f_ghm      <- file.path(PATH$interim, "cov_ghm_v3_2022_3310.tif")
f_grid_pu  <- file.path(PATH$interim, "grid_puma_1km_3310.tif")
f_grid_bo  <- file.path(PATH$interim, "grid_bobc_500m_3310.tif")

stopifnot(
  file.exists(f_units), file.exists(f_housing), file.exists(f_ghm),
  file.exists(f_grid_pu), file.exists(f_grid_bo)
)

# -----------------------------------------------------------------------------
# 1. Load
# -----------------------------------------------------------------------------
units_sf   <- read_layer(f_units)                    # asserts EPSG:3310
housing_sf <- read_layer(f_housing)                  # asserts EPSG:3310
ghm_r      <- terra::rast(f_ghm)
grid_pu_r  <- terra::rast(f_grid_pu)
grid_bo_r  <- terra::rast(f_grid_bo)

# The download script (01_download_open_data.R) renames SILVIS fields to
# snake_case on write (naming-conventions §5): HUDEN2020 -> huden_2020,
# PUBFLAG -> pubflag. Resolve the density column tolerantly so a re-read that
# changes case does not break the run.
nm <- names(housing_sf)
col_huden <- nm[tolower(nm) %in% c("huden_2020", "huden2020")][1]
col_pub   <- nm[tolower(nm) %in% c("pubflag", "pub_flag")][1]
if (is.na(col_huden)) {
  stop("No HUDEN2020 density column found in ", basename(f_housing),
       ". Columns present: ", paste(nm, collapse = ", "), call. = FALSE)
}
message("Using housing density column: ", col_huden,
        if (!is.na(col_pub)) paste0(" | PLA flag: ", col_pub) else " | no PLA flag column")

stopifnot("unit_id" %in% names(units_sf))

# Geometry hygiene (Decision 17 flagged invalid geometries on the CPAD source).
if (any(!sf::st_is_valid(housing_sf))) housing_sf <- sf::st_make_valid(housing_sf)
if (any(!sf::st_is_valid(units_sf)))   units_sf   <- sf::st_make_valid(units_sf)

log_stage("cov_housing", "blocks_loaded", nrow(housing_sf))
log_stage("openspace",   "units_loaded",  nrow(units_sf))

# =============================================================================
# TASK 1 — SILVIS HUDEN2020 pre-registered transform
# =============================================================================
# Pre-registration (§4.9):
#   (1) primary handling: log1p(HUDEN2020)  -- tame heavy right-skew
#   (2) cap before burning to grid: winsorize at p99 (study-area, operative cap
#       chosen this turn) so sliver blocks cannot dominate rasterized cells.
# Order: cap the RAW density at p99, THEN log1p. Capping raw keeps the recorded
# ceiling interpretable in native units/km2. PLA public-land zeros (PUBFLAG==1)
# are design, not outliers (Decision 16) -- left untouched, included in the
# distribution the p99 is computed over (they are legitimate near-zero values).
# -----------------------------------------------------------------------------

huden_raw <- housing_sf[[col_huden]]

# Operative cap = study-area p99 of HUDEN2020 (answer this turn: p99, data-driven)
cap_p99 <- as.numeric(stats::quantile(huden_raw, 0.99, na.rm = TRUE))

# Reference hard ceilings recorded alongside for the change log (not applied)
ref_1e4 <- sum(huden_raw > 1e4, na.rm = TRUE)
ref_1e5 <- sum(huden_raw > 1e5, na.rm = TRUE)
ref_1e6 <- sum(huden_raw > 1e6, na.rm = TRUE)

n_affected  <- sum(huden_raw > cap_p99, na.rm = TRUE)     # blocks pulled down to cap
n_blocks    <- sum(!is.na(huden_raw))
pct_affected <- 100 * n_affected / n_blocks

huden_capped <- pmin(huden_raw, cap_p99)                  # winsorize at p99
housing_sf$huden2020_cap    <- huden_capped
housing_sf$huden2020_logden <- log1p(huden_capped)        # covariate value burned to grid

message(sprintf(
  "HUDEN2020 transform: cap(p99) = %.1f units/km2 | %d of %d blocks capped (%.2f%%)",
  cap_p99, n_affected, n_blocks, pct_affected
))
message(sprintf(
  "  reference hard-ceiling counts (not applied): >1e4 = %d | >1e5 = %d | >1e6 = %d",
  ref_1e4, ref_1e5, ref_1e6
))

# ---- Record the transform parameters (pre-registration audit trail) ---------
tbl_transform <- data.frame(
  field              = "HUDEN2020",
  cap_rule           = "p99_study_area",
  cap_value_per_km2  = round(cap_p99, 2),
  n_blocks_total     = n_blocks,
  n_blocks_capped    = n_affected,
  pct_blocks_capped  = round(pct_affected, 3),
  huden_median       = round(stats::median(huden_raw, na.rm = TRUE), 1),
  huden_p90          = round(as.numeric(stats::quantile(huden_raw, 0.90, na.rm = TRUE)), 1),
  huden_max_raw      = round(max(huden_raw, na.rm = TRUE), 1),
  ref_ceiling_1e4_n  = ref_1e4,
  ref_ceiling_1e5_n  = ref_1e5,
  ref_ceiling_1e6_n  = ref_1e6,
  transform          = "log1p(pmin(HUDEN2020, cap))",
  stringsAsFactors   = FALSE
)
write.csv(tbl_transform,
          file.path(PATH$tables, "tbl_04_huden_transform.csv"),
          row.names = FALSE)

# -----------------------------------------------------------------------------
# 1a. Rasterize log-density housing onto each species grid
#     Housing is a polygon block layer -> rasterize the block value directly
#     (no resampling of a source raster; the value IS per-block). Cells falling
#     in >1 block take an area-weighted mean via `cover`+`sum` is overkill here;
#     Deterministic area-weighted burn (version-safe): rasterize the block
#     log-density to a FINE sub-grid (block detail preserved), then aggregate to
#     the target cell by mean. This avoids terra::rasterize(fun=) polygon
#     behaviour that varies across versions, and avoids seam bias from a single
#     covering-polygon burn. Sub-grid factor picks ~50 m detail under each grid.
# -----------------------------------------------------------------------------
housing_v <- terra::vect(housing_sf)

rasterize_logden <- function(grid_r, tag) {
  # Fine burn: target res / fine_fac ~= 50 m, so each target cell aggregates
  # from many sub-cells carrying block-level values (area-weighted in effect).
  target_res <- min(terra::res(grid_r))
  fine_fac   <- max(1, round(target_res / 50))         # 1km->20, 500m->10
  fine_r     <- terra::disagg(grid_r, fact = fine_fac)
  # Rasterize block value onto the fine grid (single value per sub-cell)
  r_fine <- terra::rasterize(housing_v, fine_r, field = "huden2020_logden")
  # Aggregate sub-cells back to the target grid by mean (ignores NA sub-cells)
  r <- terra::aggregate(r_fine, fact = fine_fac, fun = "mean", na.rm = TRUE)
  r <- terra::resample(r, grid_r, method = "near")     # align exactly to target
  r <- terra::mask(r, grid_r)                          # land cells only
  names(r) <- "housing_logden"
  out <- file.path(PATH$interim,
                   sprintf("cov_housing_logden_%s_3310.tif", tag))
  terra::writeRaster(r, out, overwrite = TRUE)
  message("Wrote ", out)
  r
}

housing_logden_pu_r <- rasterize_logden(grid_pu_r, "puma_1km")
housing_logden_bo_r <- rasterize_logden(grid_bo_r, "bobc_500m")

# -----------------------------------------------------------------------------
# 1b. gHM resampled onto each species grid (continuous -> bilinear, Decision 15)
#
# Edge-fill: gHM's source was cropped to the 5 km-buffered AOI (§4.9). Bilinear
# resampling onto the analysis grids returns NA for land cells near the study-
# area edge where the 300 m source window does not fully underlie the target
# cell (observed: 1,140 puma 1 km land cells, 5.6%). These are NOT interior
# gaps — they are a boundary underlap of a smooth, continuous surface. We extend
# the surface to the analysis boundary by filling ONLY land cells (never water /
# off-study-area) from nearest valid neighbours, iterated until the land holes
# close (bounded). Count filled cells and log — provenance stays explicit. This
# is surface extension to the boundary, not gap invention.
# -----------------------------------------------------------------------------
fill_land_na <- function(r, land_mask, max_iter = 25) {
  # Fill NA cells that are land, from nearest valid neighbours, iteratively.
  filled <- r
  for (i in seq_len(max_iter)) {
    holes <- terra::global(is.na(filled) & !is.na(land_mask), "sum", na.rm = TRUE)[[1]]
    if (holes == 0) break
    # focal mean over 3x3, only writing where currently NA (na.policy = "only")
    filled <- terra::focal(filled, w = 3, fun = mean, na.rm = TRUE,
                           na.policy = "only")
    filled <- terra::mask(filled, land_mask)   # never bleed off the land mask
  }
  filled
}

resample_ghm <- function(grid_r, tag) {
  r <- terra::resample(ghm_r, grid_r, method = "bilinear")
  r <- terra::mask(r, grid_r)                  # land cells only

  # Count land holes before fill, fill, count after (log for provenance)
  n_before <- terra::global(is.na(r) & !is.na(grid_r), "sum", na.rm = TRUE)[[1]]
  if (n_before > 0) {
    r <- fill_land_na(r, grid_r)
    n_after <- terra::global(is.na(r) & !is.na(grid_r), "sum", na.rm = TRUE)[[1]]
    message(sprintf("  gHM edge-fill [%s]: %d land NAs -> %d remaining (filled %d)",
                    tag, n_before, n_after, n_before - n_after))
  }
  names(r) <- "ghm"
  out <- file.path(PATH$interim, sprintf("cov_ghm_%s_3310.tif", tag))
  terra::writeRaster(r, out, overwrite = TRUE)
  message("Wrote ", out)
  r
}

ghm_pu_r <- resample_ghm(grid_pu_r, "puma_1km")
ghm_bo_r <- resample_ghm(grid_bo_r, "bobc_500m")

# -----------------------------------------------------------------------------
# 1c. Per-unit summary of both covariates (occupancy sites)
#     Decision 17: spans_gradient units (hab_area_km2 > 5 km2, 192 units) are
#     unsafe to reduce to a single whole-unit mean. exactextractr gives an
#     area-weighted mean over covered cells, which is the correct sub-cell
#     summary for ALL units and is what the flag asked for. We ALSO carry the
#     within-unit SD so the gradient units can be inspected downstream.
#     Housing summarised from the block layer directly (area-weighted), gHM from
#     its native 300 m raster (area-weighted) — summarise each at its own grain,
#     not off the coarsened species grid.
# -----------------------------------------------------------------------------
# gHM per unit (area-weighted mean + sd) from the 300 m source
units_sf$ghm_mean <- exactextractr::exact_extract(ghm_r, units_sf, "mean")
units_sf$ghm_sd   <- exactextractr::exact_extract(ghm_r, units_sf, "stdev")

# Guard: no unit should have NA gHM (5 km buffer covers every in-study unit).
# Report rather than silently pass a covariate NA into the occupancy stack.
n_ghm_na <- sum(is.na(units_sf$ghm_mean))
if (n_ghm_na > 0) {
  warning(sprintf("%d units have NA gHM mean — check boundary coverage of the 300 m source", n_ghm_na))
} else {
  message("gHM per-unit coverage complete (0 NA units)")
}

# Housing per unit: area-weighted mean of block log-density.
# Intersect blocks x units, weight by intersection area.
suppressWarnings({
  bx <- sf::st_intersection(
    housing_sf[, c("huden2020_logden")],
    units_sf[, c("unit_id")]
  )
})
bx$w_area_m2 <- as.numeric(sf::st_area(bx))
housing_unit_tbl <- bx |>
  sf::st_drop_geometry() |>
  dplyr::group_by(unit_id) |>
  dplyr::summarise(
    housing_logden_mean = stats::weighted.mean(huden2020_logden, w_area_m2, na.rm = TRUE),
    housing_logden_sd   = sqrt(stats::weighted.mean(
      (huden2020_logden - stats::weighted.mean(huden2020_logden, w_area_m2, na.rm = TRUE))^2,
      w_area_m2, na.rm = TRUE)),
    .groups = "drop"
  )

units_sf <- units_sf |>
  dplyr::left_join(housing_unit_tbl, by = "unit_id")

# Units with no overlapping block (fully inside a gap) -> housing NA; that is a
# true missing, not a zero. Report the count rather than silently filling.
n_housing_na <- sum(is.na(units_sf$housing_logden_mean))
message(sprintf("Units with no overlapping SILVIS block (housing = NA): %d", n_housing_na))

# Write the per-unit footprint covariate layer
cov_unit_out <- file.path(PATH$interim, "cov_unit_footprint_3310.gpkg")
keep_cols <- c("unit_id", "spans_gradient",
               "ghm_mean", "ghm_sd",
               "housing_logden_mean", "housing_logden_sd")
keep_cols <- intersect(keep_cols, names(units_sf))
write_layer(units_sf[, keep_cols], cov_unit_out)

# =============================================================================
# TASK 2 — gHM x housing collinearity, per species, three grains
# =============================================================================
# Decision 3: never pool species. Puma uses the 1 km grid, bobcat the 500 m grid.
# Units grain is shared (occupancy frame is bobcat-track; reported once).
# Correlation is computed on the TRANSFORMED, gridded/summarised housing — the
# value that actually enters the stack — not on raw HUDEN2020 (whose sliver
# artifact would distort the correlation).
# -----------------------------------------------------------------------------

corr_pair <- function(x, y, grain, species) {
  ok <- is.finite(x) & is.finite(y)
  n  <- sum(ok)
  if (n < 3) {
    return(data.frame(species = species, grain = grain, n = n,
                      pearson = NA_real_, spearman = NA_real_))
  }
  data.frame(
    species  = species,
    grain    = grain,
    n        = n,
    pearson  = round(stats::cor(x[ok], y[ok], method = "pearson"), 4),
    spearman = round(stats::cor(x[ok], y[ok], method = "spearman"), 4)
  )
}

# ---- Grid grains (per species) ----------------------------------------------
pu_stack <- c(ghm_pu_r, housing_logden_pu_r)
bo_stack <- c(ghm_bo_r, housing_logden_bo_r)
pu_vals  <- terra::values(pu_stack, dataframe = TRUE)
bo_vals  <- terra::values(bo_stack, dataframe = TRUE)

corr_grid_pu <- corr_pair(pu_vals$ghm, pu_vals$housing_logden, "grid_1km",  "puma")
corr_grid_bo <- corr_pair(bo_vals$ghm, bo_vals$housing_logden, "grid_500m", "bobc")

# ---- Unit grain (shared occupancy frame) ------------------------------------
corr_unit <- corr_pair(units_sf$ghm_mean, units_sf$housing_logden_mean,
                       "cpad_unit", "bobc")   # occupancy frame is the bobcat track

collin_tbl <- dplyr::bind_rows(corr_unit, corr_grid_bo, corr_grid_pu)
write.csv(collin_tbl,
          file.path(PATH$tables, "tbl_04_collinearity_footprint.csv"),
          row.names = FALSE)

message("\n===== gHM x housing (log-density) collinearity =====")
print(collin_tbl, row.names = FALSE)
message(
  "\nDecision 23 guidance (not applied here):\n",
  "  |r| < 0.7  -> keep both, document the correlation\n",
  "  |r| >= 0.7 -> drop one (keep gHM: broader, DOI-pinned, 0-1; or keep\n",
  "               housing if the urban-edge signal is the target) -> log as a\n",
  "               numbered decision with the observed r.\n"
)

# =============================================================================
# 2. Figures
# =============================================================================

# --- Fig 1: raw vs capped-log housing density distribution -------------------
png(file.path(PATH$figures, "fig_04_huden_transform.png"),
    width = 1600, height = 700, res = 150)
op <- par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
hist(log10(huden_raw[huden_raw > 0]), breaks = 60, col = "grey80", border = NA,
     main = "HUDEN2020 raw (log10 units/km2)",
     xlab = "log10 density"); abline(v = log10(cap_p99), col = "red", lwd = 2)
hist(housing_sf$huden2020_logden, breaks = 60, col = "steelblue", border = NA,
     main = "log1p(capped) — covariate value",
     xlab = "log1p density (capped at p99)")
par(op); dev.off()

# --- Fig 2: gHM vs housing scatter, per grain --------------------------------
png(file.path(PATH$figures, "fig_04_ghm_housing_scatter.png"),
    width = 1800, height = 620, res = 150)
op <- par(mfrow = c(1, 3), mar = c(4, 4, 3, 1))
plot(units_sf$ghm_mean, units_sf$housing_logden_mean, pch = 16,
     col = adjustcolor("black", 0.4), cex = 0.6,
     xlab = "gHM (unit mean)", ylab = "housing log-den (unit mean)",
     main = sprintf("CPAD units  r=%.2f", corr_unit$pearson))
plot(bo_vals$ghm, bo_vals$housing_logden, pch = 16,
     col = adjustcolor("darkgreen", 0.25), cex = 0.4,
     xlab = "gHM", ylab = "housing log-den",
     main = sprintf("bobcat 500 m  r=%.2f", corr_grid_bo$pearson))
plot(pu_vals$ghm, pu_vals$housing_logden, pch = 16,
     col = adjustcolor("firebrick", 0.25), cex = 0.4,
     xlab = "gHM", ylab = "housing log-den",
     main = sprintf("puma 1 km  r=%.2f", corr_grid_pu$pearson))
par(op); dev.off()

# =============================================================================
# 3. Console summary
# =============================================================================
message("\n================ 04_prepare_covariates.R complete ================")
message(sprintf("HUDEN2020 cap (p99): %.1f units/km2  | blocks capped: %d (%.2f%%)",
                cap_p99, n_affected, pct_affected))
message("Rasters written: housing log-den + gHM on puma 1 km and bobcat 500 m grids")
message(sprintf("Per-unit footprint layer: %s", cov_unit_out))
message("Collinearity table: outputs/tables/tbl_04_collinearity_footprint.csv")
message("--> Report r values back to close Decision 23 (keep both / drop one).")
