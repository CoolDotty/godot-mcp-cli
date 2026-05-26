@tool
## Tool provider for "get_editor_state" — Get current editor state information.
class_name ToolProviderGetEditorState
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_editor_state",
		"Get current editor state information.",
		{
			"type": "object",
			"properties": { },
		},
		"get_editor_state",
	)
