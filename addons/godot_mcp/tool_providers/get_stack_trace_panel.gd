@tool
## Tool provider for "get_stack_trace_panel" — Capture the Stack Trace panel text plus parsed frames from the debugger.
class_name ToolProviderGetStackTracePanel
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_stack_trace_panel",
		"Capture the Stack Trace panel text plus parsed frames from the debugger.",
		{
			"type": "object",
			"properties": {
				"session_id": {
					"type": "number",
					"description": "Optional debugger session ID",
				},
			},
		},
		"get_stack_trace_panel",
	)
