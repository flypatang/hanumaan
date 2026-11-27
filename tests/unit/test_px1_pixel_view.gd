extends GdUnitTestSuite
## PX1 acceptance tests: core/pixel_view.gd (the optional 'Pixel' visual style, an experiment next to 'Painterly').
## Resolution maths, pixel-stable camera snapping, the low-resolution viewport and the full-resolution HUD.

const SETTINGS_PATH: String = "user://settings.cfg"
const GameStateScript: GDScript = preload("res://core/game_state.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")

var _settings_backup: PackedByteArray = PackedByteArray()
var _had_settings: bool = false


func before_test() -> void:
	_had_settings = FileAccess.file_exists(SETTINGS_PATH)
	if _had_settings:
		_settings_backup = FileAccess.get_file_as_bytes(SETTINGS_PATH)


func after_test() -> void:
	PixelView.apply_material_tuning(false)
	if _had_settings:
		var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(_settings_backup)
		file.close()
	elif FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _iso_basis(yaw: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -deg_to_rad(35.264))


func _host() -> Node3D:
	var host: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(host)
	return host


func _inside(node: Node, ancestor: Node) -> bool:
	return node == ancestor or ancestor.is_ancestor_of(node)


# ---------------------------------------------------------------- resolution maths

func test_default_is_four_screen_pixels_per_art_pixel_at_1080p() -> void:
	assert_int(PixelView.DEFAULT_ART_PIXEL).is_equal(4)
	assert_int(PixelView.pixel_scale(1080)).is_equal(4)
	assert_object(PixelView.art_resolution(Vector2i(1920, 1080))).is_equal(Vector2i(480, 270))


func test_scale_follows_the_window_height_and_stays_a_whole_number() -> void:
	assert_int(PixelView.pixel_scale(2160)).is_equal(8)
	assert_int(PixelView.pixel_scale(1440)).is_equal(5)
	assert_int(PixelView.pixel_scale(720)).is_equal(3)
	assert_int(PixelView.pixel_scale(800)).is_equal(3)
	assert_int(PixelView.pixel_scale(100)).is_equal(1)
	assert_int(PixelView.pixel_scale(1080, 2)).is_equal(2)
	assert_int(PixelView.pixel_scale(1080, 6)).is_equal(6)
	assert_object(PixelView.art_resolution(Vector2i(3840, 2160))).is_equal(Vector2i(480, 270))
	assert_object(PixelView.art_resolution(Vector2i(1920, 1080), 2)).is_equal(Vector2i(960, 540))
	assert_object(PixelView.art_resolution(Vector2i(1920, 1080), 6)).is_equal(Vector2i(320, 180))


func test_resolution_always_covers_the_window() -> void:
	var sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(2560, 1080), Vector2i(1366, 768), Vector2i(1, 1)]
	for window: Vector2i in sizes:
		var scale: int = PixelView.pixel_scale(window.y)
		var art: Vector2i = PixelView.art_resolution(window)
		assert_bool(art.x >= 1 and art.y >= 1).is_true()
		assert_bool(art.x * scale >= window.x and art.y * scale >= window.y).is_true()
		assert_bool((art.x - 1) * scale < window.x and (art.y - 1) * scale < window.y).is_true()


func test_art_pixel_world_size() -> void:
	assert_float(PixelView.art_pixel_world_size(13.5, 270)).is_equal_approx(0.05, 0.00001)
	assert_float(PixelView.art_pixel_world_size(7.5, 0)).is_equal_approx(7.5, 0.00001)


# ---------------------------------------------------------------- pixel-stable camera

func test_snapping_keeps_the_world_origin_on_the_art_pixel_grid() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261127
	var art: Vector2i = Vector2i(480, 270)
	for i: int in 100:
		var ortho: float = rng.randf_range(5.0, 32.0)
		var yaw: float = PI / 4.0 + float(rng.randi_range(0, 3)) * PI / 2.0
		var pos: Vector3 = Vector3(rng.randf_range(-60.0, 60.0), rng.randf_range(0.0, 30.0), rng.randf_range(-60.0, 60.0))
		var cam: Transform3D = Transform3D(_iso_basis(yaw), pos)
		var snapped_cam: Transform3D = PixelView.snap_transform(cam, ortho, art.y)
		var origin_px: Vector2 = PixelView.project_to_art(snapped_cam, ortho, art, Vector3.ZERO)
		var off_grid: Vector2 = origin_px - origin_px.round()
		assert_float(off_grid.x).is_equal_approx(0.0, 0.02)
		assert_float(off_grid.y).is_equal_approx(0.0, 0.02)
		# The snap never moves the camera by more than half an art pixel on each axis and never changes its aim.
		var rest: Vector2 = PixelView.snap_remainder(cam, ortho, art.y)
		assert_bool(absf(rest.x) <= 0.5001 and absf(rest.y) <= 0.5001).is_true()
		assert_bool(snapped_cam.basis.is_equal_approx(cam.basis)).is_true()
		var moved: float = (snapped_cam.origin - cam.origin).length() / PixelView.art_pixel_world_size(ortho, art.y)
		assert_bool(moved <= 0.7072).is_true()


func test_remainder_plus_snap_reproduces_the_smooth_camera() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var art: Vector2i = Vector2i(480, 270)
	var point: Vector3 = Vector3(3.0, 1.0, -2.0)
	for i: int in 100:
		var pos: Vector3 = Vector3(rng.randf_range(-20.0, 20.0), rng.randf_range(0.0, 20.0), rng.randf_range(-20.0, 20.0))
		var cam: Transform3D = Transform3D(_iso_basis(PI / 4.0), pos)
		var smooth: Vector2 = PixelView.project_to_art(cam, 14.0, art, point)
		var stepped: Vector2 = PixelView.project_to_art(PixelView.snap_transform(cam, 14.0, art.y), 14.0, art, point)
		var shift: Vector2 = PixelView.image_offset(PixelView.snap_remainder(cam, 14.0, art.y), 1)
		assert_float(stepped.x + shift.x).is_equal_approx(smooth.x, 0.02)
		assert_float(stepped.y + shift.y).is_equal_approx(smooth.y, 0.02)


func test_image_offset_scales_to_screen_pixels() -> void:
	assert_object(PixelView.image_offset(Vector2(0.5, -0.25), 4)).is_equal(Vector2(-2.0, -1.0))
	assert_object(PixelView.image_offset(Vector2.ZERO, 4)).is_equal(Vector2.ZERO)


func test_a_slow_pan_never_moves_a_static_point_by_a_fraction_of_a_pixel() -> void:
	var art: Vector2i = Vector2i(480, 270)
	var basis: Basis = _iso_basis(PI / 4.0)
	var first: Vector2 = Vector2.ZERO
	for i: int in 100:
		var cam: Transform3D = Transform3D(basis, Vector3(10.0 + float(i) * 0.0137, 23.0, 10.0 + float(i) * 0.0071))
		var px: Vector2 = PixelView.project_to_art(PixelView.snap_transform(cam, 7.5, art.y), 7.5, art, Vector3(4.0, 0.0, 6.0))
		if i == 0:
			first = px
		var step: Vector2 = px - first
		assert_float(step.x - roundf(step.x)).is_equal_approx(0.0, 0.02)
		assert_float(step.y - roundf(step.y)).is_equal_approx(0.0, 0.02)


# ---------------------------------------------------------------- the view itself

func test_view_renders_the_shared_world_at_low_resolution_with_nearest_filtering() -> void:
	var host: Node3D = _host()
	var view: PixelView = PixelView.new()
	host.add_child(view)
	assert_object(view.sub_viewport()).is_not_null()
	assert_object(view.pixel_camera()).is_not_null()
	assert_object(view.display()).is_not_null()
	var window: Vector2i = view.window_size()
	var art: Vector2i = PixelView.art_resolution(window, view.art_pixel)
	assert_object(view.art_size()).is_equal(art)
	assert_object(view.sub_viewport().size).is_equal(art + Vector2i.ONE * 2 * PixelView.MARGIN)
	assert_int(view.display().texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_object(view.display().texture).is_not_null()
	assert_bool(view.sub_viewport().world_3d == host.get_viewport().find_world_3d()).is_true()
	assert_bool(_inside(view.pixel_camera(), view.sub_viewport())).is_true()
	assert_bool(view.layer < 0).is_true()
	assert_int(view.sub_viewport().msaa_3d).is_equal(Viewport.MSAA_DISABLED)


func test_art_pixel_size_is_configurable() -> void:
	var host: Node3D = _host()
	var view: PixelView = PixelView.new()
	view.art_pixel = 2
	host.add_child(view)
	var coarse: Vector2i = PixelView.art_resolution(view.window_size(), 6)
	view.art_pixel = 6
	assert_object(view.art_size()).is_equal(coarse)
	assert_object(view.sub_viewport().size).is_equal(coarse + Vector2i.ONE * 2 * PixelView.MARGIN)


func test_pixel_camera_follows_the_host_camera_snapped() -> void:
	var host: Node3D = _host()
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.5
	host.add_child(cam)
	cam.global_transform = Transform3D(_iso_basis(PI / 4.0), Vector3(12.3456, 23.0, 7.891))
	cam.make_current()
	var view: PixelView = PixelView.new()
	host.add_child(view)
	view.refresh()
	var pixel_cam: Camera3D = view.pixel_camera()
	assert_int(pixel_cam.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	var art: Vector2i = view.art_size()
	var expected: Transform3D = PixelView.snap_transform(cam.global_transform, 7.5, art.y)
	assert_bool(pixel_cam.global_transform.is_equal_approx(expected)).is_true()
	# One art pixel covers the same world distance in the margin-padded viewport.
	var padded: int = view.sub_viewport().size.y
	assert_float(pixel_cam.size / float(padded)).is_equal_approx(7.5 / float(art.y), 0.00001)
	var origin_px: Vector2 = PixelView.project_to_art(pixel_cam.global_transform, 7.5, art, Vector3.ZERO)
	assert_float((origin_px - origin_px.round()).length()).is_equal_approx(0.0, 0.03)


func test_host_viewport_stops_drawing_3d_while_the_view_exists() -> void:
	var host: Node3D = _host()
	var viewport: Viewport = host.get_viewport()
	var before: bool = viewport.disable_3d
	var view: PixelView = PixelView.new()
	host.add_child(view)
	assert_bool(viewport.disable_3d).is_true()
	host.remove_child(view)
	view.free()
	assert_bool(viewport.disable_3d).is_equal(before)


func test_outline_pass_sits_in_front_of_the_pixel_camera() -> void:
	var host: Node3D = _host()
	var view: PixelView = PixelView.new()
	host.add_child(view)
	var quad: MeshInstance3D = view.outline_quad()
	assert_object(quad).is_not_null()
	assert_bool(_inside(quad, view.pixel_camera())).is_true()
	var material: ShaderMaterial = quad.material_override as ShaderMaterial
	assert_object(material).is_not_null()
	assert_str(material.shader.resource_path).is_equal("res://core/pixel_outline.gdshader")
	var code: String = material.shader.code
	assert_bool(code.contains("hint_depth_texture")).is_true()
	assert_bool(code.contains("hint_normal_roughness_texture")).is_true()
	assert_bool(code.contains("hint_screen_texture")).is_true()
	assert_bool(code.contains("filter_nearest")).is_true()


func test_pixel_environment_drops_the_effects_that_smear_pixels() -> void:
	var host: Node3D = _host()
	var rig: Dictionary = Look.apply(&"dusk", host, &"high")
	var source: Environment = rig["environment"] as Environment
	assert_bool(source.glow_enabled).is_true()
	var view: PixelView = PixelView.new()
	host.add_child(view)
	view.refresh()
	var env: Environment = view.pixel_camera().environment
	assert_object(env).is_not_null()
	assert_bool(env != source).is_true()
	assert_bool(env.glow_enabled).is_false()
	assert_bool(env.ssao_enabled).is_false()
	assert_bool(env.ssil_enabled).is_false()
	assert_bool(env.sdfgi_enabled).is_false()
	assert_bool(env.volumetric_fog_enabled).is_false()
	assert_bool(env.fog_density <= source.fog_density).is_true()
	# The shared environment of the painterly style is left alone.
	assert_bool(source.glow_enabled).is_true()
	assert_bool(source.volumetric_fog_enabled).is_true()


func test_material_tuning_flattens_the_light_bands_and_restores() -> void:
	var stone: ShaderMaterial = Materials.get_material(&"stone")
	var soft: float = stone.get_shader_parameter(&"band_softness") as float
	PixelView.apply_material_tuning(true)
	assert_bool(PixelView.is_material_tuning_active()).is_true()
	assert_bool((stone.get_shader_parameter(&"band_softness") as float) < soft).is_true()
	assert_bool((stone.get_shader_parameter(&"band_softness") as float) <= 0.03).is_true()
	PixelView.apply_material_tuning(true)
	PixelView.apply_material_tuning(false)
	assert_bool(PixelView.is_material_tuning_active()).is_false()
	assert_float(stone.get_shader_parameter(&"band_softness") as float).is_equal_approx(soft, 0.00001)


func test_view_without_a_host_camera_refreshes_without_crashing() -> void:
	# No Camera3D in the host viewport: the pixel camera just keeps its transform.
	var host: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(host)
	var view: PixelView = PixelView.new()
	host.add_child(view)
	var before: Transform3D = view.pixel_camera().global_transform
	view.refresh()
	view.refresh()
	assert_object(view.sub_viewport()).is_not_null()
	assert_bool(view.pixel_camera().global_transform.is_equal_approx(before)).is_true()


func test_two_views_share_the_tuning_until_the_last_one_leaves() -> void:
	var stone: ShaderMaterial = Materials.get_material(&"stone")
	var soft: float = stone.get_shader_parameter(&"band_softness") as float
	var users: int = PixelView.tuning_users()
	var first_host: SubViewport = auto_free(SubViewport.new()) as SubViewport
	var second_host: SubViewport = auto_free(SubViewport.new()) as SubViewport
	add_child(first_host)
	add_child(second_host)
	var first: PixelView = PixelView.new()
	var second: PixelView = PixelView.new()
	first_host.add_child(first)
	second_host.add_child(second)
	assert_int(PixelView.tuning_users()).is_equal(users + 2)
	assert_bool(PixelView.is_material_tuning_active()).is_true()
	first_host.remove_child(first)
	first.free()
	# The second view is still showing: the materials stay tuned.
	assert_int(PixelView.tuning_users()).is_equal(users + 1)
	assert_bool(PixelView.is_material_tuning_active()).is_true()
	assert_bool((stone.get_shader_parameter(&"band_softness") as float) < soft).is_true()
	second_host.remove_child(second)
	second.free()
	assert_int(PixelView.tuning_users()).is_equal(users)
	assert_bool(PixelView.is_material_tuning_active()).is_false()
	assert_float(stone.get_shader_parameter(&"band_softness") as float).is_equal_approx(soft, 0.00001)


# ---------------------------------------------------------------- settings and LevelRuntime

func _make_runtime() -> LevelRuntime:
	var rt: LevelRuntime = LevelRuntime.new()
	rt.music_enabled = false
	rt.game_state = auto_free(GameStateScript.new()) as Node
	rt.event_bus = auto_free(BusScript.new()) as Node
	add_child(rt)
	auto_free(rt)
	return rt


func test_style_setting_defaults_to_pixel_persists_and_rejects_unknown_values() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	assert_str(Menus.visual_style()).is_equal("pixel")
	var menu: Menus = auto_free(Menus.new()) as Menus
	add_child(menu)
	assert_bool(menu.set_option(&"visual_style", "painterly")).is_true()
	assert_str(Menus.visual_style()).is_equal("painterly")
	var config: ConfigFile = ConfigFile.new()
	assert_int(config.load(SETTINGS_PATH)).is_equal(OK)
	assert_str(str(config.get_value("video", "visual_style", ""))).is_equal("painterly")
	assert_bool(menu.set_option(&"visual_style", "voxel")).is_false()
	assert_str(Menus.visual_style()).is_equal("painterly")
	menu.set_option(&"visual_style", "pixel")
	var option: OptionButton = menu.find_child("StyleOption", true, false) as OptionButton
	assert_object(option).is_not_null()
	assert_int(option.item_count).is_equal(2)
	assert_int(option.selected).is_equal(1)
	assert_object(menu.find_child("StyleLabel", true, false)).is_not_null()
	assert_bool(menu.set_option(&"visual_style", "painterly")).is_true()
	assert_str(Menus.visual_style()).is_equal("painterly")
	assert_int(option.selected).is_equal(0)


func test_style_strings_exist_in_english_and_hindi() -> void:
	var file: FileAccess = FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	assert_object(file).is_not_null()
	var filled: Dictionary[String, bool] = {}
	while not file.eof_reached():
		# get_csv_line honours quoted cells, so a translation may contain commas.
		var cells: PackedStringArray = file.get_csv_line()
		if cells.size() >= 3:
			filled[cells[0]] = cells[1].strip_edges() != "" and cells[2].strip_edges() != ""
	file.close()
	var keys: Array[String] = ["UI_MENU_STYLE", "UI_MENU_STYLE_PAINTERLY", "UI_MENU_STYLE_PIXEL"]
	for key: String in keys:
		assert_bool(filled.get(key, false) as bool).is_true()


func test_runtime_is_pixel_by_default() -> void:
	# Owner decision 2026-11-27: Pixel is the default style; Painterly stays selectable in Settings.
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	var rt: LevelRuntime = _make_runtime()
	assert_int(rt.load_level(&"test_tiny")).is_equal(OK)
	assert_str(str(rt.visual_style())).is_equal("pixel")
	assert_object(rt.pixel_view()).is_not_null()


func test_runtime_reads_the_saved_style_and_keeps_the_hud_at_full_resolution() -> void:
	var menu: Menus = auto_free(Menus.new()) as Menus
	add_child(menu)
	menu.set_option(&"visual_style", "pixel")
	var rt: LevelRuntime = _make_runtime()
	assert_int(rt.load_level(&"test_tiny")).is_equal(OK)
	assert_str(str(rt.visual_style())).is_equal("pixel")
	var view: PixelView = rt.pixel_view()
	assert_object(view).is_not_null()
	var low: SubViewport = view.sub_viewport()
	# The HUD, the dialogue box and every other CanvasLayer of the runtime stay outside the low-res viewport
	# and above the upscaled image.
	assert_bool(_inside(rt.hud(), low)).is_false()
	assert_bool(_inside(rt.dialogue_box(), low)).is_false()
	assert_bool(rt.hud().get_viewport() == rt.get_viewport()).is_true()
	assert_bool(rt.dialogue_box().get_viewport() == rt.get_viewport()).is_true()
	assert_bool(rt.hud().layer > view.layer).is_true()
	for node: Node in rt.find_children("*", "CanvasLayer", true, false):
		if node == view:
			continue
		assert_bool(_inside(node, low)).is_false()
		assert_bool((node as CanvasLayer).layer > view.layer).is_true()
	# The world itself is not moved: the player and the camera rig keep their places under the runtime.
	assert_bool(rt.player().get_parent() == rt).is_true()
	assert_bool(rt.player().get_node_or_null(rt.player().camera_path) == rt.camera()).is_true()
	assert_bool(low.world_3d == rt.get_viewport().find_world_3d()).is_true()


func test_runtime_switches_style_live_and_back() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	var menu: Menus = auto_free(Menus.new()) as Menus
	add_child(menu)
	menu.set_option(&"visual_style", "painterly")  # pixel is the default now; start from painterly to test switching
	var rt: LevelRuntime = _make_runtime()
	assert_int(rt.load_level(&"test_tiny")).is_equal(OK)
	assert_object(rt.pixel_view()).is_null()
	# Pixel is the default, so runtimes left over from other suites may still hold the shared tuning and the root
	# viewport's 3D switch; compare against the state before this runtime switches.
	var base_users: int = PixelView.tuning_users()
	var base_3d: bool = rt.get_viewport().disable_3d
	menu.set_option(&"visual_style", "pixel")
	assert_object(rt.pixel_view()).is_not_null()
	assert_bool(PixelView.is_material_tuning_active()).is_true()
	assert_bool(rt.get_viewport().disable_3d).is_true()
	menu.set_option(&"visual_style", "painterly")
	assert_object(rt.pixel_view()).is_null()
	assert_int(PixelView.tuning_users()).is_equal(base_users)
	assert_bool(rt.get_viewport().disable_3d).is_equal(base_3d)
	rt.set_visual_style(&"pixel")
	assert_object(rt.pixel_view()).is_not_null()
	rt.set_visual_style(&"nonsense")
	assert_str(str(rt.visual_style())).is_equal("pixel")
	rt.unload()
	assert_object(rt.pixel_view()).is_null()
	assert_bool(rt.get_viewport().disable_3d).is_equal(base_3d)
