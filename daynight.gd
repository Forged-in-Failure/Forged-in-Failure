extends Node3D

## The total time (in seconds) it takes to complete a full 360-degree rotation.
@export var rotation_time: float = 48*60

func _process(delta: float) -> void:
	# Avoid division by zero if the time is set to 0 or negative
	if rotation_time > 0.0:
		# TAU is a built-in constant equal to 2 * PI (a full rotation in radians)
		var rotation_speed = TAU / rotation_time
		
		# Linearly rotate around the local X axis
		rotate_x(rotation_speed * delta)
