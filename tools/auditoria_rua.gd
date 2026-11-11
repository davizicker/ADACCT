extends SceneTree
## Auditoria da RUA INTEIRA (exterior): portas (soleira e frente livre), números das portas, objetos atravessando casas/muros/outros
## objetos e pedras do chão dentro de paredes, da rua ou da água. Uso:
## xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/auditoria_rua.gd  -> linhas [rua] e resumo [rua-resumo]
const PROPS := ["Adornos", "Props", "Coletaveis", "Iluminacao", "Nichos", "PropsEncosta", "MurosDasCurvas", "Adro", "Ratos", "Ponte"]
var sp: PhysicsDirectSpaceState3D
var resumo := {}
var vila: Node3D


func _init() -> void:
	vila = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(vila)
	await process_frame
	for i in 3:
		await physics_frame
	sp = root.get_world_3d().direct_space_state
	_portas()
	_objetos()
	_pedras()
	for k in resumo:
		print("[rua-resumo] ", k, " ", resumo[k])
	quit()


func _conta(k: String) -> void:
	resumo[k] = int(resumo.get(k, 0)) + 1


func _caminho(n: Node) -> String:
	return String(n.get_path()).replace("/root/Vila/", "")


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var ok := false
	for vi in n.find_children("*", "VisualInstance3D", true, false):
		if vi is Light3D or vi is Decal or vi is GPUParticles3D or vi is Label3D or String(vi.name).begins_with("Halo"):
			continue
		var g := vi as VisualInstance3D
		var bb := g.global_transform * g.get_aabb()
		if bb.size.length() > 40.0:
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


## Corpos sólidos que cruzam a caixa `bb` (encolhida e levantada do chão), sem contar o próprio objeto nem o chão.
func _cruza(bb: AABB, excluir: Array[RID]) -> Array[String]:
	var enc := bb.grow(-0.05)
	enc.position.y += 0.10
	enc.size.y -= 0.10
	if enc.size.x <= 0.02 or enc.size.y <= 0.02 or enc.size.z <= 0.02:
		return []
	var box := BoxShape3D.new()
	box.size = enc.size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis.IDENTITY, enc.get_center())
	q.exclude = excluir
	var out: Array[String] = []
	for h in sp.intersect_shape(q, 16):
		var c := h["collider"] as Node
		var p := _caminho(c)
		if p.begins_with("Rua/") or p.begins_with("Terreno/") or p.contains("/Ruela_") or p.contains("Barreiras") or c.name == "Colisao" and p.begins_with("Rua"):
			continue
		out.append(p)
	return out


# ------------------------------------------------------------------ portas
func _portas() -> void:
	var nums := {}
	for casa in vila.get_node("Casas").get_children():
		var c := casa as Node3D
		if not c.has_meta("door_z"):
			continue
		var xf := c.global_transform
		var dz := float(c.get_meta("door_z"))
		var soleira := xf * Vector3(0.0, 0.0, dz)
		var frente := xf * Vector3(-0.35, 0.0, dz)          # na calçada (70 cm), logo em frente da porta
		var s := Route.nearest_s(frente)
		# 1) degrau/buraco: chão na frente da porta x altura da soleira
		var q := PhysicsRayQueryParameters3D.create(frente + Vector3(0, 2.0, 0), frente - Vector3(0, 3.0, 0))
		var h := sp.intersect_ray(q)
		if h.is_empty():
			print("[rua] PORTA SEM CHÃO %s s=%.0f: nada na frente da porta" % [c.name, s])
			_conta("porta_sem_chao")
		else:
			var dy := soleira.y - (h.position as Vector3).y
			if absf(dy) > 0.12:
				print("[rua] PORTA DEGRAU %s s=%.0f: soleira %.2f m %s da calçada" % [c.name, s, absf(dy), "ACIMA" if dy > 0 else "ABAIXO"])
				_conta("porta_degrau")
		# 2) frente da porta livre (1,4 x 2 x 1,2 m)
		var bb := AABB(xf * Vector3(-1.5, 0.0, dz) - Vector3(0.6, 0.0, 0.6), Vector3(1.2, 2.0, 1.2))
		var bl := _cruza(bb, _rids(c))
		for b in bl:
			print("[rua] PORTA TAPADA %s s=%.0f por %s" % [c.name, s, b])
			_conta("porta_tapada")
		# 3) número
		var lab := c.get_node_or_null("Numero") as Label3D
		if lab != null:
			var lado := signf(Route.right(s).dot(frente - Route.pos(s)))
			nums[c.name] = [s, lado, lab.text]
	var por_lado := {-1.0: [], 1.0: []}
	for k in nums:
		por_lado[float(nums[k][1])].append([float(nums[k][0]), String(nums[k][2]), k])
	for ld in por_lado:
		var arr: Array = por_lado[ld]
		arr.sort_custom(func(a, b) -> bool: return a[0] < b[0])
		var txt := ""
		var fora := 0
		for i in arr.size():
			txt += "%s(s%.0f) " % [arr[i][1], arr[i][0]]
			if i > 0 and int(arr[i][1]) <= int(arr[i - 1][1]):
				fora += 1
		print("[rua] NUMEROS lado %d: %s -> %d fora de ordem" % [int(ld), txt, fora])
		if fora > 0:
			_conta("numeros_fora_de_ordem")


# ------------------------------------------------------------------ objetos
func _objetos() -> void:
	var itens: Array = []
	for gn in PROPS:
		var g := vila.get_node_or_null(gn)
		if g == null:
			continue
		for c in g.get_children():
			if not (c is Node3D):
				continue
			var nm := String(c.name)
			if nm.begins_with("@") or nm.begins_with("Mur") or nm.begins_with("Laje") or nm.begins_with("Riacho") or nm.begins_with("Igreja") or nm.begins_with("Fios") or nm.begins_with("Pedras") or nm.begins_with("AdroDetalhes") or nm.begins_with("Cachoeira") or nm.begins_with("Pecas") or nm.begins_with("Lampiao") or nm.begins_with("Col") or nm.begins_with("Ruela"):
				continue
			var bb := _aabb(c as Node3D)
			if bb.size == Vector3.ZERO or bb.size.x > 12.0 or bb.size.z > 12.0:
				continue
			itens.append({"n": c, "bb": bb, "g": gn})
			var planta := nm.contains("arvore") or nm.contains("Cipreste") or nm.contains("palmeira") or nm.contains("bananeira") or nm.contains("Arbusto") or nm.contains("mato") or nm.contains("weed") or nm.contains("periwinkle") or nm.contains("rooibos") or nm.contains("grass")
			var bbc := bb
			if planta:                      # copa de árvore pode passar por cima de muro: só o tronco/base conta
				bbc = AABB(Vector3(bb.get_center().x - 0.25, bb.position.y, bb.get_center().z - 0.25), Vector3(0.5, minf(bb.size.y, 1.2), 0.5))
			for b in _cruza(bbc, _rids(c)):
				print("[rua] ATRAVESSA %s/%s (s=%.0f) com %s" % [gn, nm, Route.nearest_s(bb.get_center()), b])
				_conta("atravessa_solido")
	# objeto x objeto (pelas caixas visuais)
	for i in itens.size():
		for j in range(i + 1, itens.size()):
			var a: AABB = itens[i]["bb"]
			var b: AABB = itens[j]["bb"]
			var ab := a.grow(-0.06)
			if ab.intersects(b.grow(-0.06)):
				var na := String((itens[i]["n"] as Node).name)
				var nb := String((itens[j]["n"] as Node).name)
				var inter := ab.intersection(b.grow(-0.06))
				if inter.size.x * inter.size.z < 0.01:
					continue
				print("[rua] OBJ x OBJ %s/%s com %s/%s (s=%.0f) %.0fx%.0f cm" % [itens[i]["g"], na, itens[j]["g"], nb, Route.nearest_s(a.get_center()), inter.size.x * 100.0, inter.size.z * 100.0])
				_conta("obj_x_obj")


# ------------------------------------------------------------------ pedras
func _pedras() -> void:
	var d := vila.get_node_or_null("Detalhes")
	if d == null:
		return
	for mmi in d.find_children("Rochas*", "MultiMeshInstance3D", true, false):
		var m := mmi as MultiMeshInstance3D
		var mm := m.multimesh
		var ab := mm.mesh.get_aabb() if mm.mesh else AABB()
		for i in mm.instance_count:
			var x := m.global_transform * mm.get_instance_transform(i)
			var bb := x * ab
			var c := bb.get_center()
			var s := Route.nearest_s(c)
			if Route.dist_to_center(c) < Route.width(s) * 0.5 - 0.2:
				print("[rua] PEDRA NA RUA %s (s=%.0f) em %s tamanho %.2f" % [m.name, s, str(c.snapped(Vector3.ONE * 0.1)), bb.size.x])
				_conta("pedra_na_rua")
				continue
			var cr := _cruza(bb, [])
			for b in cr:
				if b.begins_with("Terreno") or b.contains("ChaoTmp"):
					continue
				print("[rua] PEDRA ATRAVESSA %s (s=%.0f) em %s com %s" % [m.name, s, str(c.snapped(Vector3.ONE * 0.1)), b])
				_conta("pedra_atravessa")
				break
