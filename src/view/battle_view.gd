extends Node2D
## P4 战场渲染：Kenney 素材单位/路面/城堡 + 主题底色 + 布阵点击。
## 素材缺失自动回退色块。只消费 Game 的事件与只读状态，不改规则层状态。

signal cell_clicked(cell: Vector2i)

const Events = preload("res://src/core/events.gd")
const Catalog = preload("res://src/view/sprite_catalog.gd")
const FxScript = preload("res://src/view/fx.gd")
const CELL := 48

var _mon_pos := {}     # id -> Vector2（格单位）
var _mon_def := {}     # id -> def_id
var _slowed := {}      # id -> true（受减速后短暂显示蓝圈）
var _fx: Node2D
var place_mode := false  # 布阵模式：合法格高亮

func _ready() -> void:
	Game.event_emitted.connect(_on_event)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 像素风锐利
	_fx = FxScript.new()
	add_child(_fx)

func _on_event(event: Dictionary) -> void:
	match event.type:
		Events.SPAWN:
			_mon_pos[event.data.id] = event.data.pos
			_mon_def[event.data.id] = event.data.get("def_id", "")
		Events.MOVE:
			_mon_pos[event.data.id] = event.data.pos
		Events.LEAK, Events.MONSTER_DIED:
			_mon_pos.erase(event.data.id)
			_mon_def.erase(event.data.id)
			_slowed.erase(event.data.id)
		Events.SLOWED:
			_slowed[event.data.id] = true
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i((get_global_mouse_position() / CELL).floor())
		cell_clicked.emit(cell)

func _draw_tex(key: String, center: Vector2, size: float, tint := Color.WHITE) -> bool:
	var tex: Texture2D = Catalog.texture(key)
	if tex == null:
		return false
	draw_texture_rect(tex, Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size)), false, tint)
	return true

func _draw() -> void:
	if Game.battle_grid == null:
		return
	var grid = Game.battle_grid
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 560)), Game.level_def.theme_color.darkened(0.35))
	var path_tex: Texture2D = Catalog.texture("path")
	for c in grid.path_cells.keys():
		if grid.in_bounds(c):
			if path_tex != null:
				draw_texture_rect(path_tex, Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)), false)
			else:
				draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)), Color(0.35, 0.28, 0.18))
	if place_mode:
		var occupied := {}
		var b = Game.battle()
		if b != null:
			for h in b.heroes:
				occupied[h.cell] = true
		for yy in grid.height:
			for xx in grid.width:
				var c := Vector2i(xx, yy)
				if grid.is_path(c) or occupied.has(c):
					continue
				var near_path := false
				for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if grid.is_path(c + off):
						near_path = true
						break
				if near_path:
					var r := Rect2(Vector2(c) * CELL + Vector2(3, 3), Vector2(CELL - 6, CELL - 6))
					draw_rect(r, Color(0.3, 1.0, 0.4, 0.16))
					draw_rect(r, Color(0.4, 1.0, 0.5, 0.7), false, 2.0)
	for x in grid.width + 1:
		draw_line(Vector2(x, 0) * CELL, Vector2(x, grid.height) * CELL, Color(0, 0, 0, 0.18))
	for y in grid.height + 1:
		draw_line(Vector2(0, y) * CELL, Vector2(grid.width, y) * CELL, Color(0, 0, 0, 0.18))
	# 城堡
	var castle_px: Vector2 = Vector2(Game.castle_cell) * CELL + Vector2(CELL / 2.0, CELL / 2.0)
	if not _draw_tex("castle", castle_px, CELL - 2.0):
		draw_rect(Rect2(Vector2(Game.castle_cell) * CELL, Vector2(CELL, CELL)), Color(0.85, 0.7, 0.2))
	# 英雄与怪物
	var battle = Game.battle()
	if battle != null:
		var font := ThemeDB.fallback_font
		for h in battle.heroes:
			var hp: Vector2 = Vector2(h.cell) * CELL + Vector2(CELL / 2.0, CELL / 2.0)
			var tint := Color.WHITE if h.stun_timer <= 0.0 else Color(0.45, 0.45, 0.5)
			if not _draw_tex("hero:" + h.def.id, hp, CELL - 4.0, tint):
				draw_circle(hp, 16.0, Color(0.3, 0.55, 1.0) * tint)
			draw_string(font, hp + Vector2(-26, -22), "%s Lv%d" % [h.def.display_name, h.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9))
		for id in _mon_pos.keys():
			var def_id: String = _mon_def.get(id, "")
			var boss := def_id == "ogre_lord"
			var size := 44.0 if boss else 34.0
			var mp: Vector2 = _mon_pos[id] * CELL
			var mtint := Color(0.6, 0.8, 1.0) if _slowed.has(id) else Color.WHITE
			if not _draw_tex("mon:" + def_id, mp, size, mtint):
				draw_circle(mp, 12.0, Color(0.85, 0.25, 0.2) * mtint)
			if _slowed.has(id):
				draw_arc(mp, size / 2.0 + 2.0, 0, TAU, 24, Color(0.4, 0.8, 1.0, 0.8), 2.0)
