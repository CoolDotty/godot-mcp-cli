@tool
## Tool provider for "reload_scene" — Reload the current scene from disk, discarding unsaved changes.
class_name ToolProviderReloadScene
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"reload_scene",
		"Reload the current scene from disk, discarding unsaved changes.",
		{
			"type": "object",
			"properties": {
				"scene_path": {
					"type": "string",
					"description": "Optional specific scene path to reload (default: current scene)",
				},
			},
		},
		"reload_scene",
	)
