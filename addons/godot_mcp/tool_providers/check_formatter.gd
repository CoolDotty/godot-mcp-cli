@tool
## Tool provider for "check_formatter" — Check if the GDQuest GDScript Formatter addon and binary are installed.
class_name ToolProviderCheckFormatter
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"check_formatter",
		"Check if the GDQuest GDScript Formatter addon and binary are installed.",
		{
			"type": "object",
			"properties": { },
		},
		"check_formatter",
	)
