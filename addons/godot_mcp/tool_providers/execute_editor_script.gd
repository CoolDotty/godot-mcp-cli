@tool
## Tool provider for "execute_editor_script" — Run a GDScript code snippet in the editor context.
class_name ToolProviderExecuteEditorScript
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"execute_editor_script",
		"Run a GDScript code snippet in the editor context.",
		{
			"type": "object",
			"properties": {
				"code": {
					"type": "string",
					"description": "GDScript code to execute",
				},
			},
			"required": ["code"],
		},
		"execute_editor_script",
	)
