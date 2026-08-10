# Data Sources

**Project:** Wild Cats at the Urban Edge
**Last updated:** July 27, 2026

> Skeleton. Each entry is completed at download time with: access date, exact
> version, file path, record count, CRS, licence and known issues — matching the
> tiger project format.

---

## 1. Open space and protected areas

### 1.1 CPAD / BPAD — California Protected Areas Database

Primary boundary layer. The authoritative inventory of parks and open space in
California, maintained by GreenInfo Network and published twice yearly. BPAD is
the Bay Area edition, which also incorporates conservation easements from CCED.

- **Chosen source:** statewide **CPAD 2026a** (not the BPAD Bay-Area edition — see note below). Ten-county clip deferred to Week 3.
- **Access (canonical):** https://www.calands.org/ — also listed on data.ca.gov and data.cnra.ca.gov
- **Direct download (2026a zip):** https://data.cnra.ca.gov/dataset/0ae3cd9f-0612-4572-8862-9e9a1c41e659/resource/cadf9163-aa38-44ae-851a-86b35d4c6c0c/download/cpad_2026a_release.zip
  - Note: the *data.cnra.ca.gov* dataset page still lists **2025b** as its resource; the 2026a zip above (linked from data.ca.gov) is current.
- **Version:** CPAD 2026a (statewide release, June 2026)
- **Account required:** No
- **Licence:** Creative Commons Attribution (CC-BY); data.ca.gov states "no restrictions on public use." Attribution required.
- **Downloaded:** July 27, 2026
- **File:** `data/raw/cpad/cpad_2026a_release.zip` (unzipped in place) — gitignored
- **Format / geometry levels:** Esri shapefiles — **Holdings**, **Units**, **SuperUnits** (all three present)
- **Native CRS:** California Albers (EPSG:3310) — confirm on load; matches the analysis CRS, so no reprojection needed
- **Feature counts:** Holdings 162,773 · Units 17,930 · SuperUnits 17,169 (statewide, 2026a; confirmed on load August 5, 2026)

**Geometry levels (which one is used is decided in Week 3):**
- **Holdings** — parcel-level ownership; most detailed attributes
- **Units** — the parks/preserves that Holdings roll up into
- **SuperUnits** — higher aggregation of Units

**CPAD vs BPAD (source decision):** BPAD is GreenInfo's Bay-Area edition covering
exactly the ten counties (nine bay counties + Santa Cruz, the CLN definition)
and it bundles CCED easements — but the latest BPAD is the **2025 edition**,
~1 year staler than CPAD 2026a. Statewide CPAD 2026a was chosen for freshness,
authoritative status and a scriptable download; easements come from CCED (§1.2)
and the ten-county clip is done transparently in Week 3 with the project's own
TIGER/Line boundary. BPAD remains a viable swap if bundled-easement, exact-frame
convenience outweighs freshness.

**Known issues to verify on download:**
- CPAD is an *ownership* inventory, not a habitat or biodiversity inventory —
  inclusion does not imply conservation management.
- Includes urban pocket parks; filtering by size and land cover is required.
- Three geometry levels (Holdings / Units / SuperUnits) — Units or SuperUnits
  are the appropriate analysis level; record which is chosen and why.

**Derived outputs (Week 3 — see `docs/methodology.md` Decisions 17–19,
fields in `docs/data-dictionary.md`):**
- `data/interim/openspace_cpad_bayarea_3310.gpkg` — gitignored — occupancy
  analysis frame. **Units** chosen as the site unit (Decision 17); non-habitat
  filtered (Decision 18); clipped to the ten-county boundary. 1,129 units.
- `data/interim/protected_union_bayarea_3310.gpkg` — gitignored — connectivity
  frame, CPAD fee ∪ CCED easement (Decision 19). Shared with §1.2.

### 1.2 CCED — California Conservation Easement Database
Parallel dataset covering easement-protected land, which CPAD excludes.
Relevant because much Bay Area connectivity land is easement-held ranchland.

- **Access (canonical):** https://www.calands.org/cced/ — also on data.ca.gov / data.cnra.ca.gov
- **Direct download (2026a zip):** https://data.cnra.ca.gov/dataset/31b65732-941d-4af0-9d8c-279fac441fd6/resource/2f0b8636-3901-458d-88e0-3a422e3235e8/download/cced_2026a_release.zip
- **Version:** CCED 2026a (June 2026) — matches CPAD 2026a. Note: the data.cnra.ca.gov / lab.data.ca.gov pages still list 2025b; the 2026a zip above (linked from data.ca.gov) is current.
- **Account required:** No
- **Licence:** Creative Commons Attribution (CC-BY); data.ca.gov states "no restrictions on public use." Attribution required.
- **Downloaded:** July 27, 2026
- **File:** `data/raw/cced/cced_2026a_release.zip` (unzipped in place) — gitignored
- **Format:** single Esri shapefile (easement polygons) + CCED Database Manual — one layer, no Holdings/Units/SuperUnits hierarchy
- **Native CRS:** California Albers (EPSG:3310) — confirm on load; matches analysis CRS
- **Feature count:** 23,645 easement polygons (statewide, 2026a)

**Known issues:**
- **"Incomplete" disclaimer is largely historical (quantified — Decision 9).**
  In 2026a, California Rangeland Trust is the 2nd-largest holder (1,865 easements)
  and CDFW the 4th (988) — both well-represented. CCED is used as-is, not
  supplemented: NCED can't fill it (CCED is its California feed) and remaining
  gaps are partly privacy-withheld. Treat easement absence as "not necessarily
  unprotected." Attribute caveat: ~27% of easements (6,363) have an "Unknown"
  holder — geometry present, still valid as easement extent; only matters for
  by-holder analysis.
- **Planning/assessment use only** — not a basis for regulatory or legal action;
  county recorder records are authoritative for individual easements.
- Easements sit mostly on private land; apply the same publication care as other
  layers and honour the GreenInfo data disclaimer.

**Derived output (Week 3):** contributes the `easement` half of
`data/interim/protected_union_bayarea_3310.gpkg` (gitignored) — CPAD fee ∪ CCED
easement, fee precedence on overlap (Decision 19). CCED adds 1,275.7 km² of
protected land not in CPAD fee. Full spec in `docs/data-dictionary.md`.

### 1.3 Study-area boundary — TIGER/Line counties (via `tigris`)
The ten-county clip frame for every other layer — it defines the study extent
(Decision 2), not a substantive dataset.

- **Source:** US Census Bureau TIGER/Line, pulled with
  `tigris::counties("CA", cb = TRUE)`
- **Vintage:** 2024 — pinned in `scripts/01_download_open_data.R` (`tigris_year`)
  for reproducibility; bump deliberately
- **Boundary type:** cartographic (`cb = TRUE`) — generalized, clipped to
  shoreline (land study area). `cb = FALSE` gives full legal boundaries including
  bay/ocean water.
- **Licence:** public domain (US Census)
- **CRS:** reprojected to EPSG:3310 on import
- **Output (gitignored):** `data/interim/boundary_baycounties_3310.gpkg`
  (10 county polygons: `county`, `geoid`) and
  `data/interim/boundary_baydissolved_3310.gpkg` (single study-area outline /
  clip mask)
- **Counties (10):** Alameda, Contra Costa, Marin, Napa, San Francisco,
  San Mateo, Santa Clara, Santa Cruz, Solano, Sonoma
- **Downloaded:** July 27, 2026

---

## 2. Occurrence records

### 2.1 GBIF
- **Access method:** `rgbif::occ_download()` — the citable path that returns a
  **DOI** (`occ_search()` gives none and caps at 100k records). Requires a free
  GBIF account; credentials in the **user** `.Renviron` (`GBIF_USER` /
  `GBIF_PWD` / `GBIF_EMAIL`), never committed.
- **Query:** taxonKeys for *Puma concolor* and *Lynx rufus* (resolved via
  `name_backbone()`), intersected with the study-area **bbox** (WGS84, from
  `boundary_baydissolved_3310.gpkg`), plus `hasCoordinate = TRUE` and
  `hasGeospatialIssue = FALSE`. No other server-side filtering — basisOfRecord,
  coordinate uncertainty and year are inspected/filtered in R afterward. Precise
  clip from bbox to the ten-county polygon happens at processing (Week 4).
- **Format:** `SIMPLE_CSV`.
- **Licence:** CC0 / CC BY (varies per record).
- **DOI:** https://doi.org/10.15468/dl.87ne3u — GBIF.org, accessed 2026-07-27
  (key `0013933-260721160103020`); also saved to
  `data/raw/gbif/gbif_download_doi.txt`
- **File:** `data/raw/gbif/<key>.zip` — gitignored
- **Downloaded:** July 27, 2026
- **Record counts (pre-filter, study-area bbox):** puma 1,843 · bobcat 5,164

**Known issues:**
- **Overlaps iNaturalist (§2.2).** GBIF aggregates iNaturalist research-grade
  records, so a GBIF + iNaturalist pull double-counts those observations — dedupe
  at processing (on `occurrenceID` / coordinates + date), don't sum the two.
- **Puma coordinates may already be obscured.** iNaturalist obscures
  sensitive-species coordinates and that offset propagates into GBIF for
  iNat-sourced puma records — treat GBIF puma coordinates as coarse
  (`docs/sensitive-data-policy.md`).
- Coordinate uncertainty spans orders of magnitude; heavy observer bias toward
  trailheads/roads (Q5 — a feature to explain, not an error).
- Mixed `basisOfRecord` (human observation, preserved specimens, machine/camera)
  — inspect the mix before deciding what to keep.

### 2.2 iNaturalist
- **Access method:** `rinat::get_inat_obs()` — `quality = "research"`, `geo = TRUE`,
  bounded to the study-area bbox, `maxresults = 10000`. Research grade implies
  media + community ID, so "has photo" is effectively satisfied; captive dropped
  via `captive_cultivated`. No account needed.
- **Obscuring fields preserved:** `coordinates_obscured` → **`obscured`** (the
  naming-conventions flag), plus `taxon_geoprivacy` (the puma-driving one),
  `geoprivacy`, and `public_positional_accuracy`.
- **Licence:** CC BY / CC BY-NC (varies per observer).
- **File:** `data/raw/inaturalist/inat_research_bayarea.rds` — gitignored
- **Downloaded:** July 27, 2026
- **Record counts:** puma 2,102 (50% obscured) · bobcat 6,295 (31% obscured).
  Both exceed the GBIF pull (fresher, less filtered).

**Role and known issues:**
- **Heavy overlap with GBIF (§2.1) — not additive.** GBIF is ~96–99%
  iNaturalist research-grade, so this pull mostly duplicates it. GBIF stays the
  primary occurrence source; iNat is the **obscuring-flag source and overlap
  cross-reference**, deduped (not summed) in Week 4 via iNat id ↔ GBIF
  `catalogNumber`/`occurrenceID`.
- **Sensitive-species obscuring (critical) — but observer-driven, not
  automatic.** iNaturalist does **not** taxon-obscure *Puma concolor* in
  California (0 taxon-obscured of 2,102; 1,057 open records exist). The ~50%
  obscuring is individual observers setting geoprivacy. The project therefore
  holds ~1,057 **precise** puma locations — treat as sensitive and never
  republish at native precision (`docs/sensitive-data-policy.md`). The obscured
  ones sit in a 0.2°×0.2° cell (~28 km — the GBIF uncertainty signature). The
  `obscured` flag must ride through every downstream layer.
- **10,000-record API cap** — a species at the cap means truncation; split by
  year or `place_id` if hit.

### 2.3 GBIF — target-group background effort (bobcat occupancy)
Not an occurrence source for the focal species — this is the **effort layer**
that supplies non-detection 0s for the bobcat occupancy detection history
(Fork 3, Decision 22 draft). A "surveyed" unit×year is one where *any* non-bobcat
vertebrate was recorded; a bobcat absent from a surveyed cell is a real
non-detection.

- **Access method:** `rgbif::occ_download()` (same credentialed path as §2.1).
- **Why GBIF, not `rinat`:** the effort pull spans *all* vertebrate observations
  across the study area for 2010–2026 — hundreds of thousands to millions of
  records. `rinat`'s 10,000-record cap makes this impossible: county×year tiling
  capped heavily, and county×month still capped in City Nature Challenge months
  (San Mateo April). GBIF's async download has no cap and filters server-side.
- **Scope:** ALL GBIF datasets (broad effort proxy — museum, eBird-via-GBIF,
  other surveys — not iNat-only), a deliberate widening from the original
  iNat-only Fork 3 framing. Shifts "iNat research-grade effort" to "any
  georeferenced vertebrate occurrence"; defensible and arguably stronger for a
  "was this unit visited by anyone recording wildlife" signal.
- **Query (server-side):** `taxonKey ∈ {Mammalia 359, Aves 212, Reptilia 358,
  Amphibia 131, Actinopterygii 204}`, `hasCoordinate = TRUE`,
  `hasGeospatialIssue = FALSE`, `year` 2010–2026, `pred_within(<WKT>)`, and
  `pred_not(speciesKey = 2435246)` to exclude *Lynx rufus*.
- **Footprint:** the **dissolved 10-county boundary** (`boundary_baydissolved_3310`)
  simplified to ~300 m tolerance (≈565 WKT vertices, EPSG:4326, CCW winding) —
  **not** the full bbox. The bbox first attempt returned 42.8M records / 4.8 GB
  (ocean + Central Valley); the boundary footprint cut this to 33.0M / 3.7 GB.
- **Format:** `SIMPLE_CSV` (note: has a `class` name column, **no** `classKey`).
- **Licence:** CC0 / CC BY (varies per record).
- **DOI:** https://doi.org/10.15468/dl.6xzcjt — GBIF.org, accessed 2026-08-09
  (key `0006760-260806074905277`); saved to
  `data/raw/gbif_background/background_download_key.txt`
- **File:** `data/raw/gbif_background/<key>.zip` — gitignored
- **Downloaded:** August 9, 2026
- **Record counts:** 33.0M pulled → 17.2M inside a CPAD unit. Class mix is
  bird-dominated (32.7M Aves, 0.11M Mammalia, 0.12M Amphibia).
- **Created by:** `scripts/03b_bobcat_background_effort.R`
- **Outputs:** `cov_effort_gbif_mammal_unityear_3310.gpkg` (Fork 3A; 5,401
  unit×year, 841 units), `cov_effort_gbif_vertebrate_unityear_3310.gpkg`
  (Fork 3B; 12,505 unit×year, 1,072 units). See `docs/data-dictionary.md`.

**Known issues:**
- **Bird effort ≠ bobcat detectability.** 99% of the pull is birds; a birder in
  a unit is near-zero evidence about bobcat presence. This deflates the
  vertebrate-background naive detection rate (0.083 vs 0.171 for mammal-only) —
  the mammal layer (3A) is the target-group-correct option. A-vs-B is held to the
  Week-7 fit (Decision 22 draft).
- **Boundary simplification is fuzzy at the edges** — a few near-county-line
  background records may fall just outside the WKT. Negligible for a
  presence-of-effort signal; the unit×year "surveyed" bit is set by interior
  activity, and the Part-B spatial join still clips precisely to unit polygons.
- **Absence of a unit×year row = not surveyed = NA, never a fabricated 0.**

---

## 3. Road mortality

### 3.1 CROS — California Roadkill Observation System
UC Davis Road Ecology Center. The largest system of its kind in the US, running
since 2009, with tens of thousands of observations. Explicitly identifies the
Bay Area as one of the state's highest-roadkill regions and I-280 among the
worst highways for wildlife-vehicle collisions.

- **Access:** https://wildlifecrossing.net/california/ — **no open bulk
  download.** Registered users can download only their *own* observations; the
  full dataset is request-gated (below).
- **Terms (confirmed July 27, 2026):** the public site publishes **no licence**
  and no explicit republication grant — the "Note on Data to our Users" page
  (`/california/data`) is a data-quality statement, not a licence. Bulk data must
  be **requested from the UC Davis Road Ecology Center** (Contact page), and
  republication terms for derived maps are set in that request, not published.
  **Do not assume raw CROS points may be republished** on the public story site
  without written confirmation (Decision 11).
- **Published, citable outputs (fallback):** Road Ecology Center annual
  "California Wildlife-Vehicle Collision Hotspots" reports and the CA Wildlife
  Crash Map (https://roadecology.ucdavis.edu/hotspots/map) — publishable/citable
  without a raw-data request.
- **Quality:** published spatial accuracy ~13 m; species ID accuracy >97%;
  majority of records from agency staff, academics, consultants and CHP.
- **Known issues:** volunteer/effort-based, so reporting effort is uneven and
  absence of records ≠ absence of mortality.

---

## 4. Covariates

### 4.1 Land cover — ESA WorldCover 2021 v200 (chosen; Decision 12, amended)
- **Source:** ESA WorldCover 10 m 2021 v200 — 11 classes (10 tree, 20 shrub,
  30 grass, 40 crop, 50 built-up, 60 bare, 70 snow, 80 water, 90 herbaceous
  wetland, 95 mangrove, 100 moss/lichen). Replaces NLCD — see Decision 12 for the
  full reason (NLCD access broke at every route).
- **Access:** public AWS COGs, `s3://esa-worldcover` (eu-central-1, no auth):
  `/vsicurl/https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_<TILE>_Map.tif`.
  Study area = tile **N36W123** (+ N36W126 for the Point Reyes sliver). Read +
  crop in-script; no manual step.
- **Licence:** CC-BY 4.0. Published-map attribution: "© ESA WorldCover project
  2021 / Contains modified Copernicus Sentinel data (2021) processed by ESA
  WorldCover consortium." Citation: Zanaga et al. (2022), DOI 10.5281/zenodo.7254221.
- **CRS:** native EPSG:4326 → reprojected to EPSG:3310 with **nearest-neighbour**.
- **File:** `data/interim/cov_landcover_worldcover2021_3310.tif` — gitignored
- **Downloaded:** Aug 2, 2026. Class distribution and the chaparral caveat are in
  `docs/methodology.md` §4.5.
- **Notes:** single "Built-up" class (no developed-intensity gradient — the urban
  gradient comes from GHM + housing density, §4.4). Only 2020/2021 exist (no
  annual updates); 2021 v200 used. **Under-maps California chaparral** (shrub
  folded into tree/grassland) — FVEG is the targeted supplement if needed.

### 4.2 Terrain — AWS Terrain Tiles (via elevatr)
Elevation, and derived slope and aspect, used as terrain covariates. Serves as
the terrain input for both species' covariate stacks (aggregated to the puma
1 km and bobcat 500 m grids in Week 5).

**Full Citation:**
> Mapzen, Amazon Web Services, and contributing agencies (USGS 3DEP, NASA SRTM,
> and others). *AWS Terrain Tiles* [Dataset]. Registry of Open Data on AWS.
> Accessed via the `elevatr` R package (Hollister, J. et al.).
> https://registry.opendata.aws/terrain-tiles/

- **Access URL:** https://registry.opendata.aws/terrain-tiles/
- **Access Method:** `elevatr::get_elev_raster(locations = aoi, z = 12, src = "aws", clip = "bbox")`; scripted in `scripts/01_download_open_data.R`; no account required
- **Accessed:** August 3, 2026
- **Zoom level:** z = 12 (pinned for reproducibility)
- **Source resolution:** ~30 m effective at 37.7°N (Web-Mercator Terrarium tiles; `156543 × cos(φ) / 2^z`)
- **Delivered grid:** 15.1 m cells after reprojection to EPSG:3310 (bilinear resample — grid is finer than the source; does **not** represent 15 m of real terrain detail)
- **Coordinate System:** EPSG:3310 (NAD83 / California Albers); source tiles in Web Mercator (EPSG:3857)
- **Files:**
  - `data/interim/cov_dem_terraintiles_z12_3310.tif` — elevation (m)
  - `data/interim/cov_slope_deg_terraintiles_z12_3310.tif` — slope (degrees)
  - `data/interim/cov_aspect_deg_terraintiles_z12_3310.tif` — aspect (degrees)
- **Extent:** ten-county study area + 5 km collar (edge-correct slope/aspect)
- **Elevation range (buffered AOI):** −123 m to 1,439 m
- **License:** Terrain Tiles is public / open; individual source contributions carry their own terms (USGS 3DEP public domain; SRTM public domain; others vary). Attribution to the Terrain Tiles project and contributing agencies required.
- **Role in project:** Terrain covariates (elevation, slope, aspect) for distribution/occupancy and connectivity analysis.

**Known Issues / Limitations:**
- **Not native 3DEP:** AWS Terrain Tiles are a Terrarium mosaic blending 3DEP,
  SRTM, GMTED and others — not a single-source "3DEP 10 m" product. Effective
  resolution is ~30 m (z=12), not 10 m. The 15.1 m delivered grid is a
  reprojection artefact, not real detail.
- **Water/void artefacts:** Sub-sea-level cells (down to −123 m) occur along the
  Pacific coastline, SF Bay margins, and the Farallones — Terrarium water/void
  encoding, not real bathymetry. Confined to non-terrestrial areas; removed by
  the Week-5 clip to open-space units. Optionally floored to `NA` below −20 m.
- **Blended vertical sources:** Mixed source DEMs mean vertical accuracy is not
  uniform across the study area; adequate for landscape-scale covariates, not
  for fine terrain analysis.
- **1 m lidar not included:** USGS 3DEP QL2 / CA statewide lidar covers much of
  the Bay Area at 1 m but is very large and unnecessary at this analysis scale.
  Flagged as an optional supplement for a future phase; not acquired in Phase 1.
- **Reprojection:** Reprojected with bilinear resampling (continuous data);
  slope/aspect derived post-projection in degrees so gradients are in projected
  metres.

### 4.3 Roads and traffic

Two sources: the road **network and class** from OpenStreetMap (Geofabrik
extract), and **traffic volume** from Caltrans. Traffic volume matters far more
than road presence for barrier effects — a tertiary road and a freeway are both
"roads" but differ by orders of magnitude in traffic. See Decision 14.

#### 4.3.1 Road network — OpenStreetMap via Geofabrik (NorCal extract)

**Full Citation:**
> OpenStreetMap contributors. *OpenStreetMap Data Extract — Northern California
> (NorCal)* [Dataset]. Geofabrik GmbH. Downloaded via
> https://download.geofabrik.de/north-america/us/california/ under the Open
> Database License (ODbL).

- **Source:** Geofabrik **NorCal** sub-region shapefile extract (`-latest-free`).
  The ten-county study area is fully contained in NorCal.
- **Access URL:** https://download.geofabrik.de/north-america/us/california/norcal-latest-free.shp.zip
- **Access Method:** `download.file()` (libcurl) in `scripts/01_download_open_data.R`;
  no account required. `PK`-magic + size guard rejects a non-zip response.
- **Accessed:** August 3, 2026 (download date + server `Last-Modified` recorded in
  `data/raw/osm/geofabrik_download_stamp.txt`)
- **Layer used:** `gis_osm_roads_free_1.shp` (road class field: **`fclass`**)
- **Record count:** 936,784 features after clip to study area
- **Coordinate System:** EPSG:3310 (reprojected from EPSG:4326 source)
- **Files:**
  - `data/interim/cov_roads_osm_3310.gpkg` — all road classes
  - `data/interim/cov_roads_osm_major_3310.gpkg` — motorway→secondary barrier subset
- **Licence:** Open Database License (ODbL) — attribution + share-alike required.
- **Role in project:** road-density covariate (all classes) and barrier network
  (major subset) for distribution/occupancy and connectivity analysis.

**Known Issues / Limitations:**
- **No statewide CA shapefile / no DOI:** Geofabrik does not publish a current
  statewide California shapefile extract (only stale 2014–2018 snapshots); NorCal
  sub-region used instead. "latest" is a moving target — pinned only by download
  date + server timestamp, not a DOI. Re-running later gets a different network.
- **`fclass` is Geofabrik's field, not raw OSM:** raw OSM/Overpass uses `highway`;
  `fclass` exists only in Geofabrik's processed extracts (reason for this source).
- **Volunteer data:** completeness varies; minor/private roads may be missing or
  misclassified.
- **Tracks/paths ambiguity:** `track` and `path` are unpaved/low-traffic and may be
  permeable rather than barriers — resolved per species in Week 5 (Decision 14).

#### 4.3.2 Traffic volume — Caltrans Traffic AADT

**Full Citation:**
> California Department of Transportation (Caltrans). *Traffic Volumes — Annual
> Average Daily Traffic (AADT), 2023* [Dataset]. Caltrans GIS Data.
> https://gisdata-caltrans.opendata.arcgis.com/

- **Source:** Caltrans `CHhighway/Traffic_AADT` MapServer, layer 0 (2023 vintage).
  Note: the service path is `Traffic_AADT` on a **MapServer** — "Traffic_Volumes_AADT"
  is the layer display name, not the endpoint, and it is not a FeatureServer.
- **Access URL (service):** https://caltrans-gis.dot.ca.gov/arcgis/rest/services/CHhighway/Traffic_AADT/MapServer/0
- **Access Method:** ArcGIS REST query → GeoJSON (`?where=1=1&outFields=*&outSR=4326&f=geojson`);
  no account required
- **Accessed:** August 3, 2026
- **Record count:** 2,423 count stations after clip to study area (not truncated;
  transfer-cap guard did not fire)
- **Geometry:** point (count-station locations on the state highway network)
- **Coordinate System:** EPSG:3310 (reprojected from EPSG:4326)
- **File:** `data/interim/cov_aadt_caltrans_points_3310.gpkg`
- **Key fields:** `AHEAD_AADT`, `BACK_AADT` (per-direction leg volumes),
  plus route/postmile identifiers
- **Licence:** Caltrans public data, © State of California — informational use;
  attribution expected.
- **Role in project:** traffic-weighting for the barrier / road-mortality context;
  the variable that distinguishes a freeway from a quiet road.

**Known Issues / Limitations:**
- **State highways only:** covers the Caltrans state-highway network — no county
  roads, city streets, or local arterials. Roads off the state network have no
  measured volume; Week 5 assigns an `fclass`-derived floor or model.
- **Volumes stored as strings:** `AHEAD_AADT` / `BACK_AADT` are text (commas,
  blanks; ~8% of `AHEAD_AADT` empty). Coerce to numeric and clean before use.
- **Point, not line:** AADT is per count station, not attributed to road segments;
  the AADT→segment join is a Week-5 covariate step (Decision 14).
- **Sanity range (study area):** median AHEAD_AADT ~68,000, max ~292,000 —
  freeway-scale, consistent with a state-highway-only dataset.

### 4.4 Human footprint — human modification + housing density

Two continuous layers that together carry the urban-**intensity** gradient
(WorldCover has only a flat "Built-up" class; Decision 12). Load-bearing for the
coexistence narrative, not context. Both choices deviate from the original
Week-2 plan; see methodology Decisions 15–16.

> Doc note: methodology §4.9 is the matching processing log. (Decision 12 and
> methodology §4.5/§4.7 point to "§4.4" for these layers — that pointer is to
> *this file's* §4.4; in methodology.md the footprint log is §4.9, since §4.4
> there is CROS.)

#### 4.4.1 Human modification — Global Human Modification v3, 2022

**Full citation:**
> Theobald, D.M., Oakleaf, J.R., Moncrieff, G., Voigt, M., Kiesecker, J., &
> Kennedy, C.M. (2024). *Global human modification datasets of terrestrial
> ecosystems for 2022* (v1.0.0) [Data set]. Zenodo.
> https://doi.org/10.5281/zenodo.14502573

- **Source:** "all threats combined" (AA) 300 m cloud-optimised GeoTIFF,
  `HMv20240801_2022s_AA_300.tif`, read windowed via `/vsicurl` off the Zenodo
  file URL (the file is 9.3 GB global — never downloaded whole).
- **Layer meaning:** continuous 0–1 human-modification metric (0 = unmodified,
  1 = fully modified), 5 stressor groups / 13 datasets, median year 2022.
- **DOI:** 10.5281/zenodo.14502573 (pinned).
- **Native CRS:** EPSG:4326 → reprojected to EPSG:3310 with **bilinear**
  (continuous).
- **Output:** `data/interim/cov_ghm_v3_2022_3310.tif`.
- **Licence:** CC-BY 4.0 — attribution required.
- **Why not Kennedy et al. 2019 (as the plan named):** the 2019 1 km layer ships
  as a figshare zip / GEE export with no clean `/vsicurl` route; the GEE asset
  needs an Earth Engine account + `rgee` (auth dependency avoided). v3 is a
  DOI-pinned COG, acquirable by the WorldCover pattern, and more current. The
  300 m → puma 1 km / bobcat 500 m aggregation makes the resolution difference
  immaterial. Full rationale: Decision 15.

**Known issues / limitations:**
- Single global product, 2022, not Bay-Area-tuned; 300 m native.
- Will correlate with housing density at the urban edge — check collinearity
  before stacking both into a resistance surface (Week 5).

#### 4.4.2 Housing density — SILVIS block-level (PLA v4)

**Full citation:**
> Helmers, D.P., Mockrin, M.H., Radeloff, V.C., et al. (2023). *Census Block
> Level Housing Change 1990–2020 for the Conterminous United States* (Version 4,
> Public-Land-Adjusted). SILVIS Lab, Dept. of Forest & Wildlife Ecology,
> University of Wisconsin–Madison / USDA Forest Service Northern Research Station.
> https://silvis.forest.wisc.edu/data/housing-block-change-2020/

- **Source:** California state shapefile extract
  (`CA_block20_change_1990_2020_PLA4_shp.zip`), direct download (no portal step).
- **Fields kept:** housing density `HUDEN1990`–`HUDEN2020` (units/km², the
  covariate), counts `HU2020` / `POP2020` / `POPDEN2020`, `PUBFLAG`, `WATER20`,
  `BLK20`.
- **Native CRS:** NAD83 / CONUS Albers (**EPSG:5070**) → reprojected to EPSG:3310.
- **Geometry:** polygon blocks; clipped to the study area (vector — no resampling).
- **Output:** `data/interim/cov_housing_silvis_blocks_3310.gpkg`.
- **Licence:** USDA FS / SILVIS — no restrictive licence; acknowledgement
  requested.
- **Why SILVIS over a Census/`tidycensus` build:** single direct download and
  housing **density** pre-computed per block (no API key, no per-decade join).
  Decision 16.

**Known issues / limitations:**
- **Public-Land-Adjusted (PLA):** houses are moved *out* of protected areas into
  neighbouring private blocks — so housing density inside CPAD units is near-zero
  by construction. Density *at* an open-space site measures the surrounding
  matrix, not housing in the unit. (Standing QC: `HUDEN2020` median by `PUBFLAG`.)
- **Small-area density artifact:** tiny blocks with a nonzero housing count yield
  implausibly high densities (study-area max ~2.26M units/km² vs p90 ~3k). Known
  block-density artifact, not a data error; ~99% of blocks fall in 0–10⁴. Handled
  in Week 5 by `log1p` + a p99/hard cap before rasterization (pre-registered in
  methodology §4.9), not at download.
- **No WUI flags** in this product — intermix/interface classification is a
  separate SILVIS "WUI 1990–2020" dataset (`WUIFLAG*`), not acquired.
- Rasterising `HUDEN2020` onto the puma/bobcat grids (with the log + cap above) is
  a Week-5 covariate-construction step.

---

## 5. Population context (no time series available)

There is **no** repeated regional census equivalent to the NTCA rounds.
Available context:
- California Mountain Lion Project statewide abundance estimate (CDFW with
  UC Santa Cruz, UC Davis, Audubon Canyon Ranch, Institute for Wildlife
  Studies) — a single point-in-time estimate, roughly 3,200–4,500 statewide.
- CDFW status review and **CESA listing** — in **April 2026** the Fish and Game
  Commission listed mountain lions in the Southern California / Central Coast
  Distinct Population Segment (SC/CC DPS) as **threatened** under CESA. The
  relevant subpopulation here is **Central Coast North = the Santa Cruz Mountains
  population**, which anchors the puma connectivity/isolation narrative and spans
  the San Francisco, San Mateo and peninsula range. (This supersedes the earlier
  "candidate under review" framing; see `docs/references.md` for the petition
  (2019), candidacy (2020) and listing (2026) chain. Verify against the primary
  Commission notice before any public-facing narrative claim — the doc's current
  sourcing is secondary legal alerts.)
- No statewide bobcat abundance estimate exists.

Cite these as context only. Do not present them as a trend.

---

## 6. Partner data (restricted)

### 6.1 Felidae Conservation Fund
Long-running Bay Area camera network across the East Bay, North Bay and
Peninsula, plus a public sightings map and published occupancy analyses.

- **Status:** **deferred to a future phase** (see `docs/methodology.md`
  Decision 7). Not used in Phase 1; no Felidae data is held in this repository.
- **Terms:** requires a written agreement before any use — see
  `docs/sensitive-data-policy.md` §4. Precise station / camera coordinates are
  T3 (restricted): never committed, never published at native precision.
- **Preferred products (if resumed):** derived occupancy surfaces, unit-level
  detection summaries, or published results — **not** raw camera coordinates.
- **Storage (if resumed):** `data/restricted/` only; never committed.

**Noted during initial review, for a future phase:** a Wildpod station
inventory (218 stations; `ID`, `Park`, `Station`, `Area`, coordinates,
elevation) was examined and set aside when Phase 1 moved to a full ten-county
open-data frame. Characteristics for whoever resumes it: `ID` unique, `Station`
not unique; `Park` labels untrusted (include private ranches); sub-regions
Peninsula / East Bay / South Bay plus an out-of-region Los Angeles group to
drop; Latin-1 encoding; 22 null elevations. Open-space identity would be
resolved spatially (staged point-in-polygon / nearest-unit, no blanket buffer),
not from the `Park` label.

---

## 7. Licence summary

| Dataset | Licence | Attribution | Redistribution |
|---|---|---|---|
| CPAD / CCED | Open | Yes | Allowed |
| GBIF | CC0 / CC BY (varies) | Yes | Check per record |
| iNaturalist | CC BY / CC BY-NC (varies) | Yes | Check per record |
| CROS | Confirm terms | Yes | Confirm |
| AWS Terrain / TIGER | Public domain | No | Allowed |
| ESA WorldCover | CC BY 4.0 | Yes | Allowed |
| gHM v3 (Theobald 2024) | CC BY 4.0 | Yes | Allowed |
| SILVIS housing | USDA FS / SILVIS (ack. requested) | Yes | Allowed |
| OpenStreetMap | ODbL | Yes | Share-alike |
| Caltrans AADT | CA public data | Yes | Informational |
| Felidae | Agreement | Yes | **No** |
