extends Node

var websocket_client: WebSocketPeer
var is_connected_to_server = false
var server_url = "wss://qynto-talk-room-production.up.railway.app"
var connection_attempt = 0
var max_connection_attempts = 3
var reconnect_timer: Timer

var current_lobby_config = {}
var available_lobbies = []
var current_lobby_id = ""
var is_host = false
var pending_lobby_creation = false
var lobby_creation_attempts = 0
var max_lobby_creation_attempts = 3
var current_player_id: String = ""
var all_players: Dictionary = {}

signal lobby_created(lobby_id: String)
signal lobby_joined(lobby_id: String)
signal lobby_config_updated(config: Dictionary)
signal websocket_connected()
signal websocket_disconnected()
signal websocket_error()
signal lobbies_updated(lobbies: Array)
signal connection_failed()
signal player_eliminated(message: String)
signal points_awarded(player_id: String, points: int)
signal game_ended(final_scores: Array)

func _ready():
	setup_reconnect_timer()
	reset_lobby_config()
	call_deferred("connect_to_server")

func setup_reconnect_timer():
	reconnect_timer = Timer.new()
	reconnect_timer.wait_time = 5.0
	reconnect_timer.one_shot = true
	reconnect_timer.timeout.connect(_on_reconnect_timeout)
	add_child(reconnect_timer)

func _process(_delta):
	if websocket_client:
		websocket_client.poll()
		var state = websocket_client.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				if not is_connected_to_server:
					is_connected_to_server = true
					connection_attempt = 0
					lobby_creation_attempts = 0
					websocket_connected.emit()
				if pending_lobby_creation:
					pending_lobby_creation = false
					_create_lobby_now()
				while websocket_client.get_available_packet_count():
					var packet = websocket_client.get_packet()
					var message = packet.get_string_from_utf8()
					handle_server_message(message)
			WebSocketPeer.STATE_CLOSED:
				if is_connected_to_server:
					is_connected_to_server = false
					websocket_disconnected.emit()
					attempt_reconnect()

func connect_to_server():
	if connection_attempt >= max_connection_attempts:
		connection_failed.emit()
		return
	connection_attempt += 1
	if websocket_client:
		websocket_client.close()
	websocket_client = WebSocketPeer.new()
	var error = websocket_client.connect_to_url(server_url)
	if error != OK:
		websocket_error.emit()
		attempt_reconnect()

func attempt_reconnect():
	if connection_attempt < max_connection_attempts and reconnect_timer.is_stopped():
		reconnect_timer.start()

func _on_reconnect_timeout():
	connect_to_server()

func reset_lobby_config():
	current_lobby_config = {
		"rounds": 10,
		"is_public": true,
		"max_participants": 7,
		"infinite_participants": false,
		"max_human_players": 4,
		"max_ai_players": 10,
		"current_ai_players": 3,
		"event_by_messages": true,
		"messages_interval": 12,
		"seconds_interval": 120,
		"host_type": "auto",
		"lobby_name": "My Lobby",
		"lobby_id": "",
		"created_at": Time.get_unix_time_from_system(),
		"current_players": 1,
		"creator": {},
		"players": []
	}

func create_lobby() -> String:
	if not is_connected_to_server:
		pending_lobby_creation = true
		return ""
	return _create_lobby_now()

func _create_lobby_now() -> String:
	if lobby_creation_attempts >= max_lobby_creation_attempts:
		return ""
	lobby_creation_attempts += 1
	var lobby_id = generate_lobby_id()
	current_lobby_config.lobby_id = lobby_id
	current_lobby_config.creator = {
		"id": Player.id,
		"name": Player.user_name,
		"avatar": Player.avatar,
		"points": Player.points_current
	}
	current_lobby_config.players = [Player.get_player_data()]
	current_lobby_config.players_list = [Player.get_player_data()]
	current_lobby_config.current_players = 1
	current_lobby_id = lobby_id
	current_player_id = Player.id
	is_host = true
	all_players[Player.id] = Player.get_player_data()
	send_lobby_to_server(current_lobby_config)
	return lobby_id

func join_lobby(lobby_id: String) -> bool:
	if not is_connected_to_server:
		return false
	var success = request_join_lobby(lobby_id)
	if success:
		current_lobby_id = lobby_id
		is_host = false
		return true
	return false

func leave_lobby():
	if not is_connected_to_server or current_lobby_id.is_empty():
		return
	
	var message = {
		"type": "leave_lobby",
		"lobby_id": current_lobby_id,
		"player_id": current_player_id
	}
	var message_string = JSON.stringify(message)
	websocket_client.send_text(message_string)

func generate_lobby_id() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var lobby_id = ""
	for i in range(8):
		lobby_id += chars[randi() % chars.length()]
	return lobby_id

func send_lobby_to_server(config: Dictionary):
	if not is_connected_to_server:
		return
	var message = {
		"type": "create_lobby",
		"data": config
	}
	var message_string = JSON.stringify(message)
	websocket_client.send_text(message_string)

func request_join_lobby(lobby_id: String) -> bool:
	if not is_connected_to_server:
		return false
	var player_data = Player.get_player_data()
	var message = {
		"type": "join_lobby",
		"lobby_id": lobby_id,
		"player_data": player_data
	}
	var message_string = JSON.stringify(message)
	var error = websocket_client.send_text(message_string)
	return error == OK

func request_lobbies_list():
	if not is_connected_to_server:
		return
	var message = {"type": "get_lobbies"}
	var message_string = JSON.stringify(message)
	websocket_client.send_text(message_string)

func handle_server_message(message_string: String):
	var json = JSON.new()
	var parse_result = json.parse(message_string)
	if parse_result != OK:
		return
	var message = json.data
	match message.get("type", ""):
		"lobby_created":
			handle_lobby_created_response(message)
		"lobby_joined":
			handle_lobby_joined_response(message)
		"lobbies_list":
			handle_lobbies_list(message.get("data", []))
		"lobby_updated":
			handle_lobby_update(message.get("data", {}))
		"lobby_left":
			handle_lobby_left_response(message)
		"player_joined":
			handle_player_joined(message)
		"player_left":
			handle_player_left(message)
		"new_chat_message":
			handle_chat_message(message)
		"new_event":
			handle_new_event(message)
		"player_eliminated":
			handle_player_eliminated(message)
		"points_awarded":
			handle_points_awarded(message)
		"game_started":
			handle_game_started(message)
		"game_ended":
			handle_game_ended(message)
		"round_changed":
			handle_round_changed(message)
		"force_leave":
			handle_force_leave(message)
		"lobby_updated":
			handle_lobby_update(message.get("data", {}))
		"event_resolved":
			if message.has("lobby_data"):
				current_lobby_config = message.lobby_data
				update_all_players(current_lobby_config.get("players_list", []))
				lobby_config_updated.emit(current_lobby_config)
		"error":
			pass
func send_chat_message(message: String):
	if not is_connected_to_server or current_lobby_id.is_empty():
		return false
	
	var chat_message = {
		"type": "send_chat_message",
		"lobby_id": current_lobby_id,
		"player_id": current_player_id,
		"message": message
	}
	
	var message_string = JSON.stringify(chat_message)
	var error = websocket_client.send_text(message_string)
	return error == OK

func handle_chat_message(message):
	if message.has("message"):
		var chat_msg = message.message
		if not current_lobby_config.has("chat_messages"):
			current_lobby_config.chat_messages = []
		current_lobby_config.chat_messages.append(chat_msg)
		lobby_config_updated.emit(current_lobby_config)

func handle_new_event(message):
	if message.has("lobby_data"):
		current_lobby_config = message.lobby_data
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_config_updated.emit(current_lobby_config)

func handle_player_eliminated(message):
	if message.has("eliminated_player") and message.eliminated_player == current_player_id:
		player_eliminated.emit("You have been eliminated from the game!")
		
		var leave_timer = Timer.new()
		leave_timer.wait_time = 3.0
		leave_timer.one_shot = true
		leave_timer.timeout.connect(func(): 
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
			leave_timer.queue_free()
		)
		add_child(leave_timer)
		leave_timer.start()
	
	if message.has("lobby_data"):
		current_lobby_config = message.lobby_data
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_config_updated.emit(current_lobby_config)

func handle_points_awarded(message):
	var player_id = message.get("player_id", "")
	var points = message.get("points", 0)
	
	if player_id == current_player_id:
		Player.add_points(points)
	
	points_awarded.emit(player_id, points)
	
	if message.has("lobby_data"):
		current_lobby_config = message.lobby_data
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_config_updated.emit(current_lobby_config)

func handle_game_started(message):
	if message.has("data"):
		current_lobby_config = message.data
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_config_updated.emit(current_lobby_config)

func handle_game_ended(message):
	if message.has("final_scores"):
		game_ended.emit(message.final_scores)
	
	if message.has("lobby_data"):
		current_lobby_config = message.lobby_data
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_config_updated.emit(current_lobby_config)

func handle_round_changed(message):
	if message.has("lobby_data"):
		current_lobby_config = message.lobby_data
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_config_updated.emit(current_lobby_config)

func handle_force_leave(message):
	if message.get("redirect_to_main", false):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func handle_lobby_left_response(message):
	current_lobby_id = ""
	current_player_id = ""
	all_players.clear()
	is_host = false
	current_lobby_config.clear()

func handle_lobby_created_response(message):
	if message.has("lobby_data"):
		current_lobby_config = message.lobby_data
		current_lobby_id = current_lobby_config.get("lobby_id", "")
		if message.has("player_id"):
			current_player_id = message.player_id
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_created.emit(current_lobby_id)
		lobby_config_updated.emit(current_lobby_config)
	elif message.has("data"):
		current_lobby_config = message.data
		current_lobby_id = current_lobby_config.get("lobby_id", "")
		if message.has("player_id"):
			current_player_id = message.player_id
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_created.emit(current_lobby_id)
		lobby_config_updated.emit(current_lobby_config)

func handle_lobby_joined_response(message):
	if message.has("lobby_data"):
		current_lobby_config = message.lobby_data
		current_lobby_id = message.lobby_data.get("lobby_id", "")
		if message.has("player_id"):
			current_player_id = message.player_id
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_joined.emit(current_lobby_id)
		lobby_config_updated.emit(current_lobby_config)
	elif message.has("data"):
		current_lobby_config = message.data
		current_lobby_id = current_lobby_config.get("lobby_id", "")
		if message.has("player_id"):
			current_player_id = message.player_id
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_joined.emit(current_lobby_id)
		lobby_config_updated.emit(current_lobby_config)

func handle_lobbies_list(lobbies_data):
	if lobbies_data is Array:
		available_lobbies = lobbies_data
		lobbies_updated.emit(available_lobbies)

func handle_lobby_update(lobby_data: Dictionary):
	if lobby_data.get("lobby_id", "") == current_lobby_id:
		current_lobby_config = lobby_data
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_config_updated.emit(current_lobby_config)

func update_all_players(players_list: Array):
	all_players.clear()
	for player in players_list:
		if player.has("id"):
			all_players[player.id] = player

func handle_player_joined(message):
	if message.has("lobby_data"):
		current_lobby_config = message.lobby_data
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_config_updated.emit(current_lobby_config)

func handle_player_left(message):
	if message.has("lobby_data"):
		current_lobby_config = message.lobby_data
		update_all_players(current_lobby_config.get("players_list", []))
		lobby_config_updated.emit(current_lobby_config)

func update_lobby_config(new_config: Dictionary):
	if not is_host or not is_connected_to_server:
		return
	current_lobby_config.merge(new_config)
	lobby_config_updated.emit(current_lobby_config)
	send_config_update_to_server(current_lobby_config)

func send_config_update_to_server(config: Dictionary):
	if not is_connected_to_server:
		return
	var message = {
		"type": "update_lobby",
		"lobby_id": current_lobby_id,
		"data": config
	}
	var message_string = JSON.stringify(message)
	websocket_client.send_text(message_string)

func start_game():
	if not is_host or not is_connected_to_server:
		return
	
	var message = {
		"type": "start_game",
		"lobby_id": current_lobby_id,
		"player_id": current_player_id
	}
	var message_string = JSON.stringify(message)
	websocket_client.send_text(message_string)

func next_round():
	if not is_host or not is_connected_to_server:
		return
	
	var message = {
		"type": "next_round",
		"lobby_id": current_lobby_id,
		"player_id": current_player_id
	}
	var message_string = JSON.stringify(message)
	websocket_client.send_text(message_string)

func trigger_event():
	if not is_host or not is_connected_to_server:
		return
	
	var message = {
		"type": "trigger_event",
		"lobby_id": current_lobby_id,
		"player_id": current_player_id
	}
	var message_string = JSON.stringify(message)
	websocket_client.send_text(message_string)

func get_lobby_display_info() -> Dictionary:
	return {
		"id": current_lobby_config.get("lobby_id", ""),
		"name": current_lobby_config.get("lobby_name", "Unnamed Lobby"),
		"players": str(current_lobby_config.get("current_players", 1)) + "/" +
			(str(current_lobby_config.get("max_participants", 7)) if not current_lobby_config.get("infinite_participants", false) else "∞"),
		"rounds": current_lobby_config.get("rounds", 10),
		"is_public": current_lobby_config.get("is_public", true),
		"host_type": str(current_lobby_config.get("host_type", "auto")).capitalize(),
		"is_connected": is_connected_to_server
	}

func generate_player_id() -> String:
	return str(Time.get_unix_time_from_system()) + "_" + str(randi())

func disconnect_from_server():
	if websocket_client:
		websocket_client.close()
		is_connected_to_server = false

func force_reconnect():
	connection_attempt = 0
	lobby_creation_attempts = 0
	disconnect_from_server()
	call_deferred("connect_to_server")

func get_connection_status() -> String:
	if not websocket_client:
		return "No client"
	match websocket_client.get_ready_state():
		WebSocketPeer.STATE_CONNECTING: return "Connecting..."
		WebSocketPeer.STATE_OPEN: return "Connected"
		WebSocketPeer.STATE_CLOSING: return "Disconnecting..."
		WebSocketPeer.STATE_CLOSED: return "Disconnected"
		_: return "Unknown"

func _exit_tree():
	if reconnect_timer:
		reconnect_timer.queue_free()
	disconnect_from_server()
