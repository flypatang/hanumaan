extends GdUnitTestSuite
## PX2 acceptance tests: Pixel style v2 (the default look). Per-mood palettes with colour quantisation, ordered
## dithering, stepped light bands, automatic finer pixels for close cameras, and snapping that holds for any yaw.

const ISO_PITCH: float = 35.264


func after_test() -> void:
	PixelView.apply_material_tuning(false)


func _iso_basis(yaw: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -deg_to_rad(ISO_PITCH))


func _host() -> Node3D:
	var host: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(host)
	return host


func _ortho_camera(host: Node3D, size: float) -> Camera3D:
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	host.add_child(cam)
	cam.global_transform = Transform3D(_iso_basis(PI / 4.0), Vector3(10.0, 20.0, 10.0))
	cam.make_current()
	return cam


func _luma(colour: Color) -> float:
	return colour.r * 0.299 + colour.g * 0.587 + colour.b * 0.114


func _has_colour(palette: PackedColorArray, colour: Color) -> bool:
	for entry: Color in palette:
		if entry.is_equal_approx(colour):
			return true
	return false


# ---------------------------------------------------------------- (a) palettes

func test_every_mood_has_a_limited_palette() -> void:
	assert_array(PixelView.PALETTE_MOODS).contains_exactly([&"dawn", &"day", &"dusk", &"night", &"inferno"])
	for mood: StringName in PixelView.PALETTE_MOODS:
		var palette: PackedColorArray = PixelView.palette(mood)
		assert_bool(palette.size() >= 16).is_true()
		assert_bool(palette.size() <= PixelView.MAX_PALETTE).is_true()
		for i: int in palette.size():
			for j: int in range(i + 1, palette.size()):
				assert_bool(palette[i].is_equal_approx(palette[j])).is_false()


func test_palettes_span_dark_to_light() -> void:
	for mood: StringName in PixelView.PALETTE_MOODS:
		var darkest: float = 1.0
		var lightest: float = 0.0
		for colour: Color in PixelView.palette(mood):
			darkest = minf(darkest, _luma(colour))
			lightest = maxf(lightest, _luma(colour))
		assert_bool(darkest < 0.12).is_true()
		assert_bool(lightest > 0.7).is_true()


func _warmth(mood: StringName) -> float:
	var red: float = 0.0
	var blue: float = 0.0
	for colour: Color in PixelView.palette(mood):
		red += colour.r
		blue += colour.b
	return red / blue


func test_palettes_are_warm_and_the_night_is_the_coolest() -> void:
	for mood: StringName in PixelView.PALETTE_MOODS:
		if mood != &"night":
			assert_bool(_warmth(mood) > 1.3).is_true()
			assert_bool(_warmth(mood) > _warmth(&"night") * 1.2).is_true()
	# Lanka's lamps and gold stay warm even at night.
	var lamp: Color = PixelView.quantise(Color(0.95, 0.6, 0.2), PixelView.palette(&"night"))
	assert_bool(lamp.r > lamp.b * 1.5).is_true()


func test_moods_have_different_palettes_and_unknown_moods_fall_back() -> void:
	assert_bool(PixelView.palette(&"dawn") == PixelView.palette(&"night")).is_false()
	assert_bool(PixelView.palette(&"day") == PixelView.palette(&"inferno")).is_false()
	assert_bool(PixelView.palette(&"dusk") == PixelView.palette(&"dawn")).is_false()
	assert_str(str(PixelView.resolve_palette_mood(&"nonsense"))).is_equal("day")
	assert_str(str(PixelView.resolve_palette_mood(&"divine"))).is_equal("dawn")
	assert_str(str(PixelView.resolve_palette_mood(&"inferno"))).is_equal("inferno")
	assert_bool(PixelView.palette(&"nonsense") == PixelView.palette(&"day")).is_true()


func test_quantise_returns_the_nearest_palette_colour() -> void:
	for mood: StringName in PixelView.PALETTE_MOODS:
		var palette: PackedColorArray = PixelView.palette(mood)
		for entry: Color in palette:
			assert_bool(PixelView.quantise(entry, palette).is_equal_approx(entry)).is_true()
		for probe: Color in [Color(0.9, 0.55, 0.2), Color(0.2, 0.5, 0.25), Color(0.05, 0.04, 0.1), Color(0.95, 0.95, 0.9)]:
			assert_bool(_has_colour(palette, PixelView.quantise(probe, palette))).is_true()


func test_quantise_keeps_the_hue_family() -> void:
	var palette: PackedColorArray = PixelView.palette(&"day")
	var green: Color = PixelView.quantise(Color(0.25, 0.55, 0.2), palette)
	assert_bool(green.g > green.r and green.g > green.b).is_true()
	var saffron: Color = PixelView.quantise(Color(0.95, 0.55, 0.16), palette)
	assert_bool(saffron.r > saffron.g and saffron.g > saffron.b).is_true()
	var red: Color = PixelView.quantise(Color(0.8, 0.15, 0.2), palette)
	assert_bool(red.r > red.g * 2.0).is_true()


# ---------------------------------------------------------------- (b) ordered dithering

func test_bayer_thresholds_are_a_balanced_4x4_pattern() -> void:
	var seen: Dictionary[float, bool] = {}
	var total: float = 0.0
	for y: int in 4:
		for x: int in 4:
			var threshold: float = PixelView.bayer_threshold(Vector2i(x, y))
			assert_bool(threshold >= -0.5 and threshold < 0.5).is_true()
			seen[threshold] = true
			total += threshold
	assert_int(seen.size()).is_equal(16)
	assert_float(total).is_equal_approx(0.0, 0.0001)
	assert_float(PixelView.bayer_threshold(Vector2i(5, -3))).is_equal_approx(PixelView.bayer_threshold(Vector2i(1, 1)), 0.00001)


func test_dither_mixes_two_shades_on_a_transition_and_leaves_flat_colours_alone() -> void:
	assert_bool(PixelView.DITHER > 0.0).is_true()
	var palette: PackedColorArray = PixelView.palette(&"day")
	# A palette colour stays itself in every cell: flat areas do not sparkle.
	for entry: Color in palette:
		for y: int in 4:
			for x: int in 4:
				assert_bool(PixelView.quantise_dithered(entry, palette, Vector2i(x, y)).is_equal_approx(entry)).is_true()
	# Somewhere along a slow gradient two shades alternate inside one 4x4 block.
	var mixed: bool = false
	for step: int in 200:
		var value: float = 0.1 + 0.8 * float(step) / 199.0
		var colour: Color = Color(value, value * 0.62, value * 0.3)
		var first: Color = PixelView.quantise_dithered(colour, palette, Vector2i.ZERO)
		for y: int in 4:
			for x: int in 4:
				if not PixelView.quantise_dithered(colour, palette, Vector2i(x, y)).is_equal_approx(first):
					mixed = true
	assert_bool(mixed).is_true()


func test_upscale_pass_quantises_to_the_palette_without_filtering() -> void:
	var host: Node3D = _host()
	var view: PixelView = PixelView.new()
	host.add_child(view)
	var material: ShaderMaterial = view.display().material as ShaderMaterial
	assert_object(material).is_not_null()
	assert_bool(material.shader.code.contains("palette")).is_true()
	assert_bool(material.shader.code.contains("BAYER")).is_true()
	assert_int(material.get_shader_parameter(&"palette_size") as int).is_equal(PixelView.palette(view.palette_mood()).size())
	assert_int(view.display().texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_bool(view.sub_viewport().use_taa).is_false()
	assert_int(view.sub_viewport().screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_int(view.sub_viewport().msaa_3d).is_equal(Viewport.MSAA_DISABLED)


func test_view_takes_the_palette_of_the_look_mood() -> void:
	var host: Node3D = _host()
	Look.apply(&"dusk", host, &"medium")
	var view: PixelView = PixelView.new()
	host.add_child(view)
	view.refresh()
	assert_str(str(view.palette_mood())).is_equal("dusk")
	Look.apply(&"inferno", host, &"medium")
	view.refresh()
	assert_str(str(view.palette_mood())).is_equal("inferno")
	view.set_palette_mood(&"night")
	view.refresh()
	assert_str(str(view.palette_mood())).is_equal("night")
	view.set_palette_mood(&"")
	view.refresh()
	assert_str(str(view.palette_mood())).is_equal("inferno")


func test_view_without_a_look_rig_uses_the_day_palette() -> void:
	var host: Node3D = _host()
	var view: PixelView = PixelView.new()
	host.add_child(view)
	view.refresh()
	assert_str(str(view.palette_mood())).is_equal("day")


# ---------------------------------------------------------------- (c) outlines and highlights

func test_outline_pass_draws_silhouettes_and_top_edge_highlights() -> void:
	var shader: Shader = load(PixelView.OUTLINE_SHADER_PATH) as Shader
	assert_object(shader).is_not_null()
	var code: String = shader.code
	for uniform_name: String in ["outline_strength", "outline_tint", "highlight_strength", "rim_strength", "crease_strength"]:
		assert_bool(code.contains("uniform float " + uniform_name) or code.contains("uniform vec3 " + uniform_name)).is_true()
	assert_bool(code.contains("filter_nearest")).is_true()
	assert_bool(code.contains("filter_linear")).is_false()


# ---------------------------------------------------------------- (d) stepped lighting

func test_tuning_gives_stepped_bands_with_stronger_coloured_shadows_and_restores() -> void:
	var names: Array[StringName] = [&"stone", &"fur", &"cloth", &"foliage"]
	var before_blend: Array[float] = []
	var before_shadow: Array[float] = []
	for kind: StringName in names:
		var material: ShaderMaterial = Materials.get_material(kind)
		before_blend.append(material.get_shader_parameter(&"band_continuous") as float)
		before_shadow.append(material.get_shader_parameter(&"shadow_strength") as float)
	PixelView.apply_material_tuning(true)
	for i: int in names.size():
		var material: ShaderMaterial = Materials.get_material(names[i])
		assert_float(material.get_shader_parameter(&"band_continuous") as float).is_equal_approx(0.0, 0.0001)
		assert_bool((material.get_shader_parameter(&"band_softness") as float) <= 0.03).is_true()
		assert_bool((material.get_shader_parameter(&"shadow_strength") as float) > before_shadow[i]).is_true()
	PixelView.apply_material_tuning(false)
	for i: int in names.size():
		var material: ShaderMaterial = Materials.get_material(names[i])
		assert_float(material.get_shader_parameter(&"band_continuous") as float).is_equal_approx(before_blend[i], 0.0001)
		assert_float(material.get_shader_parameter(&"shadow_strength") as float).is_equal_approx(before_shadow[i], 0.0001)


# ---------------------------------------------------------------- (e) finer pixels for close cameras

func test_close_cameras_get_finer_art_pixels() -> void:
	assert_int(PixelView.CLOSE_ART_PIXEL).is_equal(2)
	# Gameplay framings keep the chunky default.
	for size: float in [7.5, 9.5, 12.5, 14.0, 30.0]:
		assert_int(PixelView.art_pixel_for_view(size, 4)).is_equal(4)
	# Close-ups step down to 3 and then 2 screen pixels per art pixel.
	assert_int(PixelView.art_pixel_for_view(5.6, 4)).is_equal(3)
	assert_int(PixelView.art_pixel_for_view(4.4, 4)).is_equal(2)
	assert_int(PixelView.art_pixel_for_view(2.0, 4)).is_equal(2)
	# Never coarser than the base, never finer than the close size unless the base already is.
	assert_int(PixelView.art_pixel_for_view(14.0, 2)).is_equal(2)
	assert_int(PixelView.art_pixel_for_view(4.0, 1)).is_equal(1)
	assert_int(PixelView.art_pixel_for_view(4.0, 6)).is_equal(2)
	assert_int(PixelView.art_pixel_for_view(5.6, 6)).is_equal(3)
	assert_int(PixelView.art_pixel_for_view(14.0, 6)).is_equal(6)
	# Perspective cameras are the cutscene close-ups.
	assert_int(PixelView.art_pixel_for_perspective(4)).is_equal(2)
	assert_int(PixelView.art_pixel_for_perspective(1)).is_equal(1)


func test_art_pixel_choice_has_hysteresis() -> void:
	var edge: float = PixelView.CLOSE_ORTHO_SIZE
	assert_int(PixelView.art_pixel_for_view(edge * 1.03, 4, 2)).is_equal(2)
	assert_int(PixelView.art_pixel_for_view(edge * 1.03, 4, 3)).is_equal(3)
	assert_int(PixelView.art_pixel_for_view(edge * 0.97, 4, 3)).is_equal(3)
	assert_int(PixelView.art_pixel_for_view(edge * 0.97, 4, 2)).is_equal(2)
	assert_int(PixelView.art_pixel_for_view(edge * 0.8, 4, 3)).is_equal(2)
	assert_int(PixelView.art_pixel_for_view(edge * 1.2, 4, 2)).is_equal(3)


func test_view_lowers_its_pixel_scale_when_the_camera_comes_close_and_restores_it() -> void:
	var host: Node3D = _host()
	var cam: Camera3D = _ortho_camera(host, 7.5)
	var view: PixelView = PixelView.new()
	host.add_child(view)
	view.refresh()
	var window: Vector2i = view.window_size()
	assert_int(view.current_art_pixel()).is_equal(4)
	assert_object(view.art_size()).is_equal(PixelView.art_resolution(window, 4))
	cam.size = 3.6
	view.refresh()
	assert_int(view.current_art_pixel()).is_equal(2)
	assert_int(view.screen_scale()).is_equal(PixelView.pixel_scale(window.y, 2))
	assert_object(view.art_size()).is_equal(PixelView.art_resolution(window, 2))
	assert_object(view.sub_viewport().size).is_equal(view.art_size() + Vector2i.ONE * 2 * PixelView.MARGIN)
	# The snap follows the new grid.
	var expected: Transform3D = PixelView.snap_transform(cam.global_transform, 3.6, view.art_size().y)
	assert_bool(view.pixel_camera().global_transform.is_equal_approx(expected)).is_true()
	cam.size = 7.5
	view.refresh()
	assert_int(view.current_art_pixel()).is_equal(4)
	assert_int(view.art_pixel).is_equal(4)


func test_perspective_cutscene_camera_gets_the_close_scale() -> void:
	var host: Node3D = _host()
	var cam: Camera3D = Camera3D.new()
	cam.fov = 50.0
	host.add_child(cam)
	cam.make_current()
	var view: PixelView = PixelView.new()
	host.add_child(view)
	view.refresh()
	assert_int(view.current_art_pixel()).is_equal(2)


func test_auto_detail_can_be_switched_off() -> void:
	var host: Node3D = _host()
	_ortho_camera(host, 3.0)
	var view: PixelView = PixelView.new()
	view.auto_detail = false
	host.add_child(view)
	view.refresh()
	assert_int(view.current_art_pixel()).is_equal(4)


# ---------------------------------------------------------------- (f) no shimmer for any yaw

func test_a_pan_never_moves_a_static_point_by_a_fraction_of_a_pixel_at_any_yaw() -> void:
	var art: Vector2i = Vector2i(480, 270)
	var points: Array[Vector3] = [Vector3(4.0, 0.0, 6.0), Vector3(-7.3, 2.1, 1.9)]
	for yaw_step: int in 24:
		var yaw: float = deg_to_rad(float(yaw_step) * 17.0 + 3.0)
		var basis: Basis = _iso_basis(yaw)
		for point: Vector3 in points:
			var first: Vector2 = Vector2.INF
			for i: int in 40:
				var origin: Vector3 = Vector3(10.0 + float(i) * 0.0137, 20.0, 10.0 - float(i) * 0.0093) + basis.z * 5.0
				var cam: Transform3D = Transform3D(basis, origin)
				var px: Vector2 = PixelView.project_to_art(PixelView.snap_transform(cam, 7.5, art.y), 7.5, art, point)
				var fraction: Vector2 = px - px.floor()
				if first == Vector2.INF:
					first = fraction
				var drift: Vector2 = (fraction - first).abs()
				drift = Vector2(minf(drift.x, 1.0 - drift.x), minf(drift.y, 1.0 - drift.y))
				assert_float(drift.length()).is_equal_approx(0.0, 0.01)


func test_snap_plus_image_shift_equals_the_smooth_camera_at_any_yaw() -> void:
	var art: Vector2i = Vector2i(480, 270)
	for yaw_step: int in 24:
		var yaw: float = deg_to_rad(float(yaw_step) * 15.0 + 7.0)
		var cam: Transform3D = Transform3D(_iso_basis(yaw), Vector3(3.217, 18.0, -4.771))
		var point: Vector3 = Vector3(1.0, 0.5, -2.0)
		var smooth: Vector2 = PixelView.project_to_art(cam, 9.5, art, point)
		var stepped: Vector2 = PixelView.project_to_art(PixelView.snap_transform(cam, 9.5, art.y), 9.5, art, point)
		var shift: Vector2 = PixelView.image_offset(PixelView.snap_remainder(cam, 9.5, art.y), 1)
		assert_float((stepped + shift - smooth).length()).is_equal_approx(0.0, 0.001)
		var rest: Vector2 = PixelView.snap_remainder(cam, 9.5, art.y)
		assert_bool(absf(rest.x) <= 0.5001 and absf(rest.y) <= 0.5001).is_true()


func test_dither_grid_is_anchored_to_the_world() -> void:
	# The dither cell of a static world point does not change while the camera pans by whole art pixels.
	var host: Node3D = _host()
	var cam: Camera3D = _ortho_camera(host, 7.5)
	var view: PixelView = PixelView.new()
	host.add_child(view)
	view.refresh()
	var art: Vector2i = view.art_size()
	var material: ShaderMaterial = view.display().material as ShaderMaterial
	var point: Vector3 = Vector3(1.0, 0.0, 2.0)
	var first: Vector2 = Vector2.INF
	for i: int in 12:
		cam.global_position += cam.global_basis.x * 0.0371 + cam.global_basis.y * 0.0213
		view.refresh()
		var px: Vector2 = PixelView.project_to_art(view.pixel_camera().global_transform, 7.5, art, point).floor()
		var origin: Vector2 = material.get_shader_parameter(&"grid_origin") as Vector2
		var cell: Vector2 = Vector2(fposmod(px.x + origin.x, 4.0), fposmod(px.y + origin.y, 4.0))
		if first == Vector2.INF:
			first = cell
		assert_object(cell).is_equal(first)


# ---------------------------------------------------------------- painterly is untouched

func test_painterly_materials_are_untouched_after_the_view_leaves() -> void:
	var names: Array[StringName] = [&"stone", &"gold", &"skin"]
	var keys: Array[StringName] = [&"band_softness", &"band_continuous", &"detail_strength", &"edge_strength", &"shadow_strength", &"value_variation"]
	var before: Array[float] = []
	for kind: StringName in names:
		for key: StringName in keys:
			before.append(Materials.get_material(kind).get_shader_parameter(key) as float)
	var host: Node3D = _host()
	var view: PixelView = PixelView.new()
	host.add_child(view)
	view.refresh()
	host.remove_child(view)
	view.free()
	var index: int = 0
	for kind: StringName in names:
		for key: StringName in keys:
			assert_float(Materials.get_material(kind).get_shader_parameter(key) as float).is_equal_approx(before[index], 0.00001)
			index += 1
