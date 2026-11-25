extends SceneTree
## Confere a vila pronta contra a PLANTA MESTRA (scripts/planta_mestra.gd) e escreve docs/planta/planta_mestra.json.
## Uso: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/planta_mestra.gd   (depois: python3 tools/planta_jogo.py)
func _init() -> void:
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	await process_frame
	var pm := PlantaMestra.new()
	var rel := pm.fiscalizar(v, "--corrigir" in OS.get_cmdline_user_args())
	print("[planta-mestra] ", rel)
	var por_regra := {}
	for vi in pm.violacoes:
		for r in vi["regras"]:
			var k := String(r).get_slice(" (", 0).get_slice(" %", 0)
			k = k.rstrip("0123456789.,x ")
			por_regra[k] = int(por_regra.get(k, 0)) + 1
		print("[planta-mestra] VIOLA %s (%s, s=%.0f): %s" % [vi["obj"], vi["tipo"], vi["s"], " | ".join(vi["regras"])])
	for c in pm.correcoes:
		print("[planta-mestra] ", c)
	var f := FileAccess.open("res://docs/planta/planta_mestra.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(pm.exportar(), "  "))
	f.close()
	quit()
