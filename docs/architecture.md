# Godot MCP Architecture

## Overview

The Godot MCP addon exposes Godot Engine's editor and runtime features to AI assistants via the **Model Context Protocol (MCP)**. It uses **HTTP + Server-Sent Events (SSE)** as the transport layer — no Node.js or external processes required.

```
AI Assistant (MCP Client)
       |
       | SSE endpoint: GET /mcp (Accept: text/event-stream)
       | JSON-RPC:     POST /mcp
       v
Godot Editor (port 9080)
  ┌────────────────────────────────────────┐
  │  HttpServer (TCP/HTTP)                  │
  │    └── MCPRouter (extends HttpRouter)  │
  │          ├── GET /mcp (SSE) → MCPSse    │
  │          └── POST /mcp    → MCPServerCore │
  │                               │        │
  │  MCPServerCore (JSON-RPC 2.0) │        │
  │    ├── Tool Registry          │        │
  │    ├── Resource Registry     │        │
  │    └── ResponseBroker ───────┤        │
  │                              ▼        │
  │  CommandHandler                      │
  │    ├── NodeCommands                   │
  │    ├── ScriptCommands                 │
  │    ├── SceneCommands                  │
  │    ├── ProjectCommands                │
  │    ├── EditorCommands                 │
  │    ├── DebuggerCommands               │
  │    ├── InputCommands                  │
  │    └── (Enhanced/Asset/ScriptRes)     │
  │                              │        │
  │                              ▼        │
  │  Godot Engine APIs                    │
  │    ├── EditorInterface                │
  │    ├── EditorDebuggerPlugin           │
  │    ├── EngineDebugger / Runtime       │
  │    └── ProjectSettings / FileAccess   │
  └────────────────────────────────────────┘
```

## Components

### HTTP Server Layer

| File | Purpose |
|------|---------|
| `http_server.gd` | TCP/HTTP server, request parsing, router dispatch |
| `http_router.gd` | Base router class with method callables |
| `http_request.gd` | Parsed HTTP request with body/headers/query |
| `http_response.gd` | HTTP response builder (send, json, send_raw) |
| `http_file_router.gd` | Static file serving router |

Originally sourced from [bit-garden/godottpd](https://github.com/bit-garden/godottpd) and vendored directly into `addons/godot_mcp/`.

### MCP Protocol (`addons/godot_mcp/`)

| File | Purpose |
|------|---------|
| `mcp_server.gd` | Main EditorPlugin, manages lifecycle |
| `mcp_server_core.gd` | JSON-RPC 2.0 engine, tool registry, protocol handlers |
| `mcp_router.gd` | Extends HttpRouter — routes `/mcp` (SSE + JSON-RPC) |
| `mcp_sse.gd` | SSE streaming manager, keepalive, client tracking |
| `mcp_types.gd` | Shared constants, error codes, helper factories |
| `command_handler.gd` | Routes commands to processors |
| `commands/*.gd` | Command processors by category |
| `mcp_debugger_bridge.gd` | EditorDebuggerPlugin for breakpoints |
| `mcp_runtime_debugger_bridge.gd` | Runtime scene inspection |
| `mcp_input_handler.gd` | Input simulation autoload |
| `runtime_debugger.gd` | Script injected into debugged projects |
| `mcp_debug_output_publisher.gd` | Live debug output streaming |
| `mcp_enhanced_commands.gd` | Scene structure, runtime inspection, debug output, stack traces, errors |
| `mcp_asset_commands.gd` | Asset and project file listing |
| `mcp_script_resource_commands.gd` | Script fetch/edit operations |
| `ui/mcp_panel.*` | Dock panel UI |
| `utils/editor_utils.gd` | Editor helper utilities |
| `utils/node_utils.gd` | Node traversal helpers |
| `utils/resource_utils.gd` | Resource loading helpers |
| `utils/script_utils.gd` | Script path normalization |

### Command Processors

| Processor | Tools Provided |
|-----------|---------------|
| `node_commands.gd` | create_node, delete_node, update_node_property, etc. |
| `scene_commands.gd` | save_scene, load_scene, get_scene_tree, etc. |
| `script_commands.gd` | run_script, get_script, set_script, etc. |
| `debugger_commands.gd` | Breakpoints, execution control, events |
| `input_commands.gd` | Action simulation, mouse/keyboard, sequences |
| `editor_commands.gd` | Editor state, script execution |
| `project_commands.gd` | Project info, settings |
| `mcp_enhanced_commands.gd` | Scene structure, runtime inspection, debug output, stack traces, editor errors, streaming |
| `mcp_asset_commands.gd` | Asset listing by type, project file enumeration |
| `mcp_script_resource_commands.gd` | Script fetch (`get_script`) and edit (`edit_script`) operations |

## Transport: HTTP + SSE

The MCP protocol is transported over HTTP with Server-Sent Events:

### SSE Connection (`GET /mcp` with `Accept: text/event-stream`)

1. Client opens a persistent HTTP connection to `GET /mcp` with `Accept: text/event-stream`
2. Server responds with `Content-Type: text/event-stream`
3. Server sends `event: endpoint` with `data: {"uri": "/mcp"}` 
4. Server sends keepalive comments every 30 seconds
5. All subsequent MCP notifications (debug events, etc.) are pushed over this stream

### JSON-RPC (`POST /mcp`)

1. Client sends a standard HTTP POST with JSON-RPC 2.0 body
2. Server processes the request and responds immediately
3. Request/response follows the MCP specification

## Protocol Flow

### Initialization
```
Client                           Server
  │                                │
  ├─POST /mcp (initialize)───────►│
  │◄───200 (capabilities, info)───┤
  │                                │
  ├─POST /mcp (initialized)──────►│
  │◄───202 Accepted (notification)┤
```

### Tool Calling
```
Client                           Server
  │                                │
  ├─POST /mcp (tools/list)───────►│
  │◄───200 (tool definitions)─────┤
  │                                │
  ├─POST /mcp (tools/call)───────►│
  │    └─→ CommandHandler          │
  │    └─→ ResponseBroker          │
  │◄───200 (tool result)──────────┤
```

## Message Format

**JSON-RPC Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "create_node",
    "arguments": {
      "node_type": "Sprite2D",
      "node_name": "Player"
    }
  }
}
```

**JSON-RPC Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      { "type": "text", "text": "{\"node_path\": \"./Player\"}" }
    ]
  }
}
```

**SSE Notification:**
```
event: message
data: {"jsonrpc":"2.0","method":"notifications/debug/output","params":{...}}
```

## Input Simulation

Input commands flow through the debugger message system:

```
MCPServerCore → CommandHandler → MCPInputCommands
       │
       ▼ (EngineDebugger.send_message)
MCPInputHandler (runtime autoload)
       │
       ▼
Godot Input System
```

`MCPInputHandler` is auto-registered as an autoload when the plugin is enabled.

## Key Patterns

- **JSON-RPC 2.0**: Standardized request/response protocol
- **Command Pattern**: Commands encapsulated with type + params
- **Response Broker**: Captures async command processor responses for MCP callers
- **Observer Pattern**: SSE events for real-time notifications
- **SSE Transport**: Keeps a persistent connection for server→client push

## Security

- Server binds to `127.0.0.1` (localhost only) by default
- All commands validated before execution
- Errors isolated from crashing the editor
