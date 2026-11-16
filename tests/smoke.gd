extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

# Run with a window: Godot --path . --script res://tests/smoke.gd
# A test-specific path avoids overwriting the normal game save.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = "user://smoke_test.cfg"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(10, 5, 10), Vector3(10, -5, 10))
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty(), "土地碰撞存在")
	if not hit.is_empty():
		check(hit.collider == scene.get_node("Land"), "土地碰撞指向獨立場景")
		check(is_zero_approx(hit.position.y), "土地表面高度")
	scene.player.yaw = 0.0
	scene.player.pitch = -0.45
	scene.player.distance = 7.0
	scene.player.update_camera()
	check(scene.player.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "透視投影")
	scene.player.position = Vector3(100, 0, -100)
	scene.player._physics_process(0.016)
	# Vector3 stores float32; allow rounding at the 31.6 boundary.
	check(absf(scene.player.position.x) <= 31.6001, "X 邊界")
	check(absf(scene.player.position.z) <= 31.6001, "Z 邊界")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 100)
	scene.player._unhandled_input(motion)
	check(is_equal_approx(scene.player.yaw, -0.3), "滑鼠水平轉向")
	check(is_equal_approx(scene.player.pitch, -0.75), "滑鼠俯仰")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	scene.player._unhandled_input(wheel)
	check(is_equal_approx(scene.player.distance, 7.0), "滾輪不縮放鏡頭")
	scene.player.position = Vector3(5, 0, -7)
	scene.player.yaw = 1.0
	scene.player.pitch = -0.7
	scene.player.distance = 9.0
	scene.save_path = "user://smoke_test.cfg"
	check(scene.save_game() == OK, "存檔寫入")
	scene.player.position = Vector3.ZERO
	scene.player.yaw = 0.0
	scene.load_game()
	check(scene.player.position.is_equal_approx(Vector3(5, 0, -7)), "位置恢復")
	check(is_equal_approx(scene.player.yaw, 1.0), "轉向恢復")
	check(is_equal_approx(scene.player.pitch, -0.7), "俯仰恢復")
	check(is_equal_approx(scene.player.distance, 9.0), "縮放恢復")
	print("等待實際 60 秒自動存檔計時器…")
	scene.player.position = Vector3(-4, 0, 8)
	await create_timer(61.0).timeout
	scene.player.position = Vector3.ZERO
	scene.load_game()
	check(scene.player.position.is_equal_approx(Vector3(-4, 0, 8)), "60 秒自動存檔")
	var valid_path: String = scene.save_path
	scene.save_path = "user://missing_directory/invalid.cfg"
	check(scene.save_game() != OK, "存檔失敗回傳")
	check(scene.status.text.contains("失敗"), "存檔失敗提示")
	scene.save_path = valid_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.save_path))
	scene.queue_free()
	await process_frame
	print("PASS: camera, boundary, save/load, 60-second autosave, save failure" if failures == 0 else "FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
