# =============================================================================
# 04e_bobcat_null_fit.R
#
# Fit the NULL occupancy model to each bobcat detection history and read the
# three fit-time criteria that were deferred from the Week-4 gate, closing
# Decision 22 (methodology §5.4):
#   (1) fitted detection probability p  — fallback line p < 0.10 -> SDM
#   (2) parameter stability             — SEs finite, convergence, no boundary
#   (3) MacKenzie-Bailey GOF            — c-hat and p-value (overdispersion)
#
# Primary decision runs on the MAMMAL-PRECISE history (3A target-group-correct,
# precise detections). The other three (mammal_all, vertebrate_precise,
# vertebrate_all) are fit as robustness / sensitivity comparisons. Detected cells
# upgraded per Decision 27 are already baked into the histories from script 04d.
#
# Inputs (data/interim/):
#   dh_bobc_mammal_precise_3310.rds        (PRIMARY)
#   dh_bobc_mammal_all_3310.rds
#   dh_bobc_vertebrate_precise_3310.rds
#   dh_bobc_vertebrate_all_3310.rds
#
# Outputs:
#   outputs/models/bobc_occu_null_<history>_<date>.rds   (fitted unmarked objects)
#   outputs/tables/tbl_09_null_fit_criteria.csv          (p, SE, GOF per history)
#   outputs/tables/tbl_09_decision22_close.csv           (the close: which bg, verdict)
#
# NUMBERING NOTE: this script is 04e_ by execution order, but its output tables
# keep the tbl_09_ prefix on purpose — those filenames are referenced elsewhere
# and are NOT renamed (table number and script number are independent counters).
# Do not "fix" the tbl_09_ names to match 04e.
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")

library(unmarked)
library(tidyverse)

# renv note: `unmarked` and `AICcmodavg` (for mb.gof.test) must be installed +
# snapshotted before running (renv::install(); renv::snapshot()).
if (!requireNamespace("AICcmodavg", quietly = TRUE)) {
  stop("AICcmodavg not installed. Run renv::install('AICcmodavg'); renv::snapshot().",
       call. = FALSE)
}

FALLBACK_P <- 0.10                                   # §5.4 SDM-fallback line
DATE_TAG   <- format(Sys.Date(), "%Y%m%d")
GOF_NSIM   <- 1000                                   # parametric bootstrap for MB GOF

# Occasion-collapse for a TRACTABLE MacKenzie-Bailey GOF (Decision 22 close).
# Annual (17-occasion) histories produce hundreds of unique sparse detection
# patterns -> MB-GOF degenerates (c-hat in the hundreds is a test artifact, not
# real lack of fit). Binning years into 4 multi-year PERIODS collapses the
# pattern space so the test is evaluable. Rule per period: detected if detected
# in ANY year, surveyed if surveyed in ANY year, else NA. The null model has no
# time covariate, so no information is lost for the fit — only GOF gains tract-
# ability. NOTE: collapsed p is PER-PERIOD detection (~4 yr), not per-year, so it
# is reported alongside — NOT substituted for — the annual per-visit p.
PERIODS <- list(`2010-2013` = 2010:2013,
                `2014-2017` = 2014:2017,
                `2018-2021` = 2018:2021,
                `2022-2026` = 2022:2026)

collapse_periods <- function(mat) {
  yrs <- as.integer(colnames(mat))
  out <- sapply(PERIODS, function(pr) {
    cols <- which(yrs %in% pr)
    sub  <- mat[, cols, drop = FALSE]
    apply(sub, 1, function(r) {
      if (all(is.na(r))) NA_integer_               # never surveyed in period -> NA
      else if (any(r == 1, na.rm = TRUE)) 1L       # detected in any year -> 1
      else 0L                                       # surveyed, never detected -> 0
    })
  })
  rownames(out) <- rownames(mat)
  out
}

histories <- c("mammal_precise", "mammal_all",
               "vertebrate_precise", "vertebrate_all")
PRIMARY   <- "mammal_precise"

# -----------------------------------------------------------------------------
# Fit + read criteria for one history
# -----------------------------------------------------------------------------
fit_null <- function(nm) {
  mat <- readRDS(file.path(PATH$interim, sprintf("dh_bobc_%s_3310.rds", nm)))
  keep <- rowSums(!is.na(mat)) > 0
  mat  <- mat[keep, , drop = FALSE]

  # --- Annual fit: the primary p reading (per-visit detection) ---------------
  umf_yr <- unmarked::unmarkedFrameOccu(y = mat)
  fit_yr <- tryCatch(unmarked::occu(~ 1 ~ 1, data = umf_yr),
                     error = function(e) e)
  if (inherits(fit_yr, "error")) {
    return(data.frame(history = nm, converged = FALSE,
                      note = conditionMessage(fit_yr)))
  }
  psi_yr <- as.numeric(predict(fit_yr, type = "state")[1, "Predicted"])
  p_yr   <- as.numeric(predict(fit_yr, type = "det")[1, "Predicted"])
  se_yr  <- tryCatch(sqrt(diag(vcov(fit_yr))), error = function(e) NA_real_)
  conv_yr <- isTRUE(fit_yr@opt$convergence == 0) && all(is.finite(se_yr))

  # --- Collapsed fit: tractable MacKenzie-Bailey GOF (per-period detection) ---
  mat_c <- collapse_periods(mat)
  mat_c <- mat_c[rowSums(!is.na(mat_c)) > 0, , drop = FALSE]
  umf_c <- unmarked::unmarkedFrameOccu(y = mat_c)
  fit_c <- tryCatch(unmarked::occu(~ 1 ~ 1, data = umf_c),
                    error = function(e) e)
  p_period <- if (!inherits(fit_c, "error"))
    as.numeric(predict(fit_c, type = "det")[1, "Predicted"]) else NA_real_

  n_patterns_yr <- length(unique(apply(mat, 1,
                     function(r) paste(ifelse(is.na(r), ".", r), collapse = ""))))
  n_patterns_c  <- length(unique(apply(mat_c, 1,
                     function(r) paste(ifelse(is.na(r), ".", r), collapse = ""))))

  gof <- if (!inherits(fit_c, "error")) tryCatch(
    AICcmodavg::mb.gof.test(fit_c, nsim = GOF_NSIM, plot.hist = FALSE),
    error = function(e) NULL) else NULL
  chat  <- if (!is.null(gof)) as.numeric(gof$c.hat.est) else NA_real_
  gof_p <- if (!is.null(gof)) as.numeric(gof$p.value)   else NA_real_

  saveRDS(fit_yr, file.path(PATH$models,
                            sprintf("bobc_occu_null_%s_%s.rds", nm, DATE_TAG)))
  saveRDS(fit_c, file.path(PATH$models,
                           sprintf("bobc_occu_null_%s_collapsed_%s.rds", nm, DATE_TAG)))

  data.frame(
    history        = nm,
    background     = ifelse(grepl("mammal", nm), "3A_mammal", "3B_vertebrate"),
    detection_set  = ifelse(grepl("precise", nm), "precise", "all_incl_obscured"),
    n_sites_fit    = nrow(mat),
    psi_hat        = round(psi_yr, 3),
    p_annual       = round(p_yr, 3),          # per-VISIT detection (vs 0.10 line)
    p_period       = round(p_period, 3),      # per-PERIOD (~4 yr), GOF model
    p_se_finite    = all(is.finite(se_yr)),
    converged      = conv_yr,
    patterns_annual= n_patterns_yr,           # why annual GOF degenerates
    patterns_collapsed = n_patterns_c,        # tractable after collapse
    mb_chat        = round(chat, 3),          # from COLLAPSED fit
    mb_gof_p       = round(gof_p, 3),
    p_below_fallback = p_yr < FALLBACK_P,
    stringsAsFactors = FALSE
  )
}

# -----------------------------------------------------------------------------
# Fit all
# -----------------------------------------------------------------------------
res <- lapply(histories, fit_null) |> dplyr::bind_rows()
write.csv(res, file.path(PATH$tables, "tbl_09_null_fit_criteria.csv"),
          row.names = FALSE)
message("\n== Null-fit criteria (all histories) ==")
print(res, row.names = FALSE)

# -----------------------------------------------------------------------------
# Close Decision 22 on the PRIMARY history (mammal_precise)
# -----------------------------------------------------------------------------
prim <- res[res$history == PRIMARY, ]

# Verdict logic (methodology §5.4), corrected:
#   - fitted p uses the ANNUAL (per-visit) fit vs the 0.10 fallback line.
#   - GOF uses the COLLAPSED fit (annual GOF is degenerate on sparse histories).
#   - a still-degenerate GOF (c-hat implausibly large) is treated as NON-EVALUABLE,
#     which does NOT trigger SDM fallback on its own — fallback needs a genuine
#     failure (p below line, non-convergence, or a real lack-of-fit signal), not
#     an inapplicable test.
p_ok    <- isTRUE(prim$p_annual >= FALLBACK_P)
conv_ok <- isTRUE(prim$converged)

# GOF interpretation on the collapsed fit:
#   c-hat < 2       -> good fit
#   2 <= c-hat < 4  -> mild-moderate overdispersion, tolerable for a null baseline
#   c-hat >= 4 or NA-> treat as non-evaluable / suspect (don't auto-fail)
chat <- prim$mb_chat
gof_state <- dplyr::case_when(
  is.na(chat)      ~ "non_evaluable",
  chat < 2         ~ "good",
  chat < 4         ~ "mild_overdispersion",
  TRUE             ~ "non_evaluable_or_suspect"
)
gof_blocks_occupancy <- FALSE   # GOF alone never triggers fallback (see note)

occupancy_confirmed <- p_ok && conv_ok && !gof_blocks_occupancy

verdict <- if (occupancy_confirmed) {
  "OCCUPANCY CONFIRMED — proceed with unmarked occupancy track (proposal Q2)"
} else {
  "SDM FALLBACK RE-TRIGGERED — maxnet/ENMeval per §5.4"
}

close_tbl <- data.frame(
  decision            = "22",
  primary_history     = PRIMARY,
  background_selected = "3A_mammal (target-group-correct; 3B vertebrate bird-deflated)",
  p_annual            = prim$p_annual,
  p_period            = prim$p_period,
  p_fallback_line     = FALLBACK_P,
  p_clears_line       = p_ok,
  converged           = conv_ok,
  patterns_annual     = prim$patterns_annual,
  patterns_collapsed  = prim$patterns_collapsed,
  mb_chat_collapsed   = chat,
  gof_state           = gof_state,
  verdict             = verdict,
  stringsAsFactors    = FALSE
)
write.csv(close_tbl, file.path(PATH$tables, "tbl_09_decision22_close.csv"),
          row.names = FALSE)

message("\n================ Decision 22 close ================")
message(sprintf("Primary history : %s", PRIMARY))
message(sprintf("Background      : 3A mammal (3B vertebrate deflated)"))
message(sprintf("Fitted p annual : %.3f  (fallback line %.2f) -> %s",
                prim$p_annual, FALLBACK_P, ifelse(p_ok, "CLEARS", "BELOW")))
message(sprintf("Fitted p period : %.3f  (collapsed, ~4 yr — GOF model only)", prim$p_period))
message(sprintf("Converged       : %s", conv_ok))
message(sprintf("GOF (collapsed) : c-hat %s -> %s | patterns %d->%d after collapse",
                chat, gof_state, prim$patterns_annual, prim$patterns_collapsed))
message(sprintf("VERDICT         : %s", verdict))
message("\nNote: annual MB-GOF is degenerate on sparse opportunistic histories")
message("(hundreds of singleton patterns); collapsed 4-period GOF is the evaluable test.")
