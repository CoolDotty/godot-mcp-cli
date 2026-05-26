@tool
## Tool provider for "get_debug_output" — Get recent debug output.
class_name ToolProviderGetDebugOutput
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_debug_output",
		"Get recent debug output.",
		{
			"type": "object",
			"properties": {
				"max_lines": {
					"type": "number",
					"description": "Maximum number of lines to return (default 100)",
				},
			},
		},
		"get_debug_output",
	)
