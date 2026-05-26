@tool
## MCP commands for managing the GDQuest GDScript Formatter addon and binary.
##
## Provides tools to:
##   - check_formatter            — Check if the formatter addon/binary is installed
##   - install_formatter_addon    — Download the addon (godot-addon.zip) from GitHub releases
##   - install_formatter_binary   — Download the platform binary from GitHub releases
##   - format_gdscript          - Format .gd files — supports * and **/*.gd globs
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

var _async_state: Dictionary = { }
# key → { op, client_id, command_id, http, http_callback, timer, ... }


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
func process_command(cid: int, command_type: String, params: Dictionary, cmdid: String) -> bool:
	var client_id := cid
	var command_id := cmdid
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
		"format_all_gdscript":
			_format_all_gdscript(client_id, params, command_id)
			return true
		"lint_gdscript":
			_lint_gdscript(client_id, params, command_id)
			return true
	return false


# ---------------------------------------------------------------------------
# Tool: check_formatter
# ---------------------------------------------------------------------------
func _check_formatter(client_id: int, _params: Dictionary, command_id: String) -> void:
	var addon := FileAccess.file_exists(GDQ_PLUGIN_CFG)
	var binary := FileAccess.file_exists(_binary_path())
	var status := ""
	if addon and binary:
		status = "Formatter addon and binary are both installed and ready to use."
	elif addon:
		status = "Addon installed but binary missing. Use install_formatter_binary."
	elif binary:
		status = "Binary installed but addon missing. Use install_formatter_addon."
	else:
		status = "Neither addon nor binary installed. Use install_formatter_addon first."

	_send_success(
		client_id,
		{
			"addon_installed": addon,
			"binary_installed": binary,
			"binary_path": _binary_path(),
			"cache_directory": _cache_dir(),
			"addon_path": GDQ_ADDON_PATH,
			"status": status,
		},
		command_id,
	)

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
func _on_release_info_received(
		_http_result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray,
		http: HTTPRequest,
) -> void:
	var key := _find_key_by_http(http)
	if key.is_empty():
		return

	var state: Dictionary = _async_state[key]
	var client_id: int = state["client_id"]
	var command_id: String = state["command_id"]

	if response_code != 200:
		_cleanup_async(key)
		var msg := "Failed to fetch release info (HTTP %d)" % response_code
		return _send_error(client_id, msg, command_id)

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
func _install_formatter_addon(client_id: int, _params: Dictionary, command_id: String) -> void:
	if FileAccess.file_exists(GDQ_PLUGIN_CFG):
		_send_success(
			client_id,
			{
				"status": "already_installed",
				"path": GDQ_ADDON_PATH,
				"message": "GDQuest GDScript Formatter addon is already installed.",
			},
			command_id,
		)
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
		return _send_error(
			state["client_id"],
			"No '%s' asset found in release %s" % [ADDON_ZIP_ASSET_NAME, tag],
			state["command_id"],
		)

	# Reset timeout for the download phase (API call already completed)
	_reset_timeout(_find_key_by_http(http), HTTP_TIMEOUT_SEC)

	state["tag"] = tag
	state["op"] = AsyncOp.DOWNLOAD_ADDON_ZIP
	_swap_callback(http, state, _on_addon_zip_downloaded)
	http.request(download_url)


func _on_addon_zip_downloaded(
		_http_result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray,
		http: HTTPRequest,
) -> void:
	var key := _find_key_by_http(http)
	if key.is_empty():
		return
	var state: Dictionary = _async_state[key]
	var client_id: int = state["client_id"]
	var command_id: String = state["command_id"]
	var tag: String = state.get("tag", "")

	if response_code != 200 or body.is_empty():
		_cleanup_async(key)
		var dl_msg := "Failed to download addon ZIP (HTTP %d)" % response_code
		return _send_error(client_id, dl_msg, command_id)

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

	_send_success(
		client_id,
		{
			"status": "installed",
			"tag": tag,
			"path": GDQ_ADDON_PATH,
			"files": extracted,
			"message": "Addon v%s installed. Enable in Project Settings → Plugins." % [tag],
		},
		command_id,
	)


# ---------------------------------------------------------------------------
# Tool: install_formatter_binary
# ---------------------------------------------------------------------------
func _install_formatter_binary(client_id: int, _params: Dictionary, command_id: String) -> void:
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
		return _send_error(
			state["client_id"],
			"No binary for %s-%s (expected: %s)" % [platform["os"], platform["arch"], expected],
			state["command_id"],
		)

	# Reset timeout for the download phase (API call already completed)
	_reset_timeout(_find_key_by_http(http), HTTP_TIMEOUT_SEC)

	state["tag"] = tag
	state["op"] = AsyncOp.DOWNLOAD_BINARY_ZIP
	_swap_callback(http, state, _on_binary_zip_downloaded)
	http.request(download_url)


func _on_binary_zip_downloaded(
		_http_result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray,
		http: HTTPRequest,
) -> void:
	var key := _find_key_by_http(http)
	if key.is_empty():
		return

	var state: Dictionary = _async_state[key]
	var client_id: int = state["client_id"]
	var command_id: String = state["command_id"]
	var tag: String = state.get("tag", "")

	if response_code != 200 or body.is_empty():
		_cleanup_async(key)
		var dl_msg := "Failed download binary ZIP (HTTP %d, size %d)" % [response_code, body.size()]
		return _send_error(client_id, dl_msg, command_id)

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

	_send_success(
		client_id,
		{
			"status": "installed",
			"binary_path": bin_path,
			"tag": tag,
			"platform": { "os": platform["os"], "arch": platform["arch"] },
			"message": "GDScript Formatter v%s installed at: %s" % [tag, bin_path],
		},
		command_id,
	)


# ---------------------------------------------------------------------------
# Tool: format_gdscript — supports glob patterns (e.g. *, **/*.gd)
# ---------------------------------------------------------------------------
func _format_gdscript(client_id: int, params: Dictionary, command_id: String) -> void:
	var script_path: String = params.get("script_path", "")

	if script_path.is_empty():
		return _send_error(client_id, "Required: script_path", command_id)

	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	# Detect glob patterns
	if script_path.contains("*"):
		var matches := _resolve_glob(script_path)
		if matches.is_empty():
			var nf_msg := "No .gd files matched pattern: %s" % script_path
			return _send_error(client_id, nf_msg, command_id)

		var results: Array[Dictionary] = []
		var formatted_count := 0
		var unchanged_count := 0
		var error_count := 0

		for path in matches:
			var result := _format_single(path, params)
			if result.has("error"):
				error_count += 1
			elif result.get("changed", false):
				formatted_count += 1
			else:
				unchanged_count += 1
			results.append(result)

		return _send_success(
			client_id,
			{
				"pattern": script_path,
				"total": matches.size(),
				"formatted": formatted_count,
				"unchanged": unchanged_count,
				"errors": error_count,
				"files": results,
				"message": "%d formatted, %d unchanged, %d errors of %d files"
				% [formatted_count, unchanged_count, error_count, matches.size()],
			},
			command_id,
		)

	# Single file path
	if not FileAccess.file_exists(script_path):
		return _send_error(client_id, "File not found: %s" % script_path, command_id)

	if not script_path.ends_with(".gd"):
		return _send_error(client_id, "Not a .gd file: %s" % script_path, command_id)

	var result := _format_single(script_path, params)
	if result.has("error"):
		return _send_error(client_id, result["error"], command_id)

	_send_success(
		client_id,
		{
			"script_path": script_path,
			"formatted": result.get("formatted", ""),
			"write_back": result.get("write_back", true),
			"changed": result.get("changed", false),
			"message": "Script formatted." if result.get("write_back", true) else "Formatting done (dry).",
		},
		command_id,
	)


# ---------------------------------------------------------------------------
# Tool: format_all_gdscript — convenience wrapper, formats every .gd file
# ---------------------------------------------------------------------------
func _format_all_gdscript(client_id: int, params: Dictionary, command_id: String) -> void:
	# Delegate to format_gdscript with wildcard, merge extra params
	var merged := params.duplicate()
	merged["script_path"] = "*"
	_format_gdscript(client_id, merged, command_id)


# ---------------------------------------------------------------------------
# Tool: lint_gdscript — lint .gd files using the formatter's built-in linter
# ---------------------------------------------------------------------------
func _lint_gdscript(client_id: int, params: Dictionary, command_id: String) -> void:
	var script_path: String = params.get("script_path", "")

	if script_path.is_empty():
		return _send_error(client_id, "Required: script_path", command_id)

	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	# Detect glob patterns
	if script_path.contains("*"):
		var matches := _resolve_glob(script_path)
		if matches.is_empty():
			return _send_error(client_id, "No .gd files matched pattern: %s" % script_path, command_id)

		var results: Array[Dictionary] = []
		var total_issues := 0
		var files_with_issues := 0

		for path in matches:
			var result := _lint_single(path, params)
			if result.has("error"):
				result["script_path"] = path
				results.append(result)
			else:
				var issue_count := (result.get("issues", []) as Array).size()
				total_issues += issue_count
				if issue_count > 0:
					files_with_issues += 1
				results.append(result)

		return _send_success(
			client_id,
			{
				"pattern": script_path,
				"total_files": matches.size(),
				"files_with_issues": files_with_issues,
				"total_issues": total_issues,
				"files": results,
				"message": "%d issues across %d/%d files" % [total_issues, files_with_issues, matches.size()],
			},
			command_id,
		)

	# Single file path
	if not FileAccess.file_exists(script_path):
		return _send_error(client_id, "File not found: %s" % script_path, command_id)

	if not script_path.ends_with(".gd"):
		return _send_error(client_id, "Not a .gd file: %s" % script_path, command_id)

	var result := _lint_single(script_path, params)
	if result.has("error"):
		return _send_error(client_id, result["error"], command_id)

	var issues: Array = result.get("issues", [])
	_send_success(
		client_id,
		{
			"script_path": script_path,
			"issue_count": issues.size(),
			"issues": issues,
			"message": "Lint complete: %d issue(s) found" % issues.size(),
		},
		command_id,
	)


# ---------------------------------------------------------------------------
# Core: lint a single .gd file, returns {issues, script_path} or {error}
# ---------------------------------------------------------------------------
func _lint_single(script_path: String, params: Dictionary) -> Dictionary:
	var disabled_rules: String = params.get("disabled_rules", "")
	var max_line_length: int = params.get("max_line_length", 0)
	var pretty: bool = params.get("pretty", false)

	# Resolve binary
	var binary := _binary_path()
	if not FileAccess.file_exists(binary):
		var test_out: Array = []
		if OS.execute("gdscript-formatter", ["--version"], test_out) != OK:
			return { "error": "No binary at %s; 'gdscript-formatter' not on PATH." % binary, "script_path": script_path }
		binary = "gdscript-formatter"

	var src_path := ProjectSettings.globalize_path(script_path)

	# Build arguments: gdscript-formatter lint [opts] path
	var args := PackedStringArray()
	args.push_back("lint")

	if not disabled_rules.is_empty():
		args.push_back("--disable")
		args.push_back(disabled_rules)

	if max_line_length > 0:
		args.push_back("--max-line-length")
		args.push_back(str(max_line_length))

	if pretty:
		args.push_back("--pretty")

	args.push_back(src_path)

	# Execute linter
	var cmd_out: Array = []
	var exit_code := OS.execute(binary, args, cmd_out)

	# Parse output lines into structured issues
	var issues: Array[Dictionary] = []
	var raw_output := ""
	if cmd_out.size() > 0:
		raw_output = str(cmd_out[0] if cmd_out[0] is String else "\n".join(cmd_out))

	if not raw_output.is_empty():
		for line in raw_output.split("\n", false):
			var trimmed := line.strip_edges()
			if trimmed.is_empty():
				continue
			var issue := _parse_lint_line(trimmed)
			if not issue.is_empty():
				issues.append(issue)

	if exit_code != OK and issues.is_empty():
		return { "error": "Linter exited with code %d: %s" % [exit_code, raw_output.strip_edges()], "script_path": script_path }

	return {
		"script_path": script_path,
		"issues": issues,
		"issue_count": issues.size(),
		"exit_code": exit_code,
	}


## Parse a lint output line in format: filepath:line:rule:severity: description
func _parse_lint_line(line: String) -> Dictionary:
	# Expected format: filepath:line:rule:severity: description
	# Example: res://scripts/player.gd:10:function-name:warning: Function name should be snake_case
	var colon_idx := line.find(":")
	if colon_idx == -1:
		return { }

	var file_part := line.substr(0, colon_idx)
	var rest := line.substr(colon_idx + 1)

	# Parse line number
	var line_colon := rest.find(":")
	if line_colon == -1:
		return { }
	var line_str := rest.substr(0, line_colon)
	var line_num := -1
	if line_str.is_valid_int():
		line_num = int(line_str)
	rest = rest.substr(line_colon + 1)

	# Parse rule name
	var rule_colon := rest.find(":")
	if rule_colon == -1:
		return { }
	var rule := rest.substr(0, rule_colon)
	rest = rest.substr(rule_colon + 1)

	# Parse severity
	var severity_colon := rest.find(":")
	var severity := ""
	var description := ""
	if severity_colon != -1:
		severity = rest.substr(0, severity_colon)
		description = rest.substr(severity_colon + 1).strip_edges()
	else:
		severity = rest.strip_edges()

	return {
		"file": file_part,
		"line": line_num,
		"rule": rule,
		"severity": severity,
		"description": description,
	}


# ---------------------------------------------------------------------------
# Core: format a single .gd file, returns {changed, formatted, write_back} or {error}
# ---------------------------------------------------------------------------
func _format_single(script_path: String, params: Dictionary) -> Dictionary:
	var use_spaces: bool = params.get("use_spaces", false)
	var indent_size: int = params.get("indent_size", 4)
	var reorder_code: bool = params.get("reorder_code", false)
	var safe_mode: bool = params.get("safe_mode", true)
	var write_back: bool = params.get("write_back", true)

	# Resolve binary — check cache first, then PATH
	var binary := _binary_path()
	if not FileAccess.file_exists(binary):
		var test_out: Array = []
		if OS.execute("gdscript-formatter", ["--version"], test_out) != OK:
			var msg := "No binary at %s; 'gdscript-formatter' not on PATH." % binary
			return { "error": msg, "script_path": script_path }
		binary = "gdscript-formatter"

	# Read source
	var src_path := ProjectSettings.globalize_path(script_path)
	var src_file := FileAccess.open(src_path, FileAccess.READ)
	if not src_file:
		return { "error": "Cannot read: %s" % script_path, "script_path": script_path }
	var source_content := src_file.get_as_text()
	src_file.close()

	# Temp copy (avoids UTF-8 encoding issues and "file changed" popups)
	var tmp_path := OS.get_temp_dir().path_join("gdscript_fmt_%d.gd" % Time.get_ticks_msec())
	var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not tmp:
		return { "error": "Cannot create temp file", "script_path": script_path }
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
		var detail: String
		if cmd_out.size() > 0:
			detail = cmd_out[0].strip_edges()
		else:
			detail = "no output"
		var err_msg := "formatter exit %d: %s" % [exit_code, detail]
		return { "error": err_msg, "script_path": script_path }

	var changed := source_content != formatted

	# Write back
	if write_back and changed:
		var out := FileAccess.open(script_path, FileAccess.WRITE)
		if not out:
			return { "error": "Cannot write back to %s" % script_path, "script_path": script_path }
		out.store_string(formatted)
		out.close()

	return {
		"script_path": script_path,
		"formatted": formatted if not write_back else "",
		"write_back": write_back,
		"changed": changed,
	}


# ---------------------------------------------------------------------------
# Glob resolution: expand a 'res://' wildcard pattern to matching .gd paths
# Supports * (any chars except /) and ** (any chars including /)
# ---------------------------------------------------------------------------
func _resolve_glob(pattern: String) -> Array[String]:
	var results: Array[String] = []

	# Extract directory prefix and file pattern
	var pattern_stripped := pattern.trim_prefix("res://")

	# Determine the base directory and the pattern parts
	var parts := pattern_stripped.split("/")
	var base_parts: Array[String] = []
	var pattern_parts: Array[String] = []
	var in_pattern := false

	for part in parts:
		if part.contains("*"):
			in_pattern = true
		if not in_pattern:
			base_parts.append(part)
		else:
			pattern_parts.append(part)

	var base_dir := "res://" + "/".join(base_parts) if base_parts.size() > 0 else "res://"
	if not base_dir.ends_with("/"):
		base_dir += "/"

	# If no pattern parts, treat as "find all .gd recursively"
	if pattern_parts.is_empty():
		pattern_parts = ["**/*.gd"]

	# Walk the filesystem
	_walk_and_match(base_dir, "res://", pattern_parts, results)

	return results


func _walk_and_match(
		current_dir: String,
		_res_prefix: String,
		pattern_parts: Array[String],
		results: Array[String],
) -> void:
	var abs_dir := ProjectSettings.globalize_path(current_dir)
	var dir := DirAccess.open(abs_dir)
	if not dir:
		return

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname == "." or fname == "..":
			fname = dir.get_next()
			continue

		var is_dir := dir.current_is_dir()
		var rel_path := current_dir + fname

		if is_dir:
			# Skip hidden dirs and known noise
			if fname.begins_with("."):
				fname = dir.get_next()
				continue
			# Always recurse — the glob matching happens at the file level
			_walk_and_match(rel_path + "/", _res_prefix, pattern_parts, results)
		else:
			if not fname.ends_with(".gd"):
				fname = dir.get_next()
				continue
			if _path_matches_glob(rel_path, pattern_parts):
				results.append(rel_path)

		fname = dir.get_next()

	dir.list_dir_end()


func _path_matches_glob(path: String, pattern_parts: Array[String]) -> bool:
	var path_parts := path.trim_prefix("res://").split("/")

	# Match from the end backwards (right-to-left)
	var pi := pattern_parts.size() - 1
	var pp := path_parts.size() - 1

	while pi >= 0 and pp >= 0:
		var pat := pattern_parts[pi]

		if pat == "**":
			# ** matches any number of path segments (including zero)
			if pi == 0:
				return true
			# Try matching the remaining pattern against every possible prefix
			var rest_patterns: Array[String] = []
			for k in range(pi - 1, -1, -1):
				rest_patterns.push_front(pattern_parts[k])
			for j in range(pp, -1, -1):
				if _part_matches(path_parts[j], pattern_parts[pi - 1]):
					# Check if rest matches
					var all_match := true
					var rpi := pi - 2
					var rpp := j - 1
					while rpi >= 0 and rpp >= 0:
						if pattern_parts[rpi] == "**":
							# Nested ** — just match everything remaining
							return true
						if not _part_matches(path_parts[rpp], pattern_parts[rpi]):
							all_match = false
							break
						rpi -= 1
						rpp -= 1
					if all_match and rpi < 0:
						return true
				# If no match found for pi-1, ** consumed everything before it
			pp -= 1
			continue

		if not _part_matches(path_parts[pp], pat):
			return false

		pi -= 1
		pp -= 1

	return pi < 0 and pp < 0


func _part_matches(name: String, pattern: String) -> bool:
	if pattern == "*":
		return true
	if pattern == "*.gd":
		return name.ends_with(".gd")
	# Simple glob: * matches any sequence within a single part
	var pi := 0
	var ni := 0
	var star_idx := -1
	var match_idx := 0

	while ni < name.length():
		if pi < pattern.length() and (pattern[pi] == name[ni] or pattern[pi] == "?"):
			pi += 1
			ni += 1
		elif pi < pattern.length() and pattern[pi] == "*":
			star_idx = pi
			match_idx = ni
			pi += 1
		elif star_idx != -1:
			pi = star_idx + 1
			match_idx += 1
			ni = match_idx
		else:
			return false

	while pi < pattern.length() and pattern[pi] == "*":
		pi += 1

	return pi == pattern.length()
