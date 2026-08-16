# Project Plan

**Project:** Wild Cats at the Urban Edge
**Author:** Kiran Balasubramanian
**Start date:** July 23, 2026
**Target:** 10 weeks
**Last updated:** August 9, 2026

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
| **3** | Boundary and study-area preparation | Open-space units defined and filtered; analysis grid built | ✅ Complete |
| **4** | Occurrence processing | Cleaned, deduplicated, CRS-aligned occurrence layers for both species | ✅ Complete |
| **5** | Covariate preparation | Land cover, terrain, roads, housing summarised to grid and unit | ✅ Complete |
| **6** | Descriptive spatial analysis | KDE and Gi\* for both species; unit-level statistics | ✅ Complete |
| **7** | Occupancy modelling | Bobcat occupancy fitted and validated; puma feasibility assessed | 🟢 In progress |
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

## Week 3 tasks — open-space unit definition + study-area preparation

*Goal: turn raw statewide CPAD/CCED into the ten-county analysis frame — a
canonical open-space layer with a defined "site" unit, non-habitat parcels
filtered, CPAD↔CCED integrated, and the per-species analysis grids built.
Target output: `openspace_cpad_bayarea_3310.gpkg`. Next Decision number is 17.*

*Schema inspection (do first — write filters against the real schema, not the docs)*
- [x] Inspect the acquired CPAD 2026a layer(s): geometry levels held (Holdings
      162,773 / Units 17,930 / SuperUnits 17,169), fields, CRS (native 3310
      confirmed), validity (2 invalid Units, 3 invalid SuperUnits). Files are in
      `data/raw/cpad/` (not `data/interim/` as the task first assumed). Script `02`.
- [x] Enumerate filter fields + join keys — real names recorded: `ACCESS_TYP`,
      `AGNCY_TYP`/`MNG_AG_TYP`, `AGNCY_LEV`, `SPEC_USE`, `LAND_WATER`; join keys
      `HOLDING_ID`→`UNIT_ID`→`SUID_NMA`. Vocabularies dumped in script `02b`.
- [x] Confirmed CPAD Units **do** carry `COUNTY` (58 distinct, fully populated);
      SuperUnits do not. Membership is by spatial clip to
      `boundary_baydissolved_3310.gpkg`; `COUNTY` kept as audit check only.

*CPAD level choice — Decision 17 (Risk 5, resolved)*
- [x] Site unit decided: **Units** (Decision 17). SuperUnits ruled out (near-flat
      ~4% aggregation, no `COUNTY`), Holdings ruled out (fragments habitat);
      `suid_nma` carried as attribute for connectivity roll-up.
- [x] Large-Unit gradient flag added: `spans_gradient` = `hab_area_km2 > 5 km²`
      (192 units), a Week-4/5 covariate pre-flag (not a filter), written to the
      layer.

*Non-habitat filtering — Decision 18 (resolved)*
- [x] Criteria defined + justified (Decision 18): 0.10 km² habitat-area floor +
      `SPEC_USE`/`LAND_WATER`/Cemetery-District deny-list; `ACCESS_TYP`
      deliberately excluded (would drop 12.6% of area). `hab_frac ≥ 0.50` cutoff
      confirmed against a bimodal distribution.
- [x] Filter→dissolve ordering recorded and implemented: flag at Holdings →
      overlay to Units → filter → dissolve. Non-habitat **flagged, not erased**.
- [x] Audit trail logged: 4,375 → 1,142 (size floor) → 1,129 units; 4,660.4 km²
      habitat retained; 106 `has_nonhabitat`.

*CPAD↔CCED integration — Decision 19 (resolved)*
- [x] Integration form decided (Decision 19): **two frames, not one.** Occupancy
      frame stays CPAD-only; connectivity frame is a CPAD∪CCED **union** with
      `protection_type` {fee, easement}. (Correcting the original Week-3 goal
      wording — the union is a *separate* connectivity layer, NOT folded into
      `openspace_cpad_bayarea_3310.gpkg`.)
- [x] `protection_type` values defined; overlap resolved by **fee precedence**
      (CPAD fee differenced out of CCED before merge). Result: 3,773 features
      (1,129 fee + 2,644 easement); 498.2 km² overlap erased; CCED adds
      1,275.7 km² new land.
- [x] CCED coverage-gap caveat (Decision 9) carried forward — union labels tenure
      where CCED has data; absence ≠ unprotected.

*Analysis grids — puma 1 km, bobcat 500 m (separate, never pooled — Decision 3)*
- [x] Puma grid built: 1 km, EPSG:3310, snapped to round 3310 origin, masked to
      boundary. 45,400 cells / 20,416 land. 1 km cell = the puma publish floor
      (policy §3), confirmed.
- [x] Bobcat grid built: 500 m, EPSG:3310, shared origin — nests 4:1 in the puma
      grid (verified). 181,600 cells / 80,073 land. Separate file.
- [x] Grid extent, origin, cell counts, CRS recorded (data dictionary + 02e
      output).

*Documentation & reproducibility*
- [x] Wrote the `02`-family scripts (split from the single script the plan first
      imagined, which was cleaner): `02_prepare_openspace.R` (schema inspection,
      read-only), `02b_filter_vocab_probe.R` (vocab/area probe, read-only),
      `02c_prepare_openspace_build.R` (filter → overlay → dissolve → clip → write
      occupancy layer), `02d_prepare_protected_union.R` (CPAD∪CCED connectivity
      layer, Decision 19). Full scripts, numbered-step comments, EPSG suffix on
      every written layer.
- [x] Grids folded into the `02` family as `02e_build_grids.R` (the plan allowed
      "or fold into `02_`") — puma 1 km + bobcat 500 m, aligned/nested, EPSG:3310.
- [x] Added all four output layers to `docs/data-dictionary.md` — every field
      typed, with units, description, source, nulls-allowed.
- [x] Recorded Decisions 17–19 in `docs/methodology.md` §6 with date +
      justification + observed results; change-log rows added to §9.
- [x] Updated `docs/data-sources.md` — CPAD §1.1 feature counts filled + derived
      outputs noted; CCED §1.2 union note added. The integrated layer does **not**
      warrant a new source entry (it is derived, not a source); its full spec
      lives in the data dictionary. `data/interim/**` + `data/restricted/**`
      gitignore confirmed.

*Doc-hygiene carry-ins from Week 2*
- [x] `naming-conventions.md` §2 — already using `cov_landcover_worldcover2021_3310.tif`
      (NLCD example was already fixed; no change needed).
- [x] Reconcile `data-sources.md` §5 CESA framing: corrected "status review"
      (candidate) → **listed threatened April 2026** (SC/CC DPS; Central Coast
      North = Santa Cruz Mountains). Verify against primary FGC notice before any
      public-facing claim.

*Explicitly NOT this week (guard against scope creep — Risk 4)*
- Occurrence dedupe/clip (Week 4) — including the puma unique-count confirmation.
- Covariate summarisation to unit/grid (Week 5).
- Any occupancy detection-history construction (Week 4 feasibility gate, Risk 1).

---

## Week 4 tasks — occurrence processing + occupancy feasibility gate

*Goal: turn the raw GBIF and iNaturalist downloads into clean, deduplicated,
CRS-aligned, study-area-clipped occurrence layers for each species — then run
the Risk 1 gate that decides whether the bobcat track is occupancy modelling or
SDM. Puma and bobcat processed in parallel, never pooled (Decision 3).
Next Decision number is 20.*

*Inputs on hand (from Week 2 — see `data/README.md`)*
- `data/raw/gbif/<key>.zip` — GBIF, both species (DOI 10.15468/dl.87ne3u; puma
  1,843 · bobcat 5,164 pre-filter).
- `data/raw/inaturalist/inat_research_bayarea.rds` — iNat research-grade (puma
  2,102, 50% obscured · bobcat 6,295, 31% obscured); obscuring fields preserved.
- Clip frame: `boundary_baydissolved_3310.gpkg`. Grids: `grid_puma_1km_3310.tif`,
  `grid_bobc_500m_3310.tif`.

*Schema inspection (do first — same discipline as Week 3)*
- [x] Load both raw sources; print columns, row counts, CRS, date ranges, and the
      obscuring/accuracy fields actually present (`coordinates_obscured`,
      `taxon_geoprivacy`, `geoprivacy`, `public_positional_accuracy`,
      `coordinateUncertaintyInMeters`). Write cleaning against the real schema.
- [x] Confirm the GBIF↔iNat relationship: iNat records flow into GBIF, so the two
      **overlap heavily**. Quantify the overlap before deduping — this is the
      crux of the puma unique-count (Risk 2).

*Cleaning + CRS + clip (per species, per source)*
- [x] Reproject both sources to EPSG:3310; filenames end in `_3310`
      (`occ_puma_gbif_clean_3310.gpkg`, `occ_bobc_inat_research_3310.gpkg`, etc.).
- [x] Clip to `boundary_baydissolved_3310.gpkg` (study-area frame).
- [x] Coordinate-quality filter: define and justify a `coord_uncert_m` threshold
      as a numbered decision (Decision 20). Note the asymmetry — puma iNat coords
      are dominated by ~28 km obscuring (median 28,240 m) for *obscured* records,
      but Decision 10 established puma is **not taxon-obscured** in CA, so the
      precise (~1,057) and obscured records must be separated, not blanket-cut.
- [x] Preserve, don't drop, the `obscured` flag and `coord_uncert_m` on every
      record — needed for the T1/T2 handling (sensitive-data-policy §2) and the
      detection-effort/observer-bias question (proposal Q5).

*Dedupe — the load-bearing step (Risk 2)*
- [x] **Dedupe across GBIF ∪ iNat, do not sum** (README_data explicitly flags
      this). Define the dedupe key (e.g. same observer/date/coordinate, or GBIF
      `occurrenceID` provenance back to iNat) as part of Decision 20.
- [x] Report the **unique** puma count after dedupe + clip + quality filter —
      this confirms or revises Risk 2 (the "~1,057 precise puma points" figure)
      and determines whether a coarse puma distribution layer is viable alongside
      the connectivity backbone.
- [x] Report unique bobcat count — feeds the occupancy feasibility gate below.

*Occupancy feasibility gate — Risk 1 (the decision that shapes Weeks 6–7)*
- [x] Assess whether a defensible **detection history** can be built for bobcat
      from opportunistic records against the pre-registered fallback criteria in
      `methodology.md §5.4`: fewer than 40 usable site histories, naive occupancy
      outside 0.10–0.90, detection probability below 0.10, parameter instability,
      or MacKenzie-Bailey GOF failure. **Criteria are fixed before fitting** — no
      post-hoc rationalisation.
- [x] Site = open-space unit (`openspace_cpad_bayarea_3310.gpkg`); replicate =
      time bin; effort via target-group background. Count usable site-histories
      against the ≥40 floor (1,129 units is the ceiling, not the usable count).
- [x] Record the gate outcome as a numbered decision: **occupancy proceeds** or
      **fall back to SDM (`maxnet`/ENMeval)** and reframe the bobcat question
      (proposal Q2 stands either way; only the method changes).

*Documentation & reproducibility*
- [x] Write `scripts/03_prepare_occurrences.R` (schema → clean → CRS → clip →
      quality filter → dedupe → per-species clean layers). Full script, numbered
      steps, EPSG suffix on every written layer.
- [x] Add all occurrence output layers to `docs/data-dictionary.md` (every field,
      including `obscured`, `coord_uncert_m`, `source`, `species`).
- [x] Record Decision 20 (and the Risk 1 gate decision) in `methodology.md` §6 +
      change-log §9; update §4.2/§4.3 processing logs with observed counts.
- [x] Update Risk 1 and Risk 2 status in this plan once the gate + unique count
      resolve.

*Explicitly NOT this week (Risk 4)*
- Covariate summarisation to unit/grid (Week 5).
- KDE / Gi* descriptive analysis (Week 6).
- Any occupancy *fitting* — Week 4 only builds the detection history and runs the
  feasibility gate; model fitting is Week 7.
- CROS integration (parked, Decision 11).

---

## Week 5 tasks — covariate construction + resistance surface + bobcat detection history

*Goal: turn the raw covariate downloads into analysis-ready, unit- and
grid-summarised layers for both tracks; build the puma resistance surface; and
construct the bobcat detection history that closes Decision 22. Puma and bobcat
covariates stay on their own grids (puma 1 km, bobcat 500 m); never pooled
(Decision 3). Next Decision number is 23.*

*Inputs on hand (from Weeks 2–4)*
- Covariate rasters/vectors: `cov_landcover_worldcover2021_3310.tif`,
  `cov_ghm_v3_2022_3310.tif`, `cov_housing_silvis_blocks_3310.gpkg`,
  `cov_roads_osm_*_3310.gpkg`, `cov_aadt_caltrans_points_3310.gpkg`,
  terrain (DEM + slope/aspect).
- Frames/grids: `openspace_cpad_bayarea_3310.gpkg` (1,129 units, carries
  `spans_gradient`), `protected_union_bayarea_3310.gpkg`,
  `grid_puma_1km_3310.tif`, `grid_bobc_500m_3310.tif`.
- Occurrence + effort: `occ_bobc_clean_3310.gpkg`, `occ_puma_clean_3310.gpkg`,
  `cov_effort_gbif_mammal_unityear_3310.gpkg` (3A),
  `cov_effort_gbif_vertebrate_unityear_3310.gpkg` (3B).

*Covariate transforms (pre-registered — apply as specified, record the observed values)*
- [x] **SILVIS `HUDEN2020` transform** (pre-registered Week-2 QC): `log1p` +
      p99/hard cap **before** rasterization, to tame the sliver-block artifact
      (max 2,263,007 units/km², ~765× p90). Record the exact cap value and the
      number of blocks affected when run — this was pre-registered to prevent a
      post-hoc transform choice.
- [x] **gHM × housing-density collinearity check** (flagged Week 2): both carry
      the urban-intensity gradient (Decision 12) and will correlate. Compute the
      correlation at unit/grid summary level and decide — before stacking — which
      to keep, or whether to keep both with the collinearity documented. Numbered
      decision if one is dropped.

*Covariate summarisation to unit + grid (per species, on the right grid)*
- [x] Summarise each covariate to (a) CPAD units (occupancy frame) and (b) the
      species grid (puma 1 km, bobcat 500 m). Categorical → `near`, continuous →
      `bilinear` on any reprojection; filenames end in `_3310`.
- [x] **`spans_gradient` handling** (192 units, `hab_area_km2 > 5 km²`): it is a
      **covariate pre-flag, not a filter** (Decision 17). For these large units a
      whole-unit covariate mean is unsafe — summarise by sub-cell, or carry the
      within-unit covariate heterogeneity as a flag, per the pre-registered
      intent. Do not drop them.
- [x] Write stacked covariate tables keyed on `unit_id` (occupancy) and
      `cell_id` (grid), with a data-dictionary entry per output.

*Roads / traffic finalisation (deferred from Week 2, Decision 14 open items)*
- [x] **Tracks/paths permeability decision, per species** — whether OSM
      `track`/`path` classes count as barriers, neutral, or permeable, and
      differently for puma vs bobcat. Numbered decision.
- [x] **AADT → road-segment join** — attach Caltrans `AHEAD_AADT`/`BACK_AADT`
      (currently point stations, stored as strings) to road segments so traffic
      *volume* (not just road presence) drives the puma barrier effect (proposal
      Q3). Parse the string AADT to numeric here.

*Puma resistance surface (connectivity track)*
- [x] Build `resist_puma_baseline_3310.tif` on the 1 km grid from the stacked
      covariates (land cover, terrain, human modification/housing, road+traffic
      barrier). Pre-register the resistance assignment before building — no
      post-hoc weight tuning. Publishable at 1 km (sensitive-data-policy §3).

*Bobcat detection history — closes Decision 22*
- [x] Build the unit × year detection history by crossing `occ_bobc_clean_3310`
      (detections) against the Fork-3 effort layer (surveyed cells). Surveyed +
      no bobcat = 0; unsurveyed = NA (never a fabricated 0). Calendar-year
      replicate, 2010–2026 window (Decision 22 draft).
- [x] Build it under **both** backgrounds (3A mammal / 3B vertebrate) — the A-vs-B
      choice is held to the fit (Decision 22).
- [x] Fit the **null** occupancy model (`unmarked`) under each background and
      read the Week-7-deferred §5.4 criteria that are now testable: fitted
      detection probability `p`, parameter stability, MacKenzie-Bailey GOF.
- [x] **Close Decision 22** on the result: occupancy confirmed (and which
      background), or SDM fallback re-triggered. Record which background won and
      the fitted `p` under each.

*Documentation & reproducibility*
- [x] Numbered decisions for: gHM/housing collinearity outcome (if a drop),
      tracks/paths permeability, resistance assignment, and the Decision 22
      close. Record the observed SILVIS cap value + affected-block count.
- [x] Add every stacked covariate + resistance + detection-history output to
      `docs/data-dictionary.md`.
- [x] Update `methodology.md` §5 (methods now executed, not just defined) + §6 +
      change-log §9. Update Risk 1 status once Decision 22 closes.

*Explicitly NOT this week*
- KDE / Gi* descriptive analysis (Week 6).
- Least-cost paths / corridor extraction from the resistance surface (Week 6+).
- CROS integration (parked, Decision 11).
- Felidae partner data (deferred, Decision 7).

---

## Week 6 tasks — descriptive spatial analysis (KDE + Gi*, both species)

*Goal: characterise WHERE each species' records concentrate, descriptively, before
any inferential modelling. Kernel density surfaces + Getis-Ord Gi* hot/cold spots
for puma and bobcat, plus unit-level summary statistics. This is a descriptive
layer for the story site and a cross-check on the occupancy/connectivity results —
NOT a model. Both species; each on its own grid (puma 1 km, bobcat 500 m); never
pooled (Decision 3). Next Decision number is 31.*

*Inputs on hand (from Weeks 4–5)*
- Occurrence layers: `occ_puma_clean_3310.gpkg` (2,031), `occ_bobc_clean_3310.gpkg`
  (6,232) — both carry the `obscured` flag (Decision 20/21).
- Frames/grids: `openspace_cpad_bayarea_3310.gpkg` (1,129 units),
  `grid_puma_1km_3310.tif`, `grid_bobc_500m_3310.tif`.
- Effort context: the Fork-3 effort layers + the detection histories (`dh_bobc_*`)
  — for the Q5 effort-bias cross-read, not as KDE input.

*Kernel density estimation (per species, on the right grid)*
- [x] Build KDE surfaces with `spatstat.explore::density.ppp()` + edge correction
      (methodology §5.1). Puma on the 1 km grid, bobcat on the 500 m grid.
      Bandwidth chosen by a stated rule (e.g. `bw.diggle`/`bw.ppl`), recorded — not
      hand-tuned to a look. Outputs `kde_puma_current_1km_3310.tif`,
      `kde_bobc_current_500m_3310.tif`.
- [x] **Obscured-coordinate handling for KDE.** Puma is 49% obscured with ~28 km
      randomised coords (Decision 10/20) — a KDE on randomised points smears
      density. Decide + record: precise-only KDE, or precise + an obscured-density
      caveat. Numbered decision if it changes the published surface.
- [x] **Publish-floor compliance (puma).** Any published puma KDE is ≥1 km and
      generalised per sensitive-data-policy §3 — the 1 km grid already satisfies
      this; confirm no finer intermediate is exported.

*Getis-Ord Gi* hot/cold spots (per species)*
- [x] Compute Gi* with `sfdep::local_gstar_perm()` (permutation inference,
      methodology §5.2) on a unit- or grid-aggregated count. State the
      neighbour/weight definition (`_nb`) and the aggregation grain explicitly.
      Outputs `hot_puma_*_3310.gpkg`, `hot_bobc_*_3310.gpkg`.
- [x] **Effort-bias cross-read (Q5, first-class question).** A raw-count hotspot
      is partly an observer-effort hotspot. Cross the Gi* result against the
      Fork-3 effort layer (or an iNat-observer density) and state, per species,
      how much of the apparent pattern is plausibly effort vs true distribution.
      This is the descriptive analogue of the tiger project's Ranthambore
      observer-bias finding — carry it as a stated caveat on every hotspot map.

*Unit-level summary statistics*
- [x] Per-unit descriptive table: record counts, bobcat naive **detection**
      (`bobc_detected` = 1/0/NA; the naive observable, NOT modelled ψ), obscured
      fraction (flagged sparse/low-meaning — randomised coords), effort-year count,
      KDE mean + max (zonal), Gi* class — keyed on `unit_id`. Two tables, one per
      species (`stats_puma_unit_3310.csv`, `stats_bobc_unit_3310.csv`). Feeds the
      story-site unit popups and the methods cross-check.

*Documentation & reproducibility*
- [x] Numbered decision(s) for any KDE bandwidth rule / obscured-KDE handling that
      affects a published surface; record the chosen bandwidth + weight scheme.
- [x] Add `kde_*`, `hot_*`, the two matrix layers, and both unit-stats tables to
      `docs/data-dictionary.md`.
- [x] Update `methodology.md` §5.1 (unit stats), §5.2 (KDE), §5.3 (Gi*) — methods
      now executed — + §9 change log. (Gi* is §5.3, not §5.2 as originally planned.)
- [x] Packages `spatstat.explore`, `spatstat.geom`, `sfdep`, `spdep` were already
      declared in `00_setup_environment.R` — confirmed present, no fresh
      `renv::install()` needed; verify against `renv.lock`.

*Carry-ins from Week 5 (pre-registered checks — NOT started here, tracked)*
- Puma resistance sensitivity checks (Decision 26: road-confidence, chaparral,
  ±10% weight) — judged on corridor stability, so they run with the Week-8
  least-cost work, not here.
- Bobcat covariate-model c-hat decline check (Decision 22) — belongs to Week-7
  covariate occupancy fitting.

*Explicitly NOT this week (Risk 4 — scope guard)*
- Covariate occupancy model fitting (Week 7 — the null fit is done; covariate
  models are next week).
- Least-cost paths / corridor extraction + resistance sensitivity checks (Week 8).
- CROS integration (parked, Decision 11); Felidae partner data (deferred,
  Decision 7).

---

## Week 7 tasks — bobcat covariate occupancy modelling + puma feasibility close

*Goal: fit the bobcat occupancy models with habitat covariates — the inferential
step the Week-4 gate and the Week-5 null fit were building toward — and resolve
the pre-registered forward check that Decision 22's close created. Confirm the
puma track needs no occupancy fit (it stays connectivity/SDM). Bobcat only for
the occupancy models; puma and bobcat never pooled (Decision 3). Next Decision
number is 31.*

*Inputs on hand (from Weeks 4–6)*
- Detection histories: `dh_bobc_{mammal,vertebrate}_{precise,all}_3310.rds`
  (unit×year, 1/0/NA), plus the null fits in `outputs/models/`.
- Occupancy covariate stack: `stack_occu_units_3310.gpkg` — per-unit, keyed
  `unit_id`: `lc_frac_{tree,shrub,grass}`, `elev_mean`/`elev_sd`,
  `slope_mean`/`slope_sd`, `aspect_north`/`aspect_east`, `ghm_mean`/`ghm_sd`,
  `housing_logden_mean`/`housing_logden_sd`, `spans_gradient`.
- Effort layers: `cov_effort_gbif_mammal_unityear_3310.gpkg` (3A, the
  target-group-correct background per Decision 22), vertebrate (3B) retained for
  the background-sensitivity read.
- Descriptive cross-check: `stats_bobc_unit_3310.csv`, `hot_bobc_gistar_unit_3310.gpkg`
  (Week 6) — the KDE / Gi* pattern to sanity-check the fitted ψ surface against.

*Bobcat covariate occupancy fit (`unmarked::occu()`)*
- [ ] **Detection sub-model (p).** Fit detection covariates before occupancy
      covariates (standard `unmarked` order). Candidate detection covariates:
      per-unit effort (surveyed-year count) and any year/effort-structure term.
      State the covariate set and the standardisation (centre/scale continuous
      covariates before fitting). Primary background = 3A mammal_precise
      (Decision 22); 3B and the `_all` histories carried as the sensitivity set.
- [ ] **Occupancy sub-model (ψ).** Fit habitat covariates from
      `stack_occu_units_3310.gpkg`. Respect the Decision 23 keep/drop: bobcat
      **keeps both gHM and housing** at unit grain (r=0.07 PLA artifact, not
      collinear at this grain). Land cover as class-fractions, terrain
      (northness/eastness, not raw aspect), `spans_gradient` as a covariate flag.
      State the candidate model set and the selection approach (AIC / model
      averaging) **before** fitting — pre-registration discipline (as with the
      KDE bandwidth rule and the resistance weights).
- [ ] **Collinearity + scaling check** on the covariate design matrix before
      fitting — report VIF or a correlation screen; drop/keep decisions recorded,
      not silent. The gHM×housing unit-grain r=0.07 is expected (Decision 23) but
      re-confirm on the actual model matrix.

*Pre-registered forward check (the Decision 22 commitment — DO NOT skip)*
- [ ] **Covariate-model c-hat decline check.** The null model's c-hat ≈ 8.9
      (collapsed 4-period MB-GOF) **must decline substantially** once habitat
      covariates are added — that decline is the evidence the heterogeneity is
      real modelled signal, not structural misfit. Report the covariate-model
      c-hat against the null 8.9. **If it does NOT decline**, that is a genuine
      lack-of-fit problem to face here (candidate causes pre-named in Decision 22:
      unmodelled spatial autocorrelation, missing detection covariates, or
      effort-structure bias); report c-hat-inflated SEs and record the diagnosis.
      This is a declared check, not a post-hoc rescue.

*Prediction + descriptive cross-read*
- [ ] **ψ prediction surface**, keyed `unit_id`, per the primary model
      (`occu_bobc_pred_unit_3310.gpkg` or similar, `occu_` theme). Bobcat is
      low-sensitivity — no publish-floor constraint, but review before publication
      per policy §3.
- [ ] **Cross-check fitted ψ against the Week-6 descriptive pattern.** Do the
      high-ψ units align with the Gi* hot units and the KDE peaks, or diverge?
      Divergence is informative (Q5: effort-driven descriptive pattern vs
      covariate-driven modelled pattern) — state it, don't smooth it over.

*Puma feasibility close (milestone-table item)*
- [ ] **Confirm the puma track needs no occupancy fit.** Puma stays
      connectivity/SDM (proposal Q3; Decision 22 applies to bobcat only). Record a
      one-line confirmation that the puma occupancy fork was never opened — the
      puma deliverables are the resistance surface (done, Decision 26) + Week-8
      least-cost corridors, plus the Week-6 KDE/Gi* descriptive layer. No new
      decision needed unless something forces the fork open.

*Documentation & reproducibility*
- [ ] Numbered decision(s) for the covariate model set + selection approach, and
      for the c-hat forward-check outcome (a Decision recording pass/fail and any
      remediation). Record standardisation and the detection/occupancy covariate
      sets.
- [ ] Add the ψ prediction surface (and any model-summary table) to
      `docs/data-dictionary.md`; models to `outputs/models/`.
- [ ] Update `methodology.md` §5.4 (occupancy — method now executed with
      covariates), §6 (decisions), §9 (change log). Close the Decision 22 forward
      check explicitly.
- [ ] New packages if any (e.g. `AICcmodavg` for GOF/`c-hat`, if not already in
      the stack) → confirm in `00_setup_environment.R` / `renv.lock`;
      `renv::install()` + `renv::snapshot()` only if genuinely absent.

*Carry-ins / parked (tracked, NOT started here)*
- Puma resistance sensitivity checks (Decision 26: road-confidence, chaparral,
  ±10% weight) — Week 8 least-cost work.
- CROS still parked (Decision 11, awaiting F. Shilling); Felidae deferred
  (Decision 7). CAL FIRE FVEG chaparral supplement only if WorldCover shrub
  under-mapping proves material at fit.

*Explicitly NOT this week (Risk 4 — scope guard)*
- Least-cost paths / corridor extraction + puma resistance sensitivity (Week 8).
- Story-site build (Week 9); CROS integration (parked); Felidae (deferred).
- Any puma occupancy model — the puma track is connectivity/SDM by design.

---

## Risks

| # | Risk | Level | Mitigation |
|---|---|---|---|
| 1 | **Occupancy modelling not feasible from opportunistic data** — `unmarked` needs detection histories from repeated visits; GBIF/iNat records are not survey data | 🟢 Low (gate passed) | Assessed Week 4 (script 03a): pre-fit §5.4 criteria PASS — 321 site histories, 194 units with ≥2 detection-years, naive ψ 0.284 (all in range). Fork-3 background effort built (script 03b, GBIF DOI 10.15468/dl.6xzcjt) supplying real non-detections. Decision 22 drafted **occupancy proceeds**, held open only on the fit-time criteria (fitted `p`, stability, GOF) that resolve at the Week-5 null fit. SDM fallback (`maxnet`/ENMeval) retained if the fit fails |
| 2 | **Puma records too sparse for any surface** — obscured and few | 🟢 Low (resolved) | Resolved Week 4: after GBIF∪iNat identity-dedupe + clip, **2,031 unique puma records (1,028 precise + 1,003 obscured)**. The "~1,057 precise" figure held (1,028 post-clip). A coarse puma distribution layer is viable alongside the connectivity backbone; obscured records ride an `obscured` flag (Decisions 20/21). Connectivity + CROS remain the puma backbone regardless |
| 3 | **CROS data-use terms restrict republication** | 🟡 Medium | Terms confirmed request-gated (no open API; Decision 11); data request sent Aug 2 to F. Shilling, awaiting reply. Parked, not blocking — it's a threat overlay, not a Phase-1 backbone. Fallback: aggregate to road segment and cite |
| 4 | **R spatial toolchain / learning curve** — new stack after ArcGIS | 🟡 Medium | Week 1 buffer for setup; keep scripts small and numbered; `targets` deferred until pipeline is stable |
| 5 | **CPAD includes non-habitat parcels** | 🟢 Low (resolved) | Mitigated by Decision 18 (Week 3): 0.10 km² habitat-area floor + `SPEC_USE`/`LAND_WATER`/Cemetery deny-list, non-habitat flagged-not-erased, `hab_frac ≥ 0.50`. 4,375 → 1,129 units; `ACCESS_TYP` deliberately not used as a filter (would drop watershed/ranch habitat) |
| 6 | **Sensitive data disclosure** | 🔴 High | `docs/sensitive-data-policy.md` enforced from Week 1; `data/restricted/**` gitignored. Felidae (restricted tier) deferred — none held. **The project holds 1,028 precise puma coordinates** (Week-4 confirmed, `occ_puma_clean_3310.gpkg` `obscured = FALSE`) from open-geoprivacy iNat records (Decision 10): the ≥1 km publish floor + `assert_publishable()` are load-bearing, not precautionary. Never publish precise puma surfaces |

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

### Week 3 closeout — August 5, 2026
- **Progress:** ✅ **Week 3 complete** — study-area frame built. Four
  analysis-ready layers under `data/interim/`, three new Decisions (17–19), all
  documentation updated.
- **Occupancy frame — `openspace_cpad_bayarea_3310.gpkg` (1,129 units).**
  CPAD **Units** chosen as the site unit (Decision 17); SuperUnits ruled out
  (near-flat ~4% aggregation, no `COUNTY`), Holdings ruled out (fragments habitat
  on ownership seams). Non-habitat filtered (Decision 18): 0.10 km² habitat-area
  floor + `SPEC_USE`/`LAND_WATER`/Cemetery deny-list, flagged-not-erased,
  `hab_frac ≥ 0.50`. 4,375 → 1,142 (floor) → 1,129 units; 4,660.4 km² habitat.
  `ACCESS_TYP` deliberately **not** a filter — "No Public Access" is 12.6% of
  area and captures SFPUC watershed / ranch-easement habitat.
- **Connectivity frame — `protected_union_bayarea_3310.gpkg` (3,773 features).**
  CPAD fee ∪ CCED easement with `protection_type` and **fee precedence on
  overlap** (Decision 19). 498.2 km² of easement/fee overlap erased; CCED adds
  **1,275.7 km²** of genuinely new protected land (~27% over the fee footprint) —
  easements are a material part of the connectivity fabric. Kept **separate** from
  the occupancy frame by design; not folded in.
- **Analysis grids.** `grid_puma_1km_3310.tif` (20,416 land cells) +
  `grid_bobc_500m_3310.tif` (80,073 land cells), snapped to a shared round-3310
  origin, bobcat nesting 4:1 inside puma (verified). 1 km puma cell = the
  sensitive-data-policy §3 publish floor. Separate grids, never pooled (Decision 3).
- **`spans_gradient` flag** (192 units, `hab_area_km2 > 5 km²`) written to the
  occupancy layer — a Week-4/5 covariate pre-flag (not a filter) marking large
  units where a whole-unit covariate mean smears across a land-cover gradient.
- **Scripts:** `02` (schema inspection), `02b` (vocab/area probe), `02c` (build
  occupancy layer), `02d` (build union), `02e` (grids). Split from the single
  script the plan first imagined — cleaner and matches how the work broke.
- **Docs updated:** Decisions 17–19 in `methodology.md` §6 + change log §9; four
  layers in `data-dictionary.md`; `data-sources.md` CPAD/CCED derived-output
  notes + feature counts; `data-sources.md` §5 CESA framing corrected to the
  April 2026 threatened listing. `data/interim/**` + `data/restricted/**`
  gitignore confirmed clean.
- **Two area definitions coexist by design:** occupancy `hab_area_km2`
  (4,660.4 km², habitat only) vs union raw `area_km2` (fee 4,720.8 km²) — the
  ~61 km² gap is flagged interior non-habitat, documented in the data dictionary
  so it never reads as a discrepancy.
- **Carry-ins to Week 4:** CROS still parked (Decision 11, awaiting F. Shilling);
  CESA §5 wording corrected but **verify against the primary FGC notice** before
  any public-facing claim.
- **Blockers:** none.
- **Next:** Week 4 — occurrence processing (GBIF + iNat dedupe/clean/clip for
  both species) and the Risk 1 occupancy-feasibility gate. The puma unique-count
  confirmation (Risk 2) lands here: heavy GBIF/iNat overlap means **dedupe, don't
  sum** the ~1,057 precise puma points.

### Week 4 closeout — August 9, 2026
- **Progress:** ✅ **Week 4 complete** — occurrence layers built, occupancy gate
  passed, Fork-3 background effort acquired. Decisions 20–21 closed, 22 drafted
  (held to the Week-5 fit). Scripts `03`, `03a`, `03b`.
- **Occurrence layers (script 03).** GBIF ∪ iNat deduped on **observation
  identity, not coordinates** (Decision 20) — obscured puma coords are randomised
  and differ between feeds. iNat `.rds` is master; GBIF contributes only its
  non-iNat remainder. Results: `occ_puma_clean_3310.gpkg` **2,031** (1,028
  precise + 1,003 obscured), `occ_bobc_clean_3310.gpkg` **6,232** (4,420 precise
  + 1,812 obscured), after a 360-row / 4.2% study-area clip. No `coord_uncert_m`
  cutoff at the layer stage (Decision 20 amended — filter per-analysis); puma
  obscured kept under an `obscured` flag, not cut (Decision 21).
- **Risk 2 resolved.** The "~1,057 precise puma" figure held — 1,057 precise iNat
  puma pre-clip → 1,028 post-clip. A coarse puma distribution layer is viable
  alongside the connectivity backbone. Decision 10 confirmed empirically: **zero**
  puma records taxon-obscured; obscuring is entirely observer-set `geoprivacy`.
- **Risk 1 gate passed (script 03a, diagnostic only).** Site = CPAD unit,
  replicate = calendar year, window 2010–2026. Pre-fit §5.4 criteria all PASS:
  **321** occupied units (≥40 floor), **194** units with ≥2 detection-years
  (repeat-visit structure — the part that usually kills opportunistic occupancy),
  naive ψ **0.284** (in 0.10–0.90). Recent window barely differs from all-years
  (97% of records are ≥2010), so the sample is already contemporary. `p`,
  parameter stability, MacKenzie-Bailey GOF are un-evaluable pre-fit — deferred
  to the Week-5 null fit by construction.
- **Fork-3 background effort (script 03b).** Reframed from `rinat` (fought the
  iNat 10k cap — capped even at month level for City Nature Challenge) to a single
  **GBIF async download** (no cap, server-side filter; DOI 10.15468/dl.6xzcjt).
  Scope widened to **all GBIF datasets** (broad effort proxy). Dissolved-boundary
  WKT footprint (not bbox — bbox pulled 42.8M records incl. ocean/Central Valley;
  boundary cut it to 33.0M). Two effort layers written:
  `cov_effort_gbif_mammal_unityear_3310.gpkg` (3A) and
  `cov_effort_gbif_vertebrate_unityear_3310.gpkg` (3B).
- **Decision 22 drafted — occupancy proceeds, HELD OPEN.** The gate passes and a
  fittable detection history demonstrably exists, but the decision is held on the
  fit-time criteria. **Fork 3A vs 3B held to the fit**: mammal background naive
  detection rate 0.171 vs vertebrate 0.083 — 3B is deflated by bird effort (99% of
  the pull is Aves) that shares little of a bobcat's detectability, so 3A is the
  target-group-correct option, but the *fitted* p decides. Both layers retained.
- **Docs updated:** Decisions 20–22 in `methodology.md` §6 + change log §9; §4.2/
  §4.3 processing logs updated with observed counts; two occurrence layers + two
  effort layers in `data-dictionary.md`; GBIF background download (DOI
  10.15468/dl.6xzcjt) added to `data-sources.md` §2.3; Known Limitations expanded
  with the occupancy-design caveats (52% out-of-unit records, 36% single-record
  units).
- **Carry-ins to Week 5:** close Decision 22 at the null fit (which background,
  fitted p); SILVIS `HUDEN2020` log1p+cap transform (pre-registered — record the
  cap value + affected blocks); gHM×housing collinearity check before stacking;
  tracks/paths permeability + AADT→segment join (deferred from Week 2);
  `spans_gradient` sub-cell covariate handling. CROS still parked (Decision 11).
- **Blockers:** none.
- **Next:** Week 5 — covariate stacking to unit/grid, puma resistance surface, and
  the bobcat detection-history build + null occupancy fit that closes Decision 22.

### Week 5 closeout — August 15, 2026
- **Progress:** ✅ **Week 5 complete** — covariate stacks, puma resistance surface,
  bobcat detection histories + null occupancy fit. Decisions 22–27 closed.
- **Summary:** covariate stacks built (`stack_occu_units_3310.gpkg`,
  `stack_puma_grid_1km_3310.gpkg`, `stack_bobc_grid_500m_3310.gpkg`); SILVIS
  HUDEN2020 winsorized at p99=10,415 then log1p (Decision 23); gHM×housing
  collinearity resolved per species (Decision 23 — puma drops housing, bobcat
  keeps both); roads/traffic finalised (Decisions 24–25); puma resistance surface
  `resist_puma_baseline_3310.tif` pre-registered + built (Decision 26); bobcat
  occupancy confirmed on the null fit (Decision 22 closed — fitted p=0.295, ψ=0.464;
  detected-cell upgrade Decision 27). Two pre-registered forward checks carried:
  puma resistance sensitivity (Week 8) and bobcat covariate-model c-hat decline
  (Week 7).

### Week 6 closeout — August 16, 2026
- **Progress:** ✅ **Week 6 complete** — KDE + Gi* descriptive analysis and
  per-unit summary statistics for both species. Decisions 28–30 closed. Single
  script `05_kde_and_hotspots.R` (three parts). Next Decision number is 31.
- **KDE (Decision 28/29, PART 1).** `density.ppp` + Jones-Diggle edge correction,
  precise-only surfaces. Bandwidth by a pre-registered rule (compute three
  candidates, choose by a fixed rule, record the value): puma → home-range prior
  **5,000 m** (both data-driven selectors rejected as effort-collapsed), bobcat →
  `bw.ppl` **1,109.6 m**. Obscured handling: published surfaces precise-only both
  species; a separate caveated obscured-puma companion for the Q5 read only
  (Decision 29). Outputs `kde_puma_current_1km_3310.tif`,
  `kde_puma_obscured_caveat_1km_3310.tif`, `kde_bobc_current_500m_3310.tif`,
  `tbl_09_kde_bandwidth_selection.csv`. Every puma export gated through
  `assert_publishable()`; no sub-1 km puma intermediate.
- **Gi* (Decision 30, PART 2).** Grain: CPAD unit (matches the effort layer; grid
  impossible — background points not retained). Neighbours: **two corrections
  recorded** — queen contiguity (stranded 43% of units) → KNN k=8 (distance-blind,
  diluted dense clusters, bobcat collapsed to 3) → **fixed distance band 6,342 m**
  (data-sized to ~8 neighbours) **+ KNN-8 floor**. Point→unit assignment three-way,
  grounded in each record's `coord_uncert_m` (~26–31 m median), not a 1–2 km
  constant; matrix points **retained** as `occ_<sp>_matrix_3310.gpkg` (Q5 +
  connectivity signal). Q5 effort cross-read first-class (SUSPECT/TRUSTED).
  Results: puma 47 hot / 430 cold, bobcat 6 hot / 224 cold, effort 104 hot. Bobcat
  6-hot verified real (not artifact) via Global G QC — a spatial-arrangement
  finding, not scarcity (§7). Outputs `hot_puma_gistar_unit_3310.gpkg`,
  `hot_bobc_gistar_unit_3310.gpkg`, `tbl_10_gistar_q5_crossread.csv`.
- **Unit stats (PART 3).** Two per-species tables `stats_puma_unit_3310.csv` /
  `stats_bobc_unit_3310.csv` (1,129 units, keyed `unit_id`): occurrence counts,
  obscured fraction (flagged sparse/low-meaning), effort-years, zonal KDE mean+max,
  Gi* class + Q5 flag; bobcat adds `bobc_detected` (naive observable, 351/508/270
  = detected/surveyed-not/never-surveyed — NOT modelled ψ). Both validated against
  the run numbers.
- **Literature.** Neighbour scheme and bandwidth rule grounded in a literature
  survey (ESRI Gi* best practice; Diggle 1985 / Berman & Diggle 1989 / Loader 1999
  for the selectors; Johnson et al. 2025 for the uncertainty-grounded snap). Added
  to `references.md`.
- **Docs updated:** Decisions 28–30 in `methodology.md` §6 + §5.1/5.2/5.3 + change
  log §9; five layers + two stats tables in `data-dictionary.md`; Week-6
  citations in `references.md`.
- **Carry-ins to Week 7:** bobcat covariate occupancy fit + the pre-registered
  **c-hat decline check** (Decision 22 forward commitment — the null's c-hat=8.9
  must drop substantially once habitat covariates are added). CROS still parked
  (Decision 11).
- **Minor open note (non-blocking):** 32 residual sub-graphs in the Gi* neighbour
  graph after the KNN floor — did not affect results (Global G confirms
  clustering); flag only if hot-spot mapping later shows odd isolated units.
- **Blockers:** none.
- **Next:** Week 7 — covariate occupancy model fitting for bobcat (the null fit is
  done; covariate models close the Decision 22 forward check).
