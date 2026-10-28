class_name Bracos
extends Node3D
## Braços em primeira pessoa (FPS ARMS RIG 1): a mão direita segura a lanterna e a esquerda fica relaxada, entrando pelo canto da tela.
## Em vez de animações, resolve a posição dos dois braços por "IK de dois ossos" analítico, todo quadro:
## a mão direita acompanha o modelo da lanterna (que balança com a caminhada) e o cotovelo cai para baixo.
## Ajuste fino no Inspetor: Pele (tom), Escala, Offset da mão, Mão esquerda.

const MODELO := "res://assets/models/arms/fps_arms.glb"

@export var pele := Color(1, 1, 1)                 ## multiplica a textura (ex.: Color(0.78, 0.6, 0.5) para pele mais escura)
@export var escala := 1.0
@export var empunhadura := Vector3(0.0, 0.12, 0.0)     ## onde a mão pega, no espaço do nó da lanterna
@export var mao_esquerda := Vector3(-0.30, -0.60, -0.50)  ## posição da mão esquerda (no espaço da câmera)
@export var curvatura_dedos := 1.1                 ## radianos de dobra dos dedos da direita (empunhadura)

var lanterna: Node3D = null
var _sk: Skeleton3D = null
var _t := 0.0
var _ossos := {}          # nome -> índice
var _rest := {}           # índice -> Transform3D (repouso global, no espaço do esqueleto)


func _ready() -> void:
	if not ResourceLoader.exists(MODELO):
		return
	var inst := (load(MODELO) as PackedScene).instantiate() as Node3D
	add_child(inst)
	inst.scale = Vector3.ONE * escala
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	_sk = sks[0] as Skeleton3D
	for i in _sk.get_bone_count():
		_ossos[_sk.get_bone_name(i)] = i
		_rest[i] = _sk.get_bone_global_rest(i)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = 2.0
		for si in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(si)
			if mat is StandardMaterial3D:
				var d := mat.duplicate() as StandardMaterial3D
				d.albedo_color = pele
				d.roughness = 0.75
				m.set_surface_override_material(si, d)


func _osso(prefixo: String, lado: String) -> int:
	for n in _ossos.keys():
		var nm: String = n
		if nm.begins_with(prefixo) and nm.ends_with("." + lado):
			return _ossos[n]
	return -1


func _process(delta: float) -> void:
	if _sk == null:
		return
	_t += delta
	var cam_para_sk := _sk.global_transform.affine_inverse() * get_parent().global_transform
	# mão direita: segue a lanterna
	var alvo_d := Vector3(0.31, -0.28, -0.62)
	if lanterna != null:
		alvo_d = lanterna.position + lanterna.transform.basis * empunhadura
	_ik("R", cam_para_sk * alvo_d, Vector3(0.4, -1.0, 0.2))
	# mão esquerda: relaxada, balançando de leve
	var alvo_e := mao_esquerda + Vector3(sin(_t * 1.3) * 0.006, cos(_t * 1.7) * 0.005, 0.0)
	_ik("L", cam_para_sk * alvo_e, Vector3(-0.4, -1.0, 0.2))
	_dedos("R", curvatura_dedos)
	_dedos("L", 0.35)


## IK analítico de 2 ossos para o braço `lado` ("R"/"L"); `alvo` no espaço do esqueleto, `polo` = direção para onde o cotovelo aponta.
func _ik(lado: String, alvo: Vector3, polo: Vector3) -> void:
	var i_ombro := _osso("upper_arm", lado)
	var i_cot := _osso("forearm", lado)
	var i_mao := _osso("hand", lado)
	if i_ombro < 0 or i_cot < 0 or i_mao < 0:
		return
	# hand.R.control também começa com "hand": prefere o osso exato
	var ih: int = _ossos.get("hand." + lado, i_mao)
	var s: Vector3 = _rest[i_ombro].origin
	var e0: Vector3 = _rest[i_cot].origin
	var w0: Vector3 = _rest[ih].origin
	var l1 := s.distance_to(e0)
	var l2 := e0.distance_to(w0)
	var dv := alvo - s
	var d := clampf(dv.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
	var dir := dv.normalized()
	# ângulo no ombro (lei dos cossenos)
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var a := acos(cos_a)
	var lado_vec := dir.cross(polo.normalized())
	if lado_vec.length() < 0.001:
		lado_vec = Vector3.RIGHT
	var perp := lado_vec.cross(dir).normalized()          # perpendicular a dir, no lado do polo
	var cot := s + (dir * cos(a) + perp * sin(a)) * l1
	var maoP := s + dir * d
	_aponta(i_ombro, s, cot, e0)
	_aponta(i_cot, cot, maoP, w0)
	# mão: mantém a orientação de repouso girada junto com o antebraço
	var rot_ant: Basis = _sk.get_bone_global_pose_override(i_cot).basis if false else Basis()
	var b_rest: Basis = _rest[ih].basis
	var ant := (maoP - cot).normalized()
	var ant0 := (w0 - e0).normalized()
	var q := Quaternion(ant0, ant)
	_sk.set_bone_global_pose_override(ih, Transform3D(Basis(q) * b_rest, maoP), 1.0, true)


func _aponta(i: int, de: Vector3, para: Vector3, filho_rest: Vector3) -> void:
	var r: Transform3D = _rest[i]
	var d0 := (filho_rest - r.origin).normalized()
	var d1 := (para - de).normalized()
	var q := Quaternion(d0, d1)
	_sk.set_bone_global_pose_override(i, Transform3D(Basis(q) * r.basis, de), 1.0, true)


func _dedos(lado: String, ang: float) -> void:
	for n in _ossos.keys():
		var nm: String = n
		if not nm.ends_with("." + lado):
			continue
		if nm.begins_with("f_") or nm.begins_with("thumb"):
			var i: int = _ossos[n]
			var q := Quaternion(Vector3.RIGHT, ang * (0.6 if nm.begins_with("thumb") else 1.0))
			_sk.set_bone_pose_rotation(i, q)
