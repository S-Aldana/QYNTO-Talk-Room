extends Control

var current_page = 1
var total_pages = 5

func _ready():
	$tutorial.visible = false
	$tutorial/video/next.pressed.connect(_on_next_pressed)
	$tutorial/video/back.pressed.connect(_on_back_pressed)
	update_tutorial_pages()
	if Player.needs_name_setup():
		$MenuButtons/FindRoomButton.disabled = true
		$MenuButtons/CreateRoomButton.disabled = true
	else:
		$MenuButtons/FindRoomButton.disabled = false
		$MenuButtons/CreateRoomButton.disabled = false
	if Player.to_shop == true:
		$ShopPanel.visible = true
	LobbyManager.websocket_connected.connect(_on_ws_connected)
	LobbyManager.websocket_disconnected.connect(_on_ws_disconnected)
	LobbyManager.websocket_error.connect(_on_ws_error)
	LobbyManager.connection_failed.connect(_on_ws_failed)
	update_connection_status("Conectando...")
	await get_tree().create_timer(0.5).timeout

func update_ui_state():
	var can_use_lobby = not Player.needs_name_setup() and LobbyManager.is_connected_to_server
	$MenuButtons/FindRoomButton.disabled = not can_use_lobby
	$MenuButtons/CreateRoomButton.disabled = not can_use_lobby

func _on_ws_connected():
	update_connection_status("✅ Conectado")
	update_ui_state()

func _on_ws_disconnected():
	update_connection_status("❌ Desconectado")
	update_ui_state()

func _on_ws_error():
	update_connection_status("⚠️ Error de conexión")
	update_ui_state()

func _on_ws_failed():
	update_connection_status("❌ Conexión fallida")
	update_ui_state()
	
func update_connection_status(text: String):
	$ConnectionStatus.text = text

func _on_settings_button_pressed():
	Player.play_button_sound()
	var change_scene = load("res://Scenes/settings_menu.tscn")
	get_tree().change_scene_to_packed(change_scene)

func _on_reset_player_button_pressed():
	Player.reset_player_data()

func _on_tutorial_button_pressed() -> void:
	Player.play_button_sound()
	_hide_menu_elements()
	$tutorial.visible = true
	
	if Player.user_name == "user":
		$tutorial/alert.visible = true
		$tutorial/video.visible = false
	else:
		$tutorial/alert.visible = false
		$tutorial/video.visible = true

func _on_save_name_pressed() -> void:
	if $tutorial/alert/LineEdit and $tutorial/alert/LineEdit.text.strip_edges() != "":
		var new_name = $tutorial/alert/LineEdit.text.strip_edges()
		Player.set_user_name(new_name)
		Player.play_button_sound()
		
		$tutorial/alert.visible = false
		$tutorial/video.visible = true
		
		if LobbyManager.is_connected_to_server:
			$MenuButtons/FindRoomButton.disabled = false
			$MenuButtons/CreateRoomButton.disabled = false
		
func _hide_menu_elements():
	$"MenuBtn".visible = false
	$"MenuBtn2".visible = false
	$"MenuBtn3".visible = false
	$"MenuButtons".visible = false
	$"QyntOtitle".visible = false
	$StoreButton.visible = false
	$SettingsButton.visible = false

func _show_menu_elements():
	$"MenuBtn".visible = true
	$"MenuBtn2".visible = true
	$"MenuBtn3".visible = true
	$"MenuButtons".visible = true
	$"QyntOtitle".visible = true
	$StoreButton.visible = true
	$SettingsButton.visible = true

func _on_close_tutorial_pressed() -> void:
	Player.play_button_sound()
	$tutorial.visible = false
	_show_menu_elements()
	if LobbyManager.is_connected_to_server and not Player.needs_name_setup():
		$MenuButtons/FindRoomButton.disabled = false
		$MenuButtons/CreateRoomButton.disabled = false

func _on_next_pressed():
	if current_page < total_pages:
		current_page += 1
		update_tutorial_pages()

func _on_back_pressed():
	if current_page > 1:
		current_page -= 1
		update_tutorial_pages()

func update_tutorial_pages():
	for i in range(1, total_pages + 1):
		var page = $tutorial/video.get_node("tutorial" + str(i))
		page.visible = (i == current_page)
