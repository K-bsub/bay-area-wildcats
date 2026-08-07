# =============================================================================
# 02_prepare_openspace.R  —  BLOCK 2: BUILD THE CANONICAL OPEN-SPACE LAYER
# =============================================================================
# Project : Wild Cats at the Urban Edge (Bay Area Wildcats)
# Depends : Block 1 (schema inspection) already run and understood.
#           data/raw/cpad/CPAD_2026a_Release/{Holdings,Units}.shp
#           data/interim/boundary_baydissolved_3310.gpkg  (Week 2)
# Implements: Decision 17 (Units as site) + Decision 18 (non-habitat filter).
# Output  : data/interim/openspace_cpad_bayarea_3310.gpkg
# CRS     : EPSG:3310 throughout (native; verified in Block 1).
#
# Pipeline:
#   1. Load Holdings + Units, make valid, confirm 3310
#   2. Flag non-habitat Holdings (SPEC_USE / LAND_WATER / Cemetery District)
#   3. Clip to ten-county boundary (spatial — Decision 17)
#   4. Overlay flagged Holdings onto Units -> nonhab_area_km2, hab_frac
#   5. PRINT hab_frac distribution (to finalise the provisional 0.5 cutoff)
#   6. Apply size floor (habitat area >= 0.10 km2) + hab_frac rule
#   7. Attach hierarchy keys, tidy fields, write GeoPackage
#   8. Print the audit trail (counts at each step)
# =============================================================================

suppressPackageStartupMessages({
  library(sf); library(dplyr)
})

cpad_dir  <- "data/raw/cpad/CPAD_2026a_Release"
out_gpkg  <- "data/interim/openspace_cpad_bayarea_3310.gpkg"
out_layer <- "openspace_cpad_bayarea_3310"

MIN_HAB_AREA_KM2 <- 0.10   # Decision 18 size floor (habitat area)
MIN_HAB_FRAC     <- 0.50   # Decision 18 - resolved; hab_frac bimodal, insensitive 0.4-0.6

# Non-habitat SPEC_USE values (Holdings only). Deny-list, NOT "all non-NA":
# Trail Corridor / National Monument / HCP/NCCP / Arboretum / Planned Park are
# habitat or conservation land and are deliberately absent here.
NONHAB_SPEC_USE <- c("Golf Course", "Cemetery", "Community Garden",
                     "Community Center", "Senior Center", "Youth Center")
NONHAB_AGNCY_TYP <- c("Cemetery District")

# ---- 1. Load, validate, confirm CRS -----------------------------------------
holdings <- st_read(file.path(cpad_dir, "CPAD_2026a_Holdings.shp"), quiet = TRUE)
units    <- st_read(file.path(cpad_dir, "CPAD_2026a_Units.shp"),    quiet = TRUE)
bound    <- st_read("data/interim/boundary_baydissolved_3310.gpkg", quiet = TRUE)

stopifnot(st_crs(holdings)$epsg == 3310,
          st_crs(units)$epsg    == 3310,
          st_crs(bound)$epsg    == 3310)

# 2 invalid Units / 3 invalid SuperUnits seen in Block 1; Holdings clean, but
# make_valid all three cheaply and unconditionally.
holdings <- st_make_valid(holdings)
units    <- st_make_valid(units)
bound    <- st_make_valid(bound)

# ---- 2. Flag non-habitat Holdings -------------------------------------------
holdings <- holdings |>
  mutate(
    is_nonhab =
      (SPEC_USE  %in% NONHAB_SPEC_USE) |
      (LAND_WATER == "Water")          |
      (AGNCY_TYP  %in% NONHAB_AGNCY_TYP)
  )

cat("=== Non-habitat Holdings flagged (statewide, pre-clip) ===\n")
print(table(holdings$is_nonhab, useNA = "ifany"))
cat("\n")

# ---- 3. Spatial clip to ten-county boundary (Decision 17) -------------------
# Clip is the source of truth for membership. Use st_intersection so units that
# straddle the boundary are cut to it, not kept whole. Holdings clipped too so
# the overlay areas are study-area-correct.
# (s2 off to tolerate any residual geometry quirks in intersection.)
sf_use_s2(FALSE)

units_ba    <- st_intersection(units,    st_geometry(bound))
holdings_ba <- st_intersection(holdings, st_geometry(bound))

# st_intersection can emit GEOMETRYCOLLECTION / lines at edges; keep polygons.
units_ba    <- units_ba[st_dimension(units_ba) == 2, ]
holdings_ba <- holdings_ba[st_dimension(holdings_ba) == 2, ]
units_ba    <- st_collection_extract(units_ba,    "POLYGON")
holdings_ba <- st_collection_extract(holdings_ba, "POLYGON")

n_units_raw <- nrow(units_ba)

# ---- 4. Overlay flagged Holdings onto Units -> habitat fraction -------------
# Total unit area:
units_ba <- units_ba |>
  mutate(unit_area_km2 = as.numeric(st_area(geometry)) / 1e6)

# Non-habitat area per unit: intersect non-hab holdings with units, sum by UNIT_ID.
nonhab_holdings <- holdings_ba |> filter(is_nonhab)

if (nrow(nonhab_holdings) > 0) {
  nh_x <- st_intersection(
    units_ba |> select(UNIT_ID),
    nonhab_holdings |> select() # geometry only
  )
  nh_x <- nh_x[st_dimension(nh_x) == 2, ]
  nh_x <- st_collection_extract(nh_x, "POLYGON")
  nh_area <- nh_x |>
    mutate(a = as.numeric(st_area(geometry)) / 1e6) |>
    st_drop_geometry() |>
    group_by(UNIT_ID) |>
    summarise(nonhab_area_km2 = sum(a), .groups = "drop")
} else {
  nh_area <- tibble(UNIT_ID = numeric(0), nonhab_area_km2 = numeric(0))
}

units_ba <- units_ba |>
  left_join(nh_area, by = "UNIT_ID") |>
  mutate(
    nonhab_area_km2 = tidyr::replace_na(nonhab_area_km2, 0),
    hab_area_km2    = pmax(unit_area_km2 - nonhab_area_km2, 0),
    hab_frac        = ifelse(unit_area_km2 > 0, hab_area_km2 / unit_area_km2, 0),
    has_nonhabitat  = nonhab_area_km2 > 0
  )

# ---- 5. PRINT hab_frac distribution (finalise the 0.5 cutoff) ---------------
cat("=== hab_frac distribution (units with any non-habitat) ===\n")
hf <- units_ba$hab_frac[units_ba$has_nonhabitat]
if (length(hf) > 0) {
  print(round(quantile(hf, c(0,.05,.1,.25,.5,.75,.9,.95,1)), 3))
  cat(sprintf("\nUnits with non-habitat: %d\n", length(hf)))
  cat(sprintf("Would drop at hab_frac<0.4: %d | <0.5: %d | <0.6: %d\n",
              sum(hf < .4), sum(hf < .5), sum(hf < .6)))
} else {
  cat("(no units contain flagged non-habitat holdings)\n")
}
cat("\n--> Confirm MIN_HAB_FRAC against this before trusting the filtered output.\n\n")

# ---- 6. Apply the filters (Decision 18) -------------------------------------
units_keep <- units_ba |>
  filter(hab_area_km2 >= MIN_HAB_AREA_KM2,
         hab_frac      >= MIN_HAB_FRAC)

# ---- 7. Hierarchy keys, tidy fields, write ----------------------------------
# SUID_NMA (SuperUnit key) and UNIT_ID already present. Standardise names to the
# project convention (naming-conventions.md §5) while keeping the CPAD originals.
openspace <- units_keep |>
  transmute(
    unit_id        = UNIT_ID,
    unit_name      = UNIT_NAME,
    suid_nma       = SUID_NMA,          # SuperUnit roll-up key (connectivity)
    county         = COUNTY,            # audit attribute only (Decision 17)
    access_typ     = ACCESS_TYP,        # descriptive only (NOT a filter)
    agncy_typ      = AGNCY_TYP,
    agncy_lev      = AGNCY_LEV,
    mng_ag_typ     = MNG_AG_TYP,
    unit_area_km2,
    nonhab_area_km2,
    hab_area_km2,
    hab_frac,
    has_nonhabitat,
    geometry
  )

# One row per unit after intersection may have split a unit into pieces at the
# boundary; dissolve back to one geometry per unit_id so the site is whole.
openspace <- openspace |>
  group_by(unit_id, unit_name, suid_nma, county, access_typ, agncy_typ,
           agncy_lev, mng_ag_typ) |>
  summarise(
    unit_area_km2   = sum(unit_area_km2),
    nonhab_area_km2 = sum(nonhab_area_km2),
    hab_area_km2    = sum(hab_area_km2),
    hab_frac        = weighted.mean(hab_frac, unit_area_km2),
    has_nonhabitat  = any(has_nonhabitat),
    .groups = "drop"
  ) |>
  st_make_valid()

# ---- 7b. Large-Unit gradient flag (Decision 17, covariate pre-flag) ----------
# Some kept units are large enough that a single occupancy covariate value would
# smear across an internal land-cover / terrain gradient. Flag them NOW so
# Week-4/5 covariate summarisation can treat them differently (e.g. summarise by
# sub-cell rather than whole-unit mean). The threshold targets the large tail,
# not the median: with a median kept unit ~0.79 km2, a ">1 km2" rule would flag
# ~45% of units and lose its value as a triage signal. 5 km2 isolates the
# ~top-decile units where the gradient concern is real.
#
# Print the area distribution of kept units first so the threshold is read off
# the data, not asserted (same discipline as the hab_frac cutoff).
#
# Observed: median kept unit ~0.79 km2, so ">1 km2" flags ~45% of units — too
# broad to be useful for triage. The genuine gradient risk is the large tail
# (p90 ~8.7 km2), so the threshold is set at 5 km2 to catch the ~top-decile
# units where a whole-unit covariate mean smears across a real land-cover
# gradient, and leave the bulk where a unit mean is defensible.
SPANS_GRADIENT_KM2 <- 5.0

cat("=== hab_area_km2 distribution, kept units (set gradient threshold) ===\n")
print(round(quantile(openspace$hab_area_km2,
                     c(0,.25,.5,.75,.9,.95,.99,1)), 3))
cat(sprintf("Units > 2 km2: %d | > 5 km2: %d | > 10 km2: %d  (of %d)\n\n",
            sum(openspace$hab_area_km2 > 2.0),
            sum(openspace$hab_area_km2 > 5.0),
            sum(openspace$hab_area_km2 > 10.0),
            nrow(openspace)))

openspace <- openspace |>
  mutate(spans_gradient = hab_area_km2 > SPANS_GRADIENT_KM2)

st_write(openspace, out_gpkg, out_layer, delete_dsn = TRUE, quiet = TRUE)

# ---- 8. Audit trail ---------------------------------------------------------
cat("=====================================================================\n")
cat("AUDIT TRAIL (Decision 18)\n")
cat("=====================================================================\n")
cat(sprintf("  Bay-Area units (post-clip, raw)        : %d\n", n_units_raw))
cat(sprintf("  After size floor (hab_area >= %.2f km2): %d\n",
            MIN_HAB_AREA_KM2, sum(units_ba$hab_area_km2 >= MIN_HAB_AREA_KM2)))
cat(sprintf("  After hab_frac >= %.2f                 : %d\n",
            MIN_HAB_FRAC, nrow(units_keep)))
cat(sprintf("  Final units written                   : %d\n", nrow(openspace)))
cat(sprintf("  Total habitat area retained           : %.1f km2\n",
            sum(openspace$hab_area_km2)))
cat(sprintf("  Units flagged has_nonhabitat          : %d\n",
            sum(openspace$has_nonhabitat)))
cat(sprintf("  Units flagged spans_gradient (>%.1f km2): %d\n",
            SPANS_GRADIENT_KM2, sum(openspace$spans_gradient)))
cat(sprintf("\n  Written: %s :: %s\n", out_gpkg, out_layer))
cat("=====================================================================\n")
