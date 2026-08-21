# =============================================================================
# 03b_bobcat_background_effort.R
# Week 4 — Fork 3: target-group BACKGROUND EFFORT for the bobcat occupancy
# detection history, via a GBIF async download.
#
# Replaces an earlier rinat month-tiling approach that fought the iNat 10k-record
# cap (City Nature Challenge months capped even at week level). GBIF has no cap
# and filters server-side.
#
# Scope (Fork 3, resolved): ALL GBIF datasets (broad effort proxy), vertebrate
# classes, dissolved 10-county study boundary, 2010-2026, bobcat excluded.
# Footprint = dissolved boundary WKT (not the full bbox, which pulled 42.8M
# ocean + Central Valley records).
#
# Effort = per CPAD unit x year "was any non-bobcat vertebrate recorded here?"
# = the source of NON-DETECTION 0s for the bobcat occupancy detection history.
# Writes mammal (Fork 3A) and all-vertebrate (Fork 3B) effort layers so the
# A/B choice is made from real volumes without re-downloading. Decision 22
# (draft) depends on this layer to close.
#
# GRADED EFFORT (added Week 7, for the detection sub-model). Each surveyed unit x
# year now carries `eff_nrec` = the COUNT of non-bobcat background records in that
# unit x year, alongside the binary `surveyed = 1L`. `eff_nrec` is the graded
# per-occasion detection-effort proxy the p sub-model needs; the binary `surveyed`
# is kept unchanged so the existing detection-history builder (04d) and null fit
# (04e) are unaffected.
#   CAVEAT (state wherever the eff_nrec coefficient is read): eff_nrec is
#   BACKGROUND vertebrate/mammal observation volume, an observer-intensity PROXY.
#   It is not bobcat survey effort (no camera-nights / survey-hours). More records
#   ~ more observer activity ~ higher chance of detecting a bobcat if present. The
#   raw count is stored; any transform (e.g. log1p) is a Week-7 modelling choice
#   made from the observed distribution, not applied here.
#
# TWO-PART (async):
#   PART A submits the download (records the key), then stops.
#   PART B (after GBIF reports READY) imports leanly + derives effort + writes.
# On a clean re-run, Part A sees the key file and skips to Part B.
#
# Credentials: occ_download() needs GBIF_USER / GBIF_PWD / GBIF_EMAIL in
# .Renviron (same as 01_download_open_data.R). Never hard-code them here.
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

suppressPackageStartupMessages({
  library(sf); library(dplyr); library(tidyr); library(purrr)
  library(stringr); library(rgbif); library(readr); library(lubridate)
})

rule <- function(txt) cat("\n", strrep("=", 78), "\n", txt, "\n",
                          strrep("=", 78), "\n", sep = "")

# ---- parameters -------------------------------------------------------------
YR_MIN <- 2010
YR_MAX <- 2026

raw_dir  <- "data/raw/gbif_background"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
key_file <- file.path(raw_dir, "background_download_key.txt")

mammal_out <- "data/interim/cov_effort_gbif_mammal_unityear_3310.gpkg"
vert_out   <- "data/interim/cov_effort_gbif_vertebrate_unityear_3310.gpkg"

# vertebrate class taxonKeys (for the download predicate) + bobcat speciesKey
CLASS_KEYS <- c(Mammalia = 359, Aves = 212, Reptilia = 358,
                Amphibia = 131, Actinopterygii = 204)
BOBCAT_SPECIESKEY <- 2435246

# vertebrate class NAME strings (SIMPLE_CSV has `class`, not `classKey`)
VERT_CLASSES <- names(CLASS_KEYS)

# =============================================================================
# PART A — SUBMIT the download (dissolved-boundary WKT footprint)
# =============================================================================
# Uses the dissolved 10-county study boundary, simplified to a GBIF-legal vertex
# count, in EPSG:4326 with CCW winding. GBIF pred_within() takes ONE WKT polygon
# with a vertex-count limit — the 1,129 CPAD units cannot be passed directly.
rule("PART A — submit GBIF background download (boundary WKT)")

if (!file.exists(key_file)) {

  # ---- build a GBIF-legal WKT from the dissolved study boundary -------------
  bay_3310 <- read_layer("data/interim/boundary_baydissolved_3310.gpkg")

  # simplify in projected metres (3310) BEFORE transforming to 4326.
  # 300 m tolerance -> a few hundred vertices for the Bay Area outline.
  bay_simp <- bay_3310 %>%
    st_union() %>%
    st_simplify(dTolerance = 300, preserveTopology = TRUE) %>%
    st_transform(4326)

  bay_simp <- st_sfc(bay_simp, crs = 4326)

  # GBIF wants a single POLYGON. If MULTIPOLYGON, keep the largest part.
  if (inherits(st_geometry(bay_simp)[[1]], "MULTIPOLYGON")) {
    parts <- st_cast(bay_simp, "POLYGON")
    areas <- st_area(parts)
    bay_simp <- parts[which.max(areas)]
    cat("boundary was MULTIPOLYGON; kept largest part for WKT\n")
  }

  # GBIF treats a clockwise ring as the polygon's COMPLEMENT (everything
  # outside). st_make_valid + explicit CCW orientation guards against pulling
  # the whole globe minus the Bay Area.
  bay_ccw <- st_sf(geometry = bay_simp) %>%
    st_make_valid() %>%
    st_cast("POLYGON")

  # enforce CCW exterior ring
  bay_ccw <- st_sfc(
    st_polygon(list(st_coordinates(bay_ccw)[, c("X", "Y")])),
    crs = 4326
  )
  if (!isTRUE(sf::st_is_valid(bay_ccw))) bay_ccw <- st_make_valid(bay_ccw)

  wkt_boundary <- st_as_text(bay_ccw[[1]])

  n_vert <- nrow(st_coordinates(bay_ccw))
  cat("WKT vertices:", n_vert,
      if (n_vert > 500) " <-- WARNING: may exceed GBIF limit; raise dTolerance"
      else if (n_vert < 20) " <-- WARNING: over-simplified; lower dTolerance"
      else " (within GBIF limit)", "\n")

  # ---- submit ---------------------------------------------------------------
  dl <- occ_download(
    pred_in("taxonKey", unname(CLASS_KEYS)),          # vertebrate classes
    pred("hasCoordinate", TRUE),
    pred("hasGeospatialIssue", FALSE),
    pred_gte("year", YR_MIN),
    pred_lte("year", YR_MAX),
    pred_within(wkt_boundary),                        # dissolved-boundary footprint
    pred_not(pred("speciesKey", BOBCAT_SPECIESKEY)),  # exclude bobcat
    format = "SIMPLE_CSV"
  )
  writeLines(as.character(dl), key_file)
  cat("submitted. key:", as.character(dl), "\n")
  cat("saved to:", key_file, "\n")
  cat("\n>>> WAIT for GBIF to finish, then run Part B.\n")
  cat(">>> check status: occ_download_wait('", as.character(dl), "')\n", sep = "")

} else {
  cat("download key already exists:", readLines(key_file)[1], "\n")
  cat("delete", key_file, "to re-submit; otherwise run Part B.\n")
}

# =============================================================================
# PART B — IMPORT (lean) + derive effort + write  (run after download READY)
# =============================================================================
rule("PART B — wait, lean import, derive unit x year effort")

dl_key <- readLines(key_file)[1]

# blocks until ready (returns immediately if already done), then fetches
occ_download_wait(dl_key)
z <- occ_download_get(dl_key, path = raw_dir, overwrite = TRUE)

# record the DOI for data-sources.md
dl_doi <- tryCatch(occ_download_meta(dl_key)$doi, error = function(e) NA_character_)
cat("DOI (log in data-sources.md):", dl_doi %||% "see GBIF portal", "\n")

# ---- lean import: only the columns we need, from the zip on disk -----------
# SIMPLE_CSV is a single tab-delimited file; it has `class` (name string) and
# `speciesKey`, but NO `classKey`. Reading all 50 cols on a multi-million-row
# download is wasteful — select 5 columns and filter to vertebrates + window.
rule("PART B — lean import (5 cols) + classify by `class` string")

zip_path <- file.path(raw_dir, paste0(dl_key, ".zip"))
stopifnot(file.exists(zip_path))

csv_name <- utils::unzip(zip_path, list = TRUE)$Name[1]  # single SIMPLE_CSV file
cat("reading", csv_name, "from zip (5 columns only)...\n")

con <- unz(zip_path, csv_name)
bg_raw <- read_tsv(
  con,
  col_select = c(decimalLatitude, decimalLongitude, year, class, speciesKey),
  col_types  = cols(
    decimalLatitude  = col_double(),
    decimalLongitude = col_double(),
    year             = col_integer(),
    class            = col_character(),
    speciesKey       = col_character(),
    .default         = col_skip()
  ),
  quote = "", progress = TRUE
)
cat("rows read:", nrow(bg_raw), "\n")

bg <- bg_raw %>%
  filter(
    !is.na(decimalLatitude), !is.na(decimalLongitude),
    !is.na(year), year >= YR_MIN, year <= YR_MAX,
    class %in% VERT_CLASSES,
    # belt-and-suspenders: predicate already excludes bobcat, but drop any that slipped through
    is.na(speciesKey) | speciesKey != as.character(BOBCAT_SPECIESKEY)
  ) %>%
  transmute(
    latitude   = decimalLatitude,
    longitude  = decimalLongitude,
    yr         = year,
    vert_class = class
  )

rm(bg_raw); gc()   # free the large raw frame immediately

cat("after filter:", nrow(bg), "\n")
rule("records by vertebrate class")
bg %>% count(vert_class, sort = TRUE) %>% print()
cat("\nFork 3A (mammal)    :", sum(bg$vert_class == "Mammalia"), "\n")
cat("Fork 3B (vertebrate):", nrow(bg), "\n")

# =============================================================================
# SPATIAL JOIN — record -> CPAD unit -> unit x year effort
# =============================================================================
rule("UNIT x YEAR EFFORT (was this unit surveyed that year?)")

units_sf <- read_layer("data/interim/openspace_cpad_bayarea_3310.gpkg")

bg_sf <- st_as_sf(bg, coords = c("longitude", "latitude"),
                  crs = 4326, remove = FALSE) %>%
  to_analysis_crs()

bg_u <- st_join(bg_sf, units_sf["unit_id"], join = st_within) %>%
  st_drop_geometry() %>%
  filter(!is.na(unit_id))

cat("background records inside a CPAD unit:", nrow(bg_u),
    sprintf(" (%.0f%% of pulled)\n", 100 * nrow(bg_u) / nrow(bg)))

# effort table: one row per unit x year that had >=1 background record.
# `df` holds one row PER RECORD (geometry already dropped), so count() before the
# distinct collapse yields the graded per-cell intensity.
#   eff_nrec = number of non-bobcat background records in the unit x year
#              (the graded observer-intensity proxy for the p sub-model)
#   surveyed = 1L, unchanged, so binary consumers (04d/04e) are unaffected
build_effort <- function(df, label) {
  eff <- df %>%
    count(unit_id, yr, name = "eff_nrec") %>%   # graded intensity (>=1 by construction)
    mutate(surveyed = 1L)                        # binary marker retained
  cat(sprintf("\n-- %s --\n", label))
  cat("unit x year cells surveyed  :", nrow(eff), "\n")
  cat("distinct units ever surveyed:", n_distinct(eff$unit_id),
      "of", nrow(units_sf), "\n")
  cat("median survey-years per unit:",
      median(count(eff, unit_id, name = "n")$n), "\n")
  cat("eff_nrec per cell (min/med/max):",
      min(eff$eff_nrec), "/", median(eff$eff_nrec), "/", max(eff$eff_nrec), "\n")
  cat("  eff_nrec distribution (deciles):\n  ")
  print(round(quantile(eff$eff_nrec, probs = seq(0, 1, 0.1))))
  eff
}

eff_mammal <- build_effort(filter(bg_u, vert_class == "Mammalia"),
                           "Fork 3A — mammal effort")
eff_vert   <- build_effort(bg_u, "Fork 3B — all-vertebrate effort")

# =============================================================================
# WRITE both effort layers (unit x year, joined to unit geometry)
# =============================================================================
rule("WRITE effort layers")

write_effort_layer <- function(eff_tbl, out_path, label) {
  eff_sf <- units_sf %>%
    select(unit_id) %>%
    inner_join(eff_tbl, by = "unit_id")     # only surveyed unit x year rows
  write_layer(eff_sf, out_path)
  cat(label, "->", out_path, "|", nrow(eff_sf), "unit x year features\n")
}

write_effort_layer(eff_mammal, mammal_out, "Fork 3A mammal")
write_effort_layer(eff_vert,   vert_out,   "Fork 3B vertebrate")

# =============================================================================
# NON-DETECTION PREVIEW — the A-vs-B decider (and Decision 22 input)
# =============================================================================
# For each option, build the candidate detection history over surveyed unit x
# year cells: y = 1 if a bobcat was detected that unit x year, else 0 (surveyed
# by background but no bobcat = a REAL non-detection). More informative 0s +
# more units with >=2 surveyed years = stronger occupancy support.
rule("NON-DETECTION preview (Fork 3A vs 3B)")

bobc_sf <- read_layer("data/interim/occ_bobc_clean_3310.gpkg")
bobc_u  <- st_join(bobc_sf, units_sf["unit_id"], join = st_within) %>%
  st_drop_geometry() %>%
  filter(!is.na(unit_id)) %>%
  mutate(yr = suppressWarnings(year(ymd(observed_on)))) %>%
  filter(!is.na(yr), yr >= YR_MIN, yr <= YR_MAX) %>%
  distinct(unit_id, yr) %>%
  mutate(bobc_detected = 1L)

preview_hist <- function(eff_tbl, label) {
  cells <- eff_tbl %>% distinct(unit_id, yr)
  hist  <- cells %>%
    left_join(bobc_u, by = c("unit_id", "yr")) %>%
    mutate(y = if_else(is.na(bobc_detected), 0L, 1L))
  cat(sprintf("\n-- %s --\n", label))
  cat("eligible unit x year cells :", nrow(hist), "\n")
  cat("  detections (1)           :", sum(hist$y == 1L), "\n")
  cat("  NON-detections (0, real) :", sum(hist$y == 0L), "\n")
  cat("  naive detection rate     :", round(mean(hist$y), 3), "\n")
  ge2 <- cells %>% count(unit_id, name = "n") %>% filter(n >= 2) %>% nrow()
  cat("  units with >=2 surveyed years:", ge2, "\n")
}

preview_hist(eff_mammal, "Fork 3A — mammal background")
preview_hist(eff_vert,   "Fork 3B — vertebrate background")

rule("DONE — pick Fork 3A vs 3B from the preview; log the DOI in data-sources.md.")
