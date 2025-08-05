extends Control
var is_leaving = false

func _ready() -> void:
	$alert.visible = false
	update_seats(LobbyManager.current_lobby_config)
	LobbyManager.lobby_config_updated.connect(_on_lobby_updated)

func _on_lobby_updated(lobby_data: Dictionary):
	update_seats(lobby_data)

func hide_all_characters():
	for i in range(1, 8):
		get_node("Characters/Character" + str(i) + "-1").visible = false
		get_node("Characters/Character" + str(i) + "-2").visible = false

func update_seats(lobby_data: Dictionary):
	hide_all_characters()
	
	var seat_assignments = lobby_data.get("seat_assignments", {})
	
	if seat_assignments.is_empty():
		print("No seat assignments received from server")
		return
	
	print("=== CLIENT SEAT UPDATE ===")
	print("Seat assignments from server: ", seat_assignments)
	
	for player_id in seat_assignments:
		var assignment = seat_assignments[player_id]
		var seat = assignment.get("seat", -1)
		var variant = assignment.get("variant", 1)
		
		if seat >= 1 and seat <= 7:
			var character_node = get_node("Characters/Character" + str(seat) + "-" + str(variant))
			character_node.visible = true
			print("Showing character at seat ", seat, " variant ", variant, " for player ", player_id)
	
	print("=== END CLIENT SEAT UPDATE ===")

func wait_for_lobby_left():
	print("Waiting for lobby left confirmation")
	var check_timer = Timer.new()
	add_child(check_timer)
	check_timer.wait_time = 0.1
	check_timer.one_shot = false
	check_timer.timeout.connect(_check_lobby_left)
	check_timer.start()

func _check_lobby_left():
	if LobbyManager.current_lobby_id.is_empty():
		print("Lobby ID cleared - server confirmed exit")
		leave_lobby_complete()

func _on_leave_timeout():
	leave_lobby_complete()

func leave_lobby_complete():
	for child in get_children():
		if child is Timer:
			child.queue_free()
	
	LobbyManager.current_lobby_id = ""
	LobbyManager.current_player_id = ""
	LobbyManager.is_host = false
	LobbyManager.all_players.clear()
	
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")

func _on_exit_btn_pressed() -> void:
	$alert.visible = true

func _on_cancel_pressed() -> void:
	$alert.visible = false

func _on_leave_pressed() -> void:
	if is_leaving:
		print("Already processing lobby exit...")
		return
	
	is_leaving = true
	print("=== STARTING EXIT PROCESS ===")
	print("Lobby ID: ", LobbyManager.current_lobby_id)
	print("Player ID: ", LobbyManager.current_player_id)
	print("WebSocket status: ", LobbyManager.get_connection_status())
	
	var leave_message = {
		"type": "leave_lobby",
		"lobby_id": LobbyManager.current_lobby_id,
		"player_id": LobbyManager.current_player_id
	}
	
	print("Message to send: ", JSON.stringify(leave_message))
	
	if LobbyManager.websocket_client and LobbyManager.websocket_client.get_ready_state() == WebSocketPeer.STATE_OPEN:
		LobbyManager.websocket_client.send_text(JSON.stringify(leave_message))
		print("Message sent to server, waiting for response...")
		
		var timer = Timer.new()
		add_child(timer)
		timer.wait_time = 5.0
		timer.one_shot = true
		timer.timeout.connect(_on_leave_timeout)
		timer.start()
		
		wait_for_lobby_left()
		
	else:
		print("Error: WebSocket not connected, going to menu directly")
		leave_lobby_complete()
