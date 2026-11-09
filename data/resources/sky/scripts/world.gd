extends Node3D

@export var current_time := 0.0
@export var debug_time := 0.95

# This is bad too, but its another discussion
@onready var sky : SkyProperty = %Sky

func _process(delta: float) -> void:
	# Change on release
	if PublicFunctions.debug_mode:
		debug_build_run(delta)
		return
	non_debug_build_run(delta)
	return
	
func non_debug_build_run(delta : float):
	# If trying to understand:
	# "current_time" acumlates every frame.
	# "current_today_time" es a porcentagem (0.0 ~ 1.0) of the current day.
	# "current_day" is the time already passed, without considering the today time
	# I think it's a good reformulation point, the code is hard to read.
	
	current_time += delta * 0.01
	
	var current_today_time : float = fmod(current_time, 1.0)
	# Type anotation, please. that's a hot loop code.
	
	var current_day : float = current_time - current_today_time
	
	# Search in a hot loop? Seriously?
	# Just use a @onready
	
	# Inutil for now!
	# This is getting me una tonelada of problems
	
	sky.time_of_day = current_today_time
	#sky.day_of_year = current_day
	
func debug_build_run(delta : float):
	current_time += delta * 0.01
	
	var current_today_time : float = fmod(current_time, 1.0)
	var current_day : float = current_time - current_today_time
	
	sky.time_of_day = debug_time
	
	# This property apparently doens't exist on Sky
	#sky.day_of_year = current_day
	
