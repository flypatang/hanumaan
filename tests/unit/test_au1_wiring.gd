extends GdUnitTestSuite
## AU1: the gameplay files play their sounds (through the /root/Sound autoload's history hook).


func _sound() -> SoundPlayer:
	var s: SoundPlayer = get_tree().root.get_node_or_null("Sound") as SoundPlayer
	assert_object(s).is_not_null()
	s.clear_history()
	return s


func _player() -> Player:
	var p: Player = auto_free(Player.new()) as Player
	p.read_input = false
	p.event_bus = auto_free((load("res://core/event_bus.gd") as GDScript).new()) as Node
	add_child(p)
	return p


func _target() -> Hurtbox:
	var holder: Node3D = auto_free(Node3D.new()) as Node3D
	var health: Health = Health.new()
	health.name = "Health"
	health.max_value = 500
	holder.add_child(health)
	var hurt: Hurtbox = Hurtbox.new()
	hurt.team = &"enemy"
	hurt.health_path = NodePath("../Health")
	holder.add_child(hurt)
	add_child(holder)
	return hurt


func _run(p: Player, ticks: int) -> void:
	for i: int in ticks:
		p._physics_process(1.0 / 60.0)


func test_autoload_registered() -> void:
	assert_object(get_tree().root.get_node_or_null("Sound")).is_not_null()


func test_scripted_fight_emits_swing_and_impact() -> void:
	var s: SoundPlayer = _sound()
	var p: Player = _player()
	var target: Hurtbox = _target()
	p.request_light_attack()
	_run(p, 1)
	assert_bool(target.try_hit(p.get_light_hitbox())).is_true()
	var ids: Array[StringName] = s.recent_ids()
	assert_bool(ids.has(&"gada_swing_light")).is_true()
	assert_bool(ids.has(&"impact_light")).is_true()
	assert_bool(ids.has(&"enemy_hurt")).is_true()


func test_heavy_attack_and_heavy_impact() -> void:
	var s: SoundPlayer = _sound()
	var p: Player = _player()
	var target: Hurtbox = _target()
	p.request_heavy_attack()
	_run(p, 40)
	assert_bool(s.recent_ids().has(&"gada_swing_heavy")).is_true()
	assert_bool(target.try_hit(p.get_heavy_hitbox())).is_true()
	assert_bool(s.recent_ids().has(&"impact_heavy")).is_true()


func test_dodge_and_player_hurt() -> void:
	var s: SoundPlayer = _sound()
	var p: Player = _player()
	p.request_leap()
	assert_bool(s.recent_ids().has(&"dodge_whoosh")).is_true()
	var q: Player = _player()
	s.clear_history()
	q.take_damage(5, null)
	assert_bool(s.recent_ids().has(&"player_hurt")).is_true()


func test_size_shift_plays_grow_and_shrink() -> void:
	var s: SoundPlayer = _sound()
	var ss: SizeShift = auto_free(SizeShift.new()) as SizeShift
	ss.event_bus = auto_free((load("res://core/event_bus.gd") as GDScript).new()) as Node
	add_child(ss)
	ss.force_size(SizeShift.SIZE.NORMAL)
	s.clear_history()
	ss._change_size(SizeShift.SIZE.LARGE)
	assert_bool(s.recent_ids().has(&"size_grow")).is_true()
	ss._change_size(SizeShift.SIZE.SMALL)
	assert_bool(s.recent_ids().has(&"size_shrink")).is_true()


func test_shrine_plays_bell() -> void:
	var s: SoundPlayer = _sound()
	var shrine: Shrine = auto_free(Shrine.new()) as Shrine
	add_child(shrine)
	s.clear_history()
	shrine.interact(auto_free(Node.new()) as Node)
	assert_bool(s.recent_ids().has(&"shrine_meditate")).is_true()


func test_fire_plays_ignite_and_loop() -> void:
	var s: SoundPlayer = _sound()
	var fire: FireSystem = auto_free(FireSystem.new()) as FireSystem
	add_child(fire)
	var prop: Node3D = auto_free(Node3D.new()) as Node3D
	prop.set_meta("flammable", true)
	add_child(prop)
	fire.register(prop)
	s.clear_history()
	assert_bool(fire.ignite(prop)).is_true()
	assert_bool(s.recent_ids().has(&"fire_ignite")).is_true()
	assert_bool(s.recent_ids().has(&"fire_loop")).is_true()


func test_devotion_surge_exhausted_recovered() -> void:
	var s: SoundPlayer = _sound()
	var d: Devotion = auto_free(Devotion.new()) as Devotion
	d.event_bus = auto_free((load("res://core/event_bus.gd") as GDScript).new()) as Node
	add_child(d)
	s.clear_history()
	d.begin_exhausted()
	assert_bool(s.recent_ids().has(&"exhausted")).is_true()
	d._recover()
	assert_bool(s.recent_ids().has(&"recovered")).is_true()


func test_menu_buttons_click() -> void:
	var s: SoundPlayer = _sound()
	var menu: Menus = auto_free(Menus.new()) as Menus
	add_child(menu)
	s.clear_history()
	var back: Button = menu.find_child("BackButton", true, false) as Button
	assert_object(back).is_not_null()
	back.pressed.emit()
	assert_bool(s.recent_ids().has(&"ui_back")).is_true()
	s.clear_history()
	var begin: Button = menu.find_child("BeginButton", true, false) as Button
	begin.pressed.emit()
	assert_bool(s.recent_ids().has(&"ui_confirm")).is_true()


func test_freed_burning_prop_releases_fire_loop() -> void:
	var s: SoundPlayer = _sound()
	var fire: FireSystem = auto_free(FireSystem.new()) as FireSystem
	add_child(fire)
	var prop: Node3D = Node3D.new()
	prop.set_meta("flammable", true)
	add_child(prop)
	fire.register(prop)
	assert_bool(fire.ignite(prop)).is_true()
	var loop: AudioStreamPlayer3D = fire.loop_player(prop) as AudioStreamPlayer3D
	assert_object(loop).is_not_null()
	assert_bool(loop.get_parent() == s).is_true()
	var ogg: AudioStreamOggVorbis = loop.stream as AudioStreamOggVorbis
	assert_object(ogg).is_not_null()
	assert_bool(ogg.loop).is_true()
	prop.free()
	await get_tree().process_frame
	assert_bool(is_instance_valid(loop)).is_false()


func test_fire_loop_stream_loops_even_after_one_shot_of_same_file() -> void:
	var s: SoundPlayer = _sound()
	# fire_ignite and fire_loop share files; the one-shot must not poison the loop's cached stream.
	for i: int in 6:
		s.play(&"fire_ignite", Vector3.ZERO)
	var prop: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(prop)
	for i: int in 4:
		var p: AudioStreamPlayer3D = SoundPlayer.cue_at(prop, &"fire_loop") as AudioStreamPlayer3D
		assert_object(p).is_not_null()
		assert_bool((p.stream as AudioStreamOggVorbis).loop).is_true()
		SoundPlayer.stop_loop(p)
		assert_bool(p.get_parent() == null).is_true()
		await get_tree().process_frame
		assert_bool(is_instance_valid(p)).is_false()


func test_hurtbox_heavy_light_split_and_invulnerable_skip() -> void:
	var s: SoundPlayer = _sound()
	var target: Hurtbox = _target()
	var hb: Hitbox = auto_free(Hitbox.new()) as Hitbox
	hb.team = &"player"
	add_child(hb)
	hb.damage = SoundPlayer.HEAVY_HIT_DAMAGE
	hb.activate(0.5)
	assert_bool(target.try_hit(hb)).is_true()
	assert_bool(s.recent_ids().has(&"impact_heavy")).is_true()
	s.clear_history()
	hb.damage = SoundPlayer.HEAVY_HIT_DAMAGE - 1
	hb.activate(0.5)
	assert_bool(target.try_hit(hb)).is_true()
	assert_bool(s.recent_ids().has(&"impact_light")).is_true()
	assert_bool(s.recent_ids().has(&"impact_heavy")).is_false()
	s.clear_history()
	(target.get_node("../Health") as Health).invulnerable = true
	hb.activate(0.5)
	target.try_hit(hb)
	assert_bool(s.recent_ids().has(&"impact_light")).is_false()


func test_player_hurt_cued_once_per_damage() -> void:
	var s: SoundPlayer = _sound()
	var p: Player = _player()
	p.take_damage(5)
	var n: int = 0
	for id: StringName in s.recent_ids():
		if id == &"player_hurt":
			n += 1
	assert_int(n).is_equal(1)


func test_footsteps_id_and_interval() -> void:
	var s: SoundPlayer = _sound()
	var rt: LevelRuntime = auto_free(LevelRuntime.new()) as LevelRuntime
	add_child(rt)
	var p: Player = _player()
	p.velocity = Vector3(3.0, 0.0, 0.0)
	rt._player = p
	rt._tiles = {Vector2i(0, 0): {"type": "grass", "step": 0}}
	p.global_position = Vector3(0.5, 0.0, 0.5)
	rt._step_time = 0.0
	rt._footsteps(SoundPlayer.FOOTSTEP_INTERVAL * 0.5)
	assert_bool(s.recent_ids().has(&"footstep_grass")).is_false()
	rt._footsteps(SoundPlayer.FOOTSTEP_INTERVAL * 0.6)
	assert_bool(s.recent_ids().has(&"footstep_grass")).is_true()


func test_dissolve_and_shloka_cues() -> void:
	var s: SoundPlayer = _sound()
	var box: DialogueBox = auto_free(DialogueBox.new()) as DialogueBox
	add_child(box)
	s.clear_history()
	box._on_shloka_shown(&"x")
	assert_bool(s.recent_ids().has(&"shloka_open")).is_true()
