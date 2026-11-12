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
const CAMADA_DETALHE := 4      # camada visual 3: detalhes de fachada que os decalques de sujeira não atingem
const MATS := "res://assets/materials/"
const S_END := Route.S_END     # a partir daqui começa o adro da igreja
const CHURCH_S := Route.CHURCH_S

const WALLS: Array[String] = ["reboco_branco", "reboco_ocre", "reboco_amarelo", "reboco_azul", "reboco_salmao", "reboco_verde", "reboco_branco_novo", "reboco_creme"]
const WALL_WEIGHT: Array[int] = [30, 14, 18, 8, 8, 4, 6, 12]
const WOODS: Array[String] = ["madeira_azul", "madeira_vermelha", "madeira_verde", "madeira_ocre", "madeira_natural", "madeira_branca"]
## becos em escada: [s, lado]
## Becos em escada: [s, lado, tipo]. tipo "cego" = beco SEM SAÍDA (pátio com portão de ferro, itens e uma casa com porta); sem tipo = escada que sobe até a porta do alto.
## (A rota ganhou um começo novo e o resto dela deslocou Route.SHIFT m: tudo que depende da forma da rua a partir de ~65 m soma SHIFT.
## Os becos de atalho e a ladeira em zigue-zague não tinham sido deslocados e a parede de 54 m do atalho cortava a rua.)
const ALLEYS: Array = []          # (mapa antigo; o mapa novo tira os becos do plano: scripts/plano_vila.gd)
## PASSAGENS = becos de atalho: escadas/rampas que atravessam de uma perna do zigue-zague da ladeira da igreja à outra.
## "a" é a boca de baixo e "b" a de cima: [s da rua, lado]. Dá para subir 60-80 m de rua em ~20 m de escada.
const PASSAGENS: Array = []
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
var _interiores: Interiores
var _salas_rua: Dictionary = {}              # id -> sala pronta (Node3D solto) que vira filha da casa certa
const SHELL := 0.06                          # espessura da casca externa da casa (por fora da parede da sala)
var _entradas_feitas: Dictionary = {}
var _ocupados: Array = []     # [Vector3, raio]: lugares já usados por portas/barris/bancos (nada se sobrepõe)
var _beco_vizinho: Dictionary = {}          # caixa do beco que vem logo depois da casa em construção
var _casas_postas: Array[Dictionary] = []   # {xf, depth, w} das casas já colocadas (para não se atravessarem nas curvas)
var _flutuando: Array[String] = []   # peças que não encostam em nada (auditoria feita no bake)
var _spots: Array[Vector2] = []
var _pass_geo: Array[Dictionary] = []     # geometria dos becos de atalho (calculada uma vez, só com a rota)
var _lamp_n := 0
var _haunted := 0
var _joints: Array[Dictionary] = []   # junções entre lotes (onde ficam nichos)
var _wear: FastNoiseLite
var _wet: FastNoiseLite
var _porta_central := false
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
func _blocker(parent: Node, node_name: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body, true)            # nome legível e único (ColMesa, ColMesa2...): a auditoria das salas precisa deles
	return body


## Plantas de cartão (texturas geradas) que foram trocadas por modelos reais: chave antiga -> [modelos, altura-alvo em m].
## Cartões continuam só nas árvores, palmeiras e bananeiras (não há modelo real delas).
const PLANTAS_REAIS := {
	"arbusto": [["rooibos", "rooibos", "rooibos", "mato_a", "weed_a"], 1.1],
	"capim": [["mato_b", "grass_tuft_a", "grass_tuft_b", "mato_c"], 0.45],
	"samambaia": [["periwinkle_a", "periwinkle_b", "periwinkle_c", "mato_b"], 0.5],
}
var _alt_real := {}
var rb2_beiral: Array = []
var _kit2 := false               # casa em construção usa o kit 2 (sacadas de ferro, guilhotina, grades, porta com bandeira...)
var _pisca_fachada: Array[String] = []   # faces coplanares (piscam) achadas nas fachadas durante o bake
var _mod_atual: Array = []      # módulos do kit postos na casa em construção: [nome, Transform3D local] (vão para a planta)
var _vaos_atual: Array = []     # vãos (janelas/portas) da fachada em construção: {z, peitoril, topo, w, porta} — usados pelos detalhes de parede
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
	_rng_f.seed = 77
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


## Ponto da rota mais perto de (x, z) que esteja LONGE (mais de 30 m de rua) do ponto `s1`: a outra perna do zigue-zague.
func _nearest_outro(x: float, z: float, s1: float) -> Vector2:
	var q := Vector2(x, z)
	var bi := -1
	var bd := INF
	for i in _rs.size():
		if absf(i * 2.0 - s1) < 30.0:
			continue
		var d := q.distance_squared_to(_rs[i])
		if d < bd:
			bd = d
			bi = i
	if bi < 0:
		return Vector2(-1.0, INF)
	return Vector2(bi * 2.0, sqrt(bd))


func terrain_h(x: float, z: float) -> float:
	var q := _nearest(x, z)
	var base := Route.height(q.x) - 0.4      # abaixo da calçada: não cobre a rua
	# entre duas pernas do zigue-zague o chão sobe em rampa de uma rua até a outra (antes havia um degrau no meio do quarteirão)
	var q2 := _nearest_outro(x, z, q.x)
	var entre := 0.0
	if q2.x >= 0.0 and q2.y < 40.0:
		var wq := clampf((q.y - 3.5) / maxf(q.y + q2.y - 7.0, 0.1), 0.0, 0.5)
		base = lerpf(base, Route.height(q2.x) - 0.4, wq)
		entre = 1.0 - smoothstep(30.0, 45.0, q.y + q2.y)
	var dc := Route.width(q.x) * 0.5 + SW + 12.0       # corredor plano onde ficam as casas
	var t := maxf(0.0, q.y - dc) * (1.0 - entre)
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
	env.ambient_light_color = Color(0.10, 0.13, 0.20)
	env.ambient_light_energy = 0.34
	env.fog_enabled = true
	env.fog_light_color = Color(0.085, 0.11, 0.17)         # névoa fria, esverdeada e mais escura (clima de terror)
	env.fog_density = 0.033
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.3                        # o longe esmaece em direção à cor do céu, mais natural
	env.fog_sun_scatter = 0.06                              # a lua "vaza" na névoa
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.11
	env.adjustment_saturation = 0.86
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
	l.light_cull_mask = 1 | CAMADA_DETALHE     # os interiores (camada 2) não recebem luar; molduras/portas/vidros (camada 3) sim
	# a lua fica no céu à frente e à direita de quem começa a subir a rua; a luz viaja no sentido oposto
	var moon_dir := Vector3(0.50, 0.46, -0.74).normalized()
	l.transform = Transform3D(Basis.looking_at(-moon_dir, Vector3.UP), Vector3.ZERO)
	l.shadow_enabled = true
	l.shadow_opacity = 0.78           # a sombra da lua deixa um pouco de luz (menos "preto chapado")
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS   # 2 cascatas: sombras nítidas perto do jogador e ainda presentes ao longe
	l.directional_shadow_split_1 = 0.22
	l.directional_shadow_blend_splits = true                                  # sem faixa visível na troca de cascata
	l.directional_shadow_max_distance = 85.0
	l.directional_shadow_fade_start = 0.82
	l.shadow_bias = 0.03                                                       # menos "acne" (listras) nas paredes sem descolar a sombra dos pés
	l.shadow_normal_bias = 1.1
	l.shadow_blur = 1.6                                                        # borda macia, como luz de lua de verdade
	l.light_angular_distance = 0.45                                            # sombras que suavizam com a distância (Forward+)
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
	# salas das casas da rua: montadas ANTES do casario (a casa é feita sob medida para a sala); o sorteio da rua não muda
	var rng_antes := _rng.state
	_interiores = Interiores.new()
	for sid in Interiores.SALAS_RUA:
		_salas_rua[sid] = _interiores.sala_rua(self, sid)
	_rng.state = rng_antes
	_frontage_plano(root)
	_numerar_portas(root)
	_tira_plantas_dentro_das_casas(root)
	_aterra_plantas(root)
	root.add_child(Realismo.new().vidros_e_plantas(self, root))
	root.add_child(_lamps())
	root.add_child(_adornos())
	root.add_child(_nichos())
	root.add_child(_props_rua())
	root.add_child(_ratos())
	_tira_props_dentro_das_casas(root)
	root.add_child(_coletaveis())
	_bridge(root)
	root.add_child(_church_plaza())
	root.add_child(_hillside())
	root.add_child(_props_encosta())
	root.add_child(Realismo.new().construir(self))
	root.add_child(_serra())
	root.add_child(_route_path())
	root.add_child(_interiores.construir(self, OS.get_environment("BRADADOR_CUBOS") != ""))
	var det := Detalhes.new()
	root.add_child(det.construir(self))
	print("[vila] detalhes: ", det.contagem)
	print("[vila] entradas: ", _entradas_feitas)
	_separa_lampioes(root)
	# luzes da rua só iluminam a rua (camada 1); as das salas (camada 2, ver Interiores._camada) só iluminam a própria sala
	for l in root.find_children("*", "Light3D", true, false):
		if not (l is DirectionalLight3D) and not _em_sala(l):
			(l as Light3D).light_cull_mask = 1 | CAMADA_DETALHE
	# molduras, portas, janelas, vidros e plantas de janela na camada 3: as manchas projetadas (decalques, camada 1) não as pintam
	var vp := root.get_node_or_null("VidrosEPlantas")
	if vp:
		for gi in vp.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).layers = CAMADA_DETALHE
	# Desempenho: a neblina esconde o que está longe, então nem desenhamos.
	# a neblina (densidade 0,03) já apaga tudo a ~100 m: não desenhar além disso economiza centenas de chamadas
	# mapa em zigue-zague: as pernas de cima ficam a 34-100 m; a neblina já apaga quase tudo a ~90 m
	for name in ["Casas", "MurosEQuintais", "FundoDaRua", "Ponte", "MurosDasCurvas"]:
		var n := root.get_node_or_null(name)
		if n:
			_set_range(n, 95.0)
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
		_set_range(npe, 95.0)
	_set_label_range(root, 55.0)
	for halo in root.find_children("Halo", "MeshInstance3D", true, false):
		(halo as GeometryInstance3D).visibility_range_end = 75.0
	_set_range(root.get_node("Morros/CasasDoMorro"), 280.0)
	_set_range(root.get_node("Morros/Arvores"), 220.0)
	print("[vila] pecas soltas (flutuando): %d" % _flutuando.size())
	print("[vila] fachadas: faces no mesmo plano (piscam): %d" % _pisca_fachada.size())
	var tipos := {}
	for f in _pisca_fachada:
		var k := String(f).get_slice(": ", 1).get_slice(" eixo", 0)
		tipos[k] = int(tipos.get(k, 0)) + 1
	for k in tipos:
		print("[vila]   pisca: %s  (%d)" % [k, tipos[k]])
	for f in _flutuando.slice(0, 40):
		print("[vila]   ", f)
	return root


func _em_sala(n: Node) -> bool:
	var p := n
	while p != null:
		if String(p.name).begins_with("Sala_") or p.name == "Interiores":
			return true
		p = p.get_parent()
	return false


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
		_casas_postas.append({"xf": Transform3D(Basis(dv, Vector3.UP, dv.cross(Vector3.UP)), G["A"]), "depth": float(G["D"]) + 0.4, "w": PASS_W + 2.4, "corr": true})
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
						if _salas_rua.has(e["id"]):
							w = float((_salas_rua[e["id"]] as Node3D).get_meta("dim").x) + SHELL * 2.0 + 0.75 - 0.24 + 0.05      # lote sob medida da sala
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
					_beco_vizinho = {}
					for ai2 in ALLEYS.size():       # a casa logo antes de um beco: guarda onde o beco vai ficar para não invadir a escada
						var a2: Array = ALLEYS[ai2]
						if a2[1] == sigma and not done_alley.has(ai2) and s2 >= a2[0] - 4.0:
							var fb2 := lot_frame(sigma, s2, _advance(sigma, s2, 3.6))
							_beco_vizinho = {"xf": fb2["xf"], "depth": (36 if a2.size() <= 2 else 14) * 0.45 + 0.8, "w": 3.6 + 0.4, "corr": true}
							break
					_lot_casa(casas, f, sigma, w_street)
					_beco_vizinho = {}
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
				var zloc := 0.0                                  # onde, ao longo da parede do lote, o altar fica: longe da porta, no meio de um trecho de parede
				if kind == "casa" and casas.get_child_count() > 0:
					var ult := casas.get_child(casas.get_child_count() - 1)
					if ult.has_meta("door_z"):
						var dzz := float(ult.get_meta("door_z"))
						zloc = dzz + (2.4 if dzz < 0.0 else -2.4)
						zloc = clampf(zloc, -float(f["w"]) * 0.5 + 1.0, float(f["w"]) * 0.5 - 1.0)
				_joints.append({"sigma": sigma, "s": s, "xf": f["xf"], "zloc": zloc})      # guarda o quadro do lote: o altar se alinha à parede dele, não à tangente da rua
			prev_special = kind != "casa"
			s = s2


# ================================================================== MAPA DO ZERO (docs/27): tudo sai do cadastro do plano

var _plano: Dictionary = {}


## Quadro (origem na fachada, x para dentro do lote) de um retângulo do plano, a partir da peça reta e do lado.
func _quadro_plano(pl: PlanoVila, c: Dictionary) -> Dictionary:
	var pc: Dictionary = pl.pecas[int(c["peca"])]
	var q := pl._quadro_lote(pc, float(c["lado"]))
	var a: Vector2 = q["a"]
	var t: Vector2 = q["t"]
	var n: Vector2 = q["n"]
	var f: float = q["frente"]
	var m := a + t * (float(c["u"]) + float(c["w"]) * 0.5) + n * f
	var sm := Route.nearest_s(Vector3(m.x, 0.0, m.y))
	var x_axis := Vector3(n.x, 0.0, n.y)
	var basis := Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP))
	return {"xf": Transform3D(basis, Vector3(m.x, Route.height(sm) + SW_H, m.y)), "w": float(c["w"]), "sm": sm}


## Números das portas como numa rua de verdade: ímpares do lado esquerdo e pares do direito, crescendo da entrada até a igreja.
func _numerar_portas(root: Node3D) -> void:
	var casas := root.get_node_or_null("Casas")
	if casas == null:
		return
	var lados := {-1.0: [], 1.0: []}
	for c in casas.get_children():
		var lab := (c as Node3D).get_node_or_null("Numero") as Label3D
		if lab == null or not c.has_meta("door_z"):
			continue
		var porta: Vector3 = (c as Node3D).transform * Vector3(-0.9, 0.0, float(c.get_meta("door_z")))
		var s := Route.nearest_s(porta)
		var lado := -1.0 if Route.right(s).dot(porta - Route.pos(s)) < 0.0 else 1.0
		lados[lado].append([s, lab])
	for ld in lados:
		var arr: Array = lados[ld]
		arr.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var n := 1 if ld < 0.0 else 2
		for e in arr:
			(e[1] as Label3D).text = str(n)
			n += 2


func _frontage_plano(root: Node3D) -> void:
	var casas := _group(root, "Casas")
	var muros := _group(root, "MurosEQuintais")
	var becos := _group(root, "Becos")
	_start_wall(root)
	var dims := {}
	for sid in _salas_rua:
		var d: Vector3 = (_salas_rua[sid] as Node3D).get_meta("dim")
		dims[sid] = Vector2(d.x + SHELL * 2.0 + 0.75, d.z + SHELL * 2.0 + 0.75)
	var pl := PlanoVila.new()
	_plano = pl.montar(dims)
	print("[vila] plano: %d itens, %d sobreposições, avisos: %s" % [(_plano["cadastro"] as Array).size(), int(_plano["sobreposicoes"]), str(_plano["avisos"])])
	# 1) becos-escada de ligação primeiro (o terreno se ajusta ao piso deles)
	for c in _plano["cadastro"]:
		if c["tipo"] == "beco":
			_beco_escada(becos, c)
	# 2) casas, casas visitáveis, quintais e becos sem saída
	for c in _plano["cadastro"]:
		match String(c["tipo"]):
			"casa", "visitavel":
				var f := _quadro_plano(pl, c)
				if c["tipo"] == "casa" and float(f["sm"]) > CHURCH_S - 5.0:
					continue                     # ao lado das torres da igreja não cabe casa (a porta dava na parede da torre)
				_entrada_atual = {}
				if c["tipo"] == "visitavel":
					for e in ENTRADAS:
						if e["id"] == c["sala"]:
							_entrada_atual = e
					_entradas_feitas[c["sala"]] = f["sm"]
				_lot_casa_plano(casas, f, float(c["lado"]), float(c["d"]), c)
			"quintal":
				_lot_quintal(muros, _quadro_plano(pl, c))
			"cego":
				var x: float = c["x"]
				var z0: float = c["z_rua"]
				var sm := Route.nearest_s(Vector3(x, 0.0, z0))
				var xa := Vector3(0, 0, -1)
				var fb := {"xf": Transform3D(Basis(xa, Vector3.UP, xa.cross(Vector3.UP)), Vector3(x, Route.height(sm) + SW_H, z0)), "w": PlanoVila.BECO_L, "sm": sm}
				_lot_beco(becos, fb, String(c["sala"]))
	# 3) ponte (dois lados) e chafariz no largo do 1º grampo
	for sg: float in [-1.0, 1.0]:
		var fp := lot_frame(sg, Route.BRIDGE_S - Route.BRIDGE_HALF, Route.BRIDGE_S + Route.BRIDGE_HALF)
		_lot_ponte(muros, fp, sg)
	var fc := lot_frame(Route.FOUNTAIN_SIDE, Route.FOUNTAIN_S - 3.5, Route.FOUNTAIN_S + 3.5)
	var xfc: Transform3D = fc["xf"]
	xfc.origin += xfc.basis.x.normalized() * 2.2           # no grampo a beira é curva: recua o chafariz para dentro do largo (o tanque invadia a rua)
	fc["xf"] = xfc
	_lot_chafariz(muros, fc)
	_entrada_atual = {}
	_curvas_plano(root)


## Casa de um lote do plano: largura e fundo EXATOS do cadastro (nada de encolher depois). Sobrados ganham sacada.
func _lot_casa_plano(parent: Node3D, f: Dictionary, sigma: float, depth: float, c: Dictionary) -> void:
	var w: float = f["w"]
	var sala: Node3D = null
	if not _entrada_atual.is_empty() and _salas_rua.has(_entrada_atual["id"]):
		sala = _salas_rua[_entrada_atual["id"]]
	var floors := 2 if _rng.randf() < 0.65 else 1
	if _rng.randf() < 0.08 and w > 7.5:
		floors = 3
	if sala != null:
		floors = 1
	var haunted: bool = floors >= 2 and _haunted < 6 and _rng.randf() < 0.12
	if haunted:
		_haunted += 1
	var xf: Transform3D = f["xf"]
	_casas_postas.append({"xf": xf, "depth": depth, "w": w})
	var casa := make_casa(w, floors, _pick_wall(), WOODS[_rng.randi() % WOODS.size()], depth, floors >= 2, 0.28, false, haunted, _entrada_atual, sala)
	casa.name = "Casa_%02d" % _n
	_n += 1
	var pd: Vector3 = xf * Vector3(-0.4, 0.0, float(casa.get_meta("door_z")))
	xf.origin.y += clampf(Route.height(Route.nearest_s(pd)) + SW_H - pd.y, -2.2, 2.2)
	casa.transform = xf
	parent.add_child(casa)
	_reservar(xf * Vector3(-1.0, 0.0, float(casa.get_meta("door_z"))), 1.7)
	_portas.append(xf * Vector3(-0.9, 0.0, float(casa.get_meta("door_z"))))
	_decalques_fachada(casa, w, float(casa.get_meta("altura")))
	var porta_a := casa.get_node_or_null("Entrada_%s" % _entrada_atual.get("id", "")) as Node3D
	if porta_a != null:
		porta_a.position.y = 1.3
	var dzz := float(casa.get_meta("door_z"))
	var zloc := clampf(dzz + (2.4 if dzz < 0.0 else -2.4), -w * 0.5 + 1.0, w * 0.5 - 1.0)
	_joints.append({"sigma": sigma, "s": f["sm"], "xf": f["xf"], "zloc": zloc})


## BECO-ESCADA DE LIGAÇÃO (atalho entre duas pernas): reto, do meio-fio de baixo ao de cima, degraus iguais, muros dos dois lados
## acompanhando a escada, lampiões, colisão em rampa contínua (ninguém trava) e refúgio. Origem do nó: boca de baixo; x = para cima.
func _beco_escada(parent: Node3D, c: Dictionary) -> void:
	var x: float = c["x"]
	var zb: float = c["z_baixo"]
	var zc: float = c["z_cima"]
	var sb := Route.nearest_s(Vector3(x, 0.0, zb))
	var sc := Route.nearest_s(Vector3(x, 0.0, zc))
	var hb := Route.height(sb) + SW_H
	var hc := Route.height(sc) + SW_H
	var L := zb - zc
	var rise := hc - hb
	var wb := PlanoVila.BECO_L
	var xa := Vector3(0, 0, -1)
	var g := _group(parent, "BecoEscada_%02d" % _n, Transform3D(Basis(xa, Vector3.UP, xa.cross(Vector3.UP)), Vector3(x, hb, zb)))
	_n += 1
	g.set_meta("passagem", true)
	g.set_meta("comprimento", L)
	g.set_meta("subida", rise)
	_casas_postas.append({"xf": g.transform, "depth": L, "w": wb + 1.0, "corr": true})
	_pass_geo.append({"id": g.name, "A": Vector3(x, hb, zb), "B": Vector3(x, hc, zc), "dir": xa, "D": L, "rise": rise})
	_reservar(Vector3(x, hb, zb + 1.6), 2.2)          # bocas do beco livres: nada de barril/caixote na entrada de baixo nem na de cima
	_reservar(Vector3(x, hc, zc - 1.6), 2.2)
	var n := maxi(4, int(round(absf(rise) / 0.16)))
	var run := L / float(n)
	var b := _batch()
	for i in n:
		var top := rise * float(i + 1) / float(n)
		b.box("pedra_chao", Vector3(run + 0.02, top + 1.2, wb), Vector3((i + 0.5) * run, top - (top + 1.2) * 0.5, 0))
		b.box("cantaria", Vector3(0.10, 0.06, wb), Vector3(i * run + 0.05, top - rise / float(n) + 0.03, 0))      # espelho de pedra no degrau
	var nm := maxi(6, int(L / 1.6))
	for sz: float in [-1.0, 1.0]:
		for k in nm:
			var x0 := k * L / nm
			var seg := L / nm
			var top := rise * float(k + 1) / float(nm) + 2.4
			b.box("muro", Vector3(seg + 0.04, top + 1.4, 0.45), Vector3(x0 + seg * 0.5, top * 0.5 - 0.7, sz * (wb * 0.5 + 0.225)))
			b.box("cantaria", Vector3(seg + 0.04, 0.10, 0.6), Vector3(x0 + seg * 0.5, top + 0.05, sz * (wb * 0.5 + 0.225)))
	_mesh_node(g, "Degraus", b.commit())
	var ang := atan2(rise, L)
	var ramp := StaticBody3D.new()
	ramp.name = "Rampa"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(sqrt(L * L + rise * rise) + 0.6, 0.4, wb)
	cs.shape = bs
	ramp.add_child(cs)
	ramp.position = Vector3(L * 0.5, rise * 0.5 - 0.2 * cos(ang), 0)
	ramp.rotation.z = ang
	g.add_child(ramp)
	for sz: float in [-1.0, 1.0]:
		_blocker(g, "Parede_%d" % int(sz), Vector3(L, absf(rise) + 6.0, 0.45), Vector3(L * 0.5, rise * 0.5 + 1.5, sz * (wb * 0.5 + 0.225)))
	for k in range(1, int(L / 8.0) + 1):                                                   # lampiões de parede alternados
		var xl := k * 8.0 - 2.0
		if xl > L - 2.0:
			break
		var sl := 1.0 if k % 2 == 0 else -1.0
		var lw := _lantern_wall(Vector3(xl, rise * xl / L + 2.4, sl * (wb * 0.5 - 0.02)), PI if sl > 0.0 else 0.0)
		g.add_child(lw)
	var refuge := Area3D.new()
	refuge.name = "Refugio"
	refuge.add_to_group("refugio", true)
	refuge.collision_layer = 0
	var rcs := CollisionShape3D.new()
	var rbs := BoxShape3D.new()
	rbs.size = Vector3(6.0, 3.4, wb)
	rcs.shape = rbs
	refuge.add_child(rcs)
	refuge.position = Vector3(3.2, rise * 3.2 / L + 1.7, 0)
	g.add_child(refuge)
	for k in range(2, int(L) - 2, 5):                                                     # mato nas frestas dos degraus, junto ao muro
		_plant(g, "capim", Vector3(k + 0.3, rise * (k + 0.3) / L, (wb * 0.5 - 0.25) * (1.0 if k % 2 == 0 else -1.0)), _rng.randf() * TAU, 0.7)


## Curvas do zigue-zague (mapa do zero): por FORA, muro de arrimo de pedra acompanhando o arco, com capa de cantaria, lampiões e árvores
## além do muro; por DENTRO, mureta baixa de pedra com um jardim no miolo. Tudo em segmentos retos curtos colados ao arco (sem buraco).
func _curvas_plano(root: Node3D) -> void:
	var g := _group(root, "MurosDasCurvas")
	var b := _batch()
	var meia := PlanoVila.LARG_RUA * 0.5 + PlanoVila.CALCADA
	var n_luz := 0
	for pc in (_plano["pecas"] as Array):
		if pc["tipo"] != "arco":
			continue
		var c: Vector2 = pc["c"]
		var r0: float = pc["r"]
		var a0: float = pc["a0"]
		var a1: float = pc["a1"]
		var nseg := maxi(6, int(absf(a1 - a0) * r0 / 1.5))
		for lado: float in [1.0, -1.0]:                          # +1 = fora do arco (muro alto); -1 = dentro (mureta)
			var rr := r0 + lado * (meia + 0.3)
			if rr < 1.0:
				continue
			for k in nseg:
				var t0 := lerpf(a0, a1, float(k) / nseg)
				var t1 := lerpf(a0, a1, float(k + 1) / nseg)
				var tm := (t0 + t1) * 0.5
				var p0 := c + Vector2(cos(t0), sin(t0)) * rr
				var p1 := c + Vector2(cos(t1), sin(t1)) * rr
				var pm := (p0 + p1) * 0.5
				var comp := p0.distance_to(p1) + 0.08
				var sm := Route.nearest_s(Vector3(pm.x, 0, pm.y))
				if lado < 0.0 and absf(sm - Route.FOUNTAIN_S) < 6.0:
					continue                                                                      # boca do largo do chafariz fica aberta
				var y := Route.height(sm) + SW_H
				var alto := 2.2 if lado > 0.0 else 0.75
				var yaw := -atan2(p1.y - p0.y, p1.x - p0.x)
				b.box("muro", Vector3(comp, alto + 3.0, 0.5), Vector3(pm.x, y + (alto - 3.0) * 0.5, pm.y), Vector3(0, yaw, 0))
				b.box("cantaria", Vector3(comp + 0.02, 0.12, 0.66), Vector3(pm.x, y + alto + 0.06, pm.y), Vector3(0, yaw, 0))
				var col := StaticBody3D.new()
				col.name = "MuroCurva"
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(comp, alto + 3.0, 0.5)
				cs.shape = bs
				col.add_child(cs)
				col.position = Vector3(pm.x, y + (alto - 3.0) * 0.5, pm.y)
				col.rotation.y = yaw
				g.add_child(col)
				if lado > 0.0 and k % 7 == 3:                                                     # lampião no muro de fora
					var dirc := Vector3(-cos(tm), 0, -sin(tm))                                      # para o centro da curva (para a rua)
					var pl := Vector3(pm.x, y + 2.6, pm.y) + dirc * 0.27
					var lw := _lantern_wall(pl, atan2(dirc.x, dirc.z))
					lw.name = "LampiaoCurva_%d" % n_luz
					g.add_child(lw)
					n_luz += 1
				if lado > 0.0 and k % 5 == 1:                                                     # árvore além do muro
					var pa := c + Vector2(cos(tm), sin(tm)) * (rr + 2.5)
					_plant(g, "arvore_%d" % (k % 3), Vector3(pa.x, terrain_h(pa.x, pa.y) - 0.1, pa.y), _rng.randf() * TAU, 1.0)
					_reservar(Vector3(pa.x, terrain_h(pa.x, pa.y), pa.y), 1.2)        # tronco reservado: barril e jarro não vão para dentro dele
	_mesh_node(g, "Muros", b.commit())


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
	for G in _pass_geo:                       # as bocas dos becos de atalho também colam nas casas vizinhas
		for fk: String in ["fa", "fb"]:
			var ahead_p := float((G[fk] as Dictionary)["s_m"]) - float(f["sm"])
			if ahead_p > -3.0 and ahead_p < 9.0:
				near_alley = true
	var depth := _rng.randf_range(5.6, 6.8) if near_alley else _rng.randf_range(10.0, 13.0)
	var sala: Node3D = null
	if not _entrada_atual.is_empty() and _salas_rua.has(_entrada_atual["id"]):
		var d_sala := float(_salas_rua[_entrada_atual["id"]].get_meta("dim").z) + SHELL * 2.0 + 0.75      # a casa tem exatamente o tamanho da sala
		var w_sala := float(_salas_rua[_entrada_atual["id"]].get_meta("dim").x) + SHELL * 2.0 + 0.75
		var xt := (f["xf"] as Transform3D)
		xt.origin += xt.basis.x * 0.05
		if not _beco_vizinho.is_empty():
			_casas_postas.append(_beco_vizinho)
		var choque := _sala_conflita(xt, d_sala, w_sala)          # vizinhas, becos, passagens e o beco logo depois
		if not _beco_vizinho.is_empty():
			_casas_postas.pop_back()
		if choque:
			# a casa sob medida invadiria uma vizinha/beco (a colisão de uma engolia o querosene dentro da outra): nesta vaga vira casa comum e a entrada fica para o próximo lote
			push_warning("[vila] entrada %s adiada: invadiria um beco" % _entrada_atual["id"])
			_entradas_feitas.erase(_entrada_atual["id"])
			_entrada_atual = {}
		else:
			sala = _salas_rua[_entrada_atual["id"]]
			floors = 1
			haunted = false
			depth = d_sala
	_porta_central = near_alley
	# nas curvas, casas vizinhas giram uma em relação à outra e as caixas se atravessam por trás: encurta a profundidade até não haver choque
	var xf0: Transform3D = f["xf"]
	xf0.origin += xf0.basis.x * 0.05
	if not _beco_vizinho.is_empty():
		_casas_postas.append(_beco_vizinho)
	if sala != null:
		if _casa_atravessa(xf0, depth, float(sala.get_meta("dim").x) + SHELL * 2.0 + 0.75):
			push_warning("[vila] casa visitável %s encosta numa vizinha (curva): conferir" % _entrada_atual["id"])
	else:
		while depth > 2.6 and _casa_atravessa(xf0, depth, float(f["w"]) + 0.24):
			depth -= 0.3
	if not _beco_vizinho.is_empty():
		_casas_postas.pop_back()
	var w_casa: float = float(f["w"]) + 0.24
	if sala != null:
		w_casa = float(sala.get_meta("dim").x) + SHELL * 2.0 + 0.75
	_casas_postas.append({"xf": xf0, "depth": depth, "w": w_casa})
	var casa := make_casa(w_casa, floors, _pick_wall(), WOODS[_rng.randi() % WOODS.size()], depth,
		floors >= 2 and _rng.randf() < 0.55, 0.28, false, haunted, _entrada_atual, sala)
	_porta_central = false
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
	_decalques_fachada(casa, w_casa, float(casa.get_meta("altura")))
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


## Conflito entre a casa sob medida (xf, depth, w) e o que já foi posto. Encostar de lado na vizinha é normal (as casas se sobrepõem 0,24 m
## de propósito); o que NÃO pode é algo entrar na SALA: a parede da sala fica 0,44 m para dentro da borda da casa.
## Amostra a cada 0,4 m: (1) pontos da outra caixa dentro do miolo da sala; (2) pontos do miolo da sala dentro da outra caixa (encolhida 0,05).
func _sala_conflita(xf: Transform3D, depth: float, w: float) -> bool:
	var m := 0.44
	for o in _casas_postas:
		var oxf: Transform3D = o["xf"]
		var od := float(o["depth"])
		var ow := float(o["w"])
		if oxf.origin.distance_to(xf.origin) > depth + od + w + ow:
			continue
		var nx := int(ceil(od / 0.4))
		var nz := int(ceil(ow / 0.4))
		for ix in nx + 1:
			for iz in nz + 1:
				var p: Vector3 = oxf * Vector3(od * float(ix) / float(nx), 0.0, -ow / 2.0 + ow * float(iz) / float(nz))
				var q: Vector3 = xf.affine_inverse() * p
				if q.x > m and q.x < depth - m and absf(q.z) < w / 2.0 - m:
					return true
		nx = int(ceil((depth - 2.0 * m) / 0.4))
		nz = int(ceil((w - 2.0 * m) / 0.4))
		for ix in nx + 1:
			for iz in nz + 1:
				var p2: Vector3 = xf * Vector3(m + (depth - 2.0 * m) * float(ix) / float(nx), 0.0, -w / 2.0 + m + (w - 2.0 * m) * float(iz) / float(nz))
				var q2: Vector3 = oxf.affine_inverse() * p2
				if q2.x > 0.05 and q2.x < od - 0.05 and absf(q2.z) < ow / 2.0 - 0.05:
					return true
	return false


func _casa_atravessa(xf: Transform3D, depth: float, w: float, so_corredores := false) -> bool:
	# só conta SOBREPOSIÇÃO de verdade (pontos bem dentro da outra caixa): as casas vizinhas se encostam de lado de propósito
	# (+0,24 m de largura) e antes isso encurtava quase todas as casas para 2,4 m de fundo (finas como papelão vistas dos becos)
	for o in _casas_postas:
		if so_corredores and not o.has("corr"):
			continue                                      # só becos e passagens contam (casas vizinhas podem se sobrepor por trás sem ninguém ver)
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
func make_casa(w: float, floors: int, wall: String, wood: String, depth: float, balcony: bool, lit_p: float, simple: bool, haunted := false, entrada := {}, sala: Node3D = null) -> Node3D:
	var c := Node3D.new()
	c.name = "Casa"
	_kit2 = _rng_f.randf() < 0.65
	rb2_beiral = []
	_jan_atual = []
	_vaos_atual = []
	_mod_atual = []
	_pl_atual = []
	var fh := 4.0
	var up := 3.4
	var height := fh + (floors - 1) * up
	var aber: Array = []
	if sala != null:
		var sd: Vector3 = sala.get_meta("dim")
		height = maxf(4.0, sd.y + 0.4)
		fh = height
		aber = sala.get_meta("aberturas", [])
		_casca_sala(c, w, depth, height, wall, aber)
		var xs := Interiores.ESCALA_SALA
		# a sala (origem no canto da parede da frente) gira 90°: o "fundo" dela vira o +x da casa e a largura dela vira o z
		sala.transform = Transform3D(Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * xs), Vector3(0.3 * xs + SHELL, 0.0, sd.x * 0.5))
		c.add_child(sala)
		c.set_meta("sala_id", entrada["id"])
	elif floors >= 2 and _rng_f.randf() < 0.65:
		# sobrado ouro-pretano: térreo de pedra rústica e andar de cima caiado (corpo dividido em dois blocos, sem faces sobrepostas)
		_box(c, "CorpoPedra", Vector3(depth, fh + 4.0, w), Vector3(depth / 2.0, (fh - 4.0) / 2.0, 0), "muro", true)
		_box(c, "Corpo", Vector3(depth, height - fh, w), Vector3(depth / 2.0, (height + fh) / 2.0, 0), wall, true)
	else:
		_box(c, "Corpo", Vector3(depth, height + 4.0, w), Vector3(depth / 2.0, height / 2.0 - 2.0, 0), wall, true)
	# oclusão: o corpo da casa esconde o que está atrás (só Forward+/Mobile; ligado em project.godot)
	if sala == null:
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
	# silhueta do telhado: chaminé de pedra com boné (algumas casas) e antena de TV (poucas, é 1961): quebra o ar de "caixa com tampa"
	if _rng_f.randf() < 0.45:
		var cz := _rng_f.randf_range(-w * 0.3, w * 0.3)
		var cxk := rcx + (depth + 1.4) * 0.17
		var cyb := ry + rise * 0.62 - 0.25
		rb.box("muro", Vector3(0.75, 1.9, 0.75), Vector3(cxk, cyb + 0.95, cz))
		rb.box("cantaria", Vector3(0.95, 0.14, 0.95), Vector3(cxk, cyb + 1.95, cz))
		rb.box("janela_escura", Vector3(0.45, 0.05, 0.45), Vector3(cxk, cyb + 2.03, cz))
		rb.box("ferro", Vector3(0.06, 0.4, 0.06), Vector3(cxk + 0.3, cyb + 2.2, cz - 0.3))
	if _rng_f.randf() < 0.16:
		var az := _rng_f.randf_range(-w * 0.25, w * 0.25)
		rb.box("ferro", Vector3(0.04, 2.1, 0.04), Vector3(rcx, ry + rise + 1.0, az))
		for k in 3:
			rb.box("ferro", Vector3(0.03, 0.03, 1.0 - k * 0.22), Vector3(rcx, ry + rise + 0.8 + k * 0.45, az))
	_mesh_node(c, "Telhado", rb.commit())
	_telhado_colisao(c, Vector3(rcx, ry + rise / 2.0, 0), depth - 0.2, rise, w - 1.0, 0.0)      # o telhado também é sólido (antes dava para atravessá-lo pelo morro); a colisão fica DENTRO do lote: o beral não prende quem sobe um beco ao lado

	var b := _batch()
	var ncor := maxi(1, int(ceil(w)))
	for k in ncor:
		var zc := -w / 2.0 + (k + 0.5) * w / ncor
		_modulo(b, "cornija_1m", Kit.fachada(Vector3(0.0, height - 0.2, zc), Vector3(w / ncor, 1.0, 1.0)))      # cornija com dentículos
	for k in int(w / 0.9):
		var z := -w / 2.0 + 0.5 + k * 0.9
		_modulo(b, "cachorro_beiral", Kit.fachada(Vector3(0.0, height - 0.04, z)), {"madeira": "madeira_natural"})   # cachorros do beiral
	if floors >= 2 and _rng.randf() < 0.5:
		b.box("cantaria", Vector3(0.18, 0.16, w + 0.1), Vector3(-0.07, fh - 0.2, 0))           # cordão
	if _rng.randf() < 0.55:
		for end: float in [-1.0, 1.0]:                                                                     # cunhais de pedra
			for k in int(height / 0.7):
				b.box("cantaria", Vector3(0.08, 0.34, 0.5 if k % 2 == 0 else 0.36), Vector3(-0.05, k * 0.7 + 0.4, end * (w / 2.0 - 0.22)))

	var cols := maxi(2, int(round(w / 2.7)))
	var col_z: Array[float] = []
	var util := w - 2.0 * 0.62                 # largura entre os cunhais (pedra da quina 0,52 m + folga): nenhuma janela/porta sobre o cunhal
	for i in cols:
		col_z.append(-util / 2.0 + (i + 0.5) * util / cols)
	var door_i := _rng.randi_range(0, cols - 1)
	if _porta_central:
		door_i = (cols - 1) / 2         # casa colada num beco: a porta no meio, longe da parede da escada
	var dz := col_z[door_i]
	if sala != null:
		dz = 0.0                      # a porta da casa é o vão da parede da frente da sala (no meio)
	c.set_meta("door_z", dz)
	c.set_meta("altura", height)
	c.set_meta("vaos", _vaos_atual)
	c.set_meta("modulos", _mod_atual)
	c.set_meta("largura", w)
	c.set_meta("andares", floors)
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
	var pb := _batch()          # a porta é uma malha própria (nó "Porta"): antes ficava misturada às molduras do lote e sumia em algumas casas
	# porta com moldura de cantaria; em arco nos sobrados "arqueados"
	var arched := (not simple) and _rng.randf() < 0.5
	# a porta nunca tem a cor da parede: tons claros/ocre viram madeira escura, para ela se destacar da fachada
	var wood_porta := wood
	if wood == "madeira_ocre" or wood == "madeira_branca" or wood == "madeira_natural":
		# portas coloniais mineiras são coloridas (azul, verde, vermelho-sangue); madeira escura demais virava um buraco preto sob a luz fraca
		wood_porta = ["madeira_azul", "madeira_verde", "madeira_vermelha", "madeira_escura", "madeira_ocre", "madeira_ocre"][_rng_f.randi() % 6]
	if arched:
		var dr := 0.72
		var dh := 3.0
		for sz: float in [-1.0, 1.0]:
			pb.box("cantaria", Vector3(0.2, dh - dr + 0.1, 0.22), Vector3(-0.08, (dh - dr) / 2.0, dz + sz * (dr + 0.11)))
		pb.arch("cantaria", Vector3(-0.08, dh - dr, dz), dr + 0.11, 0.22, 0.2, 9)
		pb.box(wood_porta, Vector3(0.08, dh - dr, dr * 2.0), Vector3(-0.18, (dh - dr) / 2.0, dz))
		pb.half_disc("vidro_luz", Vector3(-0.225, dh - dr, dz), dr * 0.86)                                       # bandeira em arco com vidro aceso
		for k in 5:                                                                                               # raios de ferro da bandeira
			var ak := PI * (float(k) + 0.5) / 5.0
			pb.box("ferro", Vector3(0.02, 0.025, dr * 0.84), Vector3(-0.232, dh - dr + sin(ak) * dr * 0.42, dz + cos(ak) * dr * 0.42), Vector3(ak, 0, 0))
		for k in 4:                                                                                               # tábuas verticais em relevo + cintas de ferro
			pb.box("madeira_escura", Vector3(0.025, dh - dr - 0.1, 0.035), Vector3(-0.232, (dh - dr) / 2.0, dz - 0.54 + k * 0.36))
		for yy: float in [0.55, 1.45, 2.2]:
			pb.box("ferro", Vector3(0.03, 0.09, dr * 2.0 - 0.1), Vector3(-0.236, yy, dz))
		pb.sphere("ouro_velho", 0.07, Vector3(-0.255, 1.25, dz + 0.16), 8, 5)                                    # argola/maçaneta
		pb.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 0.7, dz - 0.34))
		pb.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 0.7, dz + 0.34))
		pb.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 1.9, dz - 0.34))
		pb.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 1.9, dz + 0.34))
	else:
		var cabe_dupla := absf(dz) + 1.17 <= w / 2.0 - 0.55          # a porta dupla (2,3 m com o batente) não pode tocar o cunhal da quina
		if (_kit2 and sala == null and _rng_f.randf() < 0.5) or (not cabe_dupla and sala == null):
			_modulo(pb, "porta_bandeira", Kit.fachada(Vector3(0.0, 0.0, dz)), {"madeira": wood_porta})          # porta de uma folha com bandeira em arco (1,6 m)
		else:
			_modulo(pb, "porta_dupla", Kit.fachada(Vector3(0.0, 0.0, dz), Vector3(1.0, 1.06, 1.0)), {"madeira": wood_porta})
		_vaos_atual.append({"z": dz, "peitoril": 0.0, "topo": 3.0, "w": 2.3 if cabe_dupla else 1.6, "porta": true})   # a porta principal também é um vão (barra de pedra e cunhal a respeitam)
	if arched:
		pb.box("cantaria", Vector3(0.5, 0.15, 2.0), Vector3(-0.25, -0.03, dz))                     # soleira da porta em arco
	var dn := 1.25 if not arched else 1.15
	if dz + dn > w / 2.0 - 0.2:
		dn = -dn
	pb.box("ouro_velho", Vector3(0.02, 0.10, 0.18), Vector3(-0.03, 2.2, dz + dn))   # número da casa na parede (do lado em que há parede)
	if entrada.is_empty():
		# casa FECHADA (não dá para entrar): duas tábuas pregadas em X sobre a porta e um cadeado enferrujado
		# (tábuas do tamanho do vão: antes passavam da moldura e pareciam vigas)
		for sg: float in [-1.0, 1.0]:
			pb.box("madeira_escura", Vector3(0.04, 0.16, 2.55), Vector3(-0.27, 1.3, dz), Vector3(sg * 1.0, 0.0, 0.0))
			for pz: float in [-0.5, 0.5]:
				pb.box("ferro", Vector3(0.05, 0.04, 0.04), Vector3(-0.30, 1.3 + sg * pz * 1.55, dz + pz))
		pb.box("ferro_ferrugem", Vector3(0.07, 0.2, 0.14), Vector3(-0.31, 1.05, dz + 0.55))
	var porta_no := _mesh_node(c, "Porta", pb.commit())
	porta_no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not entrada.is_empty():
		_porta_entrada(c, entrada, dz, w)
		_placa_entrada(c, entrada, dz)

	var bal_cols: Array[int] = []
	if balcony and floors >= 2:
		for i in cols:
			if cols < 3 or (i != 0 and i != cols - 1) or _rng.randf() < 0.3:
				bal_cols.append(i)
		if bal_cols.is_empty():
			bal_cols.append(door_i)
	if sala != null:
		# janelas da fachada = os vãos da parede da sala (mesma posição e tamanho): vidro de verdade, sem foto
		var xs2 := Interiores.ESCALA_SALA
		var sdw: float = float(sala.get_meta("dim").x)
		for j in aber:
			_window(b, Vector3(0, float(j["y"]) * xs2, sdw * 0.5 - float(j["x"]) * xs2), float(j["w"]) * xs2, float(j["h"]) * xs2, wood, false, false, false, false, true)
	for i in cols:
		if sala != null:
			break
		if i != door_i:
			_window(b, Vector3(0, 2.0, col_z[i]), 1.0, 1.5, wood, _rng.randf() < lit_p * 0.6, not simple and _rng.randf() < 0.4)
		for k in range(1, floors):
			var y0 := fh + (k - 1) * up
			if k == 1 and bal_cols.has(i):
				_window(b, Vector3(0, y0 + 1.33, col_z[i]), 1.1, 2.2, wood, _rng.randf() < lit_p, false, true, arched)   # porta-balcão acima da laje da sacada
			else:
				_window(b, Vector3(0, y0 + 1.65, col_z[i]), 1.0, 1.7, wood, _rng.randf() < lit_p, false, false, arched)
	if not bal_cols.is_empty() and not simple:
		if _kit2:
			for bi in bal_cols:                                                       # uma sacada de ferro forjado em cada porta-balcão
				_modulo(b, "sacada_ferro", Kit.fachada(Vector3(0.0, fh, col_z[bi])))
		else:
			_balcony(b, col_z[bal_cols[0]] - 0.95, col_z[bal_cols[bal_cols.size() - 1]] + 0.95, fh, wood)
	if not simple and _rng.randf() < 0.4:
		var chz := _rng.randf_range(-w * 0.3, w * 0.3)
		_modulo(b, "chamine", Transform3D(Basis.IDENTITY, Vector3(depth / 2.0 - 0.2, height + rise - 0.55, chz)))      # chaminé de pedra do kit (embute no telhado)
		if _rng.randf() < 0.4:
			c.add_child(Realismo.fumaca(Vector3(depth / 2.0 - 0.2, height + rise + 1.15, chz)))
	if haunted and floors >= 2:
		var hi := (door_i + 1) % cols
		_haunted_window(c, Vector3(-0.18, fh + 1.65, col_z[hi]))
	# --- detalhes de arquitetura e de abandono (para a fachada não parecer uma caixa lisa) ---
	# cunhais de cantaria nas duas quinas (blocos alternados, como nos sobrados de Minas)
	for qz: float in [-1.0, 1.0]:
		if _kit2:                                                                     # cunhal do kit 2: blocos com bisel e desgaste
			var ky := 0.0
			while ky < height - 0.9:
				var zq := qz * (w / 2.0 - 0.26)
				var cobre := false                          # trecho do cunhal que cairia sobre uma janela/porta (salas visitáveis): pula
				for v in _vaos_atual:
					if absf(zq - float(v["z"])) < float(v["w"]) * 0.5 + 0.28 and ky + 1.0 > float(v["peitoril"]) and ky < float(v["topo"]):
						cobre = true
				if not cobre:
					_modulo(b, "cunhal_1m", Kit.fachada(Vector3(0.0, ky, zq)))
				ky += 1.0
			continue
		var qy := 0.25
		var qi := 0
		while qy < height - 0.4:
			var longo := (qi % 2 == 0)
			b.box("cantaria", Vector3(0.13, 0.36, 0.52 if longo else 0.30), Vector3(-0.065, qy + 0.18, qz * (w / 2.0 - (0.26 if longo else 0.15))))
			qy += 0.5
			qi += 1
	if _kit2:
		# embasamento de pedra rústica na frente do soco (pula o vão da porta) e beiral de telhas capa-e-canal na beira do telhado
		var ez := -w / 2.0 + 0.5
		while ez <= w / 2.0 - 0.5:
			var livre_e := absf(ez - dz) > 1.3
			for v in _vaos_atual:                              # pula TODO vão que desce até o chão (portas de loja, não só a porta principal)
				if float(v["peitoril"]) < 0.6 and absf(ez - float(v["z"])) < float(v["w"]) * 0.5 + 0.55:
					livre_e = false
			if livre_e:
				_modulo(b, "embasamento_1m", Kit.fachada(Vector3(-0.26, 0.12, ez)))
			ez += 1.0
		var tz := -w / 2.0 + 0.5
		while tz <= w / 2.0 - 0.45:
			rb2_beiral.append(tz)
			tz += 1.0
	# caibros aparentes sob o beiral (as pontas das vigas do telhado)
	var zc := -w / 2.0 + 0.35
	while zc < w / 2.0 - 0.2:
		b.box("madeira_escura", Vector3(0.78, 0.07, 0.08), Vector3(-0.52, height + 0.075, zc))
		zc += 0.55
	# reboco caído mostrando a alvenaria de pedra por baixo (entre as aberturas)
	for i in range(maxi(cols - 1, 0)):
		if _rng.randf() < 0.55:
			var cz := (col_z[i] + col_z[i + 1]) * 0.5 + _rng.randf_range(-0.25, 0.25)
			var cy := _rng.randf_range(0.9, maxf(1.2, height - 1.4))
			var pw := _rng.randf_range(0.55, 1.05)
			var ph := _rng.randf_range(0.45, 0.95)
			var invade := false                                       # o remendo (com as lascas, ~1,3x) não pode encostar em janela/porta
			for v in _vaos_atual:
				if absf(cz - float(v["z"])) < pw * 0.65 + float(v["w"]) * 0.5 + 0.2 and cy + ph * 0.65 > float(v["peitoril"]) - 0.2 and cy - ph * 0.65 < float(v["topo"]) + 0.2:
					invade = true
			if absf(cz - dz) < 1.7 and cy + ph * 0.65 > 2.1 and cy - ph * 0.65 < 2.85:
				invade = true                                          # lugar do azulejo com o número, ao lado da porta
			if invade:
				continue
			b.box("muro", Vector3(0.025, ph, pw), Vector3(-0.015, cy, cz))
			b.box("muro", Vector3(0.025, ph * 0.55, pw * 0.7), Vector3(-0.02, cy + ph * 0.4, cz + pw * 0.28), Vector3(0, 0, 0.0))
			b.box("muro", Vector3(0.025, ph * 0.5, pw * 0.5), Vector3(-0.02, cy - ph * 0.38, cz - pw * 0.30))
	var nz := 99.0
	if not simple:
		# número da casa em azulejo português (branco com barra azul), ao lado da porta
		nz = 99.0
		for lado_n: float in [1.0, -1.0]:                                       # dos dois lados da porta, o primeiro que couber
			var meia_porta := 0.8
			for v in _vaos_atual:
				if bool(v["porta"]) and absf(float(v["z"]) - dz) < 0.01 and float(v["peitoril"]) < 0.1:
					meia_porta = float(v["w"]) * 0.5
			var cand := dz + lado_n * (meia_porta + 0.25)                       # logo depois do batente da porta principal
			var ok_n := absf(cand) < w * 0.5 - 0.75                            # longe do cunhal de pedra da quina
			for v in _vaos_atual:                                               # e de qualquer outra janela/porta
				if absf(float(v["z"]) - dz) < 0.01 and float(v["peitoril"]) < 0.1:
					continue
				if absf(float(v["z"]) - cand) < float(v["w"]) * 0.5 + 0.15 and 2.45 > float(v["peitoril"]) - 0.15 and 2.45 < float(v["topo"]) + 0.15:
					ok_n = false
			if ok_n:
				nz = cand
				break
	if not simple and nz < 50.0:
		b.box("listra_branca", Vector3(0.016, 0.21, 0.21), Vector3(-0.012, 2.45, nz))
		for ax: Array in [[0.0, 0.1], [0.0, -0.1]]:
			b.box("listra_azul", Vector3(0.02, 0.018, 0.21), Vector3(-0.014, 2.45 + float(ax[1]), nz))
			b.box("listra_azul", Vector3(0.02, 0.21, 0.018), Vector3(-0.014, 2.45, nz + float(ax[1])))
		var num := Label3D.new()
		num.name = "Numero"
		num.text = str(_rng.randi_range(3, 219))
		num.font_size = 64
		num.pixel_size = 0.0022
		num.modulate = Color(0.12, 0.2, 0.55)
		num.outline_size = 0
		num.shaded = true
		num.position = Vector3(-0.022, 2.45, nz)
		num.rotation.y = -PI / 2.0
		c.add_child(num)
	if not simple:
		# fiação de 1961 correndo pela fachada em isoladores de porcelana (só onde não cruza janela)
		if _rng.randf() < 0.6:
			var yf := fh - 0.32 if floors >= 2 else height - 0.55
			var livre := true
			for v in _vaos_atual:
				if yf > float(v["peitoril"]) - 0.08 and yf < float(v["topo"]) + 0.08:
					livre = false
			if livre:
				var iz := -w / 2.0 + 0.45
				while iz <= w / 2.0 - 0.4:
					b.box("ferro", Vector3(0.09, 0.02, 0.02), Vector3(-0.045, yf, iz))                                   # suporte
					b.cylinder("listra_branca", 0.028, 0.034, 0.07, Vector3(-0.1, yf + 0.03, iz), Vector3.ZERO, 8)         # isolador
					iz += 1.7
				b.box("ferro", Vector3(0.012, 0.012, w - 0.8), Vector3(-0.1, yf + 0.055, 0.0))                          # fio
				b.box("ferro", Vector3(0.012, 0.012, w - 0.8), Vector3(-0.1, yf + 0.025, 0.0))
		b.box("ferro", Vector3(0.12, 0.09, w + 0.4), Vector3(-0.92, height + 0.09, 0))               # calha do beiral
		if _rng.randf() < 0.55:
			var dz2 := (w / 2.0 - 0.05) * (1.0 if _rng.randf() < 0.5 else -1.0)
			b.box("ferro", Vector3(0.8, 0.09, 0.09), Vector3(-0.52, height + 0.05, dz2))
			b.box("ferro", Vector3(0.09, height + 0.3, 0.09), Vector3(-0.21, height / 2.0 - 0.1, dz2 - signf(dz2) * 0.08))   # tubo de queda (na frente do cunhal, não através dele)
		if sala == null and _rng.randf() < 0.22:
			_sign(c, b, col_z[(door_i + 1) % cols])
	var solidos := [AABB(Vector3(0.0, -2.0, -w / 2.0), Vector3(depth, height + 4.0, w)),
		AABB(Vector3(rcx - (depth + 1.4) / 2.0, ry - 0.05, -(w + 0.5) / 2.0), Vector3(depth + 1.4, rise + 0.1, w + 0.5))]
	for fl in b.floating(solidos):
		_flutuando.append("casa w=%.1f: %s" % [w, fl])
	for tz2 in rb2_beiral:                                                            # beiral de telhas na beira da frente
		_modulo(b, "beiral_telhas", Kit.fachada(Vector3(-0.5, height + 0.17, float(tz2))))
	if not simple:
		_fundos_e_laterais(c, w, depth, height, floors, fh, wood, sala != null)
	c.set_meta("fundo", depth)
	# auditoria de z-fighting da fachada: peças no mesmo plano (inclui a face do corpo da casa) piscam
	b._boxes.append(["corpo_da_casa", AABB(Vector3(0.0, -2.0, -w / 2.0), Vector3(depth, height + 2.0, w)), false])
	for pc in b.coplanares(6):
		_pisca_fachada.append("w=%.1f: %s" % [w, pc])
	b._boxes.pop_back()
	var det := _mesh_node(c, "Detalhes", b.commit())
	det.layers = CAMADA_DETALHE                 # molduras, portas e janelas: sem mancha/reboco caído projetado por cima
	det.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # molduras e grades não precisam de sombra (menos uma passada por casa)
	c.set_meta("janelas", _jan_atual)
	_vaos_atual = []          # listas novas: janelas feitas depois (igreja, capelas) não entram na ficha desta casa
	_mod_atual = []
	c.set_meta("plantas_janela", _pl_atual)
	return c


## FUNDOS E LATERAIS (antes eram a parede lisa do bloco): no zigue-zague a rua de cima enxerga os fundos das casas da rua de baixo.
## Fundos: janelas de cantaria com venezianas fechadas, porta de quintal, cunhais, barra de pedra, caibros do beiral, calha e condutor.
## Laterais: barra de pedra, cunhal na quina de trás e janelinha no andar de cima. Tudo em nós girados (o -X local aponta para fora da parede).
func _fundos_e_laterais(c: Node3D, w: float, depth: float, height: float, floors: int, fh: float, wood: String, visitavel: bool) -> void:
	var fb := _batch()
	# ---- fundos: plano da parede em x=0 do nó girado 180° (fica em x=depth da casa)
	var n := maxi(1, int((w - 1.0) / 2.7))
	var zs: Array[float] = []
	for i in n:
		zs.append(-w / 2.0 + w * (float(i) + 0.5) / float(n))
	var porta_i := -1          # porta de quintal desligada: o terreno atrás varia muito no zigue-zague e a porta podia ficar no ar
	for andar in floors:
		var base_y := 0.0 if andar == 0 else fh + (andar - 1) * 3.4
		for i in n:
			if andar == 0 and i == porta_i:
				_porta_fundos(fb, zs[i], wood)
			elif andar > 0 or height > 3.4:
				_janela_fundos(fb, zs[i], base_y + (1.7 if andar == 0 else 1.6), 0.85, 1.25, wood)
	_parede_detalhes(fb, w, height, true)
	var nf := _mesh_node(c, "Fundos", fb.commit())
	nf.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(depth, 0.0, 0.0))
	nf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nf.layers = CAMADA_DETALHE
	# ---- laterais
	for lado: float in [1.0, -1.0]:
		var lb := _batch()
		if floors >= 2 and depth > 4.5:
			_janela_fundos(lb, 0.0, fh + 1.6, 0.7, 1.05, wood)
		_parede_detalhes(lb, depth, height, false)
		var nl := _mesh_node(c, "Lateral_%d" % int(lado), lb.commit())
		nl.transform = Transform3D(Basis(Vector3.UP, lado * PI / 2.0), Vector3(depth / 2.0, 0.0, lado * w / 2.0))
		nl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nl.layers = CAMADA_DETALHE


## Janela de fundos (parede em x=0, fora = -X): moldura de cantaria, peitoril, vão escuro e venezianas de madeira fechadas.
func _janela_fundos(b: MeshBatch, z: float, y: float, jw: float, jh: float, wood: String) -> void:
	b.box("cantaria", Vector3(0.12, 0.09, jw + 0.30), Vector3(-0.06, y - jh * 0.5 - 0.045, z))          # peitoril
	b.box("cantaria", Vector3(0.09, 0.12, jw + 0.22), Vector3(-0.045, y + jh * 0.5 + 0.06, z))          # verga
	for sz: float in [-1.0, 1.0]:
		b.box("cantaria", Vector3(0.09, jh, 0.10), Vector3(-0.045, y, z + sz * (jw * 0.5 + 0.05)))      # ombreiras
	b.box("janela_escura", Vector3(0.02, jh, jw), Vector3(-0.012, y, z))
	for sz: float in [-1.0, 1.0]:                                                                        # duas folhas fechadas, com travessas
		b.box(wood, Vector3(0.035, jh - 0.06, jw * 0.5 - 0.03), Vector3(-0.04, y, z + sz * jw * 0.25))
		for ty: float in [-0.3, 0.3]:
			b.box(wood, Vector3(0.02, 0.06, jw * 0.5 - 0.06), Vector3(-0.065, y + ty * jh, z + sz * jw * 0.25))
	b.box("ferro", Vector3(0.03, 0.03, 0.12), Vector3(-0.07, y, z))                                    # tranca


## Porta de quintal nos fundos: batentes de cantaria, porta de tábuas com ferragens e degrau.
func _porta_fundos(b: MeshBatch, z: float, wood: String) -> void:
	b.box("cantaria", Vector3(0.10, 0.12, 1.25), Vector3(-0.05, 2.21, z))
	for sz: float in [-1.0, 1.0]:
		b.box("cantaria", Vector3(0.10, 2.15, 0.12), Vector3(-0.05, 1.08, z + sz * 0.56))
	b.box(wood, Vector3(0.05, 2.1, 1.0), Vector3(-0.03, 1.05, z))
	for ty: float in [0.35, 1.05, 1.75]:
		b.box("ferro", Vector3(0.02, 0.05, 0.55), Vector3(-0.065, ty, z - 0.18))                         # dobradiças compridas
	b.box("ferro", Vector3(0.03, 0.12, 0.04), Vector3(-0.07, 1.0, z + 0.38))
	b.box("cantaria", Vector3(0.45, 0.16, 1.3), Vector3(-0.22, 0.06, z))                                # degrau


## Barra de pedra no pé, cunhais nas quinas e (nos fundos) caibros, calha e condutor. `largura` = comprimento da parede.
func _parede_detalhes(b: MeshBatch, largura: float, height: float, fundos: bool) -> void:
	b.box("muro", Vector3(0.07, 1.9, largura + 0.02), Vector3(-0.035, -0.15, 0.0))                     # barra de pedra (desce para dentro do terreno)
	b.box("cantaria", Vector3(0.10, 0.07, largura + 0.04), Vector3(-0.05, 0.82, 0.0))
	for qz: float in ([-1.0, 1.0] if fundos else [1.0]):
		var qy := 0.9
		var qi := 0
		while qy < height - 0.4:
			var longo := qi % 2 == 0
			b.box("cantaria", Vector3(0.12, 0.36, 0.50 if longo else 0.30), Vector3(-0.06, qy + 0.18, qz * (largura * 0.5 - (0.25 if longo else 0.15))))
			qy += 0.5
			qi += 1
	if fundos:
		var zc := -largura / 2.0 + 0.35
		while zc < largura / 2.0 - 0.2:
			b.box("madeira_escura", Vector3(0.42, 0.07, 0.08), Vector3(-0.22, height + 0.075, zc))       # caibros do beiral de trás
			zc += 0.55
		b.box("ferro", Vector3(0.10, 0.08, largura + 0.2), Vector3(-0.45, height + 0.06, 0.0))         # calha
		var dz := (largura * 0.5 - 0.12) * (1.0 if _rng.randf() < 0.5 else -1.0)
		b.box("ferro", Vector3(0.08, height + 0.2, 0.08), Vector3(-0.17, height * 0.5 - 0.05, dz))       # condutor até o chão (na frente do cunhal)


## Põe um módulo do kit no lote E registra (nome + posição exata) na ficha da casa, para a planta e a conferência dos módulos.
func _modulo(lote: MeshBatch, nome: String, xf: Transform3D, mapa := {}) -> void:
	lote.malha(Kit.mesh(nome), xf, mapa)
	_mod_atual.append([nome, xf])


## Casca externa de uma casa visitável: lâminas finas por FORA das paredes da sala (a parede interna é a da sala). A frente tem o vão da porta
## e os vãos das janelas (mesmos da parede interna), então a rua enxerga a sala e a sala enxerga a rua.
func _casca_sala(c: Node3D, w: float, depth: float, height: float, wall: String, aber: Array) -> void:
	var t := SHELL
	var xs := Interiores.ESCALA_SALA
	_box(c, "CascaFundos", Vector3(t, height + 4.0, w), Vector3(depth - t / 2.0, height / 2.0 - 2.0, 0.0), wall, false)
	for sg: float in [-1.0, 1.0]:
		_box(c, "CascaLado", Vector3(depth, height + 4.0, t), Vector3(depth / 2.0, height / 2.0 - 2.0, sg * (w / 2.0 - t / 2.0)), wall, false)
	var sdw := w - SHELL * 0.0 - 0.75 - 2.0 * t          # largura da sala ampliada
	var vaos: Array = [[-0.94, 0.94, -2.0, 3.06]]       # porta (vão de 1,5 m da sala x 1,25)
	for j in aber:
		var zc := sdw * 0.5 - float(j["x"]) * xs
		var yc := float(j["y"]) * xs
		vaos.append([zc - float(j["w"]) * xs * 0.43, zc + float(j["w"]) * xs * 0.43, yc - float(j["h"]) * xs * 0.44, yc + float(j["h"]) * xs * 0.44])
	var zs: Array[float] = [-w / 2.0, w / 2.0]
	for v in vaos:
		zs.append(float(v[0]))
		zs.append(float(v[1]))
	zs.sort()
	var fb := _batch()
	for i in zs.size() - 1:
		var za: float = zs[i]
		var zb: float = zs[i + 1]
		if zb - za < 0.002:
			continue
		var cortes: Array = []
		for v in vaos:
			if float(v[0]) <= za + 0.001 and float(v[1]) >= zb - 0.001:
				cortes.append([float(v[2]), float(v[3])])
		cortes.sort_custom(func(m: Array, n2: Array) -> bool: return float(m[0]) < float(n2[0]))
		var y := -2.0
		for cr in cortes:
			if float(cr[0]) - y > 0.01:
				fb.box(wall, Vector3(t, float(cr[0]) - y, zb - za), Vector3(t / 2.0, (y + float(cr[0])) / 2.0, (za + zb) / 2.0))
			y = maxf(y, float(cr[1]))
		if height + 0.2 - y > 0.01:
			fb.box(wall, Vector3(t, height + 0.2 - y, zb - za), Vector3(t / 2.0, (y + height + 0.2) / 2.0, (za + zb) / 2.0))
	_mesh_node(c, "CascaFrente", fb.commit())


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
		var lugar := _lugar_livre_na_fachada(casa, w, altura, cw, ch)       # nunca em cima de janela ou porta
		if lugar == Vector2.INF:
			dc.free()
			continue
		dc.size = Vector3(cw, 0.8, ch)
		dc.transform = Transform3D(basis, Vector3(0.1, lugar.y, lugar.x))
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
	_detalhes_parede(casa, w, altura, basis)


## Retângulo livre (cw x ch) na fachada, longe 25 cm de qualquer janela/porta. Devolve (z, y) do centro, ou Vector2.INF se não houver.
func _lugar_livre_na_fachada(casa: Node3D, w: float, altura: float, cw: float, ch: float) -> Vector2:
	var vaos: Array = casa.get_meta("vaos", [])
	for t in 14:
		var z := _rng.randf_range(-w * 0.5 + cw * 0.5 + 0.3, w * 0.5 - cw * 0.5 - 0.3)
		var y := _rng.randf_range(0.6 + ch * 0.5, maxf(0.7 + ch * 0.5, altura - 0.5 - ch * 0.5))
		if cw > w - 0.7:
			return Vector2.INF
		var ok := true
		for v in vaos:
			var vz := float(v["z"])
			var vw := float(v["w"]) * 0.5 + 0.25
			if absf(z - vz) < cw * 0.5 + vw and y + ch * 0.5 > float(v["peitoril"]) - 0.25 and y - ch * 0.5 < float(v["topo"]) + 0.25:
				ok = false
				break
		if ok:
			return Vector2(z, y)
	return Vector2.INF


## Detalhes de parede realistas (decalques): lágrimas de chuva sob cada peitoril e sob o beiral, trincas saindo dos cantos das janelas,
## limo e salitre no pé da parede. Cada casa sorteia os seus, então nenhuma fachada fica igual à outra.
func _detalhes_parede(casa: Node3D, w: float, altura: float, basis: Basis) -> void:
	var vaos: Array = casa.get_meta("vaos", [])
	var tex_e := load("res://assets/textures/escorrido.png") as Texture2D
	var tex_r := load("res://assets/textures/rachadura.png") as Texture2D
	var tex_l := load("res://assets/textures/limo.png") as Texture2D
	var novo := func(nome: String, tex: Texture2D, tam: Vector3, pos: Vector3, giro := 0.0) -> void:
		var d := Decal.new()
		d.name = nome
		d.texture_albedo = tex
		d.size = tam
		d.transform = Transform3D(basis * Basis(Vector3.UP, giro), pos)
		d.distance_fade_enabled = true
		d.distance_fade_begin = 38.0
		d.distance_fade_length = 12.0
		d.upper_fade = 0.1
		d.lower_fade = 0.1
		d.normal_fade = 0.5                 # não escorre para os lados de molduras e peitoris
		d.cull_mask = 1
		casa.add_child(d)
	var n := 0
	for v in vaos:
		if bool(v["porta"]) or float(v["peitoril"]) < 0.6:
			continue
		if _rng.randf() < 0.65:
			var hh := minf(float(v["peitoril"]) - 0.15, _rng.randf_range(0.9, 2.1))
			if hh > 0.4:
				novo.call("Escorrido_%d" % n, tex_e, Vector3(float(v["w"]) * _rng.randf_range(0.9, 1.25), 0.5, hh), Vector3(0.08, float(v["peitoril"]) - hh * 0.5 - 0.03, float(v["z"])))
				n += 1
	if _rng.randf() < 0.5:
		novo.call("EscorridoBeiral", tex_e, Vector3(w * 0.95, 0.5, _rng.randf_range(0.9, 1.6)), Vector3(0.08, altura - 0.75, _rng.randf_range(-0.3, 0.3)))
	var trincas := _rng.randi_range(0, 2)
	for k in trincas:
		var jan: Array = vaos.filter(func(v: Dictionary) -> bool: return not bool(v["porta"]))
		if jan.is_empty():
			break
		var v: Dictionary = jan[_rng.randi() % jan.size()]
		var lado := 1.0 if _rng.randf() < 0.5 else -1.0
		var em_cima := _rng.randf() < 0.5
		var y := float(v["topo"]) + 0.45 if em_cima else float(v["peitoril"]) - 0.45
		if y < 0.5 or y > altura - 0.4:
			continue
		novo.call("Trinca_%d" % k, tex_r, Vector3(0.8, 0.5, 1.0), Vector3(0.08, y, float(v["z"]) + lado * (float(v["w"]) * 0.5 + 0.25)), _rng.randf_range(-0.7, 0.7) + (PI if em_cima else 0.0))
	if _rng.randf() < 0.6:
		novo.call("Limo", tex_l, Vector3(w * 0.98, 0.6, _rng.randf_range(0.7, 1.2)), Vector3(0.08, 0.35, 0.0))
	# fundos: limo e escorridos também (a rua de cima enxerga)
	var fundo := float(casa.get_meta("fundo", 0.0))
	if fundo > 1.0:
		var giro := Basis(Vector3.UP, PI)
		var dl := Decal.new()
		dl.name = "LimoFundos"
		dl.texture_albedo = tex_l
		dl.size = Vector3(w * 0.98, 0.6, _rng.randf_range(0.9, 1.4))
		dl.transform = Transform3D(giro * basis, Vector3(fundo - 0.08, 0.35, 0.0))
		dl.distance_fade_enabled = true
		dl.distance_fade_begin = 38.0
		dl.distance_fade_length = 12.0
		dl.cull_mask = 1
		casa.add_child(dl)
		var de := Decal.new()
		de.name = "EscorridoFundos"
		de.texture_albedo = tex_e
		de.size = Vector3(w * 0.95, 0.6, _rng.randf_range(1.0, 1.8))
		de.transform = Transform3D(giro * basis, Vector3(fundo - 0.08, altura - 0.8, 0.0))
		de.distance_fade_enabled = true
		de.distance_fade_begin = 38.0
		de.distance_fade_length = 12.0
		de.cull_mask = 1
		casa.add_child(de)


const NOME_ENTRADA := {"benedita": "D. BENEDITA", "padaria": "PADARIA", "carpintaria": "CARPINTARIA", "venda": "VENDA", "escola": "ESCOLA",
		"barbearia": "BARBEARIA", "casarao": "CASARÃO", "sineiro": "SINEIRO"}


## Marca clara das casas que se PODE entrar: plaquinha de latão com o nome sobre a porta, luz quente no limiar e faixa dourada no batente.
## (As casas fechadas têm a porta tapada com tábuas em X.)
func _placa_entrada(c: Node3D, entrada: Dictionary, dz: float) -> void:
	var nome: String = NOME_ENTRADA.get(entrada["id"], "ENTRE")
	var g := _group(c, "PlacaDeEntrada", Transform3D(Basis.IDENTITY, Vector3(-0.1, 3.55, dz)))
	var b := _batch()
	b.box("ouro_velho", Vector3(0.05, 0.36, 1.5), Vector3(-0.03, 0, 0))
	b.box("placa_preta", Vector3(0.06, 0.30, 1.44), Vector3(-0.04, 0, 0))
	b.sphere("ouro_velho", 0.035, Vector3(-0.07, 0.0, -0.72), 6, 4)
	b.sphere("ouro_velho", 0.035, Vector3(-0.07, 0.0, 0.72), 6, 4)
	_mesh_node(g, "Malha", b.commit())
	var l := Label3D.new()
	l.name = "Texto"
	l.text = nome
	l.font = _sign_font()
	l.font_size = 72
	l.pixel_size = clampf(1.28 / (maxf(nome.length(), 4.0) * 0.62 * 72.0), 0.0009, 0.0022)
	l.modulate = Color(0.98, 0.86, 0.52)
	l.outline_modulate = Color(0.05, 0.03, 0.0)
	l.outline_size = 8
	l.shaded = false
	l.double_sided = false
	l.rotation.y = -PI / 2.0
	l.position = Vector3(-0.09, 0.0, 0.0)
	g.add_child(l)
	var luz := _lamp_light(g, Vector3(-0.9, -1.9, 0.0), 0.9)                       # luz quente que "vaza" pela porta e ilumina o degrau
	luz.omni_range = 4.5
	_halo(g, Vector3(-0.5, -2.2, 0.0), 2.4, "halo_quente")


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
	if c.has_meta("sala_id"):
		a.set_meta("real", true)         # sem teleporte: a porta abre e a sala está ali mesmo
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
		l.modulate = Color(0.80, 0.66, 0.38)           # dourado sem luz própria forte: legível à noite sem "brilhar" como neon
		l.outline_modulate = Color(0.08, 0.035, 0.01)
		l.outline_size = 10
		l.shaded = false
		l.double_sided = false
		l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		l.position = Vector3(bx, by, z + side * 0.032)
		l.rotation.y = 0.0 if side > 0.0 else PI
		c.add_child(l)
	_emblem(b, String(d[2]), bx, z)


var _font_cache: Font = null

## Fonte das placas: Playfair Display SC (OFL) vem junto no projeto, então a letra é a mesma em qualquer computador.
func _sign_font() -> Font:
	if _font_cache == null:
		var ff := load("res://assets/fonts/playfair-display-sc-latin-700-normal.woff2") as Font
		if ff != null:
			_font_cache = ff
		else:
			var sf := SystemFont.new()
			sf.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"])
			sf.font_weight = 700
			_font_cache = sf
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


var _rng_f := RandomNumberGenerator.new()      # sorteio próprio das flores: não mexe na sequência que define o desenho da vila
const FLORES := ["flor_vermelha", "flor_rosa", "flor_amarela", "flor_mix"]


## Cachos de flores coloridas (buquês de bolinhas com miolo claro) e folhas pendentes: dão cor às janelas além das folhagens do kit.
func _flores(_b: MeshBatch, _centro: Vector3, _larg: float, _prof: float, _n: int, _pende := false) -> void:
	return      # as "bolinhas coloridas" foram removidas: o verde e as flores vêm dos modelos reais de plantas (vinca, mato, antúrio)


func _pot(b: MeshBatch, p: Vector3) -> void:
	# vaso de barro de verdade (planter_pot_clay, enviado pelo dono): entra como instância (tipo -1) em Realismo.vidros_e_plantas
	_pl_atual.append({"pos": p, "tipo": -1, "esc": _rng.randf_range(0.9, 1.15), "vaso": true})
	_flores(b, p + Vector3(0, 0.2, 0), 0.2, 0.2, 5)
	_pl_atual.append({"pos": p + Vector3(0, 0.19, 0), "tipo": _rng.randi() % 5, "esc": _rng.randf_range(0.8, 1.2)})


func _window(b: MeshBatch, p: Vector3, wid: float, hgt: float, wood: String, lit: bool, grate: bool, door := false, arch := false, real := false) -> void:
	_vaos_atual.append({"z": p.z, "peitoril": p.y - hgt * 0.5, "topo": p.y + hgt * 0.5, "w": wid, "porta": door})
	var glass := "vidro_luz" if lit else "vidro_noite"
	if real:
		glass = "vidro_claro"
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
	if door and _kit2:
		# porta-balcão do kit 2: almofadas embaixo, vidro em cima (o vidro com a sala atrás entra como painel)
		_modulo(b, "porta_balcao", Kit.fachada(Vector3(0.0, base_y, p.z), Vector3(wid / 1.1, hgt / 2.4, 1.0)), {"madeira": wood})
		if not real:
			_jan_atual.append({"pos": Vector3(-0.012, base_y + hgt * (0.85 + 1.55 * 0.5) / 2.4, p.z), "size": Vector2(wid * 0.85, hgt * 1.5 / 2.4), "lit": lit})
	elif door:
		# porta-balcão: porta de duas folhas do kit, menos funda
		_modulo(b, "porta_dupla", Kit.fachada(Vector3(0.0, base_y, p.z), Vector3(wid / 1.4, hgt / 2.5, 0.6)), {"madeira": wood, "vidro": glass})
	else:
		if _kit2:
			_modulo(b, "janela_guilhotina", Kit.fachada(Vector3(0.0, base_y, p.z), Vector3(wid, hgt / 1.6, 1.0)), {"madeira": wood})
			if real:
				b.quad("vidro_claro", Vector2(wid * 0.92, hgt * 0.95), Vector3(-0.01, p.y, p.z), -PI / 2.0)       # vidro de verdade (a sala aparece atrás)
		else:
			_modulo(b, "janela_colonial", Kit.fachada(Vector3(0.0, base_y, p.z), Vector3(wid, hgt / 1.5, 1.0)), {"madeira": wood, "vidro": glass})
		if not real:          # janela de verdade (sala atrás do vidro): sem foto de sala no painel
			_jan_atual.append({"pos": Vector3(-0.012, p.y, p.z), "size": Vector2(wid * 0.9, hgt * 0.933), "lit": lit})
		if p.y > 3.6 and _rng_f.randf() < 0.32:                                       # pano roxo pendurado no peitoril, como na Semana Santa
			b.box("pano_roxo", Vector3(0.02, 1.15, wid * 0.62), Vector3(-0.2, base_y - 0.55, p.z), Vector3(0.0, 0.0, 0.07))
			b.box("pano_cru", Vector3(0.022, 0.5, wid * 0.5), Vector3(-0.215, base_y - 0.3, p.z), Vector3(0.0, 0.0, 0.07))
			b.box("ferro", Vector3(0.03, 0.03, wid * 0.7), Vector3(-0.2, base_y + 0.02, p.z))
		var sorteio := _rng.randf()
		if sorteio < 0.16:
			_pot(b, Vector3(-0.2, base_y + 0.03, p.z))
		elif sorteio < 0.30:
			_jardineira(b, Vector3(-0.26, base_y + 0.03, p.z), wid)
		if _rng.randf() < 0.55:
			_venezianas(b, p, wid, hgt, wood)
	if grate and _kit2:
		_modulo(b, "grade_janela", Kit.fachada(Vector3(0.0, base_y, p.z), Vector3(wid, hgt / 1.5, 1.0)))
	elif grate:
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
	b.box("madeira_natural", Vector3(0.02, 0.05, wid * 0.9), p + Vector3(-0.13, 0.12, 0))        # friso de acabamento na frente
	_flores(b, p + Vector3(0, 0.17, 0), wid * 0.84, 0.2, int(wid * 9.0) + 4, true)
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
			_modulo(b, "sacada_1m", Kit.fachada(Vector3(0.0, floor_y, z0 + (k + 0.5) * bw / nm), Vector3(bw / nm, 1.0, 1.0)))     # laje, mísulas, balaústres torneados
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
	var xf_alto: Transform3D = (f["xf"] as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(2.6, 0.0, 0.0))
	if _rng.randf() < 0.65 and w > 6.0 and not _casa_penetra(xf_alto, 8.0, w * 0.85):
		_casas_postas.append({"xf": xf_alto, "depth": 8.0, "w": w * 0.85})        # as casas seguintes encurtam para não entrar nesta
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
	_casas_postas.append({"xf": f["xf"], "depth": steps * run + 0.8, "w": wb + 0.4, "corr": true})      # casas seguintes não invadem o beco
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
		for k in 14:                                  # muitos degraus baixos (0,5 m) em vez de 4 grandes: a parede acompanha a escada sem "cara de Minecraft"
			var x0 := k * run_len / 14.0
			var seg := run_len / 14.0
			var top := (k + 1) * total / 14.0 + 2.6
			b.box("muro", Vector3(seg + 0.05, top + 1.0, 0.5), Vector3(x0 + seg / 2.0, top / 2.0 - 0.5, sz * (wb / 2.0 + 0.25)))
			b.box("cantaria", Vector3(seg + 0.05, 0.12, 0.7), Vector3(x0 + seg / 2.0, top + 0.06, sz * (wb / 2.0 + 0.25)))
	_mesh_node(g, "Degraus", b.commit())
	_beco_detalhes(g, run_len, wb, total)
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
		_blocker(g, "Parede_%d" % int(sz), Vector3(run_len + 0.6, total + 6.0, 0.6), Vector3(run_len / 2.0 + 0.7, total / 2.0, sz * (wb / 2.0 + 0.3)))      # começa 0,4 m dentro: nas curvas a quina não invade a frente das portas vizinhas
	var refuge := Area3D.new()
	refuge.name = "Refugio"
	refuge.add_to_group("refugio", true)
	refuge.collision_layer = 0       # só DETECTA o jogador: não pode interceptar o raio de interação (E) de quem está dentro do beco
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
	for fx2: float in [0.12, 0.72, 0.92]:                   # mais lampiões, lados alternados: o beco deixa de ser um túnel escuro
		var sg2 := -1.0 if fx2 > 0.5 and fx2 < 0.8 else 1.0
		var lw2 := _lantern_wall(Vector3(run_len * fx2, total * fx2 + 2.3, sg2 * (wb / 2.0)), PI if sg2 > 0.0 else 0.0)
		g.add_child(lw2)


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
	_beco_detalhes(g, D, wb, rise, tops)
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
	refuge.collision_layer = 0       # só DETECTA o jogador: não pode interceptar o raio de interação (E) de quem está dentro do beco
	var rcs := CollisionShape3D.new()
	var rbs := BoxShape3D.new()
	rbs.size = Vector3(minf(D - 2.0, 10.0), rise + 3.4, wb)
	rcs.shape = rbs
	refuge.add_child(rcs)
	refuge.position = Vector3(D / 2.0, rise / 2.0 + 1.7, 0)
	g.add_child(refuge)
	# lampiões e vegetação
	for li in 4:
		var lx: float = D * [0.14, 0.38, 0.62, 0.86][li]
		var ly := tops[mini(n - 1, int(lx / run))] + 2.3
		var sg := 1.0 if li % 2 == 0 else -1.0
		g.add_child(_lantern_wall(Vector3(lx, ly, sg * (wb / 2.0)), PI if sg > 0.0 else 0.0))
		_plant(g, "samambaia", Vector3(lx + 2.0, ly + 0.4, -sg * (wb / 2.0 + 0.6)), 0.0, 1.2)
	_plant(g, "samambaia", Vector3(D * 0.5, tops[n / 2] + 2.8, wb / 2.0 + 0.6), 0.0, 1.3)


## Acabamento dos becos e passagens em escada: janelinhas gradeadas (algumas acesas), portas pequenas de madeira colorida, remendos de reboco,
## arcos de pedra de lado a lado, varal com roupas, vasos de barro nos degraus e lampiões de ferro extras. `tops` = altura do degrau por trecho
## (vazio: rampa linear de 0 a `total`).
func _beco_detalhes(g: Node3D, run_len: float, wb: float, total: float, tops := PackedFloat32Array()) -> void:
	var b := _batch()
	var n := maxi(tops.size(), 1)
	var hx := func(x: float) -> float:
		if tops.size() > 0:
			return tops[mini(tops.size() - 1, maxi(0, int(x / run_len * float(tops.size()))))]
		return clampf(x / maxf(run_len, 0.1), 0.0, 1.0) * total
	var cores_porta := ["madeira_azul", "madeira_verde", "madeira_vermelha", "madeira_escura"]
	var rebocos := ["reboco_creme", "reboco_ocre", "reboco_amarelo", "reboco_branco"]
	var x := 2.0
	var lado := 1.0
	while x < run_len - 1.5:
		var y0: float = hx.call(x)
		var zi := lado * (wb * 0.5 - 0.005)                 # face interna da parede
		var din := -lado                                     # sentido "para dentro" do corredor (z)
		var tipo := _rng_f.randi() % 4
		if tipo == 0:                                       # janelinha gradeada, às vezes acesa
			var acesa := _rng_f.randf() < 0.4
			b.box("cantaria", Vector3(0.72, 0.9, 0.10), Vector3(x, y0 + 2.0, zi + din * 0.03))
			b.box("janela_acesa" if acesa else "janela_escura", Vector3(0.5, 0.68, 0.11), Vector3(x, y0 + 2.0, zi + din * 0.04))
			for k in 4:
				b.box("ferro", Vector3(0.025, 0.7, 0.04), Vector3(x - 0.18 + k * 0.12, y0 + 2.0, zi + din * 0.07))
			b.box("cantaria", Vector3(0.8, 0.07, 0.2), Vector3(x, y0 + 1.52, zi + din * 0.08))
		elif tipo == 1:                                     # portinha de madeira com verga de pedra
			var cp: String = cores_porta[_rng_f.randi() % cores_porta.size()]
			b.box("cantaria", Vector3(1.05, 2.1, 0.12), Vector3(x, y0 + 1.05, zi + din * 0.03))
			b.box(cp, Vector3(0.82, 1.95, 0.08), Vector3(x, y0 + 0.98, zi + din * 0.06))
			b.box("ferro", Vector3(0.06, 0.06, 0.05), Vector3(x + 0.27, y0 + 1.0, zi + din * 0.11))
			b.box("cantaria", Vector3(1.2, 0.12, 0.2), Vector3(x, y0 + 2.14, zi + din * 0.08))
		elif tipo == 2:                                     # remendo de reboco caiado sobre a pedra
			var rp: String = rebocos[_rng_f.randi() % rebocos.size()]
			b.box(rp, Vector3(1.5, 1.2, 0.05), Vector3(x, y0 + 1.7, zi + din * 0.02))
			b.box("cantaria", Vector3(1.5, 0.06, 0.07), Vector3(x, y0 + 1.1, zi + din * 0.03))
		else:                                               # cruz de madeira e nichozinho com vela
			b.box("cantaria", Vector3(0.46, 0.7, 0.16), Vector3(x, y0 + 2.0, zi + din * 0.05))
			b.box("madeira_escura", Vector3(0.36, 0.58, 0.1), Vector3(x, y0 + 2.0, zi + din * 0.07))
			b.box("madeira_natural", Vector3(0.04, 0.34, 0.03), Vector3(x, y0 + 2.04, zi + din * 0.11))
			b.box("madeira_natural", Vector3(0.18, 0.04, 0.03), Vector3(x, y0 + 2.12, zi + din * 0.11))
			b.cylinder("vela", 0.02, 0.02, 0.1, Vector3(x, y0 + 1.76, zi + din * 0.1), Vector3.ZERO, 12)
			b.sphere("chama", 0.018, Vector3(x, y0 + 1.84, zi + din * 0.1), 6, 4)
		lado = -lado
		x += _rng_f.randf_range(2.6, 3.6)
	# arcos de pedra de lado a lado (dois ou três ao longo do beco)
	for fx: float in [0.30, 0.62, 0.9]:
		var ax := run_len * fx
		if ax < 3.0 or ax > run_len - 2.0:
			continue
		var ya: float = hx.call(ax)
		b.box("cantaria", Vector3(0.5, 0.5, wb + 0.2), Vector3(ax, ya + 3.55, 0))
		b.box("cantaria", Vector3(0.7, 0.14, wb + 0.3), Vector3(ax, ya + 3.85, 0))
		for sz: float in [-1.0, 1.0]:
			b.box("cantaria", Vector3(0.42, 0.5, 0.35), Vector3(ax, ya + 3.1, sz * (wb * 0.5 - 0.15)))    # mísulas
	# varal com roupas atravessando o beco
	var vx := run_len * 0.45
	var yv: float = hx.call(vx)
	b.box("ferro", Vector3(0.012, 0.012, wb + 0.2), Vector3(vx, yv + 3.1, 0))
	var panos := ["pano_rosa", "pano_azul", "pano_cru", "listra_branca"]
	for k in 4:
		b.box(panos[k % panos.size()], Vector3(0.5, 0.65 - 0.08 * float(k % 2), 0.012), Vector3(vx + 0.02 * float(k), yv + 2.75, -wb * 0.32 + k * wb * 0.2), Vector3(0, PI / 2.0, 0.04 * float(k % 3)))
	_mesh_node(g, "Detalhes", b.commit())
	# vasos de barro com antúrio nos cantos dos degraus (nós separados, modelos enviados pelo dono)
	var px := 3.5
	var ls := 1.0
	while px < run_len - 2.0:
		var yp: float = hx.call(px)
		var pz := ls * (wb * 0.5 - 0.3)
		_prop(g, "planter_pot_clay", Vector3(px, yp, pz), _rng_f.randf() * TAU, 1.3)
		_parte(g, "anthurium_botany_01", ["anthurium_botany_01_a"], Vector3(px, yp + 0.28, pz), _rng_f.randf() * TAU, 0.2)
		ls = -ls
		px += _rng_f.randf_range(5.0, 7.0)


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
	light.light_volumetric_fog_energy = 1.8      # cone de luz visível na neblina (raios de luz, como nos jogos de cinema)
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
## Mariposas girando em volta de uma luz: poucas partículas, brilhando e sumindo (só perto do jogador: alcance de visibilidade curto).
func _mariposas(parent: Node3D, pos: Vector3, raio := 0.55) -> void:
	var ps := GPUParticles3D.new()
	ps.name = "Mariposas"
	ps.position = pos
	ps.amount = 5
	ps.lifetime = 3.2
	ps.preprocess = 3.2
	ps.local_coords = true
	ps.visibility_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3, 3, 3))
	ps.visibility_range_end = 28.0
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = raio
	pm.direction = Vector3.ZERO
	pm.spread = 180.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3.ZERO
	pm.damping_min = 0.2
	pm.damping_max = 0.6
	pm.tangential_accel_min = -1.2
	pm.tangential_accel_max = 1.2
	pm.radial_accel_min = -0.8
	pm.radial_accel_max = 0.4
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	ps.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	qm.material = mat("halo_vela")
	ps.draw_pass_1 = qm
	parent.add_child(ps)


func make_poste() -> Node3D:
	# poste de ferro fundido (Poly Haven street_lamp_01, CC0) com a lâmpada emissiva; a luz sai do bulbo
	var m := PropKit.make("street_lamp_01", 1.0)
	m.name = "Poste"
	PropKit.setup_bulb(m, Color(1.0, 0.82, 0.52), 3.4)
	var bpos: Vector3 = m.get_meta("bulb_pos", Vector3(0, 3.5, 0))
	_lamp_light(m, bpos, 0.95)
	_halo(m, bpos, 2.6)
	_mariposas(m, bpos, 0.8)
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
	_mariposas(m, bpos + Vector3(0, 0.0, 0.25))
	return m


## Posição no mundo de um nó que ainda não está na árvore (compõe as transformações locais).
func _pos_mundo(n: Node) -> Vector3:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf.origin


## Lampiões e postes nunca ficam a menos de LAMP_MIN um do outro (antes: lampião de porta colado no de parede, poste ao lado de lampião).
## Prioridade de quem fica: lampião da porta (marca casa visitável) > chafariz e postes > lampião de parede da rua.
const LAMP_MIN := 6.5
func _separa_lampioes(root: Node3D) -> void:
	var itens: Array = []
	for n in root.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		var prio := 0
		if nm.begins_with("Poste") or nm.begins_with("LampiaoDoChafariz"):
			prio = 3
		elif nm.begins_with("LampiaoDaPorta"):
			prio = 4                      # marca as casas visitáveis (objetivo do jogo): nunca é removido
		elif nm.begins_with("LampiaoParede"):
			prio = 1
		else:
			continue
		var pw := _pos_mundo(n)
		if pw.x > 1500.0:
			continue                      # interiores
		itens.append({"n": n, "p": pw, "prio": prio})
	itens.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["prio"]) > int(b["prio"]))
	var ficam: Array = []
	var removidos := 0
	for it in itens:
		var ok := true
		for f in ficam:
			if int(it["prio"]) < 4 and (it["p"] as Vector3).distance_to(f["p"]) < LAMP_MIN:
				ok = false
				break
		if ok:
			ficam.append(it)
		else:
			(it["n"] as Node).get_parent().remove_child(it["n"])
			(it["n"] as Node).queue_free()
			removidos += 1
	# luzes redundantes: a luz de uma vela de nicho ou a do beco colada a uma luz de lampião some (a vela e o lampião continuam visíveis)
	var luzes_lamp: Array = []
	for n in root.find_children("Luz", "OmniLight3D", true, false):
		var pn := n.get_parent()
		if pn != null and (String(pn.name).begins_with("Lampiao") or String(pn.name).begins_with("Poste")):
			luzes_lamp.append(_pos_mundo(n))
	var luzes_fora := 0
	for n in root.find_children("*", "OmniLight3D", true, false):
		var pn2 := n.get_parent()
		if pn2 == null:
			continue
		var pnome := String(pn2.name)
		if not (String(n.name) == "LuzDaVela" or (pnome.begins_with("Beco_") and String(n.name) == "Luz")):
			continue
		var pw := _pos_mundo(n)
		if pw.x > 1500.0:
			continue
		for lp in luzes_lamp:
			if pw.distance_to(lp) < 3.2:
				pn2.remove_child(n)
				n.queue_free()
				luzes_fora += 1
				break
	print("[vila] luzes redundantes removidas: %d" % luzes_fora)
	print("[vila] lampiões: ficam %d, removidos por ficarem a menos de %.1f m de outro: %d" % [ficam.size(), LAMP_MIN, removidos])


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
			var ps2: float = ps
			for off: float in [0.0, 1.6, -1.6, 3.2, -3.2, 4.8, -4.8]:      # o poste não pode ficar na frente de uma porta
				var pt := Route.pos(ps + off) + Route.right(ps + off) * sigma * (Route.width(ps + off) * 0.5 + SW * 0.5)
				if not _perto_de_porta(pt, 1.7):
					ps2 = ps + off
					break
			p.position = Route.pos(ps2) + Route.right(ps2) * sigma * (Route.width(ps2) * 0.5 + SW * 0.5) + Vector3(0, SW_H, 0)
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
			for zp: float in [-1.0, 1.0]:                        # pilastras ocres com bola de pedra no topo, a cada trecho
				b.box("cantaria_ocre", Vector3(0.8, 0.5, 0.8), Vector3(0.25, 1.52, zp * f["w"] * 0.5))
				b.box("cantaria_ocre", Vector3(0.6, 0.5, 0.6), Vector3(0.25, 1.95, zp * f["w"] * 0.5))
				b.box("cantaria", Vector3(0.78, 0.1, 0.78), Vector3(0.25, 2.25, zp * f["w"] * 0.5))
				b.sphere("cantaria_ocre", 0.27, Vector3(0.25, 2.5, zp * f["w"] * 0.5), 8, 5)
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
	# bancos de pedra no adro (dois de cada lado) e neblina baixa em frente à igreja
	for sigma2: float in [-1.0, 1.0]:
		for ss2: float in [S_END + 15.0, S_END + 36.0]:
			var bp := Route.pos(ss2) + Route.right(ss2) * sigma2 * (Route.width(ss2) * 0.5 - 0.9)       # dentro do adro, longe da mureta
			var bt := Route.tangent(ss2)
			var bg := _group(root, "Banco_%d_%d" % [int(ss2), int(sigma2)], Transform3D(Basis(bt, Vector3.UP, bt.cross(Vector3.UP)), Vector3(bp.x, bp.y, bp.z)))   # no piso do adro (não na altura da calçada)
			var bb := _batch()
			bb.box("cantaria", Vector3(1.9, 0.14, 0.55), Vector3(0, 0.5, 0))
			for lx: float in [-0.75, 0.75]:
				bb.box("cantaria_ocre", Vector3(0.18, 0.5, 0.5), Vector3(lx, 0.25, 0))
			_mesh_node(bg, "Malha", bb.commit())
			_blocker(bg, "Colisao", Vector3(1.9, 0.6, 0.6), Vector3(0, 0.3, 0))
			_reservar(Vector3(bp.x, bp.y, bp.z), 1.3)
	# vasos de barro com arbustos ladeando a porta da igreja
	var igt := Transform3D(Basis(Route.tangent(CHURCH_S), Vector3.UP, Route.tangent(CHURCH_S).cross(Vector3.UP)), Route.pos(CHURCH_S))
	for sz2: float in [-1.0, 1.0]:
		var vp: Vector3 = igt * Vector3(-3.2, 0.0, sz2 * 5.6)
		var vaso := _prop(root, "planter_pot_clay", vp, 0.0, 2.6)
		vaso.name = "VasoDaIgreja_%d" % int(sz2)
		_plant(root, "arbusto", vp + Vector3(0, 0.45, 0), 0.0, 1.0)
	_adro_detalhes(root, igt)
	# ruelas atrás das muretas do adro: calçamento até a porta das casas que cercam a praça (antes as portas davam para o vazio)
	for sigma: float in [-1.0, 1.0]:
		var sr := S_END + 1.0
		while sr < CHURCH_S - 4.0:                                # termina antes das torres da igreja
			var s2r := minf(sr + 3.0, CHURCH_S - 4.0)
			var sm := (sr + s2r) * 0.5
			var ini := Route.width(sm) * 0.5 + SW + 0.45
			var fim := PlanoVila.ADRO_RECUO + 0.2
			if fim - ini > 0.5:
				var tr := Route.tangent(sm)
				var cr := Route.pos(sm) + Route.right(sm) * sigma * (ini + fim) * 0.5
				var g := _group(root, "Ruela_%02d" % _n, Transform3D(Basis(tr, Vector3.UP, tr.cross(Vector3.UP)), Vector3(cr.x, Route.height(sm) + SW_H - 1.5, cr.z)))
				_n += 1
				_box(g, "Piso", Vector3(s2r - sr + 0.05, 3.0, fim - ini), Vector3.ZERO, "pedra_chao", true)   # 3 m de espessura: vai até o terreno, sem vão embaixo
			sr = s2r
	return root


## Complementos do adro (quadro da igreja: +X para dentro, fachada em x=0): lajedo de pedra, chafariz, castiçais no portal,
## degraus-soleira, quadro de avisos da Irmandade e ex-votos (velas) ao pé das paredes.
func _adro_detalhes(root: Node3D, igt: Transform3D) -> void:
	var g := _group(root, "AdroDetalhes", igt)
	# 1) lajedo: tapete de pedra de cantaria em frente ao portal, com faixa ocre em cruz e borda (0,03 m acima da rua)
	var b := _batch()
	var w := 7.0
	b.box("cantaria", Vector3(9.0, 0.035, 2.0 * w), Vector3(-5.0, 0.02, 0))
	b.box("cantaria_ocre", Vector3(9.0, 0.04, 0.5), Vector3(-5.0, 0.022, 0))
	b.box("cantaria_ocre", Vector3(0.5, 0.04, 2.0 * w), Vector3(-5.0, 0.022, 0))
	for zz: float in [-1.0, 1.0]:
		b.box("cantaria_ocre", Vector3(9.2, 0.045, 0.3), Vector3(-5.0, 0.024, zz * (w + 0.1)))
	b.box("cantaria_ocre", Vector3(0.3, 0.045, 2.0 * w + 0.5), Vector3(-9.6, 0.024, 0))
	# degraus-soleira em frente ao portal (altura total 0,28 m: dá para subir andando)
	for k in 2:
		b.box("cantaria", Vector3(1.2 - k * 0.5, 0.12 + 0.0 * k, 4.4 - k * 0.8), Vector3(-0.7 + k * 0.35 - 0.2, 0.06 + k * 0.12, 0))
	_mesh_node(g, "Lajedo", b.commit())
	# 2) castiçais de latão sobre pedestais, de cada lado do portal
	for sz: float in [-1.0, 1.0]:
		var pb := _batch()
		pb.box("cantaria_ocre", Vector3(0.55, 0.85, 0.55), Vector3(0, 0.425, 0))
		pb.box("cantaria", Vector3(0.7, 0.1, 0.7), Vector3(0, 0.9, 0))
		var pg := _group(g, "PedestalVotivo_%d" % int(sz), Transform3D(Basis.IDENTITY, Vector3(-1.4, 0.0, sz * 3.3)))
		_mesh_node(pg, "Malha", pb.commit())
		_blocker(pg, "Colisao", Vector3(0.6, 0.95, 0.6), Vector3(0, 0.47, 0))
		_parte(pg, "brass_candleholders", ["brass_candleholder_03"], Vector3(0, 0.95, 0), 0.0, 0.6)
		_brilho_em(pg, Vector3(0, 1.45, 0), 0.9)
	# 3) ex-votos: velas acesas e cera ao pé da parede, ao lado do portal
	for sz2: float in [-1.0, 1.0]:
		var vb := _batch()
		for i in 7:
			var vx := -0.5 - _rng.randf() * 0.25
			var vz: float = sz2 * (1.2 + float(i) * 0.33)
			var vh := 0.10 + _rng.randf() * 0.14
			vb.cylinder("vela", 0.03, 0.028, vh, Vector3(vx, 0.05 + vh * 0.5, vz), Vector3.ZERO, 12)
			vb.sphere("chama", 0.022, Vector3(vx, 0.06 + vh + 0.02, vz), 10, 6)
		_mesh_node(g, "Votivas_%d" % int(sz2), vb.commit())
	# 4) chafariz de pedra no lado esquerdo do adro, com bacia, pé, taça e remate
	var cf := _group(g, "Chafariz", Transform3D(Basis.IDENTITY, Vector3(-17.0, 0.0, -6.6)))
	var fb := _batch()
	fb.cylinder("cantaria", 1.8, 1.8, 0.12, Vector3(0, 0.06, 0), Vector3.ZERO, 24)
	for k in 16:
		var a := TAU * float(k) / 16.0
		var bl := TAU * 1.5 / 16.0 + 0.04
		fb.box("cantaria_ocre", Vector3(0.4, 0.62, bl), Vector3(cos(a) * 1.5, 0.43, sin(a) * 1.5), Vector3(0, -a, 0))
	fb.cylinder("cantaria", 1.7, 1.7, 0.05, Vector3(0, 0.74, 0), Vector3.ZERO, 24)
	fb.cylinder("agua_chafariz", 1.3, 1.3, 0.03, Vector3(0, 0.46, 0), Vector3.ZERO, 24)
	fb.cylinder("cantaria_ocre", 0.35, 0.22, 1.0, Vector3(0, 0.95, 0), Vector3.ZERO, 14)
	fb.cylinder("cantaria", 0.28, 0.28, 0.1, Vector3(0, 1.5, 0), Vector3.ZERO, 14)
	fb.cylinder("cantaria_ocre", 0.3, 0.75, 0.3, Vector3(0, 1.65, 0), Vector3.ZERO, 20)
	fb.cylinder("agua_chafariz", 0.6, 0.6, 0.02, Vector3(0, 1.8, 0), Vector3.ZERO, 20)
	fb.cylinder("cantaria_ocre", 0.2, 0.1, 0.7, Vector3(0, 2.15, 0), Vector3.ZERO, 14)
	fb.sphere("cantaria_ocre", 0.2, Vector3(0, 2.62, 0), 12, 8)
	fb.box("cantaria", Vector3(0.06, 0.4, 0.06), Vector3(0, 3.0, 0))
	fb.box("cantaria", Vector3(0.3, 0.06, 0.06), Vector3(0, 3.08, 0))
	_mesh_node(cf, "Malha", fb.commit())
	_blocker(cf, "Colisao", Vector3(3.4, 1.0, 3.4), Vector3(0, 0.5, 0))
	_reservar(igt * Vector3(-17.0, 0.0, -6.6), 3.0)
	# 5) quadro de avisos da Irmandade (duas colunas de madeira, tabuleiro e papéis)
	var qa := _group(g, "QuadroDeAvisos", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-12.0, 0.0, 8.7)))
	var qb := _batch()
	for zq: float in [-0.9, 0.9]:
		qb.box("madeira_escura", Vector3(0.14, 2.3, 0.14), Vector3(0, 1.15, zq))
	qb.box("madeira_escura", Vector3(0.08, 1.2, 2.0), Vector3(0, 1.55, 0))
	qb.box("madeira_escura", Vector3(0.22, 0.1, 2.2), Vector3(0, 2.3, 0))
	for k in 4:
		var pz := -0.65 + k * 0.45
		qb.box("papel", Vector3(0.012, 0.42 - (k % 2) * 0.1, 0.3), Vector3(-0.045, 1.6 + (k % 3) * 0.12, pz), Vector3(0.0, 0.0, 0.0))
	_mesh_node(qa, "Malha", qb.commit())
	_blocker(qa, "Colisao", Vector3(0.3, 2.3, 2.0), Vector3(0, 1.15, 0))
	_reservar(igt * Vector3(-12.0, 0.0, 8.7), 1.6)
	# 6) coreto na outra metade do adro e ciprestes atrás dos muros (altura e silhueta contra a neblina)
	_coreto(g, Vector3(-36.0, 0.0, 5.8))
	_reservar(igt * Vector3(-36.0, 0.0, 5.8), 4.2)
	for sg2: float in [-1.0, 1.0]:
		var sc2 := Route.S_END + 6.0
		while sc2 < Route.CHURCH_S - 6.0:
			var cp := Route.pos(sc2) + Route.right(sc2) * sg2 * (Route.width(sc2) * 0.5 + SW + 5.2 + _rng.randf_range(-0.6, 0.6))
			_cipreste(root, Vector3(cp.x, cp.y - 0.4, cp.z), _rng.randf_range(7.0, 11.0), _rng.randf() * TAU)
			sc2 += _rng.randf_range(7.0, 10.5)


## Coreto de praça (octogonal, colunas de ferro, telhado de telha) e ciprestes: dão altura e silhueta ao adro.
func _coreto(parent: Node3D, pos: Vector3) -> void:
	var cg := _group(parent, "Coreto", Transform3D(Basis.IDENTITY, pos))
	var cb := _batch()
	cb.cylinder("cantaria", 3.5, 3.5, 0.3, Vector3(0, 0.15, 0), Vector3.ZERO, 16)
	cb.cylinder("cantaria_ocre", 3.2, 3.2, 0.1, Vector3(0, 0.34, 0), Vector3.ZERO, 16)
	for k in 8:
		var a := TAU * float(k) / 8.0 + TAU / 16.0
		var px := cos(a) * 2.9
		var pz := sin(a) * 2.9
		cb.cylinder("cantaria_ocre", 0.2, 0.2, 0.4, Vector3(px, 0.6, pz), Vector3.ZERO, 12)         # base da coluna
		cb.cylinder("ferro", 0.065, 0.055, 3.0, Vector3(px, 2.3, pz), Vector3.ZERO, 12)
		cb.sphere("ouro_velho", 0.09, Vector3(px, 3.84, pz), 10, 6)
		var a2 := TAU * float(k + 1) / 8.0 + TAU / 16.0
		if k != 0:                                                                    # guarda-corpo (a abertura k==0 é a entrada)
			var mx := (px + cos(a2) * 2.9) * 0.5
			var mz := (pz + sin(a2) * 2.9) * 0.5
			var ln := Vector2(cos(a2) * 2.9 - px, sin(a2) * 2.9 - pz).length()
			var yaw := atan2(-(sin(a2) * 2.9 - pz), cos(a2) * 2.9 - px)
			cb.box("ferro", Vector3(ln, 0.045, 0.045), Vector3(mx, 1.38, mz), Vector3(0, yaw, 0))
			cb.box("ferro", Vector3(ln, 0.03, 0.03), Vector3(mx, 0.95, mz), Vector3(0, yaw, 0))
			for q in 6:
				var f := (float(q) + 0.5) / 6.0
				cb.cylinder("ferro", 0.014, 0.014, 0.45, Vector3(lerpf(px, cos(a2) * 2.9, f), 1.17, lerpf(pz, sin(a2) * 2.9, f)), Vector3.ZERO, 12)
	cb.cylinder("madeira_escura", 3.3, 3.3, 0.22, Vector3(0, 3.95, 0), Vector3.ZERO, 16)               # viga em anel
	cb.cylinder("telha", 3.7, 0.25, 1.5, Vector3(0, 4.8, 0), Vector3.ZERO, 16)                          # telhado cônico
	cb.cylinder("ferro", 0.04, 0.02, 0.9, Vector3(0, 5.95, 0), Vector3.ZERO, 12)
	cb.sphere("ouro_velho", 0.12, Vector3(0, 6.45, 0), 10, 6)
	_mesh_node(cg, "Malha", cb.commit())
	for k in 8:
		var a := TAU * float(k) / 8.0 + TAU / 16.0
		_blocker(cg, "ColColuna_%d" % k, Vector3(0.3, 3.0, 0.3), Vector3(cos(a) * 2.9, 1.5, sin(a) * 2.9))
	_lamp_light(cg, Vector3(0, 3.2, 0), 1.0).omni_range = 7.5
	_halo(cg, Vector3(0, 3.1, 0), 1.6, "halo_vela")


func _cipreste(parent: Node3D, pos: Vector3, h: float, yaw := 0.0) -> void:
	var cg := _group(parent, "Cipreste_%d" % _n, Transform3D(Basis(Vector3.UP, yaw), pos))
	_n += 1
	var cb := _batch()
	var r := h * 0.11
	cb.cylinder("madeira_escura", 0.16, 0.12, h * 0.25, Vector3(0, h * 0.125, 0), Vector3.ZERO, 12)
	for k in 3:                                            # três cones sobrepostos e levemente desencontrados: silhueta irregular e escura
		var kk := float(k)
		cb.cylinder("cipreste", r * (1.0 - kk * 0.18), 0.04, h * (0.82 - kk * 0.12), Vector3(_rng.randf_range(-0.12, 0.12), h * 0.2 + h * (0.82 - kk * 0.12) * 0.5 + kk * h * 0.04, _rng.randf_range(-0.12, 0.12)), Vector3.ZERO, 12)
	_mesh_node(cg, "Malha", cb.commit())
	_blocker(cg, "Colisao", Vector3(0.5, h * 0.4, 0.5), Vector3(0, h * 0.2, 0))


## Brilho (halo) em um ponto local de um grupo.
func _brilho_em(parent: Node3D, pos: Vector3, size: float) -> void:
	_halo(parent, pos, size * 1.5, "halo_vela")


## Igreja barroca mineira (inspiração): fachada branca com cantaria, portal em arco, óculo, frontão com volutas e torres cilíndricas.
## Quadro local: +X para dentro da igreja, fachada em x = 0 olhando para -X. Origem ao nível do adro.
func make_igreja(width: float, nave_len: float, twin: bool, collide: bool) -> Node3D:
	var c := Node3D.new()
	c.name = "Igreja"
	var nh := 12.0                 # altura da nave
	var fh := 15.5                 # altura da fachada
	var wall := "reboco_caiado"      # caiada: bem mais clara que o reboco das casas
	var ced: String = "cantaria_ocre" if twin else "cantaria"      # igreja principal: cantaria ocre sobre parede branca (como as igrejas de Ouro Preto)
	var porta_mat: String = "madeira_verde" if twin else "madeira_natural"      # porta e janelas verdes, como na São Francisco de Assis
	var jan_mat: String = "madeira_verde" if twin else "madeira_escura"
	var half := width / 2.0
	_box(c, "Nave", Vector3(nave_len - 0.06, nh + 3.0, width), Vector3(nave_len / 2.0 + 0.03, (nh - 3.0) / 2.0, 0), wall, collide)
	_box(c, "Fachada", Vector3(1.6, fh + 3.0, width), Vector3(0.8, (fh - 3.0) / 2.0, 0), wall, collide)
	# telhado da nave: telhas no sentido do caimento, cumeeira ao longo de X, forro sob o beiral
	var rise := (width + 1.2) * 0.3
	var rb := _batch()
	rb.roof("telha_uv", wall, Vector3(width + 1.2, rise, nave_len + 1.0), Vector3(nave_len / 2.0, nh + rise / 2.0, 0), PI / 2.0, 3.6, "madeira_escura")
	rb.box("telha_cumeeira", Vector3(nave_len + 1.1, 0.28, 0.42), Vector3(nave_len / 2.0, nh + rise + 0.05, 0))
	_mesh_node(c, "TelhadoNave", rb.commit())
	_telhado_colisao(c, Vector3(nave_len / 2.0, nh + rise / 2.0, 0), width + 1.2, rise, nave_len + 1.0, PI / 2.0)

	var b := _batch()
	# pilastras e cornijas da fachada
	for sz: float in [-1.0, 1.0]:
		for zz: float in [half - 0.45, 3.5]:
			b.box(ced, Vector3(0.30, fh - 0.4, 0.62), Vector3(-0.12, (fh - 0.4) / 2.0, sz * zz))
			b.box(ced, Vector3(0.42, 0.50, 0.84), Vector3(-0.15, 0.25, sz * zz))
			b.box(ced, Vector3(0.42, 0.32, 0.84), Vector3(-0.15, fh - 0.55, sz * zz))
	b.box(ced, Vector3(0.60, 0.34, width + 0.5), Vector3(-0.22, fh - 0.17, 0))
	b.box(ced, Vector3(0.42, 0.22, width + 0.3), Vector3(-0.15, 8.6, 0))
	if not twin:
		# frontão escalonado com cornijas, volutas e pináculos
		for k in 4:
			var wk := width * (0.62 - k * 0.14)
			b.box(wall, Vector3(1.5, 0.9, wk), Vector3(0.0, fh + 0.45 + k * 0.9, 0))
			b.box(ced, Vector3(1.7, 0.16, wk + 0.3), Vector3(-0.05, fh + 0.9 + k * 0.9, 0))
		for sz: float in [-1.0, 1.0]:
			b.arch(ced, Vector3(-0.10, fh + 0.35, sz * (width * 0.62 * 0.5 + 0.95)), 0.95, 0.28, 0.36, 9)   # voluta lateral
			b.box(ced, Vector3(0.5, 0.55, 0.5), Vector3(-0.15, fh + 0.25, sz * (half - 0.3)))
			b.sphere(ced, 0.34, Vector3(-0.15, fh + 0.85, sz * (half - 0.3)), 8, 5)
		b.box(ced, Vector3(0.3, 2.4, 0.3), Vector3(-0.05, fh + 5.0, 0))
		b.box(ced, Vector3(0.3, 0.3, 1.3), Vector3(-0.05, fh + 5.6, 0))
	# portal em arco de pedra-sabão (cinza-azulada, como o de Aleijadinho em Ouro Preto) com porta de madeira e leque de luz
	var pced: String = "pedra_sabao" if twin else ced
	var pr := 1.9
	var py := 4.4
	for sz: float in [-1.0, 1.0]:
		b.box(pced, Vector3(0.62, py, 0.52), Vector3(-0.31, py / 2.0, sz * (pr + 0.26)))
	b.arch(pced, Vector3(-0.31, py, 0), pr + 0.26, 0.52, 0.62, 14)
	b.box(pced, Vector3(0.78, 0.62, 0.55), Vector3(-0.34, py + pr + 0.28, 0))                  # fecho do arco
	b.box(pced, Vector3(0.50, 0.30, 2.0 * pr + 1.6), Vector3(-0.30, py + pr + 0.90, 0))          # cornija do portal
	var pb := _batch()                      # a porta é um nó à parte: no lote grande os triângulos dela se perdiam (mesmo bug das casas)
	for sz: float in [-1.0, 1.0]:
		pb.box(porta_mat, Vector3(0.14, py - 0.05, pr - 0.04), Vector3(-0.50, py / 2.0, sz * (pr / 2.0)))
		for yy: float in [0.9, 2.2, 3.5]:
			pb.box("ferro", Vector3(0.05, 0.14, pr - 0.16), Vector3(-0.59, yy, sz * (pr / 2.0)))          # ferragens
		pb.box("ferro", Vector3(0.09, 0.50, 0.09), Vector3(-0.62, 2.2, sz * 0.22))                          # puxador
	var pmi := _mesh_node(c, "PortaMalha", pb.commit())
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.half_disc("porta_igreja", Vector3(-0.52, py, 0), pr - 0.04, 14)                                     # leque com a luz do interior
	for k in 3:                                                                                           # degraus do adro
		b.box(ced, Vector3(0.8, 0.14 * (3 - k), width * 0.7), Vector3(-1.4 - k * 0.8, 0.07 * (3 - k), 0))
	if not twin:
		# óculo com raios de pedra
		b.cylinder(ced, 1.30, 1.30, 0.30, Vector3(-0.20, 11.7, 0), Vector3(0, 0, PI / 2.0), 18)
		b.cylinder("janela_escura", 0.98, 0.98, 0.34, Vector3(-0.22, 11.7, 0), Vector3(0, 0, PI / 2.0), 18)
		for k in 4:
			b.box(ced, Vector3(0.12, 0.09, 2.0), Vector3(-0.42, 11.7, 0), Vector3(k * PI / 4.0, 0, 0))
	# janelas laterais em arco e janelas baixas com grade
	for side: float in [-1.0, 1.0]:
		_window(b, Vector3(0, 8.4, side * (half - 2.5)), 1.4, 2.8, jan_mat, true, false, false, true)     # janelas do coro, acesas
		_window(b, Vector3(0, 2.7, side * (half - 2.5)), 1.1, 1.8, jan_mat, true, true)
		_window(b, Vector3(0, 10.2, side * 3.7), 1.1, 2.3, jan_mat, true, false, false, true)
	# colunas do portal com capitel e entablamento, medalhão e nichos com santos (Ouro Preto: a portada é a joia da fachada)
	for sz: float in [-1.0, 1.0]:
		var zc := sz * (pr + 1.25)
		b.cylinder(pced, 0.36, 0.42, py + pr + 0.7, Vector3(-0.62, (py + pr + 0.7) / 2.0, zc), Vector3.ZERO, 14)
		b.box(pced, Vector3(0.95, 0.34, 0.95), Vector3(-0.62, 0.17, zc))
		b.box(pced, Vector3(1.0, 0.36, 1.0), Vector3(-0.62, py + pr + 0.9, zc))
		b.box(pced, Vector3(0.7, 0.2, 0.7), Vector3(-0.62, py + pr + 1.18, zc))
		# nicho com moldura e fundo escuro
		var nz := sz * 5.35
		b.box(ced, Vector3(0.34, 2.9, 1.6), Vector3(-0.17, 5.4, nz))
		b.arch(ced, Vector3(-0.17, 6.85, nz), 0.8, 0.34, 0.2, 9)
		b.box("janela_escura", Vector3(0.1, 2.5, 1.1), Vector3(-0.32, 5.35, nz))
		b.box(ced, Vector3(0.5, 0.18, 1.3), Vector3(-0.36, 4.15, nz))
	b.box(pced, Vector3(1.05, 0.5, 2.0 * (pr + 1.25) + 1.3), Vector3(-0.62, py + pr + 1.55, 0))
	b.box(pced, Vector3(1.15, 0.2, 2.0 * (pr + 1.25) + 1.5), Vector3(-0.66, py + pr + 1.9, 0))
	if not twin:
		b.cylinder(ced, 1.0, 1.0, 0.34, Vector3(-0.40, py + pr + 3.2, 0), Vector3(0, 0, PI / 2.0), 20)          # medalhão
		b.cylinder("ouro_velho", 0.72, 0.72, 0.38, Vector3(-0.44, py + pr + 3.2, 0), Vector3(0, 0, PI / 2.0), 20)
		b.cylinder(ced, 0.38, 0.38, 0.42, Vector3(-0.50, py + pr + 3.2, 0), Vector3(0, 0, PI / 2.0), 12)
	for k in 3:                                                                                            # escadaria mais larga
		b.box(ced, Vector3(0.9, 0.16 * (4 - k), width * 0.9), Vector3(-1.9 - k * 0.9, 0.08 * (4 - k), 0))
	if twin:
		_fachada_barroca(b, width, fh, py, pr, half, ced, wall)
		_igreja_relevos_portal(b, py, pr)
		_igreja_laterais(c, b, width, nave_len, nh, ced, wall)
		_igreja_exterior_extra(c, b, width, fh, py, pr, half, ced)
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
			tb.box(ced, Vector3(0.24, 22.6, 0.50), Vector3(cos(a) * 2.20, 7.3, sin(a) * 2.20), Vector3(0, -a, 0))
		for ry: float in [-0.2, 6.2, 12.4, 19.7]:                                                         # anéis de cornija
			tb.cylinder(ced, 2.62, 2.62, 0.34, Vector3(0, ry, 0), Vector3.ZERO, 20)
		for k in 4:                                                                                         # aberturas da sineira
			var a := k * PI / 2.0
			var rad := Vector3(cos(a), 0, sin(a))
			var tan_v := Vector3(-sin(a), 0, cos(a))
			var cen := rad * 2.12 + Vector3(0, 15.6, 0)
			tb.box("janela_escura", Vector3(0.14, 3.2, 1.35), cen, Vector3(0, -a, 0))
			for sg: float in [-1.0, 1.0]:
				tb.box(ced, Vector3(0.24, 3.5, 0.22), cen + tan_v * sg * 0.78 + rad * 0.04, Vector3(0, -a, 0))
			tb.box(ced, Vector3(0.26, 0.26, 1.80), cen + Vector3(0, 1.74, 0) + rad * 0.04, Vector3(0, -a, 0))
			tb.box(ced, Vector3(0.30, 0.22, 1.9), cen + Vector3(0, -1.70, 0) + rad * 0.06, Vector3(0, -a, 0))
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
		_mesh_node(t, "Lanterna", lantern, Vector3(0, 22.9, 0)).material_override = mat(ced)
		var dome2 := SphereMesh.new()
		dome2.radius = 1.25
		dome2.height = 2.2
		_mesh_node(t, "CupulaAlta", dome2, Vector3(0, 24.4, 0)).material_override = mat("telha")
		var cb := _batch()
		if twin:                                                                                         # agulha alta e fina com bola e cruz (como as torres da referência)
			cb.cylinder(ced, 0.07, 0.42, 4.6, Vector3(0, 27.0, 0), Vector3.ZERO, 10)
			cb.sphere("ouro_velho", 0.30, Vector3(0, 25.4, 0), 8, 5)
			cb.sphere("ouro_velho", 0.20, Vector3(0, 28.0, 0), 8, 5)
			cb.box("ferro", Vector3(0.10, 1.2, 0.10), Vector3(0, 29.7, 0))
			cb.box("ferro", Vector3(0.60, 0.10, 0.10), Vector3(0, 30.0, 0))
		else:
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


## Relevos de pedra-sabão sobre o portal: festões (guirlandas) entre as colunas e querubins ao lado do medalhão.
func _igreja_relevos_portal(b: MeshBatch, py: float, pr: float) -> void:
	var zc := pr + 1.25
	var yb := py + pr + 2.35
	for sz: float in [-1.0, 1.0]:
		for k in 9:                                                  # guirlanda pendurada em curva (catenária) de cada lado
			var f := float(k) / 8.0
			var zz := sz * lerpf(0.9, zc - 0.2, f)
			var yy := yb - 0.34 * sin(f * PI)
			b.sphere("pedra_sabao", 0.115, Vector3(-0.78, yy, zz), 8, 5)
		for k in 3:                                                  # frutas maiores no meio do festão
			var f2 := 0.25 + 0.25 * float(k)
			b.sphere("pedra_sabao", 0.17, Vector3(-0.82, yb - 0.36 * sin(f2 * PI) - 0.1, sz * lerpf(0.9, zc - 0.2, f2)), 8, 5)
		# querubim: cabecinha com duas asas, ao lado do medalhão
		var qz := sz * 2.15
		b.sphere("pedra_sabao", 0.2, Vector3(-0.8, py + pr + 3.3, qz), 10, 6)
		b.box("pedra_sabao", Vector3(0.1, 0.12, 0.42), Vector3(-0.78, py + pr + 3.18, qz + sz * 0.3), Vector3(0, 0, sz * 0.5))
		b.box("pedra_sabao", Vector3(0.1, 0.12, 0.42), Vector3(-0.78, py + pr + 3.18, qz - sz * 0.3), Vector3(0, 0, -sz * 0.5))
	b.box("pedra_sabao", Vector3(0.22, 1.4, 1.1), Vector3(-0.74, py + pr + 3.0, 0))             # cartela sob o medalhão
	b.sphere("ouro_velho", 0.16, Vector3(-0.9, py + pr + 3.0, 0), 10, 6)


## Exuberância do exterior: vitral em roseta que brilha, estátuas sobre pedestais na escadaria, balaustrada com pináculos, lampiões dourados e
## acabamento em ouro nas colunas e nos capitéis.
func _igreja_exterior_extra(c: Node3D, b: MeshBatch, width: float, fh: float, py: float, pr: float, half: float, ced: String) -> void:
	# roseta de vitral no frontão (emissiva: brilha à noite)
	var ry := fh + 2.4
	var mats := ["vitral_vermelho", "vitral_azul", "vitral_ambar", "vitral_verde"]
	for k in 12:
		var a := TAU * float(k) / 12.0
		b.box(mats[k % 4], Vector3(0.05, 0.26, 0.56), Vector3(-0.50, ry + sin(a) * 0.34, cos(a) * 0.34), Vector3(-a, 0.0, 0.0))
	b.cylinder("vitral_ambar", 0.17, 0.17, 0.06, Vector3(-0.52, ry, 0), Vector3(0, 0, PI / 2.0), 16)
	for k in 6:
		b.box("ferro", Vector3(0.04, 0.05, 1.3), Vector3(-0.54, ry, 0), Vector3(k * PI / 6.0, 0, 0))
	# ouro nos capitéis e nas bases das colunas do portal
	for sz: float in [-1.0, 1.0]:
		var zc := sz * (pr + 1.25)
		b.box("ouro_velho", Vector3(1.05, 0.10, 1.05), Vector3(-0.62, py + pr + 1.30, zc))
		b.box("ouro_velho", Vector3(1.0, 0.08, 1.0), Vector3(-0.62, 0.38, zc))
	b.box("ouro_velho", Vector3(1.0, 0.08, 2.0 * (pr + 1.25) + 1.4), Vector3(-0.64, py + pr + 1.46, 0))
	# balaustrada com balaústres e pináculos ao longo da escadaria, dos dois lados
	for sz: float in [-1.0, 1.0]:
		var zb := sz * (width * 0.45 + 0.35)
		b.box(ced, Vector3(3.3, 0.14, 0.5), Vector3(-3.1, 0.94, zb))
		for k in 7:
			b.cylinder(ced, 0.07, 0.07, 0.62, Vector3(-1.7 - k * 0.45, 0.58, zb), Vector3.ZERO, 12)
			b.sphere(ced, 0.085, Vector3(-1.7 - k * 0.45, 0.88, zb), 8, 6)
		b.box(ced, Vector3(0.5, 1.3, 0.5), Vector3(-4.8, 0.65, zb))                                  # pilar
		b.sphere("ouro_velho", 0.22, Vector3(-4.8, 1.5, zb), 12, 8)
	# estátuas sobre pedestais na frente da escadaria
	var spr := PropKit.make("gothic_statue", 1.0)
	var sbb: AABB = spr.get_meta("bb")
	spr.free()
	for sz: float in [-1.0, 1.0]:
		var zs := sz * (half + 1.6)
		b.box(ced, Vector3(1.1, 1.1, 1.1), Vector3(-3.0, 0.55, zs))
		b.box("ouro_velho", Vector3(1.2, 0.1, 1.2), Vector3(-3.0, 1.15, zs))
		var st := _prop(c, "gothic_statue", Vector3(-3.0, 1.2, zs), -PI / 2.0, 2.3 / maxf(sbb.size.y, 0.1))
		st.name = "EstatuaEscadaria_%d" % int(sz)
		var lz := _lamp_light(c, Vector3(-3.6, 3.6, zs), 0.8)
		lz.omni_range = 7.0


## Laterais da nave: embasamento de pedra, pilastras a cada 5 m, cornija com cachorros sob o beiral, óculos e janelas gradeadas,
## capela-mor mais baixa nos fundos e lampiões de parede.
func _igreja_laterais(c: Node3D, b: MeshBatch, width: float, nave_len: float, nh: float, ced: String, wall: String) -> void:
	var half := width / 2.0
	for sz: float in [-1.0, 1.0]:
		var zw := sz * (half + 0.12)
		b.box("muro", Vector3(nave_len - 1.0, 1.1, 0.32), Vector3(nave_len / 2.0 + 1.0, 0.45, zw))                 # embasamento de pedra
		b.box(ced, Vector3(nave_len - 1.0, 0.14, 0.40), Vector3(nave_len / 2.0 + 1.0, 1.04, zw))
		b.box(ced, Vector3(nave_len - 1.0, 0.34, 0.52), Vector3(nave_len / 2.0 + 1.0, nh - 0.2, sz * (half + 0.18)))   # cornija sob o beiral
		var x := 2.2
		while x < nave_len - 1.0:
			b.box(ced, Vector3(0.46, nh, 0.36), Vector3(x, nh / 2.0, zw))                                           # pilastra
			b.box(ced, Vector3(0.62, 0.3, 0.46), Vector3(x, nh - 0.05, zw))
			# janela entre pilastras: moldura de cantaria, vidro escuro e grade de ferro; óculo redondo no alto
			var xm := x + 2.5
			if xm < nave_len - 1.4:
				b.box(ced, Vector3(1.5, 2.5, 0.2), Vector3(xm, 2.9, zw + sz * 0.03))
				b.box("janela_escura", Vector3(1.1, 2.1, 0.12), Vector3(xm, 2.9, zw + sz * 0.1))
				for g in 4:
					b.box("ferro", Vector3(0.04, 2.1, 0.05), Vector3(xm - 0.42 + g * 0.28, 2.9, zw + sz * 0.17))
				b.cylinder(ced, 0.82, 0.82, 0.2, Vector3(xm, nh - 2.6, zw + sz * 0.03), Vector3(PI / 2.0, 0, 0), 18)
				b.cylinder("janela_escura", 0.6, 0.6, 0.12, Vector3(xm, nh - 2.6, zw + sz * 0.12), Vector3(PI / 2.0, 0, 0), 18)
			x += 5.0
		var xc := 1.5
		while xc < nave_len:                                                                                        # cachorros (consolos) sob o beiral
			b.box(ced, Vector3(0.22, 0.28, 0.34), Vector3(xc, nh - 0.55, sz * (half + 0.3)))
			xc += 0.95
	# capela-mor: volume mais baixo e estreito nos fundos, com telhado próprio e cruz
	var cw := width * 0.62
	var cl := 8.0
	var ch := nh - 2.8
	_box(c, "CapelaMor", Vector3(cl, ch + 3.0, cw), Vector3(nave_len + cl / 2.0 - 0.1, (ch - 3.0) / 2.0, 0), wall, true)
	var rb := _batch()
	var rise2 := (cw + 1.0) * 0.3
	rb.roof("telha_uv", wall, Vector3(cw + 1.0, rise2, cl + 1.0), Vector3(nave_len + cl / 2.0 - 0.1, ch + rise2 / 2.0, 0), PI / 2.0, 3.6, "madeira_escura")
	rb.box("telha_cumeeira", Vector3(cl + 1.1, 0.26, 0.4), Vector3(nave_len + cl / 2.0 - 0.1, ch + rise2 + 0.05, 0))
	_mesh_node(c, "TelhadoCapela", rb.commit())
	_telhado_colisao(c, Vector3(nave_len + cl / 2.0 - 0.1, ch + rise2 / 2.0, 0), cw + 1.0, rise2, cl + 1.0, PI / 2.0)
	var ab := _batch()
	for sz: float in [-1.0, 1.0]:
		ab.box(ced, Vector3(cl, 0.3, 0.5), Vector3(nave_len + cl / 2.0 - 0.1, ch - 0.15, sz * (cw / 2.0 + 0.1)))
		ab.box("muro", Vector3(cl, 1.0, 0.3), Vector3(nave_len + cl / 2.0 - 0.1, 0.4, sz * (cw / 2.0 + 0.1)))
		for xx: float in [nave_len + 1.6, nave_len + 5.4]:
			ab.box(ced, Vector3(0.4, ch, 0.34), Vector3(xx, ch / 2.0, sz * (cw / 2.0 + 0.1)))
	ab.box("ferro", Vector3(0.12, 1.8, 0.12), Vector3(nave_len + cl - 0.3, ch + rise2 + 0.9, 0))
	ab.box("ferro", Vector3(0.8, 0.12, 0.12), Vector3(nave_len + cl - 0.3, ch + rise2 + 1.4, 0))
	_mesh_node(c, "DetalhesCapela", ab.commit())
	# lampiões de parede nos flancos (só brilho decorativo: sem luz extra)
	for sz: float in [-1.0, 1.0]:
		for xl: float in [nave_len * 0.3, nave_len * 0.7]:
			var lg := _group(c, "LampiaoFlanco_%d_%d" % [int(sz), int(xl)], Transform3D(Basis.IDENTITY, Vector3(xl, 3.6, sz * (half + 0.55))))
			var lb := _batch()
			lb.box("ferro", Vector3(0.08, 0.08, 0.4), Vector3(0, 0, 0))
			lb.box("ferro", Vector3(0.22, 0.34, 0.22), Vector3(0, -0.2, sz * 0.2))
			lb.sphere("chama", 0.07, Vector3(0, -0.2, sz * 0.2), 8, 5)
			_mesh_node(lg, "Malha", lb.commit())
			_halo(lg, Vector3(0, -0.2, sz * 0.2), 1.4, "halo_vela")


## Fachada barroca da igreja principal (inspirada na foto de referência): frontão curvo em S com volutas, cartela e óculo,
## janela grande em arco com caixilhos, janelas altas com sacada de ferro, portal com concha e volutas, pináculos com estrela.
func _fachada_barroca(b: MeshBatch, width: float, fh: float, py: float, pr: float, half: float, ced: String, wall: String) -> void:
	# frontão em S: lajes finas que estreitam em curva suave, com borda ocre acompanhando o contorno
	var n := 30
	var alt := 4.6
	for k in n:
		var u := (float(k) + 0.5) / n
		var ss := u * u * (3.0 - 2.0 * u)
		var hw: float = lerpf(half - 0.35, 1.9, ss)
		var yy: float = fh + 0.2 + k * (alt / n)
		b.box(wall, Vector3(1.4, alt / n + 0.04, hw * 2.0), Vector3(0.7, yy, 0))
		for sz: float in [-1.0, 1.0]:
			b.box(ced, Vector3(0.34, alt / n + 0.06, 0.30), Vector3(-0.05, yy, sz * hw))
	b.box(ced, Vector3(0.7, 0.3, 4.6), Vector3(-0.1, fh + alt + 0.1, 0))
	b.box(ced, Vector3(0.5, 0.2, 5.0), Vector3(-0.1, fh + alt + 0.32, 0))
	# óculo do frontão com raios, e cartela ornamentada logo abaixo
	b.cylinder(ced, 1.0, 1.0, 0.32, Vector3(-0.2, fh + 2.4, 0), Vector3(0, 0, PI / 2.0), 20)
	b.cylinder("janela_escura", 0.66, 0.66, 0.36, Vector3(-0.23, fh + 2.4, 0), Vector3(0, 0, PI / 2.0), 20)
	for k in 4:
		b.box(ced, Vector3(0.12, 0.09, 1.4), Vector3(-0.42, fh + 2.4, 0), Vector3(k * PI / 4.0, 0, 0))
	b.cylinder(ced, 0.62, 0.62, 0.3, Vector3(-0.2, fh - 1.8, 0), Vector3(0, 0, PI / 2.0), 16)
	b.cylinder("ouro_velho", 0.40, 0.40, 0.34, Vector3(-0.24, fh - 1.8, 0), Vector3(0, 0, PI / 2.0), 14)
	for sz: float in [-1.0, 1.0]:
		b.arch(ced, Vector3(-0.2, fh - 1.8, sz * 1.15), 0.5, 0.2, 0.3, 8)
		# voluta grande do ombro do frontão e pináculo com estrela
		b.arch(ced, Vector3(-0.1, fh + 0.3, sz * (half - 1.25)), 0.95, 0.3, 0.38, 10)
		b.box(ced, Vector3(0.55, 1.5, 0.55), Vector3(-0.12, fh + 0.75, sz * (half - 0.28)))
		b.sphere(ced, 0.3, Vector3(-0.12, fh + 1.7, sz * (half - 0.28)), 8, 5)
		b.box("ferro", Vector3(0.06, 1.1, 0.06), Vector3(-0.12, fh + 2.5, sz * (half - 0.28)))
		b.box("ferro", Vector3(0.05, 0.05, 0.7), Vector3(-0.12, fh + 2.75, sz * (half - 0.28)))
		b.box("ferro", Vector3(0.05, 0.7, 0.05), Vector3(-0.12, fh + 2.75, sz * (half - 0.28)))
	# cruz no alto do frontão
	b.box("ferro", Vector3(0.16, 2.8, 0.16), Vector3(-0.1, fh + alt + 1.6, 0))
	b.box("ferro", Vector3(0.14, 0.16, 1.3), Vector3(-0.1, fh + alt + 2.4, 0))
	b.sphere("ouro_velho", 0.2, Vector3(-0.1, fh + alt + 3.1, 0), 6, 4)
	# medalhão redondo esculpido sobre o portal (São Francisco recebendo os estigmas): anel ocre, disco claro, figuras em relevo e festões
	var my := py + pr + 4.2
	b.cylinder(ced, 1.55, 1.55, 0.34, Vector3(-0.30, my, 0), Vector3(0, 0, PI / 2.0), 28)
	b.cylinder("cantaria", 1.28, 1.28, 0.38, Vector3(-0.33, my, 0), Vector3(0, 0, PI / 2.0), 28)
	b.cylinder("reboco_caiado", 1.10, 1.10, 0.40, Vector3(-0.36, my, 0), Vector3(0, 0, PI / 2.0), 28)
	b.cylinder(ced, 0.10, 0.20, 0.8, Vector3(-0.55, my - 0.35, -0.25), Vector3.ZERO, 8)          # frade ajoelhado
	b.sphere(ced, 0.13, Vector3(-0.55, my + 0.15, -0.25), 7, 4)
	b.cylinder(ced, 0.04, 0.06, 0.9, Vector3(-0.55, my - 0.05, 0.38), Vector3.ZERO, 6)           # cruz com o serafim
	b.box(ced, Vector3(0.05, 0.05, 0.5), Vector3(-0.55, my + 0.15, 0.38))
	for k in 3:                                                                                    # raios dos estigmas
		b.box("ouro_velho", Vector3(0.02, 0.02, 0.5), Vector3(-0.50, my + 0.15 - k * 0.12, 0.05), Vector3(0.0, 0.0, 0.25 - k * 0.25))
	for sz: float in [-1.0, 1.0]:
		b.arch(ced, Vector3(-0.32, my - 1.35, sz * 1.0), 0.55, 0.16, 0.22, 8)                      # festões presos ao anel
		b.sphere(ced, 0.16, Vector3(-0.34, my - 1.55, sz * 1.65), 6, 4)
	b.box(ced, Vector3(0.5, 0.3, 0.5), Vector3(-0.34, my + 1.78, 0))                              # fecho com concha no topo
	b.half_disc(ced, Vector3(-0.34, my + 1.62, 0), 0.4, 10)
	# janelas altas com sacada de ferro (como na referência)
	for sz: float in [-1.0, 1.0]:
		var zc := sz * 3.7
		var by := 9.0
		b.box(ced, Vector3(0.9, 0.14, 2.2), Vector3(-0.45, by, zc))
		b.box("ferro", Vector3(0.06, 0.07, 2.1), Vector3(-0.88, by + 0.95, zc))
		b.box("ferro", Vector3(0.06, 0.05, 2.1), Vector3(-0.88, by + 0.12, zc))
		for k in 9:
			b.box("ferro", Vector3(0.04, 0.88, 0.04), Vector3(-0.88, by + 0.5, zc - 1.0 + k * 0.25))
		for dz: float in [-1.05, 1.05]:
			b.box("ferro", Vector3(0.85, 0.06, 0.05), Vector3(-0.45, by + 0.95, zc + dz))
		b.box(ced, Vector3(0.5, 0.2, 1.6), Vector3(-0.3, by + 2.45, zc))                       # verga reta ornamentada
		b.box(ced, Vector3(0.34, 0.5, 0.5), Vector3(-0.25, by + 2.75, zc))
	# portal: concha em leque e volutas sobre a cornija, cartela central com folhagem
	var cy := py + pr + 1.7
	for k in 7:
		var ang := PI * (float(k) + 0.5) / 7.0
		b.box(ced, Vector3(0.24, 0.85, 0.17), Vector3(-0.72, cy + 0.55 + sin(ang) * 0.5, cos(ang) * 0.5), Vector3(PI / 2.0 - ang, 0, 0))
	b.half_disc(ced, Vector3(-0.72, cy + 0.55, 0), 0.42, 10)
	for sz: float in [-1.0, 1.0]:
		b.arch(ced, Vector3(-0.72, cy + 0.2, sz * 1.7), 0.55, 0.22, 0.3, 9)
		b.sphere(ced, 0.2, Vector3(-0.72, cy + 0.2 + 0.1, sz * 2.4), 6, 4)
		for k in 5:
			b.sphere("ouro_velho", 0.06, Vector3(-0.78, cy - 0.1 - k * 0.45, sz * 3.9), 4, 3)      # guirlanda de frutos ao lado da porta


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
	for cs in [[78.0 + Route.SHIFT, -1.0, 58.0], [236.0 + Route.SHIFT, 1.0, 70.0]]:
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
	while placed < 360 and tries < 14000:
		tries += 1
		# casario em TERRAÇOS: fileiras paralelas à rua (a cada 13 m de afastamento), casas a cada ~11 m ao longo dela, todas de frente para a rua
		# (antes cada casa era sorteada em qualquer ponto, com giro aleatório: parecia uma maquete jogada no morro)
		var sc := clampf(snappedf(_rng.randf_range(0.0, Route.length() + 15.0), 11.0) + _rng.randf_range(-0.6, 0.6), 0.0, Route.length())
		var sigma := -1.0 if _rng.randf() < 0.5 else 1.0
		if absf(sc - Route.BRIDGE_S) < 11.0:
			continue
		var d := Route.width(sc) * 0.5 + 21.0 + float(_rng.randi_range(0, 8)) * 13.0 + _rng.randf_range(-0.8, 0.8)
		if d > 150.0:
			continue
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
		var x_axis := (Route.right(sc) * sigma).rotated(Vector3.UP, _rng.randf_range(-0.05, 0.05))
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
		for o in _casas_postas:            # nada de árvore dentro do volume de uma casa
			var qc: Vector3 = (o["xf"] as Transform3D).affine_inverse() * p
			if qc.x > -1.5 and qc.x < float(o["depth"]) + 1.5 and absf(qc.z) < float(o["w"]) / 2.0 + 1.5:
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
		var lan := _prop(g, "Lantern_01", Vector3(0.2, 1.84 + dy2, end * (w / 2.0 - 0.1)), _rng.randf() * TAU, 1.0)     # pousado no topo da bola do pilar
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
		_cont(parent, "Bucket1", p + Basis(Vector3.UP, yaw) * Vector3(0.9, 0, 0), _rng.randf() * TAU)


## Bueiros, barris, caixotes, bancos, carroça, varais e bandeirinhas.
## Plantas de quintal e de talude que ficaram dentro do volume de uma casa vizinha (agora as casas têm fundo de verdade).
func _tira_plantas_dentro_das_casas(root: Node3D) -> void:
	var tirados := 0
	var prefixos := ["arvore_", "palmeira", "bananeira", "arbusto", "samambaia", "capim", "rooibos", "periwinkle", "mato", "weed", "grass"]
	var lotes: Array = []
	for gn in ["MurosEQuintais", "Becos"]:                      # árvores de quintal e de beco que entravam nas salas
		var gr := root.get_node_or_null(gn)
		if gr != null:
			lotes.append_array(gr.get_children())
	for lot in lotes:
		if not (lot is Node3D):
			continue
		for n in (lot as Node3D).get_children().duplicate():
			if not (n is Node3D):
				continue
			var nome := str(n.name)
			var eh_planta := false
			for pf in prefixos:
				if nome.begins_with(pf):
					eh_planta = true
			if not eh_planta:
				continue
			var mundo: Vector3 = (lot as Node3D).transform * (n as Node3D).position
			for o in _casas_postas:
				var q: Vector3 = (o["xf"] as Transform3D).affine_inverse() * mundo
				if q.x > 0.1 and q.x < float(o["depth"]) - 0.1 and absf(q.z) < float(o["w"]) / 2.0 - 0.1:
					lot.remove_child(n)
					n.free()
					tirados += 1
					break
	print("[vila] plantas removidas por estarem dentro de casas: ", tirados)


## Assenta no terreno as plantas dos quintais e taludes (antes ficavam numa altura fixa e, em ladeira, afundavam até 2 m ou pairavam).
func _aterra_plantas(root: Node3D) -> void:
	var grupo := root.get_node_or_null("MurosEQuintais")
	if grupo == null:
		return
	var ajustadas := 0
	var prefixos := ["arvore_", "palmeira", "bananeira", "arbusto", "samambaia", "capim", "rooibos", "periwinkle", "mato", "weed", "grass"]
	for lot in grupo.get_children():
		if not (lot is Node3D):
			continue
		for n in (lot as Node3D).get_children():
			if not (n is Node3D):
				continue
			var nome := str(n.name)
			var eh := false
			for pf in prefixos:
				if nome.begins_with(pf):
					eh = true
			if not eh:
				continue
			var local := (n as Node3D).position
			var mundo: Vector3 = (lot as Node3D).transform * local
			var chao := terrain_h(mundo.x, mundo.z)
			var dy := (chao - 0.04) - mundo.y
			if absf(dy) > 0.15:
				(n as Node3D).position.y += dy / maxf((lot as Node3D).transform.basis.get_scale().y, 0.001)
				ajustadas += 1
	print("[vila] plantas de quintal assentadas no terreno: ", ajustadas)


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
	for cfg in [[153.0 + Route.SHIFT, -1.0], [S_END + 22.0, 1.0]]:
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
	_bar_spot = _spot_livre(-1.0, 144.0 + Route.SHIFT, 0.55, 1.4)      # longe do poste de luz de s=150 (antes a TV e o barril atravessavam o poste)
	if _bar_spot.is_empty():
		_bar_spot = _spot(-1.0, 144.0 + Route.SHIFT, 0.55)
	_reservar(_bar_spot["pos"], 1.4)
	# barris e caixotes junto às paredes
	var count := 0
	var tries := 0
	while count < 80 and tries < 700:
		tries += 1
		var s := _rng.randf_range(10.0, S_END - 8.0)
		if absf(s - Route.BRIDGE_S) < 8.0 or Route.width(s) < 4.4 or _em_curva(s):
			continue                     # nas curvas a beira é o muro de arrimo e as árvores: caixote ali atravessava os dois
		var sigma := -1.0 if _rng.randf() < 0.5 else 1.0
		var base := facade(sigma, s) - Route.right(s) * sigma * 0.4 + Vector3(0, SW_H, 0)
		var out := -Route.right(s) * sigma
		var p := base + out * 0.22        # junto à parede, sem entrar nela: o meio da rua (corredor de 2,2 m) fica livre
		if not _livre(p, 0.95, true) or Route.dist_to_center(p) < 2.3:      # cestos e jarros saem até 0,7 m do ponto
			continue
		_reservar(p, 0.95)
		_recipientes(root, p, atan2(out.x, out.z))
		count += 1
	# bancos de madeira junto às paredes (lado oposto ao bar e ao carro coberto), em vagas LIVRES da calçada e com colisão
	for bs: float in [155.0 + Route.SHIFT, 164.0 + Route.SHIFT, 180.0 + Route.SHIFT]:      # longe dos pontos de querosene (s=150 e 171)
		var spb := _spot_livre(1.0, bs, 0.5, 1.05)
		if spb.is_empty():
			continue
		var perto_de_item := false
		for o in OIL_PTS:                                         # o banco não pode ficar na frente de um frasco de querosene
			if absf(float(o[0]) - Route.nearest_s(spb["pos"])) < 3.0 and float(o[1]) > 0.0:
				perto_de_item = true
		if perto_de_item:
			continue
		_reservar(spb["pos"], 1.05)
		var out: Vector3 = spb["out"]
		var pos: Vector3 = spb["pos"]
		var yaw := atan2(-out.z, out.x) + PI / 2.0
		var basis := Basis(Vector3.UP, yaw)
		b.box("madeira_natural", Vector3(1.7, 0.07, 0.45), pos + basis * Vector3(0, 0.46, 0), Vector3(0, yaw, 0))
		b.box("madeira_natural", Vector3(1.7, 0.4, 0.06), pos + basis * Vector3(0, 0.72, 0.2), Vector3(0, yaw, 0))
		for lx: float in [-0.7, 0.7]:
			b.box("cantaria", Vector3(0.12, 0.44, 0.4), pos + basis * Vector3(lx, 0.22, 0), Vector3(0, yaw, 0))
		var colb := _blocker(root, "ColBanco_%d" % int(bs), Vector3(1.75, 0.95, 0.5), pos + Vector3(0, 0.47, 0))
		colb.rotation.y = yaw
	# carroça de mão estacionada numa vaga livre
	var spc := _spot_livre(1.0, 178.0, 0.9, 1.5)
	if not spc.is_empty():
		_reservar(spc["pos"], 1.5)
		var cp: Vector3 = spc["pos"]
		var ct: Vector3 = spc["tan"]
		var cyaw := atan2(-ct.z, ct.x)
		var cb := Basis(Vector3.UP, cyaw)
		b.box("madeira_natural", Vector3(1.6, 0.08, 0.95), cp + cb * Vector3(0, 0.62, 0), Vector3(0, cyaw, 0))
		for sz: float in [-1.0, 1.0]:
			b.box("madeira_natural", Vector3(1.6, 0.3, 0.05), cp + cb * Vector3(0, 0.8, sz * 0.47), Vector3(0, cyaw, 0))
			b.cylinder("madeira_natural", 0.38, 0.38, 0.07, cp + cb * Vector3(0, 0.38, sz * 0.52), Vector3(PI / 2.0, cyaw, 0), 12)
			b.cylinder("ferro", 0.39, 0.39, 0.05, cp + cb * Vector3(0, 0.38, sz * 0.52), Vector3(PI / 2.0, cyaw, 0), 12)
		b.box("madeira_natural", Vector3(1.2, 0.05, 0.05), cp + cb * Vector3(-1.3, 0.55, 0.3), Vector3(0, cyaw, 0))
		b.box("madeira_natural", Vector3(1.2, 0.05, 0.05), cp + cb * Vector3(-1.3, 0.55, -0.3), Vector3(0, cyaw, 0))
		var colc := _blocker(root, "ColCarroca", Vector3(1.7, 1.0, 1.1), cp + Vector3(0, 0.5, 0))
		colc.rotation.y = cyaw
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
		var junto_de_sala := false                 # casa visitável ao lado: o oratório atravessaria a parede da sala por dentro
		for sid in _entradas_feitas:
			if absf(float(_entradas_feitas[sid]) - s) < 7.5:
				junto_de_sala = true
		if junto_de_sala:
			continue
		var perto_item := false                    # oratório na frente de frasco/bilhete: a interação "acender vela" roubava o clique
		for o in OIL_PTS + NOTE_PTS:
			if absf(float(o[0]) - s) < 3.0 and float(o[1]) == float(j["sigma"]):
				perto_item = true
		if perto_item:
			continue
		var sigma: float = j["sigma"]
		var x_axis := Route.right(s) * sigma
		var origin := facade(sigma, s) + Vector3(0, SW_H, 0)
		var nbasis := Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP))
		if j.has("xf"):
			# alinha à parede do lote vizinho: mesmo plano e mesma direção (antes seguia a tangente da rua e ficava torto nas curvas)
			var lxf: Transform3D = j["xf"]
			origin = lxf.origin + lxf.basis.z * float(j.get("zloc", 0.0))
			origin.y = lxf.origin.y
			nbasis = lxf.basis
		var g := _group(root, "Nicho_%03d" % int(s), Transform3D(nbasis, origin))
		_reservar(origin, 1.6)                     # frente do oratório livre (a interação "acender vela" pegava a medalha posta ali)
		var b := _batch()
		var variante := picked % 3
		match variante:
			0:
				_nicho_aedicula(b, g)
			1:
				_nicho_cruz(b)
			_:
				_nicho_alminhas(b)
		_nicho_oferendas(b, variante)
		_mesh_node(g, "Malha", b.commit())
		if variante != 1:                                  # santa de pedra no nicho (mesmo modelo dos santos da igreja)
			var spr := PropKit.make("gothic_statue", 1.0)
			var sbb2: AABB = spr.get_meta("bb")
			spr.free()
			var alt := 0.95 if variante == 0 else 0.85
			var st := _prop(g, "gothic_statue", Vector3(-0.2, 1.58 if variante == 0 else 1.66, 0.0), -PI / 2.0, alt / maxf(sbb2.size.y, 0.1))
			st.name = "Santa"
			for szv: float in [-1.0, 1.0]:               # vasos de flores com antúrio de verdade (sem bolinhas)
				_parte(g, "anthurium_botany_01", ["anthurium_botany_01_a" if szv < 0.0 else "anthurium_botany_05_e"], Vector3(-0.42, 1.62, szv * 0.52), _rng_f.randf() * TAU, 0.13)
		var l := OmniLight3D.new()
		l.name = "LuzDaVela"
		l.position = Vector3(-0.55, 1.95, 0)
		l.light_color = Color(1.0, 0.62, 0.28) if variante != 2 else Color(1.0, 0.38, 0.14)       # as alminhas ardem em vermelho
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
		var av := Area3D.new()                         # acender uma vela no altar (scripts/vela_votiva.gd)
		av.name = "AcenderVela"
		av.position = Vector3(-0.5, 1.5, 0)
		av.set_script(load("res://scripts/vela_votiva.gd"))
		var cv := CollisionShape3D.new()
		var bv := BoxShape3D.new()
		bv.size = Vector3(1.3, 1.5, 1.6)
		cv.shape = bv
		av.add_child(cv)
		g.add_child(av)
		last_s = s
		picked += 1
	print("[vila] nichos: ", picked)
	return root


## Altares de rua (oratórios). Quadro local: parede em x = 0, rua para -X. Três tipos, em rodízio.
## Tipo 0: aedícula barroca com colunas, frontão quebrado com urna e uma santa de pedra no nicho.
func _nicho_aedicula(b: MeshBatch, g: Node3D) -> void:
	b.box("cantaria", Vector3(0.62, 0.18, 1.06), Vector3(-0.15, 1.32, 0))                         # mísula escalonada
	b.box("cantaria", Vector3(0.48, 0.26, 0.90), Vector3(-0.12, 1.14, 0))
	b.box("cantaria_ocre", Vector3(0.30, 1.72, 0.92), Vector3(-0.03, 2.36, 0))                    # corpo pintado de ocre
	b.box("madeira_escura", Vector3(0.10, 1.12, 0.62), Vector3(-0.19, 2.12, 0))                   # fundo do nicho
	b.half_disc("madeira_escura", Vector3(-0.19, 2.68, 0), 0.31, 12)
	b.arch("cantaria_ocre", Vector3(-0.22, 2.68, 0), 0.36, 0.10, 0.14, 12)
	for sz: float in [-1.0, 1.0]:
		b.cylinder("cantaria_ocre", 0.055, 0.065, 1.55, Vector3(-0.30, 2.15, sz * 0.40), Vector3.ZERO, 10)    # colunas
		b.box("cantaria", Vector3(0.20, 0.08, 0.20), Vector3(-0.30, 1.40, sz * 0.40))
		b.box("cantaria", Vector3(0.22, 0.09, 0.22), Vector3(-0.30, 2.96, sz * 0.40))
		b.sphere("ouro_velho", 0.05, Vector3(-0.32, 3.1, sz * 0.40), 6, 4)
	b.box("cantaria", Vector3(0.52, 0.12, 1.12), Vector3(-0.20, 3.04, 0))                         # entablamento
	for sz: float in [-1.0, 1.0]:                                                                  # frontão quebrado
		b.prism("cantaria_ocre", Vector3(0.40, 0.30, 0.48), Vector3(-0.17, 3.25, sz * 0.27))
	b.cylinder("cantaria", 0.07, 0.10, 0.26, Vector3(-0.17, 3.30, 0), Vector3.ZERO, 8)          # urna central
	b.sphere("cantaria", 0.10, Vector3(-0.17, 3.48, 0), 7, 4)
	b.box("ferro", Vector3(0.035, 0.30, 0.035), Vector3(-0.17, 3.74, 0))
	b.box("ferro", Vector3(0.035, 0.035, 0.18), Vector3(-0.17, 3.82, 0))
	# santa: modelo real de estátua (Poly Haven, CC0), com auréola dourada
	var sprobe := PropKit.make("gothic_statue", 1.0)
	var sbb: AABB = sprobe.get_meta("bb")
	sprobe.free()
	var st := _prop(g, "gothic_statue", Vector3(-0.17, 1.52, 0), -PI / 2.0, 0.82 / maxf(sbb.size.y, 0.1))
	st.name = "Santa"
	b.cylinder("ouro_velho", 0.14, 0.14, 0.015, Vector3(-0.25, 2.55, 0), Vector3(0, 0, PI / 2.0), 14)
	# terço caindo das mãos
	for k in 9:
		b.sphere("ouro_velho" if k % 3 == 0 else "madeira_escura", 0.016, Vector3(-0.27, 2.05 - k * 0.04, 0.05 + 0.012 * sin(k * 0.9)), 4, 3)


## Tipo 1: cruz grande de madeira com pano roxo, coroa de espinhos e placa, sobre pedestal de pedra.
func _nicho_cruz(b: MeshBatch) -> void:
	b.box("cantaria", Vector3(0.50, 0.22, 0.90), Vector3(-0.15, 1.30, 0))                          # mísula
	b.box("cantaria_ocre", Vector3(0.20, 2.30, 0.80), Vector3(-0.02, 2.30, 0))                    # painel de fundo
	b.box("reboco_creme", Vector3(0.05, 2.05, 0.62), Vector3(-0.13, 2.30, 0))
	b.box("cantaria", Vector3(0.12, 0.10, 0.90), Vector3(-0.08, 3.50, 0))
	b.prism("cantaria_ocre", Vector3(0.20, 0.34, 0.86), Vector3(-0.04, 3.72, 0))
	b.box("madeira_natural", Vector3(0.10, 1.50, 0.10), Vector3(-0.22, 2.35, 0))                  # cruz de madeira clara
	b.box("madeira_natural", Vector3(0.10, 0.10, 0.70), Vector3(-0.22, 2.80, 0))
	b.box("pano_rosa", Vector3(0.05, 0.62, 0.20), Vector3(-0.27, 2.55, 0.28), Vector3(0.0, 0.0, 0.0))   # pano roxo-rosado pendurado no braço
	b.box("pano_rosa", Vector3(0.05, 0.45, 0.16), Vector3(-0.27, 2.62, -0.24))
	b.box("papel", Vector3(0.02, 0.06, 0.20), Vector3(-0.27, 3.12, 0))                            # placa
	for k in 10:                                                                                   # coroa de espinhos
		var a := TAU * k / 10.0
		b.box("madeira_escura", Vector3(0.02, 0.02, 0.05), Vector3(-0.27, 2.82 + sin(a) * 0.07, cos(a) * 0.07), Vector3(a, 0, 0))
	b.box("cantaria", Vector3(0.40, 0.08, 0.30), Vector3(-0.30, 1.43, 0))


## Tipo 2: alminhas, painel pintado com almas no purgatório entre chamas, caixa de esmolas e telhadinho.
func _nicho_alminhas(b: MeshBatch) -> void:
	b.box("cantaria", Vector3(0.50, 0.20, 0.96), Vector3(-0.14, 1.30, 0))                          # mísula
	b.box("cantaria_ocre", Vector3(0.28, 1.62, 0.92), Vector3(-0.04, 2.28, 0))
	b.box("bradador_preto", Vector3(0.05, 1.12, 0.66), Vector3(-0.20, 2.20, 0))                   # painel escuro
	b.half_disc("bradador_preto", Vector3(-0.20, 2.76, 0), 0.33, 12)
	b.arch("cantaria", Vector3(-0.22, 2.76, 0), 0.38, 0.09, 0.12, 12)
	b.box("ouro_velho", Vector3(0.03, 0.14, 0.14), Vector3(-0.245, 2.95, 0))                      # figura de Cristo no alto
	b.box("ouro_velho", Vector3(0.03, 0.04, 0.30), Vector3(-0.245, 2.98, 0))
	b.box("telha", Vector3(0.62, 0.06, 1.12), Vector3(-0.22, 3.30, 0), Vector3(0.0, 0.0, 0.20))   # telhadinho em água
	b.box("telha_cumeeira", Vector3(0.10, 0.07, 1.14), Vector3(-0.50, 3.38, 0))
	b.box("ferro", Vector3(0.14, 0.18, 0.20), Vector3(-0.22, 1.18, 0.36))                         # caixa de esmolas
	b.box("ferro_ferrugem", Vector3(0.015, 0.012, 0.10), Vector3(-0.30, 1.22, 0.36))


## Oferendas comuns a todos os altares: velas de alturas diferentes com cera derretida, vasos de flores e ex-votos.
func _nicho_oferendas(b: MeshBatch, variante: int) -> void:
	var alturas := [0.14, 0.20, 0.10, 0.17, 0.12]
	var zs := [-0.30, -0.15, 0.0, 0.15, 0.30]
	if variante == 2:
		zs = [-0.30, -0.18, -0.06, 0.06, 0.18]
	b.box("ferro", Vector3(0.30, 0.03, 0.80), Vector3(-0.34, 1.50 + (0.0 if variante != 1 else -0.04), 0))        # grade-prateleira
	for k in 5:
		var y0 := 1.52 + (0.0 if variante != 1 else -0.04)
		b.cylinder("vela", 0.024, 0.026, alturas[k], Vector3(-0.34, y0 + alturas[k] * 0.5, zs[k]), Vector3.ZERO, 6)
		b.sphere("chama", 0.022, Vector3(-0.34, y0 + alturas[k] + 0.03, zs[k]), 5, 3)
		b.cylinder("vela", 0.04, 0.04, 0.025, Vector3(-0.34, y0 + 0.012, zs[k]), Vector3.ZERO, 7)             # poça de cera
	if variante != 2:
		for sz: float in [-1.0, 1.0]:                                                                           # vasos de flores dos dois lados
			var vx := -0.42
			var vz: float = sz * 0.52
			b.cylinder("cantaria", 0.075, 0.05, 0.10, Vector3(vx, 1.57, vz), Vector3.ZERO, 14)                  # jarra de louça branca
			b.cylinder("ouro_velho", 0.082, 0.082, 0.018, Vector3(vx, 1.625, vz), Vector3.ZERO, 14)              # friso dourado na boca
			b.cylinder("ouro_velho", 0.052, 0.052, 0.012, Vector3(vx, 1.515, vz), Vector3.ZERO, 14)              # pé
	for k in 6:                                                                                                  # ex-votos de lata e cera na parede
		var zz := -0.55 + k * 0.22
		b.box("ouro_velho", Vector3(0.015, 0.09, 0.07), Vector3(-0.03, 1.15 + 0.07 * float(k % 3), zz), Vector3(0.0, 0.0, 0.2 * float(k % 2)))
	b.box("ferro", Vector3(0.14, 0.03, 0.03), Vector3(-0.12, 3.05 + (0.45 if variante == 2 else 0.0), 0.48))       # suporte de lampião vazio


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
	_halo(parent, Vector3(0, y, 0), size * 1.5, "halo_vela")      # brilho suave e redondo (antes era um quadrado branco estourado)


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
	elif tipo == "reliquia":
		# medalha da Irmandade: disco de latão com borda e cruz em relevo, de pé APOIADA na calçada (antes 12 cm no ar), com um brilho quente
		b.cylinder("ouro_velho", 0.10, 0.10, 0.025, Vector3(0, 0.505, 0), Vector3(PI / 2.0, 0, 0), 24)
		b.cylinder("cantaria_ocre", 0.075, 0.075, 0.03, Vector3(0, 0.505, 0), Vector3(PI / 2.0, 0, 0), 24)
		b.box("ouro_velho", Vector3(0.018, 0.10, 0.034), Vector3(0, 0.505, 0))
		b.box("ouro_velho", Vector3(0.060, 0.018, 0.034), Vector3(0, 0.525, 0))
		b.cylinder("ouro_velho", 0.012, 0.012, 0.04, Vector3(0, 0.625, 0), Vector3(PI / 2.0, 0, 0), 12)
		_halo(a, Vector3(0, 0.505, 0), 0.9, "halo_vela")
	else:
		var dia := _prop(a, "binder_notebook", Vector3.ZERO, _rng.randf_range(-0.8, 0.8), 0.85)
		dia.name = "Diario"
		_brilho(a, 0.2, 0.45)
	_mesh_node(a, "Malha", b.commit())
	parent.add_child(a)


const OIL_PTS := [[26.0, 1.0], [70.0, -1.0], [108.0, 1.0], [150.0, 1.0], [171.0, -1.0], [205.0, 1.0], [240.0, -1.0], [262.0, -1.0], [290.0, 1.0], [320.0, 1.0], [345.0, -1.0]]
const NOTE_PTS := [[3.0, 1.0, 11], [101.0, -1.0, 0], [166.0, -1.0, 18], [252.0, 1.0, 19], [293.0, -1.0, 20], [365.0, 1.0, 5]]      # na rua: o diário de Tomé em capítulos (11, 18, 19, 20) e dois bilhetes de regras (0, 5)


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
	# doze medalhas da Irmandade escondidas junto às paredes, cantos e escadas: exploração com recompensa
	var ri := 0
	for rs: float in [38.0, 96.0, 130.0, 178.0, 214.0, 252.0, 286.0, 316.0, 338.0, 362.0, 386.0, 404.0]:
		var rsig := 1.0 if ri % 2 == 0 else -1.0
		var rs2 := rs
		var achou := false
		for lado: float in [rsig, -rsig]:                                   # vaga livre, junto a parede de casa e longe de porta
			for off: float in [0.0, 1.2, -1.2, 2.4, -2.4, 3.6, -3.6, 4.8, -4.8, 6.0, -6.0, 7.2, -7.2]:
				var cand := facade(lado, rs + off) - Route.right(rs + off) * lado * 0.35 + Vector3(0, SW_H, 0)
				if _livre(cand, 0.7, true) and _parede_de_casa(facade(lado, rs + off), 0.7) and not _perto_de_porta(cand, 1.4):
					rs2 = rs + off
					rsig = lado
					achou = true
					break
			if achou:
				break
		if not achou:                                                       # 2ª busca: qualquer vaga livre da calçada até 14 m dali
			for lado2: float in [rsig, -rsig]:
				for k in range(1, 24):
					var off2 := (k / 2) * 1.2 * (1.0 if k % 2 == 0 else -1.0)
					var cand2 := facade(lado2, rs + off2) - Route.right(rs + off2) * lado2 * 0.35 + Vector3(0, SW_H, 0)
					if _livre(cand2, 0.5, true) and not _perto_de_porta(cand2, 1.0):
						rs2 = rs + off2
						rsig = lado2
						achou = true
						break
				if achou:
					break
		var rp := facade(rsig, rs2) - Route.right(rs2) * rsig * 0.35 + Vector3(0, SW_H - 0.4, 0)      # deitada na calçada (antes ficava na beira, 12 cm acima da sarjeta)
		_reservar(rp + Vector3(0, 0.4, 0), 0.7)
		_coletavel(root, "Reliquia_%02d" % ri, rp, "reliquia", 0, "Pegar a medalha")
		ri += 1
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


## Colisão de telhado de duas águas (prisma): cumeeira ao longo de Z (antes de girar `yaw`), `pos` = centro do prisma.
func _telhado_colisao(parent: Node3D, pos: Vector3, sx: float, rise: float, sz: float, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = "ColisaoTelhado"
	body.position = pos
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for sx2: float in [-0.5, 0.5]:
		for sz2: float in [-0.5, 0.5]:
			pts.append(Vector3(sx2 * sx, -rise * 0.5, sz2 * sz))
	for sz3: float in [-0.5, 0.5]:
		pts.append(Vector3(0.0, rise * 0.5, sz3 * sz))
	shape.points = pts
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


## Uma peça isolada de um .glb que é "folha de catálogo" (ver PropKit.make_filtrado).
func _parte(parent: Node, key: String, manter: Array, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	var p := PropKit.make_filtrado(key, manter, scale, "chao")
	p.name = "%s_%03d" % [manter[0], _n]
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


## Trecho em curva (a "fachada" ali é o muro de arrimo, não parede de casa).
func _em_curva(s: float) -> bool:
	return Route.tangent(s - 1.5).angle_to(Route.tangent(s + 1.5)) > 0.03


## Perto de casa visitável (a parede da frente é a parede da sala por dentro: nada pode encostar nela por fora).
func _perto_de_sala(s: float, r := 7.5) -> bool:
	for sid in _entradas_feitas:
		if absf(float(_entradas_feitas[sid]) - s) < r:
			return true
	return false


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
## Ratos de rua parados junto às paredes (fogem quando o jogador chega perto: scripts/rato.gd).
func _ratos() -> Node3D:
	var root := Node3D.new()
	root.name = "Ratos"
	var i := 0
	for s: float in [34.0, 87.0, 126.0, 181.0, 226.0, 261.0, 299.0, 333.0]:
		var sigma := -1.0 if i % 2 == 0 else 1.0
		var sp := _spot(sigma, s, 0.45)
		var rato := PropKit.make("street_rat", 1.7)
		rato.name = "Rato_%d" % i
		rato.position = sp["pos"]
		rato.rotation.y = float(i) * 1.7
		rato.set_script(load("res://scripts/rato.gd"))
		root.add_child(rato)
		i += 1
	return root


func _props_rua() -> Node3D:
	var root := Node3D.new()
	root.name = "Props"
	# --- bar com a TV ligada na calçada do largo (as pessoas se juntavam para ver TV nos bares): barril, TV, banquinhos
	var bar: Dictionary = _bar_spot
	var barril := _prop(root, "wine_barrel_01", bar["pos"], 0.0, 1.0)
	_prop_collision(barril, "cil", Vector3(0.72, 0.85, 0.72), Vector3(0, 0.43, 0))
	var topo_barril := 0.86
	if barril.has_meta("bb"):
		var bbb: AABB = barril.get_meta("bb")
		topo_barril = bbb.position.y + bbb.size.y            # a TV fica EM CIMA do tampo (antes afundava 34 cm no barril)
	_tv(root, bar["pos"] + Vector3(0, topo_barril, 0), _yaw_to(bar["out"]))
	for k in 2:
		var sb := _spot(-1.0, 147.0 + Route.SHIFT + k * 3.0, 0.9)
		if not _livre(sb["pos"], 0.45, true):
			continue
		_reservar(sb["pos"], 0.45)
		var banco := _prop(root, "wooden_stool_01", sb["pos"], _rng.randf() * TAU, 1.0)
		_prop_collision(banco, "cil", Vector3(0.4, 0.44, 0.4), Vector3(0, 0.22, 0))
	# --- carros cobertos com lona, estacionados na borda do largo e do adro
	for cfg in [[153.0 + Route.SHIFT, -1.0], [S_END + 22.0, 1.0]]:
		var sg: float = cfg[1]
		var s: float = float(_carros_s.get(int(cfg[0]), cfg[0]))
		var c := Route.pos(s) + Route.right(s) * sg * (Route.width(s) * 0.5 - 1.25)
		var carro := _prop(root, "covered_car", c, _yaw_to(Route.tangent(s)) + (0.0 if sg < 0 else PI), 1.0)
		carro.position.y = c.y + 0.02
		_prop_collision(carro, "caixa", Vector3(1.9, 1.4, 4.4), Vector3(0, 0.7, 0))
		# esconderijo atrás do carro, do lado da parede
		var toward_wall := Route.right(s) * sg
		var ec := _esconderijo(root, "EsconderijoCarro_%d" % int(s), c + toward_wall * 0.2 + Vector3(0, 0.9, 0), Vector3(3.0, 1.8, 5.2), c + toward_wall * 1.45 + Vector3(0, 0.05, 0), _yaw_to(toward_wall))
		ec.rotation.y = _yaw_to(Route.tangent(s))        # o gatilho acompanha o carro (antes ficava alinhado ao mundo: só servia em ruas retas no eixo Z)
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
	var bola := _prop(root, "football", _spot(1.0, 157.0 + Route.SHIFT, 2.6)["pos"], _rng.randf() * TAU, 1.0)
	bola.name = "BolaEsquecida"
	# --- ferramentas e utilidades de 1961 encostadas nas paredes: escadas, machados, regadores, lousas de cardápio
	for cfg in [[48.0, 1.0], [110.0, -1.0], [190.0, 1.0], [240.0, 1.0], [298.0, -1.0], [348.0, 1.0]]:
		if Route.width(cfg[0]) < 4.6:        # rua estreita: a escada (0,8 m de fundo) invadiria o corredor de passagem
			continue
		var sl := _spot(cfg[1], cfg[0], 0.55)
		if not _livre(sl["pos"], 0.7, true) or not _parede_de_casa(facade(float(cfg[1]), float(cfg[0])), 0.7) or _perto_de_sala(float(cfg[0])):
			continue                         # escada só encostada em parede de casa (na curva ela atravessava o muro de arrimo)
		_reservar(sl["pos"], 0.7)
		var esc := _prop(root, "wooden_ladder", sl["pos"], _yaw_to(sl["out"]), 1.6)
		esc.rotation.x = -0.2
		_prop_collision(esc, "caixa", (esc.get_meta("bb") as AABB).size, (esc.get_meta("bb") as AABB).get_center())
	for cfg in [[36.0, 1.0], [101.0, 1.0], [186.0, -1.0], [276.0, 1.0]]:
		var sa2 := _spot(cfg[1], cfg[0], 0.3)
		if not _livre(sa2["pos"], 0.4, true) or _perto_de_sala(float(cfg[0])) or _em_curva(float(cfg[0])):
			continue                         # machado encostado: nunca em casa visitável (atravessava a parede da sala) nem no muro da curva
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
