@tool
## Tool provider for "get_project_structure" — Get a summary of the project file structure (directories and file counts by exte...
class_name ToolProviderGetProjectStructure
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_project_structure",
		"Get a summary of the project file structure (directories and file counts by extension).",
		{
			"type": "object",
			"properties": { },
		},
		"get_project_structure",
	)
