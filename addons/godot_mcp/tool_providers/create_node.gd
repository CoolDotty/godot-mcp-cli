@tool
## Tool provider for "create_node" — Create a new node in the scene tree.
class_name ToolProviderCreateNode
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"create_node",
		"Create a new node in the scene tree.",
		{
			"type": "object",
			"properties": {
				"parent_path": {
					"type": "string",
					"description": "Path to the parent node (default: root)",
				},
				"node_type": {
					"type": "string",
					"description": "Node class name (e.g. Node2D, Sprite2D)",
				},
				"node_name": {
					"type": "string",
					"description": "Name for the new node",
				},
			},
			"required": ["node_type", "node_name"],
		},
		"create_node",
	)
