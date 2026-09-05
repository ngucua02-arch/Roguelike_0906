extends Node2D
## P1 战场渲染（最糙版）：网格线/路径格/城堡/英雄/怪物色块。
## 只消费 Game 的事件与只读布局，不改规则层状态。

const Events = preload("res://src/core/events.gd")
const CELL := 48

var _monster_pos := {}  # id -> Vector2（格单位）

func _ready() -> void:
	Game.event_emitted.connect(_on_event)

func _on_event(event: Dictionary) -> void:
	match event.type:
		Events.SPAWN:
			_monster_pos[event.data.id] = event.data.pos
		Events.MOVE:
			_monster_pos[event.data.id] = event.data.pos
		Events.LEAK, Events.MONSTER_DIED:
			_monster_pos.erase(event.data.id)
	queue_redraw()

func _draw() -> void:
	if Game.battle_grid == null:
		return
	var grid = Game.battle_grid
	for x in grid.width + 1:
		draw_line(Vector2(x, 0) * CELL, Vector2(x, grid.height) * CELL, Color(0.22, 0.22, 0.24))
	for y in grid.height + 1:
		draw_line(Vector2(0, y) * CELL, Vector2(grid.width, y) * CELL, Color(0.22, 0.22, 0.24))
	for cell in grid.path_cells.keys():
		if grid.in_bounds(cell):
			draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), Color(0.35, 0.28, 0.18))
	draw_rect(Rect2(Vector2(Game.castle_cell) * CELL, Vector2(CELL, CELL)), Color(0.85, 0.7, 0.2))
	var hero_px: Vector2 = Vector2(Game.hero_cell) * CELL + Vector2(CELL / 2.0, CELL / 2.0)
	draw_circle(hero_px, 16.0, Color(0.3, 0.55, 1.0))
	for id in _monster_pos.keys():
		draw_circle(_monster_pos[id] * CELL, 12.0, Color(0.85, 0.25, 0.2))
