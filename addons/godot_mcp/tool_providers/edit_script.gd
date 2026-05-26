@tool
## Tool provider for "edit_script" — Edit a script's source code by overwriting the file content.
class_name ToolProviderEditScript
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"edit_script",
		"Edit a script's source code by overwriting the file content.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path to the script file to edit",
				},
				"content": {
					"type": "string",
					"description": "New source code content for the script",
				},
			},
			"required": ["script_path", "content"],
		},
		"edit_script",
	)
