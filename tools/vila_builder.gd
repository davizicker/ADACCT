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
const SW_H := 0.15
const MATS := "res://assets/materials/"
const S_END := Route.S_END     # a partir daqui começa o adro da igreja
const CHURCH_S := Route.CHURCH_S

const WALLS: Array[String] = ["reboco_branco", "reboco_ocre", "reboco_amarelo", "reboco_azul", "reboco_salmao", "reboco_verde", "reboco_branco_novo", "reboco_creme"]
const WALL_WEIGHT: Array[int] = [30, 14, 18, 8, 8, 4, 6, 12]
const WOODS: Array[String] = ["madeira_azul", "madeira_vermelha", "madeira_verde", "madeira_ocre", "madeira_natural", "madeira_branca"]
## becos em escada: [s, lado]
const ALLEYS: Array = [[40.0, 1.0], [88.0, -1.0], [136.0, -1.0], [188.0, 1.0], [226.0, 1.0], [262.0, -1.0], [286.0, 1.0]]
const FOUNTAIN := [160.0, 1.0]

var _rng := RandomNumberGenerator.new()
var _cache := {}
var _veg := {}
var _rs := PackedVector2Array()
var _noise_lo: FastNoiseLite
var _noise_hi: FastNoiseLite
var _n := 0
var _spots: Array[Vector2] = []
var _lamp_n := 0
var _haunted := 0
var _joints: Array[Dictionary] = []   # junções entre lotes (onde ficam nichos)
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


func _plant(parent: Node, key: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	var n := (_veg[key] as PackedScene).instantiate() as Node3D
	n.name = "%s_%03d" % [key, _n]
	_n += 1
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
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
	var n := _noise_lo.get_noise_2d(x, z) * 16.0 + _noise_hi.get_noise_2d(x, z) * 3.0
	# leito do riacho que passa sob a ponte (cruza a rua; some longe, nas encostas)
	var carve := 3.6 * (1.0 - smoothstep(3.0, 6.8, absf(q.x - Route.BRIDGE_S))) * (1.0 - smoothstep(55.0, 85.0, q.y))
	return base + rise + n * smoothstep(0.0, 25.0, t) - carve
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
					var col := Color(0.62, 0.80, 0.50).lerp(Color(0.80, 0.74, 0.64), clampf(slope * 1.1 - 0.15, 0.0, 1.0))
					col *= 0.75 + 0.35 * g
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
func _road() -> Node3D:
	var root := Node3D.new()
	root.name = "Rua"
	var chunk := 30.0
	var count := int(ceil(Route.length() / chunk))
	for ci in count:
		var s0 := ci * chunk
		var s1 := minf(Route.length(), s0 + chunk)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prev: Array[Vector3] = []
		var s_cur := s0
		while true:
			var c := Route.pos(s_cur)
			var r := Route.right(s_cur)
			var a := Route.width(s_cur) * 0.5
			# perfil transversal: calçada, meio-fio, sarjeta, coroa, sarjeta, meio-fio, calçada
			var prof := [
				Vector2(-a - SW, SW_H), Vector2(-a, SW_H), Vector2(-a, 0.0), Vector2(-a + 0.25, -0.04),
				Vector2(0.0, 0.03), Vector2(a - 0.25, -0.04), Vector2(a, 0.0), Vector2(a, SW_H), Vector2(a + SW, SW_H),
			]
			var cur: Array[Vector3] = []
			for p: Vector2 in prof:
				cur.append(c + r * p.x + Vector3(0, p.y, 0))
			if not prev.is_empty():
				for j in prof.size() - 1:
					var expect := Vector3.UP
					if j == 1:
						expect = r
					elif j == 6:
						expect = -r
					MeshBatch.tri(st, prev[j], prev[j + 1], cur[j + 1], expect)
					MeshBatch.tri(st, prev[j], cur[j + 1], cur[j], expect)
			prev = cur
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
	env.ambient_light_energy = 0.50
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
	l.light_energy = 0.42
	l.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	l.shadow_enabled = true
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
	root.add_child(_lamps())
	root.add_child(_adornos())
	root.add_child(_nichos())
	root.add_child(_coletaveis())
	_bridge(root)
	root.add_child(_church_plaza())
	root.add_child(_hillside())
	root.add_child(_serra())
	root.add_child(_route_path())
	# Desempenho: a neblina esconde o que está longe, então nem desenhamos.
	for name in ["Casas", "MurosEQuintais", "Becos", "FundoDaRua"]:
		var n := root.get_node_or_null(name)
		if n:
			_set_range(n, 170.0)
	_set_range(root.get_node("Morros/CasasDoMorro"), 360.0)
	_set_range(root.get_node("Morros/Arvores"), 220.0)
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
	for sigma: float in [-1.0, 1.0]:
		var s := 0.0
		var prev_special := true
		var done_alley := {}
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
					w = 3.0
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
			var s2 := _advance(sigma, s, w)
			var f := lot_frame(sigma, s, s2)
			match kind:
				"casa":
					_lot_casa(casas, f, sigma, w_street)
				"quintal":
					_lot_quintal(muros, f)
				"talude":
					_lot_talude(muros, f)
				"beco":
					_lot_beco(becos, f)
				"chafariz":
					_lot_chafariz(muros, f)
				"ponte":
					_lot_ponte(muros, f, sigma)
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
	var casa := make_casa(26.0, 2, "reboco_branco", "madeira_azul", 12.0, true, 0.35, true)
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
	var casa := make_casa(f["w"], floors, _pick_wall(), WOODS[_rng.randi() % WOODS.size()], _rng.randf_range(9.0, 12.0),
		floors >= 2 and _rng.randf() < 0.55, 0.28, false, haunted)
	casa.name = "Casa_%02d" % _n
	_n += 1
	casa.transform = f["xf"]
	parent.add_child(casa)


# ------------------------------------------------------------------ casa colonial

## `w` largura da fachada; `floors` 1–3; `depth` profundidade; `lit_p` chance de janela acesa.
func make_casa(w: float, floors: int, wall: String, wood: String, depth: float, balcony: bool, lit_p: float, simple: bool, haunted := false) -> Node3D:
	var c := Node3D.new()
	c.name = "Casa"
	var fh := 4.0
	var up := 3.4
	var height := fh + (floors - 1) * up
	_box(c, "Corpo", Vector3(depth, height + 4.0, w), Vector3(depth / 2.0, height / 2.0 - 2.0, 0), wall, true)
	var rise := (depth + 1.4) * 0.27
	var prism := PrismMesh.new()
	prism.size = Vector3(depth + 1.4, rise, w + 0.5)
	var roof := _mesh_node(c, "Telhado", prism, Vector3(depth / 2.0 - 0.2, height + 0.15 + rise / 2.0, 0))
	roof.material_override = mat("telha")

	var b := _batch()
	b.box("muro", Vector3(0.3, 5.1, w + 0.1), Vector3(-0.1, -1.45, 0))            # embasamento de pedra
	b.box("cantaria", Vector3(0.55, 0.25, w + 0.2), Vector3(-0.27, height - 0.35, 0))  # cornija
	for k in int(w / 0.9):
		var z := -w / 2.0 + 0.5 + k * 0.9
		b.box("madeira_natural", Vector3(0.8, 0.12, 0.14), Vector3(-0.4, height + 0.04, z))   # cachorros do beiral
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
	# porta com moldura de cantaria; em arco nos sobrados "arqueados"
	var arched := (not simple) and _rng.randf() < 0.5
	if arched:
		var dr := 0.72
		var dh := 3.0
		for sz: float in [-1.0, 1.0]:
			b.box("cantaria", Vector3(0.2, dh - dr + 0.1, 0.22), Vector3(-0.08, (dh - dr) / 2.0, dz + sz * (dr + 0.11)))
		b.arch("cantaria", Vector3(-0.08, dh - dr, dz), dr + 0.11, 0.22, 0.2, 9)
		b.box(wood, Vector3(0.08, dh - dr, dr * 2.0), Vector3(-0.18, (dh - dr) / 2.0, dz))
		b.half_disc(wood, Vector3(-0.225, dh - dr, dz), dr)
		b.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 0.7, dz - 0.34))
		b.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 0.7, dz + 0.34))
		b.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 1.9, dz - 0.34))
		b.box("madeira_natural", Vector3(0.03, 0.9, 0.5), Vector3(-0.235, 1.9, dz + 0.34))
	else:
		b.box("cantaria", Vector3(0.2, 3.1, 1.8), Vector3(-0.08, 1.55, dz))
		b.box(wood, Vector3(0.08, 2.7, 1.4), Vector3(-0.18, 1.35, dz))
		for pz in [-0.34, 0.34]:
			for py in [0.8, 1.95]:
				b.box("madeira_natural", Vector3(0.03, 0.75, 0.5), Vector3(-0.235, py, dz + pz))
		b.box("janela_escura", Vector3(0.05, 0.32, 1.3), Vector3(-0.2, 2.9, dz))
	b.box("cantaria", Vector3(0.5, 0.15, 2.0), Vector3(-0.25, -0.03, dz))                         # soleira

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
		b.box(wall, Vector3(0.7, 1.8, 0.7), Vector3(depth / 2.0 - 0.2, height + rise + 0.45, _rng.randf_range(-w * 0.3, w * 0.3)))
		b.box("cantaria", Vector3(0.85, 0.12, 0.85), Vector3(depth / 2.0 - 0.2, height + rise + 1.4, 0))
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
	_mesh_node(c, "Detalhes", b.commit())
	return c


## Placa pendurada de loja (Label3D = texto em 3D, editável no Inspetor).
func _sign(c: Node3D, b: MeshBatch, z: float) -> void:
	var names := ["ARMAZÉM", "BOTICA", "BARBEARIA", "PADARIA", "SAPATARIA", "TECIDOS", "FERRARIA", "PENSÃO", "OURIVES", "ALFAIATE"]
	var text: String = names[_rng.randi() % names.size()]
	b.box("ferro", Vector3(1.15, 0.05, 0.05), Vector3(-0.58, 3.55, z))
	for dz: float in [-0.38, 0.38]:
		b.box("ferro", Vector3(0.02, 0.25, 0.02), Vector3(-1.0, 3.4, z + dz))
	b.box("madeira_escura", Vector3(0.95, 0.46, 0.05), Vector3(-0.62, 3.05, z))
	for side: float in [1.0, -1.0]:
		var l := Label3D.new()
		l.name = "Texto"
		l.text = text
		l.pixel_size = 0.0042
		l.font_size = 64
		l.modulate = Color(0.96, 0.86, 0.58)
		l.outline_size = 0
		l.double_sided = false
		l.position = Vector3(-0.62, 3.05, z + side * 0.03)
		l.rotation.y = 0.0 if side > 0.0 else PI
		c.add_child(l)


## Vaso de flores (terracota + folhagem + flores).
func _pot(b: MeshBatch, p: Vector3) -> void:
	b.cylinder("vaso", 0.11, 0.08, 0.16, p + Vector3(0, 0.08, 0), Vector3.ZERO, 8)
	b.sphere("verde_vaso", 0.17, p + Vector3(0, 0.27, 0), 7, 4)
	var fl: String = ["flor_vermelha", "flor_rosa", "flor_amarela"][_rng.randi() % 3]
	for k in 3:
		b.sphere(fl, 0.045, p + Vector3(_rng.randf_range(-0.12, 0.12), 0.3 + _rng.randf_range(0.0, 0.1), _rng.randf_range(-0.12, 0.12)), 5, 3)


func _window(b: MeshBatch, p: Vector3, wid: float, hgt: float, wood: String, lit: bool, grate: bool, door := false, arch := false) -> void:
	var glass := "janela_acesa" if lit else "janela_escura"
	if arch:
		# vão com verga em arco (como nos sobrados de Ouro Preto): parte reta + meio disco
		var r := wid * 0.5
		var hr := hgt - r
		var base_y := p.y - hgt / 2.0
		var spring := base_y + hr
		for sz: float in [-1.0, 1.0]:
			b.box("cantaria", Vector3(0.18, hr + 0.15, 0.2), Vector3(-0.07, base_y + hr / 2.0 - 0.02, p.z + sz * (r + 0.1)))
		b.arch("cantaria", Vector3(-0.07, spring, p.z), r + 0.1, 0.2, 0.18, 9)
		b.quad(glass, Vector2(wid, hr), Vector3(-0.17, base_y + hr / 2.0, p.z), -PI / 2.0)
		b.half_disc(glass, Vector3(-0.17, spring, p.z), r)
		b.box(wood, Vector3(0.05, hgt, 0.05), Vector3(-0.19, p.y, p.z))
		b.box(wood, Vector3(0.05, 0.05, wid), Vector3(-0.19, base_y + hr * 0.55, p.z))
		if not door:
			b.box("cantaria", Vector3(0.34, 0.1, wid + 0.5), Vector3(-0.17, base_y - 0.1, p.z))
		return
	b.box("cantaria", Vector3(0.18, hgt + 0.4, wid + 0.4), Vector3(-0.07, p.y, p.z))
	b.quad(glass, Vector2(wid, hgt), Vector3(-0.17, p.y, p.z), -PI / 2.0)
	b.box(wood, Vector3(0.05, hgt, 0.05), Vector3(-0.19, p.y, p.z))
	b.box(wood, Vector3(0.05, 0.05, wid), Vector3(-0.19, p.y + hgt * 0.14, p.z))
	if not door:
		b.box(wood, Vector3(0.05, 0.05, wid), Vector3(-0.19, p.y - hgt * 0.28, p.z))
		b.box("cantaria", Vector3(0.34, 0.1, wid + 0.5), Vector3(-0.17, p.y - hgt / 2.0 - 0.25, p.z))   # peitoril
		if _rng.randf() < 0.16:
			_pot(b, Vector3(-0.3, p.y - hgt / 2.0 - 0.2, p.z))
	if grate:
		for k in 5:
			b.box("ferro", Vector3(0.03, hgt, 0.03), Vector3(-0.26, p.y, p.z - wid / 2.0 + wid * k / 4.0))


func _balcony(b: MeshBatch, z0: float, z1: float, floor_y: float, wood: String) -> void:
	var bw := z1 - z0
	var bz := (z0 + z1) * 0.5
	var iron := _rng.randf() < 0.7
	var rail := "ferro" if iron else "madeira_natural"
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
	var posts := int(bw / (0.16 if iron else 0.22))
	for k in posts + 1:
		b.box(rail, Vector3(0.025 if iron else 0.045, 0.88, 0.025 if iron else 0.045), Vector3(-1.2, floor_y + 0.56, z0 + bw * k / posts))


# ------------------------------------------------------------------ lotes especiais

func _wall_ivy(parent: Node3D, w: float, height: float, x := -0.03) -> void:
	var count := maxi(1, int(w / 2.2))
	for i in count:
		var q := QuadMesh.new()
		var qh := height * _rng.randf_range(0.5, 0.8)
		q.size = Vector2(2.4, qh)
		var mi := _mesh_node(parent, "Hera_%d" % i, q, Vector3(x, height - qh / 2.0 - 0.1, -w / 2.0 + (i + 0.5) * w / count))
		mi.rotation.y = -PI / 2.0
		mi.material_override = mat("hera")


func _lot_quintal(parent: Node3D, f: Dictionary) -> void:
	var w: float = f["w"]
	var g := _group(parent, "Quintal_%02d" % _n, f["xf"])
	_n += 1
	var wall_h := _rng.randf_range(2.1, 2.6)
	_box(g, "Muro", Vector3(0.5, wall_h + 1.5, w + 0.1), Vector3(0.25, (wall_h - 1.5) / 2.0, 0), "muro", true)
	var b := _batch()
	b.box("cantaria", Vector3(0.8, 0.14, w + 0.25), Vector3(0.25, wall_h + 0.07, 0))   # capa do muro
	var gz := _rng.randf_range(-w * 0.2, w * 0.2)
	for sz: float in [-1.0, 1.0]:
		b.box("cantaria", Vector3(0.7, wall_h + 0.6, 0.45), Vector3(0.0, (wall_h + 0.6) / 2.0 - 0.3, gz + sz * 0.95))   # pilares do portão
		b.box("cantaria", Vector3(0.8, 0.2, 0.6), Vector3(0.0, wall_h + 0.7, gz + sz * 0.95))
	b.box("madeira_natural", Vector3(0.1, wall_h - 0.2, 1.5), Vector3(-0.1, (wall_h - 0.2) / 2.0, gz))
	b.box("ferro", Vector3(0.12, 0.05, 1.5), Vector3(-0.17, wall_h * 0.55, gz))
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
	var g := _group(parent, "Talude_%02d" % _n, f["xf"])
	_n += 1
	var ht := _rng.randf_range(3.0, 4.6)
	_box(g, "MuroDeArrimo", Vector3(0.8, ht + 2.0, w + 0.1), Vector3(0.4, (ht - 2.0) / 2.0, 0), "muro", true)
	_box(g, "Terraco", Vector3(8.0, ht + 1.0, w), Vector3(4.8, (ht - 1.0) / 2.0 - 0.25, 0), "terreno")
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
func _lot_beco(parent: Node3D, f: Dictionary) -> void:
	var wb: float = f["w"]
	var g := _group(parent, "Beco_%02d" % _n, f["xf"])
	_n += 1
	var steps := 36
	var run := 0.45
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
		_blocker(g, "Parede_%d" % int(sz), Vector3(run_len + 2.0, total + 6.0, 0.6), Vector3(run_len / 2.0, total / 2.0, sz * (wb / 2.0 + 0.3)))
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
	var gate := _batch()
	gate.box("cantaria", Vector3(0.5, 3.0, wb + 1.0), Vector3(run_len + 0.35, total + 1.5, 0))
	gate.box("madeira_natural", Vector3(0.12, 2.3, wb - 0.6), Vector3(run_len + 0.0, total + 1.15, 0))
	_mesh_node(g, "Portao", gate.commit())
	_plant(g, "arvore_%d" % _rng.randi_range(0, 2), Vector3(run_len + 3.0, total - 0.6, 0.5), _rng.randf() * TAU, 1.2)
	_plant(g, "bananeira", Vector3(run_len + 1.5, total - 0.3, -wb), _rng.randf() * TAU, 1.0)
	_plant(g, "samambaia", Vector3(run_len * 0.5, total * 0.5 + 2.7, wb / 2.0 + 0.6), 0.0, 1.2)
	var lamp := _lantern_wall(Vector3(run_len * 0.4, total * 0.4 + 2.4, wb / 2.0 - 0.55), PI)
	g.add_child(lamp)


## Chafariz de pedra encostado numa fachada, com bacia.
func _lot_chafariz(parent: Node3D, f: Dictionary) -> void:
	var w: float = f["w"]
	var g := _group(parent, "Chafariz", f["xf"])
	var b := _batch()
	b.box("cantaria", Vector3(1.0, 4.4, w), Vector3(0.5, 0.5, 0))                           # corpo
	b.box("cantaria", Vector3(1.3, 0.3, w + 0.3), Vector3(0.45, 2.85, 0))                    # cornija
	b.box("cantaria", Vector3(1.0, 1.1, w * 0.5), Vector3(0.5, 3.45, 0))                     # frontão
	b.box("cantaria", Vector3(1.0, 0.7, w * 0.25), Vector3(0.5, 4.3, 0))
	b.box("janela_escura", Vector3(0.1, 1.6, 1.3), Vector3(-0.02, 1.9, 0))                    # nicho
	b.box("cantaria", Vector3(0.3, 0.3, 0.3), Vector3(-0.25, 1.1, 0))                         # bica
	b.box("ferro", Vector3(0.15, 0.1, 0.1), Vector3(-0.4, 1.0, 0))
	b.box("cantaria", Vector3(1.9, 0.85, w - 1.0), Vector3(-1.2, 0.0, 0))                     # bacia
	b.box("janela_escura", Vector3(1.5, 0.04, w - 1.6), Vector3(-1.2, 0.4, 0))                # água
	b.box("cantaria", Vector3(2.4, 0.2, w), Vector3(-1.3, -0.45, 0))                          # degrau
	for sz: float in [-1.0, 1.0]:
		b.box("cantaria", Vector3(0.5, 0.5, 0.9), Vector3(-0.4, 0.0, sz * (w / 2.0 - 0.6)))   # bancos
	_mesh_node(g, "Detalhes", b.commit())
	_blocker(g, "Colisao", Vector3(4.2, 5.0, w), Vector3(0.5, 1.5, 0))
	_plant(g, "palmeira", Vector3(3.0, -0.5, -w * 0.3), 0.0, 1.0)
	_plant(g, "palmeira", Vector3(4.0, -0.5, w * 0.35), 1.0, 1.15)


# ------------------------------------------------------------------ iluminação

func _lamp_light(parent: Node3D, pos: Vector3, energy := 1.6) -> void:
	var light := OmniLight3D.new()
	light.name = "Luz"
	light.position = pos
	light.light_color = Color(1.0, 0.72, 0.35)
	light.light_energy = energy
	light.omni_range = 10.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 50.0
	light.distance_fade_length = 15.0
	light.set_script(load("res://scripts/luz_tremula.gd"))
	light.set("forca", 0.08)
	light.add_to_group("lampioes", true)
	parent.add_child(light)


func make_poste() -> Node3D:
	var p := Node3D.new()
	p.name = "Poste"
	var b := _batch()
	b.box("ferro", Vector3(0.28, 0.5, 0.28), Vector3(0, 0.25, 0))
	b.box("ferro", Vector3(0.1, 3.3, 0.1), Vector3(0, 1.9, 0))
	b.box("ferro", Vector3(0.22, 0.12, 0.22), Vector3(0, 3.5, 0))
	b.box("ferro", Vector3(0.38, 0.1, 0.38), Vector3(0, 4.06, 0))
	b.box("ferro", Vector3(0.2, 0.14, 0.2), Vector3(0, 4.18, 0), Vector3(0, 0.78, 0))
	_mesh_node(p, "Malha", b.commit())
	_glass_node(p, Vector3(0.3, 0.46, 0.3), Vector3(0, 3.78, 0))
	_lamp_light(p, Vector3(0, 3.7, 0))
	return p


## Vidro do lampião como nó próprio (com material só dele), para o apagão poder escurecê-lo.
func _glass_node(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh_node(parent, "Vidro", bm, pos)
	mi.material_override = (mat("vidro_lampiao") as Material).duplicate()


## Lampião preso à parede (para ruas estreitas e becos). `yaw` aponta o braço para a parede.
func _lantern_wall(pos: Vector3, yaw: float) -> Node3D:
	var p := Node3D.new()
	p.name = "LampiaoParede"
	p.position = pos
	p.rotation.y = yaw
	var b := _batch()
	b.box("ferro", Vector3(0.06, 0.06, 0.55), Vector3(0, 0, -0.27))
	b.box("ferro", Vector3(0.06, 0.3, 0.06), Vector3(0, -0.12, -0.5))
	b.box("ferro", Vector3(0.3, 0.07, 0.3), Vector3(0, 0.02, -0.5))
	_mesh_node(p, "Malha", b.commit())
	_glass_node(p, Vector3(0.24, 0.36, 0.24), Vector3(0, -0.2, -0.5))
	_lamp_light(p, Vector3(0, -0.2, -0.5), 1.5)
	return p
func _lamps() -> Node3D:
	var root := Node3D.new()
	root.name = "Iluminacao"
	# lampiões de ferro presos às fachadas, alternando os lados (como nas ruas reais)
	var s := 6.0
	var i := 0
	while s < S_END + 24.0:
		var sigma := -1.0 if i % 2 == 0 else 1.0
		var out := -Route.right(s) * sigma     # da fachada para a rua
		var wall_pt := facade(sigma, s) + out * 0.55 + Vector3(0, SW_H + 3.3, 0)
		var lamp := _lantern_wall(wall_pt, atan2(out.x, out.z))
		lamp.name = "LampiaoParede_%02d" % i
		root.add_child(lamp)
		i += 1
		s += _rng.randf_range(10.0, 13.5)
	# postes nas partes largas (largo, adro)
	for ps in [150.0, 164.0, 300.0, 316.0, 330.0]:
		for sigma: float in [-1.0, 1.0]:
			var w := Route.width(ps)
			var p := make_poste()
			p.name = "Poste_%d_%d" % [int(ps), int(sigma)]
			p.position = Route.pos(ps) + Route.right(ps) * sigma * (w * 0.5 + SW * 0.5) + Vector3(0, SW_H, 0)
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
	var cz := _group(root, "Cruzeiro", Transform3D(Basis.IDENTITY, Route.pos(322.0) + Route.right(322.0) * 4.5))
	var cb := _batch()
	for k in 3:
		cb.box("cantaria", Vector3(2.4 - k * 0.5, 0.3, 2.4 - k * 0.5), Vector3(0, 0.15 + k * 0.3, 0))
	cb.box("cantaria", Vector3(0.35, 4.6, 0.35), Vector3(0, 3.2, 0))
	cb.box("cantaria", Vector3(1.8, 0.35, 0.35), Vector3(0, 4.6, 0))
	_mesh_node(cz, "Malha", cb.commit())
	_blocker(cz, "Colisao", Vector3(2.4, 5.0, 2.4), Vector3(0, 2.5, 0))
	# palmeiras do adro
	for sigma: float in [-1.0, 1.0]:
		for ss: float in [306.0, 326.0]:
			var p := Route.pos(ss) + Route.right(ss) * sigma * (Route.width(ss) * 0.5 + SW + 2.6)
			_plant(root, "palmeira", Vector3(p.x, p.y - 0.4, p.z), _rng.randf() * TAU, _rng.randf_range(0.95, 1.2))
	return root


## Igreja barroca mineira (inspiração): fachada branca com cantaria, portal, frontão e torres cilíndricas com cúpula.
## Quadro local: +X para dentro da igreja, fachada em x = 0 olhando para -X. Origem ao nível do adro.
func make_igreja(width: float, nave_len: float, twin: bool, collide: bool) -> Node3D:
	var c := Node3D.new()
	c.name = "Igreja"
	var nh := 12.0                 # altura da nave
	var fh := 15.5                 # altura da fachada
	var wall := "reboco_branco"
	var half := width / 2.0
	_box(c, "Nave", Vector3(nave_len, nh + 3.0, width), Vector3(nave_len / 2.0, (nh - 3.0) / 2.0, 0), wall, collide)
	_box(c, "Fachada", Vector3(1.6, fh + 3.0, width), Vector3(0.8, (fh - 3.0) / 2.0, 0), wall, collide)
	var rise := (width + 1.2) * 0.3
	var prism := PrismMesh.new()
	prism.size = Vector3(width + 1.2, rise, nave_len + 1.0)
	# telhado da nave (cumeeira ao longo de X): o prisma é girado 90 graus
	var roof := _mesh_node(c, "TelhadoNave", prism, Vector3(nave_len / 2.0, nh + rise / 2.0, 0))
	roof.rotation.y = PI / 2.0
	roof.material_override = mat("telha")
	var b := _batch()
	# frontão curvo (aproximado por degraus) e volutas
	b.box("cantaria", Vector3(1.9, 0.5, width + 0.4), Vector3(-0.15, fh - 0.25, 0))
	for k in 4:
		var wk := width * (0.62 - k * 0.14)
		b.box(wall, Vector3(1.5, 0.9, wk), Vector3(0.0, fh + 0.45 + k * 0.9, 0))
		b.box("cantaria", Vector3(1.7, 0.16, wk + 0.3), Vector3(-0.05, fh + 0.9 + k * 0.9, 0))
	b.box("cantaria", Vector3(0.3, 2.4, 0.3), Vector3(-0.05, fh + 5.0, 0))
	b.box("cantaria", Vector3(0.3, 0.3, 1.3), Vector3(-0.05, fh + 5.6, 0))
	# portal de cantaria
	b.box("cantaria", Vector3(0.5, 6.4, 4.6), Vector3(-0.3, 3.2, 0))
	b.box("porta_igreja", Vector3(0.06, 5.2, 3.2), Vector3(-0.58, 2.6, 0))
	b.box("madeira_natural", Vector3(0.05, 5.2, 0.12), Vector3(-0.64, 2.6, 0))               # junção das folhas
	for hz in [-0.25, 0.25]:
		b.box("ferro", Vector3(0.08, 0.5, 0.08), Vector3(-0.66, 2.4, hz))                  # puxadores
	b.box("cantaria", Vector3(0.7, 0.45, 5.4), Vector3(-0.35, 6.6, 0))
	b.box("cantaria", Vector3(0.9, 1.4, 1.6), Vector3(-0.3, 7.6, 0))
	# medalhão e janelas
	b.box("cantaria", Vector3(0.3, 2.2, 2.2), Vector3(-0.2, 10.5, 0))
	b.box("janela_escura", Vector3(0.1, 1.6, 1.6), Vector3(-0.38, 10.5, 0))
	for side: float in [-1.0, 1.0]:
		_window(b, Vector3(0, 9.0, side * (half - 2.3)), 1.2, 2.4, "madeira_natural", false, false, false, true)
		_window(b, Vector3(0, 3.4, side * (half - 2.3)), 0.9, 1.4, "madeira_natural", false, true)
	for k in 3:                                                                   # degraus do adro
		b.box("cantaria", Vector3(0.8, 0.14 * (3 - k), width * 0.7), Vector3(-1.4 - k * 0.8, 0.07 * (3 - k), 0))
	_mesh_node(c, "Detalhes", b.commit())
	# torres cilíndricas com cúpula
	for side: float in [-1.0, 1.0]:
		if not twin and side > 0.0:
			continue
		var tz := side * (half + 1.7)
		var t := _group(c, "Torre_%s" % ("Esq" if side < 0 else "Dir"), Transform3D(Basis.IDENTITY, Vector3(1.0, 0, tz)))
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.2
		cyl.bottom_radius = 2.3
		cyl.height = 26.0
		cyl.radial_segments = 20
		var body := _mesh_node(t, "Corpo", cyl, Vector3(0, 10.0, 0))
		body.material_override = mat(wall)
		if collide:
			_add_box_collision(body, Vector3(4.4, 26.0, 4.4))
		var ring := CylinderMesh.new()
		ring.top_radius = 2.7
		ring.bottom_radius = 2.7
		ring.height = 0.5
		_mesh_node(t, "Cornija", ring, Vector3(0, 20.3, 0)).material_override = mat("cantaria")
		var lantern := CylinderMesh.new()
		lantern.top_radius = 1.3
		lantern.bottom_radius = 1.4
		lantern.height = 2.4
		_mesh_node(t, "Lanterna", lantern, Vector3(0, 21.8, 0)).material_override = mat("cantaria")
		var dome := SphereMesh.new()
		dome.radius = 2.5
		dome.height = 3.4
		dome.radial_segments = 20
		dome.rings = 8
		_mesh_node(t, "Cupula", dome, Vector3(0, 21.0, 0)).material_override = mat("telha")
		var dome2 := SphereMesh.new()
		dome2.radius = 1.4
		dome2.height = 2.4
		_mesh_node(t, "CupulaAlta", dome2, Vector3(0, 23.6, 0)).material_override = mat("telha")
		var cb := _batch()
		cb.box("ferro", Vector3(0.16, 2.2, 0.16), Vector3(0, 26.0, 0))
		cb.box("ferro", Vector3(1.0, 0.16, 0.16), Vector3(0, 26.5, 0))
		for k in 4:
			var a := k * PI / 2.0 + PI / 4.0
			cb.box("janela_escura", Vector3(0.8, 1.3, 0.06), Vector3(cos(a) * 1.38, 21.8, sin(a) * 1.38), Vector3(0, -a + PI / 2.0, 0))
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
	light.light_energy = 2.6
	light.omni_range = 16.0
	c.add_child(light)
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
	root.add_child(_grass_tufts())
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
		for cx: float in [-1.0, 1.0]:
			for cz: float in [-1.0, 1.0]:
				var cp := p + x_axis * cx * dep * 0.5 + z_axis * cz * w * 0.5
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
		var skirt := base - lo + 1.0
		b.box("muro", Vector3(dep + 1.0, skirt, w + 1.0), Vector3(p.x, base - skirt / 2.0 + 0.05, p.z), Vector3(0, yaw, 0))
		b.box(_pick_wall(), Vector3(dep, hgt, w), Vector3(p.x, base + hgt / 2.0, p.z), Vector3(0, yaw, 0))
		var rise := (dep + 1.2) * 0.27
		b.prism("telha", Vector3(dep + 1.2, rise, w + 0.4), Vector3(p.x, base + hgt + 0.05 + rise / 2.0, p.z), yaw)
		var face_yaw := atan2(-x_axis.x, -x_axis.z)
		var face := p - x_axis * (dep * 0.5 + 0.03)
		for k in [-1, 0, 1]:
			for fl in floors:
				if _rng.randf() < 0.75:
					var lit := _rng.randf() < 0.34
					var wp: Vector3 = face + z_axis * k * w * 0.3 + Vector3(0, base + 1.9 + fl * 3.2, 0)
					if lit and d > 60.0:
						# longe: vira um ponto de luz redondo (como nas fotos das encostas)
						_hill_lights.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(1.1, 1.8)), wp - x_axis * 0.4))
					else:
						b.quad("janela_acesa" if lit else "janela_escura", Vector2(0.9, 1.3), wp, face_yaw)
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


func _plant_mesh(key: String) -> Mesh:
	var n := (_veg[key] as PackedScene).instantiate()
	var m: Mesh = (n.get_node("Malha") as MeshInstance3D).mesh
	n.free()
	return m


## Mata das encostas e do fundo do vale, em MultiMesh (um desenho por tipo de árvore).
func _forest() -> Node3D:
	var root := Node3D.new()
	root.name = "Mata"
	var keys: Array[String] = ["arvore_0", "arvore_1", "arvore_2", "palmeira"]
	var lists: Array = [[], [], [], []]
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
		var sc := _rng.randf_range(1.2, 2.6) if kind < 3 else _rng.randf_range(1.0, 1.4)
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, terrain_h(x, z) - 0.4, z))
		(lists[kind] as Array).append(xf)
		count += 1
	for k in 4:
		var xs: Array = lists[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _plant_mesh(keys[k])
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = keys[k].capitalize().replace(" ", "")
		mmi.multimesh = mm
		mmi.visibility_range_end = 300.0
		root.add_child(mmi)
	return root


## Luzes distantes das encostas (milhares de pontos amarelos como nas fotos), em MultiMesh.
func _far_lights() -> MultiMeshInstance3D:
	var xforms: Array[Transform3D] = _hill_lights.duplicate()
	for o in _spots:
		for k in _rng.randi_range(0, 2):
			var p := o + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
			var y := terrain_h(p.x, p.y) + _rng.randf_range(1.5, 4.0)
			xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.7, 1.5)), Vector3(p.x, y, p.y)))
	var tries := 0
	var extra := 0
	while extra < 900 and tries < 5000:
		tries += 1
		var x := _rng.randf_range(-290.0, 260.0)
		var z := _rng.randf_range(-540.0, 120.0)
		var nr := _nearest(x, z)
		if nr.y < 45.0:
			continue
		xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.8, 1.8)), Vector3(x, terrain_h(x, z) + _rng.randf_range(2.0, 6.0), z)))
		extra += 1
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


func _set_range(n: Node, end: float) -> void:
	for ch in n.get_children():
		if ch is GeometryInstance3D:
			(ch as GeometryInstance3D).visibility_range_end = end
		_set_range(ch, end)


## Tufos de capim em MultiMesh: bordas da rua, pés de muro e encostas.
func _grass_tufts() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var xforms: Array[Transform3D] = []
	var tuft := (_veg["capim"] as PackedScene).instantiate()
	var mesh: Mesh = (tuft.get_node("Malha") as MeshInstance3D).mesh
	tuft.free()
	# 1) beiras da rua (frestas do calçamento e pé das casas)
	var s := 2.0
	while s < Route.length() - 2.0:
		for sigma: float in [-1.0, 1.0]:
			if _rng.randf() < 0.6:
				var w := Route.width(s)
				var p := Route.pos(s) + Route.right(s) * sigma * (w * 0.5 + SW - _rng.randf_range(0.05, 0.25)) + Vector3(0, SW_H - 0.04, 0)
				xforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.2)), p))
		s += 1.3
	# 2) encostas
	var tries := 0
	var count := 0
	while count < 900 and tries < 3000:
		tries += 1
		var ss := _rng.randf_range(0.0, Route.length())
		var sigma := -1.0 if _rng.randf() < 0.5 else 1.0
		var d := _rng.randf_range(Route.width(ss) * 0.5 + 13.0, 70.0)
		var p := Route.pos(ss) + Route.right(ss) * sigma * d
		var h := terrain_h(p.x, p.z)
		xforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.0, 2.2)), Vector3(p.x, h - 0.05, p.z)))
		count += 1
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Capim"
	mmi.multimesh = mm
	mmi.visibility_range_end = 120.0
	mmi.visibility_range_end_margin = 20.0
	return mmi


## Silhueta distante da serra (anel de montanhas), sem névoa, contra o céu.
func _serra() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(-5.0, 0, -170.0)
	var segs := 360
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.9
	noise.seed = 12
	noise.fractal_octaves = 3
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for i in segs + 1:
		var a := TAU * float(i % segs) / segs
		var n := noise.get_noise_1d(float(i % segs) * 0.05)
		var r := 720.0 + n * 90.0
		var h := 150.0 + n * 90.0 + (noise.get_noise_1d(float(i % segs) * 0.22 + 50.0)) * 25.0
		var dir := Vector3(cos(a), 0, sin(a))
		top.append(center + dir * r + Vector3(0, 20.0 + h, 0))
		bottom.append(center + dir * r + Vector3(0, -120.0, 0))
	for i in segs:
		var mid := (top[i] + bottom[i + 1]) * 0.5
		var inward := (center - mid)
		inward.y = 0
		MeshBatch.tri(st, bottom[i], top[i], top[i + 1], inward)
		MeshBatch.tri(st, bottom[i], top[i + 1], bottom[i + 1], inward)
	var mesh := st.commit()
	mesh.surface_set_material(0, mat("serra"))
	var mi := MeshInstance3D.new()
	mi.name = "Serra"
	mi.mesh = _save_mesh(mesh, "serra")
	return mi


# ------------------------------------------------------------------ ponte e riacho

## Parapeito de pedra da ponte (um por lado da rua).
func _lot_ponte(parent: Node3D, f: Dictionary, sigma: float) -> void:
	var w: float = f["w"]
	var g := _group(parent, "Parapeito_%02d" % _n, f["xf"])
	_n += 1
	# acompanha a subida da rua (o eixo Z local anda em sentido oposto ao da rua no lado +1)
	var slope := (Route.height(Route.BRIDGE_S + 1.0) - Route.height(Route.BRIDGE_S - 1.0)) / 2.0
	g.transform = g.transform * Transform3D(Basis(Vector3.RIGHT, atan(sigma * slope)), Vector3.ZERO)
	_box(g, "Muro", Vector3(0.5, 1.9, w + 0.1), Vector3(0.25, 0.2, 0), "muro", true)
	var b := _batch()
	b.box("cantaria", Vector3(0.8, 0.12, w + 0.2), Vector3(0.25, 1.21, 0))
	for sz: float in [-1.0, 1.0]:
		b.box("cantaria", Vector3(0.7, 1.5, 0.55), Vector3(0.2, 0.6, sz * (w / 2.0 - 0.1)))
		b.box("cantaria", Vector3(0.8, 0.14, 0.65), Vector3(0.2, 1.4, sz * (w / 2.0 - 0.1)))
	_mesh_node(g, "Detalhes", b.commit())
	_box(g, "FaceDaPonte", Vector3(0.5, 4.6, w + 0.1), Vector3(0.25, -3.05, 0), "muro")


## Corpo da ponte (laje de pedra), o riacho, pedras e plantas das margens.
func _bridge(root: Node3D) -> void:
	var s := Route.BRIDGE_S
	var c := Route.pos(s)
	var r := Route.right(s)
	var g := _group(root, "Ponte", Transform3D(Basis(r, Vector3.UP, r.cross(Vector3.UP)), c))
	var width := Route.width(s) + 2.0 * SW
	var slope := (Route.height(s + 1.0) - Route.height(s - 1.0)) / 2.0
	var laje := _box(g, "Laje", Vector3(width + 0.4, 1.0, Route.BRIDGE_HALF * 2.0 + 0.6), Vector3(0, -0.85, 0), "muro")
	laje.rotation.x = atan(slope)
	# riacho: plano d'água com shader (ondulação e reflexo), cruzando a rua
	var plane := PlaneMesh.new()
	plane.size = Vector2(150.0, 5.2)
	var water := _mesh_node(g, "Riacho", plane, Vector3(0, -3.0, 0))
	water.material_override = mat("agua")
	var b := _batch()
	for k in 14:
		var u := _rng.randf_range(-30.0, 30.0)
		if absf(u) < width * 0.5 + 0.5:
			continue
		b.sphere("pedra_chao", _rng.randf_range(0.5, 1.3), Vector3(u, -3.5, _rng.randf_range(-2.0, 2.0)), 6, 4)
	_mesh_node(g, "PedrasDoLeito", b.commit())
	var keys := ["samambaia", "arbusto", "arvore_pequena", "bananeira", "arvore_1"]
	for k in 22:
		var u := _rng.randf_range(8.0, 46.0) * (1.0 if k % 2 == 0 else -1.0)
		var zo := _rng.randf_range(-5.5, 5.5)
		var wp := c + r * u - Route.tangent(s) * zo
		var y := terrain_h(wp.x, wp.z)
		_plant(g, keys[_rng.randi() % keys.size()], Vector3(u, y - c.y - 0.2, zo), _rng.randf() * TAU, _rng.randf_range(0.9, 1.6))


# ------------------------------------------------------------------ adornos de rua e nichos

func _street_point(sigma: float, s: float, inset: float) -> Vector3:
	return Route.pos(s) + Route.right(s) * sigma * (Route.width(s) * 0.5 - inset) + Vector3(0, 0.03, 0)


## Bueiros, barris, caixotes, bancos, carroça, varais e bandeirinhas.
func _adornos() -> Node3D:
	var root := Node3D.new()
	root.name = "Adornos"
	var b := _batch()
	for s: float in [14.0, 62.0, 128.0, 170.0, 210.0, 246.0, 284.0]:
		var p := _street_point(1.0 if int(s) % 2 == 0 else -1.0, s, 1.4)
		b.cylinder("cantaria", 0.46, 0.46, 0.04, p + Vector3(0, 0.0, 0), Vector3.ZERO, 14)
		b.cylinder("ferro", 0.36, 0.36, 0.05, p + Vector3(0, 0.02, 0), Vector3.ZERO, 14)
		for k in 4:
			b.box("cantaria", Vector3(0.5, 0.02, 0.03), p + Vector3(0, 0.05, 0), Vector3(0, k * PI / 4.0, 0))
	# barris e caixotes junto às paredes
	var count := 0
	var tries := 0
	while count < 16 and tries < 100:
		tries += 1
		var s := _rng.randf_range(10.0, 290.0)
		if absf(s - Route.BRIDGE_S) < 8.0 or Route.width(s) < 3.8:
			continue
		var sigma := -1.0 if _rng.randf() < 0.5 else 1.0
		var base := facade(sigma, s) - Route.right(s) * sigma * 0.4 + Vector3(0, SW_H, 0)
		var out := -Route.right(s) * sigma
		var p := base + out * 0.45
		if _rng.randf() < 0.6:
			b.cylinder("madeira_natural", 0.33, 0.33, 0.8, p + Vector3(0, 0.4, 0), Vector3.ZERO, 10)
			b.cylinder("ferro", 0.345, 0.345, 0.04, p + Vector3(0, 0.2, 0), Vector3.ZERO, 10)
			b.cylinder("ferro", 0.345, 0.345, 0.04, p + Vector3(0, 0.62, 0), Vector3.ZERO, 10)
		else:
			var yaw := atan2(out.x, out.z)
			b.box("madeira_natural", Vector3(0.6, 0.5, 0.6), p + Vector3(0, 0.25, 0), Vector3(0, yaw, 0))
			if _rng.randf() < 0.5:
				b.box("madeira_natural", Vector3(0.5, 0.45, 0.5), p + Vector3(0, 0.72, 0), Vector3(0, yaw + 0.4, 0))
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
	root.add_child(_lines())
	return root


## Varais com lençóis e bandeirinhas coloridas, esticados de fachada a fachada.
func _lines() -> Node3D:
	var root := Node3D.new()
	root.name = "Varais"
	var b := _batch()
	var flags := ["bandeira_a", "bandeira_b", "bandeira_c", "bandeira_d"]
	for spec in [[58.0, "varal"], [234.0, "varal"], [190.0, "bandeirinha"], [270.0, "bandeirinha"]]:
		var s: float = spec[0]
		var a := facade(-1.0, s) + Vector3(0, SW_H + (4.4 if spec[1] == "varal" else 5.6), 0)
		var c := facade(1.0, s) + Vector3(0, SW_H + (4.4 if spec[1] == "varal" else 5.6), 0)
		var n := int(a.distance_to(c) / 0.5)
		var prev := a
		var dirv := (c - a)
		dirv.y = 0
		var lat := dirv.normalized()
		var perp := lat.cross(Vector3.UP).normalized()
		for k in range(1, n + 1):
			var t := float(k) / n
			var pt := a.lerp(c, t)
			pt.y -= sin(t * PI) * 0.7
			var seg := pt - prev
			b.box("ferro", Vector3(seg.length() + 0.02, 0.012, 0.012), (pt + prev) * 0.5, Vector3(0, atan2(-seg.z, seg.x), atan2(seg.y, Vector2(seg.x, seg.z).length())))
			if spec[1] == "bandeirinha" and k % 1 == 0:
				var m: String = flags[k % flags.size()]
				b.tri2(m, prev, pt, (prev + pt) * 0.5 + Vector3(0, -0.34, 0))
			prev = pt
		if spec[1] == "varal":
			for k in 4:
				var t2 := (k + 1.0) / 5.0
				var top := a.lerp(c, t2)
				top.y -= sin(t2 * PI) * 0.7
				var wdt := 1.05
				var hh := _rng.randf_range(1.0, 1.4)
				var p0 := top - lat * wdt * 0.5
				var p1 := top + lat * wdt * 0.5
				b.tri2("pano", p0, p1, p1 + Vector3(0, -hh, 0))
				b.tri2("pano", p0, p1 + Vector3(0, -hh, 0), p0 + Vector3(0, -hh, 0))
	_mesh_node(root, "Fios", b.commit())
	return root


## Nichos (oratórios) com imagem de santo e vela acesa nas junções das fachadas.
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
		b.box("cantaria", Vector3(0.55, 1.2, 0.75), Vector3(0.0, 2.1, 0))
		b.box("janela_escura", Vector3(0.06, 0.85, 0.48), Vector3(-0.29, 2.1, 0))
		b.box("cantaria", Vector3(0.7, 0.1, 0.9), Vector3(-0.03, 2.75, 0))
		b.box("ferro", Vector3(0.04, 0.4, 0.04), Vector3(-0.2, 3.05, 0))
		b.box("ferro", Vector3(0.04, 0.04, 0.22), Vector3(-0.2, 3.15, 0))
		b.box("cantaria", Vector3(0.14, 0.5, 0.16), Vector3(-0.26, 1.95, 0))       # imagem
		b.sphere("cantaria", 0.07, Vector3(-0.26, 2.3, 0), 6, 4)
		b.box("vela", Vector3(0.05, 0.14, 0.05), Vector3(-0.27, 1.7, 0.17))
		b.box("chama", Vector3(0.035, 0.06, 0.035), Vector3(-0.27, 1.8, 0.17))
		b.box("vela", Vector3(0.05, 0.1, 0.05), Vector3(-0.27, 1.68, -0.17))
		b.box("chama", Vector3(0.035, 0.05, 0.035), Vector3(-0.27, 1.76, -0.17))
		_mesh_node(g, "Malha", b.commit())
		var l := OmniLight3D.new()
		l.name = "LuzDaVela"
		l.position = Vector3(-0.5, 1.9, 0)
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
		last_s = s
		picked += 1
	print("[vila] nichos: ", picked)
	return root


## Janela com luz acesa e um vulto parado; apaga quando o jogador chega perto (scripts/janela_assombrada.gd).
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
		b.cylinder("vidro_oleo", 0.07, 0.07, 0.22, Vector3(0, 0.11, 0), Vector3.ZERO, 8)
		b.cylinder("vidro_oleo", 0.03, 0.03, 0.1, Vector3(0, 0.27, 0), Vector3.ZERO, 8)
		b.box("madeira_natural", Vector3(0.05, 0.04, 0.05), Vector3(0, 0.34, 0))
		_brilho(a, 0.25, 0.55)
	else:
		b.box("papel", Vector3(0.3, 0.012, 0.22), Vector3(0, 0.01, 0), Vector3(0, _rng.randf_range(-0.6, 0.6), 0))
		_brilho(a, 0.2, 0.45)
	_mesh_node(a, "Malha", b.commit())
	parent.add_child(a)


func _coletaveis() -> Node3D:
	var root := Node3D.new()
	root.name = "Coletaveis"
	var oil_pts := [[26.0, 1.0], [70.0, -1.0], [108.0, 1.0], [154.0, -1.0], [198.0, 1.0], [244.0, -1.0], [286.0, 1.0]]
	var i := 0
	for o in oil_pts:
		var s: float = o[0]
		var sigma: float = o[1]
		var p := facade(sigma, s) - Route.right(s) * sigma * 0.35 + Vector3(0, SW_H, 0)
		_coletavel(root, "Oleo_%02d" % i, p, "oleo", 0, "Pegar frasco de óleo")
		i += 1
	var notes := [[8.0, 1.0, 0], [76.0, -1.0, 1], [141.0, -1.0, 2], [203.0, 1.0, 3], [248.0, -1.0, 4], [301.0, 1.0, 5]]
	for n in notes:
		var s: float = n[0]
		var sigma: float = n[1]
		var p := facade(sigma, s) - Route.right(s) * sigma * 0.4 + Vector3(0, SW_H, 0)
		_coletavel(root, "Bilhete_%d" % int(n[2]), p, "nota", int(n[2]), "Ler bilhete")
	return root
