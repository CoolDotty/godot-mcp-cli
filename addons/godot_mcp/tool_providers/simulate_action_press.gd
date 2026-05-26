@tool
## Tool provider for "simulate_action_press" — Press an input action in the running project.
class_name ToolProviderSimulateActionPress
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"simulate_action_press",
		"Press an input action in the running project.",
		{
			"type": "object",
			"properties": {
				"action": {
					"type": "string",
					"description": "Input action name (e.g. ui_accept, move_left)",
				},
				"strength": {
					"type": "number",
					"description": "Action strength between 0.0 and 1.0 (default: 1.0)",
				},
			},
			"required": ["action"],
		},
		"simulate_action_press",
	)
