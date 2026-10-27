class_name Mula
extends Node3D
## Mula-sem-cabeça: galopa pela rua com fogo no pescoço. REGRA: ela corre atrás da luz.
##  - Na rua: morte.
##  - Num beco (refúgio) com o lampião APAGADO: ela passa e você está a salvo.
##  - Num refúgio com o lampião ACESO: ela vê a luz, o Bradador se aproxima (penalidade).
## O aviso é sonoro: galope no calçamento, vindo de longe, e luz alaranjada nas fachadas.

signal finished

const SPEED := 15.0

var active := false
var dir := -1.0          # -1 = descendo a rua, +1 = subindo
var s_m := 0.0
var player: Player
var screams: ScreamSystem
var audio: AudioDirector
## preenchido pelo EventDirector: quantos refúgios contêm o jogador agora
var refuge_count := 0

var _gallop: AudioStreamPlayer3D
var _fire: AudioStreamPlayer3D
var _neigh: AudioStreamPlayer3D
var _phase := 0.0
var _judged := false
var _legs: Array[Node3D] = []


func _ready() -> void:
	visible = false
	for n in ["PernaFE", "PernaFD", "PernaTE", "PernaTD"]:
		var leg := get_node_or_null(n) as Node3D
		if leg != null:
			_legs.append(leg)
	_gallop = _make_sound(Synth.gallop(), 4.0, 28.0)
	_fire = _make_sound(Synth.fire(), -2.0, 9.0)
	_neigh = _make_sound(Synth.neigh(), 2.0, 40.0)
	_neigh.stream.loop_mode = AudioStreamWAV.LOOP_DISABLED


func _make_sound(stream: AudioStream, db: float, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "Efeitos"
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = 0.0
	add_child(p)
	return p


## Começa o galope em `start_s` indo na direção `direction` (-1 desce, +1 sobe).
func start(p_player: Player, p_screams: ScreamSystem, p_audio: AudioDirector, start_s: float, direction: float) -> void:
	player = p_player
	screams = p_screams
	audio = p_audio
	s_m = start_s
	dir = direction
	active = true
	_judged = false
	visible = true
	_update_pose(0.0)
	_gallop.play()
	_fire.play()
	_neigh.play()
	if audio != null:
		audio.bump_fear(0.35)


func _update_pose(delta: float) -> void:
	var p := Route.pos(s_m)
	global_position = Vector3(p.x, p.y + 0.12, p.z)
	var t := Route.tangent(s_m) * dir
	look_at(global_position + t, Vector3.UP)
	_phase += delta * 11.0
	for i in _legs.size():
		var swing := sin(_phase + (i % 2) * PI + (i / 2) * 0.9) * 0.75
		_legs[i].rotation.x = swing


func _process(delta: float) -> void:
	if not active or player == null:
		return
	s_m += dir * SPEED * delta
	_update_pose(delta)
	var s_p := Route.nearest_s(player.global_position)
	var ds := absf(s_m - s_p)
	# fogo cresce quando chega perto
	_gallop.volume_db = lerpf(-6.0, 6.0, clampf(1.0 - ds / 120.0, 0.0, 1.0))
	if not _judged and ds < 2.0:
		_judged = true
		_judge()
	if s_m < -25.0 or s_m > Route.length() + 25.0:
		active = false
		visible = false
		_gallop.stop()
		_fire.stop()
		finished.emit()


func _judge() -> void:
	var in_refuge := refuge_count > 0 or player.hidden
	print("[mula] julgamento: refugio=%s luz=%s" % [str(in_refuge), str(player.is_lantern_lit())])
	if in_refuge and not player.is_lantern_lit():
		get_tree().call_group("hud", "show_prompt", "Ela passou. O escuro te escondeu.", 3.0)
		if audio != null:
			audio.bump_fear(0.1)
	elif in_refuge:
		get_tree().call_group("hud", "show_prompt", "A luz te entregou.", 3.0)
		screams.penalize(1, "mula viu a luz")
		player.shake(0.1, 0.8)
	else:
		screams.external_kill("mula")
