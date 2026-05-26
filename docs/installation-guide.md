# Godot MCP Installation Guide

## Prerequisites

- Godot 4.x (any release supporting GDScript tool mode)
- No Node.js required — the addon is pure GDScript

## Installation

The MCP addon is a self-contained Godot plugin. Simply copy it to your project.

### Via Git Clone

```bash
git clone https://github.com/CoolDotty/godot-mcp-cli.git
```

Copy `addons/godot_mcp/` from the cloned repo into your Godot project's `addons/` directory.

### Manual Copy

If you already have the source, copy the `addons/godot_mcp/` folder into your project's `addons/` directory.

Your project structure should look like:

```
your-project/
├── project.godot
├── addons/
│   └── godot_mcp/
│       ├── plugin.cfg
│       ├── mcp_server.gd
│       ├── mcp_types.gd
│       ├── mcp_sse.gd
│       ├── mcp_server_core.gd
│       ├── mcp_router.gd
│       ├── command_handler.gd
│       ├── commands/*.gd        # Node, script, scene, project, editor, debugger, input
│       ├── mcp_enhanced_commands.gd
│       ├── mcp_asset_commands.gd
│       ├── mcp_script_resource_commands.gd
│       ├── mcp_debugger_bridge.gd
│       ├── mcp_runtime_debugger_bridge.gd
│       ├── mcp_input_handler.gd
│       ├── mcp_debug_output_publisher.gd
│       ├── runtime_debugger.gd
│       ├── http_server.gd          # HTTP server (vendored from godottpd)
│       ├── http_router.gd
│       ├── http_request.gd
│       ├── http_response.gd
│       ├── http_file_router.gd
│       ├── ui/mcp_panel.tscn
│       ├── ui/mcp_panel.gd
│       └── utils/
│           ├── editor_utils.gd
│           ├── node_utils.gd
│           ├── resource_utils.gd
│           └── script_utils.gd
└── (your game files)
```

## Enable Plugin

1. Open your project in Godot
2. Go to **Project > Project Settings > Plugins**
3. Find **"Godot MCP"** in the list
4. Click the checkbox to enable it

The MCP server starts automatically on port 9080 when the editor loads.

## Verify Installation

You can verify the server is running with a simple curl command:

```bash
# Health check
curl http://localhost:9080/
# Expected: {"status":"ok","server":"godot-mcp","transport":"sse+http"}

# List available MCP tools
curl -X POST http://localhost:9080/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## MCP Client Configuration

Add to your MCP client config (e.g., Claude Desktop, Continue.dev):

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

The server uses SSE (Server-Sent Events) transport on the same `/mcp` endpoint:
- `GET /mcp` with `Accept: text/event-stream` — Establish SSE connection
- `POST /mcp` — Send JSON-RPC requests (tool calls, resource reads)

## Port and Binding

The server listens on port **9080** bound to **127.0.0.1** (localhost only). You can change this in two ways:

### Via the MCP Panel
1. Open the **MCP Server** tab at the bottom of the Godot editor
2. Adjust the port number in the panel
3. Click **Stop Server** then **Start Server** to apply

### Via Script (for programmatic changes)
The server reads from `MCPTypes.DEFAULT_PORT` and `MCPTypes.DEFAULT_BIND` in `mcp_types.gd`.

## Testing the Debugger

This repository includes a test project for verifying debugger functionality.

### Quick Test

```bash
# 1. Open the test scene
# 2. Run the project (F5)
# 3. Use MCP tools from your AI assistant:

# Set a breakpoint
tools/call → debugger_set_breakpoint
  script_path: res://test_debugger.gd
  line: 42

# Check state
tools/call → debugger_get_current_state

# Resume execution
tools/call → debugger_resume_execution
```

### Test Scene Controls

When running `test_main_scene.tscn`:
- **SPACE** - Trigger manual pause point
- **R** - Reset counter
- **T** - Call test function

The scene auto-triggers breakpoints every ~60 frames.

### Debugger Requirements

- Run with **F5** (Debug) in Godot Editor, not F6
- MCP server must be running (auto-starts with plugin)
- Only one client can receive debugger events at a time

## Troubleshooting

### Connection Issues

- Verify the MCP server is running (check the **MCP Server** panel at the bottom of the editor)
- Default port is 9080 — confirm nothing else is using it
- Check firewall isn't blocking localhost connections

### Debugger Issues

| Problem | Solution |
|---------|----------|
| "No active debugger session" | Run project with F5, not F6 |
| "Failed to set breakpoint" | Check script path exists (`res://...`) |
| Breakpoint not hitting | Ensure code execution reaches that line |
| No events received | Call `debugger_enable_events` first |

### Command Errors

- Check Godot console for errors (Output panel)
- Verify paths use `res://` format
- Ensure a scene is loaded
