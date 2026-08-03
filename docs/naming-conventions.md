# Naming Conventions

R-based project. Conventions differ from the ArcGIS/geodatabase conventions used
in the tiger project — no PascalCase feature classes, no `.gdb`.

---

## 1. Species codes

Used as a token in every species-specific file, object and field name.

| Code | Species | Common name |
|---|---|---|
| `puma` | *Puma concolor* | Puma / mountain lion |
| `bobc` | *Lynx rufus* | Bobcat |
| `both` | — | Combined or comparative output |

Do not use `PUCO` / `LYRU` alpha codes — `puma` and `bobc` are more legible in
filenames and column headers.

---

## 2. Files and directories

- **snake_case throughout.** No spaces, no capitals, no hyphens in data files.
- Hyphens are permitted **only** in documentation filenames (`data-sources.md`),
  matching the tiger project convention.
- Pattern for data layers:

```
<theme>_<subject>_<qualifier>_<crs>.<ext>
```

Examples:

```
openspace_cpad_bayarea_3310.gpkg
boundary_baycounties_3310.gpkg
occ_puma_gbif_clean_3310.gpkg
occ_bobc_inat_research_3310.gpkg
cov_landcover_worldcover2021_3310.tif
cov_roads_osm_major_3310.gpkg
kde_bobc_current_1km_3310.tif
resist_puma_baseline_3310.tif
lcp_puma_diablo_to_hamilton_3310.gpkg
occ_both_felidae_stations_3310.gpkg   # T3 — data/restricted/ only, never committed
stats_felidae_station_unit_3310.gpkg  # unit-level summary; publishable after §3 review
```

**Restricted layers** keep the same naming rules but live under
`data/restricted/` and are never committed (see `docs/sensitive-data-policy.md`).
Naming does not make a layer safe to publish — placement and the §3 review do.
The two Felidae examples above illustrate the restricted / derived naming
pattern; Felidae itself is deferred to a future phase (Decision 7) and no such
layer exists in Phase 1.

**Theme prefixes:**

| Prefix | Contents |
|---|---|
| `boundary_` | Study-area and administrative boundaries (clip frame) |
| `openspace_` | Protected area / open space boundaries |
| `occ_` | Occurrence and detection records |
| `cov_` | Environmental and anthropogenic covariates |
| `kde_` | Kernel density surfaces |
| `hot_` | Hot spot (Gi*) results |
| `occu_` | Occupancy model inputs and prediction surfaces |
| `resist_` | Resistance surfaces |
| `lcp_` | Least-cost paths and corridors |
| `mort_` | Road mortality / roadkill |
| `stats_` | Tabular summaries |

**Always end data filenames with the EPSG code.** This is the single most
useful habit for avoiding silent CRS mistakes, and it replaces the ArcGIS
practice of `_UTM43N` suffixes.

---

## 3. Scripts

```
NN_verb_object.R
```

Two-digit prefix sets execution order. Examples:

```
00_setup_environment.R
01_download_open_data.R
02_prepare_boundaries.R
05_kde_and_hotspots.R
```

Function files in `R/` use the `00_functions_<domain>.R` pattern and are sourced,
never run standalone.

---

## 4. R objects

- **snake_case** for all objects and functions.
- Suffix spatial objects by type so their class is obvious at a glance:

| Suffix | Class |
|---|---|
| `_sf` | `sf` vector object |
| `_r` | `terra::SpatRaster` |
| `_v` | `terra::SpatVector` |
| `_ppp` | `spatstat` point pattern |
| `_nb` | spatial neighbours / weights |
| `_fit` | fitted model object |
| `_df` / `_tbl` | plain data frame / tibble |

Examples: `openspace_sf`, `landcover_r`, `occ_bobc_ppp`, `occu_bobc_fit`

- Functions are verbs: `read_cpad()`, `build_detection_history()`,
  `make_resistance_surface()`.

---

## 5. Fields / columns

- **snake_case**, lowercase.
- Units embedded in the name where relevant: `area_km2`, `dist_road_m`,
  `elev_mean_m`.
- Year suffix for temporal fields: `pop_2022`, `detections_2020`.
- Standard identifiers used across layers:

| Field | Type | Meaning |
|---|---|---|
| `unit_id` | integer | Stable ID for an open-space unit (join key) |
| `unit_name` | character | Open-space unit display name |
| `unit_name_std` | character | Standardised name for joins across sources |
| `county` | character | County name |
| `species` | character | `puma` or `bobc` |
| `source` | character | `gbif`, `inat`, `cros`, `felidae` |
| `obscured` | logical | Whether the source obscured the coordinate |
| `coord_uncert_m` | numeric | Coordinate uncertainty in metres |

---

## 6. Outputs

```
outputs/figures/fig_<nn>_<slug>.png
outputs/tables/tbl_<nn>_<slug>.csv
outputs/models/<species>_<model>_<date>.rds
```

Examples: `fig_03_bobcat_occupancy.png`, `tbl_02_unit_summary.csv`,
`bobc_occu_null_20260801.rds`

---

## 7. Git

- Branches: `main` (stable), `week-NN-<topic>` for working branches.
- Commit messages: imperative present tense, scope prefix.
  - `data: add CPAD 2026a download script`
  - `analysis: fit null occupancy model for bobcat`
  - `docs: record CRS decision`
