# Data Sources

**Project:** Wild Cats at the Urban Edge
**Last updated:** July 27, 2026

> Skeleton. Each entry is completed at download time with: access date, exact
> version, file path, record count, CRS, licence and known issues — matching the
> tiger project format.

---

## 1. Open space and protected areas

### 1.1 CPAD / BPAD — California Protected Areas Database

Primary boundary layer. The authoritative inventory of parks and open space in
California, maintained by GreenInfo Network and published twice yearly. BPAD is
the Bay Area edition, which also incorporates conservation easements from CCED.

- **Chosen source:** statewide **CPAD 2026a** (not the BPAD Bay-Area edition — see note below). Ten-county clip deferred to Week 3.
- **Access (canonical):** https://www.calands.org/ — also listed on data.ca.gov and data.cnra.ca.gov
- **Direct download (2026a zip):** https://data.cnra.ca.gov/dataset/0ae3cd9f-0612-4572-8862-9e9a1c41e659/resource/cadf9163-aa38-44ae-851a-86b35d4c6c0c/download/cpad_2026a_release.zip
  - Note: the *data.cnra.ca.gov* dataset page still lists **2025b** as its resource; the 2026a zip above (linked from data.ca.gov) is current.
- **Version:** CPAD 2026a (statewide release, June 2026)
- **Account required:** No
- **Licence:** Creative Commons Attribution (CC-BY); data.ca.gov states "no restrictions on public use." Attribution required.
- **Downloaded:** July 27, 2026
- **File:** `data/raw/cpad/cpad_2026a_release.zip` (unzipped in place) — gitignored
- **Format / geometry levels:** Esri shapefiles — **Holdings**, **Units**, **SuperUnits** (all three present)
- **Native CRS:** California Albers (EPSG:3310) — confirm on load; matches the analysis CRS, so no reprojection needed
- **Feature counts:** _(fill after running the inspection)_ Holdings _n_ · Units _n_ · SuperUnits _n_

**Geometry levels (which one is used is decided in Week 3):**
- **Holdings** — parcel-level ownership; most detailed attributes
- **Units** — the parks/preserves that Holdings roll up into
- **SuperUnits** — higher aggregation of Units

**CPAD vs BPAD (source decision):** BPAD is GreenInfo's Bay-Area edition covering
exactly the ten counties (nine bay counties + Santa Cruz, the CLN definition)
and it bundles CCED easements — but the latest BPAD is the **2025 edition**,
~1 year staler than CPAD 2026a. Statewide CPAD 2026a was chosen for freshness,
authoritative status and a scriptable download; easements come from CCED (§1.2)
and the ten-county clip is done transparently in Week 3 with the project's own
TIGER/Line boundary. BPAD remains a viable swap if bundled-easement, exact-frame
convenience outweighs freshness.

**Known issues to verify on download:**
- CPAD is an *ownership* inventory, not a habitat or biodiversity inventory —
  inclusion does not imply conservation management.
- Includes urban pocket parks; filtering by size and land cover is required.
- Three geometry levels (Holdings / Units / SuperUnits) — Units or SuperUnits
  are the appropriate analysis level; record which is chosen and why.

### 1.2 CCED — California Conservation Easement Database
Parallel dataset covering easement-protected land, which CPAD excludes.
Relevant because much Bay Area connectivity land is easement-held ranchland.

- **Access (canonical):** https://www.calands.org/cced/ — also on data.ca.gov / data.cnra.ca.gov
- **Direct download (2026a zip):** https://data.cnra.ca.gov/dataset/31b65732-941d-4af0-9d8c-279fac441fd6/resource/2f0b8636-3901-458d-88e0-3a422e3235e8/download/cced_2026a_release.zip
- **Version:** CCED 2026a (June 2026) — matches CPAD 2026a. Note: the data.cnra.ca.gov / lab.data.ca.gov pages still list 2025b; the 2026a zip above (linked from data.ca.gov) is current.
- **Account required:** No
- **Licence:** Creative Commons Attribution (CC-BY); data.ca.gov states "no restrictions on public use." Attribution required.
- **Downloaded:** July 27, 2026
- **File:** `data/raw/cced/cced_2026a_release.zip` (unzipped in place) — gitignored
- **Format:** single Esri shapefile (easement polygons) + CCED Database Manual — one layer, no Holdings/Units/SuperUnits hierarchy
- **Native CRS:** California Albers (EPSG:3310) — confirm on load; matches analysis CRS
- **Feature count:** 23,645 easement polygons (statewide, 2026a)

**Known issues:**
- **"Incomplete" disclaimer is largely historical (quantified — Decision 9).**
  In 2026a, California Rangeland Trust is the 2nd-largest holder (1,865 easements)
  and CDFW the 4th (988) — both well-represented. CCED is used as-is, not
  supplemented: NCED can't fill it (CCED is its California feed) and remaining
  gaps are partly privacy-withheld. Treat easement absence as "not necessarily
  unprotected." Attribute caveat: ~27% of easements (6,363) have an "Unknown"
  holder — geometry present, still valid as easement extent; only matters for
  by-holder analysis.
- **Planning/assessment use only** — not a basis for regulatory or legal action;
  county recorder records are authoritative for individual easements.
- Easements sit mostly on private land; apply the same publication care as other
  layers and honour the GreenInfo data disclaimer.

### 1.3 Study-area boundary — TIGER/Line counties (via `tigris`)
The ten-county clip frame for every other layer — it defines the study extent
(Decision 2), not a substantive dataset.

- **Source:** US Census Bureau TIGER/Line, pulled with
  `tigris::counties("CA", cb = TRUE)`
- **Vintage:** 2024 — pinned in `scripts/01_download_open_data.R` (`tigris_year`)
  for reproducibility; bump deliberately
- **Boundary type:** cartographic (`cb = TRUE`) — generalized, clipped to
  shoreline (land study area). `cb = FALSE` gives full legal boundaries including
  bay/ocean water.
- **Licence:** public domain (US Census)
- **CRS:** reprojected to EPSG:3310 on import
- **Output (gitignored):** `data/interim/boundary_baycounties_3310.gpkg`
  (10 county polygons: `county`, `geoid`) and
  `data/interim/boundary_baydissolved_3310.gpkg` (single study-area outline /
  clip mask)
- **Counties (10):** Alameda, Contra Costa, Marin, Napa, San Francisco,
  San Mateo, Santa Clara, Santa Cruz, Solano, Sonoma
- **Downloaded:** July 27, 2026

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
