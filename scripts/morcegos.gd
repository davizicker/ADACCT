class_name Morcegos
extends Node3D
## Morcegos: silhuetas que voam em círculos irregulares sobre o adro da igreja e os telhados mais altos (as asas batem).
## Cada morcego é uma malha de 2 asas + corpo; só aparecem quando o jogador está a menos de 120 m.

const QTD := 9
var _bichos: Array[Dictionary] = []
var _t := 0.0
var _player: Node3D


func _ready() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.03)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	var centro := Route.pos(Route.CHURCH_S - 6.0) + Vector3(0, 20.0, 0)
	for i in QTD:
		var n := Node3D.new()
		var corpo := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 0.07
		cm.height = 0.2
		cm.radial_segments = 6
		cm.rings = 3
		cm.material = m
		corpo.mesh = cm
		corpo.rotation.x = PI / 2.0
		n.add_child(corpo)
		var asas: Array[MeshInstance3D] = []
		for lado: float in [-1.0, 1.0]:
			var asa := MeshInstance3D.new()
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var pts := [Vector3(0, 0, -0.06), Vector3(lado * 0.42, 0.05, -0.12), Vector3(lado * 0.3, 0.0, 0.16), Vector3(lado * 0.12, 0.0, 0.1)]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for k in tri:
					st.set_normal(Vector3.UP)
					st.add_vertex(pts[k])
			asa.mesh = st.commit()
			asa.mesh.surface_set_material(0, m)
			n.add_child(asa)
			asas.append(asa)
		add_child(n)
		_bichos.append({"n": n, "asas": asas, "c": centro + Vector3(randf_range(-14, 14), randf_range(-3, 7), randf_range(-14, 14)),
			"r": randf_range(9.0, 22.0), "v": randf_range(0.5, 0.9) * (1.0 if i % 2 == 0 else -1.0), "f": randf() * TAU, "h": randf_range(0.6, 1.6)})


func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("jogador") as Node3D
	visible = _player != null and _player.global_position.distance_to(Route.pos(Route.CHURCH_S)) < 130.0
	if not visible:
		return
	for b in _bichos:
		var a: float = b["f"] + _t * float(b["v"])
		var c: Vector3 = b["c"]
		var pos := c + Vector3(cos(a) * float(b["r"]), sin(_t * float(b["h"]) + float(b["f"])) * 2.2, sin(a * 1.3) * float(b["r"]) * 0.8)
		var n := b["n"] as Node3D
		var antes := n.global_position
		n.global_position = pos
		var d := pos - antes
		if d.length() > 0.001:
			n.look_at(pos + d, Vector3.UP)
		var bat := sin(_t * 17.0 + float(b["f"])) * 0.7
		var asas: Array = b["asas"]
		(asas[0] as Node3D).rotation.z = bat
		(asas[1] as Node3D).rotation.z = -bat
