@tool
## Tool provider for "simulate_mouse_click" — Simulate a mouse click in the running project.
class_name ToolProviderSimulateMouseClick
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"simulate_mouse_click",
		"Simulate a mouse click in the running project.",
		{
			"type": "object",
			"properties": {
				"x": {
					"type": "number",
					"description": "X position for the click",
				},
				"y": {
					"type": "number",
					"description": "Y position for the click",
				},
				"button": {
					"type": "string",
					"description": "Mouse button: left, right, or middle (default: left)",
				},
				"double_click": {
					"type": "boolean",
					"description": "Perform a double-click (default: false)",
				},
			},
		},
		"simulate_mouse_click",
	)
