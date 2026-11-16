extends SceneTree

const Terrain = preload("res://scripts/island_terrain.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_check")

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func settle(frames: int = 12) -> void:
	for index in range(frames):
		await physics_frame

func run_check() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = "user://terrain_fixture.cfg"
	root.add_child(scene)
	scene.player.set_process_unhandled_input(false)
	await create_timer(0.2).timeout
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.travel()
	check(scene.on_island, "進入地形試作島")
	var terrain = scene.island.get_node("IslandTerrain")
	await settle()
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	for point in [Vector2(8, -3), Vector2(3, -8), Vector2(-10, -9), Vector2(10, 10), Vector2(24, 0)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 5, point.y), Vector3(point.x, -2, point.y))
		query.exclude = [scene.player.get_rid(), scene.island.get_node("TestOre").get_rid()]
		var hit := space.intersect_ray(query)
		check(not hit.is_empty() and hit.collider.name == "Ground", "地形可由上方命中碰撞")
		if not hit.is_empty():
			check(absf(hit.position.y - Terrain.height_at(point.x, point.y)) < 0.02, "網格頂點與碰撞高度一致")
	check(absf(scene.player.position.y) < 0.03 and scene.player.is_on_floor(), "出入口安全站立")
	# Walk over a whole hill using the normal CharacterBody controller.
	scene.player.position = Vector3(-17, 0.05, -9)
	scene.player.velocity = Vector3.ZERO
	scene.player.yaw = 0
	await settle()
	var peak := 0.0
	var airborne := 0
	key(KEY_D, true)
	for index in range(160):
		await physics_frame
		peak = maxf(peak, scene.player.position.y)
		if not scene.player.is_on_floor():
			airborne += 1
	key(KEY_D, false)
	print("hill: peak=%f end=%s airborne=%d" % [peak, scene.player.position, airborne])
	check(peak > 1.65 and scene.player.position.x > -3.0, "可步行上低丘並下坡")
	check(airborne < 5 and scene.player.position.y > -0.1, "下坡貼地不穿地")
	# Cross beach into shallow water, then keep pushing toward deep water.
	scene.player.position = Vector3(18, 0.1, 0)
	scene.player.velocity = Vector3.ZERO
	await settle()
	key(KEY_D, true)
	await settle(140)
	key(KEY_D, false)
	check(scene.player.position.x > 24.0, "能從沙灘走進淺水")
	check(scene.player.position.y < Terrain.SEA_LEVEL and scene.player.position.y > -0.7, "腳部浸入淺水且站在海床")
	check(Terrain.shore_distance(scene.player.position.x, scene.player.position.z) < Terrain.SHALLOW_WIDTH, "深水邊界阻擋角色")
	check(scene.player.is_on_floor(), "淺水中維持地面移動")
	scene.player.yaw = -PI * 0.5
	scene.player.pitch = -0.3
	scene.player.update_camera()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/coast_shallow.png")
	# Verify a direct inland path with the standard camera-relative movement.
	scene.player.position = Vector3(25, Terrain.height_at(25, 0) + 0.05, 0)
	scene.player.velocity = Vector3.ZERO
	scene.player.yaw = 0
	await settle()
	key(KEY_A, true)
	await settle(85)
	key(KEY_A, false)
	check(scene.player.position.x < 18 and scene.player.position.y > -0.1, "可從淺水走回陸地")
	for index in range(32):
		var angle := float(index) * TAU / 32.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var radius := Terrain.shoreline_radius(angle)
		var query := PhysicsRayQueryParameters3D.create(direction * (radius + 2.0) + Vector3.UP, direction * (radius + 6.0) + Vector3.UP)
		query.exclude = [scene.player.get_rid()]
		var hit := space.intersect_ray(query)
		check(not hit.is_empty() and hit.collider.name == "DeepWaterBoundary", "環島深水碰撞無缺口")
	# Independent overview camera only for visual verification.
	scene.player.set_physics_process(false)
	var overview := Camera3D.new()
	scene.add_child(overview)
	overview.position = Vector3(34, 30, 36)
	overview.fov = 55
	overview.look_at(Vector3.ZERO)
	overview.current = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/coast_overview.png")
	check(is_equal_approx(terrain.get_node("Water").position.y, Terrain.SEA_LEVEL), "海面固定於淺水高度")
	scene.travel()
	check(not scene.on_island and is_equal_approx(scene.player.floor_snap_length, 0.1), "回本土還原移動貼地設定")
	check(scene.has_node("Land"), "本土原平地保留")
	scene.queue_free()
	await process_frame
	print("PASS: island mesh collision, slopes, shallow wading, deep boundary and return" if failures == 0 else "FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
