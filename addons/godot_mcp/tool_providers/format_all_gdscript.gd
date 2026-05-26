@tool
## Tool provider for "format_all_gdscript" — Format every .gd file in the project. Convenience wrapper that calls format_gdsc...
class_name ToolProviderFormatAllGdscript
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"format_all_gdscript",
		"Format every .gd file in the project. Convenience wrapper that calls format_gdscript with a '*' pattern.",
		{
			"type": "object",
			"properties": {
				"use_spaces": {
					"type": "boolean",
					"description": "Use spaces instead of tabs",
				},
				"indent_size": {
					"type": "number",
					"description": "Indent size when using spaces (default: 4)",
				},
				"reorder_code": {
					"type": "boolean",
					"description": "Reorder code to follow the GDScript style guide",
				},
				"safe_mode": {
					"type": "boolean",
					"description": "Skip formatting if it would change code meaning (default: true)",
				},
				"write_back": {
					"type": "boolean",
					"description": "Write formatted code back to the file (default: true). Set to false for a dry run.",
				},
			},
		},
		"format_all_gdscript",
	)
