extends SceneTree

const VisualizerManagerScript = preload("res://addons/godot_visualizer_native/visualizer_manager.gd")

var _manager: Node = null

func _initialize() -> void:
	_manager = VisualizerManagerScript.new()
	_manager.name = "VisualizerManagerSmoke"
	root.add_child(_manager)
	call_deferred("_run_smoke_test")

func _run_smoke_test() -> void:
	await process_frame

	var open_result: Dictionary = _manager.start_structured_api({})
	print("SMOKE_OPEN=%s" % JSON.stringify(open_result))
	if not open_result.get("ok", false):
		quit(1)
		return

	var port: int = int(open_result.get("port", -1))
	print("SMOKE_PORT=%s" % str(port))
	print("SMOKE_URL=%s" % str(open_result.get("url", "")))
	await process_frame

	var health_result := await _send_http_request(port, "GET", "/health")
	print("SMOKE_HEALTH=%s" % JSON.stringify(health_result))
	if not health_result.get("ok", false):
		_manager.stop_live_visualizer()
		quit(2)
		return

	var api_index_result := await _send_http_request(port, "GET", "/api/v1")
	print("SMOKE_API_INDEX=%s" % JSON.stringify(api_index_result))
	var api_index_body = api_index_result.get("body", {})
	if not api_index_result.get("ok", false) or api_index_body.get("resource", "") != "manifest":
		_manager.stop_live_visualizer()
		quit(7)
		return
	if not api_index_body.get("data", {}).has("schemas"):
		_manager.stop_live_visualizer()
		quit(7)
		return

	var api_runtime_result := await _send_http_request(port, "GET", "/api/v1/runtime")
	print("SMOKE_API_RUNTIME=%s" % JSON.stringify(api_runtime_result))
	if not api_runtime_result.get("ok", false) or api_runtime_result.get("body", {}).get("resource", "") != "runtime":
		_manager.stop_live_visualizer()
		quit(8)
		return

	var api_project_map_result := await _send_http_request(port, "GET", "/api/v1/project-map")
	print("SMOKE_API_PROJECT_MAP=%s" % JSON.stringify(api_project_map_result))
	if not api_project_map_result.get("ok", false) or api_project_map_result.get("body", {}).get("resource", "") != "project_map":
		_manager.stop_live_visualizer()
		quit(9)
		return

	var api_project_summary_result := await _send_http_request(port, "GET", "/api/v1/project-summary")
	print("SMOKE_API_PROJECT_SUMMARY=%s" % JSON.stringify(api_project_summary_result))
	if not api_project_summary_result.get("ok", false) or api_project_summary_result.get("body", {}).get("resource", "") != "project_summary":
		_manager.stop_live_visualizer()
		quit(10)
		return
	var project_summary_fingerprint := str(api_project_summary_result.get("body", {}).get("data", {}).get("fingerprint", ""))
	if project_summary_fingerprint.is_empty():
		_manager.stop_live_visualizer()
		quit(10)
		return

	var api_project_summary_cached_result := await _send_http_request(port, "GET", "/api/v1/project-summary?if_fingerprint=%s" % project_summary_fingerprint.uri_encode())
	print("SMOKE_API_PROJECT_SUMMARY_CACHED=%s" % JSON.stringify(api_project_summary_cached_result))
	if not api_project_summary_cached_result.get("ok", false) or not bool(api_project_summary_cached_result.get("body", {}).get("data", {}).get("unchanged", false)):
		_manager.stop_live_visualizer()
		quit(12)
		return

	var api_scene_summary_result := await _send_http_request(port, "GET", "/api/v1/scene-summary")
	print("SMOKE_API_SCENE_SUMMARY=%s" % JSON.stringify(api_scene_summary_result))
	if not api_scene_summary_result.get("ok", false) or api_scene_summary_result.get("body", {}).get("resource", "") != "scene_summary":
		_manager.stop_live_visualizer()
		quit(11)
		return

	var api_lookup_result := await _send_http_request(port, "GET", "/api/v1/lookup?path=res://tests/visualizer_cli_smoke.gd")
	print("SMOKE_API_LOOKUP=%s" % JSON.stringify(api_lookup_result))
	if not api_lookup_result.get("ok", false) or api_lookup_result.get("body", {}).get("resource", "") != "lookup":
		_manager.stop_live_visualizer()
		quit(13)
		return

	var refresh_result := await _send_http_request(
		port,
		"POST",
		"/command",
		["Content-Type: application/json"],
		JSON.stringify({"command": "refresh_map", "args": {}})
	)
	print("SMOKE_REFRESH=%s" % JSON.stringify(refresh_result))
	if not refresh_result.get("ok", false):
		_manager.stop_live_visualizer()
		quit(3)
		return

	var failure_result := await _send_http_request(
		port,
		"POST",
		"/command",
		["Content-Type: application/json"],
		JSON.stringify({"command": "unknown_command", "args": {}})
	)
	print("SMOKE_FAILURE=%s" % JSON.stringify(failure_result))
	if failure_result.get("ok", true) or int(failure_result.get("status_code", 0)) == 200:
		_manager.stop_live_visualizer()
		quit(4)
		return

	var recovery_result := await _send_http_request(
		port,
		"POST",
		"/command",
		["Content-Type: application/json"],
		JSON.stringify({"command": "refresh_map", "args": {}})
	)
	print("SMOKE_RECOVERY=%s" % JSON.stringify(recovery_result))
	if not recovery_result.get("ok", false):
		_manager.stop_live_visualizer()
		quit(5)
		return

	var stop_result: Dictionary = _manager.stop_live_visualizer()
	print("SMOKE_STOP=%s" % JSON.stringify(stop_result))
	if bool(stop_result.get("running", true)) or not str(stop_result.get("last_error", "")).is_empty():
		quit(6)
		return
	quit(0)

func _send_http_request(port: int, method: String, path: String, headers: Array = [], body: String = "") -> Dictionary:
	var peer := StreamPeerTCP.new()
	var err := peer.connect_to_host("127.0.0.1", port)
	if err != OK:
		return {"ok": false, "error": "connect failed", "code": err}

	var connect_wait := 0
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and connect_wait < 120:
		peer.poll()
		await process_frame
		connect_wait += 1

	peer.poll()

	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return {"ok": false, "error": "peer not connected", "status": peer.get_status()}

	var request_lines := PackedStringArray([
		"%s %s HTTP/1.1" % [method, path],
		"Host: 127.0.0.1:%d" % port,
		"Connection: close",
	])
	for header in headers:
		request_lines.append(str(header))
	if not body.is_empty():
		request_lines.append("Content-Length: %d" % body.to_utf8_buffer().size())
	request_lines.append("")
	request_lines.append(body)

	peer.put_data("\r\n".join(request_lines).to_utf8_buffer())

	var response := PackedByteArray()
	var wait_frames := 0
	while wait_frames < 240:
		peer.poll()
		await process_frame
		wait_frames += 1
		var status := peer.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED and response.size() > 0:
			break
		if status != StreamPeerTCP.STATUS_CONNECTED:
			continue

		var available := peer.get_available_bytes()
		if available > 0:
			var chunk = peer.get_data(available)
			if chunk[0] != OK:
				break
			response.append_array(chunk[1])

	peer.disconnect_from_host()

	if response.is_empty():
		return {"ok": false, "error": "empty response"}

	var response_text := response.get_string_from_utf8()
	var parts := response_text.split("\r\n\r\n", false, 1)
	var status_line := response_text.split("\r\n", false, 1)[0]
	var status_parts := status_line.split(" ")
	var status_code: int = int(status_parts[1]) if status_parts.size() > 1 else 0
	var response_body := parts[1] if parts.size() > 1 else ""
	var parsed_body = JSON.parse_string(response_body)
	var body_ok: bool = parsed_body is Dictionary and parsed_body.get("ok", false)
	return {
		"ok": status_code >= 200 and status_code < 300 and body_ok,
		"status_code": status_code,
		"status_line": status_line,
		"body": parsed_body if parsed_body != null else response_body,
	}

func _finalize() -> void:
	if is_instance_valid(_manager) and _manager.has_method("stop_live_visualizer"):
		_manager.stop_live_visualizer()