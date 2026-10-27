extends SceneTree
## Renderiza UM modelo de 4 ângulos (frente, lado, topo, 3/4). godot --path . --rendering-driver opengl3 --script res://tools/preview_angles.gd -- res://x.glb <saida_prefixo>
func _bounds(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var local := xf
	if n is Node3D:
		local = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = local * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		var b := _bounds(c, local)
		if b.size == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var world := Node3D.new(); root.add_child(world)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.32, 0.34, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.7, 0.72, 0.8); env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new(); we.environment = env; world.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 35, 0); sun.light_energy = 1.4; world.add_child(sun)
	var cam := Camera3D.new(); cam.fov = 35; world.add_child(cam); cam.current = true
	root.size = Vector2i(512, 512)
	var inst := (load(a[0]) as PackedScene).instantiate() as Node3D
	world.add_child(inst)
	await process_frame
	var bb := _bounds(inst, Transform3D.IDENTITY)
	var c := bb.get_center()
	var r := bb.size.length() * 0.5
	var dirs := [Vector3(0, 0.1, 1), Vector3(1, 0.1, 0), Vector3(0.001, 1, 0.3), Vector3(0.9, 0.5, 1.0)]
	for i in 4:
		cam.position = c + (dirs[i] as Vector3).normalized() * r * 3.1
		cam.look_at(c, Vector3.UP if i != 2 else Vector3(0, 0, -1))
		for k in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [a[1], i])
	quit()
