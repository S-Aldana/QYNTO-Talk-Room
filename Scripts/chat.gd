extends Control

@onready var chat_container = $ScrollContainer/MarginContainer/VBoxContainer2
@onready var line_edit = $LineEdit
@onready var send_button = $SendMessage
@onready var close_button = $closeChat
@onready var scroll_container = $ScrollContainer

@onready var text_type_1_template = $ScrollContainer/MarginContainer/VBoxContainer2/text_type_1
@onready var text_type_3_template = $ScrollContainer/MarginContainer/VBoxContainer2/text_type_3
@onready var event_template = $ScrollContainer/MarginContainer/VBoxContainer2/event

var is_first_player = false
var has_received_first_message = false
var last_message_count = 0
var message_debug_timer: Timer

func _ready():
	$".".visible = false
	print_lobby_ai_info()
	
	hide_templates()
	
	# Create debug timer to check messages periodically
	message_debug_timer = Timer.new()
	message_debug_timer.wait_time = 2.0
	message_debug_timer.timeout.connect(_check_messages_debug)
	add_child(message_debug_timer)
	message_debug_timer.start()
	
	# Connect signals properly
	send_button.pressed.connect(_on_send_message)
	line_edit.text_submitted.connect(_on_text_submitted)
	close_button.pressed.connect(_on_close_chat_pressed)
	
	# Connect LobbyManager signals
	LobbyManager.lobby_config_updated.connect(_on_lobby_updated)
	LobbyManager.lobby_created.connect(_on_lobby_created)
	LobbyManager.lobby_joined.connect(_on_lobby_joined)

func _check_messages_debug():
	var data = LobbyManager.current_lobby_config
	if not data.is_empty():
		var current_messages = data.get("chat_messages", [])
		print("DEBUG TIMER - Current message count: ", current_messages.size())
		if current_messages.size() > last_message_count:
			print("DEBUG TIMER - New messages detected!")
			_on_lobby_updated(data)

func _on_lobby_created(lobby_id: String):
	print("CHAT DEBUG - Lobby created: ", lobby_id)
	is_first_player = true
	has_received_first_message = false
	last_message_count = 0
	print_lobby_ai_info()

func _on_lobby_joined(lobby_id: String):
	print("CHAT DEBUG - Lobby joined: ", lobby_id)
	is_first_player = false
	has_received_first_message = true
	last_message_count = 0
	print_lobby_ai_info()

func hide_templates():
	text_type_1_template.visible = false
	text_type_3_template.visible = false
	event_template.visible = false

func _on_lobby_updated(lobby_data: Dictionary):
	print("CHAT DEBUG - Lobby updated received")
	
	# Check if we received new chat messages
	var chat_messages = lobby_data.get("chat_messages", [])
	print("CHAT DEBUG - Message count: ", chat_messages.size(), " vs last: ", last_message_count)
	
	if chat_messages.size() != last_message_count:
		print("CHAT DEBUG - Updating chat display with new messages")
		update_chat_display(chat_messages)
		last_message_count = chat_messages.size()
	else:
		print("CHAT DEBUG - No new messages to display")

func update_chat_display(messages: Array):
	print("CHAT DEBUG - Updating display with ", messages.size(), " messages")
	clear_chat_messages()
	
	for i in range(messages.size()):
		var message = messages[i]
		print("CHAT DEBUG - Processing message ", i, ": ", message)
		
		# Skip first system message for lobby creator
		if is_first_player and not has_received_first_message and i == 0:
			var is_system = message.get("is_system", false)
			var sender_id = message.get("player_id", "")
			
			if is_system or sender_id == "system":
				print("CHAT DEBUG - Skipping first system message")
				has_received_first_message = true
				continue
		
		add_message_to_chat(message)
	
	if is_first_player and not has_received_first_message:
		has_received_first_message = true
	
	call_deferred("scroll_to_bottom")

func clear_chat_messages():
	for child in chat_container.get_children():
		if child != text_type_1_template and child != text_type_3_template and child != event_template:
			child.queue_free()

func add_message_to_chat(message_data: Dictionary):
	var sender_id = message_data.get("player_id", "")
	var text = message_data.get("message", "")
	var sender_name = message_data.get("player_name", "Unknown")
	var sender_avatar = message_data.get("player_avatar", "simple_1")
	var is_system = message_data.get("is_system", false)
	var is_ai = message_data.get("is_ai", false)
	
	print("CHAT DEBUG - Adding message: ", text, " from: ", sender_name, " AI: ", is_ai, " System: ", is_system)
	
	var new_message
	
	if is_system or sender_id == "system":
		new_message = create_event_message(text, sender_name)
	elif sender_id == LobbyManager.current_player_id:
		new_message = create_own_message(sender_name, sender_avatar, text)
	else:
		new_message = create_other_message(sender_name, sender_avatar, text, is_ai)
	
	if new_message:
		chat_container.add_child(new_message)
		print("CHAT DEBUG - Message added to chat container")
	else:
		print("CHAT DEBUG - Failed to create message widget")

func create_other_message(sender_name: String, sender_avatar: String, text: String, is_ai: bool = false):
	var message = text_type_1_template.duplicate()
	message.visible = true
	
	message.text = "          " + text
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	var player_icon = message.get_node("PlayerIcon")
	var player_name_label = message.get_node("PlayerName")
	
	if player_icon:
		player_icon.texture = get_avatar_texture(sender_avatar)
	
	if player_name_label:
		var display_name = sender_name
		if is_ai and not sender_name.to_lower().contains("gamemaster"):
			display_name = sender_name + " [AI]"
		elif sender_name.to_lower().contains("gamemaster"):
			display_name = sender_name + " [HOST]"
		
		player_name_label.text = display_name
		
		if is_ai:
			player_name_label.modulate = Color(0.7, 0.9, 1.0)
		elif sender_name.to_lower().contains("gamemaster"):
			player_name_label.modulate = Color(1.0, 0.8, 0.3)
	
	return message

func create_own_message(sender_name: String, sender_avatar: String, text: String):
	var message = text_type_3_template.duplicate()
	message.visible = true
	
	message.text = "" + text + "          "
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	var player_icon = message.get_node("PlayerIcon")
	var player_name_label = message.get_node("PlayerName")
	
	if player_icon:
		player_icon.texture = get_avatar_texture(sender_avatar)
	
	if player_name_label:
		player_name_label.text = sender_name
	
	return message

func create_event_message(text: String, original_name: String = ""):
	var message = event_template.duplicate()
	message.visible = true
	
	message.text = "\n" + text
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var player_name_label = message.get_node("PlayerName")
	var player_name2_label = message.get_node("PlayerName2")
	
	if player_name_label:
		if original_name != "" and original_name != "System":
			if original_name.to_lower().contains("gamemaster"):
				player_name_label.text = original_name + " [HOST]"
				player_name_label.modulate = Color(1.0, 0.8, 0.3)
			else:
				player_name_label.text = original_name
		else:
			player_name_label.text = "GAME EVENT"
			player_name_label.modulate = Color(1.0, 1.0, 0.5)
	
	if player_name2_label:
		player_name2_label.text = ""
	
	return message

func get_avatar_texture(avatar_name: String) -> Texture2D:
	var normalized_name = avatar_name.to_lower()
	
	if avatar_name.begins_with("ai_avatar"):
		normalized_name = "ai_player"
	
	match normalized_name:
		"simple_1": return load("res://Backgrounds/PlayerIcons/SimpleIcon-1.png")
		"simple_2": return load("res://Backgrounds/PlayerIcons/SimpleIcon-2.png")
		"simple_3": return load("res://Backgrounds/PlayerIcons/SimpleIcon-3.png")
		"simple_4": return load("res://Backgrounds/PlayerIcons/SimpleIcon-4.png")
		"simple_5": return load("res://Backgrounds/PlayerIcons/SimpleIcon-5.png")
		"simple_6": return load("res://Backgrounds/PlayerIcons/SimpleIcon-6.png")
		"simple_7": return load("res://Backgrounds/PlayerIcons/SimpleIcon-7.png")
		"epic_1": return load("res://Backgrounds/PlayerIcons/EpicIcon-1.jpg")
		"epic_2": return load("res://Backgrounds/PlayerIcons/EpicIcon-2.png")
		"epic_3": return load("res://Backgrounds/PlayerIcons/EpicIcon-3.png")
		"epic_4": return load("res://Backgrounds/PlayerIcons/EpicIcon-4.png")
		"epic_5": return load("res://Backgrounds/PlayerIcons/EpicIcon-5.png")
		"epic_6": return load("res://Backgrounds/PlayerIcons/EpicIcon-6.png")
		"epic_7": return load("res://Backgrounds/PlayerIcons/EpicIcon-7.png")
		"legendary_1": return load("res://Backgrounds/PlayerIcons/LegendaryIcon-1.jpg")
		"legendary_2": return load("res://Backgrounds/PlayerIcons/LegendaryIcon-2.jpg")
		"legendary_3": return load("res://Backgrounds/PlayerIcons/LegendaryIcon-3.png")
		"legendary_4": return load("res://Backgrounds/PlayerIcons/LegendaryIcon-4.jpg")
		"legendary_5": return load("res://Backgrounds/PlayerIcons/LegendaryIcon-5.jpg")
		"legendary_6": return load("res://Backgrounds/PlayerIcons/LegendaryIcon-6.png")
		"ai_player": return load("res://Backgrounds/PlayerIcons/IAIcon.png")
		"waiting": return load("res://Backgrounds/PlayerIcons/waitingPlayers.png")
		_: return load("res://Backgrounds/PlayerIcons/SimpleIcon-1.png")

func _on_send_message():
	var message_text = line_edit.text.strip_edges()
	if message_text.is_empty():
		return
	
	print("CHAT DEBUG - Attempting to send message: ", message_text)
	
	# Check if we have connection and lobby
	if not LobbyManager.is_connected_to_server:
		print("CHAT DEBUG - Error: Not connected to server")
		return
		
	if LobbyManager.current_lobby_id.is_empty():
		print("CHAT DEBUG - Error: No current lobby")
		return
		
	if LobbyManager.current_player_id.is_empty():
		print("CHAT DEBUG - Error: No player ID")
		return
	
	send_message_to_server(message_text)
	line_edit.text = ""

func _on_text_submitted(text: String):
	_on_send_message()

func send_message_to_server(text: String):
	print("CHAT DEBUG - Sending message: ", text)
	print("CHAT DEBUG - Lobby ID: ", LobbyManager.current_lobby_id)
	print("CHAT DEBUG - Player ID: ", LobbyManager.current_player_id)
	print("CHAT DEBUG - WebSocket state: ", LobbyManager.websocket_client.get_ready_state() if LobbyManager.websocket_client else "null")
	
	var message = {
		"type": "send_chat_message",
		"lobby_id": LobbyManager.current_lobby_id,
		"player_id": LobbyManager.current_player_id,
		"message": text
	}
	
	var message_string = JSON.stringify(message)
	print("CHAT DEBUG - Message JSON: ", message_string)
	
	if LobbyManager.websocket_client and LobbyManager.websocket_client.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var error = LobbyManager.websocket_client.send_text(message_string)
		if error != OK:
			print("CHAT DEBUG - Error sending message: ", error)
		else:
			print("CHAT DEBUG - Message sent successfully, waiting for server response...")
			# Set a timer to check if we get a response
			var response_timer = Timer.new()
			response_timer.wait_time = 5.0
			response_timer.one_shot = true
			response_timer.timeout.connect(func(): 
				print("CHAT DEBUG - No server response received after 5 seconds")
				response_timer.queue_free()
			)
			add_child(response_timer)
			response_timer.start()
	else:
		print("CHAT DEBUG - WebSocket not ready. State: ", LobbyManager.websocket_client.get_ready_state() if LobbyManager.websocket_client else "null")

func scroll_to_bottom():
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _on_chat_button_pressed() -> void:
	$".".visible = true

func _on_close_chat_pressed() -> void:
	$".".visible = false

func print_lobby_ai_info():
	var data = LobbyManager.current_lobby_config
	if data.is_empty():
		print("CHAT DEBUG - No lobby data available.")
		return
	
	print("=== CHAT DEBUG - LOBBY INFO ===")
	print("Lobby Name: ", data.get("lobby_name", "N/A"))
	print("Lobby ID: ", data.get("lobby_id", "N/A"))
	print("Current Player ID: ", LobbyManager.current_player_id)
	print("Connected: ", LobbyManager.is_connected_to_server)
	print("WebSocket State: ", LobbyManager.websocket_client.get_ready_state() if LobbyManager.websocket_client else "null")
	print("Max AI Players: ", data.get("max_ai_players", -1))
	print("Current AI Players: ", data.get("current_ai_players", -1))
	
	var event_by_messages = data.get("event_by_messages", true)
	print("Event Trigger Type: ", "BY MESSAGES" if event_by_messages else "BY TIME")
	
	if event_by_messages:
		var messages_interval = data.get("messages_interval", 12)
		print("Event Trigger Interval: Every ", messages_interval, " messages")
	else:
		var seconds_interval = data.get("seconds_interval", 120)
		print("Event Trigger Interval: Every ", seconds_interval, " seconds")
	
	print("Max Participants: ", data.get("max_participants", 7))
	print("Infinite Participants: ", data.get("infinite_participants", false))
	print("Rounds: ", data.get("rounds", 10))
	
	var ai_players = data.get("ai_players", [])
	print("AI Players in Lobby: ", ai_players.size())
	for ai in ai_players:
		print("-> AI Name: ", ai.get("name", "???"), ", Avatar: ", ai.get("avatar", "???"), ", ID: ", ai.get("id", "???"))
	
	var chat_messages = data.get("chat_messages", [])
	print("Chat Messages Count: ", chat_messages.size())
	
	if chat_messages.size() > 0:
		print("Recent chat messages:")
		for i in range(min(3, chat_messages.size())):
			var msg = chat_messages[chat_messages.size() - 1 - i]
			print("  -> ", msg.get("player_name", "???"), ": ", msg.get("message", "???"))
	
	print("=== END LOBBY INFO ===")
func _exit_tree():
	if message_debug_timer:
		message_debug_timer.queue_free()
