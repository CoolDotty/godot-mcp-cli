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
| `run_project` | Launch the project using the Project Settings main scene (same as pressing F5). | _none_ | "Run the full project so I can watch the main menu flow." |
| `stop_running_project` | Stop whatever scene the editor is currently playing. | _none_ | "Stop the running scene and return to the editor." |
| `run_current_scene` | Play the scene currently open in the editor (F6 behavior). | _none_ | "Run the scene I have open to verify the latest changes." |
| `run_specific_scene` | Play a specific saved scene by resource path. | `scene_path` (string) | "Run `res://test_main_scene.tscn` so I can test the debugger harness." |
| `reload_project` | Restart the Godot editor to fully reload the project. | `save` (optional bool, default: true) | "Restart Godot to pick up the plugin changes." |
| `reload_scene` | Reload a scene from disk, discarding unsaved changes. | `scene_path` (optional string) | "Reload the current scene to discard my changes." |
| `rescan_filesystem` | Rescan the project filesystem for external file changes. | _none_ | "Rescan the filesystem after I added new assets externally." |

---

## Editor Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `execute_editor_script` | Run arbitrary GDScript inside the editor context. | `code` (string) | "Find all nodes in the `Enemies` group and print their names." |
| `get_node_warnings` | Inspect the current scene for node configuration warnings. | `debug` (optional bool) | "Include traversal stats." |

---

## Asset Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `list_assets_by_type` | Enumerate assets filtered by type. | `type` (string; `scripts`, `scenes`, `images`, `audio`, `fonts`, `models`, `shaders`, `resources`, `all`) | "List all `scripts` in the project." |
| `list_project_files` | List project files matching specific extensions. | `extensions` (optional array of strings) | "Show all `.tscn` and `.gd` files." |

---

## Enhanced Tools

| Tool | Purpose | Parameters | Example Prompt |
|------|---------|------------|----------------|
| `get_editor_scene_structure` | Dump the scene tree with optional properties/scripts/depth. | `include_properties` (optional bool), `include_scripts` (optional bool), `max_depth` (optional number) | "Give me the scene tree including properties and script info up to depth 2." |
| `get_runtime_scene_structure` | Inspect the live scene tree from the running game. | `include_properties` (optional bool), `include_scripts` (optional bool), `max_depth` (optional number), `timeout_ms` (optional number) | "While the game is running, snapshot the runtime tree up to depth 1." |
| `evaluate_runtime_expression` | Evaluate a GDScript expression on the running game (requires the runtime debugger bridge autoload). | `expression` (string), `context_path` (optional string), `capture_prints` (optional bool), `timeout_ms` (optional number) | "On `/root/Main/Player`, evaluate `print(position); velocity.length()` and return the value." |
| `get_debug_output` | Retrieve the current Godot editor debug log along with capture diagnostics (source, control path, etc.). | _none_ | "Fetch the latest debug log and tell me how the plugin captured it." |
| `get_stack_trace_panel` | Capture the Stack Trace panel text plus parsed frames whenever the debugger is paused. | `session_id` (optional number) | "Grab the Stack Trace panel (include the structured frames) so I can see exactly where the error originated." |
| `get_stack_frames_panel` | Return the structured stack frames from the debugger bridge cache (optionally request a refresh first). | `session_id` (optional number), `refresh` (optional bool) | "Give me the current call stack frames for the active session—refresh the dump first if needed." |
| `get_editor_errors` | Read the Errors tab of the editor bottom panel to capture recent script/runtime issues. | _none_ | "Dump the Errors tab and tell me where the messages are coming from so I can triage them." |
| `clear_debug_output` | Clear the Output panel and reset the streaming baseline before a new capture. | _none_ | "Clear the Output panel so the next debug stream only shows fresh lines." |
| `clear_editor_errors` | Clear the Errors tab in the debugger panel to remove accumulated warnings and errors. | _none_ | "Clear the Errors tab so I can verify no new errors appear during the next test run." |
| `update_node_transform` | Adjust a node's transform (position/rotation/scale). | `node_path` (string), `position` (optional array), `rotation` (optional number), `scale` (optional array) | "Move `./Camera` to `[512, 256]` and set rotation to `0.5`." |
| `stream_debug_output` | Start (`action="start"`) or stop (`"stop"`) live streaming of the editor Output panel (lines arrive as `[Godot Debug] ...`). | `action` (optional string, `"start"` or `"stop"`) | "Subscribe to the debug stream so new Output lines appear live; I'll stop it afterwards." |

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

**Complex Debugging**:
> "Enable debugger events, set breakpoints at lines 15, 25, and 42 in the enemy AI script, run the game, and pause execution when breakpoints are hit to examine the call stack."

### Input Simulation Tips

- **Runtime Required**: Input simulation only works when the game is running with the debugger attached (F5).
- **Action Names**: Use `get_input_actions` to discover available actions before simulating them.
- **Coordinates**: Mouse positions are in screen/viewport space, not world coordinates.
- **Sequences**: Use `simulate_input_sequence` for complex combos that require precise timing.

### Example Input Workflows

**Testing UI Navigation**:
> "Run the project, then tap `ui_down` three times to navigate the menu, then tap `ui_accept` to select the highlighted option."

**Automated Game Testing**:
> "Run the project, simulate pressing `ui_right` for 500ms to move the character, then tap `jump` to make them jump over the obstacle."

Keep this guide handy while constructing system or user prompts so the LLM knows exactly which tools are available and how to use them.
