@tool
extends VBoxContainer
class_name GVNVisualizerDock

var _manager: Node = null
var _status_label: Label = null
var _runtime_label: RichTextLabel = null
var _summary_label: RichTextLabel = null

func set_manager(manager: Node) -> void:
	_manager = manager

func _ready() -> void:
	if get_child_count() == 0:
		_build_ui()
	refresh_summary()

func refresh_summary() -> void:
	if not _manager or not _summary_label or not _status_label or not _runtime_label:
		return

	var lines: PackedStringArray = _manager.get_status_lines()
	_summary_label.clear()
	for line in lines:
		_summary_label.append_text("- %s\n" % line)

	var runtime: Dictionary = _manager.get_runtime_status()
	_runtime_label.clear()
	var running: bool = bool(runtime.get("running", false))
	var port: int = int(runtime.get("port", -1))
	var url: String = str(runtime.get("url", ""))
	var last_error: String = str(runtime.get("last_error", ""))
	_runtime_label.append_text("- Live server: %s\n" % ("running" if running else "stopped"))
	_runtime_label.append_text("- Port: %s\n" % (str(port) if port >= 0 else "-"))
	_runtime_label.append_text("- URL: %s\n" % (url if not url.is_empty() else "not available"))
	_runtime_label.append_text("- Last error: %s\n" % (last_error if not last_error.is_empty() else "none"))

	if _status_label.text.is_empty():
		_status_label.text = "Ready"

func _build_ui() -> void:
	custom_minimum_size = Vector2(320, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "Godot Visualizer Native"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Standalone Godot 4 plugin for script & scene visualization"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(subtitle)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)

	var button_row := HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(button_row)

	var project_btn := Button.new()
	project_btn.text = "Build Script Map"
	project_btn.pressed.connect(_on_build_script_map)
	button_row.add_child(project_btn)

	var scene_btn := Button.new()
	scene_btn.text = "Build Scene Map"
	scene_btn.pressed.connect(_on_build_scene_map)
	button_row.add_child(scene_btn)

	var preview_btn := Button.new()
	preview_btn.text = "Open Browser Visualizer"
	preview_btn.pressed.connect(_on_open_live_visualizer)
	add_child(preview_btn)

	var stop_btn := Button.new()
	stop_btn.text = "Stop Live Visualizer"
	stop_btn.pressed.connect(_on_stop_live_visualizer)
	add_child(stop_btn)

	var static_preview_btn := Button.new()
	static_preview_btn.text = "Export Static Preview"
	static_preview_btn.pressed.connect(_on_export_preview)
	add_child(static_preview_btn)

	var capability_btn := Button.new()
	capability_btn.text = "Refresh Status"
	capability_btn.pressed.connect(refresh_summary)
	add_child(capability_btn)

	var runtime_title := Label.new()
	runtime_title.text = "Runtime Status"
	runtime_title.add_theme_font_size_override("font_size", 15)
	add_child(runtime_title)

	_runtime_label = RichTextLabel.new()
	_runtime_label.fit_content = true
	_runtime_label.scroll_active = false
	_runtime_label.selection_enabled = false
	add_child(_runtime_label)

	var summary_title := Label.new()
	summary_title.text = "Service Summary"
	summary_title.add_theme_font_size_override("font_size", 15)
	add_child(summary_title)

	_summary_label = RichTextLabel.new()
	_summary_label.fit_content = true
	_summary_label.scroll_active = false
	_summary_label.selection_enabled = false
	_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_summary_label)

func _on_build_script_map() -> void:
	if not _manager:
		return
	var result: Dictionary = _manager.build_project_map({})
	if result.get("ok", false):
		var project_map: Dictionary = result.get("project_map", {})
		_status_label.text = "Script map ready: %s scripts, %s connections" % [
			project_map.get("total_scripts", 0),
			project_map.get("total_connections", 0),
		]
	else:
		_status_label.text = "Script map failed: %s" % result.get("error", "unknown error")
	refresh_summary()

func _on_build_scene_map() -> void:
	if not _manager:
		return
	var result: Dictionary = _manager.build_scene_map({})
	if result.get("ok", false):
		var scene_map: Dictionary = result.get("scene_map", {})
		_status_label.text = "Scene map ready: %s scenes" % scene_map.get("total_scenes", 0)
	else:
		_status_label.text = "Scene map failed: %s" % result.get("error", "unknown error")
	refresh_summary()

func _on_export_preview() -> void:
	if not _manager:
		return
	var result: Dictionary = _manager.export_script_preview({})
	if result.get("ok", false):
		_status_label.text = "Static preview exported: %s" % result.get("absolute_path", result.get("path", ""))
	else:
		_status_label.text = "Preview export failed: %s" % result.get("error", "unknown error")
	refresh_summary()

func _on_open_live_visualizer() -> void:
	if not _manager:
		return
	var result: Dictionary = _manager.open_live_visualizer({})
	if result.get("ok", false):
		_status_label.text = "Live visualizer opened: %s" % result.get("url", "")
	else:
		_status_label.text = "Live visualizer failed: %s" % result.get("error", "unknown error")
	refresh_summary()

func _on_stop_live_visualizer() -> void:
	if not _manager:
		return
	var result: Dictionary = _manager.stop_live_visualizer()
	if result.get("ok", false):
		_status_label.text = "Live visualizer stopped"
	else:
		_status_label.text = "Stop failed: %s" % result.get("error", "unknown error")
	refresh_summary()