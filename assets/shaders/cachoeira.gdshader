shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
// CORTINA DE CACHOEIRA: fios de água verticais que descem (UV.x = largura, UV.y = 0 no topo e 1 embaixo), espuma mais densa no pé e no topo.
// Edite as cores no material assets/materials/cachoeira.tres.

uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec3 cor : source_color = vec3(0.66, 0.80, 0.90);
uniform float velocidade = 1.6;

void fragment() {
	float t = TIME * velocidade;
	float a = texture(ruido, vec2(UV.x * 5.0, UV.y * 1.3 - t * 0.55)).r;
	float b = texture(ruido, vec2(UV.x * 13.0 + 3.1, UV.y * 2.6 - t * 1.0)).r;
	float c = texture(ruido, vec2(UV.x * 27.0 + 7.7, UV.y * 4.0 - t * 1.7)).r;
	float fio = a * 0.5 + b * 0.32 + c * 0.18;
	float dens = smoothstep(0.34, 0.80, fio);
	float borda = smoothstep(0.0, 0.10, UV.x) * smoothstep(1.0, 0.90, UV.x);
	float topo = smoothstep(0.0, 0.10, UV.y);
	float pe = smoothstep(0.62, 1.0, UV.y);                       // espuma branca perto do poço
	ALBEDO = mix(cor, vec3(0.95, 0.98, 1.0), pe * 0.8 + c * 0.25);
	ALPHA = clamp(dens * 0.85 + pe * 0.35, 0.0, 0.92) * borda * topo;
}
