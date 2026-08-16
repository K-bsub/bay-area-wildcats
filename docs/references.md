# References

Literature and report bibliography for the project. **Data-source** citations
(the datasets themselves — CPAD, GBIF, WorldCover, gHM, etc.) live in
`docs/data-sources.md`; this file covers the reports and papers the analysis and
narrative lean on.

Formatting: author–date. Convert to a `.bib` file if the site moves to Quarto
citation handling (`@key` cites + `references.bib`).

---

## Population and status (context only — not a trend)

> These establish a single point-in-time picture of puma abundance and
> regulatory status. Per `data-sources.md` §5 there is **no** repeated regional
> census equivalent to the tiger project's NTCA rounds, so these are cited as
> context and must **never** be presented as a population trend. No statewide
> bobcat abundance estimate exists.

**California Mountain Lion Project — statewide abundance estimate.** The first
large-scale statewide estimate of puma abundance in California, a seven-year
collaboration (~$2.45M in state funds) among CDFW, UC Santa Cruz, UC Davis, the
Institute for Wildlife Studies and Audubon Canyon Ranch. Three estimates were
produced — one ~4,511 and two near ~3,200 — commonly reported as a range of
**roughly 3,200–4,500 adult and subadult mountain lions statewide**, well below
the decades-old ~4,000–6,000 back-of-envelope figure it replaced. Project lead:
Justin Dellinger.

- Underlying method paper:
  > Dellinger, J.A., Gustafson, K.D., Gammons, D.J., Ernest, H.B., & Torres, S.G.
  > (2020). Minimum habitat thresholds required for conserving mountain lion
  > genetic diversity. *Ecology and Evolution*, 10(19), 10687–10696.
- Habitat-selection / management-framing companion (same statewide effort):
  > Dellinger, J.A., et al. (2019). Using mountain lion habitat selection in
  > management. *The Journal of Wildlife Management*, 84(2). DOI:
  > 10.1002/jwmg.21798.
- Popular-press anchors for the 3,200–4,500 figure (for narrative attribution,
  not as a primary source): *Los Angeles Times* (Jan 2024); summarised at
  phys.org (2024-01-08).
- *To locate:* the consolidated California Mountain Lion Project final report /
  census document itself (the three-estimate source), if CDFW has published it
  beyond the method papers above.

**CDFW status review + CESA listing — Southern California / Central Coast
mountain lion.**

> ⚠️ **Flag — the project's inherited wording is now stale (see below).** The
> `references.md` seed and `data-sources.md` §5 describe this as a "status review
> supporting CESA **listing**" of the "Central Coast North" population. As of
> **April 2026 the population was formally listed as threatened** — it is no
> longer a candidate under review. Wording needs a light correction; the
> underlying documents are still the right citations. Details:

- **Petition (2019):** Center for Biological Diversity & Mountain Lion Foundation
  petitioned the Fish and Game Commission (June 25, 2019) to list an
  Evolutionarily Significant Unit (ESU) of mountain lion (*Puma concolor*)
  comprising **six subpopulations** across southern and central-coastal
  California. The one directly relevant to this project is **Central Coast North
  = the Santa Cruz Mountains population**, the isolation of which anchors the
  puma connectivity narrative.
- **Candidate status (2020):** the Commission designated the SC/CC ESU a
  candidate species on **May 1, 2020**, conferring full CESA take protection
  during the review.
- **CDFW Status Review:** *Status Review of the Petitioned Southern
  California/Central Coast ESU of Mountain Lion in California.* California
  Department of Fish and Wildlife. (CDFW document portal — DocumentID 239679 /
  239696.)
- **Listing (2026):** in **April 2026** the Commission listed mountain lions
  within the **Southern California / Central Coast Distinct Population Segment
  (SC/CC DPS)** as **threatened** under CESA. The DPS spans from portions of the
  San Francisco Bay Area south to the Mexico border and largely (slightly more
  narrowly) conforms to the petitioned ESU.

  > *Provenance note:* the April 2026 listing post-dates my training cutoff and
  > was confirmed by web search on 2026-08-03 (legal alerts: Allen Matkins,
  > Mondaq, Endangered Species Law & Policy). Verify against the primary
  > Commission notice / Cal. Reg. Notice Register before it goes in public-facing
  > narrative — secondary legal-alert sourcing is fine for the doc, not ideal for
  > the story site.

- No statewide **bobcat** abundance or status estimate exists — asymmetry to
  state plainly wherever puma status context appears, so the bobcat track is not
  implied to have an equivalent.

---

## Bay Area felid research

*(To be populated — priority items to locate and read.)*

- **Felidae Conservation Fund / Bay Area Puma Project** publications, including
  the study of puma, bobcat, coyote and mule-deer response to dog-related access
  rules in Bay Area protected areas. (Relevant to the deferred Felidae partner
  data, Decision 7, and to coexistence framing.)
- **Santa Cruz Mountains puma isolation and genetic connectivity** literature
  (UC Santa Cruz — Wilmers / Ernest lab lineage). Directly supports the puma
  isolation narrative and the Central Coast North ESU/DPS framing above.
  > Hansen, K.W., Morgan, J.J., De Alfaro, L., Wilmers, C.C., & Ocampo-Peñuela, N.
  > (2025). *Variation in anthropogenic tolerance alters dispersal capacity of a
  > large carnivore.* bioRxiv 2025.09.29.677867 (not peer-reviewed as of retrieval,
  > 2026-08-15). iSSF habitat-selection models for **84 GPS-collared pumas in the
  > Santa Cruz Mountains** (2009–2024), fed into the EcoScape connectivity
  > algorithm. **Directly used in Decision 26** as the local calibration source for
  > (a) covariate selection — slope, vegetation/cover, housing density, land cover,
  > distance-to-urban-edge; (b) effect directions — pumas select for cover, against
  > slope, building density, urban centres, anthropogenic land cover; (c) the
  > **log-inverse traffic transform** for road resistance (compresses the
  > high-traffic tail / mortality-risk weighting). Note the study weights covariates
  > from step-selection coefficients (collar data this project lacks), and uses
  > housing density where this project substitutes gHM (Decision 23 divergence).
  > Data/code: Dryad 10.5061/dryad.44j0zpctn; github.com/WhitneyH1317/puma_permeability_calibration.

  Related same-lab context already worth citing (referenced within Hansen 2025 and
  relevant to the coexistence/mortality framing):
  - Wilmers, C.C., Wang, Y., Nickel, B., et al. (2013). Scale-dependent behavioral
    responses to human development by a large predator, the puma. *PLoS ONE* 8(4),
    e60590. — housing-density-as-covariate precedent for Santa Cruz pumas.
  - Nisi, A.C., Benson, J.F., King, R., & Wilmers, C.C. (2023). Habitat
    fragmentation reduces survival and drives source–sink dynamics for a large
    carnivore. *Ecological Applications* 33(4), e2822. — mortality-risk basis for
    weighting roads/traffic as barrier.
- **Coyote Valley linkage** and broader Bay Area connectivity assessments (the
  Coyote Valley pinch point between the Santa Cruz Mountains and Diablo Range —
  the key connectivity feature in the study area).

---

## Road ecology

*(Ties to CROS, Decision 11 / §4.4 — parked pending F. Shilling reply.)*

- **UC Davis Road Ecology Center** — annual California wildlife–vehicle collision
  hotspot reports (Shilling et al.). The published-hotspot fallback if CROS
  record-level access is not granted.
- Comparative analysis of puma road-crossing locations versus roadkill hotspots
  for siting crossings and fencing.

---

## Methods

- **Occupancy estimation and modelling:**
  > MacKenzie, D.I., Nichols, J.D., Lachman, G.B., Droege, S., Royle, J.A., &
  > Langtimb, C.A. (2002). Estimating site occupancy rates when detection
  > probabilities are less than one. *Ecology*, 83(8), 2248–2255.
  > MacKenzie, D.I., et al. (2017). *Occupancy Estimation and Modeling:
  > Inferring Patterns and Dynamics of Species Occurrence* (2nd ed.). Elsevier.
- **`unmarked`:**
  > Fiske, I., & Chandler, R. (2011). unmarked: An R package for fitting
  > hierarchical models of wildlife occurrence and abundance. *Journal of
  > Statistical Software*, 43(10), 1–23.
- **`spOccupancy`:**
  > Doser, J.W., Finley, A.O., Kéry, M., & Zipkin, E.F. (2022). spOccupancy: An R
  > package for single-species, multi-species, and integrated spatial occupancy
  > models. *Methods in Ecology and Evolution*, 13(8), 1670–1678.
- **Getis-Ord Gi\* local statistics:**
  > Getis, A., & Ord, J.K. (1992). The analysis of spatial association by use of
  > distance statistics. *Geographical Analysis*, 24(3), 189–206.
  > Ord, J.K., & Getis, A. (1995). Local spatial autocorrelation statistics:
  > distributional issues and an application. *Geographical Analysis*, 27(4),
  > 286–306.
- **Connectivity — least-cost path & circuit theory:**
  > McRae, B.H., Dickson, B.G., Keitt, T.H., & Shah, V.B. (2008). Using circuit
  > theory to model connectivity in ecology, evolution, and conservation.
  > *Ecology*, 89(10), 2712–2724.
  > Adriaensen, F., et al. (2003). The application of 'least-cost' modelling as a
  > functional landscape model. *Landscape and Urban Planning*, 64(4), 233–247.

---

## Data provenance notes (citations that live in `data-sources.md`)

The datasets themselves are cited in `docs/data-sources.md`, not here. One swap
is flagged so it is discoverable from either file:

- **Human modification — gHM citation swap (Decision 15).** The Week-2 plan named
  **Kennedy, C.M., et al. (2019)** ("Managing the middle: A shift in conservation
  priorities based on the global human modification gradient," *Global Change
  Biology* 25(3), 811–826) as the gHM source. The acquired layer is instead
  **Theobald, D.M., Oakleaf, J.R., Moncrieff, G., Voigt, M., Kiesecker, J., &
  Kennedy, C.M. (2024).** *Global human modification datasets of terrestrial
  ecosystems for 2022* (v1.0.0) [Data set]. Zenodo, DOI
  10.5281/zenodo.14502573. Reason: v3/2022 is a DOI-pinned COG acquirable
  auth-free via `/vsicurl` and more current; Kennedy 2019 ships as a figshare zip
  / GEE asset needing an Earth Engine account. **Wherever human-modification
  provenance is stated, cite Theobald et al. 2024, not Kennedy et al. 2019.**
  Full data record: `data-sources.md` §4.4.1.

*This file is literature; `data-sources.md` is data provenance. Keep new
dataset citations there and new paper/report citations here.*
