extends SceneTree
## Fotografa as salas das casas da RUA (dentro da casa real) de fora e de dentro, com UMA carga do jogo. Uso:
## xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/foto_casas.gd -- <pasta_saida> [id1,id2,...] [escala3d]
## Gera <pasta>/<sala>_fora.png (da calçada, olhando as janelas), _in1 (da porta para o fundo), _in2 (do fundo para a parede das janelas: mostra a rua),
## _in3 (canto). A conferência visual é obrigatória antes de entregar.
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
	root.get_viewport().scaling_3d_scale = float(a[2]) if a.size() > 2 else 0.5
	var xs := Interiores.ESCALA_SALA
	for n in get_nodes_in_group("sala_rua"):
		var sl := n as Node3D
		var id := str(sl.get_meta("sala_id"))
		if so.size() > 0 and not so.has(id):
			continue
		var dim: Vector3 = (sl.get_meta("dim") as Vector3) / xs      # medidas da sala sem a ampliação (coordenadas locais do nó)
		var ey := 1.65 / xs
		var poses := [
			["fora", Vector3(dim.x * 0.5, ey, -6.5), Vector3(dim.x * 0.5, ey * 0.95, 0.6)],
			["in1", Vector3(dim.x * 0.5, ey, 0.5), Vector3(dim.x * 0.5, ey * 0.7, dim.z)],
			["in2", Vector3(dim.x * 0.5, ey, dim.z - 0.7), Vector3(dim.x * 0.5, ey * 1.05, 0.0)],
			["in3", Vector3(dim.x - 0.7, ey, dim.z - 0.7), Vector3(dim.x * 0.15, ey * 0.7, dim.z * 0.2)],
		]
		for ps in poses:
			var pos: Vector3 = sl.global_transform * (ps[1] as Vector3)
			var alvo: Vector3 = sl.global_transform * (ps[2] as Vector3)
			p.global_position = pos - Vector3(0, 1.6, 0)
			p.cam.look_at(alvo, Vector3.UP)
			p.cam.fov = 74.0
			for i in 4:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [saida, id, ps[0]])
		print("[casas] ", id)
	quit()
