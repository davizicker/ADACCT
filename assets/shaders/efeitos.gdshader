shader_type canvas_item;
// Efeitos de câmera em tela cheia: vinheta, granulado de filme, aberração cromática e "medo"
// (dessatura, escurece as bordas e pulsa no ritmo do coração). Controlados por scripts/hud.gd.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette : hint_range(0.0, 1.0) = 0.55;
uniform float grain : hint_range(0.0, 0.2) = 0.045;
uniform float aberration : hint_range(0.0, 0.02) = 0.0006;
uniform float fear : hint_range(0.0, 1.0) = 0.0;
uniform float heartbeat = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	float pulse = pow(0.5 + 0.5 * sin(TIME * 6.2832 * heartbeat), 6.0) * fear;
	vec2 off = c * (aberration + 0.006 * fear + 0.004 * pulse) * (1.0 + 5.0 * r2);
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l) * vec3(0.88, 0.95, 1.08), fear * 0.55);
	float v = 1.0 - smoothstep(0.18, 0.62 - fear * 0.10 - pulse * 0.06, r2);
	col *= mix(1.0, 0.25 + 0.75 * v, vignette + fear * 0.25);
	col += (hash(uv * vec2(1280.0, 720.0) + fract(TIME) * 100.0) - 0.5) * grain * (1.0 + fear);
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, 1.0);
}
