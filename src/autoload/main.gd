extends Node2D
## P1 主场景：战场渲染 + 城堡 HP 与胜负 HUD。

const Events = preload("res://src/core/events.gd")
const BattleView = preload("res://src/view/battle_view.gd")

var _label: Label

func _ready() -> void:
	add_child(BattleView.new())
	_label = Label.new()
	_label.position = Vector2(16, 496)
	_label.text = "城堡 HP: 10"
	add_child(_label)
	Game.event_emitted.connect(_on_event)

func _on_event(event: Dictionary) -> void:
	match event.type:
		Events.LEAK:
			_label.text = "城堡 HP: %d" % event.data.castle_hp
		Events.VICTORY:
			_label.text = "胜利！城堡 HP %d——P1 完成" % event.data.castle_hp
		Events.DEFEAT:
			_label.text = "冒险失败……"
