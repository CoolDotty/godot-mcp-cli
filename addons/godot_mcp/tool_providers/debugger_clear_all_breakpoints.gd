@tool
## Tool provider for "debugger_clear_all_breakpoints" — Clear all breakpoints.
class_name ToolProviderDebuggerClearAllBreakpoints
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_clear_all_breakpoints",
		"Clear all breakpoints.",
		{
			"type": "object",
			"properties": { },
		},
		"debugger_clear_all_breakpoints",
	)
