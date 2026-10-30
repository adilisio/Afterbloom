shader_type sky;
// AFTERBLOOM sky: single-scattering atmosphere (Rayleigh + Mie), sun & moon discs, stars + milky band,
// two drifting 2D cloud layers, lightning bolts, Bloom tint and the chapter-2 violet cloud wall.
// All uniforms are driven by SkyWeather (sky_weather.gd).

#define PI 3.14159265

// --- sun / moon ---------------------------------------------------------------------------
uniform vec3 sun_dir = vec3(0.0, 0.7, 0.7);      // direction TO the sun (normalised)
uniform vec3 sun_color = vec3(1.0, 0.9, 0.8);            // linear
uniform float sun_disc_energy = 60.0;
uniform float sun_visibility = 1.0;               // 0 = sun dimmed (bloom event)
uniform vec3 moon_dir = vec3(0.0, -0.7, -0.7);
uniform vec3 moon_color : source_color = vec3(0.85, 0.9, 1.0);
uniform float moon_phase = 0.6;                   // radians, 0 = full
uniform float moon_energy = 1.0;

// --- atmosphere ---------------------------------------------------------------------------
uniform float sky_energy = 1.0;
uniform float haze = 1.0;                         // Mie multiplier (fog / overcast = whiter sky)
uniform float overcast = 0.0;                     // 0..1 greys the clear sky
uniform vec3 overcast_color = vec3(0.2, 0.22, 0.25);     // linear
uniform vec3 night_color : source_color = vec3(0.013, 0.023, 0.050);
uniform float night = 0.0;                        // 0 day .. 1 full night
uniform float star_energy = 1.0;
uniform vec3 ground_color = vec3(0.01, 0.012, 0.014);    // linear
uniform int quality = 2;

// --- clouds -------------------------------------------------------------------------------
uniform float cloud_coverage = 0.3;
uniform float cloud_darkness = 0.1;
uniform float cirrus = 0.4;
uniform vec2 cloud_offset = vec2(0.0);
uniform vec2 cirrus_offset = vec2(0.0);
uniform vec3 cloud_light = vec3(1.0);   // linear, sun light reaching clouds (sunset tinted, HDR)
uniform vec3 cloud_ambient = vec3(0.13, 0.17, 0.26);    // linear

// --- lightning ----------------------------------------------------------------------------
uniform float flash = 0.0;
uniform float bolt_alpha = 0.0;
uniform float bolt_azimuth = 0.0;
uniform float bolt_seed = 0.0;
uniform float bolt_height = 0.3;

// --- bloom --------------------------------------------------------------------------------
uniform vec3 bloom_color : source_color = vec3(0.55, 0.22, 1.0);
uniform float bloom_weather = 0.0;   // violet squall
uniform float bloom_event = 0.0;     // chapter-2 catastrophe (west wall)
uniform float era_after = 0.0;
uniform float anim_time = 0.0;

// ------------------------------------------------------------------------------------------
const float R_PLANET = 6371e3;
const float R_ATMOS = 6471e3;
const vec3 K_RLH = vec3(5.5e-6, 13.0e-6, 22.4e-6);
const float K_MIE = 21e-6;
const float SH_RLH = 8e3;
const float SH_MIE = 1.2e3;
const float G_MIE = 0.76;

vec2 rsi(vec3 r0, vec3 rd, float sr) {
	float b = 2.0 * dot(rd, r0);
	float c = dot(r0, r0) - sr * sr;
	float d = b * b - 4.0 * c;
	if (d < 0.0) {
		return vec2(1e9, -1e9);
	}
	float s = sqrt(d);
	return vec2((-b - s) * 0.5, (-b + s) * 0.5);
}

vec3 atmosphere(vec3 r, vec3 l, float intensity, float mie_mult, int isteps, int jsteps) {
	vec3 r0 = vec3(0.0, R_PLANET + 2.0, 0.0);
	vec2 p = rsi(r0, r, R_ATMOS);
	float pend = p.y;
	vec2 pg = rsi(r0, r, R_PLANET);
	if (pg.x > 0.0 && pg.x < pend) {
		pend = pg.x;
	}
	float step_size = pend / float(isteps);
	float mu = dot(r, l);
	float mumu = mu * mu;
	float gg = G_MIE * G_MIE;
	float p_rlh = 3.0 / (16.0 * PI) * (1.0 + mumu);
	float p_mie = 3.0 / (8.0 * PI) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * G_MIE, 1.5) * (2.0 + gg));
	float k_mie = K_MIE * mie_mult;
	vec3 total_rlh = vec3(0.0);
	vec3 total_mie = vec3(0.0);
	float od_rlh = 0.0;
	float od_mie = 0.0;
	for (int i = 0; i < isteps; i++) {
		// slightly denser sampling near the viewer
		float ti = (float(i) + 0.5) * step_size;
		vec3 pos = r0 + r * ti;
		float h = length(pos) - R_PLANET;
		float sr = exp(-h / SH_RLH) * step_size;
		float sm = exp(-h / SH_MIE) * step_size;
		od_rlh += sr;
		od_mie += sm;
		// soft earth shadow
		float along = dot(pos, l);
		float shadow = 1.0;
		if (along < 0.0) {
			float closest = length(pos - l * along);
			shadow = smoothstep(R_PLANET - 4e3, R_PLANET + 12e3, closest);
		}
		if (shadow <= 0.0) {
			continue;
		}
		float js = rsi(pos, l, R_ATMOS).y / float(jsteps);
		float jod_rlh = 0.0;
		float jod_mie = 0.0;
		for (int j = 0; j < jsteps; j++) {
			vec3 jpos = pos + l * ((float(j) + 0.5) * js);
			float jh = max(length(jpos) - R_PLANET, 0.0);
			jod_rlh += exp(-jh / SH_RLH) * js;
			jod_mie += exp(-jh / SH_MIE) * js;
		}
		// view-path extinction is reduced (cheap stand-in for multiple scattering: keeps the
		// horizon bright and pale instead of brown); the sun path stays physical for red sunsets
		vec3 attn = exp(-(k_mie * (od_mie * 0.45 + jod_mie) + K_RLH * (od_rlh * 0.5 + jod_rlh)));
		total_rlh += sr * attn * shadow;
		total_mie += sm * attn * shadow;
	}
	return intensity * (p_rlh * K_RLH * total_rlh + p_mie * k_mie * total_mie);
}

// --- noise --------------------------------------------------------------------------------
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1, 0, 0));
	float n010 = hash13(i + vec3(0, 1, 0));
	float n110 = hash13(i + vec3(1, 1, 0));
	float n001 = hash13(i + vec3(0, 0, 1));
	float n101 = hash13(i + vec3(1, 0, 1));
	float n011 = hash13(i + vec3(0, 1, 1));
	float n111 = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
			mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

const mat2 ROT = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

float fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	for (int i = 0; i < 7; i++) {
		if (i >= oct) {
			break;
		}
		s += a * vnoise(p);
		n += a;
		p = ROT * p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return s / n;
}

float fbm3(vec3 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	for (int i = 0; i < 5; i++) {
		if (i >= oct) {
			break;
		}
		s += a * vnoise3(p);
		n += a;
		p = p * 2.07 + vec3(5.1, 1.3, 7.7);
		a *= 0.5;
	}
	return s / n;
}

// billowy (cauliflower) noise: abs of signed noise gives puffs separated by dark creases
float billow3(vec3 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	for (int i = 0; i < 5; i++) {
		if (i >= oct) {
			break;
		}
		s += a * (1.0 - abs(vnoise3(p) * 2.0 - 1.0));
		n += a;
		p = p * 2.1 + vec3(3.7, 8.1, 1.9);
		a *= 0.5;
	}
	return s / n;
}

// rounded domes along x (cumulus tops): max of overlapping half-circles of random size
float domes(float x, float seed) {
	float c = floor(x);
	float best = 0.0;
	for (int i = -1; i <= 1; i++) {
		float cc = c + float(i);
		float rr = 0.5 + 0.7 * hash12(vec2(cc, seed));
		float center = cc + 0.5 + (hash12(vec2(cc, seed + 3.1)) - 0.5) * 0.6;
		float dx = (x - center) / rr;
		if (abs(dx) < 1.0) {
			best = max(best, sqrt(1.0 - dx * dx) * rr);
		}
	}
	return best;
}

// --- stars --------------------------------------------------------------------------------
float star_layer(vec3 dir, float cells, float threshold, float t) {
	vec3 p = dir * cells;
	vec3 c = floor(p);
	vec3 f = fract(p);
	float h = hash13(c);
	if (h < threshold) {
		return 0.0;
	}
	vec3 sp = vec3(hash13(c + 11.3), hash13(c + 27.1), hash13(c + 51.7)) * 0.7 + 0.15;
	float d = length(f - sp);
	float b = pow((h - threshold) / (1.0 - threshold), 3.0);
	float tw = 0.65 + 0.35 * sin(t * (2.0 + h * 5.0) + h * 91.0);
	return smoothstep(0.16, 0.0, d) * b * tw;
}

// --- lightning bolt -----------------------------------------------------------------------
float bolt_line(float az, float el, float seed, float top, float width) {
	if (el < -0.02 || el > top) {
		return 0.0;
	}
	float x = 0.0;
	float amp = 0.035;
	float fq = 9.0;
	for (int i = 0; i < 4; i++) {
		x += (vnoise(vec2(el * fq, seed + float(i) * 7.3)) - 0.5) * amp;
		amp *= 0.5;
		fq *= 2.3;
	}
	float d = abs(az - x);
	float core = smoothstep(width, 0.0, d);
	float glow = exp(-d / (width * 6.0)) * 0.35;
	float taper = smoothstep(top, top * 0.6, el);
	return (core + glow) * mix(0.6, 1.0, taper);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	bool cube = AT_CUBEMAP_PASS;
	int isteps = cube ? 10 : (quality >= 2 ? 14 : (quality == 1 ? 11 : 9));
	int jsteps = cube ? 4 : (quality >= 2 ? 5 : 4);
	int cloud_oct = cube ? 4 : (quality >= 2 ? 6 : (quality == 1 ? 5 : 4));

	float el = asin(clamp(dir.y, -1.0, 1.0));
	vec3 adir = normalize(vec3(dir.x, max(dir.y, 0.0), dir.z));
	vec3 hdir = normalize(vec3(dir.x, 0.0001, dir.z));
	float west = max(dot(hdir.xz, vec2(-1.0, 0.0)), 0.0);   // facing the sea

	// ---------------- atmosphere ----------------
	vec3 col = vec3(0.0);
	if (sun_dir.y > -0.3) {
		col += atmosphere(adir, sun_dir, 22.0 * sky_energy, haze, isteps, jsteps);
	}
	// moonlit sky (very faint, bluish) and base night colour
	if (night > 0.0) {
		vec3 moon_sky = atmosphere(adir, normalize(moon_dir + vec3(0.0, 0.02, 0.0)), 22.0 * sky_energy, haze, cube ? 6 : 8, 3);
		col += night * (moon_sky * 0.012 * moon_energy * vec3(0.8, 0.9, 1.15));
		float zen = pow(max(dir.y, 0.0), 0.5);
		col += night * mix(night_color * 1.6, night_color, zen);
	}
	// overcast greying (keeps some of the luminance structure)
	col = mix(col, overcast_color * (0.8 + 0.2 * smoothstep(0.0, 0.6, dir.y)), overcast);

	// era "after": faint violet haze low on the horizon
	float horizon_band = exp(-max(dir.y, 0.0) * 9.0);
	col += era_after * bloom_color * horizon_band * 0.22 * (0.3 + 0.7 * (1.0 - night)) * sky_energy;

	// bloom squall: violet-tinted, eerie
	if (bloom_weather > 0.0) {
		float bl = dot(col, vec3(0.3, 0.5, 0.2));
		vec3 eerie = bl * vec3(0.75, 0.55, 1.1) + bloom_color * 0.12 * (0.4 + horizon_band) * sky_energy * (1.0 - night * 0.6);
		col = mix(col, eerie, bloom_weather * 0.8);
		col += bloom_color * bloom_weather * 0.3 * horizon_band * sky_energy * (1.0 - night * 0.5);
	}

	// ---------------- stars, milky band, moon ----------------
	vec3 space = vec3(0.0);
	if (!cube && night > 0.0 && dir.y > -0.05) {
		float st = star_layer(dir, 150.0, 0.86, TIME) + star_layer(dir, 300.0, 0.90, TIME * 1.3) * 0.6;
		vec3 band_n = normalize(vec3(0.35, 0.5, 0.8));
		float band = exp(-pow(dot(dir, band_n) / 0.22, 2.0));
		float milky = band * fbm3(dir * 6.0, 4);
		milky = smoothstep(0.35, 0.8, milky) * band;
		float hz = smoothstep(-0.02, 0.25, dir.y);
		space += (vec3(1.0, 0.97, 0.92) * st * 1.8 + vec3(0.55, 0.6, 0.85) * milky * 0.035) * hz;
		space *= night * star_energy;
	}
	// moon
	vec3 mdir = normalize(moon_dir);
	float mcos = dot(dir, mdir);
	float moon_r = 0.021;
	if (moon_energy > 0.0) {
		float ang = acos(clamp(mcos, -1.0, 1.0));
		vec3 mt = normalize(cross(mdir, vec3(0.0, 1.0, 0.0)));
		vec3 mb = cross(mt, mdir);
		vec2 uv = vec2(dot(dir, mt), dot(dir, mb)) / moon_r;
		if (ang < moon_r) {
			float z = sqrt(max(1.0 - dot(uv, uv), 0.0));
			vec3 n = vec3(uv, z);
			vec3 L = vec3(sin(moon_phase), 0.15, cos(moon_phase));
			float lit = smoothstep(-0.08, 0.15, dot(n, normalize(L)));
			float maria = fbm(uv * 2.5 + 3.0, 4);
			float alb = mix(0.55, 1.0, smoothstep(0.35, 0.65, maria));
			float limb = mix(0.75, 1.0, z);
			vec3 mc = moon_color * alb * limb * (lit + 0.03) * 1.1;
			float edge = smoothstep(moon_r, moon_r * 0.93, ang);
			space = mix(space, mc * moon_energy, edge);
		}
		float halo = exp(-max(ang - moon_r, 0.0) * 28.0) * 0.12 + exp(-max(ang - moon_r, 0.0) * 6.0) * 0.03;
		col += moon_color * halo * moon_energy * smoothstep(-0.05, 0.05, mdir.y);
	}
	// sun disc
	float sun_r = 0.0105;
	float scos = dot(dir, sun_dir);
	float sang = acos(clamp(scos, -1.0, 1.0));
	vec3 sun_disc = vec3(0.0);
	if (sang < sun_r * 1.2) {
		float t = clamp(sang / sun_r, 0.0, 1.0);
		float limb = 1.0 - 0.45 * (1.0 - sqrt(max(1.0 - t * t, 0.0)));
		float edge = smoothstep(sun_r * 1.04, sun_r * 0.96, sang);
		sun_disc = sun_color * sun_disc_energy * limb * edge * sun_visibility;
	}
	// atmospheric attenuation of the disc near horizon is already in sun_color (script)
	if (dir.y < 0.0) {
		space = vec3(0.0);
		sun_disc *= smoothstep(-0.01, 0.0, dir.y);
	}
	col += space;
	col += sun_disc;

	// ---------------- clouds ----------------
	float cloud_a = 0.0;
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.11);
		float hfade = smoothstep(0.0, 0.14, dir.y);
		vec3 amb = mix(cloud_ambient, col * 0.9 + cloud_ambient * 0.3, 0.35);
		// cirrus (high, streaky)
		if (cirrus > 0.0) {
			vec2 cu = ROT * uv * vec2(0.45, 1.9) * 0.9 + cirrus_offset;
			float cn = fbm(cu, cube ? 3 : 4);
			float ca = smoothstep(0.52, 0.85, cn) * cirrus * 0.55 * hfade * (1.0 - cloud_coverage * 0.6);
			vec3 cc = cloud_light * 0.9 + amb * 0.6;
			col = mix(col, cc, ca);
		}
		// main layer
		vec2 p = uv * 1.25 + cloud_offset;
		float n = fbm(p, cloud_oct);
		// broad modulation so coverage is patchy
		float big = vnoise(p * 0.18 + 3.1);
		n = n * 0.85 + big * 0.15;
		float center = mix(0.78, 0.22, cloud_coverage);
		float soft = mix(0.10, 0.22, cloud_coverage);
		float d = smoothstep(center - soft * 0.5, center + soft, n);
		// self-shadowing: sample toward the sun / moon
		vec3 ldir = sun_dir.y > -0.12 ? sun_dir : mdir;
		vec2 toward = normalize(ldir.xz + vec2(1e-4)) * 0.06;
		float n2 = fbm(p + toward, max(cloud_oct - 2, 2)) * 0.85 + big * 0.15;
		float shade = exp(-max(n2 - n + 0.02, 0.0) * 9.0);
		float thick = smoothstep(center - 0.05, center + 0.3, n);
		// heavy skies are one thick deck seen from below: no bright sunlit tops, darker base
		float deck = cloud_coverage * cloud_darkness;
		thick = mix(thick, 0.55 + 0.45 * thick, deck);
		// silver lining toward the light
		float ph = pow(max(dot(dir, ldir), 0.0), 10.0) * (1.0 - thick) * 2.5;
		vec3 lit = cloud_light * (0.35 + 0.75 * shade + ph) * (1.0 - deck * 0.85) + amb * 0.9;
		vec3 dark = amb * mix(0.85, 0.3, cloud_darkness);
		vec3 cc = mix(lit, dark, clamp(thick * (0.35 + cloud_darkness * 0.75), 0.0, 1.0));
		// bloom: violet glow from below
		cc += bloom_color * (bloom_weather * 0.32 + bloom_event * 0.3 * west) * (0.4 + thick) * sky_energy * (0.45 + 0.55 * (1.0 - night));
		// lightning illuminates clouds
		float az = atan(dir.x, -dir.z);
		float adelta = abs(mod(az - bolt_azimuth + PI, 2.0 * PI) - PI);
		cc += vec3(0.75, 0.8, 1.0) * flash * (2.8 * exp(-adelta * 2.2) + 0.12) * (0.4 + thick);
		cloud_a = clamp(d * hfade, 0.0, 1.0);
		col = mix(col, cc, cloud_a);
	}

	// lightning bolt below the clouds + general sky flash
	if (bolt_alpha > 0.0) {
		float az = atan(dir.x, -dir.z);
		float adelta = mod(az - bolt_azimuth + PI, 2.0 * PI) - PI;
		float b = bolt_line(adelta, el, bolt_seed, bolt_height, 0.0016);
		// branch
		float br_start = bolt_height * 0.55;
		if (el < br_start) {
			float k = (br_start - el);
			b += bolt_line(adelta - k * 0.45, el, bolt_seed + 3.7, br_start, 0.0011) * 0.55 * smoothstep(0.0, 0.05, k) * smoothstep(br_start * 0.9, br_start * 0.4, br_start - el + 0.0);
		}
		col += vec3(0.85, 0.88, 1.0) * b * bolt_alpha * 18.0;
	}
	col += vec3(0.6, 0.65, 0.85) * flash * 0.1 * smoothstep(-0.1, 0.3, dir.y);

	// ---------------- bloom event: violet sky over the sea + towering cloud wall ----------------
	if (bloom_event > 0.0) {
		float be = bloom_event;
		float sea = pow(west, 1.5);
		vec3 vio = bloom_color * sky_energy;
		// the dome darkens and shifts violet as the event grows
		col *= mix(vec3(1.0), vec3(0.5, 0.36, 0.72), be * 0.85);
		// luminous aura low over the sea, climbing with t
		float aura_h = mix(0.05, 0.45, be);
		col += vio * sea * exp(-max(dir.y, 0.0) / aura_h) * be * 1.3;
		col += vio * be * be * 0.18 * exp(-max(dir.y, 0.0) * 1.5);
		// towering cumulonimbus wall on the western horizon
		float az = atan(dir.z, -dir.x);   // 0 = due west
		float span = smoothstep(2.2, 0.9, abs(az));
		float hb = mix(0.03, 0.5, pow(be, 0.8)) * span;
		float drift = anim_time * 0.004;
		float wall_top = hb * (0.5 + 0.38 * domes(az * 2.6 + drift, 1.0) + 0.16 * domes(az * 8.0 - drift * 2.0, 2.0) + 0.06 * domes(az * 23.0, 3.0));
		if (hb > 0.002 && dir.y < wall_top + 0.03 && dir.y > -0.05) {
			float y = max(dir.y, 0.0);
			float k = clamp(2.6 / max(hb, 0.03), 4.0, 60.0);
			vec3 q = vec3(az * k, (y - anim_time * 0.002) * k, anim_time * 0.02);
			int oct = (quality >= 1 && !cube) ? 4 : 3;
			float bl = billow3(q, oct);
			float top = wall_top + (bl - 0.6) * 0.03 * hb;
			float inside = smoothstep(top + 0.004, top - 0.006, y);
			float yn = clamp(y / max(top, 0.001), 0.0, 1.0);
			// puffs catch the dimmed morning sun (behind the viewer), creases fall to deep indigo
			float puff = smoothstep(0.2, 0.95, bl);
			vec3 indigo = vec3(0.03, 0.008, 0.075) * sky_energy;
			vec3 lit_c = vec3(0.26, 0.13, 0.42) * sky_energy * (0.35 + 0.65 * yn);
			vec3 wc = mix(indigo, lit_c, puff);
			// luminous violet base where the spore fog boils off the sea, and a thin glowing rim
			float base = exp(-yn * 5.0);
			float rim = smoothstep(0.88, 1.0, yn) * puff;
			wc += vio * (base * 1.9 * (0.55 + 0.45 * puff) + rim * 0.6);
			// slow internal violet flashes
			float fl = clamp(vnoise(vec2(az * 3.0, anim_time * 1.3)) * 2.4 - 1.5, 0.0, 1.0);
			wc += vio * fl * fl * 5.0 * puff * (1.0 - yn * 0.5) * be;
			col = mix(col, wc, inside * smoothstep(0.0, 0.12, be));
			col += vio * be * 0.3 * exp(-max(y - top, 0.0) / (0.05 * hb + 0.008)) * (1.0 - inside);
		}
	}

	// below the horizon: ocean/ground ambient (mostly hidden by geometry; feeds reflections/ambient)
	if (dir.y < 0.0) {
		float gd = smoothstep(0.0, -0.6, dir.y);
		col = mix(col, ground_color, gd);
	}
	COLOR = max(col, vec3(0.0));
}
