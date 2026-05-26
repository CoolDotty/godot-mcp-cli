# Godot MCP Command Reference

Complete reference for all available tools. These are accessible via `tools/call` in the MCP protocol (`POST /mcp` with JSON-RPC 2.0).

## Node Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `create_node` | Create a new node in the scene tree | `parent_path` (optional, default "."), `node_type` (required), `node_name` (required) |
| `delete_node` | Delete a node from the scene tree | `node_path` (required) |
| `update_node_property` | Update a property on a node | `node_path` (required), `property` (required), `value` (required) |
| `get_node_properties` | Get all properties of a node | `node_path` (required) |
| `list_nodes` | List all nodes in the current scene | `parent_path` (optional) |

## Script Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `execute_editor_script` | Run GDScript code in the editor context | `code` (required) |
| `get_script` | Get source code of a script by path or node attachment | `script_path` (optional), `node_path` (optional) |
| `edit_script` | Edit a script's source code | `script_path` (required), `content` (required) |

## Scene Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `save_scene` | Save the current scene | `path` (optional) |
| `open_scene` | Open a scene file in the editor | `path` (required) |
| `get_scene_structure` | Get the full scene tree structure with properties | `path` (required) |
| `get_current_scene` | Get info about the currently open scene | (none) |
| `create_scene` | Create a new scene file | `path` (required) |
| `delete_scene` | Delete a scene file from the project | `path` (required) |

## Project Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_project_info` | Get project information | (none) |
| `get_project_settings` | Get project settings | (none) |
| `run_project` | Launch the project (same as F5) | (none) |
| `stop_running_project` | Stop the running project | (none) |
| `run_current_scene` | Play the current scene in the editor (F6) | (none) |
| `run_specific_scene` | Run a specific scene by path | `scene_path` (required) |
| `reload_project` | Restart the Godot editor | `save` (optional bool, default true) |
| `reload_scene` | Reload a scene from disk | `scene_path` (optional) |
| `rescan_filesystem` | Rescan the project filesystem | (none) |

## Editor Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_editor_state` | Get current editor state information | (none) |
| `get_selected_node` | Get the currently selected node | (none) |
| `create_resource` | Create a new resource | `resource_type` (required), `path` (required) |
| `get_node_warnings` | Inspect current scene for node configuration warnings | `debug` (optional bool) |

## Enhanced / Inspection Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_editor_scene_structure` | Dump the scene tree with optional properties/scripts | `include_properties` (optional bool), `include_scripts` (optional bool), `max_depth` (optional number) |
| `get_runtime_scene_structure` | Snapshot the live scene tree from a running game | `include_properties` (optional bool), `include_scripts` (optional bool), `max_depth` (optional number), `timeout_ms` (optional number) |
| `evaluate_runtime` | Evaluate a GDScript expression on the running game | `expression` (required), `context_path` (optional), `capture_prints` (optional), `timeout_ms` (optional) |
| `update_node_transform` | Adjust a node's transform (position/rotation/scale) | `node_path` (required), `position` (optional array), `rotation` (optional number), `scale` (optional array) |

## Debug Output & Errors

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_debug_output` | Get current editor debug log | `max_lines` (optional number, default 100) |
| `clear_debug_output` | Clear the Output panel | (none) |
| `stream_debug_output` | Start or stop live debug output streaming | `action` ("start" or "stop") |
| `get_editor_errors` | Read the Errors tab of the bottom panel | (none) |
| `clear_editor_errors` | Clear the Errors tab | (none) |

## Stack Trace Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_stack_trace_panel` | Capture the Stack Trace panel text plus parsed frames | `session_id` (optional number) |
| `get_stack_frames_panel` | Return structured stack frames from the debugger bridge | `session_id` (optional number), `refresh` (optional bool) |

## Debugger Control Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `debugger_set_breakpoint` | Set a breakpoint in a script | `script_path` (required), `line` (required number) |
| `debugger_remove_breakpoint` | Remove a breakpoint from a script | `script_path` (required), `line` (required number) |
| `debugger_get_breakpoints` | List all breakpoints | (none) |
| `debugger_clear_all_breakpoints` | Clear all breakpoints | (none) |
| `debugger_pause_execution` | Pause the running project | (none) |
| `debugger_resume_execution` | Resume a paused project | (none) |
| `debugger_step_over` | Step over in the debugger | (none) |
| `debugger_step_into` | Step into a function call | (none) |
| `debugger_get_call_stack` | Get the current call stack | `session_id` (optional) |
| `debugger_get_current_state` | Get current debugger state | (none) |
| `debugger_enable_events` | Enable debugger event notifications | (none) |
| `debugger_disable_events` | Disable debugger event notifications | (none) |

## Input Simulation Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `simulate_action_press` | Press an input action | `action` (required) |
| `simulate_action_release` | Release an input action | `action` (required) |
| `simulate_action_tap` | Tap an input action (press + release) | `action` (required) |
| `simulate_mouse_click` | Simulate a mouse click | `button` (optional, default "left"), `position` (optional array [x, y]) |
| `simulate_mouse_move` | Move the mouse cursor | `position` (required array [x, y]) |
| `simulate_drag` | Click and drag from one position to another | `from` (required array [x, y]), `to` (required array [x, y]), `duration_ms` (optional) |
| `simulate_key_press` | Simulate a keyboard key press | `keycode` (required), `modifiers` (optional array), `pressed` (optional bool, default true) |
| `simulate_input_sequence` | Execute a timed input sequence | `steps` (required array of step objects) |
| `get_input_actions` | List all available input actions in the project | (none) |

## Asset Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `list_assets_by_type` | List assets filtered by type | `type` (required: scripts, scenes, images, audio, fonts, models, shaders, resources, all) |
| `list_project_files` | List project files by extension | `extensions` (optional array of strings) |

## Making Tool Calls

Send a JSON-RPC request to `POST /mcp`:

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

### Response Format

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

## Listing All Tools

To discover all available tools at runtime:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
```
