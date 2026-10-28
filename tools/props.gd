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


## Instancia o modelo `key`, escalado por `scale`. Retorna um Node3D pronto para add_child.
static func make(key: String, scale := 1.0, align := "chao") -> Node3D:
	var inst := scene(key).instantiate() as Node3D
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
