class_name Interiores
extends RefCounted
## Interiores visitáveis. Cada sala é construída num ponto distante do mapa (BASE + índice*PASSO) e o jogador é
## transportado para lá quando abre a porta da casa (scripts/missao.gd). Sistema de coordenadas de cada sala:
##   x = 0..largura, z = 0..profundidade, y = 0..altura. A porta de saída fica na parede z=0, no meio.
## O jogador nasce em (largura/2, 0.12, 1.7) olhando para +z.
##
## Para criar uma sala nova: copie uma função _sala_xxx, adicione o id em ORDEM e uma entrada em
## VilaBuilder.ENTRADAS (a porta na fachada).

const BASE := Vector3(4000.0, 0.0, 0.0)
const PASSO := 60.0
const ORDEM: Array[String] = ["benedita", "padaria", "venda", "barbearia", "sineiro", "casarao", "igreja", "carpintaria", "escola", "ferraria", "casa_vazia", "pensao", "costureira", "deposito"]

var b: VilaBuilder
var _bb: MeshBatch
var _g: Node3D
var _w := 0.0
var _d := 0.0
var _h := 0.0


func construir(builder: VilaBuilder) -> Node3D:
	b = builder
	var root := Node3D.new()
	root.name = "Interiores"
	for i in ORDEM.size():
		var id := ORDEM[i]
		var g := Node3D.new()
		g.name = id
		g.position = BASE + Vector3(i * PASSO, 0.0, 0.0)
		root.add_child(g)
		_g = g
		call("_sala_" + id, g)
		_camada(g)
	return root


## Interior só recebe luz das lâmpadas dele (a Lua usa a máscara de camada 1).
func _camada(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = 2
	for c in n.get_children():
		_camada(c)


# ------------------------------------------------------------------ casca e utilidades

func _casca(nome: String, w: float, d: float, h: float, parede: String, piso: String, teto := "madeira_escura") -> void:
	_w = w
	_d = d
	_h = h
	# paredes de perto: reboco com relevo mais suave (a lanterna fica a centímetros da parede)
	var pm := b.mat(parede).duplicate() as Material
	if pm is StandardMaterial3D:
		(pm as StandardMaterial3D).normal_scale = 0.25
	b._cache["i_" + parede] = pm
	parede = "i_" + parede
	_g.set_meta("nome", nome)
	_g.set_meta("spawn", Vector3(w / 2.0, 0.12, 1.7))
	_bb = b._batch()
	_bb.box(piso, Vector3(w + 0.6, 0.2, d + 0.6), Vector3(w / 2.0, -0.1, d / 2.0))
	_bb.box(teto, Vector3(w + 0.6, 0.2, d + 0.6), Vector3(w / 2.0, h + 0.1, d / 2.0))
	var x := 0.6
	while x < w:
		_bb.box("madeira_natural", Vector3(0.16, 0.2, d), Vector3(x, h - 0.1, d / 2.0))      # vigas
		x += 1.4
	_bb.box(parede, Vector3(0.3, h + 0.4, d + 0.6), Vector3(-0.15, h / 2.0, d / 2.0))
	_bb.box(parede, Vector3(0.3, h + 0.4, d + 0.6), Vector3(w + 0.15, h / 2.0, d / 2.0))
	_bb.box(parede, Vector3(w + 0.6, h + 0.4, 0.3), Vector3(w / 2.0, h / 2.0, -0.15))
	_bb.box(parede, Vector3(w + 0.6, h + 0.4, 0.3), Vector3(w / 2.0, h / 2.0, d + 0.15))
	# rodapé
	_bb.box("madeira_escura", Vector3(w, 0.14, 0.04), Vector3(w / 2.0, 0.07, 0.02))
	_bb.box("madeira_escura", Vector3(w, 0.14, 0.04), Vector3(w / 2.0, 0.07, d - 0.02))
	_bb.box("madeira_escura", Vector3(0.04, 0.14, d), Vector3(0.02, 0.07, d / 2.0))
	_bb.box("madeira_escura", Vector3(0.04, 0.14, d), Vector3(w - 0.02, 0.07, d / 2.0))
	# colisões (a sala é uma caixa fechada)
	b._blocker(_g, "Piso", Vector3(w + 4.0, 0.6, d + 4.0), Vector3(w / 2.0, -0.3, d / 2.0))
	b._blocker(_g, "Teto", Vector3(w + 4.0, 0.6, d + 4.0), Vector3(w / 2.0, h + 0.3, d / 2.0))
	b._blocker(_g, "ParedeO", Vector3(0.6, h + 2.0, d + 4.0), Vector3(-0.3, h / 2.0, d / 2.0))
	b._blocker(_g, "ParedeL", Vector3(0.6, h + 2.0, d + 4.0), Vector3(w + 0.3, h / 2.0, d / 2.0))
	b._blocker(_g, "ParedeS", Vector3(w + 4.0, h + 2.0, 0.6), Vector3(w / 2.0, h / 2.0, -0.3))
	b._blocker(_g, "ParedeN", Vector3(w + 4.0, h + 2.0, 0.6), Vector3(w / 2.0, h / 2.0, d + 0.3))
	# porta de saída (parede sul) e gatilho de interação
	_bb.box("cantaria", Vector3(1.5, 2.55, 0.12), Vector3(w / 2.0, 1.27, 0.06))
	_bb.box("madeira_escura", Vector3(1.2, 2.3, 0.1), Vector3(w / 2.0, 1.15, 0.11))
	_bb.box("ferro", Vector3(0.05, 0.12, 0.06), Vector3(w / 2.0 + 0.42, 1.05, 0.2))
	var a := _area("Saida", Vector3(w / 2.0, 1.2, 0.8), Vector3(1.9, 2.4, 1.5), "res://scripts/porta.gd")
	a.set("destino", "")
	a.set("texto_interacao", "Sair para a rua")


func _area(nome: String, pos: Vector3, size: Vector3, script: String) -> Area3D:
	var a := Area3D.new()
	a.name = nome
	a.position = pos
	a.set_script(load(script))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	_g.add_child(a)
	return a


func _fim() -> void:
	b._mesh_node(_g, "Mobilia", _bb.commit())


## Janela na parede: lado "L" (x = largura), "O" (x = 0) ou "N" (z = profundidade); `p` = posição ao longo da parede.
func _janela(lado: String, p: float, y := 1.6, w := 1.0, h := 1.3) -> void:
	var pos := Vector3.ZERO
	var yaw := 0.0
	match lado:
		"O":
			pos = Vector3(0.02, y, p)
			yaw = PI / 2.0
		"L":
			pos = Vector3(_w - 0.02, y, p)
			yaw = -PI / 2.0
		_:
			pos = Vector3(p, y, _d - 0.02)
			yaw = PI
	_bb.quad("vidro_noite", Vector2(w, h), pos, yaw)
	var dir := Vector3(sin(yaw), 0, cos(yaw))
	var side := Vector3(dir.z, 0, -dir.x)
	for k in [-1.0, 1.0]:
		_bb.box("madeira_escura", Vector3(0.06, h + 0.12, 0.06) if lado == "N" else Vector3(0.06, h + 0.12, 0.06), pos + dir * 0.03 + side * k * (w / 2.0 + 0.03))
	_bb.box("madeira_escura", Vector3(0.06, 0.06, 0.06), pos + dir * 0.03 + Vector3(0, h / 2.0 + 0.03, 0))
	# caixilho em cruz
	var along := side.abs()
	_bb.box("madeira_escura", Vector3(0.03 + along.x * w, 0.04, 0.03 + along.z * w), pos + dir * 0.03)
	_bb.box("madeira_escura", Vector3(0.04, h, 0.04), pos + dir * 0.03)
	# luar frio entrando (sem sombra): pequena luz azul
	var l := OmniLight3D.new()
	l.position = pos + dir * 0.8
	l.light_color = Color(0.45, 0.58, 0.9)
	l.light_energy = 0.28
	l.omni_range = 4.5
	_g.add_child(l)


func _lamparina(x: float, y: float, z: float, energia := 0.85) -> void:
	_bb.cylinder("vidro_oleo", 0.05, 0.06, 0.12, Vector3(x, y + 0.06, z), Vector3.ZERO, 8)
	_bb.cylinder("ferro", 0.04, 0.04, 0.03, Vector3(x, y + 0.14, z), Vector3.ZERO, 8)
	var l := b._lamp_light(_g, Vector3(x, y + 0.3, z), energia)
	l.omni_range = 6.5
	b._halo(_g, Vector3(x, y + 0.14, z), 0.9, "halo_vela")


func _vela(x: float, y: float, z: float, luz := false) -> void:
	_bb.cylinder("vela", 0.018, 0.018, 0.14, Vector3(x, y + 0.07, z), Vector3.ZERO, 6)
	b._halo(_g, Vector3(x, y + 0.17, z), 0.35, "halo_vela")
	if luz:
		var l := b._lamp_light(_g, Vector3(x, y + 0.3, z), 0.5)
		l.omni_range = 4.5


# ------------------------------------------------------------------ móveis (todos giram em torno de `yaw`)

func _bx(mat: String, c: Vector3, yaw: float, local: Vector3, size: Vector3) -> void:
	_bb.box(mat, size, c + Basis(Vector3.UP, yaw) * local, Vector3(0, yaw, 0))


func _mesa(x: float, z: float, w := 1.5, dd := 0.85, h := 0.78, mat := "madeira_escura", yaw := 0.0) -> void:
	var c := Vector3(x, 0, z)
	_bx(mat, c, yaw, Vector3(0, h, 0), Vector3(w, 0.07, dd))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bx(mat, c, yaw, Vector3(sx * (w / 2.0 - 0.07), h / 2.0, sz * (dd / 2.0 - 0.07)), Vector3(0.08, h, 0.08))
	if int(round(yaw / (PI / 2.0))) % 2 == 0:
		b._blocker(_g, "ColMesa", Vector3(w, h, dd), Vector3(x, h / 2.0, z))
	else:
		b._blocker(_g, "ColMesa", Vector3(dd, h, w), Vector3(x, h / 2.0, z))


func _cadeira(x: float, z: float, yaw := 0.0, mat := "madeira_natural") -> void:
	var c := Vector3(x, 0, z)
	_bx(mat, c, yaw, Vector3(0, 0.46, 0), Vector3(0.44, 0.04, 0.44))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bx(mat, c, yaw, Vector3(sx * 0.19, 0.23, sz * 0.19), Vector3(0.04, 0.46, 0.04))
	_bx(mat, c, yaw, Vector3(0, 0.78, 0.2), Vector3(0.44, 0.5, 0.04))


func _cama(x: float, z: float, yaw := 0.0, colcha := "pano_azul") -> void:
	var c := Vector3(x, 0, z)
	_bx("madeira_escura", c, yaw, Vector3(0, 0.3, 0), Vector3(1.0, 0.1, 2.0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bx("madeira_escura", c, yaw, Vector3(sx * 0.48, 0.15, sz * 0.97), Vector3(0.07, 0.3, 0.07))
	_bx("madeira_escura", c, yaw, Vector3(0, 0.7, 1.0), Vector3(1.04, 0.8, 0.06))        # cabeceira
	_bx("pano_cru", c, yaw, Vector3(0, 0.42, 0), Vector3(0.94, 0.14, 1.9))               # colchão
	_bx(colcha, c, yaw, Vector3(0, 0.5, -0.3), Vector3(0.98, 0.04, 1.2))                 # coberta
	_bx("pano_cru", c, yaw, Vector3(0, 0.52, 0.78), Vector3(0.7, 0.12, 0.34))            # travesseiro
	b._blocker(_g, "ColCama", Vector3(1.1, 0.7, 2.1) if int(round(yaw / (PI / 2.0))) % 2 == 0 else Vector3(2.1, 0.7, 1.1), Vector3(x, 0.35, z))


func _armario(x: float, z: float, w := 1.3, h := 2.0, dd := 0.55, yaw := 0.0, mat := "madeira_escura") -> void:
	var c := Vector3(x, 0, z)
	_bx(mat, c, yaw, Vector3(0, h / 2.0, 0), Vector3(w, h, dd))
	_bx("madeira_natural", c, yaw, Vector3(0, h / 2.0, dd / 2.0 + 0.01), Vector3(0.03, h - 0.2, 0.03))
	_bx("ferro", c, yaw, Vector3(-0.08, h * 0.5, dd / 2.0 + 0.03), Vector3(0.04, 0.04, 0.04))
	_bx("ferro", c, yaw, Vector3(0.08, h * 0.5, dd / 2.0 + 0.03), Vector3(0.04, 0.04, 0.04))
	b._blocker(_g, "ColArmario", Vector3(w, h, dd) if int(round(yaw / (PI / 2.0))) % 2 == 0 else Vector3(dd, h, w), Vector3(x, h / 2.0, z))


func _prateleira(x: float, y: float, z: float, w: float, yaw := 0.0, garrafas := 0) -> void:
	var c := Vector3(x, y, z)
	_bx("madeira_natural", c, yaw, Vector3.ZERO, Vector3(w, 0.04, 0.3))
	for k in garrafas:
		var lx := -w / 2.0 + 0.15 + k * (w - 0.3) / maxf(garrafas - 1, 1.0)
		var p: Vector3 = c + Basis(Vector3.UP, yaw) * Vector3(lx, 0.14, 0)
		_bb.cylinder("vidro_oleo", 0.04, 0.04, 0.24, p, Vector3.ZERO, 7)
		_bb.cylinder("vidro_oleo", 0.015, 0.02, 0.07, p + Vector3(0, 0.15, 0), Vector3.ZERO, 6)


func _balcao(x: float, z: float, w: float, yaw := 0.0) -> void:
	var c := Vector3(x, 0, z)
	_bx("madeira_escura", c, yaw, Vector3(0, 0.5, 0), Vector3(w, 1.0, 0.7))
	_bx("madeira_natural", c, yaw, Vector3(0, 1.02, 0.02), Vector3(w + 0.1, 0.06, 0.82))
	for k in int(w / 0.9):
		_bx("madeira_natural", c, yaw, Vector3(-w / 2.0 + 0.45 + k * 0.9, 0.5, 0.36), Vector3(0.78, 0.84, 0.02))
	b._blocker(_g, "ColBalcao", Vector3(w, 1.0, 0.8) if int(round(yaw / (PI / 2.0))) % 2 == 0 else Vector3(0.8, 1.0, w), Vector3(x, 0.5, z))


func _fogao(x: float, z: float, yaw := 0.0) -> void:
	var c := Vector3(x, 0, z)
	_bx("cantaria", c, yaw, Vector3(0, 0.45, 0), Vector3(1.3, 0.9, 0.8))
	_bx("ferro", c, yaw, Vector3(0, 0.92, 0), Vector3(1.2, 0.04, 0.7))
	_bx("chama", c, yaw, Vector3(0, 0.45, 0.405), Vector3(0.4, 0.22, 0.02))                  # boca em brasa
	_bx("cantaria", c, yaw, Vector3(0, 2.0, -0.1), Vector3(0.7, 2.2, 0.55))                  # chaminé
	var l := b._lamp_light(_g, c + Basis(Vector3.UP, yaw) * Vector3(0, 0.6, 0.7), 0.7)
	l.light_color = Color(1.0, 0.45, 0.15)
	l.omni_range = 5.0
	b._blocker(_g, "ColFogao", Vector3(1.3, 0.9, 0.8) if int(round(yaw / (PI / 2.0))) % 2 == 0 else Vector3(0.8, 0.9, 1.3), Vector3(x, 0.45, z))


func _saco(x: float, z: float, yaw := 0.0) -> void:
	var c := Vector3(x, 0, z)
	_bx("pano_cru", c, yaw, Vector3(0, 0.22, 0), Vector3(0.5, 0.44, 0.34))
	_bx("pano_cru", c, yaw, Vector3(0, 0.46, 0), Vector3(0.36, 0.1, 0.24))
	b._blocker(_g, "ColSaco", Vector3(0.5, 0.45, 0.4), Vector3(x, 0.22, z))


func _quadro(x: float, y: float, z: float, lado: String, w := 0.5, h := 0.65, mat := "placa_preta") -> void:
	var dir := Vector3.ZERO
	var yaw := 0.0
	var p := Vector3(x, y, z)
	match lado:
		"O":
			yaw = PI / 2.0
		"L":
			yaw = -PI / 2.0
		"N":
			yaw = PI
		_:
			yaw = 0.0
	dir = Vector3(sin(yaw), 0, cos(yaw))
	_bb.box("ouro_velho", Vector3(w + 0.08, h + 0.08, 0.03), p + dir * 0.02, Vector3(0, yaw, 0))
	_bb.quad(mat, Vector2(w, h), p + dir * 0.04, yaw)


func _oratorio(x: float, z: float) -> void:
	# nicho na parede norte com santa (cone + esfera), velas e prateleira
	_bb.box("madeira_escura", Vector3(1.3, 1.6, 0.35), Vector3(x, 1.3, z))
	_bb.box("cantaria", Vector3(1.1, 0.05, 0.3), Vector3(x, 1.0, z - 0.2))
	_bb.cylinder("pano_azul", 0.14, 0.05, 0.42, Vector3(x, 1.28, z - 0.2), Vector3.ZERO, 8)
	_bb.sphere("bradador_palido", 0.06, Vector3(x, 1.56, z - 0.2), 8, 5)
	_bb.box("ouro_velho", Vector3(0.04, 0.3, 0.04), Vector3(x, 2.25, z - 0.12))
	_bb.box("ouro_velho", Vector3(0.18, 0.04, 0.04), Vector3(x, 2.3, z - 0.12))
	for k in [-1.0, 1.0]:
		_vela(x + k * 0.42, 1.02, z - 0.2, k > 0)


func _item(id: String, pos: Vector3, label: String) -> Area3D:
	var a := _area("Item_" + id, pos, Vector3(0.7, 0.6, 0.7), "res://scripts/coletavel.gd")
	a.set("tipo", "item")
	a.set("item_id", id)
	a.set("texto_interacao", label)
	var ib := b._batch()
	match id:
		"terco":
			for k in 9:
				var t := float(k) / 8.0
				var ang := PI * 0.15 + t * PI * 0.7
				ib.sphere("madeira_escura", 0.018, Vector3(cos(ang) * 0.09, 0.0, sin(ang) * 0.09 - 0.04), 5, 3)
			ib.box("ouro_velho", Vector3(0.02, 0.07, 0.01), Vector3(0.0, 0.01, 0.1))
			ib.box("ouro_velho", Vector3(0.05, 0.02, 0.01), Vector3(0.0, 0.02, 0.1))
		"chave_casarao", "chave_igreja":
			var m := "ferro" if id == "chave_casarao" else "ouro_velho"
			ib.cylinder(m, 0.035, 0.035, 0.015, Vector3(0, 0.0, 0.07), Vector3(PI / 2.0, 0, 0), 8)
			ib.box(m, Vector3(0.018, 0.012, 0.16), Vector3(0, 0.0, -0.04))
			ib.box(m, Vector3(0.05, 0.012, 0.02), Vector3(0.02, 0.0, -0.11))
		"livro":
			ib.box("couro", Vector3(0.26, 0.06, 0.34), Vector3(0, 0.0, 0))
			ib.box("papel", Vector3(0.24, 0.05, 0.32), Vector3(0.0, 0.0, 0.0))
			ib.box("couro", Vector3(0.27, 0.07, 0.03), Vector3(0, 0.0, -0.18))
		_:
			ib.box("papel", Vector3(0.2, 0.03, 0.2), Vector3.ZERO)
	b._mesh_node(a, "Malha", ib.commit(), Vector3(0, -0.05, 0))
	b._brilho(a, 0.12, 0.5)
	return a


func _oleo(x: float, y: float, z: float) -> void:
	b._coletavel(_g, "Oleo_%d" % _g.get_child_count(), Vector3(x, y, z), "oleo", 0, "Pegar querosene")


func _nota(x: float, y: float, z: float, id: int, label: String) -> void:
	b._coletavel(_g, "Nota_%d" % id, Vector3(x, y, z), "nota", id, label)


## Modelo real COM colisão em caixa (móveis grandes). `yaw`: 0 = frente para +z (parede sul); PI = frente para -z (parede norte).
func _prop_c(key: String, x: float, z: float, yaw := 0.0, escala := 1.0, y := 0.0) -> Node3D:
	var p := b._prop(_g, key, Vector3(x, y, z), yaw, escala)
	var bb: AABB = p.get_meta("bb")
	b._prop_collision(p, "caixa", bb.size, bb.get_center())
	return p


func _prop(key: String, x: float, z: float, yaw := 0.0, escala := 1.0, y := 0.0) -> Node3D:
	return b._prop(_g, key, Vector3(x, y, z), yaw, escala)


# ------------------------------------------------------------------ salas

func _sala_benedita(g: Node3D) -> void:
	_casca("Casa de Dona Benedita", 7.0, 6.0, 3.0, "reboco_creme", "madeira_natural")
	_cama(1.2, 4.7, 0.0)
	_armario(0.4, 2.2, 1.3, 2.0, 0.55, PI / 2.0)
	_fogao(6.0, 5.4, PI)
	_mesa(4.6, 2.9, 1.6, 0.9)
	_cadeira(3.8, 2.9, -PI / 2.0)
	_cadeira(5.4, 2.9, PI / 2.0)
	_cadeira(4.6, 2.1, 0.0)
	_lamparina(4.6, 0.82, 3.1)
	_oratorio(3.6, 5.75)
	_bb.box("pano_azul", Vector3(2.4, 0.012, 1.6), Vector3(3.0, 0.008, 3.4))             # tapete
	_janela("L", 3.2)
	_quadro(0.04, 1.8, 3.5, "O", 0.4, 0.5)
	_nota(4.3, 0.85, 2.7, 1, "Ler a carta de Dona Benedita")
	_item("terco", Vector3(3.2, 1.07, 5.55), "Pegar o terço de Dona Benedita")
	_oleo(6.3, 0.95, 3.3)
	_oleo(0.6, 1.4, 4.2)
	_prop("wooden_bucket_01", 6.4, 1.2, 0.5)
	_prop("wooden_stool_01", 5.4, 4.2, 0.3)
	_prop_c("round_wooden_table_02", 1.5, 1.2, 0.0, 1.0)
	_prop("long_life_food", 4.95, 3.2, 0.6, 1.0, 0.82)
	_prop("watering_can_metal_01", 6.4, 0.9, 2.5, 1.0)
	_prop("stationery_supplies", 1.5, 1.2, 0.3, 1.0, 0.75)
	_fim()


func _sala_padaria(g: Node3D) -> void:
	_casca("Padaria da esquina", 6.0, 5.0, 3.0, "reboco_amarelo", "madeira_escura")
	# forno de lenha na parede leste: arco de pedra, boca em brasa e luz de fogo
	_bb.box("cantaria", Vector3(1.4, 1.7, 2.0), Vector3(5.3, 0.85, 3.4))
	_bb.box("cantaria", Vector3(0.9, 1.7, 0.9), Vector3(5.4, 2.0, 3.4))
	_bb.box("chama", Vector3(0.02, 0.5, 0.9), Vector3(4.59, 0.9, 3.4))
	var lf := b._lamp_light(g, Vector3(4.2, 0.9, 3.4), 0.9)
	lf.light_color = Color(1.0, 0.42, 0.12)
	lf.omni_range = 6.0
	b._blocker(g, "ColForno", Vector3(1.4, 1.7, 2.0), Vector3(5.3, 0.85, 3.4))
	_balcao(2.0, 3.4, 2.6, PI / 2.0)
	_prateleira(0.35, 1.6, 1.4, 1.6, PI / 2.0)
	for k in 5:
		_bb.cylinder("pao", 0.1, 0.1, 0.18, Vector3(0.35, 1.7, 0.8 + k * 0.32), Vector3(0, 0, PI / 2.0), 7)
	_mesa(3.0, 1.9, 1.4, 0.9, 0.9)
	_saco(5.3, 0.7)
	_saco(5.6, 1.2, 0.5)
	_saco(5.2, 1.7)
	_lamparina(2.0, 1.06, 3.6)
	_janela("N", 3.0)
	_nota(2.0, 1.15, 2.9, 4, "Ler o recado")
	_nota(2.0, 1.15, 4.1, 10, "Ler o caderno de fiado")
	_oleo(3.1, 0.95, 1.9)
	_prop("wooden_bucket_01", 1.2, 4.4, 0.0)
	_prop("long_life_food", 2.0, 3.5, 1.2, 1.0, 1.05)
	_prop("watering_can_metal_01", 4.4, 4.5, 0.4, 1.0)
	_fim()


func _sala_venda(g: Node3D) -> void:
	_casca("Venda do Seu Zé", 8.0, 6.0, 3.1, "reboco_ocre", "madeira_escura")
	_balcao(4.0, 4.7, 4.4)
	_prateleira(4.0, 1.55, 5.82, 3.6, 0.0, 9)
	_prateleira(4.0, 2.05, 5.82, 3.6, 0.0, 8)
	_prop("wine_barrel_01", 0.7, 1.4, 0.0)
	_prop("wine_barrel_01", 0.7, 2.5, 1.0)
	for k in 3:
		_prop("wooden_stool_01", 2.7 + k * 1.2, 3.55, k * 0.7)
	_saco(7.2, 4.9, 0.3)
	_saco(7.5, 5.4)
	_mesa(7.4, 2.5, 1.0, 0.8, 0.9, "madeira_escura", PI / 2.0)       # mesinha da TV
	b._tv(g, Vector3(7.4, 0.94, 2.5), -PI / 2.0)
	_lamparina(2.4, 1.08, 4.7)
	_janela("O", 3.0)
	_quadro(5.0, 1.9, 5.82, "N", 0.6, 0.5)
	_nota(5.8, 1.1, 4.6, 6, "Ler o bilhete do Seu Zé")
	_item("chave_casarao", Vector3(3.3, 1.1, 4.6), "Abrir a gaveta: pegar a chave do casarão")
	_oleo(6.2, 1.1, 4.7)
	_prop("cigarette_pack", 4.9, 4.45, 0.4, 1.5, 1.05)
	_prop("long_life_food", 3.0, 4.9, 0.0, 1.0, 1.05)
	_prop("long_life_food", 5.2, 4.9, 0.5, 1.0, 1.05)
	_prop_c("worn_metal_rack", 7.4, 0.8, -PI / 2.0, 1.0)
	_prop_c("standing_chalkboard_01", 6.2, 1.2, 0.3, 1.0)
	_fim()


func _sala_barbearia(g: Node3D) -> void:
	_casca("Barbearia", 5.0, 5.0, 3.0, "reboco_azul", "madeira_natural")
	# cadeira de barbeiro: assento, encosto, apoio e pé de ferro
	_bb.box("couro", Vector3(0.6, 0.12, 0.6), Vector3(2.5, 0.62, 2.8))
	_bb.box("couro", Vector3(0.6, 0.8, 0.12), Vector3(2.5, 1.1, 3.15))
	_bb.box("couro", Vector3(0.5, 0.06, 0.4), Vector3(2.5, 0.32, 2.35))
	_bb.cylinder("ferro", 0.09, 0.14, 0.55, Vector3(2.5, 0.28, 2.8), Vector3.ZERO, 8)
	for k in [-1.0, 1.0]:
		_bb.box("couro", Vector3(0.08, 0.06, 0.5), Vector3(2.5 + k * 0.34, 0.9, 2.8))
	b._blocker(g, "ColCadeira", Vector3(0.9, 1.4, 1.1), Vector3(2.5, 0.7, 2.8))
	# espelho grande na parede norte, prateleira com frascos
	_bb.box("ouro_velho", Vector3(1.9, 1.3, 0.04), Vector3(2.5, 1.7, 4.97))
	_bb.quad("vidro_noite", Vector2(1.8, 1.2), Vector3(2.5, 1.7, 4.94), PI)
	_prateleira(2.5, 1.0, 4.82, 2.0, 0.0, 6)
	_mesa(0.9, 4.2, 0.8, 0.6, 0.8)
	_lamparina(0.9, 0.84, 4.2)
	_janela("L", 2.5)
	_nota(0.9, 0.92, 4.0, 9, "Ler o recorte de jornal")
	_oleo(4.4, 0.95, 1.5)
	_cadeira(4.3, 3.8, -PI / 2.0)
	_prop("cigarette_pack", 0.9, 4.1, 0.8, 1.5, 0.75)
	_prop_c("worn_metal_rack", 4.55, 4.5, PI, 0.9)
	_fim()


func _sala_sineiro(g: Node3D) -> void:
	_casca("Casa do sineiro", 6.0, 5.0, 2.9, "reboco_branco", "madeira_escura")
	_cama(0.9, 3.7, 0.0, "pano_cru")
	# caixa de madeira embaixo da cama (onde está a chave)
	_bb.box("madeira_natural", Vector3(0.5, 0.26, 0.4), Vector3(1.0, 0.13, 2.45))
	_bb.box("ferro", Vector3(0.52, 0.03, 0.42), Vector3(1.0, 0.27, 2.45))
	_mesa(4.2, 3.4, 1.4, 0.8)
	_cadeira(4.2, 2.7, 0.0)
	_cadeira(4.2, 4.1, PI)
	_lamparina(4.1, 0.82, 3.4)
	# corda do sino pendurada
	_bb.cylinder("pano_cru", 0.025, 0.025, 2.3, Vector3(5.5, 1.75, 4.6), Vector3.ZERO, 6)
	_bb.sphere("pano_cru", 0.1, Vector3(5.5, 0.55, 4.6), 6, 4)
	_oratorio(3.0, 4.75)
	_janela("L", 2.0)
	_nota(3.8, 0.85, 3.5, 8, "Ler a carta do Seu Tobias")
	_nota(4.6, 0.85, 3.3, 3, "Ler a anotação do sacristão")
	_item("chave_igreja", Vector3(1.0, 0.4, 2.45), "Abrir a caixa: pegar a chave da igreja")
	_oleo(5.6, 0.95, 1.0)
	_prop("wooden_bucket_01", 5.4, 1.6, 0.2)
	_prop("vintage_binocular", 4.55, 3.75, 0.9, 1.0, 0.82)
	_prop("wooden_axe_02", 5.4, 3.2, 0.0, 1.0, 0.0).rotation.z = 0.25
	_fim()


func _sala_casarao(g: Node3D) -> void:
	_casca("Casarão dos Vaz", 10.0, 8.0, 3.8, "reboco_ocre", "madeira_escura")
	# mesa de jantar comprida com cadeiras (uma caída), castiçal apagado
	_mesa(5.0, 3.8, 3.6, 1.1, 0.8, "madeira_escura")
	for k in 3:
		_cadeira(3.9 + k * 1.1, 4.6, PI)
	for k in 2:
		_cadeira(3.9 + k * 1.1, 3.0, 0.0)
	_bx("madeira_natural", Vector3(7.4, 0, 3.8), 0.4, Vector3(0, 0.22, 0), Vector3(0.44, 0.44, 0.04))     # cadeira tombada
	_bb.cylinder("ouro_velho", 0.04, 0.04, 0.3, Vector3(5.0, 0.99, 3.8), Vector3.ZERO, 6)
	# retratos escuros, um espelho quebrado, lustre apagado
	for k in 4:
		_quadro(1.6 + k * 2.2, 2.2, 7.95, "N", 0.7, 0.9)
	_quadro(0.04, 1.9, 4.0, "O", 0.9, 1.3, "vidro_noite")
	_bb.box("ouro_velho", Vector3(1.4, 0.05, 1.4), Vector3(5.0, 3.1, 3.8))
	_bb.cylinder("ferro", 0.02, 0.02, 0.7, Vector3(5.0, 3.45, 3.8), Vector3.ZERO, 5)
	# escada que sobe e para numa parede (a ala de cima está desabada)
	for k in 8:
		_bb.box("madeira_escura", Vector3(1.2, 0.18, 0.3), Vector3(9.2, 0.09 + k * 0.18, 1.0 + k * 0.3))
	b._blocker(g, "ColEscada", Vector3(1.2, 1.5, 2.4), Vector3(9.2, 0.75, 2.2))
	# escrivaninha do capataz no canto: o livro está aqui
	_mesa(1.4, 6.7, 1.6, 0.8, 0.78, "madeira_escura")
	_cadeira(1.4, 6.0, 0.0)
	_vela(1.0, 0.82, 6.9, true)
	_item("livro", Vector3(1.8, 0.88, 6.7), "Pegar o livro de registros dos Vaz")
	_oleo(8.8, 0.9, 6.9)
	_janela("L", 5.5, 1.9, 1.0, 1.6)
	_janela("O", 1.8, 1.9, 1.0, 1.6)
	_prop_c("GothicCabinet_01", 6.0, 7.35, PI, 1.0)
	_prop_c("vintage_day_bed", 2.0, 0.75, 0.0, 1.0)
	_prop_c("gothic_coffee_table", 2.0, 2.6, 0.5, 1.0)
	_prop("stationery_supplies", 1.55, 6.5, 0.4, 1.0, 0.82)
	_fim()
	# poeira: nada de lamparina acesa aqui, só a vela do escritório e o luar


func _sala_igreja(g: Node3D) -> void:
	_casca("Igreja Matriz", 10.0, 22.0, 8.0, "reboco_branco", "cantaria", "madeira_escura")
	# fileiras de bancos dos dois lados do corredor central
	for k in 8:
		var z := 4.0 + k * 1.5
		for lado in [0, 1]:
			var x0 := 1.2 if lado == 0 else 6.2
			_bb.box("madeira_natural", Vector3(2.6, 0.06, 0.45), Vector3(x0 + 1.3, 0.45, z))
			_bb.box("madeira_escura", Vector3(2.6, 0.6, 0.06), Vector3(x0 + 1.3, 0.85, z - 0.24))
			for lx in [0.1, 1.3, 2.5]:
				_bb.box("madeira_escura", Vector3(0.06, 0.45, 0.4), Vector3(x0 + lx, 0.22, z))
		b._blocker(g, "ColBanco_%d" % k, Vector3(2.7, 0.9, 0.5), Vector3(2.5, 0.45, z))
		b._blocker(g, "ColBancoD_%d" % k, Vector3(2.7, 0.9, 0.5), Vector3(7.5, 0.45, z))
	# presbitério: degraus, altar de pedra, retábulo dourado com cruz e velas
	_bb.box("cantaria", Vector3(9.4, 0.3, 3.8), Vector3(5.0, 0.15, 19.9))
	_bb.box("cantaria", Vector3(9.4, 0.3, 2.6), Vector3(5.0, 0.45, 20.5))
	b._blocker(g, "ColDegrau", Vector3(9.4, 0.6, 3.8), Vector3(5.0, 0.3, 19.9))
	_bb.box("cantaria", Vector3(2.6, 1.05, 0.95), Vector3(5.0, 1.12, 20.2))
	_bb.box("cantaria", Vector3(2.9, 0.08, 1.1), Vector3(5.0, 1.68, 20.2))
	b._blocker(g, "ColAltar", Vector3(2.7, 1.2, 1.05), Vector3(5.0, 1.2, 20.2))
	_bb.box("ouro_velho", Vector3(7.5, 6.0, 0.5), Vector3(5.0, 4.0, 21.75))
	for k in [-1.0, 1.0]:
		_bb.box("ouro_velho", Vector3(0.5, 6.4, 0.7), Vector3(5.0 + k * 3.4, 3.8, 21.5))
		_bb.cylinder("cantaria", 0.28, 0.28, 5.6, Vector3(5.0 + k * 2.6, 3.3, 21.2), Vector3.ZERO, 10)
	_bb.box("ferro", Vector3(0.18, 2.4, 0.12), Vector3(5.0, 4.6, 21.45))
	_bb.box("ferro", Vector3(1.2, 0.18, 0.12), Vector3(5.0, 5.2, 21.45))
	_bb.box("bradador_palido", Vector3(0.28, 1.1, 0.1), Vector3(5.0, 4.5, 21.38))
	for k in [-1.0, 1.0]:
		for j in 2:
			_vela(5.0 + k * (0.7 + j * 0.45), 1.72, 20.2, j == 0)
	# janelas altas com luar e arcos
	for k in 3:
		_janela("O", 5.0 + k * 5.5, 5.0, 1.0, 2.4)
		_janela("L", 5.0 + k * 5.5, 5.0, 1.0, 2.4)
	# luz do fundo da nave (cruzeiro) e lampadário de ferro
	var lc := b._lamp_light(g, Vector3(5.0, 6.2, 10.0), 0.9)
	lc.omni_range = 12.0
	b._halo(g, Vector3(5.0, 6.2, 10.0), 2.0, "halo_vela")
	_bb.cylinder("ferro", 0.45, 0.45, 0.05, Vector3(5.0, 6.2, 10.0), Vector3.ZERO, 10)
	_bb.cylinder("ferro", 0.015, 0.015, 1.6, Vector3(5.0, 7.2, 10.0), Vector3.ZERO, 5)
	_oleo(1.0, 0.95, 3.0)
	_nota(5.0, 1.78, 19.8, 2, "Ler o que a Irmandade deixou no altar")
	var al := _area("Altar", Vector3(5.0, 1.2, 18.9), Vector3(3.2, 2.4, 1.6), "res://scripts/altar.gd")
	al.set("texto_interacao", "Ler os nomes em voz alta")
	al.set("requer", "livro")
	_fim()


func _sala_carpintaria(g: Node3D) -> void:
	_casca("Carpintaria do Seu Mateus", 8.0, 6.0, 3.2, "reboco_branco", "madeira_natural")
	# bancada comprida com plaina, serrote e tábuas; ferramentas na prateleira de metal
	_mesa(4.0, 4.6, 3.2, 0.9, 0.9, "madeira_natural")
	_prop("hand_plane_no4", 3.3, 4.5, 0.4, 1.0, 0.94)
	_prop("handsaw_wood", 4.6, 4.7, 1.2, 1.0, 0.94)
	_prop_c("worn_metal_rack", 0.5, 4.2, PI / 2.0, 1.0)
	_prop("wooden_axe_02", 1.3, 4.2, 0.0, 1.0, 0.0).rotation.z = 0.25
	_prop_c("wooden_ladder", 7.45, 3.0, -PI / 2.0, 1.5).rotation.x = -0.18
	for k in 5:
		_bb.box("madeira_natural", Vector3(2.2, 0.06, 0.28), Vector3(6.4, 0.05 + k * 0.07, 5.4))      # pilha de tábuas
	_bb.box("madeira_natural", Vector3(0.8, 0.5, 0.8), Vector3(1.2, 0.25, 1.2))                         # cepos
	b._blocker(g, "ColCepo", Vector3(0.8, 0.5, 0.8), Vector3(1.2, 0.25, 1.2))
	_lamparina(4.0, 0.95, 4.4)
	_janela("L", 2.0)
	_nota(2.6, 0.95, 4.6, 12, "Ler o bilhete do Seu Mateus")
	_oleo(6.9, 0.95, 0.9)
	_prop("watering_can_metal_01", 7.2, 5.2, 0.3, 1.0)
	_fim()


func _sala_escola(g: Node3D) -> void:
	_casca("Escola Rural", 7.0, 6.0, 3.2, "reboco_creme", "madeira_natural")
	_prop_c("standing_chalkboard_01", 3.5, 5.3, PI, 1.5)
	_quadro(6.96, 1.8, 3.0, "L", 1.4, 0.9, "placa_verde")
	for fila in 2:
		for col in 3:
			var x := 1.4 + col * 1.7
			var z := 1.9 + fila * 1.3
			_mesa(x, z, 1.0, 0.5, 0.7, "madeira_natural")
			_cadeira(x, z - 0.55, PI, "madeira_escura")
	_mesa(5.6, 4.8, 1.4, 0.7, 0.8, "madeira_escura")                # mesa da professora
	_prop("stationery_supplies", 5.6, 4.8, 0.4, 1.0, 0.84)
	_lamparina(5.2, 0.84, 4.9)
	_janela("O", 3.0)
	_nota(6.0, 0.9, 4.8, 13, "Ler o caderno de caligrafia")
	_oleo(0.6, 0.95, 5.3)
	_fim()


func _sala_ferraria(g: Node3D) -> void:
	_casca("Ferraria", 7.0, 5.0, 3.4, "reboco_ocre", "cantaria")
	# forja de pedra com brasa e fole, bigorna, tonel d'água, aros de roda
	_bb.box("cantaria", Vector3(1.8, 1.0, 1.4), Vector3(5.8, 0.5, 4.1))
	_bb.box("chama", Vector3(1.2, 0.04, 0.8), Vector3(5.8, 1.01, 4.1))
	_bb.box("cantaria", Vector3(0.9, 2.4, 0.9), Vector3(5.8, 2.2, 4.5))
	var lf := b._lamp_light(g, Vector3(5.8, 1.5, 3.5), 1.0)
	lf.light_color = Color(1.0, 0.4, 0.1)
	lf.omni_range = 6.0
	b._blocker(g, "ColForja", Vector3(1.8, 1.0, 1.4), Vector3(5.8, 0.5, 4.1))
	_bb.box("ferro", Vector3(0.5, 0.35, 0.3), Vector3(3.6, 0.7, 3.4))                              # bigorna
	_bb.box("madeira_escura", Vector3(0.4, 0.55, 0.4), Vector3(3.6, 0.27, 3.4))
	b._blocker(g, "ColBigorna", Vector3(0.6, 0.9, 0.5), Vector3(3.6, 0.45, 3.4))
	_prop_c("wine_barrel_01", 0.7, 4.2, 0.0, 1.0)
	_prop_c("worn_metal_rack", 0.4, 2.0, PI / 2.0, 1.0)
	_prop("rusted_wheel_rim_02", 1.5, 1.2, 0.5, 1.5).rotation.x = -0.2
	_prop("wooden_axe_02", 1.1, 2.0, 0.0, 1.0, 0.0).rotation.z = 0.25
	_prop("hand_plane_no4", 3.6, 3.4, 0.3, 1.0, 0.89)
	_lamparina(2.4, 0.01, 4.6, 0.7)
	_janela("L", 2.0)
	_oleo(6.4, 1.05, 1.0)
	_nota(2.4, 0.2, 4.4, 14, "Ler a encomenda do ferreiro")
	_fim()


func _sala_casa_vazia(g: Node3D) -> void:
	_casca("Casa abandonada", 6.0, 5.0, 2.9, "reboco_verde", "madeira_escura")
	_prop_c("old_bed_frame", 1.1, 3.8, 0.0, 1.0)
	_cadeira(3.6, 2.4, 1.0)                                                    # cadeira virada
	_bx("madeira_natural", Vector3(4.6, 0, 3.4), 0.9, Vector3(0, 0.2, 0), Vector3(0.44, 0.44, 0.04))
	_mesa(4.4, 3.8, 1.2, 0.8)
	_prop_c("GothicCabinet_01", 3.0, 4.35, PI, 0.9)
	_prop("cigarette_pack", 4.4, 3.8, 0.2, 1.5, 0.82)
	_vela(4.9, 0.82, 4.0, true)
	_janela("L", 2.5)
	_nota(4.2, 0.85, 3.6, 15, "Ler o diário abandonado")
	_oleo(5.5, 0.95, 1.0)
	_fim()


func _sala_pensao(g: Node3D) -> void:
	_casca("Pensão da Dona Elvira", 7.0, 6.0, 3.0, "reboco_salmao", "madeira_natural")
	_prop_c("old_bed_frame", 1.0, 4.6, 0.0, 1.0)
	_prop_c("old_bed_frame", 6.0, 4.6, 0.0, 1.0)
	_prop_c("vintage_day_bed", 3.5, 0.9, 0.0, 1.0)
	_prop_c("gothic_coffee_table", 3.5, 2.6, 0.0, 1.0)
	_prop("vintage_binocular", 3.2, 2.6, 0.4, 1.0, 0.56)
	_prop("cigarette_pack", 3.9, 2.4, 1.0, 1.5, 0.56)
	_mesa(3.5, 5.3, 1.2, 0.7, 0.8, "madeira_escura")
	_prop("stationery_supplies", 3.2, 5.3, 0.4, 1.0, 0.84)
	_lamparina(3.9, 0.84, 5.3)
	_janela("L", 4.0)
	_janela("O", 4.0)
	_nota(3.6, 0.88, 5.0, 16, "Ler o livro de hóspedes")
	_oleo(6.5, 0.95, 1.0)
	_fim()


func _sala_costureira(g: Node3D) -> void:
	_casca("Casa da costureira", 6.0, 5.0, 2.9, "reboco_azul", "madeira_natural")
	_mesa(3.0, 3.6, 1.8, 0.9, 0.8, "madeira_natural")                           # mesa de corte
	_bb.box("pano_rosa", Vector3(1.4, 0.03, 0.8), Vector3(3.0, 0.83, 3.6))
	_prop("stationery_supplies", 3.8, 3.4, 0.6, 1.0, 0.84)
	# manequim: tronco de cone + esfera
	_bb.cylinder("pano_cru", 0.24, 0.14, 0.7, Vector3(5.2, 1.2, 3.8), Vector3.ZERO, 10)
	_bb.cylinder("madeira_escura", 0.03, 0.03, 0.85, Vector3(5.2, 0.42, 3.8), Vector3.ZERO, 6)
	_bb.sphere("pano_cru", 0.1, Vector3(5.2, 1.62, 3.8), 7, 4)
	b._blocker(g, "ColManequim", Vector3(0.5, 1.6, 0.5), Vector3(5.2, 0.8, 3.8))
	for k in 4:
		_bb.cylinder(["pano_azul", "pano_rosa", "pano_cru", "listra_vermelha"][k], 0.1, 0.1, 0.8, Vector3(0.5, 0.1 + k * 0.2, 1.4 + k * 0.01), Vector3(PI / 2.0, 0, 0), 8)
	_prop_c("GothicCabinet_01", 1.6, 4.35, PI, 0.9)
	_lamparina(3.0, 0.83, 3.1)
	_janela("L", 2.0)
	_nota(2.5, 0.88, 3.5, 17, "Ler a encomenda do vestido")
	_oleo(5.5, 0.95, 1.0)
	_fim()


func _sala_deposito(g: Node3D) -> void:
	_casca("Depósito", 7.0, 5.0, 3.2, "reboco_branco", "cantaria")
	_prop_c("worn_metal_rack", 0.4, 1.6, PI / 2.0, 1.0)
	_prop_c("worn_metal_rack", 0.4, 3.2, PI / 2.0, 1.0)
	for k in 6:
		_prop("long_life_food", 0.45, 1.0 + k * 0.5, PI / 2.0, 1.0, 0.95 if k % 2 == 0 else 1.45)
	_prop_c("wine_barrel_01", 6.3, 1.0, 0.0, 1.0)
	_prop_c("wine_barrel_01", 6.3, 2.0, 1.0, 1.0)
	_saco(5.4, 3.8)
	_saco(5.9, 4.2, 0.5)
	_saco(6.4, 3.7)
	_prop_c("wooden_ladder", 3.5, 4.55, PI, 1.5).rotation.x = 0.18
	_prop("watering_can_metal_01", 2.5, 3.8, 0.3, 1.0)
	_lamparina(3.5, 0.01, 1.2, 0.7)
	_janela("L", 2.0)
	_oleo(2.0, 0.95, 4.5)
	_oleo(6.0, 1.25, 1.5)
	_fim()
