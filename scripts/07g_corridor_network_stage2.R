# =============================================================================
# 07g_corridor_network.R — STAGE 2: full Gabriel LCP network + weak-link ranking.
#
# Nodes = large cores >= 30 km² (29 nodes; cutoff from the Stage-1 area-distribution
# scan — clean break 44->29->19 at 20/30/50 km², and 30 km² = "population anchor"
# tier well above the 5 km² endpoint floor). Edges = Gabriel graph on centroids.
# Paths = create_lcp per edge, boundary-to-boundary (only create_lcp is used —
# confirmed in leastcostpath 2.x; create_lcp_network is 1.x). Cost-distance ranks
# the edges: costliest = weakest links (longest / most-resisted connections).
#
# The primary SC<->Diablo (1727-3972) is NOT a Gabriel edge (intermediate cores in
# the Coyote Valley gap) — the network connects them as a STEPPING-STONE CHAIN.
# This is the complementary framing to the direct primary corridor (Decision 33):
# the network's 2+-hop chain shows the intermediate Coyote Valley cores are
# load-bearing. The chain is traced here via igraph shortest cost path.
#
# Consumes the SAME corrected resistance surface (Decision 34) + conductance
# (1/R, 16-neighbour, Decision 33). Reuses build helpers inline to stay
# self-contained.
#
# Outputs:
#   data/processed/lcp_puma_network_3310.gpkg            (all Gabriel LCP edges)
#   data/processed/lcp_puma_network_weaklinks_swath_3310.gpkg (top-N costly swaths)
#   outputs/tables/tbl_24_network_weaklinks.csv          (ranked edges)
#   outputs/figures/fig_23_corridor_network.png
# =============================================================================

source("R/00_config.R"); source("R/00_functions_io.R"); source("R/00_functions_spatial.R")
library(sf); library(terra); library(tidyverse); library(spdep)
library(leastcostpath); library(igraph)

NODE_CUTOFF_KM2 <- 30
N_SWATH_WEAK    <- 5     # swath the 5 costliest links (weak-link deliverable)

# ---- load + conductance -----------------------------------------------------
R      <- terra::rast(file.path(PATH$rasters, "resist_puma_baseline_3310.tif"))
core   <- read_layer(file.path(PATH$processed, "lcp_puma_core_patches_3310.gpkg"))
cond_r <- 1 / R; names(cond_r) <- "conductance"
cs     <- leastcostpath::create_cs(cond_r, neighbours = 16, dem = NULL, max_slope = NULL)

nodes <- core[core$area_km2 >= NODE_CUTOFF_KM2, ]
message(sprintf("Network nodes (>=%d km²): %d", NODE_CUTOFF_KM2, nrow(nodes)))
ctr <- sf::st_centroid(sf::st_geometry(nodes)); xy <- sf::st_coordinates(ctr)

# ---- Gabriel edges ----------------------------------------------------------
gab <- spdep::gabrielneigh(xy)
E <- data.frame(i = gab$from, j = gab$to)
E <- E[E$i < E$j, ]                          # undirected dedupe
E$from_patch <- nodes$patch_id[E$i]; E$to_patch <- nodes$patch_id[E$j]
message(sprintf("Gabriel edges to route: %d", nrow(E)))

# nearest finite-conductance cell (endpoint snap, as the primary LCP)
cand_sf <- sf::st_as_sf(terra::as.points(cond_r, na.rm = TRUE))
snap <- function(pt) sf::st_geometry(cand_sf)[sf::st_nearest_feature(pt, cand_sf)]

# ---- route each edge boundary-to-boundary, carry cost-distance --------------
# Some large cores are <1 km apart at 1 km grain; their snapped endpoints collapse
# to the SAME cell and create_lcp returns empty ("share the same location"). Those
# edges are ADJACENCIES (cost ≈ 0, the strongest links), not failures — recorded
# as such, not dropped, so network connectivity is not understated.
edge_lines <- vector("list", nrow(E))
costs <- rep(NA_real_, nrow(E)); lens <- costs
E$edge_type <- NA_character_
for (e in seq_len(nrow(E))) {
  pa <- nodes[nodes$patch_id == E$from_patch[e], ]
  pb <- nodes[nodes$patch_id == E$to_patch[e], ]
  np <- sf::st_cast(sf::st_nearest_points(sf::st_geometry(pa), sf::st_geometry(pb)), "POINT")
  o  <- sf::st_sf(geometry = snap(np[1])); d <- sf::st_sf(geometry = snap(np[2]))

  # same-cell adjacency: snapped endpoints identical -> zero-cost link, no routing
  if (isTRUE(sf::st_equals(o, d, sparse = FALSE)[1,1])) {
    costs[e] <- 0; lens[e] <- 0; E$edge_type[e] <- "adjacency"
    next
  }

  lcp <- tryCatch(
    leastcostpath::create_lcp(cs, o, d, cost_distance = TRUE, check_locations = TRUE),
    error = function(err) NULL)
  # create_lcp can also return an EMPTY (0-row) sf without erroring — treat as adjacency
  if (is.null(lcp) || nrow(lcp) == 0 || all(sf::st_is_empty(lcp))) {
    costs[e] <- 0; lens[e] <- 0; E$edge_type[e] <- "adjacency"
    message(sprintf("  edge %d (%d-%d): same-cell adjacency (cost 0), not routed",
                    e, E$from_patch[e], E$to_patch[e]))
    next
  }

  lcp <- sf::st_transform(lcp, 3310)
  cc  <- intersect(c("cost","cost_distance","total_cost"), names(lcp))
  costs[e] <- if (length(cc)) as.numeric(lcp[[cc[1]]][1]) else NA_real_
  lens[e]  <- as.numeric(sf::st_length(lcp)) / 1000
  E$edge_type[e] <- "routed"
  lcp$from_patch <- E$from_patch[e]; lcp$to_patch <- E$to_patch[e]
  lcp$cost_distance <- costs[e]; lcp$length_km <- lens[e]
  edge_lines[[e]] <- lcp[, c("from_patch","to_patch","cost_distance","length_km")]
  if (e %% 10 == 0) message(sprintf("  routed %d / %d edges", e, nrow(E)))
}
net <- do.call(rbind, edge_lines[!sapply(edge_lines, is.null)])
sf::st_crs(net) <- 3310
E$cost_distance <- costs; E$length_km <- lens
n_adj <- sum(E$edge_type == "adjacency", na.rm = TRUE)
message(sprintf("Edges: %d routed, %d same-cell adjacencies (cost 0)",
                sum(E$edge_type == "routed", na.rm = TRUE), n_adj))
# keep all edges with a finite cost (routed + adjacency); drop only true failures
E <- E[!is.na(E$cost_distance), ]

# ---- rank weak links (costliest = weakest) ----------------------------------
# Weak-link ranking is over ROUTED edges only. Same-cell adjacencies (cost 0) are
# the STRONGEST links (functionally contiguous cores), not weak — reported apart.
E_routed <- E[E$edge_type == "routed", ]
E_routed$cost_per_km <- E_routed$cost_distance / E_routed$length_km
E_routed <- E_routed[order(-E_routed$cost_distance), ]
E_routed$weak_rank <- seq_len(nrow(E_routed))
message(sprintf("\nNetwork: %d routed edges + %d adjacencies. Costliest (weakest) routed links:",
                nrow(E_routed), n_adj))
weak_tbl <- E_routed |> dplyr::select(weak_rank, from_patch, to_patch,
                                      cost_distance, length_km, cost_per_km)
print(utils::head(weak_tbl, 8), row.names = FALSE)

net <- dplyr::left_join(net,
  E_routed[, c("from_patch","to_patch","weak_rank","cost_per_km")],
  by = c("from_patch","to_patch"))
write_layer(net, file.path(PATH$processed, "lcp_puma_network_3310.gpkg"))
write.csv(weak_tbl, file.path(PATH$tables, "tbl_24_network_weaklinks.csv"), row.names = FALSE)
message("Wrote lcp_puma_network_3310.gpkg + tbl_24_network_weaklinks.csv")

# ---- trace the SC-Mtns (1727) -> Diablo (3972) chain through the network -----
# graph weighted by cost-distance; shortest cost path = the stepping-stone chain.
# ALL edges included (adjacencies are valid zero-cost hops a puma crosses free).
g <- igraph::graph_from_data_frame(
  data.frame(from = E$from_patch, to = E$to_patch, weight = E$cost_distance),
  directed = FALSE)
chain_note <- "1727 or 3972 not in the >=30 km² node set"
if (all(c("1727","3972") %in% igraph::V(g)$name)) {
  sp <- igraph::shortest_paths(g, from = "1727", to = "3972", weights = igraph::E(g)$weight)
  chain <- as.integer(names(sp$vpath[[1]]))
  chain_cost <- igraph::distances(g, "1727", "3972", weights = igraph::E(g)$weight)[1,1]
  chain_note <- sprintf("SC->Diablo network chain (%d hops): %s | total cost %.1f",
                        length(chain)-1, paste(chain, collapse = " -> "), chain_cost)
}
message("\n== SC Mtns -> Diablo stepping-stone chain (network topology) ==")
message(chain_note)

# ---- swaths for the top-N costliest ROUTED links ----------------------------
message(sprintf("\nBuilding swaths for the %d costliest routed links...", N_SWATH_WEAK))
swath_list <- list()
for (r in seq_len(min(N_SWATH_WEAK, nrow(E_routed)))) {
  pa <- nodes[nodes$patch_id == E_routed$from_patch[r], ]
  pb <- nodes[nodes$patch_id == E_routed$to_patch[r], ]
  np <- sf::st_cast(sf::st_nearest_points(sf::st_geometry(pa), sf::st_geometry(pb)), "POINT")
  o <- sf::st_sf(geometry = snap(np[1])); d <- sf::st_sf(geometry = snap(np[2]))
  cc <- leastcostpath::create_cost_corridor(cs, o, d, rescale = FALSE)
  thr <- as.numeric(stats::quantile(terra::values(cc, na.rm=TRUE), 0.05))   # q5% context band
  m <- terra::ifel(cc <= thr, 1L, NA)
  p <- sf::st_as_sf(terra::as.polygons(m, dissolve = TRUE))
  p <- suppressWarnings(sf::st_collection_extract(sf::st_make_valid(p), "POLYGON"))
  p <- sf::st_sf(geometry = sf::st_union(p)); sf::st_crs(p) <- 3310
  p$weak_rank <- r; p$from_patch <- E_routed$from_patch[r]; p$to_patch <- E_routed$to_patch[r]
  p$cost_distance <- E_routed$cost_distance[r]
  swath_list[[r]] <- p
}
weak_swaths <- do.call(rbind, swath_list)
write_layer(weak_swaths, file.path(PATH$processed, "lcp_puma_network_weaklinks_swath_3310.gpkg"))
message("Wrote lcp_puma_network_weaklinks_swath_3310.gpkg")

# ---- figure -----------------------------------------------------------------
png(file.path(PATH$figures, "fig_23_corridor_network.png"), width = 1200, height = 1100, res = 150)
plot(sf::st_geometry(core), col = "grey92", border = "grey80",
     main = sprintf("Puma core-connectivity network (Gabriel, %d anchors >=%d km²)",
                    nrow(nodes), NODE_CUTOFF_KM2))
plot(sf::st_geometry(nodes), col = "#c7e9c0", border = "grey40", add = TRUE)
# edges coloured by weak_rank (red = costliest); adjacencies (NA rank) drawn grey
pal <- grDevices::colorRampPalette(c("red","orange","steelblue"))(nrow(E_routed))
net2 <- net[order(net$weak_rank, na.last = TRUE), ]
for (k in seq_len(nrow(net2))) {
  wr <- net2$weak_rank[k]
  col_k <- if (is.na(wr)) "grey60" else pal[wr]
  plot(sf::st_geometry(net2[k,]), col = col_k, lwd = 1.5, add = TRUE)
}
# top weak swaths
if (nrow(weak_swaths)) plot(sf::st_geometry(weak_swaths), col = "#ff000033", border = "red", add = TRUE)
legend("topright", bty="n", legend = c("costliest links (weak)","cheapest links","weak-link swaths"),
       col = c("red","steelblue","red"), lwd = c(2,2,NA), pch = c(NA,NA,15), cex = 0.8)
dev.off()
message("Wrote outputs/figures/fig_23_corridor_network.png")

message("\n================ STAGE 2 complete ================")
message(sprintf("%d-edge Gabriel network; %d weak-link swaths; SC->Diablo chain traced.",
                nrow(E), min(N_SWATH_WEAK, nrow(E))))
message("Record as Decision 37 from tbl_24 (weak links = conservation priorities).")

# --- Name the weak-link and chain nodes (county + centroid) -------------------
f_cty <- file.path(PATH$interim, "boundary_baycounties_3310.gpkg")  # adjust if needed
counties <- read_layer(f_cty)
cty_field <- intersect(c("county","NAME","name","namelsad"), names(counties))[1]

key_ids <- c(1053, 1899, 3289, 752, 2618, 3250, 488, 3497, 3455, 3863, 1727, 3972)
kn <- core[core$patch_id %in% key_ids, ]
ctr <- sf::st_centroid(sf::st_geometry(kn))
kn$cx <- round(sf::st_coordinates(ctr)[,1]); kn$cy <- round(sf::st_coordinates(ctr)[,2])
idx <- sf::st_intersects(ctr, counties)
kn$county <- vapply(idx, function(i) if(length(i)) as.character(counties[[cty_field]][i[1]]) else NA, character(1))
print(kn |> sf::st_drop_geometry() |>
        dplyr::arrange(dplyr::desc(area_km2)) |>
        dplyr::select(patch_id, area_km2, county, cx, cy,
                      dplyr::any_of("range_name")), row.names = FALSE)
