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
