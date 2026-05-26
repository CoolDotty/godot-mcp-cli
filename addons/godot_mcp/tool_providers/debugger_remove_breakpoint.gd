@tool
## Tool provider for "debugger_remove_breakpoint" — Remove a breakpoint from a script at the specified line.
class_name ToolProviderDebuggerRemoveBreakpoint
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_remove_breakpoint",
		"Remove a breakpoint from a script at the specified line.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path to the script file",
				},
				"line": {
					"type": "number",
					"description": "Line number of the breakpoint to remove",
				},
			},
			"required": ["script_path", "line"],
		},
		"debugger_remove_breakpoint",
	)
