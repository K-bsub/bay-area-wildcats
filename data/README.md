# Data

**No data is committed to this repository.** All open datasets are publicly
downloadable; partner data is restricted and non-redistributable.

## Directory roles

| Directory | Contents | Committed |
|---|---|---|
| `raw/` | Downloaded source files, never edited | No |
| `interim/` | Intermediate processing artefacts, safe to delete | No |
| `processed/` | Analysis-ready layers (`.gpkg`, `.tif`) | No |
| `restricted/` | Partner / sensitive data | **Never** |

`restricted/` is fully gitignored. Read `docs/sensitive-data-policy.md` before
placing anything in it.

## Acquisition

Most sources can be fetched with `scripts/01_download_open_data.R`. Sources
requiring manual download or a registration step are listed below with steps.

| Dataset | Method | Script / URL |
|---|---|---|
| CPAD / CCED | Manual download | https://www.calands.org/ |
| GBIF occurrences | Scripted (`rgbif`) | `scripts/01_download_open_data.R` |
| iNaturalist | Scripted (`rinat`) or web export | `scripts/01_download_open_data.R` |
| CROS roadkill | Manual — confirm data-use terms first | https://wildlifecrossing.net/california/ |
| 3DEP elevation | Scripted (`elevatr`) | `scripts/01_download_open_data.R` |
| NLCD land cover | Manual download | https://www.mrlc.gov/ |
| OSM roads | Manual download (Geofabrik) | https://download.geofabrik.de/north-america/us/california.html |
| Census TIGER/Line | Scripted (`tigris`) | `scripts/01_download_open_data.R` |

Record the access date, version and record count for every dataset in
`docs/data-sources.md` at download time.
