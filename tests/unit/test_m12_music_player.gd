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


func test_crossfade_never_exceeds_one() -> void:
	var from_buf: PackedVector2Array = MusicPlayer.build_samples(&"calm")
	var to_buf: PackedVector2Array = MusicPlayer.build_samples(&"combat")
	for step: int in range(5):
		var t: float = float(step) / 4.0
		var mixed: PackedVector2Array = MusicPlayer.crossfade(from_buf, to_buf, t)
		assert_float(_max_abs(mixed)).is_less_equal(1.0)


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
