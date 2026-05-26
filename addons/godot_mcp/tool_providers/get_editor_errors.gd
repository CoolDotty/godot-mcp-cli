@tool
## Tool provider for "get_editor_errors" — Read the Errors tab of the bottom panel in the editor.
class_name ToolProviderGetEditorErrors
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_editor_errors",
		"Read the Errors tab of the bottom panel in the editor.",
		{
			"type": "object",
			"properties": { },
		},
		"get_editor_errors",
	)
