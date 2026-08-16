# =============================================================================
# 05_summarise_covariates.R
#
# Week 5 — summarise every covariate to (a) CPAD units (occupancy frame, keyed
# on unit_id) and (b) each species grid (puma 1 km / bobcat 500 m, keyed on
# cell_id), then assemble the stacked covariate tables the models consume.
#
# Covariates handled here:
#   - Land cover  : ESA WorldCover 2021 (categorical, 8 classes) -> class
#                   FRACTION per unit / per cell (one column per class).
#   - Terrain     : elevation + slope (continuous -> mean + SD); aspect
#                   (circular -> northness=cos, eastness=sin, then mean).
#   - Footprint   : gHM + housing log-density — NOT recomputed. Unit summaries
#                   read from script 04's cov_unit_footprint_3310.gpkg; grid
#                   summaries read from script 04's gridded rasters.
#
# Resampling rule (methodology §2 / Decision 12/13):
#   categorical -> near ; continuous -> bilinear. Class FRACTIONS are computed
#   by coverage weighting (exactextractr / fine-cell aggregation) — this is the
#   categorical->continuous summary and is distinct from the `near` rule, which
#   governs class-VALUE reprojection, not fraction computation.
#
# spans_gradient (Decision 17): 192 large units (hab_area_km2 > 5 km2). Not a
# filter — no unit dropped. exact_extract means are already area-weighted
# (sub-cell) so they are safe; the flag's real cost is that a single mean HIDES
# within-unit heterogeneity, so every continuous covariate also carries an SD,
# and the flag is written onto the unit stack so downstream knows which means to
# treat cautiously.
#
# Per-species discipline (Decision 3): puma uses the 1 km grid, bobcat the 500 m
# grid, never pooled. Decision 23: puma resistance drops housing (kept on disk);
# bobcat keeps both. The GRID stacks reflect this — puma grid stack has no
# housing column; bobcat grid stack does. The UNIT stack is the bobcat-track
# occupancy frame and carries both.
#
# Inputs (all EPSG:3310, data/interim/):
#   openspace_cpad_bayarea_3310.gpkg            (units; unit_id, spans_gradient)
#   grid_puma_1km_3310.tif / grid_bobc_500m_3310.tif   (cell_id templates)
#   cov_landcover_worldcover2021_3310.tif       (categorical, ~8 m)
#   cov_dem_terraintiles_z12_3310.tif           (continuous)
#   cov_slope_deg_terraintiles_z12_3310.tif     (continuous)
#   cov_aspect_deg_terraintiles_z12_3310.tif    (circular degrees)
#   cov_unit_footprint_3310.gpkg                (04: ghm_*, housing_logden_*)
#   cov_ghm_puma_1km_3310.tif / cov_ghm_bobc_500m_3310.tif            (04)
#   cov_housing_logden_puma_1km_3310.tif / _bobc_500m_3310.tif        (04)
#
# Outputs:
#   data/interim/stack_occu_units_3310.gpkg     (unit_id + all covariates + spans_gradient)
#   data/interim/stack_puma_grid_1km_3310.gpkg  (cell_id + covariates, NO housing)
#   data/interim/stack_bobc_grid_500m_3310.gpkg (cell_id + covariates, incl housing)
#   outputs/tables/stack_occu_units_3310.csv
#   outputs/tables/stack_puma_grid_1km_3310.csv
#   outputs/tables/stack_bobc_grid_500m_3310.csv
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
# -----------------------------------------------------------------------------
f_units    <- file.path(PATH$interim, "openspace_cpad_bayarea_3310.gpkg")
f_grid_pu  <- file.path(PATH$interim, "grid_puma_1km_3310.tif")
f_grid_bo  <- file.path(PATH$interim, "grid_bobc_500m_3310.tif")

f_lc       <- file.path(PATH$interim, "cov_landcover_worldcover2021_3310.tif")
f_dem      <- file.path(PATH$interim, "cov_dem_terraintiles_z12_3310.tif")
f_slope    <- file.path(PATH$interim, "cov_slope_deg_terraintiles_z12_3310.tif")
f_aspect   <- file.path(PATH$interim, "cov_aspect_deg_terraintiles_z12_3310.tif")

f_unit_fp  <- file.path(PATH$interim, "cov_unit_footprint_3310.gpkg")
f_ghm_pu   <- file.path(PATH$interim, "cov_ghm_puma_1km_3310.tif")
f_ghm_bo   <- file.path(PATH$interim, "cov_ghm_bobc_500m_3310.tif")
f_hou_pu   <- file.path(PATH$interim, "cov_housing_logden_puma_1km_3310.tif")
f_hou_bo   <- file.path(PATH$interim, "cov_housing_logden_bobc_500m_3310.tif")

need <- c(f_units, f_grid_pu, f_grid_bo, f_lc, f_dem, f_slope, f_aspect,
          f_unit_fp, f_ghm_pu, f_ghm_bo, f_hou_pu, f_hou_bo)
miss <- need[!file.exists(need)]
if (length(miss)) stop("Missing inputs:\n  ", paste(miss, collapse = "\n  "),
                       call. = FALSE)

# WorldCover class codes (methodology §4.5). Fixed set; classes absent in the AOI
# simply get fraction 0 (kept as columns for schema stability across grids).
WC_CLASSES <- c(tree = 10, shrub = 20, grass = 30, crop = 40, built = 50,
                bare = 60, wetland = 90, water = 80)

# -----------------------------------------------------------------------------
# 1. Load
# -----------------------------------------------------------------------------
units_sf <- read_layer(f_units)                       # asserts EPSG:3310
grid_pu  <- terra::rast(f_grid_pu)
grid_bo  <- terra::rast(f_grid_bo)

lc_r     <- terra::rast(f_lc)
dem_r    <- terra::rast(f_dem)
slope_r  <- terra::rast(f_slope)
aspect_r <- terra::rast(f_aspect)

unit_fp  <- read_layer(f_unit_fp)                     # 04 per-unit ghm + housing

stopifnot("unit_id" %in% names(units_sf))
if (!"spans_gradient" %in% names(units_sf)) {
  warning("spans_gradient not on units layer — carrying NA; check Decision 17 build")
  units_sf$spans_gradient <- NA
}
if (any(!sf::st_is_valid(units_sf))) units_sf <- sf::st_make_valid(units_sf)

# Aspect -> northness / eastness (circular decomposition; degrees -> radians)
asp_rad   <- aspect_r * pi / 180
north_r   <- cos(asp_rad); names(north_r) <- "aspect_north"
east_r    <- sin(asp_rad); names(east_r)  <- "aspect_east"

# =============================================================================
# 2. Helper — land-cover class fractions
# =============================================================================
# For a set of polygons (units) OR a target grid, return the coverage-weighted
# fraction of each WorldCover class.

# 2a. Units: exact_extract with a per-class fraction summary.
lc_fractions_units <- function(polys_sf) {
  # exact_extract returns, per polygon, the covered cells + coverage weights.
  # Compute each class's coverage-weighted share. Robust to classes absent in AOI.
  ee <- exactextractr::exact_extract(lc_r, polys_sf, progress = FALSE)
  frac_mat <- vapply(ee, function(df) {
    if (nrow(df) == 0 || all(is.na(df$value))) return(setNames(rep(NA_real_, length(WC_CLASSES)), names(WC_CLASSES)))
    ok <- !is.na(df$value)
    w  <- df$coverage_fraction[ok]
    v  <- df$value[ok]
    tot <- sum(w)
    sapply(WC_CLASSES, function(code) if (tot > 0) sum(w[v == code]) / tot else NA_real_)
  }, numeric(length(WC_CLASSES)))
  out <- as.data.frame(t(frac_mat))
  names(out) <- paste0("lc_frac_", names(WC_CLASSES))
  out
}

# 2b. Grid: build one fractional-cover raster per class by aggregating a binary
# class mask from the fine LC grid to the target cell, weighted by area.
lc_fractions_grid <- function(grid_r, tag) {
  # For each class: mask == class -> 1/0 fine raster, resample (average) to grid.
  # `terra::resample(method="average")` over a 0/1 layer gives the covered
  # fraction per target cell — the coverage-weighted class fraction.
  frac_layers <- lapply(names(WC_CLASSES), function(cl) {
    code <- WC_CLASSES[[cl]]
    m <- terra::ifel(lc_r == code, 1, 0)
    fr <- terra::resample(m, grid_r, method = "average")
    fr <- terra::mask(fr, grid_r)
    names(fr) <- paste0("lc_frac_", cl)
    fr
  })
  fr_stack <- terra::rast(frac_layers)
  out <- file.path(PATH$interim, sprintf("cov_lcfrac_%s_3310.tif", tag))
  terra::writeRaster(fr_stack, out, overwrite = TRUE)
  message("Wrote ", out)
  fr_stack
}

# =============================================================================
# 3. UNIT summaries (occupancy frame)
# =============================================================================
message("\n== Summarising covariates to CPAD units ==")

# 3a. Terrain: area-weighted mean + SD (continuous). Aspect via north/east.
units_sf$elev_mean    <- exactextractr::exact_extract(dem_r,   units_sf, "mean")
units_sf$elev_sd      <- exactextractr::exact_extract(dem_r,   units_sf, "stdev")
units_sf$slope_mean   <- exactextractr::exact_extract(slope_r, units_sf, "mean")
units_sf$slope_sd     <- exactextractr::exact_extract(slope_r, units_sf, "stdev")
units_sf$aspect_north <- exactextractr::exact_extract(north_r, units_sf, "mean")
units_sf$aspect_east  <- exactextractr::exact_extract(east_r,  units_sf, "mean")

# 3b. Land cover: class fractions
lc_u <- lc_fractions_units(units_sf)
units_sf <- dplyr::bind_cols(units_sf, lc_u)

# 3c. Footprint: join from 04 (do NOT recompute)
fp_cols <- c("unit_id", "ghm_mean", "ghm_sd",
             "housing_logden_mean", "housing_logden_sd")
fp_cols <- intersect(fp_cols, names(unit_fp))
units_sf <- units_sf |>
  dplyr::left_join(sf::st_drop_geometry(unit_fp[, fp_cols]), by = "unit_id")

# 3d. Assemble the occupancy unit stack (keep geometry for spatial models)
occu_keep <- c(
  "unit_id", "spans_gradient",
  "elev_mean", "elev_sd", "slope_mean", "slope_sd", "aspect_north", "aspect_east",
  grep("^lc_frac_", names(units_sf), value = TRUE),
  "ghm_mean", "ghm_sd", "housing_logden_mean", "housing_logden_sd"
)
occu_keep <- intersect(occu_keep, names(units_sf))
occu_stack <- units_sf[, occu_keep]

occu_out <- file.path(PATH$interim, "stack_occu_units_3310.gpkg")
write_layer(occu_stack, occu_out)
write.csv(sf::st_drop_geometry(occu_stack),
          file.path(PATH$tables, "stack_occu_units_3310.csv"), row.names = FALSE)
log_stage("stack_occu", "units", nrow(occu_stack))

# Report spans_gradient coverage so the caution flag is auditable
n_flag <- sum(occu_stack$spans_gradient %in% TRUE)
message(sprintf("spans_gradient units carried (means flagged as caution): %d", n_flag))

# =============================================================================
# 4. GRID summaries (per species)
# =============================================================================
# Continuous covariates resample bilinear; land cover via fractional cover.
summarise_grid <- function(grid_r, tag, ghm_path, housing_path, include_housing) {
  message(sprintf("\n== Summarising covariates to %s grid ==", tag))

  # Terrain (continuous -> bilinear)
  elev  <- terra::resample(dem_r,   grid_r, method = "bilinear"); names(elev)  <- "elev_mean"
  slope <- terra::resample(slope_r, grid_r, method = "bilinear"); names(slope) <- "slope_mean"
  north <- terra::resample(north_r, grid_r, method = "bilinear"); names(north) <- "aspect_north"
  east  <- terra::resample(east_r,  grid_r, method = "bilinear"); names(east)  <- "aspect_east"

  # Land cover fractions (coverage-weighted)
  lcfr  <- lc_fractions_grid(grid_r, tag)

  # Footprint (read 04 gridded rasters; already on this grid)
  ghm   <- terra::rast(ghm_path);     names(ghm) <- "ghm"
  layers <- list(elev, slope, north, east, lcfr, ghm)
  if (include_housing) {
    hou <- terra::rast(housing_path); names(hou) <- "housing_logden"
    layers <- c(layers, hou)
  }
  cov_stack <- terra::rast(layers)
  cov_stack <- terra::mask(cov_stack, grid_r)

  # Attach cell_id from the grid template and flatten to a keyed table
  cid <- grid_r; names(cid) <- "cell_id"
  full <- c(cid, cov_stack)
  df <- terra::as.data.frame(full, cells = FALSE, na.rm = TRUE)   # land cells only

  # Write both a keyed table and a polygonised gpkg (cell centroids -> points)
  csv_out <- file.path(PATH$tables, sprintf("stack_%s_3310.csv", tag))
  write.csv(df, csv_out, row.names = FALSE)

  pts <- terra::as.points(full, na.rm = TRUE)
  pts_sf <- sf::st_as_sf(pts)
  gpkg_out <- file.path(PATH$interim, sprintf("stack_%s_3310.gpkg", tag))
  write_layer(pts_sf, gpkg_out)

  log_stage(sprintf("stack_%s", tag), "grid_cells", nrow(df))
  invisible(df)
}

# Puma 1 km — NO housing (Decision 23)
summarise_grid(grid_pu, "puma_grid_1km",
               ghm_path = f_ghm_pu, housing_path = f_hou_pu,
               include_housing = FALSE)

# Bobcat 500 m — includes housing (Decision 23)
summarise_grid(grid_bo, "bobc_grid_500m",
               ghm_path = f_ghm_bo, housing_path = f_hou_bo,
               include_housing = TRUE)

# =============================================================================
# 5. Console summary
# =============================================================================
message("\n================ 05_summarise_covariates.R complete ================")
message("Unit stack  : data/interim/stack_occu_units_3310.gpkg  (keyed unit_id)")
message("Puma grid   : data/interim/stack_puma_grid_1km_3310.gpkg (cell_id, no housing)")
message("Bobcat grid : data/interim/stack_bobc_grid_500m_3310.gpkg (cell_id, incl housing)")
message("Land-cover fraction rasters written per grid (cov_lcfrac_*_3310.tif).")
message("--> Verify class fractions sum ~1 per row; inspect spans_gradient SDs before modelling.")

# puma
g  <- rast("data/interim/grid_puma_1km_3310.tif")
st <- read.csv("outputs/tables/stack_puma_grid_1km_3310.csv")
n_land <- global(!is.na(g), "sum")[[1]]
cat("puma land cells:", n_land, "| stacked:", nrow(st),
    "| dropped:", n_land - nrow(st), "\n")

# which covariate is driving the drops? count NA per layer on the grid
pu <- c(
  rast("data/interim/cov_ghm_puma_1km_3310.tif"),
  rast("data/interim/cov_lcfrac_puma_grid_1km_3310.tif")[[1]]
)
global(is.na(pu) & !is.na(g), "sum")

st <- read.csv("outputs/tables/stack_bobc_grid_500m_3310.csv")
fr <- st[, grep("^lc_frac_", names(st))]
summary(rowSums(fr, na.rm = TRUE))   # want min/median/max all ~1.0

u <- sf::st_read("data/interim/stack_occu_units_3310.gpkg", quiet = TRUE)
big <- u[u$spans_gradient %in% TRUE, ]
summary(big$elev_sd)      # high SD = the whole-unit mean really is hiding a gradient
summary(big$slope_sd)
