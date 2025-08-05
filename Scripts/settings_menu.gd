extends Control

@onready var master_slider: HSlider = $Volumen/VBoxContainer/VBoxContainer/HSlider
@onready var music_slider: HSlider = $Volumen/VBoxContainer/VBoxContainer2/HSlider
@onready var fx_slider: HSlider = $Volumen/VBoxContainer/VBoxContainer3/HSlider
@onready var master_label: Label = $Volumen/VBoxContainer/VBoxContainer/Label
@onready var music_label: Label = $Volumen/VBoxContainer/VBoxContainer2/Label
@onready var fx_label: Label = $Volumen/VBoxContainer/VBoxContainer3/Label
@onready var avatar_texture: TextureRect = $User/TextureRect

func _ready():
	$alert.visible = false
	$User/name.text = Player.user_name
	update_avatar_display()
	setup_sliders()
	await get_tree().process_frame
	load_current_volumes()
	connect_signals()

func update_avatar_display():
	if avatar_texture:
		var icon_id = Player.avatar
		var parts = icon_id.split("_")
		var rarity = parts[0]
		var number = int(parts[1])
		
		var file_extension = get_icon_file_extension(icon_id)
		var icon_name = get_icon_name(rarity, number)
		var texture_path = "res://Backgrounds/PlayerIcons/" + icon_name + file_extension
		var texture = load(texture_path)
		
		if texture:
			avatar_texture.texture = texture

func get_icon_file_extension(icon_id: String) -> String:
	var parts = icon_id.split("_")
	var rarity = parts[0]
	var number = int(parts[1])
	
	if rarity == "simple":
		return ".png"
	elif rarity == "epic":
		return ".jpg" if number == 1 else ".png"
	elif rarity == "legendary":
		return ".jpg" if (number == 1 or number == 2 or number == 4 or number == 5) else ".png"
	
	return ".png"

func get_icon_name(rarity: String, number: int) -> String:
	match rarity:
		"simple":
			return "SimpleIcon-" + str(number)
		"epic":
			return "EpicIcon-" + str(number)
		"legendary":
			return "LegendaryIcon-" + str(number)
		_:
			return "SimpleIcon-" + str(number)

func setup_sliders():
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.01
	
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.01
	
	fx_slider.min_value = 0.0
	fx_slider.max_value = 1.0
	fx_slider.step = 0.01

func load_current_volumes():
	master_slider.value = Player.volume_master
	music_slider.value = Player.volume_music
	fx_slider.value = Player.volume_fx
	
	Player.volume_master = Player._volume_master
	Player.volume_music = Player._volume_music
	Player.volume_fx = Player._volume_fx
	
	update_volume_labels()

func connect_signals():
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	fx_slider.value_changed.connect(_on_fx_volume_changed)

func _on_master_volume_changed(value: float):
	Player.volume_master = value
	update_volume_labels()
	Player.play_button_sound()

func _on_music_volume_changed(value: float):
	Player.volume_music = value
	update_volume_labels()

func _on_fx_volume_changed(value: float):
	Player.volume_fx = value
	update_volume_labels()
	if value > 0:
		Player.play_button_sound()

func update_volume_labels():
	master_label.text = "MASTER: " + str(int(master_slider.value * 100)) + "%"
	music_label.text = "MUSIC: " + str(int(music_slider.value * 100)) + "%"
	fx_label.text = "EFFECTS: " + str(int(fx_slider.value * 100)) + "%"

func _on_close_button_pressed():
	Player.play_button_sound()
	Player.save_local_file()
	var change_scene = load("res://Scenes/menu.tscn")
	get_tree().change_scene_to_packed(change_scene)
	
func _on_edit_name_pressed() -> void:
	$alert.visible = true
	$User.visible = false
	$Volumen.visible = false
	Player.play_button_sound()
	
func _on_change_avatar_pressed() -> void:
	Player.to_shop = true
	var change_scene = load("res://Scenes/menu.tscn")
	get_tree().change_scene_to_packed(change_scene)

func _on_save_name_pressed() -> void:
	Player.play_button_sound()
	if $alert/LineEdit and $alert/LineEdit.text.strip_edges() != "":
		var new_name = $alert/LineEdit.text.strip_edges()
		Player.set_user_name(new_name)
		Player.play_button_sound()
		$alert.visible = false
		$User.visible = true
		$Volumen.visible = true
		$User/name.text = Player.user_name
