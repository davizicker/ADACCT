extends SceneTree
## Fotografa um modelo animado (.glb) tocando uma animação em 4 instantes. Uso (xvfb):
## godot --path . --rendering-driver opengl3 --script res://tools/preview_anim.gd -- <modelo.glb> <animacao> <saida.png>
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(args[0], st)
	var inst := doc.generate_scene(st)
	var w := Node3D.new()
	root.add_child(w)
	w.add_child(inst)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.3)
	env.ambient_light_color = Color(0.6, 0.6, 0.7)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	w.add_child(sun)
	var ap := inst.find_children("*", "AnimationPlayer", true, false)
	var nomes: Array = []
	if ap.size() > 0:
		for n in (ap[0] as AnimationPlayer).get_animation_list():
			nomes.append(n)
	print("[anim] animacoes: ", nomes, " esqueletos: ", inst.find_children("*", "Skeleton3D", true, false).size())
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.make_current()
	cam.look_at_from_position(Vector3(0, 1.0, -4.5) if args.size() < 4 else Vector3(float(args[3]), 1.0, float(args[4])), Vector3(0, 0.9, 0))
	var player: AnimationPlayer = ap[0] if ap.size() > 0 else null
	var fotos: Array[Image] = []
	for k in 4:
		if player != null and args[1] in nomes:
			player.play(args[1])
			player.seek(float(k) / 4.0 * player.get_animation(args[1]).length, true)
		for i in 4:
			await process_frame
		fotos.append(root.get_viewport().get_texture().get_image())
	var W := Image.create(1280, 480, false, Image.FORMAT_RGBA8)
	for k in 4:
		var im := fotos[k]
		im.resize(320, 180)
		W.blit_rect(im, Rect2i(0, 0, 320, 180), Vector2i(k * 320, 0))
	W.save_png(args[2])
	quit()
