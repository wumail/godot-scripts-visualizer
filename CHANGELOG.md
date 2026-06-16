# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3] - 2026-06-17

### Changed

- Optimized the scripts (force-graph) rendering: per-node text layout is cached instead of re-measured every frame, shadows are drawn only on the hovered/selected card, and a level-of-detail pass skips labels when zoomed out. Keeps large script maps smooth.

### Fixed

- The Scenes view no longer lags — the force-graph render loop is paused while the scene view is active instead of redrawing in the background.
- Switching from Scripts to Scenes no longer flashes a stale scripts frame.
- The Scenes view now centers and zoom-fits its content (both the scene overview and an expanded scene tree), so large scenes are visible on screen.

## [0.1.2] - 2026-06-17

### Changed

- Scripts view now uses the [force-graph](https://github.com/vasturiano/force-graph) library for force-directed layout, pan/zoom, and dragging (node cards and edge styling are preserved via custom canvas callbacks). A mild center gravity keeps disconnected nodes and separate clusters from drifting far apart.
- Scene node trees are now laid out left-to-right with [dagre](https://github.com/dagrejs/dagre), which also fixes overlapping child nodes.
- Script node stat badges now read `func` / `var` / `sig` / `line` instead of `f` / `v` / `s` / `L`.

### Fixed

- Script node title and stats are truncated to the card width so long names no longer overflow.
- A selected node now highlights immediately instead of only after the next pan/zoom (force-graph no longer pauses redraws while idle).
- The build no longer corrupts the bundle when the injected JavaScript contains `$` replacement patterns (`$&`, `$$`, etc.).

## [0.1.1] - 2026-06-17

Initial standalone release. The visualization capabilities were extracted from
[tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp) into an independent,
MCP-free Godot 4 plugin so they can be used alongside any MCP server (such as
[yurineko73/Godot-MCP-Native](https://github.com/yurineko73/Godot-MCP-Native)) or
on their own.

### Added

- Self-hosted browser visualizer running entirely inside the Godot editor plugin (no Node.js server at runtime).
- Localhost HTTP command transport (`POST /command`) backed by the GDScript service layer.
- Read-only structured `GET /api/v1` JSON API for AI / automation clients (manifest, runtime, project/scene summaries with fingerprints, lookup, full maps).
- Static read-only preview export from the editor dock.
- esbuild-based single-file frontend build and addon zip packaging (`npm run build`, `npm run package:addon`).

### Changed

- Replaced the original force-directed graph layout with a hierarchical inheritance layout: base classes flow down through their `extends` chain, with `preload`/`signal` links ordering siblings.
- Frontend transport switched from WebSocket-to-Node to localhost HTTP-to-plugin (static and legacy WebSocket modes retained).

[Unreleased]: https://github.com/wumail/godot-scripts-visualizer/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/wumail/godot-scripts-visualizer/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/wumail/godot-scripts-visualizer/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/wumail/godot-scripts-visualizer/releases/tag/v0.1.1
