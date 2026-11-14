extends SceneTree
## Desempenho: do ponto s da rua, quantos objetos/triângulos cada grupo manda desenhar (dentro do alcance de visibilidade).
## Uso: --script res://tools/perf_vila.gd -- --s=60
func _initialize() -> void:
	var s := 60.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--s="):
			s = float(a.substr(4))
	var vila := (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(vila)
	await process_frame
	if not ("--cru" in OS.get_cmdline_user_args()):
		print("[perf-vila] alcances: ", Alcances.aplicar(vila))
	var p: Vector3 = Route.pos(s) + Vector3(0, 1.6, 0)
	var grupos := {}
	var total_o := 0
	var total_t := 0
	var sem_alcance := 0
	for gi in vila.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var bb := g.global_transform * g.get_aabb()
		var d := bb.get_center().distance_to(p) - bb.size.length() * 0.5
		var fim := g.visibility_range_end
		if (fim > 0.0 and d > fim) or (g.visibility_range_begin > 0.0 and d < g.visibility_range_begin):
			continue
		if fim <= 0.0:
			sem_alcance += 1
		var tris := 0
		var surf := 1
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var m := (g as MeshInstance3D).mesh
			surf = m.get_surface_count()
			for i in surf:
				var arr := m.surface_get_arrays(i)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh and (g as MultiMeshInstance3D).multimesh.mesh:
			var mm := (g as MultiMeshInstance3D).multimesh
			var m2 := mm.mesh
			surf = m2.get_surface_count()
			for i in surf:
				var arr := m2.surface_get_arrays(i)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += ((idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3) * mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		var path := String(vila.get_path_to(g)).split("/")
		var k := path[0] + ("/" + path[1].rstrip("0123456789_") if path.size() > 2 else "")
		if not grupos.has(k):
			grupos[k] = [0, 0, 0, 0]
		grupos[k][0] += 1
		grupos[k][1] += surf
		grupos[k][2] += tris
		if fim <= 0.0:
			grupos[k][3] += 1
		total_o += 1
		total_t += tris
	var ks := grupos.keys()
	ks.sort_custom(func(a, b) -> bool: return grupos[a][1] > grupos[b][1])
	print("[perf-vila] s=%.0f objetos=%d triangulos=%d sem_alcance=%d" % [s, total_o, total_t, sem_alcance])
	for k in ks.slice(0, 40):
		print("[perf-vila] %-40s obj=%5d superficies=%5d tri=%9d sem_alcance=%d" % [k, grupos[k][0], grupos[k][1], grupos[k][2], grupos[k][3]])
	quit()
