extends SceneTree
## Fotografa TODAS as salas por dentro, de quatro pontos (porta, cantos), com UMA carga do jogo. Uso:
## xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/foto_salas.gd -- <pasta_saida> [id1,id2,...]
## Gera <pasta>/<sala>_<n>.png (n = 1..4). A conferência visual é obrigatória antes de entregar qualquer versão.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var saida := a[0]
	var so: PackedStringArray = PackedStringArray(String(a[1]).split(",")) if a.size() > 1 else PackedStringArray()
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
	(main.get_node("Gritos") as Node).set("enabled", false)
	(main.get_node("Eventos") as Node).set("enabled", false)
	main.get_node("Interface").call("hide_note")
	var inter := main.get_node("Vila/Interiores")
	for ch in main.get_node("Vila").get_children():          # só as salas: o resto da vila (milhares de objetos) deixa a captura lentíssima
		if not ["Interiores", "Ambiente", "Lua"].has(String(ch.name)):
			(ch as Node3D).visible = false if ch is Node3D else true
	for g in inter.get_children():
		if so.size() > 0 and not so.has(String(g.name)):
			continue
		var dim: Vector3 = g.get_meta("dim", Vector3(8, 3, 6))
		var o: Vector3 = (g as Node3D).global_position
		var poses := [
			[Vector3(0.5, 0, 0.12), Vector3(0.5, -0.2, 0.9)],
			[Vector3(0.1, 0, 0.1), Vector3(0.85, -0.25, 0.85)],
			[Vector3(0.9, 0, 0.1), Vector3(0.15, -0.25, 0.85)],
			[Vector3(0.9, 0, 0.9), Vector3(0.2, -0.25, 0.15)],
		]
		for k in poses.size():
			var f0: Vector3 = poses[k][0]
			var f1: Vector3 = poses[k][1]
			var pos := o + Vector3(dim.x * f0.x, 1.65, dim.z * f0.z)
			var alvo := o + Vector3(dim.x * f1.x, 1.65 + dim.y * f1.y, dim.z * f1.z)
			p.global_position = pos - Vector3(0, 1.6, 0)
			p.cam.look_at(alvo, Vector3.UP)
			p.cam.fov = 78.0
			for i in 3:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [saida, g.name, k + 1])
		print("[salas] ", g.name)
	quit()
