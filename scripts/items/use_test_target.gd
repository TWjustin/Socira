extends StaticBody3D

var hits := 0
var flash: Tween
var material: StandardMaterial3D
const BASE_COLOR := Color("7086a7")

func _ready() -> void:
	material = StandardMaterial3D.new()
	material.albedo_color = BASE_COLOR
	$Visual.material_override = material

func receive_test_hit() -> void:
	hits += 1
	if flash != null:
		flash.kill()
	material.albedo_color = Color("ffe49b")
	$Label.text = "命中"
	flash = create_tween()
	flash.tween_property(material, "albedo_color", BASE_COLOR, 0.25)
	flash.tween_callback(func(): $Label.text = "測試方塊｜選取測試工具後左鍵")
