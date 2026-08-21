# =============================================================================
# 06_occupancy_models.R
# Week 7 — Bobcat COVARIATE occupancy modelling (the inferential step the Week-4
# gate (03a) and the Week-5/6 null fit (04e) were building toward). Bobcat only;
# puma is connectivity/SDM by design (Decision 3, Decision 22 is bobcat-only).
#
# This is the ONE Week-7 fitting script. It runs the whole chain:
#   PART 1  Load detection histories + occupancy covariate stack; align sites.
#   PART 2  DETECTION sub-model (p): pre-registered candidate set, psi held ~1.
#   PART 3  COLLINEARITY + scaling screen on the psi design matrix (VIF manual +
#           usdm, cross-checked) BEFORE the psi fit.
#   PART 4  OCCUPANCY sub-model (psi): pre-registered nested candidate set, best
#           detection structure carried forward; AICc rank + model averaging.
#   PART 5  FORWARD CHECK (Decision 22 commitment): covariate-model collapsed
#           4-period MB-GOF c-hat must decline substantially from the null 8.9.
#   PART 6  psi PREDICTION surface, keyed unit_id (occu_ theme).
#   PART 7  DESCRIPTIVE CROSS-READ: fitted psi vs Week-6 Gi* hot units + KDE peaks.
#
# ---------------------------------------------------------------------------
# PRE-REGISTRATION (fixed BEFORE any fitted value was seen — the load-bearing
# discipline, same as the KDE bandwidth rule (Decision 28) and the resistance
# weights (Decision 26)). Recorded here so the model set and selection rule are
# auditable and not a post-hoc pick.
#
# Primary history : mammal_precise  (3A target-group-correct, precise detections;
#                   Decision 22 close). The other three histories (mammal_all,
#                   vertebrate_precise, vertebrate_all) are the SENSITIVITY set.
#
# DETECTION covariate set (p), psi held at ~1, standard unmarked order:
#   eff_nrec_s = scale(log1p(eff_nrec))   per-occasion observer-intensity proxy
#                (GRADED effort from 03b; log1p chosen from the observed deciles —
#                 3A: 1/1/1/1/2/3/4/6/10/21/1238, heavy right skew — and the
#                 skew-then-transform citizen-science literature; log1p matches
#                 the project's housing convention, Decision 16). CAVEAT: this is
#                 BACKGROUND vertebrate/mammal volume, an observer-intensity proxy,
#                 NOT bobcat survey effort. Carry the caveat wherever the eff_nrec
#                 coefficient is read. It also assumes diminishing returns (log
#                 shape); if the forward check (PART 5) fails, this functional form
#                 is a pre-named candidate cause (Decision 22).
#   year_s     = scale(year)              occasion-level linear time term (year is
#                                         not skewed; no transform)
#   Candidate set (nested):
#     p0: ~1              p1: ~eff_nrec_s
#     p2: ~year_s         p3: ~eff_nrec_s + year_s
#   Rule: carry the best-AICc detection structure to the psi stage.
#
# OCCUPANCY covariate set (psi), detection structure fixed from PART 2:
#   Continuous (all centred/scaled on the model matrix):
#     elev_mean, slope_mean, aspect_north, aspect_east, ghm_mean,
#     housing_logden_mean, lc_frac_tree, lc_frac_grass
#     - lc_frac_shrub EXCLUDED (Decision 12: WorldCover under-maps CA shrub ~26x;
#       chaparral folds into tree/grass — the covariate is unreliable). Stated,
#       not silent.
#     - gHM AND housing BOTH kept (Decision 23: unit-grain r=0.07 PLA artifact,
#       not collinear at this grain). Re-confirmed on the actual matrix in PART 3.
#       Housing = edge/matrix pressure around the unit, NOT housing within it
#       (Decision 16 PLA) — carry that reading wherever its coefficient is read.
#   Flag:
#     spans_gradient (logical -> factor): large units whose whole-unit means hide
#       within-unit heterogeneity (Decision 17).
#   Candidate psi set (nested, ecologically grouped — NOT all-subsets dredge):
#     m0        : ~1
#     m_terrain : ~elev_mean + slope_mean + aspect_north + aspect_east
#     m_land    : ~lc_frac_tree + lc_frac_grass
#     m_human   : ~ghm_mean + housing_logden_mean
#     m_habitat : terrain + land
#     m_full    : terrain + land + human
#     m_fullgrad: m_full + spans_gradient
#   Selection: AICc ranking (AICcmodavg::aictab); MODEL-AVERAGE the psi predictions
#     across the delta-AICc <= 2 confidence set (modavgPred) for the psi surface.
#
# FORWARD CHECK (Decision 22): refit the AICc-best covariate model on the SAME
#   4-period collapse used for the null, run mb.gof.test, compare c-hat to the
#   null 8.9. A substantial decline = the heterogeneity was real modelled signal.
#   NO decline = a genuine lack-of-fit to diagnose here (pre-named causes:
#   unmodelled spatial autocorrelation, detection covariates, effort-structure
#   bias); report c-hat-inflated SEs. Declared check, not a post-hoc rescue.
#
# ---------------------------------------------------------------------------
# Inputs (EPSG:3310):
#   data/interim/dh_bobc_{mammal,vertebrate}_{precise,all}_3310.rds  (unit x year)
#   data/interim/cov_effort_gbif_mammal_unityear_3310.gpkg     (3A; eff_nrec, yr)
#   data/interim/cov_effort_gbif_vertebrate_unityear_3310.gpkg (3B; eff_nrec, yr)
#   data/interim/stack_occu_units_3310.gpkg                    (per-unit covariates)
#   data/processed/hot_bobc_gistar_unit_3310.gpkg             (Week-6 Gi*)
#   outputs/tables/stats_bobc_unit_3310.csv                   (Week-6 KDE/naive)
#
# Outputs:
#   outputs/models/bobc_occu_det_<model>_<date>.rds           (detection fits)
#   outputs/models/bobc_occu_psi_<model>_<date>.rds           (occupancy fits)
#   outputs/tables/tbl_11_detection_selection.csv             (p AICc table)
#   outputs/tables/tbl_12_collinearity_screen.csv             (VIF + correlation)
#   outputs/tables/tbl_13_occupancy_selection.csv             (psi AICc table)
#   outputs/tables/tbl_14_forward_check_chat.csv              (c-hat vs 8.9)
#   outputs/tables/tbl_15_psi_gistar_kde_crossread.csv        (Q5 cross-read)
#   data/processed/occu_bobc_pred_unit_3310.gpkg              (psi surface, unit_id)
#   outputs/tables/tbl_16_sensitivity_histories.csv           (4-history summary)
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(unmarked)
})

# renv note: unmarked, AICcmodavg (mb.gof.test / aictab / modavgPred) and usdm
# (vifstep) are all in renv.lock (00_setup_environment.R). Fail loudly if not.
for (pkg in c("AICcmodavg", "usdm")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(pkg, " not installed. Run renv::install('", pkg,
         "'); renv::snapshot().", call. = FALSE)
  }
}

rule <- function(txt) cat("\n", strrep("=", 78), "\n", txt, "\n",
                          strrep("=", 78), "\n", sep = "")

DATE_TAG <- format(Sys.Date(), "%Y%m%d")
YEARS    <- 2010:2026                                # 17 occasions (Decision 22)
GOF_NSIM <- 1000                                     # MB-GOF bootstrap (matches 04e)
NULL_CHAT <- 8.9                                     # pre-registered null baseline

histories <- c("mammal_precise", "mammal_all",
               "vertebrate_precise", "vertebrate_all")
PRIMARY   <- "mammal_precise"

# background used by each history (for the matching effort/eff_nrec layer)
bg_of <- function(nm) if (grepl("mammal", nm)) "mammal" else "vertebrate"

# =============================================================================
# PART 1 — LOAD + ALIGN
# =============================================================================
rule("PART 1 — load detection histories, effort (eff_nrec), covariate stack")

# ---- occupancy covariate stack (per unit) ----------------------------------
stack_sf <- read_layer(file.path(PATH$interim, "stack_occu_units_3310.gpkg"))
stopifnot("unit_id" %in% names(stack_sf))
stack_df <- sf::st_drop_geometry(stack_sf)

# Pre-registered psi covariates. lc_frac names are NOT fully enumerated in the
# docs (only tree/shrub/grass are named); read what is actually present and guard
# the two we use by name rather than guessing the full 8-class set.
lc_present <- grep("^lc_frac_", names(stack_df), value = TRUE)
cat("lc_frac columns present in the stack:\n  ",
    paste(lc_present, collapse = ", "), "\n")

PSI_CONT <- c("elev_mean", "slope_mean", "aspect_north", "aspect_east",
              "ghm_mean", "housing_logden_mean",
              "lc_frac_tree", "lc_frac_grass")   # lc_frac_shrub EXCLUDED (Decision 12)
PSI_FLAG <- "spans_gradient"

miss <- setdiff(c(PSI_CONT, PSI_FLAG, "unit_id"), names(stack_df))
if (length(miss)) {
  stop("Occupancy stack is missing expected column(s): ",
       paste(miss, collapse = ", "),
       "\n  -> verify stack_occu_units_3310.gpkg field names before fitting ",
       "(read-before-write; do not rename silently).", call. = FALSE)
}
if (!"lc_frac_shrub" %in% lc_present) {
  cat("NOTE: lc_frac_shrub not present; nothing to exclude — proceeding.\n")
} else {
  cat("lc_frac_shrub present and EXCLUDED from the psi set (Decision 12).\n")
}

# =============================================================================
# HELPER — assemble an unmarkedFrameOccu for one history
# =============================================================================
# Returns the umf plus the site order (unit_id), the scaling centres/scales used
# (so the prediction grid is transformed identically), and per-occasion year.
build_umf <- function(nm) {
  # ---- detection history (unit x year, 1/0/NA) -----------------------------
  mat <- readRDS(file.path(PATH$interim, sprintf("dh_bobc_%s_3310.rds", nm)))
  yrs <- as.integer(colnames(mat))
  stopifnot(identical(yrs, YEARS))                 # occasion order must be fixed

  # ---- per-occasion effort intensity (eff_nrec), unit x year ---------------
  eff_path <- file.path(PATH$interim,
                        sprintf("cov_effort_gbif_%s_unityear_3310.gpkg", bg_of(nm)))
  eff <- sf::st_drop_geometry(read_layer(eff_path))
  stopifnot(all(c("unit_id", "yr", "eff_nrec") %in% names(eff)))

  # widen eff_nrec to a unit x year matrix aligned to `mat` (NA where unsurveyed).
  # Detected-but-background-missed cells (Decision 27) exist in `mat` as 1 with no
  # eff row; give them eff_nrec = 1 (a detection implies >=1 observation of effort)
  # so the covariate is defined wherever y is non-NA. Recorded, not silent.
  eff_wide <- eff |>
    dplyr::filter(yr %in% YEARS) |>
    dplyr::distinct(unit_id, yr, eff_nrec) |>
    tidyr::pivot_wider(names_from = yr, values_from = eff_nrec) |>
    dplyr::right_join(data.frame(unit_id = as.integer(rownames(mat))),
                      by = "unit_id") |>
    dplyr::arrange(match(unit_id, as.integer(rownames(mat))))
  # ensure all YEARS columns exist, ordered
  for (y in YEARS) if (!as.character(y) %in% names(eff_wide))
    eff_wide[[as.character(y)]] <- NA_real_
  eff_mat <- as.matrix(eff_wide[, as.character(YEARS)])
  rownames(eff_mat) <- eff_wide$unit_id

  # Decision-27 backfill: y non-NA but eff_nrec NA -> set 1 (implies >=1 effort)
  d27 <- which(!is.na(mat) & is.na(eff_mat))
  if (length(d27)) {
    eff_mat[d27] <- 1
    cat(sprintf("  [%s] eff_nrec backfilled to 1 on %d detected/surveyed cells ",
                nm, length(d27)),
        "with no background eff row (Decision 27 — detection implies effort)\n")
  }

  # ---- transform: log1p then scale on the observed (non-NA) cells ----------
  # scaling on the assembled matrix so mean/sd reflect the model matrix, not the
  # raw layer. Store centre/scale (unused downstream for detection, but recorded).
  eff_log <- log1p(eff_mat)
  eff_center <- mean(eff_log, na.rm = TRUE)
  eff_scale  <- sd(eff_log,   na.rm = TRUE)
  eff_nrec_s <- (eff_log - eff_center) / eff_scale

  # ---- per-occasion year term (occasion-level, same across sites) ----------
  yr_row     <- YEARS
  yr_center  <- mean(yr_row)
  yr_scale   <- sd(yr_row)
  yr_s_row   <- (yr_row - yr_center) / yr_scale
  year_s     <- matrix(yr_s_row, nrow = nrow(mat), ncol = length(YEARS),
                       byrow = TRUE)
  rownames(year_s) <- rownames(mat)

  # ---- site covariates: join the occupancy stack by unit_id ----------------
  site_ids <- as.integer(rownames(mat))
  site_cov <- data.frame(unit_id = site_ids) |>
    dplyr::left_join(stack_df[, c("unit_id", PSI_CONT, PSI_FLAG)], by = "unit_id")

  # keep only sites present in the stack (should be all; flag if not)
  n_nostack <- sum(is.na(site_cov$elev_mean))
  if (n_nostack > 0) {
    cat(sprintf("  [%s] WARNING: %d history sites have no covariate stack row ",
                nm, n_nostack),
        "-> dropped from the fit (cannot model psi without covariates)\n")
  }
  keep <- !is.na(site_cov$elev_mean) & rowSums(!is.na(mat)) > 0
  mat        <- mat[keep, , drop = FALSE]
  eff_nrec_s <- eff_nrec_s[keep, , drop = FALSE]
  year_s     <- year_s[keep, , drop = FALSE]
  site_cov   <- site_cov[keep, , drop = FALSE]

  # scale the continuous SITE covariates (centre/scale, store for prediction)
  sc_center <- sapply(site_cov[PSI_CONT], mean, na.rm = TRUE)
  sc_scale  <- sapply(site_cov[PSI_CONT], sd,   na.rm = TRUE)
  site_scaled <- site_cov
  for (v in PSI_CONT)
    site_scaled[[v]] <- (site_cov[[v]] - sc_center[v]) / sc_scale[v]
  site_scaled[[PSI_FLAG]] <- factor(site_cov[[PSI_FLAG]])   # logical -> factor

  umf <- unmarked::unmarkedFrameOccu(
    y       = mat,
    siteCovs = site_scaled[, c(PSI_CONT, PSI_FLAG)],
    obsCovs  = list(eff_nrec_s = eff_nrec_s, year_s = year_s)
  )

  list(umf = umf, unit_id = site_cov$unit_id,
       site_center = sc_center, site_scale = sc_scale,
       raw_site = site_cov,
       y_mat = mat, eff_nrec_s = eff_nrec_s, year_s = year_s)
}

# build the primary umf now; sensitivity umfs built in PART 8
prim <- build_umf(PRIMARY)
umf  <- prim$umf
cat(sprintf("\nPrimary history '%s': %d sites x %d occasions in the fit.\n",
            PRIMARY, numSites(umf), ncol(getY(umf))))

# =============================================================================
# PART 2 — DETECTION SUB-MODEL (p), psi held at ~1
# =============================================================================
rule("PART 2 — detection sub-model (pre-registered set; psi ~1)")

det_models <- list(
  p0 = stats::as.formula("~1            ~1"),
  p1 = stats::as.formula("~eff_nrec_s   ~1"),
  p2 = stats::as.formula("~year_s       ~1"),
  p3 = stats::as.formula("~eff_nrec_s + year_s ~1")
)

fit_one <- function(f) tryCatch(unmarked::occu(f, data = umf),
                                error = function(e) e)
det_fits <- lapply(det_models, fit_one)

det_ok <- !vapply(det_fits, inherits, logical(1), "error")
if (any(!det_ok))
  for (nm in names(det_fits)[!det_ok])
    cat("  detection model", nm, "FAILED:",
        conditionMessage(det_fits[[nm]]), "\n")
det_fits <- det_fits[det_ok]

for (nm in names(det_fits))
  saveRDS(det_fits[[nm]],
          file.path(PATH$models,
                    sprintf("bobc_occu_det_%s_%s.rds", nm, DATE_TAG)))

det_ms <- AICcmodavg::aictab(
  cand.set = det_fits, modnames = names(det_fits), second.ord = TRUE)
det_tbl <- as.data.frame(det_ms)
write.csv(det_tbl,
          file.path(PATH$tables, "tbl_11_detection_selection.csv"),
          row.names = FALSE)
cat("Detection AICc table (tbl_11):\n"); print(det_tbl, row.names = FALSE)

best_det_name <- as.character(det_ms$Modnames[1])

# Extract the detection (p) RHS structurally, not by string-splitting a deparse
# (deparse can wrap long formulas across lines). A two-sided occu formula
# ~det ~occ parses as `~`(`~`(det), occ); the detection side is the [[2]][[2]].
det_side_lang <- det_models[[best_det_name]][[2]]        # the ~det sub-formula
det_rhs <- paste(deparse(det_side_lang[[2]]), collapse = " ")  # 'det' terms as text
det_rhs <- trimws(gsub("\\s+", " ", det_rhs))
cat(sprintf("\nBest detection structure by AICc: %s  (p side: ~%s)\n",
            best_det_name, det_rhs))

# =============================================================================
# PART 3 — COLLINEARITY + SCALING SCREEN (before the psi fit)
# =============================================================================
rule("PART 3 — collinearity screen on the psi design matrix (manual VIF + usdm)")

# assemble the SCALED continuous psi design matrix actually entering the fit
X <- as.data.frame(siteCovs(umf))[, PSI_CONT, drop = FALSE]

# ---- Pearson correlation matrix (re-confirm gHM x housing r ~ 0.07) --------
cor_mat <- cor(X, use = "complete.obs")
gh_r <- cor_mat["ghm_mean", "housing_logden_mean"]
cat(sprintf("gHM x housing Pearson r on the model matrix: %.3f  ", gh_r))
cat(if (abs(gh_r) < 0.7) "(< 0.7 — Decision 23 keep-both re-confirmed)\n"
    else "(>= 0.7 — DIVERGES from Decision 23; investigate before proceeding)\n")

# ---- manual VIF via lm(): VIF_j = 1 / (1 - R2_j) ---------------------------
manual_vif <- sapply(names(X), function(v) {
  others <- setdiff(names(X), v)
  form   <- stats::as.formula(paste(v, "~", paste(others, collapse = " + ")))
  r2     <- summary(stats::lm(form, data = X))$r.squared
  1 / (1 - r2)
})

# ---- usdm::vif for cross-check ---------------------------------------------
usdm_vif <- tryCatch({
  v <- usdm::vif(X)                       # data.frame: Variables, VIF
  setNames(v$VIF, v$Variables)[names(X)]
}, error = function(e) setNames(rep(NA_real_, ncol(X)), names(X)))

vif_tbl <- data.frame(
  covariate  = names(X),
  vif_manual = round(as.numeric(manual_vif), 3),
  vif_usdm   = round(as.numeric(usdm_vif), 3),
  row.names  = NULL
)
vif_tbl$agree <- with(vif_tbl,
  ifelse(is.na(vif_usdm), NA,
         abs(vif_manual - vif_usdm) < 0.01))
write.csv(vif_tbl,
          file.path(PATH$tables, "tbl_12_collinearity_screen.csv"),
          row.names = FALSE)
cat("\nVIF (manual lm vs usdm) — tbl_12:\n"); print(vif_tbl, row.names = FALSE)

max_vif <- max(vif_tbl$vif_manual, na.rm = TRUE)
cat(sprintf("\nMax VIF = %.2f  ", max_vif))
if (max_vif >= 5) {
  worst <- vif_tbl$covariate[which.max(vif_tbl$vif_manual)]
  cat(sprintf("(>= 5 — FLAG: '%s' is collinear; drop/keep decision REQUIRED, ",
              worst),
      "record it — do NOT proceed silently)\n")
  warning("VIF >= 5 on the psi design matrix; review tbl_12 before trusting the psi fit.")
} else {
  cat("(< 5 — no collinearity action needed; the pre-registered psi set stands)\n")
}

# =============================================================================
# PART 4 — OCCUPANCY SUB-MODEL (psi), best detection carried forward
# =============================================================================
rule("PART 4 — occupancy sub-model (pre-registered nested set; AICc + averaging)")

det_side <- paste0("~", det_rhs)            # e.g. "~eff_nrec_s + year_s"

psi_rhs <- list(
  m0         = "~1",
  m_terrain  = "~elev_mean + slope_mean + aspect_north + aspect_east",
  m_land     = "~lc_frac_tree + lc_frac_grass",
  m_human    = "~ghm_mean + housing_logden_mean",
  m_habitat  = "~elev_mean + slope_mean + aspect_north + aspect_east + lc_frac_tree + lc_frac_grass",
  m_full     = "~elev_mean + slope_mean + aspect_north + aspect_east + lc_frac_tree + lc_frac_grass + ghm_mean + housing_logden_mean",
  m_fullgrad = "~elev_mean + slope_mean + aspect_north + aspect_east + lc_frac_tree + lc_frac_grass + ghm_mean + housing_logden_mean + spans_gradient"
)

fit_psi <- function(rhs) {
  f <- stats::as.formula(paste(det_side, rhs))
  tryCatch(unmarked::occu(f, data = umf), error = function(e) e)
}
psi_fits <- lapply(psi_rhs, fit_psi)

psi_ok <- !vapply(psi_fits, inherits, logical(1), "error")
if (any(!psi_ok))
  for (nm in names(psi_fits)[!psi_ok])
    cat("  occupancy model", nm, "FAILED:",
        conditionMessage(psi_fits[[nm]]), "\n")
psi_fits <- psi_fits[psi_ok]

for (nm in names(psi_fits))
  saveRDS(psi_fits[[nm]],
          file.path(PATH$models,
                    sprintf("bobc_occu_psi_%s_%s.rds", nm, DATE_TAG)))

psi_ms  <- AICcmodavg::aictab(
  cand.set = psi_fits, modnames = names(psi_fits), second.ord = TRUE)
psi_tbl <- as.data.frame(psi_ms)
write.csv(psi_tbl,
          file.path(PATH$tables, "tbl_13_occupancy_selection.csv"),
          row.names = FALSE)
cat("Occupancy AICc table (tbl_13):\n"); print(psi_tbl, row.names = FALSE)

best_psi_name <- as.character(psi_ms$Modnames[1])
best_psi_fit  <- psi_fits[[best_psi_name]]
cat(sprintf("\nBest occupancy model by AICc: %s\n", best_psi_name))

# confidence set: delta-AICc <= 2 (the pre-registered averaging set)
conf_set <- as.character(psi_ms$Modnames[psi_ms$Delta_AICc <= 2])
cat("Confidence set (delta-AICc <= 2) for model averaging:\n  ",
    paste(conf_set, collapse = ", "), "\n")

# =============================================================================
# PART 5 — FORWARD CHECK: covariate-model c-hat vs the null 8.9 (Decision 22)
# =============================================================================
rule("PART 5 — forward check: collapsed 4-period MB-GOF c-hat vs null 8.9")

# Same 4-period collapse the null used (04e). GOF is run on the AICc-best model
# refit to the collapsed history so the comparison to 8.9 is like-for-like.
PERIODS <- list(`2010-2013` = 2010:2013, `2014-2017` = 2014:2017,
                `2018-2021` = 2018:2021, `2022-2026` = 2022:2026)

collapse_periods <- function(mat) {
  yrs <- as.integer(colnames(mat))
  out <- sapply(PERIODS, function(pr) {
    sub <- mat[, which(yrs %in% pr), drop = FALSE]
    apply(sub, 1, function(r)
      if (all(is.na(r))) NA_integer_
      else if (any(r == 1, na.rm = TRUE)) 1L else 0L)
  })
  rownames(out) <- rownames(mat); out
}
collapse_cov <- function(m) {   # period mean of a per-occasion covariate matrix
  yrs <- YEARS
  out <- sapply(PERIODS, function(pr)
    rowMeans(m[, which(yrs %in% pr), drop = FALSE], na.rm = TRUE))
  out[is.nan(out)] <- NA_real_
  rownames(out) <- rownames(m); out
}

# Collapse the ORIGINAL per-occasion matrices returned by build_umf (site order
# matches siteCovs(umf) and prim$unit_id) — do NOT round-trip through obsCovs(),
# whose long-format row order would transpose on a naive matrix() reshape.
y_mat   <- prim$y_mat
y_c     <- collapse_periods(y_mat)
keep_c  <- rowSums(!is.na(y_c)) > 0
y_c     <- y_c[keep_c, , drop = FALSE]

site_c  <- as.data.frame(siteCovs(umf))[keep_c, , drop = FALSE]
eff_c   <- collapse_cov(prim$eff_nrec_s)[keep_c, , drop = FALSE]
# year term collapses to a per-period constant (row-constant); rebuild cleanly
per_mid   <- sapply(PERIODS, function(pr) mean(pr))
yr_c_row  <- (per_mid - mean(YEARS)) / sd(YEARS)
year_c    <- matrix(yr_c_row, nrow = nrow(y_c), ncol = length(PERIODS),
                    byrow = TRUE)

umf_c <- unmarked::unmarkedFrameOccu(
  y = y_c, siteCovs = site_c,
  obsCovs = list(eff_nrec_s = eff_c, year_s = year_c))

# --- Refit the AICc-best covariate model on the collapsed frame -------------
# IMPORTANT — parboot/mb.gof.test re-evaluate the fitted model's STORED CALL on
# each simulated dataset (that is how the bootstrap works). If occu() is called
# with the namespace prefix and the formula/frame passed as variable NAMES
# (occu(formula = best_form, data = umf_c)), the stored call is
#   unmarked::occu(formula = best_form, data = umf_c)
# and the internal update() fails to resolve those symbols during the bootstrap
# -> "object 'unmarked' not found" (unmarked GitHub issue #92; unmarked-list,
# "this error is due to the way unmarked fits updated models ... required for
# parboot()"). The robust idiom: attach unmarked, call occu() UNPREFIXED, and
# bind the frame to the fixed name the stored call will look up at bootstrap time.
library(unmarked)                                # ensure attached (occu unprefixed)
best_form <- stats::as.formula(paste(det_side, psi_rhs[[best_psi_name]]))

# do.call inlines the literal formula into fit_c@call (rather than the symbol
# `best_form`), so the bootstrap's update() re-evaluates a self-contained call.
# umf_c stays a top-level binding, which source()-ing this script guarantees.
fit_c <- tryCatch(
  do.call(occu, list(formula = best_form, data = quote(umf_c))),
  error = function(e) e)

if (inherits(fit_c, "error")) {
  cat("Collapsed covariate refit FAILED:", conditionMessage(fit_c), "\n")
  cov_chat <- NA_real_; gof_p <- NA_real_; gof_err <- "refit_failed"
} else {
  # parallel = FALSE: parallel bootstrap re-exports the worker environment and is
  # a second known trigger of the not-found error (unmarked-list, parboot cluster
  # thread). Serial is slower but reproducible and error-transparent here.
  gof <- tryCatch(
    AICcmodavg::mb.gof.test(fit_c, nsim = GOF_NSIM, plot.hist = FALSE,
                            parallel = FALSE),
    error = function(e) e)
  if (inherits(gof, "error")) {
    cat("GOF ERROR (surfaced, not swallowed):", conditionMessage(gof), "\n")
    cov_chat <- NA_real_; gof_p <- NA_real_; gof_err <- conditionMessage(gof)
  } else {
    cov_chat <- as.numeric(gof$c.hat.est)
    gof_p    <- as.numeric(gof$p.value)
    gof_err  <- NA_character_
  }
}

declined <- isTRUE(cov_chat < NULL_CHAT)
verdict  <- dplyr::case_when(
  is.na(cov_chat)        ~ "NON_EVALUABLE — collapsed GOF did not return c-hat; diagnose",
  cov_chat < 2           ~ "PASS — c-hat < 2; strong decline, fit good",
  cov_chat < NULL_CHAT   ~ "PASS — c-hat declined substantially from 8.9",
  TRUE                   ~ "FAIL — c-hat did NOT decline; lack-of-fit to diagnose (Decision 22 causes)")

fwd_tbl <- data.frame(
  best_model      = best_psi_name,
  detection_side  = det_side,
  null_chat       = NULL_CHAT,
  covariate_chat  = round(cov_chat, 3),
  gof_p           = round(gof_p, 3),
  chat_declined   = declined,
  gof_error       = gof_err,
  verdict         = verdict,
  stringsAsFactors = FALSE)
write.csv(fwd_tbl,
          file.path(PATH$tables, "tbl_14_forward_check_chat.csv"),
          row.names = FALSE)
cat("Forward check (tbl_14):\n"); print(fwd_tbl, row.names = FALSE)
if (!declined)
  warning("Forward check: covariate-model c-hat did NOT decline from 8.9. ",
          "Report c-hat-inflated SEs and diagnose (Decision 22).")

# =============================================================================
# PART 6 — psi PREDICTION SURFACE (model-averaged over the confidence set)
# =============================================================================
rule("PART 6 — psi prediction surface, keyed unit_id (occu_ theme)")

# newdata = the scaled site covariates for all fitted sites, in fit order
newdat <- as.data.frame(siteCovs(umf))

if (length(conf_set) >= 2) {
  cat("Model-averaging psi across the confidence set:",
      paste(conf_set, collapse = ", "), "\n")
  ma <- tryCatch(
    AICcmodavg::modavgPred(
      cand.set = psi_fits[conf_set], modnames = conf_set,
      newdata = newdat, parm.type = "psi", type = "response"),
    error = function(e) e)
  if (inherits(ma, "error")) {
    cat("modavgPred failed (", conditionMessage(ma),
        ") — falling back to the single AICc-best model.\n")
    pr <- predict(best_psi_fit, type = "state", newdata = newdat)
    psi_hat <- pr$Predicted; psi_se <- pr$SE; psi_src <- best_psi_name
  } else {
    psi_hat <- ma$mod.avg.pred; psi_se <- ma$uncond.se
    psi_src <- paste0("modavg[", paste(conf_set, collapse = "+"), "]")
  }
} else {
  cat("Single model in the confidence set — no averaging; using", best_psi_name, "\n")
  pr <- predict(best_psi_fit, type = "state", newdata = newdat)
  psi_hat <- pr$Predicted; psi_se <- pr$SE; psi_src <- best_psi_name
}

pred_df <- data.frame(unit_id = prim$unit_id,
                      psi_pred = as.numeric(psi_hat),
                      psi_se   = as.numeric(psi_se),
                      psi_src  = psi_src,
                      stringsAsFactors = FALSE)

# attach to unit geometry (all 1,129 units; unmodelled units get NA psi)
pred_sf <- stack_sf[, "unit_id"] |>
  dplyr::left_join(pred_df, by = "unit_id")

pred_path <- file.path(PATH$processed, "occu_bobc_pred_unit_3310.gpkg")
write_layer(pred_sf, pred_path)
cat(sprintf("psi surface: %d units modelled, %d NA (no fit) -> %s\n",
            sum(!is.na(pred_sf$psi_pred)), sum(is.na(pred_sf$psi_pred)),
            pred_path))
cat(sprintf("psi range: %.3f - %.3f (median %.3f)\n",
            min(pred_df$psi_pred), max(pred_df$psi_pred),
            median(pred_df$psi_pred)))

# =============================================================================
# PART 7 — DESCRIPTIVE CROSS-READ: fitted psi vs Week-6 Gi* + KDE
# =============================================================================
rule("PART 7 — cross-read: fitted psi vs Gi* hot units + KDE peaks (Q5)")

hot <- sf::st_drop_geometry(
  read_layer(file.path(PATH$processed, "hot_bobc_gistar_unit_3310.gpkg")))
stats_bobc <- utils::read.csv(
  file.path(PATH$tables, "stats_bobc_unit_3310.csv"))

xread <- pred_df |>
  dplyr::left_join(hot[, c("unit_id", "hotspot", "q5_flag")], by = "unit_id") |>
  dplyr::left_join(stats_bobc[, c("unit_id", "bobc_detected",
                                  intersect(c("kde_mean", "kde_max"),
                                            names(stats_bobc)))],
                   by = "unit_id")

# psi quintile (modelled) vs descriptive hot/cold (Gi*) and KDE
xread$psi_q5 <- dplyr::ntile(xread$psi_pred, 5)

# alignment summary: of Gi* hot units, where do they sit on modelled psi?
hot_units  <- xread |> dplyr::filter(hotspot == "hot")
psi_hi     <- xread |> dplyr::filter(psi_q5 == 5)
n_hot_in_hi <- sum(hot_units$unit_id %in% psi_hi$unit_id)

cat(sprintf("Gi* hot units: %d | in top psi quintile: %d (%.0f%%)\n",
            nrow(hot_units), n_hot_in_hi,
            100 * n_hot_in_hi / max(nrow(hot_units), 1)))
if ("kde_mean" %in% names(xread)) {
  r_kde <- suppressWarnings(cor(xread$psi_pred, xread$kde_mean,
                                use = "complete.obs"))
  cat(sprintf("psi_pred vs KDE mean (Pearson): %.3f\n", r_kde))
}

# Q5 reading: divergence between modelled psi and effort-driven descriptive
# pattern is the signal, not noise — state it (do not smooth over).
cat("\nQ5 cross-read (state divergence, do not correct it):\n")
cat("  - Gi* hot + high psi   -> covariate signal agrees with descriptive cluster\n")
cat("  - Gi* hot + low  psi   -> descriptive hot spot is effort-driven (SUSPECT),",
    "not habitat-driven\n")
cat("  - Gi* cold + high psi  -> habitat predicts bobcats where few were recorded",
    "(under-surveyed, or a genuine gap)\n")

xtab <- as.data.frame(table(psi_q5 = xread$psi_q5,
                            hotspot = xread$hotspot, useNA = "ifany"))
write.csv(xread,
          file.path(PATH$tables, "tbl_15_psi_gistar_kde_crossread.csv"),
          row.names = FALSE)
cat("\npsi-quintile x Gi*-class table:\n"); print(xtab, row.names = FALSE)

# =============================================================================
# PART 8 — SENSITIVITY: refit the best psi model on the other three histories
# =============================================================================
rule("PART 8 — sensitivity: best psi model across all four histories")

sens_rows <- list()
for (nm in histories) {
  b <- tryCatch(build_umf(nm), error = function(e) e)
  if (inherits(b, "error")) {
    cat("  [", nm, "] umf build failed:", conditionMessage(b), "\n")
    next
  }
  f <- stats::as.formula(paste(det_side, psi_rhs[[best_psi_name]]))
  fit <- tryCatch(unmarked::occu(f, data = b$umf), error = function(e) e)
  if (inherits(fit, "error")) {
    cat("  [", nm, "] fit failed:", conditionMessage(fit), "\n"); next
  }
  psi_bar <- mean(predict(fit, type = "state")$Predicted, na.rm = TRUE)
  se_ok   <- all(is.finite(sqrt(diag(vcov(fit)))))
  sens_rows[[nm]] <- data.frame(
    history      = nm,
    background   = ifelse(grepl("mammal", nm), "3A_mammal", "3B_vertebrate"),
    detection_set= ifelse(grepl("precise", nm), "precise", "all_incl_obscured"),
    best_model   = best_psi_name,
    n_sites_fit  = numSites(b$umf),
    mean_psi_pred= round(psi_bar, 3),
    se_finite    = se_ok,
    converged    = isTRUE(fit@opt$convergence == 0),
    stringsAsFactors = FALSE)
}
sens <- dplyr::bind_rows(sens_rows)
write.csv(sens,
          file.path(PATH$tables, "tbl_16_sensitivity_histories.csv"),
          row.names = FALSE)
cat("Sensitivity across histories (tbl_16):\n"); print(sens, row.names = FALSE)

log_stage("occu_bobc", "covariate_fit_complete", numSites(umf))

rule("DONE — 06_occupancy_models.R")
cat("Primary history :", PRIMARY, "\n")
cat("Best detection  :", best_det_name, "(p side", det_side, ")\n")
cat("Best occupancy  :", best_psi_name, "\n")
cat("Forward check   : c-hat", round(cov_chat, 2), "vs null 8.9 ->",
    ifelse(is.na(cov_chat),
           paste0("NON-EVALUABLE (", gof_err, ") — re-run PART 5 after the fix"),
           ifelse(declined, "DECLINED (pass)", "NOT declined (diagnose)")), "\n")
cat("psi surface     :", pred_path, "\n")
cat("\nNEXT (docs): tbl_11..16 + occu_bobc_pred_unit_3310.gpkg into data-dictionary;\n")
cat("  Decision 31 (detection+psi covariate set, selection rule) into methodology\n")
cat("  §6; forward-check outcome + Decision 22 close-out into §5.4/§9; the eff_nrec\n")
cat("  field into the two effort-layer dictionary entries.\n")
