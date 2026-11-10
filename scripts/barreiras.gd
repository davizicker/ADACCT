extends Node3D
## Barreiras contra o vazio: ao carregar a vila, percorre as duas beiras da rua de metro em metro e, onde NÃO há
## parede/casa/muro e o chão ao lado despenca (barranco, quintal aberto, beira de curva), levanta uma mureta de pedra
## com colisão alta (o jogador não cai nem pula por cima). Bocas de beco (rampa/degraus) não são fechadas: o chão ali não despenca.

const PASSO := 1.0
const QUEDA_MAX := 1.1        # desnível a partir do qual a beira é perigosa
var feitas := 0

func _ready() -> void:
	name = "Barreiras"
	for i in 3:
		await get_tree().physics_frame
	_montar()


func _montar() -> void:
	var sp := get_world_3d().direct_space_state
	var mat := load("res://assets/materials/muro.tres") as Material
	for sigma: float in [-1.0, 1.0]:
		var ini := -1.0
		var s := 0.5
		while s <= Route.length() + PASSO:
			var perigo := s <= Route.S_END + 4.0 and _perigo(sp, s, sigma)     # o adro tem as próprias muretas
			if perigo and ini < 0.0:
				ini = s
			elif not perigo and ini >= 0.0:
				_mureta(ini - 0.5, s - 0.5, sigma, mat)
				ini = -1.0
			s += PASSO
		if ini >= 0.0:
			_mureta(ini - 0.5, minf(s, Route.S_END + 4.0), sigma, mat)
	print("[barreiras] muretas contra o vazio: %d" % feitas)


func _beira(s: float) -> float:
	return Route.width(s) * 0.5 + PlanoVila.CALCADA


func _perigo(sp: PhysicsDirectSpaceState3D, s: float, sigma: float) -> bool:
	var c := Route.pos(s)
	var r := Route.right(s) * sigma
	var h := c.y
	# já existe algo sólido na beira (casa, muro, parede de beco)?
	var a := c + r * (Route.width(s) * 0.5 - 0.3) + Vector3(0, 1.0, 0)
	var b := c + r * (_beira(s) + 1.6) + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(a, b)
	if not sp.intersect_ray(q).is_empty():
		return false
	# o chão logo depois da beira despenca?
	for off: float in [0.6, 1.4]:
		var p := c + r * (_beira(s) + off)
		var qd := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p - Vector3(0, 12.0, 0))
		var hit := sp.intersect_ray(qd)
		if hit.is_empty():
			return true
		var nome := String((hit.collider as Node).name)
		if nome == "Rampa" or String((hit.collider as Node).get_parent().name).begins_with("Beco"):
			return false
		if h - (hit.position as Vector3).y > QUEDA_MAX:
			return true
	return false


func _mureta(s0: float, s1: float, sigma: float, mat: Material) -> void:
	# segmentos curtos seguindo a beira (acompanha curva e subida)
	var s := s0
	while s < s1 - 0.01:
		var e := minf(s + 2.0, s1)
		var pa := Route.pos(s) + Route.right(s) * sigma * (_beira(s) + 0.2)
		var pb := Route.pos(e) + Route.right(e) * sigma * (_beira(e) + 0.2)
		var mid := (pa + pb) * 0.5
		var d := pb - pa
		var comp := Vector2(d.x, d.z).length() + 0.12
		var yaw := atan2(d.x, d.z)
		var body := StaticBody3D.new()
		body.name = "Mureta"
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.4, 3.2, comp)
		cs.shape = bs
		cs.position.y = 1.0
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 1.6, comp)
		bm.material = mat
		mi.mesh = bm
		mi.position.y = -0.3            # 0,5 m de pedra acima da calçada, o resto enterrado (cobre o desnível)
		body.add_child(mi)
		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.5, 0.08, comp + 0.04)
		cm.material = mat
		cap.mesh = cm
		cap.position.y = 0.54
		body.add_child(cap)
		add_child(body)
		body.global_position = mid + Vector3(0, 0.22, 0)
		body.rotation.y = yaw
		feitas += 1
		s = e
