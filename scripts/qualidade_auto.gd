extends Node
## QUALIDADE AUTOMÁTICA: mede o FPS de verdade durante o jogo e, se a placa não aguenta, alivia passo a passo
## (primeiro a resolução interna com FSR 2, que quase não muda a nitidez; depois os efeitos mais pesados), até o jogo ficar fluido.
## O passo escolhido fica salvo: na próxima vez o jogo já começa nele. Só age no Forward+ e só durante o jogo (não em menu/teste).
## Passos: 0 tudo no máximo | 1 resolução 85% FSR2 | 2 resolução 77% | 3 sem bancos de névoa e névoa volumétrica 64
##         | 4 preset Alto (sem GI de 4 cascatas, sombras 4K) | 5 resolução 67% | 6 preset Médio
const ALVO := 50.0              # FPS mínimo desejado (média de 4 s)
const MAX_PASSO := 6
var main: Node
var _amostras: Array[float] = []
var _espera := 6.0              # depois de cada ajuste: shaders compilando, ignora o começo


func iniciar(m: Node) -> void:
	main = m
	if Config.qualidade_passo > 0:
		_aplicar(Config.qualidade_passo, false)


func _process(delta: float) -> void:
	if main == null or not Config.qualidade_auto or Config.qualidade_passo >= MAX_PASSO:
		return
	if get_tree().paused or (main.get("menu") != null and (main.get("menu") as Node).visible) or main.get("finished") == true:
		_amostras.clear()
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_amostras.append(Engine.get_frames_per_second())
	if _amostras.size() < 240:            # ~4 s de quadros
		return
	var soma := 0.0
	for f in _amostras:
		soma += f
	var media := soma / float(_amostras.size())
	_amostras.clear()
	if media < ALVO:
		_aplicar(Config.qualidade_passo + 1, true)
		print("[qualidade] FPS médio %.0f < %.0f: passo %d" % [media, ALVO, Config.qualidade_passo])


func _aplicar(passo: int, avisar: bool) -> void:
	Config.qualidade_passo = clampi(passo, 0, MAX_PASSO)
	var p := Config.qualidade_passo
	Config.escala_3d = [1.0, 0.85, 0.77, 0.77, 0.77, 0.67, 0.67][p]
	if p >= 6:
		Config.quality = mini(Config.quality, 1)
	elif p >= 4:
		Config.quality = mini(Config.quality, 2)
	Config.apply(main)
	if p >= 3:
		var bn := main.get_node_or_null("Vila/BancosDeNevoa")
		if bn:
			bn.queue_free()
		RenderingServer.environment_set_volumetric_fog_volume_size(64, 64)
	Config.save_all()
	_espera = 6.0
	if avisar:
		var hud := main.get_node_or_null("Interface")
		if hud and hud.has_method("show_prompt"):
			hud.call("show_prompt", "Qualidade ajustada para o jogo ficar fluido (nível %d de %d). Dá para mudar nas Opções." % [p, MAX_PASSO], 4.0)
