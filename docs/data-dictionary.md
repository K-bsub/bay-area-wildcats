# Data Dictionary

Every field in every processed layer under `data/interim/` and `data/processed/`.
Completed as layers are built. Field naming rules in `docs/naming-conventions.md` §5.

---

## Template

### `<layer_filename>`

**Source:** *(dataset)*
**Geometry:** *(point / polygon / raster)*
**CRS:** EPSG:3310
**Records:** *(n)*
**Created by:** `scripts/NN_*.R`

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| | | | | | |

**Notes:**

---

## Layers

### `openspace_cpad_bayarea_3310.gpkg`  — occupancy analysis frame (site layer)

**Source:** CPAD 2026a (Units, filtered) + CCED non-habitat flags via Holdings
**Geometry:** polygon (MULTIPOLYGON), one row per open-space unit
**CRS:** EPSG:3310
**Records:** 1,129 units (filtered from 4,375 Bay-Area units)
**Created by:** `scripts/02c_prepare_openspace_build.R`
**Storage:** `data/interim/` (T0 open — CPAD is public)
**Decisions:** 17 (Units as site), 18 (non-habitat filter)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `unit_id` | integer | — | CPAD `UNIT_ID`; stable site key (join to Holdings) | cpad | No |
| `unit_name` | character | — | CPAD `UNIT_NAME`; display name (**not** unique — join on `unit_id`) | cpad | No |
| `suid_nma` | integer | — | CPAD `SUID_NMA`; SuperUnit roll-up key (connectivity) | cpad | No |
| `county` | character | — | CPAD `COUNTY`; **audit attribute only** — membership is by spatial clip, not this field (Decision 17) | cpad | No |
| `access_typ` | character | — | CPAD `ACCESS_TYP`; **descriptive only, NOT a filter** (Decision 18) | cpad | No |
| `agncy_typ` | character | — | Owner agency type (`AGNCY_TYP`) | cpad | No |
| `agncy_lev` | character | — | Owner agency level (`AGNCY_LEV`): City/County/State/Federal/… | cpad | No |
| `mng_ag_typ` | character | — | Managing agency type (`MNG_AG_TYP`) | cpad | No |
| `unit_area_km2` | numeric | km² | Total unit area (raw `st_area`, post-clip) | derived | No |
| `nonhab_area_km2` | numeric | km² | Non-habitat area inside unit (flagged Holdings: golf/cemetery/water) | derived | No |
| `hab_area_km2` | numeric | km² | Habitat area = `unit_area_km2 − nonhab_area_km2`; **the area the size floor is applied to** | derived | No |
| `hab_frac` | numeric | — | `hab_area_km2 / unit_area_km2` (0–1); filter keeps ≥ 0.50 | derived | No |
| `has_nonhabitat` | logical | — | `TRUE` if any flagged non-habitat Holding falls inside (106 units) | derived | No |
| `spans_gradient` | logical | — | `TRUE` if `hab_area_km2 > 5 km²`; **covariate pre-flag, not a filter** — Week-4/5 should summarise these by sub-cell (192 units) | derived | No |

**Notes:**
- **Two area definitions coexist by design:** `hab_area_km2` (habitat only, used
  for the size floor) vs `unit_area_km2` (raw). The union layer (02d) reports raw
  fee area, so its 4,720.8 km² ≠ this layer's 4,660.4 km² habitat total — the
  ~61 km² gap is flagged interior non-habitat. Not a discrepancy (Decision 19).
- Non-habitat parcels inside kept units are **flagged, not erased** — geometry is
  intact; the signal is carried by `nonhab_area_km2` / `hab_frac` / `has_nonhabitat`.
- `spans_gradient` drops no units; it marks the large tail where a whole-unit
  covariate mean is unsafe.
- 2 invalid Unit geometries repaired with `st_make_valid()` on load.

---

### `protected_union_bayarea_3310.gpkg`  — connectivity analysis frame

**Source:** CPAD 2026a fee units (filtered) ∪ CCED 2026a easements
**Geometry:** polygon (MULTIPOLYGON), one row per fee unit or easement piece
**CRS:** EPSG:3310
**Records:** 3,773 features (1,129 fee + 2,644 easement, post fee-difference)
**Created by:** `scripts/02d_prepare_protected_union.R`
**Storage:** `data/interim/` (T0 open)
**Decision:** 19 (union with tenure preserved, fee precedence on overlap)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `protection_type` | character | — | `fee` (CPAD) or `easement` (CCED) — tenure class | derived | No |
| `src_id` | integer | — | Source key: `unit_id` (fee) or `e_hold_id` (easement) | cpad/cced | No |
| `holder_type` | character | — | Fee: `agncy_lev` (City/County/State/…). Easement: `eholdtyp` (Association/Private/NonProfit/Unknown/…) | cpad/cced | Yes (easement `Unknown`) |
| `land_type` | character | — | Fee: `agncy_typ` (owner agency type). Easement: `e_type` (Agricultural/Grazing/Habitat/Conservation/…) | cpad/cced | Yes (easement, sparse) |
| `pub_access` | character | — | Fee: `access_typ`. Easement: `pubaccess` (Closed/Open Access/Restricted Access) | cpad/cced | No |
| `county` | character | — | County label (source field) | cpad/cced | No |
| `area_km2` | numeric | km² | Feature area (raw `st_area`); easement pieces are post-difference | derived | No |

**Notes:**
- **Connectivity track only.** The occupancy frame is the CPAD-only layer above;
  the two are not interchangeable.
- **Fee precedence:** CPAD fee geometry is differenced out of CCED before merge,
  so every area is attributed once. 498.2 km² of easement overlapping fee was
  erased; 155 easements wholly inside fee land were dropped. CCED contributes
  1,275.7 km² of genuinely new protected land.
- `holder_type` / `land_type` are **not harmonised** across sources — fee and
  easement use different vocabularies by design; read them per `protection_type`.
- CCED coverage gap (Decision 9) is **not** closed by the union; absence of an
  easement ≠ unprotected.
- This is a tenure layer, **not** yet a habitat-patch layer — dissolving across
  tenure into contiguous patches is a Week-8 connectivity step.

---

### `occ_puma_clean_3310.gpkg`  — puma occurrence layer (cleaned, deduped)

**Source:** iNaturalist research-grade (`rinat`) ∪ GBIF non-iNat remainder
**Geometry:** point (POINT), one row per unique observation
**CRS:** EPSG:3310 (geometry). *Note:* `latitude`/`longitude` columns are the
original EPSG:4326 values, retained for provenance; geometry is the 3310 reprojection.
**Records:** 2,031 (1,028 precise + 1,003 obscured); iNat 2,017 + GBIF-non-iNat 14
**Created by:** `scripts/03_prepare_occurrences.R`
**Storage:** `data/interim/`. Tier **T1/T2** — precise (`obscured = FALSE`) puma
points are T2-sensitive (`sensitive-data-policy.md` §2); this raw layer is **not**
published. Published puma products are coarsened per policy §3.
**Decisions:** 20 (identity dedupe, no coord cutoff), 21 (obscured kept under flag)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `species` | character | — | Constant `puma` | derived | No |
| `source` | character | — | `inat` or `gbif` — feed of origin | derived | No |
| `obs_id` | character | — | Stable identity key: iNat observation id (iNat rows) or `gbif:<gbifID>` (GBIF rows). Dedupe key (Decision 20) | derived | No |
| `observed_on` | character | — | Observation date (`YYYY-MM-DD`); iNat `observed_on` / GBIF `eventDate`. **No date filter applied** (Decision 21) | inat/gbif | Yes |
| `latitude` | numeric | ° | Original **EPSG:4326** latitude (provenance; geometry is 3310) | inat/gbif | No |
| `longitude` | numeric | ° | Original **EPSG:4326** longitude (provenance; geometry is 3310) | inat/gbif | No |
| `coord_uncert_m` | numeric | m | Coordinate uncertainty: iNat `public_positional_accuracy` (→ `positional_accuracy` fallback) / GBIF `coordinateUncertaintyInMeters`. **Preserved, not filtered** — per-analysis cutoff (Decision 20 amended) | inat/gbif | Yes |
| `obscured` | logical | — | `TRUE` if iNat obscured the coordinate (observer-set `geoprivacy`; puma is NOT taxon-obscured in CA, Decision 10). GBIF rows = `FALSE` | inat/gbif | No |
| `geoprivacy` | character | — | iNat user-set geoprivacy (`obscured`/`open`/NA); `""` normalised to NA. NA for GBIF rows | inat | Yes |
| `taxon_geoprivacy` | character | — | iNat taxon-policy geoprivacy; **all NA/"open" for puma** (Decision 10 evidence). NA for GBIF rows | inat | Yes |

**Notes:**
- **Dedupe is by `obs_id`, never coordinates** (Decision 20): obscured puma coords
  are randomised and differ between GBIF and iNat, so a coordinate dedupe would
  mismatch pairs. All 6,781 iNat-sourced GBIF rows matched an iNat id; only the
  non-iNat GBIF remainder (14 puma post-clip) is additive.
- **Precise vs obscured is a flag, not a split** (Decision 21). Filter on
  `obscured == FALSE` for the ~1,028 precise points; the obscured half stays for
  coarse-distribution and observer-bias (proposal Q5) use.
- **Geometry is 3310; `latitude`/`longitude` are 4326.** Use geometry for all
  spatial ops; the lat/long columns are provenance only.
- Study-area clip (to `boundary_baydissolved_3310.gpkg`) dropped bbox-corner
  points; 0 coordinate-validity drops.

---

### `occ_bobc_clean_3310.gpkg`  — bobcat occurrence layer (cleaned, deduped)

**Source:** iNaturalist research-grade (`rinat`) ∪ GBIF non-iNat remainder
**Geometry:** point (POINT), one row per unique observation
**CRS:** EPSG:3310 (geometry). `latitude`/`longitude` columns are original EPSG:4326.
**Records:** 6,232 (4,420 precise + 1,812 obscured); iNat 6,027 + GBIF-non-iNat 205
**Created by:** `scripts/03_prepare_occurrences.R`
**Storage:** `data/interim/`. Tier **T0/T1** — bobcat is low-sensitivity; may be
published at finer resolution than puma, still reviewed per policy §3.
**Decisions:** 20 (identity dedupe, no coord cutoff), 21 (obscured kept under flag)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `species` | character | — | Constant `bobc` | derived | No |
| `source` | character | — | `inat` or `gbif` — feed of origin | derived | No |
| `obs_id` | character | — | Stable identity key: iNat observation id or `gbif:<gbifID>`. Dedupe key (Decision 20) | derived | No |
| `observed_on` | character | — | Observation date (`YYYY-MM-DD`). No date filter applied | inat/gbif | Yes |
| `latitude` | numeric | ° | Original **EPSG:4326** latitude (provenance) | inat/gbif | No |
| `longitude` | numeric | ° | Original **EPSG:4326** longitude (provenance) | inat/gbif | No |
| `coord_uncert_m` | numeric | m | Coordinate uncertainty (iNat `public_positional_accuracy`/`positional_accuracy`; GBIF `coordinateUncertaintyInMeters`). Preserved, not filtered | inat/gbif | Yes |
| `obscured` | logical | — | `TRUE` if iNat obscured (observer-set). GBIF rows = `FALSE`. One anomalous taxon-obscured bobcat kept as obscured, not special-cased | inat/gbif | No |
| `geoprivacy` | character | — | iNat user-set geoprivacy; `""` → NA; NA for GBIF | inat | Yes |
| `taxon_geoprivacy` | character | — | iNat taxon-policy geoprivacy (1 bobcat = "obscured", rest NA/"open"); NA for GBIF | inat | Yes |

**Notes:**
- Same identity-dedupe and flag-not-cut logic as the puma layer. Additive GBIF
  remainder = 205 bobcat post-clip.
- **This is the layer the Risk 1 occupancy gate is assessed against.** Preview:
  6,232 records land on 3,640 distinct 500 m grid cells; 322 of 1,129 CPAD units
  hold ≥1 record, but only 48% of records (2,961) fall inside any CPAD unit — the
  site-definition choice is the first gate decision (repeat-visit structure, not
  raw site count, is the binding criterion).
- Geometry is 3310; `latitude`/`longitude` are 4326 (provenance only).

---

### `grid_puma_1km_3310.tif`  — puma analysis grid

**Source:** derived from `boundary_baydissolved_3310.gpkg`
**Geometry:** raster, 1,000 m cell
**CRS:** EPSG:3310
**Records:** 45,400 cells total; 20,416 land (non-NA)
**Created by:** `scripts/02e_build_grids.R`
**Storage:** `data/interim/` (T0 open)

| Field (band) | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `cell_id` | integer (INT4S) | — | Sequential cell index over the snapped extent; stable join key for prediction surfaces / detection histories | derived | Yes (NA outside boundary) |

**Grid geometry:**
- Resolution 1,000 × 1,000 m; extent x[−307000, −107000] y[−129000, 98000]
- Origin (−307000, −129000), snapped to round 1 km 3310 coordinates
- 227 rows × 200 cols; cells outside the dissolved boundary set NA (land-only data)

**Notes:**
- 1 km cell **is** the puma publish floor (`sensitive-data-policy.md` §3);
  puma surfaces at this native resolution satisfy the ≥1 km coarsening rule.
- Shares its origin with the bobcat grid; 500 m grid nests exactly (4:1).
- Never pooled with bobcat (Decision 3).

---

### `grid_bobc_500m_3310.tif`  — bobcat analysis grid

**Source:** derived from `boundary_baydissolved_3310.gpkg`
**Geometry:** raster, 500 m cell
**CRS:** EPSG:3310
**Records:** 181,600 cells total; 80,073 land (non-NA)
**Created by:** `scripts/02e_build_grids.R`
**Storage:** `data/interim/` (T0 open)

| Field (band) | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `cell_id` | integer (INT4S) | — | Sequential cell index over the snapped extent; stable join key | derived | Yes (NA outside boundary) |

**Grid geometry:**
- Resolution 500 × 500 m; extent x[−307000, −107000] y[−129000, 98000]
- Origin (−307000, −129000) — identical to the puma grid
- 454 rows × 400 cols; cells outside the dissolved boundary set NA

**Notes:**
- Nests exactly inside the puma 1 km grid (same origin, 2× resolution → 4 bobcat
  cells per puma cell; verified in 02e).
- Bobcat may be published at finer resolution than puma (policy §3), still
  reviewed before publication.
- Never pooled with puma (Decision 3).

---

### `cov_effort_gbif_mammal_unityear_3310.gpkg`  — bobcat detection-history effort (Fork 3A)

**Source:** GBIF all-datasets download (DOI 10.15468/dl.6xzcjt), class Mammalia,
bobcat excluded
**Geometry:** polygon (MULTIPOLYGON) — CPAD unit geometry, one row per surveyed
unit × year
**CRS:** EPSG:3310
**Records:** 5,401 unit × year features (841 distinct units, 2010–2026)
**Created by:** `scripts/03b_bobcat_background_effort.R`
**Storage:** `data/interim/` (T0 open)
**Decision:** 22 (draft — occupancy detection history; target-group background)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `unit_id` | integer | — | CPAD unit key (join to occupancy frame) | cpad | No |
| `yr` | integer | year | Calendar year of background effort (2010–2026) | derived | No |
| `surveyed` | integer | — | Constant `1` — presence of ≥1 non-bobcat mammal record in this unit × year (effort marker). **Absence of a row = not surveyed = NA, never a 0** | derived | No |

**Notes:**
- **This is the non-detection basis for bobcat occupancy** (Decision 22 draft).
  A unit × year present here but with no bobcat detection = a real non-detection
  (0); a unit × year absent here = unsurveyed = NA (not a 0). The detection
  history is assembled by crossing this against `occ_bobc_clean_3310.gpkg`.
- **Target-group background:** other mammals share more of a bobcat's
  detectability than birds do. Preview: 4,476 real non-detections, naive
  detection rate 0.171, 697 units with ≥2 surveyed years.
- Effort geometry is the CPAD unit polygon (via `unit_id` join), not the raw
  GBIF points — the point cloud is not retained.
- **Fork 3A.** Held alongside 3B (vertebrate) pending the Week-7 fit; the fitted
  detection probability under each decides which background the model uses.

---

### `cov_effort_gbif_vertebrate_unityear_3310.gpkg`  — bobcat detection-history effort (Fork 3B)

**Source:** GBIF all-datasets download (DOI 10.15468/dl.6xzcjt), classes Mammalia
/ Aves / Reptilia / Amphibia / Actinopterygii, bobcat excluded
**Geometry:** polygon (MULTIPOLYGON) — CPAD unit geometry, one row per surveyed
unit × year
**CRS:** EPSG:3310
**Records:** 12,505 unit × year features (1,072 distinct units, 2010–2026)
**Created by:** `scripts/03b_bobcat_background_effort.R`
**Storage:** `data/interim/` (T0 open)
**Decision:** 22 (draft)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `unit_id` | integer | — | CPAD unit key | cpad | No |
| `yr` | integer | year | Calendar year of background effort (2010–2026) | derived | No |
| `surveyed` | integer | — | Constant `1` — presence of ≥1 non-bobcat **vertebrate** record in this unit × year. Absence of a row = not surveyed = NA, never a 0 | derived | No |

**Notes:**
- Same structure and role as the mammal layer (3A), broader taxon net.
- **Weaker per-cell evidence:** 32.7M of 33.0M pulled records are birds. Bird
  effort marks nearly every unit as "surveyed" nearly every year (1,022 units
  with ≥2 years) but shares little of a bobcat's detectability, deflating the
  naive detection rate to 0.083. More 0s, each individually weaker.
- **Fork 3B.** Retained for the Week-7 fit comparison; not yet selected.

### `cov_unit_footprint_3310.gpkg`  — per-unit human-footprint covariates (occupancy)

**Source:** gHM (Theobald 2024) + SILVIS housing density (HUDEN2020), summarised to CPAD units
**Geometry:** polygon (MULTIPOLYGON), one row per open-space unit (mirrors the site layer)
**CRS:** EPSG:3310
**Records:** 1,129 units
**Created by:** `scripts/04_prepare_covariates.R`
**Storage:** `data/interim/` (T0 open)
**Decisions:** 15 (gHM source), 16 (SILVIS PLA), 17 (unit as site / spans_gradient), 23 (transform + keep-both for bobcat)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `unit_id` | integer | — | CPAD `UNIT_ID`; join key to `openspace_cpad_bayarea_3310.gpkg` | cpad | No |
| `spans_gradient` | logical | — | Carried from site layer; `TRUE` = large unit summarised by sub-cell (Decision 17) | derived | No |
| `ghm_mean` | numeric | 0–1 | Area-weighted mean gHM over the unit (native 300 m source) | derived (gHM) | No |
| `ghm_sd` | numeric | 0–1 | Within-unit SD of gHM; gradient check for `spans_gradient` units | derived (gHM) | No |
| `housing_logden_mean` | numeric | log1p(units/km²) | Area-weighted mean of block `log1p(capped HUDEN2020)` over the unit | derived (silvis) | No (0 NAs observed) |
| `housing_logden_sd` | numeric | log1p(units/km²) | Within-unit SD of housing log-density | derived (silvis) | No |

**Notes:**
- **PLA caveat (load-bearing, Decision 16):** housing density is public-land-adjusted,
  so `housing_logden_mean` inside a unit reflects **edge/matrix pressure around** the
  unit, near-zero **within** it by construction — not housing inside open space.
  State this wherever the bobcat housing coefficient is interpreted.
- gHM and housing are both kept for the **bobcat occupancy** model: at unit grain
  they are effectively uncorrelated (r=0.07), but that is a PLA artifact, not true
  independence (Decision 23). Not collinear in the fitted model matrix.
- Housing summarised from the block layer directly (area-weighted intersection),
  gHM from its native 300 m raster — each at its own grain, not off a coarsened grid.
- 0 units had no overlapping SILVIS block (no housing NAs). A no-overlap unit would
  carry housing = NA (true missing), never a filled 0.

---

### `cov_ghm_puma_1km_3310.tif`  — gHM on the puma grid

**Source:** Global Human Modification v3 2022 (Theobald et al. 2024), resampled
**Geometry:** raster, 1,000 m cell (puma grid)
**CRS:** EPSG:3310
**Records:** 19,260 land cells (non-NA)
**Created by:** `scripts/04_prepare_covariates.R`
**Storage:** `data/interim/` (T0 open)
**Decisions:** 15 (gHM source), 23 (kept for puma resistance)

| Field (band) | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `ghm` | numeric (FLT4S) | 0–1 | Human modification, bilinear-resampled from 300 m source to the 1 km grid | ghm | Yes (NA outside boundary) |

**Notes:**
- Continuous metric → **bilinear** resample (contrast `near` for categorical, Decision 15).
- **This is the human-footprint carrier the puma resistance surface uses.** Housing
  was dropped from the puma stack (r=0.78 at 1 km, Decision 23).

---

### `cov_ghm_bobc_500m_3310.tif`  — gHM on the bobcat grid

**Source:** Global Human Modification v3 2022 (Theobald et al. 2024), resampled
**Geometry:** raster, 500 m cell (bobcat grid)
**CRS:** EPSG:3310
**Records:** 76,437 land cells (non-NA)
**Created by:** `scripts/04_prepare_covariates.R`
**Storage:** `data/interim/` (T0 open)
**Decisions:** 15 (gHM source), 23

| Field (band) | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `ghm` | numeric (FLT4S) | 0–1 | Human modification, bilinear-resampled from 300 m source to the 500 m grid | ghm | Yes (NA outside boundary) |

**Notes:**
- Bobcat occupancy uses the **unit-grain** summary (`cov_unit_footprint`) as the
  model covariate; this grid raster is the 500 m gridded form for stacking / display,
  not itself the occupancy design matrix.
- Never pooled with the puma grid (Decision 3).

---

### `cov_housing_logden_puma_1km_3310.tif`  — housing log-density on the puma grid

**Source:** SILVIS block-level HUDEN2020 (PLA v4), transformed + rasterized
**Geometry:** raster, 1,000 m cell (puma grid)
**CRS:** EPSG:3310
**Records:** puma land cells (non-NA)
**Created by:** `scripts/04_prepare_covariates.R`
**Storage:** `data/interim/` (T0 open)
**Decisions:** 16 (SILVIS PLA), 23 (transform; **dropped** from puma resistance)

| Field (band) | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `housing_logden` | numeric (FLT4S) | log1p(units/km²) | `log1p(pmin(HUDEN2020, p99=10,415))`; fine-burn (block→~50 m)→aggregate mean to 1 km | silvis | Yes (NA outside boundary) |

**Notes:**
- **Retained on disk but NOT carried into the puma resistance stack** (Decision 23):
  r=0.78 with gHM at 1 km; SILVIS PLA makes it unsuitable as a resistance input
  (near-zero inside the protected patches that are corridor endpoints).
- Transform pre-registered (§4.9): cap at study-area p99 = 10,415 units/km²
  (913 blocks, 1.00%, capped), then log1p. PLA public-land zeros left as-is.

---

### `cov_housing_logden_bobc_500m_3310.tif`  — housing log-density on the bobcat grid

**Source:** SILVIS block-level HUDEN2020 (PLA v4), transformed + rasterized
**Geometry:** raster, 500 m cell (bobcat grid)
**CRS:** EPSG:3310
**Records:** bobcat land cells (non-NA)
**Created by:** `scripts/04_prepare_covariates.R`
**Storage:** `data/interim/` (T0 open)
**Decisions:** 16 (SILVIS PLA), 23 (transform; kept for bobcat via unit-grain summary)

| Field (band) | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `housing_logden` | numeric (FLT4S) | log1p(units/km²) | `log1p(pmin(HUDEN2020, p99=10,415))`; fine-burn (block→~50 m)→aggregate mean to 500 m | silvis | Yes (NA outside boundary) |

**Notes:**
- Bobcat occupancy uses the **unit-grain** housing summary (`cov_unit_footprint`)
  as the model covariate (kept alongside gHM, Decision 23). This 500 m raster is
  the gridded form for stacking / display.
- Same pre-registered transform as the puma raster (p99 = 10,415, log1p).
- **PLA caveat applies** (Decision 16) — see `cov_unit_footprint_3310.gpkg` notes.

### `stack_occu_units_3310.gpkg`  — occupancy covariate stack (bobcat track)

**Source:** all covariates summarised to CPAD units (script 04a)
**Geometry:** polygon (MULTIPOLYGON), one row per unit
**CRS:** EPSG:3310
**Records:** 1,129 units
**Created by:** `scripts/04a_summarise_covariates.R`
**Storage:** `data/interim/` (T0 open)
**Decisions:** 3 (never pooled), 12 (WorldCover + chaparral caveat), 13 (terrain), 15/16 (footprint), 17 (spans_gradient), 23 (keep both footprint layers)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `unit_id` | integer | — | Site key; join to `openspace_cpad_bayarea_3310.gpkg` | cpad | No |
| `spans_gradient` | logical | — | `TRUE` = large unit (Decision 17); its whole-unit means HIDE within-unit heterogeneity — treat with the SD columns, do not drop | derived | No |
| `elev_mean` | numeric | m | Area-weighted mean elevation | derived (terrain) | No |
| `elev_sd` | numeric | m | Within-unit SD of elevation | derived (terrain) | No |
| `slope_mean` | numeric | degrees | Area-weighted mean slope | derived (terrain) | No |
| `slope_sd` | numeric | degrees | Within-unit SD of slope | derived (terrain) | No |
| `aspect_north` | numeric | −1..1 | Mean northness = mean(cos(aspect)); circular-safe, NOT mean-degrees | derived (terrain) | No |
| `aspect_east` | numeric | −1..1 | Mean eastness = mean(sin(aspect)) | derived (terrain) | No |
| `lc_frac_*` (×8) | numeric | 0–1 | Coverage-weighted fraction of each WorldCover class; the 8 sum ~1 | derived (worldcover) | No |
| `ghm_mean` | numeric | 0–1 | From script 04 (joined, not recomputed) | derived (ghm) | No |
| `ghm_sd` | numeric | 0–1 | From script 04 | derived (ghm) | No |
| `housing_logden_mean` | numeric | log1p(units/km²) | From script 04; **PLA — edge/matrix pressure, not housing inside the unit** (Decision 16) | derived (silvis) | No |
| `housing_logden_sd` | numeric | log1p(units/km²) | From script 04 | derived (silvis) | No |

**Notes:**
- **Chaparral caveat (Decision 12):** WorldCover under-maps CA shrub ~26×;
  `lc_frac_shrub` is systematically low and chaparral is folded into `lc_frac_tree`
  / `lc_frac_grass`. If bobcat occupancy leans on shrub, supplement with CAL FIRE FVEG.
- Both footprint layers retained (bobcat, Decision 23): gHM + housing are
  effectively uncorrelated at unit grain (r=0.07 PLA artifact, not independence).
- Aspect decomposed to north/east because a mean of compass degrees is invalid.

---

### `stack_puma_grid_1km_3310.gpkg`  — puma covariate stack (1 km grid)

**Source:** all covariates summarised to the puma 1 km grid (script 04a)
**Geometry:** point (cell centroids), one row per land cell
**CRS:** EPSG:3310
**Records:** puma land cells (non-NA; see grid_puma)
**Created by:** `scripts/04a_summarise_covariates.R`
**Storage:** `data/interim/` (T0 open)
**Decisions:** 3, 12, 13, 15, 23 (**housing dropped** from puma stack)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `cell_id` | integer | — | Grid cell key; join to `grid_puma_1km_3310.tif` | derived | No |
| `elev_mean` | numeric | m | Bilinear-resampled elevation | derived (terrain) | No |
| `slope_mean` | numeric | degrees | Bilinear-resampled slope | derived (terrain) | No |
| `aspect_north` | numeric | −1..1 | cos(aspect), bilinear | derived (terrain) | No |
| `aspect_east` | numeric | −1..1 | sin(aspect), bilinear | derived (terrain) | No |
| `lc_frac_*` (×8) | numeric | 0–1 | Coverage-weighted class fraction per cell | derived (worldcover) | No |
| `ghm` | numeric | 0–1 | gHM on the 1 km grid (script 04) | derived (ghm) | No |

**Notes:**
- **No `housing_logden` column** — housing dropped from the puma stack (r=0.78
  at 1 km, Decision 23; PLA makes it unsuitable as a resistance input). The
  raster `cov_housing_logden_puma_1km_3310.tif` stays on disk but is not stacked here.
- Grid cells are the puma publish floor (1 km, sensitive-data-policy §3).
- Companion fraction rasters: `cov_lcfrac_puma_grid_1km_3310.tif` (8 bands).

---

### `stack_bobc_grid_500m_3310.gpkg`  — bobcat covariate stack (500 m grid)

**Source:** all covariates summarised to the bobcat 500 m grid (script 04a)
**Geometry:** point (cell centroids), one row per land cell
**CRS:** EPSG:3310
**Records:** bobcat land cells (non-NA; see grid_bobc)
**Created by:** `scripts/04a_summarise_covariates.R`
**Storage:** `data/interim/` (T0 open)
**Decisions:** 3, 12, 13, 15, 16, 23 (housing kept)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `cell_id` | integer | — | Grid cell key; join to `grid_bobc_500m_3310.tif` | derived | No |
| `elev_mean` | numeric | m | Bilinear-resampled elevation | derived (terrain) | No |
| `slope_mean` | numeric | degrees | Bilinear-resampled slope | derived (terrain) | No |
| `aspect_north` | numeric | −1..1 | cos(aspect), bilinear | derived (terrain) | No |
| `aspect_east` | numeric | −1..1 | sin(aspect), bilinear | derived (terrain) | No |
| `lc_frac_*` (×8) | numeric | 0–1 | Coverage-weighted class fraction per cell | derived (worldcover) | No |
| `ghm` | numeric | 0–1 | gHM on the 500 m grid (script 04) | derived (ghm) | No |
| `housing_logden` | numeric | log1p(units/km²) | Housing log-density on the 500 m grid (script 04) | derived (silvis) | No |

**Notes:**
- Housing kept for the bobcat grid stack (Decision 23). PLA caveat applies (Decision 16).
- Companion fraction rasters: `cov_lcfrac_bobc_grid_500m_3310.tif` (8 bands).
- Bobcat may publish finer than puma (policy §3), still reviewed before publication.

---

### `cov_roads_classed_3310.gpkg`  — all roads, classified + per-species permeability

**Source:** OSM roads (Geofabrik NorCal) reclassified (script 04b)
**Geometry:** line (LINESTRING), one row per OSM segment
**CRS:** EPSG:3310
**Records:** 936,784 segments
**Created by:** `scripts/04b_roads_traffic.R`
**Storage:** `data/interim/` (T0 open)
**Decisions:** 3 (never pooled), 14 (roads source), 24 (permeability)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `osm_id` | character | — | OSM feature id | osm | No |
| `fclass` | character | — | OSM road class (motorway…path) | osm | No |
| `name` | character | — | Road/route name; blank on many segments | osm | Yes |
| `road_class` | character | — | Grouped class: highway / arterial / local / permeable / other | derived | No |
| `barrier_puma` | logical | — | `TRUE` for highway+arterial (puma traffic barrier, Decision 24) | derived | No |
| `barrier_bobc` | logical | — | `TRUE` for highway only (bobcat; arterials semi-permeable, Decision 24) | derived | No |

**Notes:**
- Tracks/paths (`permeable`, 45,482 km / 341,737 features) are barriers for
  neither species (Decision 24). `permeable` is broader than D14's track+path-only
  ~18,800 km — it also covers footway/cycleway/steps/bridleway; supersedes the D14
  count, not an error.
- `road_class` breakdown: local 74,605 km, permeable 45,482 km, arterial 7,366 km,
  highway 4,526 km, other 1,543 km.

---

### `cov_roads_traffic_3310.gpkg`  — major roads + AADT (traffic-weighted barrier)

**Source:** major-road subset + Caltrans AADT join (script 04b)
**Geometry:** line (LINESTRING), one row per major OSM segment
**CRS:** EPSG:3310
**Records:** 79,804 major segments
**Created by:** `scripts/04b_roads_traffic.R`
**Storage:** `data/interim/` (T0 open)
**Decisions:** 14 (traffic source), 24 (barrier flags), 25 (AADT join + floor + bias)

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `osm_id` | character | — | OSM feature id | osm | No |
| `fclass` | character | — | OSM road class | osm | No |
| `name` | character | — | Road/route name | osm | Yes |
| `road_class` | character | — | highway / arterial (major subset) | derived | No |
| `aadt` | numeric | vehicles/day | Working AADT used downstream (measured or filled or floored) | derived | No |
| `aadt_source` | character | — | Provenance: `measured` / `name_fill` / `spatial_fill` / `modelled` | derived | No |
| `aadt_measured` | numeric | vehicles/day | Station-median where a station snapped to this segment; else NA | caltrans | Yes |
| `aadt_floor` | numeric | vehicles/day | fclass-derived floor (modelled placeholder, Decision 25) | derived | No |
| `n_stations` | integer | — | Count of AADT stations snapped to this segment | derived | Yes |
| `spatial_donor_dist_m` | numeric | m | Distance to the measured donor segment (spatial_fill rows only) | derived | Yes |
| `barrier_puma` | logical | — | highway+arterial (Decision 24) | derived | No |
| `barrier_bobc` | logical | — | highway only (Decision 24) | derived | No |

**Notes:**
- **`aadt_source` is load-bearing (Decision 25).** Coverage: measured 1,856 (2.3%),
  name_fill 22,505, spatial_fill 19,851 → 55.4% station-traceable; modelled floor
  35,592 (44.6%).
- **Known data property — interpolated AADT skews HIGH.** name_fill/spatial_fill
  medians exceed measured (arterial spatial_fill ~41k vs measured 27k) because
  Caltrans stations sample busy locations; the measured network is a volume-biased
  sample. Not a join bug, not correctable by interpolation. The resistance step
  keys on `aadt_source` to treat tiers at different confidence (AADT→resistance
  treatment deferred to the puma resistance pre-registration).
- Parse: `AHEAD_AADT`/`BACK_AADT` strings → numeric, per-station volume = max leg.
- Diagnostics: `tbl_06_aadt_join.csv`, `tbl_06_aadt_bias_by_class.csv`,
  `tbl_06_road_class_summary.csv`.

### `resist_puma_baseline_3310.tif`  — puma movement resistance surface

**Source:** stacked puma covariates + road/traffic barrier, assigned per Decision 26
**Geometry:** raster, 1,000 m cell (puma grid)
**CRS:** EPSG:3310
**Records:** 20,410 land cells (non-NA)
**Created by:** `scripts/04c_puma_resistance.R`
**Storage:** `outputs/rasters/` (T0 open — publishable at 1 km, sensitive-data-policy §3)
**Decisions:** 3 (never pooled), 12 (WorldCover shrub caveat), 13 (terrain), 15 (gHM), 23 (housing dropped), 24 (barrier_puma), 25 (AADT), 26 (assignment)

| Field (band) | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `resist_puma` | numeric (FLT4S) | 1–100 | Movement resistance; 1 = freely permeable, 100 = impassable. `R = max(R_land, R_road)` on barrier-road cells, else `R_land` | derived | Yes (NA off land grid) |

**Notes:**
- `R_land = 0.45*r_ghm + 0.40*r_lc + 0.15*r_slope`. r_ghm convex (`1+99*gHM^2`);
  r_lc coverage-weighted per-class (tree 5 … built 95); r_slope linear to 45°.
- `R_road` = log-inverse AADT transform, p1/p99 winsorised (4,000/237,000),
  applied only on `barrier_puma` cells (Decision 24/26). Log compresses the
  high-traffic tail and the Decision-25 spatial_fill bias.
- Distribution: min 5.4, median 17.2, mean 29.7, p75 38.7, max 100;
  `pct_barrier ≥80` = 7.4%; ~27% of cells touched by a barrier road.
- Aspect and housing (Decision 23) excluded; conspecific density excluded
  (considered-and-excluded, Decision 26).
- Publishable at 1 km per sensitive-data-policy §3. Weights are author priors;
  covariate structure/effect-directions sourced to Hansen et al. 2025 (these exact
  pumas), Zeller et al. 2016, Wilmers et al. 2013.
- **Baseline only** — three pre-registered sensitivity variants (road-confidence,
  chaparral, ±10% weight) are judged on corridor stability, not yet run.

---

### `resist_puma_aadt_conf_3310.tif`  — AADT-confidence companion band

**Source:** `aadt_source` tier rasterised alongside the resistance surface (script 04c)
**Geometry:** raster, 1,000 m cell (puma grid)
**CRS:** EPSG:3310
**Records:** barrier-road cells (non-NA only where a barrier road crosses)
**Created by:** `scripts/04c_puma_resistance.R`
**Storage:** `outputs/rasters/` (T0 open)
**Decisions:** 25 (aadt_source), 26 (sensitivity check 1)

| Field (band) | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `aadt_conf` | integer (INT1U) | — | 1 = station-traceable road cell (measured/name_fill); 0 = modelled/spatial_fill; NA = no barrier road | derived | Yes |

**Notes:**
- Audit companion, not a resistance input. Drives sensitivity check 1 (Decision 26):
  rebuild with `aadt_conf = 0` cells dropped to `R_land`; stable corridors confirm
  the AADT bias is immaterial.
- Per-cell value is the worst (min) confidence among roads crossing the cell.

---

### `dh_bobc_<background>_<detset>_3310.rds`  — bobcat detection histories (4 files)

**Files:** `dh_bobc_mammal_precise_3310.rds` (PRIMARY),
`dh_bobc_mammal_all_3310.rds`, `dh_bobc_vertebrate_precise_3310.rds`,
`dh_bobc_vertebrate_all_3310.rds`
**Type:** R `.rds` — integer matrix (site × occasion), not a spatial layer
**CRS:** n/a (unit_id keys back to `openspace_cpad_bayarea_3310.gpkg`)
**Dimensions:** 1,129 rows (units) × 17 cols (years 2010–2026); rows with all-NA
dropped at fit time
**Created by:** `scripts/04d_bobcat_detection_history.R`
**Storage:** `data/interim/` (T0 open — presence/absence at unit level, policy §3)
**Decisions:** 17 (unit as site), 20/21 (obscured handling), 22 (encoding + close), 27 (detection implies effort)

| Element | Value | Description |
|---|---|---|
| cell = `1` | detected | Unit-year surveyed AND ≥1 bobcat detection |
| cell = `0` | non-detection | Unit-year surveyed, no bobcat (a REAL 0) |
| cell = `NA` | unsurveyed | Unit-year absent from effort layer — never a fabricated 0 |
| rownames | `unit_id` | Join key to the occupancy frame |
| colnames | `2010`…`2026` | Calendar-year occasions |

**Notes:**
- `background`: `mammal` (Fork 3A, target-group-correct) or `vertebrate` (3B,
  bird-deflated). `detset`: `precise` (obscured dropped) or `all` (obscured
  included by randomised coord, Decision 20/21).
- **Primary = `mammal_precise`** — drives the Decision 22 close.
- Decision 27: detected unit-years the target-group background missed are upgraded
  to surveyed+detected (1); logged in `tbl_08_detections_upgraded_d27.csv`.
- Null-fit results: `tbl_09_null_fit_criteria.csv`, `tbl_09_decision22_close.csv`.

---

### `bobc_occu_null_<history>_<date>.rds`  — fitted null occupancy models

**Files:** `bobc_occu_null_<history>_<YYYYMMDD>.rds` (annual fit) and
`bobc_occu_null_<history>_collapsed_<YYYYMMDD>.rds` (4-period fit, for GOF), per
history
**Type:** R `.rds` — fitted `unmarked::unmarkedFitOccu` object
**Created by:** `scripts/04e_bobcat_null_fit.R`
**Storage:** `outputs/models/` (T0 open — model object, no coordinates)
**Decisions:** 22 (close), 27 (encoding)

| Object | Description |
|---|---|
| `unmarkedFitOccu` | Null occupancy fit (`~1 ~1`); back-transform for ψ, p |

**Notes:**
- Annual fit gives the per-visit `p` read against the §5.4 fallback line (0.10);
  collapsed (4-period) fit gives the tractable MacKenzie-Bailey GOF.
- Primary `bobc_occu_null_mammal_precise_*`: ψ=0.464, p=0.295 (clears 0.10),
  converged; collapsed c-hat=8.9 = expected null-model overdispersion (Decision 22).

---

## Deferred layers (future phase — Decision 7)

> **Not built in Phase 1.** The Felidae Wildpod dataset is deferred to a future
> phase (see `docs/methodology.md` Decision 7); no Felidae data is held in this
> repository. These specs are retained for whoever resumes it and re-enter under
> `docs/sensitive-data-policy.md` §4 (written agreement first).

### `occ_both_felidae_stations_3310.gpkg`  — **T3 RESTRICTED, never committed**

**Source:** Felidae Conservation Fund Wildpod maps
**Geometry:** point
**CRS:** EPSG:3310
**Records:** 218 raw → clipped to study area (final count TBD; drops ≥13)
**Created by:** `scripts/NN_prepare_felidae_stations.R`
**Storage:** `data/restricted/` only. Coordinates are sensitive (see
`docs/sensitive-data-policy.md` §2, tier T2/T3). Do not publish points.

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `station_uid` | integer | — | Stable unique key (from raw `ID`) | felidae | No |
| `felidae_station` | character | — | Wildpod station name (**not** unique) | felidae | No |
| `felidae_park_name` | character | — | Wildpod "Park" label — **untrusted** | felidae | No |
| `felidae_subregion` | character | — | Wildpod region: Peninsula/East Bay/South Bay | felidae | No |
| `elev_felidae_m` | numeric | m | Elevation as supplied by Felidae | felidae | Yes (22 raw) |
| `source` | character | — | Constant `felidae` | derived | No |

**Notes:**
- Raw CSV is Latin-1 encoded; read with `encoding = "latin1"`.
- `Los Angeles` sub-region excluded before this layer is built (Decision 4).
- Geometry holds the precise coordinate; the coordinate is never written to any
  committed or published file.

---

### `stats_felidae_station_unit_3310`  — publishable (unit-level only)

**Source:** derived from the restricted station layer + CPAD/CCED units
**Geometry:** none (table) or polygon (joined to units); no station points
**CRS:** EPSG:3310
**Records:** one row per station (kept restricted) / one row per unit (publishable summary)
**Created by:** `scripts/NN_associate_felidae_stations.R`

| Field | Type | Units | Description | Source | Nulls allowed |
|---|---|---|---|---|---|
| `station_uid` | integer | — | Join key to station layer (restricted rows only) | derived | No |
| `unit_id` | integer | — | CPAD/CCED unit assigned (join key) | derived | Yes (if none) |
| `unit_name_std` | character | — | Standardised open-space unit name | cpad | Yes (if none) |
| `assoc_method` | character | — | `within` / `nearest` / `none` (see §5.7) | derived | No |
| `assoc_dist_m` | numeric | m | Distance to assigned unit (0 if within) | derived | Yes (if none) |
| `n_stations` | integer | — | Stations associated to the unit (summary rows) | derived | No |

**Notes:**
- Only the **unit-level** summary (`unit_id`, `unit_name_std`, `n_stations`)
  may leave `data/restricted/`, and only after `docs/sensitive-data-policy.md`
  §3 review. Watch small-n units — a unit with one station in one sub-region
  can narrow a camera location.
- `assoc_method = "none"` (private/suburban stations) is a valid, reported
  outcome, not a data gap.
