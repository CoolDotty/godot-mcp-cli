@tool
## Tool provider for "open_scene" — Open a scene file in the editor.
class_name ToolProviderOpenScene
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"open_scene",
		"Open a scene file in the editor.",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Path to the .tscn file",
				},
			},
			"required": ["path"],
		},
		"open_scene",
	)
