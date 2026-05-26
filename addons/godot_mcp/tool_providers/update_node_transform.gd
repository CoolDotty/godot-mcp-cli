@tool
## Tool provider for "update_node_transform" — Adjust a node's transform (position, rotation, scale) in the editor.
class_name ToolProviderUpdateNodeTransform
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"update_node_transform",
		"Adjust a node's transform (position, rotation, scale) in the editor.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node in the current scene",
				},
				"position": {
					"type": "array",
					"items": {
						"type": "number",
					},
					"description": "New position as [x, y]",
				},
				"rotation": {
					"type": "number",
					"description": "New rotation in radians",
				},
				"scale": {
					"type": "array",
					"items": {
						"type": "number",
					},
					"description": "New scale as [x, y]",
				},
			},
			"required": ["node_path"],
		},
		"update_node_transform",
	)
