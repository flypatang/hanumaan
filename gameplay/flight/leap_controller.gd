class_name LeapController
extends Node3D
## Chapter 1 on-rails flight (DESIGN §3 Ch1, §9 M30). Moves a rider along a Curve3D at 40 m/s, lets the player steer
## laterally inside a corridor, and pauses at the gates (Mainaka, Surasa, Simhika). Simulated in fixed 60 Hz ticks, so
## results do not depend on the frame rate. Test hooks: `read_input = false`, then set `steer_input` and call
## `request_dodge()` and `step(delta)`.

## Emitted when the rail pauses at a gate. The chapter flow runs the encounter, then calls resume().
signal gate_reached(id: StringName)
## Emitted when the Mainaka ring was flown through (health and Smarana refilled).
signal ring_collected()
## Emitted when an obstacle hits the rider.
signal obstacle_hit(kind: StringName)
## Emitted once when the end of the path is reached.
signal finished_flight()
## Emitted when health is depleted by an obstacle; the chapter flow should restart the flight.
signal failed()

const TICK: float = 1.0 / 60.0
const TICK_EPSILON: float = 0.000001
const LATERAL_SPEED: float = 14.0
const DODGE_DURATION: float = 0.35
const DODGE_COOLDOWN: float = 1.2
const DODGE_LATERAL_SPEED: float = 30.0
const OBSTACLE_DAMAGE: int = 10
const OBSTACLE_RADIUS: float = 2.5
const OBSTACLE_DEPTH: float = 2.0
const FLIGHT_HEIGHT: float = 12.0
const DEFAULT_LEVEL: String = "res://levels/ocean_leap.json"

## Lateral input -1 (left) .. 1 (right).
var steer_input: float = 0.0
## When true, input is read from the InputMap each physics frame.
var read_input: bool = true
## When false, no ocean or sky is built (tests).
var build_scenery: bool = true
## Overrides the EventBus lookup (tests).
var event_bus: Node = null
## The node moved along the rail (Hanuman). Optional.
var rider: Node3D = null
var health: Health = null
var smarana: float = 50.0
var speed: float = 40.0
var corridor_half_width: float = 12.0
var gate_defs: Array[Dictionary] = []
var obstacle_defs: Array[Dictionary] = []

## Metres travelled along the rail.
var distance: float = 0.0
## Lateral offset from the rail centre, within +-corridor_half_width.
var lateral: float = 0.0
var paused_at_gate: bool = false
var finished: bool = false

var _curve: Curve3D = Curve3D.new()
var _next_gate: int = 0
var _hit: Array[bool] = []
var _accum: float = 0.0
var _dodge_ticks: int = 0
var _cooldown_ticks: int = 0
var _dodge_dir: float = 0.0
var _loaded: bool = false


func _ready() -> void:
	if not _loaded:
		load_level(DEFAULT_LEVEL)
	if health == null:
		health = Health.new()
		health.name = "Health"
		add_child(health)
	health.depleted.connect(_on_depleted)
	if build_scenery:
		_build_scenery()
	_place_rider()


func _physics_process(delta: float) -> void:
	if read_input:
		steer_input = Input.get_axis(&"move_left", &"move_right")
		if Input.is_action_just_pressed(&"leap"):
			request_dodge()
	step(delta)


## Loads a level JSON file (see levels/ocean_leap.json). Returns false if it can't be read.
func load_level(path: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return false
	apply_data(parsed as Dictionary)
	return true


func apply_data(data: Dictionary) -> void:
	speed = _num(data, "speed", 40.0)
	corridor_half_width = _num(data, "corridor_half_width", 12.0)
	_curve = Curve3D.new()
	for p: Variant in data.get("path", []) as Array:
		var a: Array = p as Array
		_curve.add_point(Vector3(_to_f(a[0]), _to_f(a[1]), _to_f(a[2])))
	gate_defs.clear()
	for g: Variant in data.get("gates", []) as Array:
		gate_defs.append(g as Dictionary)
	gate_defs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _num(a, "d", 0.0) < _num(b, "d", 0.0))
	obstacle_defs.clear()
	for o: Variant in data.get("obstacles", []) as Array:
		obstacle_defs.append(o as Dictionary)
	_hit.clear()
	_hit.resize(obstacle_defs.size())
	_hit.fill(false)
	distance = 0.0
	lateral = 0.0
	_next_gate = 0
	paused_at_gate = false
	finished = false
	_loaded = true


func path_length() -> float:
	return _curve.get_baked_length()


## Position on the rail centre line at `d` metres.
func rail_position(d: float) -> Vector3:
	return _curve.sample_baked(clampf(d, 0.0, path_length()))


## Unit direction of travel at `d` metres.
func rail_tangent(d: float) -> Vector3:
	var a: Vector3 = rail_position(d - 0.5)
	var b: Vector3 = rail_position(d + 0.5)
	var t: Vector3 = b - a
	if t.length() < 0.0001:
		return Vector3.BACK
	return t.normalized()


## World position of the rider (rail position plus lateral offset).
func rider_position() -> Vector3:
	var t: Vector3 = rail_tangent(distance)
	var right: Vector3 = t.cross(Vector3.UP).normalized()
	return rail_position(distance) + right * lateral


func is_dodging() -> bool:
	return _dodge_ticks > 0


## The leap action: a short dodge with invulnerability and a lateral burst.
func request_dodge() -> void:
	if _dodge_ticks > 0 or _cooldown_ticks > 0 or finished:
		return
	_dodge_ticks = roundi(DODGE_DURATION * 60.0)
	_cooldown_ticks = roundi(DODGE_COOLDOWN * 60.0)
	_dodge_dir = signf(steer_input) if absf(steer_input) > 0.01 else (1.0 if lateral <= 0.0 else -1.0)
	if health != null:
		health.invulnerable = true


## Continues along the rail after a gate encounter.
func resume() -> void:
	paused_at_gate = false


## Advances the simulation by `delta` seconds in whole 60 Hz ticks.
func step(delta: float) -> void:
	_accum += delta
	while _accum >= TICK - TICK_EPSILON:
		_accum -= TICK
		_tick()


func _tick() -> void:
	if _cooldown_ticks > 0:
		_cooldown_ticks -= 1
	if _dodge_ticks > 0:
		_dodge_ticks -= 1
		if _dodge_ticks == 0 and health != null:
			health.invulnerable = false
	_steer()
	if not paused_at_gate and not finished:
		_advance()
	_place_rider()


func _steer() -> void:
	var v: float = clampf(steer_input, -1.0, 1.0) * LATERAL_SPEED
	if _dodge_ticks > 0:
		v += _dodge_dir * DODGE_LATERAL_SPEED
	lateral = clampf(lateral + v * TICK, -corridor_half_width, corridor_half_width)


func _advance() -> void:
	var before: float = distance
	var target: float = distance + speed * TICK
	var gate_d: float = INF
	if _next_gate < gate_defs.size():
		gate_d = _num(gate_defs[_next_gate], "d", 0.0)
	var end_d: float = path_length() if path_length() > 0.0 else 900.0
	var stop: float = minf(gate_d, end_d)
	distance = minf(target, stop)
	_check_obstacles(before, distance)
	if distance >= gate_d - 0.000001:
		distance = gate_d
		_arrive_gate(gate_defs[_next_gate])
		_next_gate += 1
	elif distance >= end_d - 0.000001:
		finished = true
		finished_flight.emit()



func _arrive_gate(g: Dictionary) -> void:
	paused_at_gate = true
	if g.has("ring"):
		var ring: Dictionary = g["ring"] as Dictionary
		if absf(lateral - _num(ring, "lateral", 0.0)) <= _num(ring, "radius", 4.0):
			_collect_ring()
	gate_reached.emit(StringName(str(g["id"])))


func _collect_ring() -> void:
	if health != null:
		if health.value < health.max_value:
			health.heal(health.max_value - health.value)
		_emit_bus(&"vitality_changed", [health.value, health.max_value])
	smarana = 100.0
	_emit_bus(&"smarana_changed", [smarana])
	ring_collected.emit()


func _check_obstacles(from_d: float, to_d: float) -> void:
	for i in obstacle_defs.size():
		if _hit[i]:
			continue
		var o: Dictionary = obstacle_defs[i]
		var od: float = _num(o, "d", 0.0)
		if od + OBSTACLE_DEPTH < from_d or od - OBSTACLE_DEPTH > to_d:
			continue
		if absf(lateral - _num(o, "lateral", 0.0)) > OBSTACLE_RADIUS:
			continue
		_hit[i] = true
		if is_dodging() or health == null or health.value <= 0:
			continue
		health.damage(OBSTACLE_DAMAGE, self)
		_emit_bus(&"player_damaged", [OBSTACLE_DAMAGE, self])
		_emit_bus(&"vitality_changed", [health.value, health.max_value])
		obstacle_hit.emit(StringName(str(o.get("kind", "rock"))))


func _on_depleted(_source: Node) -> void:
	failed.emit()


func _emit_bus(sig: StringName, args: Array) -> void:
	var bus: Node = event_bus
	if bus == null and is_inside_tree():
		bus = get_node_or_null(^"/root/EventBus")
	if bus == null:
		return
	match args.size():
		1:
			bus.emit_signal(sig, args[0])
		2:
			bus.emit_signal(sig, args[0], args[1])


func _place_rider() -> void:
	if rider == null or _curve.point_count < 2:
		return
	rider.position = rider_position()
	var t: Vector3 = rail_tangent(distance)
	if absf(t.dot(Vector3.UP)) < 0.99:
		rider.look_at(rider.position + t, Vector3.UP)


func _build_scenery() -> void:
	var ocean: MeshInstance3D = NatureKit.ocean_plane(Vector2(600.0, 1400.0))
	ocean.position = Vector3(0.0, -FLIGHT_HEIGHT, 450.0)
	add_child(ocean)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.SAFFRON.darkened(0.2)
	env.ambient_light_color = Palette.MOON
	env.ambient_light_energy = 0.6
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	add_child(sun)


func _to_f(v: Variant) -> float:
	return v as float if v is float or v is int else 0.0


func _num(d: Dictionary, key: String, default: float) -> float:
	return _to_f(d.get(key, default))
