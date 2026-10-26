class_name Config
extends RefCounted
## Opções do jogador, salvas em user://bradador.cfg (some se você apagar o arquivo).

const PATH := "user://bradador.cfg"

static var master := 0.9        # 0..1
static var music := 0.7
static var effects := 1.0
static var mouse_sens := 0.0025
static var mic_threshold := 0.07
static var quality := 1         # 0 baixa, 1 média, 2 alta
static var camera_fx := true    # vinheta, granulado, aberração
static var head_bob := true
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
	camera_fx = cf.get_value("video", "camera_fx", camera_fx)
	head_bob = cf.get_value("video", "head_bob", head_bob)


static func save_all() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master", master)
	cf.set_value("audio", "music", music)
	cf.set_value("audio", "effects", effects)
	cf.set_value("controles", "mouse_sens", mouse_sens)
	cf.set_value("controles", "mic_threshold", mic_threshold)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "camera_fx", camera_fx)
	cf.set_value("video", "head_bob", head_bob)
	cf.save(PATH)


## Aplica as opções de vídeo/áudio à cena do jogo. `main` = nó raiz (scenes/main.tscn).
static func apply(main: Node) -> void:
	var vp := main.get_viewport()
	var scale: float = [0.75, 1.0, 1.0][quality]
	vp.scaling_3d_scale = scale
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
		var capim := vila.get_node_or_null("Morros/Capim")
		if capim:
			capim.visible = quality >= 1
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
	e.volumetric_fog_enabled = hi # raios de luz na neblina
	if hi:
		e.volumetric_fog_density = 0.02
		e.volumetric_fog_albedo = Color(0.55, 0.62, 0.8)
		e.sdfgi_use_occlusion = true
	main.get_viewport().use_taa = hi
