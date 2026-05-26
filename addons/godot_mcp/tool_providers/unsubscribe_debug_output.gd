@tool
## Tool provider for "unsubscribe_debug_output" — Stop live streaming of debug output for this client.
class_name ToolProviderUnsubscribeDebugOutput
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"unsubscribe_debug_output",
		"Stop live streaming of debug output for this client.",
		{
			"type": "object",
			"properties": { },
		},
		"unsubscribe_debug_output",
	)
