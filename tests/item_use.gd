extends SceneTree

const TOOL = preload("res://items/testing/test_tool.tres")
const MATERIAL = preload("res://items/testing/test_material.tres")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = "user://item_use_fixture.cfg"
	root.add_child(scene)
	scene.player.set_physics_process(false)
	scene.player.set_process_unhandled_input(false)
	scene.player.position = Vector3.ZERO
	var target = scene.get_node("UseTestTarget")
	var interaction = scene.get_node("Interaction")
	await create_timer(0.2).timeout
	scene.player.camera.look_at(target.global_position)
	await physics_frame
	await physics_frame
	check(not interaction.use_selected() and scene.status.text.contains("空手"), "空手提示")
	scene.storage.hotbar.add_item(MATERIAL, 1)
	check(not interaction.use_selected() and scene.status.text.contains("不能敲擊"), "錯誤物品提示")
	scene.storage.hotbar.add_item(TOOL, 1)
	scene.storage.selected = 1
	var original: Dictionary = scene.storage.snapshot()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	check(target.hits == 0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "重新捕捉只捕捉不命中")
	Input.parse_input_event(click.duplicate())
	Input.flush_buffered_events()
	check(target.hits == 1 and scene.status.text.contains("命中"), "左鍵命中")
	check(target.material.albedo_color.is_equal_approx(Color("ffe49b")), "命中閃色")
	check(scene.storage.snapshot() == original, "工具與材料不消耗")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/item_use.png")
	await create_timer(0.4).timeout
	check(target.material.albedo_color.is_equal_approx(target.BASE_COLOR), "閃爍後復原")
	scene.get_node("InventoryPanel").set_open(true)
	interaction._unhandled_input(click)
	check(target.hits == 1 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "背包點擊不使用、不捕捉")
	scene.get_node("InventoryPanel").set_open(false)
	target.position.z = -4
	scene.player.camera.look_at(target.global_position)
	await physics_frame
	await physics_frame
	check(not interaction.use_selected() and scene.status.text.contains("太遠"), "距離拒絕提示")
	target.position.z = -1.5
	scene.player.camera.look_at(target.global_position)
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 2, 0.2)
	shape.shape = box
	blocker.add_child(shape)
	scene.add_child(blocker)
	blocker.position = Vector3(1, 0.75, -0.75)
	await physics_frame
	await physics_frame
	check(not interaction.use_selected() and scene.status.text.contains("遮擋"), "遮擋拒絕")
	check(target.hits == 1 and scene.storage.snapshot() == original, "拒絕不命中或扣物品")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	scene.player.camera.look_at(Vector3(20, 8, -10))
	check(not interaction.use_selected() and scene.status.text.contains("未瞄準"), "無目標提示")
	scene.player.camera.look_at(target.global_position)
	var right := click.duplicate() as InputEventMouseButton
	right.button_index = MOUSE_BUTTON_RIGHT
	interaction._unhandled_input(right)
	check(target.hits == 1, "右鍵不執行左鍵效果")
	scene.queue_free()
	await process_frame
	print("PASS: selected item, hit/flash, range, occlusion, cursor and UI isolation, no consumption" if failures == 0 else "FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
