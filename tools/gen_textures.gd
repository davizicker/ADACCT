extends SceneTree
## Gera texturas procedurais em res://assets/textures/ (todas originais, sem licença a cumprir).
##  - superfícies: <nome>_albedo.png + <nome>_normal.png
##  - vegetação (com transparência): <nome>.png
## Uso: godot --headless --path . --script res://tools/gen_textures.gd
## Depois: godot --headless --path . --import   e   tools/bake.gd
## Para texturas profissionais gratuitas (CC0), veja docs/APRENDER.md.

const SIZE := 512
const OUT := "res://assets/textures/"


func _init() -> void:
	_pedra()
	_muro()
	_reboco()
	_reboco_velho()
	_telha()
	_madeira()
	_cantaria()
	_terra()
	_decals()
	_folha_seca()
	_reboco_caido()
	_ponto_luz()
	_silhueta()
	_janelas()
	print("[tex] pronto")
	quit()


# ------------------------------------------------------------------ decalques de sujeira (só Forward+)

## sujeira_base.png: sujeira e respingos que sobem do chão, com escorridos verticais.
## mancha.png: manchas de umidade/mofo em lugares aleatórios. Texturas RGBA; v=1 é o PÉ da parede.
func _decals() -> void:
	var streak := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0, 81, 3)
	var blot := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0, 82, 4)
	var fine := _noise(FastNoiseLite.TYPE_SIMPLEX, 1.0, 83)
	var a := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	var m := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	for y in 512:
		for x in 512:
			var v := float(y) / 511.0           # 0 = topo, 1 = pé da parede
			var u := float(x) / 511.0
			var st := streak.get_noise_2d(u * 38.0, v * 3.0) * 0.5 + 0.5        # escorridos verticais finos
			var bl := blot.get_noise_2d(u * 5.0, v * 5.0) * 0.5 + 0.5
			var fn := fine.get_noise_2d(u * 120.0, v * 120.0) * 0.5 + 0.5
			var base := pow(v, 3.2)                                              # mais sujo perto do chão
			var alpha := clampf(base * (0.55 + st * 0.9) + (bl - 0.5) * 0.25 * v, 0.0, 1.0) * (0.75 + fn * 0.25)
			alpha = clampf(alpha * 0.85, 0.0, 0.8)
			var col := Color(0.10, 0.08, 0.06).lerp(Color(0.18, 0.16, 0.10), clampf(bl, 0.0, 1.0) * 0.5)
			a.set_pixel(x, y, Color(col.r, col.g, col.b, alpha))
			var mk := clampf((bl - 0.52) * 4.0, 0.0, 1.0) * clampf(st * 1.4, 0.0, 1.0)
			var edge := smoothstep(0.0, 0.12, u) * smoothstep(1.0, 0.88, u) * smoothstep(0.0, 0.1, v) * smoothstep(1.0, 0.9, v)
			var mcol := Color(0.12, 0.13, 0.09).lerp(Color(0.10, 0.17, 0.08), clampf(fn, 0.0, 1.0))
			m.set_pixel(x, y, Color(mcol.r, mcol.g, mcol.b, mk * edge * 0.7))
	a.save_png(OUT + "sujeira_base.png")
	m.save_png(OUT + "mancha.png")


## folha_seca.png: folha caída (silhueta pontuda, nervura central e nervuras laterais), com alfa.
func _folha_seca() -> void:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var nz := _noise(FastNoiseLite.TYPE_SIMPLEX, 0.08, 91, 2)
	for y in 128:
		for x in 128:
			var u := (float(x) - 64.0) / 64.0
			var v := (float(y) - 64.0) / 64.0
			var half := 0.62 * pow(maxf(0.0, 1.0 - absf(u) ** 1.7), 0.8)              # contorno em losango arredondado
			var inside := absf(v) < half * (0.92 + nz.get_noise_2d(x, y) * 0.2)
			if not inside:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var rib := absf(v) < 0.03
			var vein := fmod(absf(u) * 9.0 + absf(v) * 4.0, 1.0) < 0.1
			var k := 0.5 + nz.get_noise_2d(x * 2.0, y * 2.0) * 0.4
			var c := Color(0.55, 0.34, 0.12).lerp(Color(0.40, 0.22, 0.08), k)
			if rib or vein:
				c = c.darkened(0.3)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	img.generate_mipmaps()
	img.save_png(OUT + "folha_seca.png")


## reboco_caido.png: pedaço de reboco que caiu e mostra tijolo e pedra por baixo, com borda irregular e sombra.
func _reboco_caido() -> void:
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	var blot := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 95, 4)
	var fine := _noise(FastNoiseLite.TYPE_SIMPLEX, 0.2, 96)
	for y in 512:
		for x in 512:
			var u := (float(x) - 256.0) / 256.0
			var v := (float(y) - 256.0) / 256.0
			var d := sqrt(u * u * 0.8 + v * v * 1.1)
			var m := blot.get_noise_2d(x, y) * 0.5 + 0.5 - d * 0.75 + 0.25
			if m <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var row := int(y / 38)
			var off := 0 if row % 2 == 0 else 34
			var bx := (x + off) % 68
			var by := y % 38
			var mortar := bx < 5 or by < 5
			var f := fine.get_noise_2d(x, y) * 0.5 + 0.5
			var col := Color(0.52, 0.27, 0.18).lerp(Color(0.36, 0.2, 0.15), f)              # tijolo
			if int(x / 128 + y / 160) % 3 == 0:
				col = Color(0.40, 0.36, 0.30).lerp(Color(0.30, 0.28, 0.24), f)             # pedra
			if mortar:
				col = Color(0.50, 0.46, 0.40)
			var edge := smoothstep(0.0, 0.06, m)
			col = col.lerp(Color(0.06, 0.05, 0.04), (1.0 - edge) * 0.8)                    # sombra na borda
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(m * 12.0, 0.0, 1.0)))
	img.save_png(OUT + "reboco_caido.png")


# ------------------------------------------------------------------ utilidades

func _noise(type: int, freq: float, seed_: int, octaves := 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.seed = seed_
	n.fractal_octaves = octaves
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	return n


func _simg(n: FastNoiseLite) -> Image:
	return n.get_seamless_image(SIZE, SIZE)


func _save(name: String, albedo: Image, height: Image, bump: float) -> void:
	albedo.save_png(OUT + name + "_albedo.png")
	var n := height.duplicate() as Image
	n.convert(Image.FORMAT_RGBA8)
	n.bump_map_to_normal_map(bump)
	n.save_png(OUT + name + "_normal.png")
	print("[tex] ", name)


func _new_rgb() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)


func _new_h() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_L8)


func _h(img: Image, x: int, y: int, v: float) -> void:
	img.set_pixel(x, y, Color(v, v, v))


# ------------------------------------------------------------------ superfícies

## Voronoi que repete sem emenda (o ruído celular da engine não repete bem). Retorna {d: (F2-F1)/2 em px, id: 0..1}.
func _voronoi(cells: int, seed_: int, jitter: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var pts: Array[Vector2] = []
	var ids: Array[float] = []
	for j in cells:
		for i in cells:
			pts.append(Vector2(i + 0.5 + (rng.randf() - 0.5) * jitter, j + 0.5 + (rng.randf() - 0.5) * jitter))
			ids.append(rng.randf())
	var d := PackedFloat32Array()
	d.resize(SIZE * SIZE)
	var idv := PackedFloat32Array()
	idv.resize(SIZE * SIZE)
	var cs := float(SIZE) / cells
	for y in SIZE:
		for x in SIZE:
			var px := (x + 0.5) / cs
			var py := (y + 0.5) / cs
			var ci := int(floor(px))
			var cj := int(floor(py))
			var f1 := 1e9
			var f2 := 1e9
			var best := 0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var gi := ci + di
					var gj := cj + dj
					var wi := posmod(gi, cells)
					var wj := posmod(gj, cells)
					var pt := pts[wj * cells + wi]
					var dx := pt.x + (gi - wi) - px
					var dy := pt.y + (gj - wj) - py
					var dist := sqrt(dx * dx + dy * dy)
					if dist < f1:
						f2 = f1
						f1 = dist
						best = wj * cells + wi
					elif dist < f2:
						f2 = dist
			d[y * SIZE + x] = (f2 - f1) * 0.5 * cs
			idv[y * SIZE + x] = ids[best]
	return {"d": d, "id": idv}


## Calçamento "pé-de-moleque": pedras de quartzito irregulares e arredondadas, juntas finas de terra com musgo,
## cada pedra com cor, altura e brilho próprios. Gera também um mapa de rugosidade (pedra polida x junta).
func _pedra() -> void:
	var vor := _voronoi(19, 311, 0.9)
	var dd: PackedFloat32Array = vor["d"]
	var ii: PackedFloat32Array = vor["id"]
	var g_img := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.09, 5, 4))
	var sp_img := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.45, 6))
	var m_img := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.014, 9, 3))
	var albedo := _new_rgb()
	var height := _new_h()
	var rough := _new_h()
	var palette: Array[Color] = [
		Color(0.50, 0.47, 0.42),   # cinza quente
		Color(0.56, 0.45, 0.34),   # ocre
		Color(0.45, 0.44, 0.44),   # cinza frio
		Color(0.53, 0.41, 0.35),   # rosado
		Color(0.42, 0.42, 0.37),   # cinza esverdeado
	]
	for y in SIZE:
		for x in SIZE:
			var e := dd[y * SIZE + x]                              # distância até a borda da pedra (px)
			var c := ii[y * SIZE + x]
			var g := g_img.get_pixel(x, y).r
			var sp := sp_img.get_pixel(x, y).r
			var m := m_img.get_pixel(x, y).r
			var joint := smoothstep(0.7, 2.0, e)                   # 0 = junta, 1 = pedra
			var dome := smoothstep(0.8, 9.0, e)                    # arredondamento da pedra
			var pos := c * (palette.size() - 1)
			var i0 := int(floor(pos))
			var base := palette[i0].lerp(palette[mini(i0 + 1, palette.size() - 1)], pos - i0)
			var tone := 0.92 + (g - 0.5) * 0.30 + (sp - 0.5) * 0.20
			tone *= 0.90 + 0.20 * dome                             # topo mais claro (polido pelo uso)
			var col := base * tone
			var ring := smoothstep(2.0, 3.2, e) * (1.0 - smoothstep(3.2, 6.5, e))
			col += Color(0.05, 0.05, 0.045) * ring                 # borda levemente clareada
			var soil := Color(0.10, 0.085, 0.06).lerp(Color(0.14, 0.20, 0.08), clampf((m - 0.52) * 2.5, 0.0, 0.75))
			col = col.lerp(soil, 1.0 - joint)
			albedo.set_pixel(x, y, col)
			_h(height, x, y, joint * (0.30 + 0.62 * dome) * (0.80 + 0.20 * c) + (g - 0.5) * 0.06)
			_h(rough, x, y, lerpf(0.97, 0.42 + 0.30 * (1.0 - dome) + (c - 0.5) * 0.12, joint))
	_save("pedra", albedo, height, 5.0)
	rough.save_png(OUT + "pedra_rough.png")
	print("[tex] pedra_rough")


## Muro de pedra de quartzito em fiadas irregulares, com argamassa de terra.
func _muro() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var rows := _split(SIZE, 36, 96, rng)
	var albedo := _new_rgb()
	var height := _new_h()
	var wob := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.09, 61, 2))
	var grain := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.07, 62, 4))
	var moss := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.011, 63, 3))
	var y0 := 0
	for r in rows.size():
		var rh: int = rows[r]
		var blocks := _split(SIZE, 50, 210, rng)
		var x0 := 0
		for b in blocks.size():
			var bw: int = blocks[b]
			var tone := rng.randf_range(0.30, 0.55)
			var warm := rng.randf_range(0.0, 0.10)
			for y in range(y0, y0 + rh):
				for x in range(x0, x0 + bw):
					var d := minf(minf(x - x0, x0 + bw - 1 - x), minf(y - y0, y0 + rh - 1 - y))
					d += (wob.get_pixel(x % SIZE, y % SIZE).r - 0.5) * 9.0
					var top := smoothstep(0.0, 9.0, d)
					var gr := grain.get_pixel(x % SIZE, y % SIZE).r
					var t := tone + (gr - 0.5) * 0.3
					var col := Color(t * (1.0 + warm * 0.4), t * (0.95 + warm * 0.1), t * (0.85 - warm * 0.2))
					var mortar := Color(0.30, 0.25, 0.19)
					var ms := moss.get_pixel(x % SIZE, y % SIZE).r
					col = col.lerp(Color(0.2, 0.28, 0.13), clampf((ms - 0.58) * 2.0, 0.0, 0.5) * (0.5 + 0.5 * top))
					col = col.lerp(mortar, 1.0 - top)
					albedo.set_pixel(x % SIZE, y % SIZE, col)
					_h(height, x % SIZE, y % SIZE, top * 0.85 + (gr - 0.5) * 0.25)
			x0 += bw
		y0 += rh
	_save("muro", albedo, height, 7.0)


## Divide `total` em pedaços de tamanho entre lo e hi que somam exatamente `total`.
func _split(total: int, lo: int, hi: int, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	var left := total
	while left > 0:
		var v := rng.randi_range(lo, hi)
		if left - v < lo:
			v = left
		out.append(v)
		left -= v
	return out


## Reboco de cal limpo, com manchas suaves. A cor final vem do material (tint).
func _reboco() -> void:
	var b_img := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006, 21, 4))
	var f_img := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.35, 22))
	var m_img := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04, 23, 3))
	var albedo := _new_rgb()
	var height := _new_h()
	for y in SIZE:
		for x in SIZE:
			var b := b_img.get_pixel(x, y).r
			var f := f_img.get_pixel(x, y).r
			var m := m_img.get_pixel(x, y).r
			var tone := 0.82 + (b - 0.5) * 0.30 + (f - 0.5) * 0.08
			tone *= 1.0 - clampf((m - 0.62) * 2.0, 0.0, 0.5) * 0.25
			albedo.set_pixel(x, y, Color(tone, tone * 0.98, tone * 0.93))
			_h(height, x, y, 0.5 + (m - 0.5) * 0.4 + (f - 0.5) * 0.3)
	_save("reboco", albedo, height, 2.5)


## Reboco antigo: caiação descascada deixando ver a taipa (barro) e a pedra por baixo.
func _reboco_velho() -> void:
	var mask := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018, 71, 4))
	var fine := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.30, 72))
	var blot := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006, 73, 3))
	var stain := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 74, 3))
	var streak_n := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0, 75, 2)
	var albedo := _new_rgb()
	var height := _new_h()
	for y in SIZE:
		for x in SIZE:
			var mk := mask.get_pixel(x, y).r
			var f := fine.get_pixel(x, y).r
			var bl := blot.get_pixel(x, y).r
			var st := stain.get_pixel(x, y).r
			var plaster := 0.84 + (bl - 0.5) * 0.22 + (f - 0.5) * 0.06
			plaster *= 1.0 - clampf((st - 0.6) * 2.0, 0.0, 0.5) * 0.22
			# escorrimentos de chuva: riscos verticais escuros e suaves
			var sk := streak_n.get_noise_2d(x * 0.045, y * 0.0022)
			plaster *= 1.0 - clampf((sk - 0.12) * 1.6, 0.0, 0.5) * 0.28
			var base := Color(plaster, plaster * 0.98, plaster * 0.93)
			var peel := smoothstep(0.885, 0.915, mk + (f - 0.5) * 0.05)
			var adobe := Color(0.55, 0.43, 0.32).lerp(Color(0.46, 0.36, 0.28), f)
			var rim := smoothstep(0.84, 0.89, mk) * (1.0 - peel)
			var col := base.lerp(adobe, peel)
			col = col.lerp(Color(0.55, 0.52, 0.46), rim * 0.4)
			albedo.set_pixel(x, y, col)
			_h(height, x, y, (0.55 + (f - 0.5) * 0.3) - peel * 0.25 + rim * 0.08)
	_save("reboco_velho", albedo, height, 4.0)


## Telha de barro capa-e-canal: fileiras alternadas de canais e capas, cada telha sobreposta.
func _telha() -> void:
	var period := 32   # largura de um par canal+capa (px)
	var tile_len := 64  # comprimento de uma telha (px)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var tones: Array[float] = []
	for i in 64:
		tones.append(rng.randf())
	var patina := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 31, 3))
	var soot := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.012, 32, 2))
	var fine := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.4, 33))
	var albedo := _new_rgb()
	var height := _new_h()
	for y in SIZE:
		var row := y / tile_len
		var v := float(y % tile_len) / tile_len
		for x in SIZE:
			var col_i := x / period
			var u := float(x % period) / period
			var prof := 0.5 + 0.5 * cos(u * TAU)       # 1 = capa (convexa), 0 = canal (côncavo)
			var tone := tones[(row * 7 + col_i * 3 + (row * col_i) % 5) % 64]
			var base := Color(0.55, 0.22, 0.13).lerp(Color(0.38, 0.15, 0.10), tone)
			# sombra sob a borda da telha de cima (sobreposição) e junta
			var shade := 0.55 + 0.45 * smoothstep(0.0, 0.22, v)
			shade *= 0.75 + 0.25 * prof
			if v < 0.03:
				shade *= 0.35
			var p := patina.get_pixel(x, y).r
			var s := soot.get_pixel(x, y).r
			var c := base * shade * 1.35
			c = c.lerp(Color(0.24, 0.27, 0.19), clampf((p - 0.68) * 2.0, 0.0, 0.5) * (0.4 + 0.6 * (1.0 - prof)))
			c = c.lerp(Color(0.06, 0.05, 0.05), clampf((s - 0.62) * 2.0, 0.0, 0.5))
			c = c * (0.94 + fine.get_pixel(x, y).r * 0.12)
			albedo.set_pixel(x, y, c)
			_h(height, x, y, prof * 0.6 + smoothstep(0.0, 0.25, v) * 0.3)
	_save("telha", albedo, height, 5.0)


## Madeira de esquadria: tábuas verticais, tom neutro claro para receber tinta (tint do material).
func _madeira() -> void:
	var grain := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0, 41, 3)
	var wear := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 42, 3))
	var albedo := _new_rgb()
	var height := _new_h()
	var plank := 64
	for y in SIZE:
		for x in SIZE:
			var p := x / plank
			var along := grain.get_noise_2d(x * 0.12 + p * 40.0, y * 0.004)
			var rings := grain.get_noise_2d(x * 0.5 + p * 17.0, y * 0.02)
			var w := wear.get_pixel(x, y).r
			var tone := 0.68 + along * 0.10 + rings * 0.06 - clampf((w - 0.6) * 1.5, 0.0, 0.4) * 0.35
			var gap := 0.30 if (x % plank) < 2 else 1.0
			albedo.set_pixel(x, y, Color(tone, tone * 0.97, tone * 0.92) * gap)
			_h(height, x, y, 0.5 + rings * 0.15 - (0.35 if (x % plank) < 2 else 0.0))
	_save("madeira", albedo, height, 3.0)


## Cantaria (pedra-sabão/quartzito aparelhado): cinza-esverdeada, lisa, com veios finos e desgaste.
func _cantaria() -> void:
	var b := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.01, 81, 4))
	var vein := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.035, 82, 2))
	var pit := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.4, 83))
	var albedo := _new_rgb()
	var height := _new_h()
	for y in SIZE:
		for x in SIZE:
			var bb := b.get_pixel(x, y).r
			var vv := absf(vein.get_pixel(x, y).r - 0.5)
			var pp := pit.get_pixel(x, y).r
			var tone := 0.56 + (bb - 0.5) * 0.25
			var col := Color(tone * 0.92, tone * 0.97, tone * 0.90)
			if vv < 0.025:
				col = col.lerp(Color(0.32, 0.36, 0.33), 0.5)
			col *= 0.94 + pp * 0.1
			albedo.set_pixel(x, y, col)
			_h(height, x, y, 0.5 + (pp - 0.5) * 0.18 + (bb - 0.5) * 0.2)
	_save("cantaria", albedo, height, 1.5)


## Terra batida com tufos de grama: chão dos quintais e dos morros.
func _terra() -> void:
	var patch := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 91, 4))
	var detail := _simg(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.25, 92, 2))
	var rock := _simg(_noise(FastNoiseLite.TYPE_CELLULAR, 0.03, 93))
	var albedo := _new_rgb()
	var height := _new_h()
	for y in SIZE:
		for x in SIZE:
			var p := patch.get_pixel(x, y).r
			var d := detail.get_pixel(x, y).r
			var r := rock.get_pixel(x, y).r
			var grass := smoothstep(0.42, 0.58, p + (d - 0.5) * 0.25)
			var dirt := Color(0.30, 0.22, 0.15).lerp(Color(0.40, 0.30, 0.20), d)
			var green := Color(0.16, 0.23, 0.10).lerp(Color(0.26, 0.33, 0.14), d)
			var col := dirt.lerp(green, grass)
			col = col.lerp(Color(0.38, 0.35, 0.31), clampf((r - 0.8) * 3.0, 0.0, 0.5) * (1.0 - grass))
			albedo.set_pixel(x, y, col)
			_h(height, x, y, 0.5 + (d - 0.5) * 0.5 + grass * 0.15)
	_save("terra", albedo, height, 3.0)


# ------------------------------------------------------------------ vegetação (com alpha)

func _blank(size: int, base: Color) -> Image:
	# RGB dos pixels transparentes = verde médio, para não aparecer halo escuro nas bordas
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(base.r, base.g, base.b, 0.0))
	return img


## Folha elíptica com nervura central. (cx,cy) centro, len comprimento, wid largura, ang ângulo (rad).
func _leaf(img: Image, cx: float, cy: float, len: float, wid: float, ang: float, col: Color, rib := true) -> void:
	var cs := cos(ang)
	var sn := sin(ang)
	var r := int(len * 0.55) + 2
	for py in range(int(cy) - r, int(cy) + r + 1):
		for px in range(int(cx) - r, int(cx) + r + 1):
			var dx := px - cx
			var dy := py - cy
			var u := (dx * cs + dy * sn) / len + 0.5      # 0..1 ao longo da folha
			var v := (-dx * sn + dy * cs)                  # lateral (px)
			if u < 0.0 or u > 1.0:
				continue
			var half := wid * 0.5 * pow(sin(u * PI), 0.75)
			if absf(v) > half:
				continue
			var shade := 0.75 + 0.25 * (1.0 - absf(v) / maxf(half, 0.001))
			var c := col * shade
			if rib and absf(v) < 0.7:
				c = c.lerp(Color(0.55, 0.65, 0.35), 0.45)
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			img.set_pixel(px, py, Color(c.r, c.g, c.b, 1.0))


func _greens(rng: RandomNumberGenerator, dark: float) -> Color:
	var t := rng.randf()
	var c := Color(0.08, 0.20, 0.06).lerp(Color(0.26, 0.42, 0.12), t)
	return c * dark


func _save_alpha(name: String, img: Image) -> void:
	img.generate_mipmaps()
	img.save_png(OUT + name + ".png")
	print("[tex] ", name)


## Aglomerado de folhas de copa de árvore (cartão para copas).
func _folhagem() -> void:
	var s := 256
	var img := _blank(s, Color(0.14, 0.28, 0.08))
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	for i in 190:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * s * 0.42
		var cx := s * 0.5 + cos(a) * d
		var cy := s * 0.5 + sin(a) * d
		var dark := 0.55 + 0.6 * (1.0 - cy / s)    # parte de cima mais clara
		_leaf(img, cx, cy, rng.randf_range(26, 40), rng.randf_range(11, 17), rng.randf() * TAU, _greens(rng, dark))
	_save_alpha("folhagem", img)


## Arbusto denso de folhas pequenas.
func _arbusto() -> void:
	var s := 256
	var img := _blank(s, Color(0.12, 0.26, 0.08))
	var rng := RandomNumberGenerator.new()
	rng.seed = 102
	for i in 260:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * s * 0.40
		var cx := s * 0.5 + cos(a) * d
		var cy := s * 0.55 + sin(a) * d * 0.85
		_leaf(img, cx, cy, rng.randf_range(16, 26), rng.randf_range(8, 12), rng.randf() * TAU, _greens(rng, 0.5 + 0.7 * (1.0 - cy / s)))
	_save_alpha("arbusto", img)


## Samambaia: frondes arqueadas com folíolos.
func _samambaia() -> void:
	var s := 256
	var img := _blank(s, Color(0.12, 0.30, 0.10))
	var rng := RandomNumberGenerator.new()
	rng.seed = 103
	var fronds := 7
	for f in fronds:
		var ang0 := lerpf(-1.25, 1.25, float(f) / (fronds - 1)) + rng.randf_range(-0.1, 0.1)
		var length := rng.randf_range(100.0, 125.0)
		var pos := Vector2(s * 0.5, s * 0.96)
		var dir_ang := -PI / 2.0 + ang0
		var steps := 22
		for k in steps:
			var t := float(k) / steps
			dir_ang += 0.045 * ang0 + 0.01   # arqueia para o lado
			pos += Vector2(cos(dir_ang), sin(dir_ang)) * (length / steps)
			var leaflet := (1.0 - t) * 22.0 + 4.0
			for side in [-1.0, 1.0]:
				var la: float = dir_ang + side * 1.15
				_leaf(img, pos.x + cos(la) * leaflet * 0.5, pos.y + sin(la) * leaflet * 0.5, leaflet, 4.5, la, _greens(rng, 0.9), false)
			_leaf(img, pos.x, pos.y, length / steps * 1.6, 2.2, dir_ang, Color(0.18, 0.32, 0.12), false)
	_save_alpha("samambaia", img)


## Tufo de capim: lâminas finas que saem da base.
func _capim() -> void:
	var s := 256
	var img := _blank(s, Color(0.30, 0.38, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 104
	for i in 70:
		var bx := s * 0.5 + rng.randf_range(-s * 0.32, s * 0.32)
		var h := rng.randf_range(s * 0.35, s * 0.9)
		var lean := rng.randf_range(-0.5, 0.5) * (bx - s * 0.5) / (s * 0.3) + rng.randf_range(-0.15, 0.15)
		var col := Color(0.20, 0.32, 0.08).lerp(Color(0.52, 0.55, 0.20), rng.randf() * rng.randf())
		var steps := int(h)
		for k in steps:
			var t := float(k) / steps
			var x := bx + lean * t * t * h * 0.6
			var y := s - 1.0 - t * h
			var w := lerpf(3.2, 0.4, t)
			for dx in range(-int(w) - 1, int(w) + 2):
				var px := int(x) + dx
				if absf(dx) <= w and px >= 0 and px < s and y >= 0:
					img.set_pixel(px, int(y), Color(col.r * (0.7 + 0.4 * t), col.g * (0.7 + 0.4 * t), col.b, 1.0))
	_save_alpha("capim", img)


## Hera/trepadeira: folhas em coração sobrepostas, cobrindo o cartão (para muros).
func _hera() -> void:
	var s := 256
	var img := _blank(s, Color(0.10, 0.24, 0.07))
	var rng := RandomNumberGenerator.new()
	rng.seed = 105
	for i in 1100:
		var cx := rng.randf() * s
		var cy := rng.randf() * s
		# denso embaixo, ralo em cima; some suavemente nas bordas (sem contorno retangular)
		var edge_x := smoothstep(0.0, 0.22, minf(cx, s - cx) / s)
		var edge_y := smoothstep(0.0, 0.30, minf(cy, s - cy) / s)
		var keep := (0.50 + 0.50 * smoothstep(0.0, 1.0, cy / s)) * edge_x * maxf(edge_y, 0.0)
		if rng.randf() > keep:
			continue
		_leaf(img, cx, cy, rng.randf_range(20, 30), rng.randf_range(14, 20), rng.randf() * TAU, _greens(rng, 0.55 + 0.5 * rng.randf()), false)
	_save_alpha("hera", img)


## Bananeira: folhas grandes, longas, arqueadas.
func _bananeira() -> void:
	var s := 512
	var img := _blank(s, Color(0.14, 0.34, 0.10))
	var rng := RandomNumberGenerator.new()
	rng.seed = 106
	var leaves := 6
	for i in leaves:
		var ang := lerpf(-1.1, 1.1, float(i) / (leaves - 1)) + rng.randf_range(-0.12, 0.12)
		var length := rng.randf_range(300.0, 380.0)
		var width := rng.randf_range(80.0, 100.0)
		var dir_a := -PI / 2.0 + ang
		var steps := int(length * 1.6)
		var pos := Vector2(s * 0.5, s * 0.97)
		var tone := rng.randf()
		for k in steps:
			var t := float(k) / steps
			dir_a += 0.0035 * ang + 0.0022
			pos += Vector2(cos(dir_a), sin(dir_a)) * (length / steps)
			var half := width * 0.5 * pow(sin(minf(t * 1.1, 1.0) * PI), 0.7) * (1.0 if t > 0.12 else t / 0.12)
			var nrm := Vector2(-sin(dir_a), cos(dir_a))
			var shade := 0.75 + 0.3 * (1.0 - t * 0.5)
			var base_c := Color(0.10, 0.30, 0.08).lerp(Color(0.20, 0.42, 0.12), tone * 0.6) * shade
			var j := -half
			while j <= half:
				# folha rasgada: entalhes laterais
				var tear := absf(sin(j * 0.45 + float(i) * 1.7 + t * 6.0)) < 0.06 and absf(j) > half * 0.45
				if not tear:
					var p := pos + nrm * j
					var px := int(p.x)
					var py := int(p.y)
					if px >= 0 and px < s and py >= 0 and py < s:
						var c := base_c * (0.88 + 0.12 * cos(j * 0.35))
						if absf(j) < 1.6:
							c = Color(0.50, 0.58, 0.28)
						img.set_pixel(px, py, Color(c.r, c.g, c.b, 1.0))
				j += 0.5
	_save_alpha("bananeira", img)


## Ponto de luz suave (círculo com borda difusa) para as luzes distantes das encostas.
func _ponto_luz() -> void:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 1.6)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.save_png(OUT + "ponto_luz.png")
	print("[tex] ponto_luz")


## Vulto humano (cabeça e ombros) em preto, para a "janela assombrada".
func _silhueta() -> void:
	var w := 128
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var a := 0.0
			# cabeça levemente inclinada
			var hx := (x - 64.0 - (y - 70.0) * 0.08) / 22.0
			var hy := (y - 70.0) / 29.0
			if hx * hx + hy * hy < 1.0:
				a = 1.0
			# pescoço
			if y > 90 and y < 125 and absf(x - 64.0) < 11.0:
				a = 1.0
			# ombros e torso
			var sx := (x - 64.0) / 56.0
			var sy := (y - 170.0) / 52.0
			if y >= 118 and (sx * sx + sy * sy < 1.0 or y > 170) and absf(x - 64.0) < 56.0:
				a = 1.0
			img.set_pixel(x, y, Color(0, 0, 0, a))
	img.save_png(OUT + "silhueta.png")
	print("[tex] silhueta")


## Vidros de janela: "luz" (sala acesa, com cortinas e uma lâmpada) e "noite" (vidro escuro com reflexo do céu).
func _janelas() -> void:
	var w := 128
	var h := 192
	var lit := Image.create(w, h, false, Image.FORMAT_RGB8)
	var dark := Image.create(w, h, false, Image.FORMAT_RGB8)
	var n1 := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 130, 2)
	for y in h:
		for x in w:
			var u := float(x) / w
			var v := float(y) / h
			# --- sala acesa
			var warm := Color(1.0, 0.80, 0.45).lerp(Color(0.62, 0.36, 0.14), pow(absf(v - 0.45) * 1.7, 1.4))
			warm = warm.lerp(Color(0.40, 0.22, 0.09), smoothstep(0.70, 1.0, v) * 0.7)   # chão e móveis, mais escuro
			var lamp := exp(-pow((u - 0.52) * 7.0, 2.0) - pow((v - 0.22) * 6.0, 2.0))     # lâmpada/abajur
			warm += Color(0.5, 0.4, 0.2) * lamp
			# cortinas laterais com dobras e amarração
			var cw := 0.20 + 0.10 * smoothstep(0.35, 0.60, v) * 0.0
			var curtain := 0.0
			var tie := smoothstep(0.52, 0.62, v)
			var edge_l := cw * (1.0 - 0.45 * tie * (1.0 - smoothstep(0.62, 0.70, v)))
			if u < edge_l or u > 1.0 - edge_l:
				curtain = 1.0
			var fold := 0.5 + 0.5 * sin(u * 62.0 + n1.get_noise_2d(x, y) * 2.0)
			var ccol := Color(0.95, 0.84, 0.62) * (0.55 + 0.45 * fold)
			var col := warm.lerp(ccol, curtain * 0.92)
			col *= 0.62 + 0.38 * smoothstep(0.0, 0.10, minf(u, 1.0 - u) * 4.0 + 0.2)   # sombra nas bordas
			lit.set_pixel(x, y, col)
			# --- vidro noturno
			var sky := Color(0.03, 0.045, 0.08).lerp(Color(0.012, 0.016, 0.022), smoothstep(0.0, 0.8, v))
			var streak := smoothstep(0.0, 0.04, 0.5 - absf((u + v * 0.55) - 0.78)) * 0.05    # reflexo diagonal
			var dust := (n1.get_noise_2d(x * 1.7, y * 1.7) * 0.5 + 0.5) * 0.012
			dark.set_pixel(x, y, sky + Color(streak, streak * 1.1, streak * 1.4) + Color(dust, dust, dust))
	lit.save_png(OUT + "vidro_luz.png")
	dark.save_png(OUT + "vidro_noite.png")
	print("[tex] janelas")
