class_name SimhikaModel
extends RefCounted
## Procedural model of Simhika (DESIGN §4.5, §6, §9 M23): a huge serpentine-lioness form rising from the sea.
## Dark teal and NIGHT_INDIGO body, SINDOOR eyes, MOON-pale fangs. Menacing, never gory (§2).
## Named parts: "Body" (neck coils), "Head", "Jaw" (rotates for the mouth), "EyeL", "EyeR", "Mane".
## Poses: idle, mouth_open, strike, kneel.

const POSES: Array[StringName] = [&"idle", &"mouth_open", &"strike", &"kneel"]
const COIL_COUNT: int = 9
const TEAL: Color = Color("#123F4A")
const JAW_OPEN_ANGLE: float = 0.9


## Builds the model at the origin (sea level), facing -Z. The head rises about 11 m above the water.
static func build() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Simhika"
	var coils: Node3D = Node3D.new()
	coils.name = "Body"
	root.add_child(coils)
	for i: int in range(COIL_COUNT):
		var t: float = float(i) / float(COIL_COUNT - 1)
		var r: float = lerpf(2.2, 1.0, t)
		var col: Color = TEAL.lerp(Palette.NIGHT_INDIGO, 0.35 if i % 2 == 0 else 0.0)
		var pos: Vector3 = Vector3(sin(t * TAU * 0.9) * 2.4 * (1.0 - t * 0.5), 0.6 + t * 8.0, 2.0 - t * 2.5)
		_add(coils, "Coil%d" % i, MeshKit.sphere(r, 5, 8, col), pos)
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 9.6, -0.6)
	root.add_child(head)
	_add(head, "Skull", MeshKit.sphere(1.7, 5, 9, TEAL), Vector3.ZERO)
	_add(head, "Snout", MeshKit.box(Vector3(1.8, 1.1, 2.0), TEAL), Vector3(0.0, -0.35, -1.6))
	_add(head, "Brow", MeshKit.box(Vector3(2.8, 0.5, 1.2), Palette.NIGHT_INDIGO), Vector3(0.0, 0.85, -1.0))
	_add(head, "EyeL", MeshKit.sphere(0.34, 3, 6, Palette.SINDOOR), Vector3(-0.85, 0.5, -1.45))
	_add(head, "EyeR", MeshKit.sphere(0.34, 3, 6, Palette.SINDOOR), Vector3(0.85, 0.5, -1.45))
	_add(head, "EarL", MeshKit.cone(0.6, 1.2, 4, Palette.NIGHT_INDIGO), Vector3(-1.3, 1.6, 0.1))
	_add(head, "EarR", MeshKit.cone(0.6, 1.2, 4, Palette.NIGHT_INDIGO), Vector3(1.3, 1.6, 0.1))
	var mane: Node3D = Node3D.new()
	mane.name = "Mane"
	mane.position = Vector3(0.0, 0.0, 0.7)
	head.add_child(mane)
	for k: int in range(10):
		var a: float = float(k) / 10.0 * TAU
		var spike: MeshInstance3D = _add(mane, "Mane%d" % k, MeshKit.cone(0.55, 2.0, 4, Palette.NIGHT_INDIGO), Vector3(cos(a) * 2.0, sin(a) * 2.0, 0.0))
		spike.rotation = Vector3(0.0, 0.0, a - PI * 0.5)
	for dx: float in [-0.6, 0.6]:
		_add(head, "Fang", MeshKit.cone(0.2, 0.8, 4, Palette.MOON), Vector3(dx, -0.95, -2.2)).rotation.x = PI
	var jaw: Node3D = Node3D.new()
	jaw.name = "Jaw"
	jaw.position = Vector3(0.0, -0.9, -0.4)
	head.add_child(jaw)
	_add(jaw, "JawMesh", MeshKit.box(Vector3(1.6, 0.5, 2.6), Palette.NIGHT_INDIGO), Vector3(0.0, -0.1, -1.3))
	for dx2: float in [-0.5, 0.5]:
		_add(jaw, "LowerFang", MeshKit.cone(0.17, 0.6, 4, Palette.MOON), Vector3(dx2, 0.35, -2.2))
	set_pose(root, &"idle")
	return root


## Applies a named pose. Unknown names fall back to idle.
static func set_pose(root: Node3D, pose: StringName) -> void:
	var head: Node3D = root.find_child("Head", true, false) as Node3D
	var jaw: Node3D = root.find_child("Jaw", true, false) as Node3D
	if head == null or jaw == null:
		return
	match pose:
		&"mouth_open":
			jaw.rotation.x = JAW_OPEN_ANGLE
			head.rotation.x = -0.25
		&"strike":
			jaw.rotation.x = 0.35
			head.rotation.x = 0.45
		&"kneel":
			jaw.rotation.x = 0.0
			head.rotation.x = 0.7
		_:
			jaw.rotation.x = 0.0
			head.rotation.x = 0.0


static func _add(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = MeshKit.flat_material()
	mi.position = pos
	parent.add_child(mi)
	return mi
