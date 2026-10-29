class_name Arvores
extends RefCounted
## Árvores, palmeira e bananeira de GEOMETRIA real (assets/models/poly/arvores.glb, gerado por tools/blender/build_arvores.py).
## Cada espécie tem 2 níveis de detalhe: _L0 (perto) e _L1 (longe). Os materiais do .glb são trocados pelos do projeto:
## casca (Bark014, ambientCG, CC0), palma_tronco e folhas em verdes (cor sólida com translucência).

const KIT := "arvores"
const ESPECIES := ["arvore_a", "arvore_b", "arvore_c", "arvore_pequena", "palmeira", "bananeira"]
const DIST_L0 := 45.0          # além daqui entra o nível _L1
static var _cache := {}
static var _mats := {}


static func _material(nome: String) -> Material:
	if _mats.has(nome):
		return _mats[nome]
	var m: Material
	match nome:
		"casca", "palma_tronco":
			m = load("res://assets/materials/%s.tres" % nome)
		_:
			var s := StandardMaterial3D.new()
			s.resource_name = nome
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.roughness = 0.6
			s.backlight_enabled = true
			var c := Color(0.2, 0.4, 0.1)
			match nome:
				"folha_massa": c = Color(0.05, 0.14, 0.04)
				"folha_a": c = Color(0.35, 0.62, 0.28)
				"folha_b": c = Color(0.50, 0.78, 0.34)
				"folha_c": c = Color(0.70, 0.92, 0.42)
				"palma_folha": c = Color(0.16, 0.34, 0.10)
				"banana_tronco": c = Color(0.30, 0.40, 0.16)
				"banana_folha": c = Color(0.13, 0.32, 0.07)
				"banana_folha2": c = Color(0.09, 0.25, 0.05)
			s.albedo_color = c
			if nome in ["folha_a", "folha_b", "folha_c"]:      # folha real (Poly Haven, CC0) com recorte por alpha
				s.albedo_texture = load("res://assets/models/poly/mato_b_diffuse.png")
				s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				s.alpha_scissor_threshold = 0.5
				s.vertex_color_use_as_albedo = false
				s.backlight_enabled = false
			else:
				s.backlight = c * 0.55
			m = s
	_mats[nome] = m
	return m


## Malha `nome` ("arvore_a_L0") com os materiais do projeto.
static func malha(nome: String) -> Mesh:
	if _cache.has(nome):
		return _cache[nome]
	var base := PropKit.kit_mesh(KIT, nome)
	var m := base.duplicate() as Mesh
	for i in m.get_surface_count():
		var orig := base.surface_get_material(i)
		var nm := orig.resource_name if orig != null else ""
		if nm.begins_with("banana_") or nm.begins_with("folha") or nm.begins_with("palma") or nm == "casca":
			m.surface_set_material(i, _material(nm))
	_cache[nome] = m
	return m


## Nó com os dois níveis de detalhe (troca por distância). `colide`: cilindro fino no tronco.
static func no(especie: String, escala := 1.0, colide := false) -> Node3D:
	var n := Node3D.new()
	n.name = especie
	var l0 := MeshInstance3D.new()
	l0.name = "L0"
	l0.set_meta("lod", true)
	l0.mesh = malha(especie + "_L0")
	l0.visibility_range_end = DIST_L0
	l0.visibility_range_end_margin = 4.0
	l0.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	n.add_child(l0)
	var l1 := MeshInstance3D.new()
	l1.name = "L1"
	l1.set_meta("lod", true)
	l1.mesh = malha(especie + "_L1")
	l1.visibility_range_begin = DIST_L0
	l1.visibility_range_begin_margin = 4.0
	l1.visibility_range_end = 260.0
	l1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(l1)
	n.scale = Vector3.ONE * escala
	return n


## Como `no`, para os modelos reais do Poly Haven com LOD (kit "plantas_lod": rooibos_L0/L1, tronco_L0/L1): materiais próprios do .glb.
## `alvo_h` > 0 escala o modelo para essa altura (m). O pé do modelo fica em y = 0, centrado em X/Z.
static func no_kit(kit: String, base: String, escala := 1.0, alvo_h := 0.0, dist_l0 := 35.0) -> Node3D:
	var n := Node3D.new()
	n.name = base
	var m0 := PropKit.kit_mesh(kit, base + "_L0")
	var bb := m0.get_aabb()
	var k := escala
	if alvo_h > 0.0:
		k = escala * alvo_h / maxf(bb.size.y, 0.05)
	var c := bb.get_center()
	for lod in 2:
		var mi := MeshInstance3D.new()
		mi.name = "L%d" % lod
		mi.mesh = PropKit.kit_mesh(kit, "%s_L%d" % [base, lod])
		mi.set_meta("lod", true)
		mi.position = Vector3(-c.x, -bb.position.y, -c.z)
		if lod == 0:
			mi.visibility_range_end = dist_l0
			mi.visibility_range_end_margin = 3.0
		else:
			mi.visibility_range_begin = dist_l0
			mi.visibility_range_begin_margin = 3.0
			mi.visibility_range_end = 200.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	n.scale = Vector3.ONE * k
	return n
