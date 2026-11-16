extends Area3D

@export var destination_label := "前往測試外島"

func _ready() -> void:
	$Label.text = destination_label + "\n中央瞄準 · 3 m 內右鍵"
