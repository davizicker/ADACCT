extends SceneTree
## Fotografa o Bradador e a Mula de perto, de frente e de lado, sob luz de lanterna. Uso:
## godot --path . --rendering-driver opengl3 --script res://tools/preview_criaturas.gd -- <pasta>
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05)
	env.ambient_light_color = Color(0.15, 0.18, 0.28)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_density = 0.02
	env.fog_light_color = Color(0.03, 0.04, 0.07)
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.7, 0.4)
	luz.light_energy = 3.0
	luz.omni_range = 14.0
	w.add_child(luz)
	var cam := Camera3D.new()
	cam.fov = 55.0
	w.add_child(cam)
	cam.make_current()
	var fotos := [["bradador", Vector3(0, 1.5, -4.5), Vector3(0, 1.4, 0)], ["bradador_l", Vector3(3.5, 1.6, -2.0), Vector3(0, 1.3, 0)],
		["mula", Vector3(0, 1.4, -5.5), Vector3(0, 1.2, 0)], ["mula_l", Vector3(5.0, 1.5, 0.0), Vector3(0, 1.2, 0)], ["mula_t", Vector3(-3.5, 1.3, 4.0), Vector3(0, 1.2, 0)]]
	for f in fotos:
		var nome: String = f[0]
		var cena := "res://scenes/mula.tscn" if nome.begins_with("mula") else "res://scenes/bradador.tscn"
		var inst := (load(cena) as PackedScene).instantiate() as Node3D
		w.add_child(inst)
		inst.visible = true
		cam.look_at_from_position(f[1], f[2])
		luz.position = (f[1] as Vector3) + Vector3(-1.2, 1.0, 1.0)
		for i in 5:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/crit_%s.png" % [out, nome])
		inst.queue_free()
		await process_frame
	quit()
