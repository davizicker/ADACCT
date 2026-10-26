class_name LuzTremula
extends OmniLight3D
## Luz de chama (vela, lampião): a intensidade treme de leve. Edite `forca` e `velocidade` no Inspetor.

@export var forca := 0.18
@export var velocidade := 7.0

var _base := 1.0
var _seed := 0.0


func _ready() -> void:
	_base = light_energy
	_seed = randf() * 100.0


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 * velocidade + _seed
	var n := sin(t) * 0.5 + sin(t * 2.37 + 1.3) * 0.3 + sin(t * 5.1 + 4.0) * 0.2
	light_energy = _base * (1.0 + n * forca)
