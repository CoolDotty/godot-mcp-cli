@tool
## Tool provider for "get_current_script" — Get the currently edited script in the script editor.
class_name ToolProviderGetCurrentScript
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_current_script",
		"Get the currently edited script in the script editor.",
		{
			"type": "object",
			"properties": { },
		},
		"get_current_script",
	)
