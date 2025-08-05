extends Node

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var fx_player: AudioStreamPlayer = AudioStreamPlayer.new()

var id: String = ""
var _user_name: String = "user"
var _register_date: String = ""
var _points_total: int = 0
var _points_current: int = 0
var _avatar: String = "simple_1"
var _volume_master: float = 0.8
var _volume_music: float = 0.8
var _volume_fx: float = 0.8
var _unlocked_icons: Array = ["simple_1", "simple_2", "simple_3", "simple_4", "simple_5", "simple_6", "simple_7"]

var to_shop: bool = false

var button_click_sound: AudioStream

const DATA_PATH := "user://playerdata.json"

var user_name:
	get: return _user_name
	set(value): _user_name = value; save_local_file()

var register_date:
	get: return _register_date
	set(value): _register_date = value; save_local_file()

var points_total:
	get: return _points_total
	set(value): _points_total = value; save_local_file()

var points_current:
	get: return _points_current
	set(value): _points_current = value; save_local_file()

var avatar:
	get: return _avatar
	set(value): _avatar = value; save_local_file()

var volume_master:
	get: return _volume_master
	set(value): 
		_volume_master = value
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(_volume_master))
		save_local_file()

var volume_music:
	get: return _volume_music
	set(value): 
		_volume_music = value
		if music_player:
			music_player.volume_db = linear_to_db(_volume_music)
		save_local_file()

var volume_fx:
	get: return _volume_fx
	set(value): 
		_volume_fx = value
		if fx_player:
			fx_player.volume_db = linear_to_db(_volume_fx)
		if AudioServer.get_bus_index("SFX") != -1:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(_volume_fx))
		save_local_file()

func _ready():
	setup_audio()
	load_sounds()
	if not load_from_local_file():
		create_new_player()
	else:
		apply_loaded_volumes()

func setup_audio():
	add_child(music_player)
	var music = load("res://audio/sitting-by-the-fireplace-virtuexii-230918.mp3")
	music_player.stream = music
	music_player.autoplay = true
	music_player.bus = "Music"
	
	if music_player.stream is AudioStreamOggVorbis:
		music_player.stream.loop = true
	elif music_player.stream is AudioStreamMP3:
		music_player.stream.loop = true
	elif music_player.stream is AudioStreamWAV:
		music_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	add_child(fx_player)
	fx_player.bus = "SFX"
	
	setup_audio_buses()
	music_player.play()

func load_sounds():
	button_click_sound = load("res://audio/ui-click-43196.mp3")

func setup_audio_buses():
	pass

func play_button_sound():
	if button_click_sound and fx_player:
		fx_player.stream = button_click_sound
		fx_player.play()

func play_sound(sound: AudioStream):
	if sound and fx_player:
		fx_player.stream = sound
		fx_player.play()

func create_new_player():
	id = generate_simple_uuid()
	_register_date = Time.get_datetime_string_from_system()
	save_local_file()

func generate_simple_uuid() -> String:
	var timestamp = str(Time.get_unix_time_from_system())
	var random = str(randi() % 89999 + 10000)
	return "player_" + timestamp + "_" + random

func save_local_file():
	var file = FileAccess.open(DATA_PATH, FileAccess.WRITE)
	if file == null:
		return

	var data = {
		"id": id,
		"name": _user_name,
		"register_date": _register_date,
		"points_total": _points_total,
		"points_current": _points_current,
		"avatar": _avatar,
		"volume_master": _volume_master,
		"volume_music": _volume_music,
		"volume_fx": _volume_fx,
		"platform": OS.get_name(),
		"unlocked_icons": _unlocked_icons,
		"godot_version": Engine.get_version_info().string,
		"last_save": Time.get_datetime_string_from_system()
	}

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_from_local_file() -> bool:
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return false

	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(text) != OK:
		return false

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false

	id = data.get("id", "")
	_user_name = data.get("name", "user")
	_register_date = data.get("register_date", "")
	_points_total = data.get("points_total", 0)
	_points_current = data.get("points_current", 0)
	_avatar = data.get("avatar", "simple_1")
	_volume_master = data.get("volume_master", 0.8)
	_volume_music = data.get("volume_music", 0.8)
	_volume_fx = data.get("volume_fx", 0.8)
	_unlocked_icons = data.get("unlocked_icons", ["simple_1", "simple_2", "simple_3", "simple_4", "simple_5", "simple_6", "simple_7"])

	return true

func apply_loaded_volumes():
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(_volume_master))
	
	if music_player:
		music_player.volume_db = linear_to_db(_volume_music)
	
	if fx_player:
		fx_player.volume_db = linear_to_db(_volume_fx)
	
	if AudioServer.get_bus_index("Music") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(_volume_music))
	
	if AudioServer.get_bus_index("SFX") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(_volume_fx))

func set_user_name(name: String): 
	_user_name = name
	save_local_file()

func add_points(points: int): 
	_points_current += points
	_points_total += points
	save_local_file()

func spend_points(points: int) -> bool:
	if _points_current >= points:
		_points_current -= points
		save_local_file()
		return true
	else:
		return false

func set_avatar(name: String): 
	_avatar = name
	save_local_file()

func get_player_data() -> Dictionary:
	return {
		"id": id,
		"name": _user_name,
		"avatar": _avatar,
		"points": _points_current
	}

func get_player_info() -> String:
	return "ID: " + id + " | Usuario: " + _user_name + " | Puntos: " + str(_points_current)

func reset_player_data():
	if FileAccess.file_exists(DATA_PATH):
		DirAccess.remove_absolute(DATA_PATH)
	
	id = ""
	_user_name = "user"
	_register_date = ""
	_points_total = 0
	_points_current = 0
	_avatar = "simple_1"
	_volume_master = 0.8
	_volume_music = 0.8
	_volume_fx = 0.8
	_unlocked_icons = ["simple_1", "simple_2", "simple_3", "simple_4", "simple_5", "simple_6", "simple_7"]
	
	if fx_player:
		fx_player.volume_db = linear_to_db(_volume_fx)
	if music_player:
		music_player.volume_db = linear_to_db(_volume_music)
	
	create_new_player()

func stop_music():
	if music_player:
		music_player.stop()

func play_music():
	if music_player:
		music_player.play()

func set_music_volume(volume: float):
	_volume_music = volume
	if music_player:
		music_player.volume_db = linear_to_db(volume)
	save_local_file()

func unlock_icon(icon_id: String):
	if not _unlocked_icons.has(icon_id):
		_unlocked_icons.append(icon_id)
		save_local_file()

func get_unlocked_icons() -> Array:
	return _unlocked_icons.duplicate()

func set_unlocked_icons(icons: Array):
	_unlocked_icons = icons
	save_local_file()

func is_icon_unlocked(icon_id: String) -> bool:
	return _unlocked_icons.has(icon_id)

func is_default_name() -> bool:
	return _user_name == "user"

func needs_name_setup() -> bool:
	return _user_name == "user"
