# 01_download_open_data.R
# Download open datasets into data/raw/ and report counts / CRS / fields.
# data/raw/** is gitignored — nothing downloaded here is committed.

# Prerequisites ----------------------------------------------------------------
library(sf)
library(dplyr)
library(tigris)
library(rgbif)
library(rinat)
library(elevatr)
library(osmdata)   # not used for the pull; kept for any surgical follow-up queries

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

# ==============================================================================
# Covariate — land cover (ESA WorldCover 2021 v200; Decision 12, amended)
# ==============================================================================
# 10 m, 11 classes, CC-BY 4.0. Public AWS COGs (no auth) — replaces NLCD, whose
# access broke at every route (see Decision 12). WorldCover has a single
# 'Built-up' class (no developed gradient); the urban-intensity gradient is
# carried by the human-footprint layers (GHM + housing density, §4.4).

wc_dir <- "data/raw/worldcover"
dir.create(wc_dir, recursive = TRUE, showWarnings = FALSE)
lc_out <- "data/interim/cov_landcover_worldcover2021_3310.tif"

if (!file.exists(lc_out)) {
  # Study area (+5 km collar) in WGS84 — WorldCover tiles are EPSG:4326.
  aoi_ll <- st_read("data/interim/boundary_baydissolved_3310.gpkg", quiet = TRUE) |>
    st_buffer(5000) |>
    st_transform(4326)
  aoi_v  <- terra::vect(aoi_ll)

  # 3x3-degree tiles covering the study bbox (named by SW corner). Bay Area is in
  # N36W123; N36W126 catches the Point Reyes sliver west of -123 if produced
  # (mostly ocean, so it may not exist — handled gracefully).
  tiles   <- c("N36W123", "N36W126")
  url_fmt <- paste0("/vsicurl/https://esa-worldcover.s3.eu-central-1.amazonaws.com/",
                    "v200/2021/map/ESA_WorldCover_10m_2021_v200_%s_Map.tif")

  pieces <- lapply(tiles, function(t) {
    r <- tryCatch(terra::rast(sprintf(url_fmt, t)), error = function(e) NULL)
    if (is.null(r)) return(NULL)
    tryCatch(terra::crop(r, aoi_v), error = function(e) NULL)   # windowed COG read
  })
  pieces <- Filter(Negate(is.null), pieces)
  stopifnot(length(pieces) >= 1)

  wc_ll <- if (length(pieces) > 1) do.call(terra::merge, pieces) else pieces[[1]]
  wc_ll <- terra::mask(wc_ll, aoi_v)

  # Reproject to analysis CRS — NEAREST NEIGHBOUR (categorical!) — then save
  dir.create("data/interim", showWarnings = FALSE)
  wc_3310 <- terra::project(wc_ll, paste0("EPSG:", CRS_ANALYSIS), method = "near")
  terra::writeRaster(wc_3310, lc_out, overwrite = TRUE,
                     gdal = c("COMPRESS=DEFLATE", "ZLEVEL=9"))
}

# Basic check ------------------------------------------------------------------
# WorldCover classes: 10 tree, 20 shrub, 30 grass, 40 crop, 50 built-up,
# 60 bare, 70 snow, 80 water, 90 herb.wetland, 95 mangrove, 100 moss/lichen.
lc <- terra::rast(lc_out)
cat("\n--- ESA WorldCover 2021 land cover ---\n")
cat("EPSG:", terra::crs(lc, describe = TRUE)$code,
    "| resolution (m):", paste(round(terra::res(lc)), collapse = " x "), "\n")
print(terra::freq(lc))   # cell counts by class

# ==============================================================================
# Covariate — terrain (elevation, slope, aspect) via elevatr / AWS Terrain Tiles
# ==============================================================================
# NOTE ON PROVENANCE: elevatr::get_elev_raster(src = "aws") returns AWS Terrain
# Tiles (a Terrarium mosaic blending 3DEP, SRTM, etc.), sampled by an integer
# zoom `z` — NOT a native "3DEP 10 m" product. At Bay Area latitude (~37.7 N):
#     z = 12  ->  ~9.5 m/px   (used here; closest to the 10 m target)
#     z = 13  ->  ~4.8 m/px   (finer, ~4x the pixels/tiles)
# Document the source as "AWS Terrain Tiles via elevatr, z=12" in data-sources.md,
# not as "3DEP 10 m". For TRUE 3DEP 1/3 arc-second, a USGS TNM route is needed
# instead (out of scope this week).
#
# 1 m LIDAR: USGS 3DEP QL2 / CA statewide lidar covers much of the Bay Area but
# is very large and unnecessary for landscape-scale covariates. Recorded as a
# known-issue supplement in data-sources.md; NOT downloaded here.
#
# Continuous raster -> bilinear on reproject (contrast: WorldCover was `near`).

# Data Folder ------------------------------------------------------------------
terr_dir <- "data/raw/terrain"
dir.create(terr_dir, recursive = TRUE, showWarnings = FALSE)

dem_out    <- "data/interim/cov_dem_terraintiles_z12_3310.tif"
slope_out  <- "data/interim/cov_slope_deg_terraintiles_z12_3310.tif"
aspect_out <- "data/interim/cov_aspect_deg_terraintiles_z12_3310.tif"

terrain_z <- 12   # ~9.5 m at 37.7 N; pin for reproducibility

if (!file.exists(dem_out)) {
  # AOI with a 5 km collar so slope/aspect at the study-area edge aren't
  # computed from a clipped neighbourhood. elevatr wants an sf/sp object; it
  # fetches tiles covering the AOI bbox in the AOI's own CRS.
  aoi <- st_read("data/interim/boundary_baydissolved_3310.gpkg", quiet = TRUE) |>
    st_buffer(5000)
  
  # Download tiles. clip = "bbox" trims the tile mosaic to the (buffered) AOI
  # extent so we're not carrying full tiles. Comes back in the AOI CRS (3310)
  # already, but resampled from a Web-Mercator source — see reproject note below.
  dem_raw <- elevatr::get_elev_raster(
    locations = aoi,
    z         = terrain_z,
    clip      = "bbox",
    verbose   = FALSE
  )
  dem_raw <- terra::rast(dem_raw)   # elevatr returns a raster::Raster* -> terra
  
  # Reproject to a clean 3310 grid with BILINEAR (continuous elevation).
  # get_elev_raster reprojects internally from Web Mercator, so its grid isn't a
  # tidy 3310 raster; re-doing it here gives a defined, reproducible cell layout.
  dem_3310 <- terra::project(dem_raw, paste0("EPSG:", CRS_ANALYSIS),
                             method = "bilinear")
  
  # Mask to the buffered AOI (crop already implied by clip="bbox")
  aoi_v    <- terra::vect(aoi)
  dem_3310 <- terra::mask(dem_3310, aoi_v)
  names(dem_3310) <- "elevation_m"
  
  terra::writeRaster(dem_3310, dem_out, overwrite = TRUE,
                     gdal = c("COMPRESS=DEFLATE", "ZLEVEL=9"))
  
  # Derive slope + aspect in PROJECTED units (metres) — degrees would be wrong.
  slope_3310  <- terra::terrain(dem_3310, v = "slope",  unit = "degrees")
  aspect_3310 <- terra::terrain(dem_3310, v = "aspect", unit = "degrees")
  
  terra::writeRaster(slope_3310, slope_out, overwrite = TRUE,
                     gdal = c("COMPRESS=DEFLATE", "ZLEVEL=9"))
  terra::writeRaster(aspect_3310, aspect_out, overwrite = TRUE,
                     gdal = c("COMPRESS=DEFLATE", "ZLEVEL=9"))
}

# Basic check ------------------------------------------------------------------
dem    <- terra::rast(dem_out)
slope  <- terra::rast(slope_out)
aspect <- terra::rast(aspect_out)

cat("\n--- terrain (AWS Terrain Tiles via elevatr, z=", terrain_z, ") ---\n", sep = "")
cat("DEM EPSG:", terra::crs(dem, describe = TRUE)$code,
    "| resolution (m):", paste(round(terra::res(dem), 1), collapse = " x "), "\n")

# Sanity ranges: elevation should span roughly sea level to ~1150 m (Mt Hamilton
# ~1330 m / Mt Diablo ~1170 m sit near the study-area edge; buffered AOI may clip
# their peaks). Negative minima of a few metres are normal (bay margins / fill).
dem_rng <- terra::minmax(dem)
cat("elevation min/max (m):", round(dem_rng[1], 1), "/", round(dem_rng[2], 1), "\n")
cat("slope  min/max (deg):",
    paste(round(terra::minmax(slope)[, 1], 1), collapse = " / "), "\n")
cat("aspect min/max (deg):",
    paste(round(terra::minmax(aspect)[, 1], 1), collapse = " / "), "\n")

# Flag implausible elevations early (Terrain-Tile artefacts / bad tiles)
# Bay Area terrestrial bounds, buffered AOI: high point ~1450 m (Hamilton range
# with 5 km collar); slightly negative minima over water/fill are artefacts.
if (dem_rng[1] < -150 || dem_rng[2] > 1500) {
  warning("DEM elevation range outside expected Bay Area bounds — inspect tiles.")
}

# How much of the raster is implausibly low? A handful of cells = artefact; a
# swath = a bad tile or a masking problem over water.
below <- dem < -20
cat("cells < -20 m:", terra::global(below, "sum", na.rm = TRUE)[[1]],
    "of", terra::global(!is.na(dem), "sum", na.rm = TRUE)[[1]], "\n")

# Where are they? If they cluster over the Bay/ocean margin, it's a water
# artefact and harmless for terrestrial covariates.
terra::plot(below)

# ==============================================================================
# Covariate — roads (OSM via Geofabrik) + traffic volume (Caltrans AADT)
# ==============================================================================
# SOURCE CHOICE (Decision 14): Geofabrik NorCal sub-region extract — NOT
# osmdata/Overpass, and NOT the CA-statewide extract.
#   - `fclass` (the road-class field the stub calls for) exists ONLY in
#     Geofabrik's processed extracts; raw OSM/Overpass returns `highway`.
#   - Geofabrik publishes NO current statewide California shapefile (too large;
#     the CA page directs you to sub-regions — the only california-*-free.shp.zip
#     files are stale 2014-2018 snapshots). The ten-county Bay Area sits fully
#     inside the NORCAL sub-region, which does publish a current extract.
#
# REPRODUCIBILITY CAVEAT: Geofabrik has no DOI and "latest" moves. We pin by
# recording the download date + the server Last-Modified stamp (the closest
# analogue to the GBIF DOI). Documented as a known limitation in data-sources.md.
#
# Roads are a VECTOR covariate: clip (not mask), stay in EPSG:3310, no resampling.

# --- Roads: Geofabrik NorCal extract ------------------------------------------
roads_dir <- "data/raw/osm"
dir.create(roads_dir, recursive = TRUE, showWarnings = FALSE)

geofabrik_zip <- file.path(roads_dir, "norcal-latest-free.shp.zip")
geofabrik_url <- paste0("https://download.geofabrik.de/north-america/us/",
                        "california/norcal-latest-free.shp.zip")
stamp_file    <- file.path(roads_dir, "geofabrik_download_stamp.txt")

roads_out <- "data/interim/cov_roads_osm_3310.gpkg"          # all vehicle roads
roads_maj <- "data/interim/cov_roads_osm_major_3310.gpkg"    # major/barrier subset

if (!file.exists(roads_out)) {
  # Download once. Large file (~hundreds of MB); bump timeout as with CPAD/CCED.
  if (!file.exists(geofabrik_zip)) {
    options(timeout = 1800)
    download.file(geofabrik_url, geofabrik_zip, mode = "wb", method = "libcurl")
  }
  
  # Guard: a real extract is hundreds of MB and starts with the ZIP magic "PK".
  # An HTML error/redirect page is a few KB and starts with "<". Fail loud so we
  # don't limp on to unzip/st_read with a bad file (this is exactly what bit the
  # CA-statewide URL — it silently returned a 9 KB HTML page).
  sz  <- file.info(geofabrik_zip)$size
  sig <- readBin(geofabrik_zip, "raw", n = 2)
  if (sz < 1e6 || !identical(sig, as.raw(c(0x50, 0x4B)))) {  # 0x50 0x4B = "PK"
    file.remove(geofabrik_zip)   # clear the bad file so the guard can't cache it
    stop("Geofabrik download is not a zip (size ", sz, " bytes, sig ",
         paste(sig, collapse = " "), "). Got an HTML page — check the URL.")
  }
  
  # Record a reproducibility stamp: local download date + server Last-Modified.
  server_mtime <- tryCatch({
    h <- curlGetHeaders(geofabrik_url)
    sub("^Last-Modified:\\s*", "", grep("^Last-Modified:", h, value = TRUE,
                                        ignore.case = TRUE)[1])
  }, error = function(e) NA_character_)
  writeLines(c(
    "Source: Geofabrik NorCal sub-region extract (OSM, ODbL)",
    paste("URL:", geofabrik_url),
    paste("Downloaded:", Sys.Date()),
    paste("Server-Last-Modified:", server_mtime)
  ), stamp_file)
  
  unzip(geofabrik_zip, exdir = roads_dir)
  
  # Read the roads layer (Geofabrik name is fixed) and clip to the study area.
  roads_ca <- st_read(file.path(roads_dir, "gis_osm_roads_free_1.shp"),
                      quiet = TRUE) |>
    st_transform(CRS_ANALYSIS)
  
  bay <- st_read("data/interim/boundary_baydissolved_3310.gpkg", quiet = TRUE)
  
  # st_intersection is slow on a sub-regional network; pre-filter by bbox first.
  roads_bay <- roads_ca[st_bbox(bay) |> st_as_sfc() |> st_transform(CRS_ANALYSIS), ] |>
    st_intersection(bay) |>
    select(osm_id, fclass, name, maxspeed)
  
  st_write(roads_bay, roads_out, delete_dsn = TRUE, quiet = TRUE)
  
  # Major / barrier-relevant subset: the vehicle classes that actually function
  # as movement barriers. Excludes footway/cycleway/path/steps/track etc.
  major_fclass <- c("motorway", "motorway_link", "trunk", "trunk_link",
                    "primary", "primary_link", "secondary", "secondary_link")
  
  roads_bay |>
    filter(fclass %in% major_fclass) |>
    st_write(roads_maj, delete_dsn = TRUE, quiet = TRUE)
}

# Basic check ------------------------------------------------------------------
roads <- st_read(roads_out, quiet = TRUE)
cat("\n--- OSM roads (Geofabrik NorCal extract, clipped) ---\n")
cat("features:", nrow(roads), "| CRS EPSG:", st_crs(roads)$epsg, "\n")
cat("fclass field present:", "fclass" %in% names(roads), "\n")
cat("\n--- roads by fclass (top 20) ---\n")
roads |> st_drop_geometry() |> count(fclass, sort = TRUE) |> head(20) |> print()

# Total road length by class (km) — sanity + a covariate preview
roads |>
  mutate(len_km = as.numeric(st_length(roads)) / 1000) |>
  st_drop_geometry() |>
  group_by(fclass) |>
  summarise(n = n(), total_km = round(sum(len_km), 1), .groups = "drop") |>
  arrange(desc(total_km)) |> head(20) |> print()

# --- Traffic volume: Caltrans AADT --------------------------------------------
# Point locations of traffic counts (Annual Average Daily Traffic). This is the
# variable that matters for barrier effects — a quiet tertiary road and a freeway
# are both "roads" but differ by orders of magnitude in traffic. AADT is POINT
# data (count stations, state highway network only); joining AADT to road
# segments is a Week-5 covariate-prep step, not part of this download.
#
# ENDPOINT NOTE: the service is CHhighway/Traffic_AADT on a MapServer (not
# "Traffic_Volumes_AADT", which is only the layer display name, and not a
# FeatureServer). Volumes are stored per LEG as AHEAD_AADT / BACK_AADT, both as
# STRINGS (coerce to numeric in Week 5; expect commas / blanks). 2023 vintage.

aadt_dir <- "data/raw/caltrans"
dir.create(aadt_dir, recursive = TRUE, showWarnings = FALSE)
aadt_out <- "data/interim/cov_aadt_caltrans_points_3310.gpkg"

# ArcGIS REST query -> GeoJSON. Portal: gisdata-caltrans.opendata.arcgis.com
aadt_url <- paste0("https://caltrans-gis.dot.ca.gov/arcgis/rest/services/",
                   "CHhighway/Traffic_AADT/MapServer/0/query",
                   "?where=1%3D1&outFields=*&outSR=4326&f=geojson")

if (!file.exists(aadt_out)) {
  aadt_raw <- tryCatch(
    st_read(aadt_url, quiet = TRUE),
    error = function(e) { message("Caltrans AADT fetch failed: ", e$message); NULL }
  )
  # ArcGIS caps records per request (often 1000/2000). If we got exactly the cap,
  # the pull is truncated — warn so it can be paginated with resultOffset later.
  if (!is.null(aadt_raw)) {
    n <- nrow(aadt_raw)
    if (n %in% c(1000, 2000, 5000)) {
      warning("Caltrans AADT returned exactly ", n, " features — likely the ",
              "server transfer cap (truncated). Paginate with resultOffset ",
              "or add &resultRecordCount=. Statewide AADT should be >5000 points.")
    }
    bay <- st_read("data/interim/boundary_baydissolved_3310.gpkg", quiet = TRUE)
    aadt_bay <- aadt_raw |>
      st_transform(CRS_ANALYSIS) |>
      st_filter(bay)
    st_write(aadt_bay, aadt_out, delete_dsn = TRUE, quiet = TRUE)
  }
}

# Basic check ------------------------------------------------------------------
if (file.exists(aadt_out)) {
  aadt <- st_read(aadt_out, quiet = TRUE)
  cat("\n--- Caltrans AADT (count stations, clipped to study area) ---\n")
  cat("features:", nrow(aadt), "| CRS EPSG:", st_crs(aadt)$epsg, "\n")
  aadt_cols <- grep("aadt", names(aadt), ignore.case = TRUE, value = TRUE)
  cat("AADT columns:", paste(aadt_cols, collapse = ", "), "\n")
  # Preview the ahead-direction volume (string -> numeric just for the sanity range)
  if ("AHEAD_AADT" %in% names(aadt)) {
    ah <- suppressWarnings(as.numeric(gsub(",", "", aadt$AHEAD_AADT)))
    cat("AHEAD_AADT (numeric) — n non-NA:", sum(!is.na(ah)),
        "| median:", round(median(ah, na.rm = TRUE)),
        "| max:", round(max(ah, na.rm = TRUE)), "\n")
  }
} else {
  cat("\n--- Caltrans AADT: NOT acquired (endpoint failed) ---\n")
  cat("Check the service at gisdata-caltrans.opendata.arcgis.com and retry.\n")
}

# ==============================================================================
# Covariate — human modification (gHM v3, 2022; Theobald et al. 2024; Decision 15)
# ==============================================================================
# The continuous 0-1 human-modification gradient. Per Decision 12, gHM + housing
# density (not WorldCover) carry the urban-INTENSITY gradient for the coexistence
# narrative — WorldCover has a single flat "Built-up" class. This layer is
# therefore load-bearing, not context.
#
# SOURCE CHOICE (Decision 15): gHM v3 "all threats combined" (AA), 300 m COG from
# Zenodo — NOT the Kennedy et al. 2019 1 km figshare layer named in the Week-2
# plan, and NOT the Google Earth Engine asset.
#   - The 2019 layer ships as a GEE export / zipped raster (no clean /vsicurl
#     endpoint) and is the older product (median year 2016). The GEE asset needs
#     an Earth Engine account + rgee — an auth dependency this project has avoided
#     (only GBIF is gated). Both fail the "genuinely scriptable, no-auth" bar that
#     WorldCover cleared (Decision 12).
#   - v3 (Theobald et al. 2024) is a public CC-BY COG on Zenodo, DOI-pinned, and
#     more current (2022). 300 m vs the old 1 km is immaterial at the puma 1 km /
#     bobcat 500 m aggregation grids. So we get cleaner acquisition AND a better
#     layer; the only cost is a citation swap (Kennedy 2019 -> Theobald 2024).
#
# ACQUISITION: the AA GeoTIFF is 9.3 GB GLOBAL. Do NOT download it. It is a COG,
# so read it windowed via /vsicurl, crop to the buffered AOI, then pull only that
# window (a few MB of range reads). Same pattern as WorldCover. A guarded, LOUD
# full-download fallback exists only if Zenodo refuses range requests.
#
# Continuous raster -> BILINEAR on reproject (contrast: WorldCover was `near`).

# Data Folder ------------------------------------------------------------------
ghm_dir <- "data/raw/ghm"
dir.create(ghm_dir, recursive = TRUE, showWarnings = FALSE)
ghm_out    <- "data/interim/cov_ghm_v3_2022_3310.tif"
ghm_stamp  <- file.path(ghm_dir, "ghm_source_stamp.txt")

# v3 2022 "all threats combined" (AA), 300 m COG, EPSG:4326, CC-BY 4.0.
# DOI 10.5281/zenodo.14502573. Note the real filename is HMv20240801_ (the record
# description's "HMv2024080101_" is a typo — use the name from the file listing).
ghm_file <- "HMv20240801_2022s_AA_300.tif"
ghm_base <- paste0("https://zenodo.org/records/14502573/files/", ghm_file)
# /vsicurl is happiest without the ?download=1 query string; keep a plain-URL
# primary and the ?download=1 form as a fallback for the windowed read.
ghm_vsi_primary <- paste0("/vsicurl/", ghm_base)
ghm_vsi_dl      <- paste0("/vsicurl/", ghm_base, "?download=1")

if (!file.exists(ghm_out)) {
  # Study area (+5 km collar) in the COG's own CRS (EPSG:4326) for a windowed read.
  aoi_ll <- st_read("data/interim/boundary_baydissolved_3310.gpkg", quiet = TRUE) |>
    st_buffer(5000) |>
    st_transform(4326)
  aoi_v  <- terra::vect(aoi_ll)
  ext_ll <- terra::ext(aoi_v)

  # Windowed COG read: open the remote raster, crop to the AOI window, only then
  # does terra fetch the bytes for that window. Try the plain URL, then ?download=1.
  read_window <- function(vsi) {
    r <- tryCatch(terra::rast(vsi), error = function(e) NULL)
    if (is.null(r)) return(NULL)
    tryCatch(terra::crop(r, ext_ll), error = function(e) NULL)
  }
  ghm_ll <- read_window(ghm_vsi_primary)
  if (is.null(ghm_ll)) ghm_ll <- read_window(ghm_vsi_dl)

  # Guarded fallback: only if BOTH windowed reads failed (Zenodo refused range
  # requests). Download the full 9.3 GB once, then crop locally. Fail LOUD about
  # the size so this is never silent — mirrors the Geofabrik non-zip guard.
  if (is.null(ghm_ll)) {
    warning("gHM windowed /vsicurl read failed (Zenodo may not honour range ",
            "requests). Falling back to a FULL 9.3 GB download — this is large ",
            "and slow. If unintended, interrupt now and re-check the COG URL.")
    ghm_local <- file.path(ghm_dir, ghm_file)
    if (!file.exists(ghm_local)) {
      options(timeout = 7200)                     # 2 h; 9.3 GB over a slow link
      download.file(ghm_base, ghm_local, mode = "wb", method = "libcurl")
    }
    r <- terra::rast(ghm_local)
    ghm_ll <- terra::crop(r, ext_ll)
  }

  ghm_ll <- terra::mask(ghm_ll, aoi_v)

  # Reproject to analysis CRS — BILINEAR (continuous 0-1 metric) — then save.
  ghm_3310 <- terra::project(ghm_ll, paste0("EPSG:", CRS_ANALYSIS),
                             method = "bilinear")
  names(ghm_3310) <- "ghm_2022"
  terra::writeRaster(ghm_3310, ghm_out, overwrite = TRUE,
                     gdal = c("COMPRESS=DEFLATE", "ZLEVEL=9"))

  # Reproducibility stamp (Zenodo IS DOI-pinned, unlike Geofabrik — record it).
  writeLines(c(
    "Source: Global Human Modification v3, 2022 (all threats combined, AA)",
    "Citation: Theobald, D.M., Oakleaf, J.R., Moncrieff, G., Voigt, M.,",
    "  Kiesecker, J., Kennedy, C.M. (2024). Global human modification datasets",
    "  of terrestrial ecosystems for 2022 (v1.0.0). Zenodo.",
    "DOI: 10.5281/zenodo.14502573",
    paste("File:", ghm_file, "(300 m COG, EPSG:4326, CC-BY 4.0)"),
    paste("Accessed:", Sys.Date())
  ), ghm_stamp)
}

# Basic check ------------------------------------------------------------------
ghm <- terra::rast(ghm_out)
cat("\n--- Global Human Modification v3 (2022, AA) ---\n")
cat("EPSG:", terra::crs(ghm, describe = TRUE)$code,
    "| resolution (m):", paste(round(terra::res(ghm)), collapse = " x "), "\n")
ghm_rng <- terra::minmax(ghm)
cat("gHM min/max:", round(ghm_rng[1], 3), "/", round(ghm_rng[2], 3),
    "(expected within 0-1)\n")
# gHM is 0 (unmodified) to 1 (fully modified). Values outside [0,1] mean a bad
# read / wrong band / fill leaking in — flag rather than trust.
if (ghm_rng[1] < -0.001 || ghm_rng[2] > 1.001) {
  warning("gHM values fall outside [0,1] — inspect the source read (fill / band).")
}
cat("mean gHM (study area):",
    round(terra::global(ghm, "mean", na.rm = TRUE)[[1]], 3),
    "| a Bay Area urban-wildland mix should sit well above a wildland-only mean\n")

# ==============================================================================
# Covariate — housing density (SILVIS block-level 1990-2020; Decision 16)
# ==============================================================================
# The second half of the urban-intensity gradient (Decision 12). SILVIS allocates
# decennial-census housing units to 2020 blocks and reports housing DENSITY per
# block for 1990/2000/2010/2020 — density is the covariate we want, pre-computed.
#
# SOURCE CHOICE (Decision 16): SILVIS "Block Level Housing Density Change
# 1990-2020" (PLA v4), California state shapefile extract.
#   - State-level extract = a single direct download, no portal step — matches the
#     CPAD/CCED idiom. HUDEN2020 (units/km^2) is baked in; no census-API join.
#   - CAVEATS this file carries (both flagged, neither blocking):
#     (a) "PLA" = Public-Land-Adjusted: houses are moved OUT of protected areas
#         into neighbouring private blocks. So housing density INSIDE CPAD units
#         is near-zero by construction. For a coexistence covariate that reads as
#         "pressure at the edge, not phantom houses inside open space" — arguably
#         correct, but it must be understood when sampling density AT sites.
#     (b) This product has NO WUI intermix/interface flags — those live in a
#         SEPARATE SILVIS "WUI 1990-2020" product (WUIFLAG* fields). If the
#         interface classification is ever wanted, that's a distinct future pull.
#   - Native CRS is NAD83 / CONUS Albers (EPSG:5070) — reproject to 3310 like
#     everything else. It's a POLYGON layer: clip (not mask), no resampling.
#     Rasterising HUDEN2020 to a covariate grid is a Week-5 step, not a download.

# Data Folder ------------------------------------------------------------------
silvis_dir <- "data/raw/silvis"
dir.create(silvis_dir, recursive = TRUE, showWarnings = FALSE)

silvis_zip <- file.path(silvis_dir, "CA_block20_change_1990_2020_PLA4_shp.zip")
silvis_url <- paste0("https://geoserver.silvis.forest.wisc.edu/geodata/",
                     "block-change-2020/zip/shp/",
                     "CA_block20_change_1990_2020_PLA4_shp.zip")
silvis_out <- "data/interim/cov_housing_silvis_blocks_3310.gpkg"

if (!file.exists(silvis_out)) {
  # Download once (state file is large-ish; bump timeout as with CPAD/CCED).
  if (!file.exists(silvis_zip)) {
    options(timeout = 1800)
    download.file(silvis_url, silvis_zip, mode = "wb", method = "libcurl")
  }

  # Same PK-magic + size guard as Geofabrik: a real shapefile zip is many MB and
  # starts with "PK"; an HTML error page is small and starts with "<". Fail loud.
  sz  <- file.info(silvis_zip)$size
  sig <- readBin(silvis_zip, "raw", n = 2)
  if (sz < 1e5 || !identical(sig, as.raw(c(0x50, 0x4B)))) {   # 0x50 0x4B = "PK"
    file.remove(silvis_zip)
    stop("SILVIS download is not a zip (size ", sz, " bytes). Check the URL.")
  }

  unzip(silvis_zip, exdir = silvis_dir)

  # Find the shapefile (name is fixed, but locate it rather than hard-code a path).
  silvis_shp <- list.files(silvis_dir, pattern = "\\.shp$",
                           recursive = TRUE, full.names = TRUE)[1]
  stopifnot(!is.na(silvis_shp))

  # Read, reproject to 3310, clip to the study area, keep only the fields we use.
  # Density fields are the covariate; HU/POP counts kept for optional change/QC.
  silvis_ca <- st_read(silvis_shp, quiet = TRUE) |>
    st_transform(CRS_ANALYSIS)

  bay <- st_read("data/interim/boundary_baydissolved_3310.gpkg", quiet = TRUE)

  # Bbox pre-filter then clip (same two-step as roads — intersection on a full
  # state block layer is slow otherwise).
  silvis_bay <- silvis_ca[st_bbox(bay) |> st_as_sfc() |> st_transform(CRS_ANALYSIS), ] |>
    st_intersection(bay) |>
    select(blk20 = BLK20,
           huden_1990 = HUDEN1990, huden_2000 = HUDEN2000,
           huden_2010 = HUDEN2010, huden_2020 = HUDEN2020,
           hu_2020 = HU2020, pop_2020 = POP2020, popden_2020 = POPDEN2020,
           pubflag = PUBFLAG, water20 = WATER20)

  st_write(silvis_bay, silvis_out, delete_dsn = TRUE, quiet = TRUE)
}

# Basic check ------------------------------------------------------------------
silvis <- st_read(silvis_out, quiet = TRUE)
cat("\n--- SILVIS block-level housing density (clipped) ---\n")
cat("blocks:", nrow(silvis), "| CRS EPSG:", st_crs(silvis)$epsg, "\n")
cat("HUDEN2020 present:", "huden_2020" %in% names(silvis), "\n")

# Density summary (units / km^2). Bay Area blocks should span rural ~0 to dense
# urban in the thousands. The PLA adjustment pushes protected-area blocks to ~0.
huden <- silvis$huden_2020
cat("HUDEN2020 (units/km^2) — n:", length(huden),
    "| median:", round(median(huden, na.rm = TRUE), 1),
    "| p90:", round(quantile(huden, 0.90, na.rm = TRUE), 1),
    "| max:", round(max(huden, na.rm = TRUE)), "\n")

# PLA sanity: public-land blocks should be near-zero density by construction.
cat("\n--- PLA check: density on public vs private land ---\n")
silvis |>
  st_drop_geometry() |>
  group_by(pubflag) |>
  summarise(n = n(),
            med_huden_2020 = round(median(huden_2020, na.rm = TRUE), 1),
            .groups = "drop") |>
  print()
