extends SceneTree
## Fotografa os braços em primeira pessoa com a lanterna, do ponto de vista da câmera do jogador.
## xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/preview_bracos.gd -- saida.png
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.18)
	env.ambient_light_color = Color(0.7, 0.7, 0.8)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 0.6
	w.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.03
	w.add_child(cam)
	cam.make_current()
	var lant := Node3D.new()
	lant.position = Vector3(0.31, -0.42, -0.62)
	lant.rotation = Vector3(0, deg_to_rad(25), 0)
	cam.add_child(lant)
	var lm := PropKit.make("Lantern_01", 0.88)
	lant.add_child(lm)
	# variantes: [curvatura dos dedos, altura da empunhadura]; args: saida_prefixo
	var variantes := [[-1.1, 0.23]]
	for k in variantes.size():
		var br := Bracos.new()
		br.lanterna = lant
		br.curvatura_dedos = variantes[k][0]
		br.empunhadura = Vector3(0.0, variantes[k][1], 0.0)
		cam.add_child(br)
		for i in 6:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [args[0] if args.size() > 0 else "/tmp/bracos", k])
		br.queue_free()
		await process_frame
	quit()
