class_name ShotUtil
extends RefCounted
## Test helper: save the main viewport to a PNG (path relative to the project, e.g. "shots/x.png").


static func capture(tree: SceneTree, rel_path: String, delay_sec := 1.0, quit := true) -> void:
	await tree.create_timer(delay_sec, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img := tree.root.get_viewport().get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path("res://" + rel_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	img.save_png(abs_path)
	print("[shot] saved ", abs_path)
	if quit:
		tree.quit()
