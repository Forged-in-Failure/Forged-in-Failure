extends Node3D

var time := 0.0

func _process(delta: float) -> void:
	time += delta * 0.01
	
	var tod = fmod(time, 1.0)
	var day = time - tod
	
	$Sky.time_of_day = tod
	$Sky.day_of_year = day
