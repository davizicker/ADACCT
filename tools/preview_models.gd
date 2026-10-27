extends SceneTree
## Renderiza uma prévia de cada .glb de uma pasta e imprime tamanho (m) e nº de triângulos.
## godot --path . --rendering-driver opengl3 --script res://tools/preview_models.gd -- <res://pasta> <saida_dir>

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
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


func _tris(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m := (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	for c in n.get_children():
		t += _tris(c)
	return t


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var outdir: String = args[1]
	var names: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb"):
			names.append(f)
	names.sort()
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.34, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.4
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 35
	world.add_child(cam)
	cam.current = true
	root.size = Vector2i(512, 512)
	for nm in names:
		var ps := load(dir + "/" + nm) as PackedScene
		if ps == null:
			print("[prev] %s: NAO CARREGOU" % nm)
			continue
		var inst := ps.instantiate() as Node3D
		world.add_child(inst)
		await process_frame
		var bb := _bounds(inst, Transform3D.IDENTITY)
		var c := bb.get_center()
		var r := maxf(bb.size.length() * 0.5, 0.01)
		cam.position = c + Vector3(0.9, 0.55, 1.0).normalized() * r * 3.1
		cam.look_at(c, Vector3.UP)
		for i in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [outdir, nm.get_basename()])
		print("[prev] %-24s tris=%6d  tamanho(m): x=%.2f y=%.2f z=%.2f  (pes em y=%.2f)" % [nm.get_basename(), _tris(inst), bb.size.x, bb.size.y, bb.size.z, bb.position.y])
		inst.queue_free()
		await process_frame
	quit()
