# Godot Visualizer Native

[![Godot 4](https://img.shields.io/badge/Godot-4.x-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.md)
[![Version](https://img.shields.io/badge/version-0.1.3-blue.svg)](CHANGELOG.md)

A standalone Godot 4 editor plugin that visualizes and edits your project's
**script relationships** and **scene structure** — all hosted inside the Godot
editor, with no external server required.

English | [简体中文](README.zh-CN.md)

> Open the **Script Map** to see how your classes inherit and reference each
> other, browse the **Scene Map** and scene trees, edit scripts and scene nodes
> from an interactive browser view, and expose a read-only JSON API for AI agents.

## Why this project exists

This plugin extracts the **visualization** capabilities from
[tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp) into an independent,
MCP-free Godot addon.

The reasoning:

- For the **MCP integration** itself, I prefer
  [yurineko73/Godot-MCP-Native](https://github.com/yurineko73/Godot-MCP-Native),
  which runs natively inside Godot.
- But the **visualization** in `tomyud1/godot-mcp` is genuinely useful, and in
  the original it is tightly coupled to its Node.js MCP server.

So rather than carry the whole MCP stack just for the graphs, the visualization
was lifted out into this plugin. It runs on its own and works **alongside any MCP
server (or none at all)** — including `Godot-MCP-Native`.

## What changed vs. the original visualization

| Aspect | `tomyud1/godot-mcp` | Godot Visualizer Native |
| --- | --- | --- |
| Host | Node.js MCP server (`mcp-server`) serves the page | Pure GDScript plugin self-hosts everything in the editor |
| Transport | Browser ↔ Node over WebSocket, bridged to Godot | Browser ↔ Godot over localhost HTTP `POST /command` |
| Runtime deps | Requires the Node MCP server running | No Node process at runtime; Node is only used to build |
| AI access | Internal WebSocket, not exposed | Read-only `GET /api/v1` JSON API (manifest, summaries, lookup, fingerprints) |
| Graph layout | Force-directed (custom canvas) | Scripts: force-directed via [force-graph](https://github.com/vasturiano/force-graph); scene trees: left-to-right [dagre](https://github.com/dagrejs/dagre) layout |
| Static export | — | Read-only snapshot HTML export from the dock |

## Features

- **Script map** — GDScript relationship graph: `extends`, `preload`, and signal connections, with variables, functions and signals per script.
- **Scene map** — scenes, instanced scenes, and script references, plus scene-tree inspection.
- **In-place editing** — modify variables, signals and function bodies; add/remove/rename/move/duplicate/reorder scene nodes; read and set node properties.
- **Interactive browser visualizer** — launched from the editor dock, driven directly by the plugin.
- **Static preview export** — read-only HTML snapshot of the script map.
- **Structured `/api/v1` JSON API** — stable, read-only protocol designed for AI / automation clients.

## Requirements

- Godot **4.x**
- Node.js **18+** (only to build the browser frontend or the addon zip)

## Installation

### From a release zip (recommended)

1. Download `godot_visualizer_native-<version>.zip` from the
   [Releases](https://github.com/wumail/godot-scripts-visualizer/releases) page.
2. In Godot: **AssetLib → Import**, select the zip, and confirm it extracts to
   `addons/godot_visualizer_native`.
3. **Project Settings → Plugins** → enable **Godot Visualizer Native**.

### From source

1. Clone this repository.
2. Build the frontend (see below), or copy a release's `visualizer.html`.
3. Copy `addons/godot_visualizer_native` into your project's `addons/` directory.
4. Enable the plugin in **Project Settings → Plugins**.

## Building the frontend

The browser visualizer is bundled into a single
`addons/godot_visualizer_native/web/visualizer.html`. It is **not committed** —
build it (or take it from a release):

```bash
cd web
npm install
npm run build          # → addons/godot_visualizer_native/web/visualizer.html
```

To produce a distributable addon zip:

```bash
cd web
npm run package:addon  # rebuilds the frontend, then → dist/godot_visualizer_native-<version>.zip
```

## Usage

Enable the plugin and use the **Visualizer** dock on the right:

- **Build Script Map** / **Build Scene Map** — scan and show stats in the dock.
- **Open Browser Visualizer** — start the localhost host and open the interactive page.
- **Stop Live Visualizer** — stop the host and release the port.
- **Export Static Preview** — write a read-only snapshot to `user://godot_visualizer_native/`.
- **Refresh Status** — refresh the runtime/service summary.

In the live browser visualizer you can browse the script and scene graphs, create
scripts, edit variables/signals/function bodies, and edit scene nodes. The static
preview is read-only and disables the scene view.

## Structured API (`/api/v1`)

When the live host is running, the same port serves a stable, read-only JSON API
intended for AI / automation clients. Every response uses a shared envelope
(`ok`, `protocol`, `version`, `resource`, `generated_at`, `query`, `data`).

Key endpoints:

| Endpoint | Purpose |
| --- | --- |
| `GET /api/v1` | Protocol manifest: audience, parsing hints, recommended read order, schemas |
| `GET /api/v1/runtime` | Host status, port, URL, capabilities |
| `GET /api/v1/project-summary` | Compact script summary with a `fingerprint` for cheap change detection |
| `GET /api/v1/scene-summary` | Compact scene summary with a `fingerprint` |
| `GET /api/v1/lookup` | Targeted lookup by path, class, function, signal, scene, node, … |
| `GET /api/v1/project-map` | Full structured script graph |
| `GET /api/v1/scene-map` | Full structured scene graph |

Recommended flow for AI clients: read the manifest and summaries first (low
token cost), cache the `fingerprint`, pass it back as `if_fingerprint` to detect
changes, and only fetch full maps or `lookup` when deeper detail is needed.

```bash
curl http://127.0.0.1:6510/api/v1
curl http://127.0.0.1:6510/api/v1/project-summary
curl "http://127.0.0.1:6510/api/v1/lookup?class_name=MyNode"
```

You can start the API without opening a browser:

```gdscript
var result = visualizer_manager.start_structured_api()
print(result.api_base_url)
```

## Command surface

The browser host accepts these commands via `POST /command`:

`map_project`, `refresh_map`, `map_scenes`, `create_script_file`,
`modify_variable`, `modify_signal`, `modify_function`, `modify_function_delete`,
`find_usages`, `get_scene_hierarchy`, `get_scene_node_properties`,
`set_scene_node_property`, `add_node`, `remove_node`, `rename_node`,
`move_node`, `duplicate_node`, `reorder_node`.

## Verification

A headless smoke test is provided at `tests/visualizer_cli_smoke.gd`:

```bash
/path/to/Godot --headless --path /absolute/path/to/this/repo \
  -s res://tests/visualizer_cli_smoke.gd
```

It starts the localhost host (without opening a browser), exercises `/health`,
the `/api/v1` endpoints, and a `refresh_map` command, then shuts down and returns
the result via the exit code.

## Project layout

```text
addons/godot_visualizer_native/   # the distributable plugin
  services/                       # script & scene scan / edit services
  transport/browser_bridge.gd     # localhost host + /command + /api/v1
  ui/visualizer_dock.gd           # editor dock
  visualizer_manager.gd           # wiring + API responses
web/                              # browser frontend source + build scripts
docs/                             # architecture & AssetLib notes
tests/                            # headless smoke tests
```

See [docs/architecture.md](docs/architecture.md) for the layered design.

## Versioning & releases

The version lives in `addons/godot_visualizer_native/plugin.cfg` and
`web/package.json`. Pushing a `v*` tag triggers the
[release workflow](.github/workflows/release.yml), which builds the addon zip and
attaches it to a GitHub Release. See [CHANGELOG.md](CHANGELOG.md).

## Acknowledgements

- [tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp) — the original source of these visualization features.
- [yurineko73/Godot-MCP-Native](https://github.com/yurineko73/Godot-MCP-Native) — the native MCP integration this plugin is meant to complement.

## License

MIT — see [LICENSE.md](LICENSE.md).
