@tool
## Tool provider for "get_current_scene" — Get information about the currently open scene.
class_name ToolProviderGetCurrentScene
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_current_scene",
		"Get information about the currently open scene.",
		{
			"type": "object",
			"properties": { },
		},
		"get_current_scene",
	)
