extends Label

func _ready() -> void:
	# Crucial: Keeps the script running even when get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var mouse_locked = (Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED)
	var game_paused = get_tree().paused
	
	# Only show if the mouse is locked AND the game isn't paused
	visible = mouse_locked and not game_paused
