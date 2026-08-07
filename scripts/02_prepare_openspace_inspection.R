# =============================================================================
# 02_prepare_openspace.R  —  BLOCK 1: SCHEMA INSPECTION (read-only)
# =============================================================================
# Project : Wild Cats at the Urban Edge (Bay Area Wildcats)
# Purpose : Inspect acquired CPAD 2026a (Holdings / Units / SuperUnits) and
#           CCED 2026a as they actually sit on disk — geometry level, feature
#           counts, field names, CRS, geometry validity — so the Week-3 filter
#           and level-choice (Decision 17) are written against the real schema,
#           not the docs.
# Output  : PRINTS ONLY. Writes nothing, changes nothing, reprojects nothing.
# Run     : source this block, then paste the console output back.
# CRS     : expected native EPSG:3310 (verify, do not assume).
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
})

# ---- 0. Locate the data ------------------------------------------------------
# data-sources.md §1.1 says CPAD unzips in place under data/raw/cpad/ ;
# the Week-2 handoff mentioned data/interim/ . Check both, plus a couple of
# common spellings, and report what is actually found rather than assuming.

candidate_dirs <- c(
  "data/raw/cpad",
  "data/interim/cpad",
  "data/interim",
  "data/raw/cced",
  "data/interim/cced"
)

cat("=====================================================================\n")
cat("CANDIDATE DIRECTORIES\n")
cat("=====================================================================\n")
for (d in candidate_dirs) {
  cat(sprintf("  %-24s %s\n", d, if (dir.exists(d)) "[exists]" else "[missing]"))
}
cat("\n")

# Recursively list every shapefile under data/ so we see the true filenames
# (GreenInfo ships e.g. CPAD_2026a_Units.shp — capitalisation and prefix vary).
all_shp <- list.files("data", pattern = "\\.shp$", recursive = TRUE,
                      full.names = TRUE, ignore.case = TRUE)

cat("=====================================================================\n")
cat("ALL SHAPEFILES FOUND UNDER data/\n")
cat("=====================================================================\n")
if (length(all_shp) == 0) {
  cat("  (none found — check the working directory is the repo root, and that\n")
  cat("   the CPAD/CCED zips were unzipped in place)\n\n")
} else {
  for (f in all_shp) cat("  ", f, "\n")
  cat("\n")
}

# Also list any GeoPackages, in case a prior step already wrote one.
all_gpkg <- list.files("data", pattern = "\\.gpkg$", recursive = TRUE,
                       full.names = TRUE, ignore.case = TRUE)
if (length(all_gpkg) > 0) {
  cat("GeoPackages under data/ (layers listed):\n")
  for (g in all_gpkg) {
    cat("  ", g, "\n")
    tryCatch(
      { lyrs <- st_layers(g); for (i in seq_along(lyrs$name))
        cat(sprintf("       - %-30s (%s, %s features)\n",
                    lyrs$name[i], lyrs$geomtype[i], lyrs$features[i])) },
      error = function(e) cat("       [could not read layers:", conditionMessage(e), "]\n")
    )
  }
  cat("\n")
}

# ---- 1. Classify the found shapefiles by level ------------------------------
# Match on filename tokens; report what matched so nothing is silently miscast.
pick <- function(paths, pattern)
  paths[grepl(pattern, basename(paths), ignore.case = TRUE)]

cpad_holdings   <- pick(all_shp, "holding")
cpad_units      <- pick(all_shp, "unit")          # excludes superunit below
cpad_superunits <- pick(all_shp, "superunit")
# "unit" also matches "superunit" — separate them:
cpad_units      <- setdiff(cpad_units, cpad_superunits)
cced_shp        <- pick(all_shp, "cced")

cat("=====================================================================\n")
cat("LEVEL CLASSIFICATION (by filename token)\n")
cat("=====================================================================\n")
cat("  Holdings   :", if (length(cpad_holdings))   paste(basename(cpad_holdings), collapse=", ")   else "[none matched]", "\n")
cat("  Units      :", if (length(cpad_units))      paste(basename(cpad_units), collapse=", ")      else "[none matched]", "\n")
cat("  SuperUnits :", if (length(cpad_superunits)) paste(basename(cpad_superunits), collapse=", ") else "[none matched]", "\n")
cat("  CCED       :", if (length(cced_shp))        paste(basename(cced_shp), collapse=", ")        else "[none matched]", "\n\n")

# ---- 2. Inspector -----------------------------------------------------------
# For one shapefile: read WITHOUT loading all geometry first (query the layer),
# then read fully for validity/CRS checks. Prints schema, CRS, counts, validity,
# and a per-field completeness + sample-values summary for candidate filter
# fields. Nothing is written or altered.

inspect_layer <- function(path, label) {
  cat("=====================================================================\n")
  cat(sprintf("LAYER: %s\n", label))
  cat(sprintf("FILE : %s\n", path))
  cat("=====================================================================\n")

  if (length(path) == 0 || is.na(path) || !file.exists(path)) {
    cat("  [file not found — skipping]\n\n"); return(invisible(NULL))
  }

  # Lightweight metadata first (no full geometry read)
  meta <- tryCatch(st_layers(dirname(path)), error = function(e) NULL)

  x <- tryCatch(st_read(path, quiet = TRUE),
                error = function(e) { cat("  [read failed:", conditionMessage(e), "]\n\n"); NULL })
  if (is.null(x)) return(invisible(NULL))

  # --- CRS ---
  crs <- st_crs(x)
  cat("\n-- CRS --\n")
  cat("  EPSG      :", if (is.na(crs$epsg)) "NA (not tagged!)" else crs$epsg, "\n")
  cat("  Name      :", crs$Name, "\n")
  cat("  Is 3310?  :", identical(crs$epsg, 3310L), "\n")

  # --- counts / geometry ---
  cat("\n-- geometry --\n")
  cat("  Features  :", nrow(x), "\n")
  cat("  Geom type :", paste(unique(as.character(st_geometry_type(x))), collapse=", "), "\n")

  # bbox in native units
  bb <- st_bbox(x)
  cat("  bbox      : xmin", round(bb["xmin"]), " ymin", round(bb["ymin"]),
      " xmax", round(bb["xmax"]), " ymax", round(bb["ymax"]), "\n")

  # --- validity (guarded: can be slow on big statewide layers) ---
  cat("\n-- validity --\n")
  valid <- tryCatch(st_is_valid(x), error = function(e) NA)
  if (all(is.na(valid))) {
    cat("  [validity check errored or skipped]\n")
  } else {
    cat("  Valid     :", sum(valid, na.rm=TRUE), "/", length(valid), "\n")
    cat("  Invalid   :", sum(!valid, na.rm=TRUE),
        if (any(!valid, na.rm=TRUE)) "  <-- will need st_make_valid() before overlay" else "", "\n")
  }
  cat("  Empty     :", sum(st_is_empty(x)), "\n")

  # --- full field schema ---
  cat("\n-- fields (", ncol(x) - 1, "attributes ) --\n", sep="")
  flds <- setdiff(names(x), attr(x, "sf_column"))
  for (f in flds) {
    v <- x[[f]]
    cat(sprintf("  %-18s %-10s  non-NA %5d/%-5d\n",
                f, paste(class(v), collapse="/"),
                sum(!is.na(v)), length(v)))
  }

  # --- candidate filter / join fields: show distinct values ---
  # These are the fields Decision 17/18 depend on. Show cardinality + a sample
  # so we can see the real category vocabulary (access class, agency, GAP, etc.).
  cat("\n-- candidate filter/join fields (distinct value samples) --\n")
  candidate_tokens <- c("unit", "super", "hold", "name", "county", "cnty",
                        "access", "agncy", "agency", "mng", "mgmt", "own",
                        "gap", "desig", "type", "acc", "label", "id")
  cand <- flds[grepl(paste(candidate_tokens, collapse="|"), flds, ignore.case=TRUE)]
  if (length(cand) == 0) cat("  [no obvious candidate fields matched tokens]\n")
  for (f in cand) {
    v <- x[[f]]
    u <- unique(v)
    cat(sprintf("  %-18s  %d distinct\n", f, length(u)))
    if (length(u) <= 25) {
      cat("      values:", paste(utils::head(sort(as.character(u)), 25), collapse=" | "), "\n")
    } else {
      cat("      sample:", paste(utils::head(sort(as.character(u)), 12), collapse=" | "), " ...\n")
    }
  }

  # --- area distribution (for the min-area filter, Decision 18) ---
  # Only meaningful for polygons. Native CRS is metres (3310) if tagged.
  if (any(grepl("POLYGON", st_geometry_type(x)))) {
    a_km2 <- tryCatch(as.numeric(st_area(x)) / 1e6, error = function(e) NULL)
    if (!is.null(a_km2)) {
      cat("\n-- area (km2) distribution --\n")
      qs <- quantile(a_km2, c(0, .01, .1, .25, .5, .75, .9, .99, 1), na.rm=TRUE)
      for (i in seq_along(qs))
        cat(sprintf("  %-5s %12.4f km2\n", names(qs)[i], qs[i]))
      cat(sprintf("  Units < 0.1 km2 (pocket-park scale): %d of %d (%.1f%%)\n",
                  sum(a_km2 < 0.1, na.rm=TRUE), length(a_km2),
                  100*mean(a_km2 < 0.1, na.rm=TRUE)))
    }
  }

  cat("\n")
  invisible(x)
}

# ---- 3. Run inspection on each level ----------------------------------------
# Take the first match at each level (report if multiple matched).
first_or_na <- function(v) if (length(v)) v[1] else NA_character_

inspect_layer(first_or_na(cpad_holdings),   "CPAD 2026a — HOLDINGS")
inspect_layer(first_or_na(cpad_units),      "CPAD 2026a — UNITS")
inspect_layer(first_or_na(cpad_superunits), "CPAD 2026a — SUPERUNITS")
inspect_layer(first_or_na(cced_shp),        "CCED 2026a — EASEMENTS")

cat("=====================================================================\n")
cat("INSPECTION COMPLETE — nothing written. Paste this output back.\n")
cat("Key questions this answers for Decision 17/18:\n")
cat("  1. Which levels are present, with what real filenames + CRS tag?\n")
cat("  2. Do Units / SuperUnits carry a COUNTY field? (drives clip vs attribute)\n")
cat("  3. What are the real access/agency/ownership field names + vocabularies?\n")
cat("  4. What is the Unit-level area distribution? (min-area filter threshold)\n")
cat("  5. Any invalid geometry needing st_make_valid() before overlay?\n")
cat("=====================================================================\n")
