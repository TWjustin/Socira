extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = "user://movement_close_test.cfg"
	root.add_child(scene)
	scene.player.set_physics_process(false)
	scene.save_path = "user://movement_close_test.cfg"
	if "--verify-close" in OS.get_cmdline_user_args():
		scene.load_game()
		check(scene.player.position.is_equal_approx(Vector3(9, 0, 12)), "正常關閉存檔後重進恢復")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.save_path))
		print("PASS: close and reopen" if failures == 0 else "FAIL: close and reopen")
		quit(0 if failures == 0 else 1)
		return
	await physics_frame
	for angle in [0.0, PI / 2.0]:
		for key in [KEY_W, KEY_A, KEY_S, KEY_D]:
			scene.player.position = Vector3.ZERO
			scene.player.yaw = angle
			var event := InputEventKey.new()
			event.keycode = key
			event.physical_keycode = key
			event.pressed = true
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			scene.player._physics_process(1.0 / 60.0)
			var local := Vector3.ZERO
			match key:
				KEY_W: local = Vector3.FORWARD
				KEY_S: local = Vector3.BACK
				KEY_A: local = Vector3.LEFT
				KEY_D: local = Vector3.RIGHT
			var expected := Basis(Vector3.UP, angle) * local * 6.0
			check(Vector2(scene.player.velocity.x, scene.player.velocity.z).is_equal_approx(Vector2(expected.x, expected.z)), "WASD 鏡頭相對方向 %s / %s" % [key, angle])
			var release := event.duplicate() as InputEventKey
			release.pressed = false
			Input.parse_input_event(release)
			Input.flush_buffered_events()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene.player._unhandled_input(escape)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc 釋放滑鼠")
	scene.player._physics_process(1.0 / 60.0)
	check(is_zero_approx(scene.player.velocity.x) and is_zero_approx(scene.player.velocity.z), "釋放滑鼠後停止移動")
	print("PASS: WASD at two camera headings and mouse release" if failures == 0 else "FAIL: movement")
	if failures != 0:
		quit(1)
		return
	scene.player.position = Vector3(9, 0, 12)
	# Exercise the real normal-close handler; the next invocation verifies it.
	scene.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
