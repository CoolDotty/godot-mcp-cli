@tool
## Tool provider for "create_scene" — Create a new scene file.
class_name ToolProviderCreateScene
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"create_scene",
		"Create a new scene file.",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Path for the new scene file (e.g. res://scenes/level.tscn)",
				},
				"root_node_type": {
					"type": "string",
					"description": "Root node class name (e.g. Node2D, Node3D, Control). Default: Node",
				},
			},
			"required": ["path"],
		},
		"create_scene",
	)
