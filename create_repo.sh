#!/usr/bin/env bash
# =============================================================================
# create_repo.sh
# Scaffolds the bay-area-wildcats project repository.
#
# Usage:
#   bash create_repo.sh [target_parent_directory]
#
# Creates ./bay-area-wildcats/ with full directory tree, starter documentation,
# R script stubs, and Git/renv configuration.
# Safe to run once into an empty location. Will not overwrite an existing repo.
# =============================================================================

set -euo pipefail

PARENT="${1:-.}"
REPO="$PARENT/bay-area-wildcats"

if [ -d "$REPO" ]; then
  echo "ERROR: $REPO already exists. Aborting so nothing is overwritten."
  exit 1
fi

echo "Creating repository at: $REPO"

# ---------------------------------------------------------------------------
# 1. Directory tree
# ---------------------------------------------------------------------------
mkdir -p "$REPO"/{docs,R,scripts,site,media/photos}
mkdir -p "$REPO"/data/{raw,interim,processed,restricted}
mkdir -p "$REPO"/outputs/{figures,tables,rasters,models}

# Keep empty dirs under version control
for d in data/raw data/interim data/processed data/restricted \
         outputs/figures outputs/tables outputs/rasters outputs/models \
         media/photos; do
  touch "$REPO/$d/.gitkeep"
done

# ---------------------------------------------------------------------------
# 2. .gitignore
# ---------------------------------------------------------------------------
cat > "$REPO/.gitignore" << 'EOF'
# ---- Data (never committed; see data/README.md for acquisition steps) -------
data/raw/*
data/interim/*
data/processed/*
!data/**/.gitkeep
!data/README.md

# ---- Restricted / sensitive data (Felidae, precise puma locations) ---------
# Nothing in this directory may EVER be committed. See docs/sensitive-data-policy.md
data/restricted/**
!data/restricted/.gitkeep

# ---- Large outputs ---------------------------------------------------------
outputs/rasters/*
outputs/models/*
!outputs/**/.gitkeep
*.tif
*.tiff
*.gpkg
*.gdb/
*.rds
*.qs

# Allow small, publication-ready web layers
!site/data/*.geojson
!site/data/*.json

# ---- R ---------------------------------------------------------------------
.Rproj.user/
.Rhistory
.RData
.Ruserdata
renv/library/
renv/local/
renv/cellar/
renv/staging/
renv/python/

# ---- targets ---------------------------------------------------------------
_targets/

# ---- Quarto / site build ---------------------------------------------------
_site/
site/_site/
site/.quarto/
*.html
!site/**/*.html

# ---- OS / editor -----------------------------------------------------------
.DS_Store
Thumbs.db
.vscode/
*.swp
EOF

# ---------------------------------------------------------------------------
# 3. RStudio project + renv bootstrap
# ---------------------------------------------------------------------------
cat > "$REPO/bay-area-wildcats.Rproj" << 'EOF'
Version: 1.0

RestoreWorkspace: No
SaveWorkspace: No
AlwaysSaveHistory: Default

EnableCodeIndexing: Yes
UseSpacesForTab: Yes
NumSpacesForTab: 2
Encoding: UTF-8

RnwWeave: knitr
LaTeX: pdfLaTeX
EOF

cat > "$REPO/.Rprofile" << 'EOF'
# Activate renv if it has been initialised (run renv::init() once, first time).
if (file.exists("renv/activate.R")) source("renv/activate.R")

# Fail loudly on partial matching and stringsAsFactors surprises
options(
  warnPartialMatchArgs = TRUE,
  stringsAsFactors     = FALSE,
  scipen               = 999
)
EOF

# ---------------------------------------------------------------------------
# 4. LICENSE (dual: code MIT, docs CC BY 4.0)
# ---------------------------------------------------------------------------
cat > "$REPO/LICENSE" << 'EOF'
This repository uses a dual licence.

-------------------------------------------------------------------------------
1. CODE (everything in R/, scripts/, site/, and any .R / .qmd / .js / .css file)
-------------------------------------------------------------------------------
MIT License

Copyright (c) 2026 Kiran Balasubramanian

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

-------------------------------------------------------------------------------
2. DOCUMENTATION AND NARRATIVE (everything in docs/ and site/ prose content)
-------------------------------------------------------------------------------
Creative Commons Attribution 4.0 International (CC BY 4.0)
https://creativecommons.org/licenses/by/4.0/

-------------------------------------------------------------------------------
3. THIRD-PARTY DATA
-------------------------------------------------------------------------------
This licence does NOT extend to any third-party dataset. Each source carries
its own terms; several are share-alike or non-commercial. See
docs/data-sources.md for the per-dataset licence table. In particular:

  - OpenStreetMap derivatives are subject to ODbL (share-alike).
  - Any Felidae Conservation Fund data is used under separate written
    agreement and is NOT redistributable under this licence.
EOF

# ---------------------------------------------------------------------------
# 5. CITATION.cff
# ---------------------------------------------------------------------------
cat > "$REPO/CITATION.cff" << 'EOF'
cff-version: 1.2.0
title: >-
  Wild Cats at the Urban Edge: Distribution and Connectivity of Pumas and
  Bobcats in San Francisco Bay Area Open Spaces
message: If you use this work, please cite it as below.
type: dataset
authors:
  - family-names: Balasubramanian
    given-names: Kiran
repository-code: "https://github.com/K-bsub/bay-area-wildcats"
abstract: >-
  An open, reproducible spatial analysis of Puma concolor and Lynx rufus
  occurrence, occupancy and habitat connectivity across protected open space
  in the ten-county San Francisco Bay Area, built entirely in R from
  publicly available data.
keywords:
  - puma
  - bobcat
  - connectivity
  - occupancy modelling
  - San Francisco Bay Area
  - open space
license: MIT
date-released: "2026-07-23"
EOF

# ---------------------------------------------------------------------------
# 6. README.md
# ---------------------------------------------------------------------------
cat > "$REPO/README.md" << 'EOF'
# Wild Cats at the Urban Edge

**Distribution and connectivity of pumas and bobcats in San Francisco Bay Area open spaces**

A reproducible, open-source spatial analysis built entirely in R.
Phase 1 of a multi-phase project. Sister project to
[tiger-conservation-india](https://github.com/K-bsub/tiger-conservation-india).

| | |
|---|---|
| **Author** | Kiran Balasubramanian |
| **Status** | Week 1 — repository setup |
| **Focal species** | *Puma concolor* (puma / mountain lion), *Lynx rufus* (bobcat) |
| **Study area** | Ten-county San Francisco Bay Area |
| **Analysis CRS** | EPSG:3310 — NAD83 / California Albers |
| **Stack** | R (sf, terra, spatstat, sfdep, unmarked), Quarto, Leaflet |
| **Story site** | *(to be published to GitHub Pages)* |

---

## Why this project differs from Phase 1 (tigers)

The tiger project was anchored on five repeated NTCA census rounds, which made
"population recovery over time" the natural narrative. **No comparable time
series exists for Bay Area cats.** There is one recent statewide mountain lion
abundance estimate and no statewide bobcat estimate at all.

What Bay Area cats *do* have is dense, well-maintained data on **habitat
fragmentation, road mortality, and connectivity**. The narrative is therefore
built around **distribution and coexistence at the urban–wildland edge**, not
recovery.

The two species are analysed **in parallel, not merged**, because their data
situations are opposite:

| | Puma | Bobcat |
|---|---|---|
| Occurrence records | Sparse | Abundant |
| Location sensitivity | High (obscured / restricted) | Low |
| Home range | Very large (100s km²) | Small (10s km²) |
| Primary story | Isolation & connectivity | Occupancy & distribution |
| Primary method | Least-cost / circuit connectivity | Occupancy models, KDE, Gi* |

---

## Repository structure

```
bay-area-wildcats/
├── docs/               Project documentation (proposal, methodology, data sources)
├── R/                  Reusable functions and project configuration
├── scripts/            Numbered analysis pipeline (run in order)
├── data/
│   ├── raw/            Downloaded, unmodified source data      [gitignored]
│   ├── interim/        Intermediate processing artefacts       [gitignored]
│   ├── processed/      Analysis-ready layers (.gpkg / .tif)    [gitignored]
│   └── restricted/     Partner / sensitive data                [NEVER committed]
├── outputs/            Figures, tables, rasters, fitted models
├── site/               Quarto story site (published to GitHub Pages)
└── media/photos/       Imagery with attribution records
```

Data is **not** stored in this repository. Every dataset is publicly
downloadable — see `data/README.md` for acquisition steps and
`docs/data-sources.md` for full citations and licences.

---

## Getting started

```r
# 1. Open bay-area-wildcats.Rproj in RStudio

# 2. First time only — initialise the reproducible environment
install.packages("renv")
renv::init()

# 3. Install project dependencies
source("scripts/00_setup_environment.R")

# 4. Acquire data (see data/README.md), then run the pipeline in order
source("scripts/01_download_open_data.R")
source("scripts/02_prepare_boundaries.R")
# ... etc.
```

---

## Documentation

| Document | Purpose |
|---|---|
| `docs/proposal.md` | Scope, questions, expected deliverables |
| `docs/project-plan.md` | Week-by-week task breakdown and status |
| `docs/methodology.md` | Processing log, analytical decisions, limitations |
| `docs/data-sources.md` | Full citations, access steps, licences, known issues |
| `docs/data-dictionary.md` | Every field in every processed layer |
| `docs/naming-conventions.md` | File, layer, object and field naming rules |
| `docs/sensitive-data-policy.md` | **Read before handling any puma location data** |
| `docs/references.md` | Bibliography |

---

## Notes on publishing

Documentation lives in `docs/`, which conflicts with GitHub Pages' "serve from
/docs" option. The story site is therefore built from `site/` and deployed to a
`gh-pages` branch via GitHub Actions. Do not switch Pages to serve from `/docs`.
EOF

# ---------------------------------------------------------------------------
# 7. docs/sensitive-data-policy.md  (do this first — it constrains everything)
# ---------------------------------------------------------------------------
cat > "$REPO/docs/sensitive-data-policy.md" << 'EOF'
# Sensitive Data Policy

**Status:** Active — applies from Week 1 onward
**Applies to:** all contributors, all branches, all published outputs

---

## 1. Why this document exists

Precise location data for pumas is a poaching, harassment and disturbance risk.
This is not a hypothetical concern: it is the reason iNaturalist automatically
obscures coordinates for the species, and the reason research organisations do
not publish raw camera-trap coordinates.

This project is public. Anything committed to this repository or rendered to
the story site is permanently public. Treat every commit as irreversible.

---

## 2. Data sensitivity tiers

| Tier | Definition | Examples | Handling |
|---|---|---|---|
| **T0 — Open** | Public, no location risk | CPAD boundaries, roads, land cover, DEM | Normal use |
| **T1 — Open, coarse** | Public but already obscured at source | iNaturalist puma records (obscured), GBIF records with high `coordinateUncertaintyInMeters` | Normal use; document the obscuring |
| **T2 — Sensitive** | Precise locations of a sensitive species | Any unobscured puma detection, den or kill-site location | Never published at native precision |
| **T3 — Restricted** | Partner data under agreement | Felidae camera locations, detection histories, unpublished model outputs | `data/restricted/` only; never committed; use per written agreement |

---

## 3. Hard rules

- [ ] **T2 and T3 data never enters version control.** `data/restricted/**` is
      gitignored. Do not move restricted files elsewhere in the tree.
- [ ] **Published puma outputs must be generalised.** Acceptable published forms:
      - Continuous surfaces (occupancy probability, KDE, resistance) at
        **≥1 km** cell size
      - Counts or summaries aggregated to open-space unit or grid cell
      - Presence/absence at the open-space unit level
      Not acceptable: point maps of detections, camera locations, or any raster
      fine enough to reverse-engineer a camera position.
- [ ] **Bobcat data may be published at finer resolution** but is reviewed under
      the same process before publication.
- [ ] **No camera coordinates in any figure, table, caption, popup, or
      commit message** — including in `outputs/` files that get presented.
- [ ] **Check before every commit** that no restricted file has been staged:
      `git status --short` and confirm nothing under `data/restricted/`.

---

## 4. If partner data is used

Before any Felidae Conservation Fund data enters this project, a written
agreement must exist covering, at minimum:

- [ ] Which data products are shared (raw detections vs. derived surfaces)
- [ ] Required location generalisation for any published output
- [ ] Attribution and any co-authorship expectations
- [ ] Publication embargo terms (unpublished data may be under journal embargo)
- [ ] Whether the agreement permits public web display at all
- [ ] Named point of contact for pre-publication review

**Preferred ask:** derived products, not raw points — occupancy probability
rasters, detection summaries by open-space unit, or published model outputs.
These support the narrative without ever exposing a camera location.

Record the agreement date and terms summary in `docs/methodology.md` as a
numbered decision.

---

## 5. Accidental disclosure

If sensitive data is committed:

1. Do not simply delete it in a new commit — the history retains it.
2. Rewrite history (`git filter-repo`) or, if the repository is small and
   young, delete and recreate the repository.
3. Force-push, then confirm the data is gone from all branches and any fork.
4. Notify the data provider immediately if T3 data was involved.
5. Log the incident and the remediation in `docs/methodology.md`.
EOF

# ---------------------------------------------------------------------------
# 8. docs/naming-conventions.md
# ---------------------------------------------------------------------------
cat > "$REPO/docs/naming-conventions.md" << 'EOF'
# Naming Conventions

R-based project. Conventions differ from the ArcGIS/geodatabase conventions used
in the tiger project — no PascalCase feature classes, no `.gdb`.

---

## 1. Species codes

Used as a token in every species-specific file, object and field name.

| Code | Species | Common name |
|---|---|---|
| `puma` | *Puma concolor* | Puma / mountain lion |
| `bobc` | *Lynx rufus* | Bobcat |
| `both` | — | Combined or comparative output |

Do not use `PUCO` / `LYRU` alpha codes — `puma` and `bobc` are more legible in
filenames and column headers.

---

## 2. Files and directories

- **snake_case throughout.** No spaces, no capitals, no hyphens in data files.
- Hyphens are permitted **only** in documentation filenames (`data-sources.md`),
  matching the tiger project convention.
- Pattern for data layers:

```
<theme>_<subject>_<qualifier>_<crs>.<ext>
```

Examples:

```
openspace_cpad_bayarea_3310.gpkg
occ_puma_gbif_clean_3310.gpkg
occ_bobc_inat_research_3310.gpkg
cov_landcover_nlcd2021_3310.tif
cov_roads_osm_major_3310.gpkg
kde_bobc_current_1km_3310.tif
resist_puma_baseline_3310.tif
lcp_puma_diablo_to_hamilton_3310.gpkg
```

**Theme prefixes:**

| Prefix | Contents |
|---|---|
| `openspace_` | Protected area / open space boundaries |
| `occ_` | Occurrence and detection records |
| `cov_` | Environmental and anthropogenic covariates |
| `kde_` | Kernel density surfaces |
| `hot_` | Hot spot (Gi*) results |
| `occu_` | Occupancy model inputs and prediction surfaces |
| `resist_` | Resistance surfaces |
| `lcp_` | Least-cost paths and corridors |
| `mort_` | Road mortality / roadkill |
| `stats_` | Tabular summaries |

**Always end data filenames with the EPSG code.** This is the single most
useful habit for avoiding silent CRS mistakes, and it replaces the ArcGIS
practice of `_UTM43N` suffixes.

---

## 3. Scripts

```
NN_verb_object.R
```

Two-digit prefix sets execution order. Examples:

```
00_setup_environment.R
01_download_open_data.R
02_prepare_boundaries.R
05_kde_and_hotspots.R
```

Function files in `R/` use the `00_functions_<domain>.R` pattern and are sourced,
never run standalone.

---

## 4. R objects

- **snake_case** for all objects and functions.
- Suffix spatial objects by type so their class is obvious at a glance:

| Suffix | Class |
|---|---|
| `_sf` | `sf` vector object |
| `_r` | `terra::SpatRaster` |
| `_v` | `terra::SpatVector` |
| `_ppp` | `spatstat` point pattern |
| `_nb` | spatial neighbours / weights |
| `_fit` | fitted model object |
| `_df` / `_tbl` | plain data frame / tibble |

Examples: `openspace_sf`, `landcover_r`, `occ_bobc_ppp`, `occu_bobc_fit`

- Functions are verbs: `read_cpad()`, `build_detection_history()`,
  `make_resistance_surface()`.

---

## 5. Fields / columns

- **snake_case**, lowercase.
- Units embedded in the name where relevant: `area_km2`, `dist_road_m`,
  `elev_mean_m`.
- Year suffix for temporal fields: `pop_2022`, `detections_2020`.
- Standard identifiers used across layers:

| Field | Type | Meaning |
|---|---|---|
| `unit_id` | integer | Stable ID for an open-space unit (join key) |
| `unit_name` | character | Open-space unit display name |
| `unit_name_std` | character | Standardised name for joins across sources |
| `county` | character | County name |
| `species` | character | `puma` or `bobc` |
| `source` | character | `gbif`, `inat`, `cros`, `felidae` |
| `obscured` | logical | Whether the source obscured the coordinate |
| `coord_uncert_m` | numeric | Coordinate uncertainty in metres |

---

## 6. Outputs

```
outputs/figures/fig_<nn>_<slug>.png
outputs/tables/tbl_<nn>_<slug>.csv
outputs/models/<species>_<model>_<date>.rds
```

Examples: `fig_03_bobcat_occupancy.png`, `tbl_02_unit_summary.csv`,
`bobc_occu_null_20260801.rds`

---

## 7. Git

- Branches: `main` (stable), `week-NN-<topic>` for working branches.
- Commit messages: imperative present tense, scope prefix.
  - `data: add CPAD 2026a download script`
  - `analysis: fit null occupancy model for bobcat`
  - `docs: record CRS decision`
EOF

# ---------------------------------------------------------------------------
# 9. docs/methodology.md
# ---------------------------------------------------------------------------
cat > "$REPO/docs/methodology.md" << 'EOF'
# Methodology

**Project:** Wild Cats at the Urban Edge — Pumas and Bobcats in SF Bay Area Open Spaces
**Author:** Kiran Balasubramanian
**Repository:** https://github.com/K-bsub/bay-area-wildcats
**Last updated:** July 23, 2026

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
> the connectivity narrative. To be confirmed as Decision 2.

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

Exact versions are pinned in `renv.lock`. Record the R version and key package
versions here once the environment is initialised.

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

### 4.8 Partner data — Felidae
*Status: not started. Subject to `docs/sensitive-data-policy.md` §4.*

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
*Status:* pending — confirm ten-county vs nine-county definition.

**Decision 3: Species handled in parallel, never pooled**
*Date:* July 23, 2026
*Decision:* Puma and bobcat analysed as separate tracks with separate grid
resolutions and separate narrative arcs; no combined "felid" layer.
*Justification:* Detection probability, home range scale, data volume and
location sensitivity differ by roughly an order of magnitude between the two.
Pooling would let abundant bobcat records dominate any shared surface and would
force puma data to a resolution that is either too coarse to be useful or too
fine to be publishable.

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
EOF

# ---------------------------------------------------------------------------
# 10. docs/data-sources.md
# ---------------------------------------------------------------------------
cat > "$REPO/docs/data-sources.md" << 'EOF'
# Data Sources

**Project:** Wild Cats at the Urban Edge
**Last updated:** July 23, 2026

> Skeleton. Each entry is completed at download time with: access date, exact
> version, file path, record count, CRS, licence and known issues — matching the
> tiger project format.

---

## 1. Open space and protected areas

### 1.1 CPAD / BPAD — California Protected Areas Database

Primary boundary layer. The authoritative inventory of parks and open space in
California, maintained by GreenInfo Network and published twice yearly. BPAD is
the Bay Area edition, which also incorporates conservation easements from CCED.

- **Access:** https://www.calands.org/ (also data.ca.gov and data.cnra.ca.gov)
- **Bay Area edition:** https://www.bayarealands.org/maps-data/
- **Version to use:** 2026a (or latest at download)
- **Account required:** No
- **Licence:** Open, attribution required
- **Downloaded:** *(pending)*
- **File:** `data/raw/cpad/`

**Known issues to verify on download:**
- CPAD is an *ownership* inventory, not a habitat or biodiversity inventory —
  inclusion does not imply conservation management.
- Includes urban pocket parks; filtering by size and land cover is required.
- Three geometry levels (Holdings / Units / SuperUnits) — Units or SuperUnits
  are the appropriate analysis level; record which is chosen and why.

### 1.2 CCED — California Conservation Easement Database
Parallel dataset covering easement-protected land, which CPAD excludes.
Relevant because much Bay Area connectivity land is easement-held ranchland.

---

## 2. Occurrence records

### 2.1 GBIF
- **Access:** https://www.gbif.org/ (via `rgbif`)
- **Query:** `Puma concolor` / `Lynx rufus`, country US, state California,
  bounded to study area
- **Licence:** CC0 / CC BY, varies per record
- **Known issues:** aggregates iNaturalist, museum specimens and survey data;
  coordinate uncertainty varies by orders of magnitude; heavy observer bias.

### 2.2 iNaturalist
- **Access:** https://www.inaturalist.org/ (via `rinat` or export)
- **Filters:** research grade, has photo, captive excluded
- **Licence:** CC BY / CC BY-NC, varies per observer
- **Known issues (critical):** coordinates for sensitive species are
  automatically obscured. Puma records are affected. The `obscured` flag must be
  carried through every downstream layer.

---

## 3. Road mortality

### 3.1 CROS — California Roadkill Observation System
UC Davis Road Ecology Center. The largest system of its kind in the US, running
since 2009, with tens of thousands of observations. Explicitly identifies the
Bay Area as one of the state's highest-roadkill regions and I-280 among the
worst highways for wildlife-vehicle collisions.

- **Access:** https://wildlifecrossing.net/california/
- **Annual reports:** https://roadecology.ucdavis.edu/
- **Licence / terms:** confirm data-use terms before publishing derived maps
- **Known issues:** volunteer-reported, so reporting effort is uneven; absence
  of records does not indicate absence of mortality.

---

## 4. Covariates

### 4.1 Land cover
Candidates — choose one and record the decision:
- **NLCD** (US National Land Cover Database, 30 m, US-specific classes)
- **ESA WorldCover** (10 m, global; already used in tiger Phase 2)
- **CAL FIRE FVEG** (California vegetation, finer thematic detail)

### 4.2 Terrain — USGS 3DEP
- **Access:** https://apps.nationalmap.gov/downloader/ (or `elevatr` in R)
- **Resolution:** 10 m standard; 1 m lidar available for parts of the Bay Area
- Upgrade over the 30 m SRTM used in tiger Phase 1, with no canopy-return
  problem for the lidar-derived products.

### 4.3 Roads and traffic
- **OpenStreetMap** via Geofabrik — road network and class
- **Caltrans AADT** — traffic volume, which matters far more than road presence
  for barrier effects
- **Note:** OSM road class field is `fclass` in Geofabrik extracts, not
  `highway` — carried over from tiger project experience.

### 4.4 Housing and human footprint
- **US Census TIGER/Line** — boundaries
- **SILVIS housing density** or Census block housing units — urban-edge gradient
- **Global Human Modification Index** (Kennedy et al. 2019) — already used in
  tiger Phase 2, applicable here

---

## 5. Population context (no time series available)

There is **no** repeated regional census equivalent to the NTCA rounds.
Available context:
- California Mountain Lion Project statewide abundance estimate (CDFW with
  UC Santa Cruz, UC Davis, Audubon Canyon Ranch, Institute for Wildlife
  Studies) — a single point-in-time estimate, roughly 3,200–4,500 statewide.
- CDFW CESA status review — regional estimate for the Central Coast North
  population, which includes the San Francisco, San Mateo and peninsula
  populations.
- No statewide bobcat abundance estimate exists.

Cite these as context only. Do not present them as a trend.

---

## 6. Partner data (restricted)

### 6.1 Felidae Conservation Fund
Long-running Bay Area camera network across the East Bay, North Bay and
Peninsula, plus a public sightings map and published occupancy analyses.

- **Status:** not requested
- **Terms:** requires written agreement — see `docs/sensitive-data-policy.md` §4
- **Preferred products:** derived occupancy surfaces, unit-level detection
  summaries, or published results — **not** raw camera coordinates
- **Storage:** `data/restricted/` only; never committed

---

## 7. Licence summary

| Dataset | Licence | Attribution | Redistribution |
|---|---|---|---|
| CPAD / CCED | Open | Yes | Allowed |
| GBIF | CC0 / CC BY (varies) | Yes | Check per record |
| iNaturalist | CC BY / CC BY-NC (varies) | Yes | Check per record |
| CROS | Confirm terms | Yes | Confirm |
| NLCD / 3DEP / TIGER | Public domain | No | Allowed |
| ESA WorldCover | CC BY 4.0 | Yes | Allowed |
| OpenStreetMap | ODbL | Yes | Share-alike |
| Felidae | Agreement | Yes | **No** |
EOF

# ---------------------------------------------------------------------------
# 11. docs/project-plan.md
# ---------------------------------------------------------------------------
cat > "$REPO/docs/project-plan.md" << 'EOF'
# Project Plan

**Project:** Wild Cats at the Urban Edge
**Author:** Kiran Balasubramanian
**Start date:** July 23, 2026
**Target:** 10 weeks
**Last updated:** July 23, 2026

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
| **1** | Repository and environment setup | Repo scaffold, docs, renv, R toolchain verified | 🟢 In progress |
| **2** | Data acquisition | All open datasets downloaded and documented | ⚪ Not started |
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
- [ ] Install R spatial toolchain and verify GDAL/GEOS/PROJ
- [ ] `renv::init()` and commit `renv.lock`
- [ ] Confirm study area definition (ten-county vs nine-county) — Decision 2
- [ ] Draft `docs/proposal.md` research questions
- [ ] Verify GitHub Pages deployment path (gh-pages branch, not /docs)

---

## Risks

| # | Risk | Level | Mitigation |
|---|---|---|---|
| 1 | **Occupancy modelling not feasible from opportunistic data** — `unmarked` needs detection histories from repeated visits; GBIF/iNat records are not survey data | 🔴 High | Assess in Week 4 before committing. Fallbacks: (a) spatial-replication design with documented assumptions; (b) request Felidae detection histories; (c) drop to species distribution modelling (MaxEnt / `maxnet`) and reframe the narrative |
| 2 | **Puma records too sparse for any surface** — obscured and few | 🟡 Medium | Puma track leans on connectivity modelling and CROS mortality, which do not require dense occurrence data |
| 3 | **CROS data-use terms restrict republication** | 🟡 Medium | Confirm terms in Week 2, before analysis is built on it. Fallback: aggregate to road segment and cite |
| 4 | **R spatial toolchain / learning curve** — new stack after ArcGIS | 🟡 Medium | Week 1 buffer for setup; keep scripts small and numbered; `targets` deferred until pipeline is stable |
| 5 | **CPAD includes non-habitat parcels** | 🟢 Low | Define and document filtering criteria (minimum area, land cover, access class) as a numbered decision |
| 6 | **Sensitive data disclosure** | 🔴 High | `docs/sensitive-data-policy.md` enforced from Week 1; gitignore in place before any data is acquired |

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
EOF

# ---------------------------------------------------------------------------
# 12. docs/proposal.md
# ---------------------------------------------------------------------------
cat > "$REPO/docs/proposal.md" << 'EOF'
# Project Proposal

**Title:** Wild Cats at the Urban Edge: Distribution and Connectivity of Pumas
and Bobcats in San Francisco Bay Area Open Spaces

**Author:** Kiran Balasubramanian
**Date:** July 23, 2026
**Project type:** Reproducible R analysis with a published story site

---

## 1. Introduction and statement of problem

*(Draft — expand in Week 1)*

The San Francisco Bay Area supports two wild felids across a fragmented
patchwork of parks, watershed lands, ranch easements and open space preserves,
immediately adjacent to a region of roughly eight million people. Pumas and
bobcats persist here not in wilderness but at the urban–wildland edge, where
the relevant conservation questions are about **movement, permeability and
coexistence** rather than population recovery.

This differs fundamentally from the framing of the sister tiger project. India
has a repeated national census that supports a recovery narrative. California
does not have an equivalent for either species. The analytical opportunity here
is instead in the region's unusually good open data on land protection, road
mortality and landscape structure.

## 2. Research questions

1. How is protected open space distributed across the Bay Area, and how
   fragmented is it from the perspective of a wide-ranging carnivore?
2. Where are bobcats detected, and what landscape characteristics predict
   occupancy of open-space units?
3. Where are the likely movement corridors for pumas between core habitat
   patches, and where do those corridors intersect major roads?
4. Where does road mortality concentrate for each species, and does it
   coincide with modelled crossing locations?
5. How much of the apparent spatial pattern is animal distribution versus
   observer effort?

Question 5 is treated as a first-class analytical question, not a caveat —
carried forward from the tiger project, where observer bias proved to be one of
the more instructive findings.

## 3. Study area

Ten-county San Francisco Bay Area: Alameda, Contra Costa, Marin, Napa,
San Francisco, San Mateo, Santa Clara, Santa Cruz, Solano, Sonoma.

## 4. Data

Summarised in `docs/data-sources.md`. All primary data is public. Partner data
from Felidae Conservation Fund is a possible enhancement, not a dependency.

## 5. Methods

Summarised in `docs/methodology.md` §5.

## 6. Deliverables

1. Published story site (GitHub Pages)
2. Reproducible R pipeline with pinned dependencies
3. Full documentation set matching sister-project conventions
4. Processed, analysis-ready spatial layers with a data dictionary

## 7. Success criteria

- [ ] Analysis fully reproducible from a clean clone
- [ ] Both species treated with methods appropriate to their data density
- [ ] Every published map states its detection-bias caveat
- [ ] No sensitive location data published at any point
- [ ] All sources cited with licences honoured

## 8. Deviations from proposal

*(To be maintained during execution, as in the tiger project.)*
EOF

# ---------------------------------------------------------------------------
# 13. docs/data-dictionary.md and references.md
# ---------------------------------------------------------------------------
cat > "$REPO/docs/data-dictionary.md" << 'EOF'
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

*(none yet)*
EOF

cat > "$REPO/docs/references.md" << 'EOF'
# References

Bibliography for the project. Data source citations live in
`docs/data-sources.md`; this file covers literature.

---

## Bay Area felid research

*(To be populated. Priority items to locate and read:)*
- Felidae Conservation Fund / Bay Area Puma Project publications, including the
  study of puma, bobcat, coyote and mule deer response to dog-related access
  rules in Bay Area protected areas
- Santa Cruz Mountains puma isolation and genetic connectivity literature
  (UC Santa Cruz)
- Coyote Valley linkage and Bay Area connectivity assessments

## Population and status

- California Mountain Lion Project — statewide abundance estimate (CDFW with
  UC Santa Cruz, UC Davis, Audubon Canyon Ranch, Institute for Wildlife Studies)
- CDFW status review supporting CESA listing of Southern California / Central
  Coast North mountain lion populations

## Road ecology

- UC Davis Road Ecology Center — annual California wildlife-vehicle collision
  hotspot reports
- Comparative analysis of puma road-crossing locations versus roadkill hotspots
  for siting crossings and fencing

## Methods

- Occupancy estimation and modelling — MacKenzie et al.
- `unmarked` and `spOccupancy` package documentation
- Getis-Ord Gi* local statistics
- Least-cost path and circuit-theory connectivity methods

---

*Formatting: author–date. Convert to a `.bib` file if the site moves to
Quarto citation handling.*
EOF

# ---------------------------------------------------------------------------
# 14. data/README.md
# ---------------------------------------------------------------------------
cat > "$REPO/data/README.md" << 'EOF'
# Data

**No data is committed to this repository.** All open datasets are publicly
downloadable; partner data is restricted and non-redistributable.

## Directory roles

| Directory | Contents | Committed |
|---|---|---|
| `raw/` | Downloaded source files, never edited | No |
| `interim/` | Intermediate processing artefacts, safe to delete | No |
| `processed/` | Analysis-ready layers (`.gpkg`, `.tif`) | No |
| `restricted/` | Partner / sensitive data | **Never** |

`restricted/` is fully gitignored. Read `docs/sensitive-data-policy.md` before
placing anything in it.

## Acquisition

Most sources can be fetched with `scripts/01_download_open_data.R`. Sources
requiring manual download or a registration step are listed below with steps.

| Dataset | Method | Script / URL |
|---|---|---|
| CPAD / CCED | Manual download | https://www.calands.org/ |
| GBIF occurrences | Scripted (`rgbif`) | `scripts/01_download_open_data.R` |
| iNaturalist | Scripted (`rinat`) or web export | `scripts/01_download_open_data.R` |
| CROS roadkill | Manual — confirm data-use terms first | https://wildlifecrossing.net/california/ |
| 3DEP elevation | Scripted (`elevatr`) | `scripts/01_download_open_data.R` |
| NLCD land cover | Manual download | https://www.mrlc.gov/ |
| OSM roads | Manual download (Geofabrik) | https://download.geofabrik.de/north-america/us/california.html |
| Census TIGER/Line | Scripted (`tigris`) | `scripts/01_download_open_data.R` |

Record the access date, version and record count for every dataset in
`docs/data-sources.md` at download time.
EOF

# ---------------------------------------------------------------------------
# 15. R/00_config.R
# ---------------------------------------------------------------------------
cat > "$REPO/R/00_config.R" << 'EOF'
# =============================================================================
# 00_config.R
# Project-wide constants. Sourced by every script. No side effects beyond
# defining objects and creating directories.
# =============================================================================

# ---- Coordinate reference systems -------------------------------------------
CRS_ANALYSIS <- 3310    # NAD83 / California Albers - all analysis
CRS_WEB      <- 4326    # WGS84 - export only, never analysis

# ---- Study area --------------------------------------------------------------
STUDY_COUNTIES <- c(
  "Alameda", "Contra Costa", "Marin", "Napa", "San Francisco",
  "San Mateo", "Santa Clara", "Santa Cruz", "Solano", "Sonoma"
)

STUDY_STATE_FIPS <- "06"

# ---- Species -----------------------------------------------------------------
SPECIES <- list(
  puma = list(
    code            = "puma",
    scientific_name = "Puma concolor",
    common_name     = "Puma",
    grid_res_m      = 1000,   # coarse - very large home range, sparse + sensitive data
    sensitive       = TRUE
  ),
  bobc = list(
    code            = "bobc",
    scientific_name = "Lynx rufus",
    common_name     = "Bobcat",
    grid_res_m      = 500,    # finer - small home range, abundant data
    sensitive       = FALSE
  )
)

# ---- Minimum publishable resolution for sensitive species --------------------
# See docs/sensitive-data-policy.md section 3. Any published puma surface must
# be at or coarser than this cell size.
MIN_PUBLISH_RES_SENSITIVE_M <- 1000

# ---- Paths -------------------------------------------------------------------
PATH <- list(
  raw        = file.path("data", "raw"),
  interim    = file.path("data", "interim"),
  processed  = file.path("data", "processed"),
  restricted = file.path("data", "restricted"),
  figures    = file.path("outputs", "figures"),
  tables     = file.path("outputs", "tables"),
  rasters    = file.path("outputs", "rasters"),
  models     = file.path("outputs", "models"),
  site_data  = file.path("site", "data")
)

invisible(lapply(PATH, dir.create, recursive = TRUE, showWarnings = FALSE))

# ---- Helper: build a conventional data filename ------------------------------
# Enforces docs/naming-conventions.md section 2.
#   build_path("processed", "occ", "bobc_gbif_clean", "gpkg")
#   -> "data/processed/occ_bobc_gbif_clean_3310.gpkg"
build_path <- function(where, theme, subject, ext, crs = CRS_ANALYSIS) {
  stopifnot(where %in% names(PATH))
  file.path(PATH[[where]], sprintf("%s_%s_%d.%s", theme, subject, crs, ext))
}
EOF

# ---------------------------------------------------------------------------
# 16. R function stubs
# ---------------------------------------------------------------------------
cat > "$REPO/R/00_functions_io.R" << 'EOF'
# =============================================================================
# 00_functions_io.R
# Reading, writing and provenance helpers.
# =============================================================================

#' Write an sf object to GeoPackage, overwriting cleanly
write_layer <- function(x, path, layer = NULL) {
  if (is.null(layer)) layer <- tools::file_path_sans_ext(basename(path))
  sf::st_write(x, dsn = path, layer = layer, delete_dsn = TRUE, quiet = TRUE)
  message("Wrote ", nrow(x), " features -> ", path)
  invisible(path)
}

#' Read a layer and assert its CRS matches the analysis CRS
read_layer <- function(path, layer = NULL, expect_crs = CRS_ANALYSIS) {
  x <- if (is.null(layer)) sf::st_read(path, quiet = TRUE)
       else sf::st_read(path, layer = layer, quiet = TRUE)
  epsg <- sf::st_crs(x)$epsg
  if (!isTRUE(epsg == expect_crs)) {
    stop("CRS mismatch in ", path, ": found EPSG:", epsg,
         ", expected EPSG:", expect_crs, call. = FALSE)
  }
  x
}

#' Append a row to the record-count log used in docs/methodology.md
log_stage <- function(dataset, stage, n, file = "outputs/tables/record_counts.csv") {
  row <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    dataset = dataset, stage = stage, n = n
  )
  utils::write.table(
    row, file, sep = ",", row.names = FALSE,
    col.names = !file.exists(file), append = file.exists(file)
  )
  message(sprintf("[%s] %s: %s", dataset, stage, format(n, big.mark = ",")))
  invisible(row)
}
EOF

cat > "$REPO/R/00_functions_spatial.R" << 'EOF'
# =============================================================================
# 00_functions_spatial.R
# Spatial helpers shared across the pipeline.
# =============================================================================

#' Reproject any sf object to the analysis CRS
to_analysis_crs <- function(x) sf::st_transform(x, CRS_ANALYSIS)

#' Build a regular analysis grid over an area of interest
#'
#' @param aoi_sf sf polygon defining the study area
#' @param res_m  cell size in metres
#' @return sf polygon grid with a `cell_id` column
make_grid <- function(aoi_sf, res_m) {
  g <- sf::st_make_grid(aoi_sf, cellsize = res_m, square = TRUE)
  g <- sf::st_sf(cell_id = seq_along(g), geometry = g)
  g[sf::st_intersects(g, sf::st_union(aoi_sf), sparse = FALSE)[, 1], ]
}

#' Guard against publishing a sensitive-species surface at too fine a resolution
#'
#' Call before any export of a puma-derived raster. See
#' docs/sensitive-data-policy.md section 3.
assert_publishable <- function(r, sensitive = TRUE) {
  if (!sensitive) return(invisible(TRUE))
  res_m <- min(terra::res(r))
  if (res_m < MIN_PUBLISH_RES_SENSITIVE_M) {
    stop("Refusing to export sensitive-species surface at ", res_m,
         " m resolution. Minimum is ", MIN_PUBLISH_RES_SENSITIVE_M,
         " m. See docs/sensitive-data-policy.md.", call. = FALSE)
  }
  invisible(TRUE)
}
EOF

# ---------------------------------------------------------------------------
# 17. Script stubs
# ---------------------------------------------------------------------------
cat > "$REPO/scripts/00_setup_environment.R" << 'EOF'
# =============================================================================
# 00_setup_environment.R
# Installs and verifies the R spatial toolchain. Run once per machine.
# =============================================================================

pkgs <- c(
  # Core spatial
  "sf", "terra", "exactextractr", "units",
  # Data access
  "rgbif", "rinat", "tigris", "elevatr", "osmdata",
  # Analysis
  "spatstat.explore", "spatstat.geom", "sfdep", "spdep",
  "unmarked", "leastcostpath", "gdistance",
  # Wrangling and reporting
  "tidyverse", "janitor", "gt", "ggplot2", "scales", "patchwork",
  "leaflet", "quarto",
  # Reproducibility
  "renv", "targets", "here"
)

missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing)

# ---- Verify the underlying geospatial libraries -----------------------------
library(sf); library(terra)

cat("R version:      ", R.version.string, "\n")
cat("sf version:     ", as.character(packageVersion("sf")), "\n")
cat("terra version:  ", as.character(packageVersion("terra")), "\n")
cat("GDAL:           ", sf_extSoftVersion()[["GDAL"]], "\n")
cat("GEOS:           ", sf_extSoftVersion()[["GEOS"]], "\n")
cat("PROJ:           ", sf_extSoftVersion()[["PROJ"]], "\n")

# ---- Confirm the analysis CRS resolves --------------------------------------
source("R/00_config.R")
crs_check <- sf::st_crs(CRS_ANALYSIS)
stopifnot(!is.na(crs_check$epsg))
cat("\nAnalysis CRS OK: EPSG:", crs_check$epsg, " - ", crs_check$Name, "\n", sep = "")

# ---- Next step ---------------------------------------------------------------
cat("\nIf this all printed cleanly, run renv::init() and commit renv.lock.\n")
EOF

for f in 01_download_open_data 02_prepare_boundaries 03_prepare_occurrences \
         04_prepare_covariates 05_kde_and_hotspots 06_occupancy_models \
         07_connectivity 08_export_web_layers; do
cat > "$REPO/scripts/$f.R" << EOF
# =============================================================================
# $f.R
# TODO: implement
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

library(sf)
library(terra)
library(tidyverse)

# -----------------------------------------------------------------------------
# Record every parameter value used here in docs/methodology.md as you go.
# -----------------------------------------------------------------------------
EOF
done

# ---------------------------------------------------------------------------
# 18. targets pipeline placeholder
# ---------------------------------------------------------------------------
cat > "$REPO/_targets.R" << 'EOF'
# =============================================================================
# _targets.R
# Optional pipeline orchestration. Adopt once the numbered scripts stabilise -
# do not start here. Run with targets::tar_make().
# =============================================================================

library(targets)

tar_option_set(packages = c("sf", "terra", "tidyverse"))

lapply(list.files("R", full.names = TRUE, pattern = "\\.R$"), source)

list(
  # tar_target(openspace_raw, read_cpad(...), format = "file"),
  # tar_target(openspace_sf,  prepare_openspace(openspace_raw)),
)
EOF

# ---------------------------------------------------------------------------
# 19. Quarto site skeleton
# ---------------------------------------------------------------------------
cat > "$REPO/site/_quarto.yml" << 'EOF'
project:
  type: website
  output-dir: ../_site

website:
  title: "Wild Cats at the Urban Edge"
  description: "Pumas and bobcats in San Francisco Bay Area open spaces"
  navbar:
    left:
      - href: index.qmd
        text: Story
      - href: methods.qmd
        text: Methods
      - href: data.qmd
        text: Data

format:
  html:
    theme: cosmo
    toc: true
    css: styles.css

execute:
  freeze: auto
EOF

cat > "$REPO/site/index.qmd" << 'EOF'
---
title: "Wild Cats at the Urban Edge"
subtitle: "Pumas and bobcats in San Francisco Bay Area open spaces"
---

*Story site placeholder. Content built in Week 9.*

Two species, one landscape, opposite problems: bobcats are everywhere and
hard to miss; pumas are almost invisible and running out of room to move.
EOF

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "Repository scaffold created."
echo ""
find "$REPO" | sed -e "s|$REPO|bay-area-wildcats|" | sort
