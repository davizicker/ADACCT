extends SceneTree
## Fotografa o interior de cada casa (3 ângulos) e as portas na rua. Precisa de display (xvfb).
## godot --path . --rendering-driver opengl3 --script res://tools/foto_interiores.gd -- <pasta>
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
	var missao := main.get_node("Missao")
	for id in Interiores.ORDEM:
		var sala := main.get_node("Vila/Interiores/" + id) as Node3D
		missao.dentro = id
		var w: float = (sala.get_meta("spawn") as Vector3).x * 2.0
		var cams := [[Vector3(w * 0.5, 0.1, 1.0), 0.0], [Vector3(w * 0.9, 0.1, 1.0), 25.0], [Vector3(w * 0.1, 0.1, 1.0), -25.0]]
		var k := 0
		for c in cams:
			p.global_position = sala.global_position + (c[0] as Vector3)
			p.rotation.y = PI + deg_to_rad(float(c[1]))
			p.cam.rotation.x = deg_to_rad(-4.0)
			for i in 6:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/int_%s_%d.png" % [out, id, k])
			k += 1
	# portas na rua
	missao.dentro = ""
	var portas := main.get_node("Vila/Casas").find_children("Entrada_*", "Area3D", true, false)
	for pt in portas:
		var a := pt as Node3D
		var out_v: Vector3 = -(a.get_parent() as Node3D).global_transform.basis.x
		p.global_position = a.global_position + out_v * 3.0 - Vector3(0, 1.0, 0)
		var d := a.global_position - p.cam.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.cam.rotation.x = deg_to_rad(5.0)
		for i in 6:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/porta_%s.png" % [out, a.name.substr(8)])
	print("[fotos] ok")
	quit()
