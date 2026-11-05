extends SceneTree
## Exporta os sons sintetizados para .wav (para analisar o espectro): godot --headless --script res://tools/audio_export.gd -- <pasta>
func _init() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	var itens := {
		"passo_a": Synth.step(0), "passo_b": Synth.step(3), "passo_suave": Synth.step(20, true), "passo_madeira": Synth.step_wood(1),
		"grito": Synth.scream(), "sino": Synth.bell(), "vento": Synth.wind(), "grilos": Synth.crickets(), "coruja": Synth.owl(),
	}
	for k in itens:
		(itens[k] as AudioStreamWAV).save_to_wav("%s/%s.wav" % [dir, k])
		print("ok ", k)
	quit()
