@tool
## Tool provider for "debugger_get_breakpoints" — List all breakpoints currently set.
class_name ToolProviderDebuggerGetBreakpoints
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_get_breakpoints",
		"List all breakpoints currently set.",
		{
			"type": "object",
			"properties": { },
		},
		"debugger_get_breakpoints",
	)
