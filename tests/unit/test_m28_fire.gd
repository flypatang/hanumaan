extends GdUnitTestSuite
## M28 acceptance tests: world/fire.gd (DESIGN §9 M28).
## Flammable props spread fire to flammable, unprotected neighbours within 3.0 m after 1.5 s of burning,
## protected props never ignite, and a burning prop is burnt after 6 s. Time is advanced with step(delta).

const FireScript: GDScript = preload("res://world/fire.gd")
const STEP: float = 0.1


func _make_fire() -> FireSystem:
	var fire: FireSystem = FireScript.new() as FireSystem
	auto_free(fire)
	return fire


func _make_prop(pos: Vector3, flammable: bool, protected: bool) -> Node3D:
	var prop: Node3D = auto_free(Node3D.new()) as Node3D
	prop.position = pos
	prop.set_meta("flammable", flammable)
	prop.set_meta("protected", protected)
	return prop


func _run(fire: FireSystem, seconds: float) -> void:
	var steps: int = roundi(seconds / STEP)
	for i: int in range(steps):
		fire.step(STEP)


func test_unflammable_prop_does_not_ignite() -> void:
	var fire: FireSystem = _make_fire()
	var rock: Node3D = _make_prop(Vector3.ZERO, false, false)
	fire.register(rock)
	assert_bool(fire.ignite(rock)).is_false()
	assert_bool(fire.is_burning(rock)).is_false()


func test_flammable_prop_ignites() -> void:
	var fire: FireSystem = _make_fire()
	var hut: Node3D = _make_prop(Vector3.ZERO, true, false)
	fire.register(hut)
	assert_bool(fire.ignite(hut)).is_true()
	assert_bool(fire.is_burning(hut)).is_true()


func test_fire_spreads_to_neighbour_within_3m_after_1_5s() -> void:
	var fire: FireSystem = _make_fire()
	var a: Node3D = _make_prop(Vector3.ZERO, true, false)
	var b: Node3D = _make_prop(Vector3(2.0, 0.0, 0.0), true, false)
	fire.register(a)
	fire.register(b)
	fire.ignite(a)
	_run(fire, 1.4)
	assert_bool(fire.is_burning(b)).is_false()
	_run(fire, 0.2)
	assert_bool(fire.is_burning(b)).is_true()


func test_fire_does_not_spread_beyond_3m() -> void:
	var fire: FireSystem = _make_fire()
	var a: Node3D = _make_prop(Vector3.ZERO, true, false)
	var far: Node3D = _make_prop(Vector3(3.5, 0.0, 0.0), true, false)
	fire.register(a)
	fire.register(far)
	fire.ignite(a)
	_run(fire, 5.0)
	assert_bool(fire.is_burning(far)).is_false()
	assert_bool(fire.is_burnt(far)).is_false()


func test_protected_prop_never_ignites_even_when_surrounded() -> void:
	var fire: FireSystem = _make_fire()
	var centre: Node3D = _make_prop(Vector3.ZERO, true, false)
	fire.register(centre)
	var ring: Array[Node3D] = []
	ring.append(_make_prop(Vector3(1.0, 0.0, 0.0), true, true))
	ring.append(_make_prop(Vector3(-1.0, 0.0, 0.0), true, true))
	ring.append(_make_prop(Vector3(0.0, 0.0, 1.0), true, true))
	ring.append(_make_prop(Vector3(0.0, 0.0, -1.0), true, true))
	for prop: Node3D in ring:
		fire.register(prop)
	assert_bool(fire.ignite(ring[0])).is_false()
	fire.ignite(centre)
	_run(fire, 15.0)
	for prop: Node3D in ring:
		assert_bool(fire.is_burning(prop)).is_false()
		assert_bool(fire.is_burnt(prop)).is_false()


func test_burning_prop_becomes_burnt_after_6s() -> void:
	var fire: FireSystem = _make_fire()
	var hut: Node3D = _make_prop(Vector3.ZERO, true, false)
	fire.register(hut)
	fire.ignite(hut)
	_run(fire, 5.9)
	assert_bool(fire.is_burnt(hut)).is_false()
	_run(fire, 0.2)
	assert_bool(fire.is_burnt(hut)).is_true()
	assert_bool(fire.is_burning(hut)).is_false()


func test_ignition_is_not_repeated() -> void:
	var fire: FireSystem = _make_fire()
	var hut: Node3D = _make_prop(Vector3.ZERO, true, false)
	fire.register(hut)
	assert_bool(fire.ignite(hut)).is_true()
	assert_bool(fire.ignite(hut)).is_false()


func test_fire_spreads_through_chain_of_neighbours() -> void:
	var fire: FireSystem = _make_fire()
	var a: Node3D = _make_prop(Vector3.ZERO, true, false)
	var b: Node3D = _make_prop(Vector3(2.5, 0.0, 0.0), true, false)
	var c: Node3D = _make_prop(Vector3(5.0, 0.0, 0.0), true, false)
	fire.register(a)
	fire.register(b)
	fire.register(c)
	fire.ignite(a)
	_run(fire, 1.6)
	assert_bool(fire.is_burning(b)).is_true()
	assert_bool(fire.is_burning(c)).is_false()
	_run(fire, 1.5)
	assert_bool(fire.is_burning(c)).is_true()


func test_ignition_emits_fire_ignited_once() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var bus: Node = tree.root.get_node_or_null("EventBus") as Node
	assert_object(bus).is_not_null()
	var fire: FireSystem = _make_fire()
	var hut: Node3D = _make_prop(Vector3.ZERO, true, false)
	hut.name = "HutSeven"
	fire.register(hut)
	var counter: Array[int] = [0]
	var on_ignited: Callable = func(_id: StringName) -> void:
		counter[0] += 1
	bus.connect("fire_ignited", on_ignited)
	fire.ignite(hut)
	fire.ignite(hut)
	bus.disconnect("fire_ignited", on_ignited)
	assert_int(counter[0]).is_equal(1)
