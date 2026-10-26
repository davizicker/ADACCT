extends SceneTree
## Gera texturas procedurais (albedo + normal) em res://assets/textures/.
## Uso: godot --headless --path . --script res://tools/gen_textures.gd
## Depois rode `godot --headless --path . --import` e `tools/bake.gd`.
## Para usar texturas profissionais, veja docs/APRENDER.md (seção "Trocar texturas").

const SIZE := 512
const OUT := "res://assets/textures/"


func _init() -> void:
	_pedra()
	_reboco()
	_telha()
	_madeira()
	print("[tex] pronto")
	quit()


func _save(name: String, albedo: Image, height: Image, bump: float) -> void:
	albedo.save_png(OUT + name + "_albedo.png")
	var n := height.duplicate() as Image
	n.convert(Image.FORMAT_RGBA8)
	n.bump_map_to_normal_map(bump)
	n.save_png(OUT + name + "_normal.png")
	print("[tex] ", name)


func _noise(type: int, freq: float, seed_: int, octaves := 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.seed = seed_
	n.fractal_octaves = octaves
	if octaves > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
	else:
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n


## Paralelepípedos de pedra irregulares com juntas escuras.
func _pedra() -> void:
	var edges := _noise(FastNoiseLite.TYPE_CELLULAR, 0.028, 3)
	edges.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var cells := _noise(FastNoiseLite.TYPE_CELLULAR, 0.028, 3)
	cells.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var grain := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.08, 5, 4)
	var moss := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 9, 3)
	var e_img := edges.get_seamless_image(SIZE, SIZE)
	var c_img := cells.get_seamless_image(SIZE, SIZE)
	var g_img := grain.get_seamless_image(SIZE, SIZE)
	var m_img := moss.get_seamless_image(SIZE, SIZE)
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			var e := e_img.get_pixel(x, y).r
			var c := c_img.get_pixel(x, y).r
			var g := g_img.get_pixel(x, y).r
			var m := m_img.get_pixel(x, y).r
			var top := smoothstep(0.0, 0.18, e)  # 0 = junta, 1 = topo da pedra
			var tone := 0.42 + c * 0.22 + (g - 0.5) * 0.25
			var col := Color(tone * 1.0, tone * 0.95, tone * 0.86)
			col = col.lerp(Color(0.22, 0.27, 0.18), clampf((m - 0.55) * 1.6, 0.0, 0.45) * (1.0 - top * 0.4))
			col = col.lerp(Color(0.05, 0.045, 0.04), 1.0 - top)
			albedo.set_pixel(x, y, col)
			var h := top * 0.8 + (g - 0.5) * 0.25
			height.set_pixel(x, y, Color(h, h, h))
	_save("pedra", albedo, height, 6.0)


## Reboco de cal com manchas, umidade e granulação. Cor base clara: a cor final vem do material.
func _reboco() -> void:
	var blotch := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006, 21, 4)
	var fine := _noise(FastNoiseLite.TYPE_SIMPLEX, 0.35, 22)
	var mid := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04, 23, 3)
	var b_img := blotch.get_seamless_image(SIZE, SIZE)
	var f_img := fine.get_seamless_image(SIZE, SIZE)
	var m_img := mid.get_seamless_image(SIZE, SIZE)
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			var b := b_img.get_pixel(x, y).r
			var f := f_img.get_pixel(x, y).r
			var m := m_img.get_pixel(x, y).r
			var tone := 0.80 + (b - 0.5) * 0.35 + (f - 0.5) * 0.10
			var stain := clampf((m - 0.62) * 2.2, 0.0, 0.5)
			tone *= 1.0 - stain * 0.3
			albedo.set_pixel(x, y, Color(tone, tone * 0.98, tone * 0.93))
			var h := 0.5 + (m - 0.5) * 0.5 + (f - 0.5) * 0.35
			height.set_pixel(x, y, Color(h, h, h))
	_save("reboco", albedo, height, 3.0)


## Telhas de barro sobrepostas, com variação por telha.
func _telha() -> void:
	var tw := 64
	var th := 52
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wear := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 31, 3)
	var w_img := wear.get_seamless_image(SIZE, SIZE)
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	var variation: Array[float] = []
	for i in 400:
		variation.append(rng.randf())
	for y in SIZE:
		var row := y / th
		var off := (row % 2) * (tw / 2)
		for x in SIZE:
			var xx := (x + off) % SIZE
			var col_i := xx / tw
			var u := float(xx % tw) / tw
			var v := float(y % th) / th
			var vari := variation[(row * 13 + col_i) % 400]
			var curve := sin(u * PI)
			var h := curve * 0.55 + v * 0.45
			var shade := 0.55 + 0.45 * curve
			shade *= 0.6 + 0.4 * smoothstep(0.0, 0.25, 1.0 - v) + 0.0
			var base := Color(0.55, 0.22, 0.14).lerp(Color(0.42, 0.18, 0.13), vari)
			var w := w_img.get_pixel(x, y).r
			base = base.lerp(Color(0.25, 0.27, 0.2), clampf((w - 0.6) * 1.5, 0.0, 0.5))
			var edge := 1.0
			if u < 0.05 or u > 0.95 or v > 0.93:
				edge = 0.25
			albedo.set_pixel(x, y, base * shade * edge * 1.4)
			height.set_pixel(x, y, Color(h, h, h))
	_save("telha", albedo, height, 5.0)


## Tábuas de madeira envelhecida, veio vertical.
func _madeira() -> void:
	var grain := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0, 41, 3)
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	var plank := 64
	for y in SIZE:
		for x in SIZE:
			var p := x / plank
			var along := grain.get_noise_2d(x * 0.12 + p * 40.0, y * 0.004)
			var rings := grain.get_noise_2d(x * 0.5 + p * 17.0, y * 0.02)
			var tone := 0.30 + along * 0.08 + rings * 0.05
			var gap := 0.35 if (x % plank) < 2 else 1.0
			albedo.set_pixel(x, y, Color(tone * 1.05, tone * 0.78, tone * 0.52) * gap)
			var h := 0.5 + rings * 0.18 - (0.35 if (x % plank) < 2 else 0.0)
			height.set_pixel(x, y, Color(h, h, h))
	_save("madeira", albedo, height, 3.0)
