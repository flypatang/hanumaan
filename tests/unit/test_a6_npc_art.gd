extends GdUnitTestSuite
## A6 acceptance tests: Sita has a subtle face (no beak), Rama is crowned in gold and carries bow and quiver.
## Updated for B3 (art v2): parts are sculpted multi-surface meshes that may sit under pivot nodes, so the checks
## walk real vertices in root space instead of AABB corners of direct children.


func _find_prefix(node: Node, prefix: String, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.name.begins_with(prefix):
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_find_prefix(child, prefix, out)


func _parts(root: Node3D, prefix: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_find_prefix(root, prefix, out)
	return out


func _colors_of(mi: MeshInstance3D) -> Array[Color]:
	var out: Array[Color] = []
	var m: Mesh = mi.mesh
	for s: int in m.get_surface_count():
		var cs: PackedColorArray = m.surface_get_arrays(s)[Mesh.ARRAY_COLOR] as PackedColorArray
		for c: Color in cs:
			out.append(c)
	return out


func _near(a: Color, b: Color) -> bool:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) < 0.006


func _all_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_all_meshes(child, out)


func _xf(node: Node, root: Node) -> Transform3D:
	if node == root:
		return Transform3D.IDENTITY
	return _xf(node.get_parent(), root) * (node as Node3D).transform


## Every vertex of a mesh instance, in the root's space.
func _verts(mi: MeshInstance3D, root: Node3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var xf: Transform3D = _xf(mi, root)
	var m: Mesh = mi.mesh
	for s: int in m.get_surface_count():
		for v: Vector3 in m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			out.append(xf * v)
	return out


func _is_aura(mi: MeshInstance3D) -> bool:
	return String(mi.name).ends_with("Aura")


func test_sita_has_no_protruding_nose() -> void:
	var sita: Node3D = auto_free(NpcModels.build(&"sita")) as Node3D
	var meshes: Array[MeshInstance3D] = []
	_all_meshes(sita, meshes)
	# Nothing may stick out in front of the face (z < -0.128) at head height: the nose stays delicate.
	var lowest: float = 0.0
	for mi: MeshInstance3D in meshes:
		if _is_aura(mi):
			continue
		for p: Vector3 in _verts(mi, sita):
			if p.y > 0.72 and p.y < 0.85:
				lowest = minf(lowest, p.z)
	assert_float(lowest).is_greater(-0.128)


func test_sita_has_sindoor_bindi_and_small_dark_eyes() -> void:
	var sita: Node3D = auto_free(NpcModels.build(&"sita")) as Node3D
	var bindi: Array[MeshInstance3D] = _parts(sita, "Sita_Bindi")
	assert_int(bindi.size()).is_equal(1)
	assert_bool(_near(_colors_of(bindi[0])[0], Palette.SINDOOR)).is_true()
	var eyes: Array[MeshInstance3D] = _parts(sita, "Sita_Eye")
	assert_int(eyes.size()).is_equal(2)
	for e: MeshInstance3D in eyes:
		assert_float((e.mesh as Mesh).get_aabb().size.x).is_less(0.03)
		var c: Color = _colors_of(e)[0]
		assert_float(c.r + c.g + c.b).is_less(0.6)


func test_sita_stays_seated() -> void:
	var sita: Node3D = auto_free(NpcModels.build(&"sita")) as Node3D
	var meshes: Array[MeshInstance3D] = []
	_all_meshes(sita, meshes)
	var top: float = 0.0
	for mi: MeshInstance3D in meshes:
		if _is_aura(mi):
			continue
		for p: Vector3 in _verts(mi, sita):
			top = maxf(top, p.y)
	assert_float(top).is_less(1.0)


func test_rama_crown_is_gold_and_tall() -> void:
	var rama: Node3D = auto_free(NpcModels.build(&"rama")) as Node3D
	var crown: Array[MeshInstance3D] = _parts(rama, "Rama_Crown")
	assert_bool(crown.size() >= 3).is_true()
	var top: float = 0.0
	for mi: MeshInstance3D in crown:
		# Each part is on the gold material and carries the palette's GOLD.
		assert_str((mi.mesh as ArrayMesh).surface_get_name(0)).is_equal("gold")
		var golden: bool = false
		for c: Color in _colors_of(mi):
			if _near(c, Palette.GOLD):
				golden = true
				break
		assert_bool(golden).is_true()
		for p: Vector3 in _verts(mi, rama):
			top = maxf(top, p.y)
	# Head top is about 1.9; the crown must rise clearly above it.
	assert_float(top).is_greater(2.0)


func test_rama_bow_is_tall_and_in_left_hand() -> void:
	var rama: Node3D = auto_free(NpcModels.build(&"rama")) as Node3D
	var bow: Array[MeshInstance3D] = _parts(rama, "Rama_Bow")
	assert_int(bow.size()).is_equal(1)
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	var x_sum: float = 0.0
	var pts: PackedVector3Array = _verts(bow[0], rama)
	for p: Vector3 in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
		x_sum += p.x
	# Taller than 0.7 of his height, and on his left (-X when facing -Z).
	assert_float(hi - lo).is_greater(1.4)
	assert_float(x_sum / float(pts.size())).is_less(-0.25)
	var gilded: bool = false
	for c: Color in _colors_of(bow[0]):
		if _near(c, NpcModels.GOLD_DARK):
			gilded = true
			break
	assert_bool(gilded).is_true()


func test_rama_has_quiver_on_back() -> void:
	var rama: Node3D = auto_free(NpcModels.build(&"rama")) as Node3D
	var q: Array[MeshInstance3D] = _parts(rama, "Rama_Quiver")
	assert_int(q.size()).is_equal(1)
	var z_sum: float = 0.0
	var pts: PackedVector3Array = _verts(q[0], rama)
	for p: Vector3 in pts:
		z_sum += p.z
	assert_float(z_sum / float(pts.size())).is_greater(0.1)
