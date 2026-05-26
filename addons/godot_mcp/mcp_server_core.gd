@tool
## MCP Protocol Core — JSON-RPC 2.0 engine, tool/resource registry.
##
## Handles the MCP protocol lifecycle: initialize, tools/list,
## tools/call, resources/list, resources/read. Routes tool calls
## to the existing command processor chain via a response broker.
class_name MCPServerCore
extends Node

# ---------------------------------------------------------------------------
# Response Broker — captures responses from command processors
# ---------------------------------------------------------------------------
## Acts as a fake `_websocket_server` for command processors so they
## can write their responses into a dict keyed by commandId.
class ResponseBroker:
	extends RefCounted

	var _pending: Dictionary = { } # commandId → response dict
	var _completed: Dictionary = { } # commandId → response dict (after retrieval)


	func send_response(_client_id: int, response: Dictionary) -> int:
		var cmd_id: String = response.get("commandId", "")
		if cmd_id:
			_pending[cmd_id] = response.duplicate(true)
		return OK


	func send_event(_client_id: int, _event: Dictionary) -> int:
		return OK


	func broadcast_event(_event: Dictionary) -> void:
		pass


	## Wait up to `timeout` seconds for a response with the given commandId.
	func wait_for_response(cmd_id: String, timeout: float = 10.0) -> Variant:
		var elapsed: float = 0.0
		while elapsed < timeout:
			if _pending.has(cmd_id):
				var resp = _pending[cmd_id]
				_pending.erase(cmd_id)
				_completed[cmd_id] = resp
				return resp
			OS.delay_msec(10)
			elapsed += 0.01
		return null


	## Non-blocking check for a pending response.
	func poll_response(cmd_id: String) -> Variant:
		if _pending.has(cmd_id):
			var resp = _pending[cmd_id]
			_pending.erase(cmd_id)
			_completed[cmd_id] = resp
			return resp
		return null


# ---------------------------------------------------------------------------
# Tool Definition
# ---------------------------------------------------------------------------
class ToolDefinition:
	extends RefCounted

	var name: String
	var description: String
	var input_schema: Dictionary # JSON Schema
	var command_type: String # Maps to command_handler command type


	func _init(p_name: String, p_description: String, p_schema: Dictionary, p_command: String):
		name = p_name
		description = p_description
		input_schema = p_schema
		command_type = p_command

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
## Emitted when a JSON-RPC response is ready to be sent back via HTTP
signal jsonrpc_response(response: Dictionary)

## Emitted when an SSE notification should be broadcast
signal sse_notification(notification: Dictionary)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var is_initialized: bool = false
var client_capabilities: Dictionary = { }
var server_capabilities: Dictionary = {
	"tools": { },
	"resources": { },
}

# Tracks which SSE client performed the initialize (for per-session reset).
# -1 means no client has initialized. When an SSE client disconnects,
# we only reset is_initialized if the disconnecting client was the one
# that initialized. This prevents one client's disconnect from tearing
# down another client's session.
var _initialized_client_id: int = -1

# Internal
var _command_handler = null
var _response_broker: ResponseBroker = null
var _tools: Array[ToolDefinition] = []
var _resources: Array = [] # resource definitions (for future use)
var _tool_map: Dictionary = { } # tool_name → ToolDefinition


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_response_broker = ResponseBroker.new()
	_register_builtin_tools()


## Set the command handler reference. Must be called after construction.
func set_command_handler(handler) -> void:
	_command_handler = handler
	# Swap the websocket_server reference to our broker so command
	# processor responses come through us.
	if _command_handler:
		_command_handler.set_websocket_server(_response_broker)
		_set_broker_on_processors(_command_handler)


func get_response_broker() -> ResponseBroker:
	return _response_broker


## Connect to an MCPSse instance to track client disconnects.
## Resets initialization state when the last SSE client disconnects,
## allowing new clients to initialize without errors.
func bind_sse(sse: MCPSse) -> void:
	if sse:
		sse.sse_client_disconnected.connect(_on_sse_client_disconnected)


func _on_sse_client_disconnected(client_id: int) -> void:
	# Per-session tracking: only reset if the disconnecting client
	# is the one that performed the initialize.
	if client_id == _initialized_client_id:
		is_initialized = false
		_initialized_client_id = -1
		client_capabilities = { }
		return

	# Fallback: if the initialized client is gone but wasn't tracked
	# (e.g. from an older session), reset when no SSE clients remain.
	if sse_client_count() == 0:
		is_initialized = false
		_initialized_client_id = -1
		client_capabilities = { }


func sse_client_count() -> int:
	# Walk up to find the MCPSse node — it's a sibling under the plugin.
	var parent_node = get_parent()
	if parent_node:
		for child in parent_node.get_children():
			if child is MCPSse:
				return child.get_client_count()
	return 0


## Get the most recently registered SSE client ID.
## Used to associate POST initialize requests with an SSE session.
func _get_active_sse_client_id() -> int:
	var parent_node = get_parent()
	if parent_node:
		for child in parent_node.get_children():
			if child is MCPSse:
				var ids: Array = child.get_client_ids()
				if not ids.is_empty():
					return ids[-1] # Most recently registered
	return -1


## Check whether a given SSE client is still connected.
func _is_sse_client_connected(client_id: int) -> bool:
	var parent_node = get_parent()
	if parent_node:
		for child in parent_node.get_children():
			if child is MCPSse:
				return child.is_client_connected(client_id)
	return false

# ---------------------------------------------------------------------------
# MCP Method Handlers
# ---------------------------------------------------------------------------


## Handle an incoming MCP JSON-RPC request. Returns the response dict,
## or null for notifications (no response expected).
func handle_mcp_request(request: Dictionary) -> Variant:
	var method: String = request.get("method", "")
	var params: Dictionary = request.get("params", { })
	var req_id = request.get("id", null)

	# Notifications don't have an id — we don't send a response
	var is_notification := req_id == null

	match method:
		"initialize":
			return _handle_initialize(params, req_id)
		"initialized":
			_handle_initialized_notification(params)
			if is_notification:
				return null
			return MCPTypes.make_success_response(req_id, { })
		"tools/list":
			return _handle_tools_list(params, req_id)
		"tools/call":
			return _handle_tools_call(params, req_id)
		"resources/list":
			return _handle_resources_list(params, req_id)
		"resources/read":
			return _handle_resources_read(params, req_id)
		"ping":
			return MCPTypes.make_success_response(req_id, { })
		_:
			if is_notification:
				return null # Unknown notifications are ignored (MCP spec)
			return MCPTypes.make_error_response(
				req_id,
				MCPTypes.ErrorCode.METHOD_NOT_FOUND,
				"Unknown method: %s" % method,
			)


# ---------------------------------------------------------------------------
# Initialize
# ---------------------------------------------------------------------------
func _handle_initialize(params: Dictionary, req_id: Variant) -> Dictionary:
	# Auto-reset if the previously initialized SSE client disconnected
	if is_initialized and _initialized_client_id >= 0:
		if not _is_sse_client_connected(_initialized_client_id):
			is_initialized = false
			_initialized_client_id = -1
			client_capabilities = { }

	if is_initialized:
		# Already initialized — return success (idempotent) instead of
		# blocking other clients. Multi-client scenarios are common when
		# MCP clients reconnect without tearing down old SSE sessions.
		return MCPTypes.make_success_response(
			req_id,
			{
				"protocolVersion": MCPTypes.PROTOCOL_VERSION,
				"capabilities": server_capabilities,
				"serverInfo": {
					"name": "godot-mcp",
					"version": "1.1.0",
				},
			},
		)

	client_capabilities = params.get("capabilities", { })
	is_initialized = true
	_initialized_client_id = _get_active_sse_client_id()

	return MCPTypes.make_success_response(
		req_id,
		{
			"protocolVersion": MCPTypes.PROTOCOL_VERSION,
			"capabilities": server_capabilities,
			"serverInfo": {
				"name": "godot-mcp",
				"version": "1.1.0",
			},
		},
	)


func _handle_initialized_notification(_params: Dictionary) -> void:
	# Client confirms initialization is complete
	is_initialized = true


# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------
func _handle_tools_list(_params: Dictionary, req_id: Variant) -> Dictionary:
	var tools_list: Array[Dictionary] = []
	for tool in _tools:
		tools_list.append(
			{
				"name": tool.name,
				"description": tool.description,
				"inputSchema": tool.input_schema,
			},
		)

	return MCPTypes.make_success_response(
		req_id,
		{
			"tools": tools_list,
		},
	)


func _handle_tools_call(params: Dictionary, req_id: Variant) -> Variant:
	var name: String = params.get("name", "")
	var arguments: Dictionary = params.get("arguments", { })

	if not _tool_map.has(name):
		return MCPTypes.make_error_response(
			req_id,
			MCPTypes.ErrorCode.TOOL_NOT_FOUND,
			"Tool not found: %s" % name,
		)

	var tool_def: ToolDefinition = _tool_map[name]

	# Build a command in the format expected by command processors
	var command_id := "mcp_%s_%d" % [name, Time.get_ticks_msec()]
	var command := {
		"type": tool_def.command_type,
		"params": arguments,
		"commandId": command_id,
	}

	# Route to command handler
	if not _command_handler:
		return MCPTypes.make_error_response(
			req_id,
			MCPTypes.ErrorCode.INTERNAL_ERROR,
			"Command handler not available",
		)

	# Call the command handler
	var handled: bool = false
	for processor in _command_handler.get_command_processors():
		if _call_processor_blocking(processor, command_id, command):
			handled = true
			break

	if not handled:
		return MCPTypes.make_error_response(
			req_id,
			MCPTypes.ErrorCode.TOOL_EXECUTION_ERROR,
			"No processor handled tool: %s" % name,
		)

	# Wait for the response via the broker
	var response = _response_broker.wait_for_response(command_id, 30.0)
	if response == null:
		return MCPTypes.make_error_response(
			req_id,
			MCPTypes.ErrorCode.TOOL_EXECUTION_ERROR,
			"Tool execution timed out: %s" % name,
		)

	if response.get("status") == "success":
		return MCPTypes.make_success_response(
			req_id,
			{
				"content": [
					{
						"type": "text",
						"text": JSON.stringify(response.get("result", { })),
					},
				],
			},
		)

	return MCPTypes.make_error_response(
		req_id,
		MCPTypes.ErrorCode.TOOL_EXECUTION_ERROR,
		response.get("message", "Tool execution failed"),
	)


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------
func _handle_resources_list(_params: Dictionary, req_id: Variant) -> Dictionary:
	var resources_list: Array[Dictionary] = []
	for res in _resources:
		resources_list.append(res)

	return MCPTypes.make_success_response(
		req_id,
		{
			"resources": resources_list,
		},
	)


func _handle_resources_read(_params: Dictionary, req_id: Variant) -> Variant:
	var uri: String = params.get("uri", "")

	# For now, resources are read-only informational
	return MCPTypes.make_error_response(
		req_id,
		MCPTypes.ErrorCode.RESOURCE_NOT_FOUND,
		"Resource not found: %s" % uri,
	)

# ---------------------------------------------------------------------------
# Tool Registration
# ---------------------------------------------------------------------------


## Register a tool definition. Used by subclasses to add tools.
func register_tool(tool: ToolDefinition) -> void:
	_tools.append(tool)
	_tool_map[tool.name] = tool


## Register a resource definition.
func register_resource(resource: Dictionary) -> void:
	_resources.append(resource)


# ---------------------------------------------------------------------------
# Built-in tools
# ---------------------------------------------------------------------------
func _register_builtin_tools() -> void:
	# --- Node Tools ---
	register_tool(
		ToolDefinition.new(
			"create_node",
			"Create a new node in the scene tree.",
			{
				"type": "object",
				"properties": {
					"parent_path": {
						"type": "string",
						"description": "Path to the parent node (default: root)",
					},
					"node_type": {
						"type": "string",
						"description": "Node class name (e.g. Node2D, Sprite2D)",
					},
					"node_name": { "type": "string", "description": "Name for the new node" },
				},
				"required": ["node_type", "node_name"],
			},
			"create_node",
		),
	)

	register_tool(
		ToolDefinition.new(
			"delete_node",
			"Delete a node from the scene tree.",
			{
				"type": "object",
				"properties": {
					"node_path": { "type": "string", "description": "Path to the node to delete" },
				},
				"required": ["node_path"],
			},
			"delete_node",
		),
	)

	register_tool(
		ToolDefinition.new(
			"update_node_property",
			"Update a property on a node.",
			{
				"type": "object",
				"properties": {
					"node_path": { "type": "string", "description": "Path to the node" },
					"property": {
						"type": "string",
						"description": "Name of the property to update",
					},
					"value": { "description": "New value for the property" },
				},
				"required": ["node_path", "property", "value"],
			},
			"update_node_property",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_node_properties",
			"Get all properties of a node.",
			{
				"type": "object",
				"properties": {
					"node_path": { "type": "string", "description": "Path to the node" },
				},
				"required": ["node_path"],
			},
			"get_node_properties",
		),
	)

	register_tool(
		ToolDefinition.new(
			"list_nodes",
			"List all nodes in the current scene.",
			{
				"type": "object",
				"properties": {
					"parent_path": {
						"type": "string",
						"description": "Optional parent path to list children of",
					},
				},
			},
			"list_nodes",
		),
	)

	# --- Script Tools ---
	register_tool(
		ToolDefinition.new(
			"execute_editor_script",
			"Run a GDScript code snippet in the editor context.",
			{
				"type": "object",
				"properties": {
					"code": { "type": "string", "description": "GDScript code to execute" },
				},
				"required": ["code"],
			},
			"execute_editor_script",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_script",
			"Get the source code of a script attached to a node or resource.",
			{
				"type": "object",
				"properties": {
					"script_path": { "type": "string", "description": "Path to the script file" },
					"node_path": {
						"type": "string",
						"description": "Path to the node with a script attached",
					},
				},
				"oneOf": [
					{ "required": ["script_path"] },
					{ "required": ["node_path"] },
				],
			},
			"get_script",
		),
	)

	# --- Scene Tools ---
	register_tool(
		ToolDefinition.new(
			"save_scene",
			"Save the current scene.",
			{
				"type": "object",
				"properties": {
					"path": { "type": "string", "description": "Optional path to save to" },
				},
			},
			"save_scene",
		),
	)

	register_tool(
		ToolDefinition.new(
			"open_scene",
			"Open a scene file in the editor.",
			{
				"type": "object",
				"properties": {
					"path": { "type": "string", "description": "Path to the .tscn file" },
				},
				"required": ["path"],
			},
			"open_scene",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_scene_structure",
			"Get the full scene tree structure with properties.",
			{
				"type": "object",
				"properties": {
					"path": { "type": "string", "description": "Path to the .tscn file" },
				},
				"required": ["path"],
			},
			"get_scene_structure",
		),
	)

	# --- Project Tools ---
	register_tool(
		ToolDefinition.new(
			"get_project_info",
			"Get project information.",
			{
				"type": "object",
				"properties": { },
			},
			"get_project_info",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_project_settings",
			"Get project settings.",
			{
				"type": "object",
				"properties": { },
			},
			"get_project_settings",
		),
	)

	register_tool(
		ToolDefinition.new(
			"run_project",
			"Launch the project's main scene (same as F5).",
			{
				"type": "object",
				"properties": { },
			},
			"run_project",
		),
	)

	register_tool(
		ToolDefinition.new(
			"stop_running_project",
			"Stop the currently running project.",
			{
				"type": "object",
				"properties": { },
			},
			"stop_running_project",
		),
	)

	register_tool(
		ToolDefinition.new(
			"run_current_scene",
			"Play the current scene in the editor (same as F6).",
			{
				"type": "object",
				"properties": { },
			},
			"run_current_scene",
		),
	)

	register_tool(
		ToolDefinition.new(
			"run_specific_scene",
			"Run a specific scene by path.",
			{
				"type": "object",
				"properties": {
					"scene_path": { "type": "string", "description": "Path to the scene to run" },
				},
				"required": ["scene_path"],
			},
			"run_specific_scene",
		),
	)

	register_tool(
		ToolDefinition.new(
			"reload_project",
			"Restart the Godot editor (reload the entire project).",
			{
				"type": "object",
				"properties": {
					"save": {
						"type": "boolean",
						"description": "Save before restarting (default: true)",
					},
				},
			},
			"reload_project",
		),
	)

	register_tool(
		ToolDefinition.new(
			"reload_scene",
			"Reload the current scene from disk, discarding unsaved changes.",
			{
				"type": "object",
				"properties": {
					"scene_path": {
						"type": "string",
						"description": "Optional specific scene path to reload (default: " +
						"current scene)",
					},
				},
			},
			"reload_scene",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_project_structure",
			"Get a summary of the project file structure (directories and " +
			"file counts by extension).",
			{
				"type": "object",
				"properties": { },
			},
			"get_project_structure",
		),
	)

	register_tool(
		ToolDefinition.new(
			"list_project_resources",
			"List project resources categorized by type (scenes, scripts, " +
			"textures, audio, models, resources).",
			{
				"type": "object",
				"properties": { },
			},
			"list_project_resources",
		),
	)

	# --- Editor Tools ---
	register_tool(
		ToolDefinition.new(
			"get_editor_state",
			"Get current editor state information.",
			{
				"type": "object",
				"properties": { },
			},
			"get_editor_state",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_node_warnings",
			"Inspect the current scene for node configuration warnings.",
			{
				"type": "object",
				"properties": {
					"debug": { "type": "boolean", "description": "Include traversal debug stats" },
				},
			},
			"get_node_warnings",
		),
	)

	register_tool(
		ToolDefinition.new(
			"rescan_filesystem",
			"Rescan the project filesystem and reimport changed assets. " +
			"Use when files have been modified externally (e.g. " +
			"by AI writing scripts, textures) and the editor needs to pick up the changes.",
			{
				"type": "object",
				"properties": {
					"paths": {
						"type": "array",
						"items": { "type": "string" },
						"description": "Optional list of specific file paths to reimport (e.g. " +
						"['res://icon.svg', 'res://scenes/main.tscn'])",
					},
					"sources": {
						"type": "boolean",
						"description": "Also re-scan script sources for import changes " +
						"(default: true)",
					},
				},
			},
			"rescan_filesystem",
		),
	)

	# --- Enhanced Scene Tools ---
	register_tool(
		ToolDefinition.new(
			"get_editor_scene_structure",
			"Get detailed editor scene tree with properties and scripts.",
			{
				"type": "object",
				"properties": {
					"include_properties": {
						"type": "boolean",
						"description": "Include node properties",
					},
					"include_scripts": { "type": "boolean", "description": "Include script info" },
					"max_depth": { "type": "number", "description": "Maximum depth to traverse" },
				},
			},
			"get_editor_scene_structure",
		),
	)

	# --- GDScript Formatter Tools ---
	register_tool(
		ToolDefinition.new(
			"check_formatter",
			"Check if the GDQuest GDScript Formatter addon and binary are installed.",
			{
				"type": "object",
				"properties": { },
			},
			"check_formatter",
		),
	)

	register_tool(
		ToolDefinition.new(
			"install_formatter_addon",
			"Download the GDQuest GDScript Formatter addon files into the project. " +
			"Requires enabling the plugin in Project → Project Settings → Plugins afterwards.",
			{
				"type": "object",
				"properties": { },
			},
			"install_formatter_addon",
		),
	)

	register_tool(
		ToolDefinition.new(
			"install_formatter_binary",
			"Download and install the platform-specific GDScript Formatter " +
			"binary from GitHub releases. Stores it in the editor cache directory.",
			{
				"type": "object",
				"properties": { },
			},
			"install_formatter_binary",
		),
	)

	register_tool(
		ToolDefinition.new(
			"format_gdscript",
			"Format GDScript file(s) using the installed formatter. " +
			"Accepts a single file path or a glob pattern (e.g. *, **/*.gd, addons/*.gd). " +
			"Supports indent style, safe mode, code reordering, and optional dry-run.",
			{
				"type": "object",
				"properties": {
					"script_path": {
						"type": "string",
						"description": "Path to a .gd file or glob pattern (res:// or relative). " +
						"Use * to format all .gd files.",
					},
					"use_spaces": {
						"type": "boolean",
						"description": "Use spaces instead of tabs",
					},
					"indent_size": {
						"type": "number",
						"description": "Indent size when using spaces (default: 4)",
					},
					"reorder_code": {
						"type": "boolean",
						"description": "Reorder code to follow the GDScript style guide",
					},
					"safe_mode": {
						"type": "boolean",
						"description": "Skip formatting if it would change code meaning " +
						"(default: true)",
					},
					"write_back": {
						"type": "boolean",
						"description": "Write formatted code back to the file (default: true). " +
						"Set to false for a dry run.",
					},
				},
				"required": ["script_path"],
			},
			"format_gdscript",
		),
	)

	register_tool(
		ToolDefinition.new(
			"format_all_gdscript",
			"Format every .gd file in the project. " +
			"Convenience wrapper that calls format_gdscript with a '*' pattern.",
			{
				"type": "object",
				"properties": {
					"use_spaces": {
						"type": "boolean",
						"description": "Use spaces instead of tabs",
					},
					"indent_size": {
						"type": "number",
						"description": "Indent size when using spaces (default: 4)",
					},
					"reorder_code": {
						"type": "boolean",
						"description": "Reorder code to follow the GDScript style guide",
					},
					"safe_mode": {
						"type": "boolean",
						"description": "Skip formatting if it would change code meaning " +
						"(default: true)",
					},
					"write_back": {
						"type": "boolean",
						"description": "Write formatted code back to the file (default: true). " +
						"Set to false for a dry run.",
					},
				},
			},
			"format_all_gdscript",
		),
	)

	register_tool(
		ToolDefinition.new(
			"list_assets_by_type",
			"List project assets filtered by type (scripts, scenes, images, " +
			"audio, fonts, models, shaders, resources, all).",
			{
				"type": "object",
				"properties": {
					"type": {
						"type": "string",
						"description": "Asset type filter: scripts, scenes, images, audio, " +
						"fonts, models, shaders, resources, or all",
					},
				},
				"required": ["type"],
			},
			"list_assets_by_type",
		),
	)

	register_tool(
		ToolDefinition.new(
			"list_project_files",
			"List project files, optionally filtered by extension.",
			{
				"type": "object",
				"properties": {
					"extensions": {
						"type": "array",
						"items": { "type": "string" },
						"description": "File extensions to filter by (e.g. ['.gd', '.tscn'])",
					},
				},
			},
			"list_project_files",
		),
	)

	# --- Debugger Tools ---
	register_tool(
		ToolDefinition.new(
			"get_debug_output",
			"Get recent debug output.",
			{
				"type": "object",
				"properties": {
					"max_lines": {
						"type": "number",
						"description": "Maximum number of lines to return (default 100)",
					},
				},
			},
			"get_debug_output",
		),
	)

	# --- Scene Creation/Deletion ---
	register_tool(
		ToolDefinition.new(
			"create_scene",
			"Create a new scene file.",
			{
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path for the new scene file (e.g. res://scenes/level.tscn)",
					},
					"root_node_type": {
						"type": "string",
						"description": "Root node class name (e.g. Node2D, Node3D, Control). " +
						"Default: Node",
					},
				},
				"required": ["path"],
			},
			"create_scene",
		),
	)

	register_tool(
		ToolDefinition.new(
			"delete_scene",
			"Delete a scene file from the project. Cannot delete the currently open scene.",
			{
				"type": "object",
				"properties": {
					"path": { "type": "string", "description": "Path to the scene file to delete" },
				},
				"required": ["path"],
			},
			"delete_scene",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_current_scene",
			"Get information about the currently open scene.",
			{
				"type": "object",
				"properties": { },
			},
			"get_current_scene",
		),
	)

	# --- Script Creation/Editing ---
	register_tool(
		ToolDefinition.new(
			"create_script",
			"Create a new script file and optionally attach it to a node.",
			{
				"type": "object",
				"properties": {
					"script_path": {
						"type": "string",
						"description": "Path for the new script (e.g. res://scripts/player.gd)",
					},
					"content": { "type": "string", "description": "Script source code content" },
					"node_path": {
						"type": "string",
						"description": "Optional node path to attach the script to",
					},
				},
				"required": ["script_path", "content"],
			},
			"create_script",
		),
	)

	register_tool(
		ToolDefinition.new(
			"edit_script",
			"Edit a script's source code by overwriting the file content.",
			{
				"type": "object",
				"properties": {
					"script_path": {
						"type": "string",
						"description": "Path to the script file to edit",
					},
					"content": {
						"type": "string",
						"description": "New source code content for the script",
					},
				},
				"required": ["script_path", "content"],
			},
			"edit_script",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_script_metadata",
			"Get metadata about a script (class_name, extends, methods, signals).",
			{
				"type": "object",
				"properties": {
					"path": { "type": "string", "description": "Path to the script file" },
				},
				"required": ["path"],
			},
			"get_script_metadata",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_current_script",
			"Get the currently edited script in the script editor.",
			{
				"type": "object",
				"properties": { },
			},
			"get_current_script",
		),
	)

	# --- Editor Tools ---
	register_tool(
		ToolDefinition.new(
			"get_selected_node",
			"Get the currently selected node in the editor with its properties.",
			{
				"type": "object",
				"properties": { },
			},
			"get_selected_node",
		),
	)

	register_tool(
		ToolDefinition.new(
			"create_resource",
			"Create a new resource file (e.g. Material, Shader, etc.).",
			{
				"type": "object",
				"properties": {
					"resource_type": {
						"type": "string",
						"description": "Resource class name (e.g. " +
						"StandardMaterial3D, ShaderMaterial)",
					},
					"resource_path": {
						"type": "string",
						"description": "Path for the new resource file",
					},
					"properties": {
						"type": "object",
						"description": "Optional initial properties",
					},
				},
				"required": ["resource_type", "resource_path"],
			},
			"create_resource",
		),
	)

	# --- Runtime / Enhanced Tools ---
	register_tool(
		ToolDefinition.new(
			"get_runtime_scene_structure",
			"Snapshot the live scene tree from a running game via the debugger.",
			{
				"type": "object",
				"properties": {
					"include_properties": {
						"type": "boolean",
						"description": "Include node properties in the snapshot",
					},
					"include_scripts": {
						"type": "boolean",
						"description": "Include script info in the snapshot",
					},
					"max_depth": { "type": "number", "description": "Maximum depth to traverse" },
					"timeout_ms": {
						"type": "number",
						"description": "Timeout in milliseconds (default: 2000)",
					},
				},
			},
			"get_runtime_scene_structure",
		),
	)

	register_tool(
		ToolDefinition.new(
			"evaluate_runtime",
			"Evaluate a GDScript expression on the running game via the debugger.",
			{
				"type": "object",
				"properties": {
					"expression": {
						"type": "string",
						"description": "GDScript expression to evaluate (e.g. player.health)",
					},
					"context_path": {
						"type": "string",
						"description": "Optional node path to use as evaluation context",
					},
					"capture_prints": {
						"type": "boolean",
						"description": "Capture print() output during evaluation (default: true)",
					},
					"timeout_ms": {
						"type": "number",
						"description": "Timeout in milliseconds (default: 2000)",
					},
				},
				"required": ["expression"],
			},
			"evaluate_runtime",
		),
	)

	register_tool(
		ToolDefinition.new(
			"update_node_transform",
			"Adjust a node's transform (position, rotation, scale) in the editor.",
			{
				"type": "object",
				"properties": {
					"node_path": {
						"type": "string",
						"description": "Path to the node in the current scene",
					},
					"position": {
						"type": "array",
						"items": { "type": "number" },
						"description": "New position as [x, y]",
					},
					"rotation": { "type": "number", "description": "New rotation in radians" },
					"scale": {
						"type": "array",
						"items": { "type": "number" },
						"description": "New scale as [x, y]",
					},
				},
				"required": ["node_path"],
			},
			"update_node_transform",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_editor_errors",
			"Read the Errors tab of the bottom panel in the editor.",
			{
				"type": "object",
				"properties": { },
			},
			"get_editor_errors",
		),
	)

	register_tool(
		ToolDefinition.new(
			"clear_debug_output",
			"Clear the Output panel in the editor.",
			{
				"type": "object",
				"properties": { },
			},
			"clear_debug_output",
		),
	)

	register_tool(
		ToolDefinition.new(
			"clear_editor_errors",
			"Clear the Errors tab in the editor.",
			{
				"type": "object",
				"properties": { },
			},
			"clear_editor_errors",
		),
	)

	register_tool(
		ToolDefinition.new(
			"subscribe_debug_output",
			"Start live streaming of debug output to this client.",
			{
				"type": "object",
				"properties": { },
			},
			"subscribe_debug_output",
		),
	)

	register_tool(
		ToolDefinition.new(
			"unsubscribe_debug_output",
			"Stop live streaming of debug output for this client.",
			{
				"type": "object",
				"properties": { },
			},
			"unsubscribe_debug_output",
		),
	)

	# --- Stack Trace Tools ---
	register_tool(
		ToolDefinition.new(
			"get_stack_trace_panel",
			"Capture the Stack Trace panel text plus parsed frames from the debugger.",
			{
				"type": "object",
				"properties": {
					"session_id": {
						"type": "number",
						"description": "Optional debugger session ID",
					},
				},
			},
			"get_stack_trace_panel",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_stack_frames_panel",
			"Return structured stack frames from the debugger bridge.",
			{
				"type": "object",
				"properties": {
					"session_id": {
						"type": "number",
						"description": "Optional debugger session ID",
					},
					"refresh": {
						"type": "boolean",
						"description": "Force refresh from the debugger (default: false)",
					},
				},
			},
			"get_stack_frames_panel",
		),
	)

	# --- Debugger Control Tools ---
	register_tool(
		ToolDefinition.new(
			"debugger_set_breakpoint",
			"Set a breakpoint in a script at the specified line.",
			{
				"type": "object",
				"properties": {
					"script_path": { "type": "string", "description": "Path to the script file" },
					"line": { "type": "number", "description": "Line number for the breakpoint" },
				},
				"required": ["script_path", "line"],
			},
			"debugger_set_breakpoint",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_remove_breakpoint",
			"Remove a breakpoint from a script at the specified line.",
			{
				"type": "object",
				"properties": {
					"script_path": { "type": "string", "description": "Path to the script file" },
					"line": {
						"type": "number",
						"description": "Line number of the breakpoint to remove",
					},
				},
				"required": ["script_path", "line"],
			},
			"debugger_remove_breakpoint",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_get_breakpoints",
			"List all breakpoints currently set.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_get_breakpoints",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_clear_all_breakpoints",
			"Clear all breakpoints.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_clear_all_breakpoints",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_pause_execution",
			"Pause the running project.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_pause_execution",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_resume_execution",
			"Resume a paused project.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_resume_execution",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_step_over",
			"Step over the current line in the debugger.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_step_over",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_step_into",
			"Step into a function call in the debugger.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_step_into",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_get_call_stack",
			"Get the current call stack from a paused debugger session.",
			{
				"type": "object",
				"properties": {
					"session_id": {
						"type": "number",
						"description": "Optional debugger session ID",
					},
				},
			},
			"debugger_get_call_stack",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_get_current_state",
			"Get the current debugger state (active sessions, running status, etc.).",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_get_current_state",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_enable_events",
			"Enable debugger event notifications for this client (breakpoint hits, pauses, etc.).",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_enable_events",
		),
	)

	register_tool(
		ToolDefinition.new(
			"debugger_disable_events",
			"Disable debugger event notifications for this client.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_disable_events",
		),
	)

	# --- Input Simulation Tools ---
	register_tool(
		ToolDefinition.new(
			"simulate_action_press",
			"Press an input action in the running project.",
			{
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"description": "Input action name (e.g. ui_accept, move_left)",
					},
					"strength": {
						"type": "number",
						"description": "Action strength between 0.0 and 1.0 (default: 1.0)",
					},
				},
				"required": ["action"],
			},
			"simulate_action_press",
		),
	)

	register_tool(
		ToolDefinition.new(
			"simulate_action_release",
			"Release an input action in the running project.",
			{
				"type": "object",
				"properties": {
					"action": { "type": "string", "description": "Input action name to release" },
				},
				"required": ["action"],
			},
			"simulate_action_release",
		),
	)

	register_tool(
		ToolDefinition.new(
			"simulate_action_tap",
			"Tap an input action (press + release) in the running project.",
			{
				"type": "object",
				"properties": {
					"action": { "type": "string", "description": "Input action name to tap" },
					"duration_ms": {
						"type": "number",
						"description": "How long to hold before releasing (default: 100)",
					},
				},
				"required": ["action"],
			},
			"simulate_action_tap",
		),
	)

	register_tool(
		ToolDefinition.new(
			"simulate_mouse_click",
			"Simulate a mouse click in the running project.",
			{
				"type": "object",
				"properties": {
					"x": { "type": "number", "description": "X position for the click" },
					"y": { "type": "number", "description": "Y position for the click" },
					"button": {
						"type": "string",
						"description": "Mouse button: left, right, or middle (default: left)",
					},
					"double_click": {
						"type": "boolean",
						"description": "Perform a double-click (default: false)",
					},
				},
			},
			"simulate_mouse_click",
		),
	)

	register_tool(
		ToolDefinition.new(
			"simulate_mouse_move",
			"Move the mouse cursor in the running project.",
			{
				"type": "object",
				"properties": {
					"x": { "type": "number", "description": "Target X position" },
					"y": { "type": "number", "description": "Target Y position" },
				},
				"required": ["x", "y"],
			},
			"simulate_mouse_move",
		),
	)

	register_tool(
		ToolDefinition.new(
			"simulate_drag",
			"Click and drag the mouse from one position to another.",
			{
				"type": "object",
				"properties": {
					"start_x": { "type": "number", "description": "Starting X position" },
					"start_y": { "type": "number", "description": "Starting Y position" },
					"end_x": { "type": "number", "description": "Ending X position" },
					"end_y": { "type": "number", "description": "Ending Y position" },
					"duration_ms": {
						"type": "number",
						"description": "Duration of the drag in milliseconds (default: 200)",
					},
					"steps": {
						"type": "number",
						"description": "Number of intermediate steps (default: 10)",
					},
					"button": {
						"type": "string",
						"description": "Mouse button: left, right, or middle (default: left)",
					},
				},
				"required": ["start_x", "start_y", "end_x", "end_y"],
			},
			"simulate_drag",
		),
	)

	register_tool(
		ToolDefinition.new(
			"simulate_key_press",
			"Simulate a keyboard key press in the running project.",
			{
				"type": "object",
				"properties": {
					"key": {
						"type": "string",
						"description": "Key name to press (e.g. A, Space, Escape)",
					},
					"duration_ms": {
						"type": "number",
						"description": "How long to hold the key (default: 100)",
					},
					"modifiers": {
						"type": "object",
						"description": "Modifier keys (e.g. {ctrl: true, shift: false})",
					},
				},
				"required": ["key"],
			},
			"simulate_key_press",
		),
	)

	register_tool(
		ToolDefinition.new(
			"simulate_input_sequence",
			"Execute a timed sequence of input actions with precise timing.",
			{
				"type": "object",
				"properties": {
					"sequence": {
						"type": "array",
						"description": "Array of input step objects, each with a type and timing",
					},
				},
				"required": ["sequence"],
			},
			"simulate_input_sequence",
		),
	)

	register_tool(
		ToolDefinition.new(
			"get_input_actions",
			"List all available input actions defined in the project's Input Map.",
			{
				"type": "object",
				"properties": { },
			},
			"get_input_actions",
		),
	)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


## Call a processor with the broker set, returning true if handled.
## Processors return `bool` immediately — actual responses arrive later
## through `_send_success`/`_send_error` which write to the ResponseBroker.
func _call_processor_blocking(processor, _command_id: String, command: Dictionary) -> bool:
	if not processor or not processor.has_method("process_command"):
		return false

	# Temporarily set broker on processor
	var old_server = null
	if processor.has_method("get_websocket_server"):
		old_server = processor.get_websocket_server()
		processor.set_websocket_server(_response_broker)

	var handled := false
	if processor.has_method("process_command"):
		# Call synchronously — processor returns bool immediately
		# The actual response is written to the broker via
		# _send_success/_send_error
		handled = processor.process_command(
			0,
			command.get("type"),
			command.get("params", { }),
			command.get("commandId", ""),
		)

	# Restore old server reference
	if old_server != null:
		processor.set_websocket_server(old_server)

	return handled


func _set_broker_on_processors(handler) -> void:
	if not handler or not handler.has_method("get_command_processors"):
		return
	for proc in handler.get_command_processors():
		if proc and proc.has_method("set_websocket_server"):
			proc.set_websocket_server(_response_broker)
