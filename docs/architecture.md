# Architecture

The plugin is organized in three layers, so the visualization stays independent
from any MCP server or external Node process.

## 1. Service layer

`addons/godot_visualizer_native/services/`

- `project_map_service.gd` — scans GDScript and builds the script relationship graph (variables, functions, signals, `extends`, `preload`, signal connections).
- `scene_map_service.gd` — scans `.tscn` files and builds the scene overview graph (scenes, instances, script references).
- `script_edit_service.gd` — structured script edits and usage lookups.
- `scene_visualizer_service.gd` — scene tree and node property read/write.

The service layer has no dependency on MCP, the browser, or external processes.

## 2. Host / transport layer

`addons/godot_visualizer_native/transport/browser_bridge.gd`

- Serves the bundled `visualizer.html`.
- Hosts a localhost HTTP command endpoint (`POST /command`) backed by the service layer.
- Exposes the read-only structured `GET /api/v1` JSON API for AI / automation clients.
- Can write a read-only static preview page when no live host is needed.

`visualizer_manager.gd` wires the services to the bridge and owns command
dispatch plus the `/api/v1` responses.

## 3. Browser frontend layer

`web/src/visualizer/`

The frontend renders the graphs and handles interaction. It talks to the plugin
over one of three transports (`websocket.js`):

- **HTTP command mode** — default for this plugin; calls `POST /command` against the Godot host.
- **Static preview mode** — read-only, no host.
- **Legacy WebSocket mode** — retained for compatibility.

`web/scripts/build-visualizer.mjs` bundles the frontend (esbuild) into a single
`addons/godot_visualizer_native/web/visualizer.html`. `package-addon.mjs` rebuilds
it and zips the addon for distribution.

## Layout

- **Scripts** use a force-directed layout rendered by [force-graph](https://github.com/vasturiano/force-graph) (`web/src/visualizer/force_view.js`). Custom node cards and edge styling are drawn via force-graph's canvas callbacks (`drawScriptCard` / `linkStyle` in `canvas.js`), so the look matches the rest of the UI.
- **Scenes** keep the manual canvas renderer; an expanded scene's node tree is laid out left-to-right with [dagre](https://github.com/dagrejs/dagre) (`rankdir: 'LR'`) in `canvas.js`.
