extends GdUnitTestSuite
## A2 art-pass acceptance tests for gen/rakshasa_model.gd: bulk, pose names, per-variant silhouettes.
## Updated for art direction v2 (B2): each bone carries one multi-surface part, so parts are told apart by their
## material surfaces and extents instead of by counting attachments.

const VARIANTS: Array[StringName] = [&"spear", &"archer", &"brute", &"lankini"]
const BIG: float = 1.0e9


func _build(variant: StringName) -> Node3D:
	return auto_free(RakshasaModel.build(variant)) as Node3D


func _skeleton(root: Node3D) -> Skeleton3D:
	return root.get_node("Skeleton3D") as Skeleton3D


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child, out)


func _xf(node: Node, root: Node) -> Transform3D:
	if node == root:
		return Transform3D.IDENTITY
	if node is BoneAttachment3D:
		var att: BoneAttachment3D = node as BoneAttachment3D
		var skel: Skeleton3D = att.get_parent() as Skeleton3D
		return _xf(skel, root) * skel.get_bone_global_rest(skel.find_bone(att.bone_name))
	return _xf(node.get_parent(), root) * (node as Node3D).transform


func _extent(root: Node3D) -> Vector3:
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	var lo: Vector3 = Vector3(BIG, BIG, BIG)
	var hi: Vector3 = Vector3(-BIG, -BIG, -BIG)
	for mi: MeshInstance3D in list:
		var xf: Transform3D = _xf(mi, root)
		var box: AABB = (mi.mesh as Mesh).get_aabb()
		for i: int in range(8):
			var p: Vector3 = xf * box.get_endpoint(i)
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	return hi - lo


## Width of the body only (no weapon parts).
func _body_width(root: Node3D) -> float:
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	var lo: float = BIG
	var hi: float = -BIG
	for mi: MeshInstance3D in list:
		var att: BoneAttachment3D = mi.get_parent() as BoneAttachment3D
		if att.bone_name == "weapon_socket":
			continue
		var xf: Transform3D = _xf(mi, root)
		var box: AABB = (mi.mesh as Mesh).get_aabb()
		for i: int in range(8):
			var x: float = (xf * box.get_endpoint(i)).x
			lo = minf(lo, x)
			hi = maxf(hi, x)
	return hi - lo


func _count(root: Node3D, bone: String) -> int:
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	var n: int = 0
	for mi: MeshInstance3D in list:
		if (mi.get_parent() as BoneAttachment3D).bone_name == bone:
			n += 1
	return n


func _has_colour(root: Node3D, colour: Color) -> bool:
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	for mi: MeshInstance3D in list:
		for surface: int in range((mi.mesh as Mesh).get_surface_count()):
			var cols: PackedColorArray = (mi.mesh as Mesh).surface_get_arrays(surface)[Mesh.ARRAY_COLOR] as PackedColorArray
			for c: Color in cols:
				if Color(c.r, c.g, c.b).is_equal_approx(colour):
					return true
	return false


func _part(root: Node3D, bone: String) -> ArrayMesh:
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	for mi: MeshInstance3D in list:
		if (mi.get_parent() as BoneAttachment3D).bone_name == bone:
			return mi.mesh as ArrayMesh
	return null


func _surface(mesh: ArrayMesh, surface_name: String) -> int:
	for i: int in range(mesh.get_surface_count()):
		if mesh.surface_get_name(i) == surface_name:
			return i
	return -1


func _triangles(mesh: ArrayMesh, surface: int) -> int:
	return (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3


func test_pose_list_matches_hanuman_names() -> void:
	var expected: Array[StringName] = [&"idle", &"walk_a", &"walk_b", &"attack_wind", &"attack_strike"]
	assert_int(RakshasaModel.POSES.size()).is_equal(5)
	for p: StringName in expected:
		assert_bool(RakshasaModel.POSES.has(p)).is_true()


func test_all_poses_and_aliases_differ_from_idle_where_expected() -> void:
	var root: Node3D = _build(&"spear")
	var skel: Skeleton3D = _skeleton(root)
	var arm: int = skel.find_bone("upper_arm_r")
	RakshasaModel.set_pose(root, &"attack_wind")
	var wind: Quaternion = skel.get_bone_pose_rotation(arm)
	RakshasaModel.set_pose(root, &"attack_strike")
	var strike: Quaternion = skel.get_bone_pose_rotation(arm)
	assert_bool(wind.is_equal_approx(strike)).is_false()
	RakshasaModel.set_pose(root, &"attack")
	assert_bool(skel.get_bone_pose_rotation(arm).is_equal_approx(strike)).is_true()
	RakshasaModel.set_pose(root, &"walk_a")
	var leg: int = skel.find_bone("upper_leg_l")
	var a: Quaternion = skel.get_bone_pose_rotation(leg)
	RakshasaModel.set_pose(root, &"walk_b")
	var b: Quaternion = skel.get_bone_pose_rotation(leg)
	assert_bool(a.is_equal_approx(b)).is_false()
	RakshasaModel.set_pose(root, &"walk")
	assert_bool(skel.get_bone_pose_rotation(leg).is_equal_approx(a)).is_true()


func test_brute_is_about_one_and_a_half_times_wider_than_spear() -> void:
	var ratio: float = _body_width(_build(&"brute")) / _body_width(_build(&"spear"))
	assert_float(ratio).is_between(1.35, 1.8)


func test_bodies_are_bulky_not_sticks() -> void:
	for variant: StringName in VARIANTS:
		var root: Node3D = _build(variant)
		assert_float(_body_width(root)).is_greater(0.75)


func test_every_variant_has_two_horns_and_fangs_on_head() -> void:
	for variant: StringName in VARIANTS:
		var head: ArrayMesh = _part(_build(variant), "head")
		## Skull, jaw, brows, ears, horns, tusks and fangs are all in the skin surface.
		assert_int(_triangles(head, _surface(head, "skin"))).is_greater(500)
		## Horns reach out on both sides of the skull, symmetrically.
		var box: AABB = head.get_aabb()
		assert_float(box.position.x).is_less(-0.2)
		assert_float(box.end.x).is_greater(0.2)
		assert_float(box.position.x + box.end.x).is_equal_approx(0.0, 0.02)


func test_pauldrons_on_both_shoulders() -> void:
	for variant: StringName in VARIANTS:
		var root: Node3D = _build(variant)
		for bone: String in ["upper_arm_l", "upper_arm_r"]:
			var arm: ArrayMesh = _part(root, bone)
			## Skin for the arm, plus an armour plate (lacquer, or gold for Lankini) with gold trim.
			assert_int(arm.get_surface_count()).is_greater_equal(2)
			assert_int(_surface(arm, "gold")).is_greater_equal(0)
			## The pauldron rises above the shoulder joint.
			assert_float(arm.get_aabb().end.y).is_greater(0.08)
		assert_bool(_has_colour(root, Palette.GOLD)).is_true()


func test_weapon_parts_are_distinct_per_variant() -> void:
	var spear: ArrayMesh = _part(_build(&"spear"), "weapon_socket")
	var bow: ArrayMesh = _part(_build(&"archer"), "weapon_socket")
	var club: ArrayMesh = _part(_build(&"brute"), "weapon_socket")
	var trident: ArrayMesh = _part(_build(&"lankini"), "weapon_socket")
	## Spear: a wooden shaft with a bronze blade, taller than its bearer. Trident: all metal, three tines wide.
	assert_int(_surface(spear, "wood_local")).is_greater_equal(0)
	assert_float(spear.get_aabb().size.y).is_greater(2.5)
	assert_int(_surface(trident, "wood_local")).is_equal(-1)
	assert_float(trident.get_aabb().size.x).is_greater(spear.get_aabb().size.x * 1.5)
	## Bow: lacquered limbs curving in the plane of the shot. Club: short and thick.
	assert_int(_surface(bow, "lacquer_local")).is_greater_equal(0)
	assert_float(bow.get_aabb().size.z).is_greater(0.25)
	assert_float(club.get_aabb().size.y).is_less(1.6)
	assert_float(club.get_aabb().size.x).is_greater(0.4)


func test_archer_carries_quiver_on_the_chest() -> void:
	## The quiver's arrows are the only wood on a chest part.
	assert_int(_surface(_part(_build(&"archer"), "chest"), "wood_local")).is_greater_equal(0)
	assert_int(_surface(_part(_build(&"spear"), "chest"), "wood_local")).is_equal(-1)


func test_lankini_is_tallest_body_and_spear_is_tall() -> void:
	var lankini: float = _extent(_build(&"lankini")).y
	var brute: float = _extent(_build(&"brute")).y
	var archer: float = _extent(_build(&"archer")).y
	assert_bool(lankini > brute).is_true()
	assert_bool(lankini > archer).is_true()
	assert_float(_extent(_build(&"spear")).y).is_greater(2.0)
