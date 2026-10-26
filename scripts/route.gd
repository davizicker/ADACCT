class_name Route
extends RefCounted
## Rota principal da vila: uma rua sinuosa que sobe o morro até a igreja.
## A curva (x,z), a altitude e a largura são definidas por pontos de controle abaixo.
## É a fonte única de verdade: o gerador do mundo (tools/) e o jogo (gritos, IA) usam isto.
##
## Para mudar o desenho da rua: edite as listas CTRL_*, rode tools/bake.gd (recria o mundo).

## Pontos (x, z) por onde a rua passa. A rua começa em (0,0) olhando para -Z.
const CTRL_XZ: Array[Vector2] = [
	Vector2(0, 14), Vector2(0, 0), Vector2(2, -26), Vector2(-4, -52), Vector2(-17, -74),
	Vector2(-26, -100), Vector2(-19, -126), Vector2(-3, -145), Vector2(13, -168),
	Vector2(18, -198), Vector2(9, -225), Vector2(-7, -244), Vector2(-12, -271),
	Vector2(-5, -295), Vector2(6, -312), Vector2(10, -330),
]
## Altitude (m) em função da distância percorrida s (m).
const CTRL_H: Array[Vector2] = [
	Vector2(-20, -2), Vector2(0, 0), Vector2(30, 3.5), Vector2(60, 9.0), Vector2(90, 13.0),
	Vector2(120, 17.5), Vector2(150, 19.5), Vector2(178, 19.9), Vector2(208, 26.0),
	Vector2(238, 32.0), Vector2(268, 36.5), Vector2(300, 38.0), Vector2(345, 38.8),
]
## Largura do leito da rua (m, entre meios-fios) em função de s.
const CTRL_W: Array[Vector2] = [
	Vector2(0, 5.5), Vector2(22, 5.5), Vector2(45, 4.2), Vector2(68, 3.4), Vector2(92, 4.4),
	Vector2(118, 5.5), Vector2(138, 6.0), Vector2(152, 12.0), Vector2(166, 13.0),
	Vector2(180, 6.0), Vector2(202, 5.0), Vector2(218, 3.6), Vector2(240, 3.6),
	Vector2(258, 5.0), Vector2(282, 6.0), Vector2(296, 11.0), Vector2(312, 19.0), Vector2(345, 20.0),
]
const STEP := 0.5
const SIDEWALK := 0.7
## s onde termina o casario e começa o adro da igreja, e s da fachada da igreja.
const S_END := 296.0
const CHURCH_S := 338.0
## ponte de pedra sobre um riacho que cruza a rua em BRIDGE_S (metade do comprimento = BRIDGE_HALF)
const BRIDGE_S := 118.0
const BRIDGE_HALF := 4.6
## chafariz de pedra no largo (lado +1 = direita de quem sobe)
const FOUNTAIN_S := 160.0
const FOUNTAIN_SIDE := 1.0

static var _built := false
static var _pts: PackedVector2Array
static var _len := 0.0


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func _build() -> void:
	if _built:
		return
	# 1) amostra densa da curva Catmull-Rom
	var dense := PackedVector2Array()
	var n := CTRL_XZ.size()
	for i in range(1, n - 2):
		for k in 60:
			dense.append(_catmull(CTRL_XZ[i - 1], CTRL_XZ[i], CTRL_XZ[i + 1], CTRL_XZ[i + 2], float(k) / 60.0))
	dense.append(CTRL_XZ[n - 2])
	# 2) reamostra em passos iguais de comprimento de arco (STEP) a partir do ponto (0,0)
	var start := 0
	for i in dense.size():
		if dense[i].distance_to(Vector2.ZERO) < 0.2:
			start = i
			break
	_pts = PackedVector2Array()
	_pts.append(dense[start])
	var acc := 0.0
	var prev := dense[start]
	for i in range(start + 1, dense.size()):
		var seg := prev.distance_to(dense[i])
		while acc + seg >= STEP:
			var t := (STEP - acc) / seg
			prev = prev.lerp(dense[i], t)
			_pts.append(prev)
			seg = prev.distance_to(dense[i])
			acc = 0.0
		acc += seg
		prev = dense[i]
	_len = (_pts.size() - 1) * STEP
	_built = true


static func _interp(ctrl: Array[Vector2], s: float) -> float:
	var n := ctrl.size()
	if s <= ctrl[0].x:
		return ctrl[0].y
	if s >= ctrl[n - 1].x:
		return ctrl[n - 1].y
	var i := 0
	while i < n - 2 and s > ctrl[i + 1].x:
		i += 1
	var p0 := ctrl[maxi(i - 1, 0)]
	var p1 := ctrl[i]
	var p2 := ctrl[i + 1]
	var p3 := ctrl[mini(i + 2, n - 1)]
	var t := (s - p1.x) / (p2.x - p1.x)
	# Catmull-Rom só no valor (y); x é linear em s, o que é suficiente aqui
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1.y) + (-p0.y + p2.y) * t + (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 + (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3)


## Comprimento total da rota (m).
static func length() -> float:
	_build()
	return _len


static func _xz(s: float) -> Vector2:
	_build()
	var f := clampf(s, 0.0, _len) / STEP
	var i := mini(int(f), _pts.size() - 2)
	return _pts[i].lerp(_pts[i + 1], f - i)


static func height(s: float) -> float:
	return _interp(CTRL_H, s)


static func width(s: float) -> float:
	return _interp(CTRL_W, s)


## Ponto da linha central da rua, com altitude.
static func pos(s: float) -> Vector3:
	var p := _xz(s)
	return Vector3(p.x, height(s), p.y)


## Direção horizontal de caminhada (sentido da subida), normalizada.
static func tangent(s: float) -> Vector3:
	var a := _xz(s - 0.6)
	var b := _xz(s + 0.6)
	var d := b - a
	if d.length() < 0.001:
		d = Vector2(0, -1)
	d = d.normalized()
	return Vector3(d.x, 0.0, d.y)


## Normal horizontal à direita de quem sobe a rua.
static func right(s: float) -> Vector3:
	return tangent(s).cross(Vector3.UP)


## s (m) do ponto da rota mais próximo de uma posição no mundo (ignora altura).
static func nearest_s(p: Vector3) -> float:
	_build()
	var q := Vector2(p.x, p.z)
	var best := 0
	var best_d := INF
	for i in _pts.size():
		var d := q.distance_squared_to(_pts[i])
		if d < best_d:
			best_d = d
			best = i
	return best * STEP


## Distância horizontal até a linha central.
static func dist_to_center(p: Vector3) -> float:
	var s := nearest_s(p)
	var c := _xz(s)
	return Vector2(p.x, p.z).distance_to(c)


## Altitude da rua mais próxima de uma posição (para posicionar objetos).
static func ground_near(p: Vector3) -> float:
	return height(nearest_s(p))
