extends Node2D
## P2 战场渲染（最糙版）：网格/路径/城堡/英雄/怪物色块 + 点击格子信号（布阵用）。
## 只消费 Game 的事件与只读状态，不改规则层状态。

signal cell_clicked(cell: Vector2i)

const Events = preload("res://src/core/events.gd")
const CELL := 48

var _monster_pos := {}   # id -> Vector2（格单位）
var _monster_boss := {}  # id -> bool

func _ready() -> void:
	Game.event_emitted.connect(_on_event)

func _on_event(event: Dictionary) -> void:
	match event.type:
		Events.SPAWN:
			_monster_pos[event.data.id] = event.data.pos
			_monster_boss[event.data.id] = event.data.get("def_id", "") == "ogre_lord"
		Events.MOVE:
			_monster_pos[event.data.id] = event.data.pos
		Events.LEAK, Events.MONSTER_DIED:
			_monster_pos.erase(event.data.id)
			_monster_boss.erase(event.data.id)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i((get_global_mouse_position() / CELL).floor())
		cell_clicked.emit(cell)

func _draw() -> void:
	if Game.battle_grid == null:
		return
	var grid = Game.battle_grid
	for x in grid.width + 1:
		draw_line(Vector2(x, 0) * CELL, Vector2(x, grid.height) * CELL, Color(0.22, 0.22, 0.24))
	for y in grid.height + 1:
		draw_line(Vector2(0, y) * CELL, Vector2(grid.width, y) * CELL, Color(0.22, 0.22, 0.24))
	for c in grid.path_cells.keys():
		if grid.in_bounds(c):
			draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)), Color(0.35, 0.28, 0.18))
	draw_rect(Rect2(Vector2(Game.castle_cell) * CELL, Vector2(CELL, CELL)), Color(0.85, 0.7, 0.2))
	var battle = Game.battle()
	if battle == null:
		return
	for h in battle.heroes:
		var p: Vector2 = Vector2(h.cell) * CELL + Vector2(CELL / 2.0, CELL / 2.0)
		draw_circle(p, 16.0, Color(0.3, 0.55, 1.0) if h.stun_timer <= 0.0 else Color(0.4, 0.4, 0.45))
		draw_string(ThemeDB.fallback_font, p + Vector2(-24, -20), "%s Lv%d" % [h.def.display_name, h.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	for id in _monster_pos.keys():
		var r := 18.0 if _monster_boss.get(id, false) else 12.0
		var col := Color(0.75, 0.15, 0.6) if _monster_boss.get(id, false) else Color(0.85, 0.25, 0.2)
		draw_circle(_monster_pos[id] * CELL, r, col)
