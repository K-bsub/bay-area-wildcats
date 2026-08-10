# =============================================================================
# 04_bobcat_occupancy_gate.R
# Week 4 — Risk 1 feasibility gate (DIAGNOSTIC ONLY: no writes, no model fit).
# Site = CPAD unit (Fork 1). Fork 2 (time bin) and Fork 3 (background) are
# surfaced as distributions for a decision, not assumed.
# Assesses the pre-fit-testable part of methodology §5.4; p/instability/GOF are
# deferred to Week-7 fitting by construction (can't be evaluated pre-fit).
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

suppressPackageStartupMessages({
  library(sf); library(dplyr); library(tidyr)
  library(stringr); library(lubridate); library(purrr)
})

rule <- function(txt) cat("\n", strrep("=", 78), "\n", txt, "\n",
                          strrep("=", 78), "\n", sep = "")

# ---- inputs -----------------------------------------------------------------
bobc_sf  <- read_layer("data/interim/occ_bobc_clean_3310.gpkg")
units_sf <- read_layer("data/interim/openspace_cpad_bayarea_3310.gpkg")

# iNat/GBIF combined bobcat layer already deduped + clipped (script 03).
cat("bobcat records:", nrow(bobc_sf), "| CPAD units:", nrow(units_sf), "\n")

# =============================================================================
# 1. SITE ASSIGNMENT — bobcat record -> CPAD unit (Fork 1: site = unit)
# =============================================================================
rule("1. SITE ASSIGNMENT (site = CPAD unit)")

# Spatial join: which unit (if any) each bobcat record falls in.
bobc_in <- st_join(bobc_sf, units_sf["unit_id"], join = st_within)

n_in  <- sum(!is.na(bobc_in$unit_id))
n_out <- sum(is.na(bobc_in$unit_id))
cat("records inside a CPAD unit :", n_in, "\n")
cat("records outside (dropped)  :", n_out,
    sprintf(" (%.0f%%)\n", 100 * n_out / nrow(bobc_in)))
cat("  -> out-of-unit records are the urban-edge signal; excluded from the\n",
    "     occupancy site frame by design (occupancy is on open space).\n")

# Keep only records assigned to a unit.
bobc_u <- bobc_in %>% filter(!is.na(unit_id)) %>% st_drop_geometry()

# add a usable date/year — observed_on is 'YYYY-MM-DD' (may be NA)
bobc_u <- bobc_u %>%
  mutate(obs_date = suppressWarnings(ymd(observed_on)),
         yr       = year(obs_date),
         mo       = month(obs_date))

cat("\nrecords with a parseable date:",
    sum(!is.na(bobc_u$yr)), "of", nrow(bobc_u), "\n")
cat("year range:", suppressWarnings(min(bobc_u$yr, na.rm = TRUE)), "-",
    suppressWarnings(max(bobc_u$yr, na.rm = TRUE)), "\n")

# =============================================================================
# 2. FORK 2 PREVIEW — repeat-visit structure under candidate time bins
# =============================================================================
# Occupancy needs sites visited >1 time. For each candidate bin, count:
#   - occupied units (>=1 bobcat detection ever)
#   - units with >=2 DISTINCT time bins containing a bobcat detection
#     (that is the repeat-detection structure occu() actually uses)
# A binning that yields few >=2-bin units cannot support occupancy regardless
# of the 322 site count.
rule("2. FORK 2 — repeat-visit structure by candidate time bin")

dated <- bobc_u %>% filter(!is.na(yr))

bin_report <- function(df, bin_col, label) {
  per_unit <- df %>%
    distinct(unit_id, !!sym(bin_col)) %>%   # unit x bin with >=1 detection
    count(unit_id, name = "n_bins")
  cat(sprintf("\n-- %s --\n", label))
  cat("occupied units (>=1 detection):", n_distinct(df$unit_id), "\n")
  cat("units with >=2 detection-bins :", sum(per_unit$n_bins >= 2), "\n")
  cat("units with >=3 detection-bins :", sum(per_unit$n_bins >= 3), "\n")
  cat("max detection-bins in a unit  :", max(per_unit$n_bins), "\n")
  cat("median bins among occupied    :", median(per_unit$n_bins), "\n")
}

# candidate A: calendar year
bin_report(dated %>% mutate(b = yr), "b", "bin = calendar year")

# candidate B: 2-year blocks
bin_report(dated %>% mutate(b = (yr %/% 2) * 2), "b", "bin = 2-year block")

# candidate C: season (meteorological), pooled across years
dated_season <- dated %>%
  mutate(season = case_when(
    mo %in% c(12, 1, 2)  ~ "DJF",
    mo %in% c(3, 4, 5)   ~ "MAM",
    mo %in% c(6, 7, 8)   ~ "JJA",
    mo %in% c(9, 10, 11) ~ "SON"))
bin_report(dated_season %>% mutate(b = season), "b", "bin = season (pooled years)")

# raw visit-count distribution per occupied unit (bin-agnostic)
rule("2b. FORK 2 — raw records-per-unit distribution (all occupied units)")
rec_per_unit <- bobc_u %>% count(unit_id, name = "n_records")
print(summary(rec_per_unit$n_records))
cat("units with 1 record only:", sum(rec_per_unit$n_records == 1),
    "of", nrow(rec_per_unit),
    sprintf(" (%.0f%% single-record)\n",
            100 * mean(rec_per_unit$n_records == 1)))

# =============================================================================
# 3. FORK 3 PREVIEW — candidate target-group backgrounds (the 0s)
# =============================================================================
# A non-detection 0 requires evidence the unit WAS surveyed in that bin but no
# bobcat was recorded. Options differ in what counts as "surveyed". This block
# reports how many unit x bin cells each option would populate — but it needs a
# background-effort layer we have NOT built yet. Flag what's required for each.
rule("3. FORK 3 — target-group background options (what each needs)")

cat(
  "Option A — other iNat MAMMAL effort as background:\n",
  "  needs: an iNat research-grade pull of NON-bobcat mammals over the same bbox\n",
  "         + date range, clipped to units. NOT in the repo yet.\n",
  "  reads a 0 as: 'someone recorded a mammal here this bin, but not a bobcat'.\n\n",
  "Option B — all iNat VERTEBRATE effort as background:\n",
  "  needs: broader iNat pull (birds dominate -> lots of 0s, effort proxy weaker\n",
  "         for a ground carnivore). NOT in the repo yet.\n\n",
  "Option C — bobcat-only, no target group (NAIVE):\n",
  "  needs: nothing extra. Every occupied unit x bin = 1; all other occupied-unit\n",
  "         bins = 0. FABRICATES non-detections; biases p and psi. Shown only as\n",
  "         the floor case, NOT recommended.\n", sep = "")

# Option C is computable now — show it as the naive floor ONLY.
rule("3b. FORK 3 — Option C naive floor (bobcat-only; illustrative, biased)")
naive_year <- dated %>%
  distinct(unit_id, yr) %>%
  mutate(detect = 1L) %>%
  complete(unit_id, yr, fill = list(detect = 0L))   # fabricates 0s
cat("naive detection history (year bins, occupied units x observed years):\n")
cat("  unit x year cells:", nrow(naive_year), "\n")
cat("  detections (1):", sum(naive_year$detect),
    "| non-detections (0):", sum(naive_year$detect == 0), "\n")
cat("  *** these 0s are fabricated — Option A/B replace them with real effort ***\n")

# =============================================================================
# 4. §5.4 GATE — the pre-fit-testable criteria
# =============================================================================
rule("4. §5.4 GATE — pre-fit-testable criteria (site count, naive occupancy)")

n_units_total    <- nrow(units_sf)
n_units_occupied <- n_distinct(bobc_u$unit_id)

cat("CRITERION 1 — site histories >= 40:\n")
cat("  occupied units:", n_units_occupied, "/ 40 floor ->",
    if (n_units_occupied >= 40) "PASS" else "FAIL", "\n\n")

# Naive occupancy needs a 'surveyed units' denominator. Without the target-group
# background (Fork 3) the only honest denominator is 'units with ANY iNat effort'
# — which we can't compute until the background pull exists. Report the two
# bracketing denominators so the naive-psi range is explicit.
cat("CRITERION 2 — naive occupancy within 0.10-0.90:\n")
psi_vs_all  <- n_units_occupied / n_units_total
cat("  psi if denominator = ALL units (",
    n_units_total, "):", round(psi_vs_all, 3),
    if (psi_vs_all >= 0.10 & psi_vs_all <= 0.90) "-> in range" else "-> OUT of range", "\n")
cat("  psi if denominator = surveyed units only: NEEDS Fork-3 background layer\n")
cat("  (true naive psi sits between these; the surveyed denominator is < all\n",
    "   units, so true psi is HIGHER than the all-units value above.)\n\n")

cat("CRITERIA 3-5 — detection prob < 0.10, parameter instability,\n",
    "  MacKenzie-Bailey GOF: NOT evaluable pre-fit. Deferred to Week-7 fitting\n",
    "  by construction. The gate decides whether a defensible history EXISTS;\n",
    "  these three are checked when the model is actually fit.\n")

# =============================================================================
# 6. RECENT-WINDOW CHECK — 2010-2026 (the "iNat era"; Fork 2b year window)
# =============================================================================
# The all-years figures (Section 2) include a deep museum tail back to 1897.
# A 129-year detection history is not a current-distribution read: pre-iNat
# records carry no repeat-visit effort structure. Re-run the repeat-visit report
# and the pre-fit §5.4 criteria on 2010-2026 only. THIS is the occupancy sample
# the gate should be judged on.
rule("6. RECENT WINDOW 2010-2026 — repeat-visit structure (the real sample)")

YR_MIN <- 2010
YR_MAX <- 2026

bobc_recent <- bobc_u %>% filter(!is.na(yr), yr >= YR_MIN, yr <= YR_MAX)

cat("records in window:", nrow(bobc_recent),
    "of", sum(!is.na(bobc_u$yr)), "dated in-unit records",
    sprintf(" (%.0f%% retained)\n",
            100 * nrow(bobc_recent) / sum(!is.na(bobc_u$yr))))
cat("dropped pre-2010 :", sum(bobc_u$yr < YR_MIN, na.rm = TRUE), "\n\n")

# reuse the same reporter as Section 2 so the numbers are directly comparable
bin_report(bobc_recent %>% mutate(b = yr), "b", "bin = calendar year (2010-2026)")
bin_report(bobc_recent %>% mutate(b = (yr %/% 2) * 2), "b", "bin = 2-year block (2010-2026)")

# records-per-unit in the window
rule("6b. RECENT WINDOW — records-per-unit distribution")
rec_recent <- bobc_recent %>% count(unit_id, name = "n_records")
print(summary(rec_recent$n_records))
cat("occupied units in window     :", nrow(rec_recent), "\n")
cat("single-record units in window:", sum(rec_recent$n_records == 1),
    sprintf(" (%.0f%%)\n", 100 * mean(rec_recent$n_records == 1)))

# =============================================================================
# 7. §5.4 GATE on the recent window — side-by-side with all-years
# =============================================================================
rule("7. §5.4 GATE — 2010-2026 window vs all-years")

# --- helper: the two pre-fit-testable criteria for a given record set --------
gate_snapshot <- function(df, n_units_total, label) {
  occ_units <- n_distinct(df$unit_id)
  per_unit  <- df %>% filter(!is.na(yr)) %>%
    distinct(unit_id, yr) %>% count(unit_id, name = "n_bins")
  n_ge2 <- sum(per_unit$n_bins >= 2)
  psi_all <- occ_units / n_units_total
  cat(sprintf("\n-- %s --\n", label))
  cat("  occupied units (site histories):", occ_units,
      "->", if (occ_units >= 40) "PASS (>=40)" else "FAIL (<40)", "\n")
  cat("  units with >=2 year-bins        :", n_ge2,
      "  <- effective repeat-visit sample\n")
  cat("  naive psi (all-units denom)     :", round(psi_all, 3),
      "->", if (psi_all >= 0.10 & psi_all <= 0.90) "in range" else "OUT of range", "\n")
  invisible(list(occ = occ_units, ge2 = n_ge2, psi = psi_all))
}

g_all    <- gate_snapshot(bobc_u %>% filter(!is.na(yr)), nrow(units_sf), "ALL YEARS (1897-2026)")
g_recent <- gate_snapshot(bobc_recent,                    nrow(units_sf), "RECENT (2010-2026)")

rule("7b. GATE READ")
cat("Site count (>=40)  : all-years", g_all$occ, "| recent", g_recent$occ,
    "->", if (g_recent$occ >= 40) "PASS" else "FAIL", "\n")
cat("Repeat sample (>=2): all-years", g_all$ge2, "| recent", g_recent$ge2,
    "->", if (g_recent$ge2 >= 40) "occupancy structurally supported"
    else "thin — SDM fallback likely", "\n")
cat("Naive psi in range : all-years", round(g_all$psi, 3),
    "| recent", round(g_recent$psi, 3), "\n\n")
cat("If recent >=2-bin count stays well above 40 and psi stays in 0.10-0.90,\n",
    "the gate outcome is OCCUPANCY PROCEEDS (Decision 22), conditional on the\n",
    "Fork-3 background pull. If recent numbers collapse, SDM fallback.\n", sep = "")

rule("DONE — recent-window diagnostic. No files written, no model fit.")

# =============================================================================
# 5. WHAT THE GATE NEEDS NEXT
# =============================================================================
rule("5. GATE STATUS — decision inputs still outstanding")
cat(
  "Decided : site = CPAD unit (Fork 1).\n",
  "From this run, you can now choose:\n",
  "  Fork 2 (time bin): pick the binning with enough >=2-bin units to support\n",
  "           repeat-detection estimation (see section 2).\n",
  "  Fork 3 (background): A or B require an iNat non-bobcat effort pull that is\n",
  "           NOT yet in the repo. That pull is the next script if occupancy is\n",
  "           to proceed. Option C (naive) is not defensible.\n\n",
  "Gate cannot be CLOSED until Fork 3's background layer exists (or you accept\n",
  "the SDM fallback now on the strength of section 2's repeat-visit numbers).\n", sep = "")

rule("DONE — diagnostic only. No files written, no model fit.")