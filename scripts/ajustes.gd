@tool
class_name Ajustes
extends Node3D
## CAMADA MANUAL: tudo que você colocar dentro de "Ajustes" (cena scenes/ajustes.tscn) é seu e NUNCA é apagado quando o
## mundo é regerado (tools/bake.gd só reescreve scenes/vila.scn, jogador, bradador, mula...).
## Como usar no editor do Godot:
##   1) abra scenes/ajustes.tscn;  2) arraste modelos .glb do FileSystem (assets/models/...) para a cena;
##   3) mova/gire/escale com W/E/R e salve (Ctrl+S). Rode o jogo (F5) para ver no lugar.
## ZonaLimpa: nó-caixa que REMOVE objetos soltos (barris, plantas, lampiões... instâncias individuais) gerados dentro dela.
## Não remove o que foi fundido em malhas únicas (paredes, telhados, calçamento): isso se altera em tools/*.gd.

const GRUPOS_LIMPAVEIS := ["Adornos", "Props", "PropsEncosta", "Coletaveis", "Becos", "MurosEQuintais", "Casas"]


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_aplicar_zonas")


func _aplicar_zonas() -> void:
	var vila := get_tree().root.get_node_or_null("Main/Vila")
	if vila == null:
		return
	var zonas: Array[ZonaLimpa] = []
	for c in find_children("*", "ZonaLimpa", true, false):
		zonas.append(c as ZonaLimpa)
	if zonas.is_empty():
		return
	var removidos := 0
	for g in GRUPOS_LIMPAVEIS:
		var raiz := vila.get_node_or_null(g)
		if raiz == null:
			continue
		for n in raiz.find_children("*", "Node3D", true, false):
			# só instâncias individuais (modelos .glb, plantas, barris): nós com malha própria ou instâncias de cena
			if not (n is MeshInstance3D or n.scene_file_path != "" or n.has_node("Modelo")):
				continue
			for z in zonas:
				if z.contem((n as Node3D).global_position):
					n.queue_free()
					removidos += 1
					break
	print("[ajustes] %d objetos removidos por ZonaLimpa" % removidos)
