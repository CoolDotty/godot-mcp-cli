@tool
## Tool provider for "simulate_action_release" — Release an input action in the running project.
class_name ToolProviderSimulateActionRelease
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"simulate_action_release",
		"Release an input action in the running project.",
		{
			"type": "object",
			"properties": {
				"action": {
					"type": "string",
					"description": "Input action name to release",
				},
			},
			"required": ["action"],
		},
		"simulate_action_release",
	)
