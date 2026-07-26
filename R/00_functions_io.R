# =============================================================================
# 00_functions_io.R
# Reading, writing and provenance helpers.
# =============================================================================

#' Write an sf object to GeoPackage, overwriting cleanly
write_layer <- function(x, path, layer = NULL) {
  if (is.null(layer)) layer <- tools::file_path_sans_ext(basename(path))
  sf::st_write(x, dsn = path, layer = layer, delete_dsn = TRUE, quiet = TRUE)
  message("Wrote ", nrow(x), " features -> ", path)
  invisible(path)
}

#' Read a layer and assert its CRS matches the analysis CRS
read_layer <- function(path, layer = NULL, expect_crs = CRS_ANALYSIS) {
  x <- if (is.null(layer)) sf::st_read(path, quiet = TRUE)
       else sf::st_read(path, layer = layer, quiet = TRUE)
  epsg <- sf::st_crs(x)$epsg
  if (!isTRUE(epsg == expect_crs)) {
    stop("CRS mismatch in ", path, ": found EPSG:", epsg,
         ", expected EPSG:", expect_crs, call. = FALSE)
  }
  x
}

#' Append a row to the record-count log used in docs/methodology.md
log_stage <- function(dataset, stage, n, file = "outputs/tables/record_counts.csv") {
  row <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    dataset = dataset, stage = stage, n = n
  )
  utils::write.table(
    row, file, sep = ",", row.names = FALSE,
    col.names = !file.exists(file), append = file.exists(file)
  )
  message(sprintf("[%s] %s: %s", dataset, stage, format(n, big.mark = ",")))
  invisible(row)
}
