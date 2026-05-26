@tool
## Tool provider for "debugger_get_call_stack" — Get the current call stack from a paused debugger session.
class_name ToolProviderDebuggerGetCallStack
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_get_call_stack",
		"Get the current call stack from a paused debugger session.",
		{
			"type": "object",
			"properties": {
				"session_id": {
					"type": "number",
					"description": "Optional debugger session ID",
				},
			},
		},
		"debugger_get_call_stack",
	)
