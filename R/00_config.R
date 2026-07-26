# =============================================================================
# 00_config.R
# Project-wide constants. Sourced by every script. No side effects beyond
# defining objects and creating directories.
# =============================================================================

# ---- Coordinate reference systems -------------------------------------------
CRS_ANALYSIS <- 3310    # NAD83 / California Albers - all analysis
CRS_WEB      <- 4326    # WGS84 - export only, never analysis

# ---- Study area --------------------------------------------------------------
STUDY_COUNTIES <- c(
  "Alameda", "Contra Costa", "Marin", "Napa", "San Francisco",
  "San Mateo", "Santa Clara", "Santa Cruz", "Solano", "Sonoma"
)

STUDY_STATE_FIPS <- "06"

# ---- Species -----------------------------------------------------------------
SPECIES <- list(
  puma = list(
    code            = "puma",
    scientific_name = "Puma concolor",
    common_name     = "Puma",
    grid_res_m      = 1000,   # coarse - very large home range, sparse + sensitive data
    sensitive       = TRUE
  ),
  bobc = list(
    code            = "bobc",
    scientific_name = "Lynx rufus",
    common_name     = "Bobcat",
    grid_res_m      = 500,    # finer - small home range, abundant data
    sensitive       = FALSE
  )
)

# ---- Minimum publishable resolution for sensitive species --------------------
# See docs/sensitive-data-policy.md section 3. Any published puma surface must
# be at or coarser than this cell size.
MIN_PUBLISH_RES_SENSITIVE_M <- 1000

# ---- Paths -------------------------------------------------------------------
PATH <- list(
  raw        = file.path("data", "raw"),
  interim    = file.path("data", "interim"),
  processed  = file.path("data", "processed"),
  restricted = file.path("data", "restricted"),
  figures    = file.path("outputs", "figures"),
  tables     = file.path("outputs", "tables"),
  rasters    = file.path("outputs", "rasters"),
  models     = file.path("outputs", "models"),
  site_data  = file.path("site", "data")
)

invisible(lapply(PATH, dir.create, recursive = TRUE, showWarnings = FALSE))

# ---- Helper: build a conventional data filename ------------------------------
# Enforces docs/naming-conventions.md section 2.
#   build_path("processed", "occ", "bobc_gbif_clean", "gpkg")
#   -> "data/processed/occ_bobc_gbif_clean_3310.gpkg"
build_path <- function(where, theme, subject, ext, crs = CRS_ANALYSIS) {
  stopifnot(where %in% names(PATH))
  file.path(PATH[[where]], sprintf("%s_%s_%d.%s", theme, subject, crs, ext))
}
