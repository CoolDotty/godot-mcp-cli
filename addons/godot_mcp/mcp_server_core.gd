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
	var uri: String = _params.get("uri", "")

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
	_load_tool_providers()


## Dynamically load all tool provider scripts from the tool_providers/ directory.
## Each file defines a class with a get_definition() -> ToolDefinition method.
## If a file fails to compile or load, it is skipped gracefully so the rest
## of the server continues to function.
func _load_tool_providers() -> void:
	var dir := "res://addons/godot_mcp/tool_providers/"
	var da := DirAccess.open(dir)
	if da == null:
		push_error("Could not open tool_providers directory: " + dir)
		return

	da.list_dir_begin()
	var file_name := da.get_next()
	var loaded := 0
	var skipped := 0

	while not file_name.is_empty():
		if file_name.ends_with(".gd") and file_name != ".gd":
			var full_path := dir + file_name
			var tool := _try_load_tool_provider(full_path)
			if tool:
				register_tool(tool)
				loaded += 1
			else:
				skipped += 1
		file_name = da.get_next()

	da.list_dir_end()
	print("MCP Core: loaded %d tools, skipped %d" % [loaded, skipped])


## Attempt to load a single tool provider script. Returns a ToolDefinition
## on success, or null if the script fails to compile or has errors.
func _try_load_tool_provider(path: String) -> ToolDefinition:
	if not ResourceLoader.exists(path):
		push_warning("Tool provider not found: " + path)
		return null

	var script := load(path) as GDScript
	if script == null:
		push_warning("Failed to load tool provider: " + path)
		return null

	# Check for parse/compile errors in the script
	if not script.can_instantiate():
		push_warning("Tool provider has compile errors, skipping: " + path)
		return null

	# Instantiate and verify it has the required method
	var instance := script.new()
	if instance == null:
		push_warning("Could not instantiate tool provider: " + path)
		return null

	if not instance.has_method("get_definition"):
		push_warning("Tool provider missing get_definition(): " + path)
		return null

	var def: ToolDefinition = instance.get_definition()
	if def == null:
		push_warning("Tool provider returned null definition: " + path)
		return null

	return def

# (73 tool definitions moved to res://addons/godot_mcp/tool_providers/)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------------------------------------------------------------


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
