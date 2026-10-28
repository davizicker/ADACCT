class_name Menu
extends CanvasLayer
## Menu inicial e de pausa (Esc). Funciona com o jogo pausado. Opções são salvas (scripts/config.gd).

signal options_changed
signal restart_requested
signal continue_requested

var started := false
var _dim: ColorRect
var _main_box: VBoxContainer
var _opts_box: VBoxContainer
var _title: Label
var _play_btn: Button
var _restart_btn: Button


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.02, 0.78)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	sb.border_color = Color(0.85, 0.65, 0.3, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(520, 0)
	panel.add_child(stack)

	_title = _lbl("BRADADOR", 54, Color(0.95, 0.78, 0.4))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_title)
	var sub := _lbl("Use fones de ouvido. Quando o Bradador gritar, agache e fique quieto.\nEntre nas casas, ache o que a igreja precisa e chegue lá antes do amanhecer.", 16, Color(0.75, 0.75, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(sub)
	stack.add_child(HSeparator.new())

	_main_box = VBoxContainer.new()
	stack.add_child(_main_box)
	if SaveGame.existe():
		_main_box.add_child(_btn("Continuar", func() -> void: continue_requested.emit()))
	_play_btn = _btn("Novo jogo" if SaveGame.existe() else "Jogar", func() -> void:
		if SaveGame.existe():
			SaveGame.apagar()
			restart_requested.emit()
		else:
			close())
	_main_box.add_child(_play_btn)
	_main_box.add_child(_btn("Opções", _show_options))
	_restart_btn = _btn("Recomeçar", func() -> void: restart_requested.emit())
	_main_box.add_child(_restart_btn)
	_main_box.add_child(_btn("Sair", func() -> void: get_tree().quit()))
	var help := _lbl("WASD andar · Shift correr · Ctrl agachar · F lanterna · E interagir/entrar", 14, Color(0.6, 0.6, 0.66))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_box.add_child(help)

	_opts_box = VBoxContainer.new()
	_opts_box.visible = false
	stack.add_child(_opts_box)
	_build_options()
	open(true)


func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b


func _slider(label: String, value: float, lo: float, hi: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var l := _lbl(label, 18, Color(0.85, 0.85, 0.9))
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = value
	s.custom_minimum_size = Vector2(240, 0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		options_changed.emit())
	row.add_child(s)
	_opts_box.add_child(row)


func _build_options() -> void:
	_slider("Volume geral", Config.master, 0.0, 1.0, func(v: float) -> void: Config.master = v)
	_slider("Música / tensão", Config.music, 0.0, 1.0, func(v: float) -> void: Config.music = v)
	_slider("Efeitos e ambiente", Config.effects, 0.0, 1.0, func(v: float) -> void: Config.effects = v)
	_slider("Sensibilidade do mouse", Config.mouse_sens, 0.0008, 0.006, func(v: float) -> void: Config.mouse_sens = v)
	_slider("Limiar do microfone", Config.mic_threshold, 0.01, 0.3, func(v: float) -> void: Config.mic_threshold = v)
	_slider("Resolução de renderização (FSR)", Config.escala_3d, 0.5, 1.0, func(v: float) -> void: Config.escala_3d = v)
	var row := HBoxContainer.new()
	var l := _lbl("Qualidade gráfica", 18, Color(0.85, 0.85, 0.9))
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var ob := OptionButton.new()
	ob.add_item("Baixa (PC fraco)")
	ob.add_item("Média (recomendada)")
	ob.add_item("Alta (placa forte)")
	ob.select(Config.quality)
	ob.item_selected.connect(func(i: int) -> void:
		Config.quality = i
		options_changed.emit())
	row.add_child(ob)
	_opts_box.add_child(row)
	var cr := CheckBox.new()
	cr.text = "Chuva"
	cr.button_pressed = Config.chuva
	cr.toggled.connect(func(on: bool) -> void:
		Config.chuva = on
		options_changed.emit())
	_opts_box.add_child(cr)
	var cg := CheckBox.new()
	cg.text = "Responder o grito gritando (microfone ou tecla R) em vez de agachar"
	cg.button_pressed = Config.grito_ativo
	cg.toggled.connect(func(on: bool) -> void:
		Config.grito_ativo = on
		options_changed.emit())
	_opts_box.add_child(cg)
	var ct := CheckBox.new()
	ct.text = "MODO DE TESTE: imortal (Bradador e Mula não te matam). Também: tecla F9 no jogo"
	ct.button_pressed = Config.modo_teste
	ct.toggled.connect(func(on: bool) -> void:
		Config.modo_teste = on
		options_changed.emit())
	_opts_box.add_child(ct)
	var c1 := CheckBox.new()
	c1.text = "Efeitos de câmera (vinheta, granulado, medo)"
	c1.button_pressed = Config.camera_fx
	c1.toggled.connect(func(on: bool) -> void:
		Config.camera_fx = on
		options_changed.emit())
	_opts_box.add_child(c1)
	var c2 := CheckBox.new()
	c2.text = "Balanço da câmera ao andar"
	c2.button_pressed = Config.head_bob
	c2.toggled.connect(func(on: bool) -> void:
		Config.head_bob = on
		options_changed.emit())
	_opts_box.add_child(c2)
	_opts_box.add_child(_btn("Voltar", _show_main))


func _show_options() -> void:
	_main_box.visible = false
	_opts_box.visible = true


func _show_main() -> void:
	_opts_box.visible = false
	_main_box.visible = true
	Config.save_all()


func open(initial := false) -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main()
	_play_btn.text = "Jogar" if initial else "Continuar"
	_restart_btn.visible = not initial


func close() -> void:
	started = true
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Config.save_all()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and started:
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open(false)
