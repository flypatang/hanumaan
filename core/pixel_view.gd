class_name PixelView
extends CanvasLayer
## PX1 (experiment): the optional 'Pixel' visual style, next to the default 'Painterly' one.
## Add a PixelView next to a 3D world (as a child of the node that holds the camera, the lights and the
## WorldEnvironment). It then:
##   * renders that same world (the shared World3D, nothing is re-parented) into a low-resolution SubViewport,
##     by default 4 screen pixels per art pixel at 1080p (480 x 270), and shows it upscaled with nearest filtering
##     on a CanvasLayer below every UI layer, so the HUD, dialogue and Devanagari text stay at full resolution;
##   * mirrors the host viewport's current camera each frame; an orthographic camera is snapped to the art-pixel
##     grid in camera space and the upscaled image is shifted by the sub-pixel remainder, so panning is smooth
##     and static pixels never shimmer;
##   * draws outlines and highlights with core/pixel_outline.gdshader, hardens the key light's shadows, flattens
##     the light bands of the shared Materials, quantises the colours a little and drops the effects that smear
##     pixels (glow, SSAO, SSIL, SDFGI, volumetric fog; depth fog is thinned);
##   * switches 3D drawing off in the host viewport while it exists, and restores everything when it leaves.

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
## Steps of brightness the upscaled image is quantised to (0 switches the quantisation off).
const COLOUR_LEVELS: float = 18.0
const DITHER: float = 0.0

const _DIRECTIONAL_FILTER_SETTING: String = "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
const _POSITIONAL_FILTER_SETTING: String = "rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality"

const _MATERIAL_SUFFIXES: Array[String] = ["", "_local", "_world"]
## Shared painterly material uniforms retuned for chunky pixels: hard light bands, no screen-space bevel
## highlights (the post pass draws them) and calmer grain.
const _TUNED_ABSOLUTE: Dictionary[StringName, float] = {&"band_softness": 0.012, &"edge_strength": 0.0}
const _TUNED_SCALED: Dictionary[StringName, float] = {&"detail_strength": 0.55, &"cavity_strength": 0.5, &"band_wobble": 0.6}

const _UPSCALE_SHADER: String = """shader_type canvas_item;
// Nearest upscale of the low-resolution world with a small brightness quantisation. The 4x4 ordered dither is
// anchored to the world (grid_origin = the snapped camera position in art pixels), so it never crawls.
uniform float levels = 20.0;
uniform float dither = 0.0;
uniform vec2 grid_origin = vec2(0.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 colour = texture(TEXTURE, UV).rgb;
	if (levels > 0.5) {
		vec2 cell = mod(floor(UV / TEXTURE_PIXEL_SIZE) + grid_origin, 4.0);
		float threshold = (BAYER[int(cell.y) * 4 + int(cell.x)] + 0.5) / 16.0 - 0.5;
		float value = max(colour.r, max(colour.g, colour.b));
		float stepped = floor(value * levels + 0.5 + threshold * dither) / levels;
		colour *= stepped / max(value, 0.0001);
	}
	COLOR = vec4(colour, 1.0);
}
"""

static var _tuning_active: bool = false
static var _tuning_saved: Dictionary[int, Dictionary] = {}

## Screen pixels per art pixel on a 1080-pixel-high window. Changing it rebuilds the low-resolution viewport.
var art_pixel: int = DEFAULT_ART_PIXEL:
	set(value):
		art_pixel = maxi(value, 1)
		_layout()

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
	_sync_light()
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
	apply_material_tuning(true)
	_set_hard_shadows(true)
	_layout()
	refresh()


func _exit_tree() -> void:
	apply_material_tuning(false)
	_set_hard_shadows(false)
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
func _set_hard_shadows(hard: bool) -> void:
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
	_upscale.set_shader_parameter(&"levels", COLOUR_LEVELS)
	_upscale.set_shader_parameter(&"dither", DITHER)
	_display.material = _upscale
	add_child(_display)


## Sizes the low-resolution viewport from the window height and places the upscaled image.
func _layout() -> void:
	if _viewport == null or _host == null:
		return
	var window: Vector2i = window_size()
	_scale = pixel_scale(window.y, art_pixel)
	_art_size = art_resolution(window, art_pixel)
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
