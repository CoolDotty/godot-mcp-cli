@tool
## Tool provider for "install_formatter_addon" — Download the GDQuest GDScript Formatter addon files into the project. Requires e...
class_name ToolProviderInstallFormatterAddon
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"install_formatter_addon",
		"Download the GDQuest GDScript Formatter addon files into the project. Requires enabling the plugin in Project → Project Settings → Plugins afterwards.",
		{
			"type": "object",
			"properties": { },
		},
		"install_formatter_addon",
	)
