# Data — acquisition and layout

How to reacquire every dataset this project uses. **No data is committed** —
`data/raw/**` and `data/interim/**` are gitignored. Most open data is scripted in
`scripts/01_download_open_data.R`; the bobcat background-effort download (row 10)
is acquired later in `scripts/03b_bobcat_background_effort.R` because it depends
on the occupancy design. All of it is re-downloadable from scratch; partner/gated
data is not redistributable and is described but not shippable.

- **Full dataset provenance** (versions, DOIs, licences, record counts, known
  issues): `docs/data-sources.md`.
- **Processing log** (what each script does, parameter values, QC): `docs/methodology.md` §4.
- **Numbered decisions** behind every source choice: `docs/methodology.md` §6.

---

## Conventions (apply to everything below)

- **Two-CRS discipline.** Sources arrive in whatever CRS they ship in; every
  layer is reprojected to **EPSG:3310** (NAD83 / California Albers) on import.
  Web-export copies (EPSG:4326) are made only at export, never for analysis.
- **Resampling by data type.** Categorical rasters → `near`; continuous rasters
  → `bilinear`. Vectors → `sf::st_transform()` (no resampling).
- **Filename convention.** Interim files end in their EPSG code
  (`*_3310.gpkg` / `*_3310.tif`).
- **Idempotent downloads.** Each block skips the download if the file already
  exists, so re-running the script is cheap.
- **Windows note.** `download.file(..., mode = "wb")` and `options(timeout = 600)`
  are set per block — the large zips exceed the 60 s default.

---

## Prerequisites

1. Clone the repo; open the R project.
2. `renv::restore()` — installs pinned package versions from `renv.lock`.
3. Confirm `.Rprofile` neutralises `PROJ_LIB` / `PROJ_DATA` / `GDAL_DATA`
   **above** renv's `activate.R` line (PostGIS `proj.db` conflict fix —
   methodology §3). Without it `terra::project()` fails with `[rast] empty srs`.
4. GBIF only: put `GBIF_USER` / `GBIF_PWD` / `GBIF_EMAIL` in your **user**
   `.Renviron` (never committed).
5. Run `scripts/01_download_open_data.R` top to bottom, or reacquire layer by
   layer using the table below.

## Directory layout

```
data/
  raw/          # as-downloaded, gitignored
    cpad/  cced/  gbif/  gbif_background/  inaturalist/  worldcover/  terrain/
    osm/  caltrans/  ghm/  silvis/
  interim/      # reprojected to EPSG:3310, analysis-ready inputs, gitignored
  restricted/   # partner data only, never committed (empty in Phase 1)
```

---

## Open layers (scripted — no gate)

Order matches `scripts/01_download_open_data.R`. The study-area boundary
(row 3) is built first in practice because it is the bbox/clip frame for
everything after it.

### 1. CPAD 2026a — protected areas (fee lands)
- **Source:** CPAD 2026a statewide release (GreenInfo Network), via data.ca.gov.
- **How:** direct zip → `data/raw/cpad/cpad_2026a_release.zip`, unzip in place.
  URL in `data-sources.md` §1.1 and in the script.
- **Ships as:** three shapefiles — Holdings (162,773) / Units (17,930) /
  SuperUnits (17,169). **Native EPSG:3310** — no reprojection.
- **Output:** `data/interim/openspace_cpad_bayarea_3310.gpkg` (occupancy frame,
  1,129 Units) — built Week 3: Units chosen as site unit (Decision 17), non-habitat
  filtered (Decision 18), clipped to the ten-county boundary. Also feeds the
  `fee` half of `protected_union_bayarea_3310.gpkg` (Decision 19).
- **Gotcha:** SuperUnits has **no `COUNTY` field** → the ten-county selection
  must be a spatial clip to the boundary (row 3), not an attribute filter.
- Decision 8.

### 2. CCED 2026a — conservation easements
- **Source:** CCED 2026a statewide (GreenInfo), via data.ca.gov.
- **How:** direct zip → `data/raw/cced/cced_2026a_release.zip`, unzip in place.
- **Ships as:** single shapefile, 23,645 easement polygons. **Native EPSG:3310.**
  No Holdings/Units/SuperUnits hierarchy.
- **Output:** `data/interim/protected_union_bayarea_3310.gpkg` — built Week 3.
  CPAD↔CCED integration resolved (Decision 19) as a **separate connectivity
  union** (not folded into the occupancy layer): `protection_type` {fee, easement},
  fee precedence on overlap. CCED contributes 1,275.7 km² of new protected land.
- **Caveat:** ~27% (6,363) have an "Unknown" holder — geometry valid, only
  matters for by-holder analysis. Coverage gap quantified, not supplemented.
- Decision 9.

### 3. Study-area boundary — TIGER/Line counties (`tigris`)
- **Source:** US Census TIGER/Line 2024, cartographic boundaries.
- **How:** `tigris::counties("CA", cb = TRUE, year = 2024)` → filter to the ten
  `STUDY_COUNTIES` (`R/00_config.R`) → reproject to EPSG:3310. Scripted.
- **Outputs (`data/interim/`):**
  - `boundary_baycounties_3310.gpkg` — 10 county polygons (`county`, `geoid`)
  - `boundary_baydissolved_3310.gpkg` — single clip mask / study outline
- **QC:** exactly 10 counties; dissolved land area **19,623 km²** (confirms
  `cb = TRUE` land boundary — a water-inflated `cb = FALSE` would be ~28,000 km²).
- **This is the bbox and clip frame for every layer below.** Decision 2.

### 4. GBIF occurrences — puma + bobcat
- **Source:** GBIF, both species, study-area bbox.
- **How:** `rgbif::occ_download()` (the citable/DOI path — **not** `occ_search`,
  which gives no DOI and caps at 100k). taxonKeys via `name_backbone()`;
  `hasCoordinate = TRUE`, `hasGeospatialIssue = FALSE`. Needs GBIF creds
  (prereq 4).
- **DOI:** https://doi.org/10.15468/dl.87ne3u (key `0013933-260721160103020`);
  saved to `data/raw/gbif/gbif_download_doi.txt`.
- **Output:** raw zip `data/raw/gbif/<key>.zip`. **Cleaned (Week 4, script 03):**
  GBIF ∪ iNat deduped on observation identity (not coordinates), split per species
  → `data/interim/occ_puma_clean_3310.gpkg`, `occ_bobc_clean_3310.gpkg`. GBIF
  contributes only its **non-iNat remainder** (17 puma / 209 bobcat pre-clip) —
  the iNat-sourced GBIF rows are a strict subset of the `.rds` (Decision 20).
- **Counts (pre-filter):** puma 1,843 · bobcat 5,164. Puma coords dominated by
  ~28 km iNat obscuring (median 28,240 m).

### 5. iNaturalist occurrences — puma + bobcat
- **Source:** iNaturalist research-grade, study-area bbox, captive dropped.
- **How:** `rinat::get_inat_obs(quality = "research", geo = TRUE, bounds = bbox,
  maxresults = 10000)`. No account. Obscuring fields preserved
  (`coordinates_obscured` → `obscured`, `taxon_geoprivacy`, `geoprivacy`,
  `public_positional_accuracy`).
- **Output:** `data/raw/inaturalist/inat_research_bayarea.rds`. **Cleaned
  (Week 4, script 03):** deduped with GBIF by observation identity, clipped, split
  per species → `occ_puma_clean_3310.gpkg` (2,031: 1,028 precise + 1,003
  obscured), `occ_bobc_clean_3310.gpkg` (6,232: 4,420 precise + 1,812 obscured).
- **Counts:** puma 2,102 (50% obscured) · bobcat 6,295 (31% obscured).
- **Load-bearing finding (Decision 10):** puma is **not** taxon-obscured in CA
  (0 taxon-obscured) → the project holds **1,028 precise puma points** (Week-4
  confirmed: 1,057 precise iNat pre-clip → 1,028 in study area). The
  `docs/sensitive-data-policy.md` ≥1 km publish floor / coarsening rules are
  therefore load-bearing, not precautionary. Heavy overlap with GBIF — **dedupe,
  don't sum.**

### 6. Land cover — ESA WorldCover 2021 v200
- **Source:** ESA WorldCover 10 m 2021 v200 (11 classes).
- **How:** windowed `/vsicurl` read of the public AWS COGs (no auth) — tile
  **N36W123** (+ N36W126 for the Point Reyes sliver); crop in-script. No manual
  download.
- **CRS:** EPSG:4326 → EPSG:3310, **nearest-neighbour** (categorical).
- **Output:** `data/interim/cov_landcover_worldcover2021_3310.tif`.
- **Caveat:** single flat "Built-up" class (urban **intensity** comes from row 9,
  not here). **Under-maps CA chaparral** — CAL FIRE FVEG is the targeted
  supplement if bobcat covariates need shrub. Decision 12 (amended from NLCD).

### 7. Terrain — AWS Terrain Tiles (`elevatr`)
- **Source:** AWS Terrain Tiles (Terrarium mosaic: 3DEP / SRTM / GMTED / others).
- **How:** `elevatr::get_elev_raster(locations = aoi, z = 12, src = "aws",
  clip = "bbox")` over the study area + 5 km collar. No account.
- **CRS:** EPSG:3857 → EPSG:3310, **bilinear** (continuous). Slope/aspect derived
  **post-projection** with `terra::terrain()` (degrees).
- **Outputs (`data/interim/`):** `cov_dem_terraintiles_z12_3310.tif`,
  `cov_slope_deg_terraintiles_z12_3310.tif`,
  `cov_aspect_deg_terraintiles_z12_3310.tif`.
- **Caveats:** **not** native 3DEP 10 m — effective ~30 m; the 15.1 m grid is a
  reprojection artefact. Sub-sea-level minima (−123 m) are coastal/bay/Farallones
  water voids, not bad tiles. 1 m lidar deferred. Decision 13.

### 8. Roads + traffic — Geofabrik OSM + Caltrans AADT
- **Roads source:** Geofabrik **NorCal** OSM extract (CA-statewide extract was
  stale 2014–2018 only → NorCal sub-region used).
- **How (roads):** download NorCal shapefile (zip-magic guarded); read
  `gis_osm_roads_free_1.shp`; reproject EPSG:3310; bbox pre-filter then
  `st_intersection` clip to the boundary (vector — no resampling). Write full +
  major/barrier subset.
- **Traffic source:** Caltrans Traffic AADT MapServer, 2023.
- **How (traffic):** pull as GeoJSON (`outSR=4326`); reproject EPSG:3310;
  `st_filter` to study area; write points.
- **Outputs (`data/interim/`):**
  - `cov_roads_osm_3310.gpkg` — all classes, 936,784 features
  - `cov_roads_osm_major_3310.gpkg` — motorway→secondary + links
  - `cov_aadt_caltrans_points_3310.gpkg` — 2,423 count stations
- **Caveats:** AADT is **state-highway only**; AADT volumes are **strings**
  (coerce/clean); Geofabrik has **no DOI** — pin by download date + server
  timestamp. Decision 14. **Covariate steps done (script 04b):**
  tracks/paths are not barriers for either species (Decision 24); the
  AADT→segment join parses the strings and assigns volume by a tiered scheme,
  each tier flagged in `aadt_source`:
  - **`measured_route_pm`** — state highways (motorway/trunk): route-line +
    postmile linear referencing, interpolating the bracketing count stations
    along the matched route (Decision 34). Highest confidence.
  - **`measured`** — point-snap station within 100 m (Decision 25).
  - **`name_fill` → `spatial_fill` (≤1 km, measured donor) → `modelled` (fclass
    floor)** — the local/arterial fallback chain (Decision 25). The spatial_fill
    upward bias is a data property (stations sample busy roads), not a join bug —
    it holds for local/arterial roads, which Caltrans does not postmile-reference.
  ~58% of major-road segments are station-traceable after Decision 34 (was 55.4%
  pre-fix). Outputs: `cov_roads_classed_3310.gpkg`, `cov_roads_traffic_3310.gpkg`
  (the latter now carries `aadt_source` incl. `measured_route_pm`, plus
  `route_pm_rte` / `route_pm_interp_dist_m` audit fields).
- **`ref` route-number field NOT retained (acquisition follow-up, Decision 34).**
  The `gis_osm_roads_free_1.shp` read (above) does not carry the OSM `ref` route
  tag through, so freeways arrive `name = NA`. Consequence: the AADT route match
  (Decision 34) identifies state highways by `fclass` + station proximity rather
  than exact route number, and outputs label freeways "route N (motorway)" rather
  than by name. **Deferred, non-blocking follow-up:** re-pull the NorCal roads
  preserving `ref` (it exists in the Geofabrik `.pbf`; the `gis_osm_roads_free_1`
  shapefile layer drops it — the `.pbf` via `osmextract`/`sf` with an explicit
  `ref` field, or the Geofabrik "roads" layer that retains it, would recover it).
  Would make the route match exact and label freeways properly. Not required for
  Phase 1 — the barrier ranking is already correct via the route-line match.

### 9. Human footprint — gHM v3 + SILVIS housing
> Load-bearing pair carrying the urban-**intensity** gradient WorldCover's single
> Built-up class can't (Decision 12). Methodology log is **§4.9**; the
> `data-sources.md` cross-ref to "§4.4" is CROS, not this — read as §4.9.

- **gHM source:** Global Human Modification **v3, 2022** (Theobald et al. 2024),
  "all threats" (AA) 300 m COG on Zenodo (DOI 10.5281/zenodo.14502573).
- **How (gHM):** windowed `/vsicurl` read off the **9.3 GB global** file (never
  downloaded whole) — crop to the 5 km-buffered AOI, mask, reproject EPSG:3310
  **bilinear**. A guarded, loud full-download fallback exists only if Zenodo
  refuses HTTP range requests. Real filename is
  `HMv20240801_2022s_AA_300.tif` (the script *description* mistypes it).
- **Housing source:** SILVIS **Block-Level Housing Density Change 1990–2020**,
  public-land-adjusted (PLA v4), California extract.
- **How (housing):** direct shapefile download
  (`CA_block20_change_1990_2020_PLA4_shp.zip`, PK-magic + size guarded);
  reproject **EPSG:5070 → EPSG:3310**; clip to study area (vector — no resample);
  keep `HUDEN1990`–`HUDEN2020`, counts, `PUBFLAG`.
- **Outputs (`data/interim/`):**
  - `cov_ghm_v3_2022_3310.tif` (300 m continuous 0–1)
  - `cov_housing_silvis_blocks_3310.gpkg` (blocks, density + `PUBFLAG`)
- **Caveats / Week-5 handling (now done, script 04):**
  - **PLA** moves houses *out* of protected areas → density inside CPAD units is
    near-zero **by construction** (reads as "edge pressure, not phantom houses";
    QC: `HUDEN2020` median by `PUBFLAG`, public-land median 0 confirmed).
  - **Sliver-block artifact:** `HUDEN2020` max ~2.26M units/km² (p90 ~3k) — tiny
    blocks with nonzero counts. Handling applied (Decision 23): winsorize at
    **study-area p99 = 10,415 units/km²** (913 blocks, 1.00%) then `log1p`,
    before rasterization.
  - **No WUI flags** in this product (separate SILVIS WUI dataset; not acquired).
  - **gHM × housing collinearity** resolved per species (Decision 23): unit grain
    r=0.07 (PLA artifact), grid grains r≈0.73–0.75. Puma resistance drops housing
    (keeps gHM); bobcat occupancy keeps both. gHM boundary-underlap edge-filled.
  - Citation swap: Kennedy et al. 2019 → **Theobald et al. 2024** (Decision 15).
  - Decisions 15 (gHM) and 16 (housing).

### 10. GBIF background effort — bobcat occupancy non-detections
> Acquired **Week 4** (script `03b`), not Week 2. This is not focal-species
> occurrence data — it is the **target-group effort layer** that supplies
> non-detection 0s for the bobcat occupancy detection history (Fork 3, Decision 22). A unit×year with any non-bobcat vertebrate record = the
> unit was surveyed; a bobcat absent from a surveyed cell = a real non-detection.

- **Source:** GBIF, **all datasets** (broad effort proxy — museum, eBird-via-GBIF,
  other surveys — not iNat-only), vertebrate classes, 2010–2026, bobcat excluded.
- **Why GBIF not `rinat`:** the pull spans *all* vertebrate observations over the
  study area — millions of records. `rinat`'s 10,000-cap made this impossible
  (county×month tiling still capped in City Nature Challenge months). GBIF's async
  download has no cap and filters server-side. Needs GBIF creds (prereq 4).
- **How:** `rgbif::occ_download()` — `pred_in("taxonKey", <Mammalia/Aves/Reptilia/
  Amphibia/Actinopterygii>)`, `hasCoordinate`, `!hasGeospatialIssue`, year range,
  `pred_within(<WKT>)`, `pred_not(speciesKey = 2435246)`. Footprint = the
  **dissolved 10-county boundary** simplified to ~300 m (~565 WKT vertices,
  EPSG:4326, CCW) — **not** the bbox (bbox pulled 42.8M records incl. ocean /
  Central Valley; boundary cut it to 33.0M). SIMPLE_CSV has `class` (name string),
  **no** `classKey`. Two-part script: submit (Part A) → wait → lean 5-column
  import (Part B).
- **DOI:** https://doi.org/10.15468/dl.6xzcjt (key `0006760-260806074905277`);
  saved to `data/raw/gbif_background/background_download_key.txt`.
- **Outputs (`data/interim/`):**
  - `cov_effort_gbif_mammal_unityear_3310.gpkg` (Fork 3A; 5,401 unit×year, 841 units)
  - `cov_effort_gbif_vertebrate_unityear_3310.gpkg` (Fork 3B; 12,505 unit×year, 1,072 units)
  - Each surveyed unit×year carries **two** effort fields: binary `surveyed = 1`
    **and** (Week-7 re-emit) graded `eff_nrec` = the **count** of non-bobcat
    background records in that cell. `eff_nrec` is the per-occasion detection
    covariate for the occupancy fit; it is an observer-intensity **proxy**
    (background volume, not bobcat survey effort). Re-run `03b` to regenerate both
    fields — Part B reads the existing zip on disk, no re-download.
- **Counts:** 33.0M pulled → 17.2M inside a CPAD unit; bird-dominated (32.7M Aves).
- **Caveats:** bird effort ≠ bobcat detectability → vertebrate-background naive
  detection rate 0.083 vs mammal 0.171, so the **mammal layer (3A) is
  target-group-correct** — confirmed at the Week-5 null fit: mammal (3A) fitted
  p=0.295 clears the §5.4 line; vertebrate (3B) lower. **Decision 22 CLOSED —
  occupancy confirmed on the 3A mammal background** (null fit scripts `04d`/`04e`;
  their output tables keep the `tbl_08`/`tbl_09` prefix by convention — the table
  number and the script number are independent counters). The Week-7 covariate fit
  (`06_occupancy_models.R`) then consumed the graded `eff_nrec` from these layers
  as the detection covariate and passed the pre-registered forward check (c-hat
  8.9 → 1.47; Decision 31). Boundary-simplification edge fuzz is negligible (the
  Part-B spatial join clips precisely to unit polygons). Absence of a unit×year
  row = not surveyed = NA, **never a fabricated 0.** Decision 22 (CLOSED);
  detected-but-unsurveyed cells upgraded per Decision 27 (a detection implies effort).

---

## Gated / parked (not scripted — do not assume redistributable)

### CROS — California Roadkill Observation System
- **Status:** **parked.** Data request sent to F. Shilling (UC Davis Road Ecology
  Center) 2026-08-02; awaiting terms. Decision 11.
- **Why gated:** no open bulk download and **no published licence / republication
  grant**. Registered users can export only their own observations; the full
  dataset is request-gated, and republication terms for derived maps are set in
  that request, not published. **Do not scrape; do not assume raw CROS points may
  be republished** on the public site without written confirmation.
- **When granted:** download per the agreed terms, document acquisition here and
  in `data-sources.md` §3.1, and record the granted republication scope.
- **Fallback if not granted:** cite the Road Ecology Center's published annual
  "California Wildlife–Vehicle Collision Hotspots" reports + the CA Wildlife Crash
  Map (publishable/citable without a raw-data request). CROS is a **threat
  overlay, not a Phase-1 backbone** — Week 2 can close with it explicitly parked.

### Felidae Conservation Fund — Wildpod camera stations
- **Status:** **deferred to a future phase** (Decision 7). No Felidae data is
  held in this repository.
- **Terms:** requires a written agreement first (`docs/sensitive-data-policy.md`
  §4). Precise station coordinates are **T3 restricted** — never committed, never
  published at native precision. If resumed, lands in `data/restricted/` only.
- Full characteristics for whoever resumes it: `data-sources.md` §6.1.

---

## Population context (reports, not spatial layers)

Not downloaded as data — cited as **context only, never as a trend**
(`docs/references.md`): the California Mountain Lion Project statewide abundance
estimate (~3,200–4,500) and the CDFW status review / CESA listing for the
Southern California / Central Coast population (Central Coast North = the Santa
Cruz Mountains, listed threatened by Commission vote **February 12, 2026** — an
earlier draft's "April 2026" was the next scheduled meeting; verified 2026-08-17).
No statewide bobcat estimate exists.
