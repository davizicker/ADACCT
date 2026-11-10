class_name Assentar
extends RefCounted
## Passada final do bake: ENCOSTA NO CHÃO REAL tudo que foi posto pela altura do terreno antes de o mapa ser esculpido
## (muros de arrimo, becos, quintais, riacho) e REMOVE o que ficou dentro de casa/muro ou boiando sobre o vazio.
## Vale para: matos, musgos, flores, folhas, seixos, cogumelos e galhos (MultiMesh), arbustos e toras das encostas,
## árvores das curvas, plantas da ponte e do adro, e caixotes/barris (estes só descem até o chão, nunca são removidos).

var sp: PhysicsDirectSpaceState3D
var _tmp: Array[Node] = []
var rel := {"mm_assentados": 0, "mm_removidos": 0, "nos_assentados": 0, "nos_removidos": 0}


func rodar(vila: Node3D, tree: SceneTree) -> Dictionary:
	await tree.process_frame                     # a vila só fica "dentro da árvore" no quadro seguinte (caminhos e física)
	_chao_temporario(vila)
	for i in 3:
		await tree.physics_frame
	sp = vila.get_world_3d().direct_space_state
	for dn in ["Detalhes", "Realismo"]:
		var d := vila.get_node_or_null(dn)
		if d:
			for mmi in d.find_children("*", "MultiMeshInstance3D", true, false):
				if String(mmi.name).begins_with("Rochas") or String(mmi.name).begins_with("Pocas"):
					continue                       # pedras ficam meio enterradas de propósito; poças são decalque da rua
				_mm(mmi as MultiMeshInstance3D)
	for gn in ["PropsEncosta", "MurosDasCurvas", "Ponte", "Adro", "Adornos", "Props"]:
		var g := vila.get_node_or_null(gn)
		if g == null:
			continue
		for c in g.get_children():
			if c is Node3D:
				_no(c as Node3D, gn)
	for t in _tmp:
		t.get_parent().remove_child(t)
		t.free()
	return rel


## Colisão provisória do terreno visual (encostas, morros e margens do riacho): só existe durante esta passada.
func _chao_temporario(vila: Node3D) -> void:
	for gn in ["Terreno", "Morros", "Ponte"]:
		var gt := vila.get_node_or_null(gn)
		if gt == null:
			continue
		for mi in gt.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var p := String(m.get_path())
			if m.mesh == null or p.contains("CasasDoMorro") or p.contains("Arvores") or p.contains("Mata") or p.contains("Capela") or p.contains("Luzes"):
				continue
			if gn == "Ponte" and not (p.contains("Riacho") or p.contains("Margem") or p.contains("Leito") or p.contains("Pedras") or p.contains("Laje")):
				continue
			var body := StaticBody3D.new()
			body.name = "ChaoTmp"
			var cs := CollisionShape3D.new()
			cs.shape = m.mesh.create_trimesh_shape()
			body.add_child(cs)
			m.add_child(body)
			_tmp.append(body)


func _e_chao(col: Object) -> bool:
	var n := col as Node
	if n == null:
		return false
	var p := String(n.get_path())
	return n.name == "ChaoTmp" or p.contains("/Rua/") or p.contains("/Terreno/") or p.contains("Rampa") or p.contains("/Ponte/") or p.contains("Degraus") or p.contains("Adro/")


func _e_agua(col: Object) -> bool:
	var n := col as Node
	if n == null or n.get_parent() == null:
		return false
	var pn := String(n.get_parent().name) + "/" + String(n.name)
	for w in ["Riacho", "Espuma", "Agua", "Cachoeira", "Queda", "Poco"]:
		if pn.contains(w):
			return true
	return false


## Primeiro chão debaixo de `p` (procura de 0,8 m acima até 8 m abaixo). Retorna {} se não há nada (vazio).
func _chao(p: Vector3, excluir: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.8, 0), p - Vector3(0, 8.0, 0))
	q.hit_from_inside = true
	q.exclude = excluir
	return sp.intersect_ray(q)


func _mm(mmi: MultiMeshInstance3D) -> void:
	var mm := mmi.multimesh
	if mm == null or mm.instance_count == 0:
		return
	var inv := mmi.global_transform.affine_inverse()
	var manter: Array[Transform3D] = []
	var cores: Array[Color] = []
	var usa_cor := mm.use_colors
	for i in mm.instance_count:
		var xl := mm.get_instance_transform(i)
		var xg := mmi.global_transform * xl
		var h := _chao(xg.origin)
		if h.is_empty() or not _e_chao(h.collider) or _e_agua(h.collider) or (h.normal as Vector3) == Vector3.ZERO:
			rel["mm_removidos"] += 1          # dentro de casa/muro, em cima de telhado ou boiando sobre o vazio
			continue
		var gy: float = (h.position as Vector3).y
		if absf(xg.origin.y - gy) > 0.04:
			xg.origin.y = gy - 0.02
			xl = inv * xg
			rel["mm_assentados"] += 1
		manter.append(xl)
		if usa_cor:
			cores.append(mm.get_instance_color(i))
	if manter.size() == mm.instance_count:
		return
	mm.instance_count = 0
	mm.instance_count = manter.size()
	for i in manter.size():
		mm.set_instance_transform(i, manter[i])
		if usa_cor:
			mm.set_instance_color(i, cores[i])


func _rids(n: Node) -> Array[RID]:
	var r: Array[RID] = []
	if n is CollisionObject3D:
		r.append((n as CollisionObject3D).get_rid())
	for c in n.find_children("*", "CollisionObject3D", true, false):
		r.append((c as CollisionObject3D).get_rid())
	return r


func _base(n: Node3D) -> float:
	var ok := false
	var y := 0.0
	for vi in n.find_children("*", "VisualInstance3D", true, false):
		if vi is Light3D or vi is Decal or vi is GPUParticles3D or vi is Label3D:
			continue
		var bb := (vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb()
		if bb.size.length() > 60.0:
			continue
		y = bb.position.y if not ok else minf(y, bb.position.y)
		ok = true
	if n is VisualInstance3D:
		var bb2 := (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
		y = bb2.position.y if not ok else minf(y, bb2.position.y)
		ok = true
	return y if ok else n.global_position.y


func _no(n: Node3D, grupo: String) -> void:
	var nm := String(n.name)
	var planta := nm.contains("arvore") or nm.contains("Cipreste") or nm.contains("palmeira") or nm.contains("bananeira") or nm.contains("Arbusto") or nm.contains("Tora") or nm.contains("mato") or nm.contains("periwinkle") or nm.contains("weed") or nm.contains("rooibos") or nm.contains("grass_tuft")
	var solto := grupo == "Adornos" or (grupo == "Props" and (nm.begins_with("wine_barrel") or nm.begins_with("wooden_") or nm.begins_with("watering") or nm.begins_with("rusted") or nm.begins_with("Bola")))
	if not planta and not solto:
		return
	if grupo == "Adro" and (nm.contains("weed") or nm.contains("rooibos")):
		return                                   # plantas dentro dos vasos da igreja
	var base := _base(n)
	var p := Vector3(n.global_position.x, base, n.global_position.z)
	var h := _chao(p, _rids(n))
	if h.is_empty():
		if planta:
			n.get_parent().remove_child(n)
			n.free()
			rel["nos_removidos"] += 1
		return
	var gy: float = (h.position as Vector3).y
	var chao_ok := _e_chao(h.collider) and not _e_agua(h.collider) and (h.normal as Vector3) != Vector3.ZERO
	if planta and not chao_ok:
		n.get_parent().remove_child(n)
		n.free()
		rel["nos_removidos"] += 1
		return
	if solto and not chao_ok:
		return                                   # caixote em cima de outro caixote/mureta: fica
	var afunda := 0.25 if (nm.contains("arvore") or nm.contains("Cipreste") or nm.contains("palmeira") or nm.contains("bananeira")) else 0.03
	var alvo := gy - (afunda if planta else 0.0)
	if absf(base - alvo) > 0.05:
		n.global_position.y += alvo - base
		rel["nos_assentados"] += 1
