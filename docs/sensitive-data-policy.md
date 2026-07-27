# Sensitive Data Policy

**Status:** Active — applies from Week 1 onward
**Applies to:** all contributors, all branches, all published outputs

---

## 1. Why this document exists

Precise location data for pumas is a poaching, harassment and disturbance risk.
This is not hypothetical: many iNaturalist observers deliberately obscure their
own puma sightings for the animals' safety, and research organisations do not
publish raw camera-trap coordinates. **iNaturalist does not auto-obscure *Puma
concolor* in California** (Decision 10) — so this project actually holds ~1,057
precise, publicly-shared puma locations. Publishing precise puma outputs would
expose real hotspots, including near sites that obscuring observers deliberately
hid. The coarsening rules below are therefore load-bearing, not precautionary.

This project is public. Anything committed to this repository or rendered to
the story site is permanently public. Treat every commit as irreversible.

---

## 2. Data sensitivity tiers

| Tier | Definition | Examples | Handling |
|---|---|---|---|
| **T0 — Open** | Public, no location risk | CPAD boundaries, roads, land cover, DEM | Normal use |
| **T1 — Open, coarse** | Public but already obscured at source | iNaturalist puma records (obscured), GBIF records with high `coordinateUncertaintyInMeters` | Normal use; document the obscuring |
| **T2 — Sensitive** | Precise locations of a sensitive species | Any unobscured puma detection, den or kill-site location | Never published at native precision |
| **T3 — Restricted** | Partner data under agreement | Felidae camera / Wildpod station coordinates, detection histories, unpublished model outputs | `data/restricted/` only; never committed; use per written agreement |

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
- [ ] **Station-derived products publish only at open-space-unit level.**
      The station→unit association (unit id, unit name, station count) is the
      publishable form; the underlying coordinate never is. **Watch small-n:**
      a unit with a single station — especially within one sub-region — can
      reverse-narrow a camera location. Suppress or coarsen these.
- [ ] **Check before every commit** that no restricted file has been staged:
      `git status --short` and confirm nothing under `data/restricted/`.

---

## 4. If partner data is used

> **Status (July 27, 2026):** Felidae is deferred to a future phase (Decision 7);
> no Felidae / Wildpod data is held in this repository. This section applies if
> and when any partner data is taken up in a future phase.

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
