extends SceneTree
## Itens com colisão que se atravessam (barril dentro de caixote, balde dentro de banco...): godot --headless --script res://tools/auditoria_itens.gd
func _init() -> void:
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	for i in 4:
		await physics_frame
	var space := v.get_world_3d().direct_space_state
	var corpos: Array = v.find_children("*", "StaticBody3D", true, false).filter(func(n): return not str(n.get_path()).contains("/Rua/") and not str(n.get_path()).contains("Terreno"))
	var pares := {}
	for sb in corpos:
		for cs in (sb as Node).find_children("*", "CollisionShape3D", false, false):
			var c := cs as CollisionShape3D
			if c.shape == null or c.disabled:
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = c.shape
			var xf := c.global_transform
			xf.basis = xf.basis.orthonormalized() if not (c.shape is BoxShape3D) else xf.basis
			q.transform = Transform3D(c.global_transform.basis.orthonormalized(), c.global_transform.origin)
			q.margin = -0.06                           # só conta interpenetração real
			for h in space.intersect_shape(q, 12):
				var o := h["collider"] as Node
				if o == sb:
					continue
				var pa := str(sb.get_path()).replace("/root/Vila/", "")
				var pb := str(o.get_path()).replace("/root/Vila/", "")
				if pb.contains("Trecho_") or pb.contains("Terreno"):
					continue
				var prop_a := pa.begins_with("Adornos/") or pa.begins_with("Props/") or pa.begins_with("Iluminacao/") or pa.begins_with("Realismo/")
				var prop_b := pb.begins_with("Adornos/") or pb.begins_with("Props/") or pb.begins_with("Iluminacao/") or pb.begins_with("Realismo/")
				if (pb.contains("Corpo") or pa.contains("Corpo")) and not (prop_a or prop_b):
					continue
				var k := pa + "  x  " + pb if pa < pb else pb + "  x  " + pa
				if not pares.has(k):
					pares[k] = snapped(c.global_position, Vector3(0.1, 0.1, 0.1))
	for k in pares:
		print("[itens] ", k, " @", pares[k])
	print("[itens] corpos=", corpos.size(), " pares que se atravessam=", pares.size())
	quit()
