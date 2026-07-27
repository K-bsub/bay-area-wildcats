# Project Proposal

**Title:** Wild Cats at the Urban Edge: Distribution and Connectivity of Pumas
and Bobcats in San Francisco Bay Area Open Spaces

**Author:** Kiran Balasubramanian
**Date:** July 23, 2026
**Last updated:** July 27, 2026
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

*(To be maintained during execution, as in the tiger project.)*
