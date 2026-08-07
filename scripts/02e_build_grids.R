# =============================================================================
# 02e_build_grids.R  —  analysis grids: puma 1 km, bobcat 500 m
# =============================================================================
# Project : Wild Cats at the Urban Edge (Bay Area Wildcats)
# Purpose : Build the two per-species analysis grids as aligned rasters over the
#           ten-county study area. Separate grids, never pooled (Decision 3).
#           - puma  : 1 km cell (also honours the >=1 km puma publish floor,
#                     sensitive-data-policy.md §3)
#           - bobcat: 500 m cell, nested so 4 bobcat cells tile 1 puma cell
# Depends : data/interim/boundary_baydissolved_3310.gpkg (Week 2)
# Output  : data/interim/grid_puma_1km_3310.tif
#           data/interim/grid_bobc_500m_3310.tif
# CRS     : EPSG:3310 throughout.
#
# Design decisions baked in:
#   * Origin snapped to ROUND 3310 coordinates (1 km grid on 1000 m multiples;
#     500 m grid shares that origin on 500 m multiples). Keeps cells aligned
#     with any other Albers grid and makes covariate resampling in Week 5 clean
#     (no fractional-cell offset). Costs a few pad cells beyond the boundary.
#   * Full rectangular (snapped) extent retained so the two grids nest exactly;
#     cells OUTSIDE the dissolved boundary are set NA (land-only data, clean
#     aligned geometry). Masking by cropping the extent would break alignment.
#   * The two grids are written separately and never combined.
# =============================================================================

suppressPackageStartupMessages({ library(sf); library(terra) })

bound_path <- "data/interim/boundary_baydissolved_3310.gpkg"
out_puma   <- "data/interim/grid_puma_1km_3310.tif"
out_bobc   <- "data/interim/grid_bobc_500m_3310.tif"

RES_PUMA <- 1000   # m
RES_BOBC <- 500    # m

# ---- 1. Load boundary, confirm CRS ------------------------------------------
bound_sf <- st_read(bound_path, quiet = TRUE)
stopifnot(st_crs(bound_sf)$epsg == 3310)
bound_v  <- vect(bound_sf)

# ---- 2. Snap a shared origin to round 1 km coordinates ----------------------
# Take the boundary bbox, expand OUTWARD to the nearest 1000 m multiple on all
# sides. Using the 1 km multiple as the shared origin guarantees the 500 m grid
# (which also divides 1000) nests exactly inside the 1 km grid.
bb <- as.vector(ext(bound_v))   # xmin, xmax, ymin, ymax

xmin <- floor(bb["xmin"] / RES_PUMA) * RES_PUMA
xmax <- ceiling(bb["xmax"] / RES_PUMA) * RES_PUMA
ymin <- floor(bb["ymin"] / RES_PUMA) * RES_PUMA
ymax <- ceiling(bb["ymax"] / RES_PUMA) * RES_PUMA

snapped_ext <- ext(xmin, xmax, ymin, ymax)

# ---- 3. Build the two grids on that shared snapped extent --------------------
# Same extent + resolutions that both divide 1000 -> guaranteed nesting.
grid_puma_r <- rast(snapped_ext, resolution = RES_PUMA, crs = "EPSG:3310")
grid_bobc_r <- rast(snapped_ext, resolution = RES_BOBC, crs = "EPSG:3310")

# Give each a cell-id value, then mask to the dissolved boundary (outside = NA).
values(grid_puma_r) <- seq_len(ncell(grid_puma_r))
values(grid_bobc_r) <- seq_len(ncell(grid_bobc_r))
names(grid_puma_r) <- "cell_id"
names(grid_bobc_r) <- "cell_id"

grid_puma_r <- mask(grid_puma_r, bound_v)
grid_bobc_r <- mask(grid_bobc_r, bound_v)

# ---- 4. Write ---------------------------------------------------------------
writeRaster(grid_puma_r, out_puma, overwrite = TRUE,
            datatype = "INT4S", NAflag = -2147483648)
writeRaster(grid_bobc_r, out_bobc, overwrite = TRUE,
            datatype = "INT4S", NAflag = -2147483648)

# ---- 5. Alignment check + metadata record -----------------------------------
report <- function(r, label) {
  e <- as.vector(ext(r))
  n_total <- ncell(r)
  n_land  <- global(!is.na(r), "sum")[1, 1]
  cat(sprintf("--- %s ---\n", label))
  cat(sprintf("  CRS        : EPSG:%s\n", crs(r, describe = TRUE)$code))
  cat(sprintf("  Resolution : %g x %g m\n", res(r)[1], res(r)[2]))
  cat(sprintf("  Extent     : x[%g, %g]  y[%g, %g]\n", e["xmin"], e["xmax"], e["ymin"], e["ymax"]))
  cat(sprintf("  Origin     : (%g, %g)\n", e["xmin"], e["ymin"]))
  cat(sprintf("  Dimensions : %d rows x %d cols\n", nrow(r), ncol(r)))
  cat(sprintf("  Cells total: %d  |  land (non-NA): %d  (%.1f%%)\n\n",
              n_total, n_land, 100 * n_land / n_total))
}

cat("=====================================================================\n")
cat("GRID METADATA\n")
cat("=====================================================================\n")
report(grid_puma_r, "PUMA 1 km  (grid_puma_1km_3310)")
report(grid_bobc_r, "BOBCAT 500 m  (grid_bobc_500m_3310)")

# Nesting check: puma origin must equal bobcat origin, and puma res must be an
# integer multiple of bobcat res. If both hold, 4 bobcat cells tile 1 puma cell.
ep <- as.vector(ext(grid_puma_r)); eb <- as.vector(ext(grid_bobc_r))
same_origin <- ep["xmin"] == eb["xmin"] && ep["ymin"] == eb["ymin"]
clean_mult  <- (RES_PUMA %% RES_BOBC) == 0
cat("=====================================================================\n")
cat("NESTING CHECK\n")
cat("=====================================================================\n")
cat(sprintf("  Shared origin           : %s\n", same_origin))
cat(sprintf("  Puma res / bobcat res   : %g (integer multiple: %s)\n",
            RES_PUMA / RES_BOBC, clean_mult))
cat(sprintf("  Bobcat cells per puma   : %g\n", (RES_PUMA / RES_BOBC)^2))
cat(sprintf("  => 500 m nests in 1 km  : %s\n", same_origin && clean_mult))
cat("=====================================================================\n")

# ---- 6. Sensitive-data-policy note ------------------------------------------
cat("\nPUBLISH-FLOOR NOTE (sensitive-data-policy.md §3):\n")
cat("  Puma grid cell = 1 km >= the >=1 km puma publish floor. Puma surfaces\n")
cat("  rendered at this native resolution satisfy the coarsening rule. Bobcat\n")
cat("  grid (500 m) may be published at native resolution per policy (bobcat\n")
cat("  finer resolution permitted); still reviewed before publication.\n")
