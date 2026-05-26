@tool
## Tool provider for "create_resource" — Create a new resource file (e.g. Material, Shader, etc.).
class_name ToolProviderCreateResource
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"create_resource",
		"Create a new resource file (e.g. Material, Shader, etc.).",
		{
			"type": "object",
			"properties": {
				"resource_type": {
					"type": "string",
					"description": "Resource class name (e.g. StandardMaterial3D, ShaderMaterial)",
				},
				"resource_path": {
					"type": "string",
					"description": "Path for the new resource file",
				},
				"properties": {
					"type": "object",
					"description": "Optional initial properties",
				},
			},
			"required": ["resource_type", "resource_path"],
		},
		"create_resource",
	)
