# =============================================================================
# 02b_filter_vocab_probe.R  —  targeted vocabulary dump (read-only)
# =============================================================================
# Purpose : Print the FULL value vocabularies (with counts) for the fields the
#           non-habitat filter (Decision 18) will key on — the pieces the
#           inspection output truncated. Bay-Area-clipped so the counts reflect
#           THIS study area, not statewide noise.
# Output  : PRINTS ONLY.
# Depends : data/interim/boundary_baydissolved_3310.gpkg (built Week 2)
# =============================================================================

suppressPackageStartupMessages({ library(sf); library(dplyr) })

cpad_dir <- "data/raw/cpad/CPAD_2026a_Release"
holdings <- st_read(file.path(cpad_dir, "CPAD_2026a_Holdings.shp"), quiet = TRUE)
units    <- st_read(file.path(cpad_dir, "CPAD_2026a_Units.shp"),    quiet = TRUE)

bound <- st_read("data/interim/boundary_baydissolved_3310.gpkg", quiet = TRUE)
bound <- st_transform(bound, 3310)  # no-op if already 3310; cheap insurance

# Clip both to the Bay Area so vocab counts are study-area-relevant.
# Use st_filter (intersects) — fast, and we only need attributes here, not
# exact clipped geometry.
sf_use_s2(FALSE)  # tolerate the 2-3 invalid geometries for this attribute probe
holdings_ba <- holdings[st_filter(holdings, bound, .predicate = st_intersects) |> row.names() |> as.integer(), ]
# simpler + robust:
holdings_ba <- st_filter(holdings, bound, .predicate = st_intersects)
units_ba    <- st_filter(units,    bound, .predicate = st_intersects)

cat("Bay Area Holdings:", nrow(holdings_ba), " / statewide", nrow(holdings), "\n")
cat("Bay Area Units   :", nrow(units_ba),    " / statewide", nrow(units), "\n\n")

dump_vocab <- function(df, field, label = field) {
  if (!field %in% names(df)) { cat("  [", field, "not present ]\n\n"); return(invisible()) }
  cat("=====================================================================\n")
  cat(sprintf("%s  (%s)\n", label, field))
  cat("=====================================================================\n")
  v <- df[[field]]
  tab <- sort(table(v, useNA = "ifany"), decreasing = TRUE)
  for (i in seq_along(tab))
    cat(sprintf("  %6d  %s\n", tab[i], names(tab)[i]))
  cat("\n")
}

cat("################  HOLDINGS (Bay Area)  ################\n\n")
dump_vocab(holdings_ba, "AGNCY_TYP",  "Owner agency type")
dump_vocab(holdings_ba, "MNG_AG_TYP", "Managing agency type")
dump_vocab(holdings_ba, "AGNCY_LEV",  "Owner agency level")
dump_vocab(holdings_ba, "ACCESS_TYP", "Access type")
dump_vocab(holdings_ba, "LAND_WATER", "Land vs water")
dump_vocab(holdings_ba, "SPEC_USE",   "Special use (golf/cemetery flag?)")

cat("################  UNITS (Bay Area)  ################\n\n")
dump_vocab(units_ba, "AGNCY_TYP",  "Owner agency type")
dump_vocab(units_ba, "MNG_AG_TYP", "Managing agency type")
dump_vocab(units_ba, "ACCESS_TYP", "Access type")

# Cross-tab that matters for Decision 18: how much AREA (not just count) would
# each candidate exclusion rule remove, Bay-Area Units level?
cat("=====================================================================\n")
cat("AREA IMPACT OF CANDIDATE EXCLUSIONS  (Bay Area Units)\n")
cat("=====================================================================\n")
units_ba$area_km2 <- as.numeric(st_area(units_ba)) / 1e6
tot <- sum(units_ba$area_km2)
cat(sprintf("Total Bay Area Units area: %.1f km2 (n=%d)\n\n", tot, nrow(units_ba)))

report_cut <- function(df, mask, label) {
  n <- sum(mask, na.rm = TRUE)
  a <- sum(df$area_km2[mask], na.rm = TRUE)
  cat(sprintf("  %-42s remove %5d units  %9.1f km2  (%.1f%% area)\n",
              label, n, a, 100 * a / tot))
}
report_cut(units_ba, units_ba$area_km2 < 0.02,  "area < 0.02 km2 (2 ha)")
report_cut(units_ba, units_ba$area_km2 < 0.05,  "area < 0.05 km2 (5 ha)")
report_cut(units_ba, units_ba$area_km2 < 0.10,  "area < 0.10 km2 (10 ha)")
report_cut(units_ba, units_ba$AGNCY_TYP %in% c("Cemetery District"), "AGNCY_TYP = Cemetery District")
report_cut(units_ba, grepl("Airport", units_ba$AGNCY_TYP), "AGNCY_TYP contains 'Airport'")
report_cut(units_ba, units_ba$ACCESS_TYP == "No Public Access", "ACCESS_TYP = No Public Access (CAUTION)")

cat("\nDone. Paste back the vocab dumps + area-impact block.\n")
