extends GdUnitTestSuite
## Regressions from the owner's alpha-5 playtest (2026-11-27):
##  1. "There's no dialog": the story must open with Jambavan's dialogue without the player knowing any key.
##  2. "If Hanuman falls into the sea, nothing happens": water and the level edge block him, and a fall is recovered.

const GameStateScript: GDScript = preload("res://core/game_state.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")


func _make(level_id: String) -> LevelRuntime:
	var rt: LevelRuntime = LevelRuntime.new()
	rt.music_enabled = false
	rt.game_state = auto_free(GameStateScript.new()) as Node
	rt.event_bus = auto_free(BusScript.new()) as Node
	add_child(rt)
	auto_free(rt)
	assert_int(rt.load_level(StringName(level_id)) as int).is_equal(OK)
	return rt


func _tick(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func test_walking_into_the_sea_is_blocked() -> void:
	var rt: LevelRuntime = _make("mahendra")
	var p: Player = rt.player()
	p.read_input = false
	# Mahendra's sea is the tile rows z = 0..2; the sand shore starts at z = 3 (world z = 6..8).
	p.global_position = Vector3(13.0, 0.2, 7.0)
	await _tick(10)
	p.move_input = Vector2(0.0, -1.0)
	for i: int in 180:
		p.move_input = Vector2.ZERO
		p.velocity = Vector3(0.0, p.velocity.y, -5.0)
		p.move_and_slide()
		await get_tree().physics_frame
	assert_float(p.global_position.z).is_greater(5.5)  # stopped at the shore, never over the water tiles
	assert_float(p.global_position.y).is_greater(-1.0)


func test_a_fall_below_the_world_is_recovered() -> void:
	var rt: LevelRuntime = _make("mahendra")
	var p: Player = rt.player()
	await _tick(20)
	var safe: Vector3 = p.global_position
	p.global_position = Vector3(safe.x, -20.0, safe.z)
	await _tick(3)
	assert_float(p.global_position.y).is_greater(-1.0)
	assert_float(Vector2(p.global_position.x - safe.x, p.global_position.z - safe.z).length()).is_less(3.0)


func test_the_prologue_opens_with_the_jambavan_scene() -> void:
	var flow: ChapterFlow = auto_free(ChapterFlow.new()) as ChapterFlow
	add_child(flow)
	var entry: Array = flow.chapter_data(0).get("entry_cutscenes", []) as Array
	assert_array(entry).contains(["pro_jambavan_intro"])
	var steps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cutscenes/pro_jambavan_intro.json")) as Dictionary
	var has_dialogue: bool = false
	for st: Variant in steps["steps"] as Array:
		if str((st as Dictionary).get("type", "")) == "dialogue" and str((st as Dictionary).get("id", "")) == "pro_jambavan":
			has_dialogue = true
	assert_bool(has_dialogue).is_true()


func test_the_dialogue_panel_is_on_screen() -> void:
	# "There's no dialog" (2026-11-27): the panel grew downward off the bottom of the screen.
	var rt: LevelRuntime = _make("mahendra")
	assert_bool(rt.play_dialogue("pro_jambavan")).is_true()
	await _tick(3)
	var screen: Rect2 = rt.get_viewport().get_visible_rect()
	for c: Node in rt.dialogue_box().get_children():
		if c is PanelContainer and (c as PanelContainer).visible:
			var r: Rect2 = (c as PanelContainer).get_global_rect()
			assert_bool(screen.encloses(r)).is_true()
			assert_float(r.size.y).is_greater(100.0)
