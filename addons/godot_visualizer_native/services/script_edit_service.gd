@tool
extends RefCounted
class_name GVNScriptEditService

func create_script_file(args: Dictionary) -> Dictionary:
	var script_path: String = str(args.get("path", ""))
	var extends_type: String = str(args.get("extends", "Node"))
	var class_name_str: String = str(args.get("class_name", ""))

	if script_path.is_empty():
		return {"ok": false, "error": "No path provided"}

	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	if not script_path.ends_with(".gd"):
		script_path += ".gd"

	if FileAccess.file_exists(script_path):
		return {"ok": false, "error": "File already exists: " + script_path}

	var dir_path := script_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var content := ""
	if not class_name_str.is_empty():
		content += "class_name " + class_name_str + "\n"
	content += "extends " + extends_type + "\n\n\n"
	content += "func _ready() -> void:\n\tpass\n"

	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Cannot create file: " + script_path}

	file.store_string(content)
	file.close()
	return {"ok": true, "path": script_path}

func modify_variable(args: Dictionary) -> Dictionary:
	var script_path: String = str(args.get("path", ""))
	var action: String = str(args.get("action", ""))
	var old_name: String = str(args.get("old_name", ""))
	var new_name: String = str(args.get("name", ""))
	var var_type: String = str(args.get("type", ""))
	var default_val: String = str(args.get("default", ""))
	var exported: bool = bool(args.get("exported", false))
	var onready: bool = bool(args.get("onready", false))

	var lines := _read_lines(script_path)
	if lines.is_empty() and not FileAccess.file_exists(script_path):
		return {"ok": false, "error": "Cannot open file: " + script_path}

	var modified := false

	if action == "delete":
		var pattern := RegEx.new()
		pattern.compile("^(@export(?:\\([^)]*\\))?\\s+)?(?:@onready\\s+)?var\\s+" + old_name + "\\s*(?::|=|$)")
		for i: int in range(lines.size() - 1, -1, -1):
			if pattern.search(lines[i].strip_edges()):
				lines.remove_at(i)
				modified = true
				break
	elif action == "update":
		var pattern_update := RegEx.new()
		pattern_update.compile("^(@export(?:\\([^)]*\\))?\\s+)?(@onready\\s+)?var\\s+" + old_name + "\\s*(?::\\s*\\w+)?(?:\\s*=\\s*.+)?$")
		for i: int in range(lines.size()):
			if pattern_update.search(lines[i].strip_edges()):
				lines[i] = _build_var_line(new_name, var_type, default_val, exported, onready )
				modified = true
				break
	elif action == "add":
		lines.insert(_find_var_insert_position(lines), _build_var_line(new_name, var_type, default_val, exported, onready ))
		modified = true

	if not modified:
		return {"ok": false, "error": "Variable not found: " + old_name}

	return _write_lines(script_path, lines, {"ok": true, "action": action, "variable": new_name})

func modify_signal(args: Dictionary) -> Dictionary:
	var script_path: String = str(args.get("path", ""))
	var action: String = str(args.get("action", ""))
	var old_name: String = str(args.get("old_name", ""))
	var new_name: String = str(args.get("name", ""))
	var params: String = str(args.get("params", ""))

	var lines := _read_lines(script_path)
	if lines.is_empty() and not FileAccess.file_exists(script_path):
		return {"ok": false, "error": "Cannot open file: " + script_path}

	var modified := false
	if action == "delete":
		var pattern := RegEx.new()
		pattern.compile("^signal\\s+" + old_name + "(?:\\s*\\(|$)")
		for i: int in range(lines.size() - 1, -1, -1):
			if pattern.search(lines[i].strip_edges()):
				lines.remove_at(i)
				modified = true
				break
	elif action == "update":
		var pattern_update := RegEx.new()
		pattern_update.compile("^signal\\s+" + old_name + "(?:\\s*\\([^)]*\\))?$")
		for i: int in range(lines.size()):
			if pattern_update.search(lines[i].strip_edges()):
				lines[i] = _build_signal_line(new_name, params)
				modified = true
				break
	elif action == "add":
		lines.insert(_find_signal_insert_position(lines), _build_signal_line(new_name, params))
		modified = true

	if not modified:
		return {"ok": false, "error": "Signal not found: " + old_name}

	return _write_lines(script_path, lines, {"ok": true, "action": action, "signal": new_name})

func modify_function(args: Dictionary) -> Dictionary:
	var script_path: String = str(args.get("path", ""))
	var func_name: String = str(args.get("name", ""))
	var new_body: String = str(args.get("body", ""))
	return _replace_function(script_path, func_name, new_body)

func delete_function(args: Dictionary) -> Dictionary:
	var script_path: String = str(args.get("path", ""))
	var func_name: String = str(args.get("name", ""))
	return _remove_function(script_path, func_name)

func find_usages(args: Dictionary) -> Dictionary:
	var name: String = str(args.get("name", ""))
	var item_type: String = str(args.get("type", ""))
	var root_path: String = str(args.get("root", "res://"))

	if name.is_empty():
		return {"ok": false, "error": "No name provided"}

	if not root_path.begins_with("res://"):
		root_path = "res://" + root_path

	var usages: Array = []
	var script_paths: Array = []
	_collect_scripts(root_path, script_paths, false)

	var pattern := RegEx.new()
	pattern.compile("\\b" + name + "\\b")

	for path: String in script_paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var content: String = file.get_as_text()
		file.close()
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			if not pattern.search(line):
				continue
			if item_type == "variable" and RegEx.create_from_string("^\\s*(@export)?\\s*var\\s+" + name + "\\b").search(line):
				continue
			if item_type == "signal" and RegEx.create_from_string("^\\s*signal\\s+" + name + "\\b").search(line):
				continue
			if item_type == "function" and RegEx.create_from_string("^\\s*func\\s+" + name + "\\s*\\(").search(line):
				continue
			usages.append({"file": path, "line": i + 1, "code": line.strip_edges()})

	return {"ok": true, "usages": usages, "count": usages.size()}

func _replace_function(script_path: String, func_name: String, new_body: String) -> Dictionary:
	var lines := _read_lines(script_path)
	if lines.is_empty() and not FileAccess.file_exists(script_path):
		return {"ok": false, "error": "Cannot open file: " + script_path}

	var bounds := _find_function_bounds(lines, func_name)
	if bounds.is_empty():
		return {"ok": false, "error": "Function not found: " + func_name}

	for i: int in range(bounds[1] - 1, bounds[0] - 1, -1):
		lines.remove_at(i)

	var new_lines: Array = Array(new_body.split("\n"))
	for i: int in range(new_lines.size()):
		lines.insert(bounds[0] + i, new_lines[i])

	return _write_lines(script_path, lines, {"ok": true, "function": func_name})

func _remove_function(script_path: String, func_name: String) -> Dictionary:
	var lines := _read_lines(script_path)
	if lines.is_empty() and not FileAccess.file_exists(script_path):
		return {"ok": false, "error": "Cannot open file: " + script_path}

	var bounds := _find_function_bounds(lines, func_name)
	if bounds.is_empty():
		return {"ok": false, "error": "Function not found: " + func_name}

	for i: int in range(bounds[1] - 1, bounds[0] - 1, -1):
		lines.remove_at(i)

	return _write_lines(script_path, lines, {"ok": true, "deleted": func_name})

func _find_function_bounds(lines: Array, func_name: String) -> Array:
	var re_func := RegEx.new()
	re_func.compile("^func\\s+" + func_name + "\\s*\\(")
	var func_start := -1
	var func_end := -1

	for i: int in range(lines.size()):
		if func_start == -1:
			if re_func.search(String(lines[i]).strip_edges()):
				func_start = i
		elif func_start != -1:
			var stripped: String = String(lines[i]).strip_edges()
			if not stripped.is_empty() and not String(lines[i]).begins_with("\t") and not String(lines[i]).begins_with(" ") and not stripped.begins_with("#"):
				func_end = i
				break

	if func_start == -1:
		return []
	if func_end == -1:
		func_end = lines.size()

	while func_end > func_start + 1 and String(lines[func_end - 1]).strip_edges().is_empty():
		func_end -= 1

	return [func_start, func_end]

func _read_lines(script_path: String) -> Array:
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return []
	var content: String = file.get_as_text()
	file.close()
	return Array(content.split("\n"))

func _write_lines(script_path: String, lines: Array, result: Dictionary) -> Dictionary:
	var write_file := FileAccess.open(script_path, FileAccess.WRITE)
	if write_file == null:
		return {"ok": false, "error": "Cannot write to file: " + script_path}
	write_file.store_string("\n".join(PackedStringArray(lines)))
	write_file.close()
	return result

func _build_var_line(name: String, type: String, default: String, exported: bool, onready: bool) -> String:
	var line := ""
	if exported:
		line += "@export "
	if onready:
		line += "@onready "
	line += "var " + name
	if not type.is_empty():
		line += ": " + type
	if not default.is_empty():
		line += " = " + default
	return line

func _build_signal_line(name: String, params: String) -> String:
	var line := "signal " + name
	if not params.is_empty():
		line += "(" + params + ")"
	return line

func _find_var_insert_position(lines: Array) -> int:
	var last_var_line := -1
	var first_func_line := -1
	var after_class_decl := 0

	var re_var := RegEx.new()
	re_var.compile("^(@export)?\\s*(@onready)?\\s*var\\s+")
	var re_func := RegEx.new()
	re_func.compile("^func\\s+")
	var re_class := RegEx.new()
	re_class.compile("^(class_name|extends)\\s+")

	for i: int in range(lines.size()):
		var stripped: String = String(lines[i]).strip_edges()
		if re_class.search(stripped):
			after_class_decl = i + 1
		if re_var.search(stripped):
			last_var_line = i
		if re_func.search(stripped) and first_func_line == -1:
			first_func_line = i
			break

	if last_var_line != -1:
		return last_var_line + 1
	if first_func_line != -1:
		return first_func_line
	return max(after_class_decl, 2)

func _find_signal_insert_position(lines: Array) -> int:
	var last_signal_line := -1
	var first_var_line := -1
	var after_class_decl := 0

	var re_signal := RegEx.new()
	re_signal.compile("^signal\\s+")
	var re_var := RegEx.new()
	re_var.compile("^(@export)?\\s*var\\s+")
	var re_class := RegEx.new()
	re_class.compile("^(class_name|extends)\\s+")

	for i: int in range(lines.size()):
		var stripped: String = String(lines[i]).strip_edges()
		if re_class.search(stripped):
			after_class_decl = i + 1
		if re_signal.search(stripped):
			last_signal_line = i
		if re_var.search(stripped) and first_var_line == -1:
			first_var_line = i

	if last_signal_line != -1:
		return last_signal_line + 1
	if first_var_line != -1:
		return first_var_line
	return max(after_class_decl, 2)

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