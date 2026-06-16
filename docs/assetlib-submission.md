# AssetLib Submission Notes

## Suggested submission fields

- Asset Name: Godot Visualizer Native
- Category: Tools
- Godot Version: 4.x
- Version: 0.1.0
- License: MIT
- Repository URL: https://github.com/wumail/godot-scripts-visualizer
- Issues URL: https://github.com/wumail/godot-scripts-visualizer/issues
- Download Commit: the commit (or release tag) that contains `addons/godot_visualizer_native`
- Icon URL: https://raw.githubusercontent.com/wumail/godot-scripts-visualizer/main/icon.png

## Suggested English description

Godot Visualizer Native is a standalone Godot 4 editor addon for exploring and
editing project structure. It builds script relationship maps, inspects scenes
and scene trees, edits scripts and scene nodes, and launches a browser-based
visualizer driven directly by the Godot editor plugin — with no external server
required. It also exposes a read-only `/api/v1` JSON API for AI and automation
clients.

## Repository checklist

- Root `LICENSE.md` is present.
- Addon folder includes its own `README.md` and `LICENSE.md`.
- Exported GitHub archives omit non-runtime folders through `.gitattributes`.
- Root `icon.png` is available for the AssetLib listing icon.
- The submitted commit/zip must contain a built
  `addons/godot_visualizer_native/web/visualizer.html` (run `npm run build` or
  use a release zip — the file is gitignored in source checkouts).
