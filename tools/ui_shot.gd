extends SceneTree
## Tira capturas do menu e dos efeitos de medo (precisa de display; use xvfb).
## godot --path . --rendering-driver opengl3 --script res://tools/ui_shot.gd -- <pasta_de_saida>

func _init() -> void:
	var out := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame
	var p := main.get_node("Jogador") as Player
	var s := 143.0
	var t := Route.tangent(s)
	p.global_position = Route.pos(s) + Vector3(0, 0.3, 0)
	p.rotation.y = atan2(-t.x, -t.z)
	p.cam.rotation.x = deg_to_rad(12)
	p.set_physics_process(false)
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ui_a_normal.png")
	var hud := main.get_node("Interface") as Hud
	hud.set_fear(0.9, 110.0)
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ui_b_medo.png")
	hud.set_fear(0.0, 60.0)
	var menu := Menu.new()
	main.add_child(menu)
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ui_c_menu.png")
	menu._show_options()
	for i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ui_d_opcoes.png")
	print("[ui] ok")
	quit()
