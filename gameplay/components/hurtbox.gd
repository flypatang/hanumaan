class_name Hurtbox
extends Area3D
## A damageable volume (DESIGN §9 M14). It detects active Hitboxes of other teams and forwards each hit to the
## Health node at `health_path`. Each hitbox activation hits a given hurtbox at most once (`try_hit`).
## Emits `hit_taken` with the damage, a knockback velocity (away from the hitbox) and the hitbox's owner.

## Emitted when a hit is applied. `knockback` is a velocity vector on the XZ plane, pointing away from the hitbox.
signal hit_taken(damage: int, knockback: Vector3, source: Node)

## Team that owns this hurtbox: &"player", &"enemy" or &"fire". Sets the collision layer and mask.
@export var team: StringName = &"player":
	set = _set_team
## Path, relative to this node, of the Health node that receives damage.
@export var health_path: NodePath = NodePath("")

## Last activation id applied per hitbox (keyed by hitbox instance id).
var _applied: Dictionary[int, int] = {}


func _ready() -> void:
	# A hurtbox detects hitboxes; it does not need to be detected itself.
	monitorable = false
	monitoring = true
	_set_team(team)


func _physics_process(_delta: float) -> void:
	for area: Area3D in get_overlapping_areas():
		var hitbox: Hitbox = area as Hitbox
		if hitbox != null:
			try_hit(hitbox)


## Applies `hitbox` to this hurtbox if it is active, from another team, and has not already hit this activation.
## Returns true when a hit was applied.
func try_hit(hitbox: Hitbox) -> bool:
	if hitbox == null or not hitbox.is_active():
		return false
	if hitbox.team == team:
		return false
	var key: int = hitbox.get_instance_id()
	var activation: int = hitbox.get_activation_id()
	if _applied.has(key) and _applied[key] == activation:
		return false
	_applied[key] = activation

	var source: Node = hitbox.get_parent()
	if source == null:
		source = hitbox
	var health: Health = _resolve_health()
	if health != null:
		health.damage(hitbox.damage, source)
	hit_taken.emit(hitbox.damage, _knockback_from(hitbox), source)
	return true


func _resolve_health() -> Health:
	if health_path.is_empty():
		return null
	return get_node_or_null(health_path) as Health


func _knockback_from(hitbox: Hitbox) -> Vector3:
	var offset: Vector3 = global_position - hitbox.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.0 or hitbox.knockback <= 0.0:
		return Vector3.ZERO
	return offset.normalized() * hitbox.knockback


func _set_team(value: StringName) -> void:
	team = value
	collision_layer = Layers.mask([Layers.body_layer_for_team(value)])
	collision_mask = Layers.hurt_mask_for_team(value)
