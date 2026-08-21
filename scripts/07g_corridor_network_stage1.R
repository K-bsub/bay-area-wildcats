# =============================================================================
# 07g_corridor_network.R — puma core-connectivity network (Gabriel graph on
# cost-distance). STAGE 1: node set + Gabriel edges PREVIEW (cheap — no full LCP
# runs). Confirms the node count before the expensive network extraction.
#
# Design (confirmed):
#   * Nodes  = the LARGE cores only (size cutoff read from the observed area
#     distribution — same discipline as Decision 32, not asserted). Small near-
#     floor cores are stepping-stones, not population anchors, and a 164-node
#     Gabriel graph is ~300+ edges = a hairball + a very long run.
#   * Edges  = Gabriel graph on core CENTROIDS (spdep::gabrielneigh — version-
#     independent, the standard connectivity-network neighbour scheme; keeps
#     near-neighbour alternatives so a "weak link" = the only connection with no
#     alternative, unlike an MST where every edge looks critical).
#   * Paths (STAGE 2) = create_lcp per Gabriel edge, boundary-to-boundary
#     (endpoints snapped to nearest boundary points, as the primary LCP — NOT
#     centroids, so a 500 km² patch does not force the path through its interior).
#     Only create_lcp is used (confirmed present in leastcostpath 2.x);
#     create_lcp_network is a 1.x function and may not survive the terra rewrite.
#
# STAGE 1 OUTPUT (preview only, for node-count confirmation):
#   outputs/tables/tbl_24a_network_nodes.csv        (the large-core node set)
#   outputs/figures/fig_23a_gabriel_preview.png     (nodes + Gabriel edges, straight lines)
#   prints: area-distribution + proposed cutoff + resulting node & edge counts
# =============================================================================

source("R/00_config.R")
source("R/00_functions_io.R")
source("R/00_functions_spatial.R")
library(sf); library(terra); library(tidyverse); library(spdep)

core_sf <- read_layer(file.path(PATH$processed, "lcp_puma_core_patches_3310.gpkg"))
message(sprintf("All cores (>=5 km², Decision 32): %d", nrow(core_sf)))

# ---- 1. Observed core-area distribution (cutoff read from here) --------------
areas <- sort(core_sf$area_km2, decreasing = TRUE)
message("\n== Core-area distribution (km²) ==")
print(round(stats::quantile(areas, c(0, .25, .5, .75, .9, .95, 1)), 1))

# node-count as a function of candidate cutoffs — pick a tractable, meaningful N
message("\n-- Node count at candidate area cutoffs --")
for (thr in c(10, 20, 30, 50, 75, 100)) {
  n <- sum(core_sf$area_km2 >= thr)
  message(sprintf("  >= %3d km² : %3d nodes", thr, n))
}

# PROPOSED CUTOFF: target ~25-35 nodes (tractable Gabriel graph, ecologically the
# real population anchors). Chosen from the scan above. Adjust NODE_CUTOFF_KM2 if
# the printed counts suggest a better break.
NODE_CUTOFF_KM2 <- 20   # provisional — confirm from the printed scan
nodes_sf <- core_sf[core_sf$area_km2 >= NODE_CUTOFF_KM2, ]
message(sprintf("\nPROVISIONAL cutoff >= %d km² -> %d nodes",
                NODE_CUTOFF_KM2, nrow(nodes_sf)))

# ---- 2. Gabriel graph on centroids ------------------------------------------
ctr <- sf::st_centroid(sf::st_geometry(nodes_sf))
xy  <- sf::st_coordinates(ctr)
gab <- spdep::gabrielneigh(xy)
# gabrielneigh returns $from / $to index vectors — build undirected edge list
edges <- data.frame(from = gab$from, to = gab$to)
edges <- edges[edges$from < edges$to, ]   # dedupe undirected
edges$from_patch <- nodes_sf$patch_id[edges$from]
edges$to_patch   <- nodes_sf$patch_id[edges$to]
# Euclidean centroid distance (a CHEAP proxy to preview edge scale — the real
# ranking in Stage 2 is cost-distance, which will differ where barriers intervene)
edges$eucl_km <- sqrt((xy[edges$from,1]-xy[edges$to,1])^2 +
                      (xy[edges$from,2]-xy[edges$to,2])^2) / 1000
message(sprintf("Gabriel graph: %d nodes -> %d edges (Stage-2 LCP runs = %d)",
                nrow(nodes_sf), nrow(edges), nrow(edges)))

# does the primary linkage (1727 <-> 3972) appear as a Gabriel edge?
has_primary <- any((edges$from_patch==1727 & edges$to_patch==3972) |
                   (edges$from_patch==3972 & edges$to_patch==1727))
message(sprintf("Primary SC<->Diablo (1727-3972) is a Gabriel edge? %s", has_primary))
if (!has_primary)
  message("  (If FALSE: 1727 and 3972 are not Gabriel-adjacent; the network")
  message("   connects them via intermediate cores — still a valid path, note it.)")

# ---- 3. Preview outputs -----------------------------------------------------
node_tbl <- nodes_sf |> sf::st_drop_geometry() |>
  dplyr::arrange(dplyr::desc(area_km2)) |>
  dplyr::select(patch_id, area_km2, dplyr::any_of(c("range_name","linkage_role")))
write.csv(node_tbl, file.path(PATH$tables, "tbl_24a_network_nodes.csv"), row.names = FALSE)
message("\nWrote outputs/tables/tbl_24a_network_nodes.csv")

png(file.path(PATH$figures, "fig_23a_gabriel_preview.png"),
    width = 1100, height = 1000, res = 150)
plot(sf::st_geometry(core_sf), col = "grey90", border = "grey70",
     main = sprintf("Gabriel network preview: %d large cores (>=%d km²), %d edges",
                    nrow(nodes_sf), NODE_CUTOFF_KM2, nrow(edges)))
plot(sf::st_geometry(nodes_sf), col = "#41ab5d", border = "grey30", add = TRUE)
for (i in seq_len(nrow(edges))) {
  lines(rbind(xy[edges$from[i],], xy[edges$to[i],]), col = "steelblue", lwd = 1)
}
plot(ctr, add = TRUE, pch = 19, cex = 0.5, col = "black")
dev.off()
message("Wrote outputs/figures/fig_23a_gabriel_preview.png")

message("\n================ STAGE 1 (preview) complete ================")
message(sprintf("PROVISIONAL: %d nodes (>=%d km²), %d Gabriel edges.",
                nrow(nodes_sf), NODE_CUTOFF_KM2, nrow(edges)))
message("CONFIRM the node/edge count, then STAGE 2 runs create_lcp per edge,")
message("ranks by cost-distance, and swaths the costliest links.")
