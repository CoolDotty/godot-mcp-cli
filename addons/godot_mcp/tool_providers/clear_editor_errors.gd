@tool
## Tool provider for "clear_editor_errors" — Clear the Errors tab in the editor.
class_name ToolProviderClearEditorErrors
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"clear_editor_errors",
		"Clear the Errors tab in the editor.",
		{
			"type": "object",
			"properties": { },
		},
		"clear_editor_errors",
	)
