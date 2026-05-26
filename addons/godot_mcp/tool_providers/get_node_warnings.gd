@tool
## Tool provider for "get_node_warnings" — Inspect the current scene for node configuration warnings.
class_name ToolProviderGetNodeWarnings
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_node_warnings",
		"Inspect the current scene for node configuration warnings.",
		{
			"type": "object",
			"properties": {
				"debug": {
					"type": "boolean",
					"description": "Include traversal debug stats",
				},
			},
		},
		"get_node_warnings",
	)
