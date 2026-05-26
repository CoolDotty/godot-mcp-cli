# Godot MCP

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A pure Godot addon that exposes Godot Engine to AI assistants via the **Model Context Protocol (MCP)** over **HTTP + Server-Sent Events (SSE)**. No Node.js required.

Includes an integrated HTTP server for the MCP transport layer.

## Features

### Core Functionality
- **Full Godot Project Access**: AI assistants can access and modify scripts, scenes, nodes, and project resources
- **Flexible Scene Inspection**: Retrieve hierarchy with `get_editor_scene_structure`, including properties and scripts
- **Runtime Scene Inspection**: Snapshot live scene tree from running games with `get_runtime_scene_structure`
- **Runtime Expression Evaluation**: Execute expressions in live games using `evaluate_runtime`
- **Dynamic Script Access**: Read scripts via resource URIs and metadata
- **Script Editing Tools**: Create, edit, or template scripts directly through MCP commands
- **Node Management**: Create, remove, list, and inspect nodes with automatic path normalization
- **Node Warning Inspection**: Inspect current scene tree configuration warnings with `get_node_warnings`
- **Scene Operations**: Create, delete, open, and save scenes; query project info and current scene state
- **Asset Management**: List assets by type and enumerate project files
- **Project Reload**: Restart editor, reload scenes, or rescan filesystem for external changes
- **GDScript Formatting**: Install, check, and run the GDQuest GDScript Formatter — supports glob patterns (`*`, `**/*.gd`) for batch formatting
- **Debug Output Access**: Snapshot logs with `get_debug_output` or tail them live via streaming
- **Stack Trace Capture**: Pull the editor's Stack Trace text or grab structured frames
- **Editor Automation**: Execute GDScript in editor context via `execute_editor_script`

### Debugger Integration
- **Breakpoint Management**: Set, remove, and list breakpoints across scripts
- **Execution Control**: Pause, resume, and step through code
- **Real-time Events**: Live notifications for breakpoint hits and execution changes
- **Call Stack Inspection**: Access current call stack and frame information
- **Session Management**: Support for multiple debug sessions
- **Runtime Debugging**: Full integration with Godot's debugging system

### Input Simulation
- **Action Simulation**: Press, release, and tap input actions
- **Mouse Control**: Click, move, and drag operations
- **Keyboard Input**: Simulate key presses with modifier support
- **Input Sequences**: Execute complex input combos with precise timing
- **Action Discovery**: List all available input actions in the project

## Installation

### 1. Install the Addon to Your Godot Project

Clone or copy the `addons/godot_mcp` folder to your Godot project's `addons` directory:

```bash
git clone https://github.com/CoolDotty/godot-mcp-cli.git
# Copy addons/godot_mcp to your project's addons/
```

### 2. Enable the Plugin in Godot

1. Open your project in Godot
2. Go to Project > Project Settings > Plugins
3. Enable the "Godot MCP" plugin

The MCP server starts automatically on port 9080.

## Using the MCP Protocol

Configure your MCP client (e.g., Claude Desktop, Continue.dev) to connect via SSE:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

The server uses **HTTP+SSE** transport on the same `/mcp` endpoint:
- `GET  /mcp` with `Accept: text/event-stream` — Establish SSE connection
- `POST /mcp` — Send JSON-RPC requests (tools/call, etc.)

### Quick Test

```bash
# Health check
curl http://localhost:9080/
# → {"status":"ok","server":"godot-mcp","transport":"sse+http"}

# List tools
curl -X POST http://localhost:9080/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Architecture

```
AI Assistant (MCP Client)
       |
       | HTTP+SSE (port 9080)
       v
Godot Addon (EditorPlugin)
  ├── HttpServer
  ├── MCPRouter → MCPServerCore → CommandHandler
  ├── MCPSse (SSE streaming)
  └── Command Processors (node, script, scene, etc.)
       |
       v
Godot Engine APIs
```

No external dependencies, no build step, no Node.js. Purely GDScript.

## Documentation

- [Installation Guide](docs/installation-guide.md)
- [Command Reference](docs/command-reference.md)
- [Architecture](docs/architecture.md)
- [Tool Prompt Guide](docs/tool-prompt-guide.md)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request to the [GitHub repository](https://github.com/CoolDotty/godot-mcp-cli).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
