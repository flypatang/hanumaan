extends Node
## Autoload `EventBus` (DESIGN §8, §9 M02). Systems talk to each other only through these signals.
## It holds no state and no logic: emit from the owning system, connect from the listening system.

signal player_damaged(amount: int, source: Node)
signal player_exhausted()
signal player_recovered()
signal enemy_defeated(enemy_id: StringName, pos: Vector3)
signal size_changed(new_size: int)
signal smarana_changed(value: float)
signal vitality_changed(value: int, max: int)
signal objective_updated(id: StringName, text: String, done: bool)
signal dialogue_started(id: StringName)
signal dialogue_finished(id: StringName, flags: Dictionary)
signal level_loaded(id: StringName)
signal chapter_completed(id: StringName)
signal fire_ignited(target_id: StringName)
signal alarm_raised(pos: Vector3)
