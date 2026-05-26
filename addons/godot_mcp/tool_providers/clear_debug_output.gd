@tool
## Tool provider for "clear_debug_output" — Clear the Output panel in the editor.
class_name ToolProviderClearDebugOutput
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"clear_debug_output",
		"Clear the Output panel in the editor.",
		{
			"type": "object",
			"properties": { },
		},
		"clear_debug_output",
	)
