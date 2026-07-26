# Data Sources

**Project:** Wild Cats at the Urban Edge
**Last updated:** July 26, 2026

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

- **Status:** **deferred to a future phase** (see `docs/methodology.md`
  Decision 7). Not used in Phase 1; no Felidae data is held in this repository.
- **Terms:** requires a written agreement before any use — see
  `docs/sensitive-data-policy.md` §4. Precise station / camera coordinates are
  T3 (restricted): never committed, never published at native precision.
- **Preferred products (if resumed):** derived occupancy surfaces, unit-level
  detection summaries, or published results — **not** raw camera coordinates.
- **Storage (if resumed):** `data/restricted/` only; never committed.

**Noted during initial review, for a future phase:** a Wildpod station
inventory (218 stations; `ID`, `Park`, `Station`, `Area`, coordinates,
elevation) was examined and set aside when Phase 1 moved to a full ten-county
open-data frame. Characteristics for whoever resumes it: `ID` unique, `Station`
not unique; `Park` labels untrusted (include private ranches); sub-regions
Peninsula / East Bay / South Bay plus an out-of-region Los Angeles group to
drop; Latin-1 encoding; 22 null elevations. Open-space identity would be
resolved spatially (staged point-in-polygon / nearest-unit, no blanket buffer),
not from the `Park` label.

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
