# =============================================================================
# 08_bobcat_detection_history.R
#
# Build the bobcat unit x year detection history that (with the null fit in the
# next script) closes Decision 22. BUILD ONLY — no model is fit here; the
# histories are written and diagnosed for review first.
#
# Design (Decision 17 + 22):
#   site      = CPAD unit (unit_id), occupancy frame
#   occasion  = calendar year, window 2010-2026 (17 occasions)
#   cell value:
#     1  = unit-year is surveyed AND >=1 bobcat detection that year
#     0  = unit-year is surveyed AND no bobcat detection  (a REAL non-detection)
#     NA = unit-year not surveyed (absent from the effort layer) — NEVER a 0
#
# "Surveyed" comes from the Fork-3 effort layers (row present = surveyed=1;
# row absent = unsurveyed = NA). Built under BOTH backgrounds:
#   3A mammal     (cov_effort_gbif_mammal_unityear_3310.gpkg)     target-group
#   3B vertebrate (cov_effort_gbif_vertebrate_unityear_3310.gpkg) bird-deflated
# The A-vs-B choice is held to the fit (Decision 22); both histories are written.
#
# Detections (Decision 20/21): obscured bobcat coords are RANDOMISED, so a
# spatial join can place them in the wrong unit. Per sign-off:
#   PRIMARY   = precise detections only (obscured dropped from detection)
#   SENSITIVITY = precise + obscured (obscured joined by its randomised coord)
# Both detection sets x both backgrounds = 4 histories. Primary drives the close;
# sensitivity is a robustness check.
#
# Inputs (EPSG:3310, data/interim/):
#   occ_bobc_clean_3310.gpkg                       (points; observed_on, obscured)
#   openspace_cpad_bayarea_3310.gpkg               (units; unit_id — join target)
#   cov_effort_gbif_mammal_unityear_3310.gpkg      (3A; unit_id, yr, surveyed)
#   cov_effort_gbif_vertebrate_unityear_3310.gpkg  (3B; unit_id, yr, surveyed)
#
# Outputs:
#   data/interim/dh_bobc_mammal_precise_3310.rds        (site x year matrix)
#   data/interim/dh_bobc_mammal_all_3310.rds
#   data/interim/dh_bobc_vertebrate_precise_3310.rds
#   data/interim/dh_bobc_vertebrate_all_3310.rds
#   outputs/tables/tbl_08_detection_history_summary.csv (per-history diagnostics)
#   outputs/tables/tbl_08_detections_outside_effort.csv (flag: detections in unsurveyed unit-years)
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

library(sf)
library(tidyverse)

YEARS <- 2010:2026                                   # 17 occasions (Decision 22)

# -----------------------------------------------------------------------------
# 1. Load
# -----------------------------------------------------------------------------
f_occ     <- file.path(PATH$interim, "occ_bobc_clean_3310.gpkg")
f_units   <- file.path(PATH$interim, "openspace_cpad_bayarea_3310.gpkg")
f_eff_mam <- file.path(PATH$interim, "cov_effort_gbif_mammal_unityear_3310.gpkg")
f_eff_ver <- file.path(PATH$interim, "cov_effort_gbif_vertebrate_unityear_3310.gpkg")
stopifnot(file.exists(f_occ), file.exists(f_units), file.exists(f_eff_mam), file.exists(f_eff_ver))

occ_sf    <- read_layer(f_occ)
units_sf  <- read_layer(f_units)
eff_mam   <- sf::st_drop_geometry(read_layer(f_eff_mam))
eff_ver   <- sf::st_drop_geometry(read_layer(f_eff_ver))

stopifnot(all(c("observed_on","obscured") %in% names(occ_sf)))
stopifnot("unit_id" %in% names(units_sf))
stopifnot(all(c("unit_id","yr","surveyed") %in% names(eff_mam)))
stopifnot(all(c("unit_id","yr","surveyed") %in% names(eff_ver)))

# -----------------------------------------------------------------------------
# 2. Assign detections to unit x year (spatial join + date parse)
# -----------------------------------------------------------------------------
# Parse year from observed_on (YYYY-MM-DD); drop undated / out-of-window.
occ_sf$det_year <- suppressWarnings(as.integer(substr(occ_sf$observed_on, 1, 4)))
n_undated <- sum(is.na(occ_sf$det_year))
occ_win <- occ_sf[!is.na(occ_sf$det_year) &
                  occ_sf$det_year >= min(YEARS) & occ_sf$det_year <= max(YEARS), ]
message(sprintf("Detections: %d total | %d undated dropped | %d in 2010-2026 window",
                nrow(occ_sf), n_undated, nrow(occ_win)))

# Spatial join detection -> unit_id (point in polygon). Records outside all units
# get unit_id = NA and are excluded from detection (a detection must land in a
# CPAD unit to count as an in-frame detection).
occ_win <- sf::st_join(occ_win, units_sf[, "unit_id"], join = sf::st_within)
n_in_unit <- sum(!is.na(occ_win$unit_id))
message(sprintf("Detections joined to a CPAD unit: %d of %d (%.1f%%)",
                n_in_unit, nrow(occ_win), 100 * n_in_unit / nrow(occ_win)))

det <- occ_win[!is.na(occ_win$unit_id), ] |>
  sf::st_drop_geometry() |>
  dplyr::select(unit_id, det_year, obscured)

# Two detection sets
det_precise <- det[!(det$obscured %in% TRUE), c("unit_id","det_year")] |> dplyr::distinct()
det_all     <- det[, c("unit_id","det_year")] |> dplyr::distinct()
message(sprintf("Detection unit-years: precise %d | all(incl obscured) %d",
                nrow(det_precise), nrow(det_all)))

# -----------------------------------------------------------------------------
# 3. Detection-history builder
# -----------------------------------------------------------------------------
# For a given effort table and detection set, return a site x year matrix over
# ALL occupancy-frame units (rows) and YEARS (cols): 1 detected, 0 surveyed-no-
# detection, NA unsurveyed.
build_dh <- function(effort_df, det_df, tag) {
  eff <- effort_df |>
    dplyr::filter(yr %in% YEARS) |>
    dplyr::distinct(unit_id, yr) |>
    dplyr::mutate(surveyed = 1L)

  all_units <- sort(unique(units_sf$unit_id))
  grid <- tidyr::expand_grid(unit_id = all_units, yr = YEARS)

  dh_long <- grid |>
    dplyr::left_join(eff, by = c("unit_id","yr")) |>            # surveyed = 1 or NA
    dplyr::left_join(det_df |> dplyr::mutate(detected = 1L),
                     by = c("unit_id", "yr" = "det_year")) |>
    dplyr::mutate(
      value = dplyr::case_when(
        # Decision 27: a bobcat detection is DIRECT evidence of observation effort,
        # so a detected unit-year is surveyed+detected (1) even when the
        # target-group background proxy did not independently mark it surveyed.
        # This overrides the "unsurveyed -> NA" rule ONLY for detected cells; a
        # proxy miss cannot discard a real detection (which would bias p down and
        # push a viable occupancy case artificially toward the SDM line).
        !is.na(detected)             ~ 1L,            # detected -> 1 (implies effort)
        is.na(surveyed)              ~ NA_integer_,   # unsurveyed, no detection -> NA
        TRUE                         ~ 0L             # surveyed, no detection -> 0
      )
    )

  # Count how many cells were upgraded by Decision 27 (detected but background
  # did not mark surveyed) — recorded, not silently applied.
  n_upgraded <- dh_long |>
    dplyr::filter(is.na(surveyed) & !is.na(detected)) |>
    nrow()
  if (n_upgraded > 0) {
    message(sprintf("  [%s] Decision 27: %d detected unit-years upgraded to surveyed (detection implies effort)",
                    tag, n_upgraded))
  }

  upgraded <- dh_long |>
    dplyr::filter(is.na(surveyed) & !is.na(detected)) |>
    dplyr::select(unit_id, yr) |>
    dplyr::mutate(upgraded_by = "decision_27")

  dh_wide <- dh_long |>
    dplyr::select(unit_id, yr, value) |>
    tidyr::pivot_wider(names_from = yr, values_from = value) |>
    dplyr::arrange(unit_id)

  mat <- as.matrix(dh_wide[, as.character(YEARS)])
  rownames(mat) <- dh_wide$unit_id
  list(matrix = mat, upgraded = upgraded)
}

# -----------------------------------------------------------------------------
# 4. Build all four histories
# -----------------------------------------------------------------------------
combos <- list(
  mammal_precise     = list(eff = eff_mam, det = det_precise),
  mammal_all         = list(eff = eff_mam, det = det_all),
  vertebrate_precise = list(eff = eff_ver, det = det_precise),
  vertebrate_all     = list(eff = eff_ver, det = det_all)
)

summ_rows <- list()
upgraded_all <- list()

for (nm in names(combos)) {
  res <- build_dh(combos[[nm]]$eff, combos[[nm]]$det, nm)
  mat <- res$matrix
  saveRDS(mat, file.path(PATH$interim, sprintf("dh_bobc_%s_3310.rds", nm)))

  # Diagnostics
  surveyed_cells <- sum(!is.na(mat))
  det_cells      <- sum(mat == 1, na.rm = TRUE)
  sites_any_survey <- sum(rowSums(!is.na(mat)) > 0)
  sites_occupied   <- sum(rowSums(mat, na.rm = TRUE) > 0)
  sites_ge2_survey <- sum(rowSums(!is.na(mat)) >= 2)
  naive_psi <- sites_occupied / sites_any_survey
  naive_p   <- det_cells / surveyed_cells          # naive per-visit detection

  summ_rows[[nm]] <- data.frame(
    history          = nm,
    background       = ifelse(grepl("mammal", nm), "3A_mammal", "3B_vertebrate"),
    detection_set    = ifelse(grepl("precise", nm), "precise", "all_incl_obscured"),
    n_sites_total    = nrow(mat),
    n_sites_surveyed = sites_any_survey,
    n_sites_ge2_yr   = sites_ge2_survey,
    n_sites_occupied = sites_occupied,
    surveyed_cells   = surveyed_cells,
    detection_cells  = det_cells,
    n_upgraded_d27   = nrow(res$upgraded),         # cells set 1 via Decision 27
    naive_psi        = round(naive_psi, 3),
    naive_p          = round(naive_p, 3),
    fallback_p_flag  = ifelse(naive_p < 0.10, "BELOW_0.10_SDM_RISK", "ok"),
    stringsAsFactors = FALSE
  )
  if (nrow(res$upgraded) > 0) {
    res$upgraded$history <- nm
    upgraded_all[[nm]] <- res$upgraded
  }
}

summ <- dplyr::bind_rows(summ_rows)
write.csv(summ, file.path(PATH$tables, "tbl_08_detection_history_summary.csv"),
          row.names = FALSE)
message("\n== Detection-history summary ==")
print(summ, row.names = FALSE)

if (length(upgraded_all) > 0) {
  write.csv(dplyr::bind_rows(upgraded_all),
            file.path(PATH$tables, "tbl_08_detections_upgraded_d27.csv"),
            row.names = FALSE)
  message("\nDecision-27 upgraded cells written to tbl_08_detections_upgraded_d27.csv")
}

log_stage("dh_bobc", "histories_built", length(combos))

message("\n================ 08_bobcat_detection_history.R complete ================")
message("4 histories written to data/interim/dh_bobc_*_3310.rds")
message("--> REVIEW tbl_08_detection_history_summary.csv before fitting.")
message("    Key checks: naive_p vs the 0.10 SDM-fallback line; n_sites_ge2_yr (repeat structure);")
message("    precise-vs-all delta (does obscured inclusion change psi/p?).")
