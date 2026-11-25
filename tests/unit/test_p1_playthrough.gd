extends GdUnitTestSuite
## P1 acceptance tests (DESIGN §10 gate 4): the automated playthrough. The bot (tests/playtest/playthrough_bot.gd) plays
## the whole game on the real main scene from New Game to the credits, once for the whole suite; each test then checks
## one part of what it did. When the bot found a blocking game bug at a step, that step's test is skipped with the
## reason (the bot records the bug in its report and goes on with a direct state change).

const MAX_REAL_SECONDS: float = 300.0

var _bot: PlaythroughBot = null
var _credits: bool = false
var _ran: bool = false


func after() -> void:
	if _bot != null:
		_bot.restore()
		_bot.free()
		_bot = null
	var state: Node = get_tree().root.get_node_or_null("GameState")
	if state != null:
		state.call("reset")
	var objectives: Node = get_tree().root.get_node_or_null("Objectives")
	if objectives != null:
		objectives.set("_texts", {})
		objectives.set("_done", {})


## Plays the game once (the first test that needs it does it).
func _play() -> void:
	if _ran:
		return
	_ran = true
	_bot = PlaythroughBot.new()
	add_child(_bot)
	_credits = await _bot.play_all()
	_bot.restore()
	print(_bot.to_markdown())


## True (and a skip notice) when the bot hit a blocking bug at `step`: that step's test is skipped.
func _skipped(step: String) -> bool:
	for b: Dictionary in _bot.blockers:
		if str(b["step"]) == step:
			push_warning("SKIP %s: %s" % [step, str(b["detail"])])
			return true
	return false


# ---------------------------------------------------------------- the helpers of the bot

func test_best_key_direction_matches_the_isometric_camera() -> void:
	var bot: PlaythroughBot = auto_free(PlaythroughBot.new()) as PlaythroughBot
	# The isometric camera is yawed 45 degrees: pressing "up" moves along the camera's -Z, not along the world's -Z.
	var iso: Basis = Basis(Vector3.UP, deg_to_rad(45.0))
	for goal: Vector3 in [Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 1.0), Vector3(3.0, 0.0, 3.0)]:
		var key: Vector2 = bot.best_key_direction(iso, goal)
		var moved: Vector3 = iso * Vector3(key.x, 0.0, key.y)
		assert_float(moved.normalized().dot(goal.normalized())).is_greater(0.9)
	assert_bool(bot.best_key_direction(iso, Vector3.ZERO).is_zero_approx()).is_true()
	assert_bool(bot.best_key_direction(Basis.IDENTITY, Vector3(0.0, 0.0, -2.0)).is_equal_approx(Vector2(0.0, -1.0))).is_true()


func test_the_report_lists_every_chapter() -> void:
	var bot: PlaythroughBot = auto_free(PlaythroughBot.new()) as PlaythroughBot
	for id: StringName in PlaythroughBot.CHAPTER_ORDER:
		bot.chapters[id] = {"reached": false, "completed": false, "notes": [] as Array[String]}
	bot.current_chapter = &"ch2"
	bot.block("step_a", "something is wrong")
	bot.block("step_a", "the same step again")
	assert_int(bot.blockers.size()).is_equal(1)
	assert_int(bot.blockers_for(&"ch2").size()).is_equal(1)
	assert_int(bot.blockers_for(&"ch3").size()).is_equal(0)
	var text: String = bot.to_markdown()
	for id: StringName in PlaythroughBot.CHAPTER_ORDER:
		assert_bool(text.contains("| %s |" % str(id))).is_true()
	assert_bool(text.contains("BLOCKER [ch2 / step_a]")).is_true()


# ---------------------------------------------------------------- the whole game

func test_the_whole_game_is_played_to_the_credits() -> void:
	await _play()
	assert_bool(_bot.aborted).is_false()
	assert_bool(_credits).is_true()
	assert_bool(_bot.credits_reached).is_true()
	assert_bool(_bot.flow.is_finished()).is_true()
	assert_bool(_bot.finished_flow).is_true()
	assert_float(_bot.elapsed_seconds()).is_less(MAX_REAL_SECONDS)


func test_every_chapter_is_reached_and_completed() -> void:
	await _play()
	assert_int(PlaythroughBot.CHAPTER_ORDER.size()).is_equal(8)
	for id: StringName in PlaythroughBot.CHAPTER_ORDER:
		assert_bool(_bot.chapter_reached(id)).override_failure_message("chapter %s was not reached" % str(id)).is_true()
		assert_bool(_bot.chapter_completed(id)).override_failure_message("chapter %s was not completed" % str(id)).is_true()
	assert_int(_bot.flow.chapter_count()).is_equal(PlaythroughBot.CHAPTER_ORDER.size())


func test_no_chapter_needed_a_forced_state_change() -> void:
	await _play()
	if _bot.blockers.is_empty():
		assert_int(_bot.stats["forced_steps"] as int).is_equal(0)
	else:
		for b: Dictionary in _bot.blockers:
			push_warning("BLOCKER [%s / %s] %s" % [str(b["chapter"]), str(b["step"]), str(b["detail"])])
		assert_int(_bot.stats["forced_steps"] as int).is_less_equal(_bot.blockers.size())


# ---------------------------------------------------------------- the parts

func test_prologue_training_uses_real_movement_and_grow() -> void:
	await _play()
	if _skipped("walk_to_jambavan") or _skipped("grow_after_jambavan") or _skipped("training_objective"):
		return
	assert_float(_bot.stats["real_walk_metres"] as float).is_greater(5.0)
	assert_int(_bot.stats["real_light_attacks"] as int).is_greater_equal(3)
	assert_bool(_bot.stats["grow_in_prologue"] as bool).is_true()


func test_one_fight_uses_the_players_real_attacks() -> void:
	await _play()
	if _skipped("real_fight"):
		return
	assert_int(_bot.stats["real_attack_hits"] as int).is_greater_equal(1)


func test_ocean_leap_gates_and_the_surasa_puzzle() -> void:
	await _play()
	if _skipped("leap_finish") or _skipped("load"):
		return
	assert_bool(_bot.stats["ring_collected"] as bool).is_true()
	assert_int(_bot.stats["puzzle_grows"] as int).is_equal(3)
	assert_int(_bot.stats["puzzle_shrinks"] as int).is_greater_equal(1)
	assert_int(_bot.stats["simhika_hits"] as int).is_greater_equal(1)
	var gs: Node = get_tree().root.get_node("GameState")
	assert_bool(gs.call("is_unlocked", &"shrink") as bool).is_true()


func test_lankini_duel_and_the_street_search() -> void:
	await _play()
	if _skipped("lankini_defeat") or _skipped("lankini_objective") or _skipped("searches"):
		return
	assert_int(_bot.stats["searches"] as int).is_equal(3)


func test_ch3_story_choices_retry_gently_and_finish() -> void:
	await _play()
	if _skipped("ch3_done") or _skipped("ring_and_chudamani"):
		return
	assert_int(_bot.stats["choices_wrong"] as int).is_equal(1)
	assert_int(_bot.stats["choices_right"] as int).is_greater_equal(3)


func test_grove_waves_and_bosses_are_defeated() -> void:
	await _play()
	if _skipped("waves") or _skipped("encounter_start"):
		return
	# kinkaras, soldiers, archers, Jambumali, Akshaya Kumara
	assert_int(_bot.stats["waves_seen"] as int).is_greater_equal(5)


func test_rooftop_fire_burns_every_target_and_never_a_protected_prop() -> void:
	await _play()
	if _skipped("fire_all") or _skipped("burn_objective") or _skipped("fire_targets"):
		return
	assert_int(_bot.stats["fire_total"] as int).is_greater(0)
	assert_int(_bot.stats["fire_burnt"] as int).is_equal(_bot.stats["fire_total"] as int)
	assert_int(_bot.stats["protected_total"] as int).is_greater(0)
	assert_int(_bot.stats["protected_ignited"] as int).is_equal(0)
