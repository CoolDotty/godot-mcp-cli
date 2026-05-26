@tool
## MCP commands for managing the GDQuest GDScript Formatter addon and binary.
##
## Provides tools to:
##   - check_formatter            — Check if the formatter addon/binary is installed
##   - install_formatter_addon    — Download the addon (godot-addon.zip) from GitHub releases
##   - install_formatter_binary   — Download the platform binary from GitHub releases
##   - format_gdscript            — Format a GDScript file using the installed binary
##
## Async operations use HTTPRequest + signals + a state tracker,
## since the MCP server core calls process_command synchronously.
class_name MCPFormatterCommands
extends MCPBaseCommandProcessor

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const GDQ_ADDON_PATH := "res://addons/GDQuest_GDScript_formatter"
const GDQ_PLUGIN_CFG := GDQ_ADDON_PATH + "/plugin.cfg"

const URL_GITHUB_API_LATEST_RELEASE := "https://api.github.com/repos/gdquest/GDScript-formatter/releases/latest"
const ADDON_ZIP_ASSET_NAME := "godot-addon.zip"

## Expected internal path of the addon folder inside the ZIP
const ADDON_ZIP_PREFIX := "addons/GDQuest_GDScript_formatter/"

const HTTP_TIMEOUT_SEC := 60.0

# ---------------------------------------------------------------------------
# State tracking for async operations
# ---------------------------------------------------------------------------
enum AsyncOp {
	NONE,
	FETCH_RELEASE_INFO_ADDON,
	DOWNLOAD_ADDON_ZIP,
	FETCH_RELEASE_INFO_BINARY,
	DOWNLOAD_BINARY_ZIP,
}

var _async_state: Dictionary = {}  # key → { op, client_id, command_id, http, http_callback, timer, ... }

# ---------------------------------------------------------------------------
# Platform helpers
# ---------------------------------------------------------------------------
func _platform_info() -> Dictionary:
	var os_name := OS.get_name().to_lower()
	var proc_name := OS.get_processor_name().to_lower()
	var arch := "x86_64"
	if proc_name.contains("aarch64") or proc_name.contains("arm64"):
		arch = "aarch64"

	var os := ""
	var bin_name := "gdscript-formatter"
	if os_name.contains("windows"):
		os = "windows"
		bin_name = "gdscript-formatter.exe"
	elif os_name.contains("linux"):
		os = "linux"
	elif os_name.contains("macos") or os_name.contains("osx"):
		os = "macos"
	else:
		os = os_name

	return { "os": os, "arch": arch, "binary_name": bin_name }


func _cache_dir() -> String:
	return EditorInterface.get_editor_paths().get_cache_dir().path_join("gdquest")


func _binary_path() -> String:
	return _cache_dir().path_join(_platform_info()["binary_name"])


# ---------------------------------------------------------------------------
# Command dispatch
# ---------------------------------------------------------------------------
func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"check_formatter":
			_check_formatter(client_id, params, command_id)
			return true
		"install_formatter_addon":
			_install_formatter_addon(client_id, params, command_id)
			return true
		"install_formatter_binary":
			_install_formatter_binary(client_id, params, command_id)
			return true
		"format_gdscript":
			_format_gdscript(client_id, params, command_id)
			return true
	return false


# ---------------------------------------------------------------------------
# Tool: check_formatter
# ---------------------------------------------------------------------------
func _check_formatter(client_id: int, params: Dictionary, command_id: String) -> void:
	var addon := FileAccess.file_exists(GDQ_PLUGIN_CFG)
	var binary := FileAccess.file_exists(_binary_path())
	var status := ""
	if addon and binary:
		status = "Formatter addon and binary are both installed and ready to use."
	elif addon:
		status = "Formatter addon is installed, but the binary has not been downloaded yet. Use install_formatter_binary."
	elif binary:
		status = "Formatter binary is installed, but the addon is not in this project. Use install_formatter_addon."
	else:
		status = "Neither the formatter addon nor binary are installed. Use install_formatter_addon to get started."

	_send_success(client_id, {
		"addon_installed": addon,
		"binary_installed": binary,
		"binary_path": _binary_path(),
		"cache_directory": _cache_dir(),
		"addon_path": GDQ_ADDON_PATH,
		"status": status,
	}, command_id)


# ---------------------------------------------------------------------------
# Install helpers (shared between addon and binary)
# ---------------------------------------------------------------------------

## Start the common flow: fetch latest release JSON → route via op to handler.
func _start_install(client_id: int, command_id: String, op: AsyncOp, key_suffix: String) -> void:
	var http := HTTPRequest.new()
	http.name = "FormatterHTTP_%s" % key_suffix
	add_child(http)
	var callback := _on_release_info_received.bind(http)
	http.request_completed.connect(callback)

	var key := "%s_%d" % [key_suffix, client_id]
	_async_state[key] = {
		"op": op,
		"client_id": client_id,
		"command_id": command_id,
		"http": http,
		"http_callback": callback,
		"timer": _start_timeout(key, HTTP_TIMEOUT_SEC),
	}

	http.request(URL_GITHUB_API_LATEST_RELEASE)


func _swap_callback(http: HTTPRequest, state: Dictionary, new_handler: Callable) -> void:
	var old_cb: Callable = state.get("http_callback")
	if old_cb.is_valid() and http.is_connected(&"request_completed", old_cb):
		http.request_completed.disconnect(old_cb)
	var new_cb := new_handler.bind(http)
	http.request_completed.connect(new_cb)
	state["http_callback"] = new_cb


func _find_key_by_http(http: HTTPRequest) -> String:
	for k in _async_state:
		if _async_state[k].get("http") == http:
			return k
	return ""


func _start_timeout(key: String, sec: float) -> Timer:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = sec
	t.timeout.connect(_on_async_timeout.bind(key))
	add_child(t)
	t.start()
	return t


func _on_async_timeout(key: String) -> void:
	if not _async_state.has(key):
		return
	var state: Dictionary = _async_state[key]
	var client_id: int = state.get("client_id", 0)
	var command_id: String = state.get("command_id", "")
	_cleanup_async(key)
	_send_error(client_id, "Operation timed out", command_id)


func _reset_timeout(key: String, sec: float) -> void:
	if not _async_state.has(key):
		return
	var state: Dictionary = _async_state[key]
	var timer: Timer = state.get("timer")
	if timer and is_instance_valid(timer):
		timer.stop()
		remove_child(timer)
		timer.queue_free()
	state["timer"] = _start_timeout(key, sec)


func _cleanup_async(key: String) -> void:
	if not _async_state.has(key):
		return
	var state: Dictionary = _async_state[key]
	var http: HTTPRequest = state.get("http")
	if http and is_instance_valid(http):
		var cb: Callable = state.get("http_callback", Callable())
		if cb.is_valid() and http.is_connected(&"request_completed", cb):
			http.request_completed.disconnect(cb)
		remove_child(http)
		http.queue_free()
	var timer: Timer = state.get("timer")
	if timer and is_instance_valid(timer):
		timer.stop()
		remove_child(timer)
		timer.queue_free()
	_async_state.erase(key)


# ---------------------------------------------------------------------------
# Shared: release info response router
# ---------------------------------------------------------------------------
func _on_release_info_received(http_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	var key := _find_key_by_http(http)
	if key.is_empty():
		return

	var state: Dictionary = _async_state[key]
	var client_id: int = state["client_id"]
	var command_id: String = state["command_id"]

	if response_code != 200:
		_cleanup_async(key)
		return _send_error(client_id, "Failed to fetch release info (HTTP %d)" % response_code, command_id)

	var json := JSON.parse_string(body.get_string_from_utf8())
	if not json or not json.has("assets"):
		_cleanup_async(key)
		return _send_error(client_id, "Failed to parse GitHub release JSON", command_id)

	match state.get("op"):
		AsyncOp.FETCH_RELEASE_INFO_ADDON:
			_on_addon_release_found(json, state, http)
		AsyncOp.FETCH_RELEASE_INFO_BINARY:
			_on_binary_release_found(json, state, http)
		_:
			_cleanup_async(key)
			_send_error(client_id, "Unexpected async operation state", command_id)


# ---------------------------------------------------------------------------
# Tool: install_formatter_addon
# ---------------------------------------------------------------------------
func _install_formatter_addon(client_id: int, params: Dictionary, command_id: String) -> void:
	if FileAccess.file_exists(GDQ_PLUGIN_CFG):
		_send_success(client_id, {
			"status": "already_installed",
			"path": GDQ_ADDON_PATH,
			"message": "GDQuest GDScript Formatter addon is already installed.",
		}, command_id)
		return

	_start_install(client_id, command_id, AsyncOp.FETCH_RELEASE_INFO_ADDON, "addon")


func _on_addon_release_found(json: Dictionary, state: Dictionary, http: HTTPRequest) -> void:
	var assets: Array = json.get("assets", [])
	var tag: String = json.get("tag_name", "latest")

	var download_url := ""
	for asset in assets:
		if asset.get("name", "") == ADDON_ZIP_ASSET_NAME:
			download_url = asset.get("browser_download_url", "")
			break

	if download_url.is_empty():
		_cleanup_async(_find_key_by_http(http))
		return _send_error(state["client_id"],
			"No '%s' asset found in release %s" % [ADDON_ZIP_ASSET_NAME, tag],
			state["command_id"])

	# Reset timeout for the download phase (API call already completed)
	_reset_timeout(_find_key_by_http(http), HTTP_TIMEOUT_SEC)

	state["tag"] = tag
	state["op"] = AsyncOp.DOWNLOAD_ADDON_ZIP
	_swap_callback(http, state, _on_addon_zip_downloaded)
	http.request(download_url)


func _on_addon_zip_downloaded(http_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	var key := _find_key_by_http(http)
	if key.is_empty():
		return
	var state: Dictionary = _async_state[key]
	var client_id: int = state["client_id"]
	var command_id: String = state["command_id"]
	var tag: String = state.get("tag", "")

	if response_code != 200 or body.is_empty():
		_cleanup_async(key)
		return _send_error(client_id, "Failed to download addon ZIP (HTTP %d)" % response_code, command_id)

	# Write temp ZIP and extract
	var tmp_zip := OS.get_temp_dir().path_join("gdscript_fmt_addon_%d.zip" % Time.get_ticks_msec())
	var zf := FileAccess.open(tmp_zip, FileAccess.WRITE)
	if not zf:
		_cleanup_async(key)
		return _send_error(client_id, "Failed to create temp file", command_id)
	zf.store_buffer(body)
	zf.close()

	var reader := ZIPReader.new()
	var open_err := reader.open(tmp_zip)
	if open_err != OK:
		DirAccess.remove_absolute(tmp_zip)
		_cleanup_async(key)
		return _send_error(client_id, "Failed to open addon ZIP (error: %d)" % open_err, command_id)

	# Extract files from the ZIP — they live under addons/GDQuest_GDScript_formatter/
	var extracted: Array[String] = []
	for fpath in reader.get_files():
		if fpath.ends_with("/"):
			continue
		var rel_path := fpath
		if fpath.begins_with(ADDON_ZIP_PREFIX):
			rel_path = fpath.substr(ADDON_ZIP_PREFIX.length())
		var dest_path := GDQ_ADDON_PATH.path_join(rel_path)
		var dest_dir := dest_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dest_dir):
			DirAccess.make_dir_recursive_absolute(dest_dir)
		var df := FileAccess.open(dest_path, FileAccess.WRITE)
		if df:
			df.store_buffer(reader.read_file(fpath))
			df.close()
			extracted.append(rel_path)
	reader.close()
	DirAccess.remove_absolute(tmp_zip)

	_cleanup_async(key)

	if extracted.is_empty():
		return _send_error(client_id, "Addon ZIP was empty — no files extracted", command_id)

	EditorInterface.get_resource_filesystem().scan()

	_send_success(client_id, {
		"status": "installed",
		"tag": tag,
		"path": GDQ_ADDON_PATH,
		"files": extracted,
		"message": "Addon v%s installed. Enable it in Project → Project Settings → Plugins, then run install_formatter_binary." % [tag],
	}, command_id)


# ---------------------------------------------------------------------------
# Tool: install_formatter_binary
# ---------------------------------------------------------------------------
func _install_formatter_binary(client_id: int, params: Dictionary, command_id: String) -> void:
	_start_install(client_id, command_id, AsyncOp.FETCH_RELEASE_INFO_BINARY, "binary")


func _on_binary_release_found(json: Dictionary, state: Dictionary, http: HTTPRequest) -> void:
	var assets: Array = json.get("assets", [])
	var tag: String = json.get("tag_name", "latest")
	var platform := _platform_info()

	var expected := "gdscript-formatter-%s-%s-%s" % [tag, platform["os"], platform["arch"]]
	if platform["os"] == "windows":
		expected += ".exe"
	expected += ".zip"

	var download_url := ""
	for asset in assets:
		if asset.get("name", "") == expected:
			download_url = asset.get("browser_download_url", "")
			break

	if download_url.is_empty():
		_cleanup_async(_find_key_by_http(http))
		return _send_error(state["client_id"],
			"No binary for %s-%s (expected: %s)" % [platform["os"], platform["arch"], expected],
			state["command_id"])

	# Reset timeout for the download phase (API call already completed)
	_reset_timeout(_find_key_by_http(http), HTTP_TIMEOUT_SEC)

	state["tag"] = tag
	state["op"] = AsyncOp.DOWNLOAD_BINARY_ZIP
	_swap_callback(http, state, _on_binary_zip_downloaded)
	http.request(download_url)


func _on_binary_zip_downloaded(http_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	var key := _find_key_by_http(http)
	if key.is_empty():
		return

	var state: Dictionary = _async_state[key]
	var client_id: int = state["client_id"]
	var command_id: String = state["command_id"]
	var tag: String = state.get("tag", "")

	if response_code != 200 or body.is_empty():
		_cleanup_async(key)
		return _send_error(client_id, "Failed to download binary ZIP (HTTP %d, size %d)" % [response_code, body.size()], command_id)

	# Write temp ZIP, extract, install
	var cache_dir := _cache_dir()
	if not DirAccess.dir_exists_absolute(cache_dir):
		var dir_err := DirAccess.make_dir_recursive_absolute(cache_dir)
		if dir_err != OK:
			_cleanup_async(key)
			return _send_error(client_id, "Failed to create cache dir: %s" % cache_dir, command_id)

	var temp_zip := cache_dir.path_join("temp_formatter_archive.zip")
	var zf := FileAccess.open(temp_zip, FileAccess.WRITE)
	if not zf:
		_cleanup_async(key)
		return _send_error(client_id, "Failed to create temp archive", command_id)
	zf.store_buffer(body)
	zf.close()

	var reader := ZIPReader.new()
	var open_err := reader.open(temp_zip)
	if open_err != OK:
		DirAccess.remove_absolute(temp_zip)
		_cleanup_async(key)
		return _send_error(client_id, "Failed to open ZIP (error: %d)" % open_err, command_id)

	var binary_data: PackedByteArray
	var found := false
	for fpath in reader.get_files():
		if not fpath.ends_with("/"):
			binary_data = reader.read_file(fpath)
			found = true
			break
	reader.close()
	DirAccess.remove_absolute(temp_zip)

	if not found or binary_data.is_empty():
		_cleanup_async(key)
		return _send_error(client_id, "No binary found in ZIP archive", command_id)

	var bin_path := _binary_path()
	var bf := FileAccess.open(bin_path, FileAccess.WRITE)
	if not bf:
		_cleanup_async(key)
		return _send_error(client_id, "Failed to write binary: %s" % bin_path, command_id)
	bf.store_buffer(binary_data)
	bf.close()

	var platform := _platform_info()
	if platform["os"] != "windows":
		OS.execute("chmod", ["+x", bin_path])

	_cleanup_async(key)

	_send_success(client_id, {
		"status": "installed",
		"binary_path": bin_path,
		"tag": tag,
		"platform": { "os": platform["os"], "arch": platform["arch"] },
		"message": "GDScript Formatter v%s installed at: %s" % [tag, bin_path],
	}, command_id)


# ---------------------------------------------------------------------------
# Tool: format_gdscript — synchronous, uses OS.execute
# ---------------------------------------------------------------------------
func _format_gdscript(client_id: int, params: Dictionary, command_id: String) -> void:
	var script_path: String = params.get("script_path", "")
	var use_spaces: bool = params.get("use_spaces", false)
	var indent_size: int = params.get("indent_size", 4)
	var reorder_code: bool = params.get("reorder_code", false)
	var safe_mode: bool = params.get("safe_mode", true)
	var write_back: bool = params.get("write_back", true)

	if script_path.is_empty():
		return _send_error(client_id, "Required: script_path", command_id)

	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	if not FileAccess.file_exists(script_path):
		return _send_error(client_id, "File not found: %s" % script_path, command_id)

	if not script_path.ends_with(".gd"):
		return _send_error(client_id, "Not a .gd file: %s" % script_path, command_id)

	# Resolve binary — check cache first, then PATH
	var binary := _binary_path()
	if not FileAccess.file_exists(binary):
		var test_out: Array = []
		if OS.execute("gdscript-formatter", ["--version"], test_out) != OK:
			return _send_error(client_id,
				"No binary at %s and 'gdscript-formatter' not on PATH. Use install_formatter_binary first." % binary,
				command_id)
		binary = "gdscript-formatter"

	# Read source
	var src_path := ProjectSettings.globalize_path(script_path)
	var src_file := FileAccess.open(src_path, FileAccess.READ)
	if not src_file:
		return _send_error(client_id, "Cannot read: %s" % script_path, command_id)
	var source_content := src_file.get_as_text()
	src_file.close()

	# Temp copy (avoids UTF-8 encoding issues and "file changed" popups)
	var tmp_path := OS.get_temp_dir().path_join("gdscript_fmt_%d.gd" % Time.get_ticks_msec())
	var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not tmp:
		return _send_error(client_id, "Cannot create temp file", command_id)
	tmp.store_string(source_content)
	tmp.close()

	# Build arguments
	var args := PackedStringArray()
	if use_spaces:
		args.push_back("--use-spaces")
		args.push_back("--indent-size=%d" % indent_size)
	if reorder_code:
		args.push_back("--reorder-code")
	if safe_mode:
		args.push_back("--safe")
	args.push_back(tmp_path)

	# Execute formatter
	var cmd_out: Array = []
	var exit_code := OS.execute(binary, args, cmd_out)

	# Read result
	var result_file := FileAccess.open(tmp_path, FileAccess.READ)
	var formatted := ""
	if result_file:
		formatted = result_file.get_as_text()
		result_file.close()

	# Clean temp
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)

	if exit_code != OK:
		var detail: String = cmd_out[0].strip_edges() if cmd_out.size() > 0 else "no output"
		return _send_error(client_id,
			"Formatter exited with code %d: %s" % [exit_code, detail],
			command_id)

	# Write back or return formatted text
	if write_back and not source_content.is_empty():
		var out := FileAccess.open(script_path, FileAccess.WRITE)
		if not out:
			return _send_error(client_id, "Cannot write back to %s" % script_path, command_id)
		out.store_string(formatted)
		out.close()

		var plugin = Engine.get_meta("GodotMCPPlugin", null)
		if plugin:
			plugin.get_editor_interface().get_resource_filesystem().scan()

	_send_success(client_id, {
		"script_path": script_path,
		"formatted": formatted if not write_back else "",
		"write_back": write_back,
		"changed": source_content != formatted,
		"message": "Script formatted." if write_back else "Formatting complete (dry run).",
	}, command_id)
