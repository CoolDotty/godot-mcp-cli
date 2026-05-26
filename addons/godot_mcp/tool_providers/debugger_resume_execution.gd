@tool
## Tool provider for "debugger_resume_execution" — Resume a paused project.
class_name ToolProviderDebuggerResumeExecution
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"debugger_resume_execution",
		"Resume a paused project.",
		{
			"type": "object",
			"properties": { },
		},
		"debugger_resume_execution",
	)
