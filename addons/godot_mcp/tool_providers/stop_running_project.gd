@tool
## Tool provider for "stop_running_project" — Stop the currently running project.
class_name ToolProviderStopRunningProject
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"stop_running_project",
		"Stop the currently running project.",
		{
			"type": "object",
			"properties": { },
		},
		"stop_running_project",
	)
