class_name Config
extends RefCounted
## Opções do jogador, salvas em user://bradador.cfg (some se você apagar o arquivo).

const PATH := "user://bradador.cfg"

static var master := 0.9        # 0..1
static var music := 0.7
static var effects := 1.0
static var mouse_sens := 0.0025
static var mic_threshold := 0.07
static var quality := 3         # 0 baixa, 1 média, 2 alta (GI, reflexos, TAA), 3 cinematográfico (tudo no máximo: visual estilo The Last of Us; placa tipo RTX 2060 ou melhor)
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
	if int(cf.get_value("video", "preset_versao", 0)) < 2:
		quality = 3        # configurações salvas por versões antigas passam para o novo padrão cinematográfico (dá para voltar nas Opções)
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
	cf.set_value("video", "preset_versao", 2)
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
	var scale: float = clampf(escala_3d * [0.8, 1.0, 1.0, 1.0][clampi(quality, 0, 3)], 0.4, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if (forward and scale < 0.99) else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale
	if forward:       # no Forward+ o serrilhado sai por FXAA (Média) ou TAA (Alta, em _apply_high_end): bem mais barato que MSAA
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == 1 else Viewport.SCREEN_SPACE_AA_DISABLED   # 2 e 3: TAA em _apply_high_end
	else:
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][clampi(quality, 0, 3)]
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
	var cine := quality >= 3
	e.ssao_enabled = quality >= 1
	e.ssil_enabled = hi
	e.ssr_enabled = hi            # reflexos na pedra molhada e na água
	e.sdfgi_enabled = hi          # iluminação global (luz que "quica" nas paredes)
	e.volumetric_fog_enabled = quality >= 1   # raios de luz na neblina (resolução reduzida em project.godot)
	e.volumetric_fog_density = 0.035 if cine else 0.02
	e.volumetric_fog_albedo = Color(0.55, 0.62, 0.8)
	e.volumetric_fog_gi_inject = 1.0 if cine else 0.0
	if hi:
		e.sdfgi_cascades = 3
		e.sdfgi_min_cell_size = 0.4 if cine else 0.5
		e.sdfgi_use_occlusion = true
		e.sdfgi_bounce_feedback = 0.6
		e.sdfgi_energy = 1.4 if cine else 1.0
	if cine:
		# aparência cinematográfica: sombras e reflexos de alta qualidade, indireta mais forte, contraste de filme
		e.ssao_radius = 1.6
		e.ssao_intensity = 2.6
		e.ssao_power = 1.8
		e.ssil_radius = 6.0
		e.ssil_intensity = 1.2
		e.ssr_max_steps = 128
		e.ssr_fade_in = 0.1
		e.ssr_fade_out = 1.5
		e.glow_intensity = 0.9
		e.glow_hdr_threshold = 0.9
		e.adjustment_enabled = true
		e.adjustment_contrast = 1.14
		e.adjustment_saturation = 0.86
		RenderingServer.directional_shadow_atlas_set_size(4096, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
		RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
		var jog := main.get_node_or_null("Jogador/Camera") as Camera3D
		if jog != null:
			var ca := CameraAttributesPractical.new()
			ca.dof_blur_far_enabled = true           # fundo levemente desfocado, como a câmera do jogo
			ca.dof_blur_far_distance = 35.0
			ca.dof_blur_far_transition = 60.0
			ca.dof_blur_amount = 0.04
			jog.attributes = ca
	# neblina baixa em frente à igreja (só existe no Forward+ com névoa volumétrica; no OpenGL daria erro de shader)
	var adro := main.get_node_or_null("Vila/Adro")
	if adro != null:
		var antiga := adro.get_node_or_null("NeblinaDoAdro")
		if cine and antiga == null:
			var nev := FogVolume.new()
			nev.name = "NeblinaDoAdro"
			nev.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
			nev.size = Vector3(34.0, 4.0, 34.0)
			var nmat := FogMaterial.new()
			nmat.density = 0.14
			nmat.albedo = Color(0.62, 0.68, 0.84)
			nmat.edge_fade = 0.35
			nev.material = nmat
			nev.position = Route.pos(Route.CHURCH_S) - Route.tangent(Route.CHURCH_S) * 14.0 + Vector3(0, 2.2, 0)
			adro.add_child(nev)
		elif not cine and antiga != null:
			antiga.queue_free()
	RenderingServer.environment_set_ssao_quality([RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, RenderingServer.ENV_SSAO_QUALITY_LOW, RenderingServer.ENV_SSAO_QUALITY_MEDIUM, RenderingServer.ENV_SSAO_QUALITY_HIGH][clampi(quality, 0, 3)], true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_HIGH if cine else RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 4, 50.0, 300.0)
	main.get_viewport().use_taa = hi
