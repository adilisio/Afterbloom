shader_type spatial;
// Terrain splat: grass / dry grass on flats, dirt patches, sand near the sea, rock on steep slopes.

uniform sampler2D grass_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass2_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform float after = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_rock(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 a = texture(rock_alb, p.zy / 6.0).rgb * w.x + texture(rock_alb, p.xz / 6.0).rgb * w.y + texture(rock_alb, p.xy / 6.0).rgb * w.z;
	return a;
}

void fragment() {
	vec2 uv = wpos.xz;
	float m1 = texture(macro, uv / 180.0).r;
	float m2 = texture(macro, uv / 37.0 + vec2(0.3, 0.7)).r;
	float slope = 1.0 - wnrm.y;

	// anti-tiling: mix two scales/rotations of grass
	vec2 uvr = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv;
	vec3 g = mix(texture(grass_alb, uv / 3.1).rgb, texture(grass_alb, uvr / 5.3).rgb, 0.45);
	vec3 g2 = texture(grass2_alb, uv / 4.0).rgb;
	g = mix(g, g2, smoothstep(0.45, 0.75, m1) * 0.6);
	// autumn tint variation (before) / sickly lilac tint (after)
	vec3 autumn = mix(vec3(1.0, 0.97, 0.88), vec3(0.88, 1.02, 0.86), m2);
	vec3 sick = mix(vec3(0.95, 0.88, 0.95), vec3(0.85, 0.8, 0.9), m2);
	g *= mix(autumn, sick, after);
	vec3 d = texture(dirt_alb, uv / 4.0).rgb;
	vec3 s = texture(sand_alb, uv / 4.0).rgb;
	vec3 r = tri_rock(wpos, wnrm);

	float sand_w = 1.0 - smoothstep(2.4, 3.6, wpos.y + (m2 - 0.5) * 1.6);
	float dirt_w = smoothstep(0.55, 0.8, m2 * 0.7 + m1 * 0.5) * 0.7 + smoothstep(0.18, 0.3, slope) * 0.6;
	float rock_w = smoothstep(0.32, 0.5, slope + (m1 - 0.5) * 0.15);
	dirt_w = clamp(dirt_w, 0.0, 1.0);

	vec3 col = mix(g, d, dirt_w);
	vec3 nrm = mix(texture(grass_nrm, uv / 3.1).rgb, texture(dirt_nrm, uv / 4.0).rgb, dirt_w);
	col = mix(col, s, sand_w);
	nrm = mix(nrm, texture(sand_nrm, uv / 4.0).rgb, sand_w);
	col = mix(col, r, rock_w);
	nrm = mix(nrm, texture(rock_nrm, wpos.xz / 6.0).rgb, rock_w * 0.5);
	// wet sand near the water line
	float wet = 1.0 - smoothstep(0.2, 1.2, wpos.y);
	col *= mix(1.0, 0.6, wet);

	ALBEDO = col * (0.85 + m1 * 0.3);
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(0.92, 0.35, wet);
	SPECULAR = 0.3;
}
