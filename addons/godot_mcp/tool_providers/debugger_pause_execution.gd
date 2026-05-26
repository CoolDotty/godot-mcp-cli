@tool
## Tool provider for "debugger_pause_execution" — Pause the running project.
class_name ToolProviderDebuggerPauseExecution
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_pause_execution",
		"Pause the running project.",
		{
			"type": "object",
			"properties": { },
		},
		"debugger_pause_execution",
	)
