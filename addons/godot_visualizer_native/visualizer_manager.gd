@tool
extends Node
class_name GVNVisualizerManager

const ProjectMapServiceScript = preload("res://addons/godot_visualizer_native/services/project_map_service.gd")
const SceneMapServiceScript = preload("res://addons/godot_visualizer_native/services/scene_map_service.gd")
const ScriptEditServiceScript = preload("res://addons/godot_visualizer_native/services/script_edit_service.gd")
const SceneVisualizerServiceScript = preload("res://addons/godot_visualizer_native/services/scene_visualizer_service.gd")
const BrowserBridgeScript = preload("res://addons/godot_visualizer_native/transport/browser_bridge.gd")

var _project_map_service
var _scene_map_service
var _script_edit_service
var _scene_visualizer_service
var _browser_bridge

func _ready() -> void:
	_project_map_service = ProjectMapServiceScript.new()
	_scene_map_service = SceneMapServiceScript.new()
	_script_edit_service = ScriptEditServiceScript.new()
	_scene_visualizer_service = SceneVisualizerServiceScript.new()
	_browser_bridge = BrowserBridgeScript.new()
	_browser_bridge.name = "BrowserBridge"
	add_child(_browser_bridge)
	_browser_bridge.set_command_handler(Callable(self , "execute_command"))
	_browser_bridge.set_api_handler(Callable(self , "get_structured_api_response"))

func _exit_tree() -> void:
	if _browser_bridge and _browser_bridge.has_method("stop_server"):
		_browser_bridge.stop_server()

func get_capability_summary() -> Dictionary:
	return {
		"project_map": true,
		"scene_map": true,
		"script_edit_service": true,
		"scene_edit_service": true,
		"script_edit_ui": true,
		"scene_edit_ui": true,
		"browser_preview": true,
		"live_transport": true,
		"browser_live_visualizer": true,
		"native_full_ui": false,
		"static_preview_only": false,
	}

func get_status_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var runtime := get_runtime_status()
	lines.append("Project map service: ready")
	lines.append("Scene map service: ready")
	lines.append("Script edit service: ready")
	lines.append("Scene visualizer service: ready")
	lines.append("Browser static preview: available after web build")
	if runtime.get("running", false):
		lines.append("Live browser transport: running on %s" % runtime.get("url", ""))
	else:
		lines.append("Live browser transport: stopped")
	if not str(runtime.get("last_error", "")).is_empty():
		lines.append("Last live transport error: %s" % runtime.get("last_error", ""))
	lines.append("Current stable mode: browser visualizer with live command transport")
	return lines

func build_project_map(args: Dictionary = {}) -> Dictionary:
	return _project_map_service.build_project_map(args)

func build_scene_map(args: Dictionary = {}) -> Dictionary:
	return _scene_map_service.build_scene_map(args)

func export_script_preview(args: Dictionary = {}) -> Dictionary:
	var result := build_project_map(args)
	if not result.get("ok", false):
		return result
	return _browser_bridge.export_static_preview(result.get("project_map", {}))

func open_live_visualizer(args: Dictionary = {}) -> Dictionary:
	var result := build_project_map(args)
	if not result.get("ok", false):
		return result
	return _browser_bridge.start_live_server(result.get("project_map", {}), args)

func start_structured_api(args: Dictionary = {}) -> Dictionary:
	var options: Dictionary = args.duplicate(true)
	options["open_browser"] = false
	var result := open_live_visualizer(options)
	if result.get("ok", false):
		result["api_base_url"] = "%sapi/v1" % result.get("url", "")
		result["api_manifest_url"] = "%sapi/v1" % result.get("url", "")
		result["api_protocol"] = "godot_visualizer_native.v1"
	return result

func stop_live_visualizer() -> Dictionary:
	_browser_bridge.stop_server()
	var runtime := get_runtime_status()
	runtime["ok"] = true
	return runtime

func get_runtime_status() -> Dictionary:
	var runtime: Dictionary = _browser_bridge.get_runtime_status()
	runtime["capabilities"] = get_capability_summary()
	return runtime

func get_structured_api_response(path: String, query: Dictionary = {}) -> Dictionary:
	match path:
		"/api", "/api/", "/api/v1", "/api/v1/":
			return _api_success("manifest", _build_api_manifest(), query)
		"/api/runtime", "/api/v1/runtime":
			return _api_success("runtime", get_runtime_status(), query)
		"/api/capabilities", "/api/v1/capabilities":
			return _api_success("capabilities", get_capability_summary(), query)
		"/api/status-lines", "/api/v1/status-lines":
			return _api_success("status_lines", {"lines": Array(get_status_lines())}, query)
		"/api/lookup", "/api/v1/lookup":
			return _lookup_response(query)
		"/api/project-summary", "/api/v1/project-summary":
			return _project_summary_response(query)
		"/api/project-map", "/api/v1/project-map":
			return _wrap_service_result("project_map", build_project_map(_api_query_to_args(query)), query, "project_map")
		"/api/scene-summary", "/api/v1/scene-summary":
			return _scene_summary_response(query)
		"/api/scene-map", "/api/v1/scene-map":
			return _wrap_service_result("scene_map", build_scene_map(_api_query_to_args(query)), query, "scene_map")
		_:
			return _api_error("not_found", "Unknown API route", path, 404, query)

func _build_api_manifest() -> Dictionary:
	return {
		"service": "godot_visualizer_native",
		"protocol": "godot_visualizer_native.v1",
		"version": "v1",
		"canonical_base_path": "/api/v1",
		"legacy_alias_base_path": "/api",
		"audience": ["ai_agent", "automation", "developer_tooling"],
		"read_only": true,
		"parsing_hints": [
			"Always read the top-level data field for the resource payload.",
			"Use the top-level resource field as the stable discriminator.",
			"Treat ok=false as a terminal request failure and inspect error.code plus error.message.",
			"Prefer summary resources before full maps when an AI client needs low-token project awareness.",
			"Compare summary fingerprints before re-fetching full maps.",
		],
		"recommended_sequence": [
			"GET /api/v1",
			"GET /api/v1/runtime",
			"GET /api/v1/project-summary",
			"GET /api/v1/scene-summary",
			"GET /api/v1/lookup?path=res://path/to/file.gd",
			"GET /api/v1/project-map",
			"GET /api/v1/scene-map",
		],
		"ai_entrypoints": [
			"/api/v1",
			"/api/v1/project-summary",
			"/api/v1/scene-summary",
			"/api/v1/lookup",
		],
		"response_contract": {
			"success": ["ok", "protocol", "version", "resource", "generated_at", "query", "data"],
			"error": ["ok", "protocol", "version", "resource", "generated_at", "query", "error"],
		},
		"schemas": _build_api_schemas(),
		"endpoints": [
			{
				"path": "/api/v1",
				"method": "GET",
				"resource": "manifest",
				"description": "Protocol manifest optimized for AI and automation clients",
				"response_schema": "manifest_response",
			},
			{
				"path": "/api/v1/runtime",
				"method": "GET",
				"resource": "runtime",
				"description": "Host runtime status, URL, port, and capability summary",
				"response_schema": "runtime_response",
			},
			{
				"path": "/api/v1/capabilities",
				"method": "GET",
				"resource": "capabilities",
				"description": "Feature flags for the visualizer host",
				"response_schema": "capabilities_response",
			},
			{
				"path": "/api/v1/status-lines",
				"method": "GET",
				"resource": "status_lines",
				"description": "Human-readable operational summary lines",
				"response_schema": "status_lines_response",
			},
			{
				"path": "/api/v1/lookup",
				"method": "GET",
				"resource": "lookup",
				"description": "Targeted lookup for scripts, functions, signals, scenes, and nodes without fetching full maps",
				"query": {
					"kind": "any|script|scene",
					"path": "exact resource path",
					"path_contains": "substring match",
					"class_name": "exact script class name",
					"function_name": "exact function name",
					"signal_name": "exact signal name",
					"scene_path": "exact scene path",
					"node_name": "exact scene node name",
					"root_type": "exact scene root type",
					"script_path": "exact script path referenced by a scene",
					"instance_path": "exact instanced scene path",
					"limit": 10,
					"root": "res://",
					"include_addons": false,
				},
				"response_schema": "lookup_response",
			},
			{
				"path": "/api/v1/project-summary",
				"method": "GET",
				"resource": "project_summary",
				"description": "Compact script graph summary optimized for AI first-pass reading",
				"query": {"root": "res://", "include_addons": false, "if_fingerprint": "optional cached fingerprint"},
				"response_schema": "project_summary_response",
			},
			{
				"path": "/api/v1/project-map",
				"method": "GET",
				"resource": "project_map",
				"description": "Structured script graph for AI analysis and navigation",
				"query": {"root": "res://", "include_addons": false},
				"response_schema": "project_map_response",
			},
			{
				"path": "/api/v1/scene-summary",
				"method": "GET",
				"resource": "scene_summary",
				"description": "Compact scene graph summary optimized for AI first-pass reading",
				"query": {"root": "res://", "include_addons": false, "if_fingerprint": "optional cached fingerprint"},
				"response_schema": "scene_summary_response",
			},
			{
				"path": "/api/v1/scene-map",
				"method": "GET",
				"resource": "scene_map",
				"description": "Structured scene graph and scene references",
				"query": {"root": "res://", "include_addons": false},
				"response_schema": "scene_map_response",
			},
		],
	}

func _build_api_schemas() -> Dictionary:
	return {
		"envelope_success": {
			"type": "object",
			"required": ["ok", "protocol", "version", "resource", "generated_at", "query", "data"],
			"properties": {
				"ok": {"type": "boolean", "const": true},
				"protocol": {"type": "string", "const": "godot_visualizer_native.v1"},
				"version": {"type": "string", "const": "v1"},
				"resource": {"type": "string"},
				"generated_at": {"type": "string", "format": "datetime"},
				"query": {"type": "object"},
				"data": {"type": "object|array|string|number|boolean|null"},
			},
		},
		"envelope_error": {
			"type": "object",
			"required": ["ok", "protocol", "version", "resource", "generated_at", "query", "error"],
			"properties": {
				"ok": {"type": "boolean", "const": false},
				"protocol": {"type": "string", "const": "godot_visualizer_native.v1"},
				"version": {"type": "string", "const": "v1"},
				"resource": {"type": "string", "const": "error"},
				"generated_at": {"type": "string", "format": "datetime"},
				"query": {"type": "object"},
				"error": {
					"type": "object",
					"required": ["code", "message", "path"],
					"properties": {
						"code": {"type": "string"},
						"message": {"type": "string"},
						"path": {"type": "string"},
					},
				},
			},
		},
		"resources": {
			"manifest_response": {
				"envelope": "envelope_success",
				"resource": "manifest",
				"data_required": ["service", "protocol", "version", "canonical_base_path", "schemas", "endpoints"],
			},
			"runtime_response": {
				"envelope": "envelope_success",
				"resource": "runtime",
				"data_required": ["ok", "mode", "running", "port", "url", "last_error", "capabilities"],
			},
			"capabilities_response": {
				"envelope": "envelope_success",
				"resource": "capabilities",
				"data_required": ["project_map", "scene_map", "browser_live_visualizer"],
			},
			"status_lines_response": {
				"envelope": "envelope_success",
				"resource": "status_lines",
				"data_required": ["lines"],
			},
			"project_summary_response": {
				"envelope": "envelope_success",
				"resource": "project_summary",
				"data_required": ["root", "include_addons", "fingerprint", "fingerprint_algorithm", "unchanged", "totals", "top_folders", "script_highlights", "relationship_types"],
			},
			"project_map_response": {
				"envelope": "envelope_success",
				"resource": "project_map",
				"data_required": ["nodes", "edges", "total_scripts", "total_connections"],
			},
			"lookup_response": {
				"envelope": "envelope_success",
				"resource": "lookup",
				"data_required": ["kind", "limit", "filters", "counts", "script_matches", "scene_matches"],
			},
			"scene_summary_response": {
				"envelope": "envelope_success",
				"resource": "scene_summary",
				"data_required": ["root", "include_addons", "fingerprint", "fingerprint_algorithm", "unchanged", "totals", "root_types", "scene_highlights", "instanced_scene_paths"],
			},
			"scene_map_response": {
				"envelope": "envelope_success",
				"resource": "scene_map",
				"data_required": ["scenes", "edges", "total_scenes"],
			},
		},
	}

func _project_summary_response(query: Dictionary) -> Dictionary:
	var args := _api_query_to_args(query)
	var service_result := build_project_map(args)
	if not service_result.get("ok", false):
		return _api_error(
			"service_error",
			str(service_result.get("error", "Service request failed")),
			"/api/v1/project-summary",
			int(service_result.get("http_status", 422)),
			query
		)
	var project_map: Dictionary = service_result.get("project_map", {})
	var summary := _build_project_summary(project_map, args)
	_apply_fingerprint_state(summary, query)
	return _api_success("project_summary", summary, query)

func _lookup_response(query: Dictionary) -> Dictionary:
	var args := _api_query_to_args(query)
	var kind := str(query.get("kind", "any")).to_lower()
	var limit: int = max(1, _parse_int(query.get("limit", 10), 10))
	if kind != "any" and kind != "script" and kind != "scene":
		return _api_error("invalid_kind", "Lookup kind must be any, script, or scene", "/api/v1/lookup", 400, query)

	var filters := {
		"path": str(query.get("path", "")),
		"path_contains": str(query.get("path_contains", "")),
		"class_name": str(query.get("class_name", "")),
		"function_name": str(query.get("function_name", "")),
		"signal_name": str(query.get("signal_name", "")),
		"scene_path": str(query.get("scene_path", "")),
		"node_name": str(query.get("node_name", "")),
		"root_type": str(query.get("root_type", "")),
		"script_path": str(query.get("script_path", "")),
		"instance_path": str(query.get("instance_path", "")),
	}

	if not _has_lookup_filter(filters):
		return _api_error("missing_filter", "Lookup requires at least one filter", "/api/v1/lookup", 400, query)

	var script_matches: Array = []
	var scene_matches: Array = []

	if kind == "any" or kind == "script":
		var project_result := build_project_map(args)
		if not project_result.get("ok", false):
			return _api_error("service_error", str(project_result.get("error", "Service request failed")), "/api/v1/lookup", int(project_result.get("http_status", 422)), query)
		script_matches = _lookup_scripts(project_result.get("project_map", {}), filters, limit)

	if kind == "any" or kind == "scene":
		var scene_result := build_scene_map(args)
		if not scene_result.get("ok", false):
			return _api_error("service_error", str(scene_result.get("error", "Service request failed")), "/api/v1/lookup", int(scene_result.get("http_status", 422)), query)
		scene_matches = _lookup_scenes(scene_result.get("scene_map", {}), filters, limit)

	return _api_success("lookup", {
		"kind": kind,
		"limit": limit,
		"filters": _compact_lookup_filters(filters),
		"counts": {
			"script_matches": script_matches.size(),
			"scene_matches": scene_matches.size(),
		},
		"script_matches": script_matches,
		"scene_matches": scene_matches,
	}, query)

func _scene_summary_response(query: Dictionary) -> Dictionary:
	var args := _api_query_to_args(query)
	var service_result := build_scene_map(args)
	if not service_result.get("ok", false):
		return _api_error(
			"service_error",
			str(service_result.get("error", "Service request failed")),
			"/api/v1/scene-summary",
			int(service_result.get("http_status", 422)),
			query
		)
	var scene_map: Dictionary = service_result.get("scene_map", {})
	var summary := _build_scene_summary(scene_map, args)
	_apply_fingerprint_state(summary, query)
	return _api_success("scene_summary", summary, query)

func _build_project_summary(project_map: Dictionary, args: Dictionary) -> Dictionary:
	var nodes: Array = project_map.get("nodes", [])
	var edges: Array = project_map.get("edges", [])
	var folder_counts := {}
	var relationship_types := {}
	var class_names: Array = []
	var script_highlights: Array = []

	for node in nodes:
		if not (node is Dictionary):
			continue
		var folder := str(node.get("folder", "res://"))
		folder_counts[folder] = int(folder_counts.get(folder, 0)) + 1
		var script_class_name := str(node.get("class_name", ""))
		if not script_class_name.is_empty():
			class_names.append(script_class_name)
		script_highlights.append({
			"path": node.get("path", ""),
			"filename": node.get("filename", ""),
			"class_name": script_class_name,
			"extends": node.get("extends", ""),
			"function_count": Array(node.get("functions", [])).size(),
			"signal_count": Array(node.get("signals", [])).size(),
			"variable_count": Array(node.get("variables", [])).size(),
			"preload_count": Array(node.get("preloads", [])).size(),
			"connection_count": Array(node.get("connections", [])).size(),
		})

	for edge in edges:
		if edge is Dictionary:
			var relation := str(edge.get("type", "unknown"))
			relationship_types[relation] = int(relationship_types.get(relation, 0)) + 1

	script_highlights.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("function_count", 0)) > int(b.get("function_count", 0))
	)

	return {
		"root": str(args.get("root", "res://")),
		"include_addons": bool(args.get("include_addons", false)),
		"fingerprint": _compute_fingerprint(project_map),
		"fingerprint_algorithm": "md5-json-v1",
		"unchanged": false,
		"totals": {
			"scripts": int(project_map.get("total_scripts", nodes.size())),
			"relationships": int(project_map.get("total_connections", edges.size())),
			"classes": class_names.size(),
		},
		"top_folders": _top_count_pairs(folder_counts, 5),
		"relationship_types": _top_count_pairs(relationship_types, 10),
		"script_highlights": script_highlights.slice(0, min(script_highlights.size(), 8)),
	}

func _build_scene_summary(scene_map: Dictionary, args: Dictionary) -> Dictionary:
	var scenes: Array = scene_map.get("scenes", [])
	var edges: Array = scene_map.get("edges", [])
	var root_type_counts := {}
	var instanced_scene_counts := {}
	var total_nodes := 0
	var total_scripts := 0
	var scene_highlights: Array = []

	for scene in scenes:
		if not (scene is Dictionary):
			continue
		var root_type := str(scene.get("root_type", ""))
		if not root_type.is_empty():
			root_type_counts[root_type] = int(root_type_counts.get(root_type, 0)) + 1
		var instances: Array = scene.get("instances", [])
		var scripts: Array = scene.get("scripts", [])
		var node_count := int(scene.get("node_count", Array(scene.get("nodes", [])).size()))
		total_nodes += node_count
		total_scripts += scripts.size()
		for instance_path in instances:
			instanced_scene_counts[str(instance_path)] = int(instanced_scene_counts.get(str(instance_path), 0)) + 1
		scene_highlights.append({
			"path": scene.get("path", ""),
			"name": scene.get("name", ""),
			"root_type": root_type,
			"node_count": node_count,
			"instance_count": instances.size(),
			"script_count": scripts.size(),
		})

	scene_highlights.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("node_count", 0)) > int(b.get("node_count", 0))
	)

	return {
		"root": str(args.get("root", "res://")),
		"include_addons": bool(args.get("include_addons", false)),
		"fingerprint": _compute_fingerprint(scene_map),
		"fingerprint_algorithm": "md5-json-v1",
		"unchanged": false,
		"totals": {
			"scenes": int(scene_map.get("total_scenes", scenes.size())),
			"instance_edges": edges.size(),
			"nodes": total_nodes,
			"script_refs": total_scripts,
		},
		"root_types": _top_count_pairs(root_type_counts, 10),
		"instanced_scene_paths": _top_count_pairs(instanced_scene_counts, 10),
		"scene_highlights": scene_highlights.slice(0, min(scene_highlights.size(), 8)),
	}

func _lookup_scripts(project_map: Dictionary, filters: Dictionary, limit: int) -> Array:
	var matches: Array = []
	for node in project_map.get("nodes", []):
		if not (node is Dictionary):
			continue
		var matched_on := []
		if not _script_matches_filters(node, filters, matched_on):
			continue
		var matched_functions := _matching_named_items(node.get("functions", []), str(filters.get("function_name", "")))
		var matched_signals := _matching_named_items(node.get("signals", []), str(filters.get("signal_name", "")))
		matches.append({
			"path": node.get("path", ""),
			"filename": node.get("filename", ""),
			"class_name": node.get("class_name", ""),
			"extends": node.get("extends", ""),
			"line_count": node.get("line_count", 0),
			"matched_on": matched_on,
			"matched_functions": matched_functions,
			"matched_signals": matched_signals,
		})
		if matches.size() >= limit:
			break
	return matches

func _lookup_scenes(scene_map: Dictionary, filters: Dictionary, limit: int) -> Array:
	var matches: Array = []
	for scene in scene_map.get("scenes", []):
		if not (scene is Dictionary):
			continue
		var matched_on := []
		if not _scene_matches_filters(scene, filters, matched_on):
			continue
		matches.append({
			"path": scene.get("path", ""),
			"name": scene.get("name", ""),
			"root_type": scene.get("root_type", ""),
			"node_count": scene.get("node_count", 0),
			"matched_on": matched_on,
			"scripts": scene.get("scripts", []),
			"instances": scene.get("instances", []),
			"node_names": _extract_scene_node_names(scene.get("nodes", [])),
		})
		if matches.size() >= limit:
			break
	return matches

func _script_matches_filters(node: Dictionary, filters: Dictionary, matched_on: Array) -> bool:
	var path_filter := str(filters.get("path", ""))
	var path_contains_filter := str(filters.get("path_contains", ""))
	var class_name_filter := str(filters.get("class_name", ""))
	var function_name_filter := str(filters.get("function_name", ""))
	var signal_name_filter := str(filters.get("signal_name", ""))
	var node_path := str(node.get("path", ""))
	if not path_filter.is_empty() and node_path != path_filter:
		return false
	if not path_filter.is_empty():
		matched_on.append("path")
	if not path_contains_filter.is_empty() and node_path.findn(path_contains_filter) == -1:
		return false
	if not path_contains_filter.is_empty():
		matched_on.append("path_contains")
	var node_class_name := str(node.get("class_name", ""))
	if not class_name_filter.is_empty() and node_class_name != class_name_filter:
		return false
	if not class_name_filter.is_empty():
		matched_on.append("class_name")
	if not function_name_filter.is_empty() and _matching_named_items(node.get("functions", []), function_name_filter).is_empty():
		return false
	if not function_name_filter.is_empty():
		matched_on.append("function_name")
	if not signal_name_filter.is_empty() and _matching_named_items(node.get("signals", []), signal_name_filter).is_empty():
		return false
	if not signal_name_filter.is_empty():
		matched_on.append("signal_name")
	return true

func _scene_matches_filters(scene: Dictionary, filters: Dictionary, matched_on: Array) -> bool:
	var path_filter := str(filters.get("path", ""))
	var path_contains_filter := str(filters.get("path_contains", ""))
	var scene_path_filter := str(filters.get("scene_path", ""))
	var node_name_filter := str(filters.get("node_name", ""))
	var root_type_filter := str(filters.get("root_type", ""))
	var script_path_filter := str(filters.get("script_path", ""))
	var instance_path_filter := str(filters.get("instance_path", ""))
	var scene_path := str(scene.get("path", ""))
	if not path_filter.is_empty() and scene_path != path_filter:
		return false
	if not path_filter.is_empty():
		matched_on.append("path")
	if not path_contains_filter.is_empty() and scene_path.findn(path_contains_filter) == -1:
		return false
	if not path_contains_filter.is_empty():
		matched_on.append("path_contains")
	if not scene_path_filter.is_empty() and scene_path != scene_path_filter:
		return false
	if not scene_path_filter.is_empty():
		matched_on.append("scene_path")
	var root_type := str(scene.get("root_type", ""))
	if not root_type_filter.is_empty() and root_type != root_type_filter:
		return false
	if not root_type_filter.is_empty():
		matched_on.append("root_type")
	if not node_name_filter.is_empty() and not _scene_nodes_have_name(scene.get("nodes", []), node_name_filter):
		return false
	if not node_name_filter.is_empty():
		matched_on.append("node_name")
	if not script_path_filter.is_empty() and not Array(scene.get("scripts", [])).has(script_path_filter):
		return false
	if not script_path_filter.is_empty():
		matched_on.append("script_path")
	if not instance_path_filter.is_empty() and not Array(scene.get("instances", [])).has(instance_path_filter):
		return false
	if not instance_path_filter.is_empty():
		matched_on.append("instance_path")
	return true

func _matching_named_items(items: Array, target_name: String) -> Array:
	var matches: Array = []
	if target_name.is_empty():
		return matches
	for item in items:
		if item is Dictionary and str(item.get("name", "")) == target_name:
			matches.append(item.get("name", ""))
	return matches

func _scene_nodes_have_name(nodes: Array, target_name: String) -> bool:
	for node in nodes:
		if node is Dictionary and str(node.get("name", "")) == target_name:
			return true
	return false

func _extract_scene_node_names(nodes: Array) -> Array:
	var names: Array = []
	for node in nodes:
		if node is Dictionary:
			names.append(node.get("name", ""))
	return names

func _has_lookup_filter(filters: Dictionary) -> bool:
	for value in filters.values():
		if not str(value).is_empty():
			return true
	return false

func _compact_lookup_filters(filters: Dictionary) -> Dictionary:
	var compact := {}
	for key in filters.keys():
		var value := str(filters.get(key, ""))
		if not value.is_empty():
			compact[key] = value
	return compact

func _apply_fingerprint_state(summary: Dictionary, query: Dictionary) -> void:
	var requested_fingerprint := str(query.get("if_fingerprint", ""))
	var current_fingerprint := str(summary.get("fingerprint", ""))
	summary["unchanged"] = not requested_fingerprint.is_empty() and requested_fingerprint == current_fingerprint

func _compute_fingerprint(value) -> String:
	return JSON.stringify(value).md5_text()

func _top_count_pairs(counts: Dictionary, limit: int) -> Array:
	var pairs: Array = []
	for key in counts.keys():
		pairs.append({"name": str(key), "count": int(counts.get(key, 0))})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	return pairs.slice(0, min(pairs.size(), limit))

func _wrap_service_result(resource: String, service_result: Dictionary, query: Dictionary, payload_key: String) -> Dictionary:
	if not service_result.get("ok", false):
		return _api_error(
			"service_error",
			str(service_result.get("error", "Service request failed")),
			"/api/v1/%s" % resource.replace("_", "-"),
			int(service_result.get("http_status", 422)),
			query
		)
	return _api_success(resource, service_result.get(payload_key, {}), query)

func _api_success(resource: String, data: Variant, query: Dictionary = {}) -> Dictionary:
	return {
		"ok": true,
		"protocol": "godot_visualizer_native.v1",
		"version": "v1",
		"resource": resource,
		"generated_at": Time.get_datetime_string_from_system(true, false),
		"query": query.duplicate(true),
		"data": data,
	}

func _api_error(code: String, message: String, path: String, http_status: int = 400, query: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"protocol": "godot_visualizer_native.v1",
		"version": "v1",
		"resource": "error",
		"generated_at": Time.get_datetime_string_from_system(true, false),
		"query": query.duplicate(true),
		"error": {
			"code": code,
			"message": message,
			"path": path,
		},
		"http_status": http_status,
	}

func _api_query_to_args(query: Dictionary) -> Dictionary:
	var args := {}
	if query.has("root"):
		args["root"] = str(query.get("root", "res://"))
	if query.has("include_addons"):
		args["include_addons"] = _parse_bool(query.get("include_addons", false))
	return args

func _parse_bool(value) -> bool:
	if value is bool:
		return value
	var normalized := str(value).strip_edges().to_lower()
	return normalized == "1" or normalized == "true" or normalized == "yes" or normalized == "on"

func _parse_int(value, fallback: int) -> int:
	if value is int:
		return value
	var text := str(value).strip_edges()
	if text.is_empty():
		return fallback
	return int(text)

func execute_command(command: String, args: Dictionary) -> Dictionary:
	match command:
		"map_project", "refresh_map":
			return build_project_map(args)
		"map_scenes":
			return build_scene_map(args)
		"create_script_file":
			return _script_edit_service.create_script_file(args)
		"modify_variable":
			return _script_edit_service.modify_variable(args)
		"modify_signal":
			return _script_edit_service.modify_signal(args)
		"modify_function":
			return _script_edit_service.modify_function(args)
		"modify_function_delete":
			return _script_edit_service.delete_function(args)
		"find_usages":
			return _script_edit_service.find_usages(args)
		"get_scene_hierarchy":
			return _scene_visualizer_service.get_scene_hierarchy(args)
		"get_scene_node_properties":
			return _scene_visualizer_service.get_scene_node_properties(args)
		"set_scene_node_property":
			return _scene_visualizer_service.set_scene_node_property(args)
		"add_node":
			return _scene_visualizer_service.add_node(args)
		"remove_node":
			return _scene_visualizer_service.remove_node(args)
		"rename_node":
			return _scene_visualizer_service.rename_node(args)
		"move_node":
			return _scene_visualizer_service.move_node(args)
		"duplicate_node":
			return _scene_visualizer_service.duplicate_node(args)
		"reorder_node":
			return _scene_visualizer_service.reorder_node(args)
		_:
			return {"ok": false, "error": "Unknown visualizer command: " + command}

func get_services() -> Dictionary:
	return {
		"project_map_service": _project_map_service,
		"scene_map_service": _scene_map_service,
		"script_edit_service": _script_edit_service,
		"scene_visualizer_service": _scene_visualizer_service,
	}