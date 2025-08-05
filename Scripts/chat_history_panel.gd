extends Panel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$".".visible = false;



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_close_chat_h_button_pressed() -> void:
	$".".visible = false;
	



func _on_chat_button_pressed() -> void:
	$".".visible = true;


func _on_close_chat_pressed() -> void:
	pass # Replace with function body.
