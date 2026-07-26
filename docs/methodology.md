# Methodology

**Project:** Wild Cats at the Urban Edge — Pumas and Bobcats in SF Bay Area Open Spaces
**Author:** Kiran Balasubramanian
**Repository:** https://github.com/K-bsub/bay-area-wildcats
**Last updated:** July 26, 2026

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
*Status: not started*

### 4.2 Occurrence records — GBIF
*Status: not started*

### 4.3 Occurrence records — iNaturalist
*Status: not started*

### 4.4 Road mortality — CROS
*Status: not started*

### 4.5 Covariates — land cover
*Status: not started*

### 4.6 Covariates — terrain (3DEP)
*Status: not started*

### 4.7 Covariates — roads, traffic and housing density
*Status: not started*

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

---

## 5. Analysis methods

> Methods defined here in advance; actual parameter values filled in as each
> analysis is run, matching the tiger project convention.

### 5.1 Open-space unit characterisation
Area, perimeter, shape index, elevation range, land cover composition,
edge-to-urban distance, and road density per unit.

### 5.2 Kernel density estimation
`spatstat.explore::density.ppp()`. Bandwidth selection to be tested and
recorded (candidates: `bw.diggle`, `bw.ppl`, and fixed bandwidths at species-
relevant scales). Shared class breaks across species/periods for comparability.
**Same caveat as tiger Phase 1:** KDE of opportunistic records maps *detection
effort* as much as animal density.

### 5.3 Hot spot analysis (Getis-Ord Gi*)
`sfdep::local_gstar_perm()` on a regular grid of counts. Distance band and
number of permutations to be recorded. FDR correction applied.

### 5.4 Occupancy modelling
`unmarked::occu()`. Requires detection histories — repeated visits to fixed
sites. **Opportunistic GBIF/iNaturalist records do not natively provide this;**
either a spatial-replication design must be constructed and justified, or
Felidae detection histories obtained. This is the single largest methodological
risk in the project — see Decision log.

### 5.5 Connectivity
Resistance surface from land cover, housing density, road class and terrain.
Least-cost paths and corridor swaths between core open-space patches. Circuit-
theory (Omniscape/Circuitscape) as an optional extension.

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

---

## 7. Known limitations

- **No population time series.** There is no repeated regional census
  equivalent to the NTCA rounds used in the tiger project. Narrative is
  distribution and connectivity, not recovery.
- **Detection effort bias.** Opportunistic occurrence records concentrate near
  trailheads, roads and parking areas. Same artefact documented in tiger
  Phase 1; must be stated explicitly wherever KDE or Gi* output is shown.
- **Coordinate obscuring.** iNaturalist obscures puma coordinates. Records are
  usable for coarse distribution only.
- **Occupancy design.** Opportunistic records are not survey data. Any
  occupancy model built on them requires explicit, documented assumptions.
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
