@tool
## Tool provider for "list_nodes" — List all nodes in the current scene.
class_name ToolProviderListNodes
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"list_nodes",
		"List all nodes in the current scene.",
		{
			"type": "object",
			"properties": {
				"parent_path": {
					"type": "string",
					"description": "Optional parent path to list children of",
				},
			},
		},
		"list_nodes",
	)
