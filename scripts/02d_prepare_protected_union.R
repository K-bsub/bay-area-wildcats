# =============================================================================
# 02d_prepare_protected_union.R  —  CPAD ∪ CCED for the connectivity track
# =============================================================================
# Project : Wild Cats at the Urban Edge (Bay Area Wildcats)
# Implements: Decision 19 — union with protection_type {fee, easement},
#             fee precedence on overlap (Option b: tenure preserved).
# Depends : 02c already run -> data/interim/openspace_cpad_bayarea_3310.gpkg
#           data/raw/cced/CCED_2026a_Release/CCED_2026a_Release.shp
#           data/interim/boundary_baydissolved_3310.gpkg
# Output  : data/interim/protected_union_bayarea_3310.gpkg
# CRS     : EPSG:3310 throughout (native).
#
# CONNECTIVITY TRACK ONLY. The occupancy frame stays CPAD-only (02c output).
#
# Pipeline:
#   1. Load filtered CPAD fee units (02c) + CCED + boundary; make valid; check CRS
#   2. Clip CCED to the ten-county boundary (Decision 17 — spatial)
#   3. Difference CPAD fee footprint OUT of CCED (fee precedence on overlap)
#   4. Tag protection_type; harmonise a common attribute set
#   5. rbind fee + easement-only into one union layer
#   6. Write GeoPackage + print audit (area by protection_type, overlap removed)
# =============================================================================

suppressPackageStartupMessages({ library(sf); library(dplyr) })

cced_shp  <- "data/raw/cced/CCED_2026a_Release/CCED_2026a_Release.shp"
cpad_gpkg <- "data/interim/openspace_cpad_bayarea_3310.gpkg"
out_gpkg  <- "data/interim/protected_union_bayarea_3310.gpkg"
out_layer <- "protected_union_bayarea_3310"

# ---- 1. Load, validate, confirm CRS -----------------------------------------
cpad_fee <- st_read(cpad_gpkg, quiet = TRUE)                      # filtered fee units
cced     <- st_read(cced_shp, quiet = TRUE)
bound    <- st_read("data/interim/boundary_baydissolved_3310.gpkg", quiet = TRUE)

stopifnot(st_crs(cpad_fee)$epsg == 3310,
          st_crs(cced)$epsg     == 3310,
          st_crs(bound)$epsg    == 3310)

cced  <- st_make_valid(cced)
bound <- st_make_valid(bound)
cpad_fee <- st_make_valid(cpad_fee)

sf_use_s2(FALSE)  # tolerate edge geometry in intersection/difference

# ---- 2. Clip CCED to the ten-county boundary --------------------------------
cced_ba <- st_intersection(cced, st_geometry(bound))
cced_ba <- cced_ba[st_dimension(cced_ba) == 2, ]
cced_ba <- st_collection_extract(cced_ba, "POLYGON")
n_cced_ba <- nrow(cced_ba)

# ---- 3. Fee precedence: difference CPAD fee OUT of CCED ----------------------
# Union the fee geometry into a single mask, then erase it from CCED so the
# easement layer only contributes ground CPAD fee does NOT already cover.
fee_mask <- cpad_fee |> st_geometry() |> st_union()

cced_diff <- st_difference(cced_ba, fee_mask)
cced_diff <- cced_diff[!st_is_empty(cced_diff), ]
cced_diff <- cced_diff[st_dimension(cced_diff) == 2, ]
cced_diff <- st_collection_extract(cced_diff, "POLYGON")

# Area accounting for the audit (how much easement area was overlap with fee)
area_cced_ba   <- sum(as.numeric(st_area(cced_ba))   / 1e6)
area_cced_diff <- sum(as.numeric(st_area(cced_diff)) / 1e6)
area_overlap   <- area_cced_ba - area_cced_diff

# ---- 4. Tag protection_type; harmonise attributes ---------------------------
# Common schema for the union. CPAD and CCED describe tenure differently, so we
# keep a small shared set + a source-specific holder/type column, not a forced
# merge of incompatible fields.

fee_part <- cpad_fee |>
  mutate(area_km2 = as.numeric(st_area(cpad_fee)) / 1e6) |>
  transmute(
    protection_type = "fee",
    src_id          = unit_id,
    holder_type     = agncy_lev,          # City/County/State/Federal/NonProfit/...
    land_type       = agncy_typ,          # owner agency type
    pub_access      = access_typ,
    county          = county,
    area_km2        = area_km2
  )

easement_part <- cced_diff |>
  mutate(area_km2 = as.numeric(st_area(cced_diff)) / 1e6) |>
  transmute(
    protection_type = "easement",
    src_id          = e_hold_id,
    holder_type     = eholdtyp,           # Association/City/County/NonProfit/Private/Unknown/...
    land_type       = e_type,             # Agricultural/Grazing/Habitat/Conservation/...
    pub_access      = pubaccess,          # Closed/Open Access/Restricted Access
    county          = county,
    area_km2        = area_km2
  )

# ---- 5. Combine -------------------------------------------------------------
# Ensure identical column order/names before rbind. The two parts can carry
# different geometry-column names (cpad from .gpkg -> "geom"; cced from .shp ->
# "geometry"); rbind.sf matches names exactly, so rename both to "geometry".
st_geometry(fee_part)      <- "geometry"
st_geometry(easement_part) <- "geometry"

protected_union <- rbind(fee_part, easement_part) |> st_make_valid()

# ---- 6. Write + audit -------------------------------------------------------
st_write(protected_union, out_gpkg, out_layer, delete_dsn = TRUE, quiet = TRUE)

cat("=====================================================================\n")
cat("AUDIT — protected_union (Decision 19)\n")
cat("=====================================================================\n")
cat(sprintf("  CPAD fee units (from 02c)              : %d  (%.1f km2)\n",
            nrow(fee_part), sum(fee_part$area_km2)))
cat(sprintf("  CCED easements, clipped to Bay Area    : %d  (%.1f km2)\n",
            n_cced_ba, area_cced_ba))
cat(sprintf("  Easement area overlapping CPAD fee     : %.1f km2  (erased, fee wins)\n",
            area_overlap))
cat(sprintf("  Easement-only area added by union      : %.1f km2\n", area_cced_diff))
cat(sprintf("  Easement features after difference     : %d\n", nrow(easement_part)))
cat("  ----------------------------------------------------------------\n")
cat(sprintf("  Union total features                   : %d\n", nrow(protected_union)))
cat(sprintf("  Union total area                       : %.1f km2\n",
            sum(protected_union$area_km2)))
cat("\n  Area by protection_type:\n")
print(protected_union |> st_drop_geometry() |>
        group_by(protection_type) |>
        summarise(n = n(), area_km2 = round(sum(area_km2), 1), .groups = "drop"))
cat(sprintf("\n  Written: %s :: %s\n", out_gpkg, out_layer))
cat("=====================================================================\n")
