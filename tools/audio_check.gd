extends SceneTree
## Confere os sons sintetizados: duração, pico, volume médio (RMS), proporção de "clipping" e se há valores inválidos.
## godot --headless --path . --script res://tools/audio_check.gd

func _stats(name: String, w: AudioStreamWAV) -> void:
	var d := w.data
	var n := d.size() / 2
	var peak := 0.0
	var sum := 0.0
	var clipped := 0
	for i in n:
		var v := float(d.decode_s16(i * 2)) / 32768.0
		peak = maxf(peak, absf(v))
		sum += v * v
		if absf(v) > 0.999:
			clipped += 1
	var rms := sqrt(sum / maxf(n, 1))
	var flag := ""
	if peak < 0.05:
		flag += " MUITO BAIXO"
	if clipped > n * 0.001:
		flag += " CLIPPING"
	print("%-10s dur=%.2fs pico=%.2f rms=%.3f loop=%s%s" % [name, n / float(w.mix_rate), peak, rms, str(w.loop_mode != 0), flag])


func _init() -> void:
	_stats("scream", Synth.scream())
	_stats("wind", Synth.wind())
	_stats("bell", Synth.bell())
	for i in 4:
		_stats("step%d" % i, Synth.step(i))
	_stats("dog", Synth.dog())
	_stats("crickets", Synth.crickets())
	_stats("heartbeat", Synth.heartbeat())
	_stats("breath", Synth.breath())
	_stats("creak", Synth.creak())
	_stats("drone", Synth.drone())
	_stats("water", Synth.water())
	_stats("gallop", Synth.gallop())
	_stats("neigh", Synth.neigh())
	_stats("fire", Synth.fire())
	_stats("whisper", Synth.whisper())
	_stats("sting", Synth.sting())
	quit()
