@tool
extends RefCounted
class_name GVNProjectMapService

func build_project_map(args: Dictionary) -> Dictionary:
	var root_path: String = str(args.get("root", "res://"))
	var include_addons: bool = bool(args.get("include_addons", false))

	if not root_path.begins_with("res://"):
		root_path = "res://" + root_path

	var script_paths: Array = []
	_collect_scripts(root_path, script_paths, include_addons)

	if script_paths.is_empty():
		return {"ok": false, "error": "No GDScript files found in " + root_path}

	var nodes: Array = []
	var class_map: Dictionary = {}

	for path: String in script_paths:
		var info: Dictionary = _parse_script(path)
		nodes.append(info)
		if info.get("class_name", "") != "":
			class_map[info["class_name"]] = path

	var edges: Array = []
	for node: Dictionary in nodes:
		var from_path: String = node["path"]
		var extends_class: String = node.get("extends", "")
		if extends_class in class_map:
			edges.append({"from": from_path, "to": class_map[extends_class], "type": "extends"})

		for ref: String in node.get("preloads", []):
			if ref.ends_with(".gd"):
				edges.append({"from": from_path, "to": ref, "type": "preload"})

		for conn: Dictionary in node.get("connections", []):
			var target: String = conn.get("target", "")
			if target in class_map:
				edges.append({
					"from": from_path,
					"to": class_map[target],
					"type": "signal",
					"signal_name": conn.get("signal", ""),
				})

	return {
		"ok": true,
		"project_map": {
			"nodes": nodes,
			"edges": edges,
			"total_scripts": nodes.size(),
			"total_connections": edges.size(),
		},
	}

func _collect_scripts(path: String, results: Array, include_addons: bool) -> void:
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
			_collect_scripts(full_path, results, include_addons)
		elif name.ends_with(".gd"):
			results.append(full_path)

		name = dir.get_next()
	dir.list_dir_end()

func _parse_script(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"path": path, "error": "Cannot open file"}

	var content: String = file.get_as_text()
	file.close()

	var lines: PackedStringArray = content.split("\n")
	var line_count: int = lines.size()

	var description := ""
	var extends_class := ""
	var class_name_str := ""
	var variables: Array = []
	var functions: Array = []
	var signals_list: Array = []
	var preloads: Array = []
	var connections: Array = []

	var re_desc := RegEx.new()
	re_desc.compile("^##\\s*@desc:\\s*(.+)")

	var re_extends := RegEx.new()
	re_extends.compile("^extends\\s+(\\w+)")

	var re_class_name := RegEx.new()
	re_class_name.compile("^class_name\\s+(\\w+)")

	var re_var := RegEx.new()
	re_var.compile("^(@export(?:\\([^)]*\\))?\\s+)?(@onready\\s+)?var\\s+(\\w+)\\s*(?::\\s*(\\w+))?(?:\\s*=\\s*(.+))?")

	var re_func := RegEx.new()
	re_func.compile("^func\\s+(\\w+)\\s*\\(([^)]*)\\)\\s*(?:->\\s*(\\w+))?")

	var re_signal := RegEx.new()
	re_signal.compile("^signal\\s+(\\w+)(?:\\(([^)]*)\\))?")

	var re_preload := RegEx.new()
	re_preload.compile("(?:preload|load)\\s*\\(\\s*\"(res://[^\"]+)\"\\s*\\)")

	var re_connect_obj := RegEx.new()
	re_connect_obj.compile("(\\w+)\\.(\\w+)\\.connect\\s*\\(")

	var re_connect_direct := RegEx.new()
	re_connect_direct.compile("^\\s*(\\w+)\\.connect\\s*\\(")

	var var_type_map: Dictionary = {}
	var func_starts: Array = []

	for i: int in range(line_count):
		var line: String = lines[i]
		var stripped: String = line.strip_edges()

		if i < 15 and description.is_empty():
			var m_desc := re_desc.search(stripped)
			if m_desc:
				description = m_desc.get_string(1)
				continue

		if extends_class.is_empty():
			var m_ext := re_extends.search(stripped)
			if m_ext:
				extends_class = m_ext.get_string(1)
				continue

		if class_name_str.is_empty():
			var m_class := re_class_name.search(stripped)
			if m_class:
				class_name_str = m_class.get_string(1)
				continue

		if not line.begins_with("\t") and not line.begins_with(" "):
			var m_var := re_var.search(stripped)
			if m_var:
				var exported: bool = m_var.get_string(1).strip_edges() != ""
				var onready: bool = m_var.get_string(2).strip_edges() != ""
				var var_name: String = m_var.get_string(3)
				var var_type: String = m_var.get_string(4).strip_edges()
				var default_val: String = m_var.get_string(5).strip_edges()

				if var_type.is_empty() and not default_val.is_empty():
					var_type = _infer_type(default_val)

				if not var_type.is_empty():
					var_type_map[var_name] = var_type

				variables.append({
					"name": var_name,
					"type": var_type,
					"exported": exported,
					"onready": onready ,
					"default": default_val,
				})

		var m_func := re_func.search(stripped)
		if m_func:
			var func_name: String = m_func.get_string(1)
			var return_type: String = m_func.get_string(3).strip_edges()
			func_starts.append({"line_idx": i, "name": func_name})
			functions.append({
				"name": func_name,
				"params": m_func.get_string(2).strip_edges(),
				"return_type": return_type,
				"line": i + 1,
				"body": "",
			})

		var m_sig := re_signal.search(stripped)
		if m_sig:
			signals_list.append({
				"name": m_sig.get_string(1),
				"params": m_sig.get_string(2).strip_edges() if m_sig.get_string(2) else "",
			})

		var m_preload := re_preload.search(stripped)
		if m_preload:
			preloads.append(m_preload.get_string(1))

		var m_conn_obj := re_connect_obj.search(stripped)
		if m_conn_obj:
			var obj_name: String = m_conn_obj.get_string(1)
			var signal_name: String = m_conn_obj.get_string(2)
			var target_type: String = var_type_map.get(obj_name, "")
			connections.append({
				"object": obj_name,
				"signal": signal_name,
				"target": target_type,
				"line": i + 1,
			})
		else:
			var m_conn_direct := re_connect_direct.search(stripped)
			if m_conn_direct:
				connections.append({
					"signal": m_conn_direct.get_string(1),
					"target": extends_class,
					"line": i + 1,
				})

	for fi: int in range(func_starts.size()):
		var start_idx: int = func_starts[fi]["line_idx"]
		var end_idx: int = line_count
		if fi + 1 < func_starts.size():
			end_idx = func_starts[fi + 1]["line_idx"]

		while end_idx > start_idx + 1 and lines[end_idx - 1].strip_edges().is_empty():
			end_idx -= 1

		for check_idx in range(start_idx + 1, end_idx):
			var check_line: String = lines[check_idx]
			if not check_line.is_empty() and not check_line.begins_with("\t") and not check_line.begins_with(" ") and not check_line.begins_with("#"):
				end_idx = check_idx
				break

		var body_lines: PackedStringArray = PackedStringArray()
		for li: int in range(start_idx, end_idx):
			body_lines.append(lines[li])

		var body: String = "\n".join(body_lines)
		if body.length() > 3000:
			body = body.substr(0, 3000) + "\n# ... (truncated)"

		functions[fi]["body"] = body
		functions[fi]["body_lines"] = end_idx - start_idx

	return {
		"path": path,
		"filename": path.get_file(),
		"folder": path.get_base_dir(),
		"class_name": class_name_str,
		"extends": extends_class,
		"description": description,
		"line_count": line_count,
		"variables": variables,
		"functions": functions,
		"signals": signals_list,
		"preloads": preloads,
		"connections": connections,
	}

func _infer_type(default_val: String) -> String:
	if default_val == "true" or default_val == "false":
		return "bool"
	if default_val.is_valid_int():
		return "int"
	if default_val.is_valid_float():
		return "float"
	if default_val.begins_with("\"") or default_val.begins_with("'"):
		return "String"
	if default_val.begins_with("Vector2"):
		return "Vector2"
	if default_val.begins_with("Vector3"):
		return "Vector3"
	if default_val.begins_with("Color"):
		return "Color"
	if default_val.begins_with("["):
		return "Array"
	if default_val.begins_with("{"):
		return "Dictionary"
	if default_val == "null":
		return "Variant"
	if default_val.ends_with(".new()"):
		return default_val.replace(".new()", "")
	return ""