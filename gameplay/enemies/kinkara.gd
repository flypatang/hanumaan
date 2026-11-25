class_name Kinkara
extends EnemyBase
## Kinkara brute (DESIGN §4.5, §9 M22). Slow, and it ground-slams with an area attack. The slam is a SLAM_RADIUS
## disc around itself: the telegraph and the hit volume share that radius. It staggers only from heavy hits.

## Radius of the ground slam, in metres (telegraph and hit volume).
const SLAM_RADIUS: float = 3.0


func _init() -> void:
	enemy_id = &"kinkara"


func _ready() -> void:
	super()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = SLAM_RADIUS
	disc.bottom_radius = SLAM_RADIUS
	disc.height = 0.02
	telegraph.mesh = disc
	var shape: CollisionShape3D = hitbox.get_child(0) as CollisionShape3D
	if shape != null:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = SLAM_RADIUS
		shape.shape = sphere
		shape.position = Vector3(0.0, 0.5, 0.0)


func _stagger_on_hit(heavy: bool) -> bool:
	return heavy
