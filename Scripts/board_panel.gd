extends Control

@onready var human_players_label = $gameRulesContent/ScrollContainer/VBoxContainer/Label
@onready var ai_players_label = $gameRulesContent/ScrollContainer2/VBoxContainer/Label
@onready var events_label = $EventsContent/ScrollContainer/VBoxContainer/Label
@onready var next_event_label = $EventsContent/nextEvent
@onready var host_type_label = $EventsContent/HostType
@onready var rounds_label = $gameRulesContent/rounds

var current_lobby_data: Dictionary = {}
var update_timer: Timer

func _ready():
	$".".visible = false
	$options/Line3.visible = false
	$EventsContent.visible = false
	$gameRulesContent.visible = true
	
	setup_update_timer()
	
	LobbyManager.lobby_config_updated.connect(_on_lobby_updated)
	update_board_info(LobbyManager.current_lobby_config)

func setup_update_timer():
	update_timer = Timer.new()
	update_timer.wait_time = 1.0
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)
	update_timer.start()

func _on_update_timer_timeout():
	if current_lobby_data.size() > 0:
		update_events_info(current_lobby_data)

func _on_lobby_updated(lobby_data: Dictionary):
	current_lobby_data = lobby_data
	update_board_info(lobby_data)

func update_board_info(lobby_data: Dictionary):
	current_lobby_data = lobby_data
	update_players_info(lobby_data)
	update_events_info(lobby_data)
	update_rounds_info(lobby_data)
	update_host_type(lobby_data)

func update_players_info(lobby_data: Dictionary):
	var human_text = ""
	var ai_text = ""
	
	var players_list = lobby_data.get("players_list", [])
	for player in players_list:
		if player.has("name"):
			if player.get("is_ai", false):
				ai_text += player.name + "\n"
			else:
				human_text += player.name + "\n"
	
	human_players_label.text = human_text
	ai_players_label.text = ai_text

func update_events_info(lobby_data: Dictionary):
	var events_history = lobby_data.get("events_history", [])
	var events_text = ""
	
	var recent_events = events_history.slice(max(0, events_history.size() - 5))
	for event in recent_events:
		events_text += "• " + event.get("text", "") + "\n"
	
	events_label.text = events_text
	
	update_next_event_display(lobby_data)

func update_next_event_display(lobby_data: Dictionary):
	var current_event = lobby_data.get("current_event", null)
	var event_active = lobby_data.get("event_active", false)
	var has_active_event = (current_event != null and not current_event.get("resolved", true)) or event_active
	
	if has_active_event:
		next_event_label.text = "Event in progress"
		return
	
	var event_by_messages = lobby_data.get("event_by_messages", true)
	
	if event_by_messages:
		var message_count_since_event = lobby_data.get("message_count_since_event", 0)
		var messages_interval = lobby_data.get("messages_interval", 5)
		var remaining = max(0, messages_interval - message_count_since_event)
		next_event_label.text = "Next event: " + str(remaining) + " messages"
	else:
		var last_event_time = lobby_data.get("last_event_time", 0)
		var seconds_interval = lobby_data.get("seconds_interval", 120)
		
		if last_event_time > 0:
			var current_time = Time.get_unix_time_from_system() * 1000
			var time_elapsed = (current_time - last_event_time) / 1000.0
			var remaining_seconds = max(0, seconds_interval - time_elapsed)
			
			var minutes = int(remaining_seconds) / 60
			var seconds = int(remaining_seconds) % 60
			var time_str = str(minutes) + ":" + str(seconds).pad_zeros(2)
			next_event_label.text = "Next event: " + time_str
		else:
			var next_event_in = lobby_data.get("next_event_in", seconds_interval)
			var minutes = int(next_event_in) / 60
			var seconds = int(next_event_in) % 60
			var time_str = str(minutes) + ":" + str(seconds).pad_zeros(2)
			next_event_label.text = "Next event: " + time_str

func update_rounds_info(lobby_data: Dictionary):
	var current_round = lobby_data.get("current_round", 1)
	var max_rounds = lobby_data.get("max_rounds", 10)
	rounds_label.text = "Rounds: " + str(current_round) + " / " + str(max_rounds)

func update_host_type(lobby_data: Dictionary):
	var host_type = lobby_data.get("host_type", "auto")
	host_type_label.text = "Host Type: " + host_type.capitalize()

func _on_board_button_pressed() -> void:
	$".".visible = true

func _on_button_pressed() -> void:
	$".".visible = false

func _on_game_rules_pressed() -> void:
	$gameRulesContent.visible = true
	$EventsContent.visible = false
	$options/Line2.visible = true
	$options/Line3.visible = false

func _on_events_pressed() -> void:
	$gameRulesContent.visible = false
	$EventsContent.visible = true
	$options/Line2.visible = false
	$options/Line3.visible = true

func _exit_tree():
	if update_timer:
		update_timer.queue_free()
