@tool
## Tool provider for "get_script_metadata" — Get metadata about a script (class_name, extends, methods, signals).
class_name ToolProviderGetScriptMetadata
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_script_metadata",
		"Get metadata about a script (class_name, extends, methods, signals).",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Path to the script file",
				},
			},
			"required": ["path"],
		},
		"get_script_metadata",
	)
