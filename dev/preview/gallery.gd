extends SceneTree
## Dev-only: renders a gallery of generated assets to user-chosen PNG. Run: godot --path . -s dev/preview/gallery.gd -- out.png

func _initialize() -> void:
	var root3d: Node3D = Node3D.new()
	get_root().add_child(root3d)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#2a2a44")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.7)
	e.ambient_light_energy = 0.6
	env.environment = e
	root3d.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	root3d.add_child(sun)
	var h: HanumanModel = HanumanModel.new()
	root3d.add_child(h)
	h.build()
	h.position = Vector3(0, 0, 0)
	var x: float = 2.0
	for v: StringName in [&"spear", &"archer", &"brute", &"lankini"]:
		var r: Node3D = RakshasaModel.build(v)
		r.position = Vector3(x, 0, 0)
		root3d.add_child(r)
		x += 2.0
	var house: Node3D = ArchitectureKit.tier_house(Vector3(4, 5, 4), 7)
	house.position = Vector3(-5, 0, -5)
	root3d.add_child(house)
	var gop: Node3D = ArchitectureKit.gopuram(Vector3(3, 8, 3), 3)
	gop.position = Vector3(3, 0, -7)
	root3d.add_child(gop)
	var t1: Node3D = NatureKit.ashoka_tree(1)
	t1.position = Vector3(-4, 0, 2)
	root3d.add_child(t1)
	var t2: Node3D = NatureKit.shimshapa_tree(2)
	t2.position = Vector3(10, 0, -3)
	root3d.add_child(t2)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 16.0
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.position = Vector3(3, 0, -1) + Vector3(0, 0, 1).rotated(Vector3.RIGHT, deg_to_rad(-35.264)).rotated(Vector3.UP, deg_to_rad(45)) * 40.0
	root3d.add_child(cam)
	cam.make_current()
	for i: int in 8:
		await process_frame
	var img: Image = get_root().get_texture().get_image()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	img.save_png(args[0] if args.size() > 0 else "/tmp/gallery.png")
	quit()
