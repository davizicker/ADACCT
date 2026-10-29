extends SceneTree
## Procura qualquer coisa (pedra, planta, caixote, lampião...) na frente de cada porta de casa: godot --headless --script res://tools/auditoria_portas.gd
func _init() -> void:
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	for i in 4:
		await physics_frame
	var space := v.get_world_3d().direct_space_state
	var total := 0
	var bloqueadas := 0
	for casa in v.find_children("Casa*", "Node3D", true, false):
		if not casa.has_meta("door_z"):
			continue
		total += 1
		var dz: float = casa.get_meta("door_z")
		var xf: Transform3D = (casa as Node3D).global_transform
		var piso: Vector3 = xf * Vector3(-0.1, 0.0, dz)
		var cen: Vector3 = xf * Vector3(-0.95, 1.3, dz)
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.4, 2.0, 1.8)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(xf.basis, cen)
		q.collide_with_areas = false
		var hits := space.intersect_shape(q, 16)
		var nomes: Array = []
		for h in hits:
			var c := h["collider"] as Node
			var cn: String = str(c.get_path()).replace("/root/", "")
			if cn.contains("Corpo") and cn.contains(casa.name):
				continue
			nomes.append(cn)
		if not nomes.is_empty():
			bloqueadas += 1
			print("[portas] ", casa.name, " @", snapped(piso, Vector3(0.1, 0.1, 0.1)), " bloqueada por: ", nomes)
	print("[portas] casas=", total, " com algo na frente da porta=", bloqueadas)
	quit()
