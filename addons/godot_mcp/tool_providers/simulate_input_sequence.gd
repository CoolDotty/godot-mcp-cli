@tool
## Tool provider for "simulate_input_sequence" — Execute a timed sequence of input actions with precise timing.
class_name ToolProviderSimulateInputSequence
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"simulate_input_sequence",
		"Execute a timed sequence of input actions with precise timing.",
		{
			"type": "object",
			"properties": {
				"sequence": {
					"type": "array",
					"description": "Array of input step objects, each with a type and timing",
				},
			},
			"required": ["sequence"],
		},
		"simulate_input_sequence",
	)
