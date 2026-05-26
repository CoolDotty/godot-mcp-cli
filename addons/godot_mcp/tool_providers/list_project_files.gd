@tool
## Tool provider for "list_project_files" — List project files, optionally filtered by extension.
class_name ToolProviderListProjectFiles
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"list_project_files",
		"List project files, optionally filtered by extension.",
		{
			"type": "object",
			"properties": {
				"extensions": {
					"type": "array",
					"items": {
						"type": "string",
					},
					"description": "File extensions to filter by (e.g. ['.gd', '.tscn'])",
				},
			},
		},
		"list_project_files",
	)
