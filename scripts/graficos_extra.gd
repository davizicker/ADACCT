extends Node
## Extras visuais do Forward+ (qualidade Alta e Cinematográfica), montados em tempo de execução:
## 1) gaiola do lampião: textura projetada (panorâmica) nas luzes da rua: as grades de ferro fazem listras de luz e sombra nas paredes;
## 2) gradação de cor de cinema (sombras azuladas, luzes de vela quentes);
## 3) bancos de névoa baixa e irregular ao longo da rua (FogVolume com ruído 3D), só no Cinematográfico.

var cine := false


func configurar(c: bool) -> void:
	cine = c
	var main := get_tree().current_scene
	var vila := main.get_node_or_null("Vila") if main else null
	if vila == null:
		return
	_gaiola(vila)
	_gradacao(vila)
	if cine:
		_nevoa(vila)


func _gaiola(vila: Node) -> void:
	# panorama 512x256: 8 barras verticais escuras (as hastes da gaiola), base e tampa escuras (o lampião não ilumina para cima nem para baixo de si)
	var img := Image.create(512, 256, false, Image.FORMAT_L8)
	for y in 256:
		var v := float(y) / 255.0
		var vert := smoothstep(0.08, 0.30, v) * (1.0 - smoothstep(0.82, 0.97, v))       # tampa em cima, base embaixo
		for x in 512:
			var u := float(x) / 512.0 * 8.0
			var barra := absf(u - roundf(u))                                                # 0 no meio de cada haste
			var luz := clampf(smoothstep(0.03, 0.09, barra), 0.18, 1.0)                     # haste: sombra suave, não preta
			img.set_pixel(x, y, Color(luz * vert + 0.12, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	for l in vila.find_children("*", "OmniLight3D", true, false):
		var o := l as OmniLight3D
		if o.light_cull_mask & 1 and o.omni_range > 3.0 and o.omni_range < 20.0:
			o.light_projector = tex


func _gradacao(vila: Node) -> void:
	var amb := vila.get_node_or_null("Ambiente") as WorldEnvironment
	if amb == null or amb.environment == null:
		return
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 0.82, 1.0])
	g.colors = PackedColorArray([Color(0.0, 0.01, 0.03), Color(0.12, 0.16, 0.23), Color(0.50, 0.50, 0.49), Color(0.88, 0.80, 0.66), Color(1.0, 0.96, 0.88)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	gt.width = 256
	amb.environment.adjustment_enabled = true
	amb.environment.adjustment_color_correction = gt


func _nevoa(vila: Node) -> void:
	if vila.get_node_or_null("BancosDeNevoa") != null:
		return
	var raiz := Node3D.new()
	raiz.name = "BancosDeNevoa"
	vila.add_child(raiz)
	var ruido := FastNoiseLite.new()
	ruido.frequency = 0.08
	ruido.fractal_octaves = 3
	var nt := NoiseTexture3D.new()
	nt.width = 64
	nt.height = 32
	nt.depth = 64
	nt.noise = ruido
	nt.seamless = true
	var s := 12.0
	var k := 0
	while s < Route.CHURCH_S - 4.0:
		var fm := FogMaterial.new()
		fm.density = 0.07 + 0.05 * float(k % 3)
		fm.albedo = Color(0.60, 0.66, 0.78)
		fm.height_falloff = 0.6                   # mais densa rente ao chão
		fm.edge_fade = 0.5
		fm.density_texture = nt
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		fv.size = Vector3(12.0, 2.6, 12.0)
		fv.material = fm
		raiz.add_child(fv)
		fv.global_position = Route.pos(s) + Vector3(0, 0.9, 0)
		s += 22.0 + float((k * 7) % 9)
		k += 1
