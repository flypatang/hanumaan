extends GdUnitTestSuite
## CT1 acceptance tests: teaching the controls (DESIGN §4.1a). The Mahendra tutorial is driven with REAL input events
## (Input.parse_input_event of keys and mouse buttons), the glyphs follow the live InputMap, the world prompt shows near
## Jambavan and hides during dialogue, the unlock card pauses and dismisses, the controls screen lists only unlocked
## powers, and no prompt ever shows an action that is not unlocked yet.
## Tests that need the real dialogue flags use the GameState autoload and reset it before and after.

const GameStateScript: GDScript = preload("res://core/game_state.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")
const HINT_WAIT: float = 9.0


func before_test() -> void:
	_reset_autoload_state()
	KeyGlyph.set_gamepad_active(false)
	_register_inputs()
	KeyGlyph.ensure_actions()
	TranslationServer.set_locale("en")


func after_test() -> void:
	_reset_autoload_state()
	KeyGlyph.set_gamepad_active(false)
	_register_inputs()
	TranslationServer.set_locale("en")
	for code: Key in [KEY_W, KEY_F, KEY_E, KEY_SPACE, KEY_TAB, KEY_G]:
		_key(code, false)
	_mouse(false)


func _register_inputs() -> void:
	(load("res://core/input_setup.gd") as GDScript).call("register_all")


func _reset_autoload_state() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")
	if gs != null:
		gs.call("reset")


func _autoload_state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


# ---------------------------------------------------------------- real input helpers

func _key(code: Key, pressed: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()  # input is buffered until the next frame; deliver it now


func _tap_key(code: Key) -> void:
	_key(code, true)
	_key(code, false)


func _mouse(pressed: bool) -> void:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _click() -> void:
	_mouse(true)
	_mouse(false)


func _private_state() -> Node:
	return auto_free(GameStateScript.new()) as Node


func _mahendra(options: Dictionary = {}) -> LevelRuntime:
	var rt: LevelRuntime = LevelRuntime.new()
	rt.music_enabled = false
	auto_free(rt)
	add_child(rt)
	assert_int(rt.load_level(&"mahendra", options)).is_equal(OK)
	return rt


func _step_names(director: TutorialDirector) -> String:
	return str(director.current_step())


# ---------------------------------------------------------------- glyphs

func test_glyph_text_reads_the_live_input_map() -> void:
	assert_str(KeyGlyph.text_for(&"grow")).is_equal("E")
	assert_str(KeyGlyph.text_for(&"shrink")).is_equal("Q")
	assert_str(KeyGlyph.text_for(&"interact")).is_equal("F")
	assert_str(KeyGlyph.text_for(&"leap")).is_equal("Space")
	assert_str(KeyGlyph.text_for(&"attack_light")).is_equal("LMB")
	assert_str(KeyGlyph.text_for(&"smarana_surge")).is_equal("R")
	assert_str(KeyGlyph.text_for(&"pause")).is_equal("Esc")
	assert_str(KeyGlyph.text_for(&"move")).is_equal("WASD")
	assert_str(KeyGlyph.text_for(&"camera")).is_equal("Z / C")
	assert_str(KeyGlyph.text_for(&"show_controls")).is_equal("Tab")
	assert_str(KeyGlyph.text_for(&"no_such_action")).is_equal("?")


func test_glyph_text_follows_a_remapped_action() -> void:
	var glyph: KeyGlyph = KeyGlyph.new()
	auto_free(glyph)
	add_child(glyph)
	glyph.set_action(&"grow")
	assert_str(glyph.shown_text()).is_equal("E")
	InputMap.action_erase_events(&"grow")
	var remapped: InputEventKey = InputEventKey.new()
	remapped.physical_keycode = KEY_G
	InputMap.action_add_event(&"grow", remapped)
	assert_str(KeyGlyph.text_for(&"grow")).is_equal("G")
	glyph.refresh()
	assert_str(glyph.shown_text()).is_equal("G")
	# the glyph also notices a remap by itself (it compares each frame)
	InputMap.action_erase_events(&"grow")
	var again: InputEventKey = InputEventKey.new()
	again.physical_keycode = KEY_T
	InputMap.action_add_event(&"grow", again)
	glyph._process(0.016)
	assert_str(glyph.shown_text()).is_equal("T")


func test_glyph_follows_the_last_used_device() -> void:
	assert_bool(KeyGlyph.gamepad_active()).is_false()
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	assert_bool(KeyGlyph.observe(pad)).is_true()
	assert_str(KeyGlyph.text_for(&"leap")).is_equal("A")
	assert_str(KeyGlyph.text_for(&"grow")).is_equal("RB")
	assert_str(KeyGlyph.text_for(&"shrink")).is_equal("LB")
	assert_str(KeyGlyph.text_for(&"interact")).is_equal("Y")
	assert_str(KeyGlyph.text_for(&"attack_light")).is_equal("X")
	assert_str(KeyGlyph.text_for(&"smarana_surge")).is_equal("RT + LT")
	assert_str(KeyGlyph.text_for(&"move")).is_equal("L Stick")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_W
	assert_bool(KeyGlyph.observe(key)).is_true()
	assert_str(KeyGlyph.text_for(&"leap")).is_equal("Space")
	# stick drift does not switch the device
	var drift: InputEventJoypadMotion = InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.1
	assert_bool(KeyGlyph.observe(drift)).is_false()
	assert_bool(KeyGlyph.gamepad_active()).is_false()


# ---------------------------------------------------------------- the Mahendra tutorial, with real input

func test_the_mahendra_tutorial_advances_on_real_input() -> void:
	var rt: LevelRuntime = _mahendra()
	var director: TutorialDirector = rt.tutorial()
	assert_object(director).is_not_null()
	assert_bool(director.enabled).is_true()
	assert_bool(director.prologue).is_true()
	var box: DialogueBox = rt.dialogue_box()
	box.chars_per_second = 100000.0
	box.choice_guard_seconds = 0.0

	# 1. move: the card shows on spawn with the live WASD glyph
	assert_str(_step_names(director)).is_equal("move")
	director.tick(0.5)
	assert_bool(director.card_visible()).is_true()
	assert_str(director.card_text()).is_equal("Move around")
	assert_str(director.card_glyph_text()).is_equal("WASD")
	_tap_key(KEY_W)
	assert_str(_step_names(director)).is_equal("talk")

	# 2. talk: first "walk up to Jambavan", then the F glyph once he is near
	director.tick(0.5)
	assert_str(director.card_text()).is_equal("Walk up to Jambavan")
	assert_str(director.card_glyph_text()).is_equal("")
	var jambavan: Node3D = rt.actors()["jambavan"] as Node3D
	rt.player().global_position = jambavan.global_position + Vector3(-2.0, 0.0, 0.0)
	rt.world_prompt().advance(0.5)
	assert_bool(rt.world_prompt().is_showing()).is_true()
	assert_str(String(rt.world_prompt().current_verb())).is_equal("talk")
	assert_str(rt.world_prompt().verb_text()).is_equal("Talk")
	assert_str(rt.world_prompt().glyph().shown_text()).is_equal("F")
	director.tick(0.5)
	assert_str(director.card_text()).is_equal("Talk to Jambavan")
	assert_str(director.card_glyph_text()).is_equal("F")
	assert_bool(rt.dialogue_box().is_playing()).is_false()
	_tap_key(KEY_F)
	assert_bool(rt.dialogue_box().is_playing()).is_true()
	assert_str(_step_names(director)).is_equal("light")
	# the prompt and the card hide while the dialogue is on screen
	rt.world_prompt().advance(0.5)
	assert_bool(rt.world_prompt().is_showing()).is_false()
	director.tick(0.5)
	assert_bool(director.card_visible()).is_false()
	_finish_dialogue(rt)
	assert_bool(rt.input_locked()).is_false()

	# the unlock card for Grow follows Jambavan's words and pauses play until it is dismissed
	assert_bool(rt.check_unlock_cards()).is_true()
	assert_bool(rt.unlock_card().is_open()).is_true()
	assert_bool(rt.input_locked()).is_true()
	rt.unlock_card().guard_seconds = 0.0
	_tap_key(KEY_F)
	assert_bool(rt.unlock_card().is_open()).is_false()
	assert_bool(rt.input_locked()).is_false()

	# 3. light attack, then the 3-hit chain
	director.tick(0.5)
	assert_str(director.card_text()).is_equal("Strike the training rocks")
	assert_str(director.card_glyph_text()).is_equal("LMB")
	_click()
	assert_str(_step_names(director)).is_equal("chain")
	assert_int(director.chain_count()).is_equal(1)
	director.tick(0.5)
	assert_str(director.card_text()).is_equal("Strike three times in a row (1/3)")
	_click()
	assert_int(director.chain_count()).is_equal(2)
	assert_str(_step_names(director)).is_equal("chain")
	_click()
	assert_str(_step_names(director)).is_equal("heavy")

	# 4. heavy attack: a held press
	director.tick(0.5)
	assert_str(director.card_text()).is_equal("Hold to swing a heavy blow")
	director.tick(0.2)
	assert_str(_step_names(director)).is_equal("heavy")
	_mouse(true)
	director.tick(0.3)
	assert_str(_step_names(director)).is_equal("heavy")
	director.tick(0.3)
	_mouse(false)
	assert_str(_step_names(director)).is_equal("dodge")

	# 5. dodge
	director.tick(0.5)
	assert_str(director.card_text()).is_equal("Leap aside to dodge")
	assert_str(director.card_glyph_text()).is_equal("Space")
	_tap_key(KEY_SPACE)
	assert_str(_step_names(director)).is_equal("grow")

	# 6. grow: the card is there because Grow is unlocked, and it waits for the real size change
	director.tick(0.5)
	assert_bool(director.card_visible()).is_true()
	assert_str(director.card_action()).is_equal(&"grow")
	assert_str(director.card_glyph_text()).is_equal("E")
	rt.size_shift().grow()
	director.tick(0.1)
	assert_str(_step_names(director)).is_equal("peak")

	# 7. the peak
	director.tick(0.5)
	assert_str(director.card_text()).is_equal("Climb to the peak and leap")
	assert_bool(rt.fire_trigger(&"t_leap")).is_true()
	assert_bool(director.is_finished()).is_true()


func _finish_dialogue(rt: LevelRuntime) -> void:
	var box: DialogueBox = rt.dialogue_box()
	for i: int in 80:
		if not box.is_playing():
			return
		box.step_typewriter(1.0)
		_tap_key(KEY_F)
	assert_bool(box.is_playing()).is_false()


func test_a_step_the_player_already_did_is_skipped() -> void:
	var rt: LevelRuntime = _mahendra()
	var director: TutorialDirector = rt.tutorial()
	_tap_key(KEY_SPACE)  # dodge before it is asked for
	_tap_key(KEY_W)
	assert_str(_step_names(director)).is_equal("talk")
	assert_bool(director.has_seen(&"dodge")).is_true()


func test_tutorial_hints_off_shows_nothing() -> void:
	var rt: LevelRuntime = _mahendra()
	var director: TutorialDirector = rt.tutorial()
	director.enabled = false
	director.tick(0.5)
	assert_bool(director.card_visible()).is_false()
	director.tick(40.0)
	assert_bool(director.hint_visible()).is_false()
	director.notify_boss_phase("boss_lankini")
	assert_bool(director.hint_visible()).is_false()


# ---------------------------------------------------------------- world prompts

func _prompt_rig(state: Node) -> Dictionary:
	var player: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(player)
	var target: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(target)
	target.global_position = Vector3(10.0, 0.0, 0.0)
	var prompt: WorldPrompt = auto_free(WorldPrompt.new()) as WorldPrompt
	prompt.game_state = state
	add_child(prompt)
	prompt.bind(player, null)
	return {"player": player, "target": target, "prompt": prompt}


func test_world_prompt_shows_within_three_metres_only() -> void:
	var rig: Dictionary = _prompt_rig(_private_state())
	var prompt: WorldPrompt = rig["prompt"] as WorldPrompt
	var player: Node3D = rig["player"] as Node3D
	var target: Node3D = rig["target"] as Node3D
	prompt.add_target(target, &"talk")
	prompt.advance(0.1)
	assert_bool(prompt.is_showing()).is_false()
	player.global_position = Vector3(7.5, 0.0, 0.0)  # 2.5 m away
	prompt.advance(0.1)
	assert_bool(prompt.is_showing()).is_true()
	assert_object(prompt.current_target()).is_same(target)
	assert_str(prompt.verb_text()).is_equal("Talk")
	player.global_position = Vector3(6.5, 0.0, 0.0)  # 3.5 m away
	prompt.advance(0.1)
	assert_bool(prompt.is_showing()).is_false()


func test_world_prompt_hides_while_suppressed_and_in_hindi_reads_hindi() -> void:
	var rig: Dictionary = _prompt_rig(_private_state())
	var prompt: WorldPrompt = rig["prompt"] as WorldPrompt
	(rig["player"] as Node3D).global_position = Vector3(9.0, 0.0, 0.0)
	prompt.add_target(rig["target"] as Node3D, &"meditate", &"interact", true)
	var held: Array[bool] = [false]
	prompt.suppressed = func() -> bool: return held[0]
	prompt.advance(0.1)
	assert_bool(prompt.is_showing()).is_true()
	assert_str(prompt.verb_text()).is_equal("Meditate")
	held[0] = true
	prompt.advance(0.1)
	assert_bool(prompt.is_showing()).is_false()
	held[0] = false
	TranslationServer.set_locale("hi")
	prompt.advance(0.1)
	assert_str(prompt.verb_text()).is_equal("ध्यान करें")


func test_world_prompt_retires_a_verb_after_three_uses_except_for_shrines() -> void:
	var state: Node = _private_state()
	var rig: Dictionary = _prompt_rig(state)
	var prompt: WorldPrompt = rig["prompt"] as WorldPrompt
	(rig["player"] as Node3D).global_position = Vector3(9.0, 0.0, 0.0)
	var target: Node3D = rig["target"] as Node3D
	prompt.add_target(target, &"examine")
	prompt.advance(0.1)
	assert_bool(prompt.is_showing()).is_true()
	for i: int in 3:
		prompt.register_use(&"examine")
	assert_int(prompt.uses(&"examine")).is_equal(3)
	assert_int(state.call("get_flag", &"prompt_uses_examine", 0) as int).is_equal(3)  # saved in GameState
	prompt.advance(0.1)
	assert_bool(prompt.is_showing()).is_false()
	prompt.remove_target(target)
	prompt.add_target(target, &"meditate", &"interact", true)
	for i: int in 5:
		prompt.register_use(&"meditate")
	prompt.advance(0.1)
	assert_bool(prompt.is_showing()).is_true()  # shrines never retire


func test_the_shrine_gets_a_meditate_prompt_in_a_real_level() -> void:
	var rt: LevelRuntime = _mahendra()
	var shrine: Node3D = rt.level_root().find_child("Shrine_shrine_mahendra", true, false) as Node3D
	assert_object(shrine).is_not_null()
	rt.player().global_position = shrine.global_position + Vector3(1.0, 0.0, 0.0)
	rt.world_prompt().advance(0.5)
	assert_bool(rt.world_prompt().is_showing()).is_true()
	assert_str(String(rt.world_prompt().current_verb())).is_equal("meditate")


# ---------------------------------------------------------------- unlock cards

func test_unlock_card_pauses_play_and_dismisses_with_confirm() -> void:
	var rt: LevelRuntime = _mahendra()
	var state: Node = _autoload_state()
	assert_bool(rt.check_unlock_cards()).is_false()  # nothing unlocked, no card
	state.call("unlock", &"shrink")
	assert_bool(rt.check_unlock_cards()).is_true()
	var card: UnlockCard = rt.unlock_card()
	assert_bool(card.is_open()).is_true()
	assert_str(String(card.ability())).is_equal("shrink")
	assert_str(card.title_text()).is_equal("Shrink")
	assert_str(card.glyph_text()).is_equal("Q")
	assert_bool(rt.input_locked()).is_true()
	assert_bool(rt.player().read_input).is_false()
	assert_bool(rt.check_unlock_cards()).is_false()
	card.guard_seconds = 0.0
	var closed: Array[StringName] = []
	card.closed.connect(func(a: StringName) -> void: closed.append(a))
	_click()  # a mouse click dismisses too
	assert_bool(card.is_open()).is_false()
	assert_array(closed).has_size(1)
	assert_bool(rt.input_locked()).is_false()
	assert_bool(rt.player().read_input).is_true()
	assert_bool(rt.check_unlock_cards()).is_false()  # shown once only


func test_unlock_card_ignores_the_press_that_ended_the_dialogue() -> void:
	var card: UnlockCard = auto_free(UnlockCard.new()) as UnlockCard
	add_child(card)
	assert_bool(card.show_for(&"grow")).is_true()
	_tap_key(KEY_F)
	assert_bool(card.is_open()).is_true()  # inside the 0.4 s guard
	card._process(0.5)
	_tap_key(KEY_F)
	assert_bool(card.is_open()).is_false()


func test_every_unlock_card_has_text_and_tail_fire_has_no_key() -> void:
	var card: UnlockCard = auto_free(UnlockCard.new()) as UnlockCard
	add_child(card)
	for ability: StringName in [&"grow", &"shrink", &"surge", &"tail_fire"]:
		assert_bool(card.show_for(ability)).is_true()
		assert_str(card.title_text()).is_not_equal("")
		assert_str(card.body_text()).is_not_equal("")
		assert_bool(card.title_text().begins_with("UNLOCK_")).is_false()
		card.dismiss()
	card.show_for(&"tail_fire")
	assert_str(card.glyph_text()).is_equal("")
	card.dismiss()
	card.show_for(&"surge")
	assert_str(card.glyph_text()).is_equal("R")
	assert_bool(card.show_for(&"flight")).is_false()


# ---------------------------------------------------------------- the controls screen

func test_controls_screen_lists_only_unlocked_powers() -> void:
	var state: Node = _private_state()
	var screen: ControlsScreen = auto_free(ControlsScreen.new()) as ControlsScreen
	screen.game_state = state
	add_child(screen)
	screen.refresh()
	var labels: PackedStringArray = screen.shown_labels()
	assert_bool(labels.has("Light attack")).is_true()
	assert_bool(labels.has("Dodge / leap")).is_true()
	assert_bool(labels.has("Grow")).is_false()
	assert_bool(labels.has("Shrink")).is_false()
	assert_bool(labels.has("Smarana surge")).is_false()
	assert_bool(screen.shown_groups().has(&"powers")).is_false()
	assert_array(screen.shown_groups()).contains_exactly([&"move", &"fight", &"menus"])
	state.call("unlock", &"grow")
	screen.refresh()
	labels = screen.shown_labels()
	assert_bool(labels.has("Grow")).is_true()
	assert_bool(labels.has("Shrink")).is_false()
	assert_array(screen.shown_groups()).contains_exactly([&"move", &"fight", &"powers", &"menus"])
	state.call("unlock", &"shrink")
	state.call("unlock", &"surge")
	state.call("unlock", &"tail_fire")
	labels = screen.shown_labels()
	for expected: String in ["Grow", "Shrink", "Smarana surge", "Tail fire (always lit)"]:
		assert_bool(labels.has(expected)).is_true()


func test_controls_screen_opens_while_tab_is_held() -> void:
	var rt: LevelRuntime = _mahendra()
	var screen: ControlsScreen = rt.controls_screen()
	assert_bool(screen.visible).is_false()
	_key(KEY_TAB, true)
	assert_bool(screen.visible).is_true()
	_key(KEY_TAB, false)
	assert_bool(screen.visible).is_false()


func test_pause_menu_has_a_controls_button_and_a_tutorial_option() -> void:
	var menus: Menus = auto_free(Menus.new()) as Menus
	add_child(menus)
	menus.show_screen(Menus.Screen.PAUSE)
	var button: Button = menus.find_child("ControlsButton", true, false) as Button
	assert_object(button).is_not_null()
	assert_str(button.text).is_equal("Controls")
	button.pressed.emit()
	assert_int(menus.current_screen()).is_equal(Menus.Screen.CONTROLS)
	menus.go_back()
	assert_int(menus.current_screen()).is_equal(Menus.Screen.PAUSE)
	assert_object(menus.find_child("TutorialOption", true, false)).is_not_null()
	assert_bool(Menus.tutorial_hints_enabled()).is_true()  # on by default


# ---------------------------------------------------------------- the HUD ability bar

func test_ability_bar_shows_only_unlocked_abilities_and_greys_the_unusable() -> void:
	var bus: Node = auto_free(BusScript.new()) as Node
	var state: Node = _private_state()
	var hud: Hud = auto_free(Hud.new()) as Hud
	hud.connect_to(bus, null)
	add_child(hud)
	hud.bind_abilities(state, null, null, null)
	assert_bool(hud.ability_shown(&"dodge")).is_true()
	assert_bool(hud.ability_shown(&"grow")).is_false()
	assert_bool(hud.ability_shown(&"shrink")).is_false()
	assert_bool(hud.ability_shown(&"surge")).is_false()
	assert_str(hud.ability_glyph_text(&"dodge")).is_equal("Space")
	state.call("unlock", &"grow")
	state.call("unlock", &"surge")
	bus.emit_signal("smarana_changed", 3.0)
	hud.refresh_abilities()
	assert_bool(hud.ability_shown(&"grow")).is_true()
	assert_str(hud.ability_glyph_text(&"grow")).is_equal("E")
	assert_bool(hud.ability_greyed(&"grow")).is_true()  # too little Smarana to hold it
	assert_bool(hud.ability_greyed(&"surge")).is_true()
	assert_bool(hud.ability_shown(&"shrink")).is_false()
	bus.emit_signal("smarana_changed", 100.0)
	hud.refresh_abilities()
	assert_bool(hud.ability_greyed(&"grow")).is_false()
	assert_bool(hud.ability_greyed(&"surge")).is_false()
	bus.emit_signal("size_changed", Hud.SIZE_LARGE)
	hud.refresh_abilities()
	assert_bool(hud.ability_greyed(&"grow")).is_true()  # already large


func test_ability_bar_greys_the_dodge_during_its_cooldown() -> void:
	var rt: LevelRuntime = _mahendra()
	rt.hud().refresh_abilities()
	assert_bool(rt.hud().ability_greyed(&"dodge")).is_false()
	rt.player().request_leap()
	rt.hud().refresh_abilities()
	assert_bool(rt.hud().ability_greyed(&"dodge")).is_true()


# ---------------------------------------------------------------- no prompt for a locked action

func test_no_card_ever_shows_an_action_that_is_not_unlocked() -> void:
	var state: Node = _private_state()
	var player: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(player)
	var ui: Control = auto_free(Control.new()) as Control
	add_child(ui)
	var director: TutorialDirector = auto_free(TutorialDirector.new()) as TutorialDirector
	director.game_state = state
	add_child(director)
	director.setup(ui, player, null, true)
	director.set_process(false)  # the test drives the clock and the input events itself
	var locked_actions: Array[StringName] = [&"grow", &"shrink", &"smarana_surge"]
	var seen_steps: Array[StringName] = []
	var script: Array[Callable] = [
		func() -> void: _tap_key(KEY_W),
		func() -> void: director.notify_event(TutorialDirector.TALK_FILE),
		func() -> void: _click(),
		func() -> void: _click(); _click(),
		func() -> void: _mouse(true); director.tick(0.3); director.tick(0.3); _mouse(false),
		func() -> void: _tap_key(KEY_SPACE),
	]
	for step: Callable in script:
		director.tick(0.5)
		seen_steps.append(director.current_step())
		if director.card_visible():
			assert_bool(locked_actions.has(director.card_action())).is_false()
		step.call()
	director.tick(0.5)
	assert_str(String(director.current_step())).is_equal("grow")
	assert_bool(director.card_visible()).is_false()  # Grow is not unlocked: no card asks for it
	state.call("unlock", &"grow")
	director.tick(0.5)
	assert_bool(director.card_visible()).is_true()
	assert_str(String(director.card_action())).is_equal("grow")
	assert_array(seen_steps).contains_exactly([&"move", &"talk", &"light", &"chain", &"heavy", &"dodge"])


# ---------------------------------------------------------------- stuck hints and boss hints

func _bare_director(state: Node, prologue: bool) -> TutorialDirector:
	var player: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(player)
	var ui: Control = auto_free(Control.new()) as Control
	add_child(ui)
	var director: TutorialDirector = auto_free(TutorialDirector.new()) as TutorialDirector
	director.game_state = state
	add_child(director)
	director.setup(ui, player, null, prologue)
	director.set_process(false)  # the test drives the clock itself
	return director


func test_stuck_hint_in_the_prologue_is_jambavans_voice() -> void:
	var director: TutorialDirector = _bare_director(_private_state(), true)
	for i: int in 19:
		director.tick(1.0)
	assert_bool(director.hint_visible()).is_false()
	director.tick(1.5)
	assert_bool(director.hint_visible()).is_true()
	assert_str(director.hint_speaker()).is_equal("Jambavan")
	assert_str(director.hint_text()).contains("WASD")
	# progress restarts the clock
	director.tick(HINT_WAIT)
	assert_bool(director.hint_visible()).is_false()
	director.notify_progress()
	director.tick(15.0)
	assert_bool(director.hint_visible()).is_false()


func test_stuck_hint_elsewhere_is_the_narrator_with_the_open_objective() -> void:
	var director: TutorialDirector = _bare_director(_private_state(), false)
	director.notify_objective(&"search", "Search Lanka", false)
	director.notify_objective(&"done_one", "Old task", true)
	for i: int in 21:
		director.tick(1.0)
	assert_bool(director.hint_visible()).is_true()
	assert_str(director.hint_speaker()).is_equal("Narrator")
	assert_str(director.hint_text()).is_equal("Remember your task: Search Lanka")
	TranslationServer.set_locale("hi")
	assert_str(director.tr("HINT_SPEAKER_NARRATOR")).is_equal("सूत्रधार")


func test_stuck_clock_stands_still_during_dialogue() -> void:
	var director: TutorialDirector = _bare_director(_private_state(), false)
	director.locked = func() -> bool: return true
	for i: int in 40:
		director.tick(1.0)
	assert_bool(director.hint_visible()).is_false()


func test_each_boss_gets_one_hint_at_its_first_phase_change() -> void:
	var state: Node = _private_state()
	var director: TutorialDirector = _bare_director(state, false)
	var shown: Array[String] = []
	director.hint_shown.connect(func(_speaker: String, text: String) -> void: shown.append(text))
	director.notify_boss_phase("boss_lankini")
	director.notify_boss_phase("boss_lankini")
	assert_array(shown).has_size(1)
	assert_str(shown[0]).contains("Lankini")
	director.notify_boss_phase("boss_simhika")
	assert_str(shown[1]).contains("shrink with Q")
	director.notify_boss_phase("boss_jambumali")
	director.notify_boss_phase("boss_akshaya")
	assert_array(shown).has_size(4)
	assert_str(shown[3]).contains("chariot")
	# the hint is remembered (saved) and does not repeat in a later level
	var later: TutorialDirector = _bare_director(state, false)
	var more: Array[String] = []
	later.hint_shown.connect(func(_speaker: String, text: String) -> void: more.append(text))
	later.notify_boss_phase("boss_lankini")
	assert_array(more).is_empty()


func test_a_boss_in_a_level_reaches_the_director() -> void:
	var rt: LevelRuntime = _mahendra()
	var shown: Array[String] = []
	rt.tutorial().hint_shown.connect(func(_speaker: String, text: String) -> void: shown.append(text))
	var boss: BossAkshaya = auto_free(BossAkshaya.new()) as BossAkshaya
	rt.add_child(boss)
	rt.hook_boss_hints(boss, "boss_akshaya")
	boss.phase_changed.emit(1)
	assert_array(shown).has_size(1)
	assert_str(shown[0]).contains("chariot")


# ---------------------------------------------------------------- the Jambavan dialogue waits for Interact

func test_walking_into_jambavans_zone_does_not_start_his_dialogue_by_itself() -> void:
	var rt: LevelRuntime = _mahendra()
	var jambavan: Node3D = rt.actors()["jambavan"] as Node3D
	rt.player().global_position = jambavan.global_position + Vector3(-5.0, 0.0, 0.0)
	rt._on_trigger_body(rt.player(), "t_jambavan")  # what the physics engine does when he walks in
	assert_bool(rt.dialogue_box().is_playing()).is_false()
	_tap_key(KEY_F)  # too far away
	assert_bool(rt.dialogue_box().is_playing()).is_false()
	rt.player().global_position = jambavan.global_position + Vector3(-2.0, 0.0, 0.0)
	_tap_key(KEY_F)
	assert_bool(rt.dialogue_box().is_playing()).is_true()


func test_fire_trigger_still_starts_jambavans_dialogue_directly() -> void:
	var rt: LevelRuntime = _mahendra()
	assert_bool(rt.fire_trigger(&"t_jambavan")).is_true()
	assert_bool(rt.dialogue_box().is_playing()).is_true()


# ---------------------------------------------------------------- text

func test_every_teaching_string_exists_in_english_and_hindi() -> void:
	var file: FileAccess = FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	assert_object(file).is_not_null()
	var checked: int = 0
	var prefixes: PackedStringArray = ["TUT_", "PROMPT_", "UNLOCK_", "CTRL_", "HINT_"]
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 3:
			continue
		var key: String = row[0]
		var wanted: bool = false
		for prefix: String in prefixes:
			wanted = wanted or key.begins_with(prefix)
		if not wanted:
			continue
		checked += 1
		assert_str(row[1]).is_not_empty()
		assert_str(row[2]).is_not_empty()
		TranslationServer.set_locale("en")
		assert_str(TranslationServer.translate(key)).is_equal(row[1])
		TranslationServer.set_locale("hi")
		assert_str(TranslationServer.translate(key)).is_equal(row[2])
	assert_int(checked).is_greater(50)
