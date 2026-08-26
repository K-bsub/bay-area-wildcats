# Methodology

**Project:** Wild Cats at the Urban Edge — Pumas and Bobcats in SF Bay Area Open Spaces
**Author:** Kiran Balasubramanian
**Repository:** https://github.com/K-bsub/bay-area-wildcats
**Last updated:** August 9, 2026

> Living document. Every processing step, parameter value and analytical
> decision is recorded here as it happens, matching the convention established
> in the tiger project.

---

## Table of contents

1. [Project overview](#1-project-overview)
2. [Coordinate reference system](#2-coordinate-reference-system)
3. [Software environment](#3-software-environment)
4. [Data processing log](#4-data-processing-log)
5. [Analysis methods](#5-analysis-methods)
6. [Decisions and justifications](#6-decisions-and-justifications)
7. [Known limitations](#7-known-limitations)
8. [Reproducibility](#8-reproducibility)
9. [Change log](#9-change-log)

---

## 1. Project overview

Parallel analysis of two felid species across protected open space in the
ten-county San Francisco Bay Area:

| | Puma (*Puma concolor*) | Bobcat (*Lynx rufus*) |
|---|---|---|
| Analytical emphasis | Connectivity and isolation | Occupancy and distribution |
| Data density | Sparse | Abundant |
| Location sensitivity | High | Low |
| Home range scale | 100s of km² | 10s of km² |
| Grid resolution for modelling | 1 km (provisional) | 500 m (provisional) |

**Counties:** Alameda, Contra Costa, Marin, Napa, San Francisco, San Mateo,
Santa Clara, Santa Cruz, Solano, Sonoma.

> Santa Cruz is included (following the Conservation Lands Network ten-county
> definition) because the Santa Cruz Mountains puma population is central to
> the connectivity narrative. Confirmed — Decision 2; locked in
> `R/00_config.R` (`STUDY_COUNTIES`).

---

## 2. Coordinate reference system

**All analysis performed in:** EPSG:3310 — NAD83 / California Albers

| Property | Value |
|---|---|
| Projection | Albers Equal Area Conic |
| Datum | NAD83 |
| Units | Metres |
| Suitable for | Area, density and distance calculations statewide in California |

**Rationale:**
- Equal-area, which matters for density surfaces and per-unit area statistics.
- The de facto standard for California statewide and regional analysis; CPAD
  and most CDFW products are distributed in or aligned to it.
- Single CRS for the whole study area, unlike UTM which splits California
  across zones 10N and 11N.

**Raw data ingested in:** whatever the source provides (commonly EPSG:4326).
All layers reprojected on import. Vector via `sf::st_transform()`; raster via
`terra::project()` with `method = "bilinear"` for continuous data and
`method = "near"` for categorical data (land cover).

**Web delivery:** layers reprojected to EPSG:4326 at export only, in
`scripts/08_export_web_layers.R`. Analysis is never performed in 4326.

---

## 3. Software environment

| Component | Package | Role |
|---|---|---|
| Vector | `sf` | All vector I/O and geometry operations |
| Raster | `terra` | Raster I/O, reprojection, algebra |
| Zonal statistics | `exactextractr` | Fast, area-weighted zonal summaries |
| Kernel density | `spatstat.explore` | `density.ppp()` — KDE with edge correction |
| Hot spots | `sfdep` | `local_gstar_perm()` — Getis-Ord Gi* |
| Occupancy | `unmarked` | Single-species occupancy (`occu`) |
| Occupancy (multi) | `spOccupancy` | Multi-species / spatial occupancy (optional) |
| Connectivity | `leastcostpath`, `gdistance` | Resistance surfaces, least-cost paths |
| Data wrangling | `tidyverse` | Throughout |
| Occurrence access | `rgbif`, `rinat` | Programmatic data download |
| Reproducibility | `renv`, `targets` | Dependency lock, pipeline orchestration |
| Reporting | `quarto`, `ggplot2`, `gt`, `leaflet` | Figures, tables, story site |

Exact package versions are pinned in `renv.lock`. Verified environment on
first setup:

| Component | Version |
|---|---|
| Platform | Windows (x64), R 4.5.2 (2025-10-31 ucrt) |
| `sf` | 1.1.1 |
| `terra` | 1.9.27 |
| GDAL | 3.12.1 |
| GEOS | 3.14.1 |
| PROJ | 9.7.1 |
| s2 geometry | enabled (`sf_use_s2()` = TRUE) |

*Verified July 26, 2026 via `scripts/00_setup_environment.R` — both a vector
(`st_transform`) and a raster (`terra::project`) reprojection to EPSG:3310
succeeded.*

**Setup gotcha (recorded for reproducibility):** on the setup machine, `terra`
initially failed raster reprojection with `[rast] empty srs`. Cause: a stray
`PROJ_LIB`/`PROJ_DATA` environment variable from a PostgreSQL/PostGIS install
pointed PROJ at an old, incompatible `proj.db` (`LAYOUT.VERSION.MINOR = 2`).
`sf` was unaffected (it sets its own PROJ search path on load); `terra` inherited
the bad path. Fix: `.Rprofile` neutralises `PROJ_LIB`/`PROJ_DATA`/`GDAL_DATA`
before any spatial package loads, so `sf`/`terra` use their bundled `proj.db`.
This line must stay **above** renv's `activate.R` line in `.Rprofile`.

---

## 4. Data processing log

> One subsection per dataset, added as processing happens. Each records: date,
> input path, output path, steps with actual parameter values, record counts at
> each filter stage, and known issues.

### 4.1 Open space boundaries (CPAD/CCED)
*Status: downloaded and inspected — July 27, 2026. Clip to study area and level
choice deferred to Week 3.*

**Input:** `data/raw/cpad/cpad_2026a_release.zip` (unzipped in place) — CPAD 2026a
statewide; see `docs/data-sources.md` §1.1 and Decision 8.
**Output:** none yet. The analysis-ready open-space layer
(`openspace_cpad_bayarea_3310.gpkg`) is built in Week 3 after level choice, clip
and non-habitat filtering.

**Levels present (feature counts, statewide):**

| Layer | Features | CRS | `COUNTY` field |
|---|---|---|---|
| `CPAD_2026a_Holdings.shp` | 162,773 | EPSG:3310 | Yes |
| `CPAD_2026a_Units.shp` | 17,930 | EPSG:3310 | Yes |
| `CPAD_2026a_SuperUnits.shp` | 17,169 | EPSG:3310 | **No** |

- **CRS is already EPSG:3310** (NAD83 / California Albers) on all three — no
  reprojection needed for this layer.
- **Join keys / hierarchy:** Holdings → Units via `UNIT_ID`; Units → SuperUnits
  via `SUID_NMA` (present on all three). Name fields: `UNIT_NAME` (Units),
  `PARK_NAME` (SuperUnits), `SITE_NAME` (Holdings).
- **Fields useful for Week-3 filtering:** `ACCESS_TYP` (Open / Restricted / No
  Public Access), `ACRES` (size filter), `LAYER` (agency classification),
  `MNG_AGNCY` / `MNG_AG_LEV` (managing agency), `GAP1..4_acres` (GAP status —
  GAP 1/2 = managed for biodiversity); Holdings additionally has `LAND_WATER`
  and `SPEC_USE`.

**Notes carried to Week 3:**
- **Clip method:** SuperUnits has **no `COUNTY` field**, so if SuperUnits is the
  chosen level, the ten-county selection must be a **spatial clip** to the
  TIGER/Line boundary, not an attribute filter. A spatial clip is the safer
  choice at any level anyway (the `COUNTY` attribute can be blank or span
  multiple counties).
- **Level choice** (Units vs SuperUnits vs Holdings) and **non-habitat filtering**
  (pocket parks; ownership ≠ habitat; Risk 5) are Week-3 decisions.
- CPAD is an *ownership* inventory — inclusion does not imply conservation
  management.

**CCED 2026a (easements) — downloaded and inspected July 27, 2026:**
- Input: `data/raw/cced/cced_2026a_release.zip` → `CCED_2026a_Release.shp`.
- **23,645 easement polygons; EPSG:3310** (no reprojection). Single layer — no
  Holdings/Units/SuperUnits hierarchy.
- Key fields: `esmthldr` (easement holder), `eholdtyp`, `e_type`, `pubaccess`,
  `duration`/`term`, `county`, `gis_acres`, `GAP1..4_acres`, `iucncat`,
  `nced_uid` (link to the national NCED record).
- **Coverage gap — quantified, largely closed (Decision 9):** in 2026a,
  California Rangeland Trust is the 2nd-largest holder (1,865) and CDFW the 4th
  (988), so the standing "incomplete" disclaimer is largely historical. Not
  supplemented. NCED can't fill it (CCED is its CA feed). Attribute caveat:
  ~27% (6,363) have an "Unknown" holder — geometry present, still counts as
  easement land; only matters for by-holder analysis.
- **CPAD ↔ CCED integration is a Week-3 decision:** different schemas (CCED has
  no Units/SuperUnits and different fields). Options — keep easements as a
  separate overlay, or union CPAD+CCED into one protected-lands layer with a
  `protection_type` field (fee vs easement). The connectivity track likely wants
  the union; the open-space-unit/occupancy track may want CPAD only.

**Study-area boundary (TIGER/Line via `tigris`) — built July 27, 2026:**
- `tigris::counties("CA", cb = TRUE, year = 2024)`, filtered to the ten
  `STUDY_COUNTIES`, reprojected to EPSG:3310.
- QC: exactly 10 counties matched; dissolved land area **19,623 km²** —
  consistent with the ten-county land extent (a water-inflated `cb = FALSE`
  boundary would be ~28,000 km²), confirming the shoreline-clipped cartographic
  boundary.
- Outputs (`data/interim`, gitignored): `boundary_baycounties_3310.gpkg`
  (10 polygons: `county`, `geoid`) and `boundary_baydissolved_3310.gpkg`
  (clip mask).
- This is the clip frame for the Week-3 statewide-CPAD → ten-county clip and for
  every downstream layer. `cb = TRUE` (land) chosen over `cb = FALSE` (full legal
  extent incl. bay/ocean) so the study area is terrestrial.

### 4.2 Occurrence records — GBIF
*Status: downloaded and inspected — July 27, 2026. Cleaned, deduped against iNat,
and clipped — Aug 9, 2026 (script 03; Decisions 20/21). See "Week-4 processing
result" below.*

**Download:** `rgbif::occ_download()`, both species + study-area bbox +
`hasCoordinate = TRUE` / `hasGeospatialIssue = FALSE` (data-sources §2.1).
**DOI:** https://doi.org/10.15468/dl.87ne3u — GBIF.org, accessed 2026-07-27
(key `0013933-260721160103020`); saved to `data/raw/gbif/gbif_download_doi.txt`.
**Output:** raw only (`data/raw/gbif/<key>.zip`, gitignored). Cleaned/split
`occ_puma_gbif_*` / `occ_bobc_gbif_*` layers built in Week 4.

**Records (pre-filter, study-area bbox):**

| Species | n | HUMAN_OBS | PRESERVED_SPEC | MACHINE_OBS |
|---|---|---|---|---|
| Bobcat | 5,164 | 4,962 | 201 | 1 |
| Puma | 1,843 | 1,826 | 17 | — |

**Coordinate uncertainty (the headline finding):**

| Species | median | p90 | NA |
|---|---|---|---|
| Bobcat | 480 m | 28,447 m | 621 |
| Puma | 28,240 m | 28,447 m | 111 |

- **Puma occurrence data is dominated by coordinate obscuring.** Median ~28.2 km
  — the iNaturalist sensitive-species obscuring signature (both species' p90 pins
  to the same ~28,447 m obscuring-cell value; for puma it's the bulk, for bobcat
  only the top decile). This confirms puma cannot support density / occupancy /
  precise-habitat work and must lean on connectivity + coarse distribution
  (Decision 3, Risk 2) — the data validates the parallel-species architecture.
- **Bobcat is usable** (median 480 m) with a coarse tail (top ~10% at the
  obscuring value, plus 621 NA) to trim in Week 4.
- **HUMAN_OBSERVATION dominates** (bobcat 96%, puma 99%) — mostly iNaturalist, so
  the GBIF↔iNaturalist overlap (§4.3) is large; dedupe, don't sum.
- **Deep temporal range** (bobcat 1870–2026, puma 1896–2026) from museum
  specimens — a recent-year window is needed for a "current distribution" read.

**Week-4 filtering decisions (not prejudged here):** coordinate-uncertainty
threshold, recent-year window, `basisOfRecord` keep/drop, GBIF↔iNat dedupe, and
the precise clip from bbox to the ten-county polygon.

**Week-4 processing result (Aug 9, 2026 — script 03; Decisions 20/21):**
- **GBIF is almost entirely iNaturalist re-served.** Of 7,007 GBIF rows, 6,781
  are iNat-sourced (datasetKey `50c9509d-…`; `occurrenceID` carries the iNat
  observation URL). All 6,781 match an observation id in the iNat `.rds` — GBIF's
  iNat portion is a strict subset. GBIF's only additive contribution is its
  **non-iNat** remainder: **17 puma, 209 bobcat** (museum specimens, other
  datasets).
- **Dedupe is by observation identity, not coordinates** (Decision 20) — obscured
  puma coords are randomised and differ between feeds, so a coordinate dedupe
  would mismatch pairs.
- **No coordinate-uncertainty cutoff applied at the layer stage** (Decision 20,
  amended): `coord_uncert_m` is preserved from `coordinateUncertaintyInMeters`
  and left for per-analysis filtering. The recent-year window was also **not**
  applied — no date filter (Decision 21).
- GBIF's contribution flows into the combined per-species layers below (§4.3),
  not into standalone `occ_*_gbif_*` files.

### 4.3 Occurrence records — iNaturalist
*Status: downloaded and inspected — July 27, 2026. Cleaned, deduped with GBIF,
clipped, and written to per-species layers — Aug 9, 2026 (script 03;
Decisions 20/21). See "Week-4 processing result" below.*

**Download:** `rinat::get_inat_obs()`, research grade + study-area bbox, captive
dropped, obscuring fields preserved (data-sources §2.2).
**Output:** `data/raw/inaturalist/inat_research_bayarea.rds` (gitignored). Cleaned
`occ_*_inat_*` layers built in Week 4.

**Records (post captive drop):**

| Species | n | obscured | % obscured |
|---|---|---|---|
| Puma | 2,102 | 1,045 | 50% |
| Bobcat | 6,295 | 1,950 | 31% |

**Positional accuracy of the *non-obscured* records (`positional_accuracy`, m):**

| Species | n (open) | median | p90 | NA |
|---|---|---|---|---|
| Puma | 1,057 | 26 | 376 | 120 |
| Bobcat | 4,345 | 31 | 1,082 | 766 |

- **Obscuring is observer-driven for both species (decomposed July 27).**
  Bobcat: 1,949 user-set + 1 taxon (so ~entirely user privacy — residential-yard
  sightings). Puma: **1,045 user-set + 0 taxon.** So **iNaturalist does *not*
  taxon-obscure *Puma concolor* in California** — the ~50% obscuring is individual
  observers choosing geoprivacy, not iNat conservation policy. This overturns the
  inherited assumption (carried from the tiger project, where tigers *are*
  taxon-obscured); the "auto-obscured" framing was wrong for puma.
- **Consequence — the project holds ~1,057 genuinely precise puma locations.**
  This *raises* the sensitivity stakes rather than lowering them: a precise puma
  surface built from the open half would expose real hotspots, including near
  spots that obscuring observers deliberately hid. The sensitive-data-policy
  ≥1 km / unit-level coarsening is therefore **load-bearing** — see the flagged
  policy correction (policy §1 rationale currently mis-states iNat auto-obscuring
  as the reason).
- **The non-obscured puma pool is precise, not just open:** ~1,057 records,
  median positional accuracy **26 m** (p90 376 m; 120 NA) — the "not-obscured ≠
  precise" caveat mostly doesn't bite. This upgrades puma from connectivity-only
  to a plausible **coarse distribution** layer. Asterisks: counts are pre-dedupe
  (heavy GBIF overlap) and pre-clip, so the *unique* precise count settles in
  Week 4; bobcat's open pool is similar (median 31 m, p90 ~1 km).
- **iNat exceeds GBIF** (puma 2,102 vs 1,843; bobcat 6,295 vs 5,164): iNat-direct
  is fresher/less filtered, so not a pure subset — it holds a recent tail GBIF
  hasn't ingested. Still dedupe (GBIF primary); iNat adds that tail + the flags.
- Reconciles with §4.2: ~half+ of puma obscured explains the GBIF puma median
  sitting at the ~28 km obscuring value.

**Week-4 processing result (Aug 9, 2026 — script 03; Decisions 20/21):**
- **Schema note (recorded so re-runs don't trip on it):** the saved `.rds` is the
  *raw* `rinat::get_inat_obs()` output — a named list `list(puma, bobc)` of raw
  `rinat` columns (`id`, `scientific_name`, `coordinates_obscured`, `geoprivacy`,
  `taxon_geoprivacy`, `positional_accuracy`, `public_positional_accuracy`,
  `captive_cultivated`, …). The `tidy_inat()`/captive-drop in the download script
  was **not** persisted, so cleaning derives `obscured`, `captive`, `coord_uncert_m`
  and the species token from the raw fields in script 03. `geoprivacy` /
  `taxon_geoprivacy` use `""` (empty string) for "not set" — normalised to NA on
  load.
- **iNat `.rds` is the master for all iNat-sourced records** (Decision 20);
  combined 8,397 rows (puma 2,102, bobcat 6,295), all captive = FALSE. 1,616 iNat
  observation ids are present in the `.rds` but not in the GBIF snapshot — the
  fresher recent tail GBIF hasn't ingested, confirming iNat is not a pure subset.
- **Decision 10 confirmed empirically:** zero puma records carry
  `taxon_geoprivacy = "obscured"`; puma obscuring is entirely observer-set
  `geoprivacy` (967 with taxon NA + 78 with taxon "open"). One anomalous bobcat
  carries `taxon_geoprivacy = "obscured"` — flagged, kept as obscured, not
  special-cased (1 record).

**Combined cleaned layers written (GBIF ∪ iNat, identity-deduped, EPSG:3310,
clipped to `boundary_baydissolved_3310.gpkg`):**

| Layer | Total | Precise | Obscured | Sources |
|---|---|---|---|---|
| `occ_puma_clean_3310.gpkg` | 2,031 | 1,028 | 1,003 | iNat 2,017 + GBIF-non-iNat 14 |
| `occ_bobc_clean_3310.gpkg` | 6,232 | 4,420 | 1,812 | iNat 6,027 + GBIF-non-iNat 205 |

- Union before clip: puma 2,034, bobcat 6,504 (iNat combined 8,397 + 226 non-iNat
  GBIF = 8,623). Study-area clip dropped 360 rows (4.2%) falling in the bbox
  corners outside the dissolved ten-county boundary. Coordinate-validity drop: 0.
- **Risk 2 resolved:** the "~1,057 precise puma" figure holds — 1,057 precise iNat
  puma pre-clip → **1,028 precise after clip**, plus 14 precise non-iNat GBIF. A
  coarse puma distribution layer is viable alongside the connectivity backbone.
- Every record carries `source`, `species`, `obscured`, `coord_uncert_m`,
  `geoprivacy`, `taxon_geoprivacy` (see `docs/data-dictionary.md`).

### 4.4 Road mortality — CROS
*Status: terms confirmed — July 27, 2026; data request sent Aug 2, 2026 —
awaiting reply. Acquisition deferred (request-gated); not built into any published
output until republication terms are confirmed in writing.*

**Terms outcome (Risk 3 → Decision 11):** CROS publishes no open bulk download
and no reuse licence. Registered users can download only their own observations;
the full puma/bobcat dataset requires a request to the UC Davis Road Ecology
Center, and republication terms are set there, not published (data-sources §3.1).

**Phase-1 approach:**
- Request ten-county Bay Area puma + bobcat roadkill records from the Road
  Ecology Center, explicitly asking whether derived maps may be shown on a public
  GitHub Pages site (the republication question is the load-bearing term).
  **Sent Aug 2, 2026, 3:45 PM** to F. Shilling (Director, Road Ecology Center;
  fmshilling@ucdavis.edu) — awaiting terms.
- Until that clears, CROS is not built into any published output. Fallback
  (Risk 3): cite the Road Ecology Center's published hotspot reports / CA
  Wildlife Crash Map, and/or aggregate any granted data to road-segment level —
  never publish raw CROS points without a written grant.
- No scraping of the public map. CROS does not block Week 2 — covariates proceed
  in parallel.

**Quality (published):** ~13 m spatial accuracy; >97% species ID accuracy.

### 4.5 Covariates — land cover
*Status: downloaded and inspected — Aug 2, 2026 (ESA WorldCover; Decision 12
amended). Resampling to analysis grids deferred to Week 5.*

**Source/method:** ESA WorldCover 2021 v200 from public AWS COGs → `/vsicurl`
crop to the 5 km-buffered AOI → EPSG:3310, nearest-neighbour. Output
`data/interim/cov_landcover_worldcover2021_3310.tif` (~8 m post-reprojection;
native 10 m). Clean run, standard classes only.

**Class distribution (8 m cells; ×64 m² ≈ km²):**

| Class | Cells | ~km² |
|---|---|---|
| 10 Tree cover | 140.9M | ~9,020 |
| 30 Grassland | 113.1M | ~7,240 |
| 80 Water | 51.2M | ~3,280 |
| 50 Built-up | 32.5M | ~2,080 |
| 40 Cropland | 25.1M | ~1,600 |
| 90 Herb. wetland | 4.8M | ~300 |
| 20 Shrubland | 1.9M | **~123** |
| 60 Bare | 1.9M | ~120 |

(No 70 snow / 95 mangrove / 100 moss — expected for the Bay Area.)

- **Known limitation — WorldCover under-maps California chaparral.** Shrubland
  (20) at ~123 km² is implausibly low for the Bay Area; the NLCD pull (before it
  was abandoned) put shrub at ~3,200 km² — a ~26× gap. WorldCover folds
  Mediterranean chaparral into **tree cover** (open woodland/savanna → 10,
  inflating it to ~9,000 km²) and **grassland** (30). Chaparral is prime
  bobcat/puma cover, so this layer systematically mislabels a key habitat type.
- **Handling:** proceed with WorldCover for Phase 1 (clean, reproducible); flag
  the chaparral limitation wherever land-cover covariates are interpreted. If the
  bobcat occupancy covariates lean on shrub/chaparral, supplement the shrub class
  with CAL FIRE FVEG (Decision 12) — a targeted fix, not a full re-do.
- Built-up (50, ~2,080 km²) is the urban footprint; the developed-intensity
  gradient comes from the human-footprint layers (§4.7), not this layer.

### 4.6 Covariates — terrain (AWS Terrain Tiles via elevatr)

**Status:** ✅ Complete — August 3, 2026

**Source:** AWS Terrain Tiles (Terrarium mosaic — 3DEP / SRTM / GMTED / others),
via `elevatr::get_elev_raster(src = "aws", z = 12)`. **Not** native 3DEP 10 m —
see Decision 13 for the provenance correction.

**Input:** AWS Terrain Tiles, z = 12, fetched for the ten-county study area + 5 km
collar (`clip = "bbox"`).

**Outputs** (all EPSG:3310, `data/interim/`):

| File | Content | Unit |
|---|---|---|
| `cov_dem_terraintiles_z12_3310.tif` | Elevation | m |
| `cov_slope_deg_terraintiles_z12_3310.tif` | Slope (derived) | degrees |
| `cov_aspect_deg_terraintiles_z12_3310.tif` | Aspect (derived) | degrees |

**Resolution:** ~30 m effective at 37.7°N (Web-Mercator source); 15.1 m grid after
reprojection to EPSG:3310. The 15.1 m cell size is a reprojection artefact, not
real terrain detail — effective resolution remains ~30 m. Adequate for covariates
aggregated to the puma 1 km and bobcat 500 m grids.

**Processing steps:**
1. Load study-area outline; apply 5 km buffer (edge-correct slope/aspect).
2. `get_elev_raster(locations = aoi, z = 12, clip = "bbox")` → convert to `terra`.
3. Reproject to EPSG:3310 with **bilinear** (continuous data — contrast the
   nearest-neighbour used for categorical WorldCover, §4.5 / Decision 12).
4. Mask to buffered AOI.
5. Derive slope and aspect with `terra::terrain()` in degrees (post-projection,
   so gradients are computed in projected metres).
6. Write all three rasters (DEFLATE-compressed).

**Checks:**
- CRS EPSG:3310; resolution 15.1 m confirmed.
- Elevation range (buffered AOI): −123 m to 1,439 m. Max plausible (Hamilton
  range summits pulled in by the 5 km collar). Sub-sea-level minima are Terrarium
  water/void artefacts along the Pacific coast, SF Bay margins, and the Farallones
  — confirmed by plotting `dem < -20`; all non-terrestrial, none clustered over
  land. No re-fetch needed.
- Slope 0–75.7°, aspect 0–360° — within expected bounds.

**Known limitations:**
- Not native 3DEP; blended-source vertical accuracy not uniform (Decision 13).
- Water/void artefacts removed for free by the Week-5 clip to open-space units;
  optionally floored to `NA` below −20 m.
- 1 m lidar (3DEP QL2 / CA statewide) noted as an optional future-phase supplement;
  not acquired.

### 4.7 Covariates — roads and traffic

**Status:** ✅ Complete — August 3, 2026 (housing / human footprint still pending;
see §4.4 task list)

**Sources:** OSM road network via **Geofabrik NorCal** extract (`fclass`);
traffic volume via **Caltrans Traffic AADT** (2023). Source rationale — including
why NorCal not statewide, and why Geofabrik not osmdata/Overpass — in Decision 14.

**Outputs** (all EPSG:3310, `data/interim/`):

| File | Content | Features |
|---|---|---|
| `cov_roads_osm_3310.gpkg` | All OSM road classes, clipped | 936,784 |
| `cov_roads_osm_major_3310.gpkg` | Major/barrier subset (motorway→secondary) | subset |
| `cov_aadt_caltrans_points_3310.gpkg` | Caltrans AADT count stations, clipped | 2,423 |

**Processing steps:**
1. Download Geofabrik NorCal shapefile extract (guarded against non-zip response).
2. Read `gis_osm_roads_free_1.shp`; reproject to EPSG:3310.
3. Bbox pre-filter then `st_intersection` clip to the study-area outline (vector
   clip — no resampling).
4. Write full layer; write major/barrier subset (motorway, trunk, primary,
   secondary + links).
5. Pull Caltrans AADT as GeoJSON (`outSR=4326`); reproject to EPSG:3310;
   `st_filter` to study area; write points.

**Checks:**
- Roads: `fclass` present; 936,784 features; length-by-class table produced
  (service 35,112 km, residential 30,257 km, footway 24,064 km lead; motorway
  2,231 km / trunk 894 km form the core barrier network).
- AADT: 2,423 stations, not truncated (transfer-cap guard silent); 92% have a
  non-blank `AHEAD_AADT`; median ~68,000, max ~292,000 (freeway-scale, expected
  for a state-highway dataset).

**Known limitations:**
- **AADT is state-highway only** — county/city/local roads have no measured
  volume; Week 5 assigns an `fclass`-derived floor or model (Decision 14).
- **AADT volumes are strings** (commas / blanks) — coerce and clean before use.
- **Geofabrik has no DOI** — network pinned by download date + server timestamp;
  re-running later yields a different network.
- **Tracks/paths** may be permeable rather than barriers — resolved per species in
  Week 5 (Decision 14, open item 1).

**Deferred to Week 5 (covariate construction, not acquisition):**
- Tracks/paths permeability decision (per species; Decision 3 — never pooled).
- AADT→road-segment join / snap to weight the network by traffic.

### 4.8 Partner data — Felidae Wildpod stations
*Status: **deferred to a future phase** (Decision 7). Not used in Phase 1; no
Felidae data is held in this repository.*

Phase 1 uses the full ten-county open-space frame from open data only, so the
Felidae Wildpod inventory is not processed here. If resumed in a future phase it
re-enters as **T3 restricted** data under `docs/sensitive-data-policy.md` §4
(written agreement first). Characteristics noted during initial review, for
whoever picks it up: 218 stations; unique key `ID` (station names not unique);
untrusted `Park` labels (include private ranches); sub-regions Peninsula / East
Bay / South Bay plus an out-of-region Los Angeles group to drop; Latin-1
encoding. Association would use the staged point-in-polygon / nearest-unit
method — never a blanket large buffer.

### 4.9 Covariates — human footprint (human modification + housing density)

**Status:** ✅ Complete — August 3, 2026

This is the layer group Decision 12 points to as the carrier of the
urban-**intensity** gradient (WorldCover has only a flat "Built-up" class). It is
therefore load-bearing for the coexistence narrative, not context. Two datasets,
both continuous:

**Sources:** Global Human Modification **v3, 2022** (Theobald et al. 2024; AA =
all threats combined; 300 m COG on Zenodo; Decision 15) and SILVIS **block-level
housing density** 1990–2020 (PLA v4, California extract; Decision 16). Note both
choices deviate from the Week-2 plan wording — gHM is v3/2022 not Kennedy 2019,
and housing is SILVIS not a Census/`tidycensus` build; rationale in Decisions 15–16.

> Cross-reference correction: Decision 12 and §4.5 / §4.7 refer to the
> human-footprint layers as "§4.4". §4.4 is CROS (road mortality); the footprint
> layers are **§4.9** (this section). Read those pointers as §4.9.

**Outputs** (all EPSG:3310, `data/interim/`):

| File | Content | Type |
|---|---|---|
| `cov_ghm_v3_2022_3310.tif` | Human modification, 0–1 continuous | raster (300 m) |
| `cov_housing_silvis_blocks_3310.gpkg` | Housing density per census block (1990–2020) | vector (polygon) |

**Processing steps:**
1. gHM: windowed `/vsicurl` read of the 9.3 GB global AA COG (never downloaded
   whole), crop to the 5 km-buffered AOI, mask, reproject to EPSG:3310 with
   **bilinear** (continuous). Guarded loud fallback to a full download only if
   Zenodo refuses range requests.
2. SILVIS: download the CA state shapefile (PK-magic + size guard, as Geofabrik);
   reproject EPSG:5070 → EPSG:3310; bbox pre-filter then clip to the study area
   (vector — no resampling); retain density (`HUDEN1990`–`HUDEN2020`), counts
   (`HU2020`, `POP2020`, `POPDEN2020`), `PUBFLAG`, `WATER20`, `BLK20`.

**Checks:**
- gHM values confirmed within [0, 1]; study-area mean reported (an urban–wildland
  mix should sit well above a wildland-only mean). Out-of-[0,1] triggers a warning.
- Housing: block count and CRS reported; `HUDEN2020` median / p90 / max; and a
  standing **PLA check** — median `HUDEN2020` split by `PUBFLAG`, which should show
  public-land blocks near-zero by construction.

**Known limitations:**
- **gHM is 2022, 300 m** — coarser than the puma 1 km / bobcat 500 m grids in name
  only (adequate after aggregation); a single global product, not Bay-Area-tuned.
- **SILVIS is public-land-adjusted:** housing density inside protected areas is
  near-zero by construction, so density *at* an open-space unit is not a measure
  of housing *in* the unit but of the surrounding matrix. Interpret accordingly.
- **Small-area density artifact.** `HUDEN2020 = HU / area_km²`, so blocks with a
  tiny area and a nonzero housing count produce implausibly large densities
  (observed study-area max **2,263,007 units/km²**, ≈765× the p90 of 2,959;
  roughly the top few hundred blocks exceed 10⁵, ~76 exceed 10⁶). This is a known
  block-density artifact (single-structure / sliver blocks), **not** a SILVIS or
  download error — the acquisition is correct. The real distribution (~99% of
  blocks) sits between 0 and ~10⁴ units/km². Handling is pre-registered below,
  fixed before rasterization (do not decide the transform post-hoc).
- **No WUI classification** in the housing product — intermix/interface flags are
  a separate SILVIS dataset (Decision 16), not acquired.

**Week 5 — covariate construction (script `04_prepare_covariates.R`):** OK Complete
(2026-08-10). HUDEN2020 transform applied and rasterized; gHM×housing collinearity
measured; layer keep/drop = Decision 23.

- **HUDEN2020 transform (pre-registered, applied exactly as specified above).**
  Raw density winsorized at the study-area **p99 = 10,415 units/km²**, then
  `log1p` (cap-then-log, so the recorded ceiling stays in native units/km²).
  **913 of 91,223 blocks capped (1.00%).** The p99 landed essentially on the
  hard-10^4 line (988 blocks exceed 10^4), so the data-driven cap and the "no
  plausible block density exceeds ~10^4" reasoning converged — the pre-registered
  ceiling was not arbitrary. Reference hard-ceiling counts recorded, **not**
  applied (>10^4 = 988, >10^5 = 1, >10^6 = 1). `pubflag=1` near-zero density left
  as-is (PLA design, Decision 16), included in the distribution the p99 is
  computed over. Rasterized to both grids
  (`cov_housing_logden_puma_1km_3310.tif`, `cov_housing_logden_bobc_500m_3310.tif`)
  via a fine-burn-then-aggregate (block value -> ~50 m sub-grid -> mean to target
  cell; version-safe, seam-bias-free) and summarised per CPAD unit (area-weighted
  block->unit mean + within-unit SD; the area-weighted mean is the correct
  sub-cell summary for `spans_gradient` units, Decision 17). **0 units** had no
  overlapping block (no housing NAs).
- **gHM rasterized to both grids** (`cov_ghm_puma_1km_3310.tif`,
  `cov_ghm_bobc_500m_3310.tif`, `bilinear`, Decision 15) and summarised per unit
  (area-weighted mean + SD from the native 300 m source). **Edge-fill applied:**
  bilinear resampling left thin boundary-underlap NAs on land cells (source was
  cropped to the 5 km buffer) — 1,140 puma / 3,578 bobcat land cells. Filled from
  nearest valid neighbours, land-mask-bounded (never into water/off-study-area),
  leaving 6 puma / 3 bobcat isolated residual NAs (<0.03%). Surface extension to
  the analysis boundary, not interior gap-fill (0 interior holes confirmed).
  Per-unit gHM has 0 NAs (5 km buffer covers every in-study unit).
- **Per-unit footprint layer:** `data/interim/cov_unit_footprint_3310.gpkg`
  (`unit_id`, `spans_gradient`, `ghm_mean`, `ghm_sd`, `housing_logden_mean`,
  `housing_logden_sd`).
- **Collinearity (Decision 23):** gHM × housing log-density, per species (never
  pooled, Decision 3), at three grains — CPAD unit r=0.07, bobcat 500 m r=0.73,
  puma 1 km r=0.75 (post gHM edge-fill). Grains disagree because of the PLA design (below). Values in
  `outputs/tables/tbl_04_collinearity_footprint.csv`.

---

## 5. Analysis methods

> Methods defined here in advance; actual parameter values filled in as each
> analysis is run, matching the tiger project convention.

### 5.1 Open-space unit characterisation
Area, perimeter, shape index, elevation range, land cover composition,
edge-to-urban distance, and road density per unit.

**Week 6 — per-unit descriptive summary (script `05_kde_and_hotspots.R` PART 3):
Complete (2026-08-16).** Two tables, one per species, never pooled (Decision 3):
`stats_puma_unit_3310.csv` and `stats_bobc_unit_3310.csv`, keyed on `unit_id`
(1,129 units each). Each carries occurrence counts (precise inside+snapped and
total incl. obscured), the sparse/low-meaning obscured fraction (flagged — obscured
coords are randomised, so it is not a unit property), effort-year count,
coverage-weighted KDE mean and max per unit (`exactextractr`; NA where the unit
falls on masked KDE cells — ~300 units, "not covered" not "zero"), and the Gi*
class, z-score and Q5 flag. The bobcat table adds `bobc_detected` — the naive
per-unit detection collapse (1 detected / 0 surveyed-not-detected / NA
never-surveyed: 351 / 508 / 270), which is the naive observable, **not** modelled
occupancy ψ (a study-wide fitted scalar). These feed the story-site unit popups
and the methods cross-check.

### 5.2 Kernel density estimation
`spatstat.explore::density.ppp()` with Jones-Diggle edge correction
(`diggle = TRUE`). Puma on the 1 km grid, bobcat on the 500 m grid; the
dissolved study-area boundary is the observation window (`owin`).

**Week 6 — KDE (script `05_kde_and_hotspots.R`): Complete (2026-08-16).**
Bandwidth is chosen by a pre-registered rule, not hand-tuned (Decision 28).
Obscured-coordinate handling is precise-only for the published surfaces, with a
separate caveated obscured-puma companion (Decision 29). Three candidate
bandwidths are computed and printed; the chosen value follows a fixed rule
decided in advance and is recorded in
`outputs/tables/tbl_09_kde_bandwidth_selection.csv`.

- **Puma:** `bw.diggle` 48.8 m and `bw.ppl` 1,458 m both failed the rule (below
  the effort-collapse floor of home/3 = 1,667 m); the home-range prior **5,000 m**
  was used (rule 4). On 1,028 sparse precise points, both data-driven selectors
  chased observer clustering — the rule refused them. Output
  `kde_puma_current_1km_3310.tif`, precise-only, gated through
  `assert_publishable()`.
- **Bobcat:** `bw.ppl` **1,109.6 m** survived the rule (≥ 500 m cell, ≥ 500 m
  effort floor) and was the smallest survivor (rule 3); `bw.diggle` 36.8 m was
  rejected (sub-cell). Output `kde_bobc_current_500m_3310.tif`, precise-only.

**Same caveat as tiger Phase 1:** KDE of opportunistic records maps *detection
effort* as much as animal density. This is why the bandwidth rule rejects
effort-collapsed candidates, and why the raw KDE is cross-read against the
Fork-3 effort layer (proposal Q5) rather than published alone.

### 5.3 Hot spot analysis (Getis-Ord Gi*)

**Week 6 — Gi* + Q5 effort cross-read (script `05_kde_and_hotspots.R` PART 2):
Complete (2026-08-16).** `sfdep::local_gstar_perm()` on occurrence counts per
CPAD unit, per species, never pooled (Decision 3, Decision 30).

- **Grain:** CPAD unit (one tessellation) — matches the effort layer and the
  occupancy frame. Not the grid: the effort proxy exists only at unit grain (the
  GBIF background point cloud was not retained).
- **Neighbours:** fixed distance band = **6,342 m**, sized from the data so the
  mean unit has ~8 neighbours (the skew-reliability rule of thumb), unioned with
  a k = 8 KNN floor so no unit is stranded (408 units KNN-topped; final mean 11.5
  links; 32 sub-graphs). Gi* (star) includes self. Binary weights (count data).
  The neighbour-scheme history is recorded in Decision 30 (two corrections:
  queen contiguity → KNN → distance-band+floor).
- **Point→unit assignment:** three-way, grounded in each record's own
  `coord_uncert_m` (Decision 30): inside a unit / snapped if a unit lies within
  the point's own uncertainty / else matrix. Matrix points are retained as a
  separate finding (real signal for Q5 + connectivity), not discarded.
- **Inference:** 999 conditional permutations; Benjamini-Hochberg FDR on the
  folded permutation p-values; α = 0.05.
- **Results:** puma **47 hot / 430 cold**; bobcat **6 hot / 224 cold**; effort
  **104 hot / 112 cold**. Global G (QC, retained) is significant and positive for
  both species (puma z ≈ 31, bobc z ≈ 9.9, both p ≈ 0), confirming real
  clustering — so the local Gi* is behaving correctly and no detrending is
  warranted. Bobcat's lower hot-spot count is a spatial-arrangement finding, not
  an artifact (Decision 30 / §7): bobcat highs are spikier and more isolated
  (69% zero units, max 519, p99 = 29), so fewer form the jointly-high
  neighbourhoods Gi* requires; puma highs are moderate and spatially clustered
  (47 hot). Recorded in `tbl_10_gistar_q5_crossread.csv`.

**Q5 effort cross-read (first-class, not a caveat — the tiger-project Ranthambore
lesson).** A raw-count hot spot is partly an observer-effort hot spot. Gi* is run
a second time on the per-unit surveyed-year count (the retained mammal effort
layer), and each occurrence hot unit is labelled: `SUSPECT` if it is also an
effort hot spot, `TRUSTED` if it is not. This labels the counts for honest
reading; it does not "correct" them. Result: puma 25 suspect / 22 trusted; bobcat
2 suspect / 4 trusted. The effort proxy is bobcat-shaped (Decision 30 caveat); for
puma it is a looser general mammal-observer proxy.

**Same caveat as tiger Phase 1:** the counts reflect detection effort as well as
animal density — the Q5 cross-read is the explicit control, not a footnote.

### 5.4 Occupancy modelling
`unmarked::occu()`. Requires detection histories — repeated visits to fixed
sites. **Opportunistic GBIF/iNaturalist records do not natively provide this;**
either a spatial-replication design must be constructed and justified, or
Felidae detection histories obtained. This is the single largest methodological
risk in the project — see Decision log.

*As-built (Week 7, `06_occupancy_models.R`).* The bobcat covariate fit is done.
Detection sub-model fitted first (psi held `~1`), then occupancy with the
detection structure fixed — the standard `unmarked` two-stage order. Covariate
sets, standardisation and selection rule were pre-registered before any fitted
value was seen (Decision 31). Continuous covariates are centred/scaled on the
model matrix; the graded per-occasion effort proxy `eff_nrec` (from `03b`) enters
detection as `scale(log1p(eff_nrec))`. Selection is AICc with model averaging
across the ΔAICc ≤ 2 confidence set for the psi surface. Result: detection is
effort-driven (best model `p(~eff_nrec_s)`, ΔAICc to null 408); occupancy best
model `m_full` (terrain + land cover + human footprint), psi surface written to
`occu_bobc_pred_unit_3310.gpkg`.

*Forward check — CLOSED, passed (the Decision 22 commitment).* The pre-registered
check required the null-model collapsed 4-period MB-GOF c-hat (8.9) to decline
substantially once habitat covariates were added. It did: **covariate-model
c-hat = 1.47** (GOF p = 0.052). The null overdispersion was real habitat
heterogeneity absorbed by the covariates, not structural misfit — SDM fallback
stays untriggered. Recorded in `tbl_14_forward_check_chat.csv`.

### 5.5 Connectivity
Puma resistance surface from land cover, gHM, road class and terrain
(`resist_puma_baseline_3310.tif`, 1 km, 1–100; Decision 26, built `04c`; AADT
input corrected by Decision 34). Core patches = CPAD∪CCED union dissolved across
tenure, floored at 5 km² (Decision 32) → 164 core endpoints. Conductance object
`create_cs` (`cond = 1/R`, 16-neighbour, no DEM/max_slope; Decision 33). Primary
least-cost path **SC Mtns (1727) → southern Diablo (3972)**, 37.2 km through the
Coyote Valley / US-101 pinch (proposal Q3), widened into a two-tier cost-corridor
swath (core q2% / context q5%). Barrier crossings ranked within `aadt_source`
tiers; US-101 (142k measured) the top crossing. Sensitivity check 1
(road-confidence) STABLE. Circuit-theory (Omniscape/Circuitscape) remains an
optional extension, not a Phase-1 commitment. Every puma surface ≥1 km via
`assert_publishable()`; corridors publish as generalised geometry (policy §3).

*Sensitive-data gating — raster vs vector (note, 2026-08-20).* Puma export
protection uses TWO mechanisms, by data type. **Rasters** (`kde_puma_*`,
`resist_puma_baseline`, the corridor `costcorr` surface) pass `assert_publishable()`,
which checks the cell size against the 1 km sensitive floor (`terra::res`); this is
a RASTER-only check. **Vector corridor outputs** (LCP lines, swaths, crossings, the
core-connectivity network + weak-link swaths) are protected differently and
correctly: they are generalised boundary-to-boundary / band geometry derived from
the 1 km surface, carrying NO precise puma points, which satisfies
sensitive-data-policy §3 directly. `assert_publishable()` is deliberately NOT
called on the vector layers — it operates on raster resolution and does not apply
to lines/polygons. So the invariant is "every raster puma export is gated, and
every vector puma export is point-free generalised geometry", not "every export
calls assert_publishable()". Decision-35 sensitivity variant surfaces are never
written to disk (in-memory diagnostics), so there is no export to gate.

### 5.6 Road mortality analysis
CROS records intersected with the road network and open-space adjacency;
mortality hotspots compared against modelled corridor crossings.

### 5.7 Felidae station → open-space association
*Deferred to a future phase (Decision 7). Not part of Phase 1.* The staged
association method — point-in-polygon → nearest unit within a small tolerance →
unassigned, with no blanket buffer, and any home-range layer species-split — is
retained here for future use if the Felidae dataset is picked up.

---

## 6. Decisions and justifications

**Decision 1: R instead of ArcGIS Pro**
*Date:* July 23, 2026
*Decision:* Full analysis in R (`sf`/`terra` stack), no ArcGIS dependency.
*Justification:* (a) removes licence and ArcGIS Online credit constraints that
caused the tiger Phase 1 hosting problem; (b) `unmarked`/`spOccupancy` provide
occupancy modelling that ArcGIS does not offer, and occupancy is the correct
frame for camera-trap and detection data; (c) `renv` + scripted pipeline gives
stronger reproducibility than a documented click-path.
*Impact:* Naming conventions rewritten (see `docs/naming-conventions.md`);
GeoPackage replaces file geodatabase.

**Decision 2: Study area definition**
*Date:* July 26, 2026
*Decision:* Ten-county San Francisco Bay Area (Alameda, Contra Costa, Marin,
Napa, San Francisco, San Mateo, Santa Clara, Santa Cruz, Solano, Sonoma).
*Justification:* Follows the Conservation Lands Network ten-county definition and
keeps Santa Cruz in, where the Santa Cruz Mountains puma population anchors the
connectivity narrative. Locked in `R/00_config.R` (`STUDY_COUNTIES`) so every
script inherits the same frame.
*Impact:* The study area itself is the sample frame (see Decision 7); no
organisation-specific or arbitrary size-based frame is used.

**Decision 3: Species handled in parallel, never pooled**
*Date:* July 23, 2026
*Decision:* Puma and bobcat analysed as separate tracks with separate grid
resolutions and separate narrative arcs; no combined "felid" layer.
*Justification:* Detection probability, home range scale, data volume and
location sensitivity differ by roughly an order of magnitude between the two.
Pooling would let abundant bobcat records dominate any shared surface and would
force puma data to a resolution that is either too coarse to be useful or too
fine to be publishable.

**Decision 4: Felidae Wildpod scope — exclude out-of-region stations**
*[Deferred for Phase 1 — see Decision 7.]*
*Date:* July 25, 2026
*Decision:* Retain only Felidae stations within the ten-county study area.
Drop the entire `Los Angeles` sub-region (13 stations) and any Peninsula /
East Bay / South Bay station that falls outside the ten-county boundary after a
spatial clip.
*Justification:* The Wildpod inventory is statewide, not Bay-Area-only. The
`Los Angeles` sub-region sits ~500 km south (latitudes to ~33.6°N, Orange
County). Sub-region labels are Felidae's operational regions, not this
project's study-area definition, so a coordinate clip governs inclusion, not
the label.
*Impact:* ~205 of 218 stations are candidates before the clip; final count
recorded in §4.8 once processed.

**Decision 5: Station → open-space association — staged, not a blanket buffer**
*[Deferred for Phase 1 — see Decision 7.]*
*Status:* recorded; tolerances **pending confirmation.**
*Date:* July 25, 2026
*Decision:* Resolve station→unit identity by point-in-polygon, then nearest
unit within a small tolerance (default ≤1–2 km), then leave unassigned. Do
**not** use a single 10–20 mi (16–32 km) buffer to name a station's open space.
*Justification:* In the dense Bay Area a 16–32 km buffer returns dozens of
open spaces per station — it cannot identify "the" open space, and it would
manufacture associations for the many stations that are genuinely on private
or suburban land (68 `Park` names include working ranches). A large buffer is
only meaningful as a **home-range landscape-context** layer, which is a
different question and must be **species-split** (puma ≫ bobcat) to stay
consistent with Decision 3. Applying one buffer distance to both species would
violate the parallel-tracks principle.
*Open item:* confirm (a) the nearest-unit tolerance, and (b) whether a
home-range context layer is wanted, and at what radii per species.

**Decision 6: Felidae data provenance and agreement — pending**
*[Deferred for Phase 1 — see Decision 7.]*
*Status:* open — blocks any published Felidae-derived output.
*Date:* July 25, 2026
*Decision:* Treat the Wildpod CSV as T3 restricted immediately (done). Before
any Felidae-derived product is published — even coarsened — confirm the data
provenance and complete the written-agreement checklist in
`docs/sensitive-data-policy.md` §4.
*Justification:* The data was collected from Wildpod maps; it is not yet
established whether this was under a written agreement or from the public map.
Precise station coordinates are sensitive regardless of source. Analysis on the
restricted copy may proceed; publication of anything derived from it may not,
until §4 is satisfied.

**Decision 7: Felidae dataset deferred — full ten-county open-space frame**
*Date:* July 26, 2026
*Decision:* Phase 1 uses the full ten-county open-space inventory (CPAD/CCED) as
the sample frame, from open data only. The Felidae Wildpod dataset is not used
in Phase 1; it is deferred to a future phase (see project-plan Phase 3). No
Felidae data is held in the repository.
*Justification:* A whole-region open-data study is broader and more reproducible
than one scoped to Felidae's camera sites, and avoids tying the sample frame to
where one organisation happened to place cameras (a Peninsula-heavy,
effort-biased frame). It also removes the restricted-data provenance/agreement
dependency from the Phase-1 critical path.
*Impact:* Supersedes Decisions 4, 5 and 6 for Phase 1, and retires §4.8 and §5.7
to deferred status. Felidae remains a Phase-3 enhancement handled under
`docs/sensitive-data-policy.md` §4.

**Decision 8: Open-space source — statewide CPAD 2026a, not BPAD**
*Date:* July 27, 2026
*Decision:* Use statewide **CPAD 2026a** (Holdings / Units / SuperUnits) as the
open-space boundary source, clipped to the ten counties in Week 3. Easements come
separately from CCED (data-sources §1.2). BPAD is not used.
*Justification:* BPAD is GreenInfo's Bay-Area edition covering exactly the ten
counties (nine bay counties + Santa Cruz, the CLN definition) and it bundles
CCED, but its latest release is the 2025 edition — ~1 year staler than CPAD
2026a. CPAD 2026a is the freshest authoritative release, has a scriptable direct
download, arrives already in EPSG:3310, and keeps the documented CPAD/CCED split.
Clipping with the project's own TIGER/Line ten-county boundary is more
transparent and reproducible than relying on BPAD's county assignment.
*Impact:* One extra step (CCED merged separately; statewide clip in Week 3) in
exchange for freshness and transparency. BPAD remains a viable swap if
bundled-easement convenience later outweighs freshness.

**Decision 9: CCED used as-is — coverage gap quantified, not supplemented**
*Date:* July 27, 2026
*Decision:* Use CCED 2026a as the sole easement source for Phase 1; do not
supplement it to fill the historical CDFW / Rangeland Trust gap.
*Justification:* Quantified by `esmthldr` in the 2026a statewide data — California
Rangeland Trust is the 2nd-largest holder (1,865 easements) and CDFW the 4th
(988), so both are well-represented and the standing "incomplete" disclaimer is
largely historical. NCED cannot supplement (CCED is its California feed) and
remaining gaps are partly privacy-withheld, so unrecoverable from public data.
The real residual issue is attribute-level: ~27% of easements (6,363) have an
"Unknown" holder — geometry present and valid as easement extent, so no effect on
extent-based use.
*Impact:* No easement supplement in Phase 1; easement absence documented as "not
necessarily unprotected." If a specific Week-8 corridor later demands it, a
targeted CDFW/BIOS pull is the only clean option.

**Decision 10: Puma obscuring is observer-driven; precise puma data is held**
*Date:* July 27, 2026
*Decision:* Treat the sensitive-data-policy coarsening rules (≥1 km / unit-level
for puma outputs) as load-bearing, and correct the policy rationale accordingly.
*Justification:* Decomposing the iNaturalist geoprivacy fields (§4.3) shows
*Puma concolor* is **not** taxon-obscured in California — 0 of 2,102 records are
taxon-obscured, and 1,057 carry open, precise coordinates. The ~50% obscuring is
individual observers' choice, not iNat conservation policy. The project therefore
holds real precise puma locations; a precise puma surface would expose hotspots,
including near sites observers deliberately hid. This *strengthens* the policy
rather than relaxing it, and corrects the inherited (tiger-project) assumption
that iNaturalist auto-obscures the species.
*Impact:* `docs/sensitive-data-policy.md` §1 rationale corrected (the iNat
auto-obscure claim removed); the ≥1 km puma output floor and `assert_publishable()`
enforcement are retained and treated as essential, not precautionary.

**Decision 11: CROS is request-gated; terms confirmed before use**
*Date:* July 27, 2026
*Decision:* Do not scrape or bulk-download CROS. Obtain puma/bobcat roadkill via
a formal request to the UC Davis Road Ecology Center, and confirm in writing
whether derived maps may be published on the public story site before building
any published CROS output. Pending that, cite the published hotspot reports as
the fallback.
*Justification:* The CROS public site offers no open bulk download (own
observations only) and publishes no reuse licence or republication grant (Risk 3
anticipated this). Republishing raw roadkill points without a written grant would
breach the request-governed terms; citing published outputs and aggregating to
road segment is the safe fallback.
*Impact:* CROS acquisition deferred to a data request; off the Phase-1 critical
path (puma leans on connectivity; road mortality is a threat overlay). The story
site cites published Road Ecology Center outputs unless/until a data-sharing
agreement permits more.

**Decision 12: Land-cover source — ESA WorldCover (amended Aug 2, 2026; originally NLCD)**
*Date:* Aug 2, 2026
*Decision:* Use **ESA WorldCover 2021 v200** (10 m, 11 classes) as the land-cover
covariate. This replaces the original choice of Annual NLCD.
*Original choice (NLCD) and why:* NLCD was picked for its developed-intensity
gradient (Open Space / Low / Med / High), which suited the urban-edge narrative
and the puma resistance surface. WorldCover collapses human land into a single
"Built-up" class; FVEG is heavier, California-only, and weak on the developed
gradient.
*Why amended:* NLCD proved unacquirable via any clean route —
`FedData::get_nlcd_annual()` is pinned to the retired C1V0 files and rejects
newer versions; MRLC removed the flat S3 mosaics (now tiled + requester-pays);
the MRLC WCS exposes only 1985–2023 change *summaries* (and reading one crashed
the R session); and the NLCD Viewer export returned full-CONUS data with
undocumented class codes (100–104) covering real habitat (Mt Diablo). The cost
far exceeded the layer's value.
*WorldCover instead:* 10 m, CC-BY 4.0, on public AWS COGs (`s3://esa-worldcover`,
no auth) — genuinely scriptable via `/vsicurl`, cropped to the study bbox,
reprojected to EPSG:3310 with **nearest-neighbour**. Tiles N36W123 (+N36W126 for
the Point Reyes sliver). Citation: Zanaga et al. 2022, DOI 10.5281/zenodo.7254221.
*Trade-off handled:* WorldCover's single Built-up class means no developed
gradient — but the **urban-intensity gradient is carried by the Global Human
Modification index and housing density (§4.4)**, which are continuous and
arguably a better urban-edge signal than NLCD's four developed classes. So the
coexistence story is preserved; the "human intensity" job moves from land cover
to the footprint layers. FVEG remains a possible vegetation supplement.
*Impact:* `cov_landcover_worldcover2021_3310.tif` in `data/interim`.

**Decision 13 — Terrain source: AWS Terrain Tiles (elevatr z=12), not native 3DEP 10 m**
*Date:* August 3, 2026
*Decision:* Acquire terrain (elevation, slope, aspect) via `elevatr::get_elev_raster(src = "aws", z = 12)` rather than a native USGS 3DEP 1/3-arc-second product.
*Provenance correction:* `elevatr` with `src = "aws"` serves **AWS Terrain Tiles** — a Terrarium-encoded mosaic that blends multiple sources (3DEP, SRTM, GMTED, etc.), sampled by integer Web-Mercator zoom level. It is **not** a native "3DEP 10 m" grid, and the Week-2 plan's "3DEP (10 m)" wording is inaccurate as-built. At the study-area latitude (~37.7°N), z=12 has an effective ground resolution of **~30 m** in the source Mercator grid (`156543 × cos(φ) / 2^z`). After reprojection to EPSG:3310 with bilinear resampling, cells are **15.1 m**, but this is a resampled grid — it does not add real terrain detail, so effective resolution remains ~30 m.
*Justification:* ~30 m effective terrain is more than adequate for landscape-scale covariates aggregated to the puma 1 km and bobcat 500 m grids; finer source data (z=13, ~15 m) would ~4× the tile/pixel volume for no analytical gain at these grid resolutions. DEM reprojected to EPSG:3310 with **bilinear** (continuous data — contrast the `near`/nearest-neighbour used for categorical WorldCover, Decision 12). Slope and aspect derived post-projection in degrees via `terra::terrain()` so gradients are computed in projected metres, not degrees of lat/lon.
*1 m lidar:* USGS 3DEP QL2 / CA statewide lidar covers much of the Bay Area but is prohibitively large and unnecessary at this scale. Recorded as a known-issue supplement in `data-sources.md`; **not** acquired in Phase 1.
*QC:* buffered-AOI (5 km collar) elevation range −123 m to 1,439 m. Max is plausible (Hamilton range summits pulled in by the collar). Sub-sea-level minima are Terrarium water/void artefacts confined to the Pacific coastline, SF Bay margins, and the Farallones — all outside terrestrial open-space units and removed for free by the Week-5 clip-to-units. No bad-tile block over land; no re-fetch required.
*Outputs:* `data/interim/cov_dem_terraintiles_z12_3310.tif`, `cov_slope_deg_terraintiles_z12_3310.tif`, `cov_aspect_deg_terraintiles_z12_3310.tif`.
*Impact:* "3DEP 10 m" replaced by "AWS Terrain Tiles via elevatr, z=12 (~30 m effective)" wherever terrain provenance is stated (plan, data-sources, any figure caption). Filename tag `z12_3310` retained; resolution is documented in prose, not the filename.

**Decision 14 — Roads source: Geofabrik NorCal extract; traffic from Caltrans AADT**
*Date:* August 3, 2026
*Decision:* Acquire the road network from the **Geofabrik NorCal sub-region
shapefile extract** (OSM), and traffic volume from the **Caltrans Traffic AADT**
point service. Not osmdata/Overpass; not the CA-statewide Geofabrik extract.
*Why Geofabrik over osmdata/Overpass:* the `fclass` road-class field — the field
this project keys on, carried over from tiger-project convention — exists **only**
in Geofabrik's processed extracts. Raw OSM (what osmdata/Overpass returns) uses
`highway`, which would have to be re-mapped by hand. Overpass also risks timeouts
on a bbox as large and dense as the ten-county Bay Area.
*Why NorCal, not statewide:* Geofabrik publishes **no current statewide California
shapefile** — the CA download page explicitly directs to sub-regions, and the only
`california-*-free.shp.zip` files are stale 2014–2018 snapshots. The ten-county
study area sits entirely inside the **norcal** sub-region, which publishes a
current `-latest-free.shp.zip`. (First attempt at the statewide URL silently
returned a 9 KB HTML page; a `PK`-magic + size guard was added to the download so
a non-zip fails loud rather than limping on to `unzip`/`st_read`.)
*Reproducibility:* Geofabrik has no DOI and "latest" moves. Pinned by recording
download date + server `Last-Modified` in `data/raw/osm/geofabrik_download_stamp.txt`
(the closest analogue to the GBIF DOI). Documented as a known limitation.
*Roads output:* clipped to the study area in EPSG:3310 (vector — clip, no
resampling), two layers: `cov_roads_osm_3310.gpkg` (all classes, 936,784 features)
and `cov_roads_osm_major_3310.gpkg` (motorway→secondary barrier subset).
*Traffic (Caltrans AADT):* service is `CHhighway/Traffic_AADT` on a **MapServer**
(the layer *display* name "Traffic_Volumes_AADT" is not the service path; it is not
a FeatureServer). 2023 vintage. Pulled as GeoJSON, reprojected to EPSG:3310, clipped
to the study area → `cov_aadt_caltrans_points_3310.gpkg` (2,423 stations; median
AHEAD_AADT ~68,000, max ~292,000 — freeway-scale, as expected for a state-highway
dataset).
*Trade-offs / caveats recorded:*
  - **AADT is state-highway only** — no county roads, city streets, or local
    arterials. For barrier effects this is mostly acceptable (freeways are the
    barriers), but roads off the state network have no measured volume and will
    need an `fclass`-derived floor or model in Week 5.
  - **AADT volumes are stored as strings** (`AHEAD_AADT` / `BACK_AADT`,
    per-direction leg), with commas and blanks (~8% empty). Coerce to numeric and
    clean before use.
*Open items (deferred to Week 5, covariate prep):*
  1. **Tracks / paths permeability.** `track` (12,375 km) and `path` (6,452 km) are
     unpaved / low-or-no-traffic. For a puma/bobcat resistance surface they are
     arguably permeable, not barriers. Decide whether they count as "roads" in the
     connectivity context, per species (Decision 3 — never pooled). Not resolved here.
  2. **AADT-to-segment join.** AADT points must be spatially joined / snapped to
     road segments to turn "road present" into "road weighted by traffic." This is
     a covariate-construction step, not a download step.
  *Resolution (Week 5):* both open items closed — tracks/paths permeability =
  **Decision 24** (not barriers, per-species reasoning); AADT→segment join =
  **Decision 25** (4-tier parse/snap/propagate + fclass floor; spatial_fill bias
documented as a data property). See those decisions and the 2026-08-11 change-log
rows.
*Impact:* `data/interim/cov_roads_osm_3310.gpkg`, `cov_roads_osm_major_3310.gpkg`,
`cov_aadt_caltrans_points_3310.gpkg`. `osmdata` added to renv (kept available for
surgical follow-up queries even though the bulk pull is Geofabrik).

**Decision 15 — Human-modification source: gHM v3 (2022, Theobald 2024), not the Kennedy 2019 1 km layer**
*Date:* August 3, 2026
*Decision:* Acquire the human-modification gradient from the **Global Human
Modification v3, 2022** dataset (Theobald et al. 2024) — the "all threats
combined" (AA) 300 m cloud-optimised GeoTIFF on Zenodo — rather than the Kennedy
et al. 2019 1 km layer named in the Week-2 plan, and not the Google Earth Engine
asset.
*Why not the 2019 layer as planned:* the canonical Kennedy et al. 2019 gHM
(figshare, median year 2016, 1 km) ships as a GEE export / zipped raster with no
clean `/vsicurl` endpoint; the programmatic route everyone uses is the GEE asset
(`CSP/HM/GlobalHumanModification`), which requires an Earth Engine account and
`rgee`. That adds an auth dependency this project has deliberately avoided (only
GBIF is gated) and fails the "genuinely scriptable, no-auth" bar that led away
from NLCD in Decision 12.
*Why v3 instead:* Theobald et al. 2024 is public CC-BY, DOI-pinned
(10.5281/zenodo.14502573), distributed as COGs — so it is acquirable by the exact
windowed `/vsicurl` pattern already used for WorldCover — and more current (2022
vs 2016). The resolution change (300 m vs 1 km) is immaterial at the puma 1 km /
bobcat 500 m aggregation grids. Net: cleaner acquisition **and** a better layer;
the only cost is a citation swap (Kennedy et al. 2019 → Theobald et al. 2024),
recorded in `references.md` and `data-sources.md`.
*Acquisition detail:* the AA GeoTIFF is **9.3 GB global**. It is not downloaded —
it is read windowed via `/vsicurl`, cropped to the 5 km-buffered AOI, then only
that window is fetched (a few MB of range reads). A guarded, loud full-download
fallback exists solely for the case where Zenodo refuses HTTP range requests; it
warns about the 9.3 GB size rather than pulling silently. Filename in the record
*description* is mistyped (`HMv2024080101_`); the actual file is
`HMv20240801_2022s_AA_300.tif` — the real name is used, not the description's.
*Reproject:* EPSG:3310 with **bilinear** (continuous 0-1 metric — contrast the
`near`/nearest-neighbour used for categorical WorldCover, Decision 12).
*Role (per Decision 12):* gHM is load-bearing, not context — with housing density
it carries the urban-intensity gradient that WorldCover's single Built-up class
cannot. `terra` already in renv; no new package.
*Impact:* `data/interim/cov_ghm_v3_2022_3310.tif`. Supersedes the plan's
"Kennedy et al. 2019 gHM 1 km" wherever human-modification provenance is stated.

**Decision 16 — Housing density source: SILVIS block-level (PLA v4), California extract**
*Date:* August 3, 2026
*Decision:* Acquire housing density from the SILVIS **Block Level Housing Density
Change 1990–2020** product (public-land-adjusted, v4), California state shapefile
extract, keeping the pre-computed housing-density fields (`HUDEN1990`–`HUDEN2020`,
units/km²).
*Why SILVIS over a Census/`tidycensus` block build:* the state extract is a single
direct download (matches the CPAD/CCED idiom, no census-API key or per-decade
join), and housing **density** — the covariate actually wanted — is already
computed per block. Housing density is the second half of the urban-intensity
gradient (Decision 12); the AA gHM layer above is the first.
*Two caveats carried (both flagged, neither blocking):*
  - **"PLA" = public-land-adjusted.** SILVIS moves houses *out* of protected areas
    into neighbouring private blocks, so housing density **inside CPAD units is
    near-zero by construction**. For a coexistence covariate this reads as
    "pressure at the urban edge, not phantom houses inside open space" — arguably
    the right behaviour, but it must be understood when sampling density at a site
    (an open-space unit). The download reports median `HUDEN2020` split by
    `PUBFLAG` as a standing check on this.
  - **No WUI flags in this product.** The intermix/interface classification lives
    in a *separate* SILVIS "WUI 1990–2020" dataset (`WUIFLAG*` fields), not in the
    block-change file. So "density is baked in" is true; "WUI is baked in" is not.
    If the interface classification is ever wanted it is a distinct future pull —
    recorded here so the gap is explicit, not discovered later.
*CRS / geometry:* native CRS is **NAD83 / CONUS Albers (EPSG:5070)**, reprojected
to EPSG:3310 like every other layer. It is a **polygon** block layer — clip (not
mask), no resampling. Rasterising `HUDEN2020` onto a covariate grid is a Week-5
covariate-construction step, not part of this download.
*Attribution:* USDA Forest Service Northern Research Station / SILVIS Lab,
UW–Madison; acknowledgement requested (no restrictive licence).
*Impact:* `data/interim/cov_housing_silvis_blocks_3310.gpkg` (blocks clipped to
the study area, density + count + `PUBFLAG` fields retained).

**Decision 17: CPAD analysis unit — Units as the site, hierarchy carried as attributes**
*Date:* August 5, 2026
*Decision:* Use CPAD 2026a **Units** as the analysis "site" unit. Build the
canonical open-space layer from Units, carrying `suid_nma` (SuperUnit key) and,
where a per-Holding roll-up is needed, `holding_id` as attributes rather than
maintaining Holdings or SuperUnits as parallel site geometries.
*Justification:*
- **SuperUnits is nearly flat and loses key fields.** The 2026a schema has 17,169
  SuperUnits vs 17,930 Units — SuperUnit collapses only ~760 units (~4%), so it
  buys almost no aggregation. It also lacks a `COUNTY` field and drops the
  owner-agency and access attributes that Units and Holdings carry. No reason to
  pay that cost.
- **Holdings fragments habitat on ownership seams.** 162,773 parcels; splitting
  contiguous habitat on invisible tenure lines destroys site independence for
  occupancy and inflates N with correlated neighbours. Holdings is the
  *filtering* layer (see Decision 18), not the site.
- **Units matches how habitat is managed and experienced**, retains covariate
  variation a site needs, and the hierarchy keys already exist
  (`HOLDING_ID` → `UNIT_ID` → `SUID_NMA` are present on Holdings), so the
  roll-up needs no spatial join.
- **Per-track note:** the occupancy (bobcat) track uses Units directly as sites.
  The connectivity (puma) track does not use any CPAD level as its unit — it
  dissolves the CPAD∪CCED union (Decision 19) into habitat patches; the Units
  layer feeds patch-building, it is not the corridor input.
*Ten-county membership:* by **spatial clip** to `boundary_baydissolved_3310.gpkg`,
which is the source of truth. Units *do* carry a `COUNTY` field (58 distinct,
fully populated), but a Unit's `COUNTY` is a single label even where the polygon
straddles a county line, so the attribute is retained only as a secondary audit
check, not the selection method. (SuperUnits has no `COUNTY` field at all —
another reason it is not used.)
*Join discipline:* join Holdings↔Units on `UNIT_ID` (17,930 distinct = feature
count), never on `UNIT_NAME` (only 15,006 distinct — ~2,900 units share a name).
*Geometry:* 2 invalid Unit geometries and 3 invalid SuperUnit geometries found on
load; run `st_make_valid()` before any overlay.
*Impact:* Canonical layer is Unit-level. `openspace_cpad_bayarea_3310.gpkg` is
built from Units, filtered per Decision 18, clipped to the ten-county boundary.

*Large-Unit gradient flag (covariate pre-flag for Week 4/5).* A `spans_gradient`
boolean is written onto the layer, set `hab_area_km2 > 5.0 km²`, flagging **192 of
1,129 kept units (17%)**. This is **not a filter** — no units are dropped; the flag
tells the Week-4/5 covariate step that a single whole-unit mean is unsafe for
these large units (they span internal land-cover / terrain gradients — e.g. Henry
Coe at 237 km²) and to summarise by sub-cell instead. Threshold set against the
kept-unit area distribution (median 0.79 km², p90 8.7 km²): a ">1 km²" rule would
flag ~45% of units and lose triage value, so 5 km² was chosen to isolate the
~top-sixth large tail where the gradient concern is real.

**Decision 18: Non-habitat filtering — size floor on habitat area + Holdings-level non-habitat flag**
*Date:* August 5, 2026
*Decision:* Remove non-habitat open space from the analysis frame using a
**minimum-area floor applied to habitat area**, combined with a **non-habitat
flag derived at Holdings level** and carried onto Units. Non-habitat Holdings
inside an otherwise-good Unit are **flagged, not erased** — geometry is kept
intact and the information is carried as attributes (`nonhab_area_km2`,
`hab_frac`, `has_nonhabitat`).
*Filter definition (in order):*
1. **Flag non-habitat at Holdings level.** A Holding is non-habitat if:
   - `SPEC_USE` ∈ {`Golf Course`, `Cemetery`, `Community Garden`,
     `Community Center`, `Senior Center`, `Youth Center`} — the unambiguous
     developed/landscaped uses. **Not** excluded: `Trail Corridor`,
     `National Monument`, `HCP/NCCP`, `Arboretum/Botanical Garden`,
     `Planned Park` — these are habitat or conservation lands.
   - `LAND_WATER` = `Water` — submerged/open-water parcels (reservoir surface,
     bay); not terrestrial felid habitat. (`SPEC_USE` and `LAND_WATER` exist
     **only** on Holdings, which is why the flag is derived there.)
   - `AGNCY_TYP` / `MNG_AG_TYP` = `Cemetery District` — marginal (2 units) but
     free; included for completeness.
2. **Overlay flagged Holdings onto Units** and compute per Unit:
   `nonhab_area_km2`, total `area_km2`, and `hab_frac = (area − nonhab) / area`.
3. **Apply the size floor to habitat area:** drop Units with
   **habitat area < 0.10 km² (10 ha)**.
4. **Secondary non-habitat rule:** drop Units with `hab_frac < 0.5` (majority
   non-habitat, e.g. a unit that is mostly golf course) even if total area
   passes the floor.
*Justification:*
- **The size floor is nearly costless in area.** At Bay-Area Unit level, dropping
  everything < 0.10 km² removes 3,123 of 4,375 units (71% by count) but only
  ~1.0% of total open-space area (61.6 of 5,993.8 km²). The units removed are
  pocket parks, medians and tot-lots, not habitat. Thresholds tested:
  < 0.02 km² → 0.2% area; < 0.05 → 0.7%; **< 0.10 → 1.0%**. 0.10 km² chosen as
  the point where count-removal is high but area-loss is still ~1%.
- **`ACCESS_TYP` is deliberately NOT used as a filter.** Excluding
  `No Public Access` would remove 753.6 km² — **12.6% of total area** — because
  it captures water-district watersheds (SFPUC Peninsula), private ranch
  easements and closed preserves that are among the *best* felid habitat in the
  region. Access is retained as a descriptive attribute only. Habitat filtering
  keys on *what the land is* (special use, land/water, size), not *whether
  people can enter*.
- **Agency-type exclusions are marginal** (Cemetery District = 2 units; no
  Airport-typed units in the Bay Area CPAD). The filter is carried by size and
  `SPEC_USE`, not agency type. `School District` ownership is **not** blanket-cut
  — much school-adjacent green space is bobcat-permeable; those units stand or
  fall on the size floor and `hab_frac` like any other.
- **Flag-not-erase** keeps Units corresponding to real CPAD entities, preserves
  the `UNIT_ID`→`SUID_NMA` roll-up, keeps occupancy sites whole, and is
  reversible; the non-habitat signal is carried by covariates (WorldCover, gHM,
  housing) and by `hab_frac`, which is where it belongs analytically.
*Ordering (load-bearing):* flag at Holdings → overlay to Units → compute
`hab_frac` → apply floor to habitat area → apply `hab_frac` rule → dissolve.
Filtering must precede the dissolve, or interior non-habitat is swallowed and
becomes invisible.
*Audit trail:* log counts at each step (raw Bay-Area Units → after size floor →
after `hab_frac` rule → final), and record total habitat area retained.
*`hab_frac` cutoff — resolved.* Set at **0.50**, confirmed against the observed
distribution (no longer provisional). Of 303 study-area units containing any
flagged non-habitat, `hab_frac` is strongly **bimodal**: median 0.050, p75 0.951,
with almost nothing between — units are either essentially all non-habitat
(a golf course that is its own unit → `hab_frac ≈ 0`) or barely affected
(a large preserve with a small interior garden → `hab_frac ≈ 1`). The cutoff is
insensitive across 0.4–0.6: dropping at <0.4 removes 174 units, <0.5 removes 177,
<0.6 removes 183 — a 9-unit spread. 0.50 sits in the empty middle of the gap and
reads as "majority habitat," so the choice is not a fine judgment call.

*Observed result (August 5, 2026 run):* 4,375 raw Bay-Area units → 1,142 after the
0.10 km² habitat-area floor → **1,129 after the `hab_frac ≥ 0.50` rule**. The size
floor does ~99% of the filtering; `hab_frac` removes 13 additional
whole-unit-non-habitat cases. **4,660 km² habitat retained**; 106 final units
carry `has_nonhabitat = TRUE` (mostly-habitat units with a flagged interior
parcel — the flag-not-erase case). 1,129 sites is well above the ≥40-site
occupancy fallback floor (Risk 1), leaving headroom for Week-4 effort filtering.

**Decision 19: CPAD↔CCED integration — two frames, tenure preserved on the union**
*Date:* August 5, 2026
*Decision:* Do not fold CCED into the canonical open-space layer. Maintain **two
frames** from the same source data, serving the two analysis tracks:
- **Occupancy frame (bobcat):** CPAD Units only —
  `openspace_cpad_bayarea_3310.gpkg` (Decisions 17–18), unchanged. CCED
  easements are not added as sites.
- **Connectivity frame (puma):** a CPAD∪CCED **union**,
  `protected_union_bayarea_3310.gpkg`, carrying a `protection_type` attribute
  ∈ {`fee`, `easement`} with **fee precedence on overlap**.
*Justification:*
- **The tracks need different things.** For connectivity, an easement-held
  grazing parcel is permeable habitat to a wide-ranging puma regardless of
  tenure, so it belongs in the patch fabric. For occupancy, a CCED easement is
  not a survey-able unit with a detection history the way a named CPAD preserve
  is; adding easements as "sites" would manufacture pseudo-sites over private
  ranchland. Keeping two frames serves both without redundant geometry — the
  union is derived from, not a replacement for, the CPAD layer.
- **Tenure is preserved, not dissolved (Option b).** Much Bay Area connectivity
  land is easement-held ranchland; flattening fee and easement into one
  "protected" surface would erase exactly the signal the connectivity narrative
  leans on. `protection_type` keeps it queryable and mappable.
- **Fee precedence on overlap.** Where a CPAD fee parcel and a CCED easement map
  the same ground, the CPAD fee record is the authoritative, better-attributed
  protection statement; the easement is a tenure instrument layered on top. The
  union erases the CPAD footprint from CCED **before** merging (`st_difference`),
  so every area is attributed exactly once and the easement layer contributes
  only the ground CPAD does not already cover. This prevents double-counting of
  protected area and keeps the "additional easement land" interpretation clean.
*Inputs / integration form:*
- CPAD side: **filtered** Bay-Area Units from Decision 18 (fee land), tagged
  `protection_type = "fee"`. Using the filtered layer, not raw CPAD, so pocket
  parks and non-habitat do not re-enter through the union.
- CCED side: Bay-Area easements (spatial clip to the ten-county boundary, per
  Decision 17), tagged `protection_type = "easement"`, with CPAD fee geometry
  differenced out.
- CCED carries no Units/SuperUnits hierarchy (flat, one easement per row); it is
  matched on `e_hold_id`. Relevant CCED attributes retained: `eholdtyp`,
  `e_type`, `pubaccess`, `county`, `gis_acres`.
*Caveats carried forward:*
- The CCED coverage gap (Decision 9) is **not** closed by the union — the union
  labels tenure where CCED has data; absence of an easement still does not mean
  unprotected. State this wherever the union is used.
- ~27% of CCED easements have "Unknown" holder type (Decision 9); `eholdtyp` is
  kept as-is, not imputed.
*Output:* `protected_union_bayarea_3310.gpkg` — connectivity track only. The
occupancy frame remains `openspace_cpad_bayarea_3310.gpkg`.

*Observed result (August 5, 2026 run):* 1,129 CPAD fee units (4,720.8 km²) ∪
2,799 Bay-Area CCED easements (1,773.8 km²). Fee precedence erased **498.2 km²**
of easement area overlapping CPAD fee (~28% of raw Bay-Area CCED area — the
double-counting the difference prevents), and dropped 155 easements wholly inside
fee land. **CCED contributes 1,275.7 km² of genuinely new protected land — a ~27%
increase over the CPAD fee footprint** — confirming easements are a material part
of the connectivity fabric, not a rounding error. Union total: 3,773 features,
5,996.5 km² (fee 4,720.8 / easement 1,275.7).
*Area-definition note:* the 4,720.8 km² fee figure here is raw unit area
(`st_area`), which differs from 02c's 4,660.4 km² `hab_area_km2` (raw minus
flagged interior non-habitat). The ~61 km² gap is the flagged golf/garden/water
parcels inside kept units — two different area definitions, not a discrepancy.
Record both in the data dictionary.
*Downstream note:* the union is a tenure layer (fee/easement), not yet a
habitat-patch layer. Dissolving the 3,773 features into contiguous patches across
tenure boundaries is a Week-8 connectivity step, not Week-3 study-area prep.

**Decision 20: Occurrence dedupe on observation identity, not coordinates**
*Date:* 2026-08-09
*Decision:* Deduplicate GBIF∪iNat by iNaturalist observation ID, never by
coordinates. iNat research-grade records flow into GBIF, so the two feeds
overlap heavily (6,781 of 7,007 GBIF rows are iNat-sourced; all 6,781 match an
id in the iNat .rds). The iNat .rds is treated as master for all iNat-sourced
records; GBIF contributes only its non-iNat remainder (17 puma, 209 bobcat).
*Justification:* Obscured puma records receive randomised coordinates that
differ between the two feeds, so a coordinate-based dedupe would drop or keep
the wrong member of a pair. Observation ID is the only stable join key.
*Result:* Puma 2,031 (1,028 precise + 1,003 obscured); bobcat 6,232 (4,420
precise + 1,812 obscured), after study-area clip (360 rows / 4.2% fell outside
the dissolved 10-county boundary).
*No coordinate-uncertainty cutoff at the layer stage.* `coord_uncert_m` is
computed and preserved on every record (GBIF `coordinateUncertaintyInMeters`;
iNat `public_positional_accuracy`, falling back to `positional_accuracy`) but
is **not** used to filter the cleaned layers. Rationale: the defensible
threshold is analysis-specific — occupancy at 500 m, puma connectivity at 1 km
and any KDE each tolerate different positional error, so a single layer-stage
cutoff would either impose the strictest analysis's limit on all uses or discard
records a coarser analysis could use. Each downstream step filters on
`coord_uncert_m` (and `obscured`) to its own need; the interim layer stays
complete. Same flag-not-cut logic as the `obscured` handling (Decision 21).
*Impact:* Two layers written — occ_puma_clean_3310.gpkg,
occ_bobc_clean_3310.gpkg. Puma obscured records retained in-layer under a flag
(Decision 21), not cut. Coordinate-quality filtering is deferred to each
analysis, not applied here.

**Decision 21: Puma obscured records kept in-layer under a flag**
*Date:* 2026-08-09
*Decision:* Retain all puma records — precise (1,028) and obscured (1,003) — in
a single occ_puma_clean_3310.gpkg, distinguished by an `obscured` logical, with
no date filter. Do not split obscured records into a separate layer or drop them.
*Justification:* Puma is not taxon-obscured in California (Decision 10, confirmed
empirically: zero puma records carry taxon_geoprivacy = "obscured"; obscuring is
user-driven via geoprivacy). Obscured records still carry real presence
information at coarse resolution. Coarsening for publication is applied at export
time per sensitive-data-policy.md §3, not by cutting the raw interim layer.
*Impact:* Downstream steps filter on `obscured` as needed; the raw layer stays
complete.

**Decision 22: Bobcat track = occupancy
modelling, not SDM fallback**
*Status:* **CLOSED (2026-08-15) — occupancy confirmed on the 3A mammal
The Risk 1 feasibility gate (methodology §5.4) is assessed,
the pre-fit-testable criteria pass, and the Fork-3 background-effort layers are
now built (script 03b) — so a fittable detection history demonstrably exists.
The decision is **held open only on the pre-fit-unevaluable criteria** (fitted
detection probability p, parameter stability, GOF), which resolve at Week-7 fit.
The background *type* (mammal vs vertebrate) is also deliberately carried to the
fit rather than chosen now (see Fork 3 outcome below). Do not treat as final; do
not cite as closed in public-facing text.
*Gate assessed by:* `scripts/03a_bobcat_occupancy_gate.R` (diagnostic, no fit).
*Background built by:* `scripts/03b_bobcat_background_effort.R` (GBIF download,
DOI 10.15468/dl.6xzcjt).
*Provisional decision:* Proceed with **occupancy modelling** for the bobcat
track (proposal Q2), not the `maxnet`/ENMeval SDM fallback. Site = CPAD unit
(Decision 17 frame); temporal replicate = **calendar year**; analysis window
**2010–2026**.
*Evidence (recent window 2010–2026, the contemporary sample):*
- Site histories: **321 occupied units** ≥ 40 floor (8×). PASS.
- Repeat-visit sample: **194 units with ≥2 detection-years** ≥ 40 (5×) — the
  structure that normally kills opportunistic occupancy is present in force. PASS.
- Naive occupancy **ψ = 0.284** ∈ [0.10, 0.90], with margin; true ψ is higher
  (surveyed-unit denominator < all 1,129 units). PASS.
- Window is evidence-based: 2010–2026 retains **97%** of dated in-unit records
  (2,858 of 2,956); the pre-2010 museum tail is only 98 records (3%) and shifts
  ψ by <0.001 and the ≥2-bin count by 8 units — negligible. All-years vs recent
  are effectively identical, confirming the dataset is already contemporary.
*Criteria NOT evaluable at the gate (deferred to Week-7 fitting by construction):*
detection probability p < 0.10, parameter instability, MacKenzie-Bailey GOF.
The gate decides whether a defensible detection history **exists**; these three
are checked when the model is actually fit. If any fails at fit, the SDM
fallback is re-triggered then.
*Conditions carried with the draft:*
1. **Fork 3 dependency — SATISFIED (Aug 9).** Background effort built from GBIF
   (all datasets, vertebrate classes, dissolved-boundary footprint, 2010–2026,
   bobcat excluded; DOI 10.15468/dl.6xzcjt). Real non-detections now exist:
   surveyed unit×year cells with no bobcat = 0, unsurveyed = NA (never a
   fabricated 0). Two layers written — `cov_effort_gbif_mammal_unityear_3310.gpkg`
   (3A) and `cov_effort_gbif_vertebrate_unityear_3310.gpkg` (3B).
2. **Single-record units (non-blocking):** 114 of 321 occupied units (36%) hold
   one record — ψ-informative, p-uninformative. At fit their ψ leans on
   covariates. Documented, not a blocker.
3. **Detection-probability watch (Week-7):** naive detection rate under mammal
   background is 0.171 (above the §5.4 p<0.10 fallback line); under vertebrate
   background 0.083 (below it, but an effort artifact — see Fork 3 outcome). The
   *fitted* p, not the naive rate, is the actual §5.4 test.
*Fork 3 outcome (Aug 9) — background pull done, A-vs-B HELD to Week-7 fit.*
The pull reframed from `rinat` (fought the iNat 10k cap; City Nature Challenge
months capped even at week level) to a single GBIF async download (no cap,
server-side filter). Scope widened from iNat-only to **all GBIF datasets** — a
broader, more defensible effort proxy (museum, eBird-via-GBIF, other surveys),
though it shifts "iNat research-grade effort" to "any georeferenced vertebrate
occurrence." Both candidate backgrounds were built and previewed:
- **3A (mammal):** 5,401 eligible unit×year cells, 4,476 real non-detections,
  naive detection rate **0.171**, 697 units with ≥2 surveyed years.
- **3B (vertebrate):** 12,505 cells, 11,463 non-detections, naive rate **0.083**,
  1,022 units with ≥2 surveyed years.
- **3C (bobcat-only naive):** rejected — fabricates non-detections.
*Reading:* 3B's extra coverage is mostly bird effort (32.7M of 33M pulled
records are Aves), which shares little of a bobcat's detectability — its 0.083
rate is deflated by "surveyed" cells where no observer could plausibly detect a
bobcat. 3A is the target-group-correct choice (taxonomically similar, similar
detectability) and its 0.171 is the more honest rate. **Both layers are
retained** and the choice is deferred to the Week-7 fit, where the *fitted* p
under each background — not the naive rate — is the deciding §5.4 evidence.
Holding both costs nothing (layers already written) and avoids committing on a
preview statistic.
*If the gate had failed:* fall back to `maxnet`/ENMeval SDM (presence +
background, no repeat visits needed); proposal Q2 stands, only the method
changes. Recorded so the fallback path is not re-litigated.

*Close — the three fit-time criteria (null fit, scripts 04d–04e).*

Detection history: site = CPAD unit, occasion = calendar year 2010–2026, encoded
1 = surveyed+detected, 0 = surveyed+non-detected, NA = unsurveyed (Decision 22
draft; detected-cell upgrade per Decision 27). Built under both backgrounds ×
two detection sets; null `unmarked::occu(~1 ~1)` fit to each. Primary =
**mammal_precise** (3A target-group-correct, precise detections).

| Criterion (§5.4) | Result (mammal_precise) | Verdict |
|---|---|---|
| (1) Fitted detection p | **p = 0.295** (annual, per-visit) vs fallback line 0.10 | **CLEARS** (3×) |
| (2) Parameter stability | Converged; finite SEs; ψ = 0.464 identifiable | **PASS** |
| (3) MacKenzie-Bailey GOF | see below — null-model overdispersion | **not a fallback trigger** |

*On the GOF (the one that needs explaining).* Annual (17-occasion) MB-GOF was
**degenerate** — 590 unique detection-history patterns, mostly singletons, on
sparse opportunistic data inflate the Pearson statistic to a meaningless
c-hat ≈ 514 (a test artifact, not lack of fit). Collapsing occasions into **4
multi-year periods** (2010–13 / 14–17 / 18–21 / 22–26) cut the pattern space to
44 and made the test evaluable: **c-hat = 8.9, GOF p = 0.**

This c-hat is **expected null-model overdispersion, not a reason to reject
occupancy**, for a specific reason: the null model (`~1 ~1`) forces every unit to
share one occupancy and one detection probability. On data known to be
heterogeneous — occupancy varies with habitat, which IS the research question
(Q2) — a null model *must* show overdispersion; c-hat ≈ 1 would instead imply no
habitat signal to model and would undercut the occupancy premise. The §5.4 GOF
criterion asks whether a usable occupancy model can be built and estimated from
this history, not whether the intercept-only null fits well. It can: p estimates
cleanly, the model converges, ψ is identifiable, and 697 units carry ≥2 surveyed
years of repeat-visit structure.

*What the SDM fallback was for, and why it is not triggered.* The §5.4 fallback
(maxnet/ENMeval) is for the case where a defensible detection history cannot be
built or detection is too low to estimate. Neither holds: the history exists, is
correctly encoded (real 0s vs NA), and yields p = 0.295 with a stable, identifi-
able fit. The occupancy track (proposal Q2) proceeds.

*Background selected: 3A mammal.* Confirmed target-group-correct. 3B vertebrate
is bird-deflated — it marks nearly every unit surveyed nearly every year (1,072
sites, patterns dominated by Aves effort), giving a lower, less bobcat-relevant
detection signal (annual p = 0.197 vs mammal 0.295). Both were fit; 3A is retained
as the occupancy background. All four histories converged with p well above 0.10
(0.197–0.318), so the occupancy-vs-SDM verdict is robust to both the background
and the obscured-detection choice — the fork does not change the outcome.

*Pre-registered forward check (the commitment this close creates).* Null-model
overdispersion (c-hat ≈ 8.9) **must decline substantially once habitat covariates
are added** — that decline is the evidence the heterogeneity is real, modelled
signal rather than structural misfit. If covariate occupancy models still show
c-hat of this magnitude, that is a genuine lack-of-fit problem to be addressed
then (candidate causes: unmodelled spatial autocorrelation, detection covariates,
or effort-structure bias), and c-hat-inflated SEs would be reported. This is
logged now so the covariate-model GOF is a declared check, not a post-hoc rescue.

*Sensitivity results (all four histories, tbl_09_null_fit_criteria.csv):*
mammal_precise p=0.295 / mammal_all p=0.318 / vertebrate_precise p=0.197 /
vertebrate_all p=0.208 — all clear 0.10; all converged; all collapsed c-hat 8.6–10.1
(same expected null overdispersion). Obscured-detection inclusion (Decision 20/21)
lifts p ~0.02 and ψ ~0.05, changing no threshold — obscured records are immaterial
to the close, as designed.

**Decision 23 — Human-footprint pair: HUDEN2020 transform + gHM×housing keep/drop,
per species**
*Date:* 2026-08-10
*Status:* **CLOSED** (both parts).

*Part A — HUDEN2020 transform.* Applied the pre-registered §4.9 handling with no
post-hoc change: winsorize raw `HUDEN2020` at **study-area p99 = 10,415 units/km²**,
then `log1p`. **913 blocks (1.00%)** pulled to the cap. p99 chosen over the hard
10^4/10^5 alternatives because it is defined by the observed distribution, not an
asserted threshold — consistent with the project's "cutoffs from observed
distributions" standard. The p99 landing on the 10^4 line (988 blocks > 10^4)
confirms the two rationales converge; the sliver-block artifact (raw max
2,263,007 units/km², ~765× p90) is compressed into the distribution body before
rasterization. Cap-then-log keeps the recorded ceiling in native units. PLA
public-land zeros untouched (Decision 16).

*Part B — gHM × housing collinearity, resolved per species (Decision 3).*
Measured at the grain each track actually uses:

| Grain | Track | n | Pearson r | Spearman rho |
|---|---|---|---|---|
| CPAD unit | bobcat (occupancy) | 1,129 | 0.07 | -0.07 |
| grid 500 m | bobcat | 79,928 | 0.73 | 0.60 |
| grid 1 km | puma (resistance) | 20,372 | 0.75 | 0.64 |

*Why the grains disagree — the unit r~0 is a PLA artifact, not independence.*
SILVIS is public-land-adjusted (Decision 16): housing is moved *out* of protected
areas, so `housing_logden` is near-zero **inside** CPAD units by construction,
while gHM varies freely inside units. At the unit grain the two are therefore
**forced apart** by the adjustment (visible as a flat row of housing~0 across all
gHM in `fig_04_ghm_housing_scatter.png`), not genuinely decorrelated. Off
protected land — the grid grains — both track the urban gradient as Decision 12
predicted, giving the honest r~0.73–0.75.

*Resolution:*
- **Bobcat (occupancy):** covariate enters at the **unit** grain (r=0.07). **Keep
  both** gHM and housing — they are not collinear in the model matrix that is
  actually fit. **PLA caveat carried:** the per-unit housing covariate measures
  edge/matrix pressure around the unit, not housing within it (Decision 16); this
  is its intended coexistence reading, but must be stated wherever the bobcat
  housing coefficient is interpreted.
- **Puma (resistance/connectivity):** covariate enters at the **1 km** grain
  (r=0.75 >= 0.7). **Drop housing, keep gHM.** Rationale: (1) at r=0.75 both
  layers would double-weight the same urban penalty in the resistance surface;
  (2) gHM is the broader all-threats index, DOI-pinned, bounded 0–1, continuous
  Bay-wide; (3) SILVIS PLA makes housing actively unsuitable as a *resistance*
  input — it is near-zero inside the protected patches that are the corridor
  endpoints, precisely where a resistance artifact would distort least-cost paths.

*Impact:*
- Bobcat occupancy covariate set: gHM + housing (both, unit grain).
- Puma resistance stack: gHM only (housing dropped). `cov_housing_logden_puma_1km_3310.tif`
  remains on disk (not deleted) but is not carried into the resistance surface.
- No acquisition change; both source layers retained.

**Decision 24 — Tracks/paths permeability, per species**
*Date:* 2026-08-11
*Status:* CLOSED.

*Decision:* OSM `track` (12,375 km) and `path` (6,452 km) are **not barriers**
for either felid. The operational call converges but the reasoning is
per-species (Decision 3 — never pooled):
- **Puma (resistance/connectivity):** functionally crossable — a wide-ranging
  puma crosses an unpaved fire road or trail without measurable resistance.
  Encoding tracks/paths as barriers would sever corridors that are actually
  connected, biasing least-cost paths. -> permeable, background resistance.
- **Bobcat (occupancy):** also not a movement barrier. Any human-recreation
  *disturbance* signal a trail carries is already captured by gHM + housing
  density (Decision 23); re-encoding trails as barriers would double-count the
  same anthropogenic gradient. -> neutral.

*Operationalisation (`04b_roads_traffic.R`):* a `road_class` grouping
(highway / arterial / local / permeable) plus per-species barrier flags:
- `barrier_puma = road_class in {highway, arterial}` — arterials (primary/
  secondary) are traffic barriers for a dispersing puma.
- `barrier_bobc = road_class in {highway}` only — at the 500 m occupancy grain
  arterials are semi-permeable and their disturbance is carried elsewhere.
Tracks/paths (`permeable` class) are barriers for neither.

*Scope note — `permeable` supersedes the Decision 14 track+path figures.* The
`permeable` class here is broader than D14's "track (12,375 km) + path (6,452 km)
= ~18,800 km": it also includes `footway`, `cycleway`, `steps`, `bridleway`, all
equally non-barriers. Observed permeable total = **45,482 km / 341,737 features**.
This supersedes the D14 track+path-only count; the larger figure is the full set
of non-barrier ways, not an error.

*Impact:* the permeability flags feed the puma resistance surface (barrier_puma)
and are available as a bobcat occupancy covariate (barrier_bobc) without
re-deriving road class. No road segment dropped.

**Decision 25 — AADT -> road-segment join; fclass floor for off-network segments**
*Date:* 2026-08-11
*Status:* **CLOSED.** Join method, 4-tier propagation, spatial_fill bias (data
property), and fclass floor all resolved. AADT→resistance treatment deferred to
the resistance pre-registration.

*Problem.* Caltrans AADT is 2,423 POINT count stations, **state-highway network
only**, with volumes stored as STRINGS (`AHEAD_AADT` / `BACK_AADT` per leg,
commas + ~8% blank). The roads pull dropped `ref` (route number), so there is no
attribute key linking a station to a named route — the join must be spatial.

*Join method (CLOSED).*
1. Parse both leg strings -> numeric (strip commas/whitespace; blanks -> NA).
   All 2,423 stations parsed to a finite volume (0% blank in this vintage).
2. Per-station volume = **max(AHEAD, BACK)** — the peak traffic a crossing animal
   faces; the conservative barrier choice (vs mean).
3. Snap each station to the nearest MAJOR segment within **100 m** — 2,413 of
   2,423 snapped (99.6%).

*Why a single snap is not enough — and the propagation fix.* The 2,413 snapped
stations land on only ~1,856 of 79,804 OSM segments (**2.3%**), because OSM chops
each highway into hundreds of short segments and a point station only stabs the
one it sits on. Assigning traffic to just those segments would leave a resistance
surface ~98% driven by the fclass floor, gutting proposal Q3 (volume, not
presence, drives the barrier). AADT is therefore propagated in tiers, each
recorded in `aadt_source`:

- **measured** — a station snapped directly to the segment (median of stations).
- **name_fill** — unmeasured segment inherits the median measured AADT of all
  same-`name` segments (traffic is ~constant along a named route between
  interchanges). Named routes only.
- **spatial_fill** — remaining unmeasured segments take AADT from the nearest
  already-resolved segment of the **same `road_class`** within **2 km** (catches
  unnamed / name-mismatched state-highway segments without bleeding across road
  classes).
- **modelled** — only segments still unresolved fall to the fclass floor.

*Off-network floor (accepted).* Segments never resolved to a station receive an
**fclass-derived floor**, flagged `aadt_source = "modelled"`. Floor values
reviewed and **accepted** (2026-08-11) — after the measured-only donor rule
below, the floor carries 44.6% of major segments, but the resistance mapping bins
AADT so class-scaled floors are adequate. Coverage after propagation:
station-traceable = 55.4% of major segments (measured 1,856 / name_fill 22,505 /
spatial_fill 19,851); modelled floor = 44.6% (35,592 segments).

*Known data property — AADT station placement biases interpolated volume HIGH.*
The spatial_fill tier was found to skew high (arterial spatial_fill median ~41k
vs measured 27k; highway ~142k vs 117k) **even after** restricting donors to
`measured` segments only and tightening the donor cap to 1 km (observed donor
distance: median 197 m, p90 843 m). The cause is not the join method but the
**sampling design of AADT itself**: Caltrans places count stations on
high-traffic locations (interchanges, urban arterials, chokepoints), so the
measured network is a volume-biased sample of the road network, and any
measured→unmeasured inference (name_fill or spatial_fill) inherits that upward
bias. This is documented as a **data property, not a correctable join error** —
no interpolation removes a biased sample. The `aadt_source` flag
(measured / name_fill / spatial_fill / modelled) is retained on every segment so
the **resistance-assignment decision** can treat each tier at a different
confidence (e.g. bin AADT to barrier classes before use, so a 41k-vs-27k arterial
difference need not cross a resistance bin). *The AADT→resistance treatment is
deferred to the puma resistance-assignment pre-registration, where it belongs.*

*Donor rule (recorded).* spatial_fill donates ONLY from `measured` segments
(never from name_fill or a prior spatial_fill) to prevent inflated route-medians
chaining outward; cap 1 km. This dropped station-traceable coverage from an
earlier 88.7% (2 km, any-resolved donor) to 55.4% — the lost coverage was the
biased coverage, so the reduction is an honesty gain, not a regression.

First-pass floor (vehicles/day, order-of-magnitude by class, all below the
state-highway measured median ~68,000):

| fclass | floor | fclass | floor |
|---|---|---|---|
| motorway | 80,000 | tertiary | 3,000 |
| trunk | 40,000 | residential | 1,000 |
| primary | 20,000 | living_street | 300 |
| secondary | 8,000 | service | 200 |

*Why held:* the floor is MODELLED data entering the puma resistance surface. Per
project discipline (cutoffs/inputs pre-registered before they feed a model), the
values need explicit sign-off before Decision 25 closes fully. The `aadt_source`
flag means a later change to the floor does not touch any measured value.

*Rationale for a floor at all (vs NA):* a resistance surface cannot carry NA on a
road cell — an unmeasured local road still has SOME barrier effect. The floor
gives a defensible, class-scaled minimum; the flag keeps it honest.

*Impact:* `cov_roads_traffic_3310.gpkg` (major roads + `aadt`, `aadt_source`,
`aadt_measured`, `aadt_floor`, per-species barrier flags). Feeds the puma
resistance surface (traffic-weighted barrier, proposal Q3).

**Decision 26 — Puma resistance-surface assignment (pre-registration)**
*Date:* 2026-08-15
*Status:* **CLOSED.** Pre-registration approved 2026-08-15; surface built and
verified the same day (`04c_puma_resistance.R`). No post-hoc weight tuning: the
assignment below was locked and signed off *before* the raster existed, and was
not changed after inspection. The one pre-build change (road transform: bins →
log-inverse) was a method-match to the local calibration study found during
literature review, not an output-driven adjustment.

*Build result (verification, not tuning).* `resist_puma_baseline_3310.tif`,
20,410 land cells, 1 km, 1–100. Distribution: min 5.4, median 17.2, mean 29.7,
p75 38.7, max 100; `pct_barrier ≥80` = 7.4%; 5,507 cells (~27%) touched by a
barrier road. AADT log scale a_min(p1)=4,000, a_max(p99)=237,000. The surface
reads correctly against known connectivity: Santa Cruz Mountains and Diablo Range
low-resistance (permeable), the urban bayshore a continuous high-resistance band,
freeways as linear barriers, and the Coyote Valley / US-101 pinch point resolved
as a barrier between the two ranges. Right-skewed toward permeable with a thin
hard-barrier tail — the correct shape. Robustness is tested by the three
pre-registered sensitivity checks below (judged on corridor stability), NOT by
adjusting the surface.

*Scope.* Defines how each stacked puma covariate (1 km grid) and the road/traffic
layer maps to a movement-resistance value for `resist_puma_baseline_3310.tif`.
Puma track only (Decision 3). Output publishable at 1 km (sensitive-data-policy §3).

*Scale and combination rule.* Resistance is scored **1–100** (1 = freely
permeable ideal movement habitat, 100 = effectively impassable; standard
Circuitscape/least-cost convention, McRae et al. 2008). The landscape base is a
**weighted additive** sum of land cover, gHM and slope, rescaled to 1–100. Roads
are **not** summed in — a freeway barrier must not be diluted by surrounding good
habitat — so the final value takes `R = max(R_land, R_road)` on cells a barrier
road crosses. Additive base keeps the landscape terms interpretable and stops one
moderate covariate silently dominating; the road `max()` override supplies the one
place where domination is ecologically wanted.

*Input weights (landscape base, sum = 100%).* **Provenance: structure sourced, magnitudes are author priors.** The covariate SET and the DIRECTION of each effect are taken from the local calibration study (Hansen et al. 2025: pumas select for vegetation cover, against steep slopes, building density, urban centres and anthropogenic land cover). The relative WEIGHTS below cannot be calibrated here — that study derives them from 84 GPS-collared pumas' step-selection coefficients, and this project has no collar data (Q5) — so the 45/40/15 split is an explicit author prior, bounded by sensitivity check 3 (±10% weight perturbation). Human modification leads because this is a fragmentation study at the urban edge (proposal §1); land cover second; terrain a minor modifier.
- **gHM — 45%.** Primary fragmentation axis for a wide-ranging carnivore at the
  urban edge; broad all-threats index (Decision 23, housing dropped). *Divergence from the local reference:* Hansen et al. 2025 and Wilmers et al. 2013 use **housing density** (Microsoft building-footprint KDE) as the core anthropogenic covariate and do not use gHM. This project drops housing at the 1 km grain (Decision 23, gHM×housing r=0.78) and keeps gHM as the human-modification axis — gHM carries the same urban-intensity signal the reference attributes to housing, plus roads/land-use, so it is a defensible substitute at this grain. Recorded as a divergence, not an oversight.
- **Land cover — 40%.** Cover type strongly conditions movement (forest/shrub
  permeable; built/crop/bare hostile).
- **Slope — 15%.** Minor modifier — pumas handle steep terrain well; only extreme
  slope mildly resists.

Aspect (northness/eastness) is **excluded** from resistance — it is a
habitat-selection covariate with no defensible mechanism as a movement barrier for
pumas. It remains on the occupancy/habitat stacks, not here.

*Considered and excluded — conspecific (puma) density.* Territoriality is a real
secondary effect: resident pumas, especially males, exclude other males, and a
disperser genuinely threads between occupied territories. It is nonetheless
**excluded from the resistance weights**, for three reasons. (1) It is an *outcome,
not a landscape property* — conspecific density is produced by the movement the
surface is meant to predict, so including it makes the surface partly a function of
its own output (circular in a way gHM/land cover/slope are not). (2) *No defensible
density layer exists* — there is no Bay Area puma abundance surface (references.md:
no repeated regional census, only a statewide 3,200–4,500 estimate); deriving one
from this project's sparse, obscured, effort-biased puma points (Q5) would import
that error into the surface, and the weight could not be honestly pre-registered.
(3) It changes what the surface *means* — a structural resistance surface answers
"how permeable is the ground?", whereas a conspecific term shifts it to "where can
this population's pumas go right now?", a dynamic question that makes corridors
non-reproducible as the population shifts. The effect is better handled later as a
*modifier on least-cost paths* (social resistance layered on landscape resistance)
once a real density proxy exists — a natural fit for the deferred Felidae
camera-trap data (Decision 7). Recorded here as considered, not overlooked.

*Per-input value maps (before weighting).*

gHM → resistance, convex so light exurban modification is cheap and dense urban
rises steeply: `r_ghm = 1 + 99 * (gHM^2)` (gHM 0.0→1, 0.3→~10, 0.5→~26, 0.7→~49,
0.9→~81, 1.0→100). Convex because the movement cost of the urban gradient is
non-linear — light modification is crossable, dense urban is a wall.

Land cover → resistance, per class, then fraction-weighted per cell
(`r_lc = Σ lc_frac_class × resistance_class`):

| WorldCover class | Resistance | Rationale |
|---|---|---|
| tree (10) | 5 | Best puma movement cover |
| shrub (20) | 10 | Excellent (chaparral); under-mapped, Decision 12 |
| grass (30) | 25 | Crossable, some exposure |
| wetland (90) | 40 | Passable but slows/deflects |
| crop (40) | 55 | Open, exposed, human-associated |
| bare (60) | 60 | Exposed, little cover |
| water (80) | 90 | Major water bodies deflect movement |
| built (50) | 95 | Near-barrier |

Slope → resistance, linear to a 45° ceiling: `r_slope = 1 + 99 * pmin(slope,45)/45`
(0°→1, 10°→~23, 20°→~45, ≥45°→100). Mild — terrain is a weak modifier.

*Roads / traffic → resistance (closes the AADT→resistance question deferred from
Decision 25).* **Method changed from bins to a log transform to match the local
calibration study.** Hansen et al. 2025 (these exact pumas) weight roads by a
**log-inverse transformation of average daily traffic**, explicitly to compress
the dynamic range and reduce the disproportionate influence of high-traffic
pixels. That compression is also the correct treatment for the Decision-25
spatial_fill upward bias: a log scale flattens the inflated high-AADT tail, so the
biased interpolation cannot dominate the surface. This supersedes the earlier
4-bin proposal (bins were a cruder version of the same intent; the published
log transform is preferred).

Road resistance applies only to cells a `barrier_puma` road crosses (highway +
arterial, Decision 24). Continuous log map, rescaled to 1–100:
```
R_road = 1 + 99 * ( log1p(aadt) - log1p(a_min) ) / ( log1p(a_max) - log1p(a_min) )
```
with `a_min`/`a_max` = the 1st/99th percentile of `aadt` over barrier-road cells
(winsorised so a single extreme station cannot set the scale). Effect: a quiet
5k arterial ≈ 40, a 50k highway ≈ 80, a 200k+ freeway → ~100, with the steep part
of the curve at low volumes where a puma's crossing decision actually changes —
the log compresses differences among already-busy roads, exactly the bias fix.

`spatial_fill`/`modelled` cells are flagged in a companion band (`aadt_conf`) so
sensitivity check 1 can drop them to `R_land`; the log transform already absorbs
the volume bias, so no value change is made — only auditability. Non-barrier roads
(`local`/`permeable`, `barrier_puma = FALSE`) contribute no override; tracks/paths
are not barriers (Decision 24).

*Assembly.*
```
R_land = 0.45*r_ghm + 0.40*r_lc + 0.15*r_slope          # 1..100
R      = ifelse(barrier_puma_cell, pmax(R_land, R_road), R_land)
R      = clamp(R, 1, 100)
```
Output: `resist_puma_baseline_3310.tif` (1 km, EPSG:3310, Float32, 1–100), plus an
`aadt_conf` companion band for the sensitivity run.

*Pre-registered sensitivity checks (run AFTER build; declared now so they cannot
reverse-engineer weights).* (1) Road-confidence: rebuild with spatial_fill/modelled
road cells dropped to `R_land`; if corridor least-cost paths are stable, the AADT
bias is immaterial (expected). (2) Chaparral (Decision 12): rebuild with shrub
resistance = tree (5) to bound WorldCover shrub under-mapping; if corridors move
materially, flag CAL FIRE FVEG supplement. (3) Weight perturbation: ±10% on the
gHM/land-cover split, reported as a robustness statement, not a tuning loop.

*Known limitations (carried, not fixed).* gHM 300 m→1 km bilinear + edge-fill
(Decision 23) extends boundary cells rather than measuring them; AADT interpolation
biased high (Decision 25), compressed by the log-inverse road transform and bounded by sensitivity check
1; WorldCover shrub under-mapping (Decision 12) bounded by sensitivity check 2;
1 km grain is coarse for pinch-points (e.g. Coyote Valley) — the baseline surface
is regional, not site-scale.

*References added (references.md, Bay Area felid research + Methods):* Hansen, K.W., Morgan, J.J., De Alfaro, L., Wilmers, C.C., & Ocampo-Peñuela, N. (2025). *Variation in anthropogenic tolerance alters dispersal capacity of a large carnivore.* bioRxiv 2025.09.29.677867 — local iSSF/EcoScape calibration for 84 Santa Cruz Mountains pumas; source for covariate selection, effect directions, and the log-inverse traffic transform. Zeller, K.A., McGarigal, K., Cushman, S.A., Beier, P., Vickers, T.W., & Boyce, W.M. (2016). *Using step and path selection functions for estimating resistance to movement: pumas as a case study.* Landscape Ecology 31(6), 1319–1335 — foundational puma resistance-from-step-selection method.

*Signed off (2026-08-15, all approved as written):* (1) weights 45/40/15
(gHM/land-cover/slope; author priors, structure sourced, bounded by sensitivity
check 3); (2) gHM convex (squared) curve; (3) the eight land-cover class values;
(4) AADT log-inverse transform (Hansen 2025 method) + p1/p99 winsorising,
replacing the earlier bins; (5) `max()` road override vs an additive road term;
(6) aspect excluded from resistance; (7) conspecific density excluded
(considered-and-excluded note above). No item was altered after the build.

*Script-name note (2026-08-20):* this Decision built `04c_puma_resistance.R`. Early
Decision-26 wording named it `07_puma_resistance.R` (a stale reference from before
the resistance build was renumbered to `04c`, the same drift class as `04d`/`04e`
→ `tbl_08`/`tbl_09`). The DOC wording is corrected to `04c`. The script's own
internal header still reads `07_puma_resistance.R`; that is a separately-flagged,
non-blocking item and is intentionally NOT silently corrected — do not "fix" it
without explicit acknowledgement. Output/table numbering (`tbl_07`, resistance
figure) is an independent counter and is unchanged.

**Decision 27 — A bobcat detection implies observation effort (detection-history encoding)**
*Date:* 2026-08-15
*Status:* CLOSED.

*Context.* The bobcat detection history (script 04d) marks a unit-year "surveyed"
from the Fork-3 target-group background effort layer (Decision 22): a unit-year is
surveyed if the background feed recorded ≥1 non-bobcat mammal (3A) there that year.
Crossing the detections against 3A revealed **98 detection unit-years (85 distinct
units, spread evenly across 2010–2026) where a bobcat WAS detected but the
background did NOT mark the unit-year surveyed.** These arise because the
target-group proxy registers effort only from *other* mammals; a unit-year whose
only mammal observation was the bobcat itself has no background record, so a real
bobcat detection would fall in an "unsurveyed" (NA) cell.

*Decision.* A verifiable bobcat detection is **direct evidence that observation
effort occurred** in that unit-year — not a proxy for it. Therefore a detected
unit-year is encoded **surveyed + detected (1)** even when the target-group
background did not independently mark it surveyed. This overrides the
"unsurveyed → NA" rule for **detected cells only**; non-detected unsurveyed cells
remain NA (never a fabricated 0, per Decision 22).

*Justification.* (a) The alternative — leaving these cells NA — discards ~11% of
real bobcat detections (98 of ~808 mammal-precise detection cells) purely because
an imperfect proxy missed them. (b) That discard biases naive detection
probability *downward* (it removes 1s while retaining the 0s), which is precisely
the wrong error for Decision 22: the occupancy-vs-SDM fork turns on whether fitted
p clears the §5.4 line (p < 0.10 → SDM), so systematically deflating p could push a
genuinely viable occupancy case into a false fallback. (c) An observation record IS
observation effort by definition; letting a background proxy override ground-truth
detection inverts the evidence hierarchy. (d) The upgraded cells are logged
(`tbl_08_detections_upgraded_d27.csv`) so the choice is fully auditable and
reversible.

*Scope / cost.* Effort is now defined from two sources: the target-group background
(primary) plus the detections themselves (for detected cells only). This is a
deliberate, bounded departure from a strictly background-defined design. It cannot
create false non-detections (0s are still background-defined) and cannot fabricate
occupancy at unsurveyed sites (only detected cells upgrade). The obscured-coordinate
caveat (Decision 20/21) is unaffected — obscured detections still only enter the
"all" sensitivity histories, not the precise-primary one.

*Impact.* Applied in `04d_bobcat_detection_history.R` to all four histories.
Mammal-precise (the primary for the Decision 22 close) gains 98 detection cells;
the null fit (script 04e) and Decision 22 close run on the upgraded histories. Effect
on naive_p is upward (toward honest), recorded in the fit.

---

**Decision 28 — KDE bandwidth: a pre-registered selection rule, not a fixed value or a post-hoc look**
*Date:* 2026-08-16
*Status:* CLOSED.

*Context.* KDE bandwidth (σ) sets the smoothing scale and therefore the map. The
project's pre-registration discipline forbids choosing an analytical value after
inspecting the output (as with the resistance weights, Decision 26, and the
housing cap, Decision 23). But the two standard data-driven selectors are built
for *point-process intensity estimation* of a designed sample, not for
effort-clustered opportunistic records. On clustered iNaturalist data `bw.diggle`
in particular collapses toward a very small bandwidth, producing a KDE that maps
*where observers go* — the exact Q5 effort artifact the analysis must expose, not
bake in. A separate hard constraint: the puma publish floor is 1 km
(`sensitive-data-policy.md` §3) and the puma cell **is** 1 km, so any σ below the
cell is meaningless at the output grain.

*Decision.* Compute **three** candidates per species and print them: `bw.diggle`,
`bw.ppl`, and a **home-range prior** (author prior: puma **5,000 m**, bobcat
**1,500 m**). Choose by a rule fixed in advance — only the *value* is read from
output, never the *choice*:

1. Reject any σ **< output cell size** (sub-cell smoothing; for puma, below the
   1 km policy floor).
2. Reject any σ **< home-range prior / 3** (collapsed toward the observer-cluster
   scale rather than the movement scale).
3. Among survivors, take the **smallest** σ (least smoothing that still passes
   1–2; preserves real structure without effort-chasing).
4. If none survive, use the **home-range prior** — defensible from first
   principles: KDE bandwidth ≈ the scale at which one occurrence informs
   neighbouring space = the animal's movement scale.

*Outcome (real run, script 05, values recorded in
`tbl_09_kde_bandwidth_selection.csv`).*
- **Puma (1,028 precise points):** `bw.diggle` 48.8 m — rejected (rules 1 + 2);
  `bw.ppl` 1,458.1 m — rejected (rule 2, below the 1,666.7 m effort floor); →
  **home-range prior 5,000 m** used (rule 4). Both data-driven selectors chased
  effort on the sparse point set; the rule refused them. This is the
  pre-registration working as intended.
- **Bobcat (4,420 precise points):** `bw.diggle` 36.8 m — rejected (rules 1 + 2);
  `bw.ppl` **1,109.6 m** — passed both tests, smallest survivor → **chosen**
  (rule 3). The larger point set gave `bw.ppl` enough support to clear the
  collapse floor with headroom (1,109.6 ≫ 500).

*Caveat (stated so it is not mistaken for two independent checks).* For bobcat the
effort floor (home/3 = 500 m) **equals** the cell size (500 m), so rules 1 and 2
coincided; they were not independent guards for bobcat. `bw.ppl` cleared with wide
margin, so the outcome is unambiguous, but the coincidence is noted. For puma the
two guards were distinct (1,000 m cell vs 1,666.7 m floor).

*Justification.* (a) The rule, not the number, is pre-registered — this is the
only way "compute all three, then pick" stays inside the project's own discipline.
(b) It structurally prevents an effort-collapsed bandwidth from setting the
smoothing, directly serving proposal Q5. (c) The species diverge on which
candidate wins (puma → prior, bobcat → `bw.ppl`) purely through data density, not
through any per-species hand-tuning — the same rule produced both.

---

**Decision 29 — Obscured-coordinate handling in KDE: precise-only published surfaces + a caveated obscured-puma companion**
*Date:* 2026-08-16
*Status:* CLOSED.

*Context.* Puma occurrence is ~49% obscured (1,003 of 2,031) with coordinates
randomised within ~28 km (Decision 10/20). A KDE that includes obscured points
smears ~28 km of positional noise into a 1 km surface — a diffuse haze that is
pure artifact, not signal. Bobcat is ~29% obscured (1,812 of 6,232), also
randomised, but precise-dominant and low-sensitivity (`sensitive-data-policy.md`
§2, T1).

*Decision.* Published KDE surfaces for **both species are precise-only**
(`obscured == FALSE`): puma 1,028 points, bobcat 4,420 points. A **separate,
caveated obscured-puma density companion** (`kde_puma_obscured_caveat_1km_3310.tif`)
is written from the 1,003 obscured puma points at the home-range bandwidth
(5,000 m) — for the Q5 effort/uncertainty cross-read **only**. It is **not** a
distribution surface and **not** the published puma KDE. Bobcat gets **no**
obscured companion.

*Justification.* (a) Precise-only removes the ~28 km smear from every published
surface. (b) The puma companion earns its place because dropping the obscured half
discards ~49% of puma records; seeing where that obscured effort concentrates is a
first-class Q5 input, not a caveat. Bobcat's obscured fraction is smaller (~29%)
and the precise set is already dense (4,420), so no companion is needed — **the
asymmetry is deliberate and by data situation, not an oversight.** (c) The
companion still clears policy §3: home-range smoothing over already-randomised
~28 km coordinates cannot reverse to a camera or den, and it is ≥ 1 km; it passes
`assert_publishable()`. It is labelled `_caveat_` in the filename and flagged in
the data dictionary as an effort/uncertainty read.

*Scope / cost.* Three rasters written (script 05): `kde_puma_current_1km_3310.tif`
(published, precise-only), `kde_puma_obscured_caveat_1km_3310.tif` (T2 companion,
caveated), `kde_bobc_current_500m_3310.tif` (published, precise-only). Every puma
export gated through `assert_publishable()`; no sub-1 km puma intermediate is
written at any point.

---

**Decision 30 — Gi* hot-spot analysis: unit grain, distance-band neighbours, uncertainty-grounded point assignment, and a first-class Q5 effort cross-read**
*Date:* 2026-08-16
*Status:* CLOSED.

*Context.* Getis-Ord Gi* (`sfdep::local_gstar_perm`) identifies units whose local
neighbourhood sum is significantly high (hot) or low (cold). Three design choices
drive the result — grain, neighbour scheme, and how occurrence points are
assigned to units — plus the Q5 effort control. Two of these went through
documented corrections before the design held; both are recorded here rather than
hidden, per the project's "document corrections" discipline.

*Decision — grain.* CPAD **unit**, one tessellation, per species, never pooled
(Decision 3). Rationale: the effort proxy (Fork-3 mammal layer) exists only at
unit grain — the GBIF background point cloud was not retained — so a grid-grain
effort cross-read is impossible without re-opening a closed acquisition step. The
KDE surfaces (§5.2) carry the fine-grain *distribution* product; Gi* carries the
*statistical-cluster* product. They answer different questions.

*Decision — neighbour scheme (TWO CORRECTIONS recorded).*
- **Attempt 1 — queen contiguity (rejected).** Stranded 485 / 1,129 units (43%)
  with no neighbour; 630 sub-graphs. CPAD open-space units rarely share edges, so
  contiguity is structurally wrong for this geometry.
- **Attempt 2 — KNN k = 8 (rejected).** Fixed the stranding but diluted dense
  clusters: KNN is distance-blind, so a unit's 8 "nearest" can be tens of km away.
  Bobcat collapsed to 3 hot units because dense clusters borrowed low-count units
  across the matrix. The "~8 neighbours" rule of thumb was mis-applied — it sizes
  a *distance band*, it is not an endorsement of KNN (literature: ESRI Gi* best
  practice; Getis & Ord 1992/1995).
- **Final — fixed distance band + KNN floor.** Band = **6,342 m**, computed from
  the data as the mean per-unit distance to the 8th-nearest unit (min 2,159 /
  median 5,680 / mean 6,342 / max 44,112). Any unit left under 8 neighbours is
  unioned with its nearest 8 (KNN floor): 408 units topped, final mean 11.5 links,
  32 sub-graphs. This is the literature default for skewed count data — a natural
  spatial scale with a minimum-neighbour guarantee. Gi* (star) includes self;
  binary weights (`style = "B"`, correct for counts). The band is **not**
  per-species: the unit tessellation is identical across species, so one shared
  graph is built once and reused for puma, bobcat and effort — keeping the three
  runs directly comparable. Only the counts on the units differ.

*Decision — point→unit assignment (uncertainty-grounded, literature-led).*
Occurrences do not carry `unit_id`; they are assigned spatially, three ways:
(1) **inside** a unit (`st_within`); (2) **snapped** if the nearest unit lies
within the point's **own `coord_uncert_m`** (boundary-jitter recovery); (3)
**matrix** otherwise, including `coord_uncert_m = NA` (conservatively not snapped).
The snap tolerance is grounded in each record's coordinate uncertainty (~26-31 m
median here), **not** a chosen 1-2 km constant — a km-scale blanket snap would
launder genuine matrix detections into parks. Literature basis: ground snap
tolerance in the data's positional error (PostGIS guidance); characterise the
neighbourhood by the radius of actual sampling uncertainty (conservation-methods
neighbourhood approach). Result: puma 657 inside / 79 snapped / 292 matrix (59 NA);
bobcat 2,502 inside / 396 snapped / 1,522 matrix (392 NA). Matrix points are
**retained** as a finding (`occ_<sp>_matrix_3310.gpkg`) — genuine outside-open-space
occurrence is signal for Q5 and connectivity, not error. The puma matrix layer is
precise puma coordinates (T2-source): it stays in `data/interim/`, is never
published as points, and only counts/summaries may inform Q5.

*Decision — Q5 effort cross-read (first-class).* Gi* is run a second time on the
per-unit surveyed-year count (retained mammal effort layer), and each occurrence
hot unit is labelled `SUSPECT` (also effort-hot) or `TRUSTED` (not effort-hot).
This is the tiger-project Ranthambore lesson made a first-class analytical step,
not a caveat. It labels, does not correct. Result: puma 25 suspect / 22 trusted;
bobcat 2 suspect / 4 trusted. **Caveat (explicit asymmetry):** the mammal effort
layer is bobcat-shaped (bobcat excluded, mammal target-group tuned to bobcat
detectability); for puma it is a looser general mammal-observer proxy. There is no
puma-specific effort layer.

*Results and QC.* Puma 47 hot / 430 cold; bobcat 6 hot / 224 cold; effort 104 hot
/ 112 cold (FDR ≤ 0.05, 999 permutations). **Bobcat's low hot-spot count was
verified real, not an artifact**, by a retained Global G QC step: both species
have significant positive Global G (puma z ≈ 31, bobc z ≈ 9.9, both p ≈ 0) — real
clustering is present. A global-gradient artifact would show significant Global G
*with* suppressed local structure; instead puma has 47 local hot spots and the
mechanism is working. The species differ in the **spatial arrangement** of their
highs: bobcat is spikier and more isolated (69% zero units, max 519, p99 = 29), so
fewer units form the jointly-high neighbourhoods Gi* rewards; puma highs are
moderate and spatially clustered. No detrending applied — forcing more bobcat hot
spots would be post-hoc number-chasing. This is a finding, recorded in §7.

*Outputs.* `hot_puma_gistar_unit_3310.gpkg`, `hot_bobc_gistar_unit_3310.gpkg`,
`occ_puma_matrix_3310.gpkg` (interim), `occ_bobc_matrix_3310.gpkg`,
`tbl_10_gistar_q5_crossread.csv`.

---

**Decision 31 — Bobcat covariate occupancy: detection + occupancy covariate sets,
transform, and selection rule (pre-registered)**
*Date:* 2026-08-17
*Status:* **CLOSED.** Fitted in `06_occupancy_models.R`.

*Decision:* Fit the bobcat covariate occupancy model on the **mammal_precise**
primary history (3A target-group-correct; Decision 22), with the covariate sets,
standardisation and selection rule below **fixed before any fitted value was
seen** — same pre-registration discipline as the KDE bandwidth rule (Decision 28)
and the resistance weights (Decision 26).

*Detection sub-model (p), fitted first with psi held `~1`:*
- Covariate `eff_nrec_s = scale(log1p(eff_nrec))` — the graded per-occasion
  observer-intensity proxy. `eff_nrec` is the count of non-bobcat background
  records per surveyed unit×year, emitted by `03b` (replacing the earlier binary
  `surveyed` marker). **`log1p` chosen from the observed distribution, not
  asserted:** the 3A deciles are 1/1/1/1/2/3/4/6/10/21/1238 — heavy right skew, a
  ~400× tail — so a raw-scaled term would let a single 1,238-record cell dominate
  the detection slope. `log1p` compresses the tail; it also matches the housing
  convention (Decision 16). Backed by the skew-then-transform practice standard
  for list-length / record-count effort covariates in the citizen-science
  occupancy literature (MacKenzie 2017; Altwegg & Nichols 2019).
- `year_s = scale(year)` — occasion-level linear time term (year not skewed).
- Candidate set: p0 `~1`, p1 `~eff_nrec_s`, p2 `~year_s`, p3 `~eff_nrec_s +
  year_s`. Rule: carry the best-AICc detection structure to the psi stage.
- *Result:* **p1 `~eff_nrec_s`** wins by ΔAICc 408 over the null; the year term
  adds nothing (p3 +1.26). Detection is effort-driven and nothing else.

*Occupancy sub-model (psi), detection structure fixed from above:*
- Continuous (all scaled): `elev_mean`, `slope_mean`, `aspect_north`,
  `aspect_east`, `ghm_mean`, `housing_logden_mean`, `lc_frac_tree`,
  `lc_frac_grass`. `lc_frac_shrub` **excluded** (Decision 12: WorldCover
  under-maps CA shrub ~26×; the covariate is unreliable). gHM **and** housing both
  kept (Decision 23; unit-grain r re-confirmed on the model matrix at **0.094**,
  well below 0.7). `spans_gradient` as a flag (Decision 17).
- Candidate set (nested, ecologically grouped, NOT all-subsets): m0, m_terrain,
  m_land, m_human, m_habitat, m_full, m_fullgrad.
- Selection: AICc ranking (`AICcmodavg::aictab`); model-average psi predictions
  across the ΔAICc ≤ 2 confidence set (`modavgPred`).
- *Result:* **m_full** best; confidence set {m_full, m_fullgrad} (ΔAICc 1.37 —
  `spans_gradient` weak). Effect directions (collapsed refit): elevation +, tree
  cover +, gHM −, effort + — all ecologically expected. psi range 0.035–1.000,
  median 0.669 across 845 modelled units.

*Collinearity screen (before fitting, on the actual scaled matrix).* VIF computed
**two ways and cross-checked — manual `lm()` and `usdm::vif` agree to three
decimals** on every covariate. All VIF < 4 except `lc_frac_tree` = **5.18**.

*Sub-decision — `lc_frac_tree` retained despite VIF 5.18.* The pre-registration
set VIF ≥ 5 as a **flag requiring a recorded keep/drop decision**, not an
automatic drop. Retained because: (1) 5.18 is marginal against the usual VIF ≥ 10
action threshold; (2) tree cover is the primary bobcat-habitat axis and dropping
it would gut `m_full`; (3) manual and `usdm` VIF agree exactly, so the value is
not a computation artifact; (4) the psi fit is stable with finite SEs. Recorded,
not silently kept. Screen written to `tbl_12_collinearity_screen.csv`.

*Forward check (the Decision 22 commitment) — PASSED.* The AICc-best model was
refit on the same 4-period collapse the null used and run through
`AICcmodavg::mb.gof.test`. **c-hat fell from the null 8.9 to 1.47** (GOF p =
0.052): the null overdispersion was real habitat heterogeneity the covariates
absorbed, not structural misfit. SDM fallback stays untriggered.
- *Implementation note (bug found and fixed).* The first forward-check run
  returned c-hat = NA because `mb.gof.test` → `parboot` re-evaluates the fitted
  model's stored call on each simulated dataset; a namespace-prefixed call
  (`unmarked::occu(...)`) with the frame passed by variable name failed to
  resolve inside the bootstrap `update()` (`object 'unmarked' not found`; the
  documented `unmarked` parboot behaviour). Fixed by attaching `unmarked`,
  calling `occu()` unprefixed with the formula inlined via `do.call`, and running
  the bootstrap serially (`parallel = FALSE`). The error is now surfaced, not
  swallowed to NA. Documented per the project's explicit-error standard.

*Sensitivity (`tbl_16`).* `m_full` refit on all four histories: all converge,
finite SEs, mean psi 0.49 (3B vertebrate) – 0.62 (3A mammal). The
background/obscured fork does not change the model or the story.

*Q5 cross-read (`tbl_15`).* Fitted psi vs the Week-6 descriptive pattern
**diverges**, which is the Q5 finding, not a defect: psi vs KDE mean Pearson r =
**0.075** — near-zero. All 5 Gi* hot units fall in the top two psi quintiles
(covariate signal agrees with the descriptive clusters where they exist), but the
broad KDE pattern is effort-shaped, not habitat-shaped. Stated, not smoothed over
(proposal Q5, first-class).

*Impact:* Bobcat occupancy track closed for Phase 1. Outputs:
`occu_bobc_pred_unit_3310.gpkg` (psi surface, keyed `unit_id`),
`tbl_11`–`tbl_16`, and the fitted models in `outputs/models/`.

**Puma feasibility close (Week-7 milestone).** Confirmed: the puma track needs
**no** occupancy fit. Puma stays connectivity/SDM by design (proposal Q3;
Decision 22 is bobcat-only). The puma occupancy fork was never opened; puma
deliverables are the resistance surface (Decision 26) + Week-8 least-cost
corridors, plus the Week-6 KDE/Gi* descriptive layer. No new decision required.

**Decision 32 — Puma core-habitat patches: dissolve rule, minimum-patch-area
floor, and named linkage endpoints (pre-registered mechanism, floor read from the
observed distribution)**
*Date:* 2026-08-18
*Status:* **CLOSED.** Built in `07_connectivity.R` (Part 1 + Part 2).

*Decision:* Derive the puma corridor **endpoints** from the CPAD∪CCED union
(`protected_union_bayarea_3310.gpkg`, Decision 19), not from CPAD Units (Units are
the occupancy frame; the connectivity track uses no CPAD level as its unit —
methodology §3 per-track note). Three sub-rules, the mechanism fixed before the
run and the one numeric threshold read from the observed area distribution, not
asserted:

1. **Dissolve rule (fork A — all tenure melted, then split by contiguity).**
   `st_union()` the whole validity-guarded union, `st_cast` to POLYGON. Fee and
   easement melt geometrically: an easement grazing parcel abutting a fee preserve
   is one functional patch to a wide-ranging puma (Decision 19). Tenure is **not**
   erased as information — each patch keeps a fee/easement area tally
   (`area_fee`, `area_easement`). Fork B (bridge near-adjacent patches across a
   gap tolerance) was **considered and deferred**: it needs a second
   pre-registered gap distance and drifts toward asserting connectivity the
   surface should predict. It is available as a named variant only if the raw
   dissolve strands a named range — it did not.

2. **Minimum-patch-area floor = 5 km² (home-range anchored, NOT read off a curve
   break).** A patch below 5 km² cannot hold a meaningful fraction of a single
   puma home range (home-range prior **5 km**, Decision 28; Hansen et al. 2025
   ranges span tens–hundreds of km²), so it is a **stepping-stone, not a corridor
   endpoint**. The observed patch-area distribution is a **smooth size continuum
   with no break** (endpoint-floor scan below), so "read the break" does not apply
   — the floor is set by the ecological home-range scale, and the scan is recorded
   as the evidence that the cut is not severe (82.5% of protected area retained at
   5 km²). **Alternative 1 km² floor (the resistance grid resolution) considered
   and rejected:** it keeps 464 endpoints and generates a dense mesh of trivial
   short links that would bury the Santa Cruz Mountains ↔ Diablo Range signal the
   proposal asks for (Q3). 2 km² and other mid-curve values were **not** used —
   the middle of a smooth curve is an asserted cutoff with no anchor.

   *Endpoint-floor scan (evidence; `tbl_17`):*
   | floor (km²) | patches kept | protected area retained |
   |---|---|---|
   | 0.01 | 2,356 | 99.9% |
   | 0.10 | 1,429 | 99.3% |
   | 0.50 | 696 | 96.5% |
   | 1.00 | 464 | 93.7% |
   | 2.00 | 307 | 90.0% |
   | **5.00** | **164** | **82.5%** |
   | 10.00 | 86 | 73.7% |

   *Result:* **164 core patches** (endpoints) ≥ 5 km²; **3,512 stepping-stones**
   retained; **591 sub-100 m² "dust" patches dropped from both layers.** The floor
   drops patches from the **endpoint set only** — it does **not** alter the
   resistance raster; least-cost movement still crosses stepping-stones and matrix.

3. **Named linkage endpoints (verified from county + west→east geometry; two
   initial seed labels CORRECTED on record).** The primary linkage (proposal Q3)
   is **Santa Cruz Mountains ↔ southern Diablo Range** through the Coyote Valley /
   US-101 pinch:
   - **Santa Cruz Mountains = `patch_id 1727`** (177.0 km², San Mateo, centroid
     cx −196,663 / cy −85,363) — the largest of the ~8 SC-range cores; the range
     is split by internal highways (92/35/9/17). Routing seeds from this dominant
     core (option **a**); SC-range fragmentation is a **stated corridor
     limitation**, not an endpoint-naming problem. Nearest-SC-core routing
     (option b) is available as a refinement if the least-cost surface warrants it.
   - **Diablo Range (southern) = `patch_id 3972`** (500.4 km², Santa Clara,
     centroid cx −135,434 / cy −91,905) — Henry Coe + easement margins, east of
     Coyote Valley.
   - **Correction on record:** the initial code seeds were **both wrong** —
     `3972` was first mislabelled "Santa Cruz Mountains" and `220` "Diablo Range".
     Verification against county centroids and the south-Bay west→east scan showed
     `3972` is the *southern Diablo Range* and `220` is the *Marin / Mt Tamalpais*
     block (438 km², Marin) — **not a linkage endpoint**, left unlabelled. The
     error was surfaced and fixed before any Decision text was committed; recorded
     here per the project's surface-errors principle.

*Cleaning note (not a threshold).* The raw dissolve inflates the patch count
(3,773 features → 4,267 patches) because the Decision-19 `st_difference`
fee-precedence erase leaves sub-metre gaps that `st_union` cannot close and
`st_cast` splits into sub-100 m² dust. An `st_snap(union, union, tol)` clean was
**attempted and abandoned** — it is all-pairs O(n²) on 3,773 features and hung. It
is unnecessary: the dust holds 0.0002% of protected area and sits ~5 orders of
magnitude below the 5 km² floor, so the floor removes it for free. **One
threshold, one justification** — the dust exclusion is the `< 1e-4 km²` (sub-100
m²) artifact cutoff, not a second ecological rule.

*Outputs.* `lcp_puma_core_patches_3310.gpkg` (164 endpoints),
`lcp_puma_stepping_stones_3310.gpkg` (3,512 retained), `tbl_17` (area
distribution + floor scan), `tbl_18` (core-patch summary), `fig_17` (log-area
histogram with the 5 km² floor marked). Both layers are T0 (protected-area
boundaries) — no `assert_publishable()` gate applies (that gates puma
surfaces/corridors, not protected-land polygons).

*Signed off (2026-08-18):* (1) fork A dissolve, fork B deferred; (2) 5 km²
home-range floor, 1 km² rejected, mid-curve values rejected; (3) endpoints 1727
(SC Mtns) / 3972 (southern Diablo), option (a) dominant-core routing, two seed
labels corrected; (4) 591 dust patches excluded as `st_difference` artifacts, no
snap. Table/figure numbers (`tbl_17`/`tbl_18`/`fig_17`) are the next free counter
values, independent of the `07` script number (same convention as `04d`/`04e` →
`tbl_08`/`tbl_09`).

---

** Decision 32 — Puma core-habitat patches: dissolve rule, 5 km² floor, named endpoints
*Date:* 2026-08-18 · *Status:* **CLOSED** (`07_connectivity.R` Parts 1–2).

Corridor **endpoints** are derived from the CPAD∪CCED union
(`protected_union_bayarea_3310.gpkg`, Decision 19), NOT CPAD Units (Units are the
occupancy frame; connectivity uses no CPAD level as its unit — §3 per-track note).

1. **Dissolve (fork A).** `st_union` all tenure, `st_cast` to POLYGON: fee +
   easement melt geometrically (one functional patch to a wide-ranging puma,
   Decision 19); tenure kept as a per-patch `area_fee` / `area_easement` tally.
   Fork B (bridge near-adjacent patches across a gap tolerance) considered and
   **deferred** — a second threshold, not needed (no named range was stranded).
2. **Minimum-patch-area floor = 5 km² (home-range anchored).** A patch below
   5 km² cannot hold a meaningful fraction of a puma home range (prior 5 km,
   Decision 28; Hansen 2025 ranges tens–hundreds km²) → **stepping-stone, not an
   endpoint.** The area distribution is a smooth continuum with **no break**
   (endpoint-floor scan, `tbl_17`), so the floor is set by the ecological
   home-range scale, and the scan is the evidence the cut is not severe (82.5% of
   protected area retained). **1 km² (grid resolution) rejected** — 464 endpoints,
   a dense mesh of trivial links that would bury the SC Mtns ↔ Diablo signal
   (Q3). Mid-curve values (2 km²) rejected as anchor-free. Result: **164 cores,
   3,512 stepping-stones retained, 591 sub-100 m² dust dropped.**
3. **Named endpoints (verified from county + west→east geometry; two seed labels
   CORRECTED).** Primary linkage = **Santa Cruz Mountains (`patch_id 1727`,
   177 km², San Mateo) ↔ southern Diablo Range (`patch_id 3972`, 500 km², Santa
   Clara, Henry Coe)** through the Coyote Valley / US-101 pinch. **Correction on
   record:** initial code seeds (3972 = "SC Mtns", 220 = "Diablo") were BOTH
   wrong — verification showed 3972 is southern Diablo and 220 is the Marin / Mt
   Tam block (438 km², not a linkage endpoint). Surfaced and fixed before any
   Decision text was committed (surface-errors principle). SC Mtns is split into
   ~8 cores by internal highways; 1727 is the dominant core; fragmentation is a
   stated corridor limitation (option a — dominant-core routing).

*Cleaning note (not a threshold).* Raw dissolve inflates the count (3,773 →
4,267) via sub-metre `st_difference` gaps split into sub-100 m² dust. An
`st_snap(union,union,tol)` clean was attempted and **abandoned** (all-pairs O(n²),
hung); unnecessary — the dust holds 0.0002% of area and is removed for free by the
5 km² floor. The `< 1e-4 km²` dust cutoff is the artifact bound, not a second
ecological rule.

*Outputs:* `lcp_puma_core_patches_3310.gpkg`, `lcp_puma_stepping_stones_3310.gpkg`,
`tbl_17`, `tbl_18`, `fig_17`. Both layers T0 (protected-area boundaries) — no
`assert_publishable()` gate. `tbl_17/18` + `fig_17` numbering is independent of the
`07` script number (same convention as `04d/04e` → `tbl_08/09`).

---

** Decision 33 — Least-cost corridor construction: conductance, neighbourhood, swath band
*Date:* 2026-08-18 · *Status:* **CLOSED** (`07_connectivity.R` Parts 3–4).
Consumes `resist_puma_baseline_3310.tif` (Decision 26); does NOT rebuild it.
Built on `leastcostpath` 2.0.13 (terra `create_cs` API; `gdistance` not on the
path — the <2.0 transition workflow is not used).

1. **Resistance → conductance inversion (`cond = 1/R`) before `create_cs`.**
   `create_cs` treats higher raster values as EASIER movement (barrier
   conductance = 0). Our surface is resistance (100 = impassable), so it MUST be
   inverted or the path would run through freeways. Non-negotiable for
   correctness. R clamped 1–100 → cond 0.01–1.0, strictly positive (observed
   range 0.010–0.185: no cell reaches resistance 1, consistent with the Decision
   26 min of 5.4).
2. **Neighbourhood = 16 (package default).** Extended adjacency reduces the
   deviation / elongation distortion of 8-connectivity (paths locked to 45°
   increments); 16 adds knight's moves and roughly halves angular error. Standard
   for connectivity modelling (Antikainen 2013 *Transactions in GIS*; Shirabe
   2016; Etherington distortion literature). Residual elongation is a known,
   unfixable raster limitation — recorded, not hidden. Compute is trivial at this
   grain, so the accuracy gain is free.
3. **`dem = NULL, max_slope = NULL`.** Slope is ALREADY in R (Decision 26
   `r_slope`, 15%) as a graded cost. A DEM + `max_slope` would double-count
   terrain and hard-zero steep cells the pre-registration made merely costly. Off.
4. **Endpoints = nearest boundary points**, snapped to the nearest
   finite-conductance cell (`check_locations = TRUE`). Centroids rejected (a
   500 km² patch centroid sits deep inside). Snap moved SC 240 m / Diablo 287 m
   (< 1 cell).
5. **Two-tier swath band (read from the observed cost-corridor distribution;
   literature-informed).** `create_cost_corridor` (both directions averaged, raw
   accumulated cost). The cost distribution has a **cliff** — q25→q50 jumps
   376→1011 — so low-cost corridor cells are cleanly separated from off-route
   background. Bands set BELOW the cliff:
   - **CORE = accumulated cost ≤ q2%** (146.9) → 409 km², high-confidence corridor.
   - **CONTEXT = ≤ q5%** (180.4) → 1,021 km², permeable flanks.
   q10% (2,041 km², ~20 km mean width) **rejected**: the field-verified Coyote
   Valley functional linkage is a narrow thread (0.6–3.2 km at the pinch), so a
   broad band would erase the constriction the corridor is about. **1 km grain
   limitation stated:** the sub-1 km pinch is below one cell (Decision 26 flagged
   this), so the swath is REGIONAL corridor context, not a site-scale pinch map;
   the precise US-101 pinch is located by the barrier-crossing step (road
   geometry), not the swath.
6. **Barrier crossings ranked WITHIN `aadt_source` confidence tiers** (Decision
   34), not on raw AADT — so US-101 (`measured_route_pm`) leads and a `name_fill`
   arterial cannot masquerade as the top barrier. Roads identified + labelled by
   `fclass` (freeways are `name = NA`; `ref` lost — Decision 34 follow-up).

*Primary linkage result:* LCP **37.2 km**, SC Mtns (1727) → southern Diablo
(3972), passing **1.6 km** from the verified Coyote Valley / US-101 pinch; the
core swath covers the pinch. Independently corroborated (Bay Area Critical
Linkages; OSA Coyote Valley Landscape Linkage; SC Mtns Linkage CAPP). US-101 is
the top-ranked measured crossing (142k, `in_core`).

*Sensitivity verdict recording:* by qualitative statement + raw divergence
metrics, NOT a hard pass/fail threshold (a numeric cutoff on a one-off comparison
would be false precision). See sensitivity check 1 under Decision 34.

*Outputs:* `lcp_puma_scmtns_to_diablo_3310.gpkg` (LCP),
`lcp_puma_scmtns_to_diablo_costcorr_3310.tif` (surface, gated
`assert_publishable`), `lcp_puma_scmtns_to_diablo_swath_3310.gpkg` (two tiers),
`lcp_puma_scmtns_to_diablo_crossings_3310.gpkg`, `tbl_19`, `tbl_20`, `fig_18`,
`fig_19`. Swaths/corridors are generalised geometry, publishable per
sensitive-data-policy §3.

---

** Decision 34 — State-highway AADT by route-line + postmile referencing (data-correction)
*Date:* 2026-08-18 · *Status:* **CLOSED** (pre-registered before the re-run;
closed after). Revises the AADT INPUT to Decision 26; Decision 26's weights /
transform are UNCHANGED (data correction, not a re-tune).

**Bug.** The Decision-25 AADT join snapped Caltrans count-station POINTS to the
nearest road within 100 m, discarding Caltrans' native route + postmile linear
referencing. US-101 through Coyote Valley — the field-verified critical barrier —
sits in the largest station gap on SCL Route-101 (8.96 mi, PM 17.82 → 26.78, both
bracket stations ~142k) and fell to the modelled 80k floor: a ~43% underestimate.
A named arterial (Santa Teresa Blvd) meanwhile carried a `name_fill` 111k that
outranked the real freeway (US-101 is `name = NA`, so name-propagation skipped it).

**Fix (pre-registered from the data structure, not the outcome).** For every
state-highway segment (`fclass ∈ {motorway, trunk, +links}`): build the matched
route as a PM-ordered line of its stations (per `RTE`+`CNTY`), pick the route the
segment lies ALONG (min distance to route-line, ≤ 500 m — junction-safe: a US-101
segment is 190 m from the 101 line vs 4,977 m from the Route-85 line, so it can
not inherit Route-85's terminal AADT), and interpolate the bracketing stations'
AADT. New provenance tier **`measured_route_pm`** (highest confidence). Non-state
roads keep the Decision-25 tiers unchanged. This **refines Decision 25's**
"spatial_fill skews high, not correctable" note: that stands for *local/arterial*
roads (Caltrans does not PM-reference them); state highways ARE PM-referenced and
so ARE correctable — which is what this does.

*Implementation note:* OSM segments carry no postmile, so the route is
reconstructed as a PM-ordered station polyline and segments are projected onto it
— a geometry-based approximation of postmile interpolation, exact enough on the
near-linear, flat-inter-interchange state-highway network. Two failed
implementations preceded this (nearest-station route inference pulled Route-85's
56k, then southern-101's low values) — both surfaced and corrected; the route-LINE
match is the working version. `ref`-field recovery (exact route match + freeway
labels) is a deferred roads-pull follow-up (§4 data-sources).

**Result.** US-101 @ Coyote Valley now **142,000** (`measured_route_pm`);
state-highway network 17,327 segments route-referenced, median 135k (vs the 80k
floor). US-101 is correctly the top measured crossing; Santa Teresa demoted to a
flagged estimate.

**Scope = full re-run** (`04b` join → `04c` resistance → `07` corridors), because
AADT feeds the resistance surface. `resist_puma_baseline_3310.tif` re-emitted as a
data-correction revision superseding the 2026-08-15 build.

**Sensitivity check 1 (road-confidence; pre-registered Decision 26) — PASSED /
STABLE.** The old-vs-new corridor comparison IS this check. Verdict by qualitative
statement + raw metrics (Decision 33): the corridor is **fully robust** to the
correction — LCP identical (Hausdorff 0 m; length 37.19 km both), core swath IoU
1.000, context IoU 0.990, cost-surface Spearman 1.000 — while accumulated cost rose
+4.4% (311.9 → 325.7). **Mechanism (why it is rank-preserving, stated so the
perfect overlap is not misread as a trivial change):** both 80k and 142k already
map to the high-resistance tail under the Decision-26 log-inverse transform (which
compresses the high-traffic tail by design), so US-101 cells were already
high-cost and the path already avoided them; the correction changed absolute cost
but not cell rank. **The correction was consequential for the crossing SEVERITY
RANKING (US-101 mis-ranked → correctly top) but immaterial for corridor GEOMETRY.**
Two distinct findings, kept distinct. `tbl_21`, `fig_20`.

*Outputs:* revised `cov_roads_traffic_3310.gpkg` (+ `measured_route_pm` tier,
`route_pm_rte`, `route_pm_interp_dist_m`), revised `resist_puma_baseline_3310.tif`,
`tbl_21`, `fig_20`.

---

** Decision 35 — Corridor sensitivity verdict: robust to all three pre-registered checks
*Date:* 2026-08-20 · *Status:* **CLOSED** (`07e_sensitivity.R`; `tbl_22`, `fig_21`).

The three pre-registered Decision-26 sensitivity checks were run as one-at-a-time
(OAT) plausible-range perturbations of the resistance surface, judged on corridor
overlap (method: Beier, Majka & Newell 2009; Rayfield, Fortin & Fall 2010; Marrec
et al. 2020 — perturb one uncertain parameter across its plausible range,
re-extract, report overlap; a perturbation that does not touch the high-resistance
cells that pin the corridor is expected to leave it stable). Every variant is the
`04c` build parameterised (`build_resistance()`) with the SAME corrected AADT
(Decision 34) — only the one perturbed parameter differs. Verdict recorded
qualitatively + raw metrics (Decision 33), not a hard pass/fail threshold.

**Result — STABLE across all three checks** (baseline LCP 37.19 km):

| check | LCP km | mean sep | core IoU | context IoU |
|---|---|---|---|---|
| baseline | 37.19 | 0 | 1.000 | 1.000 |
| 1 road-confidence (drop low-conf AADT → R_land) | 37.19 | 0 m | 0.916 | 0.941 |
| 2 chaparral (shrub 10 → 5 = tree) | 37.19 | 0 m | 1.000 | 0.998 |
| 3a weights gHM-heavy (+10% gHM / −10% LC) | 35.55 | 1,312 m | 0.976 | 0.975 |
| 3b weights LC-heavy (−10% gHM / +10% LC) | 37.19 | 0 m | 0.976 | 0.975 |

Worst case: context IoU 0.941, mean LCP separation 1,312 m (~1 cell). The corridor
is robust to all three known data limitations.

**Per-check findings (mechanism stated, not just the aggregate):**

1. **Road-confidence — PASS.** Trusting only station-traceable AADT (dropping
   spatial_fill/modelled barrier cells to R_land) left the LCP identical (0 m);
   only the swath edges shifted (IoU 0.92/0.94, the widest tier is the most
   perturbable at its margin). Consistent with sensitivity check 1 (Decision 34
   v1/v2): AADT confidence affects the surface at the margins, not the corridor
   spine. (Sensitivity check 1 is thus corroborated by a second, independent
   variant — dropping low-confidence cells rather than correcting them.)

2. **Chaparral (Decision 12) — PASS; FVEG supplement NOT triggered.** Lowering
   shrub resistance 10 → 5 (treating all WorldCover shrub as tree-equivalent
   cover, bounding the ~26× chaparral under-mapping) moved the corridor **not at
   all** (core IoU 1.000, context 0.998, LCP 0 m). Mechanism: shrub was already a
   low value (10) on a path pinned by freeway/urban barriers and running through
   tree/grass cells, so halving an already-low mid-range value changes nothing.
   **This CLOSES the Decision-12 chaparral contingency: WorldCover shrub
   under-mapping is immaterial to puma connectivity; the CAL FIRE FVEG supplement
   is not needed.** (The under-mapping may still matter for other analyses — this
   verdict is specific to the connectivity corridor.)

3. **Weight perturbation — PASS, with a stated caveat.** The gHM/LC split was
   bounded ±10% relative (opposite directions, slope fixed, renormalised) as a
   plausible-range bound on the expert prior (Decision 26 weights have no
   collar-data fit; Beier/Rayfield plausible-range logic — NOT a tuning loop).
   Both bounds keep IoU ≥ 0.975. **Asymmetry, recorded honestly:** the LC-heavy
   bound (3b) did not move the path (0 m); the gHM-heavy bound (3a) shortened it
   37.19 → 35.55 km (mean sep 1,312 m, max 3,206 m) via a marginally more direct
   northern route through lower-gHM interior cells. **This 3a shift is the largest
   single sensitivity in the Week-8 analysis.** It is still robust (same corridor,
   IoU 0.976), but the honest limitation is: the corridor *location* is robust,
   while the corridor's *exact route/length* has ~1.5 km of play tied to the gHM
   weight — an author prior without empirical backing. The asymmetry is
   ecologically sensible (gHM is the dominant discriminator in this human-dominated
   landscape, so up-weighting it has more leverage than down-weighting it).

**Overall verdict:** the SC Mtns ↔ southern Diablo corridor is **robust to the
known data limitations** — AADT interpolation bias, WorldCover chaparral
under-mapping, and the author-prior resistance weights. No supplement is
triggered. The one stated caveat is the ~1.5 km route play under gHM up-weighting,
recorded as a §7 limitation, not a re-fit (the weights are pre-registered priors,
Decision 26; this bounds them, it does not tune them). Variant surfaces are
in-memory diagnostics only — none is written to disk or substituted for the
Decision-26 baseline.

*Outputs:* `tbl_22`, `fig_21`. No new spatial layers (variants are diagnostic).

---

** Decision 36 — Puma Q5 cross-read: corridor CONVERGES with the descriptive pattern
*Date:* 2026-08-20 · *Status:* **CLOSED** (`07f_corridor_crossread.R`; `tbl_23`,
`fig_22`).

Proposal Q5 for the puma track: does the modelled (structure-driven) corridor run
through the Week-6 descriptive (effort-shaped) occurrence pattern — KDE + Gi* — or
diverge from it? A corridor is "where pumas MOVE BETWEEN cores", not "where pumas
ARE", so this is a three-part read (endpoint check / corridor-vs-pattern / Q5
effort), not the single ψ-vs-KDE correlation used for bobcat.

**Result — CONVERGENCE (and this reverses the pre-analysis expectation, recorded
honestly).** The pre-analysis guess was divergence — that the corridor, especially
the Coyote Valley pinch, would run through LOW-KDE occurrence gaps (pumas moving
through a developed pinch unobserved). **The data says the opposite:**

- **Endpoints high** (SC Mtns 78th KDE percentile, 11 Gi* hot units; S Diablo
  53rd, 4 hot units) — cores are where pumas concentrate, as expected.
- **The whole corridor runs through above-median density** — LCP median 77th KDE
  percentile, range 53–93, **0% of the LCP below the median** (no matrix crossing).
  Swath mean 73rd (core) / 68th (context) percentile.
- **The Coyote Valley pinch is 83rd KDE percentile — HIGH, not the predicted low.**
  (The LCP centre-line passes 1.6 km from the exact pinch cell — the 1 km grain;
  the pinch value is the cell, not the on-LCP value.)
- **Gi* hot units on the corridor: 7, of which 6 TRUSTED / 1 SUSPECT** — the hot
  units the corridor crosses are mostly NOT effort artifacts.

So two independent methods — structure-driven least-cost and effort-shaped
descriptive KDE/Gi* — **agree on where the corridor is**, and the agreement is
mostly effort-independent (6/7 TRUSTED). This is **corroboration, but only
weak-to-moderate and partly structural — NOT independent validation.** The
literature is explicit on both points: (a) corridor-through-high-occurrence is the
*expected* result, since least-cost paths by construction follow suitable habitat
and occurrences concentrate in the same suitable habitat (Larkin et al. 2004;
LaRue & Nielsen 2008), so agreement is what a working model *should* produce and
is a recognised validation approach (LaRue & Nielsen modelled corridors to
confirmed occurrences; Chetkiewicz & Boyce 2009 found telemetry supported some
modelled crossings); BUT (b) our resistance surface (Decision 26) and the KDE
share a land-cover/gHM foundation, so part of the convergence is two views of the
SAME landscape gradient, not two independent confirmations.

**What keeps the convergence meaningful despite the shared foundation:**
- **The 6/7 TRUSTED Gi* hot units** are occurrence concentration that is NOT
  effort-driven — real puma presence on the corridor, the load-bearing evidence
  against pure circularity.
- **The corridor carries a road/barrier (AADT) term the KDE does not** — they are
  not the same construct; convergence *despite* that added structure is more than
  shared-terrain agreement.

**What it is NOT:** strong or independent validation. That would require telemetry
/ movement data (the literature gold standard — Chetkiewicz & Boyce 2009 used GPS
collars; we have occurrence points only). Furthermore, the comparative-evaluation
literature (Unnithan Kumar et al. 2022, *Sci Rep*) found the precise least-cost
PATH is the least accurate connectivity form against simulated true movement,
while resistant-kernel-like SWATHS overlap true connectivity far better — so the
two-tier SWATH (not the centre-line) is the more defensible product, and the story
should lead with it. Our corridor is a plausible, occurrence-corroborated
hypothesis, not a validated movement route.

**Two caveats, stated so the convergence is not over-read:**
1. **Effort entanglement.** KDE is effort-shaped. "Corridor follows density" could
   mean the corridor is real (pumas are there) OR both the occurrence data and the
   corridor are drawn to the same accessible, well-surveyed valley-edge terrain.
   The 6/7 TRUSTED hot units argue for the former (real corroboration), but the
   convergence is stated WITH its effort caveat, not as clean independent proof.
2. **KDE bandwidth bleed.** At σ = 5 km (Decision 28, home-range prior), the
   high-density SC Mtns and Diablo cores smear density into the 1 km-wide pinch
   between them, so the pinch's 83rd percentile is partly flanking-core bleed, not
   purely pinch-local observation. Cannot be cleanly separated here; likely BOTH
   real observed use (Coyote Valley is a known, watched linkage) and bleed.

**Cross-track contrast (a genuine finding, not a coincidence):**
- **Bobcat (Decision 31, Week 7):** modelled ψ **diverged** from descriptive KDE
  (ψ-vs-KDE r = 0.075) — the descriptive pattern was effort-shaped and the
  occupancy model (which has an explicit detection/effort sub-model) corrected it.
- **Puma (this Decision):** modelled corridor **converges** with descriptive
  KDE/Gi* — the least-cost model has NO effort term, yet lands on the same places
  as the occurrence data, which is *stronger* evidence the puma pattern is real
  terrain-driven signal rather than effort.

The split is mechanistically sensible: the bobcat model is *designed* to pull away
from raw effort-shaped counts; the puma corridor is pure landscape structure, so
its convergence with the independent occurrence data is corroboration rather than
circularity. Stated as the puma-track Q5 finding.

*Outputs:* `tbl_23`, `fig_22`. No new spatial layers.

---

** Decision 37 — Puma core-connectivity network: Gabriel graph + weak-link ranking
*Date:* 2026-08-20 · *Status:* **CLOSED** (`07g_corridor_network.R`; `tbl_24`,
`fig_23`, network + weak-swath layers).

Extends the single SC↔Diablo linkage (Decision 33) to a study-area connectivity
network, to answer "how is the whole large-core system connected, and where is it
weakest" (proposal Q3, network scale).

> **CORRECTION (Decision 38, 2026-08-25):** two figures in this entry are wrong
> against the code as run (`07g_corridor_network_stage1/2.R`). The node cutoff was
> **20 km², not 30 km²** (`NODE_CUTOFF_KM2 <- 20`), giving **44 nodes**
> (`tbl_24a_network_nodes.csv`), not 29. And the SC→Diablo chain in Finding 1
> below was **never traced**: patch 1727 is not in the node set, the
> `if (all(c("1727","3972") %in% V(g)$name))` guard was FALSE, and no chain
> output was written. The "1727→2618→3250→3972, cost 185.5" figures are stale and
> must not be cited. The weak-link ranking, the two-subnetwork finding, and the
> traffic-pinch-vs-structural-weak-link distinction are unaffected and stand. See
> Decision 38 for the full correction. The original text is kept below for audit.

**Design.**
- **Nodes = 29 large cores ≥ 30 km²** (cutoff from the observed core-area
  distribution scan: clean break 44→29→19 at 20/30/50 km²; 30 km² = "population
  anchor" tier, well above the 5 km² endpoint floor — small cores are
  stepping-stones, not network nodes). *[Superseded — see correction above: cutoff
  was 20 km², 44 nodes.]*
- **Edges = Gabriel graph on core centroids** (`spdep::gabrielneigh` —
  version-independent; keeps near-neighbour alternatives so a weak link = a
  connection with no alternative, unlike an MST where every edge looks critical).
- **Paths = `create_lcp` per edge, boundary-to-boundary** (only `create_lcp`,
  confirmed in leastcostpath 2.x; `create_lcp_network` is 1.x). Same corrected
  resistance (Decision 34) + conductance (1/R, 16-neighbour, Decision 33).
- **Weak links = costliest routed edges** (highest cost-distance). Chain from
  SC↔Diablo traced via `igraph` shortest cost path (edges weighted by
  cost-distance).

**Results (49 Gabriel edges: 38 routed, 11 same-cell adjacencies).**

*Same-cell adjacencies (11/49, 22%).* Eleven edges join cores whose nearest
boundary points fall in the SAME 1 km cell — functionally contiguous cores a puma
crosses within one cell. Recorded as `adjacency` (cost 0, the STRONGEST links),
not dropped. The high adjacency fraction shows the large cores **cluster** (SC
Mtns cluster, Diablo cluster, North Bay cluster), so fragility lives in the sparse
INTER-cluster links.

*Finding 1 — SC→Diablo is a low-cost stepping-stone chain, not the direct link.*
*[SUPERSEDED by Decision 38 — this specific chain was never traced by the code as
run; 1727 is not a network node and the trace guard was FALSE. The node-cost
CONTRAST it describes (south-Bay links cheap, cross-bay links costly) is real and
is retained via the cost-distance ordering of the edges; the specific node path
and the 185.5 figure are withdrawn. Original text kept for audit:]*
The network routes SC Mtns → S Diablo as **1727 → 2618 → 3250 → 3972** (3 hops,
total cost **185.5**) — roughly HALF the direct primary-corridor cost (~325,
Decision 33). A puma would hop through the intermediate south-Bay cores (2618
Santa Clara, 3250 Santa Clara / Coyote Valley area), not take the forced direct
route. This confirms + strengthens the stepping-stone framing: the intermediate
Coyote Valley cores are the EFFICIENT path; losing them forces the animal onto the
costlier direct route.

*Finding 2 — the network's structural weak links are the CROSS-BAY connections,
NOT Coyote Valley.* Costliest routed links (`tbl_24`): **1053↔1899** (cost 1063,
61 km; San Mateo Peninsula ↔ Contra Costa/Mt Diablo), **1053↔3289** (804, 42 km;
Peninsula ↔ Alameda), **752↔1899** (729, 48 km; Marin ↔ Contra Costa). These
connect the **Peninsula/SC-Mtns cluster to the East-Bay/Diablo cluster ACROSS the
central urbanized Bay** — long, high-resistance spans with no stepping stones. The
Coyote Valley chain edges are CHEAP (cost 185 total), not weak. **So the famous
traffic pinch (Coyote Valley / US-101) is NOT the structural weak point** — its
importance is the traffic BARRIER (142k AADT, Decision 34 crossing analysis), a
different axis from network fragility.

*Finding 3 — the central Bay splits the network into two subnetworks.* Reading 1+2
together: the Bay is a near-complete barrier separating a **Peninsula/SC-Mtns
subnetwork** from an **East-Bay/Diablo subnetwork**, connected efficiently only at
the SOUTH (the Coyote Valley stepping-stone chain) and tenuously across the middle.
The SC→Diablo chain works *because* it routes around the south end. This aligns
with known biology — SC Mtns pumas are famously isolated, connected to the Diablo
Range mainly via the south Bay.

**Caveat — cross-bay weak links are partly artifactual (recorded, load-bearing).**
A 61 km least-cost path across the entire developed bayshore is at the edge of
biological plausibility; pumas do not routinely traverse the urban Bay. The
Gabriel graph FORCES a connection between geometric neighbours regardless of
realism, and the LCP dutifully finds the least-bad route across an essentially
impassable barrier. So the very-longest cross-bay links mean "these clusters are
effectively DISCONNECTED", not "here is a corridor to protect." The weak-link
RANKING is valid within the Gabriel topology; the cross-bay link IDENTITIES should
be read as disconnection evidence, not conservation-target corridors. The
south-Bay (Coyote Valley) chain, by contrast, IS a real protectable connection.

**Ceiling (inherited).** Like Decision 36, the network is a hypothesis from an
author-prior resistance surface, not a telemetry-validated result; the weak-link
cost-ORDERING has some give (Decision 35: ±10% gHM weight → ~1.5 km route play),
so weak-link identities are robust but exact ranking is approximate.

*Outputs:* `lcp_puma_network_3310.gpkg` (38 routed edges),
`lcp_puma_network_weaklinks_swath_3310.gpkg` (5 costliest swaths), `tbl_24`,
`fig_23`.

** Decision 38 — Correction to Decision 37: node cutoff and the un-traced SC→Diablo chain
*Date:* 2026-08-25 · *Status:* **CLOSED** (documentation correction; no re-run).

Preparing the Week-9 network map surfaced two claims in Decision 37 that do not
match `07g_corridor_network_stage1/2.R` as run. Both are corrected here; Decision
37 is annotated, not rewritten, so the original record and its correction are both
preserved.

**What was wrong.**
1. **Node cutoff and count.** Decision 37 states "29 large cores ≥ 30 km²." The
   code sets `NODE_CUTOFF_KM2 <- 20` (stage 1, line 50) and `tbl_24a_network_nodes.csv`
   contains **44 nodes**, area range 20.22–500.35 km². The correct statement is
   **44 candidate nodes at ≥ 20 km²**. (Of these, the Gabriel graph + LCP routing
   connected the subset that appears in the 38-edge routed layer.)
2. **The SC→Diablo stepping-stone chain was never traced.** Decision 37 Finding 1
   reports a chain "1727 → 2618 → 3250 → 3972 (3 hops, cost 185.5)." The chain
   trace in stage 2 is guarded: `if (all(c("1727","3972") %in% V(g)$name))`. Patch
   **1727 is not a network node** (confirmed: `"1727" %in% V(g)$name` is FALSE), so
   the guard was FALSE, the trace did not execute, and `chain_note` kept its
   fallback string. **No chain table was written** (only `tbl_24_network_weaklinks.csv`
   and `tbl_24a_network_nodes.csv` exist). The "185.5 / 3-hop" figures are not a
   product of this analysis and are withdrawn.

**Why 1727 is absent.** 1727 (Santa Cruz Mountains, 177 km²) is the endpoint of the
single SC↔Diablo *corridor* (Decision 33), identified by nearest-boundary snapping
in the corridor layer. The *network* (Decision 37) selects its own nodes from the
core layer by area; the SC-Mtns end is represented in the network by different
core geometry, and the corridor-endpoint ID 1727 does not carry over as a network
node. The two analyses use different node identities — a cross-layer subtlety that
the Decision-37 text elided by reusing 1727 for both.

**What still stands (unaffected).**
- The **weak-link ranking** is correct and code-produced: `tbl_24` and the layer
  agree (1053↔1899 cost 1063; 1053↔3289 cost 804; 752↔1899 cost 729).
- The **two-subnetwork finding** (central Bay splits Peninsula/SC-Mtns from
  East-Bay/Diablo) stands — it rests on the weak-link geography, not the chain.
- The **traffic-pinch ≠ structural-weak-link distinction** stands. Coyote Valley /
  US-101 remains the traffic barrier (142k, Decision 34); the structural weak
  links remain the cross-bay spans.
- The **strong-vs-weak contrast** is retained through the edge `cost_distance`
  ordering directly: south-Bay edges are cheap (strong), cross-bay edges are
  costly (weak). The contrast does not require the named chain.

**Consequence for deliverables.**
- The Week-9 network map shows edges coloured by cost (cheap/strong → costly/weak)
  and flags the cross-bay weak links with the artifact caveat. It does **not** draw
  a labelled "1727→…→3972" chain, because that path is not in the data.
- Site prose (`puma.qmd`) is corrected to describe the cheap-south / costly-cross-bay
  contrast without asserting the specific node path or the 185.5 figure.
- No analysis is re-run. Producing an actual traced chain would require forcing
  1727 into the node set or re-defining the SC-Mtns network node, which is new
  analysis and is deferred, not done here.

**Justification for correct-to-code over re-run.** Week 9 is content-and-deploy;
correctness of the record takes priority when a genuine error is found (cf. the
US-101 AADT correction, Decision 34), but the fix here is to the *documentation and
the claim*, not the analysis — the analysis outputs are correct, only their
description was wrong. Recording the discrepancy and withdrawing the unsupported
figures is the pre-registration-consistent action; a re-run to manufacture the
chain would be new analysis outside this week's scope.

*Docs updated:* this entry; Decision 37 annotated (node count + Finding 1 flagged);
Decision-log line for D37 corrected; `data-dictionary.md` network-layer cutoff
(30→20 km²); site `puma.qmd` network prose. Next Decision number is 39.

---

## 7. Known limitations

- **No population time series.** There is no repeated regional census
  equivalent to the NTCA rounds used in the tiger project. Narrative is
  distribution and connectivity, not recovery.
- **Detection effort bias.** Opportunistic occurrence records concentrate near
  trailheads, roads and parking areas. Same artefact documented in tiger
  Phase 1; must be stated explicitly wherever KDE or Gi* output is shown.
- **Bobcat Gi* hot-spot count is low by spatial arrangement, not scarcity.**
  Bobcat returns only 6 Gi* hot units despite abundant data. This is a real
  spatial-structure result (verified by Global G QC, Decision 30): bobcat's
  high-count units are spikier and more spatially isolated than puma's, so fewer
  form the jointly-high neighbourhoods Gi* requires. The bobcat KDE surface
  (§5.2) is the better *distribution* product; the Gi* is the better
  *statistical-cluster* product. The low hot-spot count must not be read as "few
  bobcats" — 351 units hold bobcat records and 34% of precise points fall in the
  matrix outside any unit.
- **Coordinate obscuring.** iNaturalist obscures puma coordinates. Records are
  usable for coarse distribution only.
- **Occupancy design.** Opportunistic records are not survey data. Any
  occupancy model built on them requires explicit, documented assumptions. The
  bobcat detection history (Decision 22 draft) is *constructed*, not surveyed:
  site = CPAD unit, replicate = calendar year (2010–2026), non-detections
  established from target-group iNat effort (Fork 3), never from empty cells.
  Two caveats ride the gate: (1) **52% of bobcat records fall outside CPAD units**
  and are excluded from the occupancy frame by design — occupancy is on open
  space; the out-of-unit urban-edge records inform proposal Q5, not ψ. (2) **36%
  of occupied units are single-record** — ψ-informative but p-uninformative;
  their occupancy estimate leans on covariates at fit.
- **Open space ≠ habitat.** CPAD includes urban pocket parks and non-habitat
  holdings; filtering criteria must be defined and justified.

---

## 8. Reproducibility

1. Clone the repository.
2. `renv::restore()` to install pinned package versions.
3. Acquire source data following `data/README.md`.
4. Run `scripts/` in numeric order, or `targets::tar_make()`.

Data is not committed. All open sources are publicly downloadable. Partner data
is not redistributable.

---

## 9. Change log

| Date | Section | Change |
|---|---|---|
| 2026-07-23 | — | Repository created; documentation scaffold established |
| 2026-07-23 | 2 | CRS set to EPSG:3310 (California Albers) |
| 2026-07-23 | 6 | Decision 1 recorded — R replaces ArcGIS Pro |
| 2026-07-23 | 6 | Decision 3 recorded — parallel species tracks |
| 2026-07-25 | 4.8 | Felidae Wildpod CSV received (218 stations); T3, restricted; schema logged |
| 2026-07-25 | 5.7 | Station → open-space association method added (staged) |
| 2026-07-25 | 6 | Decision 4 — exclude Los Angeles sub-region / clip to study area |
| 2026-07-25 | 6 | Decision 5 — staged association, rejected blanket 10–20 mi buffer |
| 2026-07-25 | 6 | Decision 6 — provenance/agreement pending before publication |
| 2026-07-26 | 3 | Environment verified (R 4.5.2, sf 1.1.1, terra 1.9.27, GDAL 3.12.1, GEOS 3.14.1, PROJ 9.7.1); PostGIS proj.db conflict documented + fixed in .Rprofile |
| 2026-07-26 | 6 | Decision 2 resolved — ten-county study area (locked in R/00_config.R) |
| 2026-07-26 | 6 | Decision 7 — Felidae deferred to a future phase; §4.8/§5.7 retired; Decisions 4–6 deferred |
| 2026-07-27 | 4.1 | CPAD 2026a downloaded + inspected (Holdings 162,773 / Units 17,930 / SuperUnits 17,169; all EPSG:3310) |
| 2026-07-27 | 6 | Decision 8 — open-space source: statewide CPAD 2026a, not BPAD |
| 2026-07-27 | 4.1 | CCED 2026a downloaded + inspected (23,645 easements, EPSG:3310); coverage-gap handling noted |
| 2026-07-27 | 6 | Decision 9 — CCED used as-is; gap quantified (Rangeland Trust 2nd-largest holder, 1,865; CDFW 988), not supplemented |
| 2026-07-27 | 4.1 | Study-area boundary built (tigris TIGER/Line 2024, cb=TRUE, 10 counties, EPSG:3310, 19,623 km²) |
| 2026-07-27 | 4.2 | GBIF downloaded (DOI 10.15468/dl.87ne3u); puma 1,843 / bobcat 5,164; puma coords dominated by ~28 km iNat obscuring |
| 2026-07-27 | 4.3 | iNaturalist downloaded (rinat, research-grade); puma 2,102 (50% obscured) / bobcat 6,295 (31% obscured); precise-puma pool larger than feared |
| 2026-07-27 | 4.3 | Obscuring decomposed: puma & bobcat obscuring both observer-set; *Puma concolor* NOT taxon-obscured in CA; ~1,057 precise puma points held — sensitive-data-policy rules load-bearing |
| 2026-07-27 | 6 | Decision 10 — puma obscuring observer-driven not taxon policy; precise puma data held; policy §1 rationale corrected, coarsening rules load-bearing |
| 2026-07-27 | 4.3 | iNat positional-accuracy spread logged (non-obscured: puma median 26 m / bobcat 31 m); puma precise pool confirmed |
| 2026-07-27 | 4.4 | CROS terms confirmed — no open download / no published licence; request-gated (Decision 11); acquisition deferred, published hotspots as fallback |
| 2026-07-27 | 6 | Decision 11 — CROS request-gated; confirm republication terms in writing before use; no scraping |
| 2026-08-02 | 4.4 | CROS data request sent to F. Shilling (Road Ecology Center); awaiting terms |
| 2026-08-02 | 6 | Decision 12 — land-cover source: Annual NLCD (developed-intensity gradient), over WorldCover/FVEG |
| 2026-08-02 | 6 | Decision 12 amended — pivoted land cover NLCD → ESA WorldCover 2021 (NLCD access unworkable); urban gradient moved to GHM/housing |
| 2026-08-02 | 4.5 | Land cover downloaded (ESA WorldCover 2021 v200, EPSG:3310); WorldCover under-maps CA chaparral (shrub ~123 km² vs NLCD ~3,200) — flagged, FVEG supplement if needed |
| 2026-08-03 | 4.6 | Terrain downloaded (AWS Terrain Tiles via elevatr, z=12, EPSG:3310; DEM + derived slope/aspect); ~30 m effective (15.1 m reprojected grid); elevation −123–1,439 m; sub-sea-level minima confirmed as coastal/bay/Farallones water artefacts, not bad tiles |
| 2026-08-03 | 6 | Decision 13 — terrain source AWS Terrain Tiles (elevatr z=12), NOT native 3DEP 10 m; "3DEP 10 m" wording corrected; bilinear reproject; slope/aspect post-projection; 1 m lidar deferred |
| 2026-08-03 | 4.7 | Roads downloaded (Geofabrik NorCal extract, OSM; `fclass`; 936,784 features clipped, EPSG:3310); full + major/barrier subsets written. CA-statewide extract unavailable (stale 2014-2018 only) → NorCal sub-region used |
| 2026-08-03 | 4.7 | Traffic downloaded (Caltrans Traffic_AADT MapServer, 2023; 2,423 stations clipped, EPSG:3310); AHEAD/BACK_AADT stored as strings; state-highway-only + AADT→segment join flagged for Week 5 |
| 2026-08-03 | 6 | Decision 14 — roads via Geofabrik NorCal (`fclass`), not osmdata/Overpass or stale CA-statewide; traffic via Caltrans AADT; open items: tracks/paths permeability + AADT-segment join deferred to Week 5 |
| 2026-08-03 | 4.9 | Human modification downloaded (gHM v3 2022, Theobald 2024, AA 300 m COG; windowed /vsicurl off 9.3 GB global file, EPSG:3310, bilinear); values confirmed in [0,1] |
| 2026-08-03 | 6 | Decision 15 — gHM source v3/2022 (Zenodo COG, /vsicurl), NOT Kennedy 2019 1 km figshare/GEE; citation swaps Kennedy 2019 → Theobald 2024; auth-free acquisition preserved |
| 2026-08-03 | 4.9 | Housing density downloaded (SILVIS block-level PLA v4, CA extract; EPSG:5070 → 3310; blocks clipped; HUDEN1990–2020 + PUBFLAG retained); PLA check: public-land blocks near-zero by construction |
| 2026-08-03 | 6 | Decision 16 — housing via SILVIS block-level (density baked in), not Census/tidycensus build; caveats logged: PLA zeroes protected-area density, no WUI flags in this product |
| 2026-08-03 | 4.9 | SILVIS QC: HUDEN2020 median 846 / p90 2,959 / max 2,263,007 units/km² — small-area (sliver-block) density artifact, not a download error; Week-5 handling pre-registered (log1p primary + p99/hard cap before rasterization); PLA public-land median 0 confirmed by design |
| 2026-08-03 | 4.5/4.7/12 | Cross-ref correction — footprint layers are §4.9 (not §4.4, which is CROS); pointers in Decision 12 and §4.5/§4.7 read as §4.9 |
| 2026-08-05 | 6 | Decision 17 recorded — CPAD Units as analysis site unit; SuperUnits ruled out (near-flat ~4% aggregation, no COUNTY field), Holdings ruled out (fragments habitat on ownership seams); hierarchy carried as suid_nma/holding_id attributes; ten-county membership by spatial clip to boundary_baydissolved (COUNTY attribute audit-only); join on UNIT_ID not UNIT_NAME (~2,900 shared names); spans_gradient flag added (hab_area_km2 > 5 km², 192 units) as Week-4/5 covariate pre-flag, not a filter |
| 2026-08-05 | 6 | Decision 18 recorded — non-habitat filter: 0.10 km² floor on habitat area (removes 71% of units, ~1% of area) + SPEC_USE/LAND_WATER/Cemetery-District deny-list flagged at Holdings level pre-dissolve; ACCESS_TYP deliberately excluded (No Public Access = 12.6% of area, incl. SFPUC watershed/ranch easements); non-habitat flagged-not-erased; hab_frac ≥ 0.50 cutoff (bimodal dist, insensitive 0.4–0.6, confirmed not provisional); result 4,375 → 1,142 (floor) → 1,129 units, 4,660.4 km² habitat, 106 has_nonhabitat |
| 2026-08-05 | 6 | Decision 19 recorded — CPAD∪CCED kept as separate connectivity frame, not folded into occupancy layer; protection_type {fee, easement} with fee precedence on overlap (Option b, tenure preserved); result 3,773 features (1,129 fee + 2,644 easement), 498.2 km² fee/easement overlap erased, 155 easements dropped wholly-inside-fee, CCED adds 1,275.7 km² new protected land; fee 4,720.8 km² (raw st_area) vs occupancy 4,660.4 km² (hab_area) reconciled — ~61 km² flagged interior non-habitat, not a discrepancy |
| 2026-08-05 | 4 | Built openspace_cpad_bayarea_3310.gpkg (occupancy frame, 1,129 units, scripts 02/02b/02c), protected_union_bayarea_3310.gpkg (connectivity frame, 3,773 features, script 02d), grid_puma_1km_3310.tif (20,416 land cells) + grid_bobc_500m_3310.tif (80,073 land cells, nested 4:1, script 02e); all EPSG:3310; four layers added to data-dictionary.md |
| 2026-08-09 | 4.2/4.3 | Built occ_puma_clean_3310.gpkg (2,031: 1,028 precise + 1,003 obscured) + occ_bobc_clean_3310.gpkg (6,232: 4,420 precise + 1,812 obscured), script 03; GBIF∪iNat identity-deduped (all 6,781 iNat-sourced GBIF rows matched .rds; only 226 non-iNat GBIF additive: 17 puma / 209 bobcat), 360 rows / 4.2% clipped outside boundary |
| 2026-08-09 | 6 | Decision 20 recorded — occurrence dedupe on iNat observation ID not coordinates (obscured puma coords randomised, differ between feeds); iNat .rds is master, GBIF contributes non-iNat remainder only (17 puma / 209 bobcat) |
| 2026-08-09 | 6 | Decision 21 recorded — puma obscured records kept in-layer under `obscured` flag, no date filter, not split or cut; Decision 10 confirmed empirically (zero puma taxon_geoprivacy="obscured"); publish-time coarsening per sensitive-data-policy §3 |
| 2026-08-09 | 6 | Decision 20 amended — no coord_uncert_m cutoff at layer stage; `coord_uncert_m` preserved on every record, coordinate-quality filtering deferred per-analysis (occupancy/connectivity/KDE tolerate different error); flag-not-cut, consistent with Decision 21 |
| 2026-08-09 | 5.4/6 | Risk 1 occupancy gate assessed (script 03a, diagnostic only); pre-fit §5.4 criteria PASS on 2010–2026 window — 321 site histories, 194 units ≥2 detection-years, naive ψ 0.284; site=CPAD unit, replicate=calendar year. Decision 22 DRAFTED (occupancy proceeds, not SDM) but HELD OPEN pending Fork-3 background-effort pull that supplies real non-detections; p/instability/GOF deferred to Week-7 fit |
| 2026-08-09 | 4.3/6 | Fork-3 background effort built (script 03b) — reframed rinat→GBIF async download (iNat 10k cap unworkable, capped even at month/week for City Nature Challenge); GBIF all-datasets vertebrate, dissolved-boundary WKT footprint, 2010–2026, bobcat excluded (DOI 10.15468/dl.6xzcjt; 33.0M pulled, 17.2M in-unit). Two effort layers written (mammal 3A / vertebrate 3B). Fork-3 dependency for Decision 22 SATISFIED; A-vs-B held to Week-7 fit (mammal naive p 0.171 vs vertebrate 0.083 — 3B deflated by bird effort) |
| 2026-08-10 | 4.9 | HUDEN2020 transform applied (script 04): raw winsorized at study-area p99 = 10,415 units/km² then log1p; 913 blocks capped (1.00%); PLA zeros untouched; hard-ceiling counts recorded not applied (>1e4 988, >1e5 1, >1e6 1). Rasterized to puma 1 km + bobcat 500 m (fine-burn to aggregate); per-unit footprint layer cov_unit_footprint_3310.gpkg written (0 housing NAs) |
| 2026-08-10 | 4.9 | gHM rasterized to both grids (bilinear) + summarised per unit (area-weighted, native 300 m). Edge-fill: bilinear left land-cell boundary-underlap NAs (1,140 puma / 3,578 bobcat, source cropped to 5 km buffer); filled from nearest valid neighbours, land-bounded, 6 puma / 3 bobcat residual (<0.03%); 0 interior holes; per-unit gHM 0 NA |
| 2026-08-10 | 6 | Decision 23 Part A CLOSED — HUDEN2020 p99 cap (10,415 units/km²) + log1p applied as pre-registered; p99 converged on the 1e4 hard line (988 blocks), confirming the ceiling non-arbitrary; artifact compressed pre-rasterization |
| 2026-08-10 | 6 | Decision 23 Part B CLOSED — gHM×housing collinearity per species (unit r=0.07 PLA artifact, bobc 500 m r=0.73, puma 1 km r=0.75, post gHM edge-fill). Bobcat occupancy (unit grain): keep both, PLA caveat carried. Puma resistance (1 km grain, r=0.75): drop housing, keep gHM. Both source layers retained on disk |
| 2026-08-12 | 6 | Decision 24 CLOSED — tracks/paths NOT barriers for either species (per-species reasoning: puma functionally crossable; bobcat disturbance carried by gHM/housing). road_class + barrier_puma/barrier_bobc flags on cov_roads_classed_3310.gpkg |
| 2026-08-12 | 6 | Decision 25 CLOSED — AADT string parse (max leg) + 4-tier propagation (measured -> name_fill -> spatial_fill[measured-donor only, 1 km] -> fclass floor), each flagged in aadt_source. spatial_fill skews high (arterial 41k vs measured 27k) = documented DATA PROPERTY (stations sample busy roads), not a join bug; not correctable by interpolation. Station-traceable 55.4%, floor 44.6%; floor accepted. AADT→resistance treatment (bin vs value, per-tier confidence) deferred to resistance pre-reg. cov_roads_traffic_3310.gpkg |
| 2026-08-12 | 4.8 | Roads/traffic finalised (Decision 14 open items 1+2 closed): cov_roads_classed_3310.gpkg, cov_roads_traffic_3310.gpkg |
| 2026-08-15 | 6 | Decision 26 CLOSED — puma resistance-surface assignment pre-registered, approved, and built (04c_puma_resistance.R). R_land = 0.45*r_ghm(convex) + 0.40*r_lc(class-fraction) + 0.15*r_slope; R = max(R_land, R_road) on barrier_puma cells; R_road = log-inverse AADT transform (Hansen 2025 method for these pumas, p1/p99=4,000/237,000), replacing the earlier bins after literature review. Aspect + housing (Decision 23) excluded; conspecific density considered-and-excluded. Weights are author priors (no collar data); structure/effect-directions sourced to Hansen 2025 / Zeller 2016 / Wilmers 2013 |
| 2026-08-15 | 5.5 | resist_puma_baseline_3310.tif built — 1 km, 20,410 cells, 1-100; median 17.2, mean 29.7, pct_barrier>=80 7.4%, 5,507 road cells. Verified against known connectivity (SC Mtns + Diablo permeable, urban bayshore barrier, Coyote Valley/US-101 pinch resolved). aadt_conf companion band written. 3 pre-registered sensitivity checks pending (run on corridor stability) |
| 2026-08-15 | refs | Added Hansen et al. 2025 (bioRxiv, 84-puma SC Mtns iSSF/EcoScape calibration) + Zeller et al. 2016 (puma resistance-from-step-selection) to references.md — covariate selection, effect directions, log traffic transform |
| 2026-08-15 | 6 | Decision 27 CLOSED — a bobcat detection implies observation effort; detected unit-years encode surveyed+detected (1) even where the target-group background missed them (98 cells, 85 units, mammal_precise). Prevents a proxy miss from discarding real detections / deflating p. Non-detected unsurveyed cells stay NA. Logged in tbl_08_detections_upgraded_d27.csv |
| 2026-08-15 | 6/5.4 | Decision 22 CLOSED — occupancy confirmed on 3A mammal background. Null occu(~1 ~1): fitted p=0.295 (annual, clears 0.10 line 3x), converged, psi=0.464 identifiable. Annual MB-GOF degenerate on sparse histories (590 patterns, c-hat~514 artifact); collapsed to 4 periods (44 patterns) -> c-hat=8.9 = expected null-model overdispersion (heterogeneity is the research signal), NOT a fallback trigger. SDM fallback not triggered. Forward check pre-registered: covariate-model c-hat must decline. Scripts 08-09 |
| 2026-08-15 | 5.4 | Bobcat detection histories built (08): 4 variants (3A/3B x precise/all), unit x year 2010-2026, 1/0/NA encoding. Null fits (09): all 4 clear p>0.10 (0.197-0.318), all converged; verdict robust to background + obscured choice |
| 2026-08-16 | 6 | Decision 28 CLOSED — KDE bandwidth by pre-registered rule (not a fixed value, not a post-hoc look). Three candidates computed + printed (bw.diggle, bw.ppl, home-range prior puma 5,000 m / bobc 1,500 m); choose by fixed rule: reject sub-cell, reject < home/3 (effort-collapse), take smallest survivor, else home prior. Puma: diggle 48.8 + ppl 1,458.1 both rejected -> home 5,000 m (rule 4). Bobc: ppl 1,109.6 m chosen (rule 3). Bobcat effort floor (500) == cell (500) coincided — noted, not two independent guards. Recorded in tbl_09_kde_bandwidth_selection.csv |
| 2026-08-16 | 6 | Decision 29 CLOSED — KDE obscured-coordinate handling: published surfaces precise-only both species (puma 1,028 / bobc 4,420 points); ~28 km randomised obscured coords excluded from published density. Separate caveated obscured-puma companion (kde_puma_obscured_caveat_1km_3310.tif, 1,003 pts, home bandwidth) for Q5 effort read only — NOT distribution, NOT published KDE. Bobcat no companion (29% obscured, precise-dominant, low-sensitivity); asymmetry deliberate. All puma exports gated via assert_publishable(); no sub-1 km puma intermediate written |
| 2026-08-16 | 5.2/5.5 | KDE built (script 05_kde_and_hotspots.R PART 1): kde_puma_current_1km_3310.tif (precise-only, sigma 5,000 m), kde_puma_obscured_caveat_1km_3310.tif (T2 companion), kde_bobc_current_500m_3310.tif (precise-only, sigma 1,109.6 m). density.ppp() + Jones-Diggle edge correction, dissolved boundary as owin. Three rasters + tbl_09 added to data-dictionary.md. Gi* + Q5 effort cross-read (PART 2) next |
| 2026-08-16 | 6 | Decision 30 CLOSED — Gi* hot-spot design. Grain: CPAD unit (matches effort layer; grid impossible, background points not retained). Neighbours: TWO corrections recorded — queen contiguity (stranded 485/1,129 units, 630 sub-graphs, rejected) -> KNN k=8 (distance-blind, diluted dense clusters, bobcat collapsed to 3, rejected) -> fixed distance band 6,342 m (data-sized to ~8 neighbours) + KNN-8 floor (408 units topped, 32 sub-graphs). include_self, binary weights. Band shared across species (one tessellation). Point->unit assignment three-way, grounded in each record's coord_uncert_m (~26-31 m median), NOT a 1-2 km constant (literature: ground snap in positional error). Matrix points retained as occ_<sp>_matrix layers (Q5 + connectivity signal). Q5 effort cross-read first-class (SUSPECT/TRUSTED). 999 perms, BH-FDR, alpha 0.05 |
| 2026-08-16 | 5.3 | Gi* built (05_kde_and_hotspots.R PART 2). Results: puma 47 hot/430 cold, bobc 6 hot/224 cold, effort 104 hot/112 cold. Point assignment: puma 657 inside/79 snapped/292 matrix; bobc 2,502/396/1,522. Q5: puma 25 suspect/22 trusted, bobc 2 suspect/4 trusted. Outputs hot_puma_gistar_unit_3310.gpkg, hot_bobc_gistar_unit_3310.gpkg, occ_puma_matrix_3310.gpkg (interim), occ_bobc_matrix_3310.gpkg, tbl_10_gistar_q5_crossread.csv. Five entries added to data-dictionary.md |
| 2026-08-16 | 5.3/7 | Bobcat 6-hot-spot result VERIFIED real (not artifact) via retained Global G QC: both species significant positive Global G (puma z~31, bobc z~9.9, p~0) = real clustering present with intact local structure (puma 47 hot), so no global-gradient artifact, no detrending. Bobcat highs spikier/more isolated (69% zero units, max 519, p99=29) -> fewer jointly-high neighbourhoods. Logged as §7 limitation: low hot count is spatial arrangement, not scarcity |
| 2026-08-16 | 5.1 | Per-unit summary stats built (05 PART 3): stats_puma_unit_3310.csv + stats_bobc_unit_3310.csv, 1,129 units each, keyed unit_id, never pooled (Decision 3). Fields: occurrence counts (n_occ inside+snapped / n_total incl obscured / n_obscured), obscured_frac (FLAGGED sparse/low-meaning — randomised coords, 163 puma / 322 bobc units with points), effort_years, coverage-weighted kde_mean+kde_max (exactextractr; ~300 units NA = masked KDE cells, not zero), gistar_z/hotspot/q5_flag. Bobcat adds bobc_detected (naive per-unit collapse, NOT modelled psi): 351 detected / 508 surveyed-not-detected / 270 never-surveyed NA. Two entries added to data-dictionary.md |
| 2026-08-17 | 4.3 | Effort layers re-emitted with GRADED intensity (03b): each surveyed unit×year now carries eff_nrec = count of non-bobcat background records, alongside the retained binary surveyed=1 (04d/04e unaffected). Deciles printed for the transform decision. 3A mammal 1/1/1/1/2/3/4/6/10/21/1238 (heavy right skew); 3B vertebrate median 106, max 158,123. eff_nrec field added to both effort-layer dictionary entries. eff_nrec is an observer-intensity PROXY (background volume, not bobcat survey effort) — caveat carried |
| 2026-08-17 | 5.4/6/9 | Decision 31 CLOSED — bobcat covariate occupancy fit (06_occupancy_models.R), pre-registered before fitted values seen. Detection p1 ~eff_nrec_s (scale(log1p(eff_nrec)), transform chosen from observed deciles; ΔAICc 408 over null, year term adds nothing). Occupancy best m_full (terrain+land+human), confidence set {m_full, m_fullgrad} ΔAICc 1.37. gHM×housing model-matrix r=0.094 (Decision 23 keep-both re-confirmed). VIF manual==usdm to 3 dp; lc_frac_tree=5.18 flagged, KEPT with recorded justification (marginal vs VIF≥10, primary habitat axis). psi surface occu_bobc_pred_unit_3310.gpkg (845 units, median 0.669). tbl_11–16 + surface added to data-dictionary.md |
| 2026-08-17 | 5.4/7 | Decision 22 FORWARD CHECK CLOSED — PASSED. Covariate-model collapsed 4-period MB-GOF c-hat = 1.47 (GOF p=0.052), declined substantially from null 8.9: null overdispersion was real habitat heterogeneity absorbed by covariates, not misfit. SDM fallback stays untriggered. Bug fixed en route: mb.gof.test/parboot re-evaluates the stored call in the bootstrap; namespace-prefixed occu() with frame-by-name gave "object 'unmarked' not found" → fixed via attached unmarked + do.call-inlined formula + parallel=FALSE; error now surfaced not swallowed. tbl_14. Q5 cross-read: psi vs KDE r=0.075 (effort-shaped descriptive vs habitat-shaped modelled — stated). Puma feasibility closed: no occupancy fit needed (connectivity/SDM by design) |
| 2026-08-18 | 6 | Decision 32 CLOSED — puma core-habitat patches from the CPAD∪CCED union (Decision 19), fork-A dissolve (all tenure melted, tenure kept as per-patch fee/easement tally), min-patch-area floor 5 km² (home-range anchored, Decision 28 prior; NOT read off the smooth area curve; 1 km²/mid-curve rejected). 164 core endpoints, 3,512 stepping-stones retained, 591 sub-100 m² dust dropped as st_difference artifacts (no snap — st_snap hung O(n²); floor removes dust for free). Endpoints: SC Mtns = patch 1727 (177 km², San Mateo), southern Diablo = patch 3972 (500 km², Santa Clara); two initial seed labels (3972=SC, 220=Diablo) surfaced as WRONG and corrected — 220 is Marin/Mt Tam, not an endpoint. Option (a) dominant-core routing; SC-range fragmentation a stated corridor limitation. tbl_17/tbl_18/fig_17 |
| 2026-08-18 | 5.5 | Core-patch stage built (07_connectivity.R Part 1+2) — lcp_puma_core_patches_3310.gpkg (164), lcp_puma_stepping_stones_3310.gpkg (3,512). leastcostpath 2.0.13 / gdistance 1.6.5 confirmed installed; leastcostpath uses the terra create_cs API (≥2.0), so gdistance is not on the corridor path. Both flagged NOT in renv.lock — snapshot pending. Least-cost path extraction + 3 Decision-26 sensitivity checks pending |
| 2026-08-20 | 6 | Decision 32 CLOSED — puma core patches from the CPAD∪CCED union, fork-A dissolve, 5 km² home-range floor (Decision 28 prior; NOT off the smooth area curve; 1 km²/mid-curve rejected). 164 cores, 3,512 stepping-stones retained, 591 sub-100 m² dust dropped (st_difference artifact; st_snap abandoned — hung O(n²), floor removes dust for free). Endpoints SC Mtns=1727 / southern Diablo=3972; two seed labels (3972=SC, 220=Diablo) surfaced WRONG and corrected (220=Marin/Mt Tam). tbl_17/18, fig_17 |
| 2026-08-20 | 5.5/6 | Decision 33 CLOSED — least-cost corridor construction. leastcostpath 2.0.13 terra create_cs; cond=1/R inversion (REQUIRED — package reads high=permeable); neighbours=16 (Antikainen 2013/Shirabe 2016, distortion-reduced); dem/max_slope NULL (slope already in R, Decision 26). LCP SC Mtns→S Diablo 37.2 km through Coyote Valley, 1.6 km from verified pinch, core swath covers pinch. Two-tier swath core q2%(409 km²)/context q5%(1,021 km²), set below the q25→q50 cost cliff; q10% rejected (would erase the narrow pinch). 1 km grain can't resolve sub-1 km pinch = swath is regional context, crossing step locates the pinch. lcp_* layers, tbl_19/20, fig_18/19 |
| 2026-08-20 | 6/9 | Decision 34 CLOSED — state-highway AADT by route-line + PM referencing, fixing the Decision-25 spatial-snap that dropped US-101 @ Coyote Valley to the 80k modelled floor (true ~142k, bracketing PM17.82/26.78 stations). Route chosen by nearest route-LINE (junction-safe: 101 line 190 m vs 85 line 4,977 m), new measured_route_pm tier. REFINES Decision 25 (spatial_fill-skew-not-correctable holds for local/arterial; state highways ARE PM-referenced, so correctable). Two failed impls surfaced+corrected before the working route-line match. Full re-run 04b→04c→07; resist_puma_baseline re-emitted (data-correction revision, Decision 26 weights unchanged). US-101 now top measured crossing 142k; Santa Teresa demoted to flagged estimate. ref-recovery deferred |
| 2026-08-20 | 5.5/7 | Sensitivity check 1 (road-confidence, Decision 26) PASSED/STABLE — v1(80k) vs v2(142k) corridor: LCP identical (Hausdorff 0 m), core swath IoU 1.000, context 0.990, cost Spearman 1.000; accumulated cost +4.4%. Rank-preserving because both AADT values map to the log-inverse high-resistance tail (transform compresses high-traffic tail by design) — path already avoided US-101 cells. Correction material for crossing SEVERITY ranking, immaterial for corridor GEOMETRY (two distinct findings). Verdict recorded qualitatively + raw metrics, no hard threshold. tbl_21, fig_20 |
| 2026-08-20 | 6/7 | Decision 35 CLOSED — three pre-registered Decision-26 corridor sensitivity checks (07e_sensitivity.R), OAT plausible-range perturbation judged on corridor overlap (Beier 2009/Rayfield 2010/Marrec 2020). ALL STABLE (worst context IoU 0.941, worst LCP mean sep 1,312 m). (1) road-confidence PASS (LCP identical, swath edges only) — corroborates sensitivity check 1. (2) chaparral shrub 10→5 PASS, IoU 1.000/0.998 — **FVEG supplement NOT triggered, Decision-12 chaparral contingency closed** (under-mapping immaterial to connectivity). (3) weights ±10% PASS, IoU ≥0.975, but asymmetric: gHM-heavy shortened LCP 37.19→35.55 km (mean sep 1,312 m) = largest single Week-8 sensitivity; LC-heavy 0 m. Caveat recorded: corridor LOCATION robust, exact route/length has ~1.5 km play tied to the gHM author-prior weight (§7 limitation, not a re-fit). Variant surfaces in-memory only. tbl_22, fig_21 |
| 2026-08-20 | 5.3/6 | Decision 36 CLOSED — puma Q5 corridor cross-read (07f_corridor_crossread.R). Three-part read (corridor ≠ density, so not a single ψ-vs-KDE correlation). Result CONVERGENCE (reverses the pre-analysis divergence guess, recorded honestly): LCP median 77th KDE percentile, 0% below median; Coyote Valley pinch 83rd (HIGH, not the predicted low); 7 Gi* hot units on the corridor, 6 TRUSTED. Corroboration but only WEAK-TO-MODERATE and PARTLY STRUCTURAL — NOT independent validation: resistance surface + KDE share a land-cover/gHM foundation (part of the agreement is two views of the same gradient; Larkin 2004/LaRue-Nielsen 2008 note corridor-through-occurrence is expected). Load-bearing counter-evidence: 6/7 TRUSTED hot units (effort-independent) + corridor's road term absent from KDE. Strong validation would need telemetry (we have occurrence only). Unnithan Kumar 2022: LCP centre-line is least-accurate form → lead the story with the SWATH not the line. CROSS-TRACK CONTRAST: bobcat ψ DIVERGED from KDE (r=0.075, model corrects effort); puma corridor CONVERGES (no effort term, yet lands on observed density). tbl_23, fig_22 |
| 2026-08-20 | 5.5/6 | Decision 37 CLOSED — puma core-connectivity network (07g_corridor_network.R). Large-core anchors (Gabriel graph on core centroids, spdep), create_lcp per edge (2.x-only; create_lcp_network is 1.x). 49 edges: 38 routed + 11 same-cell adjacencies (cost 0, strongest links — cores cluster, 22% adjacency). Finding 2: structural weak links are CROSS-BAY Peninsula↔East-Bay spans (1053-1899 cost 1063/61 km etc.), NOT Coyote Valley (cheap). Traffic pinch (US-101) ≠ structural weak point — different axes. Finding 3: central Bay splits the network into Peninsula/SC-Mtns + East-Bay/Diablo subnetworks, joined efficiently only at the south (matches known SC-Mtns puma isolation). CAVEAT: longest cross-bay links partly artifactual (Gabriel forces geometric-neighbour edges across an impassable barrier) = disconnection evidence, not protectable corridors. tbl_24, fig_23. **[Node count "29 ≥30 km²" and Finding-1 chain "1727→2618→3250→3972 cost 185.5" CORRECTED by Decision 38 — actual cutoff 20 km²/44 nodes; the chain was never traced (1727 not a node). See D38.]** |
| 2026-08-25 | 6 | Decision 38 CLOSED — documentation correction to D37 (no re-run). Node cutoff is 20 km²/44 nodes (code line 50, tbl_24a), not "29 ≥30 km²". The SC→Diablo chain (1727→2618→3250→3972, cost 185.5) was NEVER TRACED: 1727 is not a network node, the igraph trace guard was FALSE, no chain table written. Figures withdrawn. Weak-link ranking, two-subnetwork finding, and traffic-pinch≠structural-weak-link distinction all UNAFFECTED and stand; strong-vs-weak contrast retained via edge cost-distance ordering. Network map shows cost-coloured edges + cross-bay caveat, no labelled chain. D37 annotated (not rewritten); data-dictionary cutoff 30→20 km²; puma.qmd prose corrected. |
