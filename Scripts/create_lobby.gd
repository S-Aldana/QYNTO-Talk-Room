extends Panel

# UI
@onready var rounds_spinbox = $lobbySettings/SpinBox
@onready var public_room_btn = $lobbySettings/publicBtn
@onready var max_participants_spinbox = $lobbySettings/maxParticipants2
@onready var infinity_button = $lobbySettings/InfinityButton
@onready var infinity_texture = $lobbySettings/InfinityButton/TextureRect
@onready var max_human_spinbox = $lobbySettings/maxHumanPlayers
@onready var max_ai_spinbox = $lobbySettings/maxAiPlayers2
@onready var max_human_label = $lobbySettings/maxHumanParticipants
@onready var max_ai_label = $lobbySettings/maxAiParticipants2
@onready var messages_checkbox = $lobbySettings2/Panel/CheckButton2
@onready var seconds_checkbox = $lobbySettings2/Panel/CheckButton
@onready var messages_spinbox = $lobbySettings2/Panel/SpinBox
@onready var seconds_spinbox = $lobbySettings2/Panel/SpinBox2
@onready var auto_host_btn = $lobbySettings2/autoHostBtn
@onready var choose_host_btn = $lobbySettings2/chooseHostBtn
@onready var mystery_host_btn = $lobbySettings2/mysteryHostBtn
@onready var description = $Description
@onready var description2 = $Description2

# CONFIG
var lobby_config = {
	"rounds": 10,
	"is_public": true,
	"max_participants": 7,
	"infinite_participants": false,
	"max_human_players": 4,
	"max_ai_players": 3,
	"current_ai_players": 3,
	"event_by_messages": true,
	"messages_interval": 12,
	"seconds_interval": 120,
	"host_type": "auto",
	"lobby_name": "Mi Lobby"
}

# READY
func _ready() -> void:
	$".".visible = false
	setup_default_values()
	connect_signals()
	setup_descriptions()

# UI DEFAULTS
func setup_default_values():
	rounds_spinbox.value = lobby_config.rounds
	rounds_spinbox.min_value = 4
	rounds_spinbox.max_value = 20
	max_participants_spinbox.value = lobby_config.max_participants
	max_participants_spinbox.min_value = 2
	max_participants_spinbox.max_value = 20
	max_human_spinbox.value = lobby_config.max_human_players
	max_human_spinbox.min_value = 1
	max_human_spinbox.max_value = lobby_config.max_participants
	max_ai_spinbox.value = lobby_config.max_ai_players
	max_ai_spinbox.min_value = 0
	max_ai_spinbox.max_value = 10
	messages_checkbox.button_pressed = lobby_config.event_by_messages
	seconds_checkbox.button_pressed = false
	messages_spinbox.value = lobby_config.messages_interval
	messages_spinbox.min_value = 5
	messages_spinbox.max_value = 50
	seconds_spinbox.value = lobby_config.seconds_interval
	seconds_spinbox.min_value = 15
	seconds_spinbox.max_value = 300
	update_public_room_button()
	update_infinity_button()
	update_ai_values()
	choose_host_btn.disabled = true
	mystery_host_btn.disabled = true

# SIGNALS
func connect_signals():
	public_room_btn.pressed.connect(_on_public_room_toggled)
	infinity_button.pressed.connect(_on_infinity_button_pressed)
	rounds_spinbox.value_changed.connect(_on_rounds_changed)
	max_participants_spinbox.value_changed.connect(_on_max_participants_changed)
	max_human_spinbox.value_changed.connect(_on_max_human_changed)
	max_ai_spinbox.value_changed.connect(_on_max_ai_changed)
	messages_checkbox.toggled.connect(_on_messages_checkbox_toggled)
	seconds_checkbox.toggled.connect(_on_seconds_checkbox_toggled)
	messages_spinbox.value_changed.connect(_on_messages_interval_changed)
	seconds_spinbox.value_changed.connect(_on_seconds_interval_changed)
	auto_host_btn.pressed.connect(_on_auto_host_pressed)

# UI DESCRIPTIONS
func setup_descriptions():
	description.visible = true
	description2.visible = false
	rounds_spinbox.mouse_entered.connect(_show_lobby_description)
	public_room_btn.mouse_entered.connect(_show_lobby_description)
	max_participants_spinbox.mouse_entered.connect(_show_lobby_description)
	infinity_button.mouse_entered.connect(_show_lobby_description)
	max_human_spinbox.mouse_entered.connect(_show_lobby_description)
	max_ai_spinbox.mouse_entered.connect(_show_lobby_description)
	messages_checkbox.mouse_entered.connect(_show_events_description)
	seconds_checkbox.mouse_entered.connect(_show_events_description)
	messages_spinbox.mouse_entered.connect(_show_events_description)
	seconds_spinbox.mouse_entered.connect(_show_events_description)
	auto_host_btn.mouse_entered.connect(_show_events_description)
	choose_host_btn.mouse_entered.connect(_show_events_description)
	mystery_host_btn.mouse_entered.connect(_show_events_description)

func _show_lobby_description():
	description.visible = true
	description2.visible = false

func _show_events_description():
	description.visible = false
	description2.visible = true

# UI TOGGLES
func _on_public_room_toggled():
	lobby_config.is_public = !lobby_config.is_public
	update_public_room_button()
	Player.play_button_sound()

func _on_infinity_button_pressed():
	lobby_config.infinite_participants = !lobby_config.infinite_participants
	update_infinity_button()
	update_ai_values()
	Player.play_button_sound()

# UI CHANGES
func _on_rounds_changed(value): 
	lobby_config.rounds = int(value)

func _on_max_participants_changed(value): 
	lobby_config.max_participants = int(value)
	update_participant_limits()
	update_ai_values()

func _on_max_human_changed(value): 
	lobby_config.max_human_players = int(value)
	update_ai_values()

func _on_max_ai_changed(value): 
	lobby_config.max_ai_players = int(value)
	lobby_config.current_ai_players = int(value)

func _on_messages_checkbox_toggled(pressed):
	if pressed:
		lobby_config.event_by_messages = true
		seconds_checkbox.button_pressed = false
		messages_spinbox.editable = true
		seconds_spinbox.editable = false

func _on_seconds_checkbox_toggled(pressed):
	if pressed:
		lobby_config.event_by_messages = false
		messages_checkbox.button_pressed = false
		seconds_spinbox.editable = true
		messages_spinbox.editable = false

func _on_messages_interval_changed(value): 
	lobby_config.messages_interval = int(value)

func _on_seconds_interval_changed(value): 
	lobby_config.seconds_interval = int(value)

func _on_auto_host_pressed():
	lobby_config.host_type = "auto"
	update_host_buttons()
	Player.play_button_sound()

# UI UPDATE BUTTONS
func update_public_room_button():
	if lobby_config.is_public:
		public_room_btn.icon = load("res://Backgrounds/Imgs/CheckBtn_1.png")
	else:
		public_room_btn.icon = load("res://Backgrounds/Imgs/CheckBtn_2.png")

func update_infinity_button():
	if lobby_config.infinite_participants:
		infinity_texture.texture = load("res://Backgrounds/Imgs/infinity.png")
		max_participants_spinbox.editable = false
		max_human_spinbox.visible = false
		max_human_label.visible = false
		max_ai_spinbox.visible = true
		max_ai_label.visible = true
	else:
		infinity_texture.texture = load("res://Backgrounds/Imgs/infinityDisabled.png")
		max_participants_spinbox.editable = true
		max_human_spinbox.visible = true
		max_human_label.visible = true
		max_ai_spinbox.visible = false
		max_ai_label.visible = false

func update_participant_limits():
	if not lobby_config.infinite_participants:
		max_human_spinbox.max_value = lobby_config.max_participants
		if max_human_spinbox.value > lobby_config.max_participants:
			max_human_spinbox.value = lobby_config.max_participants
			lobby_config.max_human_players = lobby_config.max_participants

func update_ai_values():
	if not lobby_config.infinite_participants:
		var calculated_ai = lobby_config.max_participants - lobby_config.max_human_players
		calculated_ai = max(0, calculated_ai)
		lobby_config.max_ai_players = calculated_ai
		lobby_config.current_ai_players = calculated_ai
		max_ai_spinbox.value = calculated_ai

func update_host_buttons():
	auto_host_btn.modulate = Color.WHITE
	choose_host_btn.modulate = Color.GRAY
	mystery_host_btn.modulate = Color.GRAY
	match lobby_config.host_type:
		"auto": auto_host_btn.modulate = Color.YELLOW
		"choose": choose_host_btn.modulate = Color.YELLOW
		"mystery": mystery_host_btn.modulate = Color.YELLOW

# UI NAVIGATION
func _on_close_create_pressed() -> void:
	$".".visible = false
	$"../MenuBtn".visible = true
	$"../MenuBtn2".visible = true
	$"../MenuBtn3".visible = true
	$"../MenuButtons".visible = true
	$"../QyntOtitle".visible = true
	Player.play_button_sound()

func _on_create_room_button_pressed() -> void:
	$".".visible = true
	$"../MenuBtn".visible = false
	$"../MenuBtn2".visible = false
	$"../MenuBtn3".visible = false
	$"../MenuButtons".visible = false
	$"../QyntOtitle".visible = false
	Player.play_button_sound()

# CREATE LOBBY
func _on_create_button_pressed() -> void:
	save_lobby_config()
	LobbyManager.current_lobby_config = get_lobby_config()
	var lobby_id = LobbyManager._create_lobby_now()
	if lobby_id != "":
		var change_scene = load("res://Scenes/Room.tscn")
		get_tree().change_scene_to_packed(change_scene)
	else:
		$".".visible = false
		$"../MenuBtn".visible = true
		$"../MenuBtn2".visible = true
		$"../MenuBtn3".visible = true
		$"../MenuButtons".visible = true
		$"../QyntOtitle".visible = true
	Player.play_button_sound()

func save_lobby_config():
	if lobby_config.lobby_name == "Mi Lobby":
		lobby_config.lobby_name = "Lobby_" + str(Time.get_unix_time_from_system())

func get_lobby_config() -> Dictionary:
	return lobby_config.duplicate()
