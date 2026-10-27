class_name SaveGame
extends RefCounted
## Salvar/continuar. Um único arquivo em user://save.cfg (apague para recomeçar do zero).
## Salva sozinho ao pegar item, entrar/sair de casa e a cada minuto na rua.

const PATH := "user://save.cfg"

## Quando true, a próxima cena principal carrega o save ao iniciar (usado por "Continuar" e ao morrer).
static var carregar_ao_iniciar := false


static func existe() -> bool:
	return FileAccess.file_exists(PATH)


static func apagar() -> void:
	if existe():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func gravar(d: Dictionary) -> void:
	var cf := ConfigFile.new()
	for k: String in d:
		cf.set_value("jogo", k, d[k])
	cf.save(PATH)


static func ler() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return {}
	var d := {}
	for k in cf.get_section_keys("jogo"):
		d[k] = cf.get_value("jogo", k)
	return d
