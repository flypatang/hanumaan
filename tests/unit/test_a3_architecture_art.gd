extends GdUnitTestSuite
## Art-pass acceptance tests for the architecture kit (A3): tall tapering gopuram, gold trim, triangle budget.

const SIZE: Vector3 = Vector3(4.0, 8.0, 4.0)


func _mesh_of(root: Node3D) -> ArrayMesh:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			return (child as MeshInstance3D).mesh as ArrayMesh
	return null


@warning_ignore("integer_division")
func _tri_count(mesh: ArrayMesh) -> int:
	var total: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
			total += (idx as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _has_color(mesh: ArrayMesh, color: Color) -> bool:
	for s: int in range(mesh.get_surface_count()):
		var cols: PackedColorArray = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR] as PackedColorArray
		for c: Color in cols:
			if c.is_equal_approx(color):
				return true
	return false


func _width_at(mesh: ArrayMesh, y_min: float, y_max: float) -> float:
	var wide: float = 0.0
	for s: int in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for v: Vector3 in verts:
			if v.y >= y_min and v.y <= y_max:
				wide = maxf(wide, absf(v.x))
	return wide


func test_gopuram_tapers() -> void:
	var tower: Node3D = auto_free(ArchitectureKit.gopuram(SIZE, 5))
	var mesh: ArrayMesh = _mesh_of(tower)
	var low: float = _width_at(mesh, -4.0, -3.0)
	var high: float = _width_at(mesh, 1.0, 2.0)
	assert_float(low).is_greater(high * 1.4)


func test_gopuram_has_five_to_seven_tiers() -> void:
	for s: int in range(1, 12):
		var tower: Node3D = auto_free(ArchitectureKit.gopuram(SIZE, s))
		var n: int = 0
		for body: Node in tower.find_children("*", "StaticBody3D", true, false):
			n += 1
		assert_int(n).is_between(5, 7)


func test_gopuram_has_gold_and_sindoor_and_height() -> void:
	var tower: Node3D = auto_free(ArchitectureKit.gopuram(SIZE, 3))
	var mesh: ArrayMesh = _mesh_of(tower)
	assert_bool(_has_color(mesh, Palette.GOLD)).is_true()
	assert_bool(_has_color(mesh, Palette.SINDOOR)).is_true()
	assert_float(mesh.get_aabb().size.y).is_equal_approx(SIZE.y, 0.05)


func test_triangle_budget() -> void:
	var props: Array[Node3D] = [
		auto_free(ArchitectureKit.gopuram(Vector3(6, 14, 6), 9)),
		auto_free(ArchitectureKit.tier_house(Vector3(6, 6, 6), 9)),
		auto_free(ArchitectureKit.pillar(Vector3(1, 5, 1), 9)),
		auto_free(ArchitectureKit.stairs(SIZE, 9)),
		auto_free(ArchitectureKit.rooftop(SIZE, 9)),
	]
	for p: Node3D in props:
		assert_int(_tri_count(_mesh_of(p))).is_less(3000)


func test_tier_house_has_gold_and_pillars() -> void:
	var house: Node3D = auto_free(ArchitectureKit.tier_house(SIZE, 4))
	var mesh: ArrayMesh = _mesh_of(house)
	assert_bool(_has_color(mesh, Palette.GOLD)).is_true()
	assert_int(_tri_count(mesh)).is_greater(150)


func test_pillar_has_base_shaft_capital() -> void:
	var p: Node3D = auto_free(ArchitectureKit.pillar(Vector3(1, 5, 1), 2))
	var mesh: ArrayMesh = _mesh_of(p)
	assert_float(mesh.get_aabb().size.y).is_equal_approx(5.0, 0.01)
	assert_bool(_has_color(mesh, Palette.GOLD)).is_true()
	assert_int(_tri_count(mesh)).is_greater(60)
