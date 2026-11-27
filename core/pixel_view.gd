class_name PixelView
extends CanvasLayer
## PX1 + PX2: the 'Pixel' visual style (the default look; 'Painterly' stays selectable in Settings).
## Add a PixelView next to a 3D world (as a child of the node that holds the camera, the lights and the
## WorldEnvironment). It then:
##   * renders that same world (the shared World3D, nothing is re-parented) into a low-resolution SubViewport,
##     by default 4 screen pixels per art pixel at 1080p (480 x 270), and shows it upscaled with nearest filtering
##     on a CanvasLayer below every UI layer, so the HUD, dialogue and Devanagari text stay at full resolution;
##   * mirrors the host viewport's current camera each frame; an orthographic camera is snapped to the art-pixel
##     grid in camera space (for any yaw) and the upscaled image is shifted by the sub-pixel remainder, so
##     panning is smooth and static pixels never shimmer;
##   * maps every art pixel to a curated, limited palette of the level's mood (dawn, day, dusk, night, inferno)
##     with a world-anchored 4x4 ordered (Bayer) dither on the transitions between two shades;
##   * draws 1-art-pixel dark outlines, lighter top-edge highlights and crease lines with
##     core/pixel_outline.gdshader, hardens the key light's shadows, turns the light bands of the shared Materials
##     into pure steps with stronger hue-shifted shadows, and drops the effects that smear pixels (glow, SSAO,
##     SSIL, SDFGI, volumetric fog; depth fog is thinned);
##   * uses finer art pixels by itself when the camera is close (a small orthographic size, or a perspective
##     cutscene camera), so faces and ornaments stay legible;
##   * switches 3D drawing off in the host viewport while it exists, and restores everything when it leaves.
## Use one PixelView per host viewport. Several views in different viewports may coexist: the global material
## tuning and shadow filter are reference-counted and restored when the last view leaves the tree.

const DEFAULT_ART_PIXEL: int = 4
const REFERENCE_HEIGHT: int = 1080
## Extra art pixels rendered around the visible image, so the sub-pixel shift never shows an empty border.
const MARGIN: int = 1
const VIEW_LAYER: int = -10
## Render layer (1-based) that only the pixel camera's post pass uses.
const POST_RENDER_LAYER: int = 20
const OUTLINE_SHADER_PATH: String = "res://core/pixel_outline.gdshader"
const KEY_LIGHT_NAME: StringName = &"Sun"
## How much of the depth fog survives in the pixel style.
const FOG_KEEP: float = 0.3
const SATURATION_BOOST: float = 1.08
const BRIGHTNESS_BOOST: float = 0.97
## Screen pixels per art pixel (at 1080p) for close views, so faces and ornaments stay legible.
const CLOSE_ART_PIXEL: int = 2
const MID_ART_PIXEL: int = 3
## Orthographic sizes below which the view steps down to MID_ART_PIXEL and then CLOSE_ART_PIXEL.
const MID_ORTHO_SIZE: float = 6.5
const CLOSE_ORTHO_SIZE: float = 4.8
## The size must pass a threshold by this fraction before the pixel size changes (no flapping while zooming).
const DETAIL_HYSTERESIS: float = 0.06

## The moods that have a curated palette. Other moods borrow one (see resolve_palette_mood).
const PALETTE_MOODS: Array[StringName] = [&"dawn", &"day", &"dusk", &"night", &"inferno"]
const DEFAULT_PALETTE_MOOD: StringName = &"day"
## The most colours a palette may hold (the size of the shader's array).
const MAX_PALETTE: int = 64
## Width of the world-anchored 4x4 ordered dither. A colour between two palette colours sits at 0 (on the
## nearest) to 0.5 (half-way); only colours within DITHER / 2 of half-way are dithered between the two, so the
## transitions dither and flat areas stay flat.
const DITHER: float = 0.1
## Matching weights: a colour may change shade (brightness) more easily than hue.
const LUMA_WEIGHT: float = 1.0
const CHROMA_WEIGHT: float = 2.6
## Palette entries closer than this (RGB distance) are merged.
const PALETTE_MIN_DISTANCE: float = 0.06
## How much the shared materials' coloured shadow is strengthened (hue-shifted shadows, never grey).
const SHADOW_BOOST: float = 1.7

const _BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const _BORROWED_MOODS: Dictionary[StringName, StringName] = {&"divine": &"dawn"}
## The hue families of the game (DESIGN §6.1) as mid-tones. Every mood grades them and builds a 4-shade ramp.
const _RAMP_BASES: Array[Color] = [
	Color("#D9A05E"),  # sand, sunlit earth
	Color("#A8603A"),  # terracotta, bark, brick
	Color("#B8A88A"),  # stone
	Color("#7FA63A"),  # sunlit grass
	Color("#2E7D4F"),  # grove green
	Color("#F28C28"),  # saffron
	Color("#E9B949"),  # gold
	Color("#D7263D"),  # sindoor, Ashoka red
	Color("#C98B3B"),  # Hanuman's fur
	Color("#5A4A86"),  # rakshasa violet
	Color("#2A7D9C"),  # ocean
	Color("#8FC3E0"),  # sky
	Color("#D8C9B0"),  # marble, moonlit white
	Color("#7C8DA0"),  # slate, sea foam shadow, cool stone
]
## Ramps that are lit by their own fire (lamps, gold, flames): the mood grade touches them only half as much.
const _WARM_ACCENTS: Array[int] = [5, 6, 7]

const _DIRECTIONAL_FILTER_SETTING: String = "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
const _POSITIONAL_FILTER_SETTING: String = "rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality"

const _MATERIAL_SUFFIXES: Array[String] = ["", "_local", "_world"]
## Shared painterly material uniforms retuned for chunky pixels: hard light bands, no screen-space bevel
## highlights (the post pass draws them) and calmer grain.
const _TUNED_ABSOLUTE: Dictionary[StringName, float] = {&"band_softness": 0.012, &"band_continuous": 0.0, &"edge_strength": 0.0}
const _TUNED_SCALED: Dictionary[StringName, float] = {
	&"detail_strength": 0.3, &"cavity_strength": 0.5, &"band_wobble": 0.6, &"value_variation": 0.55, &"hue_variation": 0.5,
	&"shadow_strength": SHADOW_BOOST,
}

const _UPSCALE_SHADER: String = """shader_type canvas_item;
// Nearest upscale of the low-resolution world. Every art pixel is matched to the mood's palette (the same
// maths as PixelView.quantise_dithered). The 4x4 ordered dither is anchored to the world (grid_origin = the
// snapped camera position in art pixels), so it never crawls while the camera pans.
uniform vec3 palette[64];
uniform int palette_size = 0;
uniform float dither = 0.1;
uniform float luma_weight = 1.0;
uniform float chroma_weight = 2.6;
uniform vec2 grid_origin = vec2(0.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec3 colour = texture(TEXTURE, UV).rgb;
	if (palette_size > 0) {
		vec2 cell = mod(floor(UV / TEXTURE_PIXEL_SIZE) + grid_origin, 4.0);
		float threshold = (BAYER[int(cell.y) * 4 + int(cell.x)] + 0.5) / 16.0 - 0.5;
		float best = 1000.0;
		float second = 1000.0;
		vec3 pick = colour;
		vec3 other = colour;
		for (int i = 0; i < palette_size; i++) {
			vec3 diff = colour - palette[i];
			float dl = dot(diff, LUMA);
			vec3 dc = diff - vec3(dl);
			float d = dl * dl * luma_weight + dot(dc, dc) * chroma_weight;
			if (d < best) {
				second = best;
				other = pick;
				best = d;
				pick = palette[i];
			} else if (d < second) {
				second = d;
				other = palette[i];
			}
		}
		// Between two palette colours: 0 on the nearest, 0.5 half-way. Only the half-way zone dithers, always
		// from the darker toward the lighter colour, so the pattern is continuous across the transition.
		float near = sqrt(best);
		float toward = near / max(near + sqrt(second), 0.00001);
		bool pick_is_dark = dot(pick, LUMA) <= dot(other, LUMA);
		float position = pick_is_dark ? toward : 1.0 - toward;
		bool want_light = position + threshold * dither > 0.5;
		if (want_light == pick_is_dark) {
			pick = other;
		}
		colour = pick;
	}
	COLOR = vec4(colour, 1.0);
}
"""

static var _tuning_active: bool = false
## How many PixelViews are in the tree. The material tuning and the hard shadow filter are global, so they are
## shared: the first view to enter switches them on and the last one to leave restores them.
static var _tuning_users: int = 0
static var _tuning_saved: Dictionary[int, Dictionary] = {}
static var _palettes: Dictionary[StringName, PackedColorArray] = {}

## Screen pixels per art pixel on a 1080-pixel-high window. Changing it rebuilds the low-resolution viewport.
var art_pixel: int = DEFAULT_ART_PIXEL:
	set(value):
		art_pixel = maxi(value, 1)
		_current_px = art_pixel
		_layout()

## When true (the default) close cameras get finer art pixels (see art_pixel_for_view); `art_pixel` is then the
## coarsest size, used for the normal gameplay framing.
var auto_detail: bool = true

var _viewport: SubViewport = null
var _camera: Camera3D = null
var _quad: MeshInstance3D = null
var _outline: ShaderMaterial = null
var _display: TextureRect = null
var _upscale: ShaderMaterial = null
var _host: Viewport = null
var _host_disabled_3d: bool = false
var _art_size: Vector2i = Vector2i(480, 270)
var _scale: int = DEFAULT_ART_PIXEL
var _env_source: Environment = null
var _light_id: int = 0
var _light_saved: Dictionary = {}
var _current_px: int = DEFAULT_ART_PIXEL
var _mood_override: StringName = &""
var _palette_mood: StringName = &""


# ---------------------------------------------------------------- the maths (static, tested)

## Whole screen pixels per art pixel for a window of this height (`art_px` at 1080p, never less than 1).
static func pixel_scale(window_height: int, art_px: int = DEFAULT_ART_PIXEL) -> int:
	return maxi(1, roundi(float(maxi(art_px, 1)) * float(window_height) / float(REFERENCE_HEIGHT)))


## The low resolution that covers a window of `window_size` real pixels (480 x 270 at 1080p by default).
static func art_resolution(window_size: Vector2i, art_px: int = DEFAULT_ART_PIXEL) -> Vector2i:
	var scale_px: int = pixel_scale(window_size.y, art_px)
	return Vector2i(maxi(1, ceili(float(window_size.x) / float(scale_px))), maxi(1, ceili(float(window_size.y) / float(scale_px))))


## World size of one art pixel for an orthographic camera of `ortho_size` (its vertical extent).
static func art_pixel_world_size(ortho_size: float, art_height: int) -> float:
	return ortho_size / float(maxi(art_height, 1))


## How far the camera sits from its art-pixel grid position, in art pixels (x to the camera's right, y up),
## each within [-0.5, 0.5].
static func snap_remainder(camera: Transform3D, ortho_size: float, art_height: int) -> Vector2:
	var pixel: float = art_pixel_world_size(ortho_size, art_height)
	if pixel <= 0.0:
		return Vector2.ZERO
	var basis: Basis = camera.basis.orthonormalized()
	var across: float = camera.origin.dot(basis.x) / pixel
	var up: float = camera.origin.dot(basis.y) / pixel
	return Vector2(across - roundf(across), up - roundf(up))


## The camera transform moved onto the art-pixel grid of its own view plane (its aim and depth do not change),
## so every static world point lands on the same place inside an art pixel whatever the camera position.
static func snap_transform(camera: Transform3D, ortho_size: float, art_height: int) -> Transform3D:
	var pixel: float = art_pixel_world_size(ortho_size, art_height)
	if pixel <= 0.0:
		return camera
	var basis: Basis = camera.basis.orthonormalized()
	var across: float = camera.origin.dot(basis.x)
	var up: float = camera.origin.dot(basis.y)
	var depth: float = camera.origin.dot(basis.z)
	var origin: Vector3 = basis.x * (roundf(across / pixel) * pixel) + basis.y * (roundf(up / pixel) * pixel) + basis.z * depth
	return Transform3D(camera.basis, origin)


## Where a world point lands in the art image (pixels, x right, y down, origin top-left) for an orthographic
## camera at `camera` showing `ortho_size` world units over `art_size.y` pixels.
static func project_to_art(camera: Transform3D, ortho_size: float, art_size: Vector2i, world_point: Vector3) -> Vector2:
	var pixel: float = art_pixel_world_size(ortho_size, art_size.y)
	var basis: Basis = camera.basis.orthonormalized()
	var local: Vector3 = world_point - camera.origin
	return Vector2(local.dot(basis.x) / pixel + float(art_size.x) * 0.5, -local.dot(basis.y) / pixel + float(art_size.y) * 0.5)


## The shift of the upscaled image, in screen pixels, that puts back what the snap took away.
static func image_offset(remainder: Vector2, scale_px: int) -> Vector2:
	return Vector2(-remainder.x, remainder.y) * float(scale_px)


# ---------------------------------------------------------------- palettes and dithering (static, tested)

## The palette mood a Look mood maps to: itself when it has a palette, a borrowed one (divine uses dawn), else day.
static func resolve_palette_mood(mood: StringName) -> StringName:
	if PALETTE_MOODS.has(mood):
		return mood
	if _BORROWED_MOODS.has(mood):
		return _BORROWED_MOODS[mood]
	return DEFAULT_PALETTE_MOOD


## The curated colours of a mood: a 4-shade ramp for every hue family of the game, graded by the mood's light
## (shadows shift toward the mood's shadow hue, lights toward its highlight), plus an ink and a paper colour.
static func palette(mood: StringName) -> PackedColorArray:
	var resolved: StringName = resolve_palette_mood(mood)
	if not _palettes.has(resolved):
		_palettes[resolved] = _build_palette(resolved)
	return _palettes[resolved]


## The -0.5 .. 0.5 threshold of an art-pixel cell in the repeating 4x4 Bayer pattern.
static func bayer_threshold(cell: Vector2i) -> float:
	return (float(_BAYER[posmod(cell.y, 4) * 4 + posmod(cell.x, 4)]) + 0.5) / 16.0 - 0.5


## How different two colours are for the palette match: hue differences count more than brightness differences.
static func colour_distance(a: Color, b: Color) -> float:
	var diff: Vector3 = Vector3(a.r - b.r, a.g - b.g, a.b - b.b)
	var luma: float = diff.x * 0.299 + diff.y * 0.587 + diff.z * 0.114
	var chroma: Vector3 = diff - Vector3(luma, luma, luma)
	return luma * luma * LUMA_WEIGHT + chroma.length_squared() * CHROMA_WEIGHT


## The palette colour nearest to `colour`.
static func quantise(colour: Color, colours: PackedColorArray) -> Color:
	var best: float = INF
	var pick: Color = colour
	for entry: Color in colours:
		var distance: float = colour_distance(colour, entry)
		if distance < best:
			best = distance
			pick = entry
	return pick


## The palette colour an art pixel in dither cell `cell` gets (what the upscale shader does on the GPU).
static func quantise_dithered(colour: Color, colours: PackedColorArray, cell: Vector2i, strength: float = DITHER) -> Color:
	var best: float = INF
	var second: float = INF
	var pick: Color = colour
	var other: Color = colour
	for entry: Color in colours:
		var distance: float = colour_distance(colour, entry)
		if distance < best:
			second = best
			other = pick
			best = distance
			pick = entry
		elif distance < second:
			second = distance
			other = entry
	if second == INF:
		return pick
	var near: float = sqrt(best)
	var toward: float = near / maxf(near + sqrt(second), 0.00001)
	var pick_is_dark: bool = _luma(pick) <= _luma(other)
	var position: float = toward if pick_is_dark else 1.0 - toward
	var want_light: bool = position + bayer_threshold(cell) * strength > 0.5
	return other if want_light == pick_is_dark else pick


static func _luma(colour: Color) -> float:
	return colour.r * 0.299 + colour.g * 0.587 + colour.b * 0.114


## Screen pixels per art pixel (at 1080p) for an orthographic camera of `ortho_size`: `base` for the gameplay
## framings, finer for close-ups. Pass the size in use as `current` to get hysteresis around the thresholds.
static func art_pixel_for_view(ortho_size: float, base: int = DEFAULT_ART_PIXEL, current: int = 0) -> int:
	var coarse: int = maxi(base, 1)
	if current <= 0:
		return _art_pixel_at(ortho_size, coarse)
	var low: int = _art_pixel_at(ortho_size * (1.0 - DETAIL_HYSTERESIS), coarse)
	var high: int = _art_pixel_at(ortho_size * (1.0 + DETAIL_HYSTERESIS), coarse)
	return clampi(current, mini(low, high), maxi(low, high))


## Screen pixels per art pixel for a perspective camera (the cutscene close-ups): the close size.
static func art_pixel_for_perspective(base: int = DEFAULT_ART_PIXEL) -> int:
	return mini(maxi(base, 1), CLOSE_ART_PIXEL)


static func _art_pixel_at(ortho_size: float, coarse: int) -> int:
	if ortho_size < CLOSE_ORTHO_SIZE:
		return mini(coarse, CLOSE_ART_PIXEL)
	if ortho_size < MID_ORTHO_SIZE:
		return mini(coarse, MID_ART_PIXEL)
	return coarse


static func _grade(base: Color, tint: Color, saturation: float, amount: float) -> Color:
	var graded: Color = Color(base.r * tint.r, base.g * tint.g, base.b * tint.b)
	var grey: float = graded.r * 0.299 + graded.g * 0.587 + graded.b * 0.114
	graded = Color(lerpf(grey, graded.r, saturation), lerpf(grey, graded.g, saturation), lerpf(grey, graded.b, saturation))
	return base.lerp(graded, amount)


static func _scaled(colour: Color, factor: float) -> Color:
	return Color(clampf(colour.r * factor, 0.0, 1.0), clampf(colour.g * factor, 0.0, 1.0), clampf(colour.b * factor, 0.0, 1.0))


static func _build_palette(mood: StringName) -> PackedColorArray:
	# tint = the mood's light on a mid-tone; shadow = the hue the darks drift to; light = the hue of the lights.
	var tint: Color = Color(1.0, 0.97, 0.9)
	var shadow: Color = Color("#3A2A52")
	var light: Color = Color("#FFF1C9")
	var saturation: float = 1.05
	match mood:
		&"dawn":
			tint = Color(1.06, 0.93, 0.82)
			shadow = Color("#4A2F5E")
			light = Color("#FFE3B0")
			saturation = 1.0
		&"dusk":
			tint = Color(1.05, 0.8, 0.72)
			shadow = Color("#33214F")
			light = Color("#FFC98A")
			saturation = 1.0
		&"night":
			tint = Color(0.5, 0.62, 0.95)
			shadow = Color("#141433")
			light = Color("#DDE6F2")
			saturation = 0.8
		&"inferno":
			tint = Color(1.1, 0.66, 0.5)
			shadow = Color("#2B1026")
			light = Color("#FFD166")
			saturation = 1.05
	var colours: PackedColorArray = PackedColorArray()
	_add_colour(colours, _scaled(shadow, 0.42))
	for i: int in _RAMP_BASES.size():
		var mid: Color = _grade(_RAMP_BASES[i], tint, saturation, 0.5 if _WARM_ACCENTS.has(i) else 1.0)
		_add_colour(colours, _scaled(mid, 0.3).lerp(shadow, 0.5))
		_add_colour(colours, _scaled(mid, 0.6).lerp(shadow, 0.22))
		_add_colour(colours, mid)
		_add_colour(colours, _scaled(mid, 1.28).lerp(light, 0.32))
	_add_colour(colours, light)
	return colours


static func _add_colour(colours: PackedColorArray, colour: Color) -> void:
	if colours.size() >= MAX_PALETTE:
		return
	var opaque: Color = Color(colour.r, colour.g, colour.b, 1.0)
	for entry: Color in colours:
		if Vector3(entry.r - opaque.r, entry.g - opaque.g, entry.b - opaque.b).length() < PALETTE_MIN_DISTANCE:
			return
	colours.append(opaque)


## Retunes (or restores) the shared painterly materials for the pixel style: hard light bands, calmer grain.
static func apply_material_tuning(enabled: bool) -> void:
	if enabled == _tuning_active:
		return
	_tuning_active = enabled
	if not enabled:
		for id: int in _tuning_saved:
			var old: ShaderMaterial = instance_from_id(id) as ShaderMaterial
			if old == null:
				continue
			var values: Dictionary = _tuning_saved[id]
			for key: Variant in values:
				old.set_shader_parameter(key as StringName, values[key])
		_tuning_saved.clear()
		return
	for kind: StringName in Materials.kinds():
		for suffix: String in _MATERIAL_SUFFIXES:
			var material: ShaderMaterial = Materials.get_material(StringName(String(kind) + suffix))
			if material == null or _tuning_saved.has(material.get_instance_id()):
				continue
			var saved: Dictionary = {}
			for key: StringName in _TUNED_ABSOLUTE:
				saved[key] = material.get_shader_parameter(key)
				material.set_shader_parameter(key, _TUNED_ABSOLUTE[key])
			for key: StringName in _TUNED_SCALED:
				var before: Variant = material.get_shader_parameter(key)
				saved[key] = before
				if typeof(before) == TYPE_FLOAT or typeof(before) == TYPE_INT:
					material.set_shader_parameter(key, (before as float) * _TUNED_SCALED[key])
			_tuning_saved[material.get_instance_id()] = saved


static func is_material_tuning_active() -> bool:
	return _tuning_active


## How many PixelViews currently hold the shared (global) tuning.
static func tuning_users() -> int:
	return _tuning_users


static func _retain_tuning() -> void:
	_tuning_users += 1
	if _tuning_users == 1:
		apply_material_tuning(true)
		_set_hard_shadows(true)


static func _release_tuning() -> void:
	_tuning_users = maxi(_tuning_users - 1, 0)
	if _tuning_users == 0:
		apply_material_tuning(false)
		_set_hard_shadows(false)


# ---------------------------------------------------------------- public API

## The low-resolution viewport the world is rendered into.
func sub_viewport() -> SubViewport:
	return _viewport


## The camera inside the low-resolution viewport (it mirrors the host viewport's current camera).
func pixel_camera() -> Camera3D:
	return _camera


## The full-screen rect that shows the upscaled image.
func display() -> TextureRect:
	return _display


## The quad in front of the pixel camera that runs the outline shader.
func outline_quad() -> MeshInstance3D:
	return _quad


## The visible low resolution (the viewport itself is MARGIN art pixels larger on every side).
func art_size() -> Vector2i:
	return _art_size


## Whole screen pixels per art pixel right now.
func screen_scale() -> int:
	return _scale


## The art-pixel size in use right now (screen pixels per art pixel at 1080p): `art_pixel`, or finer while the
## camera is close and `auto_detail` is on.
func current_art_pixel() -> int:
	return _current_px


## The mood whose palette is shown (it follows the Look rig next to this view unless set_palette_mood names one).
func palette_mood() -> StringName:
	return _palette_mood


## Fixes the palette to a mood; an empty name follows the Look rig again.
func set_palette_mood(mood: StringName) -> void:
	_mood_override = mood
	_sync_palette()


## The host viewport's size in real pixels.
func window_size() -> Vector2i:
	if _host == null:
		return Vector2i(1920, REFERENCE_HEIGHT)
	var window: Window = _host as Window
	if window != null:
		return window.size
	return Vector2i(_host.get_visible_rect().size)


## Mirrors the host camera, the environment and the key light now (also runs every frame).
func refresh() -> void:
	if _viewport == null or _host == null:
		return
	_sync_environment()
	_sync_palette()
	_sync_light()
	_sync_detail()
	_sync_camera()


# ---------------------------------------------------------------- lifecycle

func _init() -> void:
	layer = VIEW_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After the camera rigs have moved this frame.
	process_priority = 1000


func _enter_tree() -> void:
	_host = get_viewport()
	if _viewport == null:
		_build()
	_viewport.world_3d = _host.find_world_3d()
	_host_disabled_3d = _host.disable_3d
	_host.disable_3d = true
	if not _host.size_changed.is_connected(_layout):
		_host.size_changed.connect(_layout)
	_retain_tuning()
	_layout()
	refresh()


func _exit_tree() -> void:
	_release_tuning()
	_restore_light()
	if _host != null:
		if _host.size_changed.is_connected(_layout):
			_host.size_changed.disconnect(_layout)
		_host.disable_3d = _host_disabled_3d
	_host = null
	_env_source = null


func _process(_delta: float) -> void:
	refresh()


## Unfiltered shadow maps give a short, stepped shadow edge at the art resolution instead of a wide blur;
## leaving restores the project's soft filter.
static func _set_hard_shadows(hard: bool) -> void:
	var directional: int = ProjectSettings.get_setting(_DIRECTIONAL_FILTER_SETTING, RenderingServer.SHADOW_QUALITY_SOFT_LOW) as int
	var positional: int = ProjectSettings.get_setting(_POSITIONAL_FILTER_SETTING, RenderingServer.SHADOW_QUALITY_SOFT_LOW) as int
	if hard:
		directional = RenderingServer.SHADOW_QUALITY_HARD
		positional = RenderingServer.SHADOW_QUALITY_HARD
	RenderingServer.directional_soft_shadow_filter_set_quality(directional as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(positional as RenderingServer.ShadowQuality)


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "LowRes"
	_viewport.own_world_3d = false
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_taa = false
	_viewport.use_debanding = false
	_viewport.scaling_3d_scale = 1.0
	_viewport.gui_disable_input = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.name = "PixelCamera"
	_viewport.add_child(_camera)
	_camera.current = true
	_quad = MeshInstance3D.new()
	_quad.name = "OutlinePass"
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	_quad.mesh = mesh
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.extra_cull_margin = 16384.0
	_quad.layers = 0
	_quad.set_layer_mask_value(POST_RENDER_LAYER, true)
	_outline = ShaderMaterial.new()
	_outline.shader = load(OUTLINE_SHADER_PATH) as Shader
	_outline.render_priority = RenderingServer.MATERIAL_RENDER_PRIORITY_MIN
	_quad.material_override = _outline
	_camera.add_child(_quad)
	_quad.position = Vector3(0.0, 0.0, -1.0)
	_display = TextureRect.new()
	_display.name = "Upscaled"
	_display.texture = _viewport.get_texture()
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upscale = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = _UPSCALE_SHADER
	_upscale.shader = shader
	_upscale.set_shader_parameter(&"dither", DITHER)
	_upscale.set_shader_parameter(&"luma_weight", LUMA_WEIGHT)
	_upscale.set_shader_parameter(&"chroma_weight", CHROMA_WEIGHT)
	_display.material = _upscale
	add_child(_display)


## Sizes the low-resolution viewport from the window height and places the upscaled image.
func _layout() -> void:
	if _viewport == null or _host == null:
		return
	var window: Vector2i = window_size()
	_scale = pixel_scale(window.y, _current_px)
	_art_size = art_resolution(window, _current_px)
	var padded: Vector2i = _art_size + Vector2i.ONE * 2 * MARGIN
	if _viewport.size != padded:
		_viewport.size = padded
	_place_display(Vector2.ZERO)


## Places the upscaled image: whole screen pixels per art pixel, centred, shifted by `shift` screen pixels.
func _place_display(shift: Vector2) -> void:
	var window: Vector2 = Vector2(window_size())
	var canvas: Vector2 = _host.get_visible_rect().size
	var canvas_per_pixel: float = canvas.x / window.x if window.x > 0.0 and canvas.x > 0.0 else 1.0
	var padded: Vector2 = Vector2(_art_size + Vector2i.ONE * 2 * MARGIN) * float(_scale)
	var corner: Vector2 = ((window - padded) * 0.5).floor() + shift.round()
	_display.position = corner * canvas_per_pixel
	_display.size = padded * canvas_per_pixel


## Sends the palette of the current mood to the upscale pass when the mood changes.
func _sync_palette() -> void:
	if _upscale == null:
		return
	var wanted: StringName = _mood_override
	if wanted == &"":
		wanted = Look.mood_of(get_parent())
	wanted = resolve_palette_mood(wanted)
	if wanted == _palette_mood:
		return
	_palette_mood = wanted
	var colours: PackedColorArray = palette(wanted)
	var values: PackedVector3Array = PackedVector3Array()
	for colour: Color in colours:
		values.append(Vector3(colour.r, colour.g, colour.b))
	_upscale.set_shader_parameter(&"palette_size", colours.size())
	values.resize(MAX_PALETTE)
	_upscale.set_shader_parameter(&"palette", values)
	if _outline != null and colours.size() > 0:
		_outline.set_shader_parameter(&"outline_tint", colours[0])


## Picks finer art pixels while the host camera is close (and the coarse size again when it leaves).
func _sync_detail() -> void:
	var wanted: int = art_pixel
	var source: Camera3D = _host.get_camera_3d()
	if auto_detail and source != null and source.is_inside_tree():
		if source.projection == Camera3D.PROJECTION_ORTHOGONAL:
			wanted = art_pixel_for_view(source.size, art_pixel, _current_px)
		else:
			wanted = art_pixel_for_perspective(art_pixel)
	if wanted != _current_px:
		_current_px = wanted
		_layout()


func _sync_camera() -> void:
	var source: Camera3D = _host.get_camera_3d()
	if source == null or not source.is_inside_tree():
		return
	_camera.projection = source.projection
	_camera.keep_aspect = source.keep_aspect
	_camera.near = source.near
	_camera.far = source.far
	_camera.h_offset = source.h_offset
	_camera.v_offset = source.v_offset
	_camera.cull_mask = source.cull_mask
	_camera.set_cull_mask_value(POST_RENDER_LAYER, true)
	var grow: float = float(_art_size.y + 2 * MARGIN) / float(_art_size.y)
	var at: Transform3D = source.global_transform
	var shift: Vector2 = Vector2.ZERO
	if source.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var pixel: float = art_pixel_world_size(source.size, _art_size.y)
		_camera.size = source.size * grow
		shift = image_offset(snap_remainder(at, source.size, _art_size.y), _scale)
		at = snap_transform(at, source.size, _art_size.y)
		_outline.set_shader_parameter(&"pixel_world", pixel)
		var basis: Basis = at.basis.orthonormalized()
		var cell: Vector2 = Vector2(roundf(at.origin.dot(basis.x) / pixel), -roundf(at.origin.dot(basis.y) / pixel))
		_upscale.set_shader_parameter(&"grid_origin", Vector2(fposmod(cell.x, 4.0), fposmod(cell.y, 4.0)))
	else:
		var half: float = tan(deg_to_rad(source.fov) * 0.5)
		_camera.fov = rad_to_deg(atan(half * grow) * 2.0)
		_outline.set_shader_parameter(&"pixel_per_depth", 2.0 * half / float(_art_size.y))
		_upscale.set_shader_parameter(&"grid_origin", Vector2.ZERO)
	_camera.global_transform = at
	_place_display(shift)


## The WorldEnvironment that sits next to this view (the Look rig of the level), or null.
func _find_world_environment() -> WorldEnvironment:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		var found: WorldEnvironment = child as WorldEnvironment
		if found != null and not found.is_queued_for_deletion():
			return found
	return null


## Gives the pixel camera its own copy of the world's environment without the effects that smear pixels.
func _sync_environment() -> void:
	var holder: WorldEnvironment = _find_world_environment()
	var source: Environment = holder.environment if holder != null else null
	if source == _env_source and (source == null) == (_camera.environment == null):
		return
	_env_source = source
	if source == null:
		_camera.environment = null
		return
	var env: Environment = source.duplicate() as Environment
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.ssr_enabled = false
	env.volumetric_fog_enabled = false
	env.fog_density = source.fog_density * FOG_KEEP
	env.fog_height_density = source.fog_height_density * FOG_KEEP
	env.adjustment_enabled = true
	if source.adjustment_enabled:
		env.adjustment_saturation = source.adjustment_saturation * SATURATION_BOOST
		env.adjustment_brightness = source.adjustment_brightness * BRIGHTNESS_BOOST
	else:
		env.adjustment_saturation = SATURATION_BOOST
		env.adjustment_brightness = BRIGHTNESS_BOOST
	_camera.environment = env


func _find_key_light() -> DirectionalLight3D:
	var parent: Node = get_parent()
	if parent == null:
		return null
	var named: DirectionalLight3D = parent.get_node_or_null(NodePath(String(KEY_LIGHT_NAME))) as DirectionalLight3D
	if named != null and not named.is_queued_for_deletion():
		return named
	for child: Node in parent.get_children():
		var light: DirectionalLight3D = child as DirectionalLight3D
		if light != null and light.shadow_enabled and not light.is_queued_for_deletion():
			return light
	return null


## Points the highlights at the key light and hardens its shadow edge (stepped pixels instead of a blur).
func _sync_light() -> void:
	var light: DirectionalLight3D = _find_key_light()
	if light == null:
		_restore_light()
		return
	if light.get_instance_id() != _light_id:
		_restore_light()
		_light_id = light.get_instance_id()
		_light_saved = {"blur": light.shadow_blur, "angle": light.light_angular_distance}
		light.shadow_blur = 0.0
		light.light_angular_distance = 0.0
	if light.is_inside_tree():
		_outline.set_shader_parameter(&"light_direction", light.global_basis.z.normalized())


func _restore_light() -> void:
	if _light_id == 0:
		return
	var light: DirectionalLight3D = instance_from_id(_light_id) as DirectionalLight3D
	if light != null:
		light.shadow_blur = _light_saved.get("blur", 1.0) as float
		light.light_angular_distance = _light_saved.get("angle", 0.0) as float
	_light_id = 0
	_light_saved = {}
