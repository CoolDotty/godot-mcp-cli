@tool
## Tool provider for "run_specific_scene" — Run a specific scene by path.
class_name ToolProviderRunSpecificScene
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"run_specific_scene",
		"Run a specific scene by path.",
		{
			"type": "object",
			"properties": {
				"scene_path": {
					"type": "string",
					"description": "Path to the scene to run",
				},
			},
			"required": ["scene_path"],
		},
		"run_specific_scene",
	)
