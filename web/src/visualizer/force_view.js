/**
 * Force-directed scripts view powered by force-graph.
 *
 * Renders the same script cards and relationship edges as the manual canvas
 * (reusing drawScriptCard / linkStyle), but lets force-graph own the layout,
 * pan/zoom, dragging, and hit-testing for the scripts view.
 */

import ForceGraph from "force-graph";
import { forceCollide, forceX, forceY } from "d3-force-3d";

import {
  nodes,
  edges,
  NODE_W,
  NODE_H,
  searchTerm,
  selectedNode,
  currentView,
} from "./state.js";
import {
  drawScriptCard,
  linkStyle,
  roundRect,
  savePositions,
} from "./canvas.js";
import { openPanel, closePanel } from "./panel.js";

let fg = null;
let container = null;
let hovered = null;

// --- Force layout spacing (lower = tighter) ---
const CHARGE_STRENGTH = -1200; // node repulsion; more negative = farther apart
const CHARGE_DISTANCE_MAX = 2500; // cap repulsion range so clusters stay compact
const LINK_DISTANCE = 220; // target length of each edge
const LINK_STRENGTH = 0.6;
const COLLIDE_RADIUS = 117; // min center spacing to avoid card overlap
const GRAVITY_STRENGTH = 0.05; // pull toward center; higher gathers disconnected nodes / clusters tighter

function updateZoomText(k) {
  const zt = document.getElementById("zoom-text");
  const zi = document.getElementById("zoom-indicator");
  if (zt) zt.value = Math.round(k * 100) + "%";
  if (zi) zi.classList.toggle("faded", Math.abs(k - 1) < 0.01);
}

function drawLink(ctx, link) {
  const s = link.source;
  const t = link.target;
  if (!s || !t || typeof s !== "object" || typeof t !== "object") return;

  const style = linkStyle(link.type);
  const bothHighlighted = s.highlighted !== false && t.highlighted !== false;
  ctx.globalAlpha = bothHighlighted ? 0.5 : 0.12;
  ctx.strokeStyle = style.color;
  ctx.lineWidth = style.width;
  ctx.setLineDash(style.dash);

  ctx.beginPath();
  ctx.moveTo(s.x, s.y);
  ctx.lineTo(t.x, t.y);
  ctx.stroke();
  ctx.setLineDash([]);

  // Arrowhead at the midpoint (matches the manual renderer).
  const angle = Math.atan2(t.y - s.y, t.x - s.x);
  const mx = (s.x + t.x) / 2;
  const my = (s.y + t.y) / 2;
  const al = 10;
  ctx.beginPath();
  ctx.moveTo(mx + Math.cos(angle) * al, my + Math.sin(angle) * al);
  ctx.lineTo(
    mx + Math.cos(angle + 2.5) * al * 0.6,
    my + Math.sin(angle + 2.5) * al * 0.6,
  );
  ctx.lineTo(
    mx + Math.cos(angle - 2.5) * al * 0.6,
    my + Math.sin(angle - 2.5) * al * 0.6,
  );
  ctx.closePath();
  ctx.fillStyle = style.color;
  ctx.fill();
  ctx.globalAlpha = 1;
}

function buildLinks() {
  const ids = new Set(nodes.map((n) => n.path));
  return edges
    .filter((e) => ids.has(e.from) && ids.has(e.to))
    .map((e) => ({ source: e.from, target: e.to, type: e.type }));
}

export function initForceView() {
  container = document.getElementById("force-graph");
  if (!container || typeof ForceGraph !== "function") return null;

  fg = ForceGraph()(container)
    .backgroundColor("rgba(0,0,0,0)")
    // Node appearance depends on external state (selection/hover), so keep
    // redrawing every frame instead of pausing when the simulation settles.
    // Otherwise a selected node only highlights after the next pan/zoom.
    .autoPauseRedraw(false)
    .nodeId("path")
    .nodeRelSize(1)
    .nodeVisibility((n) => !(searchTerm && n.visible === false))
    .linkVisibility((l) => {
      if (!searchTerm) return true;
      const s = l.source;
      const t = l.target;
      const sv = typeof s === "object" ? s.visible !== false : true;
      const tv = typeof t === "object" ? t.visible !== false : true;
      return sv || tv;
    })
    .nodeCanvasObjectMode(() => "replace")
    .nodeCanvasObject((node, ctx) => {
      drawScriptCard(ctx, node, node === hovered, node === selectedNode);
    })
    .nodePointerAreaPaint((node, color, ctx) => {
      ctx.fillStyle = color;
      ctx.beginPath();
      roundRect(
        ctx,
        node.x - NODE_W / 2,
        node.y - NODE_H / 2,
        NODE_W,
        NODE_H,
        10,
      );
      ctx.fill();
    })
    .linkCanvasObjectMode(() => "replace")
    .linkCanvasObject((link, ctx) => drawLink(ctx, link))
    .onNodeHover((node) => {
      hovered = node || null;
      container.style.cursor = node ? "pointer" : "grab";
    })
    .onNodeClick((node) => {
      openPanel(node);
    })
    .onNodeDragEnd((node) => {
      node.fx = node.x;
      node.fy = node.y;
      savePositions();
    })
    .onBackgroundClick(() => {
      closePanel();
    })
    .onZoom((t) => updateZoomText(t.k));

  // Tune forces for large rectangular cards so they spread out and don't overlap.
  fg.d3Force("charge")
    .strength(CHARGE_STRENGTH)
    .distanceMax(CHARGE_DISTANCE_MAX);
  fg.d3Force("link").distance(LINK_DISTANCE).strength(LINK_STRENGTH);
  fg.d3Force("collide", forceCollide(COLLIDE_RADIUS));
  // Mild gravity toward the center keeps unconnected nodes and separate clusters
  // from drifting far apart (the default "center" force only re-centers, no pull).
  fg.d3Force("x", forceX(0).strength(GRAVITY_STRENGTH));
  fg.d3Force("y", forceY(0).strength(GRAVITY_STRENGTH));

  resizeForceView();
  setForceData();

  // Make zoom controls in the toolbar force-aware while keeping scene behavior.
  const prevReset = window.resetZoom;
  const prevCustom = window.setCustomZoom;
  window.resetZoom = () => {
    if (currentView === "scripts" && fg) {
      fg.zoom(1, 300);
      updateZoomText(1);
    } else if (prevReset) {
      prevReset();
    }
  };
  window.setCustomZoom = (value) => {
    if (currentView === "scripts" && fg) {
      let parsed = parseFloat(String(value).replace("%", "").trim());
      if (isNaN(parsed)) return;
      if (parsed > 0 && parsed < 10) parsed *= 100;
      const k = Math.max(0.1, Math.min(5, parsed / 100));
      fg.zoom(k, 300);
      updateZoomText(k);
    } else if (prevCustom) {
      prevCustom(value);
    }
  };

  return fg;
}

export function setForceData() {
  if (!fg) return;
  fg.graphData({ nodes, links: buildLinks() });
}

export function showForceView() {
  if (!container) return;
  container.style.display = "block";
  const c = document.getElementById("canvas");
  if (c) c.style.display = "none";
  resizeForceView();
}

export function hideForceView() {
  if (container) container.style.display = "none";
  const c = document.getElementById("canvas");
  if (c) c.style.display = "block";
}

export function resizeForceView() {
  if (!fg) return;
  fg.width(window.innerWidth);
  fg.height(window.innerHeight);
}

export function fitForceView() {
  if (fg) fg.zoomToFit(400, 80);
}

export function centerOnNodesForce(list) {
  if (!fg || !list || list.length === 0) return;
  let minX = Infinity,
    maxX = -Infinity,
    minY = Infinity,
    maxY = -Infinity;
  list.forEach((n) => {
    minX = Math.min(minX, n.x);
    maxX = Math.max(maxX, n.x);
    minY = Math.min(minY, n.y);
    maxY = Math.max(maxY, n.y);
  });
  fg.centerAt((minX + maxX) / 2, (minY + maxY) / 2, 400);
}

// Unpin every node and re-run the simulation from scratch.
export function resetForceLayout() {
  if (!fg) return;
  nodes.forEach((n) => {
    delete n.fx;
    delete n.fy;
  });
  setForceData();
  if (fg.d3ReheatSimulation) fg.d3ReheatSimulation();
  setTimeout(fitForceView, 600);
}
