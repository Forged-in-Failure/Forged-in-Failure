extends CharacterBody3D

# --- Movement ---
@export var SPEED = 7.5
@export var SPRINT_MULTIPLIER = 1.5
const JUMP_VELOCITY = 3.5
const MOUSE_SENS = 0.002
const DEATH_Y = -20.0
var is_sprinting = false

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var cam = $SpringArm3D/Camera3D
var cam_x_rot = 0.0

const PITCH_MIN = -60.0
const PITCH_MAX = 30.0

# --- Rotation smoothing (body facing movement direction) ---
const BODY_ROTATE_SPEED = 10.0

# --- Checkpoint ---
var respawn_position: Vector3
var respawn_rotation: Vector3 = Vector3.ZERO

# --- Head bob / footstep sync (first person only) ---
var bob_timer = 0.0
const BOB_VERTICAL = 0.05
const BOB_HORIZONTAL = 0.03
const BOB_SPEED = 10.0
var cam_orig_pos = Vector3.ZERO
var cam_target_pos = Vector3.ZERO
var fov_orig = 70.0
const FOV_KICK = 5.0
var last_footstep = 0
var run_footstep_timer = 0.0

# --- Camera sway (first person only) ---
@export var IDLE_SWAY_AMOUNT = 0.015
@export var IDLE_SWAY_SPEED = 0.8
@export var LEAN_AMOUNT_DEG = 2.5
@export var TURN_SWAY_AMOUNT = 0.035
const SWAY_SMOOTH = 6.0
var sway_time = 0.0
var target_roll = 0.0
var turn_roll = 0.0

# --- FOV ---
@export var ZOOM_FOV = 45.0
@export var ZOOM_SPEED = 8.0
@export var SPRINT_FOV = 80.0
var is_zooming = false
var target_fov = 70.0

# --- Spring arm zoom (third person only) ---
@export var SPRING_LENGTH_NORMAL = 4.0
@export var SPRING_LENGTH_ZOOM = 2.0
var target_spring_length = 4.0

# --- Scroll wheel zoom (third person only) ---
@export var ZOOM_STEP = 0.5
@export var MIN_ZOOM_OFFSET = -2.0
@export var MAX_ZOOM_OFFSET = 4.0
var scroll_zoom_offset = 0.0

# --- Fall thud effect ---
var thud_timer = 0.0
const THUD_DURATION = 0.35
const THUD_HEIGHT = 0.5
const THUD_SHAKE = 0.15
var thud_active = false
var thud_strength = 1.0
@export var THUD_MIN_FALL = 1.5
@export var THUD_MAX_FALL = 9.0
var fall_start_y = 0.0

# --- Audio players ---
@onready var footstep_player = $Footsteps
@onready var jump_player = $JumpAudio
@onready var wind_player = $WindAudio
@onready var thud_player = $ThudAudio

# --- Animation ---
@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false)
@onready var mesh_root: Node3D = find_child("Torso", true, false)
const ANIM_BLEND = 0.30 # seconds to crossfade between animations

# --- Camera mode ---
var is_first_person = false
@onready var first_person_cam: Camera3D = $Camera3D

# --- Head shadow handling ---
# Path is relative to this node (Player). Adjust if John FiF isn't a direct child.
@onready var head_node: Node = get_node_or_null("John FiF/metarig/Skeleton3D/spine_004/Head_001")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	cam_orig_pos = cam.transform.origin if first_person_cam else Vector3.ZERO
	fov_orig = cam.fov
	respawn_position = global_position
	respawn_rotation = rotation
	cam_target_pos = cam_orig_pos
	target_fov = fov_orig
	target_spring_length = SPRING_LENGTH_NORMAL
	spring_arm.spring_length = SPRING_LENGTH_NORMAL
	fall_start_y = global_position.y
	
	if anim_player == null:
		push_warning("AnimationPlayer not found under Player — check the node path.")
	elif anim_player.has_animation("Idle"):
		anim_player.play("Idle")
	
	if head_node == null:
		push_warning("Head_001 not found — check the node path under John FiF.")
	
	update_camera_mode()

func _input(event):
	# --- Toggle camera mode ---
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_V:
			is_first_person = !is_first_person
			update_camera_mode()
			get_tree().root.set_input_as_handled()
			return
	
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			return
		
		if is_first_person:
			rotate_y(-event.relative.x * MOUSE_SENS)
			cam_x_rot = clamp(cam_x_rot - event.relative.y * MOUSE_SENS, deg_to_rad(-80.0), deg_to_rad(80.0))
			first_person_cam.rotation.x = cam_x_rot
			turn_roll = clamp(-event.relative.x * 0.0015, -TURN_SWAY_AMOUNT, TURN_SWAY_AMOUNT)
		else:
			rotate_y(-event.relative.x * MOUSE_SENS)
			cam_x_rot = clamp(cam_x_rot - event.relative.y * MOUSE_SENS, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
			spring_arm.rotation.x = cam_x_rot
	
	if event is InputEventMouseButton:
		# --- Middle Click Look Behind (Hold to see front of player) ---
		if event.button_index == MOUSE_BUTTON_MIDDLE and not is_first_person:
			spring_arm.rotation.y = PI if event.pressed else 0.0
			
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				is_zooming = event.pressed
			else:
				is_zooming = false
		elif not is_first_person:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll_zoom_offset = clamp(scroll_zoom_offset - ZOOM_STEP, MIN_ZOOM_OFFSET, MAX_ZOOM_OFFSET)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll_zoom_offset = clamp(scroll_zoom_offset + ZOOM_STEP, MIN_ZOOM_OFFSET, MAX_ZOOM_OFFSET)

func _physics_process(delta: float) -> void:
	is_sprinting = Input.is_key_pressed(KEY_SHIFT)
	
	if global_position.y < DEATH_Y:
		respawn()
	
	var was_on_floor = is_on_floor()
	if was_on_floor:
		fall_start_y = global_position.y
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if jump_player:
			jump_player.play()
	
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var current_speed = SPEED * (SPRINT_MULTIPLIER if is_sprinting else 1.0)
	var target_velocity = direction * current_speed
	velocity.x = lerp(velocity.x, target_velocity.x, 0.15)
	velocity.z = lerp(velocity.z, target_velocity.z, 0.15)
	
	move_and_slide()
	
	if not is_first_person:
		var flat_vel = Vector3(velocity.x, 0.0, velocity.z)
		if flat_vel.length() > 0.2 and mesh_root:
			var target_angle = atan2(flat_vel.x, flat_vel.z)
			mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_angle, delta * BODY_ROTATE_SPEED)
	
	if not was_on_floor and is_on_floor():
		var fall_distance = fall_start_y - global_position.y
		if fall_distance > THUD_MIN_FALL:
			var strength = clamp((fall_distance - THUD_MIN_FALL) / (THUD_MAX_FALL - THUD_MIN_FALL), 0.0, 1.0)
			trigger_thud(strength)
	
	if is_first_person:
		update_first_person(delta, input_dir)
	else:
		update_third_person(delta, input_dir)

func update_first_person(delta: float, input_dir: Vector2) -> void:
	if is_zooming:
		target_fov = ZOOM_FOV
	elif is_sprinting:
		target_fov = SPRINT_FOV
	else:
		target_fov = fov_orig
	first_person_cam.fov = lerp(first_person_cam.fov, target_fov, delta * ZOOM_SPEED)
	
	var speed = Vector3(velocity.x, 0.0, velocity.z).length()
	var bob_speed_mult = SPRINT_MULTIPLIER if is_sprinting else 1.0
	var bob_offset = Vector3.ZERO
	
	if speed > 0.1:
		bob_timer += delta * BOB_SPEED * bob_speed_mult
		var vertical = sin(bob_timer) * BOB_VERTICAL
		var horizontal = sin(bob_timer * 0.5) * (BOB_HORIZONTAL * 0.5)
		bob_offset = Vector3(horizontal, vertical, 0.0)
		first_person_cam.fov = lerp(first_person_cam.fov, target_fov + FOV_KICK, delta * 6.0)
		
		if is_sprinting:
			run_footstep_timer += delta
			if run_footstep_timer >= (20.0 / 60.0): # 20 frames at 60 FPS (approx 0.33s)
				run_footstep_timer = 0.0
				if footstep_player:
					footstep_player.play()
			last_footstep = int(bob_timer * 2.0)
		else:
			run_footstep_timer = 0.0
			if int(bob_timer * 2.0) != last_footstep:
				last_footstep = int(bob_timer * 2.0)
				if footstep_player:
					footstep_player.play()
	else:
		bob_timer = lerp(bob_timer, 0.0, delta * 5.0)
		last_footstep = 0
		run_footstep_timer = 0.0
	
	sway_time += delta * IDLE_SWAY_SPEED
	var sway_offset = Vector3(
		sin(sway_time) * IDLE_SWAY_AMOUNT + sin(sway_time * 2.3) * IDLE_SWAY_AMOUNT * 0.3,
		cos(sway_time * 0.7) * IDLE_SWAY_AMOUNT * 0.5,
		0.0
	)
	
	var strafe_lean = -input_dir.x * deg_to_rad(LEAN_AMOUNT_DEG)
	target_roll = strafe_lean + turn_roll
	first_person_cam.rotation.z = lerp(first_person_cam.rotation.z, target_roll, delta * SWAY_SMOOTH)
	turn_roll = lerp(turn_roll, 0.0, delta * 8.0)
	
	var thud_offset = Vector3.ZERO
	if thud_active:
		thud_timer += delta
		var t = thud_timer / THUD_DURATION
		var height_drop = sin(t * PI) * THUD_HEIGHT * thud_strength
		var shake_x = (randf() - 0.5) * 2.0 * THUD_SHAKE * thud_strength
		var shake_z = (randf() - 0.5) * 2.0 * THUD_SHAKE * thud_strength
		thud_offset = Vector3(shake_x, -height_drop, shake_z)
		if thud_timer >= THUD_DURATION:
			thud_active = false
			thud_timer = 0.0
	
	if wind_player:
		var fall_speed = max(0.0, -velocity.y)
		wind_player.volume_db = clamp(linear_to_db(fall_speed / 30.0), -40.0, 0.0)
	
	cam_target_pos = cam_orig_pos + bob_offset + sway_offset + thud_offset
	first_person_cam.transform.origin = first_person_cam.transform.origin.lerp(cam_target_pos, delta * 8.0)
	
	if anim_player:
		if input_dir != Vector2.ZERO:
			var target_anim = "Run" if is_sprinting else "Walk"
			if anim_player.current_animation != target_anim:
				anim_player.play(target_anim, ANIM_BLEND)
			anim_player.speed_scale = 1.0
		else:
			if anim_player.current_animation != "Idle":
				anim_player.play("Idle", ANIM_BLEND)
			anim_player.speed_scale = 1.0

func update_third_person(delta: float, input_dir: Vector2) -> void:
	if is_zooming:
		target_fov = ZOOM_FOV
		target_spring_length = SPRING_LENGTH_ZOOM
	elif is_sprinting:
		target_fov = SPRINT_FOV
		target_spring_length = SPRING_LENGTH_NORMAL + scroll_zoom_offset
	else:
		target_fov = fov_orig
		target_spring_length = SPRING_LENGTH_NORMAL + scroll_zoom_offset
	cam.fov = lerp(cam.fov, target_fov, delta * ZOOM_SPEED)
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_spring_length, delta * ZOOM_SPEED)
	
	var flat_vel = Vector3(velocity.x, 0.0, velocity.z)
	var speed = flat_vel.length()
	var step_speed_mult = SPRINT_MULTIPLIER if is_sprinting else 1.0
	
	if speed > 0.1:
		bob_timer += delta * BOB_SPEED * step_speed_mult
		
		if is_sprinting:
			run_footstep_timer += delta
			if run_footstep_timer >= (20.0 / 60.0):
				run_footstep_timer = 0.0
				if footstep_player:
					footstep_player.play()
			last_footstep = int(bob_timer * 2.0)
		else:
			run_footstep_timer = 0.0
			if int(bob_timer * 2.0) != last_footstep:
				last_footstep = int(bob_timer * 2.0)
				if footstep_player:
					footstep_player.play()
	else:
		bob_timer = 0.0
		last_footstep = 0
		run_footstep_timer = 0.0
	
	if wind_player:
		var fall_speed = max(0.0, -velocity.y)
		wind_player.volume_db = clamp(linear_to_db(fall_speed / 30.0), -40.0, 0.0)
	
	if anim_player:
		if input_dir != Vector2.ZERO:
			var target_anim = "Run" if is_sprinting else "Walk"
			if anim_player.current_animation != target_anim:
				anim_player.play(target_anim, ANIM_BLEND)
			anim_player.speed_scale = 1.0 
		else:
			if anim_player.current_animation != "Idle":
				anim_player.play("Idle", ANIM_BLEND)
			anim_player.speed_scale = 1.0

func update_camera_mode() -> void:
	if is_first_person:
		first_person_cam.current = true
		spring_arm.visible = false
		cam_orig_pos = first_person_cam.transform.origin
		cam_x_rot = first_person_cam.rotation.x
		bob_timer = 0.0
		sway_time = 0.0
		set_head_shadow_mode(GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	else:
		first_person_cam.current = false
		spring_arm.visible = true
		spring_arm.rotation.y = 0.0 # Clean rotation in case we switched while middle-clicking
		cam_x_rot = spring_arm.rotation.x
		scroll_zoom_offset = 0.0
		bob_timer = 0.0
		set_head_shadow_mode(GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

# Recursively applies a shadow-casting mode to head_node and every
# GeometryInstance3D descendant of it (meshes attached under the head bone).
func set_head_shadow_mode(mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	if head_node == null:
		return
	_apply_shadow_mode_recursive(head_node, mode)

func _apply_shadow_mode_recursive(node: Node, mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = mode
	for child in node.get_children():
		_apply_shadow_mode_recursive(child, mode)

func set_checkpoint(pos: Vector3, rot: Vector3 = Vector3.ZERO):
	respawn_position = pos
	if rot != Vector3.ZERO:
		respawn_rotation = rot

func trigger_thud(strength: float):
	thud_active = true
	thud_timer = 0.0
	thud_strength = strength
	if thud_player:
		thud_player.play()

func respawn():
	global_position = respawn_position
	rotation = respawn_rotation
	cam_x_rot = 0.0
	if is_first_person:
		first_person_cam.transform.origin = cam_orig_pos
		first_person_cam.rotation = Vector3(0.0, 0.0, 0.0)
	else:
		spring_arm.rotation.x = 0.0
		spring_arm.rotation.y = 0.0 # Clean state on death
		scroll_zoom_offset = 0.0
	velocity = Vector3.ZERO
	fall_start_y = global_position.y
	trigger_thud(1.0)

func die():
	respawn()
