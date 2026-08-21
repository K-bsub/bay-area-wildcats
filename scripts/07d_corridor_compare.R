# =============================================================================
# 07d_corridor_compare.R — Sensitivity check 1 (road-confidence), Decision 26
#
# Quantifies how much the puma corridor moves when US-101 (and the state-highway
# network) carry CORRECTED measured AADT (Decision 34, ~142k at Coyote Valley)
# versus the previous modelled floor (~80k). This IS the pre-registered
# Decision-26 road-confidence sensitivity check: if the corridor is stable, the
# AADT bias was immaterial to the path; if it shifts, that shift is the quantified
# barrier effect. Judged on corridor STABILITY, not by tuning the surface.
#
# WORKFLOW (run in this order):
#   STEP A  — BEFORE re-running 04c/07: archive the current (v1, 80k-modelled)
#             corridor outputs to *_v1_aadt80k so the re-run does not overwrite
#             them. Run STEP A once, then stop.
#   STEP B  — Re-run 04c (resistance, consumes corrected 04b) and 07 Parts 3–4
#             (path/swath/crossings). These overwrite the canonical names with v2.
#   STEP C  — run STEP C of THIS script: load v1 (archived) + v2 (canonical),
#             compute divergence metrics, write the comparison table + figure.
#
# The canonical (unsuffixed) files are the v2 CORRECTED result — that is the real
# deliverable. v1 is retained only as the sensitivity-check baseline.
#
# Outputs (STEP C):
#   outputs/tables/tbl_21_sensitivity1_road_confidence.csv
#   outputs/figures/fig_20_corridor_v1_v2_overlay.png
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")
library(sf); library(terra); library(tidyverse)

# canonical output paths (these hold v2 after the re-run)
f_lcp    <- file.path(PATH$processed, "lcp_puma_scmtns_to_diablo_3310.gpkg")
f_swath  <- file.path(PATH$processed, "lcp_puma_scmtns_to_diablo_swath_3310.gpkg")
f_cc     <- file.path(PATH$rasters,   "lcp_puma_scmtns_to_diablo_costcorr_3310.tif")
f_cross  <- file.path(PATH$processed, "lcp_puma_scmtns_to_diablo_crossings_3310.gpkg")

# v1 archive paths
f_lcp_v1   <- sub("_3310", "_v1_aadt80k_3310", f_lcp)
f_swath_v1 <- sub("_3310", "_v1_aadt80k_3310", f_swath)
f_cc_v1    <- sub("_3310", "_v1_aadt80k_3310", f_cc)
f_cross_v1 <- sub("_3310", "_v1_aadt80k_3310", f_cross)

# -----------------------------------------------------------------------------
# STEP A — archive current (v1) outputs. RUN ONCE, BEFORE re-running 04c/07.
# -----------------------------------------------------------------------------
archive_v1 <- function() {
  pairs <- list(c(f_lcp, f_lcp_v1), c(f_swath, f_swath_v1),
                c(f_cc, f_cc_v1), c(f_cross, f_cross_v1))
  for (p in pairs) {
    if (file.exists(p[1])) {
      file.copy(p[1], p[2], overwrite = TRUE)
      message("archived: ", basename(p[1]), " -> ", basename(p[2]))
    } else message("SKIP (absent): ", basename(p[1]))
  }
  message("STEP A done. Now re-run 04c + 07 Parts 3-4, then run STEP C.")
}

# -----------------------------------------------------------------------------
# STEP C — compare v1 (archived) vs v2 (canonical, post re-run).
# -----------------------------------------------------------------------------
compare_v1_v2 <- function() {
  stopifnot(file.exists(f_lcp_v1), file.exists(f_lcp),
            file.exists(f_swath_v1), file.exists(f_swath),
            file.exists(f_cc_v1), file.exists(f_cc))

  # v1 files predate the CRS stamp; the current v2 swath was also written without
  # a CRS (polygonise_band bug, fixed in 07 going forward). Assign 3310 to any
  # file that reads EPSG:NA — NOT reproject (coords are already 3310).
  read_v1 <- function(f) {
    x <- sf::st_read(f, quiet = TRUE)
    if (is.na(sf::st_crs(x))) sf::st_crs(x) <- 3310
    x
  }

  lcp1 <- read_v1(f_lcp_v1);   lcp2 <- read_v1(f_lcp)
  sw1  <- read_v1(f_swath_v1); sw2  <- read_v1(f_swath)
  cc1  <- terra::rast(f_cc_v1);   cc2  <- terra::rast(f_cc)
  if (is.na(terra::crs(cc1)) || terra::crs(cc1) == "") terra::crs(cc1) <- "EPSG:3310"
  if (is.na(terra::crs(cc2)) || terra::crs(cc2) == "") terra::crs(cc2) <- "EPSG:3310"

  # ---- 1. LCP centre-line divergence -------------------------------------
  # mean + max separation between the two paths (Hausdorff for worst-case,
  # mean nearest-point distance for typical divergence).
  hausdorff_m <- as.numeric(sf::st_distance(
    sf::st_union(lcp1), sf::st_union(lcp2), which = "Hausdorff"))
  # sample points along v2, measure distance to v1
  p2 <- sf::st_line_sample(sf::st_union(lcp2), density = 1/500)  # ~every 500 m
  p2 <- sf::st_cast(p2, "POINT")
  d_pt <- as.numeric(sf::st_distance(p2, sf::st_union(lcp1)))
  len1 <- as.numeric(sf::st_length(lcp1)) / 1000
  len2 <- as.numeric(sf::st_length(lcp2)) / 1000

  # ---- 2. Swath overlap (per tier) ---------------------------------------
  swath_overlap <- function(tier) {
    a <- sf::st_geometry(sw1[sw1$tier == tier, ])
    b <- sf::st_geometry(sw2[sw2$tier == tier, ])
    if (length(a) == 0 || length(b) == 0) return(c(NA, NA, NA))
    inter <- as.numeric(sf::st_area(sf::st_intersection(a, b))) / 1e6
    ua    <- as.numeric(sf::st_area(a)) / 1e6
    ub    <- as.numeric(sf::st_area(b)) / 1e6
    union <- ua + ub - inter
    c(iou = inter / union, frac_v1_kept = inter / ua, frac_v2_new = 1 - inter / ub)
  }
  ov_core <- swath_overlap("core")
  ov_ctx  <- swath_overlap("context")

  # ---- 3. Cost-surface correlation (are the surfaces themselves similar?) --
  # resample v1 onto v2 grid if needed, then Spearman on overlapping cells.
  if (!terra::compareGeom(cc1, cc2, stopOnError = FALSE)) {
    cc1 <- terra::resample(cc1, cc2, method = "bilinear")
  }
  v <- terra::values(c(cc1, cc2), na.rm = TRUE)
  cost_spearman <- suppressWarnings(stats::cor(v[,1], v[,2], method = "spearman",
                                               use = "complete.obs"))

  # ---- 4. Crossing ranking change (did US-101 move to the top?) -----------
  cross_note <- "crossings layer absent"
  if (file.exists(f_cross_v1) && file.exists(f_cross)) {
    c1 <- sf::st_drop_geometry(read_v1(f_cross_v1))
    c2 <- sf::st_drop_geometry(read_v1(f_cross))
    top1 <- if ("aadt" %in% names(c1)) c1$road_label[which.max(c1$aadt)][1] else NA
    # v2 top of the measured tier
    if (all(c("aadt_tier","aadt") %in% names(c2))) {
      m2 <- c2[c2$aadt_tier == "measured_route_pm", ]
      top2 <- m2$road_label[which.max(m2$aadt)][1]
      top2_aadt <- max(m2$aadt, na.rm = TRUE)
    } else { top2 <- NA; top2_aadt <- NA }
    cross_note <- sprintf("v1 top-AADT crossing: %s | v2 top measured crossing: %s (%.0f)",
                          top1, top2, top2_aadt)
  }

  # ---- assemble + write ---------------------------------------------------
  cmp <- data.frame(
    metric = c("lcp_len_v1_km","lcp_len_v2_km","lcp_hausdorff_m",
               "lcp_mean_sep_m","lcp_max_sep_m","lcp_p90_sep_m",
               "core_swath_iou","context_swath_iou",
               "core_frac_v1_kept","context_frac_v1_kept",
               "cost_surface_spearman"),
    value = c(round(len1,2), round(len2,2), round(hausdorff_m),
              round(mean(d_pt)), round(max(d_pt)),
              round(as.numeric(stats::quantile(d_pt,0.9))),
              round(ov_core["iou"],3), round(ov_ctx["iou"],3),
              round(ov_core["frac_v1_kept"],3), round(ov_ctx["frac_v1_kept"],3),
              round(cost_spearman,3))
  )
  write.csv(cmp, file.path(PATH$tables, "tbl_21_sensitivity1_road_confidence.csv"),
            row.names = FALSE)
  message("== Sensitivity check 1 (road-confidence): v1(80k) vs v2(142k) ==")
  print(cmp, row.names = FALSE)
  message(cross_note)

  # verdict guidance (stated, not tuned): high IoU + high cost correlation +
  # small LCP separation => corridor STABLE => AADT bias immaterial to the path.
  verdict <- if (!is.na(ov_ctx["iou"]) && ov_ctx["iou"] >= 0.80 &&
                 cost_spearman >= 0.95 && mean(d_pt) <= 2000)
    "STABLE — corridor robust to the US-101 AADT correction" else
    "SHIFTED — corridor sensitive to US-101 weighting; report the movement"
  message("\nVerdict: ", verdict)

  # ---- overlay figure -----------------------------------------------------
  png(file.path(PATH$figures, "fig_20_corridor_v1_v2_overlay.png"),
      width = 1200, height = 1000, res = 150)
  plot(sf::st_geometry(sw2[sw2$tier=="context",]), col = "#c7e9c022", border = NA,
       main = "Corridor sensitivity: v1 (80k modelled) vs v2 (142k measured US-101)")
  plot(sf::st_geometry(sw1[sw1$tier=="core",]), border = "#1f78b4", col = NA, lwd = 2, add = TRUE)
  plot(sf::st_geometry(sw2[sw2$tier=="core",]), border = "#e31a1c", col = NA, lwd = 2, add = TRUE)
  plot(sf::st_geometry(lcp1), col = "#1f78b4", lwd = 2, lty = 2, add = TRUE)
  plot(sf::st_geometry(lcp2), col = "#e31a1c", lwd = 2, add = TRUE)
  legend("topright", bty = "n",
         legend = c("v1 core (80k)","v2 core (142k)","v1 LCP","v2 LCP"),
         col = c("#1f78b4","#e31a1c","#1f78b4","#e31a1c"),
         lty = c(1,1,2,1), lwd = 2)
  dev.off()
  message("Wrote outputs/figures/fig_20_corridor_v1_v2_overlay.png")
  invisible(cmp)
}

# -----------------------------------------------------------------------------
# Run control — uncomment the step you are on.
# -----------------------------------------------------------------------------
# STEP A (archive v1, BEFORE re-running 04c/07):
# archive_v1()

# STEP C (compare, AFTER re-running 04c/07):
# compare_v1_v2()

message("07d_corridor_compare.R loaded.")
message("  STEP A: run archive_v1()  BEFORE re-running 04c + 07")
message("  STEP C: run compare_v1_v2()  AFTER the re-run")
