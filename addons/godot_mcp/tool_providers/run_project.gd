@tool
## Tool provider for "run_project" — Launch the project's main scene (same as F5).
class_name ToolProviderRunProject
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"run_project",
		"Launch the project's main scene (same as F5).",
		{
			"type": "object",
			"properties": { },
		},
		"run_project",
	)
