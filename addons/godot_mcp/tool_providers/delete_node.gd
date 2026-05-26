@tool
## Tool provider for "delete_node" — Delete a node from the scene tree.
class_name ToolProviderDeleteNode
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"delete_node",
		"Delete a node from the scene tree.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node to delete",
				},
			},
			"required": ["node_path"],
		},
		"delete_node",
	)
