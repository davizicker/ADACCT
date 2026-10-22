class_name Hud
extends CanvasLayer
## Interface mínima: o jogo é áudio e escuridão, então quase nada na tela.

var _prompt: Label
var _status: Label
var _mic: Label
var _debug: Label
var _overlay: ColorRect
var _title: Label
var _prompt_t := 0.0
var _flash_t := 0.0
var _flash_len := 0.0


func _ready() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_prompt = _label(0.70, 0.80, 34, HORIZONTAL_ALIGNMENT_CENTER)
	_title = _label(0.35, 0.65, 46, HORIZONTAL_ALIGNMENT_CENTER)
	_status = _label(0.94, 1.0, 16, HORIZONTAL_ALIGNMENT_LEFT)
	_mic = _label(0.90, 0.94, 16, HORIZONTAL_ALIGNMENT_LEFT)
	_debug = _label(0.0, 0.1, 14, HORIZONTAL_ALIGNMENT_RIGHT)
	for l in [_status, _mic]:
		(l as Label).offset_left = 16.0


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
	_status.text = "Lampião [F]: %s   óleo: %d" % ["aceso" if lantern_on else "apagado", int(oil)]


func set_mic(level: float, threshold: float, has_mic: bool) -> void:
	if has_mic:
		var bars := "|".repeat(clampi(int(level * 80.0), 0, 40))
		_mic.text = "mic %s   limiar %.2f  ([ e ] ajustam)   ou segure R" % [bars, threshold]
	else:
		_mic.text = "sem microfone: segure R para gritar"


func set_debug(text: String) -> void:
	_debug.text = text


func flash(color: Color, seconds: float) -> void:
	_overlay.color = color
	_flash_t = seconds
	_flash_len = seconds


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
		if _flash_t <= 0.0:
			_overlay.color.a = 0.0
