extends SceneTree
## Dev-only (PX1 experiment): renders the SAME frame in the 'Painterly' and the 'Pixel' visual style and saves
## side-by-side PNGs (left Painterly, right Pixel, labelled), plus a 2x close crop of the middle of each frame.
## Usage: godot --path . -s dev/preview/compare_styles.gd -- <out_dir> [lang en|hi] [only_scene]
## Scenes: mahendra (Hanuman and Jambavan), lanka_rooftops, lanka_streets, npc_closeup (Rama, Sita, Jambavan).
## Writes <out_dir>/compare_<scene>.png and <out_dir>/compare_<scene>_detail.png.

const LEVELS: Array[StringName] = [&"mahendra", &"lanka_rooftops", &"lanka_streets"]
## The NPC Hanuman stands next to in a level's shot.
const COMPANIONS: Dictionary[StringName, StringName] = {&"mahendra": &"jambavan"}
const COMPANION_OFFSET: Vector3 = Vector3(-1.6, 0.2, 1.0)
const FRAME_SIZE: Vector2i = Vector2i(1920, 1080)
const NPC_SCENE: StringName = &"npc_closeup"
const WARM_UP_FRAMES: int = 40
const SETTLE_FRAMES: int = 6
const LABEL_LAYER: int = 100
## The part of a frame the detail sheet enlarges, as fractions of the frame: Hanuman (the camera aims at his
## feet) and whoever stands beside him in a level; Rama and Sita in the close-up.
const LEVEL_DETAIL: Rect2 = Rect2(0.36, 0.16, 0.36, 0.64)
const NPC_DETAIL: Rect2 = Rect2(0.02, 0.14, 0.3, 0.62)
const GAP: int = 8

var _label_layer: CanvasLayer = null
var _label: Label = null
var _stage: SubViewport = null


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/compare_styles"
	var lang: String = args[1] if args.size() > 1 else "en"
	var only: String = args[2] if args.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	await process_frame
	var locale: Node = get_root().get_node_or_null("/root/Locale")
	if locale != null:
		locale.call("set_language", StringName(lang))
	_build_label()
	for level_id: StringName in LEVELS:
		if only == "" or only == String(level_id):
			await _compare_level(level_id, out_dir)
	if only == "" or only == String(NPC_SCENE):
		await _compare_npcs(out_dir)
	quit()


## Everything is rendered in an off-screen 1920 x 1080 viewport, so the frames do not depend on the size the
## window manager gives the window (the window only mirrors it).
func _build_stage() -> void:
	_stage = SubViewport.new()
	_stage.size = FRAME_SIZE
	_stage.own_world_3d = true
	_stage.msaa_3d = Viewport.MSAA_2X
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_stage)
	var mirror: TextureRect = TextureRect.new()
	mirror.texture = _stage.get_texture()
	mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mirror.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mirror.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(mirror)


func _build_label() -> void:
	_label_layer = CanvasLayer.new()
	_label_layer.layer = LABEL_LAYER
	_label_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_stage.add_child(_label_layer)
	var plate: PanelContainer = PanelContainer.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	plate.position.y -= 24.0
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.04, 0.08, 0.85)
	box.set_content_margin_all(12.0)
	box.set_corner_radius_all(6)
	plate.add_theme_stylebox_override("panel", box)
	_label_layer.add_child(plate)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 34)
	plate.add_child(_label)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


## One frame of the root window with `caption` on it.
func _capture(caption: String) -> Image:
	_label.text = caption
	await _frames(SETTLE_FRAMES)
	await RenderingServer.frame_post_draw
	return _stage.get_texture().get_image()


func _compare_level(level_id: StringName, out_dir: String) -> void:
	var rt: LevelRuntime = LevelRuntime.new()
	rt.music_enabled = false
	_stage.add_child(rt)
	rt.set_visual_style(&"painterly")
	rt.load_level(level_id)
	_stand_next_to(rt, COMPANIONS.get(level_id, &"") as StringName)
	await _frames(WARM_UP_FRAMES)
	# Freeze the game so both styles show the same frame (the PixelView keeps running while paused).
	paused = true
	var painterly: Image = await _capture("Painterly (current)")
	rt.set_visual_style(&"pixel")
	var pixel: Image = await _capture("Pixel (experiment)")
	paused = false
	_save_pair(painterly, pixel, out_dir, String(level_id), LEVEL_DETAIL)
	rt.unload()
	_stage.remove_child(rt)
	rt.queue_free()
	await _frames(2)


## Puts Hanuman beside an NPC of the level, so both are in the frame.
func _stand_next_to(rt: LevelRuntime, actor_id: StringName) -> void:
	var actor: Node3D = rt.actors().get(String(actor_id)) as Node3D
	if actor == null or rt.player() == null:
		return
	rt.player().global_position = actor.global_position + COMPANION_OFFSET
	rt.camera().global_position = rt.player().global_position


func _compare_npcs(out_dir: String) -> void:
	var stage: Node3D = Node3D.new()
	_stage.add_child(stage)
	Look.apply(&"day", stage, &"high")
	var ids: Array[StringName] = [&"rama", &"sita", &"jambavan"]
	for i: int in ids.size():
		var npc: Node3D = NpcModels.build(ids[i])
		npc.position = Vector3(float(i) * 2.4, 0.0, 0.0)
		npc.rotation_degrees.y = 200.0
		stage.add_child(npc)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.4
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(2.4, 2.0, 30.0), Vector3(2.4, 0.9, 0.0))
	cam.make_current()
	await _frames(WARM_UP_FRAMES / 2)
	paused = true
	var painterly: Image = await _capture("Painterly (current)")
	var view: PixelView = PixelView.new()
	stage.add_child(view)
	var pixel: Image = await _capture("Pixel (experiment)")
	paused = false
	_save_pair(painterly, pixel, out_dir, String(NPC_SCENE), NPC_DETAIL)
	_stage.remove_child(stage)
	stage.queue_free()
	await _frames(2)


func _save_pair(left: Image, right: Image, out_dir: String, scene: String, detail_part: Rect2) -> void:
	left.convert(Image.FORMAT_RGB8)
	right.convert(Image.FORMAT_RGB8)
	var full: String = out_dir.path_join("compare_%s.png" % scene)
	_side_by_side(left, right).save_png(full)
	var detail: String = out_dir.path_join("compare_%s_detail.png" % scene)
	_side_by_side(_detail(left, detail_part), _detail(right, detail_part)).save_png(detail)
	print("compare_styles: wrote ", full, " and ", detail)


## A part of a frame (fractions of its size), enlarged 2x without smoothing.
func _detail(frame: Image, part: Rect2) -> Image:
	var size: Vector2 = Vector2(frame.get_size())
	var region: Rect2i = Rect2i(Vector2i(part.position * size), Vector2i(part.size * size))
	var crop: Image = frame.get_region(region)
	crop.resize(region.size.x * 2, region.size.y * 2, Image.INTERPOLATE_NEAREST)
	return crop


func _side_by_side(left: Image, right: Image) -> Image:
	var size: Vector2i = left.get_size()
	var sheet: Image = Image.create(size.x * 2 + GAP, size.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.05, 0.04, 0.08))
	sheet.blit_rect(left, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	sheet.blit_rect(right, Rect2i(Vector2i.ZERO, right.get_size()), Vector2i(size.x + GAP, 0))
	return sheet
