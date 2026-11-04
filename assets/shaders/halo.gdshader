shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Brilho de luz (lampião, vela): um quadrado virado para a câmera com queda radial CALCULADA (sem textura), sempre suave, de perto e de longe.
uniform vec4 cor : source_color = vec4(1.0, 0.7, 0.32, 0.55);
uniform float expoente = 2.4;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	float f = pow(1.0 - d, expoente);
	f *= 1.0 - smoothstep(0.85, 1.0, d);
	ALBEDO = cor.rgb * f * cor.a * 1.6;
	ALPHA = 1.0;
}
