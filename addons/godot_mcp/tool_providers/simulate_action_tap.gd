@tool
## Tool provider for "simulate_action_tap" — Tap an input action (press + release) in the running project.
class_name ToolProviderSimulateActionTap
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"simulate_action_tap",
		"Tap an input action (press + release) in the running project.",
		{
			"type": "object",
			"properties": {
				"action": {
					"type": "string",
					"description": "Input action name to tap",
				},
				"duration_ms": {
					"type": "number",
					"description": "How long to hold before releasing (default: 100)",
				},
			},
			"required": ["action"],
		},
		"simulate_action_tap",
	)
