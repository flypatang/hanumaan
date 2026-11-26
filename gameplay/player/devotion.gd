class_name Devotion
extends Node
## Smarana (devotion) meter, the Smarana surge and the Exhausted/recovery flow (DESIGN §2, §4, §9 M20).
## Child of the Player. There is no game-over state: at 0 Vitality Hanuman is exhausted, meditates under a saffron
## fade, and wakes at the last shrine with full Vitality and Smarana 0 (the cost).
## All timing runs through `tick(delta)` (called from `_process`), so tests can drive it with fixed deltas.

signal surge_fired
signal exhausted_started
signal recovered

const MAX_SMARANA: float = 100.0
const HIT_GAIN: float = 2.0
const SURGE_RADIUS: float = 6.0
const SURGE_DISSOLVE_HP: int = 40
const SURGE_BOSS_DAMAGE: int = 10
const SURGE_KNOCKBACK: float = 6.0
const FADE_TIME: float = 1.5
const FADE_OUT_TIME: float = 0.5
const SHOCKWAVE_LIFETIME: float = 0.4

## Overrides for the EventBus / GameState autoloads (tests). When null, /root/<Name> is used.
var event_bus: Node = null
var game_state: Node = null

## Current Smarana, always within 0..100.
var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, MAX_SMARANA)

var _exhausted: bool = false
var _fade_t: float = 0.0
var _fade_out_t: float = -1.0
var _was_read_input: bool = true
var _layer: CanvasLayer = null
var _rect: ColorRect = null
var _wave: Area3D = null
var _wave_t: float = 0.0
var _health: Health = null


func _ready() -> void:
	var p: Player = get_parent() as Player
	if p == null:
		return
	# Children are ready before their parent, so the Player's Health may not exist yet.
	if p.get_health() != null:
		_connect_health()
	else:
		p.ready.connect(_connect_health, CONNECT_ONE_SHOT)


func _connect_health() -> void:
	var p: Player = get_parent() as Player
	if p == null:
		return
	_health = p.get_health()
	if _health != null and not _health.depleted.is_connected(_on_depleted):
		_health.depleted.connect(_on_depleted)


func _process(delta: float) -> void:
	tick(delta)


## Adds Smarana. `reason` is informational (e.g. "hit", "protect", "dialogue").
func gain(amount: float, _reason: String = "") -> void:
	if amount <= 0.0:
		return
	_set_value(value + amount)


## Spends `amount`; returns false (and spends nothing) if there is not enough.
func spend(amount: float) -> bool:
	if amount < 0.0 or value < amount:
		return false
	_set_value(value - amount)
	return true


## Fills the meter completely (meditating at a Shrine).
func refill() -> void:
	_set_value(MAX_SMARANA)


## The player calls this for every landed hit (+2).
func on_hit_landed() -> void:
	gain(HIT_GAIN, "hit")


## Connects a DialogueRunner's `smarana_awarded` so choices true to the text add Smarana.
func connect_dialogue(runner: Object) -> void:
	if runner.has_signal(&"smarana_awarded") and not runner.is_connected(&"smarana_awarded", _on_dialogue_award):
		runner.connect(&"smarana_awarded", _on_dialogue_award)


func is_exhausted() -> bool:
	return _exhausted


func can_surge() -> bool:
	if _exhausted or value < MAX_SMARANA:
		return false
	var gs: Node = _get_state()
	if gs == null:
		return false
	return (gs.call("is_unlocked", &"surge") as bool)


## Fires the Smarana surge: needs a full meter and the unlocked ability; resets Smarana to 0.
## Dissolves enemies with hp <= 40 within 6 m and staggers bosses. Returns whether it fired.
func surge() -> bool:
	if not can_surge():
		return false
	_set_value(0.0)
	var owner_node: Node3D = get_parent() as Node3D
	if owner_node != null and is_inside_tree():
		var origin: Vector3 = owner_node.global_position
		for n: Node in get_tree().get_nodes_in_group(&"enemy"):
			var e: EnemyBase = n as EnemyBase
			if e == null or e.state == EnemyBase.State.DISSOLVE:
				continue
			var offset: Vector3 = e.global_position - origin
			offset.y = 0.0
			if offset.length() > SURGE_RADIUS:
				continue
			var dir: Vector3 = offset.normalized() * SURGE_KNOCKBACK
			if e.is_in_group(&"boss"):
				e.apply_hit(SURGE_BOSS_DAMAGE, dir, true)
			elif e.hp <= SURGE_DISSOLVE_HP:
				e.apply_hit(maxi(e.hp, 1), dir, true)
		_spawn_wave(owner_node)
	SoundPlayer.cue(self, &"surge")
	surge_fired.emit()
	return true


## Advances the surge shockwave and the exhausted flow by `delta` seconds.
func tick(delta: float) -> void:
	if _wave != null:
		_wave_t += delta
		if _wave_t >= SHOCKWAVE_LIFETIME:
			_wave.queue_free()
			_wave = null
	if _fade_out_t >= 0.0:
		_fade_out_t += delta
		if _rect != null:
			_rect.color.a = clampf(1.0 - _fade_out_t / FADE_OUT_TIME, 0.0, 1.0)
		if _fade_out_t >= FADE_OUT_TIME:
			_fade_out_t = -1.0
			_remove_fade()
	if _exhausted:
		_fade_t += delta
		if _rect != null:
			_rect.color.a = clampf(_fade_t / FADE_TIME, 0.0, 1.0)
		if _fade_t >= FADE_TIME:
			_recover()


## Enters the exhausted state (normally triggered by the player's Health depletion).
func begin_exhausted() -> void:
	if _exhausted:
		return
	_exhausted = true
	_fade_t = 0.0
	_fade_out_t = -1.0
	var p: Player = get_parent() as Player
	if p != null:
		_was_read_input = p.read_input
		p.read_input = false
		p.move_input = Vector2.ZERO
		p.velocity = Vector3.ZERO
		p.set_physics_process(false)
		p.get_health().invulnerable = true
		var m: HanumanModel = _find_model(p)
		if m != null:
			m.set_pose(&"meditate")
	_make_fade()
	SoundPlayer.cue(self, &"exhausted")
	_emit(&"player_exhausted", [])
	exhausted_started.emit()


func _recover() -> void:
	_exhausted = false
	var p: Player = get_parent() as Player
	var gs: Node = _get_state()
	if p != null:
		var shrine: Variant = null
		if gs != null:
			var ls: Variant = gs.get("last_shrine")
			if ls is Dictionary:
				shrine = (ls as Dictionary).get("pos", null)
		if shrine is Vector3 and p.is_inside_tree():
			p.global_position = shrine as Vector3
		elif shrine is Vector3:
			p.position = shrine as Vector3
		var h: Health = p.get_health()
		h.invulnerable = false
		h.heal(h.max_value)
		p.read_input = _was_read_input
		p.set_physics_process(true)
		var m: HanumanModel = _find_model(p)
		if m != null:
			m.set_pose(&"idle")
	_set_value(0.0)
	_fade_out_t = 0.0
	SoundPlayer.cue(self, &"recovered")
	_emit(&"player_recovered", [])
	recovered.emit()


func _on_depleted(_source: Node) -> void:
	begin_exhausted()


func _on_dialogue_award(amount: float) -> void:
	gain(amount, "dialogue")


func _set_value(v: float) -> void:
	var before: float = value
	value = v
	if not is_equal_approx(before, value):
		_emit(&"smarana_changed", [value])


func _make_fade() -> void:
	_remove_fade()
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_rect = ColorRect.new()
	_rect.color = Color(Palette.SAFFRON, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_rect)
	add_child(_layer)


func _remove_fade() -> void:
	if _layer != null:
		_layer.queue_free()
	_layer = null
	_rect = null


func _spawn_wave(at: Node3D) -> void:
	if _wave != null:
		_wave.queue_free()
	_wave = Area3D.new()
	_wave.name = "SmaranaShockwave"
	_wave.collision_layer = 0
	_wave.collision_mask = Layers.mask([Layers.ENEMY])
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = SURGE_RADIUS
	cs.shape = sphere
	_wave.add_child(cs)
	_wave_t = 0.0
	add_child(_wave)
	_wave.global_position = at.global_position


func _find_model(root: Node) -> HanumanModel:
	for c: Node in root.get_children():
		var m: HanumanModel = c as HanumanModel
		if m != null:
			return m
		var deep: HanumanModel = _find_model(c)
		if deep != null:
			return deep
	return null


func _get_state() -> Node:
	if game_state != null:
		return game_state
	return get_node_or_null("/root/GameState")


func _emit(signal_name: StringName, args: Array) -> void:
	var bus: Node = event_bus
	if bus == null:
		var p: Player = get_parent() as Player
		if p != null:
			bus = p.event_bus
	if bus == null:
		bus = get_node_or_null("/root/EventBus")
	if bus == null:
		return
	if args.is_empty():
		bus.emit_signal(signal_name)
	else:
		bus.emit_signal(signal_name, args[0])
