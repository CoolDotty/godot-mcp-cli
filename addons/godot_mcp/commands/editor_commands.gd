@tool
class_name MCPEditorCommands
extends MCPBaseCommandProcessor

func process_command(
		client_id: int,
		command_type: String,
		params: Dictionary,
		command_id: String,
) -> bool:
	match command_type:
		"get_editor_state":
			_get_editor_state(client_id, params, command_id)
			return true
		"get_selected_node":
			_get_selected_node(client_id, params, command_id)
			return true
		"create_resource":
			_create_resource(client_id, params, command_id)
			return true
		"reload_project":
			_reload_project(client_id, params, command_id)
			return true
		"reload_scene":
			_reload_scene(client_id, params, command_id)
			return true
		"get_node_warnings":
			_get_node_warnings(client_id, params, command_id)
			return true
		"rescan_filesystem":
			_rescan_filesystem(client_id, params, command_id)
			return true
	return false # Command not handled


func _get_editor_state(client_id: int, _params: Dictionary, command_id: String) -> void:
	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)

	var editor_interface = plugin.get_editor_interface()

	var state = {
		"current_scene": "",
		"current_script": "",
		"selected_nodes": [],
		"is_playing": editor_interface.is_playing_scene(),
	}

	# Get current scene
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if edited_scene_root:
		state["current_scene"] = edited_scene_root.scene_file_path

	# Get current script if any is being edited
	var script_editor = editor_interface.get_script_editor()
	var current_script = script_editor.get_current_script()
	if current_script:
		state["current_script"] = current_script.resource_path

	# Get selected nodes
	var selection = editor_interface.get_selection()
	var selected_nodes = selection.get_selected_nodes()

	for node in selected_nodes:
		state["selected_nodes"].append(
			{
				"name": node.name,
				"path": str(node.get_path()),
			},
		)

	_send_success(client_id, state, command_id)


func _get_selected_node(client_id: int, _params: Dictionary, command_id: String) -> void:
	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)

	var editor_interface = plugin.get_editor_interface()
	var selection = editor_interface.get_selection()
	var selected_nodes = selection.get_selected_nodes()

	if selected_nodes.size() == 0:
		return _send_success(
			client_id,
			{
				"selected": false,
				"message": "No node is currently selected",
			},
			command_id,
		)

	var node = selected_nodes[0] # Get the first selected node

	# Get node info
	var node_data = {
		"selected": true,
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	# Get script info if available
	var script = node.get_script()
	if script:
		node_data["script_path"] = script.resource_path

	# Get important properties
	var properties = { }
	var property_list = node.get_property_list()

	for prop in property_list:
		var name = prop["name"]
		if not name.begins_with("_"): # Skip internal properties
			# Only include some common properties to avoid overwhelming data
			if name in ["position", "rotation", "scale", "visible", "modulate", "z_index"]:
				properties[name] = node.get(name)

	node_data["properties"] = properties

	_send_success(client_id, node_data, command_id)


func _create_resource(client_id: int, params: Dictionary, command_id: String) -> void:
	var resource_type = params.get("resource_type", "")
	var resource_path = params.get("resource_path", "")
	var properties = params.get("properties", { })

	# Validation
	if resource_type.is_empty():
		return _send_error(client_id, "Resource type cannot be empty", command_id)

	if resource_path.is_empty():
		return _send_error(client_id, "Resource path cannot be empty", command_id)

	# Make sure we have an absolute path
	if not resource_path.begins_with("res://"):
		resource_path = "res://" + resource_path

	# Get editor interface
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)

	var editor_interface = plugin.get_editor_interface()

	# Create the resource
	var resource

	if ClassDB.class_exists(resource_type):
		if ClassDB.is_parent_class(resource_type, "Resource"):
			resource = ClassDB.instantiate(resource_type)
			if not resource:
				return _send_error(
					client_id,
					"Failed to instantiate resource: %s" % resource_type,
					command_id,
				)
		else:
			return _send_error(
				client_id,
				"Type is not a Resource: %s" % resource_type,
				command_id,
			)
	else:
		return _send_error(client_id, "Invalid resource type: %s" % resource_type, command_id)

	# Set properties
	for key in properties:
		resource.set(key, properties[key])

	# Create directory if needed
	var dir = resource_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var err = DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			return _send_error(
				client_id,
				"Failed to create directory: %s (Error code: %d)" % [dir, err],
				command_id,
			)

	# Save the resource
	var result = ResourceSaver.save(resource, resource_path)
	if result != OK:
		return _send_error(client_id, "Failed to save resource: %d" % result, command_id)

	# Refresh the filesystem
	editor_interface.get_resource_filesystem().scan()

	_send_success(
		client_id,
		{
			"resource_path": resource_path,
			"resource_type": resource_type,
		},
		command_id,
	)


func _reload_project(client_id: int, params: Dictionary, command_id: String) -> void:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)

	var editor_interface = plugin.get_editor_interface()
	var save_before_restart: bool = params.get("save", true)

	# Send success response before restarting (since restart will disconnect)
	_send_success(
		client_id,
		{
			"status": "restarting",
			"save": save_before_restart,
			"message": "Godot editor is restarting...",
		},
		command_id,
	)

	# Use call_deferred to allow the response to be sent before restart
	editor_interface.call_deferred("restart_editor", save_before_restart)


func _reload_scene(client_id: int, params: Dictionary, command_id: String) -> void:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)

	var editor_interface = plugin.get_editor_interface()
	var scene_path: String = params.get("scene_path", "")

	# If no scene path provided, reload the current scene
	if scene_path.is_empty():
		var edited_scene_root = editor_interface.get_edited_scene_root()
		if not edited_scene_root:
			return _send_error(client_id, "No scene is currently open in the editor", command_id)

		scene_path = edited_scene_root.scene_file_path
		if scene_path.is_empty():
			return _send_error(client_id, "Current scene has not been saved yet", command_id)

	# Validate scene path
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path

	if not ResourceLoader.exists(scene_path):
		return _send_error(client_id, "Scene does not exist: %s" % scene_path, command_id)

	# Reload the scene from disk
	editor_interface.reload_scene_from_path(scene_path)

	_send_success(
		client_id,
		{
			"status": "reloaded",
			"scene_path": scene_path,
			"message": "Scene reloaded from disk",
		},
		command_id,
	)


func _get_node_warnings(client_id: int, params: Dictionary, command_id: String) -> void:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		return _send_error(client_id, "No scene is currently being edited", command_id)

	var debug = _coerce_bool(params.get("debug", false), false)
	var scene_path = edited_scene_root.scene_file_path
	if scene_path.is_empty():
		scene_path = "Unsaved Scene"

	var scene_tree = EditorUtils.find_scene_tree_editor_tree(
		editor_interface,
		edited_scene_root.name,
	)
	if not scene_tree:
		return _send_error(client_id, "Scene tree dock not found", command_id)

	var scan = EditorUtils.collect_scene_tree_warning_entries(scene_tree, edited_scene_root.name)
	var warnings = scan.get("warnings", [])
	if warnings == null:
		warnings = []

	var result = {
		"scene_path": scene_path,
		"root_node_name": edited_scene_root.name,
		"root_node_type": edited_scene_root.get_class(),
		"tree_path": scan.get("tree_path", ""),
		"warnings": warnings,
		"warnings_count": warnings.size(),
		"items_scanned": scan.get("items_scanned", 0),
		"buttons_scanned": scan.get("buttons_scanned", 0),
	}

	if debug:
		result["debug"] = {
			"enabled": true,
			"tree_path": scan.get("tree_path", ""),
			"items_scanned": scan.get("items_scanned", 0),
			"buttons_scanned": scan.get("buttons_scanned", 0),
			"warnings_found": warnings.size(),
		}

	_send_success(client_id, result, command_id)


func _coerce_bool(value, default: bool) -> bool:
	if typeof(value) == TYPE_BOOL:
		return value
	if typeof(value) == TYPE_STRING:
		var lowered = value.to_lower()
		if lowered == "true":
			return true
		if lowered == "false":
			return false
	return bool(value) if value != null else default


func _rescan_filesystem(client_id: int, params: Dictionary, command_id: String) -> void:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)

	var editor_interface = plugin.get_editor_interface()
	var filesystem = editor_interface.get_resource_filesystem()

	var target_paths: Array = params.get("paths", [])
	var scan_src: bool = params.get("sources", true)

	var start_ms := Time.get_ticks_msec()
	var reimported_count := 0
	var actions_performed: Array[String] = []

	# Step 1: Reimport specific files if paths provided
	if not target_paths.is_empty():
		var packed := PackedStringArray()
		var skipped := 0
		for p in target_paths:
			var path_str: String = str(p).strip_edges()
			if path_str.is_empty():
				skipped += 1
				continue
			if not path_str.begins_with("res://"):
				path_str = "res://" + path_str
			# Accept both files and directories (reimport_files handles import groups)
			if FileAccess.file_exists(path_str) or DirAccess.dir_exists_absolute(path_str):
				packed.append(path_str)
			else:
				skipped += 1

		if not packed.is_empty():
			# reimport_files() blocks until done — no polling needed
			filesystem.reimport_files(packed)
			reimported_count = packed.size()
			actions_performed.append("reimported %d files" % reimported_count)
		if skipped > 0:
			actions_performed.append("skipped %d nonexistent paths" % skipped)
		else:
			actions_performed.append("all %d paths were invalid or nonexistent" % skipped)
	else:
		# Step 2: Full filesystem scan (detects new/changed files, triggers reimports)
		filesystem.scan()
		actions_performed.append("initiated full filesystem scan")

	# Step 3: Scan script sources for import changes (e.g. .gd files that affect .import)
	if scan_src:
		filesystem.scan_sources()
		actions_performed.append("scanned script sources")

	# Step 4: Wait for background scan to complete (scan() is async)
	if filesystem.has_method("is_scanning") and filesystem.is_scanning():
		var scene_tree := get_tree()
		var timeout_ms: int = 30000
		while filesystem.is_scanning() and (Time.get_ticks_msec() - start_ms) < timeout_ms:
			if scene_tree:
				await scene_tree.process_frame

	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	var still_scanning: bool = filesystem.has_method("is_scanning") and filesystem.is_scanning()

	_send_success(
		client_id,
		{
			"status": "timeout" if still_scanning else "complete",
			"reimported_count": reimported_count,
			"scan_complete": not still_scanning,
			"elapsed_ms": elapsed_ms,
			"actions": actions_performed,
			"message": (
				"Filesystem rescan %s in %d ms — %s"
				% [
					"completed" if not still_scanning else "timed out",
					elapsed_ms,
					", ".join(actions_performed),
				]
			),
		},
		command_id,
	)
