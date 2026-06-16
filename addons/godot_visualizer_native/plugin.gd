@tool
extends EditorPlugin

const VisualizerManagerScript = preload("res://addons/godot_visualizer_native/visualizer_manager.gd")
const VisualizerDockScript = preload("res://addons/godot_visualizer_native/ui/visualizer_dock.gd")

var _manager: Node = null
var _dock: Control = null

func _enter_tree() -> void:
	_manager = VisualizerManagerScript.new()
	_manager.name = "VisualizerManager"
	add_child(_manager)

	_dock = VisualizerDockScript.new()
	_dock.name = "Visualizer"
	_dock.set_manager(_manager)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	if _dock.has_method("refresh_summary"):
		_dock.refresh_summary()

func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

	if _manager:
		_manager.queue_free()
		_manager = null