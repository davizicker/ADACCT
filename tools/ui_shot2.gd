extends SceneTree
## Captura do painel de bilhete e do aviso de interação. godot --path . --rendering-driver opengl3 --script res://tools/ui_shot2.gd -- <pasta>
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 6:
		await process_frame
	var menu := main.get("menu") as Node
	if menu != null:
		menu.call("close")
	var p := main.get_node("Jogador") as Player
	var s := 141.0
	var t := Route.tangent(s)
	p.global_position = Route.pos(s) + Vector3(0, 0.3, 0)
	p.rotation.y = atan2(-t.x, -t.z)
	p.cam.rotation.x = deg_to_rad(5)
	p.set_physics_process(false)
	var hud := main.get_node("Interface") as Hud
	hud.show_interact("[E] Ler bilhete")
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ui_e_interagir.png")
	hud.show_interact("")
	var n: Array = Notas.TEXTOS[2]
	hud.show_note(n[0], n[1])
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ui_f_bilhete.png")
	print("[ui] ok")
	quit()
