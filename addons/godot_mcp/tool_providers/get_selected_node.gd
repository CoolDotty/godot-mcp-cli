@tool
## Tool provider for "get_selected_node" — Get the currently selected node in the editor with its properties.
class_name ToolProviderGetSelectedNode
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_selected_node",
		"Get the currently selected node in the editor with its properties.",
		{
			"type": "object",
			"properties": { },
		},
		"get_selected_node",
	)
