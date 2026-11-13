extends SceneTree
## Foto do menu de opções (conferir se tudo cabe na tela). Uso: --script res://tools/foto_menu.gd
func _initialize() -> void:
	var m := Menu.new()
	root.add_child(m)
	for i in 4: await process_frame
	m.call("_show_options")
	for i in 6: await process_frame
	root.get_texture().get_image().save_png("user://menu_opcoes.png")
	print("[menu] foto salva")
	quit()
