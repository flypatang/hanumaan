extends GdUnitTestSuite
## B6 acceptance: painted terrain from world/level_builder.gd (docs/ART.md "Geometry": "ground tiles get gentle
## height noise and blended edges between tile types. No visible grid", bevelled architecture with cornices).
## Everything here is visual only: colliders stay flat boxes and the navmesh stays one flat quad per walkable tile.

const UP: Vector3 = Vector3(0.0, 1.0, 0.0)
const TOP_DOT: float = 0.9


func _level(tiles: Array, level_id: String = "b6_level") -> Dictionary:
	return {"id": level_id, "nav": true, "tiles": tiles, "props": [], "spawns": [], "triggers": [], "shrines": []}


func _tile(x: int, z: int, tile_type: String, step: int = 0) -> Dictionary:
	return {"x": x, "z": z, "type": tile_type, "step": step}


func _field(width: int, depth: int, tile_type: String, step: int = 0) -> Array:
	var tiles: Array = []
	for x: int in range(width):
		for z: int in range(depth):
			tiles.append(_tile(x, z, tile_type, step))
	return tiles


func _build(tiles: Array, level_id: String = "b6_level") -> Node3D:
	var root: Node3D = LevelBuilder.build(_level(tiles, level_id))
	auto_free(root)
	return root


func _type_mesh(root: Node3D, tile_type: String) -> MeshInstance3D:
	return root.get_node_or_null("Tiles/Tiles_" + tile_type) as MeshInstance3D


func _verts(mesh_node: MeshInstance3D) -> PackedVector3Array:
	return mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array


func _normals(mesh_node: MeshInstance3D) -> PackedVector3Array:
	return mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] as PackedVector3Array


func _colours(mesh_node: MeshInstance3D) -> PackedColorArray:
	return mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray


func _key(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))


func _colour_gap(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func test_walkable_ground_has_gentle_height_noise() -> void:
	for tile_type: String in ["grass", "ground", "sand"]:
		var root: Node3D = _build(_field(6, 6, tile_type, 2))
		var low: float = 1000.0
		var high: float = -1000.0
		for v: Vector3 in _verts(_type_mesh(root, tile_type)):
			if v.x > 1.0 and v.x < 11.0 and v.z > 1.0 and v.z < 11.0:
				low = minf(low, v.y)
				high = maxf(high, v.y)
		# Uneven, but never more than HEIGHT_AMPLITUDE from the flat collider top at y = 1.0.
		assert_bool(high - low > 0.02).is_true()
		assert_bool(low >= 1.0 - LevelBuilder.HEIGHT_AMPLITUDE - 0.001).is_true()
		assert_bool(high <= 1.0 + LevelBuilder.HEIGHT_AMPLITUDE + 0.001).is_true()
	assert_bool(LevelBuilder.HEIGHT_AMPLITUDE <= 0.1).is_true()


func test_ground_is_smooth_and_seamless_across_tiles() -> void:
	# Tiles share their edge vertices exactly: same height, same normal, same colour. So no crack and no grid line.
	var root: Node3D = _build(_field(4, 4, "grass"))
	var mesh_node: MeshInstance3D = _type_mesh(root, "grass")
	var verts: PackedVector3Array = _verts(mesh_node)
	var norms: PackedVector3Array = _normals(mesh_node)
	var cols: PackedColorArray = _colours(mesh_node)
	var heights: Dictionary = {}
	var first: Dictionary = {}
	var shared: int = 0
	var tilted: int = 0
	for i: int in range(verts.size()):
		var flat_key: Vector2i = Vector2i(roundi(verts[i].x * 1000.0), roundi(verts[i].z * 1000.0))
		if heights.has(flat_key):
			shared += 1
			var j: int = first[flat_key] as int
			assert_float(verts[i].y).is_equal_approx(heights[flat_key] as float, 0.0001)
			assert_bool(norms[i].is_equal_approx(norms[j])).is_true()
			assert_bool(_colour_gap(cols[i], cols[j]) < 0.002).is_true()
		else:
			heights[flat_key] = verts[i].y
			first[flat_key] = i
		if norms[i].dot(UP) < 0.9999:
			tilted += 1
	assert_int(shared).is_greater(0)
	# Smooth normals follow the noise instead of all pointing straight up.
	assert_int(tilted).is_greater(0)


func test_height_noise_fades_out_at_walls_drops_and_paving() -> void:
	# A strip of grass with a wall on the west, paving on the east and a drop to the south.
	var tiles: Array = []
	for z: int in range(4):
		tiles.append(_tile(0, z, "wall", 2))
		tiles.append(_tile(1, z, "grass", 2))
		tiles.append(_tile(2, z, "grass", 2))
		tiles.append(_tile(3, z, "stone_floor", 2))
	for x: int in range(4):
		tiles.append(_tile(x, 4, "grass", 0))
	var root: Node3D = _build(tiles)
	var mesh_node: MeshInstance3D = _type_mesh(root, "grass")
	var verts: PackedVector3Array = _verts(mesh_node)
	var norms: PackedVector3Array = _normals(mesh_node)
	var checked: int = 0
	for i: int in range(verts.size()):
		var v: Vector3 = verts[i]
		# Only the tops of the raised strip (the lower row of grass also touches z = 8).
		if norms[i].dot(UP) < TOP_DOT or v.y < 0.5:
			continue
		if is_equal_approx(v.x, 2.0) or is_equal_approx(v.x, 6.0) or is_equal_approx(v.z, 8.0):
			checked += 1
			assert_float(v.y).is_equal_approx(1.0, 0.0001)
	assert_int(checked).is_greater(0)


func test_no_per_tile_colour_steps() -> void:
	# The old look jittered each tile's colour, which drew the grid. Colours now come from a continuous field:
	# neighbouring vertices (0.5 m apart) never differ by much, on a tile edge or off it.
	var root: Node3D = _build(_field(6, 6, "grass"))
	var mesh_node: MeshInstance3D = _type_mesh(root, "grass")
	var verts: PackedVector3Array = _verts(mesh_node)
	var cols: PackedColorArray = _colours(mesh_node)
	var worst: float = 0.0
	var i: int = 0
	while i + 2 < verts.size():
		worst = maxf(worst, _colour_gap(cols[i], cols[i + 1]))
		worst = maxf(worst, _colour_gap(cols[i + 1], cols[i + 2]))
		worst = maxf(worst, _colour_gap(cols[i], cols[i + 2]))
		i += 3
	assert_bool(worst < 0.12).is_true()


func test_grass_colour_varies_in_hue_not_only_in_value() -> void:
	var root: Node3D = _build(_field(12, 12, "grass"))
	var low: float = 10.0
	var high: float = -10.0
	for c: Color in _colours(_type_mesh(root, "grass")):
		var warmth: float = c.r / maxf(c.g, 0.001)
		low = minf(low, warmth)
		high = maxf(high, warmth)
	# Sunlit yellow-green patches and deep cool ones: the red to green ratio moves, so it is not one flat green.
	assert_bool(high - low > 0.1).is_true()


func test_borders_between_tile_types_are_blended() -> void:
	# Grass on the west (x < 6), sand on the east. Along the border both meshes carry the same mixed colour, and
	# the pure colours are only reached further in.
	var tiles: Array = []
	for z: int in range(6):
		for x: int in range(6):
			tiles.append(_tile(x, z, "grass" if x < 3 else "sand"))
	var root: Node3D = _build(tiles)
	var grass: MeshInstance3D = _type_mesh(root, "grass")
	var sand: MeshInstance3D = _type_mesh(root, "sand")
	var grass_edge: Dictionary = {}
	var grass_verts: PackedVector3Array = _verts(grass)
	var grass_cols: PackedColorArray = _colours(grass)
	for i: int in range(grass_verts.size()):
		if is_equal_approx(grass_verts[i].x, 6.0):
			grass_edge[_key(grass_verts[i])] = grass_cols[i]
	assert_int(grass_edge.size()).is_greater(0)
	var sand_verts: PackedVector3Array = _verts(sand)
	var sand_cols: PackedColorArray = _colours(sand)
	var matched: int = 0
	var mixed: int = 0
	for i: int in range(sand_verts.size()):
		if not is_equal_approx(sand_verts[i].x, 6.0):
			continue
		var key: Vector3i = _key(sand_verts[i])
		assert_bool(grass_edge.has(key)).is_true()
		var on_grass: Color = grass_edge[key] as Color
		matched += 1
		# No seam: the two meshes agree on the border.
		assert_bool(_colour_gap(on_grass, sand_cols[i]) < 0.002).is_true()
		# Sand is far redder than grass; a mixed colour sits between them.
		var redness: float = sand_cols[i].r - sand_cols[i].g
		if redness > -0.2 and redness < 0.08:
			mixed += 1
	assert_int(matched).is_greater(0)
	assert_bool(float(mixed) > float(matched) * 0.5).is_true()
	# Far from the border the grass is plain grass: green well above red.
	for i: int in range(grass_verts.size()):
		if grass_verts[i].x < 3.0:
			assert_bool(grass_cols[i].g > grass_cols[i].r * 1.2).is_true()
	for i: int in range(sand_verts.size()):
		if sand_verts[i].x > 9.0:
			assert_bool(sand_cols[i].r > sand_cols[i].g).is_true()


func test_tiles_use_the_painterly_material() -> void:
	var tiles: Array = [
		_tile(0, 0, "ground"), _tile(1, 0, "grass"), _tile(2, 0, "sand"), _tile(0, 1, "stone_floor"),
		_tile(1, 1, "wall"), _tile(2, 1, "water"),
	]
	var root: Node3D = _build(tiles)
	for tile_type: String in LevelBuilder.TILE_TYPES:
		var mesh_node: MeshInstance3D = _type_mesh(root, tile_type)
		assert_object(mesh_node).is_not_null()
		assert_int(mesh_node.mesh.get_surface_count()).is_equal(1)
		assert_object(mesh_node.material_override).is_null()
		# One shared material for every type, so the blended borders have no material seam.
		assert_object(mesh_node.mesh.surface_get_material(0)).is_same(Materials.get_material(LevelBuilder.TILE_MATERIAL))
		assert_bool(mesh_node.mesh.surface_get_material(0) != MeshKit.flat_material()).is_true()


func test_stone_floor_is_laid_with_bevelled_slabs() -> void:
	var root: Node3D = _build(_field(4, 4, "stone_floor", 2))
	var mesh_node: MeshInstance3D = _type_mesh(root, "stone_floor")
	var verts: PackedVector3Array = _verts(mesh_node)
	var norms: PackedVector3Array = _normals(mesh_node)
	var joint_y: float = 1.0 - LevelBuilder.JOINT_DEPTH
	var flat: int = 0
	var bevel: int = 0
	var joints: int = 0
	var through_border: int = 0
	for i: int in range(verts.size()):
		var v: Vector3 = verts[i]
		# Only the tops: skip the faces, the plinth's ledge and the cornice that overhangs the field's footprint.
		if norms[i].dot(UP) < 0.5 or v.y < 0.9 or v.x < 0.0 or v.x > 8.0 or v.z < 0.0 or v.z > 8.0:
			continue
		# Paving is walked on, so it stays flat: slab faces at the tile height, joints a hair below.
		assert_bool(is_equal_approx(v.y, 1.0) or is_equal_approx(v.y, joint_y)).is_true()
		if norms[i].dot(UP) > 0.9999:
			flat += 1
		else:
			bevel += 1
		if is_equal_approx(v.y, joint_y):
			joints += 1
		# Slabs run across tile borders (x = 4 is one), so the paving does not redraw the tile grid.
		if is_equal_approx(v.x, 4.0) and is_equal_approx(v.y, 1.0) and v.z > 0.1 and v.z < 7.9:
			through_border += 1
	assert_int(flat).is_greater(0)
	assert_int(bevel).is_greater(0)
	assert_int(joints).is_greater(0)
	assert_int(through_border).is_greater(0)


func test_paving_slabs_differ_in_tone() -> void:
	var root: Node3D = _build(_field(4, 4, "stone_floor"))
	var tones: Dictionary = {}
	for c: Color in _colours(_type_mesh(root, "stone_floor")):
		tones[snappedf(c.v, 0.01)] = true
	assert_int(tones.size()).is_greater(4)


func test_walls_are_bevelled_stone_with_a_cornice_and_a_plinth() -> void:
	# One wall block, tile (1, 1): footprint x and z in 2..4, roof at y = 2.
	var root: Node3D = _build([_tile(1, 1, "wall")])
	var mesh_node: MeshInstance3D = _type_mesh(root, "wall")
	var verts: PackedVector3Array = _verts(mesh_node)
	var norms: PackedVector3Array = _normals(mesh_node)
	var cornice_reach: float = 0.0
	var plinth_reach: float = 0.0
	var shaft_reach: float = 0.0
	var recessed: int = 0
	var bevelled: int = 0
	for i: int in range(verts.size()):
		var v: Vector3 = verts[i]
		var reach: float = maxf(maxf(2.0 - v.x, v.x - 4.0), maxf(2.0 - v.z, v.z - 4.0))
		if v.y > 1.5:
			cornice_reach = maxf(cornice_reach, reach)
		elif v.y < 0.3:
			plinth_reach = maxf(plinth_reach, reach)
		elif v.y > 0.6 and v.y < 1.4:
			shaft_reach = maxf(shaft_reach, reach)
			if reach < -0.001 and v.x > 1.9 and v.x < 4.1 and v.z > 1.9 and v.z < 4.1:
				recessed += 1
		var n: Vector3 = norms[i]
		var axis: float = maxf(absf(n.x), maxf(absf(n.y), absf(n.z)))
		if axis < 0.98:
			bevelled += 1
	# The cornice overhangs the face, the plinth stands proud of it, and the shaft between them does not.
	assert_float(cornice_reach).is_equal_approx(LevelBuilder.CORNICE_OVERHANG, 0.001)
	assert_bool(plinth_reach > 0.05 and plinth_reach < cornice_reach).is_true()
	assert_float(shaft_reach).is_equal_approx(0.0, 0.001)
	# Block joints are cut into the face, and bevels and mouldings give slanted normals.
	assert_int(recessed).is_greater(0)
	assert_int(bevelled).is_greater(20)
	# Visual only: the collider is still the plain block.
	var shape_node: CollisionShape3D = root.get_node("Tiles/Floor/Tile_1_1") as CollisionShape3D
	assert_vector((shape_node.shape as BoxShape3D).size).is_equal_approx(Vector3(2.0, 2.0, 2.0), Vector3.ONE * 0.001)


func test_cornice_is_mitred_round_outward_corners_only() -> void:
	# Two wall blocks in a row along x (tiles (1,1) and (2,1)): the cornice turns the four outer corners but
	# runs straight through the joint between the blocks at x = 4.
	var root: Node3D = _build([_tile(1, 1, "wall"), _tile(2, 1, "wall")])
	var verts: PackedVector3Array = _verts(_type_mesh(root, "wall"))
	var out: float = LevelBuilder.CORNICE_OVERHANG
	var corner: bool = false
	for v: Vector3 in verts:
		if is_equal_approx(v.x, 2.0 - out) and is_equal_approx(v.z, 2.0 - out):
			corner = true
		# Along the run, the widest the moulding gets is the overhang; nothing pokes past the mitre.
		assert_bool(v.x >= 2.0 - out - 0.001 and v.x <= 6.0 + out + 0.001).is_true()
		assert_bool(v.z >= 2.0 - out - 0.001 and v.z <= 4.0 + out + 0.001).is_true()
	assert_bool(corner).is_true()


func test_raised_stone_floor_gets_built_faces_and_natural_ground_a_cliff() -> void:
	var root: Node3D = _build([_tile(0, 0, "stone_floor", 3), _tile(2, 0, "grass", 3)])
	# Built face: flat ashlar, so plenty of exactly axis-aligned side normals.
	var stone_norms: PackedVector3Array = _normals(_type_mesh(root, "stone_floor"))
	var stone_flat: int = 0
	for n: Vector3 in stone_norms:
		if absf(n.y) < 0.001 and maxf(absf(n.x), absf(n.z)) > 0.9999:
			stone_flat += 1
	assert_int(stone_flat).is_greater(0)
	# Cliff: an uneven rock face that bulges out of the tile's footprint below the lip.
	var bulge: float = 0.0
	for v: Vector3 in _verts(_type_mesh(root, "grass")):
		bulge = maxf(bulge, maxf(maxf(4.0 - v.x, v.x - 6.0), maxf(0.0 - v.z, v.z - 2.0)))
	assert_bool(bulge > 0.03 and bulge < 0.3).is_true()


func test_water_tiles_get_a_waterkit_surface_over_a_sloping_bed() -> void:
	# A 5 x 5 pond ringed by sand, in the middle of a larger sand field (so it does not touch the level's edge).
	var tiles: Array = []
	for x: int in range(9):
		for z: int in range(9):
			var pond: bool = x >= 2 and x <= 6 and z >= 2 and z <= 6
			tiles.append(_tile(x, z, "water" if pond else "sand", 2))
	var root: Node3D = _build(tiles)
	var water: MeshInstance3D = root.get_node_or_null("Tiles/Water_2") as MeshInstance3D
	assert_object(water).is_not_null()
	var material: ShaderMaterial = water.material_override as ShaderMaterial
	assert_object(material).is_not_null()
	assert_bool(material.shader == WaterKit.shader(true) or material.shader == WaterKit.shader(false)).is_true()
	# The surface lies just below the tile height (y = 1.0) and covers exactly the pond.
	assert_float(water.position.y).is_equal_approx(1.0 - LevelBuilder.WATER_DROP, 0.001)
	assert_float(water.position.x).is_equal_approx(9.0, 0.001)
	assert_float(water.position.z).is_equal_approx(9.0, 0.001)
	assert_vector((water.mesh as PlaneMesh).size).is_equal_approx(Vector2(10.0, 10.0), Vector2.ONE * 0.001)
	# Waves never reach the height of the land next to them.
	assert_bool(WaterKit.max_wave_height(LevelBuilder.WATER_WAVE_SCALE) < LevelBuilder.WATER_DROP - LevelBuilder.HEIGHT_AMPLITUDE).is_true()
	# The bed meets the shore at the tile height and sinks below the surface toward the middle.
	var shore_checked: int = 0
	var deepest: float = 1000.0
	for v: Vector3 in _verts(_type_mesh(root, "water")):
		if v.x < 3.9 or v.x > 14.1 or v.z < 3.9 or v.z > 14.1:
			continue
		# (The dark sheet under the whole surface lies below every bed; it is not part of the shore.)
		if v.y < 1.0 - LevelBuilder.WATER_DEPTH - LevelBuilder.HEIGHT_AMPLITUDE - 0.01:
			continue
		deepest = minf(deepest, v.y)
		if is_equal_approx(v.x, 4.0) or is_equal_approx(v.x, 14.0) or is_equal_approx(v.z, 4.0) or is_equal_approx(v.z, 14.0):
			shore_checked += 1
			assert_float(v.y).is_equal_approx(1.0, LevelBuilder.HEIGHT_AMPLITUDE + 0.001)
	assert_int(shore_checked).is_greater(0)
	assert_bool(deepest < 1.0 - LevelBuilder.WATER_DROP - 0.3).is_true()
	# Water stays solid to bodies at its tile height, as levels/SCHEMA.md says.
	var shape_node: CollisionShape3D = root.get_node("Tiles/Floor/Tile_4_4") as CollisionShape3D
	assert_float(shape_node.position.y + (shape_node.shape as BoxShape3D).size.y * 0.5).is_equal_approx(1.0, 0.001)


func test_sea_at_the_level_edge_runs_on_past_it() -> void:
	var tiles: Array = []
	for x: int in range(4):
		tiles.append(_tile(x, 0, "water"))
		tiles.append(_tile(x, 1, "sand"))
	var root: Node3D = _build(tiles)
	var water: MeshInstance3D = root.get_node_or_null("Tiles/Water_0") as MeshInstance3D
	assert_object(water).is_not_null()
	var size: Vector2 = (water.mesh as PlaneMesh).size
	assert_bool(size.x > 8.0 + LevelBuilder.WATER_OVERRUN).is_true()
	assert_bool(size.y > 2.0 + LevelBuilder.WATER_OVERRUN * 0.9).is_true()
	# It runs out to sea (toward -z), not inland.
	assert_float(water.position.z + size.y * 0.5).is_equal_approx(2.0, 0.001)


func test_levels_without_water_have_no_water_surface() -> void:
	var root: Node3D = _build(_field(2, 2, "grass"))
	for child: Node in root.get_node("Tiles").get_children():
		assert_bool(str(child.name).begins_with("Water_")).is_false()


func test_water_takes_the_mood_of_its_level() -> void:
	var tiles: Array = [_tile(0, 0, "water"), _tile(1, 0, "sand")]
	var night: Node3D = _build(tiles, "lanka_streets")
	var dawn: Node3D = _build(tiles, "mahendra")
	var night_material: ShaderMaterial = (night.get_node("Tiles/Water_0") as MeshInstance3D).material_override as ShaderMaterial
	var dawn_material: ShaderMaterial = (dawn.get_node("Tiles/Water_0") as MeshInstance3D).material_override as ShaderMaterial
	assert_str(str(night_material.get_meta(&"mood"))).is_equal("night")
	assert_str(str(dawn_material.get_meta(&"mood"))).is_equal("dawn")


func test_colliders_and_navmesh_stay_flat() -> void:
	var tiles: Array = _field(3, 3, "grass", 1)
	tiles.append(_tile(3, 0, "wall", 1))
	tiles.append(_tile(3, 1, "water", 1))
	tiles.append(_tile(3, 2, "stone_floor", 1))
	var root: Node3D = _build(tiles)
	var floor_body: StaticBody3D = root.get_node("Tiles/Floor") as StaticBody3D
	assert_int(floor_body.get_child_count()).is_equal(12)
	for child: Node in floor_body.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		var box: BoxShape3D = shape_node.shape as BoxShape3D
		assert_object(box).is_not_null()
		assert_float(box.size.x).is_equal_approx(2.0, 0.001)
		assert_float(box.size.z).is_equal_approx(2.0, 0.001)
		var top: float = shape_node.position.y + box.size.y * 0.5
		assert_float(top).is_equal_approx(2.5 if shape_node.name == &"Tile_3_0" else 0.5, 0.001)
	var region: NavigationRegion3D = root.get_node("NavigationRegion3D") as NavigationRegion3D
	var nav: NavigationMesh = region.navigation_mesh
	# Nine grass tiles and the stone floor: one flat quad each, at exactly the tile height.
	assert_int(nav.get_polygon_count()).is_equal(10)
	assert_int(nav.get_vertices().size()).is_equal(40)
	for v: Vector3 in nav.get_vertices():
		assert_float(v.y).is_equal_approx(0.5, 0.0001)
		assert_float(fposmod(v.x, 2.0)).is_equal_approx(0.0, 0.0001)


func test_terrain_is_deterministic() -> void:
	var tiles: Array = _field(3, 3, "grass", 1)
	tiles.append(_tile(3, 0, "wall", 1))
	tiles.append(_tile(3, 1, "sand", 1))
	tiles.append(_tile(3, 2, "stone_floor", 1))
	var first: Node3D = _build(tiles)
	var second: Node3D = _build(tiles)
	for tile_type: String in ["grass", "wall", "sand", "stone_floor"]:
		var a: PackedVector3Array = _verts(_type_mesh(first, tile_type))
		var b: PackedVector3Array = _verts(_type_mesh(second, tile_type))
		assert_int(a.size()).is_equal(b.size())
		assert_bool(a == b).is_true()
		assert_bool(_colours(_type_mesh(first, tile_type)) == _colours(_type_mesh(second, tile_type))).is_true()


func test_real_levels_build_with_painted_terrain() -> void:
	for level_id: String in ["mahendra", "lanka_gate", "ashoka_vatika"]:
		var file: FileAccess = FileAccess.open("res://levels/%s.json" % level_id, FileAccess.READ)
		assert_object(file).is_not_null()
		var data: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
		var root: Node3D = LevelBuilder.build(data)
		auto_free(root)
		var tiles: Node = root.get_node("Tiles")
		var meshes: int = 0
		for child: Node in tiles.get_children():
			if child is MeshInstance3D and str(child.name).begins_with("Tiles_"):
				meshes += 1
				var mesh_node: MeshInstance3D = child as MeshInstance3D
				var verts: PackedVector3Array = _verts(mesh_node)
				assert_int(verts.size()).is_greater(0)
				assert_int(verts.size() % 3).is_equal(0)
				assert_int(_normals(mesh_node).size()).is_equal(verts.size())
				assert_int(_colours(mesh_node).size()).is_equal(verts.size())
		assert_int(meshes).is_greater(1)
		assert_int((data["tiles"] as Array).size()).is_equal((tiles.get_node("Floor") as Node).get_child_count())
