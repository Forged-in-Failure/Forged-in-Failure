@tool
extends EditorScript

func _run():
	var env = get_scene().find_child("WorldEnvironment").environment
	var img = RenderingServer.environment_bake_panorama(
		env.get_rid(), true, Vector2i(4096, 2048)
	)
	img.save_exr("user://sky_hdri.exr")
	print("Saved to: ", OS.get_user_data_dir() + "/sky_hdri.exr")
