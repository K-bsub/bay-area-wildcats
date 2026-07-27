# 01_download_open_data.R
# Download open datasets into data/raw/ and report counts / CRS / fields.
# data/raw/** is gitignored — nothing downloaded here is committed.

# Prerequisites ----------------------------------------------------------------
library(sf)
library(dplyr)
library(tigris)
source("R/00_config.R")   # PATH, CRS_ANALYSIS, STUDY_COUNTIES

# ==============================================================================
# CPAD 2026a — statewide protected areas (Holdings / Units / SuperUnits)
# ==============================================================================

# Data Folder ------------------------------------------------------------------
cpad_dir <- "data/raw/cpad"
dir.create(cpad_dir, recursive = TRUE, showWarnings = FALSE)

# Note CPAD release year
cpad_zip <- file.path(cpad_dir, "cpad_2026a_release.zip")
cpad_url <- "https://data.cnra.ca.gov/dataset/0ae3cd9f-0612-4572-8862-9e9a1c41e659/resource/cadf9163-aa38-44ae-851a-86b35d4c6c0c/download/cpad_2026a_release.zip"

# Download ---------------------------------------------------------------------
# Don't re-download if the file already exists (time optimized)
if (!file.exists(cpad_zip)) {
  options(timeout = 600)                 # default 60s is too short for this file
  download.file(cpad_url, cpad_zip, mode = "wb")   # mode="wb" is required on Windows
}
unzip(cpad_zip, exdir = cpad_dir)

# Basic check ------------------------------------------------------------------
# Report every shapefile: feature count, CRS, fields
cpad_shp <- list.files(
  cpad_dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE
)
for (f in cpad_shp) {
  lyr <- sf::st_read(f, quiet = TRUE)
  cat("\n---", basename(f), "---\n")
  cat("features:", nrow(lyr), "\n")
  cat("CRS:", sf::st_crs(lyr)$input, "| EPSG:", sf::st_crs(lyr)$epsg, "\n")
  cat("fields:", paste(names(lyr), collapse = ", "), "\n")
}

# ==============================================================================
# CCED 2026a — conservation easements (single layer, no Holdings/Units hierarchy)
# ==============================================================================

# Data Folder ------------------------------------------------------------------
cced_dir <- "data/raw/cced"
dir.create(cced_dir, recursive = TRUE, showWarnings = FALSE)

# Note CCED release year
cced_zip <- file.path(cced_dir, "cced_2026a_release.zip")
cced_url <- "https://data.cnra.ca.gov/dataset/31b65732-941d-4af0-9d8c-279fac441fd6/resource/2f0b8636-3901-458d-88e0-3a422e3235e8/download/cced_2026a_release.zip"

# Download ---------------------------------------------------------------------
if (!file.exists(cced_zip)) {
  options(timeout = 600)
  download.file(cced_url, cced_zip, mode = "wb")
}
unzip(cced_zip, exdir = cced_dir)

# Basic check ------------------------------------------------------------------
cced_shp <- list.files(
  cced_dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE
)
for (f in cced_shp) {
  lyr <- sf::st_read(f, quiet = TRUE)
  cat("\n---", basename(f), "---\n")
  cat("features:", nrow(lyr), "\n")
  cat("CRS:", sf::st_crs(lyr)$input, "| EPSG:", sf::st_crs(lyr)$epsg, "\n")
  cat("fields:", paste(names(lyr), collapse = ", "), "\n")
}

# Quantify the residual gap before decision on additional data------------------
cced <- st_read(
  "data/raw/cced/CCED_2026a_Release/CCED_2026a_Release.shp", quiet = TRUE
)

cced |>
  st_drop_geometry() |>
  mutate(holder = tolower(esmthldr)) |>
  summarise(
    n_total          = n(),
    n_rangeland      = sum(grepl("rangeland", holder)),
    n_cdfw           = sum(grepl("fish|wildlife", holder))
  ) |>
  print()

# and the top holders, to see who's actually represented
cced |> st_drop_geometry() |> count(esmthldr, sort = TRUE) |> head(20) |> print()

# ==============================================================================
# Study-area boundary — ten Bay Area counties (TIGER/Line via tigris)
# ==============================================================================
# The clip frame for every other layer. STUDY_COUNTIES comes from R/00_config.R.

options(tigris_use_cache = TRUE)   # cache the download; re-runs won't re-fetch
tigris_year <- 2024                # pin the TIGER/Line vintage for reproducibility

# Data Folder ------------------------------------------------------------------
bound_dir <- "data/interim"
dir.create(bound_dir, recursive = TRUE, showWarnings = FALSE)

# Pull + filter + reproject ----------------------------------------------------
# cb = TRUE  -> cartographic boundary: generalized, clipped to shoreline (land).
# cb = FALSE -> full legal boundaries including bay/ocean water.
ca_counties <- tigris::counties(state = "CA", cb = TRUE, year = tigris_year)

bay_counties <- ca_counties |>
  filter(NAME %in% STUDY_COUNTIES) |>
  st_transform(CRS_ANALYSIS) |>
  select(county = NAME, geoid = GEOID)

# QC: exactly the ten counties — a failure here means a name mismatch between
# STUDY_COUNTIES and TIGER's NAME field (casing / "County" suffix), not a bug.
stopifnot(nrow(bay_counties) == length(STUDY_COUNTIES))
cat("\nCounties matched:", nrow(bay_counties), "of", length(STUDY_COUNTIES), "\n")
print(sort(bay_counties$county))

# Dissolved single-polygon study-area outline (the clip mask)
bay_outline <- st_sf(
  study_area = "SF Bay Area (10 counties)",
  geometry   = st_union(bay_counties)
)

# Save -------------------------------------------------------------------------
st_write(bay_counties, file.path(bound_dir, "boundary_baycounties_3310.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)
st_write(bay_outline, file.path(bound_dir, "boundary_baydissolved_3310.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)

# Basic check ------------------------------------------------------------------
cat("\n--- study-area boundary ---\n")
cat("counties:", nrow(bay_counties), "| CRS EPSG:", st_crs(bay_counties)$epsg, "\n")
cat("study-area area (km^2):",
    round(as.numeric(sum(st_area(bay_outline))) / 1e6), "\n")
