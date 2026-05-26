@tool
## Tool provider for "reload_project" — Restart the Godot editor (reload the entire project).
class_name ToolProviderReloadProject
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"reload_project",
		"Restart the Godot editor (reload the entire project).",
		{
			"type": "object",
			"properties": {
				"save": {
					"type": "boolean",
					"description": "Save before restarting (default: true)",
				},
			},
		},
		"reload_project",
	)
