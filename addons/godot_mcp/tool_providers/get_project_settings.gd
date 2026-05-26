@tool
## Tool provider for "get_project_settings" — Get project settings.
class_name ToolProviderGetProjectSettings
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_project_settings",
		"Get project settings.",
		{
			"type": "object",
			"properties": { },
		},
		"get_project_settings",
	)
