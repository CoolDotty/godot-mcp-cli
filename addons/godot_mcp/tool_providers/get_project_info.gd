@tool
## Tool provider for "get_project_info" — Get project information.
class_name ToolProviderGetProjectInfo
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_project_info",
		"Get project information.",
		{
			"type": "object",
			"properties": { },
		},
		"get_project_info",
	)
