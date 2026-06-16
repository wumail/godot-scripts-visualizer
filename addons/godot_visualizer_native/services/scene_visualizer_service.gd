@tool
extends RefCounted
class_name GVNSceneVisualizerService

const _SKIP_PROPS := {
	"script": true,
	"owner": true,
	"multiplayer": true,
	"editor_description": true,
}

func get_scene_hierarchy(args: Dictionary) -> Dictionary:
	var scene_path := _ensure_res_path(str(args.get("scene_path", "")))
	if scene_path.strip_edges() == "res://":
		return {"ok": false, "error": "Missing scene_path"}

	var load_result := _load_scene_root(scene_path)
	if not load_result.get("ok", false):
		return load_result

	var root: Node = load_result.get("root")
	var hierarchy := _build_hierarchy_recursive(root, ".")
	root.queue_free()

	return {"ok": true, "scene_path": scene_path, "hierarchy": hierarchy}

func get_scene_node_properties(args: Dictionary) -> Dictionary:
	var scene_path := _ensure_res_path(str(args.get("scene_path", "")))
	var node_path: String = str(args.get("node_path", "."))
	if scene_path.strip_edges() == "res://":
		return {"ok": false, "error": "Missing scene_path"}

	var load_result := _load_scene_root(scene_path)
	if not load_result.get("ok", false):
		return load_result

	var root: Node = load_result.get("root")
	var target: Node = _find_node(root, node_path)
	if target == null:
		root.queue_free()
		return {"ok": false, "error": "Node not found: " + node_path}

	var properties: Array = []
	var categories: Dictionary = {}
	for prop: Dictionary in target.get_property_list():
		var prop_name: String = str(prop.get("name", ""))
		if prop_name.begins_with("_") or _SKIP_PROPS.has(prop_name):
			continue
		var usage: int = int(prop.get("usage", 0))
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		var prop_info := {
			"name": prop_name,
			"type": prop.get("type", TYPE_NIL),
			"type_name": _type_id_to_name(int(prop.get("type", TYPE_NIL))),
			"hint": prop.get("hint", 0),
			"hint_string": prop.get("hint_string", ""),
			"value": _serialize_value(target.get(prop_name)),
			"usage": usage,
			"category": _get_property_category(target, prop_name),
		}
		var category: String = prop_info["category"]
		if not categories.has(category):
			categories[category] = []
		categories[category].append(prop_info)
		properties.append(prop_info)

	var node_type: String = target.get_class()
	var node_name: String = str(target.name)
	root.queue_free()
	return {
		"ok": true,
		"scene_path": scene_path,
		"node_path": node_path,
		"node_type": node_type,
		"node_name": node_name,
		"properties": properties,
		"categories": categories,
		"property_count": properties.size(),
	}

func set_scene_node_property(args: Dictionary) -> Dictionary:
	var scene_path := _ensure_res_path(str(args.get("scene_path", "")))
	var node_path: String = str(args.get("node_path", "."))
	var property_name: String = str(args.get("property_name", ""))
	var value = args.get("value")
	var value_type: int = int(args.get("value_type", -1))

	if scene_path.strip_edges() == "res://":
		return {"ok": false, "error": "Missing scene_path"}
	if property_name.is_empty():
		return {"ok": false, "error": "Missing property_name"}

	var load_result := _load_scene_root(scene_path)
	if not load_result.get("ok", false):
		return load_result

	var root: Node = load_result.get("root")
	var target: Node = _find_node(root, node_path)
	if target == null:
		root.queue_free()
		return {"ok": false, "error": "Node not found: " + node_path}

	var old_value = target.get(property_name)
	target.set(property_name, _parse_value(value, value_type))
	var new_value = _serialize_value(target.get(property_name))

	var save_result := _save_scene(root, scene_path)
	root.queue_free()
	if not save_result.get("ok", false):
		return save_result

	return {
		"ok": true,
		"scene_path": scene_path,
		"node_path": node_path,
		"property_name": property_name,
		"old_value": _serialize_value(old_value),
		"new_value": new_value,
	}

func add_node(args: Dictionary) -> Dictionary:
	var scene_path := _ensure_res_path(str(args.get("scene_path", "")))
	var parent_path: String = str(args.get("parent_path", "."))
	var node_type: String = str(args.get("node_type", "Node"))
	var node_name: String = str(args.get("node_name", node_type))

	var load_result := _load_scene_root(scene_path)
	if not load_result.get("ok", false):
		return load_result

	var root: Node = load_result.get("root")
	var parent: Node = _find_node(root, parent_path)
	if parent == null:
		root.queue_free()
		return {"ok": false, "error": "Parent not found: " + parent_path}

	if not ClassDB.can_instantiate(node_type):
		root.queue_free()
		return {"ok": false, "error": "Cannot instantiate node type: " + node_type}

	var instance = ClassDB.instantiate(node_type)
	if not (instance is Node):
		root.queue_free()
		return {"ok": false, "error": "Instantiated object is not a Node: " + node_type}

	var node: Node = instance
	node.name = node_name
	parent.add_child(node)
	_assign_owner_recursive(node, root)

	var save_result := _save_scene(root, scene_path)
	root.queue_free()
	if not save_result.get("ok", false):
		return save_result

	return {"ok": true, "scene_path": scene_path, "node_name": node_name, "node_type": node_type}

func remove_node(args: Dictionary) -> Dictionary:
	var scene_path := _ensure_res_path(str(args.get("scene_path", "")))
	var node_path: String = str(args.get("node_path", ""))
	var load_result := _load_scene_root(scene_path)
	if not load_result.get("ok", false):
		return load_result

	var root: Node = load_result.get("root")
	var node: Node = _find_node(root, node_path)
	if node == null or node == root:
		root.queue_free()
		return {"ok": false, "error": "Cannot remove target node: " + node_path}

	var parent: Node = node.get_parent()
	parent.remove_child(node)
	node.queue_free()

	var save_result := _save_scene(root, scene_path)
	root.queue_free()
	if not save_result.get("ok", false):
		return save_result

	return {"ok": true, "scene_path": scene_path, "removed": node_path}

func rename_node(args: Dictionary) -> Dictionary:
	var scene_path := _ensure_res_path(str(args.get("scene_path", "")))
	var node_path: String = str(args.get("node_path", ""))
	var new_name: String = str(args.get("new_name", ""))
	if new_name.is_empty():
		return {"ok": false, "error": "Missing new_name"}

	var load_result := _load_scene_root(scene_path)
	if not load_result.get("ok", false):
		return load_result

	var root: Node = load_result.get("root")
	var node: Node = _find_node(root, node_path)
	if node == null:
		root.queue_free()
		return {"ok": false, "error": "Node not found: " + node_path}

	node.name = new_name
	var save_result := _save_scene(root, scene_path)
	root.queue_free()
	if not save_result.get("ok", false):
		return save_result

	return {"ok": true, "scene_path": scene_path, "node_path": node_path, "new_name": new_name}

func move_node(args: Dictionary) -> Dictionary:
	var scene_path := _ensure_res_path(str(args.get("scene_path", "")))
	var node_path: String = str(args.get("node_path", ""))
	var new_parent_path: String = str(args.get("new_parent_path", "."))
	var new_index: int = int(args.get("new_index", -1))

	var load_result := _load_scene_root(scene_path)
	if not load_result.get("ok", false):
		return load_result

	var root: Node = load_result.get("root")
	var node: Node = _find_node(root, node_path)
	var new_parent: Node = _find_node(root, new_parent_path)
	if node == null or node == root or new_parent == null:
		root.queue_free()
		return {"ok": false, "error": "Move target not found"}

	var old_parent: Node = node.get_parent()
	old_parent.remove_child(node)
	new_parent.add_child(node)
	_assign_owner_recursive(node, root)
	if new_index >= 0:
		new_parent.move_child(node, clamp(new_index, 0, new_parent.get_child_count() - 1))

	var save_result := _save_scene(root, scene_path)
	root.queue_free()
	if not save_result.get("ok", false):
		return save_result

	return {"ok": true, "scene_path": scene_path, "node_path": node_path, "new_parent_path": new_parent_path}

func duplicate_node(args: Dictionary) -> Dictionary:
	var scene_path := _ensure_res_path(str(args.get("scene_path", "")))
	var node_path: String = str(args.get("node_path", ""))

	var load_result := _load_scene_root(scene_path)
	if not load_result.get("ok", false):
		return load_result

	var root: Node = load_result.get("root")
	var node: Node = _find_node(root, node_path)
	if node == null or node == root:
		root.queue_free()
		return {"ok": false, "error": "Cannot duplicate target node"}

	var duplicate: Node = node.duplicate()
	duplicate.name = _unique_sibling_name(node.get_parent(), "%sCopy" % node.name)
	node.get_parent().add_child(duplicate)
	node.get_parent().move_child(duplicate, node.get_index() + 1)
	_assign_owner_recursive(duplicate, root)
	var duplicate_name: String = str(duplicate.name)

	var save_result := _save_scene(root, scene_path)
	root.queue_free()
	if not save_result.get("ok", false):
		return save_result

	return {"ok": true, "scene_path": scene_path, "node_path": node_path, "duplicate_name": duplicate_name}

func reorder_node(args: Dictionary) -> Dictionary:
	var scene_path := _ensure_res_path(str(args.get("scene_path", "")))
	var node_path: String = str(args.get("node_path", ""))
	var new_index: int = int(args.get("new_index", -1))

	var load_result := _load_scene_root(scene_path)
	if not load_result.get("ok", false):
		return load_result

	var root: Node = load_result.get("root")
	var node: Node = _find_node(root, node_path)
	if node == null or node == root:
		root.queue_free()
		return {"ok": false, "error": "Cannot reorder target node"}

	var parent: Node = node.get_parent()
	parent.move_child(node, clamp(new_index, 0, parent.get_child_count() - 1))

	var save_result := _save_scene(root, scene_path)
	root.queue_free()
	if not save_result.get("ok", false):
		return save_result

	return {"ok": true, "scene_path": scene_path, "node_path": node_path, "new_index": new_index}

func _build_hierarchy_recursive(node: Node, path: String) -> Dictionary:
	var data := {
		"name": str(node.name),
		"type": node.get_class(),
		"path": path,
		"children": [],
		"child_count": node.get_child_count(),
	}
	var script = node.get_script()
	if script:
		data["script"] = script.resource_path
	var parent = node.get_parent()
	if parent:
		data["index"] = node.get_index()
	for i: int in range(node.get_child_count()):
		var child: Node = node.get_child(i)
		var child_name: String = str(child.name)
		var child_path: String = child_name if path == "." else path + "/" + child_name
		data["children"].append(_build_hierarchy_recursive(child, child_path))
	return data

func _ensure_res_path(path: String) -> String:
	if path.is_empty():
		return "res://"
	if path.begins_with("res://"):
		return path
	return "res://" + path

func _load_scene_root(scene_path: String) -> Dictionary:
	var scene = load(scene_path)
	if scene == null or not (scene is PackedScene):
		return {"ok": false, "error": "Could not load scene: " + scene_path}
	var root = scene.instantiate()
	if root == null:
		return {"ok": false, "error": "Could not instantiate scene: " + scene_path}
	return {"ok": true, "root": root}

func _find_node(root: Node, node_path: String) -> Node:
	if node_path == "." or node_path.is_empty():
		return root
	return root.get_node_or_null(node_path) as Node

func _save_scene(root: Node, scene_path: String) -> Dictionary:
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return {"ok": false, "error": "Failed to pack scene: %s" % pack_err}
	var save_err := ResourceSaver.save(packed, scene_path)
	if save_err != OK:
		return {"ok": false, "error": "Failed to save scene: %s" % save_err}
	return {"ok": true}

func _assign_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_assign_owner_recursive(child, owner)

func _unique_sibling_name(parent: Node, base_name: String) -> String:
	var candidate := base_name
	var suffix := 2
	while parent.has_node(NodePath(candidate)):
		candidate = "%s%d" % [base_name, suffix]
		suffix += 1
	return candidate

func _serialize_value(value):
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_NODE_PATH, TYPE_STRING_NAME:
			return str(value)
		TYPE_ARRAY:
			var items: Array = []
			for item in value:
				items.append(_serialize_value(item))
			return items
		TYPE_DICTIONARY:
			var data := {}
			for key in value.keys():
				data[str(key)] = _serialize_value(value[key])
			return data
		TYPE_OBJECT:
			if value is Resource and value.resource_path != "":
				return {"resource": value.resource_path, "type": value.get_class()}
			return str(value)
		_:
			return str(value)

func _parse_value(value, type_hint: int):
	match type_hint:
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			return str(value)
		TYPE_VECTOR2:
			if value is Dictionary:
				return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
		TYPE_VECTOR3:
			if value is Dictionary:
				return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
		TYPE_COLOR:
			if value is Dictionary:
				return Color(float(value.get("r", 0.0)), float(value.get("g", 0.0)), float(value.get("b", 0.0)), float(value.get("a", 1.0)))
		TYPE_ARRAY:
			return value if value is Array else []
		TYPE_DICTIONARY:
			return value if value is Dictionary else {}
	return value

func _get_property_category(node: Node, prop_name: String) -> String:
	var cls: String = node.get_class()
	while cls != "":
		for prop: Dictionary in ClassDB.class_get_property_list(cls, true):
			if prop.get("name", "") == prop_name:
				return cls
		cls = ClassDB.get_parent_class(cls)
	return node.get_class()

func _type_id_to_name(type_id: int) -> String:
	match type_id:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_COLOR: return "Color"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT: return "Object"
		_: return "Variant"