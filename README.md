# Wild Cats at the Urban Edge

**Distribution and connectivity of pumas and bobcats in San Francisco Bay Area open spaces**

A reproducible, open-source spatial analysis built entirely in R.
Phase 1 of a multi-phase project. Sister project to
[tiger-conservation-india](https://github.com/K-bsub/tiger-conservation-india).

| | |
|---|---|
| **Author** | Kiran Balasubramanian |
| **Status** | Week 4 complete (occurrence layers cleaned + deduped; bobcat occupancy feasibility gate passed; background effort acquired) — Week 5 next: covariate stacking, puma resistance surface, bobcat detection history + null occupancy fit |
| **Focal species** | *Puma concolor* (puma / mountain lion), *Lynx rufus* (bobcat) |
| **Study area** | Ten-county San Francisco Bay Area |
| **Analysis CRS** | EPSG:3310 — NAD83 / California Albers |
| **Stack** | R (sf, terra, spatstat, sfdep, unmarked), Quarto, Leaflet |
| **Story site** | *Skeleton live at [k-bsub.github.io/bay-area-wildcats](https://k-bsub.github.io/bay-area-wildcats/); content in Week 9* |

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
| Location sensitivity | High (precise points held; coarsen on publish) | Low |
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

# 2. Install and verify the spatial toolchain (GDAL/GEOS/PROJ) first, so any
#    system-library issue surfaces before renv is layered on top
source("scripts/00_setup_environment.R")

# 3. First time only — initialise the reproducible environment
install.packages("renv")
renv::init()          # then renv::snapshot(); commit renv.lock

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
`gh-pages` branch by `.github/workflows/publish.yml`. Set GitHub Pages to serve
from the **`gh-pages` branch / root** — do not switch Pages to serve from `/docs`.

The site is rendered **locally** (`quarto render site`) and its computed output
is frozen in `site/_freeze/`, which is committed. The Action therefore needs only
Quarto, not the R spatial stack — re-render locally and commit `site/_freeze/`
whenever a `.qmd`'s code changes.
