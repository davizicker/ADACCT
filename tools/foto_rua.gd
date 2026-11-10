extends SceneTree
## Passeio fotográfico pela rua (conferir objetos fora do lugar, casas, props): uma carga do jogo, 2 fotos (esquerda/direita) a cada `passo` metros.
## xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/foto_rua.gd -- <pasta> [passo=30] [s_ini=8] [s_fim=410] [escala=0.5]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var saida := a[0]
	var passo := float(a[1]) if a.size() > 1 else 30.0
	var s0 := float(a[2]) if a.size() > 2 else 8.0
	var s1 := float(a[3]) if a.size() > 3 else 410.0
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
	root.get_viewport().scaling_3d_scale = float(a[4]) if a.size() > 4 else 0.5
	var s := s0
	while s <= s1:
		var c := Route.pos(s)
		var fwd := (Route.pos(minf(s + 4.0, Route.length())) - c).normalized()
		var rgt := Route.right(s)
		for lado: float in [-1.0, 1.0]:
			var alvo := c + fwd * 7.0 + rgt * lado * 7.5 + Vector3(0, 1.5, 0)
			p.global_position = c
			p.cam.look_at(alvo, Vector3.UP)
			p.cam.fov = 78.0
			for i in 4:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/s%03d_%s.png" % [saida, int(s), "E" if lado < 0.0 else "D"])
		print("[rua] s=", s)
		s += passo
	quit()
