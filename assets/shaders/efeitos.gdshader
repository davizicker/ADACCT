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
uniform float nitidez : hint_range(0.0, 1.0) = 0.38;    // máscara de nitidez (detalhe fino das pedras, reboco e folhas)
uniform float grade : hint_range(0.0, 1.0) = 0.65;      // correção de cor de cinema: sombras frias, luzes quentes, curva em S

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
	// nitidez (unsharp mask com 4 vizinhos)
	vec2 px = 1.0 / vec2(textureSize(screen_tex, 0));
	vec3 borrado = (texture(screen_tex, uv + vec2(px.x, 0.0)).rgb + texture(screen_tex, uv - vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, uv + vec2(0.0, px.y)).rgb + texture(screen_tex, uv - vec2(0.0, px.y)).rgb) * 0.25;
	col += (col - borrado) * nitidez * 1.6;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	// color grading: sombras esverdeadas/frias, luzes quentes e curva de contraste em S
	vec3 tom = mix(vec3(0.90, 1.0, 1.07), vec3(1.10, 1.0, 0.88), smoothstep(0.08, 0.75, l));
	col = mix(col, col * tom, grade);
	col = mix(col, clamp(col * col * (3.0 - 2.0 * col), 0.0, 1.0), grade * 0.35);
	col = mix(col, vec3(l) * vec3(0.88, 0.95, 1.08), fear * 0.55);
	float v = 1.0 - smoothstep(0.18, 0.62 - fear * 0.10 - pulse * 0.06, r2);
	col *= mix(1.0, 0.25 + 0.75 * v, vignette + fear * 0.25);
	col += (hash(uv * vec2(1280.0, 720.0) + fract(TIME) * 100.0) - 0.5) * grain * (1.0 + fear);
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, 1.0);
}
