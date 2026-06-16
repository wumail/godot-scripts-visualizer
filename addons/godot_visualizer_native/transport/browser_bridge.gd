@tool
extends Node
class_name GVNBrowserBridge

const TEMPLATE_PATH := "res://addons/godot_visualizer_native/web/visualizer.html"
const OUTPUT_DIR := "user://godot_visualizer_native"
const OUTPUT_FILE := "project_preview.html"
const DEFAULT_PORT := 6510
const MAX_PORT_ATTEMPTS := 32
const BOOTSTRAP_PLACEHOLDER := "<!-- %%BOOTSTRAP%% -->"
const PROJECT_DATA_PLACEHOLDER := '"%%PROJECT_DATA%%"'

var _tcp_server := TCPServer.new()
var _connections: Array = []
var _html: String = ""
var _active_port := -1
var _command_handler: Callable = Callable()
var _api_handler: Callable = Callable()
var _last_error := ""
var _last_url := ""
var _last_mode := "idle"

func _ready() -> void:
	set_process(false)

func _exit_tree() -> void:
	stop_server()

func set_command_handler(handler: Callable) -> void:
	_command_handler = handler

func set_api_handler(handler: Callable) -> void:
	_api_handler = handler

func start_live_server(project_map: Dictionary, args: Dictionary = {}) -> Dictionary:
	_last_error = ""
	if not _command_handler.is_valid():
		_last_error = "Command handler is not configured"
		return {"ok": false, "error": _last_error}

	var html_result := _build_live_html(project_map)
	if not html_result.get("ok", false):
		_last_error = str(html_result.get("error", "Failed to build live visualizer HTML"))
		return html_result

	stop_server()

	var port := DEFAULT_PORT
	var listen_err := ERR_ALREADY_IN_USE
	while port < DEFAULT_PORT + MAX_PORT_ATTEMPTS:
		listen_err = _tcp_server.listen(port, "127.0.0.1")
		if listen_err == OK:
			break
		port += 1

	if listen_err != OK:
		_last_error = "Failed to start local visualizer server"
		return {"ok": false, "error": _last_error, "code": listen_err}

	_html = str(html_result.get("html", ""))
	_active_port = port
	_last_mode = "live_server"
	_last_url = "http://127.0.0.1:%d/" % port
	_last_error = ""
	_connections.clear()
	set_process(true)

	if args.get("open_browser", true):
		OS.shell_open(_last_url)

	return {
		"ok": true,
		"mode": "live_server",
		"port": port,
		"url": _last_url,
	}

func export_static_preview(project_map: Dictionary) -> Dictionary:
	_last_error = ""
	var html_result := _build_static_html(project_map)
	if not html_result.get("ok", false):
		_last_error = str(html_result.get("error", "Failed to build static preview HTML"))
		return html_result

	var html: String = str(html_result.get("html", ""))

	var global_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(global_dir)

	var output_path := OUTPUT_DIR.path_join(OUTPUT_FILE)
	var output_file := FileAccess.open(output_path, FileAccess.WRITE)
	if output_file == null:
		_last_error = "Could not write static preview"
		return {"ok": false, "error": _last_error}
	output_file.store_string(html)
	output_file.close()

	var absolute_output := ProjectSettings.globalize_path(output_path)
	OS.shell_open(absolute_output)
	_last_mode = "static_preview"
	_last_error = ""

	return {
		"ok": true,
		"path": output_path,
		"absolute_path": absolute_output,
		"mode": "static_preview",
	}

func stop_server() -> void:
	set_process(false)
	for connection in _connections:
		var peer: StreamPeerTCP = connection.get("peer")
		if peer:
			peer.disconnect_from_host()
	_connections.clear()
	if _tcp_server.is_listening():
		_tcp_server.stop()
	_active_port = -1
	_last_url = ""
	_last_error = ""
	if _last_mode == "live_server":
		_last_mode = "idle"

func get_runtime_status() -> Dictionary:
	return {
		"ok": true,
		"mode": _last_mode,
		"running": _tcp_server.is_listening() and _active_port > 0,
		"port": _active_port,
		"url": _last_url,
		"last_error": _last_error,
	}

func _process(_delta: float) -> void:
	if _tcp_server.is_listening():
		while _tcp_server.is_connection_available():
			var peer := _tcp_server.take_connection()
			_connections.append({"peer": peer, "buffer": ""})

	for index: int in range(_connections.size() - 1, -1, -1):
		var connection: Dictionary = _connections[index]
		var peer: StreamPeerTCP = connection.get("peer")
		if peer == null:
			_connections.remove_at(index)
			continue

		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
			_connections.remove_at(index)
			continue

		var available := peer.get_available_bytes()
		if available <= 0:
			continue

		var read_result := peer.get_data(available)
		if read_result[0] != OK:
			peer.disconnect_from_host()
			_connections.remove_at(index)
			continue

		connection["buffer"] = str(connection.get("buffer", "")) + (read_result[1] as PackedByteArray).get_string_from_utf8()
		_connections[index] = connection

		if _request_complete(str(connection.get("buffer", ""))):
			_handle_request(peer, str(connection.get("buffer", "")))
			peer.disconnect_from_host()
			_connections.remove_at(index)

func _request_complete(buffer: String) -> bool:
	var header_end := buffer.find("\r\n\r\n")
	if header_end < 0:
		return false

	var content_length := 0
	for line in buffer.substr(0, header_end).split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			var parts := line.split(":", false, 1)
			if parts.size() > 1:
				content_length = int(parts[1].strip_edges())
			break

	return buffer.length() >= header_end + 4 + content_length

func _parse_query_string(query_string: String) -> Dictionary:
	var query := {}
	if query_string.is_empty():
		return query

	for pair in query_string.split("&"):
		if pair.is_empty():
			continue
		var parts := pair.split("=", false, 1)
		var key := parts[0].uri_decode()
		var value := ""
		if parts.size() > 1:
			value = parts[1].uri_decode()
		query[key] = value

	return query

func _handle_request(peer: StreamPeerTCP, request_text: String) -> void:
	var header_end := request_text.find("\r\n\r\n")
	var header_text := request_text.substr(0, header_end)
	var body := request_text.substr(header_end + 4)
	var lines := header_text.split("\r\n")
	if lines.is_empty():
		_send_response(peer, 400, "text/plain; charset=utf-8", "Bad Request")
		return

	var request_line := lines[0].split(" ")
	if request_line.size() < 2:
		_send_response(peer, 400, "text/plain; charset=utf-8", "Bad Request")
		return

	var method: String = request_line[0]
	var target: String = request_line[1]
	var target_parts := target.split("?", false, 1)
	var path: String = target_parts[0]
	var query: Dictionary = {}
	if target_parts.size() > 1:
		query = _parse_query_string(target_parts[1])

	if method == "GET" and (path == "/" or path == "/index.html"):
		_send_response(peer, 200, "text/html; charset=utf-8", _html)
		return

	if method == "GET" and path.begins_with("/api"):
		if not _api_handler.is_valid():
			_send_response(peer, 500, "application/json; charset=utf-8", JSON.stringify({"ok": false, "error": "API handler is not configured"}))
			return

		var api_result = _api_handler.call(path, query)
		var api_status := 200
		if api_result == null or not (api_result is Dictionary):
			api_result = {"ok": false, "error": "API handler returned invalid result"}
			api_status = 500
		elif not api_result.get("ok", false):
			api_status = int(api_result.get("http_status", 404))
		_send_response(peer, api_status, "application/json; charset=utf-8", JSON.stringify(api_result))
		return

	if method == "GET" and path == "/health":
		_send_response(peer, 200, "application/json; charset=utf-8", JSON.stringify({"ok": true, "port": _active_port}))
		return

	if method == "POST" and path == "/command":
		var payload = JSON.parse_string(body)
		if payload == null or not (payload is Dictionary):
			_send_response(peer, 400, "application/json; charset=utf-8", JSON.stringify({"ok": false, "error": "Invalid JSON body"}))
			return

		var command: String = str(payload.get("command", ""))
		var payload_args = payload.get("args", {})
		var args: Dictionary = payload_args if payload_args is Dictionary else {}
		if command.is_empty():
			_send_response(peer, 400, "application/json; charset=utf-8", JSON.stringify({"ok": false, "error": "Missing command"}))
			return

		var result = _command_handler.call(command, args)
		var status_code := 200
		if result == null or not (result is Dictionary):
			result = {"ok": false, "error": "Command returned invalid result"}
			status_code = 500
		if not result.get("ok", false):
			_last_error = str(result.get("error", "Command failed"))
			status_code = int(result.get("http_status", 422))
		else:
			_last_error = ""
		if command == "map_project" or command == "refresh_map":
			if result.get("ok", false) and result.has("project_map"):
				var html_result := _build_live_html(result.get("project_map", {}))
				if html_result.get("ok", false):
					_html = str(html_result.get("html", _html))
		_send_response(peer, status_code, "application/json; charset=utf-8", JSON.stringify(result))
		return

	if method == "OPTIONS":
		_send_response(peer, 204, "text/plain; charset=utf-8", "")
		return

	_send_response(peer, 404, "text/plain; charset=utf-8", "Not Found")

func _send_response(peer: StreamPeerTCP, status: int, content_type: String, body: String) -> void:
	var status_text := "OK"
	match status:
		200:
			status_text = "OK"
		204:
			status_text = "No Content"
		400:
			status_text = "Bad Request"
		422:
			status_text = "Unprocessable Content"
		404:
			status_text = "Not Found"
		500:
			status_text = "Internal Server Error"
		_:
			status_text = "OK"

	var body_bytes := body.to_utf8_buffer()
	var headers := [
		"HTTP/1.1 %d %s" % [status, status_text],
		"Content-Type: %s" % content_type,
		"Content-Length: %d" % body_bytes.size(),
		"Access-Control-Allow-Origin: *",
		"Access-Control-Allow-Headers: Content-Type",
		"Access-Control-Allow-Methods: GET, POST, OPTIONS",
		"Connection: close",
		"",
		"",
	]
	peer.put_data("\r\n".join(headers).to_utf8_buffer())
	if body_bytes.size() > 0:
		peer.put_data(body_bytes)

func _build_static_html(project_map: Dictionary) -> Dictionary:
	return _build_html(project_map, [
		"window.GODOT_VISUALIZER_STATIC = true;",
	])

func _build_live_html(project_map: Dictionary) -> Dictionary:
	return _build_html(project_map, [
		"window.GODOT_VISUALIZER_STATIC = false;",
		"window.GODOT_VISUALIZER_HTTP_COMMANDS = true;",
		"window.GODOT_VISUALIZER_COMMAND_URL = '/command';",
	])

func _build_html(project_map: Dictionary, bootstrap_lines: Array) -> Dictionary:
	if not FileAccess.file_exists(TEMPLATE_PATH):
		return {
			"ok": false,
			"error": "Built visualizer not found. Run web build first.",
			"expected_path": TEMPLATE_PATH,
		}

	var file := FileAccess.open(TEMPLATE_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Could not open built visualizer HTML"}

	var html := file.get_as_text()
	file.close()

	var bootstrap := "<script>%s</script>" % " ".join(bootstrap_lines)
	if html.find(BOOTSTRAP_PLACEHOLDER) == -1:
		return {"ok": false, "error": "Built visualizer HTML is missing bootstrap placeholder"}
	if html.find(PROJECT_DATA_PLACEHOLDER) == -1:
		return {"ok": false, "error": "Built visualizer HTML is missing project data placeholder"}
	html = html.replace(BOOTSTRAP_PLACEHOLDER, bootstrap)
	html = html.replace(PROJECT_DATA_PLACEHOLDER, JSON.stringify(project_map))
	return {"ok": true, "html": html}