shader_type spatial;
// AFTERBLOOM ocean: camera-following polar grid, Gerstner swell, detail normals, depth-based
// shoreline foam + shallow-water refraction, crest foam and subsurface glow. Driven by ocean.gd.
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

#define PI 3.14159265
#define WAVES 8

uniform vec4 waves[WAVES];               // x = wavelength, y = angle (rad, relative to wind), z = steepness
uniform vec2 wind_dir = vec2(0.94, 0.34);
uniform float wave_time = 0.0;
uniform float storm : hint_range(0.0, 1.0) = 0.25;
uniform float snap = 1.0;

uniform vec3 deep_color : source_color = vec3(0.010, 0.040, 0.055);
uniform vec3 shallow_color : source_color = vec3(0.06, 0.22, 0.21);
uniform vec3 storm_color : source_color = vec3(0.030, 0.042, 0.046);
uniform vec3 sss_color : source_color = vec3(0.06, 0.30, 0.26);
uniform vec3 tint : source_color = vec3(1.0);
uniform float glow = 0.0;
uniform vec3 glow_color : source_color = vec3(0.62, 0.32, 1.0);
uniform vec3 sun_dir = vec3(0.3, 0.6, 0.5);
uniform vec3 sun_color : source_color = vec3(1.0);
uniform float sun_energy = 2.0;
uniform float absorption = 0.35;
uniform float foam_width = 0.3;

uniform int clip_mode = 1;               // 0 none, 1 landward edge only (+X local), 2 rectangle
uniform vec2 half_size = vec2(1500.0, 1500.0);

uniform sampler2D normal_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

varying vec3 v_world;
varying vec3 v_local;
varying float v_height;
varying float v_amp;
varying float v_shallow;

// Water depth below the surface at a world point, read from the depth buffer (the ocean is drawn in
// the transparent pass, so opaque depth is available). Returns 1000 when unknown / off-screen.
float floor_depth_at(vec3 wp, mat4 view, mat4 proj, mat4 inv_proj, mat4 inv_view, float sea_y) {
	vec4 clip = proj * view * vec4(wp, 1.0);
	if (clip.w <= 0.5) {
		// behind / at the camera: unknown. Treat as shallow so triangles reaching into the view
		// from behind the player can't poke above the beach.
		return 0.6;
	}
	vec3 ndc = clip.xyz / clip.w;
	// off-screen vertices reuse the nearest edge pixel so waves don't pop up at the screen border
	vec2 suv = clamp(ndc.xy * 0.5 + 0.5, vec2(0.001), vec2(0.999));
	float dr = textureLod(DEPTH_TEXTURE, suv, 0.0).r;
	if (dr <= 0.000001) {
		return 1000.0;
	}
	vec4 v = inv_proj * vec4(suv * 2.0 - 1.0, dr, 1.0);
	v.xyz /= v.w;
	float d_water = length((view * vec4(wp, 1.0)).xyz);
	if (length(v.xyz) < d_water) {
		return 1000.0;      // something in front of the water: ignore
	}
	vec3 vw = (inv_view * vec4(v.xyz, 1.0)).xyz;
	return sea_y - vw.y;
}

vec3 gerstner(vec2 p, float t, float amp_mul, float lod_dist, float lod_k, inout vec3 tangent, inout vec3 binormal) {
	vec3 disp = vec3(0.0);
	float steep_scale = mix(0.1, 0.72, storm);
	float len_scale = mix(1.0, 1.3, storm);
	for (int i = 0; i < WAVES; i++) {
		vec4 w = waves[i];
		float wl = w.x * len_scale;
		float lod = smoothstep(lod_dist * lod_k, lod_dist * lod_k * 2.5, wl);
		float s = w.z * steep_scale * amp_mul * lod;
		if (s <= 0.0001) {
			continue;
		}
		float k = 2.0 * PI / wl;
		float c = sqrt(9.81 / k);
		float ca = cos(w.y);
		float sa = sin(w.y);
		vec2 d = normalize(vec2(wind_dir.x * ca - wind_dir.y * sa, wind_dir.x * sa + wind_dir.y * ca));
		float f = k * (dot(d, p) - c * t) + float(i) * 1.7;
		float a = s / k;
		float sf = sin(f);
		float cf = cos(f);
		tangent += vec3(-d.x * d.x * s * sf, d.x * s * cf, -d.x * d.y * s * sf);
		binormal += vec3(-d.x * d.y * s * sf, d.y * s * cf, -d.y * d.y * s * sf);
		disp += vec3(d.x * a * cf, a * sf, d.y * a * cf);
	}
	return disp;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 cam = floor(CAMERA_POSITION_WORLD.xz / snap) * snap;
	vec3 wp = VERTEX;
	wp.xz += cam - origin.xz;
	// local position for clipping (assumes the node is not scaled)
	v_local = transpose(mat3(MODEL_MATRIX)) * (wp - origin);
	float dist = length(wp.xz - CAMERA_POSITION_WORLD.xz);
	float amp = 1.0 - smoothstep(300.0, 2500.0, dist);
	// waves shoal and die down in shallow water near the beach
	float fd = floor_depth_at(wp, VIEW_MATRIX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, origin.y);
	v_shallow = mix(0.05, 1.0, smoothstep(0.3, 10.0, fd));
	amp *= v_shallow;
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	vec3 disp = gerstner(wp.xz, wave_time, amp, max(dist, 1.0), 0.12, t, b);
	v_height = disp.y;
	v_amp = amp;
	wp += disp;
	VERTEX = wp;
	v_world = wp;
	NORMAL = normalize(cross(b, t));
}

void fragment() {
	if (clip_mode == 1 && v_local.x > half_size.x) {
		discard;
	}
	if (clip_mode == 2 && (abs(v_local.x) > half_size.x || abs(v_local.z) > half_size.y)) {
		discard;
	}
	vec3 cam = CAMERA_POSITION_WORLD;
	float dist = length(v_world - cam);
	vec3 vdir = normalize(v_world - cam);

	// per-pixel swell normal (small waves fade with distance to avoid shimmering)
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	gerstner(v_world.xz, wave_time, v_amp, max(dist, 1.0), 0.012, t, b);
	vec3 nw = normalize(cross(b, t));

	// detail ripples
	vec2 perp = vec2(-wind_dir.y, wind_dir.x);
	vec2 uv1 = v_world.xz * 0.045 + wind_dir * wave_time * 0.035;
	vec2 uv2 = v_world.xz * 0.13 + perp * wave_time * 0.05 - wind_dir * wave_time * 0.02;
	vec2 uv3 = v_world.xz * 0.011 + wind_dir * wave_time * 0.012;
	vec3 na = texture(normal_a, uv1).xyz * 2.0 - 1.0;
	vec3 nb = texture(normal_b, uv2).xyz * 2.0 - 1.0;
	vec3 nc = texture(normal_a, uv3).xyz * 2.0 - 1.0;
	float far = smoothstep(40.0, 900.0, dist);
	float detail = mix(0.32, 0.75, storm) * (1.0 - far * 0.75);
	vec2 dxy = (na.xy * 0.7 + nb.xy * 0.45 * (1.0 - far) + nc.xy * 0.6) * detail;
	nw = normalize(nw + vec3(dxy.x, 0.0, dxy.y));
	if (dot(nw, -vdir) < 0.02) {
		nw = normalize(nw + (-vdir) * 0.2);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	// scene depth behind the water
	float draw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, draw, 1.0);
	vp.xyz /= vp.w;
	vec3 scene_world = (INV_VIEW_MATRIX * vec4(vp.xyz, 1.0)).xyz;
	float water_depth = draw <= 0.000001 ? 1000.0 : max(v_world.y - scene_world.y, 0.0);
	float path_len = draw <= 0.000001 ? 1000.0 : max(length(vp.xyz) - length(VERTEX), 0.0);

	// refraction
	vec2 roff = dxy * 0.04 * clamp(water_depth * 0.5, 0.0, 1.0) / max(1.0, dist * 0.05);
	vec2 ruv = SCREEN_UV + roff;
	float rdraw = texture(DEPTH_TEXTURE, ruv).r;
	vec4 rvp = INV_PROJECTION_MATRIX * vec4(ruv * 2.0 - 1.0, rdraw, 1.0);
	rvp.xyz /= rvp.w;
	if (length(rvp.xyz) < length(VERTEX)) {
		ruv = SCREEN_UV;
	}
	vec3 refr = textureLod(SCREEN_TEXTURE, ruv, 0.0).rgb;

	float clarity = exp(-min(path_len, water_depth * 3.0 + path_len * 0.3) * absorption);
	vec3 body = mix(deep_color, storm_color, storm);
	vec3 shallow = mix(shallow_color, storm_color * 1.6, storm * 0.6);
	body = mix(body, shallow, exp(-water_depth * 0.25) * 0.8);
	body *= tint;

	// foam
	float ft = wave_time;
	float fa = texture(foam_tex, v_world.xz * 0.11 + wind_dir * ft * 0.03).r;
	float fb = texture(foam_tex, v_world.xz * 0.27 - wind_dir * ft * 0.05).r;
	float fpat = fa * 0.6 + fb * 0.4;
	float lace = 1.0 - fpat;      // cell borders => lacy foam network
	float fw = foam_width * (0.7 + storm * 1.3);
	float shore = 1.0 - smoothstep(0.0, fw, water_depth);
	// surf: bands of foam washing in and out over the first metre of depth
	float surf_band = exp(-water_depth / (fw * 2.0)) * pow(0.5 + 0.5 * sin(water_depth * 7.0 / fw - ft * 1.4 + fa * 2.0), 3.0);
	float shore_foam = smoothstep(0.5, 0.85, lace * 0.75 + shore * 0.45 + surf_band * 0.3) * max(shore, surf_band) * 0.9;
	float crest_h = v_height / (0.15 + storm * 0.9);
	float crest = smoothstep(0.45, 1.0, crest_h) * smoothstep(0.4, 0.7, fpat) * (0.15 + storm * 0.85) * v_amp;
	float whitecaps = storm * storm * smoothstep(0.66, 0.8, fb) * smoothstep(0.1, 0.6, crest_h) * 0.6;
	float foam = clamp(shore_foam + crest + whitecaps, 0.0, 1.0);

	float ndv = clamp(dot(nw, -vdir), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);

	// subsurface: light through wave crests when looking toward the sun
	vec3 sflat = normalize(vec3(sun_dir.x, 0.0, sun_dir.z) + vec3(1e-4));
	float toward = pow(max(dot(vdir, sflat), 0.0), 3.0);
	float sss = toward * (0.3 + max(v_height, 0.0) * 0.8) * smoothstep(-0.05, 0.2, sun_dir.y);
	vec3 sss_col = sss_color * tint * sun_color * sun_energy * sss * 0.18 * (1.0 - storm * 0.5);

	vec3 trans = refr * clarity * (1.0 - fres);
	ALBEDO = mix(body * (1.0 - clarity * 0.85), vec3(0.92, 0.95, 0.97), foam);
	EMISSION = (trans + sss_col) * (1.0 - foam) + glow_color * glow * (0.05 + 0.15 * smoothstep(0.55, 0.9, fpat)) * (1.0 - foam);
	ROUGHNESS = clamp(mix(0.035, 0.16, storm) + far * 0.06 + foam * 0.7, 0.0, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	// soft contact with the shore
	ALPHA = smoothstep(0.0, 0.12, water_depth);
}
