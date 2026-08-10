# Project Proposal

**Title:** Wild Cats at the Urban Edge: Distribution and Connectivity of Pumas
and Bobcats in San Francisco Bay Area Open Spaces

**Author:** Kiran Balasubramanian
**Date:** July 23, 2026
**Last updated:** August 9, 2026
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

Each question is tagged with the track it belongs to. Puma and bobcat are
analysed in parallel and never pooled (`docs/methodology.md` Decision 3), so most
questions are species-specific by design.

1. **[Landscape]** How is protected open space distributed across the ten-county
   Bay Area, and how connected or fragmented is that network from the
   perspective of a wide-ranging carnivore?
2. **[Bobcat]** Where are bobcats present across open-space units, and which
   landscape characteristics — land cover, patch size, terrain, road density,
   urban-edge proximity — best explain that pattern? The intended approach is
   occupancy modelling; if a defensible detection history cannot be built from
   opportunistic records, this becomes a habitat-suitability (SDM) question
   under the pre-registered fallback criteria in `docs/methodology.md` §5.4
   (Risk 1). The question stands either way; only the method changes.
3. **[Puma]** Where are the likely movement corridors for pumas between core
   habitat patches, and where do those corridors intersect major roads and
   high-traffic barriers (where traffic volume, not just road presence, drives
   the barrier effect)?
4. **[Both]** Where does wildlife–vehicle road mortality concentrate for each
   species, and does it coincide with modelled corridors and crossing points?
5. **[Cross-cutting]** How much of the apparent spatial pattern reflects true
   distribution versus observer and detection effort?

Question 5 is treated as a first-class analytical question, not a caveat —
carried forward from the tiger project, where observer bias proved to be one of
the more instructive findings.

## 3. Study area

Ten-county San Francisco Bay Area: Alameda, Contra Costa, Marin, Napa,
San Francisco, San Mateo, Santa Clara, Santa Cruz, Solano, Sonoma.

Confirmed as the analysis frame (Decision 2) and locked in `R/00_config.R`
(`STUDY_COUNTIES`). The study area itself is the sample frame — no
organisation-specific or size-based subsetting.

## 4. Data

Summarised in `docs/data-sources.md`. Phase 1 uses public open data only.
Partner data from Felidae Conservation Fund is **deferred to a future phase**
(`docs/methodology.md` Decision 7) and is not a Phase-1 dependency.

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

*Maintained during execution, as in the tiger project. Each entry records where
the as-built work diverged from a named source or method in this proposal or the
Week-plan. Elaborations the proposal left open (e.g. the specific occupancy site
unit, the dedupe key) are documented as numbered Decisions in
`docs/methodology.md`, not here — this section is for genuine divergences from a
stated choice. Full justification for each lives in the referenced Decision.*

---

### 1. Open-space source: BPAD → statewide CPAD 2026a (Decision 8)

**Proposed / implied:** a Bay Area protected-area layer.
**Actual:** statewide **CPAD 2026a** (fee Units + Holdings), with **CCED 2026a**
as a separate easement layer.
**Reason:** CPAD carries the Unit/SuperUnit/Holding hierarchy the occupancy site
definition needs, with cleaner provenance than a pre-clipped regional extract.
Clipped to the ten-county frame by boundary, not by a source-specific subset.

---

### 2. Land-cover source: NLCD → ESA WorldCover 2021 (Decision 12)

**Proposed / Week-2 plan:** Annual **NLCD** (developed-intensity gradient).
**Actual:** **ESA WorldCover 2021 v200** (10 m, 11 classes); the urban-intensity
gradient moved to gHM + housing density.
**Reason:** NLCD proved unacquirable via any clean scripted route. WorldCover is
10 m, CC-BY 4.0, on public AWS COGs, auth-free. **Known cost:** WorldCover
under-maps California chaparral ~26× vs NLCD (shrub ~123 km² vs ~3,200) — flagged,
with CAL FIRE FVEG as a targeted supplement if chaparral proves material at model
fit, not a full re-do.

---

### 3. Terrain source: "3DEP 10 m" → AWS Terrain Tiles via elevatr (Decision 13)

**Proposed / Week-2 plan:** USGS **3DEP 10 m** DEM.
**Actual:** **AWS Terrain Tiles** (`elevatr`, `src = "aws"`, z=12) — a
Terrarium-encoded mosaic blending 3DEP/SRTM/GMTED, ~30 m effective resolution at
the study-area latitude (the 15.1 m post-reprojection cell size is a resampling
artifact, not real detail).
**Reason:** auth-free scripted acquisition; native 3DEP tiling was heavier for
marginal gain at the analysis grain. The "3DEP 10 m" wording is inaccurate
as-built and was corrected; 1 m lidar deferred.

---

### 4. Human-modification citation: Kennedy 2019 → Theobald 2024 (Decision 15)

**Proposed / Week-2 plan:** gHM from **Kennedy et al. 2019** (1 km).
**Actual:** **Theobald et al. 2024** gHM v3/2022 (300 m COG, Zenodo, `/vsicurl`).
**Reason:** v3/2022 is DOI-pinned, more current, and acquirable auth-free;
Kennedy 2019 ships as a figshare zip / GEE asset needing an Earth Engine account.
Provenance swap recorded so every human-modification citation points to Theobald
2024. Housing density added separately (SILVIS block-level, Decision 16).

---

### 5. Roads source: statewide → Geofabrik NorCal extract (Decision 14)

**Proposed / Week-2 plan:** OSM roads (unspecified extract) + traffic.
**Actual:** **Geofabrik NorCal** OSM extract (`fclass`) + **Caltrans AADT**.
**Reason:** no current statewide California OSM shapefile is published (only stale
2014–2018); the NorCal sub-region fully contains the study area. Not
osmdata/Overpass (heavier, rate-limited for this extent).

---

### 6. Bobcat background effort: rinat/iNat-only → GBIF all-datasets (Decision 22 draft)

**Proposed / implied:** the occupancy detection history would draw on the same
iNaturalist effort as the occurrence data.
**Actual:** target-group **background effort pulled from GBIF (all datasets)** via
a single async download, not `rinat`.
**Reason:** the effort pull spans *all* vertebrate observations across the study
area for 2010–2026 — millions of records. `rinat`'s 10,000-record cap made this
impossible (county×month tiling still capped in City Nature Challenge months).
GBIF's async download has no cap and filters server-side. **Scope also widened**
from iNat-only to all GBIF datasets — a broader, more defensible effort proxy
(museum, eBird-via-GBIF, other surveys), shifting "iNat research-grade effort" to
"any georeferenced vertebrate occurrence." The bird-dominated breadth is why the
mammal-subset background (Fork 3A) is the target-group-correct option; A-vs-B is
held to the Week-5 fit.

---

### 7. Occupancy vs SDM — resolved as anticipated, not a deviation

The proposal (Q2) explicitly built in the occupancy-or-SDM fork under the §5.4
fallback criteria. Week-4's Risk 1 gate resolved it toward **occupancy**
(Decision 22 draft; 194 units with ≥2 detection-years, naive ψ 0.284). This is
recorded here only to note the fork was exercised as designed — it is a
*resolution of a planned contingency*, not a divergence from the proposal.
Logged for traceability; the fit-time confirmation (fitted p, GOF) closes it in
Week 5.
