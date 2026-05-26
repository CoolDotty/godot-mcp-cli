@tool
## Tool provider for "debugger_step_into" — Step into a function call in the debugger.
class_name ToolProviderDebuggerStepInto
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_step_into",
		"Step into a function call in the debugger.",
		{
			"type": "object",
			"properties": { },
		},
		"debugger_step_into",
	)
