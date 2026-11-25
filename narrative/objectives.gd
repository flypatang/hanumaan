extends Node
## Autoload `Objectives` (DESIGN §9, M17): the player's current goals.
## Each objective has an id, a text and a done flag. Every real change is announced through
## EventBus.objective_updated(id, text, done). Adding an id that already exists does nothing,
## and completing an unknown or already completed id does nothing.

const _BUS_NAME: String = "EventBus"

var _texts: Dictionary = {}
var _done: Dictionary = {}


func add(id: StringName, text: String) -> void:
	if _texts.has(id):
		return
	_texts[id] = text
	_done[id] = false
	_announce(id)


func complete(id: StringName) -> void:
	if not _texts.has(id):
		return
	var already: bool = _done[id] as bool
	if already:
		return
	_done[id] = true
	_announce(id)


func is_done(id: StringName) -> bool:
	var done: bool = _done.get(id, false) as bool
	return done


func _announce(id: StringName) -> void:
	var bus: Node = _event_bus()
	if bus == null:
		return
	var text: String = _texts[id] as String
	var done: bool = _done[id] as bool
	bus.emit_signal("objective_updated", id, text, done)


func _event_bus() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	var tree: SceneTree = loop as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(_BUS_NAME) as Node
