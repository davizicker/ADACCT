class_name World
extends Node3D
## Vila colonial fictícia: uma ladeira de pedra até a igreja, casario colado,
## lampiões âmbar e neblina. Tudo montado por código (sem assets) para o protótipo.

const STREET_LEN := 260.0
const STREET_W := 7.0
const SLOPE := deg_to_rad(7.0)
const WALL_X := 16.0

const PALETTE: Array[Color] = [
	Color(0.36, 0.30, 0.20), # ocre
	Color(0.40, 0.38, 0.33), # cal envelhecida
	Color(0.22, 0.28, 0.33), # azul desbotado
	Color(0.33, 0.18, 0.13), # terracota
]

var church_door: Area3D
var lamp_lights: Array[OmniLight3D] = []
var _rng := RandomNumberGenerator.new()


## Altura do chão na ladeira em função de z (sobe para z negativo).
static func ground_y(z: float) -> float:
	return -z * tan(SLOPE)


func build() -> void:
	_rng.seed = 1789
	_environment()
	_ground()
	_houses()
	_lamps()
	_church()


func _mat(color: Color, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, collide := true, rot_x := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = rot_x
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		mi.add_child(body)
	return mi


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10, 0.12, 0.18)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.14, 0.19)
	env.fog_density = 0.045
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _ground() -> void:
	var length := STREET_LEN + 40.0
	var slab_len := length / cos(SLOPE)
	var center_z := -(STREET_LEN - 10.0) / 2.0
	var stone := _mat(Color(0.16, 0.15, 0.14))
	_box(Vector3(2.0 * WALL_X, 1.0, slab_len), Vector3(0, ground_y(center_z) - 0.5, center_z), stone, true, SLOPE)
	# paredes invisíveis laterais e de fundo
	var invisible := StandardMaterial3D.new()
	invisible.albedo_color = Color(0, 0, 0, 0)
	invisible.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(1.0, 30.0, length), Vector3(sx * WALL_X, 10.0, center_z), invisible)
	_box(Vector3(2.0 * WALL_X, 30.0, 1.0), Vector3(0, 10.0, 3.5), invisible)


func _houses() -> void:
	var wall_mat_cache: Array[StandardMaterial3D] = []
	for c in PALETTE:
		wall_mat_cache.append(_mat(c))
	var roof_mat := _mat(Color(0.14, 0.08, 0.06))
	var window_mat := _mat(Color(1.0, 0.7, 0.3), true)
	var door_mat := _mat(Color(0.05, 0.03, 0.02))
	for side: float in [-1.0, 1.0]:
		var z := 4.0
		while z > -(STREET_LEN + 2.0):
			var w := _rng.randf_range(8.0, 14.0)
			var h := _rng.randf_range(6.0, 9.0)
			var depth := 10.0
			var cz := z - w / 2.0
			var gy := ground_y(cz)
			var x := side * (STREET_W / 2.0 + depth / 2.0)
			var wall: StandardMaterial3D = wall_mat_cache[_rng.randi() % wall_mat_cache.size()]
			# a base é enterrada (+4 m) para acompanhar o declive
			_box(Vector3(depth, h + 4.0, w), Vector3(x, gy + h / 2.0 - 2.0, cz), wall)
			# telhado de duas águas, cumeeira paralela à rua
			var roof := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(depth + 1.0, 2.6, w + 0.6)
			roof.mesh = prism
			roof.material_override = roof_mat
			roof.position = Vector3(x, gy + h + 1.3, cz)
			add_child(roof)
			# porta e janelas voltadas para a rua
			var face_x := side * (STREET_W / 2.0 + 0.02)
			var yaw := -side * PI / 2.0
			_quad(Vector2(1.4, 2.4), Vector3(face_x, gy + 1.2, cz), yaw, door_mat)
			for k in [-1, 1]:
				if _rng.randf() < 0.45:
					_quad(Vector2(0.9, 1.3), Vector3(face_x, gy + h * 0.65, cz + k * w * 0.28), yaw, window_mat)
				else:
					_quad(Vector2(0.9, 1.3), Vector3(face_x, gy + h * 0.65, cz + k * w * 0.28), yaw, door_mat)
			z -= w


func _quad(size: Vector2, pos: Vector3, yaw: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)


func _lamps() -> void:
	var pole_mat := _mat(Color(0.05, 0.05, 0.05))
	var glass_mat := _mat(Color(1.0, 0.75, 0.35), true)
	var i := 0
	var z := -6.0
	while z > -STREET_LEN:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (STREET_W / 2.0 - 0.5)
		var gy := ground_y(z)
		_box(Vector3(0.12, 3.4, 0.12), Vector3(x, gy + 1.7, z), pole_mat, false)
		_box(Vector3(0.35, 0.5, 0.35), Vector3(x, gy + 3.6, z), glass_mat, false)
		var light := OmniLight3D.new()
		light.position = Vector3(x, gy + 3.5, z)
		light.light_color = Color(1.0, 0.72, 0.35)
		light.light_energy = 1.7
		light.omni_range = 12.0
		add_child(light)
		lamp_lights.append(light)
		i += 1
		z -= 24.0


func _church() -> void:
	var stone := _mat(Color(0.42, 0.40, 0.36))
	var front_z := -(STREET_LEN + 2.0)
	var gy := ground_y(front_z)
	_box(Vector3(18.0, 16.0, 26.0), Vector3(0, gy + 4.0, front_z - 13.0), stone)
	_box(Vector3(6.0, 30.0, 6.0), Vector3(-6.0, gy + 11.0, front_z - 3.0), stone)
	_box(Vector3(6.0, 30.0, 6.0), Vector3(6.0, gy + 11.0, front_z - 3.0), stone)
	var door_glow := _mat(Color(1.0, 0.8, 0.45), true)
	_quad(Vector2(3.2, 4.6), Vector3(0, gy + 2.3, front_z + 0.03), 0.0, door_glow)
	var light := OmniLight3D.new()
	light.position = Vector3(0, gy + 3.0, front_z + 3.0)
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 3.5
	light.omni_range = 18.0
	add_child(light)
	church_door = Area3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.0, 4.0, 3.0)
	cs.shape = bs
	church_door.add_child(cs)
	church_door.position = Vector3(0, gy + 2.0, front_z + 2.0)
	church_door.monitoring = true
	add_child(church_door)
