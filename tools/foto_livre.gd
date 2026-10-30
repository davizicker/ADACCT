extends SceneTree
## Foto com câmera livre (sem jogador): godot --path . --script res://tools/foto_livre.gd -- x y z alvo_x alvo_y alvo_z saida.png [fov] [dia]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
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
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	(main.get_node("Gritos") as Node).set("enabled", false)
	(main.get_node("Eventos") as Node).set("enabled", false)
	main.get_node("Interface").call("hide_note")
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(float(a[0]), float(a[1]), float(a[2]))
	cam.look_at(Vector3(float(a[3]), float(a[4]), float(a[5])), Vector3.UP)
	cam.fov = float(a[7]) if a.size() > 7 else 60.0
	cam.far = 1500.0
	cam.make_current()
	if a.size() > 9 and a[9] == "sem_oclusao":
		root.use_occlusion_culling = false
	p.global_position = cam.global_position + Vector3(0, 300, 0)      # tira o jogador (e o braço) da foto
	if a.size() > 8 and a[8] == "dia":
		var amb := main.get_node("Vila").get_node_or_null("Ambiente") as WorldEnvironment
		if amb:
			amb.environment.ambient_light_energy = 3.0
			amb.environment.fog_enabled = false
			amb.environment.volumetric_fog_enabled = false
			amb.environment.ssao_enabled = false
			amb.environment.adjustment_enabled = true
			amb.environment.adjustment_brightness = 1.6
	if a.size() > 10:
		var alvo := main.get_node_or_null("Vila/Casas/" + str(a[10]))
		if alvo != null:
			for fil in str(a[11] if a.size() > 11 else "Corpo").split(","):
				var nn := alvo.get_node_or_null(fil) as Node3D
				if nn != null:
					nn.visible = false
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(a[6])
	quit()
