extends SceneTree
## Lista lampiões/postes/luzes da rua que estão perto demais um do outro: godot --headless --script res://tools/auditoria_luzes.gd
const MIN_LAMP := 6.0      # lampiões/postes visíveis: nunca mais perto que isso
const MIN_LUZ := 3.0       # luzes (OmniLight) da rua
func _init() -> void:
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	for i in 3:
		await physics_frame
	var lamps: Array = []
	var luzes: Array = []
	for n in v.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		var p := (n as Node3D).global_position
		if p.x > 1500.0:
			continue                     # interiores ficam longe da rua
		if nm.begins_with("Lampiao") or nm.begins_with("Poste"):
			lamps.append([nm, p])
		elif n is OmniLight3D or n is SpotLight3D:
			luzes.append([nm, p, String(n.get_parent().name)])
	var ruins := 0
	for i in lamps.size():
		for j in range(i + 1, lamps.size()):
			var d: float = (lamps[i][1] as Vector3).distance_to(lamps[j][1])
			if d < MIN_LAMP:
				ruins += 1
				print("[luzes] lampiões perto: %s x %s a %.1f m @%s" % [lamps[i][0], lamps[j][0], d, snapped(lamps[i][1], Vector3(0.1, 0.1, 0.1))])
	var perto_luz := 0
	for i in luzes.size():
		for j in range(i + 1, luzes.size()):
			var d2: float = (luzes[i][1] as Vector3).distance_to(luzes[j][1])
			if d2 < MIN_LUZ:
				perto_luz += 1
				print("[luzes] luzes perto: %s/%s x %s/%s a %.1f m @%s" % [luzes[i][2], luzes[i][0], luzes[j][2], luzes[j][0], d2, snapped(luzes[i][1], Vector3(0.1, 0.1, 0.1))])
	print("[luzes] lampiões/postes=%d perto demais=%d | luzes=%d pares a menos de %.0f m=%d" % [lamps.size(), ruins, luzes.size(), MIN_LUZ, perto_luz])
	quit()
