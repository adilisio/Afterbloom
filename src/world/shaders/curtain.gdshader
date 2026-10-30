shader_type spatial;
render_mode cull_disabled;
// Fabric curtain panel: soft vertical folds and a gentle breeze sway; translucent to sunlight.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float folds = 9.0;
uniform float depth = 0.045;

void vertex() {
	float f = sin(UV.x * folds * 6.2831);
	VERTEX.z += f * depth * (0.6 + 0.4 * UV.y);
	VERTEX.z += sin(TIME * 0.8 + UV.y * 2.0) * 0.006 * UV.y;
	NORMAL = normalize(vec3(-cos(UV.x * folds * 6.2831) * depth * folds * 2.0, 0.0, 1.0));
}

void fragment() {
	vec3 c = texture(albedo_tex, UV * vec2(1.5, 2.2)).rgb * tint.rgb;
	float shade = 0.85 + 0.15 * sin(UV.x * folds * 6.2831 + 1.2);
	ALBEDO = c * shade;
	ROUGHNESS = 0.95;
	BACKLIGHT = c * 0.55;
	SPECULAR = 0.2;
}
