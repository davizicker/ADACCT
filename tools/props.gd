class_name PropKit
extends RefCounted
## Carrega os modelos reais (.glb do Poly Haven, CC0) de res://assets/models/poly/ e os prepara para uso no mundo.
## Convenção: o modelo volta dentro de um nó "Modelo" com os pés em y = 0 e centrado em X/Z
## (exceto `align = "parede"`: a face de trás fica em z = 0, projetando-se para +Z, para lampiões de parede).
## Metadados do nó devolvido: "bb" (AABB já alinhada) e, para lâmpadas, "bulb_mi", "bulb_idx", "bulb_pos".

const DIR := "res://assets/models/poly/"
static var _cache := {}


static func scene(key: String) -> PackedScene:
	if not _cache.has(key):
		_cache[key] = load(DIR + key + ".glb")
	return _cache[key]


static func bounds(n: Node, xf := Transform3D.IDENTITY) -> AABB:
	var out := AABB()
	var first := true
	var local := xf
	if n is Node3D:
		local = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = local * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		var b := bounds(c, local)
		if b.size == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out


## O modelo do vaso de barro vem VAZIO: acrescenta a terra escura dentro (disco logo abaixo da borda). `bb` = caixa do modelo sem escala.
static func _terra_do_vaso(bb: AABB) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Terra"
	var cm := CylinderMesh.new()
	cm.top_radius = minf(bb.size.x, bb.size.z) * 0.5 * 0.88
	cm.bottom_radius = cm.top_radius
	cm.height = 0.012
	cm.radial_segments = 14
	cm.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.15, 0.09, 0.055)
	m.roughness = 1.0
	cm.material = m
	mi.mesh = cm
	var c := bb.get_center()
	mi.position = Vector3(c.x, bb.position.y + bb.size.y * 0.80, c.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Malha do vaso + terra numa só (para vasos em lote/MultiMesh).
static func malha_vaso_com_terra(vaso: Mesh, bb: AABB) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in vaso.get_surface_count():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, vaso.surface_get_arrays(si))
		out.surface_set_material(out.get_surface_count() - 1, vaso.surface_get_material(si))
	var t := _terra_do_vaso(bb)
	var tm := t.mesh as CylinderMesh
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tm.get_mesh_arrays())
	# desloca os vértices da terra para a posição dela (o disco foi criado na origem)
	var arrs := out.surface_get_arrays(out.get_surface_count() - 1)
	var vs: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
	for i in vs.size():
		vs[i] += t.position
	arrs[Mesh.ARRAY_VERTEX] = vs
	var out2 := ArrayMesh.new()
	for si in out.get_surface_count() - 1:
		out2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out.surface_get_arrays(si))
		out2.surface_set_material(si, out.surface_get_material(si))
	out2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	out2.surface_set_material(out2.get_surface_count() - 1, tm.material)
	return out2


## Malhas auxiliares do Blender (planos "wdg_*" de 0,00001 m de altura, invisíveis) esticavam a caixa do modelo (o relógio de lareira "media" 0,9 m).
static func _tira_auxiliares(inst: Node) -> void:
	for mi in inst.find_children("wdg_*", "MeshInstance3D", true, false):
		mi.get_parent().remove_child(mi)
		mi.free()


## Instancia o modelo `key`, escalado por `scale`. Retorna um Node3D pronto para add_child.
static func make(key: String, scale := 1.0, align := "chao") -> Node3D:
	var inst := scene(key).instantiate() as Node3D
	_tira_auxiliares(inst)
	var holder := Node3D.new()
	holder.name = key
	var wrap := Node3D.new()
	wrap.name = "Modelo"
	holder.add_child(wrap)
	wrap.add_child(inst)
	var bb := bounds(inst)
	if key == "planter_pot_clay":
		inst.add_child(_terra_do_vaso(bb))                    # terra dentro do vaso (escala junto com o modelo)
	inst.scale = Vector3.ONE * scale
	var sb := AABB(bb.position * scale, bb.size * scale)
	var c := sb.get_center()
	if align == "parede":
		inst.position = Vector3(-c.x, -sb.position.y, -sb.position.z)
	else:
		inst.position = Vector3(-c.x, -sb.position.y, -c.z)
	holder.set_meta("bb", AABB(sb.position + inst.position, sb.size))
	return holder


## Como `make`, mas guarda só as malhas cujo nome começa com algum dos prefixos de `manter`. Vários .glb do Poly Haven são "folhas de catálogo"
## (lápis empilhados, 4 latas lado a lado, 2 malas juntas...): aqui cada peça pode ser usada sozinha, no lugar certo.
static func make_filtrado(key: String, manter: Array, scale := 1.0, align := "chao") -> Node3D:
	var inst := scene(key).instantiate() as Node3D
	_tira_auxiliares(inst)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var ok := false
		for pre in manter:
			if String(mi.name).begins_with(String(pre)):
				ok = true
				break
		if not ok:
			mi.get_parent().remove_child(mi)
			mi.free()
	var holder := Node3D.new()
	holder.name = key
	var wrap := Node3D.new()
	wrap.name = "Modelo"
	holder.add_child(wrap)
	wrap.add_child(inst)
	var bb := bounds(inst)
	inst.scale = Vector3.ONE * scale
	var sb := AABB(bb.position * scale, bb.size * scale)
	var c := sb.get_center()
	if align == "parede":
		inst.position = Vector3(-c.x, -sb.position.y, -sb.position.z)
	else:
		inst.position = Vector3(-c.x, -sb.position.y, -c.z)
	holder.set_meta("bb", AABB(sb.position + inst.position, sb.size))
	return holder


## Kits: um .glb com várias malhas (um nó por variação) -> Mesh por nome. Usado por containers.glb e hera.glb.
static var _kits: Dictionary = {}


static func kit_mesh(arquivo: String, nome: String) -> Mesh:
	_kit_carrega(arquivo)
	return (_kits[arquivo] as Dictionary).get(nome, null)


static func kit_nomes(arquivo: String) -> PackedStringArray:
	_kit_carrega(arquivo)
	var out := PackedStringArray((_kits[arquivo] as Dictionary).keys())
	out.sort()
	return out


static func _kit_carrega(arquivo: String) -> void:
	if _kits.has(arquivo):
		return
	var d := {}
	var inst := (load(DIR + arquivo + ".glb") as PackedScene).instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		d[(mi as MeshInstance3D).name] = (mi as MeshInstance3D).mesh
	inst.free()
	_kits[arquivo] = d


## Medieval Containers (Daniel74, CC0): um .glb com 45 variações (Barrel1_1.., Basket1_1.., Crate1_1.., Jug1_1.., Sack1_1.. etc.).
static var _cont: Dictionary = {}


static func cont_nomes() -> PackedStringArray:
	_cont_carrega()
	var out := PackedStringArray(_cont.keys())
	out.sort()
	return out


static func _cont_carrega() -> void:
	if not _cont.is_empty():
		return
	var inst := (load(DIR + "containers.glb") as PackedScene).instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		_cont[(mi as MeshInstance3D).name] = (mi as MeshInstance3D).mesh
	inst.free()


## Como `make`, mas para uma variação do kit de recipientes (ex.: "Barrel1_3"). Pés em y = 0, centrado em X/Z.
static func make_cont(nome: String, scale := 1.0) -> Node3D:
	_cont_carrega()
	var holder := Node3D.new()
	holder.name = nome
	var wrap := Node3D.new()
	wrap.name = "Modelo"
	holder.add_child(wrap)
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = _cont[nome]
	wrap.add_child(mi)
	var bb := mi.mesh.get_aabb()
	mi.scale = Vector3.ONE * scale
	var sb := AABB(bb.position * scale, bb.size * scale)
	var c := sb.get_center()
	mi.position = Vector3(-c.x, -sb.position.y, -c.z)
	holder.set_meta("bb", AABB(sb.position + mi.position, sb.size))
	return holder


## Procura a superfície "…_bulb" (a lâmpada) e a torna emissiva. Guarda no `holder`: caminho do mesh, índice e posição.
static func setup_bulb(holder: Node3D, color := Color(1.0, 0.80, 0.50), energy := 3.2) -> bool:
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm != null and sm.resource_name.ends_with("_bulb"):
				var nm := sm.duplicate() as StandardMaterial3D
				nm.emission_enabled = true
				nm.emission = color
				nm.emission_energy_multiplier = energy
				nm.albedo_color = color
				m.set_surface_override_material(i, nm)
				var arr := m.mesh.surface_get_arrays(i)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var lo := Vector3(1e9, 1e9, 1e9)
				var hi := Vector3(-1e9, -1e9, -1e9)
				for v in verts:
					lo = lo.min(v)
					hi = hi.max(v)
				var center_local := (lo + hi) * 0.5
				holder.set_meta("bulb_mi", holder.get_path_to(m))
				holder.set_meta("bulb_idx", i)
				holder.set_meta("bulb_pos", _xf_to(m, holder) * center_local)
				return true
	return false


## Transformação de `node` até `ancestor` (sem precisar estar na árvore de cena).
static func _xf_to(node: Node3D, ancestor: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Tinge uma superfície do modelo por nome do material (ex.: deixar a lona do carro mais escura).
static func tint_material(holder: Node3D, mat_name_contains: String, color: Color) -> void:
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm != null and sm.resource_name.contains(mat_name_contains):
				var nm := sm.duplicate() as StandardMaterial3D
				nm.albedo_color = color
				m.set_surface_override_material(i, nm)
