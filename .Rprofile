source("renv/activate.R")
# Neutralise a stray PROJ/GDAL database inherited from another install
# (here: PostgreSQL/PostGIS) so sf and terra use their own bundled proj.db.
# Must run before any spatial package loads, which is why it lives in .Rprofile.
Sys.unsetenv(c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA"))

# Activate renv if it has been initialised (run renv::init() once, first time).
if (file.exists("renv/activate.R")) source("renv/activate.R")

# Fail loudly on partial matching and stringsAsFactors surprises
options(
  warnPartialMatchArgs = TRUE,
  stringsAsFactors     = FALSE,
  scipen               = 999
)
