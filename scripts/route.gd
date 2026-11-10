class_name Route
extends RefCounted
## Rota principal da vila: uma rua sinuosa que sobe o morro até a igreja.
## A curva (x,z), a altitude e a largura são definidas por pontos de controle abaixo.
## É a fonte única de verdade: o gerador do mundo (tools/) e o jogo (gritos, IA) usam isto.
##
## Para mudar o desenho da rua: edite as listas CTRL_*, rode tools/bake.gd (recria o mundo).

## A rua vem do PLANO DA VILA (scripts/plano_vila.gd, mapa do zero): pernas retas em zigue-zague ligadas por curvas de raio fixo.
## Altura: cada peça tem a sua rampa. Largura do leito: constante nas ruas, alarga no adro da igreja.
const CTRL_W: Array[Vector2] = [
	Vector2(0, 5.0), Vector2(435.0, 5.0), Vector2(445.0, 14.0), Vector2(455.0, 20.0), Vector2(540.0, 20.0),
]
## Deslocamento (m) das distâncias s depois da curva inicial (a rua ficou 25 m mais comprida no começo).
const SHIFT := 0.0          # (o mapa antigo deslocava 25 m; o mapa novo não usa mais)
const STEP := 0.5
const SIDEWALK := 0.7
## s onde termina o casario e começa o adro da igreja, e s da fachada da igreja.
const S_END := 435.0
const CHURCH_S := 482.0
## ponte de pedra sobre um riacho que cruza a rua em BRIDGE_S (metade do comprimento = BRIDGE_HALF)
const BRIDGE_S := 63.5
const BRIDGE_HALF := 4.6
## chafariz de pedra no largo (lado +1 = direita de quem sobe)
const FOUNTAIN_S := 118.7
const FOUNTAIN_SIDE := -1.0

static var _built := false
static var _pts: PackedVector2Array
static var _len := 0.0


static var _hs := PackedFloat32Array()


static func _build() -> void:
	if _built:
		return
	var pl := PlanoVila.new()
	var dense := pl.eixo3(0.1)
	# começa no ponto mais perto de (0, 0) e reamostra em passos iguais (STEP), guardando a altura
	var start := 0                                      # a rua começa no começo da 1ª peça do plano (s = 0)
	var h0 := dense[start].y
	_pts = PackedVector2Array()
	_hs = PackedFloat32Array()
	_pts.append(Vector2(dense[start].x, dense[start].z))
	_hs.append(0.0)
	var acc := 0.0
	var prev := dense[start]
	for i in range(start + 1, dense.size()):
		var cur := dense[i]
		var seg := Vector2(prev.x, prev.z).distance_to(Vector2(cur.x, cur.z))
		while acc + seg >= STEP and seg > 0.0:
			var t := (STEP - acc) / seg
			prev = prev.lerp(cur, t)
			_pts.append(Vector2(prev.x, prev.z))
			_hs.append(prev.y - h0)
			seg = Vector2(prev.x, prev.z).distance_to(Vector2(cur.x, cur.z))
			acc = 0.0
		acc += seg
		prev = cur
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
	var t := (s - ctrl[i].x) / (ctrl[i + 1].x - ctrl[i].x)
	return lerpf(ctrl[i].y, ctrl[i + 1].y, smoothstep(0.0, 1.0, t))


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
	_build()
	if s <= 0.0:
		return _hs[0] + s * 0.08                       # antes do começo (a rua da estação continua descendo)
	var f := clampf(s, 0.0, _len) / STEP
	var i := mini(int(f), _hs.size() - 2)
	return lerpf(_hs[i], _hs[i + 1], f - i)


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
