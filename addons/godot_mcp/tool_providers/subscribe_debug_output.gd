@tool
## Tool provider for "subscribe_debug_output" — Start live streaming of debug output to this client.
class_name ToolProviderSubscribeDebugOutput
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"subscribe_debug_output",
		"Start live streaming of debug output to this client.",
		{
			"type": "object",
			"properties": { },
		},
		"subscribe_debug_output",
	)
