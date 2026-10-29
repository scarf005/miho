shader_type spatial;
// A paper cut-out: the art inside a white paper margin with a faint cut edge.
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform float border = 0.035;
uniform vec4 paper : source_color = vec4(0.984, 0.965, 0.918, 1.0);
uniform vec4 rim : source_color = vec4(0.66, 0.61, 0.53, 1.0);
uniform float flash = 0.0;
uniform float dim = 0.0;

float reach(vec2 uv, float r) {
	float m = 0.0;
	for (int i = 0; i < 16; i++) {
		float a = float(i) * 0.392699;
		m = max(m, texture(art, uv + vec2(cos(a), sin(a)) * r).a);
	}
	return m;
}

void fragment() {
	vec4 c = texture(art, UV);
	float outer = max(max(reach(UV, border), reach(UV, border * 0.5)), c.a);
	float inner = max(reach(UV, border * 0.7), c.a);
	vec3 col = mix(paper.rgb, c.rgb, c.a);
	col = mix(rim.rgb, col, step(0.5, inner));
	col = mix(col, vec3(1.0), flash);
	col = mix(col, vec3(0.55, 0.52, 0.48), dim);
	ALBEDO = col;
	ALPHA = outer;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
