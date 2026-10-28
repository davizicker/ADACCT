shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
// SOBREPOSIÇÃO (next_pass): musgo, limo ou sujeira em manchas por cima de outro material, em coordenadas do MUNDO.
// `so_topo` faz acumular mais nas faces voltadas para cima (telhados, capas de muro, degraus).

uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec3 cor : source_color = vec3(0.16, 0.28, 0.09);
uniform float cobertura : hint_range(0.0, 1.0) = 0.45;
uniform float escala = 0.35;
uniform float so_topo : hint_range(0.0, 1.0) = 0.8;
uniform float opacidade : hint_range(0.0, 1.0) = 0.8;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX += NORMAL * 0.012;          // evita brigar com a superfície de baixo
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 w = pow(abs(n), vec3(6.0));
	w /= (w.x + w.y + w.z + 1e-5);
	float m = texture(ruido, wpos.zy * escala).r * w.x + texture(ruido, wpos.xz * escala).r * w.y + texture(ruido, wpos.xy * escala).r * w.z;
	float d = texture(ruido, wpos.xz * escala * 3.1 + vec2(5.0, 9.0)).r;
	float topo = mix(1.0, smoothstep(0.1, 0.8, n.y), so_topo);
	float a = smoothstep(1.0 - cobertura, 1.0 - cobertura + 0.1, m + (d - 0.5) * 0.25) * topo;
	ALBEDO = cor * (0.75 + 0.5 * d);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	ALPHA = a * opacidade;
}
