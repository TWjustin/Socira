extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_check")

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func settle(frames: int = 12) -> void:
	for index in range(frames):
		await physics_frame

func run_check() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = "user://block_terrain_fixture.cfg"
	root.add_child(scene)
	await create_timer(0.2).timeout
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.travel()
	var terrain = scene.island.get_node("BlockTerrain")
	await settle()
	check(scene.player.is_on_floor() and absf(scene.player.position.y) < 0.02, "出入口平地安全")
	var ramps := 0
	for cell: Vector2i in terrain.cells:
		var info: Dictionary = terrain.cells[cell]
		check(is_equal_approx(float(info.height), roundf(float(info.height))), "方塊高度以 1 m 分層")
		if info.ramp != Vector2i.ZERO:
			ramps += 1
	check(ramps > 0, "已產生一格斜坡")
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	for point in [Vector2(8.5, -3.5), Vector2(-10.5, -9.5), Vector2(23.2, 0.5), Vector2(23.8, 0.5)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 6, point.y), Vector3(point.x, -3, point.y))
		query.exclude = [scene.player.get_rid(), scene.island.get_node("TestOre").get_rid()]
		var hit := space.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y - terrain.surface_height(point.x, point.y)) < 0.015, "方塊與斜坡外觀、碰撞高度一致")
	check(is_equal_approx(absf(terrain.surface_height(23.1, 0.5) - terrain.surface_height(23.9, 0.5)), 0.8), "斜坡水平 1m 上升 1m")
	# Measure free jump height away from edges that can cause early landing.
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	var free_peak := 0.0
	for index in range(60):
		await physics_frame
		free_peak = maxf(free_peak, scene.player.position.y)
		if index == 8:
			check(not scene.player.is_on_floor(), "平地跳躍測試的第二次按鍵確實在空中")
			key(KEY_SPACE, true)
			key(KEY_SPACE, false)
	check(free_peak > 1.08 and free_peak < 1.3, "跳高約 1.2m，空中再次按鍵不連跳")
	# A clean 1m vertical ledge on a flat patch, only in this test fixture.
	var ledge := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 1, 4)
	collision.shape = box
	ledge.add_child(collision)
	scene.island.add_child(ledge)
	ledge.position = Vector3(2.5, 0.5, 15)
	scene.player.position = Vector3(-2, 0.05, 15)
	scene.player.velocity = Vector3.ZERO
	scene.player.yaw = 0
	await settle()
	key(KEY_D, true)
	await settle(30)
	check(scene.player.position.x < 0 and scene.player.position.y < 0.1, "1m 直角落差不能自動走上")
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	await settle(50)
	key(KEY_D, false)
	check(scene.player.position.x > 1 and absf(scene.player.position.y - 1.0) < 0.02 and scene.player.is_on_floor(), "跳上 1m 平台並落地")
	scene.get_node("InventoryPanel").set_open(true)
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	await settle()
	check(absf(scene.player.position.y - 1.0) < 0.02, "背包開啟不跳躍")
	scene.get_node("InventoryPanel").set_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	await settle()
	check(absf(scene.player.position.y - 1.0) < 0.02, "游標釋放不跳躍")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ledge.queue_free()
	await settle()
	# Shoreline has an actual generated west-facing ramp at x=23, z=0.
	scene.player.position = Vector3(25, -0.95, 0.5)
	scene.player.velocity = Vector3.ZERO
	scene.player.yaw = 0
	await settle()
	key(KEY_A, true)
	await settle(80)
	key(KEY_A, false)
	check(scene.player.position.x < 20 and absf(scene.player.position.y) < 0.02, "不用跳就能沿一格斜坡由淺水回陸地")
	key(KEY_D, true)
	await settle(130)
	key(KEY_D, false)
	check(scene.player.position.x > 24 and absf(scene.player.position.y + 1.0) < 0.02, "可走進方塊海床淺水")
	check(terrain.shore_distance(scene.player.position.x, scene.player.position.z) < 4.0, "深水仍阻擋")
	# Confirm holding Space/repeated key events never launches a second jump.
	scene.player.position = Vector3(8, 0.05, -3)
	scene.player.velocity = Vector3.ZERO
	await settle()
	key(KEY_SPACE, true)
	var takeoffs := 0
	var grounded := true
	for index in range(90):
		await physics_frame
		if grounded and not scene.player.is_on_floor():
			takeoffs += 1
		grounded = scene.player.is_on_floor()
		key(KEY_SPACE, true, true)
	key(KEY_SPACE, false)
	check(takeoffs == 1, "長按 Space 不自動連跳")
	scene.player.position = Vector3(-17, terrain.surface_height(-17, -6) + 0.05, -6)
	scene.player.velocity = Vector3.ZERO
	await settle()
	scene.player.camera.look_at(Vector3(-10, 1, -9))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/block_terrain_walk.png")
	scene.player.set_physics_process(false)
	var overview := Camera3D.new()
	scene.add_child(overview)
	overview.position = Vector3(34, 30, 36)
	overview.fov = 55
	overview.look_at(Vector3.ZERO)
	overview.current = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/block_terrain_overview.png")
	scene.travel()
	check(not scene.on_island and scene.has_node("Land"), "返回原本土平地")
	scene.queue_free()
	await process_frame
	print("PASS: one-metre blocks, ramps, vertical ledge jump, no double/held jump, shallow water and return" if failures == 0 else "FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
