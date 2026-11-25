extends GdUnitTestSuite
## Acceptance tests for M12 gen/music_player.gd (DESIGN §7, §9 M12): Bhairav scale degrees,
## loop lengths of 8-16 s, and no sample above 1.0 during a crossfade mix.

const RATE: int = 44100
const MUSIC_PATH: String = "res://gen/music_player.gd"


func _max_abs(buf: PackedVector2Array) -> float:
	var m: float = 0.0
	for i: int in range(buf.size()):
		var s: Vector2 = buf[i]
		m = maxf(m, maxf(absf(s.x), absf(s.y)))
	return m


func _new_music() -> MusicPlayer:
	return auto_free(MusicPlayer.new()) as MusicPlayer


func test_scale_degrees_are_bhairav() -> void:
	var expected: Array[float] = [1.0, 16.0 / 15.0, 5.0 / 4.0, 4.0 / 3.0, 3.0 / 2.0, 8.0 / 5.0, 15.0 / 8.0]
	var degrees: Array[float] = MusicPlayer.scale_degrees()
	assert_array(degrees).has_size(7)
	for i: int in range(expected.size()):
		assert_float(degrees[i]).is_equal_approx(expected[i], 0.001)


func test_calm_loop_length_is_between_8_and_16_seconds() -> void:
	var buf: PackedVector2Array = MusicPlayer.build_samples(&"calm")
	var seconds: float = float(buf.size()) / float(RATE)
	assert_bool(seconds >= 8.0 and seconds <= 16.0).is_true()


func test_combat_loop_length_is_between_8_and_16_seconds() -> void:
	var buf: PackedVector2Array = MusicPlayer.build_samples(&"combat")
	var seconds: float = float(buf.size()) / float(RATE)
	assert_bool(seconds >= 8.0 and seconds <= 16.0).is_true()


func test_unknown_track_builds_empty_buffer() -> void:
	var buf: PackedVector2Array = MusicPlayer.build_samples(&"no_such_track")
	assert_int(buf.size()).is_equal(0)


func test_built_track_peak_stays_below_one() -> void:
	var buf: PackedVector2Array = MusicPlayer.build_samples(&"calm")
	assert_float(_max_abs(buf)).is_greater(0.0)
	assert_float(_max_abs(buf)).is_less_equal(1.0)


func _filled(value: float, count: int) -> PackedVector2Array:
	var buf: PackedVector2Array = PackedVector2Array()
	buf.resize(count)
	for i: int in range(count):
		buf[i] = Vector2(value, value)
	return buf


func test_crossfade_never_exceeds_one() -> void:
	# Full-scale inputs: the weights (1 - t, t) sum to 1, so the exact mix stays at 1.0 and never above it.
	var full: PackedVector2Array = _filled(1.0, 4)
	for t: float in [0.0, 0.5, 1.0]:
		var mixed: PackedVector2Array = MusicPlayer.crossfade(full, full, t)
		assert_float(_max_abs(mixed)).is_less_equal(1.0)
		for i: int in range(mixed.size()):
			assert_float(mixed[i].x).is_equal_approx(1.0, 0.0001)
			assert_float(mixed[i].y).is_equal_approx(1.0, 0.0001)


func test_crossfade_full_scale_opposite_signs_gives_exact_values() -> void:
	var pos: PackedVector2Array = _filled(1.0, 4)
	var neg: PackedVector2Array = _filled(-1.0, 4)
	var at_0: PackedVector2Array = MusicPlayer.crossfade(pos, neg, 0.0)
	var at_half: PackedVector2Array = MusicPlayer.crossfade(pos, neg, 0.5)
	var at_quarter: PackedVector2Array = MusicPlayer.crossfade(pos, neg, 0.25)
	var at_1: PackedVector2Array = MusicPlayer.crossfade(pos, neg, 1.0)
	assert_float(at_0[0].x).is_equal_approx(1.0, 0.0001)
	assert_float(at_half[0].x).is_equal_approx(0.0, 0.0001)
	assert_float(at_quarter[0].x).is_equal_approx(0.5, 0.0001)
	assert_float(at_1[0].x).is_equal_approx(-1.0, 0.0001)
	assert_float(_max_abs(at_quarter)).is_less_equal(1.0)


func test_every_built_track_peak_stays_below_one() -> void:
	for track: StringName in [&"calm", &"stealth", &"combat", &"boss", &"dahan"]:
		var buf: PackedVector2Array = MusicPlayer.build_samples(track)
		assert_float(_max_abs(buf)).is_less_equal(1.0)


func test_all_five_track_loops_are_between_8_and_16_seconds() -> void:
	for track: StringName in [&"calm", &"stealth", &"combat", &"boss", &"dahan"]:
		var buf: PackedVector2Array = MusicPlayer.build_samples(track)
		var seconds: float = float(buf.size()) / float(RATE)
		assert_bool(seconds >= 8.0 and seconds <= 16.0).is_true()


func test_track_stream_loops_over_its_whole_length() -> void:
	var music: MusicPlayer = _new_music()
	var stream: AudioStreamWAV = music._stream_for(&"calm")
	assert_object(stream).is_not_null()
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(stream.loop_begin).is_equal(0)
	assert_int(stream.loop_end).is_equal(MusicPlayer.build_samples(&"calm").size())


func test_every_track_stream_has_forward_loop() -> void:
	var music: MusicPlayer = _new_music()
	for track: StringName in [&"calm", &"stealth", &"combat", &"boss", &"dahan"]:
		var stream: AudioStreamWAV = music._stream_for(track)
		assert_object(stream).is_not_null()
		assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
		assert_int(stream.loop_end).is_equal(MusicPlayer.build_samples(track).size())


func test_track_stream_is_cached() -> void:
	var music: MusicPlayer = _new_music()
	var first: AudioStreamWAV = music._stream_for(&"boss")
	var second: AudioStreamWAV = music._stream_for(&"boss")
	assert_object(first).is_same(second)


func test_unknown_track_play_is_not_playing() -> void:
	var music: MusicPlayer = _new_music()
	add_child(music)
	music.play(&"no_such_track", 0.0)
	assert_bool(music.is_playing()).is_false()
	assert_str(String(music.current_track())).is_equal("")


func test_crossfade_endpoints_match_inputs() -> void:
	var from_buf: PackedVector2Array = MusicPlayer.build_samples(&"calm")
	var to_buf: PackedVector2Array = MusicPlayer.build_samples(&"combat")
	var at_start: PackedVector2Array = MusicPlayer.crossfade(from_buf, to_buf, 0.0)
	var at_end: PackedVector2Array = MusicPlayer.crossfade(from_buf, to_buf, 1.0)
	var probe: int = 1000
	assert_float(at_start[probe].x).is_equal_approx(from_buf[probe].x, 0.0001)
	assert_float(at_end[probe].x).is_equal_approx(to_buf[probe].x, 0.0001)


func test_play_and_stop_update_current_track() -> void:
	var music: MusicPlayer = _new_music()
	add_child(music)
	assert_bool(music.is_playing()).is_false()
	music.play(&"calm", 0.0)
	assert_str(String(music.current_track())).is_equal("calm")
	assert_bool(music.is_playing()).is_true()
	music.stop(0.0)
	assert_bool(music.is_playing()).is_false()
