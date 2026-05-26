@tool
## Tool provider for "debugger_enable_events" — Enable debugger event notifications for this client (breakpoint hits, pauses, et...
class_name ToolProviderDebuggerEnableEvents
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_enable_events",
		"Enable debugger event notifications for this client (breakpoint hits, pauses, etc.).",
		{
			"type": "object",
			"properties": { },
		},
		"debugger_enable_events",
	)
