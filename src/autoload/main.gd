extends Node2D
## P0 占位主场景：Task 5 实装为固定步进循环的演示画面。

func _ready() -> void:
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.text = "HeroShowdown P0"
	add_child(label)
