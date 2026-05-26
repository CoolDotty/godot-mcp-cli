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
| `update_node_property` | Update a node property. | `node_path` (string), `property` (string), `value` (any) | "Set `./Player`'s `position` to `[128, 256]`." |
| `get_node_properties` | Read all editor-visible properties of a node. | `node_path` (string) | "List the properties for `./UI/ScoreLabel`." |
| `list_nodes` | List direct children of a node. | `parent_path` (string) | "What nodes live under `./UI`?" |

---

## Script Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `execute_editor_script` | Run GDScript code in the editor context. | `code` (string) | "Find all nodes in the `Enemies` group and print their names." |
| `get_script` | Fetch script source by file path or node attachment. | `script_path` (string) or `node_path` (string) | "Show me the script at `res://scripts/player.gd`." |
| `edit_script` | Edit a script's source code directly. | `script_path` (string), `content` (string) | "Update `res://scripts/enemy.gd` to add a `take_damage(amount)` function." |

---

## Scene Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `save_scene` | Save the current scene. | `path` (optional string) | "Save our current scene as `res://scenes/level_02.tscn`." |
| `open_scene` | Open a scene file in the editor. | `path` (string) | "Open `res://scenes/menu.tscn` in the editor." |
| `get_scene_structure` | Get the full scene tree structure with properties. | `path` (string) | "Show me the tree structure of `res://scenes/main.tscn`." |
| `get_current_scene` | Get info about the currently open scene. | (none) | "What scene is currently open?" |
| `create_scene` | Create a new scene file. | `path` (string) | "Create an empty scene at `res://scenes/level_01.tscn`." |
| `delete_scene` | Delete a scene file from the project. | `path` (string) | "Delete `res://scenes/old_test.tscn` from the project." |

---

## Project Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `get_project_info` | Get project metadata (name, version, etc.). | (none) | "What is the project name and main scene?" |
| `get_project_settings` | Get project configuration settings. | (none) | "What are the current project settings?" |
| `run_project` | Launch the project using the main scene (same as F5). | (none) | "Run the full project so I can test the main menu flow." |
| `stop_running_project` | Stop the currently running project. | (none) | "Stop the running scene and return to the editor." |
| `run_current_scene` | Play the scene currently open in the editor (F6). | (none) | "Run the scene I have open to verify the latest changes." |
| `run_specific_scene` | Play a specific saved scene by resource path. | `scene_path` (string) | "Run `res://test_main_scene.tscn` so I can test the debugger." |
| `reload_project` | Restart the Godot editor to fully reload the project. | `save` (optional bool, default true) | "Restart Godot to pick up the plugin changes." |
| `reload_scene` | Reload a scene from disk, discarding unsaved changes. | `scene_path` (optional string) | "Reload the current scene to discard my changes." |
| `rescan_filesystem` | Rescan the project filesystem for external file changes. | (none) | "Rescan filesystem after I added new assets externally." |

---

## Editor Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `get_editor_state` | Get the current editor state information. | (none) | "What is the current editor state?" |
| `get_selected_node` | Get the currently selected node in the scene tree. | (none) | "Which node is currently selected?" |
| `create_resource` | Create a new resource file. | `resource_type` (string), `path` (string) | "Create a new `Resource` at `res://data/game_data.tres`." |
| `get_node_warnings` | Inspect the current scene for node configuration warnings. | `debug` (optional bool) | "Are there any configuration warnings in the current scene?" |

---

## Enhanced / Inspection Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `get_editor_scene_structure` | Dump the scene tree with optional properties/scripts/depth. | `include_properties` (optional bool), `include_scripts` (optional bool), `max_depth` (optional number) | "Give me the scene tree including properties and script info up to depth 2." |
| `get_runtime_scene_structure` | Inspect the live scene tree from the running game. | `include_properties` (optional bool), `include_scripts` (optional bool), `max_depth` (optional number), `timeout_ms` (optional number) | "While the game is running, snapshot the runtime tree up to depth 1." |
| `evaluate_runtime` | Evaluate a GDScript expression on the running game. | `expression` (string), `context_path` (optional string), `capture_prints` (optional bool), `timeout_ms` (optional number) | "On `/root/Main/Player`, evaluate `position` and `velocity.length()`." |
| `update_node_transform` | Adjust a node's transform (position/rotation/scale). | `node_path` (string), `position` (optional array), `rotation` (optional number), `scale` (optional array) | "Move `./Camera` to `[512, 256]` and set rotation to `0.5`." |

---

## Debug Output & Error Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `get_debug_output` | Retrieve the current Godot editor debug log. | `max_lines` (optional number, default 100) | "Fetch the latest debug log entries." |
| `clear_debug_output` | Clear the Output panel and reset streaming baseline. | (none) | "Clear the Output panel so the next stream only shows fresh lines." |
| `stream_debug_output` | Start or stop live streaming of the editor Output panel. | `action` ("start" or "stop") | "Subscribe to the debug stream so new Output lines appear live." |
| `get_editor_errors` | Read the Errors tab of the editor bottom panel. | (none) | "Dump the Errors tab and tell me where the messages are coming from." |
| `clear_editor_errors` | Clear the Errors tab in the debugger panel. | (none) | "Clear the Errors tab so I can verify no new errors appear." |

---

## Stack Trace Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `get_stack_trace_panel` | Capture the Stack Trace panel text plus parsed frames. | `session_id` (optional number) | "Grab the Stack Trace panel so I can see exactly where the error originated." |
| `get_stack_frames_panel` | Return structured stack frames from the debugger bridge. | `session_id` (optional number), `refresh` (optional bool) | "Give me the current call stack frames for the active session." |

---

## Debugger Control Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `debugger_set_breakpoint` | Set a breakpoint in a script. | `script_path` (string), `line` (number) | "Set a breakpoint at line 42 of `res://test_debugger.gd`." |
| `debugger_remove_breakpoint` | Remove a breakpoint from a script. | `script_path` (string), `line` (number) | "Remove the breakpoint at line 42 of `res://test_debugger.gd`." |
| `debugger_get_breakpoints` | List all set breakpoints. | (none) | "List all current breakpoints." |
| `debugger_clear_all_breakpoints` | Clear all breakpoints. | (none) | "Clear all breakpoints." |
| `debugger_pause_execution` | Pause the running project. | (none) | "Pause the running game." |
| `debugger_resume_execution` | Resume a paused project. | (none) | "Resume the paused game." |
| `debugger_step_over` | Step over in the debugger. | (none) | "Step over the current line." |
| `debugger_step_into` | Step into a function call. | (none) | "Step into the function on the current line." |
| `debugger_get_call_stack` | Get the current call stack. | `session_id` (optional) | "Show me the current call stack." |
| `debugger_get_current_state` | Get the current debugger state. | (none) | "What's the current debugger state?" |
| `debugger_enable_events` | Enable debugger event notifications via SSE. | (none) | "Enable debugger events so I can see breakpoint hits live." |
| `debugger_disable_events` | Disable debugger event notifications. | (none) | "Disable debugger events to stop live notifications." |

---

## Input Simulation Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `simulate_action_press` | Press and hold an input action. | `action` (string) | "Press the `ui_right` action to start moving right." |
| `simulate_action_release` | Release a held input action. | `action` (string) | "Release `ui_right` to stop moving." |
| `simulate_action_tap` | Quickly press and release an input action. | `action` (string) | "Tap `ui_accept` to confirm the selection." |
| `simulate_mouse_click` | Click a mouse button at a position. | `button` (optional, default "left"), `position` (optional array [x, y]) | "Left-click at position `[400, 300]`." |
| `simulate_mouse_move` | Move the mouse cursor to a position. | `position` (array [x, y]) | "Move the mouse to `[100, 200]`." |
| `simulate_drag` | Click and drag from one position to another. | `from` (array [x, y]), `to` (array [x, y]), `duration_ms` (optional number) | "Drag from `[100, 100]` to `[300, 300]` over 500ms." |
| `simulate_key_press` | Simulate a keyboard key press. | `keycode` (string), `modifiers` (optional array), `pressed` (optional bool, default true) | "Press `Ctrl+S` to save." |
| `simulate_input_sequence` | Execute a timed sequence of input steps. | `steps` (array of {action, type, params, duration_ms}) | "Navigate down the menu and confirm: tap `ui_down` three times, wait 200ms, tap `ui_accept`." |
| `get_input_actions` | List all available input actions in the project. | (none) | "What input actions are defined in this project?" |

---

## Asset Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `list_assets_by_type` | Enumerate assets filtered by type. | `type` (string: scripts, scenes, images, audio, fonts, models, shaders, resources, all) | "List all `scripts` in the project." |
| `list_project_files` | List project files matching specific extensions. | `extensions` (optional array of strings) | "Show all `.tscn` and `.gd` files." |

---

---

## Example Workflows

### Scene Editing
> "Create a `Sprite2D` named `Player` under `./World`, load a texture from `res://icon.svg`, and set its position to `[400, 300]`."

Steps:
1. `create_node` → `parent_path: "."`, `node_type: "Sprite2D"`, `node_name: "Player"`
2. `update_node_property` → `node_path: "./Player"`, `property: "position"`, `value: [400, 300]`

### Debugging with Breakpoints
> "Set a breakpoint at line 42 in `res://test_debugger.gd`, enable debugger events, run the project, and wait for the breakpoint to fire. When it does, get the call stack and stack frames."

Steps:
1. `debugger_set_breakpoint` → `script_path: "res://test_debugger.gd"`, `line: 42`
2. `debugger_enable_events` → (none)
3. `run_project` → (none)
4. Wait for breakpoint event via SSE
5. `debugger_get_call_stack` → (none)
6. `get_stack_frames_panel` → `refresh: true`

### Automated Input Testing
> "Run the project, navigate down three menu items, then confirm the selection."

Steps:
1. `run_project` → (none)
2. `simulate_action_tap` → `action: "ui_down"`
3. `simulate_action_tap` → `action: "ui_down"`
4. `simulate_action_tap` → `action: "ui_down"`
5. `simulate_action_tap` → `action: "ui_accept"`

### Script Operations
> "Read the player script, modify it to add a new function, then verify the changes."

Steps:
1. `get_script` → `script_path: "res://scripts/player.gd"`
2. `edit_script` → `script_path: "res://scripts/player.gd"`, `content: "..."` (modified content)
3. `get_script` → `script_path: "res://scripts/player.gd"` (verify)

### Input Simulation Tips

- **Runtime Required**: Input simulation only works when the game is running with the debugger attached (F5).
- **Action Names**: Use `get_input_actions` to discover available actions before simulating them.
- **Coordinates**: Mouse positions are in screen/viewport space, not world coordinates.
- **Sequences**: Use `simulate_input_sequence` for complex combos that require precise timing.

Keep this guide handy while constructing system or user prompts so the LLM knows exactly which tools are available and how to use them.
