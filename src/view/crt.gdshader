// A CRT over the whole screen: barrel curve, slight colour fringing, glow
// from lit glyphs, scanlines, an aperture grille and a dark rim.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float curve = 0.03;
uniform float fringe = 0.0006;
uniform float glow = 0.35;
uniform float scan = 0.18;
uniform float grille = 0.08;
uniform float rim = 0.15;
uniform float lines = 360.0;

vec3 blur(vec2 uv, vec2 px) {
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5236;
		vec2 d = vec2(cos(a), sin(a));
		sum += texture(screen, uv + d * px * 3.0).rgb;
		sum += texture(screen, uv + d * px * 8.0).rgb * 0.6;
	}
	return sum / 19.2;
}

void fragment() {
	vec2 c = SCREEN_UV * 2.0 - 1.0;
	c *= 1.0 + curve * dot(c, c);
	vec2 uv = c * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col;
		col.r = texture(screen, uv + vec2(fringe, 0.0)).r;
		col.g = texture(screen, uv).g;
		col.b = texture(screen, uv - vec2(fringe, 0.0)).b;
		vec3 halo = blur(uv, SCREEN_PIXEL_SIZE);
		col += max(halo - 0.08, 0.0) * glow;
		float s = 0.5 + 0.5 * cos(uv.y * lines * 6.2832);
		col *= 1.0 - scan * s;
		int g = int(mod(FRAGCOORD.x, 3.0));
		vec3 mask = vec3(g == 0 ? 1.0 : 1.0 - grille, g == 1 ? 1.0 : 1.0 - grille, g == 2 ? 1.0 : 1.0 - grille);
		col *= mask;
		float edge = smoothstep(0.0, 1.0, 1.0 - dot(c * 0.7, c * 0.7));
		col *= mix(1.0 - rim, 1.0, edge);
		col *= 1.0 + 0.012 * sin(TIME * 50.0);
		COLOR = vec4(col * 1.12, 1.0);
	}
}
