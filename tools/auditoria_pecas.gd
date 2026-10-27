extends SceneTree
## Auditoria de peças soltas: objetos que não encostam no chão (flutuando) ou estão afundados, e props que se atravessam.
## godot --headless --path . --script res://tools/auditoria_pecas.gd

func _aabb_of(n: Node3D) -> AABB:
	var have := false
	var out := AABB()
	for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var bb := m.global_transform * m.mesh.get_aabb()
		if m.name.begins_with("Halo") or m.name.begins_with("Brilho") or m.name == "Tela":
			continue
		out = bb if not have else out.merge(bb)
		have = true
	return out if have else AABB()


func _rids(n: Node) -> Array[RID]:
	var r: Array[RID] = []
	for co in n.find_children("*", "CollisionObject3D", true, false):
		r.append((co as CollisionObject3D).get_rid())
	if n is CollisionObject3D:
		r.append((n as CollisionObject3D).get_rid())
	return r


func _init() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	var vila := main.get_node("Vila")
	var space := root.world_3d.direct_space_state
	var excl: Array[RID] = [(main.get_node("Jogador") as CollisionObject3D).get_rid()]
	var flut := 0
	var afund := 0
	var total := 0
	var items: Array[Dictionary] = []
	for grupo in ["Props", "Adornos", "Coletaveis"]:
		var g := vila.get_node_or_null(grupo)
		if g == null:
			continue
		for c in g.get_children():
			if not (c is Node3D):
				continue
			var bb := _aabb_of(c as Node3D).abs()
			if bb.size == Vector3.ZERO or bb.size.x > 8.0 or bb.size.z > 8.0 or c.name == "Pecas":
				continue
			total += 1
			items.append({"n": c, "bb": bb, "g": grupo})
			var ctr := bb.get_center()
			# vários pontos da base: o menor vão ao chão
			var gap := 1e9
			for off in [Vector3.ZERO, Vector3(bb.size.x * 0.3, 0, 0), Vector3(-bb.size.x * 0.3, 0, 0), Vector3(0, 0, bb.size.z * 0.3), Vector3(0, 0, -bb.size.z * 0.3)]:
				var p: Vector3 = ctr + off
				var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, bb.position.y + 0.3, p.z), Vector3(p.x, bb.position.y - 6.0, p.z))
				q.exclude = excl + _rids(c)
				var hit := space.intersect_ray(q)
				if not hit.is_empty():
					gap = minf(gap, bb.position.y - (hit["position"] as Vector3).y)
			var nm: String = (c as Node).name
			# coisas penduradas na parede / em cima de outras são normais
			var pendurado: bool = nm.contains("Lampiao") or nm.contains("Lanterna") or nm.contains("Placa") or nm.contains("Varal") or nm.contains("Bandeir") or nm.contains("Linha") or nm.contains("Vaso")
			if gap > 0.25 and gap < 1e8 and not pendurado:
				flut += 1
				print("[pecas] FLUTUANDO %s/%s: base a %.2f m do chao em (%.1f, %.1f, %.1f)" % [grupo, nm, gap, ctr.x, bb.position.y, ctr.z])
			elif gap < -0.45 and not pendurado:
				afund += 1
				print("[pecas] AFUNDADO %s/%s: base %.2f m abaixo do chao" % [grupo, nm, -gap])
	# props atravessando props (volumes se sobrepõem mais que 12 cm em todos os eixos)
	var cruz := 0
	for i in items.size():
		for j in range(i + 1, items.size()):
			var a: AABB = (items[i]["bb"] as AABB).grow(-0.06)
			var b: AABB = (items[j]["bb"] as AABB).grow(-0.06)
			if a.size.x < 0.0 or a.size.y < 0.0 or a.size.z < 0.0 or b.size.x < 0.0 or b.size.y < 0.0 or b.size.z < 0.0:
				continue
			if a.intersects(b):
				var ni: String = (items[i]["n"] as Node).name
				var nj: String = (items[j]["n"] as Node).name
				print("[pecas] ATRAVESSAM: %s e %s (%.1f, %.1f, %.1f)" % [ni, nj, a.get_center().x, a.get_center().y, a.get_center().z])
				cruz += 1
	print("[pecas] %d itens | flutuando %d | afundados %d | atravessando %d" % [total, flut, afund, cruz])
	quit()
