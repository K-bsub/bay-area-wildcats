# =============================================================================
# 07_puma_resistance.R
#
# Build resist_puma_baseline_3310.tif on the 1 km grid — puma movement
# resistance surface. Implements Decision 26 (pre-registration) EXACTLY. No
# weights, curves, class values, or AADT bins are changed from the signed-off
# decision; any change requires amending Decision 26 first (no post-hoc tuning).
#
# Assignment (Decision 26):
#   R_land = 0.45*r_ghm + 0.40*r_lc + 0.15*r_slope      (1..100)
#     r_ghm   = 1 + 99 * gHM^2                            (convex)
#     r_lc    = Σ lc_frac_class * resistance_class        (per-class table)
#     r_slope = 1 + 99 * pmin(slope,45)/45                (linear, 45° ceiling)
#   R      = ifelse(barrier_puma cell, pmax(R_land, R_road), R_land)
#     R_road = log-inverse transform of aadt, p1/p99 winsorised, rescaled 1..100
#              (Hansen et al. 2025 for these pumas; Zeller et al. 2016)
#   Aspect EXCLUDED (Decision 26). Housing EXCLUDED (Decision 23).
#   Companion band aadt_conf flags spatial_fill/modelled road cells (audit only).
#
# Inputs (EPSG:3310):
#   data/interim/grid_puma_1km_3310.tif            (1 km template, cell_id land mask)
#   data/interim/stack_puma_grid_1km_3310.gpkg     (cell_id, ghm, elev_mean, slope_mean, lc_frac_*)
#   data/interim/cov_roads_traffic_3310.gpkg       (barrier_puma, aadt, aadt_source)
#
# Outputs (EPSG:3310):
#   outputs/rasters/resist_puma_baseline_3310.tif  (1 km, Float32, 1..100)
#   outputs/rasters/resist_puma_aadt_conf_3310.tif (companion: 1=station-traceable, 0=modelled/spatial)
#   outputs/tables/tbl_07_resistance_summary.csv
#   outputs/figures/fig_07_resist_puma_baseline.png
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

library(sf)
library(terra)
library(tidyverse)

# -----------------------------------------------------------------------------
# 0. Pre-registered constants (Decision 26 — DO NOT tune post-hoc)
# -----------------------------------------------------------------------------
W_GHM   <- 0.45
W_LC    <- 0.40
W_SLOPE <- 0.15
stopifnot(abs(W_GHM + W_LC + W_SLOPE - 1) < 1e-9)

# Land-cover per-class resistance (Decision 26 table). Names match lc_frac_* cols.
LC_RESIST <- c(tree = 5, shrub = 10, grass = 25, wetland = 40,
               crop = 55, bare = 60, water = 90, built = 95)

# AADT -> R_road: log-inverse transform (Decision 26, matching Hansen et al. 2025
# for these exact Santa Cruz pumas + Zeller et al. 2016). Log compresses the
# high-traffic tail and the Decision-25 spatial_fill upward bias. Scale set by
# p1/p99 of aadt over barrier cells (winsorised so one extreme station cannot set
# the range). Returns 1..100.
aadt_to_rroad <- function(aadt, a_min, a_max) {
  x  <- log1p(pmin(pmax(aadt, a_min), a_max))
  lo <- log1p(a_min); hi <- log1p(a_max)
  1 + 99 * (x - lo) / (hi - lo)
}

# -----------------------------------------------------------------------------
# 1. Load
# -----------------------------------------------------------------------------
f_grid    <- file.path(PATH$interim, "grid_puma_1km_3310.tif")
f_stack   <- file.path(PATH$interim, "stack_puma_grid_1km_3310.gpkg")
f_traffic <- file.path(PATH$interim, "cov_roads_traffic_3310.gpkg")
stopifnot(file.exists(f_grid), file.exists(f_stack), file.exists(f_traffic))

grid_r    <- terra::rast(f_grid)
stack_sf  <- read_layer(f_stack)                 # points, one per land cell
traffic_sf<- read_layer(f_traffic)               # major road lines

need_cols <- c("ghm", "slope_mean",
               paste0("lc_frac_", names(LC_RESIST)))
miss <- setdiff(need_cols, names(stack_sf))
if (length(miss)) stop("stack missing columns: ", paste(miss, collapse = ", "),
                       call. = FALSE)
stopifnot(all(c("barrier_puma","aadt","aadt_source") %in% names(traffic_sf)))

# -----------------------------------------------------------------------------
# 2. Landscape resistance R_land (per Decision 26)
# -----------------------------------------------------------------------------
d <- sf::st_drop_geometry(stack_sf)

# r_ghm — convex
r_ghm <- 1 + 99 * (d$ghm ^ 2)

# r_lc — fraction-weighted per-class resistance
lc_cols <- paste0("lc_frac_", names(LC_RESIST))
lc_mat  <- as.matrix(d[, lc_cols])
lc_mat[is.na(lc_mat)] <- 0
r_lc <- as.numeric(lc_mat %*% LC_RESIST[names(LC_RESIST)])
# guard: if fractions do not sum to ~1 (edge cells), normalise by coverage
cov_sum <- rowSums(lc_mat)
r_lc <- ifelse(cov_sum > 0, r_lc / cov_sum, NA_real_)

# r_slope — linear to 45° ceiling
r_slope <- 1 + 99 * pmin(d$slope_mean, 45) / 45

R_land <- W_GHM * r_ghm + W_LC * r_lc + W_SLOPE * r_slope

# Rasterize R_land onto the grid via cell_id -> geometry
stack_sf$R_land <- R_land
# Guard: terra::vect fails if attribute rows != geometry rows. Drop empty/NA
# geometries and any all-NA R_land rows before coercion.
stack_sf <- stack_sf[!sf::st_is_empty(stack_sf) & !is.na(stack_sf$R_land), ]
stack_sf <- sf::st_cast(stack_sf, "POINT", warn = FALSE)   # ensure single-part
Rland_r <- terra::rasterize(terra::vect(stack_sf), grid_r, field = "R_land")
Rland_r <- terra::mask(Rland_r, grid_r)

# -----------------------------------------------------------------------------
# 3. Road resistance R_road on barrier_puma cells (per Decision 26)
#    Log-inverse transform; scale set by p1/p99 of aadt over barrier roads so a
#    single extreme station cannot set the range (Decision 26).
# -----------------------------------------------------------------------------
bar <- traffic_sf[traffic_sf$barrier_puma %in% TRUE, ]
# Guard: drop empty geometries so terra::vect does not hit a row-count mismatch.
bar <- bar[!sf::st_is_empty(bar), ]
# Normalise geometry type — script-06 joins can leave GEOMETRYCOLLECTION/mixed
# parts that terra::vect rejects. Keep only (multi)linestring components.
bar <- suppressWarnings(sf::st_collection_extract(bar, "LINESTRING"))
bar <- bar[!sf::st_is_empty(bar), ]
a_min <- as.numeric(stats::quantile(bar$aadt, 0.01, na.rm = TRUE))
a_max <- as.numeric(stats::quantile(bar$aadt, 0.99, na.rm = TRUE))
message(sprintf("AADT log-transform scale: a_min(p1)=%.0f  a_max(p99)=%.0f", a_min, a_max))
bar$r_road <- aadt_to_rroad(bar$aadt, a_min, a_max)
# confidence: station-traceable (measured/name_fill) = 1, else 0 (spatial/modelled)
bar$conf <- ifelse(bar$aadt_source %in% c("measured","name_fill"), 1L, 0L)
# also drop any row with NA r_road (aadt NA) — cannot rasterize an NA field cleanly
bar <- bar[is.finite(bar$r_road), ]

# Rasterize the MAX r_road per cell (a cell crossed by several roads takes the
# worst barrier — consistent with the max() philosophy of Decision 26).
Rroad_r <- terra::rasterize(terra::vect(bar), grid_r, field = "r_road",
                            fun = "max", background = NA)
conf_r  <- terra::rasterize(terra::vect(bar), grid_r, field = "conf",
                            fun = "min", background = NA)   # min = worst-confidence
Rroad_r <- terra::mask(Rroad_r, grid_r)

# -----------------------------------------------------------------------------
# 4. Combine: R = max(R_land, R_road) where a barrier road crosses; else R_land
#    Cellwise max needs a 2-layer stack (terra::max on two separate rasters is
#    NOT cellwise). Where R_road is NA (no barrier road), max() with na.rm keeps
#    R_land. Land cells with neither would be NA but R_land covers all land.
# -----------------------------------------------------------------------------
road_stack <- c(Rland_r, Rroad_r)
names(road_stack) <- c("land", "road")
R <- terra::app(road_stack, fun = function(x) max(x, na.rm = TRUE))
# app returns -Inf if a cell were all-NA; restore to NA then mask to land
R <- terra::ifel(is.infinite(R), NA, R)
R <- terra::clamp(R, lower = 1, upper = 100)
R <- terra::mask(R, grid_r)
names(R) <- "resist_puma"

# aadt_conf companion: 1 where station-traceable road, 0 where modelled/spatial,
# NA where no barrier road. Land cells with no road are left NA (not a road).
conf_out <- terra::mask(conf_r, grid_r)
names(conf_out) <- "aadt_conf"

# -----------------------------------------------------------------------------
# 5. Write outputs
# -----------------------------------------------------------------------------
r_out <- file.path(PATH$rasters, "resist_puma_baseline_3310.tif")
terra::writeRaster(R, r_out, overwrite = TRUE, datatype = "FLT4S")
conf_path <- file.path(PATH$rasters, "resist_puma_aadt_conf_3310.tif")
terra::writeRaster(conf_out, conf_path, overwrite = TRUE, datatype = "INT1U")
message("Wrote ", r_out)
message("Wrote ", conf_path)

# -----------------------------------------------------------------------------
# 6. Summary + figure
# -----------------------------------------------------------------------------
vals <- terra::values(R, na.rm = TRUE)
summ <- data.frame(
  n_cells     = length(vals),
  min         = round(min(vals), 2),
  p25         = round(as.numeric(stats::quantile(vals, 0.25)), 2),
  median      = round(stats::median(vals), 2),
  mean        = round(mean(vals), 2),
  p75         = round(as.numeric(stats::quantile(vals, 0.75)), 2),
  max         = round(max(vals), 2),
  pct_barrier_ge80 = round(100 * mean(vals >= 80), 1),
  n_road_cells     = as.integer(terra::global(!is.na(Rroad_r), "sum", na.rm = TRUE)[[1]])
)
write.csv(summ, file.path(PATH$tables, "tbl_07_resistance_summary.csv"),
          row.names = FALSE)
message("\n== Resistance summary ==")
print(summ, row.names = FALSE)

png(file.path(PATH$figures, "fig_07_resist_puma_baseline.png"),
    width = 1200, height = 1100, res = 150)
terra::plot(R, main = "Puma baseline resistance (1 km, 1-100) — Decision 26",
            col = grDevices::hcl.colors(100, "YlOrRd", rev = FALSE))
dev.off()

message("\n================ 07_puma_resistance.R complete ================")
message("Resistance surface: outputs/rasters/resist_puma_baseline_3310.tif (1 km, 1-100)")
message("--> Next: run the 3 pre-registered sensitivity checks (Decision 26) before corridors.")
