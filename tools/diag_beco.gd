extends SceneTree
## Lista o que há no corredor de um beco: godot --headless --script res://tools/diag_beco.gd -- Beco_02
func _init() -> void:
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	for i in 4:
		await physics_frame
	var nome := "Beco_02"
	var b := v.find_child(nome, true, false) as Node3D
	var space := v.get_world_3d().direct_space_state
	var xf := b.global_transform
	print("comprimento=", b.get_meta("comprimento", -1), " subida=", b.get_meta("subida", -1), " cego=", b.has_meta("cego"))
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.7
	for xm in [1.0, 2.0, 3.0, 3.6, 4.2, 4.8, 5.4, 6.0, 6.6]:
		var p: Vector3 = xf * Vector3(xm, 0.0, 0.0)
		var rise: float = xm / 0.45 * 0.19
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), p + Vector3(0, rise + 1.0, 0))
		var hits := space.intersect_shape(q, 8)
		var nn: Array = []
		for h in hits:
			nn.append(str((h["collider"] as Node).get_path()).replace("/root/", ""))
		print("x=", xm, " ", nn)
	quit()
