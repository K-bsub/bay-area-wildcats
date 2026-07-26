# =============================================================================
# _targets.R
# Optional pipeline orchestration. Adopt once the numbered scripts stabilise -
# do not start here. Run with targets::tar_make().
# =============================================================================

library(targets)

tar_option_set(packages = c("sf", "terra", "tidyverse"))

lapply(list.files("R", full.names = TRUE, pattern = "\\.R$"), source)

list(
  # tar_target(openspace_raw, read_cpad(...), format = "file"),
  # tar_target(openspace_sf,  prepare_openspace(openspace_raw)),
)
