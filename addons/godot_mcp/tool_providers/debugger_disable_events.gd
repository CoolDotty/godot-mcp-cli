@tool
## Tool provider for "debugger_disable_events" — Disable debugger event notifications for this client.
class_name ToolProviderDebuggerDisableEvents
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_disable_events",
		"Disable debugger event notifications for this client.",
		{
			"type": "object",
			"properties": { },
		},
		"debugger_disable_events",
	)
