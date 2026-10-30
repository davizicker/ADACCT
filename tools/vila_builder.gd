class_name VilaBuilder
extends RefCounted
## Gera a vila (inspirada em Ouro Preto) como árvore de nós. Usado só por tools/bake.gd
## para CRIAR scenes/vila.scn. Depois disso o mundo é editado no editor do Godot.
## A rua vem de scripts/route.gd; materiais de res://assets/materials/*.tres.
##
## Convenção do quadro local de uma casa/lote: origem no centro da fachada, ao nível da calçada;
##   +X = para dentro da casa (longe da rua), +Y = cima, Z = ao longo da rua.
##   A fachada está no plano x = 0 e "olha" para -X.

const SW := Route.SIDEWALK
const RIO_QUEDA_T := 30.0          # distância da ponte (ao longo do riacho, lado +) onde fica a cachoeira
const RIO_QUEDA_H := 3.2           # altura da queda
const RIO_DECLIVE := 0.12         # quanto o leito do riacho sobe por metro de distância da rua
const SW_H := 0.12
const MATS := "res://assets/materials/"
const S_END := Route.S_END     # a partir daqui começa o adro da igreja
const CHURCH_S := Route.CHURCH_S

const WALLS: Array[String] = ["reboco_branco", "reboco_ocre", "reboco_amarelo", "reboco_azul", "reboco_salmao", "reboco_verde", "reboco_branco_novo", "reboco_creme"]
const WALL_WEIGHT: Array[int] = [30, 14, 18, 8, 8, 4, 6, 12]
const WOODS: Array[String] = ["madeira_azul", "madeira_vermelha", "madeira_verde", "madeira_ocre", "madeira_natural", "madeira_branca"]
## becos em escada: [s, lado]
## Becos em escada: [s, lado, tipo]. tipo "cego" = beco SEM SAÍDA (pátio com portão de ferro, itens e uma casa com porta); sem tipo = escada que sobe até a porta do alto.
const ALLEYS: Array = [
	[18.0, -1.0], [28.0, 1.0, "cego"], [44.0, 1.0], [60.0, -1.0, "cego"], [74.0, 1.0], [88.0, -1.0], [104.0, 1.0],
	[134.0, -1.0], [172.0, -1.0], [196.0, 1.0], [214.0, -1.0, "cego"], [250.0, 1.0], [268.0, 1.0, "cego"],
	[348.0, -1.0, "cego"], [372.0, -1.0],
]
## PASSAGENS = becos de atalho: escadas/rampas que atravessam de uma perna do zigue-zague da ladeira da igreja à outra.
## "a" é a boca de baixo e "b" a de cima: [s da rua, lado]. Dá para subir 60-80 m de rua em ~20 m de escada.
const PASSAGENS: Array = [
	{"id": "AtalhoDoSino", "a": [240.0, -1.0], "b": [318.0, -1.0]},
	{"id": "AtalhoDaFonte", "a": [310.0, 1.0], "b": [376.0, 1.0]},
]
const PASS_W := 3.2          # largura útil do corredor
const PASS_BOCA := 4.6       # largura da boca na fachada
const FOUNTAIN := [Route.FOUNTAIN_S, Route.FOUNTAIN_SIDE]
## Interiores atrás de cada beco sem saída, na ordem em que aparecem subindo a rua.
const CEGO_IDS: Array[String] = ["ferraria", "casa_vazia", "pensao", "costureira", "deposito"]
## Casas que o jogador pode ENTRAR (porta com luz). O lote real é o primeiro "casa" a partir de `s` no lado `sigma`.
## `requer`/`trancada`: item do inventário que destranca a porta e o aviso enquanto trancada.
const ENTRADAS: Array = [
	{"s": 28.0, "sigma": -1.0, "id": "benedita", "texto": "Entrar na casa de Dona Benedita"},
	{"s": 54.0, "sigma": -1.0, "id": "padaria", "texto": "Entrar na padaria"},
	{"s": 80.0, "sigma": 1.0, "id": "carpintaria", "texto": "Entrar na carpintaria do Seu Mateus"},
	{"s": 94.0, "sigma": 1.0, "id": "venda", "texto": "Entrar na Venda do Seu Zé"},
	{"s": 140.0, "sigma": 1.0, "id": "escola", "texto": "Entrar na escola"},
	{"s": 202.0, "sigma": -1.0, "id": "barbearia", "texto": "Entrar na barbearia"},
	{"s": 224.0, "sigma": 1.0, "id": "casarao", "texto": "Entrar no Casarão dos Vaz", "requer": "chave_casarao", "trancada": "Trancada com chave de ferro. Dizem que o Seu Zé guarda a chave."},
	{"s": 272.0, "sigma": 1.0, "id": "sineiro", "texto": "Entrar na casa do sineiro"},
]

var _rng := RandomNumberGenerator.new()
var _cache := {}
var _veg := {}
var _rs := PackedVector2Array()
var _noise_lo: FastNoiseLite
var _noise_hi: FastNoiseLite
var _n := 0
var _cego_n := 0
var _cego_atual := ""
var _entrada_atual: Dictionary = {}
var _entradas_feitas: Dictionary = {}
var _ocupados: Array = []     # [Vector3, raio]: lugares já usados por portas/barris/bancos (nada se sobrepõe)
var _casas_postas: Array[Dictionary] = []   # {xf, depth, w} das casas já colocadas (para não se atravessarem nas curvas)
var _flutuando: Array[String] = []   # peças que não encostam em nada (auditoria feita no bake)
var _spots: Array[Vector2] = []
var _pass_geo: Array[Dictionary] = []     # geometria dos becos de atalho (calculada uma vez, só com a rota)
var _lamp_n := 0
var _haunted := 0
var _joints: Array[Dictionary] = []   # junções entre lotes (onde ficam nichos)
var _wear: FastNoiseLite
var _wet: FastNoiseLite
var _carros_s := {}
var _bar_spot := {}
var _rio_ok := false
var _rio_c := Vector3.ZERO
var _rio_r := Vector3.RIGHT
var _rio_t := Vector3.FORWARD
var _portas: Array[Vector3] = []             # chão em frente a cada porta de casa: nada de prop de rua aí
var _hill_lights: Array[Transform3D] = []   # janelas acesas das casas distantes (viram pontos de luz)


func mat(n: String) -> Material:
	if not _cache.has(n):
		_cache[n] = load(MATS + n + ".tres")
	return _cache[n]


func _batch() -> MeshBatch:
	return MeshBatch.new(mat)


# ------------------------------------------------------------------ utilidades de nós

func _group(parent: Node, node_name: String, xf := Transform3D.IDENTITY) -> Node3D:
	var g := Node3D.new()
	g.name = node_name
	g.transform = xf
	parent.add_child(g)
	return g


func _mesh_node(parent: Node, node_name: String, mesh: Mesh, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


## Caixa com material único; opcionalmente com colisão.
func _box(parent: Node, node_name: String, size: Vector3, pos: Vector3, material: String, collide := false) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh_node(parent, node_name, bm, pos)
	mi.material_override = mat(material)
	if collide:
		_add_box_collision(mi, size)
	return mi


func _add_box_collision(parent: Node, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Colisao"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)


## Só colisão (sem malha), em posição local.
func _blocker(parent: Node, node_name: String, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)


## Plantas de cartão (texturas geradas) que foram trocadas por modelos reais: chave antiga -> [modelos, altura-alvo em m].
## Cartões continuam só nas árvores, palmeiras e bananeiras (não há modelo real delas).
const PLANTAS_REAIS := {
	"arbusto": [["rooibos", "rooibos", "rooibos", "mato_a", "weed_a"], 1.1],
	"capim": [["mato_b", "grass_tuft_a", "grass_tuft_b", "mato_c"], 0.45],
	"samambaia": [["periwinkle_a", "periwinkle_b", "periwinkle_c", "mato_b"], 0.5],
}
var _alt_real := {}
var _jan_atual: Array = []      # painéis de vidro da casa em construção: {pos, size, lit} (locais da casa)
var _pl_atual: Array = []       # plantas de janela da casa em construção: {pos, tipo, esc}
const ESPECIE_REAL := {"arvore_0": "arvore_a", "arvore_1": "arvore_b", "arvore_2": "arvore_c"}


func _plant(parent: Node, key: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	if PLANTAS_REAIS.has(key):
		var opcoes: Array = PLANTAS_REAIS[key][0]
		var real: String = opcoes[_rng.randi() % opcoes.size()]
		if real == "rooibos":        # moita de verdade (wild_rooibos_bush, Poly Haven) com 2 níveis de detalhe
			var rn := Arvores.no_kit("plantas_lod", "rooibos", scale * _rng.randf_range(0.9, 1.3), float(PLANTAS_REAIS[key][1]))
			rn.name = "rooibos_%03d" % _n
			_n += 1
			rn.position = pos
			rn.rotation.y = yaw
			parent.add_child(rn)
			return rn
		if not _alt_real.has(real):
			var amostra := PropKit.make(real)
			var bbm := (amostra.get_meta("bb") as AABB).size
			_alt_real[real] = maxf(maxf(bbm.x, bbm.z), maxf(bbm.y, 0.05))      # maior dimensão: plantas rasteiras são largas e baixas
			amostra.free()
		return _prop(parent, real, pos, yaw, float(PLANTAS_REAIS[key][1]) * scale / float(_alt_real[real]))
	# árvores, palmeiras e bananeiras: geometria real (tools/arvores.gd), com troca de detalhe por distância
	var esp: String = ESPECIE_REAL.get(key, key)
	var n := Arvores.no(esp, scale)
	n.name = "%s_%03d" % [key, _n]
	_n += 1
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	return n


func _pick_wall() -> String:
	var total := 0
	for w in WALL_WEIGHT:
		total += w
	var r := _rng.randi_range(0, total - 1)
	for i in WALLS.size():
		r -= WALL_WEIGHT[i]
		if r < 0:
			return WALLS[i]
	return WALLS[0]


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# ------------------------------------------------------------------ geometria da rota

## Ponto da linha de fachada (lado sigma = -1 esquerda, +1 direita) na posição s.
func facade(sigma: float, s: float) -> Vector3:
	return Route.pos(s) + Route.right(s) * sigma * (Route.width(s) * 0.5 + SW)


func _advance(sigma: float, s: float, w: float) -> float:
	var a := facade(sigma, s)
	var s2 := s
	while s2 < Route.length():
		s2 += 0.2
		if _flat(facade(sigma, s2) - a).length() >= w:
			break
	return s2


## Quadro local do lote entre s e s2 (corda da fachada).
func lot_frame(sigma: float, s: float, s2: float) -> Dictionary:
	var a := facade(sigma, s)
	var b := facade(sigma, s2)
	var sm := (s + s2) * 0.5
	var m := (a + b) * 0.5
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var dist := d.length()
	d = d.normalized()
	var x_axis := d.cross(Vector3.UP) * sigma      # para dentro do lote
	var p := facade(sigma, sm)
	var enc := Vector3(m.x - p.x, 0, m.z - p.z).dot(-x_axis)
	var origin := Vector3(m.x, Route.height(sm) + SW_H, m.z)
	if enc > 0.0:
		origin += x_axis * enc    # a corda invadiria a calçada: empurra para dentro
	var basis := Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP))
	return {"xf": Transform3D(basis, origin), "w": dist, "sm": sm}


## Boca de um beco de atalho: lote estreito que começa em s_t - PASS_BOCA/2 (calculável só com a rota, sem sorteio).
func _boca_frame(sigma: float, s_t: float) -> Dictionary:
	var s_m := s_t - PASS_BOCA * 0.5
	var s2 := _advance(sigma, s_m, PASS_BOCA)
	var f := lot_frame(sigma, s_m, s2)
	f["s_m"] = s_m
	f["s2"] = s2
	return f


func _passagens_calc() -> void:
	_pass_geo.clear()
	for i in PASSAGENS.size():
		var P: Dictionary = PASSAGENS[i]
		var fa := _boca_frame(float(P["a"][1]), float(P["a"][0]))
		var fb := _boca_frame(float(P["b"][1]), float(P["b"][0]))
		var A: Vector3 = (fa["xf"] as Transform3D).origin
		var B: Vector3 = (fb["xf"] as Transform3D).origin
		var dv := Vector3(B.x - A.x, 0.0, B.z - A.z)
		var D := dv.length()
		_pass_geo.append({"id": P["id"], "A": A, "B": B, "dir": dv / D, "D": D, "rise": B.y - A.y, "fa": fa, "fb": fb})


## true se o ponto (x, z) está sobre o corredor de algum beco de atalho (com folga m).
func _na_passagem(x: float, z: float, m: float) -> bool:
	for G in _pass_geo:
		var A: Vector3 = G["A"]
		var dv: Vector3 = G["dir"]
		var rx := x - A.x
		var rz := z - A.z
		var along := rx * dv.x + rz * dv.z
		var lat := absf(rx * dv.z - rz * dv.x)
		if along > -m and along < float(G["D"]) + m and lat < PASS_W * 0.5 + m:
			return true
	return false


# ------------------------------------------------------------------ terreno

func _setup(veg_scenes: Dictionary) -> void:
	_veg = veg_scenes
	_rng.seed = 1789
	_noise_lo = FastNoiseLite.new()
	_noise_lo.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_lo.frequency = 0.0055
	_noise_lo.fractal_octaves = 4
	_noise_lo.seed = 5
	_noise_hi = FastNoiseLite.new()
	_noise_hi.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_hi.frequency = 0.03
	_noise_hi.seed = 6
	_rs = PackedVector2Array()
	var s := 0.0
	while s <= Route.length():
		var p := Route.pos(s)
		_rs.append(Vector2(p.x, p.z))
		s += 2.0
	_passagens_calc()


## (s, distância) do ponto mais próximo da linha central.
func _nearest(x: float, z: float) -> Vector2:
	var q := Vector2(x, z)
	var bi := 0
	var bd := INF
	for i in _rs.size():
		var d := q.distance_squared_to(_rs[i])
		if d < bd:
			bd = d
			bi = i
	var s0 := bi * 2.0
	var best_s := s0
	var best_d := INF
	var s := maxf(s0 - 2.0, 0.0)
	var s_max := minf(s0 + 2.0, Route.length())
	while s <= s_max:
		var p := Route.pos(s)
		var d := q.distance_squared_to(Vector2(p.x, p.z))
		if d < best_d:
			best_d = d
			best_s = s
		s += 0.25
	return Vector2(best_s, sqrt(best_d))


func terrain_h(x: float, z: float) -> float:
	var q := _nearest(x, z)
	var base := Route.height(q.x) - 0.4      # abaixo da calçada: não cobre a rua
	var dc := Route.width(q.x) * 0.5 + SW + 12.0       # corredor plano onde ficam as casas
	var t := maxf(0.0, q.y - dc)
	var rise := 0.30 * t + 0.0030 * t * t
	rise = 130.0 * tanh(rise / 130.0)        # morros altos, mas sem paredões de 400 m nas bordas do terreno
	var n := _noise_lo.get_noise_2d(x, z) * 16.0 + _noise_hi.get_noise_2d(x, z) * 3.0
	# leito do riacho que passa sob a ponte (cruza a rua; some longe, nas encostas)
	var h := base + rise + n * smoothstep(0.0, 25.0, t)
	# o riacho: vale em V que corta a encosta dos dois lados da ponte; o leito sobe aos poucos (a água desce das serras) e as margens
	# alargam com a distância, então ele continua um riacho de verdade até longe, em vez de um tanque quadrado
	if not _rio_ok:
		_rio_c = Route.pos(Route.BRIDGE_S)
		_rio_r = Route.right(Route.BRIDGE_S)
		_rio_t = Route.tangent(Route.BRIDGE_S)
		_rio_ok = true
	var drv := Vector2(x - _rio_c.x, z - _rio_c.z)
	var dw := absf(drv.x * _rio_t.x + drv.y * _rio_t.z)          # distância ao eixo do riacho (reta no mundo)
	var tl := absf(drv.x * _rio_r.x + drv.y * _rio_r.z)          # distância ao longo dele a partir da ponte
	# só escava perto da ponte ou longe de qualquer trecho da rua (a rua faz zigue-zague: não pode ser comida pelo vale)
	var protege := maxf(1.0 - smoothstep(8.0, 14.0, absf(q.x - Route.BRIDGE_S)), smoothstep(10.0, 16.0, q.y - Route.width(q.x) * 0.5))
	var kk := (1.0 - smoothstep(3.0, 6.8 + 0.22 * maxf(tl - 10.0, 0.0), dw)) * (1.0 - smoothstep(70.0, 100.0, tl)) * protege
	var tsg := drv.x * _rio_r.x + drv.y * _rio_r.z
	var leito := _rio_c.y - 4.0 + RIO_DECLIVE * maxf(tl - 8.0, 0.0) + RIO_QUEDA_H * smoothstep(RIO_QUEDA_T - 2.5, RIO_QUEDA_T + 0.5, tsg)
	h = lerpf(h, minf(h, leito), kk)
	# leito dos becos de atalho: o terreno desce/sobe até o piso da escada (senão cobriria os degraus)
	for G in _pass_geo:
		var A: Vector3 = G["A"]
		var dv: Vector3 = G["dir"]
		var rx := x - A.x
		var rz := z - A.z
		var along := rx * dv.x + rz * dv.z
		var lat := absf(rx * dv.z - rz * dv.x)
		var Dd: float = G["D"]
		if along > -3.0 and along < Dd + 3.0 and lat < 8.0:
			var w := (1.0 - smoothstep(PASS_W * 0.5 + 1.5, PASS_W * 0.5 + 7.0, lat)) * smoothstep(-3.0, 0.5, along) * (1.0 - smoothstep(Dd - 0.5, Dd + 3.0, along))
			var floor_y := A.y + clampf(along / Dd, 0.0, 1.0) * float(G["rise"]) - 0.45
			h = lerpf(h, floor_y, w)
	return h
func _terrain() -> Node3D:
	var root := Node3D.new()
	root.name = "Terreno"
	var x0 := -300.0
	var z0 := -560.0
	var step := 4.0
	var nx := int(570.0 / step) + 1
	var nz := int(700.0 / step) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			heights[iz * nx + ix] = terrain_h(x0 + ix * step, z0 + iz * step)
	# Ladrilhos de 20x20 células: cada trecho tem poucas luzes sobre ele (limite do renderizador).
	var tile := 20
	var tid := 0
	for tz in range(0, nz - 1, tile):
		for tx in range(0, nx - 1, tile):
			var ex := mini(tx + tile, nx - 1)
			var ez := mini(tz + tile, nz - 1)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for iz in range(tz, ez + 1):
				for ix in range(tx, ex + 1):
					var h := heights[iz * nx + ix]
					var hl := heights[iz * nx + maxi(ix - 1, 0)]
					var hr := heights[iz * nx + mini(ix + 1, nx - 1)]
					var hd := heights[maxi(iz - 1, 0) * nx + ix]
					var hu := heights[mini(iz + 1, nz - 1) * nx + ix]
					var nrm := Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
					var slope := clampf(Vector2(hr - hl, hu - hd).length() / (2.0 * step), 0.0, 1.5)
					var g := _noise_hi.get_noise_2d(ix * 7.0, iz * 7.0) * 0.5 + 0.5
					# plano = mato verde; íngreme = terra e pedra mais clara
					var col := Color(1.0, 1.0, 1.0)
					col *= 0.72 + 0.4 * g
					st.set_normal(nrm)
					st.set_color(col)
					st.set_uv(Vector2(x0 + ix * step, z0 + iz * step) * 0.05)
					st.add_vertex(Vector3(x0 + ix * step, h, z0 + iz * step))
			var w := ex - tx + 1
			for iz in range(ez - tz):
				for ix in range(ex - tx):
					var a := iz * w + ix
					st.add_index(a)
					st.add_index(a + 1)
					st.add_index(a + w)
					st.add_index(a + 1)
					st.add_index(a + w + 1)
					st.add_index(a + w)
			st.generate_tangents()
			var mesh := st.commit()
			mesh.surface_set_material(0, mat("terreno"))
			var mi := MeshInstance3D.new()
			mi.name = "Trecho_%03d" % tid
			mi.mesh = _save_mesh(mesh, "terreno_%03d" % tid)
			mi.visibility_range_end = 900.0
			root.add_child(mi)
			tid += 1
	return root


func _save_mesh(mesh: Mesh, mesh_name: String) -> Mesh:
	var path := "res://assets/meshes/%s.res" % mesh_name
	ResourceSaver.save(mesh, path)
	return load(path) as Mesh


# ------------------------------------------------------------------ rua
## Triângulo com cor por vértice (orientado para `expect`).
func _tri_c(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, expect: Vector3) -> void:
	var n := -(b - a).cross(c - a)
	if n.length() < 0.000001:
		return
	n = n.normalized()
	if n.dot(expect) < 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
		n = -n
	for pair in [[a, ca], [b, cb], [c, cc]]:
		st.set_normal(n)
		st.set_color(pair[1])
		st.add_vertex(pair[0])


## Cor do calçamento por vértice: variação de tom, sujeira e musgo junto ao meio-fio, manchas de umidade.
func _road_color(p: Vector3, lat: float, half: float) -> Color:
	var n := _wear.get_noise_2d(p.x, p.z) * 0.5 + 0.5
	var w := _wet.get_noise_2d(p.x, p.z) * 0.5 + 0.5
	var k := 0.84 + 0.32 * n
	var edge := smoothstep(half * 0.62, half, absf(lat))
	var col := Color(k, k, k)
	col *= 1.0 - 0.26 * edge
	col = col.lerp(Color(0.62, 0.74, 0.5) * k, edge * 0.40 * w)
	if w > 0.62:
		col *= 0.8
	return Color(col.r, col.g, col.b, 1.0)


func _road() -> Node3D:
	var root := Node3D.new()
	root.name = "Rua"
	_wear = FastNoiseLite.new()
	_wear.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_wear.frequency = 0.05
	_wear.fractal_octaves = 3
	_wear.seed = 17
	_wet = FastNoiseLite.new()
	_wet.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_wet.frequency = 0.02
	_wet.seed = 23
	var chunk := 30.0
	var count := int(ceil(Route.length() / chunk))
	var bevel := SW_H                    # chanfro de 45° entre calçada e sarjeta (o jogador sobe sem travar)
	var gutter := 0.14
	for ci in count:
		var s0 := ci * chunk
		var s1 := minf(Route.length(), s0 + chunk)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prev: Array[Vector3] = []
		var prev_c: Array[Color] = []
		var s_cur := s0
		while true:
			var c := Route.pos(s_cur)
			var r := Route.right(s_cur)
			var a := Route.width(s_cur) * 0.5
			# perfil transversal: calçada, chanfro, sarjeta, coroa (com pontos intermediários), sarjeta, chanfro, calçada
			var prof: Array[Vector2] = []
			prof.append(Vector2(-a - SW, SW_H))
			prof.append(Vector2(-a, SW_H))
			prof.append(Vector2(-a + bevel, 0.0))
			prof.append(Vector2(-a + bevel + gutter, -0.035))
			var inner := 2.0 * (a - bevel - gutter)
			var n := 14          # SEMPRE o mesmo número de pontos: se mudasse, a faixa entre dois quadros ficaria sem chão (buraco)
			for k in range(1, n):
				var u := -a + bevel + gutter + inner * float(k) / n
				var f := u / a
				prof.append(Vector2(u, -0.035 + 0.065 * (1.0 - f * f)))
			prof.append(Vector2(a - bevel - gutter, -0.035))
			prof.append(Vector2(a - bevel, 0.0))
			prof.append(Vector2(a, SW_H))
			prof.append(Vector2(a + SW, SW_H))
			var cur: Array[Vector3] = []
			var cur_c: Array[Color] = []
			for pf in prof:
				var wp := c + r * pf.x + Vector3(0, pf.y, 0)
				cur.append(wp)
				cur_c.append(_road_color(wp, pf.x, a))
			if not prev.is_empty():
				assert(prev.size() == cur.size(), "perfil da rua com tamanho variável")
				for j in prof.size() - 1:
					_tri_c(st, prev[j], prev[j + 1], cur[j + 1], prev_c[j], prev_c[j + 1], cur_c[j + 1], Vector3.UP)
					_tri_c(st, prev[j], cur[j + 1], cur[j], prev_c[j], cur_c[j + 1], cur_c[j], Vector3.UP)
			prev = cur
			prev_c = cur_c
			if s_cur >= s1:
				break
			s_cur = minf(s_cur + 1.0, s1)
		var mesh := st.commit()
		mesh.surface_set_material(0, mat("pedra_chao"))
		var mi := _mesh_node(root, "Trecho_%02d" % ci, _save_mesh(mesh, "rua_%02d" % ci))
		var body := StaticBody3D.new()
		body.name = "Colisao"
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		mi.add_child(body)
	return root


# ------------------------------------------------------------------ ambiente
func _environment() -> WorldEnvironment:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = load("res://assets/materials/ceu.tres")
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.11, 0.14, 0.22)
	env.ambient_light_energy = 0.38
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.12, 0.19)
	env.fog_density = 0.030
	env.fog_sky_affect = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.95
	# Só valem no renderizador Forward+ (Projeto > Configurações > Renderização).
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	var we := WorldEnvironment.new()
	we.name = "Ambiente"
	we.environment = env
	return we


func _moon() -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = "Lua"
	l.light_color = Color(0.55, 0.65, 0.95)
	l.light_energy = 0.30
	l.light_cull_mask = 1             # os interiores (camada 2) não recebem luar
	# a lua fica no céu à frente e à direita de quem começa a subir a rua; a luz viaja no sentido oposto
	var moon_dir := Vector3(0.50, 0.46, -0.74).normalized()
	l.transform = Transform3D(Basis.looking_at(-moon_dir, Vector3.UP), Vector3.ZERO)
	l.shadow_enabled = true
	l.shadow_opacity = 0.78           # a sombra da lua deixa um pouco de luz (menos "preto chapado")
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL    # 1 passada de sombra (em vez de 4)
	l.directional_shadow_max_distance = 60.0
	return l


# ------------------------------------------------------------------ construir tudo

func build_vila(veg_scenes: Dictionary) -> Node3D:
	_setup(veg_scenes)
	var root := Node3D.new()
	root.name = "Vila"
	root.add_child(_environment())
	root.add_child(_moon())
	root.add_child(_terrain())
	root.add_child(_road())
	_frontage(root)
	root.add_child(Realismo.new().vidros_e_plantas(self, root))
	root.add_child(_lamps())
	root.add_child(_adornos())
	root.add_child(_nichos())
	root.add_child(_props_rua())
	_tira_props_dentro_das_casas(root)
	root.add_child(_coletaveis())
	_bridge(root)
	root.add_child(_church_plaza())
	root.add_child(_hillside())
	root.add_child(_props_encosta())
	root.add_child(Realismo.new().construir(self))
	root.add_child(_serra())
	root.add_child(_route_path())
	root.add_child(Interiores.new().construir(self))
	var det := Detalhes.new()
	root.add_child(det.construir(self))
	print("[vila] detalhes: ", det.contagem)
	print("[vila] entradas: ", _entradas_feitas)
	# Desempenho: a neblina esconde o que está longe, então nem desenhamos.
	# a neblina (densidade 0,03) já apaga tudo a ~100 m: não desenhar além disso economiza centenas de chamadas
	for name in ["Casas", "MurosEQuintais", "FundoDaRua", "Ponte"]:
		var n := root.get_node_or_null(name)
		if n:
			_set_range(n, 125.0)
	var nb := root.get_node_or_null("Becos")
	if nb:
		_set_range(nb, 100.0)
	# detalhes pequenos somem mais cedo: a neblina já os esconde e eles são muitos objetos
	for name in ["Iluminacao", "Nichos", "Adornos", "Coletaveis", "Props"]:
		var n := root.get_node_or_null(name)
		if n:
			_set_range(n, 85.0)
	var npe := root.get_node_or_null("PropsEncosta")
	if npe:
		_set_range(npe, 130.0)
	_set_label_range(root, 55.0)
	for halo in root.find_children("Halo", "MeshInstance3D", true, false):
		(halo as GeometryInstance3D).visibility_range_end = 75.0
	_set_range(root.get_node("Morros/CasasDoMorro"), 280.0)
	_set_range(root.get_node("Morros/Arvores"), 220.0)
	print("[vila] pecas soltas (flutuando): %d" % _flutuando.size())
	for f in _flutuando.slice(0, 40):
		print("[vila]   ", f)
	return root


func _route_path() -> Path3D:
	var p := Path3D.new()
	p.name = "RotaReferencia"
	var curve := Curve3D.new()
	var s := 0.0
	while s <= Route.length():
		curve.add_point(Route.pos(s))
		s += 12.0
	p.curve = curve
	return p


# ------------------------------------------------------------------ fachadas

func _frontage(root: Node3D) -> void:
	var casas := _group(root, "Casas")
	var muros := _group(root, "MurosEQuintais")
	var becos := _group(root, "Becos")
	_start_wall(root)
	# os corredores dos becos de atalho entram como "casas já postas": nenhuma casa nem quintal invade o vão
	for G in _pass_geo:
		var dv: Vector3 = G["dir"]
		_casas_postas.append({"xf": Transform3D(Basis(dv, Vector3.UP, dv.cross(Vector3.UP)), G["A"]), "depth": float(G["D"]) + 0.4, "w": PASS_W + 2.4})
		var k := 0.0
		while k <= float(G["D"]):
			var q: Vector3 = (G["A"] as Vector3) + dv * k
			_spots.append(Vector2(q.x, q.z))
			k += 3.0
	for sigma: float in [-1.0, 1.0]:
		var s := 0.0
		var prev_special := true
		var done_alley := {}
		var bocas: Array[Dictionary] = []
		for gi in PASSAGENS.size():
			for fim: String in ["a", "b"]:
				if float(PASSAGENS[gi][fim][1]) == sigma:
					var bf: Dictionary = _pass_geo[gi]["fa" if fim == "a" else "fb"]
					bocas.append({"s_m": float(bf["s_m"]), "s2": float(bf["s2"]), "idx": gi, "ini": fim == "a"})
		bocas.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["s_m"]) < float(y["s_m"]))
		var bi := 0
		while s < S_END - 6.0:
			var w_street := Route.width(s)
			var w := _rng.randf_range(6.5, 11.5) if w_street >= 5.0 else _rng.randf_range(5.5, 9.0)
			var kind := "casa"
			# eventos programados
			for ai in ALLEYS.size():
				var a: Array = ALLEYS[ai]
				if a[1] == sigma and not done_alley.has(ai) and s >= a[0] - 4.0:
					kind = "beco"
					done_alley[ai] = true
					w = 3.6
					_cego_atual = ""
					if a.size() > 2:
						_cego_atual = CEGO_IDS[_cego_n % CEGO_IDS.size()]
						_cego_n += 1
			var boca: Dictionary = bocas[bi] if bi < bocas.size() else {}
			if not boca.is_empty() and s >= float(boca["s_m"]) - 0.01:
				kind = "passagem"
				w = PASS_BOCA
			if kind == "casa" and not done_alley.has("b") and s >= Route.BRIDGE_S - Route.BRIDGE_HALF:
				kind = "ponte"
				done_alley["b"] = true
				w = Route.BRIDGE_HALF * 2.0
			if kind == "casa" and FOUNTAIN[1] == sigma and s >= FOUNTAIN[0] and not done_alley.has("f"):
				kind = "chafariz"
				done_alley["f"] = true
				w = 7.0
			if kind == "casa" and not prev_special:
				var r := _rng.randf()
				var narrow := w_street < 4.4
				if r < (0.07 if narrow else 0.15):
					kind = "quintal"
				elif r < (0.12 if narrow else 0.25):
					kind = "talude"
			_entrada_atual = {}
			if kind == "casa" or kind == "quintal" or kind == "talude":
				for e in ENTRADAS:
					if float(e["sigma"]) == sigma and not _entradas_feitas.has(e["id"]) and s >= float(e["s"]) - 3.0 and w_street >= 3.6:
						kind = "casa"
						w = maxf(w, 7.2)
						_entrada_atual = e
						_entradas_feitas[e["id"]] = s
						break
			var s2 := _advance(sigma, s, w)
			if kind == "passagem":
				s2 = float(boca["s2"])
				bi += 1
			elif not boca.is_empty():
				# o lote termina exatamente onde começa a boca do atalho (a boca tem posição fixa)
				var sm_t := float(boca["s_m"])
				if s2 > sm_t - 0.01 or sm_t - s2 < 5.0:
					s2 = sm_t
					if s2 - s < 4.5 and (kind == "casa" or kind == "quintal" or kind == "talude"):
						kind = "quintal"
			var f := lot_frame(sigma, s, s2)
			if kind == "casa" and _entrada_atual.is_empty():
				# nas curvas fechadas a casa não cabe nem raspando (caixas giram uma contra a outra): vira quintal murado
				var xt: Transform3D = f["xf"]
				xt.origin += xt.basis.x * 0.05
				if _casa_penetra(xt, 2.6, float(f["w"]) + 0.24):
					kind = "quintal"
			match kind:
				"casa":
					_lot_casa(casas, f, sigma, w_street)
				"quintal":
					_lot_quintal(muros, f)
				"talude":
					_lot_talude(muros, f)
				"beco":
					_lot_beco(becos, f, _cego_atual)
				"chafariz":
					_lot_chafariz(muros, f)
				"ponte":
					_lot_ponte(muros, f, sigma)
				"passagem":
					_lot_passagem(becos, f, int(boca["idx"]), bool(boca["ini"]))
			if kind == "casa" or kind == "quintal" or kind == "talude":
				_joints.append({"sigma": sigma, "s": s})
			prev_special = kind != "casa"
			s = s2


## Prédio que fecha o começo da rua (atrás do jogador).
func _start_wall(root: Node3D) -> void:
	var t := Route.tangent(0.0)
	var x_axis := -t
	var basis := Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP))
	var origin := Route.pos(0.0) + Vector3(0, SW_H, 0) + t * 0.0
	var g := _group(root, "FundoDaRua", Transform3D(basis, origin))
	var casa := make_casa(26.0, 2, "reboco_creme", "madeira_verde", 12.0, true, 0.35, false)
	casa.name = "Casarao"
	g.add_child(casa)


func _lot_casa(parent: Node3D, f: Dictionary, sigma: float, w_street: float) -> void:
	var narrow := w_street < 4.4
	var floors := 2 if _rng.randf() < (0.8 if narrow else 0.6) else 1
	if _rng.randf() < 0.07 and not narrow:
		floors = 3
	var haunted: bool = floors >= 2 and not narrow and _haunted < 6 and f["sm"] > 30.0 and _rng.randf() < 0.14
	if haunted:
		_haunted += 1
	# +0,24 m de largura: as casas se encostam por dentro e não abrem frestas na parte de fora das curvas
	# casas vizinhas a um beco ficam rasas: a curva gira a caixa da casa e ela invadiria o vão da escada
	# só a casa logo ANTES de um beco (ainda não sabe onde ele está) fica mais rasa; as seguintes encurtam sozinhas contra o beco já posto
	var near_alley := false
	for al in ALLEYS:
		var ahead := float(al[0]) - float(f["sm"])
		if ahead > -3.0 and ahead < 9.0:
			near_alley = true
	var depth := _rng.randf_range(5.6, 6.8) if near_alley else _rng.randf_range(10.0, 13.0)
	# nas curvas, casas vizinhas giram uma em relação à outra e as caixas se atravessam por trás: encurta a profundidade até não haver choque
	var xf0: Transform3D = f["xf"]
	xf0.origin += xf0.basis.x * 0.05
	while depth > 2.6 and _casa_atravessa(xf0, depth, float(f["w"]) + 0.24):
		depth -= 0.3
	_casas_postas.append({"xf": xf0, "depth": depth, "w": float(f["w"]) + 0.24})
	var casa := make_casa(f["w"] + 0.24, floors, _pick_wall(), WOODS[_rng.randi() % WOODS.size()], depth,
		floors >= 2 and _rng.randf() < 0.55, 0.28, false, haunted, _entrada_atual)
	casa.name = "Casa_%02d" % _n
	# cada casa recua um pouco diferente da vizinha (como no real) e dispensa o z-fighting entre fachadas
	var jit := (0.01 + _rng.randf() * 0.03) if _n % 2 == 0 else (0.08 + _rng.randf() * 0.03)
	_n += 1
	var xf: Transform3D = f["xf"]
	xf.origin += xf.basis.x * jit
	# em ladeira o chão na porta fica acima/abaixo do chão no centro do lote: sobe/desce a casa para a soleira ficar rente à calçada
	# (antes a calçada cobria a parte de baixo da porta ou deixava a porta no ar)
	var pd: Vector3 = xf * Vector3(-0.4, 0.0, float(casa.get_meta("door_z")))
	xf.origin.y += clampf(Route.height(Route.nearest_s(pd)) + SW_H - pd.y, -2.2, 2.2)
	casa.transform = xf
	parent.add_child(casa)
	_reservar(xf * Vector3(-1.0, 0.0, float(casa.get_meta("door_z"))), 1.7)
	_portas.append(xf * Vector3(-0.9, 0.0, float(casa.get_meta("door_z"))))
	_decalques_fachada(casa, float(f["w"]) + 0.24, float(casa.get_meta("altura")))
	var porta_a := casa.get_node_or_null("Entrada_%s" % _entrada_atual.get("id", "")) as Node3D
	if porta_a != null:
		# em ladeira o chão na porta fica acima/abaixo da origem do lote: o gatilho acompanha o chão real
		porta_a.position.y = 1.3


## true se a pegada (planta) da casa em `xf` com `depth` x `w` invade a de alguma casa já colocada.
func _livre(p: Vector3, r: float, corredor := false) -> bool:
	# `corredor`: também recusa o que invade a faixa central de passagem do jogador (1,3 m de cada lado do eixo da rua)
	if corredor and Route.dist_to_center(p) < 1.45 + r:
		return false
	for o in _ocupados:
		if Vector2(p.x - (o[0] as Vector3).x, p.z - (o[0] as Vector3).z).length() < r + float(o[1]):
			return false
	return true


func _reservar(p: Vector3, r: float) -> void:
	_ocupados.append([p, r])


## Interpenetração REAL (pontos internos de uma caixa dentro da outra), mais folgada que _casa_atravessa (que também recusa encostos de 0,2 m).
func _casa_penetra(xf: Transform3D, depth: float, w: float) -> bool:
	for o in _casas_postas:
		var oxf: Transform3D = o["xf"]
		if oxf.origin.distance_to(xf.origin) > depth + float(o["depth"]) + w + float(o["w"]):
			continue
		for fx in [0.15, 0.85]:
			for fz in [0.15, 0.85]:
				var q: Vector3 = oxf.affine_inverse() * (xf * Vector3(depth * fx, 0.0, -w / 2.0 + w * fz))
				if q.x > 0.2 and q.x < float(o["depth"]) - 0.2 and absf(q.z) < float(o["w"]) / 2.0 - 0.2:
					return true
				var q2: Vector3 = xf.affine_inverse() * (oxf * Vector3(float(o["depth"]) * fx, 0.0, -float(o["w"]) / 2.0 + float(o["w"]) * fz))
				if q2.x > 0.2 and q2.x < depth - 0.2 and absf(q2.z) < w / 2.0 - 0.2:
					return true
	return false


func _casa_atravessa(xf: Transform3D, depth: float, w: float) -> bool:
	# só conta SOBREPOSIÇÃO de verdade (pontos bem dentro da outra caixa): as casas vizinhas se encostam de lado de propósito
	# (+0,24 m de largura) e antes isso encurtava quase todas as casas para 2,4 m de fundo (finas como papelão vistas dos becos)
	for o in _casas_postas:
		var oxf: Transform3D = o["xf"]
		if oxf.origin.distance_to(xf.origin) > depth + float(o["depth"]) + w + float(o["w"]):
			continue
		for ix in 6:
			for iz in 5:
				var p: Vector3 = xf * Vector3(0.5 + (depth - 1.0) * ix / 5.0, 0.0, -w / 2.0 + 0.7 + (w - 1.4) * iz / 4.0)
				var q: Vector3 = oxf.affine_inverse() * p
				if q.x > 0.15 and q.x < float(o["depth"]) - 0.15 and absf(q.z) < float(o["w"]) / 2.0 - 0.3:
					return true
		for ix in 6:
			for iz in 5:
				var p2: Vector3 = oxf * Vector3(0.5 + (float(o["depth"]) - 1.0) * ix / 5.0, 0.0, -float(o["w"]) / 2.0 + 0.7 + (float(o["w"]) - 1.4) * iz / 4.0)
				var q2: Vector3 = xf.affine_inverse() * p2
				if q2.x > 0.15 and q2.x < depth - 0.15 and absf(q2.z) < w / 2.0 - 0.3:
					return true
	return false


# ------------------------------------------------------------------ casa colonial

## `w` largura da fachada; `floors` 1–3; `depth` profundidade; `lit_p` chance de janela acesa.
func make_casa(w: float, floors: int, wall: String, wood: String, depth: float, balcony: bool, lit_p: float, simple: bool, haunted := false, entrada := {}) -> Node3D:
	var c := Node3D.new()
	c.name = "Casa"
	_jan_atual = []
	_pl_atual = []
	var fh := 4.0
	var up := 3.4
	var height := fh + (floors - 1) * up
	_box(c, "Corpo", Vector3(depth, height + 4.0, w), Vector3(depth / 2.0, height / 2.0 - 2.0, 0), wall, true)
	# oclusão: o corpo da casa esconde o que está atrás (só Forward+/Mobile; ligado em project.godot)
	var occ := OccluderInstance3D.new()
	occ.name = "Oclusor"
	var bo := BoxOccluder3D.new()
	bo.size = Vector3(maxf(depth - 0.6, 0.5), height + 2.0, maxf(w - 0.6, 0.5))
	occ.occluder = bo
	occ.position = Vector3(depth / 2.0, height / 2.0 - 1.0, 0)
	c.add_child(occ)
	# telhado com UV (telhas no sentido do caimento), cumeeira de capa e tábuas de beiral; inclinação varia por casa
	var rise := (depth + 1.4) * _rng.randf_range(0.24, 0.33)
	var rcx := depth / 2.0 - 0.2
	var ry := height + 0.15
	var rb := _batch()
	rb.roof("telha_uv", wall, Vector3(depth + 1.4, rise, w + 0.5), Vector3(rcx, ry + rise / 2.0, 0), 0.0, 3.6, "madeira_escura")
	rb.box("telha_cumeeira", Vector3(0.36, 0.22, w + 0.56), Vector3(rcx, ry + rise + 0.03, 0))
	rb.box("madeira_escura", Vector3(0.10, 0.16, w + 0.50), Vector3(rcx - (depth + 1.4) / 2.0 + 0.04, ry - 0.05, 0))
	rb.box("madeira_escura", Vector3(0.10, 0.16, w + 0.50), Vector3(rcx + (depth + 1.4) / 2.0 - 0.04, ry - 0.05, 0))
	_mesh_node(c, "Telhado", rb.commit())

	var b := _batch()
	var ncor := maxi(1, int(ceil(w)))
	for k in ncor:
		var zc := -w / 2.0 + (k + 0.5) * w / ncor
		b.malha(Kit.mesh("cornija_1m"), Kit.fachada(Vector3(0.0, height - 0.2, zc), Vector3(w / ncor, 1.0, 1.0)))      # cornija com dentículos
	for k in int(w / 0.9):
		var z := -w / 2.0 + 0.5 + k * 0.9
		b.malha(Kit.mesh("cachorro_beiral"), Kit.fachada(Vector3(0.0, height - 0.04, z)), {"madeira": "madeira_natural"})   # cachorros do beiral
	if floors >= 2 and _rng.randf() < 0.5:
		b.box("cantaria", Vector3(0.18, 0.16, w + 0.1), Vector3(-0.07, fh - 0.2, 0))           # cordão
	if _rng.randf() < 0.55:
		for end: float in [-1.0, 1.0]:                                                                     # cunhais de pedra
			for k in int(height / 0.7):
				b.box("cantaria", Vector3(0.08, 0.34, 0.5 if k % 2 == 0 else 0.36), Vector3(-0.05, k * 0.7 + 0.4, end * (w / 2.0 - 0.22)))

	var cols := maxi(2, int(round(w / 2.7)))
	var col_z: Array[float] = []
	for i in cols:
		col_z.append(-w / 2.0 + (i + 0.5) * w / cols)
	var door_i := _rng.randi_range(0, cols - 1)
	var dz := col_z[door_i]
	c.set_meta("door_z", dz)
	c.set_meta("altura", height)
	# embasamento de pedra em dois trechos: o vão da porta fica livre (antes o muro de 1,1 m tapava a parte de baixo da porta)
	var vao := 1.15
	var z_ini := -w / 2.0 - 0.05
	var z_fim := w / 2.0 + 0.05
	var trechos: Array = [[z_ini, dz - vao], [dz + vao, z_fim]]
	for tr in trechos:
		var comp: float = float(tr[1]) - float(tr[0])
		if comp > 0.05:
			b.box("muro", Vector3(0.3, 5.1, comp), Vector3(-0.1, -1.45, (float(tr[0]) + float(tr[1])) * 0.5))
	b.box("muro", Vector3(0.3, 4.0, vao * 2.0), Vector3(-0.1, -2.0, dz))      # sob a soleira: só abaixo do piso da porta
	# porta com moldura de cantaria; em arco nos sobrados "arqueados"
	var arched := (not simple) and _rng.randf() < 0.5
	# a porta nunca tem a cor da parede: tons claros/ocre viram madeira escura, para ela se destacar da fachada
	var wood_porta := wood
	if wood == "madeira_ocre" or wood == "madeira_branca" or wood == "madeira_natural":
		wood_porta = "madeira_escura"
	if arched:
		var dr := 0.72
		var dh := 3.0
		for sz: float in [-1.0, 1.0]:
			b.box("cantaria", Vector3(0.2, dh - dr + 0.1, 0.22), Vector3(-0.08, (dh - dr) / 2.0, dz + sz * (dr + 0.11)))
		b.arch("cantaria", Vector3(-0.08, dh - dr, dz), dr + 0.11, 0.22, 0.2, 9)
		b.box(wood_porta, Vector3(0.08, dh - dr, dr * 2.0), Vector3(-0.18, (dh - dr) / 2.0, dz))
		b.half_disc(wood_porta, Vector3(-0.225, dh - dr, dz), dr)
		b.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 0.7, dz - 0.34))
		b.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 0.7, dz + 0.34))
		b.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 1.9, dz - 0.34))
		b.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 1.9, dz + 0.34))
	else:
		b.malha(Kit.mesh("porta_dupla"), Kit.fachada(Vector3(0.0, 0.0, dz), Vector3(1.0, 1.06, 1.0)), {"madeira": wood_porta})
	if arched:
		b.box("cantaria", Vector3(0.5, 0.15, 2.0), Vector3(-0.25, -0.03, dz))                     # soleira da porta em arco
	var dn := 1.25 if not arched else 1.15
	if dz + dn > w / 2.0 - 0.2:
		dn = -dn
	b.box("ouro_velho", Vector3(0.02, 0.10, 0.18), Vector3(-0.03, 2.2, dz + dn))   # número da casa na parede (do lado em que há parede)
	if not entrada.is_empty():
		_porta_entrada(c, entrada, dz, w)

	var bal_cols: Array[int] = []
	if balcony and floors >= 2:
		for i in cols:
			if cols < 3 or (i != 0 and i != cols - 1) or _rng.randf() < 0.3:
				bal_cols.append(i)
		if bal_cols.is_empty():
			bal_cols.append(door_i)
	for i in cols:
		if i != door_i:
			_window(b, Vector3(0, 2.0, col_z[i]), 1.0, 1.5, wood, _rng.randf() < lit_p * 0.6, not simple and _rng.randf() < 0.4)
		for k in range(1, floors):
			var y0 := fh + (k - 1) * up
			if k == 1 and bal_cols.has(i):
				_window(b, Vector3(0, y0 + 1.25, col_z[i]), 1.1, 2.2, wood, _rng.randf() < lit_p, false, true, arched)
			else:
				_window(b, Vector3(0, y0 + 1.65, col_z[i]), 1.0, 1.7, wood, _rng.randf() < lit_p, false, false, arched)
	if not bal_cols.is_empty() and not simple:
		_balcony(b, col_z[bal_cols[0]] - 0.95, col_z[bal_cols[bal_cols.size() - 1]] + 0.95, fh, wood)
	if not simple and _rng.randf() < 0.4:
		var chz := _rng.randf_range(-w * 0.3, w * 0.3)
		b.malha(Kit.mesh("chamine"), Transform3D(Basis.IDENTITY, Vector3(depth / 2.0 - 0.2, height + rise - 0.55, chz)))      # chaminé de pedra do kit (embute no telhado)
		if _rng.randf() < 0.4:
			c.add_child(Realismo.fumaca(Vector3(depth / 2.0 - 0.2, height + rise + 1.15, chz)))
	if haunted and floors >= 2:
		var hi := (door_i + 1) % cols
		_haunted_window(c, Vector3(-0.18, fh + 1.65, col_z[hi]))
	if not simple:
		b.box("ferro", Vector3(0.12, 0.09, w + 0.4), Vector3(-0.92, height + 0.09, 0))               # calha do beiral
		if _rng.randf() < 0.55:
			var dz2 := (w / 2.0 - 0.05) * (1.0 if _rng.randf() < 0.5 else -1.0)
			b.box("ferro", Vector3(0.8, 0.09, 0.09), Vector3(-0.52, height + 0.05, dz2))
			b.box("ferro", Vector3(0.09, height + 0.3, 0.09), Vector3(-0.12, height / 2.0 - 0.1, dz2))   # tubo de queda
		if _rng.randf() < 0.22:
			_sign(c, b, col_z[(door_i + 1) % cols])
	var solidos := [AABB(Vector3(0.0, -2.0, -w / 2.0), Vector3(depth, height + 4.0, w)),
		AABB(Vector3(rcx - (depth + 1.4) / 2.0, ry - 0.05, -(w + 0.5) / 2.0), Vector3(depth + 1.4, rise + 0.1, w + 0.5))]
	for fl in b.floating(solidos):
		_flutuando.append("casa w=%.1f: %s" % [w, fl])
	var det := _mesh_node(c, "Detalhes", b.commit())
	det.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # molduras e grades não precisam de sombra (menos uma passada por casa)
	c.set_meta("janelas", _jan_atual)
	c.set_meta("plantas_janela", _pl_atual)
	return c


## Sujeira e umidade projetadas na fachada (Decal: só Forward+; em Compatibilidade são ignorados).
func _decalques_fachada(casa: Node3D, w: float, altura: float) -> void:
	# a projeção do Decal desce pelo -Y local; giramos para ela entrar na parede (+X local da casa).
	var basis := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
	for caido in _rng.randi_range(0, 2) if _rng.randf() < 0.5 else 0:
		var dc := Decal.new()
		dc.name = "RebocoCaido_%d" % caido
		dc.texture_albedo = load("res://assets/textures/reboco_caido.png")
		var cw := _rng.randf_range(1.0, 2.4)
		var ch := _rng.randf_range(0.9, 1.8)
		dc.size = Vector3(cw, 0.8, ch)
		dc.transform = Transform3D(basis, Vector3(0.1, _rng.randf_range(0.6, maxf(0.7, altura - 1.6)), _rng.randf_range(-w * 0.4, w * 0.4)))
		dc.distance_fade_enabled = true
		dc.distance_fade_begin = 40.0
		dc.distance_fade_length = 12.0
		dc.cull_mask = 1
		casa.add_child(dc)
	for k in 2:
		if k == 1 and _rng.randf() > 0.6:
			continue
		var d := Decal.new()
		d.name = "Sujeira" if k == 0 else "Umidade"
		d.texture_albedo = load("res://assets/textures/%s.png" % ("sujeira_base" if k == 0 else "mancha"))
		var h := minf(altura + 0.5, 4.0 if k == 0 else 3.4)
		d.size = Vector3(w, 0.9, h)
		d.transform = Transform3D(basis, Vector3(0.1, h * 0.5 - 0.25, 0.0))
		d.distance_fade_enabled = true
		d.distance_fade_begin = 45.0
		d.distance_fade_length = 15.0
		d.upper_fade = 0.05
		d.lower_fade = 0.05
		d.cull_mask = 1
		casa.add_child(d)


## Porta que o jogador pode abrir (E): gatilho + lampião de parede aceso ao lado (marca as casas visitáveis).
func _porta_entrada(c: Node3D, entrada: Dictionary, dz: float, w_casa: float) -> void:
	var a := Area3D.new()
	a.name = "Entrada_%s" % entrada["id"]
	a.position = Vector3(-0.85, 1.3, dz)
	a.set_script(load("res://scripts/porta.gd"))
	a.set("destino", entrada["id"])
	a.set("texto_interacao", entrada["texto"])
	a.set("requer", entrada.get("requer", ""))
	a.set("texto_trancada", entrada.get("trancada", "Está trancada."))
	a.set_meta("fora_local", Vector3(-1, 0, 0))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 2.6, 1.8)
	cs.shape = bs
	a.add_child(cs)
	c.add_child(a)
	var lado := 1.0 if dz + 1.35 < w_casa * 0.5 - 0.35 else -1.0
	var lw := _lantern_wall(Vector3(0.0, 3.0, dz + lado * 1.35), -PI / 2.0)
	lw.name = "LampiaoDaPorta"
	c.add_child(lw)


func _sign(c: Node3D, b: MeshBatch, z: float) -> void:
	# [texto, cor da placa, emblema]
	var defs := [
		["ARMAZÉM", "placa_verde", ""], ["BOTICA", "placa_vermelha", "pilao"], ["BARBEARIA", "placa_azul", "barbeiro"],
		["PADARIA", "placa_marrom", "pao"], ["SAPATARIA", "placa_preta", "bota"], ["TECIDOS", "placa_azul", "tesoura"],
		["FERRARIA", "placa_preta", "ferradura"], ["PENSÃO", "placa_verde", ""], ["OURIVES", "placa_vermelha", "anel"],
		["ALFAIATE", "placa_marrom", "tesoura"],
	]
	var d: Array = defs[_rng.randi() % defs.size()]
	var text: String = d[0]
	var board: String = d[1]
	var bx := -0.82          # centro da placa (para fora da fachada)
	var by := 3.22
	# braço de ferro com escora e voluta, saindo da parede
	b.box("ferro", Vector3(0.06, 0.40, 0.06), Vector3(-0.03, 3.45, z))                                    # haste na parede
	b.box("ferro", Vector3(1.40, 0.05, 0.05), Vector3(-0.70, 3.66, z))                                    # braço
	b.box("ferro", Vector3(0.80, 0.035, 0.035), Vector3(-0.38, 3.40, z), Vector3(0, 0, 0.60))             # escora
	b.sphere("ferro", 0.045, Vector3(-1.40, 3.66, z), 6, 4)
	for dx: float in [-0.30, 0.30]:
		b.box("ferro", Vector3(0.015, 0.26, 0.015), Vector3(bx + dx, 3.52, z))                             # correntes
	# placa com moldura dourada em relevo
	b.box(board, Vector3(0.90, 0.46, 0.05), Vector3(bx, by, z))
	b.box("ouro_velho", Vector3(0.94, 0.035, 0.08), Vector3(bx, by + 0.245, z))
	b.box("ouro_velho", Vector3(0.94, 0.035, 0.08), Vector3(bx, by - 0.245, z))
	for dx: float in [-0.455, 0.455]:
		b.box("ouro_velho", Vector3(0.035, 0.52, 0.08), Vector3(bx + dx, by, z))
	b.sphere("ouro_velho", 0.04, Vector3(bx - 0.455, by + 0.25, z), 5, 3)
	b.sphere("ouro_velho", 0.04, Vector3(bx + 0.455, by + 0.25, z), 5, 3)
	# letras em relevo, dos dois lados (Label3D: texto 3D editável no Inspetor)
	for side: float in [1.0, -1.0]:
		var l := Label3D.new()
		l.name = "Texto"
		l.text = text
		l.font = _sign_font()
		l.font_size = 96
		l.pixel_size = clampf(0.72 / (text.length() * 0.62 * 96.0), 0.0011, 0.0026)
		l.modulate = Color(0.97, 0.84, 0.50)
		l.outline_modulate = Color(0.06, 0.03, 0.0)
		l.outline_size = 14
		l.shaded = true
		l.double_sided = false
		l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		l.position = Vector3(bx, by, z + side * 0.032)
		l.rotation.y = 0.0 if side > 0.0 else PI
		c.add_child(l)
	_emblem(b, String(d[2]), bx, z)


var _font_cache: SystemFont = null

func _sign_font() -> SystemFont:
	if _font_cache == null:
		_font_cache = SystemFont.new()
		# fonte com serifa, se o computador tiver; senão a engine usa a fonte padrão
		_font_cache.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"])
		_font_cache.font_weight = 700
	return _font_cache


## Emblema pendurado sob a placa (pão, pilão, poste de barbeiro, bota, ferradura, anel, tesoura).
func _emblem(b: MeshBatch, kind: String, bx: float, z: float) -> void:
	var y := 2.70
	match kind:
		"pao":
			b.cylinder("pao", 0.11, 0.11, 0.34, Vector3(bx, y, z), Vector3(0, 0, PI / 2.0), 8)
			b.sphere("pao", 0.11, Vector3(bx - 0.17, y, z), 7, 4)
			b.sphere("pao", 0.11, Vector3(bx + 0.17, y, z), 7, 4)
			b.box("ferro", Vector3(0.015, 0.14, 0.015), Vector3(bx, y + 0.17, z))
		"pilao":
			b.cylinder("ferro", 0.10, 0.15, 0.17, Vector3(bx, y - 0.02, z), Vector3.ZERO, 10)
			b.box("ferro", Vector3(0.04, 0.34, 0.04), Vector3(bx + 0.05, y + 0.12, z), Vector3(0, 0, -0.5))
			b.box("ferro", Vector3(0.015, 0.14, 0.015), Vector3(bx, y + 0.17, z))
		"barbeiro":
			for k in 6:
				var m: String = ["listra_branca", "listra_vermelha", "listra_azul"][k % 3]
				b.cylinder(m, 0.055, 0.055, 0.12, Vector3(bx, y + 0.18 - k * 0.12, z), Vector3.ZERO, 8)
			b.sphere("ouro_velho", 0.065, Vector3(bx, y + 0.28, z), 6, 4)
		"bota":
			b.box("couro", Vector3(0.10, 0.26, 0.11), Vector3(bx - 0.04, y + 0.04, z))
			b.box("couro", Vector3(0.24, 0.09, 0.11), Vector3(bx + 0.03, y - 0.14, z))
			b.box("ferro", Vector3(0.015, 0.14, 0.015), Vector3(bx, y + 0.26, z))
		"ferradura":
			for k in 9:
				var a := deg_to_rad(-50.0 + k * 37.5)
				b.box("ferro", Vector3(0.05, 0.035, 0.05), Vector3(bx + cos(a) * 0.14, y + 0.05 + sin(a) * 0.14 * -1.0 + 0.1, z), Vector3(0, 0, a + PI / 2.0))
			b.box("ferro", Vector3(0.015, 0.14, 0.015), Vector3(bx, y + 0.28, z))
		"anel":
			for k in 10:
				var a := TAU * k / 10.0
				b.box("ouro_velho", Vector3(0.045, 0.045, 0.045), Vector3(bx + cos(a) * 0.12, y + sin(a) * 0.12, z), Vector3(0, 0, a))
			b.sphere("gema", 0.05, Vector3(bx, y + 0.14, z), 6, 4)
			b.box("ferro", Vector3(0.015, 0.14, 0.015), Vector3(bx, y + 0.22, z))
		"tesoura":
			b.box("ferro", Vector3(0.05, 0.40, 0.03), Vector3(bx, y, z), Vector3(0, 0, 0.35))
			b.box("ferro", Vector3(0.05, 0.40, 0.03), Vector3(bx, y, z), Vector3(0, 0, -0.35))
			b.box("ferro", Vector3(0.015, 0.14, 0.015), Vector3(bx, y + 0.28, z))


func _pot(b: MeshBatch, p: Vector3) -> void:
	b.cylinder("vaso", 0.11, 0.08, 0.16, p + Vector3(0, 0.08, 0), Vector3.ZERO, 8)
	_pl_atual.append({"pos": p + Vector3(0, 0.15, 0), "tipo": _rng.randi() % 5, "esc": _rng.randf_range(0.8, 1.2)})


func _window(b: MeshBatch, p: Vector3, wid: float, hgt: float, wood: String, lit: bool, grate: bool, door := false, arch := false) -> void:
	var glass := "vidro_luz" if lit else "vidro_noite"
	if arch:
		# vão com verga em arco (como nos sobrados de Ouro Preto): parte reta + meio disco
		var r := wid * 0.5
		var hr := hgt - r
		var base_y := p.y - hgt / 2.0
		var spring := base_y + hr
		for sz: float in [-1.0, 1.0]:
			b.box("cantaria", Vector3(0.18, hr + 0.15, 0.2), Vector3(-0.07, base_y + hr / 2.0 - 0.02, p.z + sz * (r + 0.1)))
		b.arch("cantaria", Vector3(-0.07, spring, p.z), r + 0.1, 0.2, 0.18, 9)
		_jan_atual.append({"pos": Vector3(-0.17, base_y + hr / 2.0, p.z), "size": Vector2(wid, hr), "lit": lit})
		b.half_disc(glass, Vector3(-0.17, spring, p.z), r, 10, Vector2(r / hgt, hgt))
		b.box(wood, Vector3(0.05, hgt, 0.05), Vector3(-0.19, p.y, p.z))
		b.box(wood, Vector3(0.05, 0.05, wid), Vector3(-0.19, base_y + hr * 0.55, p.z))
		if not door:
			b.box("cantaria", Vector3(0.34, 0.1, wid + 0.5), Vector3(-0.17, base_y - 0.1, p.z))
		return
	var base_y := p.y - hgt / 2.0
	if door:
		# porta-balcão: porta de duas folhas do kit, menos funda
		b.malha(Kit.mesh("porta_dupla"), Kit.fachada(Vector3(0.0, base_y, p.z), Vector3(wid / 1.4, hgt / 2.5, 0.6)), {"madeira": wood, "vidro": glass})
	else:
		b.malha(Kit.mesh("janela_colonial"), Kit.fachada(Vector3(0.0, base_y, p.z), Vector3(wid, hgt / 1.5, 1.0)), {"madeira": wood, "vidro": glass})
		_jan_atual.append({"pos": Vector3(-0.012, p.y, p.z), "size": Vector2(wid * 0.9, hgt * 0.933), "lit": lit})
		var sorteio := _rng.randf()
		if sorteio < 0.16:
			_pot(b, Vector3(-0.2, base_y + 0.03, p.z))
		elif sorteio < 0.30:
			_jardineira(b, Vector3(-0.26, base_y + 0.03, p.z), wid)
		if _rng.randf() < 0.55:
			_venezianas(b, p, wid, hgt, wood)
	if grate:
		for k in 5:
			b.box("ferro", Vector3(0.03, hgt, 0.03), Vector3(-0.26, p.y, p.z - wid / 2.0 + wid * k / 4.0))


## Venezianas de madeira abertas em ângulo (cada folha gira na dobradiça, na lateral do vão).
func _venezianas(b: MeshBatch, p: Vector3, wid: float, hgt: float, wood: String) -> void:
	var theta := _rng.randf_range(0.8, 1.35)
	for side: float in [-1.0, 1.0]:
		var th := theta * _rng.randf_range(0.85, 1.1)
		var hinge := Vector3(-0.12, p.y - hgt / 2.0 - 0.03, p.z + side * (wid * 0.5 + 0.2))
		# folha do kit (a da direita é espelhada); gira na dobradiça: a esquerda abre para -theta, a direita para +theta
		var mesh := Kit.mesh("veneziana" if side < 0.0 else "veneziana_e")
		var bas := Basis(Vector3.UP, -side * th) * Basis(Vector3.UP, -PI / 2.0)
		b.malha(mesh, Transform3D(bas.scaled_local(Vector3((wid * 0.5 + 0.02) / 0.52, (hgt + 0.1) / 1.56, 1.0)), hinge), {"madeira": wood})


## Jardineira de madeira sob a janela, com folhagem e flores.
func _jardineira(b: MeshBatch, p: Vector3, wid: float) -> void:
	b.box("madeira_escura", Vector3(0.26, 0.16, wid * 0.9), p + Vector3(0, 0.08, 0))
	for k in maxi(2, int(wid * 2.2)):
		var z := p.z - wid * 0.38 + k * (wid * 0.76) / maxf(1.0, int(wid * 2.2) - 1)
		_pl_atual.append({"pos": Vector3(p.x, p.y + 0.15, z), "tipo": _rng.randi() % 5, "esc": _rng.randf_range(0.8, 1.3)})


func _balcony(b: MeshBatch, z0: float, z1: float, floor_y: float, wood: String) -> void:
	var bw := z1 - z0
	var bz := (z0 + z1) * 0.5
	var iron := _rng.randf() < 0.7
	var rail := "ferro" if iron else "madeira_natural"
	if iron:
		var nm := maxi(1, int(ceil(bw)))
		for k in nm:
			b.malha(Kit.mesh("sacada_1m"), Kit.fachada(Vector3(0.0, floor_y, z0 + (k + 0.5) * bw / nm), Vector3(bw / nm, 1.0, 1.0)))     # laje, mísulas, balaústres torneados
	else:
		b.box("cantaria", Vector3(1.25, 0.18, bw), Vector3(-0.62, floor_y - 0.09, bz))
		for z in [z0 + 0.3, z1 - 0.3, bz]:
			b.box("cantaria", Vector3(0.9, 0.32, 0.3), Vector3(-0.45, floor_y - 0.34, z))      # mísulas
		b.box(rail, Vector3(0.06, 0.06, bw), Vector3(-1.2, floor_y + 1.0, bz))
		b.box(rail, Vector3(0.05, 0.05, bw), Vector3(-1.2, floor_y + 0.12, bz))
	for z in [z0, z1]:
		b.box(rail, Vector3(1.2, 0.05, 0.05), Vector3(-0.6, floor_y + 1.0, z))
	if _rng.randf() < 0.6:
		for k in maxi(1, int(bw / 1.5)):
			_pot(b, Vector3(-0.95, floor_y, z0 + bw * (k + 0.5) / maxi(1, int(bw / 1.5))))
	if not iron:
		var posts := int(bw / 0.22)
		for k in posts + 1:
			b.box(rail, Vector3(0.045, 0.88, 0.045), Vector3(-1.2, floor_y + 0.56, z0 + bw * k / posts))


# ------------------------------------------------------------------ lotes especiais

## Hera de verdade (peças do "Tiny Weeds 3", Nobiax, CC0): pendem do alto do muro, viradas para a rua (-x local).
func _wall_ivy(parent: Node3D, w: float, height: float, x := -0.03) -> void:
	var nomes := PropKit.kit_nomes("hera")
	var cols := maxi(1, int(w / 0.85))
	for i in cols:
		var nome: String = nomes[_rng.randi() % nomes.size()]
		var mesh := PropKit.kit_mesh("hera", nome)
		var bb := mesh.get_aabb()
		var sc := minf(_rng.randf_range(1.3, 2.1), height * 0.95 / maxf(bb.size.y, 0.1))
		var mi := MeshInstance3D.new()
		mi.name = "Hera_%d" % i
		mi.mesh = mesh
		mi.scale = Vector3.ONE * sc
		mi.rotation.y = -PI / 2.0 + _rng.randf_range(-0.12, 0.12)
		var topo := height - _rng.randf_range(0.0, 0.25)
		mi.position = Vector3(x + bb.position.z * sc, topo - (bb.position.y + bb.size.y) * sc, -w / 2.0 + (i + 0.5) * w / cols + _rng.randf_range(-0.15, 0.15))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 45.0
		parent.add_child(mi)


func _lot_quintal(parent: Node3D, f: Dictionary) -> void:
	var w: float = f["w"]
	# o muro ocupa a calçada de cara: nada de caixote/balde/cesto encostado (atravessava o muro)
	var zz := -w / 2.0 + 0.6
	while zz <= w / 2.0 - 0.5:
		_reservar((f["xf"] as Transform3D) * Vector3(-0.4, 0.0, zz), 0.8)
		zz += 1.1
	var g := _group(parent, "Quintal_%02d" % _n, f["xf"])
	_n += 1
	var wall_h := _rng.randf_range(2.1, 2.6)
	_box(g, "Muro", Vector3(0.5, wall_h + 1.5, w + 0.1), Vector3(0.25, (wall_h - 1.5) / 2.0, 0), "muro", true)
	var b := _batch()
	b.box("cantaria", Vector3(0.8, 0.14, w + 0.25), Vector3(0.25, wall_h + 0.07, 0))   # capa do muro
	var gz := _rng.randf_range(-w * 0.2, w * 0.2)
	for sz: float in [-1.0, 1.0]:
		b.box("cantaria", Vector3(0.7, wall_h + 0.6, 0.45), Vector3(0.0, (wall_h + 0.6) / 2.0 - 0.3, gz + sz * 0.95))   # pilares do portão
		b.box("cantaria", Vector3(0.8, 0.2, 0.6), Vector3(0.0, wall_h + 0.36, gz + sz * 0.95))
	if _rng.randf() < 0.5:
		var pg := _prop(g, "large_iron_gate", Vector3(-0.12, 0, gz), -PI / 2.0, 1.55 / 2.95)      # portão de ferro (Poly Haven) entre os pilares
		pg.name = "PortaoDeFerro"
	else:
		b.box("madeira_natural", Vector3(0.1, wall_h - 0.2, 1.5), Vector3(-0.1, (wall_h - 0.2) / 2.0, gz))
		b.box("ferro", Vector3(0.12, 0.05, 1.5), Vector3(-0.17, wall_h * 0.55, gz))
	for fl in b.floating([AABB(Vector3(0.0, -1.5, -w / 2.0), Vector3(0.5, wall_h + 1.5, w))]):
		_flutuando.append("quintal w=%.1f: %s" % [w, fl])
	_mesh_node(g, "Detalhes", b.commit())
	_wall_ivy(g, w, wall_h)
	var mats_here := ["arvore_0", "arvore_1", "arvore_2", "arvore_pequena", "palmeira", "bananeira"]
	_plant(g, mats_here[_rng.randi() % 3], Vector3(_rng.randf_range(3.5, 6.5), -0.5, _rng.randf_range(-w * 0.3, w * 0.3)), _rng.randf() * TAU, _rng.randf_range(0.9, 1.3))
	if _rng.randf() < 0.55:
		_plant(g, "bananeira", Vector3(_rng.randf_range(1.5, 3.5), -0.45, _rng.randf_range(-w * 0.4, w * 0.4)), _rng.randf() * TAU, _rng.randf_range(0.9, 1.3))
	if _rng.randf() < 0.3:
		_plant(g, "palmeira", Vector3(_rng.randf_range(2.0, 5.0), -0.5, _rng.randf_range(-w * 0.3, w * 0.3)), _rng.randf() * TAU, _rng.randf_range(0.8, 1.1))
	for i in 3:
		_plant(g, "arbusto", Vector3(_rng.randf_range(0.8, 2.5), -0.5, _rng.randf_range(-w * 0.45, w * 0.45)), _rng.randf() * TAU, _rng.randf_range(0.9, 1.6))
	for i in int(w / 1.5):
		_plant(g, "capim", Vector3(-0.35, -0.12, -w / 2.0 + (i + 0.5) * w / int(w / 1.5)), _rng.randf() * TAU, _rng.randf_range(0.8, 1.5))


func _lot_talude(parent: Node3D, f: Dictionary) -> void:
	var w: float = f["w"]
	# o muro ocupa a calçada de cara: nada de caixote/balde/cesto encostado (atravessava o muro)
	var zz := -w / 2.0 + 0.6
	while zz <= w / 2.0 - 0.5:
		_reservar((f["xf"] as Transform3D) * Vector3(-0.4, 0.0, zz), 0.8)
		zz += 1.1
	var g := _group(parent, "Talude_%02d" % _n, f["xf"])
	_n += 1
	var ht := _rng.randf_range(3.0, 4.6)
	_box(g, "MuroDeArrimo", Vector3(0.8, ht + 2.0, w + 0.1), Vector3(0.4, (ht - 2.0) / 2.0, 0), "muro", true)
	_box(g, "Terraco", Vector3(8.0, ht + 1.0, w), Vector3(4.8, (ht - 1.0) / 2.0 - 0.25, 0), "terra_quintal")
	var b := _batch()
	b.box("cantaria", Vector3(1.0, 0.14, w + 0.2), Vector3(0.4, ht + 0.07, 0))
	_mesh_node(g, "Detalhes", b.commit())
	_wall_ivy(g, w, ht, -0.03)
	_wall_ivy(g, w, ht * 0.7, -0.05)
	if _rng.randf() < 0.65 and w > 6.0:
		var casa := make_casa(w * 0.85, 1, _pick_wall(), WOODS[_rng.randi() % WOODS.size()], 8.0, false, 0.4, true)
		casa.name = "CasaDoAlto"
		casa.position = Vector3(2.6, ht - 0.3, 0)
		g.add_child(casa)
	else:
		_plant(g, "arvore_%d" % _rng.randi_range(0, 2), Vector3(3.5, ht - 0.4, _rng.randf_range(-w * 0.3, w * 0.3)), _rng.randf() * TAU, _rng.randf_range(0.9, 1.3))
	for i in 3:
		_plant(g, "arbusto", Vector3(1.2, ht - 0.35, _rng.randf_range(-w * 0.45, w * 0.45)), _rng.randf() * TAU, _rng.randf_range(0.9, 1.5))
	for i in maxi(1, int(w / 2.5)):
		_plant(g, "samambaia", Vector3(0.1, ht - 0.2, -w / 2.0 + (i + 0.5) * w / maxi(1, int(w / 2.5))), 0.0, _rng.randf_range(0.8, 1.4))


## Beco em escada que sobe entre as casas.
func _lot_beco(parent: Node3D, f: Dictionary, cego_id := "") -> void:
	var wb: float = f["w"]
	var g := _group(parent, "Beco_%02d" % _n, f["xf"])
	_n += 1
	for off in [-0.5, 0.0, 1.0, 2.0]:
		_reservar((f["xf"] as Transform3D) * Vector3(-1.0 - off * 0.0, 0.0, 0.0) + (f["xf"] as Transform3D).basis.x * (-1.4 + off), wb * 0.5 + 0.9)
	var steps := 36 if cego_id == "" else 14
	var run := 0.45
	_casas_postas.append({"xf": f["xf"], "depth": steps * run + 0.8, "w": wb + 0.4})      # casas seguintes não invadem o beco
	var rise := 0.19
	var b := _batch()
	for i in steps:
		var top := (i + 1) * rise
		var hh := top + 1.0
		b.box("pedra_chao", Vector3(run, hh, wb - 0.2), Vector3((i + 0.5) * run, top - hh / 2.0, 0))
	var run_len := steps * run
	var total := steps * rise
	var ang := atan2(total, run_len)
	# paredes de pedra dos dois lados, em degraus, depois das casas vizinhas
	for sz: float in [-1.0, 1.0]:
		for k in 4:
			var x0 := k * run_len / 4.0
			var seg := run_len / 4.0
			var top := (k + 1) * total / 4.0 + 2.6
			b.box("muro", Vector3(seg + 0.05, top + 1.0, 0.5), Vector3(x0 + seg / 2.0, top / 2.0 - 0.5, sz * (wb / 2.0 + 0.25)))
			b.box("cantaria", Vector3(seg + 0.05, 0.12, 0.7), Vector3(x0 + seg / 2.0, top + 0.06, sz * (wb / 2.0 + 0.25)))
	_mesh_node(g, "Degraus", b.commit())
	# colisão: rampa sob os degraus + paredes
	var ramp := StaticBody3D.new()
	ramp.name = "Rampa"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(sqrt(run_len * run_len + total * total) + 0.5, 0.4, wb)
	cs.shape = bs
	ramp.add_child(cs)
	ramp.position = Vector3(run_len / 2.0, total / 2.0 - 0.2 * cos(ang), 0)
	ramp.rotation.z = ang
	g.add_child(ramp)
	for sz: float in [-1.0, 1.0]:
		# a parede começa na linha da fachada (x = 0); se avançasse para a rua, nas curvas prenderia quem anda pela borda
		_blocker(g, "Parede_%d" % int(sz), Vector3(run_len + 1.0, total + 6.0, 0.6), Vector3(run_len / 2.0 + 0.5, total / 2.0, sz * (wb / 2.0 + 0.3)))
	var refuge := Area3D.new()
	refuge.name = "Refugio"
	refuge.add_to_group("refugio", true)
	var rcs := CollisionShape3D.new()
	var rbs := BoxShape3D.new()
	rbs.size = Vector3(6.0, 3.4, wb)
	rcs.shape = rbs
	refuge.add_child(rcs)
	refuge.position = Vector3(3.2, 2.2, 0)
	g.add_child(refuge)
	# portão no alto + árvore e luz
	_blocker(g, "Fundo", Vector3(0.6, 8.0, wb + 1.2), Vector3(run_len + 0.6, total + 3.0, 0))
	if cego_id == "":
		var gate := _batch()
		gate.box("cantaria", Vector3(0.5, 3.0, wb + 1.0), Vector3(run_len + 0.35, total + 1.5, 0))
		_mesh_node(g, "Portao", gate.commit())
	if cego_id == "":
		# porta de madeira com ferragens (Poly Haven large_castle_door, CC0), voltada para a escada
		var door := _prop(g, "large_castle_door", Vector3(run_len + 0.12, total, 0), -PI / 2.0, 1.0)
		door.name = "PortaDoBeco"
	else:
		_beco_cego(g, wb, run_len, total, run, rise, cego_id)
	_plant(g, "arvore_%d" % _rng.randi_range(0, 2), Vector3(run_len + 3.0, total - 0.6, 0.5), _rng.randf() * TAU, 1.2)
	_plant(g, "bananeira", Vector3(run_len + 1.5, total - 0.3, -wb), _rng.randf() * TAU, 1.0)
	_plant(g, "samambaia", Vector3(run_len * 0.5, total * 0.5 + 2.7, wb / 2.0 + 0.6), 0.0, 1.2)
	var lamp := _lantern_wall(Vector3(run_len * 0.4, total * 0.4 + 2.3, wb / 2.0), PI)
	g.add_child(lamp)


## Beco de atalho. A boca de baixo ("ini") constrói o corredor inteiro (escadaria com patamares, muros, arcos, lampiões);
## a boca de cima só reserva o espaço: o corredor chega nela pelo outro lado.
func _lot_passagem(parent: Node3D, f: Dictionary, idx: int, ini: bool) -> void:
	var G: Dictionary = _pass_geo[idx]
	var xf_boca: Transform3D = f["xf"]
	_n += 1
	_reservar(xf_boca.origin, PASS_BOCA * 0.5 + 0.8)
	if not ini:
		return
	var dv: Vector3 = G["dir"]
	var D: float = G["D"]
	var rise: float = G["rise"]
	var g := _group(parent, str(G["id"]), Transform3D(Basis(dv, Vector3.UP, dv.cross(Vector3.UP)), G["A"]))
	g.set_meta("passagem", true)
	g.set_meta("comprimento", D)
	g.set_meta("subida", rise)
	var wb := PASS_W
	var n := maxi(8, int(round(D / 0.5)))
	var run := D / n
	var q := 0.0
	if rise > 0.05:
		q = rise / ceilf(rise / 0.19)       # degraus de no máximo 19 cm; onde a rampa "sobra", vira patamar plano
	var tops := PackedFloat32Array()
	for i in n:
		var lin := (i + 1) * rise / n
		tops.append(roundf(lin / q) * q if q > 0.0 else lin)
	var b := _batch()
	for i in n:
		var top := tops[i]
		var hh := top + 1.0
		b.box("pedra_chao", Vector3(run + 0.02, hh, wb + 0.1), Vector3((i + 0.5) * run, top - hh / 2.0, 0))
	# muros de pedra dos dois lados, em lances que acompanham a subida
	var nseg := int(ceil(D / 4.0))
	var seg := D / nseg
	for sz: float in [-1.0, 1.0]:
		for k in nseg:
			var x0 := k * seg
			var top := tops[mini(n - 1, int((k + 1) * seg / run) - 1)] + 2.7
			b.box("muro", Vector3(seg + 0.05, top + 1.0, 0.5), Vector3(x0 + seg / 2.0, top / 2.0 - 0.5, sz * (wb / 2.0 + 0.25)))
			b.box("cantaria", Vector3(seg + 0.05, 0.12, 0.7), Vector3(x0 + seg / 2.0, top + 0.06, sz * (wb / 2.0 + 0.25)))
	# arcos de cantaria nas duas bocas
	for fim: float in [0.0, 1.0]:
		var ax := 0.45 if fim == 0.0 else D - 0.45
		var by := tops[0] if fim == 0.0 else tops[n - 1]
		for sz: float in [-1.0, 1.0]:
			b.box("cantaria", Vector3(0.7, 3.3, 0.6), Vector3(ax, by + 1.65, sz * (wb / 2.0 + 0.3)))
		b.box("cantaria", Vector3(0.9, 0.45, wb + 1.5), Vector3(ax, by + 3.5, 0))
		b.box("cantaria", Vector3(1.1, 0.14, wb + 1.7), Vector3(ax, by + 3.78, 0))
	_mesh_node(g, "Degraus", b.commit())
	# colisão: rampa lisa sob os degraus (o jogador sobe como nos outros becos) + paredes
	var ang := atan2(rise, D)
	var ramp := StaticBody3D.new()
	ramp.name = "Rampa"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(sqrt(D * D + rise * rise) + 0.5, 0.4, wb)
	cs.shape = bs
	ramp.add_child(cs)
	ramp.position = Vector3(D / 2.0, rise / 2.0 - 0.2 * cos(ang), 0)
	ramp.rotation.z = ang
	g.add_child(ramp)
	for sz: float in [-1.0, 1.0]:
		_blocker(g, "Parede_%d" % int(sz), Vector3(D - 0.2, rise + 6.0, 0.6), Vector3(D / 2.0, rise / 2.0, sz * (wb / 2.0 + 0.3)))
	# refúgio no meio: dentro do corredor fechado vale como esconderijo contra a Mula
	var refuge := Area3D.new()
	refuge.name = "Refugio"
	refuge.add_to_group("refugio", true)
	var rcs := CollisionShape3D.new()
	var rbs := BoxShape3D.new()
	rbs.size = Vector3(minf(D - 2.0, 10.0), rise + 3.4, wb)
	rcs.shape = rbs
	refuge.add_child(rcs)
	refuge.position = Vector3(D / 2.0, rise / 2.0 + 1.7, 0)
	g.add_child(refuge)
	# lampiões e vegetação
	for li in 2:
		var lx := D * (0.28 if li == 0 else 0.72)
		var ly := tops[mini(n - 1, int(lx / run))] + 2.3
		var sg := 1.0 if li == 0 else -1.0
		g.add_child(_lantern_wall(Vector3(lx, ly, sg * (wb / 2.0)), PI if li == 0 else 0.0))
		_plant(g, "samambaia", Vector3(lx + 2.0, ly + 0.4, -sg * (wb / 2.0 + 0.6)), 0.0, 1.2)
	_plant(g, "samambaia", Vector3(D * 0.5, tops[n / 2] + 2.8, wb / 2.0 + 0.6), 0.0, 1.3)


func _lot_chafariz(parent: Node3D, f: Dictionary) -> void:
	var w: float = f["w"]
	var g := _group(parent, "Chafariz", f["xf"])
	for zz: float in [-2.4, 0.0, 2.4]:
		_reservar((f["xf"] as Transform3D) * Vector3(-1.2, 0.0, zz), 1.6)        # tanque e bica: nada de caixote encostado
	var b := _batch()
	# frente do paredão de pedra com pilastras, cornija, frontão e cruz
	b.box("muro", Vector3(1.0, 4.6, w), Vector3(0.5, 0.7, 0))
	b.box("cantaria", Vector3(1.15, 0.30, w + 0.3), Vector3(0.45, 3.15, 0))                    # cornija
	b.box("cantaria", Vector3(1.05, 0.22, w + 0.1), Vector3(0.50, 3.00, 0))
	for sz: float in [-1.0, 1.0]:
		b.box("cantaria", Vector3(0.34, 3.0, 0.55), Vector3(-0.08, 1.5, sz * 1.85))            # pilastras
		b.box("cantaria", Vector3(0.46, 0.20, 0.70), Vector3(-0.08, 0.10, sz * 1.85))
		b.box("cantaria", Vector3(0.46, 0.16, 0.70), Vector3(-0.08, 3.00, sz * 1.85))
		b.sphere("cantaria", 0.16, Vector3(-0.08, 3.40, sz * 2.05), 7, 4)                      # pináculos de bola
	b.box("cantaria", Vector3(0.70, 0.34, 4.4), Vector3(-0.02, 3.10, 0))                       # arquitrave
	b.prism("cantaria", Vector3(0.80, 0.95, 4.2), Vector3(0.0, 3.80, 0))                       # frontão triangular
	b.box("cantaria", Vector3(0.30, 0.55, 0.9), Vector3(-0.05, 3.55, 0))                       # brasão
	b.box("ferro", Vector3(0.05, 0.9, 0.05), Vector3(-0.05, 4.65, 0))                          # cruz
	b.box("ferro", Vector3(0.05, 0.05, 0.5), Vector3(-0.05, 4.85, 0))
	# nicho em arco com carranca e bica
	b.box("janela_escura", Vector3(0.10, 1.30, 1.50), Vector3(0.02, 1.55, 0))
	b.half_disc("janela_escura", Vector3(0.0, 2.20, 0), 0.75, 12)
	b.arch("cantaria", Vector3(-0.10, 2.20, 0), 0.82, 0.18, 0.20, 12)
	b.box("cantaria", Vector3(0.20, 1.30, 0.18), Vector3(-0.10, 1.55, -0.84))
	b.box("cantaria", Vector3(0.20, 1.30, 0.18), Vector3(-0.10, 1.55, 0.84))
	b.sphere("cantaria", 0.20, Vector3(-0.10, 1.65, 0), 8, 5)                                  # carranca
	b.cylinder("cantaria", 0.07, 0.07, 0.42, Vector3(-0.30, 1.38, 0), Vector3(0, 0, PI / 2.0), 8)   # bica
	b.cylinder("ferro", 0.035, 0.035, 0.12, Vector3(-0.54, 1.36, 0), Vector3(0, 0, PI / 2.0), 6)
	# tanque de pedra (paredes + fundo) e degraus
	b.box("cantaria", Vector3(1.20, 0.18, 2.9), Vector3(-1.10, 0.09, 0))                       # fundo
	b.box("cantaria", Vector3(0.16, 0.78, 2.9), Vector3(-1.62, 0.39, 0))
	b.box("cantaria", Vector3(0.16, 0.78, 2.9), Vector3(-0.60, 0.39, 0))
	b.box("cantaria", Vector3(1.20, 0.78, 0.16), Vector3(-1.10, 0.39, -1.37))
	b.box("cantaria", Vector3(1.20, 0.78, 0.16), Vector3(-1.10, 0.39, 1.37))
	b.box("cantaria", Vector3(1.32, 0.07, 3.02), Vector3(-1.10, 0.81, 0))                      # borda
	b.box("cantaria", Vector3(1.0, 0.13, 3.3), Vector3(-2.15, 0.065, 0))                       # degraus
	b.box("cantaria", Vector3(0.7, 0.26, 3.1), Vector3(-1.95, 0.13, 0))
	for sz: float in [-1.0, 1.0]:
		b.box("cantaria", Vector3(0.45, 0.46, 0.95), Vector3(-0.35, 0.23, sz * (w / 2.0 - 0.55)))   # bancos
	_mesh_node(g, "Detalhes", b.commit())
	# água do tanque (shader) e fio de água caindo da bica
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 2.7)
	var water := _mesh_node(g, "Agua", plane, Vector3(-1.10, 0.62, 0))
	water.material_override = mat("agua")
	for yaw: float in [0.0, PI / 2.0]:
		var q := QuadMesh.new()
		q.size = Vector2(0.12, 0.78)
		var jet := _mesh_node(g, "FioDeAgua", q, Vector3(-0.60, 1.0, 0))
		jet.rotation.y = yaw
		jet.material_override = mat("agua_queda")
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lamp := _lantern_wall(Vector3(-0.26, 2.55, 1.85), -PI / 2.0)
	lamp.name = "LampiaoDoChafariz"
	g.add_child(lamp)
	_blocker(g, "Colisao", Vector3(1.6, 5.0, w), Vector3(0.7, 1.5, 0))
	_blocker(g, "ColisaoTanque", Vector3(1.5, 0.9, 3.0), Vector3(-1.1, 0.45, 0))
	_plant(g, "palmeira", Vector3(3.0, -0.5, -w * 0.3), 0.0, 1.0)
	_plant(g, "palmeira", Vector3(4.0, -0.5, w * 0.35), 1.0, 1.15)


# ------------------------------------------------------------------ iluminação
func _lamp_light(parent: Node3D, pos: Vector3, energy := 0.9) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "Luz"
	light.position = pos
	light.light_color = Color(1.0, 0.72, 0.35)
	light.light_energy = energy
	light.omni_range = 8.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 50.0
	light.distance_fade_length = 15.0
	light.set_script(load("res://scripts/luz_tremula.gd"))
	light.set("forca", 0.08)
	light.add_to_group("lampioes", true)
	parent.add_child(light)
	return light


## Esconderijo: gatilho (Area) um pouco maior que o objeto, para o raio de interação o alcançar antes da colisão.
func _esconderijo(parent: Node, nome: String, pos: Vector3, size: Vector3, oculto: Vector3, yaw: float) -> Area3D:
	var a := Area3D.new()
	a.name = nome
	a.position = pos
	a.set_script(load("res://scripts/esconderijo.gd"))
	a.set("pos_oculto", oculto)
	a.set("yaw_oculto", yaw)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	parent.add_child(a)
	return a


## Beco SEM SAÍDA: o portão de ferro trancado fecha o alto da escada (dá para ver o quintal atrás) e há uma casa com porta na parede lateral.
func _beco_cego(g: Node3D, wb: float, run_len: float, total: float, run: float, rise: float, cego_id: String) -> void:
	g.set_meta("cego", true)
	var kit := PropKit.scene("large_iron_gate").instantiate() as Node3D
	var gb := PropKit.bounds(kit)
	kit.free()
	var sc := (wb - 0.15) / maxf(gb.size.x, 0.01)
	var gate := _prop(g, "large_iron_gate", Vector3(run_len + 0.1, total, 0), -PI / 2.0, sc)
	gate.name = "PortaoDeFerro"
	_prop_collision(gate, "caixa", Vector3(wb, 3.0, 0.3), Vector3(0, 1.5, 0))
	var sz := -1.0 if _rng.randf() < 0.5 else 1.0
	var dx := run_len - 1.9
	var base_y := (int(dx / run) + 1) * rise
	var b := _batch()
	b.box("cantaria", Vector3(1.5, 2.55, 0.14), Vector3(dx, base_y + 1.27, sz * (wb / 2.0 - 0.02)))
	b.box("madeira_escura", Vector3(1.15, 2.3, 0.1), Vector3(dx, base_y + 1.15, sz * (wb / 2.0 - 0.1)))
	b.box("ferro", Vector3(0.05, 0.12, 0.06), Vector3(dx + 0.4, base_y + 1.05, sz * (wb / 2.0 - 0.18)))
	b.box("cantaria", Vector3(1.4, 0.12, 0.6), Vector3(dx, base_y + 0.06, sz * (wb / 2.0 - 0.3)))   # soleira
	_mesh_node(g, "PortaLateral", b.commit())
	var a := Area3D.new()
	a.name = "Entrada_%s" % cego_id
	a.position = Vector3(dx, base_y + 1.3, sz * (wb / 2.0 - 0.7))
	a.set_script(load("res://scripts/porta.gd"))
	a.set("destino", cego_id)
	a.set("texto_interacao", "Entrar na casa do beco")
	a.set_meta("fora_local", Vector3(0, 0, -sz))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 2.6, 1.4)
	cs.shape = bs
	a.add_child(cs)
	g.add_child(a)
	_coletavel(g, "Oleo_beco_%d" % _n, Vector3(run_len - 0.5, total, -sz * 0.7), "oleo", 0, "Pegar querosene")
	# esconderijo: agachado no canto do alto da escada, atrás do portão (os positions são locais ao beco; convertidos no bake)
	var bx := g.transform.basis.x
	_esconderijo(g, "Esconderijo", Vector3(run_len - 0.9, total + 0.8, sz * 0.95), Vector3(1.0, 1.6, 0.9), g.transform * Vector3(run_len - 1.3, total + 0.1, sz * 0.9), atan2(-bx.x, -bx.z))
	_lamp_light(g, Vector3(dx, base_y + 3.0, sz * (wb / 2.0 - 0.6)), 0.7)


## Brilho difuso ao redor de uma fonte de luz (billboard aditivo). Some junto com a luz no apagão.
func _halo(parent: Node3D, pos: Vector3, size: float, mat_name := "halo_quente") -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := _mesh_node(parent, "Halo", q, pos)
	mi.material_override = mat(mat_name)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
func make_poste() -> Node3D:
	# poste de ferro fundido (Poly Haven street_lamp_01, CC0) com a lâmpada emissiva; a luz sai do bulbo
	var m := PropKit.make("street_lamp_01", 1.0)
	m.name = "Poste"
	PropKit.setup_bulb(m, Color(1.0, 0.82, 0.52), 3.4)
	var bpos: Vector3 = m.get_meta("bulb_pos", Vector3(0, 3.5, 0))
	_lamp_light(m, bpos, 0.95)
	_halo(m, bpos, 2.6)
	_prop_collision(m, "cil", Vector3(0.22, 3.9, 0.22), Vector3(0, 1.95, 0))
	return m


func _glass_node(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh_node(parent, "Vidro", bm, pos)
	mi.material_override = (mat("vidro_lampiao") as Material).duplicate()
func _lantern_wall(pos: Vector3, yaw: float) -> Node3D:
	# lampião com suporte de ferro (Poly Haven street_lamp_02, CC0). `pos` = ponto NA PAREDE; `yaw` aponta o braço (+Z local) para a rua.
	var m := PropKit.make("street_lamp_02", 0.62, "parede")
	m.name = "LampiaoParede"
	m.position = pos
	m.rotation.y = yaw
	PropKit.setup_bulb(m, Color(1.0, 0.80, 0.48), 3.0)
	var bpos: Vector3 = m.get_meta("bulb_pos", Vector3(0, 0.8, 0.3))
	_lamp_light(m, bpos, 0.85)
	_halo(m, bpos, 1.8)
	return m


func _lamps() -> Node3D:
	var root := Node3D.new()
	root.name = "Iluminacao"
	# lampiões de ferro presos às fachadas, alternando os lados (como nas ruas reais)
	var s := 6.0
	var i := 0
	while s < S_END + 24.0:
		var sigma := -1.0 if i % 2 == 0 else 1.0
		var out := -Route.right(s) * sigma     # da fachada para a rua
		# só prende o lampião onde há parede de casa de verdade (vão de beco, quintal, ponte e talude deixavam o lampião no ar)
		var sl := s
		var achou := false
		for k in 12:
			var wp0 := facade(sigma, sl)
			if _parede_de_casa(wp0, 0.7):
				achou = true
				break
			sl += 0.9
		if achou:
			var wall_pt := facade(sigma, sl) + Vector3(0, SW_H + 2.75, 0)
			var lamp := _lantern_wall(wall_pt, atan2(out.x, out.z))
			lamp.name = "LampiaoParede_%02d" % i
			root.add_child(lamp)
			i += 1
		s = sl + _rng.randf_range(10.0, 13.5)
	# postes nas partes largas (largo, adro)
	for ps in [150.0, 164.0, S_END + 10.0, S_END + 26.0, S_END + 42.0]:
		for sigma: float in [-1.0, 1.0]:
			var w := Route.width(ps)
			var p := make_poste()
			p.name = "Poste_%d_%d" % [int(ps), int(sigma)]
			p.position = Route.pos(ps) + Route.right(ps) * sigma * (w * 0.5 + SW * 0.5) + Vector3(0, SW_H, 0)
			_reservar(p.position, 0.9)
			root.add_child(p)
	root.add_child(_string_lights())
	return root


## Fios de lâmpadas atravessando a rua (como nas fotos da cidade à noite).
func _string_lights() -> Node3D:
	var root := Node3D.new()
	root.name = "FiosDeLuz"
	var sph := SphereMesh.new()
	sph.radius = 0.07
	sph.height = 0.14
	sph.radial_segments = 6
	sph.rings = 3
	var xforms: Array[Transform3D] = []
	for s: float in [28.0, 96.0, 150.0, 172.0, 205.0, 252.0, 292.0]:
		var a := facade(-1.0, s) + Vector3(0, SW_H + 5.2, 0)
		var b := facade(1.0, s) + Vector3(0, SW_H + 5.2, 0)
		var n := int(a.distance_to(b) / 0.55)
		for k in n + 1:
			var t := float(k) / n
			var pt := a.lerp(b, t)
			pt.y -= sin(t * PI) * 0.9           # catenária
			xforms.append(Transform3D(Basis.IDENTITY, pt))
		var l := OmniLight3D.new()
		l.name = "Luz_%d" % int(s)
		l.position = (a + b) * 0.5 + Vector3(0, -0.6, 0)
		l.light_color = Color(1.0, 0.8, 0.5)
		l.light_energy = 0.9
		l.omni_range = 8.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 45.0
		l.distance_fade_length = 15.0
		root.add_child(l)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sph
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Lampadas"
	mmi.multimesh = mm
	mmi.material_override = mat("bulbo")
	root.add_child(mmi)
	return root


# ------------------------------------------------------------------ largo da igreja

func _church_plaza() -> Node3D:
	var root := Node3D.new()
	root.name = "Adro"
	# muretas baixas ao longo do adro
	for sigma: float in [-1.0, 1.0]:
		var s := S_END
		while s < CHURCH_S - 4.0:
			var s2 := _advance(sigma, s, 4.0)
			var f := lot_frame(sigma, s, s2)
			var g := _group(root, "Mureta_%02d" % _n, f["xf"])
			_n += 1
			_box(g, "Muro", Vector3(0.5, 2.4, f["w"] + 0.1), Vector3(0.25, 0.0, 0), "muro", true)
			var b := _batch()
			b.box("cantaria", Vector3(0.75, 0.12, f["w"] + 0.2), Vector3(0.25, 1.26, 0))
			_mesh_node(g, "Capa", b.commit())
			_wall_ivy(g, f["w"], 1.2)
			if _rng.randf() < 0.5:
				_plant(g, "arbusto", Vector3(1.2, 0.0, _rng.randf_range(-1, 1)), 0.0, 1.3)
			s = s2
	# igreja
	var sc := CHURCH_S
	var pos := Route.pos(sc)
	var t := Route.tangent(sc)
	var basis := Basis(t, Vector3.UP, t.cross(Vector3.UP))
	var church := make_igreja(15.0, 30.0, true, true)
	church.transform = Transform3D(basis, pos + Vector3(0, 0.0, 0))
	root.add_child(church)
	# cruzeiro
	var cz := _group(root, "Cruzeiro", Transform3D(Basis.IDENTITY, Route.pos(S_END + 24.0) + Route.right(S_END + 24.0) * 4.5))
	var cb := _batch()
	for k in 3:
		cb.box("cantaria", Vector3(2.4 - k * 0.5, 0.3, 2.4 - k * 0.5), Vector3(0, 0.15 + k * 0.3, 0))
	cb.box("cantaria", Vector3(0.35, 4.6, 0.35), Vector3(0, 3.2, 0))
	cb.box("cantaria", Vector3(1.8, 0.35, 0.35), Vector3(0, 4.6, 0))
	_mesh_node(cz, "Malha", cb.commit())
	_blocker(cz, "Colisao", Vector3(2.4, 5.0, 2.4), Vector3(0, 2.5, 0))
	# palmeiras do adro
	for sigma: float in [-1.0, 1.0]:
		for ss: float in [S_END + 8.0, S_END + 28.0]:
			var p := Route.pos(ss) + Route.right(ss) * sigma * (Route.width(ss) * 0.5 + SW + 2.6)
			_plant(root, "palmeira", Vector3(p.x, p.y - 0.4, p.z), _rng.randf() * TAU, _rng.randf_range(0.95, 1.2))
	return root


## Igreja barroca mineira (inspiração): fachada branca com cantaria, portal em arco, óculo, frontão com volutas e torres cilíndricas.
## Quadro local: +X para dentro da igreja, fachada em x = 0 olhando para -X. Origem ao nível do adro.
func make_igreja(width: float, nave_len: float, twin: bool, collide: bool) -> Node3D:
	var c := Node3D.new()
	c.name = "Igreja"
	var nh := 12.0                 # altura da nave
	var fh := 15.5                 # altura da fachada
	var wall := "reboco_caiado"      # caiada: bem mais clara que o reboco das casas
	var half := width / 2.0
	_box(c, "Nave", Vector3(nave_len, nh + 3.0, width), Vector3(nave_len / 2.0, (nh - 3.0) / 2.0, 0), wall, collide)
	_box(c, "Fachada", Vector3(1.6, fh + 3.0, width), Vector3(0.8, (fh - 3.0) / 2.0, 0), wall, collide)
	# telhado da nave: telhas no sentido do caimento, cumeeira ao longo de X, forro sob o beiral
	var rise := (width + 1.2) * 0.3
	var rb := _batch()
	rb.roof("telha_uv", wall, Vector3(width + 1.2, rise, nave_len + 1.0), Vector3(nave_len / 2.0, nh + rise / 2.0, 0), PI / 2.0, 3.6, "madeira_escura")
	rb.box("telha_cumeeira", Vector3(nave_len + 1.1, 0.28, 0.42), Vector3(nave_len / 2.0, nh + rise + 0.05, 0))
	_mesh_node(c, "TelhadoNave", rb.commit())

	var b := _batch()
	# pilastras e cornijas da fachada
	for sz: float in [-1.0, 1.0]:
		for zz: float in [half - 0.45, 3.5]:
			b.box("cantaria", Vector3(0.30, fh - 0.4, 0.62), Vector3(-0.12, (fh - 0.4) / 2.0, sz * zz))
			b.box("cantaria", Vector3(0.42, 0.50, 0.84), Vector3(-0.15, 0.25, sz * zz))
			b.box("cantaria", Vector3(0.42, 0.32, 0.84), Vector3(-0.15, fh - 0.55, sz * zz))
	b.box("cantaria", Vector3(0.60, 0.34, width + 0.5), Vector3(-0.22, fh - 0.17, 0))
	b.box("cantaria", Vector3(0.42, 0.22, width + 0.3), Vector3(-0.15, 8.6, 0))
	# frontão escalonado com cornijas, volutas e pináculos
	for k in 4:
		var wk := width * (0.62 - k * 0.14)
		b.box(wall, Vector3(1.5, 0.9, wk), Vector3(0.0, fh + 0.45 + k * 0.9, 0))
		b.box("cantaria", Vector3(1.7, 0.16, wk + 0.3), Vector3(-0.05, fh + 0.9 + k * 0.9, 0))
	for sz: float in [-1.0, 1.0]:
		b.arch("cantaria", Vector3(-0.10, fh + 0.35, sz * (width * 0.62 * 0.5 + 0.95)), 0.95, 0.28, 0.36, 9)   # voluta lateral
		b.box("cantaria", Vector3(0.5, 0.55, 0.5), Vector3(-0.15, fh + 0.25, sz * (half - 0.3)))
		b.sphere("cantaria", 0.34, Vector3(-0.15, fh + 0.85, sz * (half - 0.3)), 8, 5)
	b.box("cantaria", Vector3(0.3, 2.4, 0.3), Vector3(-0.05, fh + 5.0, 0))
	b.box("cantaria", Vector3(0.3, 0.3, 1.3), Vector3(-0.05, fh + 5.6, 0))
	# portal em arco de cantaria com porta de madeira e leque de luz
	var pr := 1.9
	var py := 4.4
	for sz: float in [-1.0, 1.0]:
		b.box("cantaria", Vector3(0.62, py, 0.52), Vector3(-0.31, py / 2.0, sz * (pr + 0.26)))
	b.arch("cantaria", Vector3(-0.31, py, 0), pr + 0.26, 0.52, 0.62, 14)
	b.box("cantaria", Vector3(0.78, 0.62, 0.55), Vector3(-0.34, py + pr + 0.28, 0))                  # fecho do arco
	b.box("cantaria", Vector3(0.50, 0.30, 2.0 * pr + 1.6), Vector3(-0.30, py + pr + 0.90, 0))          # cornija do portal
	for sz: float in [-1.0, 1.0]:
		b.box("madeira_natural", Vector3(0.14, py - 0.05, pr - 0.04), Vector3(-0.50, py / 2.0, sz * (pr / 2.0)))
		for yy: float in [0.9, 2.2, 3.5]:
			b.box("ferro", Vector3(0.05, 0.14, pr - 0.16), Vector3(-0.59, yy, sz * (pr / 2.0)))          # ferragens
		b.box("ferro", Vector3(0.09, 0.50, 0.09), Vector3(-0.62, 2.2, sz * 0.22))                          # puxador
	b.half_disc("porta_igreja", Vector3(-0.52, py, 0), pr - 0.04, 14)                                     # leque com a luz do interior
	for k in 3:                                                                                           # degraus do adro
		b.box("cantaria", Vector3(0.8, 0.14 * (3 - k), width * 0.7), Vector3(-1.4 - k * 0.8, 0.07 * (3 - k), 0))
	# óculo com raios de pedra
	b.cylinder("cantaria", 1.30, 1.30, 0.30, Vector3(-0.20, 11.7, 0), Vector3(0, 0, PI / 2.0), 18)
	b.cylinder("janela_escura", 0.98, 0.98, 0.34, Vector3(-0.22, 11.7, 0), Vector3(0, 0, PI / 2.0), 18)
	for k in 4:
		b.box("cantaria", Vector3(0.12, 0.09, 2.0), Vector3(-0.42, 11.7, 0), Vector3(k * PI / 4.0, 0, 0))
	# janelas laterais em arco e janelas baixas com grade
	for side: float in [-1.0, 1.0]:
		_window(b, Vector3(0, 8.4, side * (half - 2.5)), 1.4, 2.8, "madeira_escura", true, false, false, true)     # janelas do coro, acesas
		_window(b, Vector3(0, 2.7, side * (half - 2.5)), 1.1, 1.8, "madeira_escura", true, true)
		_window(b, Vector3(0, 10.2, side * 3.7), 1.1, 2.3, "madeira_escura", true, false, false, true)
	# colunas do portal com capitel e entablamento, medalhão e nichos com santos (Ouro Preto: a portada é a joia da fachada)
	for sz: float in [-1.0, 1.0]:
		var zc := sz * (pr + 1.25)
		b.cylinder("cantaria", 0.36, 0.42, py + pr + 0.7, Vector3(-0.62, (py + pr + 0.7) / 2.0, zc), Vector3.ZERO, 14)
		b.box("cantaria", Vector3(0.95, 0.34, 0.95), Vector3(-0.62, 0.17, zc))
		b.box("cantaria", Vector3(1.0, 0.36, 1.0), Vector3(-0.62, py + pr + 0.9, zc))
		b.box("cantaria", Vector3(0.7, 0.2, 0.7), Vector3(-0.62, py + pr + 1.18, zc))
		# nicho com moldura e fundo escuro
		var nz := sz * 5.35
		b.box("cantaria", Vector3(0.34, 2.9, 1.6), Vector3(-0.17, 5.4, nz))
		b.arch("cantaria", Vector3(-0.17, 6.85, nz), 0.8, 0.34, 0.2, 9)
		b.box("janela_escura", Vector3(0.1, 2.5, 1.1), Vector3(-0.32, 5.35, nz))
		b.box("cantaria", Vector3(0.5, 0.18, 1.3), Vector3(-0.36, 4.15, nz))
	b.box("cantaria", Vector3(1.05, 0.5, 2.0 * (pr + 1.25) + 1.3), Vector3(-0.62, py + pr + 1.55, 0))
	b.box("cantaria", Vector3(1.15, 0.2, 2.0 * (pr + 1.25) + 1.5), Vector3(-0.66, py + pr + 1.9, 0))
	b.cylinder("cantaria", 1.0, 1.0, 0.34, Vector3(-0.40, py + pr + 3.2, 0), Vector3(0, 0, PI / 2.0), 20)          # medalhão
	b.cylinder("ouro_velho", 0.72, 0.72, 0.38, Vector3(-0.44, py + pr + 3.2, 0), Vector3(0, 0, PI / 2.0), 20)
	b.cylinder("cantaria", 0.38, 0.38, 0.42, Vector3(-0.50, py + pr + 3.2, 0), Vector3(0, 0, PI / 2.0), 12)
	for k in 3:                                                                                            # escadaria mais larga
		b.box("cantaria", Vector3(0.9, 0.16 * (4 - k), width * 0.9), Vector3(-1.9 - k * 0.9, 0.08 * (4 - k), 0))
	_mesh_node(c, "Detalhes", b.commit())
	# santos nos nichos (Poly Haven gothic_statue, CC0)
	var sprobe := PropKit.make("gothic_statue", 1.0)
	var sbb: AABB = sprobe.get_meta("bb")
	sprobe.free()
	var ssc := 1.9 / maxf(sbb.size.y, 0.1)
	for sz: float in [-1.0, 1.0]:
		var st := _prop(c, "gothic_statue", Vector3(-0.36, 4.25, sz * 5.35), -PI / 2.0, ssc)
		st.name = "Santo_%s" % ("E" if sz < 0 else "D")
	# lampiões de ferro e luz quente de baixo para cima: a fachada aparece de noite
	for sz: float in ([-1.0, 1.0] if twin else []):
		var pt := make_poste()
		pt.position = Vector3(-6.0, 0.0, sz * 6.4)
		c.add_child(pt)
		var fl := OmniLight3D.new()
		fl.name = "Refletor_%s" % ("E" if sz < 0 else "D")
		fl.position = Vector3(-3.4, 1.4, sz * 5.4)
		fl.light_color = Color(1.0, 0.80, 0.5)
		fl.light_energy = 3.2
		fl.omni_range = 14.0
		fl.distance_fade_enabled = true
		fl.distance_fade_begin = 70.0
		fl.distance_fade_length = 20.0
		c.add_child(fl)

	# torres cilíndricas com pilastras, sineira com aberturas e cúpula
	for side: float in [-1.0, 1.0]:
		if not twin and side > 0.0:
			continue
		var tz := side * (half + 1.7)
		var t := _group(c, "Torre_%s" % ("Esq" if side < 0 else "Dir"), Transform3D(Basis.IDENTITY, Vector3(1.0, 0, tz)))
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.12
		cyl.bottom_radius = 2.28
		cyl.height = 24.0
		cyl.radial_segments = 24
		var body := _mesh_node(t, "Corpo", cyl, Vector3(0, 8.0, 0))
		body.material_override = mat(wall)
		if collide:
			_add_box_collision(body, Vector3(4.4, 24.0, 4.4))
		var tb := _batch()
		for k in 8:                                                                                         # pilastras verticais
			var a := k * TAU / 8.0 + PI / 8.0
			tb.box("cantaria", Vector3(0.24, 22.6, 0.50), Vector3(cos(a) * 2.20, 7.3, sin(a) * 2.20), Vector3(0, -a, 0))
		for ry: float in [-0.2, 6.2, 12.4, 19.7]:                                                         # anéis de cornija
			tb.cylinder("cantaria", 2.62, 2.62, 0.34, Vector3(0, ry, 0), Vector3.ZERO, 20)
		for k in 4:                                                                                         # aberturas da sineira
			var a := k * PI / 2.0
			var rad := Vector3(cos(a), 0, sin(a))
			var tan_v := Vector3(-sin(a), 0, cos(a))
			var cen := rad * 2.12 + Vector3(0, 15.6, 0)
			tb.box("janela_escura", Vector3(0.14, 3.2, 1.35), cen, Vector3(0, -a, 0))
			for sg: float in [-1.0, 1.0]:
				tb.box("cantaria", Vector3(0.24, 3.5, 0.22), cen + tan_v * sg * 0.78 + rad * 0.04, Vector3(0, -a, 0))
			tb.box("cantaria", Vector3(0.26, 0.26, 1.80), cen + Vector3(0, 1.74, 0) + rad * 0.04, Vector3(0, -a, 0))
			tb.box("cantaria", Vector3(0.30, 0.22, 1.9), cen + Vector3(0, -1.70, 0) + rad * 0.06, Vector3(0, -a, 0))
		_mesh_node(t, "Detalhes", tb.commit())
		var dome := SphereMesh.new()
		dome.radius = 2.5
		dome.height = 3.8
		dome.radial_segments = 24
		dome.rings = 10
		_mesh_node(t, "Cupula", dome, Vector3(0, 20.6, 0)).material_override = mat("telha")
		var lantern := CylinderMesh.new()
		lantern.top_radius = 1.0
		lantern.bottom_radius = 1.1
		lantern.height = 2.0
		_mesh_node(t, "Lanterna", lantern, Vector3(0, 22.9, 0)).material_override = mat("cantaria")
		var dome2 := SphereMesh.new()
		dome2.radius = 1.25
		dome2.height = 2.2
		_mesh_node(t, "CupulaAlta", dome2, Vector3(0, 24.4, 0)).material_override = mat("telha")
		var cb := _batch()
		cb.box("ferro", Vector3(0.16, 2.4, 0.16), Vector3(0, 26.4, 0))
		cb.box("ferro", Vector3(1.0, 0.16, 0.16), Vector3(0, 26.9, 0))
		cb.sphere("ouro_velho", 0.20, Vector3(0, 25.4, 0), 8, 5)
		for k in 4:
			var a := k * PI / 2.0 + PI / 4.0
			cb.box("janela_escura", Vector3(0.7, 1.1, 0.06), Vector3(cos(a) * 1.07, 22.9, sin(a) * 1.07), Vector3(0, -a + PI / 2.0, 0))
		_mesh_node(t, "Cruz", cb.commit())

	# gatilho de vitória, na frente do portal
	var door := Area3D.new()
	door.name = "Porta"
	door.position = Vector3(-2.6, 2.5, 0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 5.0, 5.5)
	cs.shape = bs
	door.add_child(cs)
	c.add_child(door)
	var light := OmniLight3D.new()
	light.name = "LuzPorta"
	light.position = Vector3(-3.0, 3.5, 0)
	light.light_color = Color(1.0, 0.78, 0.42)
	light.light_energy = 1.7
	light.omni_range = 16.0
	c.add_child(light)
	_halo(c, Vector3(-1.2, 5.0, 0), 3.2, "halo_quente")
	return c


# ------------------------------------------------------------------ morros ao redor

func _hillside() -> Node3D:
	var root := Node3D.new()
	root.name = "Morros"
	_capelas(root)
	_hill_houses(root)
	_near_trees(root)
	root.add_child(_forest())
	root.add_child(_far_lights())
	return root


func _capelas(root: Node3D) -> void:
	# capelas em morros altos, visíveis de longe (referência para o jogador)
	for cs in [[78.0, -1.0, 58.0], [236.0, 1.0, 70.0]]:
		var s: float = cs[0]
		var sg: float = cs[1]
		var p := Route.pos(s) + Route.right(s) * sg * float(cs[2])
		var h := terrain_h(p.x, p.z)
		var x_axis := Route.right(s) * sg
		var ch := make_igreja(9.0, 14.0, false, false)
		ch.name = "Capela_%d" % int(s)
		ch.transform = Transform3D(Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)), Vector3(p.x, h + 0.6, p.z))
		_box(ch, "Embasamento", Vector3(18.0, 9.0, 13.0), Vector3(7.0, -3.9, 0), "muro")
		root.add_child(ch)
		_spots.append(Vector2(p.x, p.z))
		_spots.append(Vector2(p.x, p.z) + Vector2(x_axis.x, x_axis.z) * 8.0)


## Casario denso das encostas: centenas de casas fundidas em poucos blocos (um bloco por área de 70 m).
func _hill_houses(root: Node3D) -> void:
	var holder := _group(root, "CasasDoMorro")
	var batches := {}
	var tries := 0
	var placed := 0
	while placed < 360 and tries < 8000:
		tries += 1
		var sc := clampf(_rng.randf_range(0.0, Route.length() + 15.0), 0.0, Route.length())
		var sigma := -1.0 if _rng.randf() < 0.5 else 1.0
		if absf(sc - Route.BRIDGE_S) < 11.0:
			continue
		var d := _rng.randf_range(Route.width(sc) * 0.5 + 21.0, 150.0)
		var p := Route.pos(sc) + Route.right(sc) * sigma * d
		var q := Vector2(p.x, p.z)
		if Route.dist_to_center(p) < Route.width(sc) * 0.5 + 19.0:      # nas curvas fechadas, d medido na normal pode cair perto de OUTRA perna da rua
			continue
		var near := false
		for o in _spots:
			if o.distance_to(q) < 10.5:
				near = true
				break
		if near:
			continue
		var x_axis := (Route.right(sc) * sigma).rotated(Vector3.UP, _rng.randf_range(-0.4, 0.4))
		var z_axis := x_axis.cross(Vector3.UP)
		var w := _rng.randf_range(6.0, 10.5)
		var dep := _rng.randf_range(6.0, 9.0)
		var hi := -INF
		var lo := INF
		for cx: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			for cz: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var cp := p + x_axis * cx * (dep * 0.5 + 0.8) + z_axis * cz * (w * 0.5 + 0.8)
				var hh := terrain_h(cp.x, cp.z)
				hi = maxf(hi, hh)
				lo = minf(lo, hh)
		if hi - lo > 5.5:
			continue
		var base := lerpf(lo, hi, 0.5) + 0.25      # meio enterrada na encosta: base de pedra mais baixa
		var floors := 2 if _rng.randf() < 0.4 else 1
		var hgt := 3.8 + (floors - 1) * 3.2
		var key := Vector2i(int(floor(p.x / 70.0)), int(floor(p.z / 70.0)))
		if not batches.has(key):
			batches[key] = _batch()
		var b: MeshBatch = batches[key]
		var yaw := atan2(-x_axis.z, x_axis.x)
		var skirt := base - lo + 2.0
		b.box("muro", Vector3(dep + 1.0, skirt, w + 1.0), Vector3(p.x, base - skirt / 2.0 + 0.05, p.z), Vector3(0, yaw, 0))
		var hw := _pick_wall()
		b.box(hw, Vector3(dep, hgt, w), Vector3(p.x, base + hgt / 2.0, p.z), Vector3(0, yaw, 0))
		var rise := (dep + 1.2) * _rng.randf_range(0.24, 0.33)
		b.roof("telha_uv", hw, Vector3(dep + 1.2, rise, w + 0.4), Vector3(p.x, base + hgt + 0.05 + rise / 2.0, p.z), yaw, 3.6, "madeira_escura")
		var face_yaw := atan2(-x_axis.x, -x_axis.z)
		var face := p - x_axis * (dep * 0.5 + 0.03)
		for k in [-1, 0, 1]:
			for fl in floors:
				if _rng.randf() < 0.75:
					var lit := _rng.randf() < 0.34
					var wp: Vector3 = face + z_axis * k * w * 0.3 + Vector3(0, base + 1.9 + fl * 3.2, 0)
					if lit and d > 40.0:
						# longe: vira um ponto de luz redondo (como nas fotos das encostas)
						_hill_lights.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(1.1, 1.8)), wp - x_axis * 0.4))
					elif d < 70.0:
						b.quad("vidro_luz" if lit else "vidro_noite", Vector2(0.9, 1.3), wp, face_yaw)
		_spots.append(q)
		placed += 1
	for key: Vector2i in batches:
		_mesh_node(holder, "Bloco_%d_%d" % [key.x, key.y], (batches[key] as MeshBatch).commit())
	print("[vila] casas nos morros: ", placed)


## Árvores individuais (cenas) perto da rua: quintais, encostas próximas.
func _near_trees(root: Node3D) -> void:
	var trees := _group(root, "Arvores")
	var planted := 0
	var tries := 0
	while planted < 110 and tries < 1500:
		tries += 1
		var s := clampf(_rng.randf_range(-10.0, Route.length() + 30.0), 0.0, Route.length())
		var sigma := -1.0 if _rng.randf() < 0.5 else 1.0
		if absf(s - Route.BRIDGE_S) < 6.0:
			continue
		var d := _rng.randf_range(Route.width(s) * 0.5 + 14.0, 60.0)
		var p := Route.pos(s) + Route.right(s) * sigma * d
		var q := Vector2(p.x, p.z)
		if Route.dist_to_center(p) < Route.width(s) * 0.5 + 12.0:
			continue
		var blocked := false
		for o in _spots:
			if o.distance_to(q) < 8.5:
				blocked = true
				break
		if blocked:
			continue
		var r := _rng.randf()
		var key := "arvore_%d" % _rng.randi_range(0, 2)
		var sc := _rng.randf_range(1.0, 1.7)
		if r < 0.12:
			key = "palmeira"
			sc = _rng.randf_range(0.9, 1.2)
		elif r < 0.25:
			key = "bananeira"
			sc = _rng.randf_range(1.0, 1.5)
		elif r < 0.5:
			key = "arvore_pequena"
			sc = _rng.randf_range(1.0, 1.6)
		_plant(trees, key, Vector3(p.x, terrain_h(p.x, p.z) - 0.3, p.z), _rng.randf() * TAU, sc)
		planted += 1


## Mata das encostas e do fundo do vale. Perto da rua (até 60 m) cada árvore é um nó com 2 níveis de detalhe;
## o resto vai em MultiMesh por quadras de 64 m (só as quadras próximas são desenhadas), com o nível de detalhe simples.
func _forest() -> Node3D:
	var root := Node3D.new()
	root.name = "Mata"
	var esp: Array[String] = ["arvore_a", "arvore_b", "arvore_c", "palmeira"]
	var quadras := {}      # "ix,iz" -> [listas por espécie]
	var tries := 0
	var count := 0
	while count < 1700 and tries < 12000:
		tries += 1
		var x := _rng.randf_range(-290.0, 260.0)
		var z := _rng.randf_range(-540.0, 120.0)
		var nr := _nearest(x, z)
		if nr.y < Route.width(nr.x) * 0.5 + 20.0 or absf(nr.x - Route.BRIDGE_S) < 5.0:
			continue
		var q := Vector2(x, z)
		var blocked := false
		for o in _spots:
			if o.distance_squared_to(q) < 72.0:
				blocked = true
				break
		if blocked:
			continue
		var kind := 3 if _rng.randf() < 0.07 else _rng.randi_range(0, 2)
		var sc := _rng.randf_range(1.2, 2.2) if kind < 3 else _rng.randf_range(1.0, 1.4)
		var pos := Vector3(x, terrain_h(x, z) - 0.4, z)
		var yaw := _rng.randf() * TAU
		count += 1
		if nr.y < 60.0:
			var n := Arvores.no(esp[kind], sc)
			n.name = "%s_%03d" % [esp[kind], count]
			n.position = pos
			n.rotation.y = yaw
			root.add_child(n)
			continue
		var kq := "%d,%d" % [floori(x / 64.0), floori(z / 64.0)]
		if not quadras.has(kq):
			quadras[kq] = [[], [], [], []]
		((quadras[kq] as Array)[kind] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), pos))
	for kq: String in quadras:
		for k in 4:
			var xs: Array = (quadras[kq] as Array)[k]
			if xs.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = Arvores.malha(esp[k] + "_L1")
			mm.instance_count = xs.size()
			for i in xs.size():
				mm.set_instance_transform(i, xs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_q%s" % [esp[k], kq.replace(",", "_").replace("-", "m")]
			mmi.multimesh = mm
			mmi.visibility_range_end = 260.0
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mmi)
	return root


## Luzes distantes das encostas (milhares de pontos amarelos como nas fotos), em MultiMesh.
func _far_lights() -> MultiMeshInstance3D:
	var xforms: Array[Transform3D] = _hill_lights.duplicate()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "LuzesDistantes"
	mmi.multimesh = mm
	mmi.material_override = mat("luz_distante")
	mmi.visibility_range_end = 800.0
	return mmi


func _set_label_range(n: Node, end: float) -> void:
	for ch in n.find_children("*", "Label3D", true, false):
		(ch as Label3D).visibility_range_end = end


func _set_range(n: Node, end: float) -> void:
	for ch in n.get_children():
		if ch is GeometryInstance3D:
			var gi := ch as GeometryInstance3D
			if ch.has_meta("lod"):       # árvores com troca de detalhe: só encurta o alcance, sem mexer no limite da troca
				if gi.visibility_range_end <= 0.0 or end < gi.visibility_range_end:
					gi.visibility_range_end = end
			else:
				gi.visibility_range_end = end
		_set_range(ch, end)


## Tufos de capim em MultiMesh: bordas da rua, pés de muro e encostas.
## Silhueta distante da serra (anel de montanhas), sem névoa, contra o céu.
func _serra() -> Node3D:
	# três anéis de serra, de longe para perto: o mais distante é azulado e alto (névoa), o mais perto é escuro e esverdeado.
	# Cada anel tem cume "rugoso" (ruído em cristas), vales entre os picos e cor por vértice (mais clara no alto).
	var out := Node3D.new()
	out.name = "Serra"
	var center := Vector3(-5.0, 0, -170.0)
	var aneis := [
		{"r": 980.0, "h": 260.0, "amp": 150.0, "seed": 12, "topo": Color(0.085, 0.105, 0.17), "base": Color(0.05, 0.065, 0.11)},
		{"r": 790.0, "h": 190.0, "amp": 110.0, "seed": 31, "topo": Color(0.05, 0.068, 0.105), "base": Color(0.03, 0.044, 0.07)},
		{"r": 640.0, "h": 110.0, "amp": 70.0, "seed": 57, "topo": Color(0.03, 0.05, 0.05), "base": Color(0.018, 0.03, 0.032)},
	]
	var segs := 480
	for k in aneis.size():
		var A: Dictionary = aneis[k]
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.9
		noise.seed = int(A["seed"])
		noise.fractal_octaves = 4
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top: Array[Vector3] = []
		var bottom: Array[Vector3] = []
		var ctop: Color = A["topo"]
		var cbot: Color = A["base"]
		for i in segs + 1:
			var ii := float(i % segs)
			var a := TAU * ii / segs
			var n := noise.get_noise_1d(ii * 0.05)
			var crista := 1.0 - absf(noise.get_noise_1d(ii * 0.16 + 90.0)) * 2.0       # 1 = pico, -1 = vale
			var r: float = float(A["r"]) + n * 90.0
			var h: float = float(A["h"]) + n * float(A["amp"]) + crista * float(A["amp"]) * 0.45 + noise.get_noise_1d(ii * 0.7 + 50.0) * 18.0
			var dir := Vector3(cos(a), 0, sin(a))
			top.append(center + dir * r + Vector3(0, 10.0 + h, 0))
			bottom.append(center + dir * r + Vector3(0, -120.0, 0))
		for i in segs:
			var mid := (top[i] + bottom[i + 1]) * 0.5
			var inward := center - mid
			inward.y = 0
			var t0 := ctop * (0.8 + 0.4 * noise.get_noise_1d(float(i) * 0.4))
			var t1 := ctop * (0.8 + 0.4 * noise.get_noise_1d(float(i + 1) * 0.4))
			_tri_c(st, bottom[i], top[i], top[i + 1], cbot, t0, t1, inward)
			_tri_c(st, bottom[i], top[i + 1], bottom[i + 1], cbot, t1, cbot, inward)
		var mesh := st.commit()
		mesh.surface_set_material(0, mat("serra"))
		var mi := MeshInstance3D.new()
		mi.name = "Anel_%d" % k
		mi.mesh = _save_mesh(mesh, "serra_%d" % k)
		out.add_child(mi)
	return out


# ------------------------------------------------------------------ ponte e riacho

func _lot_ponte(parent: Node3D, f: Dictionary, sigma: float) -> void:
	var w: float = f["w"]
	var g := _group(parent, "Parapeito_%02d" % _n, f["xf"])
	_n += 1
	# o muro acompanha a subida da rua; os pilares das pontas ficam verticais, em grupos separados
	var slope := (Route.height(Route.BRIDGE_S + 1.0) - Route.height(Route.BRIDGE_S - 1.0)) / 2.0
	var ang := atan(sigma * slope)
	var tilted := _group(g, "Muro", Transform3D(Basis(Vector3.RIGHT, ang), Vector3.ZERO))
	# mureta baixa de pedra com GRADE de ferro aberta por cima: da ponte dá para ver e ouvir o riacho (antes o muro alto escondia a água)
	_box(tilted, "Corpo", Vector3(0.5, 1.2, w + 0.1), Vector3(0.25, -0.15, 0), "muro", false)
	_blocker(tilted, "ColisaoGrade", Vector3(0.4, 1.2, w), Vector3(0.25, 0.55, 0))
	var b := _batch()
	b.box("cantaria", Vector3(0.8, 0.12, w + 0.2), Vector3(0.25, 0.51, 0))
	b.box("ferro", Vector3(0.07, 0.07, w), Vector3(0.25, 1.12, 0))
	b.box("ferro", Vector3(0.05, 0.05, w), Vector3(0.25, 0.78, 0))
	var nposts := int(w / 0.8)
	for k in nposts + 1:
		var pz := -w / 2.0 + w * float(k) / float(nposts)
		b.box("ferro", Vector3(0.05, 0.56, 0.05), Vector3(0.25, 0.85, pz))
		b.sphere("ferro", 0.045, Vector3(0.25, 1.17, pz), 6, 4)
	_mesh_node(tilted, "Capa", b.commit())
	_box(tilted, "FaceDaPonte", Vector3(0.5, 4.6, w + 0.1), Vector3(0.25, -3.05, 0), "muro")
	var pb := _batch()
	for end: float in [-1.0, 1.0]:
		var dy: float = tan(ang) * end * (w / 2.0 - 0.1)          # altura do chão naquela ponta
		pb.box("cantaria", Vector3(0.70, 1.55, 0.55), Vector3(0.2, 0.62 + dy, end * (w / 2.0 - 0.1)))
		pb.box("cantaria", Vector3(0.82, 0.14, 0.67), Vector3(0.2, 1.46 + dy, end * (w / 2.0 - 0.1)))
		pb.sphere("cantaria", 0.17, Vector3(0.2, 1.68 + dy, end * (w / 2.0 - 0.1)), 7, 4)
	_mesh_node(g, "Pilares", pb.commit())
	for end: float in [-1.0, 1.0]:                                           # lampião aceso em cada pilar: a água embaixo aparece
		var dy2: float = tan(ang) * end * (w / 2.0 - 0.1)
		var lan := _prop(g, "Lantern_01", Vector3(0.2, 1.78 + dy2, end * (w / 2.0 - 0.1)), _rng.randf() * TAU, 1.0)
		_lamp_light(lan, Vector3(0, 0.13, 0), 0.9).omni_range = 9.0
		_halo(lan, Vector3(0, 0.13, 0), 1.0, "halo_vela")


## Cachoeira do riacho: degrau de pedra, cortina d'água com listras que descem, espuma e névoa no poço, rochas dos lados e luz fria.
func _cachoeira(g: Node3D, c: Vector3, r: Vector3, xf_g: Transform3D, hw: float) -> void:
	var queda := Node3D.new()
	queda.name = "Cachoeira"
	g.add_child(queda)
	var lat := Vector3(-r.z, 0, r.x)
	var y_alto := c.y - 3.0 + RIO_DECLIVE * (RIO_QUEDA_T - 8.0) + RIO_QUEDA_H
	var y_baixo := c.y - 3.0 + RIO_DECLIVE * (RIO_QUEDA_T - 1.6 - 8.0)
	var t0 := RIO_QUEDA_T - 1.6
	# cortina: faixa de 7 colunas, levemente abaulada e mais larga embaixo
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 8
	var rows := 6
	for ri in rows:
		for ci in cols:
			for tri in [[0, 0], [1, 0], [0, 1], [1, 0], [1, 1], [0, 1]]:
				var u := float(ci + tri[0]) / float(cols)
				var v := float(ri + tri[1]) / float(rows)
				var tv := lerpf(RIO_QUEDA_T, t0 - 0.35, v) + sin(v * PI) * 0.18       # cai quase na vertical, com barriga
				var wy := lerpf(y_alto, y_baixo - 0.05, v)
				var lw := lerpf(hw * 0.9, hw * 1.05, v) * (u * 2.0 - 1.0)
				var wp := c + r * tv + lat * lw
				st.set_uv(Vector2(u, v))
				st.set_normal(-r)
				st.add_vertex(xf_g.affine_inverse() * Vector3(wp.x, wy, wp.z))
	var cort := MeshInstance3D.new()
	cort.name = "Cortina"
	cort.mesh = st.commit()
	cort.material_override = mat("cachoeira")
	cort.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	queda.add_child(cort)
	# espuma no poço (mancha branca macia sobre a água) e névoa subindo
	var fq := QuadMesh.new()
	fq.size = Vector2(hw * 2.2, 4.0)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_texture = load("res://assets/textures/ponto_luz.png")
	fm.albedo_color = Color(0.75, 0.88, 0.95, 0.9)
	fm.disable_fog = true
	var foam := MeshInstance3D.new()
	foam.name = "EspumaDoPoco"
	foam.mesh = fq
	foam.material_override = fm
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fp := c + r * (t0 - 1.2)
	foam.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), xf_g.affine_inverse() * Vector3(fp.x, y_baixo + 0.06, fp.z))
	foam.basis = Basis.from_euler(Vector3(-PI / 2.0, 0, PI / 2.0))
	queda.add_child(foam)
	var neblina := Realismo.fumaca(xf_g.affine_inverse() * Vector3(fp.x, y_baixo + 0.2, fp.z))
	neblina.name = "Neblina"
	neblina.amount = 18
	neblina.lifetime = 3.5
	(neblina.process_material as ParticleProcessMaterial).gravity = Vector3(0, 0.25, 0)
	(neblina.process_material as ParticleProcessMaterial).direction = Vector3(0, 1, 0)
	(neblina.process_material as ParticleProcessMaterial).initial_velocity_min = 0.25
	(neblina.process_material as ParticleProcessMaterial).initial_velocity_max = 0.6
	queda.add_child(neblina)
	# rochas: borda do degrau e laterais (malha facetada de verdade)
	var det := Detalhes.new()
	det.b = self
	var meshes: Array[Mesh] = []
	for v in 3:
		meshes.append(det._malha_pedra(70 + v * 13, 0.7 + 0.1 * v))
	for k in 16:
		var side := -1.0 if k % 2 == 0 else 1.0
		var tv := RIO_QUEDA_T + _rng.randf_range(-3.2, 1.6)
		var out_w := hw * _rng.randf_range(0.85, 1.35)
		var ry := lerpf(y_baixo, y_alto, clampf((tv - t0) / 1.6, 0.0, 1.0)) if tv < RIO_QUEDA_T else y_alto
		var sz := _rng.randf_range(0.9, 2.1)
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[_rng.randi() % 3]
		mi.name = "RochaQueda_%02d" % k
		var wp2 := c + r * tv + lat * out_w * side
		mi.transform = Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3))).scaled(Vector3(sz, sz * 1.1, sz)), xf_g.affine_inverse() * Vector3(wp2.x, ry + sz * 0.15 - 0.2, wp2.z))
		mi.visibility_range_end = 160.0
		queda.add_child(mi)
	# parede de pedra atrás do degrau (esconde o corte do terreno) e lábio onde a água cai
	var lab := _batch()
	var lp := xf_g.affine_inverse() * (c + r * (RIO_QUEDA_T + 1.35))
	lab.box("muro", Vector3(2.4, RIO_QUEDA_H + 0.6, hw * 2.3), Vector3(lp.x, y_baixo + RIO_QUEDA_H * 0.5 - 0.1, lp.z))
	_mesh_node(queda, "ParedeDeDegrau", lab.commit())
	var luz := OmniLight3D.new()
	luz.name = "LuzFria"
	var lq := xf_g.affine_inverse() * (c + r * (t0 - 1.5))
	luz.position = Vector3(lq.x, y_baixo + 1.6, lq.z)
	luz.light_color = Color(0.55, 0.75, 1.0)
	luz.light_energy = 0.9
	luz.omni_range = 11.0
	luz.distance_fade_enabled = true
	luz.distance_fade_begin = 55.0
	luz.distance_fade_length = 15.0
	queda.add_child(luz)


func _bridge(root: Node3D) -> void:
	var s := Route.BRIDGE_S
	var c := Route.pos(s)
	var r := Route.right(s)
	var g := _group(root, "Ponte", Transform3D(Basis(r, Vector3.UP, r.cross(Vector3.UP)), c))
	var width := Route.width(s) + 2.0 * SW
	var slope := (Route.height(s + 1.0) - Route.height(s - 1.0)) / 2.0
	var laje := _box(g, "Laje", Vector3(width + 0.4, 1.0, Route.BRIDGE_HALF * 2.0 + 0.6), Vector3(0, -0.85, 0), "muro")
	laje.rotation.x = atan(slope)
	# riacho: faixa d'água com shader (correnteza, espuma nas margens e nas pedras, reflexo do céu), cruzando a rua
	var xf_g := Transform3D(Basis(r, Vector3.UP, r.cross(Vector3.UP)), c)
	var hw := 4.6                 # meia-largura da faixa d'água (a margem do vale corta o excesso)
	var queda_t := RIO_QUEDA_T
	# trecho de baixo (da ponte até o pé da cachoeira), trecho de cima (acima do degrau) e a cortina d'água entre os dois
	var lo_ts: Array[float] = []
	var hi_ts: Array[float] = []
	var tt0 := -96.0
	while tt0 < queda_t - 1.6:
		lo_ts.append(tt0)
		tt0 += 4.0
	lo_ts.append(queda_t - 1.6)
	hi_ts.append(queda_t)
	tt0 = queda_t + 4.0
	while tt0 <= 96.0:
		hi_ts.append(tt0)
		tt0 += 4.0
	for parte in [["Riacho", lo_ts], ["RiachoAlto", hi_ts]]:
		var tl_list: Array = parte[1]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var along := 0.0
		var vs: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for i in tl_list.size():
			var tv: float = tl_list[i]
			var wy := c.y - 3.0 + RIO_DECLIVE * maxf(absf(tv) - 8.0, 0.0) + (RIO_QUEDA_H if tv >= queda_t else 0.0)
			if i > 0:
				along += absf(tv - float(tl_list[i - 1]))
			for sd: float in [-1.0, 1.0]:
				var wp := c + r * tv + Vector3(-r.z, 0, r.x) * hw * sd
				vs.append(xf_g.affine_inverse() * Vector3(wp.x, wy, wp.z))
				uvs.append(Vector2(along, hw * sd))
		for i in tl_list.size() - 1:
			var a0 := i * 2
			for k in [0, 2, 1, 1, 2, 3]:
				st.set_uv(uvs[a0 + k])
				st.set_normal(Vector3.UP)
				st.add_vertex(vs[a0 + k])
		var water := MeshInstance3D.new()
		water.name = parte[0]
		water.mesh = st.commit()
		g.add_child(water)
		water.material_override = mat("agua")
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cachoeira(g, c, r, xf_g, hw)
	# pedras do leito e das margens (malha facetada de verdade, não esferas), metade dentro d'água
	var det := Detalhes.new()
	det.b = self
	var meshes: Array[Mesh] = []
	for v in 3:
		meshes.append(det._malha_pedra(40 + v * 11, 0.55 + 0.1 * v))
	var pedras := Node3D.new()
	pedras.name = "PedrasDoLeito"
	g.add_child(pedras)
	var np := 0
	var tries := 0
	while np < 46 and tries < 400:
		tries += 1
		var u := _rng.randf_range(-55.0, 55.0)
		if absf(u) < width * 0.5 + 0.8:
			continue
		var zc := _rng.randf_range(-3.3, 3.3)
		var wpr := c + r * u - Route.tangent(s) * zc
		var hy := terrain_h(wpr.x, wpr.z) - c.y
		if hy > -2.0 or hy < -4.6:           # só onde o leito está perto da linha d'água
			continue
		var sz := _rng.randf_range(0.3, 1.1)
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[_rng.randi() % 3]
		mi.name = "Pedra_%02d" % np
		mi.transform = Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3))).scaled(Vector3(sz, sz, sz * _rng.randf_range(0.8, 1.3))), Vector3(u, hy + sz * 0.1, zc))
		mi.visibility_range_end = 140.0
		pedras.add_child(mi)
		np += 1
	# vegetação de beira de rio: capim, samambaia, taboas e mato real junto à água
	var beira := ["capim", "samambaia", "arbusto", "capim", "samambaia"]
	var nv := 0
	tries = 0
	while nv < 150 and tries < 1800:
		tries += 1
		var u2 := _rng.randf_range(-48.0, 48.0)
		if absf(u2) < width * 0.5 + 1.2:
			continue
		var zc2 := _rng.randf_range(-6.0, 6.0)
		var wp2 := c + r * u2 - Route.tangent(s) * zc2
		var h2 := terrain_h(wp2.x, wp2.z) - c.y
		if h2 < -3.05 or h2 > -1.4:          # da linha d'água até ~1,6 m acima
			continue
		var kv: String = beira[_rng.randi() % beira.size()]
		if absf(zc2) > 4.3 and h2 > -2.4 and _rng.randf() < 0.22:
			kv = "bananeira" if _rng.randf() < 0.5 else "arvore_pequena"
		_plant(g, kv, Vector3(u2, h2 - 0.08, zc2), _rng.randf() * TAU, _rng.randf_range(0.9, 1.7))
		nv += 1


# ------------------------------------------------------------------ adornos de rua e nichos

func _street_point(sigma: float, s: float, inset: float) -> Vector3:
	return Route.pos(s) + Route.right(s) * sigma * (Route.width(s) * 0.5 - inset) + Vector3(0, 0.03, 0)


## Um recipiente do kit "Medieval Containers" (CC0) pelo prefixo do nome ("Barrel1", "Crate3"...), com colisão simples.
func _cont(parent: Node, prefixo: String, pos: Vector3, yaw := 0.0, scale := 1.0, colide := true) -> Node3D:
	var nomes: Array = []
	for nm in PropKit.cont_nomes():
		if nm.begins_with(prefixo + "_"):
			nomes.append(nm)
	if nomes.is_empty():
		return null
	var nome: String = nomes[_rng.randi() % nomes.size()]
	var h := PropKit.make_cont(nome, scale)
	h.name = "%s_%03d" % [nome, _n]
	_n += 1
	h.position = pos
	h.rotation.y = yaw
	parent.add_child(h)
	if colide:
		var bb: AABB = h.get_meta("bb")
		var redondo := prefixo.begins_with("Barrel") or prefixo.begins_with("Basket1") or prefixo.begins_with("Bucket") or prefixo.begins_with("Jug") or prefixo.begins_with("Bowl")
		_prop_collision(h, "cil" if redondo else "caixa", bb.size, bb.get_center())
	return h


## Grupo de recipientes encostado na parede: barril, pilha de caixotes, cestos, jarros, sacos...
func _recipientes(parent: Node, p: Vector3, yaw: float) -> void:
	var r := _rng.randf()
	if r < 0.22:
		var barril := _prop(parent, "wine_barrel_01", p, _rng.randf() * TAU, _rng.randf_range(0.95, 1.1))
		_prop_collision(barril, "cil", Vector3(0.72, 0.85, 0.72), Vector3(0, 0.43, 0))
	elif r < 0.38:
		_cont(parent, "Barrel1", p, _rng.randf() * TAU)
	elif r < 0.62:
		var c1 := _cont(parent, "Crate3", p, yaw + _rng.randf_range(-0.3, 0.3))
		if c1 != null and _rng.randf() < 0.55:
			var top := (c1.get_meta("bb") as AABB).size.y
			_cont(parent, "Crate3", p + Vector3(0, top, 0), yaw + _rng.randf_range(-0.5, 0.5), 0.9, false)
	elif r < 0.74:
		_cont(parent, "Crate1" if _rng.randf() < 0.6 else "Crate2", p, yaw + PI / 2.0 + _rng.randf_range(-0.15, 0.15))      # lado comprido junto à parede
	elif r < 0.84:
		_cont(parent, "Basket1" if _rng.randf() < 0.6 else "Basket2", p, _rng.randf() * TAU)
		if _rng.randf() < 0.5:
			_cont(parent, "Basket1", p + Basis(Vector3.UP, yaw) * Vector3(0.85, 0, 0), _rng.randf() * TAU)
	elif r < 0.93:
		var desl: Array = [Vector3(0, 0, 0), Vector3(0.55, 0, 0), Vector3(-0.55, 0, 0)]      # ao longo da parede, afastados: não invadem a rua nem se atravessam
		for k in _rng.randi_range(1, 3):
			_cont(parent, "Jug1" if _rng.randf() < 0.5 else "Jug2", p + Basis(Vector3.UP, yaw) * (desl[k] as Vector3), _rng.randf() * TAU)
	else:
		_cont(parent, "Sack1" if _rng.randf() < 0.5 else "Sack2", p, _rng.randf() * TAU)
		_cont(parent, "Bucket1", p + Basis(Vector3.UP, yaw) * Vector3(0.55, 0, 0), _rng.randf() * TAU)


## Bueiros, barris, caixotes, bancos, carroça, varais e bandeirinhas.
## Remove caixote/barril/escada que ficou com o corpo dentro de uma casa (a casa pode avançar um pouco sobre a calçada).
func _tira_props_dentro_das_casas(root: Node3D) -> void:
	var tirados := 0
	for gname in ["Adornos", "Props"]:
		var g := root.get_node_or_null(gname)
		if g == null:
			continue
		for n in g.get_children().duplicate():
			if not (n is Node3D) or not n.has_meta("bb"):
				continue
			var bb: AABB = n.get_meta("bb")
			var pos: Vector3 = (n as Node3D).position
			var r := maxf(bb.size.x, bb.size.z) * 0.5 * (n as Node3D).scale.x
			for o in _casas_postas:
				var q: Vector3 = (o["xf"] as Transform3D).affine_inverse() * pos
				if q.x > -r * 1.0 - 0.12 and q.x < float(o["depth"]) and absf(q.z) < float(o["w"]) * 0.5 + r * 0.5:
					g.remove_child(n)
					n.free()
					tirados += 1
					break
	print("[vila] props removidos por estarem dentro de casas: ", tirados)


func _adornos() -> Node3D:
	var root := Node3D.new()
	root.name = "Adornos"
	var b := _batch()
	for s: float in [14.0, 62.0, 128.0, 170.0, 216.0, 262.0, 300.0, 330.0]:
		var p := _street_point(1.0 if int(s) % 2 == 0 else -1.0, s, 1.4)
		b.cylinder("cantaria", 0.46, 0.46, 0.04, p + Vector3(0, 0.0, 0), Vector3.ZERO, 14)
		b.cylinder("ferro", 0.36, 0.36, 0.05, p + Vector3(0, 0.02, 0), Vector3.ZERO, 14)
		for k in 4:
			b.box("cantaria", Vector3(0.5, 0.02, 0.03), p + Vector3(0, 0.05, 0), Vector3(0, k * PI / 4.0, 0))
	# lugares dos carros cobertos (colocados depois, em _props_rua): nada se sobrepõe a eles
	for cfg in [[153.0, -1.0], [S_END + 22.0, 1.0]]:
		var cs0: float = _s_sem_porta(float(cfg[1]), float(cfg[0]), 0.5, 3.4)      # o carro não pode ficar na frente de uma porta
		_carros_s[int(cfg[0])] = cs0
		_reservar(Route.pos(cs0) + Route.right(cs0) * float(cfg[1]) * (Route.width(cs0) * 0.5 - 1.25), 3.0)
	# querosene e diários: o lugar deles (e a frente, de onde o jogador olha) fica livre de barris e caixotes
	for o in OIL_PTS:
		var so: float = o[0]
		_reservar(facade(float(o[1]), so) - Route.right(so) * float(o[1]) * 0.35 + Vector3(0, SW_H, 0), 1.5)
	for n in NOTE_PTS:
		var sn: float = n[0]
		_reservar(facade(float(n[1]), sn) - Route.right(sn) * float(n[1]) * 0.4 + Vector3(0, SW_H, 0), 1.5)
	# lugar do bar da TV (barril + TV + banquinhos): reservado antes dos barris e caixotes, para nada ficar dentro dele
	_bar_spot = _spot_livre(-1.0, 148.5, 0.55, 1.4)
	if _bar_spot.is_empty():
		_bar_spot = _spot(-1.0, 148.5, 0.55)
	_reservar(_bar_spot["pos"], 1.4)
	# barris e caixotes junto às paredes
	var count := 0
	var tries := 0
	while count < 80 and tries < 700:
		tries += 1
		var s := _rng.randf_range(10.0, S_END - 8.0)
		if absf(s - Route.BRIDGE_S) < 8.0 or Route.width(s) < 4.4:
			continue
		var sigma := -1.0 if _rng.randf() < 0.5 else 1.0
		var base := facade(sigma, s) - Route.right(s) * sigma * 0.4 + Vector3(0, SW_H, 0)
		var out := -Route.right(s) * sigma
		var p := base + out * 0.22        # junto à parede, sem entrar nela: o meio da rua (corredor de 2,2 m) fica livre
		if not _livre(p, 0.95, true) or Route.dist_to_center(p) < 2.3:      # cestos e jarros saem até 0,7 m do ponto
			continue
		_reservar(p, 0.95)
		_recipientes(root, p, atan2(out.x, out.z))
		count += 1
	# bancos no largo
	for bs: float in [146.0, 156.0, 170.0]:
		var sg := -1.0
		var bp := facade(sg, bs) - Route.right(bs) * sg * 0.0 + Route.right(bs) * sg * 0.0
		var out := -Route.right(bs) * sg
		var pos := bp + out * 0.5 + Vector3(0, SW_H, 0)
		var yaw := atan2(-out.z, out.x) + PI / 2.0
		var basis := Basis(Vector3.UP, yaw)
		b.box("madeira_natural", Vector3(1.7, 0.07, 0.45), pos + basis * Vector3(0, 0.46, 0), Vector3(0, yaw, 0))
		b.box("madeira_natural", Vector3(1.7, 0.4, 0.06), pos + basis * Vector3(0, 0.72, 0.2), Vector3(0, yaw, 0))
		for lx: float in [-0.7, 0.7]:
			b.box("cantaria", Vector3(0.12, 0.44, 0.4), pos + basis * Vector3(lx, 0.22, 0), Vector3(0, yaw, 0))
	# carroça de mão
	var cs := 174.0
	var cp := facade(-1.0, cs) + Route.right(cs) * 0.9 + Vector3(0, SW_H, 0)
	var ct := Route.tangent(cs)
	var cyaw := atan2(-ct.z, ct.x)
	var cb := Basis(Vector3.UP, cyaw)
	b.box("madeira_natural", Vector3(1.6, 0.08, 0.95), cp + cb * Vector3(0, 0.62, 0), Vector3(0, cyaw, 0))
	for sz: float in [-1.0, 1.0]:
		b.box("madeira_natural", Vector3(1.6, 0.3, 0.05), cp + cb * Vector3(0, 0.8, sz * 0.47), Vector3(0, cyaw, 0))
		b.cylinder("madeira_natural", 0.38, 0.38, 0.07, cp + cb * Vector3(0, 0.38, sz * 0.52), Vector3(PI / 2.0, cyaw, 0), 12)
		b.cylinder("ferro", 0.39, 0.39, 0.05, cp + cb * Vector3(0, 0.38, sz * 0.52), Vector3(PI / 2.0, cyaw, 0), 12)
	b.box("madeira_natural", Vector3(1.2, 0.05, 0.05), cp + cb * Vector3(-1.3, 0.55, 0.3), Vector3(0, cyaw, 0))
	b.box("madeira_natural", Vector3(1.2, 0.05, 0.05), cp + cb * Vector3(-1.3, 0.55, -0.3), Vector3(0, cyaw, 0))
	_mesh_node(root, "Pecas", b.commit())
	return root


func _lines() -> Node3D:
	var root := Node3D.new()
	root.name = "Varais"
	var b := _batch()
	var flags := ["bandeira_a", "bandeira_b", "bandeira_c", "bandeira_d"]
	var cloths := ["pano", "pano_azul", "pano_rosa", "pano_cru"]
	for spec in [[58.0, "varal"], [234.0, "varal"], [190.0, "bandeirinha"], [270.0, "bandeirinha"]]:
		var s: float = spec[0]
		var hgt := 4.4 if spec[1] == "varal" else 5.6
		var a := facade(-1.0, s) + Vector3(0, SW_H + hgt, 0)
		var c := facade(1.0, s) + Vector3(0, SW_H + hgt, 0)
		var n := int(a.distance_to(c) / 0.5)
		var prev := a
		var dirv := (c - a)
		dirv.y = 0
		var lat := dirv.normalized()
		for k in range(1, n + 1):
			var t := float(k) / n
			var pt := a.lerp(c, t)
			pt.y -= sin(t * PI) * 0.7
			var seg := pt - prev
			b.box("ferro", Vector3(seg.length() + 0.02, 0.012, 0.012), (prev + pt) * 0.5, Vector3(0, atan2(-seg.z, seg.x), atan2(seg.y, Vector2(seg.x, seg.z).length())))
			if spec[1] == "bandeirinha":
				var m: String = flags[k % flags.size()]
				b.tri2(m, prev, pt, (prev + pt) * 0.5 + Vector3(0, -0.30, 0))
			prev = pt
		if spec[1] == "varal":
			# peças penduradas: pano largo com dobras verticais, preso por prendedores de madeira
			for k in 4:
				var t2 := (k + 1.0) / 5.0
				var top := a.lerp(c, t2)
				top.y -= sin(t2 * PI) * 0.7
				var wdt := _rng.randf_range(0.9, 1.25)
				var hh := _rng.randf_range(1.05, 1.5)
				var m2: String = cloths[_rng.randi() % cloths.size()]
				var cols := 8
				var rows := 3
				for ci in cols:
					for ri in rows:
						var u0 := float(ci) / cols
						var u1 := float(ci + 1) / cols
						var v0 := float(ri) / rows
						var v1 := float(ri + 1) / rows
						var fold := func(u: float, v: float) -> Vector3:
							var x := (u - 0.5) * wdt
							var drop := v * hh + sin(u * PI * 1.0) * 0.03 * v    # barra levemente curva
							var depth := sin(u * TAU * 2.0 + float(k)) * 0.045 * (0.3 + v)   # dobras
							return top + lat * x + Vector3(0, -drop, 0) + lat.cross(Vector3.UP) * depth
						var p00: Vector3 = fold.call(u0, v0)
						var p10: Vector3 = fold.call(u1, v0)
						var p01: Vector3 = fold.call(u0, v1)
						var p11: Vector3 = fold.call(u1, v1)
						b.tri2(m2, p00, p10, p11)
						b.tri2(m2, p00, p11, p01)
				for ex: float in [-0.5, 0.5]:
					b.box("madeira_natural", Vector3(0.03, 0.10, 0.03), top + lat * ex * wdt + Vector3(0, 0.0, 0))
	_mesh_node(root, "Fios", b.commit())
	return root


func _nichos() -> Node3D:
	var root := Node3D.new()
	root.name = "Nichos"
	var picked := 0
	var last_s := -100.0
	for j in _joints:
		var s: float = j["s"]
		if s < 20.0 or s > S_END - 10.0 or s - last_s < 38.0:
			continue
		if absf(s - Route.BRIDGE_S) < 12.0:
			continue
		var sigma: float = j["sigma"]
		var x_axis := Route.right(s) * sigma
		var origin := facade(sigma, s) + Vector3(0, SW_H, 0)
		var g := _group(root, "Nicho_%03d" % int(s), Transform3D(Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)), origin))
		var b := _batch()
		# oratório: mísula, corpo com arco, frontão com cruz, santo e velas
		b.box("cantaria", Vector3(0.50, 0.16, 0.86), Vector3(-0.10, 1.50, 0))                       # mísula
		b.box("cantaria", Vector3(0.40, 0.22, 0.74), Vector3(-0.10, 1.35, 0))
		b.box("cantaria", Vector3(0.34, 1.50, 0.80), Vector3(-0.05, 2.30, 0))                       # corpo
		b.box("janela_escura", Vector3(0.06, 0.95, 0.52), Vector3(-0.22, 2.12, 0))                  # vão
		b.half_disc("janela_escura", Vector3(-0.22, 2.60, 0), 0.26, 10)
		b.arch("cantaria", Vector3(-0.21, 2.60, 0), 0.30, 0.08, 0.10, 9)                             # arco de pedra
		b.box("cantaria", Vector3(0.10, 0.96, 0.08), Vector3(-0.21, 2.12, -0.30))
		b.box("cantaria", Vector3(0.10, 0.96, 0.08), Vector3(-0.21, 2.12, 0.30))
		b.cylinder("cantaria", 0.075, 0.10, 0.50, Vector3(-0.24, 1.98, 0), Vector3.ZERO, 8)          # imagem do santo
		b.sphere("cantaria", 0.075, Vector3(-0.24, 2.32, 0), 7, 4)
		b.box("cantaria", Vector3(0.60, 0.12, 1.00), Vector3(-0.05, 3.10, 0))                        # cornija
		b.prism("cantaria", Vector3(0.50, 0.30, 0.96), Vector3(-0.04, 3.31, 0))                       # frontão
		b.box("ferro", Vector3(0.035, 0.36, 0.035), Vector3(-0.04, 3.62, 0))                         # cruz
		b.box("ferro", Vector3(0.035, 0.035, 0.20), Vector3(-0.04, 3.70, 0))
		b.box("ferro", Vector3(0.30, 0.03, 0.62), Vector3(-0.30, 1.62, 0))                           # grade-prateleira
		for sz: float in [-0.20, 0.20]:
			b.box("vela", Vector3(0.05, 0.14, 0.05), Vector3(-0.30, 1.71, sz))
			b.box("chama", Vector3(0.035, 0.065, 0.035), Vector3(-0.30, 1.82, sz))
		_mesh_node(g, "Malha", b.commit())
		var l := OmniLight3D.new()
		l.name = "LuzDaVela"
		l.position = Vector3(-0.55, 1.95, 0)
		l.light_color = Color(1.0, 0.62, 0.28)
		l.light_energy = 0.9
		l.omni_range = 4.5
		l.distance_fade_enabled = true
		l.distance_fade_begin = 35.0
		l.distance_fade_length = 10.0
		l.set_script(load("res://scripts/luz_tremula.gd"))
		l.set("forca", 0.3)
		l.set("velocidade", 9.0)
		g.add_child(l)
		_halo(g, Vector3(-0.34, 1.85, 0), 0.9, "halo_vela")
		last_s = s
		picked += 1
	print("[vila] nichos: ", picked)
	return root


func _haunted_window(parent: Node3D, pos: Vector3) -> void:
	var g := _group(parent, "JanelaAssombrada", Transform3D(Basis.IDENTITY, pos))
	g.set_script(load("res://scripts/janela_assombrada.gd"))
	g.add_to_group("assombradas", true)
	var glass := QuadMesh.new()
	glass.size = Vector2(1.0, 1.7)
	var gm := _mesh_node(g, "Vidro", glass)
	gm.material_override = mat("janela_acesa")
	gm.rotation.y = -PI / 2.0
	var fig := QuadMesh.new()
	fig.size = Vector2(0.5, 1.0)
	var fm := _mesh_node(g, "Vulto", fig, Vector3(-0.01, -0.28, 0))
	fm.material_override = mat("vulto")
	fm.rotation.y = -PI / 2.0
	var l := OmniLight3D.new()
	l.name = "Luz"
	l.position = Vector3(-0.7, 0, 0)
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 0.8
	l.omni_range = 6.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 10.0
	g.add_child(l)


# ------------------------------------------------------------------ itens: óleo e bilhetes

func _brilho(parent: Node3D, y: float, size: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := _mesh_node(parent, "Brilho", q, Vector3(0, y, 0))
	mi.material_override = mat("luz_distante")


func _coletavel(parent: Node3D, node_name: String, pos: Vector3, tipo: String, nota_id: int, label: String) -> void:
	var a := Area3D.new()
	a.name = node_name
	a.position = pos
	a.set_script(load("res://scripts/coletavel.gd"))
	a.set("tipo", tipo)
	a.set("nota_id", nota_id)
	a.set("texto_interacao", label)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 1.3, 0.9)
	cs.shape = bs
	cs.position = Vector3(0, 0.6, 0)
	a.add_child(cs)
	var b := _batch()
	if tipo == "oleo":
		b.cylinder("vidro_oleo", 0.075, 0.085, 0.20, Vector3(0, 0.10, 0), Vector3.ZERO, 10)       # bojo
		b.sphere("vidro_oleo", 0.085, Vector3(0, 0.20, 0), 8, 4)
		b.cylinder("vidro_oleo", 0.032, 0.032, 0.12, Vector3(0, 0.30, 0), Vector3.ZERO, 8)        # gargalo
		b.cylinder("madeira_natural", 0.04, 0.036, 0.05, Vector3(0, 0.38, 0), Vector3.ZERO, 8)    # rolha
		_halo(a, Vector3(0, 0.22, 0), 0.7, "halo_vela")
	else:
		var dia := _prop(a, "binder_notebook", Vector3.ZERO, _rng.randf_range(-0.8, 0.8), 0.85)
		dia.name = "Diario"
		_brilho(a, 0.2, 0.45)
	_mesh_node(a, "Malha", b.commit())
	parent.add_child(a)


const OIL_PTS := [[26.0, 1.0], [70.0, -1.0], [108.0, 1.0], [150.0, 1.0], [171.0, -1.0], [205.0, 1.0], [240.0, -1.0], [262.0, -1.0], [290.0, 1.0], [320.0, 1.0], [345.0, -1.0]]
const NOTE_PTS := [[8.0, 1.0, 0], [76.0, -1.0, 1], [141.0, -1.0, 2], [210.0, 1.0, 3], [268.0, -1.0, 4], [340.0, 1.0, 5]]


func _coletaveis() -> Node3D:
	var root := Node3D.new()
	root.name = "Coletaveis"
	var oil_pts := OIL_PTS
	var i := 0
	for o in oil_pts:
		var s: float = o[0]
		var sigma: float = o[1]
		var p := facade(sigma, s) - Route.right(s) * sigma * 0.35 + Vector3(0, SW_H, 0)
		_coletavel(root, "Oleo_%02d" % i, p, "oleo", 0, "Pegar querosene")
		i += 1
	var notes := NOTE_PTS
	for n in notes:
		var s: float = n[0]
		var sigma: float = n[1]
		var p := facade(sigma, s) - Route.right(s) * sigma * 0.4 + Vector3(0, SW_H, 0)
		_coletavel(root, "Bilhete_%d" % int(n[2]), p, "nota", int(n[2]), "Ler diário")
	return root


# ------------------------------------------------------------------ modelos reais (Poly Haven, CC0)

## Instancia um modelo .glb em `pos` (pés no chão), girado para a frente (+Z do modelo) apontar para `yaw`.
func _prop(parent: Node, key: String, pos: Vector3, yaw := 0.0, scale := 1.0, align := "chao") -> Node3D:
	var p := PropKit.make(key, scale, align)
	p.name = "%s_%03d" % [key, _n]
	_n += 1
	p.position = pos
	p.rotation.y = yaw
	parent.add_child(p)
	return p


## Colisão de cilindro solta (poste, tronco): devolve um StaticBody3D na posição `pos` (mundo).
func _prop_collision_node(pos: Vector3, diametro: float, altura: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ColisaoPoste"
	body.position = pos + Vector3(0, altura * 0.5, 0)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = diametro * 0.5
	cy.height = altura
	cs.shape = cy
	body.add_child(cs)
	return body


## Colisão simples para um prop: "cil" (cilindro: size.x = diâmetro, size.y = altura) ou "caixa".
func _prop_collision(p: Node3D, kind: String, size: Vector3, off := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = "Colisao"
	body.position = off
	var cs := CollisionShape3D.new()
	if kind == "cil":
		var cy := CylinderShape3D.new()
		cy.radius = size.x * 0.5
		cy.height = size.y
		cs.shape = cy
	else:
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
	body.add_child(cs)
	p.add_child(body)


## Ponto na calçada a `d` m da fachada (para a rua) e a direção "para fora" e ao longo da rua.
## `p` (na fachada) cai sobre a parede de alguma casa, com folga `folga` das quinas?
func _parede_de_casa(p: Vector3, folga: float) -> bool:
	for o in _casas_postas:
		var xf: Transform3D = o["xf"]
		var q: Vector3 = xf.affine_inverse() * p
		if absf(q.x) < 0.45 and absf(q.z) < float(o["w"]) * 0.5 - folga:
			return true
	return false


## Há porta de casa a menos de `r` m de `p` (no plano)?
func _perto_de_porta(p: Vector3, r: float) -> bool:
	for q in _portas:
		if Vector2(p.x - q.x, p.z - q.z).length() < r:
			return true
	return false


## `s` deslocado ao longo da rua até o ponto não ficar na frente de uma porta.
func _s_sem_porta(sigma: float, s: float, d: float, r := 1.9) -> float:
	for off: float in [0.0, 1.8, -1.8, 3.6, -3.6, 5.4, -5.4]:
		var p := facade(sigma, s + off) - Route.right(s + off) * sigma * d
		if not _perto_de_porta(p, r):
			return s + off
	return s


## Como _spot, mas só devolve um lugar que esteja livre (raio `r`): tenta deslocar ao longo da rua; vazio se não houver.
## `p` cai dentro da água do riacho (faixa da água, de uma ponta à outra) com folga `folga`?
func no_rio(p: Vector3, folga: float) -> bool:
	if not _rio_ok:
		return false
	var d := Vector2(p.x - _rio_c.x, p.z - _rio_c.z)
	var dw := absf(d.x * _rio_t.x + d.y * _rio_t.z)
	var tl := absf(d.x * _rio_r.x + d.y * _rio_r.z)
	return dw < 4.6 + folga and tl < 96.0 and p.y < _rio_c.y - 2.0 + RIO_DECLIVE * maxf(tl - 8.0, 0.0) + (RIO_QUEDA_H if d.x * _rio_r.x + d.y * _rio_r.z > RIO_QUEDA_T else 0.0)


func _spot_livre(sigma: float, s: float, d: float, r: float) -> Dictionary:
	for off: float in [0.0, 1.1, -1.1, 2.2, -2.2, 3.3, -3.3, 4.4, -4.4, 5.5, -5.5, 6.6, -6.6, 7.7, -7.7]:
		var sp := _spot(sigma, s + off, d)
		if _livre(sp["pos"], r, true):
			return sp
	return {}


func _spot(sigma: float, s: float, d: float) -> Dictionary:
	s = _s_sem_porta(sigma, s, d)
	var out := -Route.right(s) * sigma
	return {"pos": facade(sigma, s) + out * d + Vector3(0, SW_H, 0), "out": out, "tan": Route.tangent(s)}


func _yaw_to(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


## Objetos de rua de 1961: um bar com TV ligada, carros cobertos, banquinhos, baldes, aros de roda, bola, estátua.
func _props_rua() -> Node3D:
	var root := Node3D.new()
	root.name = "Props"
	# --- bar com a TV ligada na calçada do largo (as pessoas se juntavam para ver TV nos bares): barril, TV, banquinhos
	var bar: Dictionary = _bar_spot
	var barril := _prop(root, "wine_barrel_01", bar["pos"], 0.0, 1.0)
	_prop_collision(barril, "cil", Vector3(0.72, 0.85, 0.72), Vector3(0, 0.43, 0))
	_tv(root, bar["pos"] + Vector3(0, 0.86, 0), _yaw_to(bar["out"]))
	for k in 2:
		var sb := _spot(-1.0, 147.0 + k * 3.0, 0.9)
		if not _livre(sb["pos"], 0.45, true):
			continue
		_reservar(sb["pos"], 0.45)
		var banco := _prop(root, "wooden_stool_01", sb["pos"], _rng.randf() * TAU, 1.0)
		_prop_collision(banco, "cil", Vector3(0.4, 0.44, 0.4), Vector3(0, 0.22, 0))
	# --- carros cobertos com lona, estacionados na borda do largo e do adro
	for cfg in [[153.0, -1.0], [S_END + 22.0, 1.0]]:
		var sg: float = cfg[1]
		var s: float = float(_carros_s.get(int(cfg[0]), cfg[0]))
		var c := Route.pos(s) + Route.right(s) * sg * (Route.width(s) * 0.5 - 1.25)
		var carro := _prop(root, "covered_car", c, _yaw_to(Route.tangent(s)) + (0.0 if sg < 0 else PI), 1.0)
		carro.position.y = c.y + 0.02
		_prop_collision(carro, "caixa", Vector3(1.9, 1.4, 4.4), Vector3(0, 0.7, 0))
		# esconderijo atrás do carro, do lado da parede
		var toward_wall := Route.right(s) * sg
		var ec := _esconderijo(root, "EsconderijoCarro_%d" % int(s), c + toward_wall * 0.2 + Vector3(0, 0.9, 0), Vector3(3.0, 1.8, 5.2), c + toward_wall * 1.45 + Vector3(0, 0.05, 0), _yaw_to(toward_wall))
	# --- banquinhos e baldes junto às portas, com um lampião de querosene esquecido em um deles
	for cfg in [[30.0, 1.0], [96.0, -1.0], [212.0, 1.0], [264.0, -1.0], [304.0, 1.0]]:
		var sp := _spot(cfg[1], cfg[0], 0.55)
		if not _livre(sp["pos"], 0.45, true):
			continue
		_reservar(sp["pos"], 0.45)
		var banco := _prop(root, "wooden_stool_01", sp["pos"], _rng.randf() * TAU, 1.0)
		_prop_collision(banco, "cil", Vector3(0.4, 0.44, 0.4), Vector3(0, 0.22, 0))
		if int(cfg[0]) == 96 or int(cfg[0]) == 264:
			var lan := _prop(root, "Lantern_01", sp["pos"] + Vector3(0, 0.44, 0), _rng.randf() * TAU, 1.0)
			_lamp_light(lan, Vector3(0, 0.13, 0), 0.9).omni_range = 5.0
			_halo(lan, Vector3(0, 0.13, 0), 0.9, "halo_vela")
	for cfg in [[64.0, 1.0], [122.0, -1.0], [244.0, -1.0], [168.0, 1.0], [310.0, -1.0]]:
		var sp := _spot(cfg[1], cfg[0], 0.55)
		if not _livre(sp["pos"], 0.4, true):
			continue
		_reservar(sp["pos"], 0.4)
		var balde := _prop(root, "wooden_bucket_01", sp["pos"], _rng.randf() * TAU, 1.0)
		_prop_collision(balde, "cil", Vector3(0.38, 0.3, 0.38), Vector3(0, 0.15, 0))
	# --- ferro-velho de 1961: aros de roda encostados na parede (a ferraria) e uma bola de futebol esquecida
	for cfg in [[141.0, -1.0], [141.8, -1.0], [282.0, 1.0]]:
		var sp := _spot_livre(cfg[1], cfg[0], 0.3, 0.55)
		if sp.is_empty():
			continue
		_reservar(sp["pos"], 0.55)
		var aro := _prop(root, "rusted_wheel_rim_02", sp["pos"], _yaw_to(sp["out"]) + _rng.randf_range(-0.25, 0.25), 1.0)
		aro.rotation.x = -0.20      # inclinado, encostado na parede
	var bola := _prop(root, "football", _spot(1.0, 157.0, 2.6)["pos"], _rng.randf() * TAU, 1.0)
	bola.name = "BolaEsquecida"
	# --- ferramentas e utilidades de 1961 encostadas nas paredes: escadas, machados, regadores, lousas de cardápio
	for cfg in [[48.0, 1.0], [110.0, -1.0], [190.0, 1.0], [240.0, 1.0], [298.0, -1.0], [348.0, 1.0]]:
		if Route.width(cfg[0]) < 4.6:        # rua estreita: a escada (0,8 m de fundo) invadiria o corredor de passagem
			continue
		var sl := _spot(cfg[1], cfg[0], 0.55)
		if not _livre(sl["pos"], 0.7, true):
			continue
		_reservar(sl["pos"], 0.7)
		var esc := _prop(root, "wooden_ladder", sl["pos"], _yaw_to(sl["out"]), 1.6)
		esc.rotation.x = -0.2
		_prop_collision(esc, "caixa", (esc.get_meta("bb") as AABB).size, (esc.get_meta("bb") as AABB).get_center())
	for cfg in [[36.0, 1.0], [101.0, 1.0], [186.0, -1.0], [276.0, 1.0]]:
		var sa2 := _spot(cfg[1], cfg[0], 0.3)
		if not _livre(sa2["pos"], 0.4, true):
			continue
		_reservar(sa2["pos"], 0.4)
		var machado := _prop(root, "wooden_axe_02", sa2["pos"], _yaw_to(sa2["out"]) + _rng.randf_range(-0.4, 0.4), 1.0)
		machado.rotation.x = -0.28
	for cfg in [[22.0, -1.0], [66.0, -1.0], [131.0, 1.0], [199.0, 1.0], [256.0, -1.0], [312.0, 1.0]]:
		var sr := _spot(cfg[1], cfg[0], 0.5)
		if not _livre(sr["pos"], 0.4, true):
			continue
		_reservar(sr["pos"], 0.4)
		var regador := _prop(root, "watering_can_metal_01", sr["pos"], _rng.randf() * TAU, 1.0)
		_prop_collision(regador, "cil", Vector3(0.35, 0.35, 0.35), Vector3(0, 0.17, 0))
	for id in ["venda", "padaria", "escola", "carpintaria"]:
		if not _entradas_feitas.has(id):
			continue
		var ent: Dictionary = {}
		for e in ENTRADAS:
			if e["id"] == id:
				ent = e
		var sl2 := _spot(ent["sigma"], float(_entradas_feitas[id]) - 1.4, 0.6 if Route.width(float(_entradas_feitas[id])) >= 4.4 else 0.2)
		if not _livre(sl2["pos"], 0.7, true):
			continue
		_reservar(sl2["pos"], 0.7)
		var lousa := _prop(root, "standing_chalkboard_01", sl2["pos"], _yaw_to(sl2["out"]) + _rng.randf_range(-0.3, 0.3), 1.0)
		lousa.name = "Lousa_%s" % id
		_prop_collision(lousa, "caixa", (lousa.get_meta("bb") as AABB).size, (lousa.get_meta("bb") as AABB).get_center())
	# --- estátua sobre pedestal no adro, voltada para a porta da igreja
	var s_est := S_END + 20.0
	var sa := Route.pos(s_est) + Route.right(s_est) * (-5.4)
	var base := _group(root, "Pedestal", Transform3D(Basis(Vector3.UP, _yaw_to(Route.tangent(s_est))), sa))
	var pb := _batch()
	pb.box("cantaria", Vector3(1.5, 0.28, 1.5), Vector3(0, 0.14, 0))
	pb.box("cantaria", Vector3(1.2, 0.7, 1.2), Vector3(0, 0.63, 0))
	pb.box("cantaria", Vector3(1.38, 0.16, 1.38), Vector3(0, 1.06, 0))
	_mesh_node(base, "Malha", pb.commit())
	_prop_collision(base, "cil", Vector3(1.4, 1.2, 1.4), Vector3(0, 0.6, 0))
	var estatua := _prop(base, "gothic_statue", Vector3(0, 1.14, 0), PI, 1.0)
	estatua.name = "Estatua"
	root.add_child(_lines())
	return root


## TV de tubo ligada: tela de estática, luz azulada que pisca e som de chuvisco (scripts/televisao.gd).
func _tv(parent: Node, pos: Vector3, yaw: float) -> void:
	var tv := _prop(parent, "Television_01", pos, yaw, 1.0)
	tv.name = "Televisao"
	tv.set_script(load("res://scripts/televisao.gd"))
	var bb: AABB = tv.get_meta("bb")
	var front := bb.position.z + bb.size.z
	# tela: retângulo sobre o vidro (a frente do modelo olha para +Z); medidas ajustadas olhando as capturas
	var q := QuadMesh.new()
	q.size = Vector2(bb.size.x * 0.56, bb.size.y * 0.60)
	var tela := _mesh_node(tv, "Tela", q, Vector3(bb.position.x + bb.size.x * 0.40, bb.position.y + bb.size.y * 0.54, front + 0.004))
	tela.set_surface_override_material(0, mat("tv_tela"))
	tela.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.name = "Luz"
	l.position = Vector3(bb.position.x + bb.size.x * 0.4, bb.position.y + bb.size.y * 0.55, front + 0.5)
	l.light_color = Color(0.62, 0.78, 1.0)
	l.light_energy = 1.3
	l.omni_range = 6.5
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 10.0
	tv.add_child(l)
	_halo(tv, l.position, 1.2, "halo_tv")
	_prop_collision(tv, "caixa", bb.size, bb.get_center())


## Toras de árvore caídas e arbustos nas encostas.
func _props_encosta() -> Node3D:
	var root := Node3D.new()
	root.name = "PropsEncosta"
	var placed := 0
	var tries := 0
	while placed < 30 and tries < 1200:
		tries += 1
		var sc := _rng.randf_range(10.0, Route.length() - 10.0)
		var sg := -1.0 if _rng.randf() < 0.5 else 1.0
		var d := _rng.randf_range(Route.width(sc) * 0.5 + 16.0, 55.0)
		var p := Route.pos(sc) + Route.right(sc) * sg * d
		if absf(sc - Route.BRIDGE_S) < 12.0 or _near_spot(Vector2(p.x, p.z), 9.0) or Route.dist_to_center(p) < Route.width(sc) * 0.5 + 13.0:
			continue
		var tora := Arvores.no_kit("plantas_lod", "tronco", _rng.randf_range(0.9, 1.4))
		tora.position = Vector3(p.x, terrain_h(p.x, p.z) - 0.05, p.z)
		tora.rotation.y = _rng.randf() * TAU
		root.add_child(tora)
		tora.name = "Tora_%02d" % placed
		_spots.append(Vector2(p.x, p.z))
		placed += 1
	placed = 0
	tries = 0
	while placed < 140 and tries < 3000:
		tries += 1
		var sc := _rng.randf_range(4.0, Route.length() - 4.0)
		var sg := -1.0 if _rng.randf() < 0.5 else 1.0
		var d := _rng.randf_range(Route.width(sc) * 0.5 + 15.0, 62.0)
		var p := Route.pos(sc) + Route.right(sc) * sg * d
		if absf(sc - Route.BRIDGE_S) < 12.0 or _near_spot(Vector2(p.x, p.z), 6.5) or Route.dist_to_center(p) < Route.width(sc) * 0.5 + 12.0:
			continue
		var arb := Arvores.no_kit("plantas_lod", "rooibos", _rng.randf_range(1.0, 1.7))
		arb.position = Vector3(p.x, terrain_h(p.x, p.z) - 0.04, p.z)
		arb.rotation.y = _rng.randf() * TAU
		root.add_child(arb)
		arb.name = "Arbusto_%02d" % placed
		_spots.append(Vector2(p.x, p.z))
		placed += 1
	_set_range(root, 160.0)
	return root


func _near_spot(q: Vector2, r: float) -> bool:
	for o in _spots:
		if o.distance_to(q) < r:
			return true
	return false
