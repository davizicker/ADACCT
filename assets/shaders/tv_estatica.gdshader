shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
// Tela de TV de tubo sem sinal: chuvisco animado, linhas de varredura, faixa que rola e cantos escuros.
// Edite cor e brilho no material assets/materials/tv_tela.tres.

uniform vec3 tom : source_color = vec3(0.72, 0.86, 1.0);
uniform float brilho = 1.35;
uniform float tremor = 0.0;       // sobe por um instante em "surtos" (televisao.gd)

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float quadro = floor(TIME * 30.0);
	float n = hash(floor(uv * vec2(170.0, 130.0)) + quadro);
	float n2 = hash(floor(uv * vec2(40.0, 260.0)) + quadro * 1.7);
	float scan = 0.82 + 0.18 * sin(uv.y * 420.0 + TIME * 18.0);
	float banda = smoothstep(0.0, 0.07, abs(fract(uv.y * 0.8 - TIME * 0.18) - 0.5) - 0.40) ;
	vec2 c = uv - 0.5;
	float vig = clamp(1.0 - dot(c, c) * 2.6, 0.0, 1.0);
	float v = mix(n, n2, 0.35) * (0.55 + 0.45 * banda) * scan * vig;
	v = mix(v, v * (0.5 + n * 1.6), tremor);
	ALBEDO = tom * (0.10 + 0.90 * v) * brilho;
}
