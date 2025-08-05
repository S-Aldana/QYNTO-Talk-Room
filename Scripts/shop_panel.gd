extends Panel

@onready var points_label: Label = $points
@onready var icons_unlocked_label: Label = $iconsUnlocked
@onready var show_icon: Control = $ShowIcon
@onready var simple_icons: Control = $Icons/SimpleIcons
@onready var epic_icons: Control = $Icons/EpicIcons  
@onready var legendary_icons: Control = $Icons/LegendaryIcons
@onready var simple_label: Label = $ShowIcon/simple
@onready var epic_label: Label = $ShowIcon/epic
@onready var legendary_label: Label = $ShowIcon/legendary
@onready var icon_texture: TextureRect = $ShowIcon/TextureRect

@onready var alert_panel: Control = $alert
@onready var alert_label: Label = $alert/Label
@onready var alert_yes_button: Button = $alert/yes
@onready var alert_cancel_button: Button = $alert/cancel

var icons_data = {
	"simple_1": {"cost": 0, "rarity": "simple", "unlocked": true, "name": "Pink Pixie"},
	"simple_2": {"cost": 0, "rarity": "simple", "unlocked": true, "name": "Quiet Thought"},
	"simple_3": {"cost": 0, "rarity": "simple", "unlocked": true, "name": "Chick"},
	"simple_4": {"cost": 0, "rarity": "simple", "unlocked": true, "name": "Mint"},
	"simple_5": {"cost": 0, "rarity": "simple", "unlocked": true, "name": "Please"},
	"simple_6": {"cost": 0, "rarity": "simple", "unlocked": true, "name": "Bitwise"},
	"simple_7": {"cost": 0, "rarity": "simple", "unlocked": true, "name": "Not Today"},
	
	"epic_1": {"cost": 3, "rarity": "epic", "unlocked": false, "name": "Little Puppy"},
	"epic_2": {"cost": 3, "rarity": "epic", "unlocked": false, "name": "Inner Peace"},
	"epic_3": {"cost": 2, "rarity": "epic", "unlocked": false, "name": "Crimson"},
	"epic_4": {"cost": 3, "rarity": "epic", "unlocked": false, "name": "Host of Shadows"},
	"epic_5": {"cost": 3, "rarity": "epic", "unlocked": false, "name": "Gloomy Girl"},
	"epic_6": {"cost": 2, "rarity": "epic", "unlocked": false, "name": "Genius"},
	"epic_7": {"cost": 4, "rarity": "epic", "unlocked": false, "name": "Storm Raven"},

	"legendary_1": {"cost": 10, "rarity": "legendary", "unlocked": false, "name": "Crowlight"},
	"legendary_2": {"cost": 7, "rarity": "legendary", "unlocked": false, "name": "Crystal Witch"},
	"legendary_3": {"cost": 8, "rarity": "legendary", "unlocked": false, "name": "Phoenix Eye"},
	"legendary_4": {"cost": 9, "rarity": "legendary", "unlocked": false, "name": "Comet Tails"},
	"legendary_5": {"cost": 7, "rarity": "legendary", "unlocked": false, "name": "Just Reading"},
	"legendary_6": {"cost": 13, "rarity": "legendary", "unlocked": false, "name": "Zappy Sand Prince"}
}

var current_selected_icon: String = ""
var pending_purchase_icon: String = ""

func _ready() -> void:
	$".".visible = false
	if alert_panel:
		alert_panel.visible = false
	load_unlocked_icons()
	current_selected_icon = Player.avatar
	connect_buttons()
	connect_alert_buttons()
	update_ui()

func connect_alert_buttons():
	if alert_yes_button:
		alert_yes_button.pressed.connect(_on_alert_yes_pressed)
	if alert_cancel_button:
		alert_cancel_button.pressed.connect(_on_alert_cancel_pressed)

func _on_alert_yes_pressed():
	Player.play_button_sound()
	if pending_purchase_icon != "" and icons_data.has(pending_purchase_icon):
		var icon_data = icons_data[pending_purchase_icon]
		if Player.points_current >= icon_data.cost:
			if Player.spend_points(icon_data.cost):
				icons_data[pending_purchase_icon].unlocked = true
				save_unlocked_icons()
				Player.unlock_icon(pending_purchase_icon)
				Player.set_avatar(pending_purchase_icon)
				current_selected_icon = pending_purchase_icon
				update_ui()
	
	hide_alert()

func _on_alert_cancel_pressed():
	Player.play_button_sound()
	hide_alert()

func show_alert(icon_id: String):
	pending_purchase_icon = icon_id
	var icon_data = icons_data[icon_id]
	
	if alert_panel and alert_label and alert_yes_button:
		if Player.points_current >= icon_data.cost:
			alert_label.text = "Do you want to buy '" + icon_data.name + "?"
			alert_yes_button.disabled = false
		else:
			alert_label.text = "You don't have enough points"
			alert_yes_button.disabled = true
		
		alert_panel.visible = true

func hide_alert():
	if alert_panel:
		alert_panel.visible = false
	pending_purchase_icon = ""

func _on_close_store_button_pressed() -> void:
	$".".visible = false
	$"../MenuBtn".visible = true
	$"../MenuBtn2".visible = true
	$"../MenuBtn3".visible = true
	Player.play_button_sound()
	if Player.to_shop == true:
		Player.to_shop = false

func _on_store_button_pressed() -> void:
	$".".visible = true
	refresh_shop()
	Player.play_button_sound()

func connect_buttons():
	for i in range(1, 8):
		var simple_button = simple_icons.get_node_or_null("SimpleIco_" + str(i) + "/Button")
		if simple_button:
			simple_button.pressed.connect(_on_icon_pressed.bind("simple_" + str(i)))
		
		if i <= 7:
			var epic_button = epic_icons.get_node_or_null("EpicIco_" + str(i) + "/Button")
			if epic_button:
				epic_button.pressed.connect(_on_icon_pressed.bind("epic_" + str(i)))
	
	for i in range(1, 7):
		var legendary_button = legendary_icons.get_node_or_null("LegendaryIco_" + str(i) + "/Button")
		if legendary_button:
			legendary_button.pressed.connect(_on_icon_pressed.bind("legendary_" + str(i)))
	
	var buy_button = show_icon.get_node_or_null("BuyIconButton")
	if buy_button:
		buy_button.pressed.connect(_on_buy_pressed)

func _on_icon_pressed(icon_id: String):
	Player.play_button_sound()
	current_selected_icon = icon_id
	update_selected_display()

func _on_buy_pressed():
	var icon_data = icons_data[current_selected_icon]
	
	if icon_data.unlocked:
		if current_selected_icon != Player.avatar:
			Player.play_button_sound()
			Player.set_avatar(current_selected_icon)
			update_ui()
		else:
			Player.play_button_sound()
	else:
		Player.play_button_sound()
		show_alert(current_selected_icon)

func update_ui():
	points_label.text = str(Player.points_current) + "PTS"
	
	var unlocked_count = 0
	for icon_data in icons_data.values():
		if icon_data.unlocked:
			unlocked_count += 1
	icons_unlocked_label.text = "ICONS UNLOCKED: " + str(unlocked_count) + " / " + str(icons_data.size())
	
	update_icon_buttons()
	update_selected_display()

func update_icon_buttons():
	for icon_id in icons_data.keys():
		var icon_data = icons_data[icon_id]
		var button = get_icon_button(icon_id)
		var cost_label = get_icon_cost_label(icon_id)
		
		if button and cost_label:
			if icon_data.unlocked:
				if icon_id == Player.avatar:
					cost_label.text = "EQUIPPED"
					cost_label.modulate = Color.YELLOW
					button.modulate = Color.YELLOW
				else:
					cost_label.text = "UNLOCKED"
					cost_label.modulate = Color.GREEN
					button.modulate = Color.WHITE
			else:
				if icon_data.cost == 0:
					cost_label.text = "FREE"
					cost_label.modulate = Color.GREEN
				else:
					cost_label.text = str(icon_data.cost) + "PTS"
					cost_label.modulate = Color.WHITE
				button.modulate = Color.GRAY

func update_selected_display():
	if current_selected_icon in icons_data:
		var icon_data = icons_data[current_selected_icon]
		
		show_rarity_labels(icon_data.rarity)
		update_icon_image(current_selected_icon)
		
		var icon_name_label = show_icon.get_node_or_null("iconName")
		if icon_name_label:
			icon_name_label.text = icon_data.name
		
		var cost_label = show_icon.get_node_or_null("cost")
		if cost_label:
			if icon_data.cost == 0:
				cost_label.text = "FREE"
			else:
				cost_label.text = str(icon_data.cost) + "PTS"
		
		var buy_button = show_icon.get_node_or_null("BuyIconButton")
		if buy_button:
			if icon_data.unlocked:
				if current_selected_icon == Player.avatar:
					buy_button.text = "EQUIPPED"
					buy_button.disabled = true
				else:
					buy_button.text = "EQUIP"
					buy_button.disabled = false
			else:
				buy_button.text = "BUY ICON"
				buy_button.disabled = false

func get_icon_button(icon_id: String) -> Button:
	var parts = icon_id.split("_")
	var rarity = parts[0]
	var number = parts[1]
	
	var container = get_icon_container(rarity)
	var container_name = get_container_name(rarity) + number
	var icon_node = container.get_node_or_null(container_name)
	
	if icon_node:
		return icon_node.get_node_or_null("Button")
	return null

func get_icon_cost_label(icon_id: String) -> Label:
	var parts = icon_id.split("_")
	var rarity = parts[0]
	var number = parts[1]
	
	var container = get_icon_container(rarity)
	var container_name = get_container_name(rarity) + number
	var icon_node = container.get_node_or_null(container_name)
	
	if icon_node:
		return icon_node.get_node_or_null("cost")
	return null

func get_icon_container(rarity: String) -> Control:
	match rarity:
		"simple": return simple_icons
		"epic": return epic_icons
		"legendary": return legendary_icons
		_: return simple_icons

func get_container_name(rarity: String) -> String:
	match rarity:
		"simple": return "SimpleIco_"
		"epic": return "EpicIco_"
		"legendary": return "LegendaryIco_"
		_: return "SimpleIco_"

func save_unlocked_icons():
	var unlocked_list = []
	for icon_id in icons_data.keys():
		if icons_data[icon_id].unlocked:
			unlocked_list.append(icon_id)
	
	Player.set_unlocked_icons(unlocked_list)

func load_unlocked_icons():
	var unlocked_list = Player.get_unlocked_icons()
	for icon_id in unlocked_list:
		if icon_id in icons_data:
			icons_data[icon_id].unlocked = true

func refresh_shop():
	current_selected_icon = Player.avatar
	load_unlocked_icons()
	update_ui()

func show_rarity_labels(rarity: String):
	simple_label.visible = (rarity == "simple")
	epic_label.visible = (rarity == "epic")
	legendary_label.visible = (rarity == "legendary")

func update_icon_image(icon_id: String):
	var parts = icon_id.split("_")
	var rarity = parts[0]
	var number = int(parts[1])
	
	var file_extension = ".png"
	
	if rarity == "epic" and number == 1:
		file_extension = ".jpg"
	elif rarity == "legendary" and (number == 1 or number == 2 or number == 4 or number == 5):
		file_extension = ".jpg"
	
	var icon_name = ""
	match rarity:
		"simple":
			icon_name = "SimpleIcon-" + str(number)
		"epic":
			icon_name = "EpicIcon-" + str(number)
		"legendary":
			icon_name = "LegendaryIcon-" + str(number)
	
	var texture_path = "res://Backgrounds/PlayerIcons/" + icon_name + file_extension
	var texture = load(texture_path)
	
	if icon_texture and texture:
		icon_texture.texture = texture

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
