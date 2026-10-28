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
				"folha_a": c = Color(0.10, 0.27, 0.07)
				"folha_b": c = Color(0.17, 0.34, 0.09)
				"folha_c": c = Color(0.25, 0.40, 0.11)
				"palma_folha": c = Color(0.16, 0.34, 0.10)
				"banana_tronco": c = Color(0.40, 0.50, 0.22)
				"banana_folha": c = Color(0.22, 0.45, 0.11)
			s.albedo_color = c
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
