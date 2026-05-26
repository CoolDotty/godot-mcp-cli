@tool
## Tool provider for "debugger_set_breakpoint" — Set a breakpoint in a script at the specified line.
class_name ToolProviderDebuggerSetBreakpoint
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_set_breakpoint",
		"Set a breakpoint in a script at the specified line.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path to the script file",
				},
				"line": {
					"type": "number",
					"description": "Line number for the breakpoint",
				},
			},
			"required": ["script_path", "line"],
		},
		"debugger_set_breakpoint",
	)
