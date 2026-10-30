extends SceneTree
## Fotografa a porta de TODAS as casas (de frente, a 3,2 m): godot --path . --script res://tools/foto_todas_portas.gd -- <pasta>
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
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
	var amb := main.get_node("Vila").get_node_or_null("Ambiente") as WorldEnvironment
	if amb:
		amb.environment.ambient_light_energy = 3.0
		amb.environment.fog_enabled = false
		amb.environment.volumetric_fog_enabled = false
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 62.0
	cam.make_current()
	var casas := main.get_node("Vila/Casas").get_children()
	var n := 0
	for c in casas:
		if not c.has_meta("door_z"):
			continue
		var xf: Transform3D = (c as Node3D).global_transform
		var dz: float = c.get_meta("door_z")
		var porta := xf * Vector3(-0.1, 1.3, dz)
		var fora := xf.basis * Vector3(-1, 0, 0)
		p.global_position = porta + Vector3(0, 300, 0)
		cam.global_position = porta + fora * 3.4 + Vector3(0, 0.5, 0)
		cam.look_at(porta + Vector3(0, -0.2, 0), Vector3.UP)
		for i in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/porta_%03d_%s.png" % [out, n, c.name])
		n += 1
	print("[fotos] ", n)
	quit()
