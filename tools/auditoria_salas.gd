extends SceneTree
## Monta todas as salas (sem a vila) e escreve docs/26-auditoria-salas.md e docs/23-medidas-dos-moveis.md:
## godot --headless --path . --script res://tools/auditoria_salas.gd
func _init() -> void:
	var vb := VilaBuilder.new()
	vb._setup({})
	var it := Interiores.new()
	var salas := it.construir(vb, true)
	print("[auditoria] salas montadas: ", salas.get_child_count())
	quit()
