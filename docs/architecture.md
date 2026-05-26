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
  │  Tool Providers (auto-loaded)         │
  │    ├── create_node / delete_node      │
  │    ├── get_script / edit_script       │
  │    ├── open_scene / save_scene        │
  │    ├── get_project_info               │
  │    ├── execute_editor_script          │
  │    ├── debugger_provider              │
  │    ├── runtime_provider               │
  │    └── input_provider                 │
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

### HTTP Server Layer (`http/`)

| File | Purpose |
|------|---------|
| `http/http_server.gd` | TCP/HTTP server, request parsing, router dispatch |
| `http/http_router.gd` | Base router class with method callables |
| `http/http_request.gd` | Parsed HTTP request with body/headers/query |
| `http/http_response.gd` | HTTP response builder (send, json, send_raw) |
| `http/http_file_router.gd` | Static file serving router |

Originally sourced from [bit-garden/godottpd](https://github.com/bit-garden/godottpd) and vendored into `addons/godot_mcp/http/`.

### MCP Core (root)

| File | Purpose |
|------|---------|
| `mcp_server.gd` | Main EditorPlugin, manages plugin lifecycle |
| `mcp_server_core.gd` | JSON-RPC 2.0 engine, tool registry, dynamically loads tool providers |
| `tool_definition.gd` | Shared tool definition resource type |

### MCP Protocol (`mcp/`)

| File | Purpose |
|------|---------|
| `mcp/mcp_router.gd` | Extends HttpRouter — routes `/mcp` (SSE + JSON-RPC) |
| `mcp/mcp_sse.gd` | SSE streaming manager, keepalive, client tracking |
| `mcp/mcp_types.gd` | Shared constants, error codes, helper factories |
| `mcp/mcp_input_handler.gd` | Input simulation autoload (registered at plugin start) |

### Debugger Integration (`debugger/`)

| File | Purpose |
|------|---------|
| `debugger/mcp_debugger_bridge.gd` | EditorDebuggerPlugin for breakpoints and execution control |
| `debugger/mcp_runtime_debugger_bridge.gd` | Runtime scene inspection bridge |
| `debugger/mcp_debug_output_publisher.gd` | Live debug output streaming to SSE clients |
| `debugger/runtime_debugger.gd` | Script injected into debugged projects for expression evaluation |

### Tool Providers (`tool_providers/`)

Each `.gd` file in `tool_providers/` registers one or more MCP tools. MCPServerCore scans this directory at startup and auto-loads all valid providers.

| Provider | Tools Provided |
|----------|---------------|
| `tool_providers/create_node.gd` | create_node |
| `tool_providers/delete_node.gd` | delete_node |
| `tool_providers/update_node_property.gd` | update_node_property |
| `tool_providers/update_node_transform.gd` | update_node_transform |
| `tool_providers/list_nodes.gd` | list_nodes |
| `tool_providers/get_node_properties.gd` | get_node_properties |
| `tool_providers/get_node_warnings.gd` | get_node_warnings |
| `tool_providers/get_selected_node.gd` | get_selected_node |
| `tool_providers/get_current_scene.gd` | get_current_scene |
| `tool_providers/get_scene_structure.gd` | get_scene_structure |
| `tool_providers/get_editor_scene_structure.gd` | get_editor_scene_structure |
| `tool_providers/create_scene.gd` | create_scene |
| `tool_providers/delete_scene.gd` | delete_scene |
| `tool_providers/open_scene.gd` | open_scene |
| `tool_providers/save_scene.gd` | save_scene |
| `tool_providers/reload_scene.gd` | reload_scene |
| `tool_providers/reload_project.gd` | reload_project |
| `tool_providers/run_current_scene.gd` | run_current_scene |
| `tool_providers/run_project.gd` | run_project |
| `tool_providers/run_specific_scene.gd` | run_specific_scene |
| `tool_providers/stop_running_project.gd` | stop_running_project |
| `tool_providers/create_script.gd` | create_script |
| `tool_providers/get_script.gd` | get_script |
| `tool_providers/get_script_metadata.gd` | get_script_metadata |
| `tool_providers/edit_script.gd` | edit_script |
| `tool_providers/get_current_script.gd` | get_current_script |
| `tool_providers/create_resource.gd` | create_resource |
| `tool_providers/get_project_info.gd` | get_project_info |
| `tool_providers/get_project_settings.gd` | get_project_settings |
| `tool_providers/get_project_structure.gd` | get_project_structure |
| `tool_providers/list_assets_by_type.gd` | list_assets_by_type |
| `tool_providers/list_project_files.gd` | list_project_files |
| `tool_providers/list_project_resources.gd` | list_project_resources |
| `tool_providers/rescan_filesystem.gd` | rescan_filesystem |
| `tool_providers/get_editor_state.gd` | get_editor_state |
| `tool_providers/get_editor_errors.gd` | get_editor_errors |
| `tool_providers/clear_editor_errors.gd` | clear_editor_errors |
| `tool_providers/get_debug_output.gd` | get_debug_output |
| `tool_providers/clear_debug_output.gd` | clear_debug_output |
| `tool_providers/subscribe_debug_output.gd` | subscribe_debug_output |
| `tool_providers/unsubscribe_debug_output.gd` | unsubscribe_debug_output |
| `tool_providers/get_stack_trace_panel.gd` | get_stack_trace_panel |
| `tool_providers/get_stack_frames_panel.gd` | get_stack_frames_panel |
| `tool_providers/debugger_provider.gd` | Debugger breakpoints and execution control |
| `tool_providers/runtime_provider.gd` | Runtime scene inspection and expression evaluation |
| `tool_providers/input_provider.gd` | Input simulation (actions, mouse, keyboard) |
| `tool_providers/editor_script_provider.gd` | execute_editor_script |

### UI & Utilities

| File | Purpose |
|------|---------|
| `ui/mcp_panel.*` | Dock panel UI for server control and status |
| `utils/editor_utils.gd` | Editor helper utilities |
| `utils/node_utils.gd` | Node traversal helpers |
| `utils/resource_utils.gd` | Resource loading helpers |
| `utils/script_utils.gd` | Script path normalization |

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
MCPServerCore → InputProvider
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
