# Godot MCP Command Reference

Quick reference for all available tools. These tools are accessible via `tools/call` in the MCP protocol.

## Node Tools

| Tool | Description | Key Parameters |
|------|-------------|----------------|
| `create_node` | Create a node | `parent_path`, `node_type`, `node_name` |
| `delete_node` | Delete a node | `node_path` |
| `update_node_property` | Set a property | `node_path`, `property_name`, `value` |
| `get_node_properties` | Get all properties | `node_path` |
| `list_nodes` | List child nodes | `parent_path` |

## Script Tools

| Tool | Description | Key Parameters |
|------|-------------|----------------|
| `run_script` | Execute GDScript code | `script` |
| `get_script` | Get script content | `path` |
| `set_script` | Set script on a node | `node_path`, `script_path` |

## Scene Tools

| Tool | Description | Key Parameters |
|------|-------------|----------------|
| `save_scene` | Save current scene | `path` (optional) |
| `load_scene` | Load a scene file | `path` |
| `get_scene_tree` | Get current scene info | (none) |

## Project Tools

| Tool | Description | Key Parameters |
|------|-------------|----------------|
| `get_project_settings` | Get project info | (none) |
| `set_project_setting` | Set a project setting | `key`, `value` |

## Debugger Tools

| Tool | Description | Key Parameters |
|------|-------------|----------------|
| `get_debug_output` | Get debug output | `max_lines` (optional) |

## Input Simulation Tools

| Tool | Description | Key Parameters |
|------|-------------|----------------|
| `simulate_input` | Simulate an input action | `action`, `pressed` |

## Making Tool Calls

To call a tool, send a JSON-RPC request to `POST /mcp`:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "create_node",
    "arguments": {
      "node_type": "Sprite2D",
      "node_name": "Player",
      "parent_path": "."
    }
  }
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"node_path\": \"./Player\"}"
      }
    ]
  }
}
```

## Listing Tools

To list all available tools:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
```
