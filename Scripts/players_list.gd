extends Control

@onready var player_list_container = $PlayerList
@onready var prev_button = $BackArrowButton
@onready var next_button = $NextArrowButton
@onready var prev_arrow_img = $BackArrowButton/ArrowImg
@onready var prev_disabled_img = $BackArrowButton/DisabledArrowImg
@onready var next_arrow_img = $NextArrowButton/ArrowImg
@onready var next_disabled_img = $NextArrowButton/DisabledArrowImg
@onready var players_number_label = $PlayersNumber

var all_players = []
var current_page = 0
var players_per_page = 4
var total_pages = 0
var player_panels = []

func _ready():
	$".".visible = false
	LobbyManager.lobby_config_updated.connect(_on_lobby_updated)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
	collect_player_panels()
	update_players_list(LobbyManager.current_lobby_config)

func _on_lobby_updated(lobby_data: Dictionary):
	update_players_list(lobby_data)

func collect_player_panels():
	player_panels.clear()
	for child in player_list_container.get_children():
		if child.name.begins_with("PlayerPanel"):
			player_panels.append(child)

func update_players_list(lobby_data: Dictionary):
	all_players.clear()
	
	var players_list = lobby_data.get("players_list", [])
	for player in players_list:
		all_players.append({
			"name": player.get("name", "Unknown"),
			"avatar": player.get("avatar", "simple_1"),
			"points": player.get("points", 0),
			"is_ai": player.get("is_ai", false)
		})
	
	players_number_label.text = "NUMBER OF PLAYERS: " + str(all_players.size())
	calculate_pages()
	update_display()

func calculate_pages():
	total_pages = max(1, ceil(float(all_players.size()) / players_per_page))
	current_page = min(current_page, total_pages - 1)

func update_display():
	hide_all_panels()
	
	var start_index = current_page * players_per_page
	var end_index = min(start_index + players_per_page, all_players.size())
	
	for i in range(start_index, end_index):
		var panel_index = i - start_index
		if panel_index < player_panels.size():
			var panel = player_panels[panel_index]
			setup_player_panel(panel, all_players[i])
			panel.visible = true
	
	update_navigation()

func hide_all_panels():
	for panel in player_panels:
		panel.visible = false

func setup_player_panel(panel: Panel, player_data: Dictionary):
	var name_label = panel.get_node("PlayerName")
	var points_label = panel.get_node("PlayerPts")
	var avatar_texture = panel.get_node("PlayerIcon")
	
	name_label.text = player_data.name
	points_label.text = str(player_data.points)
	avatar_texture.texture = get_avatar_texture(player_data.avatar)

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

func update_navigation():
	var is_first_page = (current_page <= 0)
	var is_last_page = (current_page >= total_pages - 1)
	
	prev_button.disabled = is_first_page
	next_button.disabled = is_last_page
	
	prev_arrow_img.visible = not is_first_page
	prev_disabled_img.visible = is_first_page
	next_arrow_img.visible = not is_last_page
	next_disabled_img.visible = is_last_page

func _on_prev_pressed():
	if current_page > 0:
		current_page -= 1
		update_display()

func _on_next_pressed():
	if current_page < total_pages - 1:
		current_page += 1
		update_display()

func _on_poster_button_pressed() -> void:
	$".".visible = true

func _on_close_button_pressed() -> void:
	$".".visible = false
