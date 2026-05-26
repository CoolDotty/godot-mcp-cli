@tool
## Tool provider for "debugger_step_over" — Step over the current line in the debugger.
class_name ToolProviderDebuggerStepOver
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_step_over",
		"Step over the current line in the debugger.",
		{
			"type": "object",
			"properties": { },
		},
		"debugger_step_over",
	)
