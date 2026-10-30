shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Leaf cards / pine cards / grass blades: alpha-scissor, wind sway, colour variation, backlit translucency.

uniform sampler2D alpha_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 color_a : source_color = vec4(0.8, 0.35, 0.12, 1.0);
uniform vec4 color_b : source_color = vec4(0.95, 0.7, 0.2, 1.0);
uniform float wind = 1.0;
uniform float sway_height = 3.0;
uniform float is_grass = 0.0;
uniform float alpha_cut = 0.45;

varying float vvar;
varying float vh;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 inst = MODEL_MATRIX[3].xyz;
	float h = is_grass > 0.5 ? UV.y : clamp(VERTEX.y / sway_height, 0.0, 1.5);
	if (is_grass > 0.5) { h = 1.0 - UV.y; }
	vh = h;
	float t = TIME * (1.2 + 0.3 * sin(inst.x * 0.1));
	float s = sin(t + wp.x * 0.35 + wp.z * 0.21) * 0.6 + sin(t * 2.3 + wp.z * 0.7) * 0.25;
	float flutter = sin(TIME * 7.0 + wp.x * 3.1 + wp.y * 2.7) * 0.02 * (1.0 - is_grass);
	vec3 off = vec3(s * 0.05, 0.0, s * 0.035) * wind * h * h + vec3(flutter, flutter * 0.5, flutter);
	if (is_grass > 0.5) { off *= 4.0; }
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * off);
	vvar = fract(sin(dot(inst.xz + floor(wp.xz * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 a = texture(alpha_tex, UV);
	if (a.a < alpha_cut) { discard; }
	vec3 base = mix(color_a.rgb, color_b.rgb, clamp(vvar * 1.2 - 0.1 + (a.r - 0.8), 0.0, 1.0));
	base *= a.r;
	if (is_grass > 0.5) { base *= mix(0.7, 1.1, vh); }
	ALBEDO = base;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = base * 0.6;
	AO = mix(0.75, 1.0, vh);
	AO_LIGHT_AFFECT = 0.4;
}
