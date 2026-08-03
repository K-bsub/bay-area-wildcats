# Project Plan

**Project:** Wild Cats at the Urban Edge
**Author:** Kiran Balasubramanian
**Start date:** July 23, 2026
**Target:** 10 weeks
**Last updated:** August 3, 2026

---

## Scope

**Phase 1 (this repository)**
- Characterise open space across the ten-county Bay Area
- Map puma and bobcat distribution from open occurrence data
- Model bobcat occupancy; model puma connectivity
- Analyse road mortality as the primary threat layer
- Publish a reproducible story site

**Deliberately out of scope for Phase 1**
- Population size or trend estimation (no data supports it)
- Genetic / inbreeding analysis
- Prey base modelling

**Future phases**
- Phase 2: circuit-theory connectivity, crossing-structure prioritisation
- Phase 3: partner data integration, formal multi-species occupancy
- Phase 4: individual open-space case studies

---

## Timeline

| Week | Milestone | Key deliverables | Status |
|---|---|---|---|
| **1** | Repository and environment setup | Repo scaffold, docs, renv, R toolchain verified | ✅ Complete |
| **2** | Data acquisition | All open datasets downloaded and documented | ✅ Complete (CROS parked) |
| **3** | Boundary and study-area preparation | Open-space units defined and filtered; analysis grid built | ⚪ Not started |
| **4** | Occurrence processing | Cleaned, deduplicated, CRS-aligned occurrence layers for both species | ⚪ Not started |
| **5** | Covariate preparation | Land cover, terrain, roads, housing summarised to grid and unit | ⚪ Not started |
| **6** | Descriptive spatial analysis | KDE and Gi* for both species; unit-level statistics | ⚪ Not started |
| **7** | Occupancy modelling | Bobcat occupancy fitted and validated; puma feasibility assessed | ⚪ Not started |
| **8** | Connectivity analysis | Resistance surface, least-cost paths, core-patch linkages | ⚪ Not started |
| **9** | Story site build | Quarto site, maps, charts, narrative | ⚪ Not started |
| **10** | Review and publication | QA, accessibility check, GitHub Pages deployment, docs finalised | ⚪ Not started |

**Status legend:** 🟢 In progress · 🟡 At risk · 🔴 Blocked · ✅ Complete · ⚪ Not started

---

## Week 1 tasks

- [x] Create GitHub repository
- [x] Establish directory structure
- [x] Write `docs/sensitive-data-policy.md`
- [x] Write `docs/naming-conventions.md`
- [x] Establish CRS decision (EPSG:3310)
- [x] Install R spatial toolchain and verify GDAL/GEOS/PROJ
- [x] `renv::init()` and commit `renv.lock`
- [x] Confirm study area definition — ten-county (Decision 2)
- [x] Draft `docs/proposal.md` research questions
- [x] Verify GitHub Pages deployment path (gh-pages branch, not /docs)

---

## Week 2 tasks — data acquisition (open data only; Felidae deferred, Decision 7)

*Boundaries*
- [x] Download CPAD/BPAD (v2026a or latest) → `data/raw/cpad/`; record edition and available geometry levels (Holdings / Units / SuperUnits). Level choice and non-habitat filtering deferred to Week 3.
- [x] Download CCED easements → `data/raw/cced/`
- [x] Pull the ten-county boundary via `tigris` (TIGER/Line) for clipping

*Occurrence records*
- [x] `rgbif`: download *Puma concolor* + *Lynx rufus*, California, study-area bbox; record the download DOI
- [x] `rinat`: download research-grade records; preserve the `obscured` flag (puma)
- [x] Log per-species raw counts and coordinate-uncertainty spread

*Road mortality*
- [ ] **Confirm CROS data-use / republication terms first** (Risk 3), then download puma + bobcat records → `data/raw/cros/` — *terms confirmed (request-gated, Decision 11); data request sent Aug 2 to F. Shilling, awaiting reply. Download blocked until terms granted.*

*Covariates*
- [x] Choose land-cover source → **ESA WorldCover 2021 v200** (pivoted from NLCD after its access broke; Decision 12 amended); `cov_landcover_worldcover2021_3310.tif`
- [x] Terrain via `elevatr` — AWS Terrain Tiles z=12 (~30 m effective, NOT native 3DEP 10 m; Decision 13); DEM + slope + aspect. 1 m lidar noted, deferred
- [x] Roads via Geofabrik **NorCal** extract (`fclass`; not osmdata/Overpass, not stale CA-statewide) + Caltrans **AADT** traffic (Decision 14)
- [x] Housing / human footprint: **SILVIS block-level housing density** (PLA v4, CA extract; density baked in — Decision 16, not a Census/tigris build) + **Global Human Modification v3, 2022** (Theobald 2024 COG via /vsicurl — Decision 15, not Kennedy 2019). Per Decision 12 these carry the urban-intensity gradient. `cov_ghm_v3_2022_3310.tif`, `cov_housing_silvis_blocks_3310.gpkg`

*Population context (context only — no time series)*
- [x] Gather CA Mountain Lion Project abundance estimate + CDFW CESA status review as reference material (not a trend) — in `docs/references.md` §population-and-status. **Flag:** the SC/CC population was **listed threatened (April 2026)**, no longer merely a candidate/status-review — the inherited "status review supporting listing" wording is now stale; verify against the primary FGC notice before public use, and reconcile `data-sources.md` §5

*Documentation & reproducibility*
- [x] Write `scripts/01_download_open_data.R` (scripted downloads where possible: `rgbif`, `rinat`, `elevatr`, `tigris`, `osmdata`) — all blocks written: CPAD/CCED/boundary/GBIF/iNat/WorldCover/terrain/roads+AADT/gHM/SILVIS
- [x] Create / complete `data/README.md` acquisition steps — per-layer source/how/output for all open layers, plus CROS + Felidae as gated/parked
- [x] Fill every `docs/data-sources.md` entry (access date, version, path, record count, CRS, licence, known issues); confirm `data/raw/**` is gitignored — all acquired layers documented incl. §4.4 human footprint
- [x] Add cited reports / literature to `docs/references.md` — population/status, methods, road ecology, felid research stubs; Kennedy→Theobald gHM citation swap recorded as a provenance note (Decision 15)

---

## Risks

| # | Risk | Level | Mitigation |
|---|---|---|---|
| 1 | **Occupancy modelling not feasible from opportunistic data** — `unmarked` needs detection histories from repeated visits; GBIF/iNat records are not survey data | 🔴 High | Assess in Week 4 before committing. Fallbacks: (a) spatial-replication design with documented assumptions; (b) request Felidae detection histories (Phase-3 partner data, not used in Phase 1); (c) drop to species distribution modelling (MaxEnt / `maxnet`) and reframe the narrative |
| 2 | **Puma records too sparse for any surface** — obscured and few | 🟢 Low (revised) | Substantially resolved: *Puma concolor* is not taxon-obscured (Decision 10); ~1,057 precise puma points held (median 26 m accuracy). A coarse distribution layer is now plausible — pending Week-4 dedupe (heavy GBIF overlap) + clip to confirm the *unique* count. Connectivity + CROS remain the puma backbone regardless |
| 3 | **CROS data-use terms restrict republication** | 🟡 Medium | Terms confirmed request-gated (no open API; Decision 11); data request sent Aug 2 to F. Shilling, awaiting reply. Parked, not blocking — it's a threat overlay, not a Phase-1 backbone. Fallback: aggregate to road segment and cite |
| 4 | **R spatial toolchain / learning curve** — new stack after ArcGIS | 🟡 Medium | Week 1 buffer for setup; keep scripts small and numbered; `targets` deferred until pipeline is stable |
| 5 | **CPAD includes non-habitat parcels** | 🟢 Low | Define and document filtering criteria (minimum area, land cover, access class) as a numbered decision |
| 6 | **Sensitive data disclosure** | 🔴 High | `docs/sensitive-data-policy.md` enforced from Week 1; `data/restricted/**` gitignored. Felidae (restricted tier) deferred — none held. **But the project now holds ~1,057 precise puma coordinates** from open-geoprivacy iNat records (Decision 10): the ≥1 km publish floor + `assert_publishable()` are load-bearing, not precautionary. Never publish precise puma surfaces |

---

## Progress log

### Week 1 — July 23, 2026
- **Progress:** 🟢 In progress
- **Completed:** repository scaffold, documentation skeleton, sensitive data
  policy, naming conventions, CRS decision
- **Blockers:** none
- **Next:** R environment setup and data acquisition
- **Notes:** Scope reframed away from the tiger project's population-recovery
  arc. No regional census time series exists for either species, so the
  narrative is distribution, connectivity and coexistence. Risk 1 (occupancy
  feasibility) is the item to resolve earliest — it determines whether Week 7
  is occupancy modelling or species distribution modelling.

### Felidae Wildpod stations — July 25, 2026
- **Received:** 218-station Wildpod CSV (`ID`, `Park`, `Station`, `Area`,
  coords, elevation). Held as **T3 restricted** in `data/restricted/`.
- **Scoping:** `Los Angeles` sub-region (13 stations) is out of study area —
  excluded (Decision 4). ~205 candidates before the ten-county clip.
- **Association:** `Park` labels untrusted and many stations are on
  private/suburban land → staged point-in-polygon / nearest-unit method, **not**
  a 10–20 mi buffer (Decision 5). Open item: nearest-unit tolerance.
- **Provenance:** written-agreement status unconfirmed — Decision 6. Blocks any
  published Felidae-derived output until resolved.
- **Reminder:** these are station *locations*, not detection histories; Risk 1
  is not yet resolved by this data.
- **Superseded 2026-07-26:** Felidae deferred to a future phase; the study
  scope is now the full ten-county open-space frame and no Felidae CSV is
  committed (Decision 7).

### Week 1 environment — July 26, 2026
- **Progress:** environment setup complete.
- **Completed:** R spatial toolchain installed and verified — R 4.5.2, sf 1.1.1,
  terra 1.9.27, GDAL 3.12.1, GEOS 3.14.1, PROJ 9.7.1, s2 enabled. Both vector
  and raster reprojection to EPSG:3310 pass. `renv::init()` run and `renv.lock`
  committed. Study area confirmed ten-county (Decision 2).
- **Fixed:** a PostgreSQL/PostGIS `proj.db` was hijacking terra via
  `PROJ_LIB`/`PROJ_DATA` (`[rast] empty srs`); `.Rprofile` now clears those
  vars before spatial packages load. Kept above renv's activate line.
- **Scope change:** Felidae dataset dropped from Phase 1 in favour of the full
  ten-county open-data study (Decision 7).
- **Blockers:** none.
- **Next:** finish remaining Week 1 items (proposal research questions, verify
  gh-pages path), then Week 2 data acquisition (CPAD/CCED, GBIF, iNaturalist,
  CROS, covariates).

### Week 1 closeout — July 27, 2026
- **Progress:** ✅ Week 1 complete.
- **Completed:** proposal research questions finalised (five questions,
  species-tagged; the bobcat question made method-agnostic to survive the
  occupancy-vs-SDM fork). GitHub Pages publishing path configured — added
  `.github/workflows/publish.yml` (the scaffold had none), fixed
  `site/_quarto.yml` output-dir (`../_site` → `_site` to match `.gitignore`),
  and added the `methods.qmd`, `data.qmd` and `styles.css` that the navbar/config
  referenced but the scaffold never created. Local `quarto render site` passes.
- **Carry-forward (first push):** confirm the Actions run is green, set Pages
  Source to `gh-pages` / root (not main /`docs`), and load
  https://k-bsub.github.io/bay-area-wildcats/. Commit `site/_freeze/` so CI
  renders without R.
- **Blockers:** none.
- **Next:** Week 2 data acquisition.

### Week 2 — data acquisition — July 27, 2026
- **Progress:** 🟢 In progress. Boundaries and occurrence downloads complete;
  CROS + covariates + population context + acquisition docs remain.
- **Boundaries:** CPAD 2026a (statewide; Holdings/Units/SuperUnits; EPSG:3310;
  Decision 8 — CPAD over BPAD); CCED 2026a (23,645 easements; Decision 9 — gap
  quantified, Rangeland Trust 2nd-largest holder, used as-is); ten-county
  TIGER/Line boundary via `tigris` (19,623 km², `cb = TRUE` land).
- **Occurrences:** GBIF via `occ_download` (DOI 10.15468/dl.87ne3u; puma 1,843 /
  bobcat 5,164); iNaturalist via `rinat` research-grade (puma 2,102 / bobcat
  6,295). Per-species counts + uncertainty/accuracy spreads logged (§4.2, §4.3).
- **Key finding (Decision 10):** *Puma concolor* is **not** taxon-obscured in CA —
  the ~50% obscuring is observer-set. The project holds ~1,057 *precise* puma
  points (median 26 m accuracy). This (a) upgrades puma from connectivity-only
  toward a plausible coarse distribution layer (Risk 2 → Low, pending Week-4
  dedupe/clip), and (b) makes the sensitive-data-policy coarsening rules
  load-bearing (policy §1 rationale corrected; Risk 6 updated).
- **Reproducibility:** `01_download_open_data.R` holds the CPAD / CCED / boundary /
  GBIF / iNat blocks (covariate blocks to follow); `renv.lock` updated with
  `tigris` / `rgbif` / `rinat`.
- **Blockers:** none.
- **Next:** CROS road mortality — confirm UC Davis data-use / republication terms
  **before** pulling or building on it (Risk 3).

### Week 2 status / handoff — August 2, 2026
Data acquisition ~70% done. State for picking up in a fresh chat:

**Done + documented** (methodology §4, data-sources):
- Boundaries — CPAD 2026a (Decision 8), CCED 2026a (Decision 9), ten-county
  TIGER/Line boundary (`boundary_baydissolved_3310.gpkg`, 19,623 km²).
- Occurrences — GBIF (DOI 10.15468/dl.87ne3u; puma 1,843 / bobcat 5,164) +
  iNaturalist (rinat; puma 2,102 / bobcat 6,295). **Key finding (Decision 10):**
  *Puma concolor* is NOT taxon-obscured in CA; ~1,057 precise puma points held →
  sensitive-data-policy §1 corrected, coarsening rules load-bearing; Risk 2 → Low.
- Land cover — **ESA WorldCover 2021 v200** (`cov_landcover_worldcover2021_3310.tif`).
  Pivoted from NLCD after its access broke at every route (Decision 12 amended).
  **Caveat:** WorldCover under-maps CA chaparral (shrub folded into tree/grass) —
  CAL FIRE FVEG is the flagged supplement if bobcat covariates need it (§4.5).

**In flight:**
- CROS road mortality — terms confirmed (request-gated, no open API; Decision 11);
  data request sent Aug 2 to F. Shilling (Road Ecology Center); awaiting reply.
  Nothing is built on CROS until republication terms are granted in writing.

**Remaining Week 2:**
- Covariates — terrain (`elevatr`, next), roads/traffic (`osmdata` + Caltrans
  AADT), housing/human footprint (Census + Global Human Modification; GHM +
  housing now also carry the urban-intensity gradient, per Decision 12).
- Population context — CA Mountain Lion Project + CDFW CESA (references only).
- Acquisition docs — `data/README.md`, remaining `data-sources.md` covariate
  stubs, `references.md`.

**Working files (current):** `scripts/01_download_open_data.R` (CPAD / CCED /
boundary / GBIF / iNat / WorldCover blocks — terrain/roads/housing to follow);
`docs/methodology.md`, `docs/data-sources.md`, `docs/sensitive-data-policy.md`.

**Env note for a fresh session:** new packages need `renv::install()` + snapshot
on first use (hit with tigris/rgbif/rinat). Land-cover access lesson: FedData/NLCD
is broken — use the WorldCover AWS COGs already in the script.

- **Blockers:** none (CROS is parked, not blocking — it's a threat overlay).
- **Next:** terrain via `elevatr::get_elev_raster()` for the study AOI.

### Week 2 — covariates: terrain + roads/traffic — August 3, 2026
- **Progress:** 🟢 In progress. Data acquisition ~85% done. Terrain and
  roads/traffic complete; housing/footprint + population context + acquisition
  docs remain.
- **Terrain (Decision 13):** `elevatr::get_elev_raster(src="aws", z=12)` — AWS
  Terrain Tiles, **not** native 3DEP 10 m. ~30 m effective (15.1 m reprojected
  grid); the "3DEP 10 m" plan wording was corrected. DEM + slope + aspect in
  EPSG:3310 (bilinear DEM; slope/aspect post-projection in degrees). Elevation
  −123–1,439 m; sub-sea-level minima confirmed as coastal/bay/Farallones water
  artefacts (plotted), not bad tiles — no re-fetch. Outputs:
  `cov_dem_terraintiles_z12_3310.tif`, `cov_slope_deg_..._3310.tif`,
  `cov_aspect_deg_..._3310.tif`. 1 m lidar noted, deferred.
- **Roads (Decision 14):** Geofabrik **NorCal** shapefile extract (OSM, `fclass`).
  CA-statewide extract does not exist (only stale 2014–2018 snapshots) →
  NorCal sub-region, which fully contains the study area. osmdata/Overpass
  rejected (`fclass` is Geofabrik-only; Overpass timeout risk). 936,784 features
  clipped, EPSG:3310. Two layers: `cov_roads_osm_3310.gpkg` (all classes) +
  `cov_roads_osm_major_3310.gpkg` (motorway→secondary barrier subset). Download
  guarded with `PK`-magic check after a statewide URL returned an HTML page.
  Pinned by download date + server `Last-Modified` (no DOI).
- **Traffic (Decision 14):** Caltrans **Traffic_AADT** MapServer (2023; the
  service is `Traffic_AADT`/MapServer, not `Traffic_Volumes_AADT`/FeatureServer).
  2,423 count stations clipped, EPSG:3310 (`cov_aadt_caltrans_points_3310.gpkg`).
  `AHEAD_AADT`/`BACK_AADT` stored as **strings** (median ~68k, max ~292k —
  freeway-scale). Caveats: **state-highway only** (no local roads) and
  string-volumes — both deferred to Week 5 covariate construction.
- **Open items → Week 5:** (1) tracks/paths permeability decision, per species;
  (2) AADT→road-segment join. Neither is an acquisition task.
- **renv:** `elevatr` + `osmdata` installed and snapshotted.
- **Docs updated:** methodology §4.6/§4.7, data-sources §4.2/§4.3, Decisions 13 & 14,
  change log.
- **Blockers:** none (CROS still parked, awaiting F. Shilling reply).
- **Next:** housing / human footprint (Census TIGER + block housing / SILVIS;
  Global Human Modification Index) — the last covariate group.

### Week 2 — covariates: housing / human footprint — August 3, 2026
- **Progress:** 🟢 In progress. Acquisition ~95% done — all datasets are now
  downloaded, but **Week 2 is not complete**: four tasks remain open (CROS reply,
  population-context references, `data/README.md`, `references.md`). Week 2 closes
  only when those are done.
- **Human modification (Decision 15):** Global Human Modification **v3, 2022**
  (Theobald et al. 2024), "all threats combined" (AA) 300 m COG on Zenodo (DOI
  10.5281/zenodo.14502573). Read **windowed via `/vsicurl`** off the 9.3 GB
  global file — never downloaded whole; guarded loud fallback to full download if
  Zenodo refuses range requests. **Chosen over the plan's Kennedy et al. 2019
  1 km layer**, which ships as a figshare zip / GEE asset (auth dependency this
  project avoids); v3 is a DOI-pinned COG, acquirable by the WorldCover pattern,
  and more current. Reproject bilinear (continuous). QC: EPSG:3310, 265 m cells,
  values in [0,1], study-area mean 0.325 (mixed urban–wildland, as expected).
  Output `cov_ghm_v3_2022_3310.tif`. Citation swap Kennedy 2019 → Theobald 2024.
- **Housing density (Decision 16):** SILVIS **Block Level Housing Density Change
  1990–2020** (PLA v4, CA shapefile extract). Housing **density** pre-computed
  per block (`HUDEN1990`–`HUDEN2020`) — chosen over a Census/`tidycensus` build
  (single direct download, no API join). Native EPSG:5070 → 3310; polygon layer,
  clipped (91,223 blocks). Output `cov_housing_silvis_blocks_3310.gpkg`.
  **Two caveats logged:** (a) PLA moves houses *out* of protected areas → density
  inside CPAD units is ~0 by construction (confirmed: `PUBFLAG=1` median 0 vs
  private 921) — density at a site measures the surrounding matrix, not the unit;
  (b) no WUI intermix/interface flags (separate SILVIS product, not acquired).
- **QC flag → pre-registered handling:** `HUDEN2020` max 2,263,007 units/km²
  (≈765× p90) is a small-area (sliver-block) density artifact, **not** a download
  error (~99% of blocks in 0–10⁴). Week-5 handling pre-registered **now** to avoid
  a post-hoc transform choice: `log1p` primary + p99/hard cap before rasterization
  (methodology §4.9). PLA near-zero public-land density left as-is (by design).
- **Cross-ref fix:** Decision 12 / methodology §4.5 / §4.7 point to "§4.4" for the
  footprint layers; in methodology that log is **§4.9** (§4.4 there is CROS).
  Pointer corrected in-doc. (In `data-sources.md` the footprint entry *is* §4.4.)
- **Collinearity note → Week 5:** gHM and housing density will correlate at the
  urban edge — check before stacking both into the resistance surface (per
  species, never pooled, Decision 3).
- **renv:** no new packages — `terra` / `sf` already snapshotted.
- **Docs updated:** methodology §4.9 + Decisions 15 & 16 + change log; data-sources
  §4.4 (human footprint) + licence table (dropped NLCD, added gHM/SILVIS/Caltrans).
- **Still open (non-acquisition, → Week 3):** population-context references
  (CA Mountain Lion Project + CDFW CESA); `data/README.md` acquisition steps;
  `docs/references.md` (incl. the Kennedy→Theobald swap — that file wasn't in
  hand this session). CROS remains parked, awaiting reply.
- **Remaining to close Week 2** (all non-acquisition; none blocking analysis):
  1. Population-context references — CA Mountain Lion Project abundance estimate +
     CDFW CESA status review, as reference material only (not a trend).
  2. `data/README.md` — acquisition steps for every layer.
  3. `docs/references.md` — cited reports/literature, incl. the Kennedy→Theobald
     citation swap for gHM (Decision 15; that file wasn't in hand this session).
  4. CROS — awaiting F. Shilling reply; download + doc once terms granted. If the
     reply is slow, Week 2 can be declared closed with CROS explicitly carried as
     a parked item (it's a threat overlay, not a Phase-1 backbone).
- **Blockers:** none.
- **Next:** finish the four items above to close Week 2, then Week 3 — open-space
  unit definition and study-area preparation (CPAD level choice + non-habitat
  filtering, Decision 5 / Risk 5; analysis grid at puma 1 km / bobcat 500 m).

### Week 2 closeout — August 3, 2026
- **Progress:** ✅ **Week 2 complete** — closed with CROS explicitly parked (no
  reply yet from F. Shilling). All acquisition done; the three ungated closing
  tasks are finished. CROS is a threat overlay, not a Phase-1 backbone, so its
  absence does not block Week 3.
- **Population-context references (task 1):** CA Mountain Lion Project abundance
  estimate (~3,200–4,500 statewide; three estimates — one ~4,511, two ~3,200;
  ~$2.45M over seven years; CDFW/UCSC/UCD/IWS/Audubon Canyon Ranch) and the CDFW
  status review / CESA listing for the Southern California / Central Coast
  population — both recorded in `docs/references.md` as **context only, never a
  trend**. Dellinger et al. method papers cited as the anchors; the consolidated
  Mountain Lion Project census report marked *to locate* (not invented).
- **⚠️ Stale-framing flag (the real find):** the inherited docs describe the
  SC/CC population as under a "status review supporting CESA listing" — i.e.
  *candidate*. As of **April 2026 it was formally listed as threatened** (the
  SC/CC **DPS**, SF Bay Area south to the Mexico border). **Central Coast North =
  the Santa Cruz Mountains pumas** — the exact population the puma connectivity
  narrative is built on. Flagged inline in `references.md`; `data-sources.md` §5
  left for Kiran to reconcile. Listing post-dates training cutoff; confirmed by
  web search 2026-08-03 via legal-alert secondary sources — **verify against the
  primary FGC notice before any public-facing claim.**
- **`data/README.md` (task 2):** per-layer acquisition spine — source / how /
  output for every open layer in `01_download_open_data.R` order, plus CROS and
  Felidae documented as gated/parked. Encodes the two-CRS discipline and the
  pre-registered Week-5 handling (SILVIS sliver-block log1p+cap; gHM×housing
  collinearity).
- **`docs/references.md` (task 3):** literature bibliography populated
  (population/status, Bay Area felid research stubs, road ecology, methods). The
  **Kennedy→Theobald gHM citation swap (Decision 15)** recorded as an explicit
  provenance note so it's discoverable from either `references.md` or
  `data-sources.md` §4.4.1 — not duplicated as a full dataset citation.
- **No new Decision triggered** — these are documentation tasks, not analytical
  choices. Next Decision (17) stays reserved for the Week-3 open-space level
  choice.
- **CROS (task 4):** still parked, awaiting F. Shilling reply. `data/README.md`
  documents it as a gated threat overlay with the published-hotspots fallback, so
  closure is clean — when terms land, download + document in `data-sources.md`
  §3.1 and lift the parked flag. No new work needed to hold it.
- **Doc hygiene noted (not blocking):** `naming-conventions.md` §2 still lists
  `cov_landcover_nlcd2021_3310.tif` as a filename example — stale after the
  NLCD→WorldCover pivot (Decision 12). Real file is
  `cov_landcover_worldcover2021_3310.tif`. One-line fix when convenient.
- **Blockers:** none.
- **Next:** Week 3 — open-space unit definition + study-area prep. CPAD level
  choice (Units vs SuperUnits vs Holdings) + non-habitat filtering (Decision 5 /
  Risk 5), CPAD↔CCED integration, and the analysis grid (puma 1 km / bobcat
  500 m). SuperUnits has no `COUNTY` field → spatial clip, not attribute filter.
