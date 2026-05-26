@tool
## Tool provider for "format_gdscript" — Format GDScript file(s) using the installed formatter. Accepts a single file pat...
class_name ToolProviderFormatGdscript
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"format_gdscript",
		"Format GDScript file(s) using the installed formatter. Accepts a single file path or a glob pattern (e.g. *, **/*.gd, addons/*.gd). Supports indent style, safe mode, code reordering, and optional dry-run.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path to a .gd file or glob pattern (res:// or relative). Use * to format all .gd files.",
				},
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
			"required": ["script_path"],
		},
		"format_gdscript",
	)
