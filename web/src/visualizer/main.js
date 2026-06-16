/**
 * Main entry point for the Godot Project Map Visualizer
 */

import {
  nodes, edges, camera, NODE_W, NODE_H
} from './state.js';
import { connectWebSocket, getTransportState, reconnectTransport } from './websocket.js';
import { initCanvas, draw } from './canvas.js';
import { initForceView, showForceView, hideForceView, fitForceView } from './force_view.js';
import { initPanel } from './panel.js';
import { initModals } from './modals.js';
import { initEvents, updateStats } from './events.js';
import './usages.js'; // Load usages module for side effects (global functions)

function renderTransportStatus(state = getTransportState()) {
  const badge = document.getElementById('transport-badge');
  const detail = document.getElementById('transport-detail');
  const retryButton = document.getElementById('transport-retry');

  if (!badge || !detail || !retryButton) {
    return;
  }

  badge.dataset.status = state.status;
  badge.textContent = state.label;
  detail.textContent = state.detail || '';

  const retryVisible = state.mode !== 'static' && state.status !== 'connected' && state.status !== 'connecting';
  retryButton.hidden = !retryVisible;
}

function initTransportStatus() {
  const retryButton = document.getElementById('transport-retry');
  if (retryButton) {
    retryButton.addEventListener('click', () => {
      renderTransportStatus({
        mode: 'manual',
        status: 'connecting',
        label: 'Retrying',
        detail: 'Trying to reconnect transport',
        lastError: ''
      });
      reconnectTransport();
    });
  }

  document.addEventListener('visualizer-transport-state', (event) => {
    renderTransportStatus(event.detail);
  });

  renderTransportStatus();
}

// Initialize everything when DOM is ready
function init() {
  initTransportStatus();

  // Connect WebSocket for real-time communication
  connectWebSocket();

  // Initialize canvas and rendering (also restores saved positions)
  initCanvas();

  // Initialize panel and modals
  initPanel();
  initModals();

  // Initialize event handlers
  initEvents();

  // Initialize the force-directed scripts view (force-graph)
  initForceView();

  // Update stats
  updateStats();

  // Get zoom indicator element
  const zoomIndicator = document.getElementById('zoom-indicator');

  if (nodes.length === 0) {
    // No scripts found - show placeholder on the manual canvas
    hideForceView();
    const ctx = document.getElementById('canvas').getContext('2d');
    const W = window.innerWidth;
    const H = window.innerHeight;

    ctx.font = '18px -apple-system, system-ui, sans-serif';
    ctx.fillStyle = '#706c66';
    ctx.textAlign = 'center';
    ctx.fillText('No scripts found in project', W / 2, H / 2);
    zoomIndicator.style.display = 'none';
  } else {
    // Scripts is the default view → force-directed layout via force-graph.
    showForceView();
    fitForceView();
    // Refit once the simulation has had time to settle.
    setTimeout(fitForceView, 700);
  }
}

window.retryVisualizerTransport = reconnectTransport;

// Start when DOM is loaded
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
