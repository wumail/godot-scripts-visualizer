# Godot Visualizer Native

A standalone Godot 4 editor addon that visualizes and edits your project's
script relationships and scene structure, hosted entirely inside the Godot
editor — no external server required.

It provides:

- script relationship maps (`extends`, `preload`, signal connections)
- scene overview and scene tree inspection
- script editing helpers (variables, signals, function bodies)
- scene node inspection and editing
- an interactive browser visualizer driven by the editor plugin
- a read-only `/api/v1` JSON API for AI / automation clients

## Installation

1. Copy `addons/godot_visualizer_native` into your project's `addons/` directory.
2. Open the project in Godot.
3. Go to **Project Settings → Plugins** and enable **Godot Visualizer Native**.

The bundled browser frontend lives at
`addons/godot_visualizer_native/web/visualizer.html`. If it is missing (e.g. a
source checkout), build it from the repository's `web/` directory with
`npm install && npm run build`, or use a packaged release zip.

## Usage

From the **Visualizer** dock, build the script/scene map, open the live browser
visualizer, or export a read-only static preview.

## Links

- Repository: https://github.com/wumail/godot-scripts-visualizer
- Full documentation and the split rationale are in the repository README.

## License

MIT — see `LICENSE.md` in this folder.
