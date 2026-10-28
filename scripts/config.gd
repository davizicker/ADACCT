class_name Config
extends RefCounted
## Opções do jogador, salvas em user://bradador.cfg (some se você apagar o arquivo).

const PATH := "user://bradador.cfg"

static var master := 0.9        # 0..1
static var music := 0.7
static var effects := 1.0
static var mouse_sens := 0.0025
static var mic_threshold := 0.07
static var quality := 1         # 0 baixa, 1 média (recomendada), 2 alta (liga GI, reflexos e TAA: placa forte)
static var escala_3d := 1.0     # resolução de renderização (0.5 a 1.0); abaixo de 1 usa FSR 2 no Forward+ (mais FPS)
static var grito_ativo := false # opção antiga: responder gritando (microfone ou R). Padrão: ficar parado e agachado
static var camera_fx := true    # vinheta, granulado, aberração
static var head_bob := true
static var chuva := false
static var modo_teste := false   # MODO DE TESTE: imortal (Bradador e Mula não te matam; o jogo só avisa). Normal = padrão
static var loaded := false


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	master = cf.get_value("audio", "master", master)
	music = cf.get_value("audio", "music", music)
	effects = cf.get_value("audio", "effects", effects)
	mouse_sens = cf.get_value("controles", "mouse_sens", mouse_sens)
	mic_threshold = cf.get_value("controles", "mic_threshold", mic_threshold)
	quality = cf.get_value("video", "quality", quality)
	escala_3d = cf.get_value("video", "escala_3d", escala_3d)
	camera_fx = cf.get_value("video", "camera_fx", camera_fx)
	head_bob = cf.get_value("video", "head_bob", head_bob)
	grito_ativo = cf.get_value("controles", "grito_ativo", grito_ativo)
	chuva = cf.get_value("video", "chuva", chuva)
	modo_teste = cf.get_value("jogo", "modo_teste", modo_teste)


static func save_all() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master", master)
	cf.set_value("audio", "music", music)
	cf.set_value("audio", "effects", effects)
	cf.set_value("controles", "mouse_sens", mouse_sens)
	cf.set_value("controles", "mic_threshold", mic_threshold)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "escala_3d", escala_3d)
	cf.set_value("video", "camera_fx", camera_fx)
	cf.set_value("video", "head_bob", head_bob)
	cf.set_value("controles", "grito_ativo", grito_ativo)
	cf.set_value("video", "chuva", chuva)
	cf.set_value("jogo", "modo_teste", modo_teste)
	cf.save(PATH)


## Aplica as opções de vídeo/áudio à cena do jogo. `main` = nó raiz (scenes/main.tscn).
static func apply(main: Node) -> void:
	var vp := main.get_viewport()
	var forward := RenderingServer.get_rendering_device() != null and str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "forward_plus"
	var scale: float = clampf(escala_3d * [0.8, 1.0, 1.0][quality], 0.4, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if (forward and scale < 0.99) else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale
	if forward:       # no Forward+ o serrilhado sai por FXAA (Média) ou TAA (Alta, em _apply_high_end): bem mais barato que MSAA
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	else:
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	var vila := main.get_node_or_null("Vila")
	if vila:
		var lua := vila.get_node_or_null("Lua") as DirectionalLight3D
		if lua:
			lua.shadow_enabled = quality >= 1
		var amb := vila.get_node_or_null("Ambiente") as WorldEnvironment
		if amb and amb.environment:
			amb.environment.glow_enabled = quality >= 1
		var mata := vila.get_node_or_null("Morros/Mata")
		if mata:
			mata.visible = quality >= 1
		var matos := vila.get_node_or_null("Detalhes/PlantasReais")      # matos, tufos e ervas reais: só da Média para cima
		if matos:
			matos.visible = quality >= 1
	_apply_high_end(main)
	var jog := main.get_node_or_null("Jogador")
	if jog:
		var lamp := jog.get_node_or_null("Camera/Lampiao") as OmniLight3D
		if lamp:
			lamp.shadow_enabled = quality >= 2
	_bus_volume("Master", master)
	_bus_volume("Musica", music)
	_bus_volume("Efeitos", effects)


static func _bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


## Efeitos que só existem no renderizador Forward+ (placa de vídeo com Vulkan). No modo Compatibilidade
## (o padrão do projeto) esta função não faz nada. NÃO foi testada em Forward+ no ambiente de desenvolvimento.
static func _apply_high_end(main: Node) -> void:
	# Compatibilidade não tem "RenderingDevice"; Forward+ e Mobile têm. Só o Forward+ suporta esses efeitos.
	if RenderingServer.get_rendering_device() == null or str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) != "forward_plus":
		return
	var amb := main.get_node_or_null("Vila/Ambiente") as WorldEnvironment
	if amb == null or amb.environment == null:
		return
	var e := amb.environment
	var hi := quality >= 2
	e.ssao_enabled = quality >= 1
	e.ssil_enabled = hi
	e.ssr_enabled = hi            # reflexos na pedra molhada e na água
	e.sdfgi_enabled = hi          # iluminação global (luz que "quica" nas paredes)
	e.volumetric_fog_enabled = quality >= 1   # raios de luz na neblina (resolução reduzida em project.godot)
	e.volumetric_fog_density = 0.02
	e.volumetric_fog_albedo = Color(0.55, 0.62, 0.8)
	if hi:
		e.sdfgi_cascades = 3
		e.sdfgi_min_cell_size = 0.5
		e.sdfgi_use_occlusion = true
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if quality == 1 else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
	main.get_viewport().use_taa = hi
