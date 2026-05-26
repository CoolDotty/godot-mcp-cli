@tool
## Tool provider for "lint_gdscript" — Lint GDScript file(s) using the formatter's built-in linter. Checks for style an...
class_name ToolProviderLintGdscript
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"lint_gdscript",
		"Lint GDScript file(s) using the formatter's built-in linter. Checks for style and convention issues (17 rules). Accepts a single file path or a glob pattern (e.g. *, **/*.gd). Does NOT modify any files.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path to a .gd file or glob pattern (res:// or relative). Use * to lint all .gd files.",
				},
				"disabled_rules": {
					"type": "string",
					"description": "Comma-separated list of rule names to disable (e.g. 'class-name,signal-name')",
				},
				"max_line_length": {
					"type": "number",
					"description": "Maximum allowed line length (default: formatter default)",
				},
				"pretty": {
					"type": "boolean",
					"description": "Use human-readable output format",
				},
			},
			"required": ["script_path"],
		},
		"lint_gdscript",
	)
