# 01_download_open_data.R
# Download open datasets into data/raw/ and report counts / CRS / fields.
# data/raw/** is gitignored — nothing downloaded here is committed.

# Prerequisites ----------------------------------------------------------------
library(sf)
library(dplyr)
library(tigris)
library(rgbif)
library(rinat)
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

# ==============================================================================
# GBIF occurrences — Puma concolor + Lynx rufus (study-area bbox)
# ==============================================================================
# Citable download via occ_download() -> produces a DOI (occ_search() does not).
# Requires a free GBIF account. Set these in your USER .Renviron (never in the
# repo), then restart R:
#   GBIF_USER=...   GBIF_PWD=...   GBIF_EMAIL=...
# rgbif reads them automatically; credentials never appear in this script.

# Data Folder ------------------------------------------------------------------
gbif_dir <- "data/raw/gbif"
dir.create(gbif_dir, recursive = TRUE, showWarnings = FALSE)
key_file <- file.path(gbif_dir, "gbif_download_key.txt")
doi_file <- file.path(gbif_dir, "gbif_download_doi.txt")

# Taxon keys (resolve from names, don't hard-code integers) --------------------
puma_key <- name_backbone("Puma concolor")$usageKey
bobc_key <- name_backbone("Lynx rufus")$usageKey
stopifnot(!is.null(puma_key), !is.null(bobc_key))
cat("\ntaxonKeys — puma:", puma_key, "| bobcat:", bobc_key, "\n")

# Study-area bbox in WGS84 (GBIF works in lat/lon) -----------------------------
bay_ll <- st_read("data/interim/boundary_baydissolved_3310.gpkg", quiet = TRUE) |>
  st_transform(4326)
bb <- st_bbox(bay_ll)

# Submit the download once; record key + DOI -----------------------------------
# Minimal server-side filtering on purpose: species + bbox + usable coords only.
# basisOfRecord / uncertainty / year are inspected & filtered later (Week 4).
if (!file.exists(key_file)) {
  dl_key <- occ_download(
    pred_in("taxonKey", c(puma_key, bobc_key)),
    pred("hasCoordinate", TRUE),
    pred("hasGeospatialIssue", FALSE),
    pred_gte("decimalLatitude",  bb[["ymin"]]),
    pred_lte("decimalLatitude",  bb[["ymax"]]),
    pred_gte("decimalLongitude", bb[["xmin"]]),
    pred_lte("decimalLongitude", bb[["xmax"]]),
    format = "SIMPLE_CSV"
  )
  occ_download_wait(dl_key)                 # polls until GBIF finishes preparing
  meta <- occ_download_meta(dl_key)
  writeLines(as.character(dl_key), key_file)
  writeLines(c(
    paste("DOI:", meta$doi),
    paste("Key:", meta$key),
    paste("Accessed:", Sys.Date()),
    paste0("Citation: GBIF.org (", Sys.Date(),
           ") GBIF Occurrence Download https://doi.org/", meta$doi)
  ), doi_file)
}

# Fetch (reuses the zip on re-run) + import ------------------------------------
dl_key <- readLines(key_file)[1]
if (!file.exists(file.path(gbif_dir, paste0(dl_key, ".zip")))) {
  occ_download_get(dl_key, path = gbif_dir, overwrite = TRUE)
}
gbif_raw <- occ_download_import(key = dl_key, path = gbif_dir)

cat("\nDOI recorded in", doi_file, "\n")
cat(readLines(doi_file), sep = "\n"); cat("\n")

# Pre-filtering report (species kept separate — Decision 3) --------------------
gbif_raw <- gbif_raw |>
  mutate(sp = case_when(
    speciesKey == puma_key ~ "puma",
    speciesKey == bobc_key ~ "bobc",
    TRUE                   ~ "other"
  ))

cat("\n--- GBIF records by species ---\n")
gbif_raw |> count(sp) |> print()

cat("\n--- basisOfRecord mix ---\n")
gbif_raw |> count(sp, basisOfRecord, sort = TRUE) |> print(n = Inf)

cat("\n--- coordinateUncertaintyInMeters (per species) ---\n")
gbif_raw |>
  group_by(sp) |>
  summarise(
    n            = n(),
    n_uncert_na  = sum(is.na(coordinateUncertaintyInMeters)),
    med_uncert_m = median(coordinateUncertaintyInMeters, na.rm = TRUE),
    p90_uncert_m = quantile(coordinateUncertaintyInMeters, 0.90, na.rm = TRUE),
    .groups = "drop"
  ) |> print()

cat("\n--- year range (per species) ---\n")
gbif_raw |>
  group_by(sp) |>
  summarise(min_yr = min(year, na.rm = TRUE),
            max_yr = max(year, na.rm = TRUE), .groups = "drop") |> print()

# ==============================================================================
# iNaturalist occurrences — research-grade (via rinat); preserve obscured flag
# ==============================================================================
# Heavily overlaps GBIF (§4.2 was ~96-99% iNaturalist). Its purpose here is NOT
# additive data — it is the authoritative source of the obscuring flags and the
# hook for quantifying overlap. GBIF stays primary; dedupe (don't sum) in Week 4.
# Reuses `bb` (study-area bbox in WGS84) computed in the GBIF section above.

# Data Folder ------------------------------------------------------------------
inat_dir  <- "data/raw/inaturalist"
dir.create(inat_dir, recursive = TRUE, showWarnings = FALSE)
inat_file <- file.path(inat_dir, "inat_research_bayarea.rds")

# rinat bounds = c(swlat, swlng, nelat, nelng)
inat_bounds <- c(bb[["ymin"]], bb[["xmin"]], bb[["ymax"]], bb[["xmax"]])

# Download once (iNat API caps at 10,000 records per query) --------------------
if (!file.exists(inat_file)) {
  get_sp <- function(name) {
    obs <- get_inat_obs(taxon_name = name, quality = "research",
                        geo = TRUE, bounds = inat_bounds, maxresults = 10000)
    Sys.sleep(2)                      # be polite to the API between species
    obs
  }
  inat <- list(puma = get_sp("Puma concolor"),
               bobc = get_sp("Lynx rufus"))
  saveRDS(inat, inat_file)
}
inat <- readRDS(inat_file)

# Truncation check: a species at the cap means results were cut off ------------
if (nrow(inat$puma) >= 10000 || nrow(inat$bobc) >= 10000) {
  warning("A species hit the 10,000-record iNat cap — results truncated; ",
          "split the query by year or place_id in Week 4.")
}

# Normalise: drop captive, add species token, preserve obscuring fields --------
tidy_inat <- function(df, sp) {
  df |>
    filter(is.na(captive_cultivated) | tolower(captive_cultivated) != "true") |>
    transmute(
      source           = "inat",
      species          = sp,
      inat_id          = id,
      observed_on      = observed_on,
      latitude, longitude,
      pos_acc_m        = positional_accuracy,
      public_pos_acc_m = public_positional_accuracy,
      geoprivacy,
      taxon_geoprivacy,
      obscured         = tolower(as.character(coordinates_obscured)) == "true"
    )
}
inat_puma <- tidy_inat(inat$puma, "puma")
inat_bobc <- tidy_inat(inat$bobc, "bobc")

# Report -----------------------------------------------------------------------
cat("\n--- iNaturalist research-grade (post captive drop) ---\n")
cat("puma:", nrow(inat_puma), "| obscured:", sum(inat_puma$obscured),
    "(", round(100 * mean(inat_puma$obscured)), "% )\n")
cat("bobc:", nrow(inat_bobc), "| obscured:", sum(inat_bobc$obscured),
    "(", round(100 * mean(inat_bobc$obscured)), "% )\n")

# Obscuring Decomposition ------------------------------------------------------
bind_rows(inat_puma, inat_bobc) |>
  transmute(species,
            taxon_obs = !is.na(taxon_geoprivacy) & tolower(as.character(taxon_geoprivacy)) == "obscured",
            user_obs  = !is.na(geoprivacy)       & tolower(as.character(geoprivacy))       == "obscured") |>
  count(species, taxon_obs, user_obs) |>
  arrange(species, desc(n)) |>
  as.data.frame()

# Species counts ---------------------------------------------------------------
bind_rows(inat_puma, inat_bobc) |>
  filter(!obscured) |>
  group_by(species) |>
  summarise(
    n         = n(),
    n_acc_na  = sum(is.na(pos_acc_m)),
    med_acc_m = median(pos_acc_m, na.rm = TRUE),
    p90_acc_m = quantile(pos_acc_m, 0.90, na.rm = TRUE),
    .groups = "drop"
  ) |> as.data.frame()
