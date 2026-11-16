extends SceneTree

const Storage = preload("res://scripts/inventory/player_storage.gd")
const MATERIAL = preload("res://items/testing/test_material.tres")
var failures := 0

func _initialize() -> void:
	var storage := Storage.new()
	storage.add_pickup(MATERIAL, 10)
	var catalog := {MATERIAL.item_id: MATERIAL}
	var original := storage.snapshot()
	for mode in ["unknown", "fraction", "capacity", "selection", "negative"]:
		var value := original.duplicate(true)
		match mode:
			"unknown": value.hotbar[0].item_id = &"missing_item"
			"fraction": value.hotbar[0].quantity = 1.5
			"capacity": value.backpack.pop_back()
			"selection": value.selected = 9
			"negative": value.hotbar[0].quantity = -1
		if storage.restore(value, catalog) or storage.snapshot() != original:
			failures += 1
			push_error("Invalid storage was accepted: " + mode)
	print("PASS: storage unknown ID, types, capacity, selection, atomic rejection" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
