class_name Porta
extends Area3D
## Porta interativa (tecla E). `destino` = id do interior para entrar; vazio = sair do interior para a rua.
## `requer` = item do inventário necessário (ex.: "chave_casarao"); sem ele a porta está trancada.

@export var destino := ""
@export var texto_interacao := "Entrar"
@export var requer := ""
@export var texto_trancada := "Está trancada."


func _ready() -> void:
	add_to_group("interagivel")
	monitoring = false


func interagir(player: Player) -> void:
	get_tree().call_group("missao", "usar_porta", self, player)


var _aberta: Node3D = null


## Abre a porta da casa (só visual, antes de entrar): as duas folhas giram nas dobradiças para fora e dentro aparece a luz quente da sala.
func abrir_visual() -> void:
	var casa := get_parent() as Node3D
	if casa == null or _aberta != null:
		return
	var mesh := casa.get_node_or_null("Porta") as MeshInstance3D
	if mesh == null:
		return
	# material da madeira da porta: o primeiro da malha que não seja a cantaria da moldura
	var mat_folha: Material = null
	if mesh.mesh != null:
		for i in mesh.mesh.get_surface_count():
			var m := mesh.mesh.surface_get_material(i)
			if m != null and not m.resource_name.contains("cantaria") and mat_folha == null:
				mat_folha = m
	mesh.visible = false
	var real := bool(get_meta("real", false))          # casa da rua: a sala está atrás da porta (sem fundo falso nem teleporte)
	_aberta = Node3D.new()
	_aberta.name = "PortaAberta"
	casa.add_child(_aberta)
	var dz := position.z
	if not real:
		var vao := MeshInstance3D.new()                      # o vão: parede de luz quente ao fundo
		var q := QuadMesh.new()
		q.size = Vector2(2.0, 2.9)
		vao.mesh = q
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = Color(0.42, 0.24, 0.10)
		vao.material_override = mt
		vao.position = Vector3(0.12, 1.45, dz)
		vao.rotation.y = -PI / 2.0
		_aberta.add_child(vao)
	for sgn: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(-0.16, 0.0, dz + sgn * 1.0)
		_aberta.add_child(pivot)
		var folha := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 2.9, 1.0)
		folha.mesh = bm
		folha.position = Vector3(0.0, 1.45, -sgn * 0.5)
		if mat_folha != null:
			folha.material_override = mat_folha
		pivot.add_child(folha)
		var tw := create_tween()
		tw.tween_property(pivot, "rotation:y", sgn * PI * 0.46, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if real:
		# tira o bloqueio do vão (colisão) e deixa a porta aberta de vez: a rua e a sala passam a ser o mesmo lugar
		var bl := casa.find_child("BloqueioPorta", true, false)
		if bl != null:
			for ch in bl.get_children():
				if ch is CollisionShape3D:
					(ch as CollisionShape3D).set_deferred("disabled", true)
		remove_from_group("interagivel")
		return
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.7, 0.36)
	luz.light_energy = 1.6
	luz.omni_range = 5.5
	luz.position = Vector3(-0.8, 1.5, dz)
	_aberta.add_child(luz)


## Fecha de novo (ao voltar para a rua): a porta inteira volta a aparecer.
func fechar_visual() -> void:
	if _aberta != null:
		_aberta.queue_free()
		_aberta = null
	var casa := get_parent() as Node3D
	if casa != null:
		var mesh := casa.get_node_or_null("Porta") as Node3D
		if mesh != null:
			mesh.visible = true
