extends SceneTree
## Fotografa cada porta de entrada (de frente, a 3 m). xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/foto_portas.gd -- <pasta>
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame
	var menu := main.get("menu") as Node
	if menu != null:
		menu.call("close")
	var p := main.get_node("Jogador") as Player
	p.set_physics_process(false)
	(main.get_node("Gritos") as Node).set("enabled", false)
	(main.get_node("Eventos") as Node).set("enabled", false)
	main.get_node("Interface").call("hide_note")
	p.frozen = false
	var portas := main.get_node("Vila").find_children("Entrada_*", "Area3D", true, false)
	for pt in portas:
		var a := pt as Node3D
		var par := a.get_parent() as Node3D
		var out_v: Vector3 = par.global_transform.basis.x * -1.0
		if par.has_meta("fora_local"):
			out_v = par.global_transform.basis * (par.get_meta("fora_local") as Vector3)
		p.global_position = a.global_position + out_v * 3.0 - Vector3(0, 1.0, 0)
		var d := a.global_position - p.cam.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.cam.rotation.x = deg_to_rad(3.0)
		for i in 6:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/porta_%s.png" % [out, a.name.substr(8)])
	print("[fotos] ok ", portas.size())
	quit()
