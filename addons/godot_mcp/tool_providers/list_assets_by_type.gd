@tool
## Tool provider for "list_assets_by_type" — List project assets filtered by type (scripts, scenes, images, audio, fonts, mod...
class_name ToolProviderListAssetsByType
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"list_assets_by_type",
		"List project assets filtered by type (scripts, scenes, images, audio, fonts, models, shaders, resources, all).",
		{
			"type": "object",
			"properties": {
				"type": {
					"type": "string",
					"description": "Asset type filter: scripts, scenes, images, audio, fonts, models, shaders, resources, or all",
				},
			},
			"required": ["type"],
		},
		"list_assets_by_type",
	)
