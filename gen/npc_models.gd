class_name NpcModels
extends RefCounted
## Story characters and set-piece figures (DESIGN §9 M36). Static low-poly models built with MeshKit; no skeletons,
## so the only pose is idle (set_pose is a safe no-op kept for API parity with HanumanModel). Forward is -Z.
## Depiction rules (§2): Sita is dignified and sorrowful, Rama is serene and reverent, nobody is comic.
## Ids: jambavan, angada, vanara (or vanara_<seed>), sita, trijata, rakshasi, ravana, vibhishana, indrajit,
## courtier, rama, mainaka, surasa. Unknown ids fall back to vanara.

## Extra colour constants beyond Palette (documented here; see allowed_colors()).
const BEAR_FUR: Color = Color("#3A2C26")
const BEAR_MUZZLE: Color = Color("#6B5646")
const BROW_WHITE: Color = Color("#EEE8DA")
const HUMAN_SKIN: Color = Color("#D9A878")
const SARI_SOILED: Color = Color("#CDB57C")
const SARI_HEM: Color = Color("#A8935F")
const RAMA_SKIN: Color = Color("#2E4A7A")
const DHOTI_YELLOW: Color = Color("#E8C23A")
const ELDER_HAIR: Color = Color("#BDB8C8")
const RAKSHASA_PALE: Color = Color("#8A7DB5")
const EMERALD: Color = Color("#1F8A5B")
const GOLD_DARK: Color = Color("#C99A2E")
const VANARA_GREY: Color = Color("#8C8C86")


static func allowed_colors() -> Array[Color]:
	return [
		Palette.SAFFRON, Palette.SINDOOR, Palette.GOLD, Palette.HANUMAN_FUR, Palette.DEEP_OCEAN, Palette.NIGHT_INDIGO,
		Palette.MOON, Palette.GROVE_GREEN, Palette.ASHOKA_RED, Palette.RAKSHASA_SKIN, Palette.RAKSHASA_ARMOR,
		Palette.STONE, Palette.FIRE_CORE, Palette.FIRE_EDGE, Palette.UI_DARK, Palette.BARK, Palette.LEAF_DARK,
		Palette.SKY_DUSK, BEAR_FUR, BEAR_MUZZLE, BROW_WHITE, HUMAN_SKIN, SARI_SOILED, SARI_HEM, RAMA_SKIN,
		DHOTI_YELLOW, ELDER_HAIR, RAKSHASA_PALE, EMERALD, GOLD_DARK, VANARA_GREY,
	]


static func build(id: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Npc_" + String(id)
	var sid: String = String(id)
	if sid.begins_with("vanara"):
		var seed_value: int = 0
		if sid.length() > 7:
			seed_value = sid.substr(7).to_int()
		_vanara(root, seed_value)
		return root
	match id:
		&"jambavan":
			_jambavan(root)
		&"angada":
			_angada(root)
		&"sita":
			_sita(root)
		&"trijata":
			_trijata(root)
		&"rakshasi":
			_rakshasi(root)
		&"ravana":
			_ravana(root)
		&"vibhishana":
			_vibhishana(root)
		&"indrajit":
			_indrajit(root)
		&"courtier":
			_courtier(root)
		&"rama":
			_rama(root)
		&"mainaka":
			_mainaka(root)
		&"surasa":
			_surasa(root)
		_:
			_vanara(root, 0)
	return root


## All figures are static, so every pose is the same idle stance.
static func set_pose(_root: Node3D, _pose: StringName) -> void:
	pass


# ---------------------------------------------------------------- helpers

static func _add(root: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Part"
	mi.mesh = mesh
	mi.material_override = MeshKit.flat_material()
	mi.transform = Transform3D(Basis.from_euler(rot).scaled(scl), pos)
	root.add_child(mi)
	return mi


## Standard standing humanoid, feet on y = 0. o keys (all optional): H (scale), w (width), skin, cloth, torso, trim,
## stoop, armlets (bool), eyes (bool). The head top sits at about 0.91 * H.
static func _body(root: Node3D, o: Dictionary) -> void:
	var h: float = (o.get("H", 1.8) as float)
	var w: float = (o.get("w", 1.0) as float)
	var skin: Color = o.get("skin", HUMAN_SKIN) as Color
	var cloth: Color = o.get("cloth", Palette.STONE) as Color
	var torso: Color = o.get("torso", skin) as Color
	var trim: Color = o.get("trim", Palette.GOLD) as Color
	var stoop: float = (o.get("stoop", 0.0) as float)
	var bend: float = (o.get("bend", 0.0) as float)
	var bs: float = sin(bend)
	for sx: float in [-1.0, 1.0]:
		_add(root, MeshKit.cylinder(0.05 * h * w, 0.04 * h * w, 0.46 * h, 6, skin), Vector3(sx * 0.07 * h * w, 0.25 * h, 0.0))
		_add(root, MeshKit.box(Vector3(0.07 * h, 0.035 * h, 0.12 * h), skin), Vector3(sx * 0.07 * h * w, 0.018 * h, -0.025 * h))
	_add(root, MeshKit.cylinder(0.125 * h * w, 0.16 * h * w, 0.42 * h, 8, cloth), Vector3(0.0, 0.3 * h, 0.0))
	_add(root, MeshKit.cylinder(0.13 * h * w, 0.13 * h * w, 0.03 * h, 8, trim), Vector3(0.0, 0.5 * h, 0.0))
	var lean: Vector3 = Vector3(-stoop * 2.0, 0.0, 0.0)
	_add(root, MeshKit.cylinder(0.16 * h * w, 0.125 * h * w, 0.3 * h, 8, torso), Vector3(0.0, 0.64 * h, -stoop * 0.3 * h), lean)
	_add(root, MeshKit.cylinder(0.04 * h, 0.045 * h, 0.06 * h, 6, skin), Vector3(0.0, 0.79 * h, -stoop * 0.8 * h))
	if o.get("head", true) as bool:
		_add(root, MeshKit.sphere(0.075 * h, 6, 8, skin), Vector3(0.0, 0.855 * h, -stoop * 0.95 * h))
	if (o.get("eyes", true) as bool):
		for sx2: float in [-1.0, 1.0]:
			_add(root, MeshKit.box(Vector3(0.016 * h, 0.012 * h, 0.01 * h), Palette.NIGHT_INDIGO), Vector3(sx2 * 0.03 * h, 0.865 * h, -(0.073 * h + stoop * 0.95 * h)))
	for sx3: float in [-1.0, 1.0]:
		var ax: float = sx3 * 0.2 * h * w
		_add(root, MeshKit.sphere(0.05 * h, 5, 7, torso), Vector3(ax, 0.745 * h, -stoop * 0.5 * h))
		_add(root, MeshKit.cylinder(0.034 * h, 0.03 * h, 0.2 * h, 6, skin), Vector3(ax, 0.64 * h, -stoop * 0.3 * h))
		_add(root, MeshKit.cylinder(0.03 * h, 0.026 * h, 0.18 * h, 6, skin), Vector3(ax, 0.46 * h, -stoop * 0.15 * h - 0.09 * h * bs), Vector3(bend, 0.0, 0.0))
		_add(root, MeshKit.sphere(0.03 * h, 5, 6, skin), Vector3(ax, 0.355 * h, -stoop * 0.1 * h - 0.195 * h * bs))
		if (o.get("armlets", false) as bool):
			_add(root, MeshKit.cylinder(0.045 * h, 0.045 * h, 0.04 * h, 8, Palette.GOLD), Vector3(ax, 0.69 * h, -stoop * 0.3 * h))
			_add(root, MeshKit.cylinder(0.036 * h, 0.036 * h, 0.025 * h, 8, Palette.GOLD), Vector3(ax, 0.4 * h, -stoop * 0.12 * h - 0.15 * h * bs), Vector3(bend, 0.0, 0.0))


static func _named(mi: MeshInstance3D, part_name: String) -> MeshInstance3D:
	mi.name = part_name
	return mi


static func _crown(root: Node3D, y: float, r: float, points: int, tall: float, col: Color, z: float = 0.0, x: float = 0.0) -> void:
	_add(root, MeshKit.cylinder(r, r * 1.05, tall * 0.45, 8, col), Vector3(x, y, z))
	for i: int in points:
		var a: float = TAU * float(i) / float(points)
		_add(root, MeshKit.cone(r * 0.2, tall, 5, col), Vector3(x + sin(a) * r * 0.8, y + tall * 0.7, z + cos(a) * r * 0.8))


static func _staff(root: Node3D, pos: Vector3, length: float, wood: Color, knob: Color) -> void:
	_add(root, MeshKit.cylinder(0.02, 0.025, length, 5, wood), pos + Vector3(0.0, length * 0.5, 0.0))
	_add(root, MeshKit.sphere(0.045, 4, 6, knob), pos + Vector3(0.0, length, 0.0))


static func _bow(root: Node3D, pos: Vector3, size: float, wood: Color, tips: Color) -> void:
	# Held upright, bulging away from the archer (-Z); the string is a thin box on the archer's side.
	var k: float = size * 0.25
	var m: float = size * 0.55
	for i: int in 7:
		var a: float = -1.0 + 0.333 * float(i)
		var p: Vector3 = pos + Vector3(0.0, m * sin(a), -k * cos(a) + k * 0.54)
		var theta: float = atan2(k * sin(a), m * cos(a))
		_add(root, MeshKit.box(Vector3(0.03, size * 0.2, 0.03), wood), p, Vector3(theta, 0.0, 0.0))
	_add(root, MeshKit.box(Vector3(0.008, size * 0.92, 0.008), Palette.STONE), pos + Vector3(0.0, 0.0, k * 0.54 - k * 0.54 + 0.02))
	for sgn: float in [-1.0, 1.0]:
		_add(root, MeshKit.cone(0.025, 0.08, 5, tips), pos + Vector3(0.0, sgn * size * 0.47, 0.02), Vector3(0.0 if sgn > 0.0 else PI, 0.0, 0.0))


# ---------------------------------------------------------------- vanaras

static func _vanara_head(root: Node3D, h: float, fur: Color, face: Color, muzzle: float, z: float = 0.0) -> void:
	_add(root, MeshKit.sphere(0.085 * h, 6, 8, fur), Vector3(0.0, 0.86 * h, z))
	_add(root, MeshKit.box(Vector3(0.09 * h, 0.06 * h, 0.07 * h * muzzle), face), Vector3(0.0, 0.84 * h, z - 0.075 * h))
	for sx: float in [-1.0, 1.0]:
		_add(root, MeshKit.sphere(0.03 * h, 4, 6, fur), Vector3(sx * 0.085 * h, 0.87 * h, z))


static func _tail(root: Node3D, h: float, fur: Color) -> void:
	for i: int in 5:
		var t: float = float(i) / 4.0
		_add(root, MeshKit.cylinder(0.025 * h, 0.03 * h, 0.14 * h, 5, fur), Vector3(0.0, (0.34 + 0.12 * t) * h, (0.14 + 0.2 * t) * h), Vector3(-0.9 + 0.2 * t, 0.0, 0.0))


static func _vanara(root: Node3D, seed_value: int) -> void:
	var furs: Array[Color] = [Palette.HANUMAN_FUR, Palette.BARK, VANARA_GREY, Palette.STONE]
	var cloths: Array[Color] = [Palette.GROVE_GREEN, Palette.SINDOOR, Palette.LEAF_DARK, Palette.DEEP_OCEAN]
	var k: int = absi(seed_value)
	var fur: Color = furs[k % furs.size()]
	var cloth: Color = cloths[(k / furs.size() + k) % cloths.size()]
	var h: float = 1.55 + 0.04 * float(k % 3)
	_body(root, {"H": h, "w": 1.0, "skin": fur, "cloth": cloth, "trim": Palette.STONE, "eyes": false, "stoop": 0.03})
	_vanara_head(root, h, fur, Palette.STONE, 1.0, -0.03 * h)
	_tail(root, h, fur)


static func _angada(root: Node3D) -> void:
	var h: float = 1.75
	var fur: Color = Palette.HANUMAN_FUR
	_body(root, {"H": h, "w": 1.05, "skin": fur, "cloth": Palette.SINDOOR, "trim": Palette.GOLD, "armlets": true, "eyes": false})
	_vanara_head(root, h, fur, Palette.STONE, 1.0)
	_add(root, MeshKit.cylinder(0.09 * h, 0.09 * h, 0.02 * h, 8, Palette.GOLD), Vector3(0.0, 0.915 * h, 0.0))
	_tail(root, h, fur)
	_add(root, MeshKit.cylinder(0.17 * h, 0.17 * h, 0.025 * h, 8, Palette.GOLD), Vector3(0.0, 0.76 * h, 0.0))


static func _jambavan(root: Node3D) -> void:
	var h: float = 1.85
	_body(root, {"H": h, "w": 1.3, "skin": BEAR_FUR, "cloth": Palette.BARK, "trim": Palette.GOLD, "stoop": 0.07, "eyes": false})
	var z: float = -0.07 * h
	# Bear head: broad skull, long muzzle, round ears, white brows and beard.
	_add(root, MeshKit.sphere(0.095 * h, 6, 8, BEAR_FUR), Vector3(0.0, 0.875 * h, z))
	_add(root, MeshKit.box(Vector3(0.09 * h, 0.07 * h, 0.09 * h), BEAR_MUZZLE), Vector3(0.0, 0.85 * h, z - 0.09 * h))
	_add(root, MeshKit.box(Vector3(0.03 * h, 0.025 * h, 0.02 * h), Palette.NIGHT_INDIGO), Vector3(0.0, 0.865 * h, z - 0.14 * h))
	for sx: float in [-1.0, 1.0]:
		_add(root, MeshKit.sphere(0.04 * h, 4, 6, BEAR_FUR), Vector3(sx * 0.07 * h, 0.95 * h, z))
		_add(root, MeshKit.box(Vector3(0.055 * h, 0.02 * h, 0.03 * h), BROW_WHITE), Vector3(sx * 0.04 * h, 0.9 * h, z - 0.085 * h), Vector3(0.0, 0.0, -sx * 0.2))
		_add(root, MeshKit.box(Vector3(0.012 * h, 0.012 * h, 0.01 * h), Palette.NIGHT_INDIGO), Vector3(sx * 0.04 * h, 0.882 * h, z - 0.092 * h))
	_add(root, MeshKit.cone(0.05 * h, 0.12 * h, 6, BROW_WHITE), Vector3(0.0, 0.79 * h, z - 0.07 * h), Vector3(PI, 0.0, 0.0))
	# Grey-white mane across the shoulders and a staff in the right hand.
	_add(root, MeshKit.cylinder(0.1 * h, 0.17 * h, 0.07 * h, 8, BROW_WHITE), Vector3(0.0, 0.76 * h, -0.02 * h))
	_staff(root, Vector3(-0.27 * h, 0.0, -0.06 * h), 1.15 * h, Palette.BARK, Palette.GOLD)
	_add(root, MeshKit.cylinder(0.02 * h, 0.02 * h, 0.1 * h, 5, Palette.BARK), Vector3(-0.27 * h, 0.36 * h, -0.06 * h), Vector3(PI / 2.0, 0.0, 0.0))


# ---------------------------------------------------------------- Lanka's women

static func _sita(root: Node3D) -> void:
	var s: float = 1.0
	# Seated cross-legged: a soft mound of sari, an upright torso, hands folded in the lap.
	_add(root, MeshKit.cylinder(0.2 * s, 0.42 * s, 0.34 * s, 8, SARI_SOILED), Vector3(0.0, 0.17 * s, 0.0))
	_add(root, MeshKit.cylinder(0.43 * s, 0.43 * s, 0.05 * s, 8, SARI_HEM), Vector3(0.0, 0.03 * s, 0.0))
	_add(root, MeshKit.cylinder(0.16 * s, 0.2 * s, 0.32 * s, 8, SARI_SOILED), Vector3(0.0, 0.5 * s, 0.0), Vector3(-0.06, 0.0, 0.0))
	_add(root, MeshKit.box(Vector3(0.34 * s, 0.07 * s, 0.1 * s), SARI_HEM), Vector3(0.0, 0.52 * s, -0.12 * s), Vector3(0.0, 0.0, 0.0))
	_add(root, MeshKit.cylinder(0.035 * s, 0.04 * s, 0.07 * s, 6, HUMAN_SKIN), Vector3(0.0, 0.7 * s, -0.02 * s))
	# Head slightly bowed, covered by the draped sari; a gentle face beneath it.
	_add(root, MeshKit.sphere(0.075 * s, 6, 8, HUMAN_SKIN), Vector3(0.0, 0.785 * s, -0.045 * s))
	_add(root, MeshKit.sphere(0.095 * s, 6, 8, SARI_SOILED), Vector3(0.0, 0.8 * s, -0.01 * s), Vector3.ZERO, Vector3(1.0, 1.0, 0.95))
	# No protruding nose (depiction rule): the face is a smooth oval with a sindoor bindi and the pallu framing it.
	_named(_add(root, MeshKit.box(Vector3(0.012 * s, 0.016 * s, 0.006 * s), Palette.SINDOOR), Vector3(0.0, 0.822 * s, -0.12 * s)), "Sita_Bindi")
	_add(root, MeshKit.box(Vector3(0.17 * s, 0.03 * s, 0.1 * s), SARI_SOILED), Vector3(0.0, 0.855 * s, -0.07 * s))
	_add(root, MeshKit.cylinder(0.08 * s, 0.16 * s, 0.34 * s, 8, SARI_SOILED), Vector3(0.0, 0.62 * s, 0.1 * s), Vector3(0.18, 0.0, 0.0))
	for sx: float in [-1.0, 1.0]:
		_named(_add(root, MeshKit.box(Vector3(0.012 * s, 0.008 * s, 0.005 * s), Palette.NIGHT_INDIGO), Vector3(sx * 0.028 * s, 0.795 * s, -0.12 * s)), "Sita_Eye")
		_add(root, MeshKit.box(Vector3(0.03 * s, 0.13 * s, 0.07 * s), SARI_SOILED), Vector3(sx * 0.085 * s, 0.785 * s, -0.07 * s), Vector3(0.0, sx * 0.4, 0.0))
		_add(root, MeshKit.sphere(0.04 * s, 5, 6, SARI_SOILED), Vector3(sx * 0.17 * s, 0.62 * s, 0.0))
		_add(root, MeshKit.cylinder(0.03 * s, 0.027 * s, 0.22 * s, 6, SARI_SOILED), Vector3(sx * 0.17 * s, 0.5 * s, -0.04 * s), Vector3(-0.35, 0.0, -sx * 0.2))
	# Folded hands (anjali) resting in front of the chest.
	_add(root, MeshKit.sphere(0.04 * s, 5, 6, HUMAN_SKIN), Vector3(0.0, 0.45 * s, -0.17 * s))
	_add(root, MeshKit.box(Vector3(0.05 * s, 0.07 * s, 0.025 * s), HUMAN_SKIN), Vector3(0.0, 0.47 * s, -0.19 * s))


static func _trijata(root: Node3D) -> void:
	var h: float = 1.6
	_body(root, {"H": h, "w": 0.95, "skin": Palette.RAKSHASA_SKIN, "cloth": Palette.STONE, "torso": Palette.STONE, "trim": Palette.GOLD, "stoop": 0.06})
	var z: float = -0.06 * h
	_add(root, MeshKit.sphere(0.082 * h, 6, 8, ELDER_HAIR), Vector3(0.0, 0.87 * h, z + 0.02 * h))
	_add(root, MeshKit.sphere(0.04 * h, 5, 6, ELDER_HAIR), Vector3(0.0, 0.885 * h, z + 0.1 * h))
	_add(root, MeshKit.cylinder(0.14 * h, 0.17 * h, 0.1 * h, 8, Palette.STONE), Vector3(0.0, 0.74 * h, -0.02 * h))
	_staff(root, Vector3(-0.22 * h, 0.0, -0.08 * h), 0.95 * h, Palette.BARK, Palette.BARK)


static func _rakshasi(root: Node3D) -> void:
	var h: float = 1.8
	_body(root, {"H": h, "w": 1.0, "skin": Palette.RAKSHASA_SKIN, "cloth": Palette.RAKSHASA_ARMOR, "torso": Palette.RAKSHASA_ARMOR, "trim": Palette.GOLD})
	_add(root, MeshKit.sphere(0.08 * h, 6, 8, Palette.NIGHT_INDIGO), Vector3(0.0, 0.88 * h, 0.012 * h))
	for sx: float in [-1.0, 1.0]:
		_add(root, MeshKit.cone(0.025 * h, 0.09 * h, 5, Palette.STONE), Vector3(sx * 0.055 * h, 0.95 * h, 0.0), Vector3(0.0, 0.0, -sx * 0.4))
		_add(root, MeshKit.sphere(0.045 * h, 5, 6, Palette.GOLD), Vector3(sx * 0.2 * h, 0.745 * h, 0.0))
	_add(root, MeshKit.cylinder(0.2 * h, 0.2 * h, 0.04 * h, 8, Palette.GOLD), Vector3(0.0, 0.5 * h, 0.0))


# ---------------------------------------------------------------- Lanka's court

static func _ravana(root: Node3D) -> void:
	var h: float = 2.9
	_body(root, {"H": h, "w": 1.45, "skin": Palette.RAKSHASA_SKIN, "cloth": Palette.NIGHT_INDIGO, "torso": Palette.RAKSHASA_ARMOR, "trim": Palette.GOLD, "eyes": false, "head": false})
	# The heads are built below on top of a thick neck, so the body helper skips its own.
	_add(root, MeshKit.box(Vector3(0.36 * h, 0.17 * h, 0.1 * h), Palette.GOLD), Vector3(0.0, 0.67 * h, -0.115 * h * 1.45))
	_add(root, MeshKit.box(Vector3(0.5 * h, 0.04 * h, 0.2 * h), Palette.GOLD), Vector3(0.0, 0.76 * h, 0.0))
	for sx: float in [-1.0, 1.0]:
		_add(root, MeshKit.sphere(0.1 * h, 5, 7, Palette.GOLD), Vector3(sx * 0.3 * h, 0.75 * h, 0.0))
		_add(root, MeshKit.cylinder(0.05 * h, 0.05 * h, 0.05 * h, 8, Palette.GOLD), Vector3(sx * 0.3 * h, 0.55 * h, 0.0))
		for k: int in 2:
			# Extra arms, folded across the body at rest.
			_add(root, MeshKit.cylinder(0.034 * h, 0.03 * h, 0.2 * h, 6, Palette.RAKSHASA_SKIN), Vector3(sx * 0.22 * h, (0.62 - 0.1 * float(k)) * h, -0.08 * h), Vector3(0.0, 0.0, sx * 0.9))
	var heads: Node3D = Node3D.new()
	heads.name = "Heads"
	root.add_child(heads)
	# Main head: bigger, front and centre, tall gold crown.
	var main_head: Node3D = Node3D.new()
	main_head.name = "Head_main"
	main_head.position = Vector3(0.0, 0.88 * h, 0.0)
	heads.add_child(main_head)
	_head(main_head, 0.075 * h, 1.0)
	# Nine smaller crowned heads: four to each side in a rising arc, one above.
	for i: int in 4:
		for sx2: float in [-1.0, 1.0]:
			var hd: Node3D = Node3D.new()
			hd.name = "Head_%s%d" % ["l" if sx2 > 0.0 else "r", i]
			var fi: float = float(i)
			hd.position = Vector3(sx2 * (0.14 + 0.1 * fi) * h, (0.86 + 0.03 * fi) * h, (0.03 + 0.012 * fi) * h)
			heads.add_child(hd)
			_head(hd, 0.052 * h, 0.7)
	var top: Node3D = Node3D.new()
	top.name = "Head_top"
	top.position = Vector3(0.0, 1.02 * h, 0.02 * h)
	heads.add_child(top)
	_head(top, 0.055 * h, 0.75)
	# Sword at the belt, a sign of rank.
	_add(root, MeshKit.box(Vector3(0.02 * h, 0.3 * h, 0.02 * h), Palette.STONE), Vector3(0.26 * h, 0.32 * h, -0.02 * h))
	_add(root, MeshKit.box(Vector3(0.07 * h, 0.015 * h, 0.03 * h), Palette.GOLD), Vector3(0.26 * h, 0.48 * h, -0.02 * h))


## One face: skull, brow, fangs-free calm mouth, eyes, ears and a gold crown scaled to the head.
static func _head(parent: Node3D, r: float, crown_scale: float) -> void:
	_add(parent, MeshKit.sphere(r, 6, 8, Palette.RAKSHASA_SKIN), Vector3.ZERO)
	_add(parent, MeshKit.box(Vector3(r * 1.1, r * 0.4, r * 0.6), Palette.RAKSHASA_SKIN), Vector3(0.0, -r * 0.35, -r * 0.7))
	_add(parent, MeshKit.box(Vector3(r * 1.7, r * 0.18, r * 0.3), Palette.RAKSHASA_ARMOR), Vector3(0.0, r * 0.3, -r * 0.8))
	for sx: float in [-1.0, 1.0]:
		_add(parent, MeshKit.box(Vector3(r * 0.3, r * 0.15, r * 0.1), Palette.FIRE_CORE), Vector3(sx * r * 0.38, r * 0.1, -r * 0.95))
		_add(parent, MeshKit.cone(r * 0.2, r * 0.7, 5, Palette.RAKSHASA_ARMOR), Vector3(sx * r * 0.65, r * 0.75, 0.0), Vector3(0.0, 0.0, -sx * 0.5))
	_crown_at(parent, r, crown_scale)


static func _crown_at(parent: Node3D, r: float, crown_scale: float) -> void:
	var band_y: float = r * 0.78
	_add(parent, MeshKit.cylinder(r * 0.92, r * 1.0, r * 0.32, 8, Palette.GOLD), Vector3(0.0, band_y, 0.0))
	_add(parent, MeshKit.cone(r * 0.55, r * 1.1 * crown_scale + r * 0.3, 8, Palette.GOLD), Vector3(0.0, band_y + r * 0.7, 0.0))
	for i: int in 5:
		var a: float = TAU * float(i) / 5.0
		_add(parent, MeshKit.cone(r * 0.14, r * 0.45, 5, Palette.GOLD), Vector3(sin(a) * r * 0.82, band_y + r * 0.35, cos(a) * r * 0.82))


static func _vibhishana(root: Node3D) -> void:
	var h: float = 2.05
	_body(root, {"H": h, "w": 1.0, "skin": RAKSHASA_PALE, "cloth": Palette.MOON, "torso": Palette.MOON, "trim": Palette.GOLD})
	var r: float = 0.075 * h
	_add(root, MeshKit.sphere(r * 1.05, 6, 8, Palette.NIGHT_INDIGO), Vector3(0.0, 0.87 * h, 0.012 * h))
	_add(root, MeshKit.cylinder(r * 0.95, r * 0.95, 0.025 * h, 8, Palette.GOLD), Vector3(0.0, 0.915 * h, 0.0))
	_add(root, MeshKit.cone(0.025 * h, 0.07 * h, 5, Palette.GOLD), Vector3(0.0, 0.97 * h, -0.02 * h))
	_add(root, MeshKit.cylinder(0.17 * h, 0.2 * h, 0.07 * h, 8, Palette.GOLD), Vector3(0.0, 0.5 * h, 0.0))
	_add(root, MeshKit.box(Vector3(0.12 * h, 0.2 * h, 0.03 * h), Palette.GOLD), Vector3(0.0, 0.62 * h, -0.14 * h))


static func _indrajit(root: Node3D) -> void:
	var h: float = 2.1
	_body(root, {"H": h, "w": 1.1, "skin": Palette.RAKSHASA_SKIN, "cloth": Palette.NIGHT_INDIGO, "torso": Palette.RAKSHASA_ARMOR, "trim": Palette.GOLD, "armlets": true})
	var r: float = 0.075 * h
	_add(root, MeshKit.cylinder(r * 0.95, r * 1.05, 0.08 * h, 8, Palette.RAKSHASA_ARMOR), Vector3(0.0, 0.91 * h, 0.0))
	_add(root, MeshKit.cone(0.03 * h, 0.14 * h, 5, Palette.GOLD), Vector3(0.0, 1.0 * h, 0.0))
	_add(root, MeshKit.box(Vector3(0.28 * h, 0.2 * h, 0.04 * h), Palette.GOLD), Vector3(0.0, 0.66 * h, -0.14 * h))
	for sx: float in [-1.0, 1.0]:
		_add(root, MeshKit.sphere(0.07 * h, 5, 7, Palette.GOLD), Vector3(sx * 0.2 * h * 1.1, 0.755 * h, 0.0))
	_bow(root, Vector3(0.22 * h * 1.1, 0.4 * h, 0.0), 0.75 * h, Palette.RAKSHASA_ARMOR, Palette.GOLD)
	_add(root, MeshKit.cylinder(0.05 * h, 0.04 * h, 0.3 * h, 6, Palette.RAKSHASA_ARMOR), Vector3(-0.08 * h, 0.7 * h, 0.17 * h), Vector3(0.0, 0.0, 0.3))
	for k: int in 3:
		_add(root, MeshKit.cone(0.015 * h, 0.06 * h, 4, Palette.GOLD), Vector3((-0.03 - 0.025 * float(k)) * h, 0.87 * h, 0.17 * h), Vector3(0.0, 0.0, 0.3))


static func _courtier(root: Node3D) -> void:
	var h: float = 1.85
	_body(root, {"H": h, "w": 1.05, "skin": Palette.RAKSHASA_SKIN, "cloth": Palette.NIGHT_INDIGO, "torso": Palette.NIGHT_INDIGO, "trim": Palette.GOLD})
	_add(root, MeshKit.cylinder(0.17 * h, 0.21 * h, 0.4 * h, 8, Palette.RAKSHASA_ARMOR), Vector3(0.0, 0.3 * h, 0.0))
	_add(root, MeshKit.box(Vector3(0.12 * h, 0.3 * h, 0.03 * h), Palette.GOLD), Vector3(0.0, 0.64 * h, -0.15 * h))
	_add(root, MeshKit.cylinder(0.075 * h, 0.085 * h, 0.07 * h, 8, Palette.RAKSHASA_ARMOR), Vector3(0.0, 0.92 * h, 0.0))
	_add(root, MeshKit.cylinder(0.088 * h, 0.088 * h, 0.015 * h, 8, Palette.GOLD), Vector3(0.0, 0.89 * h, 0.0))


# ---------------------------------------------------------------- Rama (epilogue only)

static func _rama(root: Node3D) -> void:
	var h: float = 2.0
	var bend: float = 0.35
	_body(root, {"H": h, "w": 1.0, "skin": RAMA_SKIN, "cloth": DHOTI_YELLOW, "torso": RAMA_SKIN, "trim": Palette.GOLD, "armlets": true, "bend": bend})
	var r: float = 0.075 * h
	# Dark hair under a tall gold kirita crown; a garland; a quiver on the back and the bow in the left hand.
	_add(root, MeshKit.sphere(r * 1.05, 6, 8, Palette.NIGHT_INDIGO), Vector3(0.0, 0.875 * h, 0.012 * h))
	_named(_add(root, MeshKit.cylinder(r * 1.0, r * 1.08, 0.05 * h, 8, Palette.GOLD), Vector3(0.0, 0.925 * h, 0.0)), "Rama_Crown")
	_named(_add(root, MeshKit.cone(r * 0.85, 0.1 * h, 8, Palette.GOLD), Vector3(0.0, 0.97 * h, 0.0)), "Rama_Crown_Peak")
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		_named(_add(root, MeshKit.cone(r * 0.2, 0.06 * h, 5, Palette.GOLD), Vector3(sin(a) * r * 0.95, 0.95 * h, cos(a) * r * 0.95)), "Rama_Crown_Point")
	_add(root, MeshKit.box(Vector3(0.008 * h, 0.012 * h, 0.006 * h), Palette.SINDOOR), Vector3(0.0, 0.885 * h, -0.074 * h))
	_add(root, MeshKit.cylinder(0.172 * h, 0.172 * h, 0.03 * h, 8, Palette.ASHOKA_RED), Vector3(0.0, 0.73 * h, 0.0))
	_add(root, MeshKit.cylinder(0.13 * h, 0.13 * h, 0.03 * h, 8, Palette.GOLD), Vector3(0.0, 0.5 * h, 0.0))
	# Quiver across the back, its arrows fletched in gold.
	_named(_add(root, MeshKit.cylinder(0.04 * h, 0.035 * h, 0.34 * h, 6, Palette.BARK), Vector3(0.07 * h, 0.7 * h, 0.2 * h), Vector3(0.0, 0.0, -0.3)), "Rama_Quiver")
	_add(root, MeshKit.cylinder(0.042 * h, 0.042 * h, 0.03 * h, 6, Palette.GOLD), Vector3(0.1 * h, 0.84 * h, 0.2 * h), Vector3(0.0, 0.0, -0.3))
	for k: int in 3:
		_add(root, MeshKit.cone(0.012 * h, 0.05 * h, 4, Palette.GOLD), Vector3((0.115 + 0.012 * float(k)) * h, (0.89 + 0.01 * float(k)) * h, 0.2 * h), Vector3(0.0, 0.0, -0.3))
	# Tall bow in the left hand (-X), gilded wood and tips; the hand rests at its grip.
	_bow(root, Vector3(-0.2 * h, 0.45 * h, -0.195 * h * sin(bend) - 0.04 * h), 1.0 * h, GOLD_DARK, Palette.GOLD)


# ---------------------------------------------------------------- set pieces

static func _mainaka(root: Node3D) -> void:
	var layers: Array[Color] = [Palette.GOLD, GOLD_DARK, Palette.GOLD, GOLD_DARK]
	_add(root, MeshKit.cylinder(1.5, 2.2, 0.8, 9, GOLD_DARK), Vector3(0.0, 0.4, 0.0))
	for i: int in 4:
		var fi: float = float(i)
		_add(root, MeshKit.cylinder(1.3 - 0.28 * fi, 1.6 - 0.3 * fi, 1.0, 9, layers[i]), Vector3(0.0, 1.15 + 0.85 * fi, 0.0), Vector3(0.0, 0.4 * fi, 0.0))
	_add(root, MeshKit.cone(0.95, 2.4, 9, Palette.GOLD), Vector3(0.0, 4.6, 0.0))
	# Secondary summits.
	_add(root, MeshKit.cone(0.7, 1.9, 7, GOLD_DARK), Vector3(-1.1, 2.4, 0.4))
	_add(root, MeshKit.cone(0.6, 1.5, 7, Palette.GOLD), Vector3(1.0, 2.0, -0.5))
	# Pale crest of stone at the summit and a few trees on the slopes.
	_add(root, MeshKit.cone(0.28, 0.5, 6, Palette.STONE), Vector3(0.0, 5.65, 0.0))
	for i2: int in 3:
		var a: float = 1.0 + 2.1 * float(i2)
		_add(root, MeshKit.cone(0.22, 0.6, 5, Palette.LEAF_DARK), Vector3(sin(a) * 1.4, 1.65, cos(a) * 1.4))


static func _surasa(root: Node3D) -> void:
	# A great naga mother: a coil of thick emerald rings with gold bands, a raised neck and a crowned hooded head.
	var rings: int = 4
	for i: int in rings:
		var fi: float = float(i)
		var rr: float = 1.1 - 0.17 * fi
		for k: int in 8:
			var a: float = TAU * float(k) / 8.0
			var col: Color = Palette.GOLD if (k + i) % 4 == 0 else EMERALD
			_add(root, MeshKit.sphere(0.34, 4, 6, col), Vector3(sin(a) * rr, 0.34 + 0.46 * fi, cos(a) * rr))
	var neck_rot: float = 0.0
	for j: int in 5:
		var fj: float = float(j)
		var col2: Color = Palette.GOLD if j % 2 == 0 else EMERALD
		_add(root, MeshKit.cylinder(0.24 - 0.02 * fj, 0.28 - 0.02 * fj, 0.46, 7, col2), Vector3(0.0, 1.4 + 0.42 * fj, -0.05 * fj), Vector3(neck_rot, 0.0, 0.0))
	var hy: float = 3.6
	var hz: float = -0.3
	# Hood, face and crown.
	_add(root, MeshKit.sphere(0.55, 6, 8, EMERALD), Vector3(0.0, hy, hz + 0.1), Vector3.ZERO, Vector3(1.3, 1.0, 0.45))
	_add(root, MeshKit.sphere(0.3, 6, 8, EMERALD), Vector3(0.0, hy + 0.05, hz - 0.1))
	_add(root, MeshKit.box(Vector3(0.28, 0.2, 0.3), EMERALD), Vector3(0.0, hy - 0.08, hz - 0.35))
	for sx: float in [-1.0, 1.0]:
		_add(root, MeshKit.box(Vector3(0.09, 0.06, 0.04), Palette.FIRE_CORE), Vector3(sx * 0.12, hy + 0.1, hz - 0.37))
		_add(root, MeshKit.cone(0.025, 0.12, 5, BROW_WHITE), Vector3(sx * 0.06, hy - 0.2, hz - 0.5), Vector3(PI, 0.0, 0.0))
		_add(root, MeshKit.cylinder(0.5, 0.5, 0.06, 8, Palette.GOLD), Vector3(sx * 0.5, hy, hz + 0.28), Vector3(0.0, 0.0, 0.0), Vector3(0.4, 1.0, 0.2))
	_add(root, MeshKit.cylinder(0.26, 0.3, 0.12, 8, Palette.GOLD), Vector3(0.0, hy + 0.35, hz - 0.1))
	for m: int in 5:
		var am: float = TAU * float(m) / 5.0
		_add(root, MeshKit.cone(0.06, 0.28, 5, Palette.GOLD), Vector3(sin(am) * 0.22, hy + 0.55, hz - 0.1 + cos(am) * 0.22))
