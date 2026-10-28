extends SceneTree
## Auditoria "fora do lugar": pedras/plantas em cima da rua, e árvores/arbustos individuais flutuando ou enterrados.
## xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/auditoria_lugar.gd

func _init() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	var vila := main.get_node("Vila")
	var space := root.world_3d.direct_space_state
	var excl: Array[RID] = [(main.get_node("Jogador") as CollisionObject3D).get_rid()]
	# A) MultiMesh de pedras e plantas: nada em cima do leito da rua (exceto o que nasce na calçada/frestas de propósito)
	var na_rua := 0
	var total := 0
	for mmi in vila.find_children("*", "MultiMeshInstance3D", true, false):
		var m := mmi as MultiMeshInstance3D
		var nome := m.name
		var rocha := nome.begins_with("Rochas")
		var arvore := nome.begins_with("arvore") or nome.begins_with("palmeira")
		var encosta := nome.begins_with("Mato_a_") or nome.begins_with("Mato_b_") or nome.begins_with("Mato_c_") or nome.begins_with("Tufo_c") or nome.begins_with("Tufo_d") or nome.begins_with("Vinca_c") or nome.contains("_encosta_")
		if nome.contains("calcada") or nome.contains("_rua"):
			encosta = false
		if not (rocha or arvore or encosta):
			continue
		for i in m.multimesh.instance_count:
			var p := (m.global_transform * m.multimesh.get_instance_transform(i)).origin
			total += 1
			var d := Route.dist_to_center(p)
			var s := Route.nearest_s(p)
			var lim := Route.width(s) * 0.5 + (2.5 if rocha else 1.0)
			if d < lim and s < Route.S_END + 40.0:
				na_rua += 1
				if na_rua <= 25:
					print("[lugar] %s #%d em cima da rua: dist=%.1f (limite %.1f) s=%.0f em (%.1f, %.1f, %.1f)" % [nome, i, d, lim, s, p.x, p.y, p.z])
	# B) árvores/arbustos individuais: base a menos de 0.35 m do terreno, sem flutuar nem afundar
	var flut := 0
	var afund := 0
	var nn := 0
	for grupo in ["Morros/Arvores", "PropsEncosta", "Morros/Mata", "Becos", "MurosEQuintais"]:
		var g := vila.get_node_or_null(grupo)
		if g == null:
			continue
		for n in g.find_children("*", "Node3D", true, false):
			var nm := String(n.name)
			if not (nm.begins_with("arvore") or nm.begins_with("palmeira") or nm.begins_with("bananeira") or nm.begins_with("rooibos") or nm.begins_with("Arbusto") or nm.begins_with("Tora") or nm.begins_with("tronco")):
				continue
			if not (n.get_child_count() > 0 and (n.get_child(0) is MeshInstance3D)):
				continue
			nn += 1
			var p := (n as Node3D).global_position
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p - Vector3(0, 6.0, 0))
			q.exclude = excl
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var gap := p.y - (hit["position"] as Vector3).y
			if gap > 0.6:
				flut += 1
				print("[lugar] FLUTUANDO %s: %.2f m acima do chão em (%.1f, %.1f, %.1f)" % [nm, gap, p.x, p.y, p.z])
			elif gap < -1.2:
				afund += 1
				print("[lugar] AFUNDADO %s: %.2f m abaixo do chão em (%.1f, %.1f, %.1f)" % [nm, -gap, p.x, p.y, p.z])
	print("[lugar] instancias verificadas=%d na_rua=%d | individuais=%d flutuando=%d afundados=%d" % [total, na_rua, nn, flut, afund])
	quit()
