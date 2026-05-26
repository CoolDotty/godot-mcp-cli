@tool
## Tool provider for "install_formatter_binary" — Download and install the platform-specific GDScript Formatter binary from GitHub...
class_name ToolProviderInstallFormatterBinary
extends RefCounted

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"install_formatter_binary",
		"Download and install the platform-specific GDScript Formatter binary from GitHub releases. Stores it in the editor cache directory.",
		{
			"type": "object",
			"properties": { },
		},
		"install_formatter_binary",
	)
