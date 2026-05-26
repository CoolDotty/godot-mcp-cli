@tool
## Tool provider for "get_input_actions" — List all available input actions defined in the project's Input Map.
class_name ToolProviderGetInputActions
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_input_actions",
		"List all available input actions defined in the project's Input Map.",
		{
			"type": "object",
			"properties": { },
		},
		"get_input_actions",
	)
