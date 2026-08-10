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
