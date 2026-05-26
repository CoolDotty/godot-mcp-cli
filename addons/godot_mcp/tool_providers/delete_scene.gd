@tool
## Tool provider for "delete_scene" — Delete a scene file from the project. Cannot delete the currently open scene.
class_name ToolProviderDeleteScene
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"delete_scene",
		"Delete a scene file from the project. Cannot delete the currently open scene.",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Path to the scene file to delete",
				},
			},
			"required": ["path"],
		},
		"delete_scene",
	)
