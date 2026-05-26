@tool
## Tool provider for "rescan_filesystem" — Rescan the project filesystem and reimport changed assets. Use when files have b...
class_name ToolProviderRescanFilesystem
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"rescan_filesystem",
		"Rescan the project filesystem and reimport changed assets. Use when files have been modified externally (e.g. by AI writing scripts, textures) and the editor needs to pick up the changes.",
		{
			"type": "object",
			"properties": {
				"paths": {
					"type": "array",
					"items": {
						"type": "string",
					},
					"description": "Optional list of specific file paths to reimport (e.g. ['res://icon.svg', 'res://scenes/main.tscn'])",
				},
				"sources": {
					"type": "boolean",
					"description": "Also re-scan script sources for import changes (default: true)",
				},
			},
		},
		"rescan_filesystem",
	)
