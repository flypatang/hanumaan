extends GdUnitTestSuite
## A6 acceptance tests: Sita has a subtle face (no beak), Rama is crowned in gold and carries bow and quiver.


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


func _all_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_all_meshes(child, out)


func test_sita_has_no_protruding_nose() -> void:
	var sita: Node3D = auto_free(NpcModels.build(&"sita")) as Node3D
	var meshes: Array[MeshInstance3D] = []
	_all_meshes(sita, meshes)
	# Nothing may stick out in front of the face (z < -0.125) at head height.
	for mi: MeshInstance3D in meshes:
		var box: AABB = (mi.mesh as Mesh).get_aabb()
		for i: int in 8:
			var p: Vector3 = mi.transform * box.get_endpoint(i)
			if p.y > 0.72 and p.y < 0.85:
				assert_float(p.z).is_greater(-0.128)


func test_sita_has_sindoor_bindi_and_small_dark_eyes() -> void:
	var sita: Node3D = auto_free(NpcModels.build(&"sita")) as Node3D
	var bindi: Array[MeshInstance3D] = _parts(sita, "Sita_Bindi")
	assert_int(bindi.size()).is_equal(1)
	assert_bool(_colors_of(bindi[0])[0].is_equal_approx(Palette.SINDOOR)).is_true()
	var eyes: Array[MeshInstance3D] = _parts(sita, "Sita_Eye")
	assert_int(eyes.size()).is_equal(2)
	for e: MeshInstance3D in eyes:
		assert_float((e.mesh as Mesh).get_aabb().size.x).is_less(0.03)


func test_sita_stays_seated() -> void:
	var sita: Node3D = auto_free(NpcModels.build(&"sita")) as Node3D
	var meshes: Array[MeshInstance3D] = []
	_all_meshes(sita, meshes)
	var top: float = 0.0
	for mi: MeshInstance3D in meshes:
		var box: AABB = (mi.mesh as Mesh).get_aabb()
		for i: int in 8:
			top = maxf(top, (mi.transform * box.get_endpoint(i)).y)
	assert_float(top).is_less(1.0)


func test_rama_crown_is_gold_and_tall() -> void:
	var rama: Node3D = auto_free(NpcModels.build(&"rama")) as Node3D
	var crown: Array[MeshInstance3D] = _parts(rama, "Rama_Crown")
	assert_bool(crown.size() >= 3).is_true()
	var top: float = 0.0
	for mi: MeshInstance3D in crown:
		assert_bool(_colors_of(mi)[0].is_equal_approx(Palette.GOLD)).is_true()
		var box: AABB = (mi.mesh as Mesh).get_aabb()
		for i: int in 8:
			top = maxf(top, (mi.transform * box.get_endpoint(i)).y)
	# Head top is about 1.82 (0.91 * 2.0); the crown must rise clearly above it.
	assert_float(top).is_greater(2.0)


func test_rama_bow_is_tall_and_in_left_hand() -> void:
	var rama: Node3D = auto_free(NpcModels.build(&"rama")) as Node3D
	var meshes: Array[MeshInstance3D] = []
	_all_meshes(rama, meshes)
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	var count: int = 0
	for mi: MeshInstance3D in meshes:
		if mi.mesh.get_aabb().size.x < 0.05 and mi.position.x < -0.3 and mi.position.x > -0.5:
			var cs: Array[Color] = _colors_of(mi)
			if cs[0].is_equal_approx(NpcModels.GOLD_DARK):
				count += 1
				lo = minf(lo, mi.position.y)
				hi = maxf(hi, mi.position.y)
	assert_bool(count >= 5).is_true()
	assert_float(hi - lo).is_greater(0.7)


func test_rama_has_quiver_on_back() -> void:
	var rama: Node3D = auto_free(NpcModels.build(&"rama")) as Node3D
	var q: Array[MeshInstance3D] = _parts(rama, "Rama_Quiver")
	assert_int(q.size()).is_equal(1)
	assert_float(q[0].position.z).is_greater(0.1)
