shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
// Fio de água caindo (chafariz): listras que descem. Edite as cores no material assets/materials/agua_queda.tres.

uniform vec4 cor : source_color = vec4(0.78, 0.90, 1.0, 0.7);
uniform float velocidade = 2.6;

void fragment() {
	float flow = fract(UV.y * 3.5 - TIME * velocidade + sin(UV.x * 9.0) * 0.15);
	float a = smoothstep(0.0, 0.25, flow) * smoothstep(1.0, 0.55, flow);
	float edge = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x);   // bordas suaves
	ALBEDO = cor.rgb * (0.7 + 0.3 * a);
	ALPHA = cor.a * (0.30 + 0.70 * a) * edge * smoothstep(0.0, 0.08, UV.y);
}
