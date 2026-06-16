extends SceneTree

const VisualizerManagerScript = preload("res://addons/godot_visualizer_native/visualizer_manager.gd")

var _manager: Node = null

func _initialize() -> void:
	_manager = VisualizerManagerScript.new()
	_manager.name = "VisualizerPreviewExporter"
	root.add_child(_manager)
	call_deferred("_export_preview")

func _export_preview() -> void:
	await process_frame
	var result: Dictionary = _manager.export_script_preview({})
	print("PREVIEW_EXPORT=%s" % JSON.stringify(result))
	quit(0 if result.get("ok", false) else 1)

func _finalize() -> void:
	if is_instance_valid(_manager):
		_manager.queue_free()