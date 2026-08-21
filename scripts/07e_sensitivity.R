# =============================================================================
# 07e_sensitivity.R — Decision-26 pre-registered corridor sensitivity checks
#
# Runs the three pre-registered sensitivity checks as one-at-a-time (OAT)
# perturbations of the resistance surface, judged on CORRIDOR STABILITY — not by
# tuning the surface. Method follows the least-cost uncertainty-analysis lineage
# (Beier, Majka & Newell 2009; Rayfield, Fortin & Fall 2010; Marrec et al. 2020):
# perturb one uncertain parameter across its PLAUSIBLE RANGE, re-extract the
# corridor, and report overlap. A perturbation that does not touch the high-
# resistance cells that pin the corridor is expected to leave it stable (Marrec:
# concordance is highest among high-value cells).
#
# Checks (all vs the corrected baseline; Decision 34 AADT already in the traffic
# layer, so every variant shares the SAME corrected road resistance — the only
# thing that differs per variant is the ONE perturbed parameter):
#   (1) Road-confidence — re-run here for a consistent table (already STABLE via
#       the Decision-34 v1/v2 comparison). Variant: drop aadt_conf=0 barrier cells
#       (spatial_fill/modelled) to R_land, i.e. trust only station-traceable AADT.
#   (2) Chaparral (Decision 12) — LC_RESIST["shrub"] 10 -> 5 (= tree). Plausible-
#       range bound on WorldCover shrub under-mapping: if the missed shrub is
#       really chaparral pumas treat like cover, 5 is the bound.
#   (3) Weight perturbation — gHM/LC split ±10% RELATIVE, opposite directions,
#       slope fixed, renormalised to sum 1. A plausible-range bound on the expert
#       prior (Decision 26 weights have no collar-data fit), NOT a tuning loop.
#       Two bounds: gHM-heavy and LC-heavy.
#
# Everything except the perturbed parameter is IDENTICAL to 04c — build_resistance()
# below IS the 04c assignment, parameterised, so no variant can drift from the
# baseline logic.
#
# Outputs:
#   outputs/tables/tbl_22_corridor_sensitivity.csv     (all checks, one row each)
#   outputs/figures/fig_21_sensitivity_overlay.png
#   (intermediate variant surfaces are NOT written to disk — in-memory only;
#    they are diagnostic, not deliverables, and must not be mistaken for the
#    Decision-26 baseline surface.)
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")
library(sf); library(terra); library(tidyverse); library(leastcostpath)

# =============================================================================
# A. build_resistance() — parameterised 04c (Decision 26 assignment EXACTLY)
# -----------------------------------------------------------------------------
# Args are the ONLY things a sensitivity variant may change. Defaults reproduce
# the Decision-26 baseline bit-for-bit. Returns the 1 km resistance SpatRaster.
# =============================================================================
build_resistance <- function(lc_resist = c(tree=5, shrub=10, grass=25, wetland=40,
                                           crop=55, bare=60, water=90, built=95),
                             w_ghm = 0.45, w_lc = 0.40, w_slope = 0.15,
                             drop_lowconf_road = FALSE) {
  stopifnot(abs(w_ghm + w_lc + w_slope - 1) < 1e-6)

  grid_r     <- terra::rast(file.path(PATH$interim, "grid_puma_1km_3310.tif"))
  stack_sf   <- read_layer(file.path(PATH$interim, "stack_puma_grid_1km_3310.gpkg"))
  traffic_sf <- read_layer(file.path(PATH$interim, "cov_roads_traffic_3310.gpkg"))

  d <- sf::st_drop_geometry(stack_sf)
  # r_ghm convex
  r_ghm <- 1 + 99 * (d$ghm ^ 2)
  # r_lc fraction-weighted per-class
  lc_cols <- paste0("lc_frac_", names(lc_resist))
  lc_mat  <- as.matrix(d[, lc_cols]); lc_mat[is.na(lc_mat)] <- 0
  r_lc    <- as.numeric(lc_mat %*% lc_resist[names(lc_resist)])
  cov_sum <- rowSums(lc_mat)
  r_lc    <- ifelse(cov_sum > 0, r_lc / cov_sum, NA_real_)
  # r_slope linear to 45
  r_slope <- 1 + 99 * pmin(d$slope_mean, 45) / 45

  R_land <- w_ghm * r_ghm + w_lc * r_lc + w_slope * r_slope
  stack_sf$R_land <- R_land
  stack_sf <- stack_sf[!sf::st_is_empty(stack_sf) & !is.na(stack_sf$R_land), ]
  stack_sf <- sf::st_cast(stack_sf, "POINT", warn = FALSE)
  Rland_r  <- terra::mask(terra::rasterize(terra::vect(stack_sf), grid_r,
                                           field = "R_land"), grid_r)

  # R_road (Decision 26 log-inverse; identical transform)
  aadt_to_rroad <- function(aadt, a_min, a_max) {
    x <- log1p(pmin(pmax(aadt, a_min), a_max))
    lo <- log1p(a_min); hi <- log1p(a_max)
    1 + 99 * (x - lo) / (hi - lo)
  }
  bar <- traffic_sf[traffic_sf$barrier_puma %in% TRUE, ]
  bar <- suppressWarnings(sf::st_collection_extract(bar[!sf::st_is_empty(bar), ], "LINESTRING"))
  bar <- bar[!sf::st_is_empty(bar), ]
  # CHECK 1 variant: drop low-confidence road cells to R_land (trust only
  # station-traceable AADT). measured_route_pm is station-traceable (Decision 34).
  if (drop_lowconf_road) {
    keep <- bar$aadt_source %in% c("measured_route_pm", "measured", "name_fill")
    bar  <- bar[keep, ]
  }
  a_min <- as.numeric(stats::quantile(bar$aadt, 0.01, na.rm = TRUE))
  a_max <- as.numeric(stats::quantile(bar$aadt, 0.99, na.rm = TRUE))
  bar$r_road <- aadt_to_rroad(bar$aadt, a_min, a_max)
  bar <- bar[is.finite(bar$r_road), ]
  Rroad_r <- terra::mask(terra::rasterize(terra::vect(bar), grid_r,
                                          field = "r_road", fun = "max",
                                          background = NA), grid_r)

  # R = max(R_land, R_road)
  R <- terra::app(c(Rland_r, Rroad_r), fun = function(x) max(x, na.rm = TRUE))
  R <- terra::ifel(is.infinite(R), NA, R)
  R <- terra::mask(terra::clamp(R, 1, 100), grid_r)
  names(R) <- "resist_puma"
  R
}

# =============================================================================
# B. extract_corridor() — parameterised 07 Part 3-4 (Decision 33 EXACTLY)
# -----------------------------------------------------------------------------
# Same conductance (1/R, 16-neighbour), same endpoints, same q2/q5 swath. Returns
# the LCP line, the two swath tiers, and the crossing table. In-memory only.
# =============================================================================
extract_corridor <- function(R, core_sf, id_from = 1727L, id_to = 3972L,
                             traffic_sf = NULL) {
  cond_r <- 1 / R; names(cond_r) <- "conductance"
  cs <- leastcostpath::create_cs(cond_r, neighbours = 16, dem = NULL, max_slope = NULL)

  patch_a <- core_sf[core_sf$patch_id == id_from, ]
  patch_b <- core_sf[core_sf$patch_id == id_to, ]
  np <- sf::st_cast(sf::st_nearest_points(sf::st_geometry(patch_a),
                                          sf::st_geometry(patch_b)), "POINT")
  snap <- function(pt) {
    cand <- sf::st_as_sf(terra::as.points(cond_r, na.rm = TRUE))
    sf::st_sf(geometry = sf::st_geometry(cand)[sf::st_nearest_feature(pt, cand)], crs = 3310)
  }
  o <- snap(np[1]); dst <- snap(np[2])

  lcp <- leastcostpath::create_lcp(cs, o, dst, cost_distance = TRUE, check_locations = TRUE)
  lcp <- sf::st_transform(lcp, 3310)

  cc <- leastcostpath::create_cost_corridor(cs, o, dst, rescale = FALSE)
  ccv <- terra::values(cc, na.rm = TRUE)
  thr2 <- as.numeric(stats::quantile(ccv, 0.02))
  thr5 <- as.numeric(stats::quantile(ccv, 0.05))
  band <- function(thr, tier) {
    m <- terra::ifel(cc <= thr, 1L, NA)
    p <- sf::st_as_sf(terra::as.polygons(m, dissolve = TRUE))
    p <- suppressWarnings(sf::st_collection_extract(sf::st_make_valid(p), "POLYGON"))
    p <- sf::st_sf(geometry = sf::st_union(p)); sf::st_crs(p) <- 3310
    p$tier <- tier; p
  }
  sw <- rbind(band(thr2, "core"), band(thr5, "context"))

  list(lcp = lcp, swath = sw, cc = cc,
       len_km = as.numeric(sf::st_length(lcp)) / 1000)
}

# =============================================================================
# C. Stability metrics vs baseline (same as sensitivity check 1)
# =============================================================================
corridor_stability <- function(base, var) {
  # LCP separation
  p <- sf::st_cast(sf::st_line_sample(sf::st_union(var$lcp), density = 1/500), "POINT")
  dsep <- as.numeric(sf::st_distance(p, sf::st_union(base$lcp)))
  # swath IoU per tier
  iou <- function(tier) {
    a <- sf::st_geometry(base$swath[base$swath$tier == tier, ])
    b <- sf::st_geometry(var$swath[var$swath$tier == tier, ])
    if (length(a) == 0 || length(b) == 0) return(NA_real_)
    i <- as.numeric(sf::st_area(sf::st_intersection(a, b)))
    ua <- as.numeric(sf::st_area(a)); ub <- as.numeric(sf::st_area(b))
    i / (ua + ub - i)
  }
  data.frame(
    lcp_len_km      = round(var$len_km, 2),
    lcp_mean_sep_m  = round(mean(dsep)),
    lcp_max_sep_m   = round(max(dsep)),
    core_iou        = round(iou("core"), 3),
    context_iou     = round(iou("context"), 3)
  )
}

# =============================================================================
# D. Run baseline + the three checks
# =============================================================================
core_sf    <- read_layer(file.path(PATH$processed, "lcp_puma_core_patches_3310.gpkg"))

message("== Building baseline resistance (Decision 26 defaults) ==")
R_base   <- build_resistance()
cor_base <- extract_corridor(R_base, core_sf)
message(sprintf("baseline LCP: %.2f km", cor_base$len_km))

variants <- list(
  chk1_road_conf = list(
    label = "1: road-confidence (drop low-conf AADT to R_land)",
    R = function() build_resistance(drop_lowconf_road = TRUE)),
  chk2_chaparral = list(
    label = "2: chaparral (shrub resistance 10->5=tree)",
    R = function() build_resistance(
          lc_resist = c(tree=5, shrub=5, grass=25, wetland=40,
                        crop=55, bare=60, water=90, built=95))),
  chk3_ghm_heavy = list(
    label = "3a: weights gHM-heavy (+10% gHM / -10% LC, renorm)",
    R = function() { w <- c(0.45*1.10, 0.40*0.90, 0.15); w <- w/sum(w)
          build_resistance(w_ghm=w[1], w_lc=w[2], w_slope=w[3]) }),
  chk3_lc_heavy = list(
    label = "3b: weights LC-heavy (-10% gHM / +10% LC, renorm)",
    R = function() { w <- c(0.45*0.90, 0.40*1.10, 0.15); w <- w/sum(w)
          build_resistance(w_ghm=w[1], w_lc=w[2], w_slope=w[3]) })
)

rows <- list()
cors <- list()
for (nm in names(variants)) {
  message(sprintf("\n== Sensitivity %s ==", variants[[nm]]$label))
  Rv  <- variants[[nm]]$R()
  cv  <- extract_corridor(Rv, core_sf)
  st  <- corridor_stability(cor_base, cv)
  st$check <- variants[[nm]]$label
  rows[[nm]] <- st
  cors[[nm]] <- cv
  message(sprintf("  LCP %.2f km | mean sep %.0f m | core IoU %.3f | context IoU %.3f",
                  st$lcp_len_km, st$lcp_mean_sep_m, st$core_iou, st$context_iou))
}

sens_tbl <- dplyr::bind_rows(rows) |>
  dplyr::select(check, lcp_len_km, lcp_mean_sep_m, lcp_max_sep_m, core_iou, context_iou)
sens_tbl <- rbind(
  data.frame(check = "baseline (Decision 26)", lcp_len_km = round(cor_base$len_km,2),
             lcp_mean_sep_m = 0, lcp_max_sep_m = 0, core_iou = 1, context_iou = 1),
  sens_tbl)
write.csv(sens_tbl, file.path(PATH$tables, "tbl_22_corridor_sensitivity.csv"), row.names = FALSE)
message("\n== Corridor sensitivity summary (tbl_22) ==")
print(sens_tbl, row.names = FALSE)

# verdict guidance (qualitative + raw metrics, per Decision 33 recording choice):
# STABLE if every variant keeps context IoU high and LCP mean separation small.
worst_iou <- min(sens_tbl$context_iou, na.rm = TRUE)
worst_sep <- max(sens_tbl$lcp_mean_sep_m, na.rm = TRUE)
message(sprintf("\nWorst context IoU across checks: %.3f | worst mean LCP sep: %.0f m",
                worst_iou, worst_sep))
message("Judge qualitatively (Decision 33): high IoU + small separation across all")
message("three checks => corridors ROBUST to the known data limitations.")

# =============================================================================
# E. Overlay figure — baseline LCP + each variant LCP
# =============================================================================
png(file.path(PATH$figures, "fig_21_sensitivity_overlay.png"),
    width = 1200, height = 1000, res = 150)
plot(sf::st_geometry(cor_base$swath[cor_base$swath$tier=="context",]),
     col = "#eeeeee", border = NA,
     main = "Corridor sensitivity: baseline vs 3 pre-registered checks")
plot(sf::st_geometry(cor_base$lcp), col = "black", lwd = 3, add = TRUE)
cols <- c(chk1_road_conf="#1f78b4", chk2_chaparral="#33a02c",
          chk3_ghm_heavy="#e31a1c", chk3_lc_heavy="#ff7f00")
for (nm in names(cors)) plot(sf::st_geometry(cors[[nm]]$lcp),
                             col = cols[nm], lwd = 1.5, lty = 2, add = TRUE)
legend("topright", bty = "n",
       legend = c("baseline", variants$chk1_road_conf$label,
                  variants$chk2_chaparral$label, variants$chk3_ghm_heavy$label,
                  variants$chk3_lc_heavy$label),
       col = c("black", cols), lwd = c(3,1.5,1.5,1.5,1.5), lty = c(1,2,2,2,2), cex = 0.7)
dev.off()
message("\nWrote outputs/figures/fig_21_sensitivity_overlay.png")

message("\n================ 07e_sensitivity.R complete ================")
message("Three pre-registered Decision-26 sensitivity checks run on corridor stability.")
message("Record the verdict as a numbered Decision (35) from tbl_22.")
