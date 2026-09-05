extends Node2D
## P0 主场景：验证实时循环活着——每秒 tick 计数 +20，画面显示计数。

const Events = preload("res://src/core/events.gd")

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.text = "HeroShowdown P0"
	add_child(_label)
	Game.event_emitted.connect(_on_event)

func _on_event(event: Dictionary) -> void:
	if event.type != Events.TICK:
		return
	var t: int = event.data.tick
	if t % 20 == 0:
		_label.text = "P0 运行中 tick=%d" % t
