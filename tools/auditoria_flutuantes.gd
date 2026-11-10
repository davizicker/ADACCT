extends SceneTree
## Auditoria de objetos FORA DO LUGAR na vila (exterior): flutuando, enterrados, dentro de casa/muro ou no meio da rua.
## Uso: godot --headless --script res://tools/auditoria_flutuantes.gd  -> imprime [flut] ... e um resumo [flut-resumo].
const GRUPOS := ["Adornos", "Props", "Coletaveis", "PropsEncosta", "MurosDasCurvas", "Ponte", "Adro", "Iluminacao", "Becos", "MurosEQuintais"]
var sp: PhysicsDirectSpaceState3D
var achados := {}

func _init() -> void:
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	# chão "visual" sem colisão (encostas, morros, leito do riacho): cria colisão só para a medição
	for gn in ["Terreno", "Morros", "Ponte"]:
		var gt := v.get_node_or_null(gn)
		if gt == null:
			continue
		for mi in gt.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var p := String(m.get_path())
			if p.contains("CasasDoMorro") or p.contains("Arvores") or p.contains("Mata") or p.contains("Capela") or m.mesh == null:
				continue
			if m.get_aabb().size.y < 0.05 and m.get_aabb().size.x < 3.0:
				continue
			m.create_trimesh_collision()
	for i in 3:
		await physics_frame
	sp = root.get_world_3d().direct_space_state
	for gname in GRUPOS:
		var g := v.get_node_or_null(gname)
		if g == null:
			continue
		for c in g.get_children():
			if c is Node3D:
				_checar_no(c as Node3D, gname)
	for dn in ["Detalhes", "Realismo", "Morros/Arvores"]:
		var d := v.get_node_or_null(dn)
		if d:
			for mmi in d.find_children("*", "MultiMeshInstance3D", true, false):
				_checar_mm(mmi as MultiMeshInstance3D, dn)
	for k in achados:
		print("[flut-resumo] ", k, " ", achados[k])
	quit()


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var ok := false
	for vi in n.find_children("*", "VisualInstance3D", true, false):
		if vi is Light3D or vi is Decal or vi is GPUParticles3D or vi is Label3D:
			continue
		var g := vi as VisualInstance3D
		var bb := g.global_transform * g.get_aabb()
		if bb.size.length() > 60.0:
			continue
		out = bb if not ok else out.merge(bb)
		ok = true
	if n is VisualInstance3D and not ok:
		out = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
	return out


func _rids(n: Node) -> Array[RID]:
	var r: Array[RID] = []
	if n is CollisionObject3D:
		r.append((n as CollisionObject3D).get_rid())
	for c in n.find_children("*", "CollisionObject3D", true, false):
		r.append((c as CollisionObject3D).get_rid())
	return r


func _anota(cat: String) -> void:
	achados[cat] = int(achados.get(cat, 0)) + 1


func _checar_no(n: Node3D, grupo: String) -> void:
	var nm := String(n.name)
	if nm.begins_with("@") or nm.begins_with("Muro") or nm.begins_with("Laje") or nm.begins_with("Riacho") or nm.begins_with("Cachoeira") or nm.begins_with("Igreja") or nm.begins_with("Fios") or nm.begins_with("Quintal") or nm.begins_with("Beco") or nm.begins_with("Parapeito") or nm.begins_with("Mureta") or nm.begins_with("AdroDetalhes") or nm.begins_with("PedrasDoLeito") or nm.begins_with("Chafariz") or nm.begins_with("Varais"):
		return
	if nm.begins_with("LampiaoParede") or nm.begins_with("LampiaoCurva"):
		return            # preso na parede de propósito
	var bb := _aabb(n)
	if bb.size == Vector3.ZERO:
		return
	var c := bb.get_center()
	var base := bb.position.y
	var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, base + 0.6, c.z), Vector3(c.x, base - 10.0, c.z))
	q.exclude = _rids(n)
	var h := sp.intersect_ray(q)
	var s := Route.nearest_s(c)
	var na_rua := Route.dist_to_center(c) < Route.width(s) * 0.5 - 0.4 and grupo != "Coletaveis"
	if h.is_empty():
		print("[flut] VAZIO %s/%s em %s (s=%.0f): nada embaixo" % [grupo, nm, str(c.snapped(Vector3.ONE * 0.1)), s])
		_anota("vazio")
		return
	var gap := base - (h.position as Vector3).y
	var col := h.collider as Node
	var onde := "%s/%s" % [col.get_parent().name, col.name]
	var arvore := nm.contains("arvore") or nm.contains("Cipreste") or nm.contains("palmeira") or nm.contains("bananeira") or nm.contains("Arbusto") or nm.contains("Tora")
	var limite_enterrado := -0.9 if arvore else -0.25
	if gap > 0.08:
		print("[flut] FLUTUA %.2f m %s/%s em %s (s=%.0f) sobre %s" % [gap, grupo, nm, str(c.snapped(Vector3.ONE * 0.1)), s, onde])
		_anota("flutua")
	elif gap < limite_enterrado:
		print("[flut] ENTERRADO %.2f m %s/%s em %s (s=%.0f) sobre %s" % [gap, grupo, nm, str(c.snapped(Vector3.ONE * 0.1)), s, onde])
		_anota("enterrado")
	if onde.contains("Telhado") or (onde.contains("Corpo") and not grupo == "Coletaveis"):
		print("[flut] EM_CASA %s/%s em %s (s=%.0f) sobre %s" % [grupo, nm, str(c.snapped(Vector3.ONE * 0.1)), s, onde])
		_anota("em_casa")
	if na_rua and not nm.begins_with("Poste") and not nm.begins_with("Esconderijo") and not nm.begins_with("Rato"):
		print("[flut] NA_RUA %s/%s em %s (s=%.0f)" % [grupo, nm, str(c.snapped(Vector3.ONE * 0.1)), s])
		_anota("na_rua")


func _checar_mm(mmi: MultiMeshInstance3D, grupo: String) -> void:
	var mm := mmi.multimesh
	if mm == null:
		return
	var ruins := 0
	var exemplo := ""
	var passo := maxi(1, mm.instance_count / 600)
	var vistos := 0
	for i in range(0, mm.instance_count, passo):
		vistos += 1
		var p: Vector3 = (mmi.global_transform * mm.get_instance_transform(i)).origin
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.35, 0), p - Vector3(0, 4.0, 0))
		var h := sp.intersect_ray(q)
		var gap := 9.0 if h.is_empty() else p.y - (h.position as Vector3).y
		if gap > 0.12 or gap < -0.30:
			ruins += 1
			if exemplo == "":
				exemplo = "%s gap=%.2f" % [str(p.snapped(Vector3.ONE * 0.1)), gap]
	if ruins > 0:
		print("[flut] MM %s/%s: %d de %d amostras fora do chão (%.0f%%) ex: %s" % [grupo, mmi.name, ruins, vistos, 100.0 * ruins / vistos, exemplo])
		_anota("mm_" + grupo)
