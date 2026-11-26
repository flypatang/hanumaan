extends GdUnitTestSuite
## B2 (art direction v2) acceptance tests for gen/chariot_model.gd: a carved gilded chariot with spoked wheels
## and two stylised horses with wind-blown manes, built from the painterly material kinds.

const PARTS: Array[String] = ["Car", "Wheel_L", "Wheel_R", "Pole", "Horse_A", "Horse_B"]


func _build() -> Node3D:
	return auto_free(ChariotModel.build()) as Node3D


func _part(root: Node3D, path: String) -> MeshInstance3D:
	return root.get_node(path) as MeshInstance3D


func _alpha_range(mi: MeshInstance3D) -> Vector2:
	var cols: PackedColorArray = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
	var lo: float = 1.0
	var hi: float = 0.0
	for c: Color in cols:
		lo = minf(lo, c.a)
		hi = maxf(hi, c.a)
	return Vector2(lo, hi)


func test_public_constants_are_unchanged() -> void:
	assert_float(ChariotModel.PLATFORM_TOP).is_equal_approx(0.85, 0.0001)
	assert_float(ChariotModel.WHEEL_RADIUS).is_equal_approx(0.62, 0.0001)
	assert_float(ChariotModel.WHEEL_X).is_equal_approx(0.85, 0.0001)
	assert_float(ChariotModel.HORSE_X).is_equal_approx(0.5, 0.0001)
	assert_float(ChariotModel.HORSE_Z).is_equal_approx(-2.6, 0.0001)


func test_every_part_and_sub_part_has_a_material() -> void:
	var c: Node3D = _build()
	assert_int(c.get_child_count()).is_equal(PARTS.size())
	for part_name: String in PARTS:
		var mi: MeshInstance3D = _part(c, part_name)
		assert_object(mi).is_not_null()
		assert_object(mi.material_override).is_not_null()
		assert_int(mi.get_child_count()).is_greater(0)
		for child: Node in mi.get_children():
			var sub: MeshInstance3D = child as MeshInstance3D
			assert_object(sub).is_not_null()
			assert_object(sub.material_override).is_not_null()
			assert_int(sub.mesh.get_surface_count()).is_equal(1)


func test_car_is_lacquer_with_gold_timber_and_a_pennant() -> void:
	var c: Node3D = _build()
	assert_object(_part(c, "Car").material_override).is_same(Materials.get_material(&"lacquer_local"))
	assert_object(_part(c, "Car/Car_gold").material_override).is_same(Materials.get_material(&"gold"))
	assert_object(_part(c, "Car/Car_wood_local").material_override).is_same(Materials.get_material(&"wood_local"))
	var pennant: MeshInstance3D = _part(c, "Car/Car_cloth")
	assert_object(pennant.material_override).is_same(Materials.get_material(&"cloth"))
	## Pinned at the staff, free at the tip.
	var wind: Vector2 = _alpha_range(pennant)
	assert_float(wind.x).is_equal_approx(0.0, 0.01)
	assert_float(wind.y).is_equal_approx(1.0, 0.01)
	## The standard rises well above the rider's head.
	assert_float(_part(c, "Car/Car_gold").mesh.get_aabb().end.y).is_greater(ChariotModel.PLATFORM_TOP + 2.6)


func test_deck_is_at_platform_top_and_clear_for_the_rider() -> void:
	var c: Node3D = _build()
	var deck: AABB = _part(c, "Car/Car_wood_local").mesh.get_aabb()
	assert_float(deck.size.x).is_greater(1.4)
	## The wall stays outside the rider's spot (0, PLATFORM_TOP, 0.2).
	var verts: PackedVector3Array = _part(c, "Car").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	for v: Vector3 in verts:
		var flat: Vector2 = Vector2(v.x, v.z - 0.2)
		assert_float(flat.length()).is_greater(0.6)
	## The car is open at the back.
	var back_high: int = 0
	for v2: Vector3 in verts:
		if v2.z > 0.6 and absf(v2.x) < 0.5 and v2.y > ChariotModel.PLATFORM_TOP + 0.1:
			back_high += 1
	assert_int(back_high).is_equal(0)


func test_wheels_are_round_spoked_and_fit_the_radius() -> void:
	var c: Node3D = _build()
	assert_int(ChariotModel.WHEEL_SPOKES).is_greater_equal(8)
	for wheel_name: String in ["Wheel_L", "Wheel_R"]:
		var wheel: MeshInstance3D = _part(c, wheel_name)
		assert_float(wheel.position.y).is_equal_approx(ChariotModel.WHEEL_RADIUS, 0.0001)
		assert_float(absf(wheel.position.x)).is_equal_approx(ChariotModel.WHEEL_X, 0.0001)
		var gold: MeshInstance3D = wheel.get_node(wheel_name + "_gold") as MeshInstance3D
		var box: AABB = gold.mesh.get_aabb()
		## The gold tyre runs at the rolling radius, in the YZ plane.
		assert_float(box.size.y * 0.5).is_equal_approx(ChariotModel.WHEEL_RADIUS, 0.03)
		assert_float(box.size.z * 0.5).is_equal_approx(ChariotModel.WHEEL_RADIUS, 0.03)
		assert_float(box.size.x).is_less(0.6)
		## The felloe is a ring: no lacquer near the hub except the hub band.
		var verts: PackedVector3Array = wheel.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for v: Vector3 in verts:
			var r: float = Vector2(v.y, v.z).length()
			assert_bool(r < 0.2 or r > 0.45).is_true()
	## The hub bosses point away from the car.
	assert_float(_part(c, "Wheel_L/Wheel_L_gold").mesh.get_aabb().position.x).is_less(-0.2)
	assert_float(_part(c, "Wheel_R/Wheel_R_gold").mesh.get_aabb().end.x).is_greater(0.2)


func test_wheels_spin_with_their_trim() -> void:
	var c: Node3D = _build()
	ChariotModel.spin_wheels(c, 0.5)
	ChariotModel.spin_wheels(c, 0.25)
	assert_float(_part(c, "Wheel_L").rotation.x).is_equal_approx(0.75, 0.001)
	assert_float(_part(c, "Wheel_R").rotation.x).is_equal_approx(0.75, 0.001)
	## The gold spokes are children, so they turn with the wheel.
	assert_object(_part(c, "Wheel_L/Wheel_L_gold").get_parent()).is_same(_part(c, "Wheel_L"))


func test_horses_stand_ahead_with_manes_tails_and_tack() -> void:
	var c: Node3D = _build()
	for horse_name: String in ["Horse_A", "Horse_B"]:
		var horse: MeshInstance3D = _part(c, horse_name)
		assert_float(horse.position.z).is_equal_approx(ChariotModel.HORSE_Z, 0.0001)
		assert_object(horse.material_override).is_same(Materials.get_material(&"fur"))
		var box: AABB = horse.mesh.get_aabb()
		## A horse: about 1.9 m to the ears, longer than it is wide, standing on the ground.
		assert_float(box.end.y).is_between(1.8, 2.3)
		assert_float(box.size.z).is_greater(box.size.x * 2.5)
		var hair: MeshInstance3D = horse.get_node(horse_name + "_cloth") as MeshInstance3D
		var wind: Vector2 = _alpha_range(hair)
		assert_float(wind.x).is_equal_approx(0.0, 0.01)
		assert_float(wind.y).is_equal_approx(1.0, 0.01)
		## The tail streams out behind the croup.
		assert_float(hair.mesh.get_aabb().end.z).is_greater(box.end.z + 0.3)
		assert_object(horse.get_node(horse_name + "_gold")).is_not_null()
		var eyes: MeshInstance3D = horse.get_node(horse_name + "_glow") as MeshInstance3D
		assert_object(eyes.material_override).is_same(RakshasaModel.glow_material())
		## Hooves reach the ground.
		assert_float((horse.get_node(horse_name + "_gold") as MeshInstance3D).mesh.get_aabb().position.y).is_between(-0.03, 0.05)
	assert_float(_part(c, "Horse_A").position.x).is_equal_approx(-ChariotModel.HORSE_X, 0.0001)
	assert_float(_part(c, "Horse_B").position.x).is_equal_approx(ChariotModel.HORSE_X, 0.0001)


func test_the_two_horses_are_posed_differently() -> void:
	var c: Node3D = _build()
	var a: PackedVector3Array = _part(c, "Horse_A").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var b: PackedVector3Array = _part(c, "Horse_B").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	assert_int(a.size()).is_equal(b.size())
	var differing: int = 0
	for i: int in range(a.size()):
		if not a[i].is_equal_approx(b[i]):
			differing += 1
	assert_int(differing).is_greater(100)


func test_pole_and_yoke_reach_the_horses() -> void:
	var box: AABB = _part(_build(), "Pole").mesh.get_aabb()
	assert_float(box.position.z).is_less(ChariotModel.HORSE_Z + 1.0)
	assert_float(box.end.z).is_greater(-1.0)
	assert_float(box.size.x).is_greater(ChariotModel.HORSE_X * 2.0)


func test_triangle_budget() -> void:
	## Car, two wheels, pole and two horses together.
	assert_int(RakshasaModel.triangle_count(_build())).is_between(5000, 13000)
