@tool
## Tool provider for "get_editor_scene_structure" — Get detailed editor scene tree with properties and scripts.
class_name ToolProviderGetEditorSceneStructure
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_editor_scene_structure",
		"Get detailed editor scene tree with properties and scripts.",
		{
			"type": "object",
			"properties": {
				"include_properties": {
					"type": "boolean",
					"description": "Include node properties",
				},
				"include_scripts": {
					"type": "boolean",
					"description": "Include script info",
				},
				"max_depth": {
					"type": "number",
					"description": "Maximum depth to traverse",
				},
			},
		},
		"get_editor_scene_structure",
	)
