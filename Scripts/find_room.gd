extends Panel

@onready var scroll_container = $ScrollContainer
@onready var vbox_container = $ScrollContainer/VBoxContainer

var created_lobbies_cache = {}
var refresh_timer: Timer
var refresh_interval = 5.0
var room_template
var active_room_nodes = {}
var is_refreshing = false

func _ready() -> void:
	room_template = $ScrollContainer/VBoxContainer/Room
	if room_template: room_template.visible = false
	visible = false
	setup_refresh_timer()
	
	LobbyManager.lobbies_updated.connect(_on_lobbies_updated)
	LobbyManager.lobby_config_updated.connect(_on_lobby_updated)
	LobbyManager.websocket_connected.connect(_on_websocket_connected)
	LobbyManager.lobby_created.connect(_on_lobby_created)

func _on_websocket_connected():
	if visible: request_lobbies_safely()

func _on_lobbies_updated(lobbies: Array):
	is_refreshing = false
	
	var valid_lobby_ids = {}
	for lobby_data in lobbies:
		var lobby_id = lobby_data.get("id", lobby_data.get("lobby_id", ""))
		if lobby_id != "":
			valid_lobby_ids[lobby_id] = true
	
	var nodes_to_remove = []
	for lobby_id in active_room_nodes.keys():
		if lobby_id not in valid_lobby_ids:
			nodes_to_remove.append(lobby_id)
	
	for lobby_id in nodes_to_remove:
		if active_room_nodes.has(lobby_id) and active_room_nodes[lobby_id] and active_room_nodes[lobby_id].is_inside_tree():
			active_room_nodes[lobby_id].queue_free()
		active_room_nodes.erase(lobby_id)
		if lobby_id in created_lobbies_cache:
			created_lobbies_cache.erase(lobby_id)
	
	for lobby_data in lobbies:
		var lobby_id = lobby_data.get("id", lobby_data.get("lobby_id", ""))
		if lobby_id != "":
			if lobby_id in active_room_nodes and active_room_nodes[lobby_id] and active_room_nodes[lobby_id].is_inside_tree():
				update_room_node(active_room_nodes[lobby_id], lobby_data)
			else:
				create_lobby_room_node(lobby_data)

func _on_lobby_updated(lobby_data: Dictionary):
	var lobby_id = lobby_data.get("id", lobby_data.get("lobby_id", ""))
	if lobby_id in active_room_nodes and active_room_nodes[lobby_id] and active_room_nodes[lobby_id].is_inside_tree():
		update_room_node(active_room_nodes[lobby_id], lobby_data)

func clear_lobby_list():
	var children_to_remove = []
	for child in vbox_container.get_children():
		if child != room_template and child.is_inside_tree():
			children_to_remove.append(child)
	for child in children_to_remove:
		child.queue_free()
	active_room_nodes.clear()

func create_lobby_room_node(lobby_data: Dictionary):
	var lobby_id = lobby_data.get("id", lobby_data.get("lobby_id", ""))
	if lobby_id == "" or not room_template: return
	var room_node = room_template.duplicate(true)
	if not room_node: return
	room_node.visible = true
	room_node.name = "Room_" + lobby_id
	active_room_nodes[lobby_id] = room_node
	setup_room_node(room_node, lobby_data)
	vbox_container.add_child(room_node)

func setup_room_node(room_node: Control, lobby_data: Dictionary):
	var room_content = room_node.get_node_or_null("RoomContent")
	if not room_content: return
	var room_header = room_content.get_node_or_null("RoomHeader")
	if not room_header: return
	
	var public_private = room_header.get_node_or_null("PublicOrPrivate")
	if public_private:
		var is_public = lobby_data.get("is_public", true)
		public_private.text = "Public" if is_public else "Private"
		public_private.modulate = Color.GREEN if is_public else Color.RED
	
	var ia_players = room_header.get_node_or_null("IAPlayers")
	if ia_players:
		var max_players = lobby_data.get("max_players", lobby_data.get("max_participants", 7))
		var max_human_players = lobby_data.get("max_human_players", 4)
		var max_ai_players = lobby_data.get("max_ai_players", 0)
		var infinite_participants = lobby_data.get("infinite_participants", false)
		var ai_count = max_ai_players if infinite_participants else max(0, max_players - max_human_players)
		ia_players.text = "AI Players: " + str(ai_count)
	
	var host_type = room_header.get_node_or_null("HostType")
	if host_type:
		var host_type_value = lobby_data.get("host_type", "auto")
		host_type.text = "HOST TYPE: " + host_type_value.capitalize()
	
	var current_players = room_content.get_node_or_null("currentPlayers")
	if current_players:
		var current_count = get_total_player_count(lobby_data)
		var max_count = lobby_data.get("max_players", lobby_data.get("max_participants", 7))
		var infinite_participants = lobby_data.get("infinite_participants", false)
		current_players.text = str(current_count) + "/" + ("∞" if infinite_participants else str(max_count))
		
		print("=== PLAYER COUNT DEBUG ===")
		print("Lobby ID: ", lobby_data.get("lobby_id", "unknown"))
		print("Current count calculated: ", current_count)
		print("Max count: ", max_count)
		print("Final display: ", current_players.text)
		print("Players list size: ", lobby_data.get("players_list", []).size())
		print("Current players field: ", lobby_data.get("current_players", "not found"))
		print("Total players field: ", lobby_data.get("total_players", "not found"))
		print("Human players: ", lobby_data.get("human_players", []).size())
		print("AI players: ", lobby_data.get("ai_players", []).size())
		print("=== END DEBUG ===")

	var join_button = room_content.get_node_or_null("JoinButton")
	if join_button:
		var lobby_id = lobby_data.get("id", lobby_data.get("lobby_id", ""))
		var is_public = lobby_data.get("is_public", true)
		for connection in join_button.pressed.get_connections():
			join_button.pressed.disconnect(connection.callable)
		join_button.pressed.connect(_on_join_lobby_pressed.bind(lobby_id, is_public))
	
	setup_player_icons(room_node, lobby_data)

func get_total_player_count(lobby_data: Dictionary) -> int:
	if lobby_data.has("total_players"):
		return lobby_data.get("total_players", 0)
	
	if lobby_data.has("players_list"):
		return lobby_data.get("players_list", []).size()
	
	var human_count = 0
	var ai_count = 0
	
	if lobby_data.has("human_players"):
		human_count = lobby_data.get("human_players", []).size()
	elif lobby_data.has("current_players"):
		human_count = lobby_data.get("current_players", 0)
	
	if lobby_data.has("ai_players"):
		ai_count = lobby_data.get("ai_players", []).size()
	elif lobby_data.has("current_ai_players"):
		ai_count = lobby_data.get("current_ai_players", 0)
	
	return human_count + ai_count

func setup_player_icons(room_node: Control, lobby_data: Dictionary):
	var room_content = room_node.get_node_or_null("RoomContent")
	if not room_content:
		return
	var vbox_container_node = room_content.get_node_or_null("VBoxContainer")
	if not vbox_container_node:
		return
	var original_players_lobby = vbox_container_node.get_node_or_null("PlayersInLobby")
	if not original_players_lobby:
		return

	var line_decoration = vbox_container_node.get_node_or_null("LineDecorations")
	var line_decoration_index = -1
	if line_decoration:
		line_decoration_index = line_decoration.get_index()

	var children_to_remove = []
	for child in vbox_container_node.get_children():
		if child.name.begins_with("PlayersInLobby") and child != original_players_lobby:
			children_to_remove.append(child)
	for child in children_to_remove:
		child.queue_free()

	var players_list = lobby_data.get("players_list", [])
	var max_players = lobby_data.get("max_players", lobby_data.get("max_participants", 7))
	var max_ai_players = lobby_data.get("max_ai_players", 0)
	var infinite_participants = lobby_data.get("infinite_participants", false)
	
	var display_total = max_players
	if infinite_participants:
		display_total = max(players_list.size() + 2, max_players)
	
	var players_per_row = 7
	var rows_needed = ceil(float(display_total) / float(players_per_row))

	for row in range(rows_needed):
		var players_in_lobby
		if row == 0:
			players_in_lobby = original_players_lobby
		else:
			players_in_lobby = original_players_lobby.duplicate()
			players_in_lobby.name = "PlayersInLobby" + str(row + 1)
			if line_decoration_index != -1:
				var insert_index = original_players_lobby.get_index() + row
				vbox_container_node.add_child(players_in_lobby)
				vbox_container_node.move_child(players_in_lobby, min(insert_index, line_decoration_index))
			else:
				vbox_container_node.add_child(players_in_lobby)

		var hbox_container = players_in_lobby.get_node_or_null("HBoxContainer")
		if not hbox_container:
			continue
		var icons_in_this_row = min(players_per_row, display_total - (row * players_per_row))
		var all_icons = []
		for child in hbox_container.get_children():
			if child.name.begins_with("RowIcon_"):
				all_icons.append(child)
		all_icons.sort_custom(func(a, b): return a.name < b.name)
		for i in range(all_icons.size()):
			var icon = all_icons[i]
			if i < icons_in_this_row:
				var player_index = (row * players_per_row) + i
				if player_index < players_list.size():
					var avatar_name = get_player_avatar_name(player_index, lobby_data)
					icon.texture = get_avatar_texture(avatar_name)
				else:
					icon.texture = get_avatar_texture("waiting")
				icon.visible = true
			else:
				icon.visible = false
	var base_lines = 1
	var total_lines = base_lines + max(0, rows_needed - 1) * 2
	var filler = "\n".repeat(total_lines)
	var original_text = "
	
	
	
	
	
	
	"
	$ScrollContainer/VBoxContainer/Room.text = original_text + filler

func get_player_avatar_name(player_index: int, lobby_data: Dictionary) -> String:
	var players_list = lobby_data.get("players_list", [])
	if player_index < players_list.size() and players_list[player_index].has("avatar"):
		return players_list[player_index]["avatar"]
	return "simple_1"

func get_avatar_texture(avatar_name: String) -> Texture2D:
	var normalized_name = avatar_name.to_lower()
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

func setup_refresh_timer():
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 2.0
	refresh_timer.timeout.connect(_on_refresh_timer_timeout)
	add_child(refresh_timer)

func _on_refresh_timer_timeout():
	if visible and LobbyManager.is_connected_to_server:
		request_lobbies_safely()

func request_lobbies_safely():
	if not is_refreshing:
		is_refreshing = true
		LobbyManager.request_lobbies_list()

func _on_find_room_button_pressed() -> void:
	visible = true
	$"../MenuBtn".visible = false
	$"../MenuBtn2".visible = false
	$"../MenuBtn3".visible = false
	$"../MenuButtons".visible = false
	$"../QyntOtitle".visible = false
	Player.play_button_sound()
	if LobbyManager.is_connected_to_server:
		request_lobbies_safely()
		refresh_timer.start()

func _on_close_find_room_button_pressed() -> void:
	visible = false
	refresh_timer.stop()
	is_refreshing = false
	$"../MenuButtons".visible = true
	$"../MenuBtn".visible = true
	$"../MenuBtn2".visible = true
	$"../MenuBtn3".visible = true
	$"../QyntOtitle".visible = true
	Player.play_button_sound()

func _on_lobby_created(lobby_id: String):
	created_lobbies_cache[lobby_id] = {
		"creator": Player.get_player_data(),
		"created_by_us": true
	}

func update_room_node(room_node: Control, lobby_data: Dictionary):
	setup_room_node(room_node, lobby_data)

func _on_join_lobby_pressed(lobby_id: String, is_public: bool):
	if not is_public:
		return
	if LobbyManager.join_lobby(lobby_id):
		var change_scene = load("res://Scenes/Room.tscn")
		get_tree().change_scene_to_packed(change_scene)
	Player.play_button_sound()
