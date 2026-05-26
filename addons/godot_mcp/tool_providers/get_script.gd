@tool
## Tool provider for "get_script" — Get the source code of a script attached to a node or resource.
class_name ToolProviderGetScript
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_script",
		"Get the source code of a script attached to a node or resource.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path to the script file",
				},
				"node_path": {
					"type": "string",
					"description": "Path to the node with a script attached",
				},
			},
			"oneOf": [
				{
					"required": ["script_path"],
				},
				{
					"required": ["node_path"],
				},
			],
		},
		"get_script",
	)
