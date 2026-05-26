@tool
extends Control

var http_server: HttpServer = null
var mcp_sse: MCPSse = null
var status_label: Label
var port_input: SpinBox
var start_button: Button
var stop_button: Button
var connection_count_label: Label
var log_text: TextEdit


func _ready():
	status_label = $VBoxContainer/StatusContainer/StatusLabel
	port_input = $VBoxContainer/PortContainer/PortSpinBox
	start_button = $VBoxContainer/ButtonsContainer/StartButton
	stop_button = $VBoxContainer/ButtonsContainer/StopButton
	connection_count_label = $VBoxContainer/ConnectionsContainer/CountLabel
	log_text = $VBoxContainer/LogContainer/LogText

	start_button.pressed.connect(_on_start_button_pressed)
	stop_button.pressed.connect(_on_stop_button_pressed)
	port_input.value_changed.connect(_on_port_changed)

	# Initial UI setup
	_update_ui()

	# Setup server signals once it's available
	await get_tree().process_frame
	if http_server and http_server.is_listening():
		# The HttpServer uses _server (TCPServer) internally
		log_message("Server configured on port %d" % http_server.port)


func _update_ui():
	if not http_server:
		status_label.text = "Server: Not initialized"
		start_button.disabled = true
		stop_button.disabled = true
		port_input.editable = true
		connection_count_label.text = "0"
		return

	var is_active = http_server and http_server.is_listening()

	status_label.text = "Server: " + ("Running" if is_active else "Stopped")
	start_button.disabled = is_active
	stop_button.disabled = not is_active
	port_input.editable = not is_active

	if is_active:
		var count = 0
		if mcp_sse:
			count = mcp_sse.get_client_count()
		connection_count_label.text = str(count)
	else:
		connection_count_label.text = "0"


func _on_start_button_pressed():
	if http_server:
		http_server.port = int(port_input.value)
		http_server.start()
		_log_message("Server started on port " + str(http_server.port))
		_update_ui()


func _on_stop_button_pressed():
	if http_server:
		http_server.stop()
		_log_message("Server stopped")
		_update_ui()


func _on_port_changed(new_port: float):
	_log_message("Port changed to " + str(int(new_port)))


func _log_message(message: String):
	var timestamp = Time.get_datetime_string_from_system()
	log_text.text += "[" + timestamp + "] " + message + "\n"
	# Auto-scroll to bottom
	log_text.scroll_vertical = log_text.get_line_count()


## Public wrapper for _update_ui
func update_ui() -> void:
	_update_ui()


## Public wrapper for _log_message
func log_message(message: String) -> void:
	_log_message(message)
