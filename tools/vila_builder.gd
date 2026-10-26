class_name VilaBuilder
extends RefCounted
## Gera a vila como uma árvore de nós. Usado só por tools/bake.gd para CRIAR
## scenes/vila.tscn; depois disso o mundo é editado no editor do Godot.
## Todos os materiais vêm de res://assets/materials/*.tres (edite lá).

const MATS := "res://assets/materials/"
const WALLS: Array[String] = ["reboco_branco", "reboco_ocre", "reboco_azul", "reboco_terracota"]

var _rng := RandomNumberGenerator.new()
var _cache := {}


func mat(n: String) -> Material:
	if not _cache.has(n):
		_cache[n] = load(MATS + n + ".tres")
	return _cache[n]


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, material: String, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(material)
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.name = "Colisao"
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		mi.add_child(body)
	return mi


func _quad(parent: Node3D, node_name: String, size: Vector2, pos: Vector3, yaw: float, material: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat(material)
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


func _group(parent: Node3D, node_name: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


# ------------------------------------------------------------------ vila

func build_vila() -> Node3D:
	_rng.seed = 1789
	var root := Node3D.new()
	root.name = "Vila"
	root.add_child(_environment())
	root.add_child(_moon())
	root.add_child(_ground())
	root.add_child(_invisible_walls())
	root.add_child(_houses())
	root.add_child(_lamps())
	root.add_child(_church())
	return root


func _environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.09, 0.11, 0.18)
	env.ambient_light_energy = 0.30
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.09)
	env.fog_density = 0.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9
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
	l.light_energy = 0.07
	l.rotation_degrees = Vector3(-48.0, 28.0, 0.0)
	l.shadow_enabled = true
	l.directional_shadow_max_distance = 70.0
	return l


func _ground() -> Node3D:
	var g := Node3D.new()
	g.name = "Chao"
	var length := World.STREET_LEN + 40.0
	var slab_len := length / cos(World.SLOPE)
	var center_z := -(World.STREET_LEN - 10.0) / 2.0
	var slab := _box(g, "Calcamento", Vector3(2.0 * World.WALL_X, 1.0, slab_len),
		Vector3(0, World.ground_y(center_z) - 0.5, center_z), "pedra_chao", true)
	slab.rotation.x = World.SLOPE
	return g


func _invisible_walls() -> Node3D:
	var root := Node3D.new()
	root.name = "ParedesInvisiveis"
	var length := World.STREET_LEN + 40.0
	var center_z := -(World.STREET_LEN - 10.0) / 2.0
	var specs := [
		["Esquerda", Vector3(1.0, 30.0, length), Vector3(-World.WALL_X, 10.0, center_z)],
		["Direita", Vector3(1.0, 30.0, length), Vector3(World.WALL_X, 10.0, center_z)],
		["Fundo", Vector3(2.0 * World.WALL_X, 30.0, 1.0), Vector3(0, 10.0, 3.5)],
	]
	for s in specs:
		var body := StaticBody3D.new()
		body.name = s[0]
		body.position = s[2]
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s[1]
		cs.shape = bs
		body.add_child(cs)
		root.add_child(body)
	return root


# ------------------------------------------------------------------ casas

func _houses() -> Node3D:
	var root := Node3D.new()
	root.name = "Casas"
	var n := 0
	for side: float in [-1.0, 1.0]:
		var z := 4.0
		while z > -(World.STREET_LEN + 2.0):
			var w := _rng.randf_range(8.0, 14.0)
			var h := _rng.randf_range(6.5, 9.0)
			var depth := 10.0
			var cz := z - w / 2.0
			var x := side * (World.STREET_W / 2.0 + depth / 2.0)
			var wall: String = WALLS[_rng.randi() % WALLS.size()]
			var casa := make_casa(w, h, wall, side, _rng.randf() < 0.45, depth)
			casa.name = "Casa_%02d" % n
			casa.position = Vector3(x, World.ground_y(cz), cz)
			root.add_child(casa)
			n += 1
			z -= w
	return root


## Casa colonial (sobrado). Origem no centro da base; a fachada olha para a rua.
## side = -1 (lado esquerdo da rua) ou +1 (lado direito).
func make_casa(w: float, h: float, wall: String, side: float, balcony: bool, depth := 10.0) -> Node3D:
	var c := Node3D.new()
	c.name = "Casa"
	var n := -side                      # direção da fachada (para a rua)
	var face_x := n * depth / 2.0       # plano da fachada, em coordenadas locais
	var yaw := n * PI / 2.0
	# a base é enterrada (4 m) para acompanhar o declive da rua
	_box(c, "Corpo", Vector3(depth, h + 4.0, w), Vector3(0, h / 2.0 - 2.0, 0), wall, true)
	_box(c, "Embasamento", Vector3(depth + 0.15, 1.1, w + 0.15), Vector3(0, 0.55, 0), "pedra_clara")
	_box(c, "Cornija", Vector3(depth + 0.5, 0.3, w + 0.3), Vector3(0, h + 0.05, 0), "moldura")
	var roof := MeshInstance3D.new()
	roof.name = "Telhado"
	var prism := PrismMesh.new()
	prism.size = Vector3(depth + 1.4, 2.6, w + 0.8)
	roof.mesh = prism
	roof.material_override = mat("telha")
	roof.position = Vector3(0, h + 0.2 + 1.3, 0)
	c.add_child(roof)

	# porta
	_box(c, "PortaMoldura", Vector3(0.2, 3.0, 2.0), Vector3(face_x + n * 0.1, 1.5, 0), "moldura")
	_box(c, "Porta", Vector3(0.12, 2.6, 1.5), Vector3(face_x + n * 0.22, 1.4, 0), "madeira")

	# janelas: térreo e andar de cima
	var upper_y := h - 2.2
	for k in [-1, 1]:
		var lz: float = k * w * 0.3
		_window(c, "JanelaTerreo_%d" % k, Vector3(face_x, 1.9, lz), n, yaw, Vector2(0.9, 1.2), _rng.randf() < 0.25)
		_window(c, "JanelaAlto_%d" % k, Vector3(face_x, upper_y, k * w * 0.25), n, yaw, Vector2(0.9, 1.5), _rng.randf() < 0.35)
	_window(c, "JanelaAlto_0", Vector3(face_x, upper_y, 0), n, yaw, Vector2(0.9, 1.5), _rng.randf() < 0.35)

	if balcony:
		var bw := w * 0.7
		var by := upper_y - 0.95
		_box(c, "BalcaoLaje", Vector3(1.2, 0.14, bw), Vector3(face_x + n * 0.6, by, 0), "moldura")
		var rail_x := face_x + n * 1.12
		_box(c, "BalcaoCorrimao", Vector3(0.07, 0.07, bw), Vector3(rail_x, by + 1.0, 0), "ferro")
		var posts := int(bw / 0.45)
		for i in posts + 1:
			var pz := -bw / 2.0 + bw * float(i) / posts
			_box(c, "BalcaoGrade_%02d" % i, Vector3(0.04, 1.0, 0.04), Vector3(rail_x, by + 0.55, pz), "ferro")
	return c


func _window(parent: Node3D, node_name: String, pos: Vector3, n: float, yaw: float, size: Vector2, lit: bool) -> void:
	var g := _group(parent, node_name, pos)
	_box(g, "Moldura", Vector3(0.14, size.y + 0.3, size.x + 0.3), Vector3(n * 0.07, 0, 0), "moldura")
	_box(g, "Peitoril", Vector3(0.3, 0.1, size.x + 0.5), Vector3(n * 0.15, -size.y / 2.0 - 0.2, 0), "moldura")
	_quad(g, "Vidro", size, Vector3(n * 0.15, 0, 0), yaw, "janela_acesa" if lit else "janela_escura")


# ------------------------------------------------------------------ postes

func _lamps() -> Node3D:
	var root := Node3D.new()
	root.name = "Postes"
	var i := 0
	var z := -6.0
	while z > -World.STREET_LEN:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := make_poste()
		p.name = "Poste_%02d" % i
		p.position = Vector3(side * (World.STREET_W / 2.0 - 0.5), World.ground_y(z), z)
		root.add_child(p)
		i += 1
		z -= 24.0
	return root


func make_poste() -> Node3D:
	var p := Node3D.new()
	p.name = "Poste"
	var haste := MeshInstance3D.new()
	haste.name = "Haste"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.08
	cyl.height = 3.4
	haste.mesh = cyl
	haste.material_override = mat("ferro")
	haste.position.y = 1.7
	p.add_child(haste)
	_box(p, "Lanterna", Vector3(0.35, 0.5, 0.35), Vector3(0, 3.6, 0), "vidro_lampiao")
	var cap := MeshInstance3D.new()
	cap.name = "Cupula"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.3
	cone.height = 0.25
	cone.radial_segments = 4
	cap.mesh = cone
	cap.material_override = mat("ferro")
	cap.position.y = 3.98
	p.add_child(cap)
	var light := OmniLight3D.new()
	light.name = "Luz"
	light.position.y = 3.5
	light.light_color = Color(1.0, 0.72, 0.35)
	light.light_energy = 1.3
	light.omni_range = 11.0
	light.shadow_enabled = true
	p.add_child(light)
	return p


# ------------------------------------------------------------------ igreja

func _church() -> Node3D:
	var c := Node3D.new()
	c.name = "Igreja"
	var front_z := -(World.STREET_LEN + 2.0)
	var gy := World.ground_y(front_z)
	c.position = Vector3(0, gy, front_z)
	_box(c, "Nave", Vector3(18.0, 16.0, 26.0), Vector3(0, 4.0, -13.0), "pedra_clara", true)
	_box(c, "Fachada", Vector3(14.0, 18.0, 1.2), Vector3(0, 5.0, 0.0), "reboco_branco", true)
	var gable := MeshInstance3D.new()
	gable.name = "Frontao"
	var pm := PrismMesh.new()
	pm.size = Vector3(14.0, 5.0, 1.4)
	gable.mesh = pm
	gable.material_override = mat("reboco_branco")
	gable.position = Vector3(0, 16.5, 0.0)
	c.add_child(gable)
	for side in [-1.0, 1.0]:
		var t := _group(c, "Torre_%s" % ("Esq" if side < 0 else "Dir"), Vector3(side * 7.5, 0, -3.0))
		_box(t, "Corpo", Vector3(5.0, 32.0, 5.0), Vector3(0, 11.0, 0), "reboco_branco", true)
		_box(t, "Sineira", Vector3(3.2, 3.0, 3.2), Vector3(0, 27.5, 0), "moldura")
		var spire := MeshInstance3D.new()
		spire.name = "Cupula"
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 3.0
		cone.height = 6.0
		cone.radial_segments = 4
		spire.mesh = cone
		spire.material_override = mat("telha")
		spire.rotation.y = PI / 4.0
		spire.position.y = 32.0
		t.add_child(spire)
		_box(t, "CruzV", Vector3(0.18, 1.8, 0.18), Vector3(0, 36.0, 0), "ferro")
		_box(t, "CruzH", Vector3(1.0, 0.18, 0.18), Vector3(0, 36.3, 0), "ferro")
	# porta principal com moldura e degraus
	_box(c, "PortaMoldura", Vector3(4.2, 5.6, 0.3), Vector3(0, 2.8 - 0.0, 0.7), "moldura")
	_quad(c, "PortaLuz", Vector2(3.2, 4.6), Vector3(0, 2.3, 0.88), 0.0, "porta_igreja")
	_box(c, "Degrau", Vector3(6.0, 0.2, 1.4), Vector3(0, 0.1, 1.3), "pedra_clara")
	var light := OmniLight3D.new()
	light.name = "LuzPorta"
	light.position = Vector3(0, 3.0, 3.5)
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 3.5
	light.omni_range = 18.0
	c.add_child(light)
	# gatilho de vitória
	var door := Area3D.new()
	door.name = "Porta"
	door.position = Vector3(0, 2.0, 2.0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.0, 4.0, 3.0)
	cs.shape = bs
	door.add_child(cs)
	c.add_child(door)
	return c


# ------------------------------------------------------------------ jogador e monstro

func build_player() -> CharacterBody3D:
	var p := CharacterBody3D.new()
	p.name = "Jogador"
	var shape := CollisionShape3D.new()
	shape.name = "Colisao"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	p.add_child(shape)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(0, 1.6, 0)
	cam.fov = 75.0
	cam.far = 250.0
	p.add_child(cam)
	var lantern := OmniLight3D.new()
	lantern.name = "Lampiao"
	lantern.position = Vector3(0.25, -0.35, -0.5)
	lantern.light_color = Color(1.0, 0.72, 0.38)
	lantern.light_energy = 1.7
	lantern.omni_range = 9.0
	lantern.shadow_enabled = true
	cam.add_child(lantern)
	return p


func build_bradador() -> Node3D:
	var b := Node3D.new()
	b.name = "Bradador"
	var manto := MeshInstance3D.new()
	manto.name = "Manto"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.14
	cone.bottom_radius = 0.55
	cone.height = 2.2
	cone.radial_segments = 10
	manto.mesh = cone
	manto.material_override = mat("bradador_preto")
	manto.position.y = 1.15
	b.add_child(manto)
	var cabeca := MeshInstance3D.new()
	cabeca.name = "Cabeca"
	var sph := SphereMesh.new()
	sph.radius = 0.15
	sph.height = 0.46
	cabeca.mesh = sph
	cabeca.material_override = mat("bradador_palido")
	cabeca.position.y = 2.45
	b.add_child(cabeca)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		arm.name = "Braco_%s" % ("Esq" if side < 0 else "Dir")
		var ac := CylinderMesh.new()
		ac.top_radius = 0.05
		ac.bottom_radius = 0.03
		ac.height = 1.7
		arm.mesh = ac
		arm.material_override = mat("bradador_preto")
		arm.position = Vector3(side * 0.34, 1.45, 0.05)
		arm.rotation_degrees = Vector3(0, 0, side * 6.0)
		b.add_child(arm)
	return b
