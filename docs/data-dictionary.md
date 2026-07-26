# Data Dictionary

Every field in every layer under `data/processed/`. Completed as layers are
built. Field naming rules in `docs/naming-conventions.md` §5.

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

*(none yet — added here as processed layers are built)*

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
