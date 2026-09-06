@tool
extends Node

@export_range(0.0, 1.0) var time_of_day := 0.0
@export_range(-90.0, 90.0, 1.0) var latitude := 45.0

@export var sky_material: ShaderMaterial = preload("res://Sky/materials/SkyMaterial.tres")

@export var environment: WorldEnvironment;

@export var sun: DirectionalLight3D

func kelvin_to_rgb(temp_kelvin: float) -> Color:
	var temperature = temp_kelvin / 100.0

	var red: float
	var green: float
	var blue: float

	if temperature <= 66.0:
		red = 255.0
	else:
		red = temperature - 60.0
		red = 329.698727446 * pow(red, -0.1332047592)
		red = clamp(red, 0.0, 255.0)

	if temperature <= 66.0:
		green = 99.4708025861 * log(temperature) - 161.1195681661
		green = clamp(green, 0.0, 255.0)
	else:
		green = temperature - 60.0
		green = 288.1221695283 * pow(green, -0.0755148492)
		green = clamp(green, 0.0, 255.0)

	if temperature >= 66.0:
		blue = 255.0
	elif temperature <= 19.0:
		blue = 0.0
	else:
		blue = temperature - 10.0
		blue = 138.5177312231 * log(blue) - 305.0447927307
		blue = clamp(blue, 0.0, 255.0)

	return Color(red / 255.0, green / 255.0, blue / 255.0)


func _process(_delta: float) -> void:	
	if sun:
		sky_material.set_shader_parameter("stars_rotation", sun.global_basis)
	
		var sun_weight: float = sun.global_basis.z.normalized().dot(Vector3.UP)
		var sun_energy = smoothstep(-0.09, -0.00, sun_weight)
		sun_weight = pow(clamp(sun_weight, 0.0, 1.0), 0.5)
		var sun_color = kelvin_to_rgb(lerpf(1500, 6500, sun_weight))
		sun.light_color = sun_color
		sun.light_energy = sun_energy
