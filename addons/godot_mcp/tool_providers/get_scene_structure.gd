@tool
## Tool provider for "get_scene_structure" — Get the full scene tree structure with properties.
class_name ToolProviderGetSceneStructure
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_scene_structure",
		"Get the full scene tree structure with properties.",
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
		"get_scene_structure",
	)
