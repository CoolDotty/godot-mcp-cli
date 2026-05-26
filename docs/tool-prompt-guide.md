# MCP Tool Prompt Guide

Use this document to craft effective prompts when instructing an AI to interact with the Godot MCP server. Each tool entry includes its purpose, parameters, and a ready-to-use example prompt.

The server uses **HTTP + SSE** transport on port 9080. All tool calls are made via `POST /mcp` with JSON-RPC 2.0 body:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "<tool_name>",
    "arguments": { ... }
  }
}
```

---

## Node Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `create_node` | Create a new node under a parent in the current scene. | `parent_path` (string), `node_type` (string), `node_name` (string) | "Create a `Sprite2D` named `Enemy` under `./World`." |
| `delete_node` | Remove a node from the scene tree. | `node_path` (string) | "Delete the node at `./World/Enemy`." |
| `update_node_property` | Update a node property. | `node_path` (string), `property_name` (string), `value` (any) | "Set `./Player`'s `position` to `[128, 256]`." |
| `get_node_properties` | Read all editor-visible properties of a node. | `node_path` (string) | "List the properties for `./UI/ScoreLabel`." |
| `list_nodes` | List direct children of a node. | `parent_path` (string) | "What nodes live under `./UI`?" |

---

## Script Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `run_script` | Run GDScript code in the editor context. | `script` (string) | "Find all nodes in the `Enemies` group and print their names." |
| `get_script` | Fetch script source based on file path or node attachment. | `path` (string) | "Show me the script at `res://scripts/player.gd`." |
| `set_script` | Set a script on a node. | `node_path` (string), `script_path` (string) | "Attach `res://scripts/health_manager.gd` to `./World/HealthManager`." |

---

## Scene Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `save_scene` | Save the current scene. | `path` (optional string) | "Save our current scene as `res://scenes/level_02.tscn`." |
| `load_scene` | Load a scene file. | `path` (string) | "Open `res://scenes/menu.tscn` in the editor." |
| `get_scene_tree` | Get the current scene tree structure. | (none) | "Show me the current scene tree." |

---

## Project Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `get_project_settings` | Get project settings/metadata. | (none) | "Show me the project name, version, and current scene path." |
| `set_project_setting` | Set a project setting value. | `key` (string), `value` (any) | "Set the project name to 'My Game'." |

---

## Debugger Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `get_debug_output` | Retrieve the current Godot editor debug log. | `max_lines` (optional number) | "Fetch the latest debug log entries." |

---

## Input Simulation Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `simulate_input` | Simulate an input action in the running game. | `action` (string), `pressed` (boolean) | "Press the `ui_accept` action to confirm the selection." |

---

## Example Workflows

### Scene Editing
> "Create a `Sprite2D` named `Player` under `./World`, load a texture from `res://icon.svg`, and set its position to `[400, 300]`."

Steps:
1. `create_node` → `parent_path: "."`, `node_type: "Sprite2D"`, `node_name: "Player"`
2. `update_node_property` → `node_path: "./Player"`, `property_name: "position"`, `value: [400, 300]`

### Debugging
> "Get the latest debug output to see if there are any errors."

1. `get_debug_output` → `max_lines: 50`

### Script Operations
> "Read the player script, then run a quick command to get the editor state."

1. `get_script` → `path: "res://scripts/player.gd"`
2. `get_project_settings`
