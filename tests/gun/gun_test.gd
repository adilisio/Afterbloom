extends Node3D

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.5, 0.55)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	env.environment = e
	add_child(env)
	var W: GDScript = load("res://src/player/weapons.gd")
	var w: Node3D = W.new()
	add_child(w)
	for name in ["pistol", "rifle"]:
		var rig: Node3D = w.call("_build_rig", name)
		rig.position = Vector3.ZERO
		var cam := Camera3D.new()
		add_child(cam)
		for view in [["side", Vector3(1.2, 0, 0)], ["top", Vector3(0, 1.2, 0.001)], ["front", Vector3(0, 0, -1.2)]]:
			cam.position = view[1]
			cam.look_at(Vector3.ZERO, Vector3.UP if view[0] != "top" else Vector3.FORWARD)
			cam.current = true
			var axes := Label3D.new()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/gun_%s_%s.png" % [name, view[0]]))
		rig.visible = false
	get_tree().quit()
