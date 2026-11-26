extends GdUnitTestSuite
## M36 acceptance tests for gen/npc_models.gd (helpers updated for the B3 art pass: parts may sit under pivot
## nodes, colours may be shaded blends and the divine aura shell is not part of a figure's height).

const IDS: Array[StringName] = [
	&"jambavan", &"angada", &"vanara", &"sita", &"trijata", &"rakshasi", &"ravana",
	&"vibhishana", &"indrajit", &"courtier", &"rama", &"mainaka", &"surasa",
]
## id -> [min height, max height]
const RANGES: Dictionary = {
	&"jambavan": [1.4, 2.4], &"angada": [1.3, 2.2], &"vanara": [1.1, 2.0], &"sita": [0.8, 1.6],
	&"trijata": [1.2, 2.0], &"rakshasi": [1.4, 2.3], &"ravana": [2.2, 4.0], &"vibhishana": [1.6, 2.6],
	&"indrajit": [1.6, 2.6], &"courtier": [1.4, 2.4], &"rama": [1.5, 2.4], &"mainaka": [3.0, 9.0],
	&"surasa": [2.0, 6.0],
}
const BIG: float = 1.0e9


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child, out)


func _height(root: Node3D) -> float:
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	var lo: float = BIG
	var hi: float = -BIG
	for mi: MeshInstance3D in list:
		if String(mi.name).ends_with("Aura"):
			continue
		var box: AABB = (mi.mesh as Mesh).get_aabb()
		for i: int in 8:
			var p: Vector3 = _local_xf(mi, root) * box.get_endpoint(i)
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
	return hi - lo


func _local_xf(node: Node, root: Node) -> Transform3D:
	if node == root:
		return Transform3D.IDENTITY
	return _local_xf(node.get_parent(), root) * (node as Node3D).transform


func test_every_id_builds() -> void:
	for id: StringName in IDS:
		var n: Node3D = auto_free(NpcModels.build(id)) as Node3D
		assert_object(n).is_not_null()
		var list: Array[MeshInstance3D] = []
		_meshes(n, list)
		assert_bool(list.size() > 5).is_true()


func test_heights_in_range() -> void:
	for id: StringName in IDS:
		var n: Node3D = auto_free(NpcModels.build(id)) as Node3D
		var r: Array = RANGES[id] as Array
		var h: float = _height(n)
		assert_bool(h >= (r[0] as float) and h <= (r[1] as float)).override_failure_message("%s height %f" % [id, h]).is_true()


func test_ravana_has_exactly_ten_heads() -> void:
	var n: Node3D = auto_free(NpcModels.build(&"ravana")) as Node3D
	var heads: Node = n.get_node("Heads")
	assert_int(heads.get_child_count()).is_equal(10)
	assert_object(heads.get_node("Head_main")).is_not_null()


func test_ravana_wears_gold_crowns() -> void:
	var n: Node3D = auto_free(NpcModels.build(&"ravana")) as Node3D
	var cols: Array[Color] = _colors(n)
	var found: bool = false
	for c: Color in cols:
		if _near(c, Palette.GOLD):
			found = true
	assert_bool(found).is_true()


func test_angada_has_gold_armlets() -> void:
	var cols: Array[Color] = _colors(auto_free(NpcModels.build(&"angada")) as Node3D)
	var found: bool = false
	for c: Color in cols:
		if _near(c, Palette.GOLD):
			found = true
	assert_bool(found).is_true()


func test_rama_skin_tone() -> void:
	var cols: Array[Color] = _colors(auto_free(NpcModels.build(&"rama")) as Node3D)
	var found: bool = false
	for c: Color in cols:
		if _near(c, Color("#2E4A7A")):
			found = true
	assert_bool(found).is_true()


func test_vanara_seed_variants_differ() -> void:
	var a: Array[Color] = _colors(auto_free(NpcModels.build(&"vanara_0")) as Node3D)
	var b: Array[Color] = _colors(auto_free(NpcModels.build(&"vanara_1")) as Node3D)
	var same: bool = a.size() == b.size()
	if same:
		for c: Color in a:
			var hit: bool = false
			for d: Color in b:
				if _near(c, d):
					hit = true
					break
			if not hit:
				same = false
				break
	assert_bool(same).is_false()


## B3: vertex colours may be shaded, so each one must be a documented colour or a blend of two documented colours
## (alpha is the wind weight and is ignored).
func test_only_documented_colours() -> void:
	var allowed: Array[Color] = NpcModels.allowed_colors()
	for id: StringName in IDS:
		for c: Color in _colors(auto_free(NpcModels.build(id)) as Node3D):
			assert_bool(_is_blend(c, allowed)).override_failure_message("%s uses undocumented colour %s" % [id, c.to_html()]).is_true()


func _near(a: Color, b: Color) -> bool:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) < 0.006


func _is_blend(c: Color, allowed: Array[Color]) -> bool:
	var v: Vector3 = Vector3(c.r, c.g, c.b)
	for i: int in allowed.size():
		var a: Vector3 = Vector3(allowed[i].r, allowed[i].g, allowed[i].b)
		if a.distance_to(v) < 0.012:
			return true
		for j: int in range(i + 1, allowed.size()):
			var b: Vector3 = Vector3(allowed[j].r, allowed[j].g, allowed[j].b)
			var ab: Vector3 = b - a
			var t: float = clampf((v - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
			if (a + ab * t).distance_to(v) < 0.012:
				return true
	return false


func test_unknown_id_falls_back() -> void:
	var n: Node3D = auto_free(NpcModels.build(&"nobody")) as Node3D
	assert_object(n).is_not_null()


func test_set_pose_idle_is_safe() -> void:
	var n: Node3D = auto_free(NpcModels.build(&"sita")) as Node3D
	NpcModels.set_pose(n, &"idle")
	assert_object(n).is_not_null()


## Unique vertex colours (rgb only, quantised to 8 bits).
func _colors(root: Node3D) -> Array[Color]:
	var seen: Dictionary = {}
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	for mi: MeshInstance3D in list:
		var m: Mesh = mi.mesh
		for s: int in m.get_surface_count():
			var arrs: Array = m.surface_get_arrays(s)
			var cs: PackedColorArray = arrs[Mesh.ARRAY_COLOR] as PackedColorArray
			for c: Color in cs:
				seen[Color(c.r, c.g, c.b, 1.0).to_rgba32()] = true
	var out: Array[Color] = []
	for key: Variant in seen:
		out.append(Color.hex(key as int))
	return out
