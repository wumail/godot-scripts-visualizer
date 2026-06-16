@tool
extends RefCounted
class_name GVNSceneMapService

func build_scene_map(args: Dictionary) -> Dictionary:
	var root_path: String = str(args.get("root", "res://"))
	var include_addons: bool = bool(args.get("include_addons", false))

	if not root_path.begins_with("res://"):
		root_path = "res://" + root_path

	var scene_paths: Array = []
	_collect_scenes(root_path, scene_paths, include_addons)

	if scene_paths.is_empty():
		return {"ok": true, "scene_map": {"scenes": [], "edges": [], "total_scenes": 0}}

	var scenes: Array = []
	for path: String in scene_paths:
		scenes.append(_parse_scene(path))

	var edges: Array = []
	for scene: Dictionary in scenes:
		for instance: String in scene.get("instances", []):
			edges.append({"from": scene["path"], "to": instance, "type": "instance"})

	return {
		"ok": true,
		"scene_map": {
			"scenes": scenes,
			"edges": edges,
			"total_scenes": scenes.size(),
		},
	}

func _collect_scenes(path: String, results: Array, include_addons: bool) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue

		var full_path := path.path_join(name)

		if dir.current_is_dir():
			if name == "addons" and not include_addons:
				name = dir.get_next()
				continue
			_collect_scenes(full_path, results, include_addons)
		elif name.ends_with(".tscn"):
			results.append(full_path)

		name = dir.get_next()
	dir.list_dir_end()

func _parse_scene(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"path": path, "error": "Cannot open file"}

	var content: String = file.get_as_text()
	file.close()

	var root_type := ""
	var nodes: Array = []
	var instances: Array = []
	var scripts: Array = []

	var lines: PackedStringArray = content.split("\n")

	var re_ext_resource := RegEx.new()
	re_ext_resource.compile('\\[ext_resource.*path="([^"]+)".*type="([^"]+)"')

	var re_node := RegEx.new()
	re_node.compile('\\[node name="([^"]+)".*type="([^"]+)"')

	var ext_resources: Dictionary = {}

	for line: String in lines:
		var m_ext := re_ext_resource.search(line)
		if m_ext:
			var res_path: String = m_ext.get_string(1)
			var res_type: String = m_ext.get_string(2)
			var id_match := RegEx.create_from_string('id="([^"]+)"').search(line)
			if id_match:
				ext_resources[id_match.get_string(1)] = {"path": res_path, "type": res_type}
				if res_type == "PackedScene":
					instances.append(res_path)
				elif res_type == "Script":
					scripts.append(res_path)
			continue

		var m_node := re_node.search(line)
		if m_node:
			var node_name: String = m_node.get_string(1)
			var node_type: String = m_node.get_string(2)
			if root_type.is_empty():
				root_type = node_type
			nodes.append({"name": node_name, "type": node_type})

	return {
		"path": path,
		"name": path.get_file().replace(".tscn", ""),
		"root_type": root_type,
		"nodes": nodes,
		"instances": instances,
		"scripts": scripts,
		"node_count": nodes.size(),
	}