@tool
## Tool provider for "run_current_scene" — Play the current scene in the editor (same as F6).
class_name ToolProviderRunCurrentScene
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"run_current_scene",
		"Play the current scene in the editor (same as F6).",
		{
			"type": "object",
			"properties": { },
		},
		"run_current_scene",
	)
