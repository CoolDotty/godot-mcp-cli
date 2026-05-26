@tool
## Tool provider for "get_runtime_scene_structure" — Snapshot the live scene tree from a running game via the debugger.
class_name ToolProviderGetRuntimeSceneStructure
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_runtime_scene_structure",
		"Snapshot the live scene tree from a running game via the debugger.",
		{
			"type": "object",
			"properties": {
				"include_properties": {
					"type": "boolean",
					"description": "Include node properties in the snapshot",
				},
				"include_scripts": {
					"type": "boolean",
					"description": "Include script info in the snapshot",
				},
				"max_depth": {
					"type": "number",
					"description": "Maximum depth to traverse",
				},
				"timeout_ms": {
					"type": "number",
					"description": "Timeout in milliseconds (default: 2000)",
				},
			},
		},
		"get_runtime_scene_structure",
	)
