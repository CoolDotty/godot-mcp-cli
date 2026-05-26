@tool
## Tool provider for "get_stack_frames_panel" — Return structured stack frames from the debugger bridge.
class_name ToolProviderGetStackFramesPanel
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_stack_frames_panel",
		"Return structured stack frames from the debugger bridge.",
		{
			"type": "object",
			"properties": {
				"session_id": {
					"type": "number",
					"description": "Optional debugger session ID",
				},
				"refresh": {
					"type": "boolean",
					"description": "Force refresh from the debugger (default: false)",
				},
			},
		},
		"get_stack_frames_panel",
	)
