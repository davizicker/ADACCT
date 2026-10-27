extends SceneTree
## Monta uma fachada de teste com o kit modelado e fotografa de 3 ângulos. Uso (com xvfb):
## godot --path . --rendering-driver opengl3 --script res://tools/preview_kit.gd -- <pasta>
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.45)
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	w.add_child(sun)
	var mats := {}
	for n in ["reboco_ocre", "cantaria", "madeira_natural", "madeira_verde", "ferro", "vidro_luz", "vidro_noite", "telha_uv", "muro"]:
		mats[n] = load("res://assets/materials/%s.tres" % n)
	var b := MeshBatch.new(func(n: String) -> Material: return mats.get(n, mats["cantaria"]))
	var mapa := {"madeira": "madeira_verde", "vidro": "vidro_noite"}
	# parede de 9 m x 7 m
	b.box("reboco_ocre", Vector3(0.3, 7.0, 9.0), Vector3(0.15, 3.5, 0))
	b.box("muro", Vector3(0.4, 1.1, 9.1), Vector3(-0.1, 0.55, 0))
	var jan := Kit.mesh("janela_colonial")
	var ven := Kit.mesh("veneziana")
	var por := Kit.mesh("porta_dupla")
	var sac := Kit.mesh("sacada_1m")
	var cor := Kit.mesh("cornija_1m")
	var cac := Kit.mesh("cachorro_beiral")
	for z: float in [-3.2, 3.2]:
		b.malha(jan, Kit.fachada(Vector3(0.0, 1.5, z)), mapa)
		for sd: float in [-1.0, 1.0]:
			var t := Kit.fachada(Vector3(-0.16, 1.5, z + sd * 0.7), Vector3.ONE)
			t.basis = t.basis * Basis(Vector3.UP, sd * 1.1)
			b.malha(ven, t, mapa)
	b.malha(por, Kit.fachada(Vector3(0.0, 0.0, 0.0)), mapa)
	for z: float in [-3.2, 0.0, 3.2]:
		b.malha(jan, Kit.fachada(Vector3(0.0, 4.7, z)), {"madeira": "madeira_verde", "vidro": "vidro_luz"})
	for k in 9:
		b.malha(sac, Kit.fachada(Vector3(0.0, 3.5, -4.0 + k)), mapa)
		b.malha(cor, Kit.fachada(Vector3(0.0, 6.7, -4.0 + k)), mapa)
		b.malha(cac, Kit.fachada(Vector3(0.0, 6.55, -4.0 + k) + Vector3(0, 0, 0.0)), mapa)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	w.add_child(mi)
	var cam := Camera3D.new()
	cam.fov = 50
	w.add_child(cam)
	cam.make_current()
	for v in [[Vector3(-12, 3.5, 0), Vector3(0, 3.5, 0), "frente"], [Vector3(-6, 2.0, -6), Vector3(0, 2.0, -1.0), "obliqua"], [Vector3(-4.5, 1.7, 3.0), Vector3(0, 1.6, 3.0), "janela"]]:
		cam.look_at_from_position(v[0], v[1])
		for i in 6:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/kit_%s.png" % [out, v[2]])
	quit()
