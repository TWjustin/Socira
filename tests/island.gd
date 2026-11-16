extends SceneTree

var failures := 0
const FIXTURE := "user://island_fixture.cfg"

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func settle() -> void:
	await physics_frame
	await physics_frame

func _run() -> void:
	if "--verify-close" in OS.get_cmdline_user_args():
		var reopened = load("res://scenes/main.tscn").instantiate()
		reopened.save_path = FIXTURE
		root.add_child(reopened)
		reopened.player.set_physics_process(false)
		check(not reopened.on_island and reopened.player.position.is_equal_approx(reopened.RETURN_POSITION), "正常關閉重進回土地")
		check(reopened.storage.hotbar.count_item(&"test_material") == 120, "正常關閉保留外島所得")
		check(reopened.get_node("TestPickups/TestMaterial").quantity == 37, "正常關閉保留土地狀態")
		DirAccess.remove_absolute(FIXTURE)
		print("PASS: island normal close recovery" if failures == 0 else "FAIL")
		quit(0 if failures == 0 else 1)
		return
	if FileAccess.file_exists(FIXTURE):
		DirAccess.remove_absolute(FIXTURE)
	var packed = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	scene.save_path = FIXTURE
	root.add_child(scene)
	scene.player.set_physics_process(false)
	await create_timer(0.3).timeout
	var interaction = scene.get_node("Interaction")
	var gate = scene.get_node("TravelGate")
	scene.player.position = scene.RETURN_POSITION
	scene.player.camera.look_at(gate.global_position)
	await settle()
	check(interaction.find_target() == gate, "出入口中央瞄準與 3m 判定")
	scene.get_node("InventoryPanel").set_open(true)
	check(interaction.find_target() == null, "背包開啟阻擋出入口")
	scene.get_node("InventoryPanel").set_open(false)
	scene.player.position.z = 0
	scene.player.camera.look_at(gate.global_position)
	await settle()
	check(interaction.find_target() == null, "出入口超距離拒絕")
	scene.player.position = scene.RETURN_POSITION
	scene.player.camera.look_at(gate.global_position)
	await settle()
	var obstacle := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.3)
	shape.shape = box
	obstacle.add_child(shape)
	scene.add_child(obstacle)
	obstacle.position = Vector3(8, 1, -4)
	await settle()
	check(interaction.find_target() == null, "出入口遮擋拒絕")
	obstacle.queue_free()
	await settle()
	var home_material = scene.get_node("TestPickups/TestMaterial")
	home_material.quantity = 37
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	interaction._unhandled_input(right)
	await process_frame
	await settle()
	check(scene.on_island, "右鍵出發")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/island_ui.png")
	check(not scene.has_node("TestPickups"), "土地物品不在外島")
	var material = scene.island.get_node("IslandMaterial")
	check(material.quantity == 120, "新島 120 材料")
	scene.player.position = Vector3(5, 0, -5)
	scene.player.camera.look_at(material.global_position)
	await settle()
	await create_timer(0.1).timeout
	check(not is_instance_valid(material) or material.is_queued_for_deletion(), "外島碰觸拾取入包")
	await process_frame
	check(scene.storage.hotbar.count_item(&"test_material") == 120, "取得數量正確")
	check(scene.save_game() == OK, "外島存檔")
	var data := ConfigFile.new()
	data.load(FIXTURE)
	check(data.get_value("world", "pickups")["TestMaterial"] == 37, "外島存檔保留土地餘量")
	check(data.get_value("player", "position").is_equal_approx(scene.RETURN_POSITION), "保存土地安全落點")
	scene.player.position = scene.RETURN_POSITION
	var return_gate = scene.island.get_node("TravelGate")
	scene.player.camera.look_at(return_gate.global_position)
	await settle()
	interaction._unhandled_input(right)
	await process_frame
	check(not scene.on_island and scene.get_node("TestPickups/TestMaterial").quantity == 37, "右鍵返回且土地狀態保留")
	scene.travel()
	check(scene.island.get_node("IslandMaterial").quantity == 120, "第二趟重設材料")
	scene.player.position = Vector3(-20, 0, 20)
	scene.save_game()
	scene.queue_free()
	await process_frame
	var restored = packed.instantiate()
	restored.save_path = FIXTURE
	root.add_child(restored)
	restored.player.set_physics_process(false)
	check(not restored.on_island and restored.player.position.is_equal_approx(restored.RETURN_POSITION), "外島退出重進回土地")
	check(restored.storage.hotbar.count_item(&"test_material") == 120, "重進保留物品")
	check(restored.get_node("TestPickups/TestMaterial").quantity == 37, "重進保留土地 Pickup")
	restored.queue_free()
	await process_frame
	print("PASS: island travel, interaction, reset, home isolation and save recovery" if failures == 0 else "FAIL: %d" % failures)
	if failures > 0:
		quit(1)
		return
	var closing = packed.instantiate()
	closing.save_path = FIXTURE
	root.add_child(closing)
	closing.travel()
	closing.player.position = Vector3(-20, 0, 20)
	closing._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
