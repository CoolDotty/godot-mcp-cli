@tool
## Tool provider for "list_project_resources" — List project resources categorized by type (scenes, scripts, textures, audio, mo...
class_name ToolProviderListProjectResources
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"list_project_resources",
		"List project resources categorized by type (scenes, scripts, textures, audio, models, resources).",
		{
			"type": "object",
			"properties": { },
		},
		"list_project_resources",
	)
