extends GdUnitTestSuite
## Acceptance tests for M19 (gameplay/abilities/size_shift.gd), DESIGN §9 M19 and §4.2.
## Scenarios are stepped with fixed deltas through SizeShift.tick(), at 30 and at 60 fps.


class FakePlayer extends CharacterBody3D:
	var speed_multiplier: float = 1.0
	var damage_multiplier: float = 1.0
	var damage_taken_multiplier: float = 1.0


class FakeDevotion extends Node:
	var value: float = 100.0

	func spend(amount: float) -> bool:
		if amount > value + 0.000001:
			return false
		value -= amount
		return true


const FPS_LIST: Array[int] = [30, 60]

var _bus: Node = null


func before_test() -> void:
	_state().call(&"reset")
	_bus = auto_free((load("res://core/event_bus.gd") as GDScript).new()) as Node


func _state() -> Node:
	return get_node("/root/GameState")


func _player() -> FakePlayer:
	var p: FakePlayer = auto_free(FakePlayer.new()) as FakePlayer
	p.collision_layer = Layers.mask([Layers.PLAYER])
	p.collision_mask = Layers.mask([Layers.WORLD])
	var pivot: Node3D = Node3D.new()
	pivot.name = "Pivot"
	p.add_child(pivot)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.85, 0.0)
	p.add_child(shape)
	add_child(p)
	return p


func _shift(p: FakePlayer) -> SizeShift:
	var s: SizeShift = SizeShift.new()
	s.name = "SizeShift"
	s.event_bus = _bus
	p.add_child(s)
	return s


func _run(s: SizeShift, seconds: float, fps: int) -> void:
	var n: int = roundi(seconds * float(fps))
	for i: int in n:
		s.tick(1.0 / float(fps))


func _pivot_scale(p: FakePlayer) -> float:
	return (p.get_node("Pivot") as Node3D).scale.x


func _shape_scale(p: FakePlayer) -> float:
	return (p.get_node("Shape") as CollisionShape3D).scale.x


# ---------------------------------------------------------------- table (§4.2)

func test_small_row_of_table() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	s.force_size(SizeShift.SIZE.SMALL)
	assert_float(s.get_scale_target()).is_equal_approx(0.35, 0.001)
	assert_float(p.speed_multiplier).is_equal_approx(0.8, 0.001)
	assert_float(p.damage_multiplier).is_equal_approx(0.3, 0.001)
	assert_float(p.damage_taken_multiplier).is_equal_approx(1.0, 0.001)


func test_normal_row_of_table() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	s.force_size(SizeShift.SIZE.LARGE)
	s.force_size(SizeShift.SIZE.NORMAL)
	assert_float(s.get_scale_target()).is_equal_approx(1.0, 0.001)
	assert_float(p.speed_multiplier).is_equal_approx(1.0, 0.001)
	assert_float(p.damage_multiplier).is_equal_approx(1.0, 0.001)
	assert_float(p.damage_taken_multiplier).is_equal_approx(1.0, 0.001)


func test_large_row_of_table() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	s.force_size(SizeShift.SIZE.LARGE)
	assert_float(s.get_scale_target()).is_equal_approx(2.5, 0.001)
	assert_float(p.speed_multiplier).is_equal_approx(0.75, 0.001)
	assert_float(p.damage_multiplier).is_equal_approx(2.0, 0.001)
	assert_float(p.damage_taken_multiplier).is_equal_approx(0.6, 0.001)


func test_giant_scale_for_scripted_moments() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	s.force_size(SizeShift.SIZE.GIANT)
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.GIANT)
	assert_float(s.get_scale_target()).is_equal_approx(6.0, 0.001)


# ---------------------------------------------------------------- steps and unlocks

func test_grow_from_small_to_normal_needs_no_unlock() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	s.force_size(SizeShift.SIZE.SMALL)
	assert_bool(s.grow()).is_true()
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.NORMAL)


func test_grow_to_large_requires_grow_unlock() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	assert_bool(s.grow()).is_false()
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.NORMAL)
	_state().call(&"unlock", &"grow")
	assert_bool(s.grow()).is_true()
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.LARGE)


func test_grow_never_reaches_giant() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	_state().call(&"unlock", &"grow")
	s.force_size(SizeShift.SIZE.LARGE)
	assert_bool(s.grow()).is_false()
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.LARGE)


func test_shrink_to_small_requires_shrink_unlock() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	assert_bool(s.shrink()).is_false()
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.NORMAL)
	_state().call(&"unlock", &"shrink")
	assert_bool(s.shrink()).is_true()
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.SMALL)
	assert_bool(s.shrink()).is_false()
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.SMALL)


func test_shrink_from_large_needs_no_unlock() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	s.force_size(SizeShift.SIZE.LARGE)
	assert_bool(s.shrink()).is_true()
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.NORMAL)


# ---------------------------------------------------------------- tween and visuals

func test_tween_is_partial_then_exact_after_0_4_seconds() -> void:
	for fps: int in FPS_LIST:
		var p: FakePlayer = _player()
		var s: SizeShift = _shift(p)
		_state().call(&"unlock", &"grow")
		assert_bool(s.grow()).is_true()
		_run(s, 0.2, fps)
		assert_bool(s.is_transitioning()).is_true()
		assert_float(s.get_visual_scale()).is_greater(1.0)
		assert_float(s.get_visual_scale()).is_less(2.5)
		_run(s, 0.2, fps)
		assert_bool(s.is_transitioning()).is_false()
		assert_float(s.get_visual_scale()).is_equal_approx(2.5, 0.001)
		assert_float(_pivot_scale(p)).is_equal_approx(2.5, 0.001)
		assert_float(_shape_scale(p)).is_equal_approx(2.5, 0.001)


func test_size_state_meta_and_signal() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	var seen: Array[int] = []
	_bus.connect(&"size_changed", func(v: int) -> void: seen.append(v))
	s.force_size(SizeShift.SIZE.SMALL)
	assert_int(p.get_meta(&"size_state") as int).is_equal(SizeShift.SIZE.SMALL)
	s.force_size(SizeShift.SIZE.GIANT)
	assert_int(p.get_meta(&"size_state") as int).is_equal(SizeShift.SIZE.GIANT)
	assert_array(seen).is_equal([0, 3])


# ---------------------------------------------------------------- Smarana drain

func test_large_drains_six_smarana_per_second() -> void:
	for fps: int in FPS_LIST:
		var p: FakePlayer = _player()
		var s: SizeShift = _shift(p)
		var dev: FakeDevotion = auto_free(FakeDevotion.new()) as FakeDevotion
		s.set_devotion(dev)
		s.force_size(SizeShift.SIZE.LARGE)
		_run(s, 1.0, fps)
		assert_float(dev.value).is_equal_approx(94.0, 0.05)
		assert_int(s.get_size()).is_equal(SizeShift.SIZE.LARGE)


func test_no_drain_outside_large() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	var dev: FakeDevotion = auto_free(FakeDevotion.new()) as FakeDevotion
	s.set_devotion(dev)
	s.force_size(SizeShift.SIZE.NORMAL)
	_run(s, 1.0, 60)
	assert_float(dev.value).is_equal_approx(100.0, 0.001)


func test_forced_shrink_when_smarana_runs_out() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	var dev: FakeDevotion = auto_free(FakeDevotion.new()) as FakeDevotion
	dev.value = 0.25
	s.set_devotion(dev)
	s.force_size(SizeShift.SIZE.LARGE)
	for i: int in 2:
		s.tick(1.0 / 60.0)  # two drains of 0.1 are paid from 0.25
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.LARGE)
	s.tick(1.0 / 60.0)  # the third drain of 0.1 fails
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.NORMAL)
	assert_float(p.speed_multiplier).is_equal_approx(1.0, 0.001)
	assert_float(p.damage_multiplier).is_equal_approx(1.0, 0.001)
	assert_float(p.damage_taken_multiplier).is_equal_approx(1.0, 0.001)


# ---------------------------------------------------------------- ceiling check

func test_grow_blocked_by_ceiling() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	_state().call(&"unlock", &"grow")
	var ceiling: StaticBody3D = auto_free(StaticBody3D.new()) as StaticBody3D
	ceiling.collision_layer = Layers.mask([Layers.WORLD])
	var box: CollisionShape3D = CollisionShape3D.new()
	var bshape: BoxShape3D = BoxShape3D.new()
	bshape.size = Vector3(4.0, 0.5, 4.0)
	box.shape = bshape
	ceiling.add_child(box)
	ceiling.position = Vector3(0.0, 3.25, 0.0)  # underside at y = 3.0, below Hanuman's grown head
	add_child(ceiling)
	await get_tree().physics_frame
	assert_bool(s.grow()).is_false()
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.NORMAL)
	assert_float(p.speed_multiplier).is_equal_approx(1.0, 0.001)


func test_grow_allowed_without_ceiling() -> void:
	var p: FakePlayer = _player()
	var s: SizeShift = _shift(p)
	_state().call(&"unlock", &"grow")
	await get_tree().physics_frame
	assert_bool(s.grow()).is_true()
	assert_int(s.get_size()).is_equal(SizeShift.SIZE.LARGE)
