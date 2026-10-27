class_name Hud
extends CanvasLayer
## Interface: quase nada na tela (o jogo é áudio e escuridão) + efeitos de câmera.

var _prompt: Label
var _status: Label
var _mic: Label
var _objetivo: Label
var _debug: Label
var _interact: Label
var _stamina: ColorRect
var _stamina_bg: ColorRect
var _note_panel: PanelContainer
var _note_title: Label
var _note_body: Label
var _overlay: ColorRect
var _title: Label
var _fx: ColorRect
var _fx_mat: ShaderMaterial
var _prompt_t := 0.0
var _flash_t := 0.0
var _flash_len := 0.0
var _fear := 0.0


func _ready() -> void:
	add_to_group("hud")
	layer = 5
	_fx = ColorRect.new()
	_fx.name = "Efeitos"
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = load("res://assets/shaders/efeitos.gdshader")
	_fx.material = _fx_mat
	add_child(_fx)

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_prompt = _label(0.70, 0.80, 34, HORIZONTAL_ALIGNMENT_CENTER)
	_interact = _label(0.60, 0.66, 24, HORIZONTAL_ALIGNMENT_CENTER)
	_title = _label(0.35, 0.65, 46, HORIZONTAL_ALIGNMENT_CENTER)
	_status = _label(0.94, 1.0, 16, HORIZONTAL_ALIGNMENT_LEFT)
	_mic = _label(0.90, 0.94, 16, HORIZONTAL_ALIGNMENT_LEFT)
	_debug = _label(0.0, 0.1, 14, HORIZONTAL_ALIGNMENT_RIGHT)
	_objetivo = _label(0.02, 0.16, 18, HORIZONTAL_ALIGNMENT_LEFT)
	_objetivo.offset_left = 20.0
	_objetivo.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	for l in [_status, _mic]:
		(l as Label).offset_left = 16.0

	_stamina_bg = ColorRect.new()
	_stamina_bg.color = Color(0, 0, 0, 0.35)
	_stamina_bg.anchor_left = 0.5
	_stamina_bg.anchor_right = 0.5
	_stamina_bg.anchor_top = 0.96
	_stamina_bg.anchor_bottom = 0.96
	_stamina_bg.offset_left = -80
	_stamina_bg.offset_right = 80
	_stamina_bg.offset_top = -3
	_stamina_bg.offset_bottom = 3
	_stamina_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamina_bg)
	_stamina = ColorRect.new()
	_stamina.color = Color(0.9, 0.8, 0.55, 0.8)
	_stamina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bg.add_child(_stamina)
	_stamina_bg.visible = false

	_note_panel = PanelContainer.new()
	_note_panel.anchor_left = 0.25
	_note_panel.anchor_right = 0.75
	_note_panel.anchor_top = 0.2
	_note_panel.anchor_bottom = 0.8
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.82, 0.74, 0.56, 0.96)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(28)
	_note_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	_note_title = Label.new()
	_note_title.add_theme_font_size_override("font_size", 28)
	_note_title.add_theme_color_override("font_color", Color(0.18, 0.10, 0.06))
	_note_body = Label.new()
	_note_body.add_theme_font_size_override("font_size", 20)
	_note_body.add_theme_color_override("font_color", Color(0.14, 0.09, 0.05))
	_note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var hint := Label.new()
	hint.text = "[E] fechar"
	hint.add_theme_color_override("font_color", Color(0.3, 0.2, 0.12))
	vb.add_child(_note_title)
	vb.add_child(_note_body)
	vb.add_child(hint)
	_note_panel.add_child(vb)
	_note_panel.visible = false
	add_child(_note_panel)
	apply_config()


func apply_config() -> void:
	var on := Config.camera_fx
	_fx.visible = on
	_fx_mat.set_shader_parameter("vignette", 0.55 if on else 0.0)


func _label(top: float, bottom: float, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = top
	l.anchor_bottom = bottom
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.92, 0.82, 0.6))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func show_prompt(text: String, seconds: float) -> void:
	_prompt.text = text
	_prompt_t = seconds


func set_status(oil: float, lantern_on: bool) -> void:
	_status.text = "Lanterna [F]: %s   querosene: %d" % ["acesa" if lantern_on else "apagada", int(oil)]


func set_mic(level: float, threshold: float, has_mic: bool) -> void:
	if not Config.grito_ativo:
		_mic.text = ""
	elif has_mic:
		var bars := "|".repeat(clampi(int(level * 80.0), 0, 40))
		_mic.text = "mic %s   limiar %.2f  ([ e ] ajustam)   ou segure R" % [bars, threshold]
	else:
		_mic.text = "sem microfone: segure R para gritar"


func set_debug(text: String) -> void:
	_debug.text = text


## Medo de 0 a 1: escurece, dessatura e pulsa no ritmo do coração.
func set_fear(f: float, bpm: float) -> void:
	_fear = f
	_fx_mat.set_shader_parameter("fear", f)
	_fx_mat.set_shader_parameter("heartbeat", bpm / 60.0)


func set_stamina(frac: float, exhausted: bool) -> void:
	_stamina_bg.visible = frac < 0.995
	_stamina.anchor_right = clampf(frac, 0.0, 1.0)
	_stamina.color = Color(0.85, 0.35, 0.25, 0.85) if exhausted else Color(0.9, 0.8, 0.55, 0.8)


## Objetivo atual e itens carregados (canto superior esquerdo).
func set_objetivo(text: String) -> void:
	_objetivo.text = text


func show_interact(text: String) -> void:
	_interact.text = text


func show_note(title: String, body: String) -> void:
	_note_title.text = title
	_note_body.text = body
	_note_panel.visible = true


func hide_note() -> void:
	_note_panel.visible = false


func note_open() -> bool:
	return _note_panel.visible


func flash(color: Color, seconds: float) -> void:
	_overlay.color = color
	_flash_t = seconds
	_flash_len = seconds
	_fx_mat.set_shader_parameter("flash", minf(color.a, 0.8))


func end_screen(title: String, subtitle: String, color: Color) -> void:
	_overlay.color = color
	_flash_t = 0.0
	_title.text = "%s\n\n[Enter] recomeçar\n%s" % [title, subtitle]


func _process(delta: float) -> void:
	if _prompt_t > 0.0:
		_prompt_t -= delta
		if _prompt_t <= 0.0:
			_prompt.text = ""
	if _flash_t > 0.0:
		_flash_t -= delta
		var a := clampf(_flash_t / maxf(_flash_len, 0.001), 0.0, 1.0)
		_overlay.color.a = a * _overlay.color.a if a < 1.0 else _overlay.color.a
		_fx_mat.set_shader_parameter("flash", clampf(a * 0.6, 0.0, 0.8))
		if _flash_t <= 0.0:
			_overlay.color.a = 0.0
			_fx_mat.set_shader_parameter("flash", 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _note_panel != null and _note_panel.visible and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		hide_note()
		get_tree().call_group("jogador", "set", "frozen", false)
		get_viewport().set_input_as_handled()
