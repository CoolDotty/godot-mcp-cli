@tool
## Tool provider for "get_node_properties" — Get all properties of a node.
class_name ToolProviderGetNodeProperties
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_node_properties",
		"Get all properties of a node.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node",
				},
			},
			"required": ["node_path"],
		},
		"get_node_properties",
	)
