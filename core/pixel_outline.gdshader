shader_type spatial;
// PX1 + PX2: the post pass of the 'Pixel' visual style. A quad in front of the low-resolution camera reads
// the depth and normal buffers (Forward+) and draws, one art pixel wide:
//   * dark outlines where the depth jumps (the silhouette of every character and prop), on the pixels of the
//     nearer surface;
//   * a lighter rim just inside the outline on the edges that face up and toward the key light (top edges);
//   * light highlight lines on convex normal creases whose face is turned to the key light;
//   * thin dark lines in concave creases.
// It runs first in the transparent pass (lowest render priority), so fire, sparks and water draw over it
// untouched and stay bright.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;

// World direction that points from the scene to the key light.
uniform vec3 light_direction = vec3(0.4, 0.8, 0.4);
// World size of one art pixel (orthographic camera).
uniform float pixel_world = 0.03;
// World size of one art pixel per unit of depth (perspective camera).
uniform float pixel_per_depth = 0.004;
// How far, in art pixels, a neighbour must fall behind the surface plane to count as a silhouette.
uniform float depth_threshold = 2.5;
uniform float outline_strength = 1.0;
// The ink of the outlines: the darkest colour of the mood palette (PixelView sets it).
uniform vec3 outline_tint : source_color = vec3(0.08, 0.05, 0.11);
uniform float highlight_strength = 0.4;
// The lighter line just inside the outline of top edges.
uniform float rim_strength = 0.3;
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.93, 0.78);
uniform float crease_strength = 0.45;
uniform float normal_threshold = 0.22;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_projection) {
	float raw = texture(depth_tex, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, raw, 1.0);
	return -view.z / view.w;
}

vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	vec3 colour = texture(screen_tex, uv).rgb;
	float raw = texture(depth_tex, uv).r;
	if (raw > 0.000001) {
		float depth = view_depth(uv, INV_PROJECTION_MATRIX);
		vec3 normal = view_normal(uv);
		bool orthographic = PROJECTION_MATRIX[3][3] != 0.0;
		float pixel = orthographic ? pixel_world : depth * pixel_per_depth;
		float threshold = depth_threshold * pixel;
		vec3 to_light = normalize((VIEW_MATRIX * vec4(light_direction, 0.0)).xyz);
		float facing = max(normal.z, 0.2);

		float outline = 0.0;
		float highlight = 0.0;
		float crease = 0.0;
		const vec2 OFFSETS[4] = vec2[4](vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(1.0, 0.0), vec2(-1.0, 0.0));
		for (int i = 0; i < 4; i++) {
			vec2 step_px = OFFSETS[i];
			vec2 neighbour_uv = uv + step_px * texel;
			float neighbour_depth = view_depth(neighbour_uv, INV_PROJECTION_MATRIX);
			// Where the surface plane through this pixel would be one pixel over (screen y points down).
			vec2 view_step = vec2(step_px.x, -step_px.y) * pixel;
			float expected = depth + dot(normal.xy, view_step) / facing;
			float behind = neighbour_depth - expected;
			// Small steps (a paving seam) get a faint line, real silhouettes the full one.
			float jump = smoothstep(threshold, threshold * 2.0, behind) * (0.3 + 0.7 * smoothstep(threshold * 2.0, threshold * 8.0, behind));
			outline = max(outline, jump);
			// Creases: same surface (no jump either way), different normal.
			float same_surface = 1.0 - smoothstep(threshold, threshold * 2.0, abs(neighbour_depth - depth) - abs(expected - depth));
			vec3 neighbour_normal = view_normal(neighbour_uv);
			float bend = smoothstep(normal_threshold, normal_threshold * 2.5, 1.0 - dot(normal, neighbour_normal)) * same_surface;
			float convex = step(0.0, dot(neighbour_normal - normal, vec3(view_step, 0.0)));
			float lit_side = step(0.0, dot(normal - neighbour_normal, to_light));
			highlight = max(highlight, bend * convex * lit_side);
			crease = max(crease, bend * (1.0 - convex) * (1.0 - lit_side));
		}
		// Top-edge rim: the pixel above (or toward the light's side) is an outline pixel of this same surface.
		float rim = 0.0;
		vec2 light_side = vec2(to_light.x > 0.0 ? 1.0 : -1.0, 0.0);
		const float RIM_WEIGHT[2] = float[2](1.0, 0.6);
		for (int i = 0; i < 2; i++) {
			vec2 step_px = i == 0 ? vec2(0.0, -1.0) : light_side;
			vec2 view_step = vec2(step_px.x, -step_px.y) * pixel;
			float slope = dot(normal.xy, view_step) / facing;
			float edge_depth = view_depth(uv + step_px * texel, INV_PROJECTION_MATRIX);
			float beyond_depth = view_depth(uv + step_px * texel * 2.0, INV_PROJECTION_MATRIX);
			float same = 1.0 - smoothstep(threshold, threshold * 2.0, abs(edge_depth - depth - slope));
			float drop = smoothstep(threshold * 2.0, threshold * 8.0, beyond_depth - edge_depth - slope);
			rim = max(rim, same * drop * RIM_WEIGHT[i]);
		}
		float lit = clamp(dot(normal, to_light), 0.0, 1.0);
		rim *= (1.0 - outline) * (0.4 + 0.6 * lit);
		highlight *= (1.0 - outline) * (0.35 + 0.65 * lit);
		crease *= (1.0 - outline);
		float luma = dot(colour, vec3(0.299, 0.587, 0.114));
		// Outlines keep a little of the surface hue (a darker, cooler shade of it), never flat black.
		vec3 ink = outline_tint + mix(vec3(luma), colour * colour / max(luma, 0.05), 0.7) * 0.035;
		colour = mix(colour, ink, outline * outline_strength);
		colour = mix(colour, colour * 0.45 + ink, crease * crease_strength);
		colour += (colour * 0.9 + vec3(0.03)) * highlight_tint * max(highlight * highlight_strength, rim * rim_strength);
	}
	ALBEDO = colour;
}
