@tool
## Tool provider for "simulate_drag" — Click and drag the mouse from one position to another.
class_name ToolProviderSimulateDrag
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"simulate_drag",
		"Click and drag the mouse from one position to another.",
		{
			"type": "object",
			"properties": {
				"start_x": {
					"type": "number",
					"description": "Starting X position",
				},
				"start_y": {
					"type": "number",
					"description": "Starting Y position",
				},
				"end_x": {
					"type": "number",
					"description": "Ending X position",
				},
				"end_y": {
					"type": "number",
					"description": "Ending Y position",
				},
				"duration_ms": {
					"type": "number",
					"description": "Duration of the drag in milliseconds (default: 200)",
				},
				"steps": {
					"type": "number",
					"description": "Number of intermediate steps (default: 10)",
				},
				"button": {
					"type": "string",
					"description": "Mouse button: left, right, or middle (default: left)",
				},
			},
			"required": ["start_x", "start_y", "end_x", "end_y"],
		},
		"simulate_drag",
	)
