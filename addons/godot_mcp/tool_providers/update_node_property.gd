@tool
## Tool provider for "update_node_property" — Update a property on a node.
class_name ToolProviderUpdateNodeProperty
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"update_node_property",
		"Update a property on a node.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node",
				},
				"property": {
					"type": "string",
					"description": "Name of the property to update",
				},
				"value": {
					"description": "New value for the property",
				},
			},
			"required": ["node_path", "property", "value"],
		},
		"update_node_property",
	)
