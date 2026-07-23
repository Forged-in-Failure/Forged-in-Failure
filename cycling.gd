extends CanvasLayer

@onready var pause_menu = $GameplayPauseMenu
@onready var inventory_menu = $InventoryWindow
@onready var stats_menu = $StatsWindow

@onready var cycle_menus = [inventory_menu, stats_menu]

var menu_base_y: Dictionary = {}
var anim_speed: float = 0.55 
var current_index: int = -1
var active_tween: Tween
var pause_tween: Tween

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Setup the pause menu for a clean alpha fade
	pause_menu.hide()
	pause_menu.modulate.a = 0.0
	
	setup_pause_buttons(pause_menu)
	
	for menu in cycle_menus:
		menu_base_y[menu] = menu.position.y 
		menu.hide()

func _unhandled_input(event):
	if event.is_action_pressed("ui_pause"):
		if current_index != -1:
			close_current_menu()
		else:
			toggle_pause_menu()

	elif event.is_action_pressed("ui_cycle_menus"):
		if not pause_menu.visible:
			cycle_to_next_menu()

# --- Pause Menu Logic (Simple Fade + Mouse Toggle) ---

func toggle_pause_menu():
	if pause_tween and pause_tween.is_valid():
		pause_tween.kill()
		
	pause_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	if not pause_menu.visible:
		pause_menu.show()
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Unlock mouse
		
		pause_tween.tween_property(pause_menu, "modulate:a", 1.0, 0.3)
	else:
		get_tree().paused = false
		# Only capture mouse if the tracking conveyor belt menus are also closed
		if current_index == -1:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
		pause_tween.tween_property(pause_menu, "modulate:a", 0.0, 0.25)
		pause_tween.tween_callback(pause_menu.hide)

# --- Button Hover Polish ---

func setup_pause_buttons(node: Node):
	if node is Button:
		node.mouse_entered.connect(func(): tween_button_scale(node, Vector2(1.1, 1.1)))
		node.mouse_exited.connect(func(): tween_button_scale(node, Vector2(1.0, 1.0)))
		
	for child in node.get_children():
		setup_pause_buttons(child)

func tween_button_scale(button: Button, target_scale: Vector2):
	button.pivot_offset = button.size / 2
	var tween = button.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.2)

# --- Cycle Menu Logic (Conveyor Belt + Mouse Toggle) ---

func close_current_menu():
	if current_index != -1:
		if active_tween and active_tween.is_valid():
			active_tween.kill()
			
		var old_menu = cycle_menus[current_index]
		var screen_height = get_viewport().size.y
		
		active_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
		active_tween.tween_property(old_menu, "position:y", menu_base_y[old_menu] - screen_height, anim_speed)
		active_tween.tween_callback(old_menu.hide)
		
		current_index = -1
		if not pause_menu.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Lock mouse back to gameplay

func cycle_to_next_menu():
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	var next_index = current_index + 1
	var screen_height = get_viewport().size.y
	
	for i in range(cycle_menus.size()):
		if i != current_index and i != next_index:
			cycle_menus[i].hide()

	active_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	
	if current_index != -1:
		var old_menu = cycle_menus[current_index]
		active_tween.parallel().tween_property(old_menu, "position:y", menu_base_y[old_menu] - screen_height, anim_speed)
		active_tween.tween_callback(old_menu.hide)
		
	if next_index < cycle_menus.size():
		var new_menu = cycle_menus[next_index]
		new_menu.show()
		new_menu.position.y = menu_base_y[new_menu] + screen_height
		active_tween.parallel().tween_property(new_menu, "position:y", menu_base_y[new_menu], anim_speed)
		
		current_index = next_index
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Unlock mouse while UI cycling is active
	else:
		current_index = -1
		if not pause_menu.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Lock mouse if everything is cleared
