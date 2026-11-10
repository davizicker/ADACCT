extends SceneTree
## Passeio em vídeo pela rua inteira (quadros numerados para virar MP4 com ffmpeg). Uma carga só do jogo.
## xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/video_rua.gd -- <pasta> [passo_m=4] [escala=0.5] [luz=1.0]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var saida := a[0]
	var passo := float(a[1]) if a.size() > 1 else 4.0
	DirAccess.make_dir_recursive_absolute(saida)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 6:
		await process_frame
	var menu := main.get("menu") as Node
	if menu != null:
		menu.call("close")
	var p := main.get_node("Jogador") as Player
	p.set_physics_process(false)
	p.set_process(false)
	(main.get_node("Gritos") as Node).set("enabled", false)
	(main.get_node("Eventos") as Node).set("enabled", false)
	main.get_node("Interface").call("hide_note")
	var hud_n := main.get_node("Interface")
	if hud_n is CanvasLayer:
		(hud_n as CanvasLayer).visible = false
	elif hud_n is CanvasItem:
		(hud_n as CanvasItem).visible = false
	root.get_viewport().scaling_3d_scale = float(a[2]) if a.size() > 2 else 0.5
	var luz := float(a[3]) if a.size() > 3 else 1.0
	var amb := main.get_node("Vila").get_node_or_null("Ambiente") as WorldEnvironment
	if amb and luz > 1.0:
		amb.environment.ambient_light_energy = 0.38 * luz
	var s := 1.0
	var k := 0
	var fim := Route.CHURCH_S - 4.0
	while s <= fim:
		var c := Route.pos(s) + Vector3(0, 1.65, 0)
		var alvo := Route.pos(minf(s + 9.0, Route.length())) + Vector3(0, 1.45, 0)
		p.global_position = c - Vector3(0, 1.6, 0)
		p.cam.look_at(alvo, Vector3.UP)
		p.cam.fov = 75.0
		for i in 3:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/q%04d.png" % [saida, k])
		k += 1
		s += passo
		if k % 10 == 0:
			print("[video] s=", s)
	print("[video] quadros=", k)
	quit()
