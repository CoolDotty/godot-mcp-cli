@tool
## Tool provider for "save_scene" — Save the current scene.
class_name ToolProviderSaveScene
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"save_scene",
		"Save the current scene.",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Optional path to save to",
				},
			},
		},
		"save_scene",
	)
