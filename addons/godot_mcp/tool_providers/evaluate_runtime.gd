@tool
## Tool provider for "evaluate_runtime" — Evaluate a GDScript expression on the running game via the debugger.
class_name ToolProviderEvaluateRuntime
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"evaluate_runtime",
		"Evaluate a GDScript expression on the running game via the debugger.",
		{
			"type": "object",
			"properties": {
				"expression": {
					"type": "string",
					"description": "GDScript expression to evaluate (e.g. player.health)",
				},
				"context_path": {
					"type": "string",
					"description": "Optional node path to use as evaluation context",
				},
				"capture_prints": {
					"type": "boolean",
					"description": "Capture print() output during evaluation (default: true)",
				},
				"timeout_ms": {
					"type": "number",
					"description": "Timeout in milliseconds (default: 2000)",
				},
			},
			"required": ["expression"],
		},
		"evaluate_runtime",
	)
