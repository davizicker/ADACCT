extends SceneTree
## Auditoria automática da geometria da vila (sem imagem). godot --headless --path . --script res://tools/auditoria_geom.gd
## Procura: objetos dentro de casas, itens enterrados ou flutuando, árvores em cima da rua, estatísticas de custo.

func _init() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	var vila := main.get_node("Vila")
	# ---------- contagens
	var meshes := vila.find_children("*", "MeshInstance3D", true, false)
	var mm := vila.find_children("*", "MultiMeshInstance3D", true, false)
	var lights := vila.find_children("*", "OmniLight3D", true, false)
	var bodies := vila.find_children("*", "StaticBody3D", true, false)
	var surfaces := 0
	var tris := 0
	var by_mat := {}
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			var mat: Material = mi.get_active_material(s)
			var key := mat.resource_path.get_file() if mat != null and mat.resource_path != "" else "(sem material)"
			by_mat[key] = int(by_mat.get(key, 0)) + 1
	print("[geom] MeshInstance3D=%d superficies=%d MultiMesh=%d OmniLight=%d StaticBody=%d" % [meshes.size(), surfaces, mm.size(), lights.size(), bodies.size()])
	var top: Array = by_mat.keys()
	top.sort_custom(func(a: String, b: String) -> bool: return by_mat[a] > by_mat[b])
	var line := "[geom] materiais com mais superficies: "
	for i in mini(8, top.size()):
		line += "%s=%d  " % [top[i], by_mat[top[i]]]
	print(line)
	# ---------- casas: caixas ORIENTADAS (a AABB exagera nas casas giradas)
	var corpos: Array[MeshInstance3D] = []
	for c in vila.get_node("Casas").get_children():
		var corpo := c.get_node_or_null("Corpo") as MeshInstance3D
		if corpo != null:
			corpos.append(corpo)
	var dentro := func(p: Vector3, m: MeshInstance3D, margem: float) -> bool:
		var q: Vector3 = m.global_transform.affine_inverse() * p
		var bb := m.mesh.get_aabb().grow(-margem)
		return bb.has_point(q)
	var problems := 0
	for it in get_nodes_in_group("interagivel"):
		if it is Porta:
			continue        # portas de beco ficam dentro do volume da casa vizinha de propósito
		var p: Vector3 = (it as Node3D).global_position + Vector3(0, 0.3, 0)
		for m in corpos:
			if dentro.call(p, m, 0.05):
				print("[geom] PROBLEMA: %s dentro de uma casa em %s" % [it.name, str(p)])
				problems += 1
		var gy := Route.ground_near((it as Node3D).global_position)
		var dy := (it as Node3D).global_position.y - gy
		if dy < 0.0 or dy > 0.6:
			print("[geom] AVISO: %s a %.2f m da rua (altura)" % [it.name, dy])
	var plantas := 0
	var g := vila.get_node_or_null("Morros/Arvores")
	if g != null:
		for pnt in g.get_children():
			plantas += 1
			var p3 := (pnt as Node3D).global_position + Vector3(0, 1.0, 0)
			for m in corpos:
				if dentro.call(p3, m, 0.0):
					print("[geom] PROBLEMA: arvore %s dentro de casa" % pnt.name)
					problems += 1
			var d := Route.dist_to_center(p3)
			var s := Route.nearest_s(p3)
			if d < Route.width(s) * 0.5 + 1.0:
				print("[geom] PROBLEMA: arvore %s em cima da rua (dist %.1f)" % [pnt.name, d])
				problems += 1
	# casas vizinhas: pontos de uma dentro da outra (interpenetração real)
	var overlaps := 0
	for i in corpos.size():
		var a_mi := corpos[i]
		var bb := a_mi.mesh.get_aabb()
		var pts: Array[Vector3] = []
		for fx in [0.15, 0.85]:
			for fz in [0.15, 0.85]:
				pts.append(a_mi.global_transform * (bb.position + Vector3(bb.size.x * fx, bb.size.y * 0.8, bb.size.z * fz)))
		for j in corpos.size():
			if i == j:
				continue
			for pt in pts:
				if dentro.call(pt, corpos[j], 0.2):
					overlaps += 1
					print("[geom] casas se atravessam: %s e %s em %s" % [a_mi.get_parent().name, corpos[j].get_parent().name, str(a_mi.global_position)])
					break
	print("[geom] casas=%d (casas com interpenetracao real: %d) plantas individuais=%d problemas=%d" % [corpos.size(), overlaps, plantas, problems])
	# ---------- buracos no chão: dispara raios de cima para baixo em toda a rua (a cada 0,5 m, em 7 posições laterais)
	var space := root.world_3d.direct_space_state
	var holes := 0
	var obstacles := 0
	var checked := 0
	var first_hole := ""
	var hole_list: Array[String] = []
	var s_probe := 0.4
	while s_probe <= Route.length() - 0.4:
		var c := Route.pos(s_probe)
		var r := Route.right(s_probe)
		var half := Route.width(s_probe) * 0.5
		for fr in [-0.95, -0.6, -0.3, 0.0, 0.3, 0.6, 0.95]:
			var wp: Vector3 = c + r * half * fr
			var q := PhysicsRayQueryParameters3D.create(wp + Vector3(0, 3.0, 0), wp + Vector3(0, -3.0, 0))
			q.exclude = [(main.get_node("Jogador") as CollisionObject3D).get_rid()]
			var hit := space.intersect_ray(q)
			checked += 1
			if hit.is_empty():
				holes += 1
				hole_list.append("s=%.1f lat=%.2f" % [s_probe, fr * half])
				if first_hole == "":
					first_hole = "s=%.1f lateral=%.2f" % [s_probe, fr * half]
			elif (hit["position"] as Vector3).y - wp.y < -0.35:
				holes += 1       # o chão está MAIS BAIXO que a rua: algo errado (degrau, rua afundada)
				if first_hole == "":
					first_hole = "s=%.1f lateral=%.2f (chao %.2f m abaixo do esperado)" % [s_probe, fr * half, (hit["position"] as Vector3).y - wp.y]
			elif (hit["position"] as Vector3).y - wp.y > 0.35:
				obstacles += 1   # algo acima da rua (parede do tanque, banco, barril): normal
		s_probe += 0.5
	print("[geom] chao da rua: %d pontos verificados, %d buracos %s (obstaculos propositais: %d)" % [checked, holes, first_hole, obstacles])
	if hole_list.size() > 0:
		print("[geom] lista de buracos: ", ", ".join(hole_list.slice(0, 20)))
	# ---------- altura máxima dos telhados e proporções
	var tallest := 0.0
	for m in corpos:
		tallest = maxf(tallest, m.mesh.get_aabb().size.y)
	print("[geom] corpo de casa mais alto: %.1f m (inclui 4 m enterrados)" % tallest)
	quit()
