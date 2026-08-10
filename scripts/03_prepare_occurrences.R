# =============================================================================
# 03_prepare_occurrences.R
# Week 4 — occurrence prep: schema inspection, GBIF<->iNat overlap (identity
#   dedupe), clean/clip to study area, write per-species layers, log counts.
# Sections 1-3: inspect + quantify overlap (no writes).
# Section 4:    clean + dedupe + clip + write occ_{puma,bobc}_clean_3310.gpkg.
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(tibble)
  library(stringr)
  library(purrr)
})

# ---- paths ------------------------------------------------------------------
gbif_zip <- list.files("data/raw/gbif", pattern = "\\.zip$", full.names = TRUE)
inat_rds <- "data/raw/inaturalist/inat_research_bayarea.rds"

stopifnot(length(gbif_zip) == 1, file.exists(gbif_zip), file.exists(inat_rds))

iNAT_GBIF_DATASET_KEY <- "50c9509d-22c7-4a22-a47d-8c48425ef4a7"  # iNat RG on GBIF

rule <- function(txt) cat("\n", strrep("=", 78), "\n", txt, "\n",
                          strrep("=", 78), "\n", sep = "")

# Treat "" and whitespace as NA everywhere (rinat uses "" for "not obscured").
blank_to_na <- function(x) {
  x <- as.character(x)
  x[trimws(x) == ""] <- NA_character_
  x
}

# =============================================================================
# 1. LOAD GBIF   (SIMPLE_CSV: one tab-delimited file, named after the download key)
# =============================================================================
rule("GBIF — load")

gbif_tmp <- tempfile(fileext = "_gbif")
dir.create(gbif_tmp)
utils::unzip(gbif_zip, exdir = gbif_tmp)

gbif_inner <- list.files(gbif_tmp, pattern = "\\.(csv|txt)$",
                         recursive = TRUE, full.names = TRUE)
cat("files unzipped:", paste(basename(gbif_inner), collapse = ", "), "\n")
stopifnot(length(gbif_inner) >= 1)
gbif_file <- gbif_inner[which.max(file.info(gbif_inner)$size)]
cat("using data file:", basename(gbif_file), "\n")

gbif_raw <- read_tsv(
  gbif_file,
  col_types = cols(.default = col_character()),
  quote = "",
  progress = FALSE
)
cat("GBIF rows:", nrow(gbif_raw), " cols:", ncol(gbif_raw), "\n")

rule("GBIF — all column names")
print(names(gbif_raw))

gbif_fields_of_interest <- c(
  "gbifID", "occurrenceID", "catalogNumber", "institutionCode",
  "datasetKey", "basisOfRecord",
  "species", "speciesKey", "taxonKey",
  "decimalLatitude", "decimalLongitude",
  "coordinateUncertaintyInMeters", "coordinatePrecision",
  "eventDate", "year", "month", "day",
  "issue", "countryCode", "stateProvince", "license"
)
rule("GBIF — fields of interest: present? + example non-NA value")
walk(gbif_fields_of_interest, function(f) {
  if (f %in% names(gbif_raw)) {
    vals <- blank_to_na(gbif_raw[[f]])
    ex <- vals[!is.na(vals)][1]
    cat(sprintf("  %-32s present   e.g. %s\n", f, substr(ex, 1, 50)))
  } else {
    cat(sprintf("  %-32s MISSING\n", f))
  }
})

rule("GBIF — records by species (raw)")
gbif_raw %>% count(species, sort = TRUE) %>% print(n = 20)

# ---- origin: iNaturalist vs other -------------------------------------------
rule("GBIF — origin: iNaturalist vs other")
gbif_raw <- gbif_raw %>%
  mutate(
    from_inat = (datasetKey == iNAT_GBIF_DATASET_KEY) |
      str_detect(coalesce(occurrenceID, ""), "inaturalist\\.org/observations/"),
    inat_obs_id = case_when(
      str_detect(coalesce(occurrenceID, ""), "inaturalist\\.org/observations/") ~
        str_extract(occurrenceID, "(?<=observations/)\\d+"),
      from_inat & str_detect(coalesce(catalogNumber, ""), "^\\d+$") ~ catalogNumber,
      TRUE ~ NA_character_
    )
  )

gbif_raw %>% count(from_inat) %>% print()
cat("GBIF rows with a parseable iNat obs id:",
    sum(!is.na(gbif_raw$inat_obs_id)), "\n")

rule("GBIF — origin x species")
gbif_raw %>% count(species, from_inat) %>% arrange(species) %>% print(n = 40)

# =============================================================================
# 2. LOAD iNAT   (RAW rinat schema — the .rds is untidied get_inat_obs() output)
# =============================================================================
# NOTE: the download script's tidy_inat()/captive-drop was NOT persisted; the
# saved list holds RAW rinat columns. Real fields present:
#   scientific_name, id, latitude, longitude, positional_accuracy,
#   public_positional_accuracy, geoprivacy, taxon_geoprivacy,
#   coordinates_obscured, captive_cultivated, observed_on, ...
rule("iNat — load")

inat_obj <- readRDS(inat_rds)
cat("iNat object class:", paste(class(inat_obj), collapse = ", "), "\n")

if (is.list(inat_obj) && !is.data.frame(inat_obj)) {
  cat("iNat is a named list:", paste(names(inat_obj), collapse = ", "), "\n")
  # Each element is a raw rinat df; tag species from the list name so we never
  # depend on scientific_name parsing for the token.
  inat_tbl <- imap(inat_obj, ~ mutate(as_tibble(.x),
                                      sp_list = .y)) %>% bind_rows()
} else if (inherits(inat_obj, "sf")) {
  inat_tbl <- st_drop_geometry(inat_obj) %>% mutate(sp_list = NA_character_)
} else {
  inat_tbl <- as_tibble(inat_obj) %>% mutate(sp_list = NA_character_)
}
cat("iNat rows (combined):", nrow(inat_tbl), " cols:", ncol(inat_tbl), "\n")

rule("iNat — all column names")
print(names(inat_tbl))

# derive the fields the cleaning step will rely on, from the RAW schema --------
inat_tbl <- inat_tbl %>%
  mutate(
    inat_id          = as.character(id),
    geoprivacy       = blank_to_na(geoprivacy),
    taxon_geoprivacy = blank_to_na(taxon_geoprivacy),
    obscured         = tolower(as.character(coordinates_obscured)) %in% c("true", "t"),
    captive          = tolower(as.character(captive_cultivated)) %in% c("true", "t"),
    sp = case_when(
      !is.na(sp_list) & sp_list %in% c("puma", "bobc") ~ sp_list,
      str_detect(coalesce(scientific_name, ""), regex("puma concolor", ignore_case = TRUE)) ~ "puma",
      str_detect(coalesce(scientific_name, ""), regex("lynx rufus",    ignore_case = TRUE)) ~ "bobc",
      TRUE ~ "other"
    )
  )

inat_fields_of_interest <- c(
  "sp", "inat_id", "observed_on", "latitude", "longitude",
  "positional_accuracy", "public_positional_accuracy",
  "geoprivacy", "taxon_geoprivacy", "obscured", "captive"
)
rule("iNat — fields of interest: present? + example non-NA value")
walk(inat_fields_of_interest, function(f) {
  if (f %in% names(inat_tbl)) {
    vals <- inat_tbl[[f]]
    ex <- vals[!is.na(vals)][1]
    cat(sprintf("  %-26s present   e.g. %s\n", f, substr(as.character(ex), 1, 50)))
  } else {
    cat(sprintf("  %-26s MISSING\n", f))
  }
})

# ---- species breakdown ------------------------------------------------------
rule("iNat — records by species (from list name)")
inat_tbl %>% count(sp, sort = TRUE) %>% print(n = 20)

# ---- captive (never dropped in the saved .rds) ------------------------------
rule("iNat — captive_cultivated (still present; drop in 04_)")
inat_tbl %>% count(sp, captive) %>% arrange(sp) %>% print()

# ---- obscuring breakdown ----------------------------------------------------
# obscured = the effective flag. geoprivacy (user-set) vs taxon_geoprivacy
# (taxon policy) are the drivers. Puma is NOT taxon-obscured in CA (Decision 10),
# so puma obscuring should come from geoprivacy (user), not taxon_geoprivacy.
rule("iNat — obscuring by species (effective flag)")
inat_tbl %>% count(sp, obscured) %>% arrange(sp) %>% print()

rule("iNat — obscuring drivers: geoprivacy x taxon_geoprivacy (NA = not set)")
inat_tbl %>%
  count(sp, geoprivacy, taxon_geoprivacy) %>%
  arrange(sp, desc(n)) %>%
  print(n = 40)

# =============================================================================
# 3. OVERLAP — match on iNat observation identity, NOT coordinates.
# =============================================================================
rule("OVERLAP — GBIF(from iNat) vs iNat .rds, by observation id")

gbif_inat_ids <- gbif_raw$inat_obs_id[!is.na(gbif_raw$inat_obs_id)]
inat_ids      <- inat_tbl$inat_id[!is.na(inat_tbl$inat_id)]

cat("distinct iNat obs ids inside GBIF feed :", n_distinct(gbif_inat_ids), "\n")
cat("distinct iNat obs ids in iNat .rds     :", n_distinct(inat_ids), "\n")

in_both <- intersect(unique(gbif_inat_ids), unique(inat_ids))
cat("id-matched overlap (in BOTH feeds)     :", length(in_both), "\n")
cat("iNat-only (in .rds, not in GBIF feed)  :",
    length(setdiff(unique(inat_ids), unique(gbif_inat_ids))), "\n")
cat("GBIF-iNat ids with no match in .rds     :",
    length(setdiff(unique(gbif_inat_ids), unique(inat_ids))), "\n")

# per-species overlap (the Risk 2 number for puma) ----------------------------
rule("OVERLAP — per species (puma is the Risk 2 figure)")

gbif_sp_norm <- function(x) case_when(
  str_detect(coalesce(x, ""), regex("puma concolor", ignore_case = TRUE)) ~ "puma",
  str_detect(coalesce(x, ""), regex("lynx rufus",    ignore_case = TRUE)) ~ "bobc",
  TRUE ~ "other"
)

gbif_inat_by_sp <- gbif_raw %>%
  filter(!is.na(inat_obs_id)) %>%
  transmute(sp = gbif_sp_norm(species), inat_obs_id, feed = "gbif")

inat_by_sp <- inat_tbl %>%
  filter(!is.na(inat_id)) %>%
  transmute(sp, inat_obs_id = inat_id, feed = "inat")

overlap_by_sp <- bind_rows(gbif_inat_by_sp, inat_by_sp) %>%
  filter(sp %in% c("puma", "bobc")) %>%
  distinct(sp, feed, inat_obs_id) %>%
  group_by(sp, inat_obs_id) %>%
  summarise(n_feeds = n_distinct(feed), .groups = "drop") %>%
  group_by(sp) %>%
  summarise(
    in_both      = sum(n_feeds == 2),
    single_feed  = sum(n_feeds == 1),
    total_unique = n(),
    .groups = "drop"
  )
print(overlap_by_sp)

# Union count across BOTH sources, deduped by identity, per species -----------
# (puma total_unique here previews the Risk 2 denominator BEFORE quality/date
#  filtering. Non-iNat GBIF rows have no inat id — added separately in 04_.)
rule("PREVIEW — non-iNat GBIF rows (genuinely additive; no iNat id)")
gbif_raw %>%
  filter(!from_inat) %>%
  transmute(sp = gbif_sp_norm(species)) %>%
  count(sp) %>% print()

rule("DONE — inspection only. No files written.")
# =============================================================================
# 4. CLEAN + DEDUPE  (writes two per-species layers to data/interim/)
# =============================================================================
# Decision 20: dedupe on OBSERVATION IDENTITY, never coordinates. iNat .rds is
#   master; GBIF contributes only its non-iNat rows. Obscured puma records get
#   randomised coordinates that differ between feeds, so a coordinate dedupe
#   would drop/keep the wrong member of a pair.
# Decision 21: puma obscured records are KEPT in the same layer, distinguished
#   by the `obscured` flag (not blanket-cut). Coarsening happens at publish time
#   per sensitive-data-policy.md §3, not in the raw interim layer.
# No date filter (all years retained). Captive dropped (none present here).

rule("SECTION 4 — clean + dedupe (writes layers)")

dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

boundary_path <- "data/interim/boundary_baydissolved_3310.gpkg"
stopifnot(file.exists(boundary_path))
bay_3310 <- st_read(boundary_path, quiet = TRUE)
if (is.na(st_crs(bay_3310)$epsg) || st_crs(bay_3310)$epsg != CRS_ANALYSIS) {
  bay_3310 <- st_transform(bay_3310, CRS_ANALYSIS)
}

# ---- 4a. iNat master: normalise to the common schema ------------------------
# Keep RAW coordinates as supplied (obscured rows already carry their obscured
# coordinate from iNat). coord_uncert_m uses PUBLIC positional accuracy — for
# obscured rows this reflects the obscuring radius, which is the honest public
# uncertainty. Fall back to positional_accuracy where public is NA.
inat_clean <- inat_tbl %>%
  filter(!captive) %>%
  mutate(
    source        = "inat",
    obs_id        = inat_id,                       # stable identity key
    latitude      = suppressWarnings(as.numeric(latitude)),
    longitude     = suppressWarnings(as.numeric(longitude)),
    coord_uncert_m = suppressWarnings(as.numeric(
      dplyr::coalesce(public_positional_accuracy, positional_accuracy))),
    obscured      = as.logical(obscured),
    observed_on   = as.character(observed_on)
  ) %>%
  filter(sp %in% c("puma", "bobc")) %>%
  transmute(species = sp, source, obs_id,
            observed_on, latitude, longitude,
            coord_uncert_m, obscured,
            geoprivacy, taxon_geoprivacy)

# ---- 4b. GBIF: keep ONLY non-iNat rows (the additive remainder) -------------
# iNat-sourced GBIF rows are a strict subset of the .rds (0 unmatched in §3),
# so they are dropped here to avoid double-counting. GBIF has no obscuring flag;
# treat GBIF-native records as not-obscured but carry their coordinate
# uncertainty so a high-uncertainty record is still visible downstream.
gbif_clean <- gbif_raw %>%
  filter(!from_inat) %>%
  mutate(
    species = gbif_sp_norm(species),
    source  = "gbif",
    obs_id  = paste0("gbif:", gbifID),             # namespaced so it can't collide
    latitude      = suppressWarnings(as.numeric(decimalLatitude)),
    longitude     = suppressWarnings(as.numeric(decimalLongitude)),
    coord_uncert_m = suppressWarnings(as.numeric(coordinateUncertaintyInMeters)),
    obscured      = FALSE,
    observed_on   = as.character(eventDate),
    geoprivacy       = NA_character_,
    taxon_geoprivacy = NA_character_
  ) %>%
  filter(species %in% c("puma", "bobc")) %>%
  transmute(species, source, obs_id,
            observed_on, latitude, longitude,
            coord_uncert_m, obscured,
            geoprivacy, taxon_geoprivacy)

# ---- 4c. union, then guard coordinate validity ------------------------------
occ_all <- bind_rows(inat_clean, gbif_clean)

n_before <- nrow(occ_all)
occ_all <- occ_all %>%
  filter(!is.na(latitude), !is.na(longitude),
         !(latitude == 0 & longitude == 0),
         latitude  > 30, latitude  < 43,      # sane CA bbox in lat/long
         longitude > -125, longitude < -118)
cat("coordinate-validity drop:", n_before - nrow(occ_all),
    "of", n_before, "rows\n")

# Identity dedupe safety net: obs_id is unique by construction (iNat id is
# unique; gbif: namespace can't collide with it), but assert it.
dup_ids <- occ_all %>% count(obs_id) %>% filter(n > 1)
if (nrow(dup_ids) > 0) {
  warning(nrow(dup_ids), " duplicate obs_id values after union — investigate; ",
          "keeping first occurrence of each.")
  occ_all <- occ_all %>% distinct(obs_id, .keep_all = TRUE)
}

# ---- 4d. to sf, project to 3310, clip to study area -------------------------
occ_sf <- st_as_sf(occ_all, coords = c("longitude", "latitude"),
                   crs = 4326, remove = FALSE) %>%
  st_transform(CRS_ANALYSIS)

# spatial clip (st_filter = keep points intersecting the dissolved boundary)
n_pre_clip <- nrow(occ_sf)
occ_sf <- occ_sf[bay_3310, ]
cat("study-area clip drop:", n_pre_clip - nrow(occ_sf),
    "of", n_pre_clip, "rows (outside 10-county boundary)\n")

# ---- 4e. split by species, write ---------------------------------------------
occ_puma_sf <- occ_sf %>% filter(species == "puma")
occ_bobc_sf <- occ_sf %>% filter(species == "bobc")

puma_out <- "data/interim/occ_puma_clean_3310.gpkg"
bobc_out <- "data/interim/occ_bobc_clean_3310.gpkg"

write_layer(occ_puma_sf, puma_out)
write_layer(occ_bobc_sf, bobc_out)

rule("SECTION 4 — cleaned layer summary")
cat("PUMA written:", puma_out, "\n")
occ_puma_sf %>% st_drop_geometry() %>%
  count(source, obscured) %>% arrange(source, obscured) %>% print()
cat("  puma total:", nrow(occ_puma_sf),
    "| precise:", sum(!occ_puma_sf$obscured),
    "| obscured:", sum(occ_puma_sf$obscured), "\n")

cat("\nBOBCAT written:", bobc_out, "\n")
occ_bobc_sf %>% st_drop_geometry() %>%
  count(source, obscured) %>% arrange(source, obscured) %>% print()
cat("  bobc total:", nrow(occ_bobc_sf),
    "| precise:", sum(!occ_bobc_sf$obscured),
    "| obscured:", sum(occ_bobc_sf$obscured), "\n")

# ---- 4e-bis. log record counts (docs/methodology.md discipline) -------------
log_stage("occ_puma", "union_raw",   nrow(filter(inat_clean, species == "puma")) +
            nrow(filter(gbif_clean, species == "puma")))
log_stage("occ_puma", "clipped",     nrow(occ_puma_sf))
log_stage("occ_puma", "precise",     sum(!occ_puma_sf$obscured))
log_stage("occ_puma", "obscured",    sum(occ_puma_sf$obscured))

log_stage("occ_bobc", "union_raw",   nrow(filter(inat_clean, species == "bobc")) +
            nrow(filter(gbif_clean, species == "bobc")))
log_stage("occ_bobc", "clipped",     nrow(occ_bobc_sf))
log_stage("occ_bobc", "precise",     sum(!occ_bobc_sf$obscured))
log_stage("occ_bobc", "obscured",    sum(occ_bobc_sf$obscured))

# ---- 4f. Risk 1 preview — bobcat records per occupancy site ------------------
# The Risk 1 gate needs the count of DISTINCT bobcat detection sites. Preview it
# two ways (do NOT design the gate here): (i) distinct 500 m grid cells with >=1
# bobcat record, (ii) distinct CPAD units with >=1 bobcat record. These are the
# candidate "site" definitions; the gate criterion is <40 site histories.
rule("SECTION 4f — Risk 1 PREVIEW (bobcat sites; gate designed next step)")

grid_bobc_path <- "data/interim/grid_bobc_500m_3310.tif"
openspace_path <- "data/interim/openspace_cpad_bayarea_3310.gpkg"

if (file.exists(grid_bobc_path)) {
  suppressPackageStartupMessages(library(terra))
  g <- terra::rast(grid_bobc_path)
  cells <- terra::cellFromXY(g, st_coordinates(occ_bobc_sf))
  n_cells <- dplyr::n_distinct(cells[!is.na(cells)])
  cat("distinct 500 m grid cells with >=1 bobcat record:", n_cells, "\n")
  cat("  (bobcat records landing on a land cell:",
      sum(!is.na(cells)), "of", nrow(occ_bobc_sf), ")\n")
}

if (file.exists(openspace_path)) {
  units_sf <- st_read(openspace_path, quiet = TRUE)
  if (st_crs(units_sf)$epsg != CRS_ANALYSIS) units_sf <- st_transform(units_sf, CRS_ANALYSIS)
  hit <- lengths(st_intersects(units_sf, occ_bobc_sf))
  cat("CPAD units with >=1 bobcat record:", sum(hit > 0),
      "of", nrow(units_sf), "\n")
  cat("  bobcat records falling inside any CPAD unit:",
      sum(lengths(st_intersects(occ_bobc_sf, units_sf)) > 0),
      "of", nrow(occ_bobc_sf), "\n")
}

rule("SECTION 4 — DONE (2 layers written; Risk 1 gate is the next step)")