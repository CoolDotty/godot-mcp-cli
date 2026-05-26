@tool
## Tool provider for "simulate_key_press" — Simulate a keyboard key press in the running project.
class_name ToolProviderSimulateKeyPress
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"simulate_key_press",
		"Simulate a keyboard key press in the running project.",
		{
			"type": "object",
			"properties": {
				"key": {
					"type": "string",
					"description": "Key name to press (e.g. A, Space, Escape)",
				},
				"duration_ms": {
					"type": "number",
					"description": "How long to hold the key (default: 100)",
				},
				"modifiers": {
					"type": "object",
					"description": "Modifier keys (e.g. {ctrl: true, shift: false})",
				},
			},
			"required": ["key"],
		},
		"simulate_key_press",
	)
