class_name ChariotModel
extends RefCounted
## Akshaya Kumara's chariot (DESIGN §9 M26, §6): a gilded two-wheeled chariot drawn by two stylised horses.
## Everything is MeshKit geometry in GOLD and RAKSHASA_ARMOR. The chariot faces -Z (Godot forward), the horses
## stand ahead of the car, and the rider's platform top is at PLATFORM_TOP. build() returns the root Node3D with
## children "Car", "Wheel_L", "Wheel_R", "Pole", "Horse_A" and "Horse_B".

const PLATFORM_TOP: float = 0.85
const WHEEL_RADIUS: float = 0.62
const WHEEL_X: float = 0.85
const HORSE_X: float = 0.5
const HORSE_Z: float = -2.6
const _WHEEL_SPOKES: int = 6


## Builds the chariot with its horses.
static func build() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Chariot"
	_add(root, "Car", _car_mesh(), Vector3.ZERO)
	_add(root, "Wheel_L", _wheel_mesh(), Vector3(-WHEEL_X, WHEEL_RADIUS, 0.0))
	_add(root, "Wheel_R", _wheel_mesh(), Vector3(WHEEL_X, WHEEL_RADIUS, 0.0))
	_add(root, "Pole", _pole_mesh(), Vector3.ZERO)
	_add(root, "Horse_A", _horse_mesh(), Vector3(-HORSE_X, 0.0, HORSE_Z))
	_add(root, "Horse_B", _horse_mesh(), Vector3(HORSE_X, 0.0, HORSE_Z))
	return root


## Spins both wheels by `angle` radians (call with the distance travelled / WHEEL_RADIUS).
static func spin_wheels(root: Node3D, angle: float) -> void:
	for wheel_name: String in ["Wheel_L", "Wheel_R"]:
		var w: Node3D = root.get_node_or_null(wheel_name) as Node3D
		if w != null:
			w.rotation.x += angle


static func _add(root: Node3D, node_name: String, mesh: Mesh, pos: Vector3) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = MeshKit.flat_material()
	mi.position = pos
	root.add_child(mi)


static func _part(mesh: ArrayMesh, xf: Transform3D) -> Dictionary:
	return {"mesh": mesh, "transform": xf}


static func _at(pos: Vector3) -> Transform3D:
	return Transform3D(Basis(), pos)


static func _car_mesh() -> ArrayMesh:
	var gold: Color = Palette.GOLD
	var armor: Color = Palette.RAKSHASA_ARMOR
	var parts: Array[Dictionary] = []
	# Floor, front and side panels in armour red, gilded rails and a standard pole.
	parts.append(_part(MeshKit.box(Vector3(1.5, 0.12, 1.7), gold), _at(Vector3(0.0, PLATFORM_TOP - 0.06, 0.0))))
	parts.append(_part(MeshKit.box(Vector3(1.5, 0.7, 0.1), armor), _at(Vector3(0.0, PLATFORM_TOP + 0.35, -0.8))))
	parts.append(_part(MeshKit.box(Vector3(0.1, 0.55, 1.5), armor), _at(Vector3(-0.7, PLATFORM_TOP + 0.28, 0.0))))
	parts.append(_part(MeshKit.box(Vector3(0.1, 0.55, 1.5), armor), _at(Vector3(0.7, PLATFORM_TOP + 0.28, 0.0))))
	parts.append(_part(MeshKit.box(Vector3(1.6, 0.08, 0.14), gold), _at(Vector3(0.0, PLATFORM_TOP + 0.72, -0.8))))
	parts.append(_part(MeshKit.box(Vector3(0.14, 0.08, 1.6), gold), _at(Vector3(-0.7, PLATFORM_TOP + 0.58, 0.0))))
	parts.append(_part(MeshKit.box(Vector3(0.14, 0.08, 1.6), gold), _at(Vector3(0.7, PLATFORM_TOP + 0.58, 0.0))))
	parts.append(_part(MeshKit.box(Vector3(0.14, 1.9, 0.14), gold), _at(Vector3(0.0, PLATFORM_TOP + 0.95, 0.75))))
	parts.append(_part(MeshKit.cone(0.28, 0.5, 6, Palette.SINDOOR), _at(Vector3(0.0, PLATFORM_TOP + 2.15, 0.75))))
	# Axle between the wheels.
	var axle: Transform3D = Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, WHEEL_RADIUS, 0.0))
	parts.append(_part(MeshKit.cylinder(0.07, 0.07, WHEEL_X * 2.0, 6, gold), axle))
	return MeshKit.merge(parts)


## A wheel in the YZ plane: a gilded rim ring built from segments, a hub and spokes.
static func _wheel_mesh() -> ArrayMesh:
	var gold: Color = Palette.GOLD
	var armor: Color = Palette.RAKSHASA_ARMOR
	var parts: Array[Dictionary] = []
	var tube: float = 0.09
	var seg_len: float = TAU * WHEEL_RADIUS / 12.0 * 1.15
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0
		var basis: Basis = Basis(Vector3.RIGHT, a)
		var pos: Vector3 = Vector3(0.0, -sin(a) * WHEEL_RADIUS, cos(a) * WHEEL_RADIUS)
		parts.append(_part(MeshKit.box(Vector3(0.14, seg_len, tube), gold), Transform3D(basis, pos)))
	for i: int in _WHEEL_SPOKES:
		var a: float = TAU * float(i) / float(_WHEEL_SPOKES)
		var basis: Basis = Basis(Vector3.RIGHT, a)
		parts.append(_part(MeshKit.box(Vector3(0.08, WHEEL_RADIUS * 2.0 - 0.1, 0.07), armor), Transform3D(basis, Vector3.ZERO)))
	var hub: Transform3D = Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3.ZERO)
	parts.append(_part(MeshKit.cylinder(0.14, 0.14, 0.2, 8, gold), hub))
	return MeshKit.merge(parts)


static func _pole_mesh() -> ArrayMesh:
	var parts: Array[Dictionary] = []
	var pole: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.7, HORSE_Z * 0.5 - 0.3))
	parts.append(_part(MeshKit.cylinder(0.06, 0.06, absf(HORSE_Z) + 0.6, 6, Palette.GOLD), pole))
	parts.append(_part(MeshKit.box(Vector3(2.0, 0.1, 0.1), Palette.GOLD), _at(Vector3(0.0, 1.05, HORSE_Z + 0.5))))
	return MeshKit.merge(parts)


## A stylised horse facing -Z, origin on the ground under its body.
static func _horse_mesh() -> ArrayMesh:
	var coat: Color = Palette.RAKSHASA_ARMOR
	var gold: Color = Palette.GOLD
	var parts: Array[Dictionary] = []
	var lying: Basis = Basis(Vector3.RIGHT, deg_to_rad(90.0))
	parts.append(_part(MeshKit.capsule(0.3, 1.5, coat), Transform3D(lying, Vector3(0.0, 1.05, 0.0))))
	# Neck rising forward, head and snout.
	var neck: Basis = Basis(Vector3.RIGHT, deg_to_rad(-35.0))
	parts.append(_part(MeshKit.capsule(0.17, 0.8, coat), Transform3D(neck, Vector3(0.0, 1.5, -0.8))))
	var head: Basis = Basis(Vector3.RIGHT, deg_to_rad(80.0))
	parts.append(_part(MeshKit.capsule(0.13, 0.55, coat), Transform3D(head, Vector3(0.0, 1.8, -1.2))))
	parts.append(_part(MeshKit.cone(0.05, 0.16, 4, coat), _at(Vector3(-0.07, 2.02, -1.0))))
	parts.append(_part(MeshKit.cone(0.05, 0.16, 4, coat), _at(Vector3(0.07, 2.02, -1.0))))
	# Gold mane, tail and harness.
	parts.append(_part(MeshKit.box(Vector3(0.06, 0.5, 0.2), gold), Transform3D(neck, Vector3(0.0, 1.78, -0.62))))
	parts.append(_part(MeshKit.box(Vector3(0.1, 0.1, 0.5), gold), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-40.0)), Vector3(0.0, 1.0, 0.95))))
	parts.append(_part(MeshKit.box(Vector3(0.7, 0.08, 0.1), gold), _at(Vector3(0.0, 1.0, -0.45))))
	# Four legs.
	for lx: float in [-0.17, 0.17]:
		for lz: float in [-0.55, 0.55]:
			parts.append(_part(MeshKit.cylinder(0.07, 0.05, 0.85, 5, coat), _at(Vector3(lx, 0.42, lz))))
			parts.append(_part(MeshKit.cylinder(0.08, 0.08, 0.08, 5, gold), _at(Vector3(lx, 0.04, lz))))
	return MeshKit.merge(parts)
