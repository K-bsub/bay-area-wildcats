# =============================================================================
# 00_functions_spatial.R
# Spatial helpers shared across the pipeline.
# =============================================================================

#' Reproject any sf object to the analysis CRS
to_analysis_crs <- function(x) sf::st_transform(x, CRS_ANALYSIS)

#' Build a regular analysis grid over an area of interest
#'
#' @param aoi_sf sf polygon defining the study area
#' @param res_m  cell size in metres
#' @return sf polygon grid with a `cell_id` column
make_grid <- function(aoi_sf, res_m) {
  g <- sf::st_make_grid(aoi_sf, cellsize = res_m, square = TRUE)
  g <- sf::st_sf(cell_id = seq_along(g), geometry = g)
  g[sf::st_intersects(g, sf::st_union(aoi_sf), sparse = FALSE)[, 1], ]
}

#' Guard against publishing a sensitive-species surface at too fine a resolution
#'
#' Call before any export of a puma-derived raster. See
#' docs/sensitive-data-policy.md section 3.
assert_publishable <- function(r, sensitive = TRUE) {
  if (!sensitive) return(invisible(TRUE))
  res_m <- min(terra::res(r))
  if (res_m < MIN_PUBLISH_RES_SENSITIVE_M) {
    stop("Refusing to export sensitive-species surface at ", res_m,
         " m resolution. Minimum is ", MIN_PUBLISH_RES_SENSITIVE_M,
         " m. See docs/sensitive-data-policy.md.", call. = FALSE)
  }
  invisible(TRUE)
}
