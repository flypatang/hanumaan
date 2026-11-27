class_name PlaythroughBot
extends Node
## Automated playthrough (DESIGN §10 gate 4): plays the WHOLE game from New Game to the credits on the real main scene,
## which means the real ChapterFlow, LevelRuntime, Player, enemies, bosses, dialogue box and cutscene player.
##
## What is real and what is a shortcut (REPORT.md repeats this):
##  - Real: new game through the title menu, the prologue walk and training swings (keyboard actions), the Surasa size
##    puzzle (grow / shrink actions), the leap steering and the Simhika fight (attack and shrink actions), one Kinkara
##    fight with the player's own light attacks, dialogue advancing (input events), the Ch3 story choices (choice
##    buttons, including one wrong answer), the cutscenes, the shloka cards, the grove waves, the court and the credits.
##    The climb from the training rocks up the Mahendra terraces to the peak is a real walk too (keyboard input along
##    a route planned by plan_route), since the player now steps up the 0.5 m terraces (FX1).
##  - Shortcuts (allowed by the brief): the other long walks are teleports; most enemies are finished with apply_hit; the player
##    is made invulnerable during fights so that no fight depends on luck.
## The bot never edits game code. When a step cannot be completed it records a blocker (with the exact detail) and
## continues with a direct state change, so the rest of the game is still exercised.

const MAIN_SCENE: String = "res://main.tscn"
const DIALOGUE_DIR: String = "res://data/dialogue/"
## Game seconds per physics frame. Frames come at a fixed 60 Hz, scaled by time_scale for speed.
const FRAME: float = 1.0 / 60.0
const CHAPTER_ORDER: Array[StringName] = [&"prologue", &"ch1", &"ch2", &"ch3", &"ch4", &"ch5", &"epilogue", &"teaser_setu"]
const TELEPORT_LIFT: float = 0.4
const WALK_TOLERANCE: float = 0.8
const REAL_BUDGET_MSEC: int = 240000
## One entry per key direction the keyboard can give (8 directions); the chosen one is the best match for the goal.
const KEY_DIRS: Array[Vector2] = [
	Vector2(0.0, -1.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0),
	Vector2(0.7071068, -0.7071068), Vector2(-0.7071068, -0.7071068), Vector2(0.7071068, 0.7071068), Vector2(-0.7071068, 0.7071068),
]
const SAFE_LATERAL_GAP: float = 5.5

## Speed-up for the whole run. Every physics step is exactly 1/60 s of game time (the physics rate and the time scale
## are raised together), and every rendered frame is capped at 60 per real second, so a run is repeatable.
var speed: int = 8
var _saved_ticks: int = 60
var _saved_steps: int = 8
## When valid and it returns true, walk_to ends (successfully) at once: the goal's trigger fired on the way in.
var walk_stop: Callable = Callable()
var real_budget_msec: int = REAL_BUDGET_MSEC
## Development hook: stop after this chapter id ("prologue", "ch1" ...). Empty plays everything.
var stop_after: StringName = &""
## Chapter id -> {"reached": bool, "completed": bool, "notes": Array[String]}.
var chapters: Dictionary = {}
## Blocking bugs found in game code: {"chapter", "step", "detail"}.
var blockers: Array[Dictionary] = []
## Non-blocking observations.
var notes: Array[String] = []
## Counters proving the real paths were used.
var stats: Dictionary = {
	"real_walk_metres": 0.0, "real_light_attacks": 0, "real_attack_hits": 0, "dialogue_lines": 0, "choices_right": 0,
	"choices_wrong": 0, "cards_closed": 0, "puzzle_grows": 0, "puzzle_shrinks": 0, "simhika_hits": 0, "teleports": 0,
	"fire_burnt": 0, "fire_total": 0, "protected_total": 0, "protected_ignited": 0, "searches": 0, "waves_seen": 0,
	"frames": 0, "forced_steps": 0, "grow_in_prologue": false, "ring_collected": false,
}
var credits_reached: bool = false
var finished_flow: bool = false
var aborted: bool = false
var started_msec: int = 0

var main: Node = null
var flow: ChapterFlow = null
var menus: Menus = null
## Which chapter the bot is currently playing (for the report).
var current_chapter: StringName = &""

var _wrong_choice_done: bool = false
var _leap_gates: Array[StringName] = []
var _spent_blockers: Array[String] = []
var _saved_time_scale: float = 1.0
var _saved_max_fps: int = 0
var _pending_wrong_choice: bool = true


# ---------------------------------------------------------------- setup and teardown

## Starts the real main scene and presses New Game. The bot must already be inside the tree.
func boot() -> void:
	started_msec = Time.get_ticks_msec()
	_saved_time_scale = Engine.time_scale
	_saved_max_fps = Engine.max_fps
	_saved_ticks = Engine.physics_ticks_per_second
	_saved_steps = Engine.max_physics_steps_per_frame
	Engine.max_fps = 60
	for id: StringName in CHAPTER_ORDER:
		chapters[id] = {"reached": false, "completed": false, "notes": [] as Array[String]}
	var scene: PackedScene = load(MAIN_SCENE) as PackedScene
	main = scene.instantiate()
	add_child(main)
	flow = main.get_node("ChapterFlow") as ChapterFlow
	flow.autosave = false
	flow.chapter_started.connect(_on_chapter_started)
	flow.chapter_finished.connect(_on_chapter_finished)
	flow.all_done.connect(_on_all_done)
	menus = main.find_child("Menus", true, false) as Menus
	set_speed(speed)


## Sets the game speed: `factor` times real time, with a fixed 1/60 s physics step.
func set_speed(factor: int) -> void:
	Engine.max_physics_steps_per_frame = maxi(_saved_steps, factor + 2)
	Engine.physics_ticks_per_second = 60 * factor
	Engine.time_scale = float(factor)


func restore() -> void:
	_release_all()
	Engine.time_scale = _saved_time_scale
	Engine.physics_ticks_per_second = _saved_ticks
	Engine.max_physics_steps_per_frame = _saved_steps
	Engine.max_fps = _saved_max_fps


func _on_chapter_started(id: StringName) -> void:
	current_chapter = id
	if chapters.has(id):
		(chapters[id] as Dictionary)["reached"] = true


func _on_chapter_finished(id: StringName) -> void:
	if chapters.has(id):
		(chapters[id] as Dictionary)["completed"] = true


func _on_all_done() -> void:
	finished_flow = true


# ---------------------------------------------------------------- report helpers

func note(text: String) -> void:
	notes.append(text)
	var entry: Dictionary = chapters.get(current_chapter, {}) as Dictionary
	if not entry.is_empty():
		(entry["notes"] as Array[String]).append(text)


## Records a blocking bug (once per step) and returns so the caller can continue past it with a direct state change.
func block(step: String, detail: String) -> void:
	if _spent_blockers.has("%s/%s" % [str(current_chapter), step]):
		return
	_spent_blockers.append("%s/%s" % [str(current_chapter), step])
	blockers.append({"chapter": str(current_chapter), "step": step, "detail": detail})


func chapter_reached(id: StringName) -> bool:
	return (chapters.get(id, {}) as Dictionary).get("reached", false) as bool


func chapter_completed(id: StringName) -> bool:
	return (chapters.get(id, {}) as Dictionary).get("completed", false) as bool


func blockers_for(id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in blockers:
		if str(b["chapter"]) == str(id):
			out.append(b)
	return out


## The report as Markdown (written into tests/playtest/REPORT.md by hand after a run).
func to_markdown() -> String:
	var lines: Array[String] = []
	lines.append("| Chapter | Reached | Completed | Blocking bugs |")
	lines.append("|---|---|---|---|")
	for id: StringName in CHAPTER_ORDER:
		var found: Array[Dictionary] = blockers_for(id)
		lines.append("| %s | %s | %s | %d |" % [str(id), "yes" if chapter_reached(id) else "NO", "yes" if chapter_completed(id) else "NO", found.size()])
	lines.append("")
	lines.append("credits reached: %s" % str(credits_reached))
	lines.append("real seconds: %.1f" % elapsed_seconds())
	for b: Dictionary in blockers:
		lines.append("- BLOCKER [%s / %s] %s" % [str(b["chapter"]), str(b["step"]), str(b["detail"])])
	for n: String in notes:
		lines.append("- note: %s" % n)
	lines.append("stats: %s" % JSON.stringify(stats))
	return "\n".join(lines)


func elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - started_msec) / 1000.0


# ---------------------------------------------------------------- frame loop and UI servicing

func runtime() -> LevelRuntime:
	if main == null:
		return null
	var world: Node = main.get_node_or_null("World")
	if world == null:
		return null
	for child: Node in world.get_children():
		var rt: LevelRuntime = child as LevelRuntime
		if rt != null and not rt.is_queued_for_deletion():
			return rt
	return null


func credits_open() -> bool:
	return main != null and main.get("_credits") != null


## Waits one fixed physics frame and services the UI (dialogue lines, choices, shloka cards).
func frame() -> void:
	await get_tree().physics_frame
	stats["frames"] = (stats["frames"] as int) + 1
	if Time.get_ticks_msec() - started_msec > real_budget_msec:
		aborted = true
	_service()


## Runs frames until `done` is true. Returns false (and records `label`) when `max_seconds` of game time pass first.
func until(done: Callable, max_seconds: float, label: String = "") -> bool:
	var frames: int = int(max_seconds / FRAME)
	for i: int in frames:
		if done.call() as bool:
			return true
		if aborted:
			return false
		await frame()
	if done.call() as bool:
		return true
	if label != "":
		note("timeout after %.0f s waiting for: %s" % [max_seconds, label])
	return false


func wait_seconds(seconds: float) -> void:
	var frames: int = int(seconds / FRAME)
	for i: int in frames:
		if aborted:
			return
		await frame()


func _service() -> void:
	var rt: LevelRuntime = runtime()
	if rt == null:
		return
	var box: DialogueBox = rt.dialogue_box()
	if box != null:
		box.chars_per_second = 5000.0
	var unlock_card: UnlockCard = rt.unlock_card()
	if unlock_card != null and unlock_card.is_open():
		_press_key()  # an ability-unlock card (DESIGN §4.1a) closes with the real Interact input
		stats["cards_closed"] = (stats["cards_closed"] as int) + 1
		return
	for card_node: Node in rt.find_children("*", "ShlokaCard", true, false):
		var card: ShlokaCard = card_node as ShlokaCard
		if card != null and card.is_open():
			_press_key()
			stats["cards_closed"] = (stats["cards_closed"] as int) + 1
			return
	if box == null or not box.is_playing():
		return
	var runner: DialogueRunner = box.get_runner()
	if runner.waiting_for_choice():
		_answer_choice(box)
		return
	_press_key()
	stats["dialogue_lines"] = (stats["dialogue_lines"] as int) + 1


## One "interact" key press through the real input pipeline (the dialogue box and shloka card read it).
func _press_key() -> void:
	var down: InputEventAction = InputEventAction.new()
	down.action = &"interact"
	down.pressed = true
	Input.parse_input_event(down)
	var up: InputEventAction = InputEventAction.new()
	up.action = &"interact"
	up.pressed = false
	Input.parse_input_event(up)


## The choice that is true to the text is the one that awards Smarana. Once, the bot answers wrongly on purpose to
## prove the gentle retry (DESIGN §3 Ch3).
func _answer_choice(box: DialogueBox) -> void:
	var buttons: Array[Button] = box.choice_buttons()
	if buttons.is_empty() or not buttons[0].visible:
		return
	var runner: DialogueRunner = box.get_runner()
	var right: int = _right_choice(box, runner.current_node())
	var pick: int = right
	if _pending_wrong_choice and buttons.size() > 1 and str(runner.current_node()) == "c1":
		_pending_wrong_choice = false
		pick = 1 if right == 0 else 0
		stats["choices_wrong"] = (stats["choices_wrong"] as int) + 1
		_wrong_choice_done = true
	else:
		stats["choices_right"] = (stats["choices_right"] as int) + 1
	buttons[pick].pressed.emit()


func _right_choice(box: DialogueBox, node_id: String) -> int:
	var file_id: String = str(box.get("_file_id"))
	var path: String = "%s%s.json" % [DIALOGUE_DIR, file_id]
	if not FileAccess.file_exists(path):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return 0
	var nodes: Dictionary = (parsed as Dictionary).get("nodes", {}) as Dictionary
	var entry: Dictionary = nodes.get(node_id, {}) as Dictionary
	var choices: Array = entry.get("choices", []) as Array
	for i: int in choices.size():
		var choice: Dictionary = choices[i] as Dictionary
		if (choice.get("smarana", 0) as float) > 0.0:
			return i
	return 0


# ---------------------------------------------------------------- input helpers (real actions)

func _release_all() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack_light", &"attack_heavy", &"grow", &"shrink", &"leap"]:
		if InputMap.has_action(action):
			Input.action_release(action)


## Holds one keyboard direction (or none for Vector2.ZERO).
func _hold_direction(v: Vector2) -> void:
	_set_action(&"move_left", maxf(-v.x, 0.0))
	_set_action(&"move_right", maxf(v.x, 0.0))
	_set_action(&"move_up", maxf(-v.y, 0.0))
	_set_action(&"move_down", maxf(v.y, 0.0))


func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


## Presses an action long enough for both the physics poll and the _process poll to see "just pressed".
func tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().physics_frame


## The keyboard direction whose camera-relative result is closest to the world direction `want`.
func best_key_direction(camera_basis: Basis, want: Vector3) -> Vector2:
	var flat: Vector3 = Vector3(want.x, 0.0, want.z)
	if flat.length() < 0.001:
		return Vector2.ZERO
	flat = flat.normalized()
	var best: Vector2 = Vector2.ZERO
	var best_dot: float = -2.0
	for key: Vector2 in KEY_DIRS:
		var world: Vector3 = camera_basis * Vector3(key.x, 0.0, key.y)
		world.y = 0.0
		if world.length() < 0.001:
			continue
		var d: float = world.normalized().dot(flat)
		if d > best_dot:
			best_dot = d
			best = key
	return best


## Walks the player to `goal` (x, z) with the keyboard. Returns false when it gets stuck or times out.
func walk_to(goal: Vector2, tolerance: float = WALK_TOLERANCE, max_seconds: float = 12.0) -> bool:
	var rt: LevelRuntime = runtime()
	var player: Player = rt.player()
	var camera: Node3D = player.get_node_or_null(player.camera_path) as Node3D
	var basis_used: Basis = camera.global_transform.basis if camera != null else Basis.IDENTITY
	var last_progress: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	var check: float = 0.0
	var frames: int = int(max_seconds / FRAME)
	for i: int in frames:
		if aborted:
			break
		if walk_stop.is_valid() and walk_stop.call() as bool:
			_hold_direction(Vector2.ZERO)
			return true
		if not is_instance_valid(player) or not player.is_inside_tree():
			return false
		var here: Vector2 = Vector2(player.global_position.x, player.global_position.z)
		if here.distance_to(goal) <= tolerance:
			_hold_direction(Vector2.ZERO)
			return true
		if rt.input_locked():
			_hold_direction(Vector2.ZERO)
			await frame()
			continue
		var want: Vector3 = Vector3(goal.x - here.x, 0.0, goal.y - here.y)
		_hold_direction(best_key_direction(basis_used, want))
		await frame()
		var after: Vector2 = Vector2(player.global_position.x, player.global_position.z)
		stats["real_walk_metres"] = (stats["real_walk_metres"] as float) + here.distance_to(after)
		check += FRAME
		if check >= 3.0:
			check = 0.0
			if after.distance_to(last_progress) < 0.5:
				break
			last_progress = after
	_hold_direction(Vector2.ZERO)
	var final_here: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	return final_here.distance_to(goal) <= tolerance


## Height of the ground at (x, z), by a ray from above. Falls back to `fallback`.
func ground_y(x: float, z: float, fallback: float) -> float:
	var rt: LevelRuntime = runtime()
	var space: PhysicsDirectSpaceState3D = rt.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, 40.0, z), Vector3(x, -5.0, z), Layers.mask([Layers.WORLD]))
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return fallback
	return (hit["position"] as Vector3).y


## Moves the player straight to (x, z) and lets the physics settle.
func teleport(x: float, z: float) -> void:
	var rt: LevelRuntime = runtime()
	var player: Player = rt.player()
	var y: float = ground_y(x, z, player.global_position.y)
	player.global_position = Vector3(x, y + TELEPORT_LIFT, z)
	player.velocity = Vector3.ZERO
	stats["teleports"] = (stats["teleports"] as int) + 1
	for i: int in 4:
		await frame()


## Plans a walkable route across a level's tile grid with an A* search over 4-neighbour cells: only ground, stone floor,
## grass and sand tiles, steps of at most one between neighbours, and no cell whose centre is within CLEARANCE of a solid
## prop (or an NPC spawn). Returns the cell centres to visit (not the start cell) followed by `to`; empty when no route
## exists. The start and goal cells are always allowed.
static func plan_route(level: Dictionary, from: Vector2, to: Vector2) -> Array[Vector2]:
	var cells: Dictionary = {}
	for entry: Variant in level.get("tiles", []) as Array:
		var tile: Dictionary = entry as Dictionary
		var kind: String = str(tile.get("type", "ground"))
		if kind == "ground" or kind == "stone_floor" or kind == "grass" or kind == "sand":
			cells[Vector2i(tile.get("x", 0) as int, tile.get("z", 0) as int)] = tile.get("step", 0) as int
	var start: Vector2i = Vector2i(floori(from.x / 2.0), floori(from.y / 2.0))
	var goal: Vector2i = Vector2i(floori(to.x / 2.0), floori(to.y / 2.0))
	var solids: Array[Dictionary] = _route_solids(level)
	var open: Array[Vector2i] = [start]
	var came: Dictionary = {start: start}
	var cost: Dictionary = {start: 0.0}
	var found: bool = false
	while not open.is_empty():
		var best: int = 0
		for i: int in open.size():
			var fi: float = (cost[open[i]] as float) + Vector2(open[i]).distance_to(Vector2(goal))
			var fb: float = (cost[open[best]] as float) + Vector2(open[best]).distance_to(Vector2(goal))
			if fi < fb:
				best = i
		var here: Vector2i = open[best]
		open.remove_at(best)
		if here == goal:
			found = true
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = here + d
			if not cells.has(next) or absi((cells[next] as int) - (cells[here] as int)) > 1:
				continue
			if next != goal and _route_blocked(next, solids):
				continue
			var new_cost: float = (cost[here] as float) + 1.0
			if not cost.has(next) or new_cost < (cost[next] as float):
				cost[next] = new_cost
				came[next] = here
				open.append(next)
	var route: Array[Vector2] = []
	if not found:
		return route
	var walk: Vector2i = goal
	while walk != start:
		route.push_front(Vector2(float(walk.x) * 2.0 + 1.0, float(walk.y) * 2.0 + 1.0))
		walk = came[walk] as Vector2i
	if not route.is_empty():
		route[route.size() - 1] = to
	return route


const ROUTE_CLEARANCE: float = 1.2


static func _route_solids(level: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in level.get("props", []) as Array:
		var prop: Dictionary = entry as Dictionary
		var kind: String = str(prop.get("kind", ""))
		if kind == "grass_patch":
			continue
		var pos: Array = prop.get("pos", [0.0, 0.0]) as Array
		var size: Array = prop.get("size", [2.0, 3.0, 2.0]) as Array
		var half: float = maxf(size[0] as float, size[2] as float) * 0.5
		if kind.ends_with("_tree"):
			half = 0.6
		out.append({"x": pos[0] as float, "z": pos[1] as float, "half": half})
	for entry: Variant in level.get("spawns", []) as Array:
		var spawn: Dictionary = entry as Dictionary
		if str(spawn.get("kind", "")).begins_with("npc_"):
			var at: Array = spawn.get("pos", [0.0, 0.0]) as Array
			out.append({"x": at[0] as float, "z": at[1] as float, "half": 0.7})
	return out


static func _route_blocked(cell: Vector2i, solids: Array[Dictionary]) -> bool:
	var cx: float = float(cell.x) * 2.0 + 1.0
	var cz: float = float(cell.y) * 2.0 + 1.0
	for solid: Dictionary in solids:
		var reach: float = (solid["half"] as float) + ROUTE_CLEARANCE
		if absf(cx - (solid["x"] as float)) < reach and absf(cz - (solid["z"] as float)) < reach:
			return true
	return false


## Walks the player along plan_route's waypoints with the keyboard. Returns true when the goal is reached.
func walk_route(level_id: StringName, goal: Vector2, max_seconds: float = 10.0) -> bool:
	var rt: LevelRuntime = runtime()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s.json" % str(level_id)))
	if not (parsed is Dictionary):
		return false
	var here: Vector3 = rt.player().global_position
	var route: Array[Vector2] = plan_route(parsed as Dictionary, Vector2(here.x, here.z), goal)
	if route.is_empty():
		return false
	for i: int in route.size():
		var last: bool = i == route.size() - 1
		var ok: bool = await walk_to(route[i], 0.6 if last else 0.9, max_seconds)
		if not ok:
			return false
	return true


## Gets the level trigger `id` to fire: first by standing in it, and if the physics did not route it, by firing it
## directly (and noting that the entry did not work).
func enter_trigger(trigger_id: StringName, at: Vector2, walk_level: StringName = &"") -> void:
	var rt: LevelRuntime = runtime()
	var fired: Array[bool] = [false]
	var rt_id: int = rt.get_instance_id()
	var handler: Callable = func(tid: StringName, _on: String) -> void:
		if tid == trigger_id:
			fired[0] = true
	rt.trigger_fired.connect(handler)
	if walk_level != &"":
		walk_stop = func() -> bool: return fired[0]
		var walked: bool = await walk_route(walk_level, at)
		walk_stop = Callable()
		if not walked:
			note("could not walk to trigger %s at %s; teleported" % [str(trigger_id), str(at)])
			await teleport(at.x, at.y)
	else:
		await teleport(at.x, at.y)
	await until(func() -> bool:
		var now: LevelRuntime = runtime()
		return fired[0] or now == null or now.get_instance_id() != rt_id, 1.0)
	var now_rt: LevelRuntime = runtime()
	if not fired[0] and now_rt != null and now_rt.get_instance_id() == rt_id:
		note("trigger %s did not fire when the player stood in it at %s; fired directly" % [str(trigger_id), str(at)])
		rt.fire_trigger(trigger_id)
	if now_rt != null and now_rt.get_instance_id() == rt_id and rt.trigger_fired.is_connected(handler):
		rt.trigger_fired.disconnect(handler)


## Waits until no cutscene is running, nothing is queued, no dialogue is open and the player may act.
func free_control(max_seconds: float = 120.0, label: String = "control") -> bool:
	var ok: bool = await until(func() -> bool:
		if credits_open() or flow.is_finished():
			return true
		var rt: LevelRuntime = runtime()
		if rt == null or (rt.player() == null and rt.leap() == null):
			return false
		var box: DialogueBox = rt.dialogue_box()
		return not flow.is_busy_with_cutscene() and flow.queued_cutscenes().is_empty() and not rt.input_locked() \
			and not (box != null and box.is_playing()), max_seconds, "free " + label)
	if not ok and not aborted:
		var rt: LevelRuntime = runtime()
		note("state at timeout: chapter %s level %s busy=%s queue=%s locked=%s dialogue=%s cutscene_playing=%s" % [str(flow.current_id()), \
			str(rt.level_id()) if rt != null else "-", str(flow.is_busy_with_cutscene()), str(flow.queued_cutscenes()), \
			str(rt.input_locked()) if rt != null else "-", str(rt.dialogue_box().is_playing()) if rt != null else "-", \
			str(rt.cutscene_player().is_playing()) if rt != null else "-"])
	return ok


func wait_level(level_id: StringName, max_seconds: float = 30.0) -> bool:
	var ok: bool = await until(func() -> bool:
		var rt: LevelRuntime = runtime()
		return rt != null and rt.level_id() == level_id and (rt.player() != null or rt.leap() != null), max_seconds, "level %s loaded" % str(level_id))
	if ok:
		await frame()
	return ok


func wait_chapter(id: StringName, max_seconds: float = 60.0) -> bool:
	return await until(func() -> bool: return flow.current_id() == id, max_seconds, "chapter %s" % str(id))


func set_precise(on: bool) -> void:
	set_speed(2 if on else speed)


## Makes the player unhittable (so a fight never depends on luck) or hittable again.
func set_invulnerable(on: bool) -> void:
	var rt: LevelRuntime = runtime()
	if rt != null and rt.player() != null:
		rt.player().get_health().invulnerable = on


# ---------------------------------------------------------------- the whole game

## Plays New Game -> credits. Returns true when the credits screen came up.
func play_all() -> bool:
	boot()
	await frame()
	menus.start_requested.emit()
	await _play_prologue()
	if stop_after == &"prologue":
		return false
	await _play_ch1()
	if stop_after == &"ch1":
		return false
	await _play_ch2()
	if stop_after == &"ch2":
		return false
	await _play_ch3()
	if stop_after == &"ch3":
		return false
	await _play_ch4()
	if stop_after == &"ch4":
		return false
	await _play_ch5()
	if stop_after == &"ch5":
		return false
	await _play_ending()
	restore()
	return credits_reached


func _force_chapter(id: StringName, why: String) -> void:
	stats["forced_steps"] = (stats["forced_steps"] as int) + 1
	note("forced past %s: %s" % [str(id), why])
	var next_index: int = flow.chapter_ids().find(id) + 1
	if flow.current_id() == id:
		flow.start_chapter(next_index)
	await frame()


# ---- prologue ----

func _play_prologue() -> void:
	current_chapter = &"prologue"
	if not await wait_level(&"mahendra", 40.0):
		block("load", "mahendra did not load after New Game")
		return
	# the opening title cutscene (with its shloka card) plays by itself
	await free_control(90.0, "opening cutscene")
	var rt: LevelRuntime = runtime()
	var start: Vector3 = rt.player().global_position
	# Real movement: walk to Jambavan (his trigger is 6 m east of the start).
	var ok: bool = await walk_to(Vector2(19.0, 13.0), 1.8, 10.0)
	if not ok:
		block("walk_to_jambavan", "the player could not walk 6 m east from %s to the t_jambavan trigger with the keyboard" % str(start))
		rt.fire_trigger(&"t_jambavan")
	# Jambavan's dialogue waits for the Interact key near him (DESIGN §4.1a): press it through the real input pipeline.
	await wait_seconds(0.2)
	_press_key()
	await until(func() -> bool: return rt.dialogue_box().is_playing() or flow.is_objective_done(&"talk_jambavan"), 3.0)
	if not rt.dialogue_box().is_playing() and not flow.is_objective_done(&"talk_jambavan"):
		note("Interact near Jambavan did not start his dialogue; fired the trigger directly")
		rt.fire_trigger(&"t_jambavan")
	await free_control(60.0, "jambavan dialogue")
	if not flow.is_objective_done(&"talk_jambavan"):
		block("jambavan_objective", "objective talk_jambavan not done after the Jambavan dialogue")
	# Grow was taught by Jambavan's words: press Grow for real, check the size and go back to normal.
	set_precise(true)
	await tap(&"grow")
	await frame()
	stats["grow_in_prologue"] = rt.size_shift().get_size() == SizeShift.SIZE.LARGE
	if not (stats["grow_in_prologue"] as bool):
		block("grow_after_jambavan", "pressing Grow after the Jambavan dialogue did not make Hanuman LARGE (size %d)" % int(rt.size_shift().get_size()))
	rt.size_shift().force_size(SizeShift.SIZE.NORMAL)
	set_precise(false)
	# Training: walk to the rocks and strike them with real light attacks, then stand in the training trigger.
	var trained: bool = await walk_to(Vector2(13.0, 16.0), 1.0, 10.0)
	if not trained:
		note("could not walk to the training rocks; teleported")
		await teleport(13.0, 16.0)
	await _swing(3)
	if not flow.is_objective_done(&"training"):
		await enter_trigger(&"t_training_done", Vector2(13.0, 17.0))
	if not flow.is_objective_done(&"training"):
		block("training_objective", "objective 'training' not done after standing in t_training_done")
	# The leap point at the peak: a real climb up the terraces.
	await enter_trigger(&"t_leap", Vector2(43.0, 43.0), &"mahendra")
	await free_control(60.0, "leap dialogue")
	await wait_chapter(&"ch1", 40.0)


## Light attacks with the real action. Counts them.
func _swing(count: int) -> void:
	set_precise(true)
	for i: int in count:
		await tap(&"attack_light")
		stats["real_light_attacks"] = (stats["real_light_attacks"] as int) + 1
		await wait_seconds(0.4)
	set_precise(false)


# ---- chapter 1: the leap ----

func _play_ch1() -> void:
	current_chapter = &"ch1"
	if not await wait_level(&"ocean_leap", 40.0):
		block("load", "ocean_leap did not load")
		await _force_chapter(&"ch1", "ocean_leap never loaded")
		return
	await free_control(30.0, "leap start")
	var rt: LevelRuntime = runtime()
	var controller: LeapController = rt.leap()
	_leap_gates.clear()
	controller.gate_reached.connect(func(id: StringName) -> void: _leap_gates.append(id))
	controller.ring_collected.connect(func() -> void: stats["ring_collected"] = true)
	var frames_left: int = int(150.0 / FRAME)
	while frames_left > 0 and flow.current_id() == &"ch1" and not aborted:
		frames_left -= 1
		_steer(controller)
		await _leap_gate_logic(rt, controller)
		await frame()
	_release_all()
	set_precise(false)
	if flow.current_id() == &"ch1":
		block("leap_finish", "the leap did not complete in 150 s of game time (gates reached: %s)" % str(_leap_gates))
		await _force_chapter(&"ch1", "leap did not finish")
	else:
		await wait_chapter(&"ch2", 30.0)


## Steers away from the next obstacle (and onto the Mainaka ring) with the real move actions.
func _steer(controller: LeapController) -> void:
	var want: float = 0.0
	if controller.paused_at_gate:
		_hold_direction(Vector2.ZERO)
		return
	for o: Dictionary in controller.obstacle_defs:
		var d: float = (o.get("d", 0.0) as float) - controller.distance
		if d < -3.0 or d > 32.0:
			continue
		var at: float = o.get("lateral", 0.0) as float
		want = at + SAFE_LATERAL_GAP if at <= 0.0 else at - SAFE_LATERAL_GAP
		break
	if absf(controller.distance - 220.0) < 25.0:
		want = 0.0
	var diff: float = want - controller.lateral
	if absf(diff) < 0.6:
		_hold_direction(Vector2.ZERO)
	else:
		_hold_direction(Vector2(signf(diff), 0.0))


func _leap_gate_logic(rt: LevelRuntime, controller: LeapController) -> void:
	var puzzle: ChapterFlow.SurasaPuzzle = flow.puzzle()
	if puzzle != null and puzzle.is_active() and not rt.input_locked():
		set_precise(true)
		if puzzle.phase == ChapterFlow.SurasaPuzzle.Phase.GROWING:
			var before: int = puzzle.grows
			await tap(&"grow")
			if puzzle.grows > before:
				stats["puzzle_grows"] = (stats["puzzle_grows"] as int) + 1
		elif puzzle.phase == ChapterFlow.SurasaPuzzle.Phase.WINDOW:
			await tap(&"shrink")
			if puzzle.phase == ChapterFlow.SurasaPuzzle.Phase.DONE:
				stats["puzzle_shrinks"] = (stats["puzzle_shrinks"] as int) + 1
		return
	var boss: BossSimhika = rt.get_node_or_null("BossSimhika") as BossSimhika
	if boss != null and is_instance_valid(boss) and boss.active and not boss.is_defeated() and not rt.input_locked():
		set_precise(true)
		_hold_direction(Vector2.ZERO)
		if boss.window_open() or boss.is_inside():
			if boss.window_open():
				await tap(&"shrink")
			else:
				await _simhika_strike(boss)
		elif boss.is_vulnerable():
			await _simhika_strike(boss)
		return
	if not controller.paused_at_gate:
		set_precise(false)


func _simhika_strike(boss: BossSimhika) -> void:
	var before: int = boss.health.value
	await tap(&"attack_light")
	if boss.health.value < before:
		stats["simhika_hits"] = (stats["simhika_hits"] as int) + 1


# ---- chapter 2: Night in Lanka ----

func _play_ch2() -> void:
	current_chapter = &"ch2"
	if not await wait_chapter(&"ch2", 30.0) or not await wait_level(&"lanka_gate", 40.0):
		block("load", "lanka_gate did not load after the leap")
		await _force_chapter(&"ch2", "lanka_gate never loaded")
		return
	await free_control(60.0, "gate entry")
	var rt: LevelRuntime = runtime()
	set_invulnerable(true)
	# The gate: Lankini's dialogue, then the duel.
	await enter_trigger(&"t_lankini", Vector2(19.0, 15.0))
	await free_control(60.0, "lankini dialogue")
	var lankini: BossLankini = rt.actors().get("lankini", null) as BossLankini
	if lankini == null:
		block("lankini", "no Lankini actor in lanka_gate")
	else:
		await _duel(lankini)
	await free_control(60.0, "lankini yields")
	if not flow.is_objective_done(&"lankini"):
		block("lankini_objective", "objective 'lankini' not done after Lankini yielded")
	var gs: Node = main.get_node("/root/GameState")
	if not (gs.call("get_flag", &"gate_open", false) as bool):
		block("gate_open", "flag gate_open was not set after the Lankini cutscene, so the gate trigger cannot advance to lanka_streets")
		gs.call("set_flag", &"gate_open", true)
	await enter_trigger(&"t_gate_open", Vector2(19.0, 33.0))
	if not await wait_level(&"lanka_streets", 30.0):
		block("streets_load", "lanka_streets did not load after t_gate_open with gate_open set")
		flow.handle_event("level:lanka_streets")
		await wait_level(&"lanka_streets", 30.0)
	await _play_streets()


func _duel(boss: BossLankini) -> void:
	set_precise(false)
	var frames: int = int(60.0 / FRAME)
	for i: int in frames:
		if aborted or boss.has_yielded() or not is_instance_valid(boss):
			break
		if i % 20 == 0 and boss.state != EnemyBase.State.DISSOLVE:
			boss.apply_hit(70, Vector3.ZERO, true)
		await frame()
	if is_instance_valid(boss) and not boss.has_yielded():
		block("lankini_defeat", "Lankini did not yield after 60 s of 70-damage hits")
		boss.health.damage(boss.health.max_value, null)
		await wait_seconds(3.0)


func _play_streets() -> void:
	var rt: LevelRuntime = runtime()
	await free_control(30.0, "streets entry")
	set_invulnerable(true)
	var places: Array[Dictionary] = [
		{"id": &"t_search_0", "at": Vector2(41.0, 41.0)},
		{"id": &"t_search_1", "at": Vector2(81.0, 81.0)},
		{"id": &"t_search_2", "at": Vector2(25.0, 87.0)},
	]
	for place: Dictionary in places:
		await enter_trigger(place["id"] as StringName, place["at"] as Vector2)
		await free_control(20.0, "search")
	stats["searches"] = flow.search_count()
	if flow.search_count() < 3:
		block("searches", "only %d of 3 searches registered after entering the three search triggers" % flow.search_count())
	await enter_trigger(&"t_despair", Vector2(88.0, 9.0))
	await free_control(60.0, "despair beat")
	await enter_trigger(&"t_vatika", Vector2(92.0, 5.0))
	await free_control(30.0, "vatika exit")
	if flow.current_id() == &"ch2":
		block("ch2_complete", "chapter 2 did not complete after three searches and t_vatika")
		await _force_chapter(&"ch2", "t_vatika did not complete the chapter")
	rt = null


# ---- chapter 3: the grove ----

func _play_ch3() -> void:
	current_chapter = &"ch3"
	if not await wait_chapter(&"ch3", 30.0) or not await wait_level(&"ashoka_vatika", 40.0):
		block("load", "ashoka_vatika did not load for chapter 3")
		await _force_chapter(&"ch3", "grove never loaded")
		return
	await free_control(30.0, "grove entry")
	set_invulnerable(true)
	var rt: LevelRuntime = runtime()
	_pending_wrong_choice = true
	await enter_trigger(&"t_grove_story", Vector2(29.0, 33.0))
	await free_control(120.0, "grove story")
	var gs: Node = main.get_node("/root/GameState")
	if not (gs.call("get_flag", &"ch3_done", false) as bool):
		block("ch3_done", "flag ch3_done was not set after the grove dialogue")
		gs.call("set_flag", &"ch3_done", true)
		flow.handle_event("dialogue:ch3_grove")
	if not (gs.call("get_flag", &"ring_given", false) as bool) or not (gs.call("get_flag", &"chudamani", false) as bool):
		block("ring_and_chudamani", "ring_given / chudamani flags missing after the grove dialogue")
	if rt != null and flow.current_id() == &"ch3":
		await _force_chapter(&"ch3", "chapter did not advance after ch3_done")
	await wait_chapter(&"ch4", 30.0)


# ---- chapter 4: the battle ----

func _play_ch4() -> void:
	current_chapter = &"ch4"
	if not await wait_chapter(&"ch4", 30.0) or not await wait_level(&"ashoka_vatika", 40.0):
		block("load", "ashoka_vatika did not load for chapter 4")
		await _force_chapter(&"ch4", "arena never loaded")
		return
	await free_control(60.0, "battle cry cutscene")
	set_invulnerable(true)
	var rt: LevelRuntime = runtime()
	var ok: bool = await until(func() -> bool: return rt.encounter().current_wave() >= 0 or rt.encounter().is_finished(), 20.0, "first wave")
	if not ok:
		block("encounter_start", "the encounter did not start after the battle-cry cutscene (encounter_requested)")
		rt.begin_encounter(4)
	var fought_for_real: bool = false
	var guard: int = int(240.0 / FRAME)
	var last_wave: int = -2
	while guard > 0 and not rt.encounter().is_finished() and not aborted and flow.current_id() == &"ch4":
		guard -= 1
		var wave: int = rt.encounter().current_wave()
		if wave != last_wave:
			last_wave = wave
			stats["waves_seen"] = (stats["waves_seen"] as int) + 1
		if not fought_for_real:
			var brute: Node3D = _first_enemy()
			if brute != null:
				fought_for_real = true
				await _real_fight(brute)
				continue
		_strike_enemies()
		await frame()
	if not rt.encounter().is_finished() and flow.current_id() == &"ch4":
		block("waves", "the waves did not finish in 240 s of game time (current wave %d, living %d)" % [rt.encounter().current_wave(), rt.encounter().living_count()])
	await free_control(60.0, "brahmastra cutscene")
	if flow.current_id() == &"ch4":
		await _force_chapter(&"ch4", "chapter did not complete after the waves")
	await wait_chapter(&"ch5", 30.0)


func _first_enemy() -> Node3D:
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy != null and enemy.is_inside_tree() and enemy.state != EnemyBase.State.DISSOLVE:
			return enemy
	return null


## Finishes every living enemy with big hits (a shortcut allowed by the brief), at most every 6 frames.
func _strike_enemies() -> void:
	if (stats["frames"] as int) % 6 != 0:
		return
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or not enemy.is_inside_tree() or enemy.state == EnemyBase.State.DISSOLVE:
			continue
		enemy.apply_hit(120, Vector3.ZERO, true)


## One fight with the player's own attacks: walk up to the enemy and swing until it is down (or 40 s pass).
func _real_fight(target: Node3D) -> void:
	var rt: LevelRuntime = runtime()
	var player: Player = rt.player()
	var enemy: EnemyBase = target as EnemyBase
	await teleport(target.global_position.x - 5.0, target.global_position.z)
	set_precise(true)
	var frames: int = int(40.0 / FRAME)
	var start_hp: int = enemy.health.value
	var hits: int = 0
	var last_hp: int = start_hp
	for i: int in frames:
		if aborted or not is_instance_valid(enemy) or enemy.state == EnemyBase.State.DISSOLVE:
			break
		var to: Vector3 = enemy.global_position - player.global_position
		to.y = 0.0
		var camera: Node3D = player.get_node_or_null(player.camera_path) as Node3D
		var basis_used: Basis = camera.global_transform.basis if camera != null else Basis.IDENTITY
		if to.length() > 1.4:
			_hold_direction(best_key_direction(basis_used, to))
			stats["real_walk_metres"] = (stats["real_walk_metres"] as float) + 5.0 * FRAME
		else:
			_hold_direction(Vector2.ZERO)
			if i % 18 == 0:
				Input.action_press(&"attack_light")
				stats["real_light_attacks"] = (stats["real_light_attacks"] as int) + 1
			elif i % 18 == 3:
				Input.action_release(&"attack_light")
		await frame()
		if is_instance_valid(enemy) and enemy.health.value < last_hp:
			hits += 1
			last_hp = enemy.health.value
	_release_all()
	stats["real_attack_hits"] = (stats["real_attack_hits"] as int) + hits
	if is_instance_valid(enemy) and enemy.state != EnemyBase.State.DISSOLVE:
		block("real_fight", "the player's real light attacks did not defeat a Kinkara in 40 s (hp %d -> %d, hits landed %d)" % [start_hp, enemy.health.value, hits])
		enemy.apply_hit(500, Vector3.ZERO, true)
	set_precise(false)


# ---- chapter 5: court and fire ----

func _play_ch5() -> void:
	current_chapter = &"ch5"
	if not await wait_chapter(&"ch5", 30.0) or not await wait_level(&"ravana_court", 40.0):
		block("load", "ravana_court did not load for chapter 5")
		await _force_chapter(&"ch5", "court never loaded")
		return
	await free_control(30.0, "court entry")
	set_invulnerable(true)
	await enter_trigger(&"t_court", Vector2(15.0, 11.0))
	await free_control(120.0, "court dialogue")
	if not await wait_level(&"lanka_rooftops", 30.0):
		block("rooftops_load", "lanka_rooftops did not load after the court dialogue")
		flow.handle_event("dialogue:ch5_court")
		await wait_level(&"lanka_rooftops", 30.0)
	await free_control(60.0, "rooftops entry")
	set_invulnerable(true)
	await _burn_the_rooftops()
	var rt: LevelRuntime = runtime()
	await enter_trigger(&"t_grove_check", Vector2(109.0, 105.0))
	await free_control(60.0, "grove check")
	await enter_trigger(&"t_ocean_exit", Vector2(65.0, 9.0))
	await free_control(90.0, "ocean exit and return cutscene")
	if flow.current_id() == &"ch5":
		block("ch5_complete", "chapter 5 did not complete at t_ocean_exit (chapter_complete:ch5)")
		await _force_chapter(&"ch5", "ocean exit did not complete the chapter")
	rt = null


func _burn_the_rooftops() -> void:
	var rt: LevelRuntime = runtime()
	var props: Node = rt.level_root().get_node("Props")
	var fire: FireSystem = rt.fire()
	var flammable: Array[Node3D] = []
	var protected_props: Array[Node3D] = []
	for child: Node in props.get_children():
		var prop: Node3D = child as Node3D
		if prop == null:
			continue
		if prop.get_meta("protected", false) as bool:
			protected_props.append(prop)
		elif prop.get_meta("flammable", false) as bool:
			flammable.append(prop)
	stats["fire_total"] = flammable.size()
	stats["protected_total"] = protected_props.size()
	if flammable.is_empty():
		block("fire_targets", "lanka_rooftops has no flammable props")
		return
	# Fly over every flammable target with the tail fire; the player's own tail ignites it.
	for prop: Node3D in flammable:
		var p: Vector3 = prop.global_position
		await teleport(p.x - 2.2, p.z)
		if not fire.is_burning(prop) and not fire.is_burnt(prop):
			rt.burn_near(p)
			note("tail fire did not catch %s by standing next to it; burn_near used" % str(prop.name))
	await wait_seconds(1.0)
	var burnt: int = 0
	for prop: Node3D in flammable:
		if fire.is_burning(prop) or fire.is_burnt(prop):
			burnt += 1
	stats["fire_burnt"] = burnt
	if burnt < flammable.size():
		block("fire_all", "only %d of %d flammable props are burning or burnt" % [burnt, flammable.size()])
	# Protected props (innocent homes, Vibhishana's house, the grove) must never ignite, even when the tail is beside them
	# and even when ignite() is called on them directly.
	var ignited: int = 0
	for prop: Node3D in protected_props:
		var p: Vector3 = prop.global_position
		fire.ignite(prop)
		rt.burn_near(p)
	await wait_seconds(8.0)
	for prop: Node3D in protected_props:
		if fire.is_burning(prop) or fire.is_burnt(prop):
			ignited += 1
	stats["protected_ignited"] = ignited
	if ignited > 0:
		block("protected_burnt", "%d protected props ignited" % ignited)
	if not flow.is_objective_done(&"burn"):
		block("burn_objective", "objective 'burn' not done after props were set alight (fire_ignited event)")


# ---- epilogue, teaser and credits ----

func _play_ending() -> void:
	current_chapter = &"epilogue"
	await until(func() -> bool: return credits_open() or flow.is_finished(), 180.0, "credits")
	credits_reached = credits_open()
	if not credits_reached and flow.is_finished():
		block("credits", "ChapterFlow finished but main did not show the credits")
