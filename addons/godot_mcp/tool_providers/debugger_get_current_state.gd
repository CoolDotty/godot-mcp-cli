@tool
## Tool provider for "debugger_get_current_state" — Get the current debugger state (active sessions, running status, etc.).
class_name ToolProviderDebuggerGetCurrentState
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_get_current_state",
		"Get the current debugger state (active sessions, running status, etc.).",
		{
			"type": "object",
			"properties": { },
		},
		"debugger_get_current_state",
	)
