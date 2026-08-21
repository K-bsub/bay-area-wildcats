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

> ✅ **Resolved (2026-08-17) — inherited wording corrected against primary
> sources.** The `references.md` seed and `data-sources.md` §5 described this as a
> "status review supporting CESA **listing**" of the "Central Coast North"
> population, and an earlier draft dated the listing to April 2026. Both are now
> corrected: the Commission voted to list the population as **threatened on
> February 12, 2026** (not April — April 15–16 was only the *next* scheduled
> meeting). It is no longer a candidate under review. The underlying documents are
> still the right citations. Details:

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
  Department of Fish and Wildlife. The status-review report the Commission relied
  on is dated **December 2025**. (CDFW document portal — DocumentID 239679 /
  239696.)
- **Listing (2026):** at its **February 12, 2026** meeting (the Feb 11–12
  Commission meeting) the Commission voted unanimously to list mountain lions
  within the **Southern California / Central Coast Distinct Population Segment
  (SC/CC DPS)** as **threatened** under CESA. The DPS spans from portions of the
  San Francisco Bay Area south to the Mexico border and is slightly smaller than,
  but largely conforms to, the petitioned SC/CC ESU. Affected counties named in
  the release include Ventura, Los Angeles, Orange, San Diego, San Bernardino,
  Riverside, Santa Barbara, San Luis Obispo, Monterey, Santa Cruz and parts of
  the Bay Area. **Note:** the Feb 12 vote determined listing is *warranted*; the
  Commission adopts its formal findings (and the regulatory effective date
  follows) at a later meeting — so cite the **date of the vote**, not an effective
  date, unless the final regulation date has since been confirmed.

  > *Provenance note:* the listing post-dates my training cutoff. Corrected and
  > verified 2026-08-17 against the CDFW / Fish and Game Commission news release
  > (fgc.ca.gov, "CESA Protections Warranted … Mountain Lion," Feb 2026) and
  > concurring legal alerts (National Law Review, Endangered Species Law & Policy,
  > Fennemore). The earlier "April 2026" date was wrong (that was the next
  > scheduled meeting). For the public-facing story site, still cite the primary
  > Commission notice / Cal. Reg. Notice Register for the final adopted findings
  > and effective date once published — the vote date (Feb 12, 2026) is firm.

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
- **Kernel density estimation + bandwidth selection (Decision 28):**
  > Baddeley, A., Rubak, E., & Turner, R. (2015). *Spatial Point Patterns:
  > Methodology and Applications with R.* Chapman & Hall/CRC. — the `spatstat`
  > reference; `density.ppp` with Jones-Diggle edge correction (`diggle = TRUE`).

  Bandwidth-selector primary sources (the three candidates in the Decision 28
  rule):
  - `bw.diggle` (Diggle-Berman MSE cross-validation):
    > Diggle, P.J. (1985). A kernel method for smoothing point process data.
    > *Applied Statistics (JRSS-C)*, 34(2), 138–147.
    > Berman, M., & Diggle, P.J. (1989). Estimating weighted integrals of the
    > second-order intensity of a spatial point process. *JRSS-B*, 51(1), 81–92.
  - `bw.ppl` (likelihood cross-validation):
    > Loader, C. (1999). *Local Regression and Likelihood.* Springer, New York.
    > (Section 5.3 — the LCV criterion `bw.ppl` implements.)
  - Selector-disagreement support (motivates the pre-registered rule, not a
    post-hoc pick): Diggle-Berman MSE picks very small bandwidths (small high-count
    areas), the window rule-of-thumb picks very smooth, LCV lands between — exactly
    the puma result (diggle 49 m vs home-range 5 km):
    > Macdonald, J.A., et al. (2025). Bandwidth selection for kernel intensity
    > estimators for spatial point processes. *Scandinavian Journal of Statistics*.
    > DOI: 10.1111/sjos.12782.
- **Getis-Ord Gi\* local statistics:**
  > Getis, A., & Ord, J.K. (1992). The analysis of spatial association by use of
  > distance statistics. *Geographical Analysis*, 24(3), 189–206.
  > Ord, J.K., & Getis, A. (1995). Local spatial autocorrelation statistics:
  > distributional issues and an application. *Geographical Analysis*, 27(4),
  > 286–306.

  Implementation + neighbour-scheme choice (Decision 30):
  > Parry, J. *sfdep: Spatial Dependence for Simple Features* [R package]. CRAN,
  > https://cran.r-project.org/package=sfdep. — `local_gstar_perm`,
  > `st_dist_band`, `st_knn`, `global_g_test`; a piped `sf` interface to `spdep`.
  > (Cite the installed version from `renv.lock` when converting to `.bib`.)
  > Bivand, R.S., & Wong, D.W.S. (2018). Comparing implementations of global and
  > local indicators of spatial association. *TEST*, 27(3), 716–748. DOI:
  > 10.1007/s11749-018-0599-x. — the `spdep` implementation reference underneath
  > `sfdep`.
  - *Neighbour-scheme guidance (grey literature, cited as guidance not a journal
    source):* Esri, *How Hot Spot Analysis (Getis-Ord Gi\*) works* and *Best
    practices for selecting a fixed distance band value* (ArcGIS Pro
    documentation). Basis for Decision 30's fixed distance band sized so the mean
    feature has ~8 neighbours (the skew-reliability rule of thumb) with a
    minimum-neighbour floor. The "~8" sizes the band; it is not an endorsement of
    KNN — the correction recorded in Decision 30.
- **Point-to-unit assignment / coordinate-uncertainty snap tolerance
  (Decision 30):**
  > Johnson, B.A., Pinilla-Buitrago, G.E., & Anderson, R.P. (2025). A neighborhood
  > approach for using remotely sensed data to estimate current ranges for
  > conservation assessments. *Ecology and Evolution*, 15(7), e71631. DOI:
  > 10.1002/ece3.71631. — grounds the tolerance in the record's own coordinate
  > uncertainty / radius of actual sampling, rather than a fixed distance; basis
  > for snapping only within each point's `coord_uncert_m`.
- **Connectivity — least-cost path & circuit theory:**
  > McRae, B.H., Dickson, B.G., Keitt, T.H., & Shah, V.B. (2008). Using circuit
  > theory to model connectivity in ecology, evolution, and conservation.
  > *Ecology*, 89(10), 2712–2724.
  > Adriaensen, F., et al. (2003). The application of 'least-cost' modelling as a
  > functional landscape model. *Landscape and Urban Planning*, 64(4), 233–247.

  Implementation — `leastcostpath` (Decision 33):
  > Lewis, J. *leastcostpath: Modelling Pathways and Movement Potential Within a
  > Landscape* [R package]. v2.0.13 (2.x terra API — `create_cs`, `create_lcp`,
  > `create_cost_corridor`; the pre-2.0 `gdistance` transition backend is not
  > used). CRAN, https://cran.r-project.org/package=leastcostpath. (Cite the
  > installed version from `renv.lock` when converting to `.bib`.)

  Raster neighbourhood / adjacency distortion (Decision 33 — the 16-connectivity
  choice; more movement directions reduce the deviation & elongation distortion
  of raster least-cost paths, which otherwise overestimate cost-weighted length
  by orienting segments only along 8 directions):
  > Antikainen, H. (2013). Comparison of different strategies for determining
  > raster-based least-cost paths with a minimum amount of distortion.
  > *Transactions in GIS*, 17(1), 96–108. DOI: 10.1111/j.1467-9671.2012.01355.x.
  > Shirabe, T. (2016). A method for finding a least-cost wide path in raster
  > space. *International Journal of Geographical Information Science*, 30(8),
  > 1469–1485. DOI: 10.1080/13658816.2015.1124435.

  Bay Area / Santa Cruz Mountains ↔ Diablo Range linkage — corroboration of the
  modelled corridor (Decision 33; the Coyote Valley / US-101 pinch as the
  field-verified constriction between the two ranges). Grey-literature / agency
  connectivity assessments, cited as corroboration, not as method:
  > Bay Area Critical Linkages / Conservation Lands Network — Santa Cruz Mountains
  > and Coyote Valley linkage assessments. Open Space Authority of Santa Clara
  > Valley, *Coyote Valley Landscape Linkage* (conservation vision + wildlife
  > movement). Santa Cruz Mountains Linkage — *Linkage Conceptual Area Protection
  > Plan (CAPP)*. (Locate primary reports for the story-site citation; used here
  > to confirm the modelled 1727↔3972 linkage matches the field-established one.)
  Least-cost uncertainty / sensitivity analysis (Decision 35 — OAT plausible-range
  perturbation of the resistance surface, judged on corridor overlap; the method
  and the finding that corridor location is driven by high-resistance cells and is
  robust to plausible variation in lower-value parameters):
  > Beier, P., Majka, D.R., & Newell, S.L. (2009). Uncertainty analysis of
  > least-cost modeling for designing wildlife linkages. *Ecological Applications*,
  > 19(8), 2067–2077.
  > Rayfield, B., Fortin, M.-J., & Fall, A. (2010). The sensitivity of least-cost
  > habitat graphs to relative cost surface values. *Landscape Ecology*, 25(4),
  > 519–532. DOI: 10.1007/s10980-009-9436-7.
  > Marrec, R., et al. (2020). A conceptual framework and uncertainty analysis for
  > large-scale, species-agnostic modelling of landscape connectivity. *Scientific
  > Reports*, 10, 21073. — connectivity maps most sensitive to some parameters
  > (barrier definition, scaling function), robust to others; high-value cells more
  > concordant than low.
  Connectivity network topology (Decision 37 — Gabriel graph on cores, shortest
  cost path for the SC↔Diablo chain):
  > Gabriel, K.R., & Sokal, R.R. (1969). A new statistical approach to geographic
  > variation analysis. *Systematic Zoology*, 18(3), 259–278. (Gabriel graph.)
  > Csárdi, G., & Nepusz, T. (2006). The igraph software package for complex
  > network research. *InterJournal Complex Systems*, 1695. [R package `igraph`.]
  > `spdep` (Bivand et al.) — `gabrielneigh`. (Cite installed versions from
  > `renv.lock` when converting to `.bib`.)

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
