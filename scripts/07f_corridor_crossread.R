# =============================================================================
# 07f_corridor_crossread.R — puma Q5 cross-read: modelled corridor vs Week-6
# descriptive pattern (KDE + Gi*). Proposal Q5, puma track.
#
# Parallels the Week-7 bobcat cross-read (psi vs KDE/Gi*, tbl_15) but respects a
# key difference: a CORRIDOR is "where pumas MOVE BETWEEN cores", NOT "where pumas
# ARE". KDE / Gi* measure occurrence concentration. So a naive corridor-vs-KDE
# correlation would conflate two different quantities. Instead, three distinct
# reads:
#   (1) ENDPOINT CHECK — do the two cores (1727, 3972) coincide with KDE peaks /
#       Gi* hot units? (sanity: cores should be where pumas concentrate.)
#   (2) CORRIDOR-vs-PATTERN — does the corridor BETWEEN cores run through high-KDE
#       / hot cells, or through low-occurrence matrix? Either is informative. The
#       Coyote Valley pinch is expected to be LOW KDE (occurrence gap) but HIGH
#       movement importance — the headline Q5 finding: the corridor's most
#       important cell is where the descriptive data is thinnest (structure-driven
#       connectivity vs effort-driven occurrence).
#   (3) Q5 EFFORT — for Gi* hot units the corridor passes through, report their
#       q5_flag (SUSPECT = also effort-hot / TRUSTED = not), so the corridor↔
#       observation relationship carries its effort caveat.
#
# Inputs (EPSG:3310):
#   data/processed/kde_puma_current_1km_3310.tif       (band kde_intensity_puma_precise)
#   data/processed/hot_puma_gistar_unit_3310.gpkg      (gistar_z, hotspot, q5_flag, n_occ)
#   data/processed/lcp_puma_core_patches_3310.gpkg     (endpoints 1727/3972)
#   data/processed/lcp_puma_scmtns_to_diablo_3310.gpkg (LCP)
#   data/processed/lcp_puma_scmtns_to_diablo_swath_3310.gpkg (two-tier swath)
#
# Outputs:
#   outputs/tables/tbl_23_corridor_kde_gistar_crossread.csv
#   outputs/figures/fig_22_corridor_vs_kde.png
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")
library(sf); library(terra); library(tidyverse); library(exactextractr)

# CRS-tolerant reader (some Week-8 lcp_ files were written EPSG:NA pre-fix).
read_any <- function(f) {
  x <- sf::st_read(f, quiet = TRUE)
  if (is.na(sf::st_crs(x))) sf::st_crs(x) <- 3310
  x
}

kde_r   <- terra::rast(file.path(PATH$processed, "kde_puma_current_1km_3310.tif"))
gistar  <- read_layer(file.path(PATH$processed, "hot_puma_gistar_unit_3310.gpkg"))
core_sf <- read_layer(file.path(PATH$processed, "lcp_puma_core_patches_3310.gpkg"))
lcp_sf  <- read_any(file.path(PATH$processed, "lcp_puma_scmtns_to_diablo_3310.gpkg"))
swath   <- read_any(file.path(PATH$processed, "lcp_puma_scmtns_to_diablo_swath_3310.gpkg"))

kde_band <- "kde_intensity_puma_precise"
if (!kde_band %in% names(kde_r)) names(kde_r)[1] <- kde_band
ID_SC <- 1727L; ID_DIA <- 3972L

# KDE reference distribution (land cells) for percentile framing.
kde_vals <- terra::values(kde_r, na.rm = TRUE)
kde_pct  <- function(v) 100 * mean(kde_vals <= v, na.rm = TRUE)   # percentile of a value

# =============================================================================
# (1) ENDPOINT CHECK — cores vs KDE peaks + Gi* hot
# =============================================================================
message("== (1) Endpoint check: do cores coincide with KDE peaks / Gi* hot? ==")
endpoint_row <- function(pid, label) {
  patch <- core_sf[core_sf$patch_id == pid, ]
  kmean <- exactextractr::exact_extract(kde_r, patch, "mean")
  kmax  <- exactextractr::exact_extract(kde_r, patch, "max")
  # Gi* units intersecting the patch
  gi <- gistar[lengths(sf::st_intersects(gistar, patch)) > 0, ]
  n_hot <- sum(gi$hotspot == "hot", na.rm = TRUE)
  n_u   <- nrow(gi)
  data.frame(endpoint = label, patch_id = pid,
             kde_mean = signif(kmean, 3), kde_mean_pctile = round(kde_pct(kmean)),
             kde_max_pctile = round(kde_pct(kmax)),
             gistar_units = n_u, gistar_hot_units = n_hot)
}
ep <- rbind(endpoint_row(ID_SC, "SC Mountains (1727)"),
            endpoint_row(ID_DIA, "S Diablo (3972)"))
print(ep, row.names = FALSE)

# =============================================================================
# (2) CORRIDOR-vs-PATTERN — KDE + Gi* along the LCP and in the swath
# =============================================================================
message("\n== (2) Corridor vs descriptive pattern ==")

# 2a. KDE ALONG THE LCP — sample the centre-line every ~500 m.
pts <- sf::st_cast(sf::st_line_sample(sf::st_union(lcp_sf), density = 1/500), "POINT")
pts <- sf::st_sf(geometry = pts)
pts$kde   <- terra::extract(kde_r, terra::vect(pts))[, 2]
pts$kde_pctile <- sapply(pts$kde, function(v) if (is.na(v)) NA else kde_pct(v))
message(sprintf("LCP KDE percentile: median %.0f, min %.0f, max %.0f (of land cells)",
                stats::median(pts$kde_pctile, na.rm = TRUE),
                min(pts$kde_pctile, na.rm = TRUE), max(pts$kde_pctile, na.rm = TRUE)))
message(sprintf("  LCP length in BELOW-median KDE (matrix): %.0f%%",
                100 * mean(pts$kde_pctile < 50, na.rm = TRUE)))

# 2b. KDE WITHIN the swath tiers — mean percentile per tier.
swath_kde <- function(tier) {
  g <- swath[swath$tier == tier, ]
  if (nrow(g) == 0) return(c(NA, NA))
  m <- exactextractr::exact_extract(kde_r, g, "mean")
  c(mean_kde = m, mean_pctile = kde_pct(m))
}
sk_core <- swath_kde("core"); sk_ctx <- swath_kde("context")
message(sprintf("Swath mean-KDE percentile: core %.0f | context %.0f",
                sk_core[2], sk_ctx[2]))

# 2c. THE COYOTE VALLEY PINCH — verified coord. Expected LOW KDE, HIGH importance.
cv <- sf::st_transform(sf::st_sf(geometry =
        sf::st_sfc(sf::st_point(c(-121.74056, 37.21667)), crs = 4326)), 3310)
cv_kde <- terra::extract(kde_r, terra::vect(cv))[, 2]
# nearest LCP point's KDE percentile as the "pinch on-corridor" value
d_lcp  <- as.numeric(sf::st_distance(cv, sf::st_union(lcp_sf)))
message(sprintf("\nCoyote Valley pinch: KDE = %s (percentile %s), %.1f km from LCP",
                ifelse(is.na(cv_kde), "NA", signif(cv_kde,3)),
                ifelse(is.na(cv_kde), "NA", round(kde_pct(cv_kde))), d_lcp/1000))

# 2d. Gi* hotspot status ALONG the corridor — which units does the swath cross,
# and are they hot / cold / ns?
sw_ctx <- sf::st_geometry(swath[swath$tier == "context", ])
gi_corr <- gistar[lengths(sf::st_intersects(gistar, sw_ctx)) > 0, ]
gi_tab  <- table(factor(gi_corr$hotspot, levels = c("hot","cold","ns")), useNA = "ifany")
message("\nGi* units the context swath crosses, by hotspot class:")
print(gi_tab)

# =============================================================================
# (3) Q5 EFFORT — for corridor Gi* HOT units, are they SUSPECT or TRUSTED?
# =============================================================================
message("\n== (3) Q5 effort read for corridor hot units ==")
gi_hot_corr <- gi_corr[gi_corr$hotspot == "hot", ]
if (nrow(gi_hot_corr)) {
  q5_tab <- table(gi_hot_corr$q5_flag)
  print(q5_tab)
  message(sprintf("  %d hot units on the corridor: %d SUSPECT (effort-hot), %d TRUSTED",
                  nrow(gi_hot_corr),
                  sum(grepl("SUSPECT", gi_hot_corr$q5_flag)),
                  sum(grepl("TRUSTED", gi_hot_corr$q5_flag))))
} else {
  message("  No Gi* hot units on the corridor — the corridor runs through non-hot")
  message("  (matrix / gap) units. This is the divergence signal (see verdict).")
}

# =============================================================================
# Assemble cross-read table + verdict
# =============================================================================
crossread <- data.frame(
  metric = c("SC_endpoint_kde_pctile", "Diablo_endpoint_kde_pctile",
             "SC_endpoint_gistar_hot_units", "Diablo_endpoint_gistar_hot_units",
             "lcp_median_kde_pctile", "lcp_pct_below_median_kde",
             "swath_core_kde_pctile", "swath_context_kde_pctile",
             "coyote_pinch_kde_pctile", "coyote_pinch_km_from_lcp",
             "corridor_gistar_hot_units", "corridor_hot_units_suspect",
             "corridor_hot_units_trusted"),
  value = c(ep$kde_mean_pctile[1], ep$kde_mean_pctile[2],
            ep$gistar_hot_units[1], ep$gistar_hot_units[2],
            round(stats::median(pts$kde_pctile, na.rm = TRUE)),
            round(100 * mean(pts$kde_pctile < 50, na.rm = TRUE)),
            round(sk_core[2]), round(sk_ctx[2]),
            ifelse(is.na(cv_kde), NA, round(kde_pct(cv_kde))),
            round(d_lcp/1000, 1),
            nrow(gi_hot_corr),
            ifelse(nrow(gi_hot_corr), sum(grepl("SUSPECT", gi_hot_corr$q5_flag)), 0),
            ifelse(nrow(gi_hot_corr), sum(grepl("TRUSTED", gi_hot_corr$q5_flag)), 0))
)
write.csv(crossread, file.path(PATH$tables, "tbl_23_corridor_kde_gistar_crossread.csv"),
          row.names = FALSE)
message("\n== tbl_23 corridor × KDE/Gi* cross-read ==")
print(crossread, row.names = FALSE)

# =============================================================================
# Figure — KDE surface + LCP coloured by on-corridor KDE percentile + pinch
# =============================================================================
png(file.path(PATH$figures, "fig_22_corridor_vs_kde.png"),
    width = 1200, height = 1000, res = 150)
terra::plot(kde_r, main = "Puma corridor vs KDE: does the LCP follow observed density?",
            col = grDevices::hcl.colors(100, "YlGnBu", rev = TRUE))
plot(sf::st_geometry(swath[swath$tier=="context",]), border = "grey40", col = NA, add = TRUE)
plot(sf::st_geometry(lcp_sf), col = "red", lwd = 2, add = TRUE)
plot(sf::st_geometry(core_sf[core_sf$patch_id %in% c(ID_SC,ID_DIA),]),
     border = "black", col = NA, lwd = 2, add = TRUE)
plot(sf::st_geometry(cv), col = "magenta", pch = 4, cex = 2, lwd = 3, add = TRUE)
legend("topright", bty="n",
       legend = c("LCP","swath (context)","endpoints","Coyote Valley pinch"),
       col = c("red","grey40","black","magenta"), lwd = c(2,1,2,3),
       pch = c(NA,NA,NA,4))
dev.off()
message("\nWrote outputs/figures/fig_22_corridor_vs_kde.png")

message("\n================ 07f_corridor_crossread.R complete ================")
message("Record the Q5 puma-track finding as a numbered Decision (36) from tbl_23.")
message("Interpretation guide: if the corridor (esp. the pinch) runs through LOW-KDE")
message("units while endpoints are high-KDE, that is the DIVERGENCE finding —")
message("structure-driven connectivity crosses an occurrence GAP that the")
message("effort-shaped descriptive layer under-represents (the puma-track Q5 signal).")
