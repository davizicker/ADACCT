extends SceneTree
## Fotografa as espécies lado a lado (L0 em cima, L1 embaixo). xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/preview_arvores.gd -- saida.png
func _init() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.55, 0.7)
	env.ambient_light_color = Color(0.8, 0.85, 0.95)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	w.add_child(sun)
	var x := 0.0
	for esp in Arvores.ESPECIES:
		for lod in 2:
			var mi := MeshInstance3D.new()
			mi.mesh = Arvores.malha("%s_L%d" % [esp, lod])
			mi.position = Vector3(x, 0, -lod * 14.0)
			w.add_child(mi)
		x += 9.0
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.make_current()
	cam.look_at_from_position(Vector3(40, 5, 18), Vector3(40, 5, 0))
	cam.fov = 60
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
