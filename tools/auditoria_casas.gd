extends SceneTree
## Mapa de casas fora do lugar: casa (ou quintal) no meio da RUA/calçada, dentro de BECO, atravessando OUTRA CASA ou um MURO.
## Uso: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/auditoria_casas.gd  -> linhas [casas-aud] e resumo
var sp: PhysicsDirectSpaceState3D
var resumo := {}


func _init() -> void:
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	await process_frame
	for i in 3:
		await physics_frame
	sp = root.get_world_3d().direct_space_state
	var lotes: Array = []
	for c in v.get_node("Casas").get_children():
		lotes.append(c)
	for c in v.get_node("MurosEQuintais").get_children():
		if String(c.name).begins_with("Quintal"):
			lotes.append(c)
	lotes.append(v.get_node("FundoDaRua/Casarao"))
	var n_casas := 0
	for c in lotes:
		n_casas += 1
		_checa(c as Node3D)
	for k in resumo:
		print("[casas-aud-resumo] ", k, " ", resumo[k])
	print("[casas-aud] lotes verificados: %d" % n_casas)
	quit()


func _conta(k: String) -> void:
	resumo[k] = int(resumo.get(k, 0)) + 1


func _caixas(n: Node3D) -> Array:
	# caixas de colisão do corpo da casa (Corpo, CorpoPedra, Casca*, Muro do quintal)
	var out: Array = []
	for cs in n.find_children("*", "CollisionShape3D", true, false):
		var c := cs as CollisionShape3D
		var dono := String(c.get_parent().get_parent().name) if c.get_parent().get_parent() else ""
		var nome := String(c.get_parent().name)
		if not (c.shape is BoxShape3D):
			continue
		if nome.begins_with("Corpo") or dono.begins_with("Corpo") or dono.begins_with("Casca") or dono == "Muro" or nome == "Colisao" and (dono.begins_with("Corpo") or dono == "Muro"):
			out.append(c)
	return out


func _checa(c: Node3D) -> void:
	var achou := {}
	for cs: CollisionShape3D in _caixas(c):
		var box := cs.shape as BoxShape3D
		var xf := cs.global_transform
		var meio := box.size * 0.5 - Vector3(0.15, 0.0, 0.15)
		# 1) pontos da planta da caixa contra a faixa da rua + calçada
		var nx := maxi(2, int(meio.x * 2.0 / 0.5))
		var nz := maxi(2, int(meio.z * 2.0 / 0.5))
		for ix in nx + 1:
			for iz in nz + 1:
				var lp := Vector3(-meio.x + 2.0 * meio.x * ix / nx, 0.0, -meio.z + 2.0 * meio.z * iz / nz)
				var p := xf * lp
				var s := Route.nearest_s(p)
				if s > 1.0 and s < Route.length() - 1.0 and Route.dist_to_center(p) < Route.width(s) * 0.5 + Route.SIDEWALK - 0.05 and absf(p.y - Route.height(s)) < 6.0:
					achou["NA RUA/CALÇADA (s=%.0f)" % s] = true
					break
		# 2) caixa (encolhida) contra becos, outras casas e muros
		var sh := BoxShape3D.new()
		sh.size = (box.size - Vector3(0.3, 0.0, 0.3)).max(Vector3(0.05, 0.05, 0.05))
		sh.size.y = box.size.y - 4.6             # sem a parte enterrada nem o rente ao chão
		if sh.size.y < 0.3:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sh
		q.transform = Transform3D(xf.basis.orthonormalized(), xf * Vector3(0, 2.3 - 0.0, 0) if box.size.y > 6.0 else xf.origin)
		for h in sp.intersect_shape(q, 24):
			var o := h["collider"] as Node
			if o == null or c.is_ancestor_of(o):
				continue
			var path := String(o.get_path()).replace("/root/Vila/", "")
			if path.begins_with("Rua/") or path.begins_with("Terreno/") or path.contains("Barreiras") or path.contains("Adornos") or path.contains("Props/") or path.contains("Nichos") or path.contains("Iluminacao"):
				continue
			if path.begins_with("Becos/"):
				achou["DENTRO DE BECO: " + path.get_slice("/", 1)] = true
			elif path.begins_with("Casas/") and not path.contains("Telhado"):
				achou["ATRAVESSA OUTRA CASA: " + path.get_slice("/", 1) + " (" + path.get_slice("/", path.get_slice_count("/") - 2) + "/" + path.get_slice("/", path.get_slice_count("/") - 1) + ")"] = true
			elif path.begins_with("MurosEQuintais/") or path.begins_with("MurosDasCurvas/"):
				achou["ATRAVESSA MURO: " + path.get_slice("/", 0) + "/" + path.get_slice("/", 1)] = true
			elif path.begins_with("Adro/") or path.begins_with("Ponte/"):
				achou["ATRAVESSA " + path.get_slice("/", 0) + ": " + path.get_slice("/", 1)] = true
	for k in achou:
		print("[casas-aud] %s (s=%.0f): %s" % [_caminho(c), Route.nearest_s(c.global_position), k])
		_conta(String(k).get_slice(":", 0).get_slice(" (", 0))


func _caminho(n: Node) -> String:
	return String(n.get_path()).replace("/root/Vila/", "")
