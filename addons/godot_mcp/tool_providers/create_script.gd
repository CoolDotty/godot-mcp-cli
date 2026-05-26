@tool
## Tool provider for "create_script" — Create a new script file and optionally attach it to a node.
class_name ToolProviderCreateScript
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"create_script",
		"Create a new script file and optionally attach it to a node.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path for the new script (e.g. res://scripts/player.gd)",
				},
				"content": {
					"type": "string",
					"description": "Script source code content",
				},
				"node_path": {
					"type": "string",
					"description": "Optional node path to attach the script to",
				},
			},
			"required": ["script_path", "content"],
		},
		"create_script",
	)
