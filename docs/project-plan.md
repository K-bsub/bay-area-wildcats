# Project Plan

**Project:** Wild Cats at the Urban Edge
**Author:** Kiran Balasubramanian
**Start date:** July 23, 2026
**Target:** 10 weeks
**Last updated:** July 27, 2026

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
| **2** | Data acquisition | All open datasets downloaded and documented | 🟢 In progress |
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
- [ ] **Confirm CROS data-use / republication terms first** (Risk 3), then download puma + bobcat records → `data/raw/cros/`

*Covariates*
- [ ] Choose land-cover source (NLCD vs ESA WorldCover vs CAL FIRE FVEG) → record as a numbered decision, then download for the study area
- [ ] `elevatr`: download 3DEP terrain (10 m; note 1 m lidar coverage)
- [ ] Roads via `osmdata`/Geofabrik (`fclass`); Caltrans AADT traffic volumes
- [ ] Housing / human footprint: Census TIGER/Line + block housing (or SILVIS); Global Human Modification Index

*Population context (context only — no time series)*
- [ ] Gather CA Mountain Lion Project abundance estimate + CDFW CESA status review as reference material (not a trend)

*Documentation & reproducibility*
- [ ] Write `scripts/01_download_open_data.R` (scripted downloads where possible: `rgbif`, `rinat`, `elevatr`, `tigris`, `osmdata`)
- [ ] Create / complete `data/README.md` acquisition steps
- [ ] Fill every `docs/data-sources.md` entry (access date, version, path, record count, CRS, licence, known issues); confirm `data/raw/**` is gitignored
- [ ] Add cited reports / literature to `docs/references.md`

---

## Risks

| # | Risk | Level | Mitigation |
|---|---|---|---|
| 1 | **Occupancy modelling not feasible from opportunistic data** — `unmarked` needs detection histories from repeated visits; GBIF/iNat records are not survey data | 🔴 High | Assess in Week 4 before committing. Fallbacks: (a) spatial-replication design with documented assumptions; (b) request Felidae detection histories (Phase-3 partner data, not used in Phase 1); (c) drop to species distribution modelling (MaxEnt / `maxnet`) and reframe the narrative |
| 2 | **Puma records too sparse for any surface** — obscured and few | 🟢 Low (revised) | Substantially resolved: *Puma concolor* is not taxon-obscured (Decision 10); ~1,057 precise puma points held (median 26 m accuracy). A coarse distribution layer is now plausible — pending Week-4 dedupe (heavy GBIF overlap) + clip to confirm the *unique* count. Connectivity + CROS remain the puma backbone regardless |
| 3 | **CROS data-use terms restrict republication** | 🟡 Medium | Confirm terms in Week 2, before analysis is built on it. Fallback: aggregate to road segment and cite |
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
