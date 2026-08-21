# =============================================================================
# 00_setup_environment.R
# Installs and verifies the R spatial toolchain. Run once per machine.
#
# BEFORE running: open bay-area-wildcats.Rproj so the working directory is the
# repo root (this script uses the relative path R/00_config.R).
# AFTER it passes: run renv::init() then renv::snapshot() (see bottom).
#
# Windows prerequisite: install RTools matching your R version
#   https://cran.r-project.org/bin/windows/Rtools/
# The packages below ship as Windows binaries, so if install.packages() ever
# asks "install from source?", answer NO to take the prebuilt binary.
# =============================================================================

pkgs <- c(
  # Core spatial
  "sf", "terra", "exactextractr", "units",
  # Data access
  "rgbif", "rinat", "tigris", "elevatr", "osmdata",
  # Analysis
  "spatstat.explore", "spatstat.geom", "sfdep", "spdep",
  "unmarked", "AICcmodavg", "usdm", "leastcostpath", "gdistance",
  # Wrangling and reporting
  "tidyverse", "janitor", "gt", "ggplot2", "scales", "patchwork",
  "leaflet", "quarto",
  # Reproducibility
  "renv", "targets", "here"
)

missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing)

# leastcostpath / gdistance aren't needed until connectivity (Week 8); if either
# fails to install today it does not block verification -- proceed and revisit.
#
# AICcmodavg (mb.gof.test, aictab) is already in renv.lock -- it was used by the
# Week-6 bobcat null fit (04e) but was previously ABSENT from this pkgs vector, a
# latent manifest/setup gap. Declared here so the setup script and renv.lock
# agree. usdm (vifstep) is added for the Week-7 covariate-matrix VIF screen; the
# fit script also computes VIF manually via lm() and cross-checks the two.

# ---- Confirm we are running inside the project ------------------------------
if (!file.exists("R/00_config.R")) {
  stop("R/00_config.R not found. Open bay-area-wildcats.Rproj so the working ",
       "directory is the repo root, then re-run this script.", call. = FALSE)
}

# ---- Verify the underlying geospatial libraries -----------------------------
library(sf); library(terra)

cat("R version:      ", R.version.string, "\n")
cat("sf version:     ", as.character(packageVersion("sf")), "\n")
cat("terra version:  ", as.character(packageVersion("terra")), "\n")
cat("GDAL:           ", sf_extSoftVersion()[["GDAL"]], "\n")
cat("GEOS:           ", sf_extSoftVersion()[["GEOS"]], "\n")
cat("PROJ:           ", sf_extSoftVersion()[["PROJ"]], "\n")
cat("GDAL has GEOS:  ", sf_extSoftVersion()[["GDAL_with_GEOS"]], "\n")

# ---- Confirm the analysis CRS resolves --------------------------------------
source("R/00_config.R")                 # defines CRS_ANALYSIS (3310), CRS_WEB (4326)
crs_check <- sf::st_crs(CRS_ANALYSIS)
stopifnot(!is.na(crs_check$epsg))
cat("\nAnalysis CRS OK: EPSG:", crs_check$epsg, " - ", crs_check$Name, "\n", sep = "")

# ---- Functional test: PROJ must actually reproject, not just parse ----------
# Vector: WGS84 -> analysis CRS (generic Bay Area test point, not project data).
pt <- sf::st_sfc(sf::st_point(c(-122.271, 37.804)), crs = CRS_WEB)
xy <- sf::st_coordinates(sf::st_transform(pt, CRS_ANALYSIS))
stopifnot(is.finite(xy[1]), abs(xy[1]) > 1000)          # metres, not degrees
cat("Vector transform OK: (", round(xy[1]), ", ", round(xy[2]), ") m\n", sep = "")

# Raster: build a small grid in WGS84 and reproject to the analysis CRS.
r <- terra::rast(nrows = 10, ncols = 10,
                 xmin = -122.5, xmax = -122, ymin = 37.5, ymax = 38,
                 crs = paste0("EPSG:", CRS_WEB))
terra::values(r) <- seq_len(terra::ncell(r))
r_alb <- terra::project(r, paste0("EPSG:", CRS_ANALYSIS))
stopifnot(terra::ncell(r_alb) > 0)
cat("Raster reprojection OK: ", terra::ncol(r_alb), "x", terra::nrow(r_alb),
    " grid in EPSG:", CRS_ANALYSIS, "\n", sep = "")

# ---- Next step ---------------------------------------------------------------
cat("\nAll checks passed. Now run:  renv::init()  then  renv::snapshot()  ",
    "and commit renv.lock.\n", sep = "")
