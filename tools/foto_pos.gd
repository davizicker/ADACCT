extends SceneTree
## Foto de qualquer ponto do mundo (sem jogador): xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/foto_pos.gd -- x y z alvo_x alvo_y alvo_z saida.png [fov] [dia]
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
	(main.get_node("Gritos") as Node).set("enabled", false)
	(main.get_node("Eventos") as Node).set("enabled", false)
	main.get_node("Interface").call("hide_note")
	var pos := Vector3(float(a[0]), float(a[1]), float(a[2]))
	var alvo := Vector3(float(a[3]), float(a[4]), float(a[5]))
	p.global_position = pos - Vector3(0, 1.6, 0)
	p.cam.look_at(alvo, Vector3.UP)
	p.cam.fov = float(a[7]) if a.size() > 7 else 60.0
	if a.size() > 8 and a[8] == "dia":
		var amb := main.get_node("Vila").get_node_or_null("Ambiente") as WorldEnvironment
		if amb:
			amb.environment.ambient_light_energy = 1.6
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(a[6])
	quit()
