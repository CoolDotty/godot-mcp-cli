@tool
## Tool provider for "simulate_mouse_move" — Move the mouse cursor in the running project.
class_name ToolProviderSimulateMouseMove
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"simulate_mouse_move",
		"Move the mouse cursor in the running project.",
		{
			"type": "object",
			"properties": {
				"x": {
					"type": "number",
					"description": "Target X position",
				},
				"y": {
					"type": "number",
					"description": "Target Y position",
				},
			},
			"required": ["x", "y"],
		},
		"simulate_mouse_move",
	)
