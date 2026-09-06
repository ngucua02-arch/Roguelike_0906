extends Node2D
## P4 表现特效：伤害/金币/治疗/状态飘字、受击闪白、死亡淡出、远程弹道、技能圆环。
## 只消费 Game.event_emitted；不改规则层状态。怪物坐标自查（SPAWN/MOVE/LEAK/DIED）。

const Events = preload("res://src/core/events.gd")
const CELL := 48

var _mon_pos := {}        # id -> Vector2（格单位）
var _mon_def := {}        # id -> def_id
var _floats := []         # {pos: Vector2(px), text, color, age}
var _bullets := []        # {from: Vector2(px), to_id, to: Vector2(px), age, dur, tex_key}
var _flashes := []        # {pos, age}
var _rings := []          # {pos, age, color, max_r}

func _ready() -> void:
	Game.event_emitted.connect(_on_event)
	set_process(true)

func _mon_px(id: int) -> Vector2:
	return _mon_pos.get(id, Vector2.ZERO) * CELL

func _hero_px(hero_id: int) -> Vector2:
	var b = Game.battle()
	if b == null:
		return Vector2.ZERO
	for h in b.heroes:
		if h.id == hero_id:
			return Vector2(h.cell) * CELL + Vector2(CELL / 2.0, CELL / 2.0)
	return Vector2.ZERO

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
		Events.ATTACK:
			var tid: int = event.data.target_id
			var kind: String = "bullet"
			var hid: int = event.data.hero_id
			var b = Game.battle()
			if b != null:
				for h in b.heroes:
					if h.id == hid:
						kind = h.def.id
			var ranged := kind in ["archer", "mage", "cannonier"]
			if ranged and _mon_pos.has(tid):
				_bullets.append({"from": _hero_px(hid), "to_id": tid, "to": _mon_px(tid), "age": 0.0, "dur": 0.18, "kind": kind})
			else:
				_flashes.append({"pos": _mon_px(tid), "age": 0.0})
		Events.HURT:
			var pos: Vector2 = _mon_px(event.data.id)
			_flashes.append({"pos": pos, "age": 0.0})
			_floats.append({"pos": pos + Vector2(randf_range(-8, 8), -18), "text": str(event.data.damage), "color": Color(1, 0.95, 0.6), "age": 0.0})
		Events.MONSTER_DIED:
			_floats.append({"pos": _mon_px(event.data.id), "text": "✦", "color": Color(0.8, 0.8, 0.85), "age": 0.0})
		Events.HEALED:
			_floats.append({"pos": _mon_px(event.data.id) + Vector2(0, -14), "text": "+%d" % event.data.hp, "color": Color(0.4, 0.9, 0.4), "age": 0.0})
		Events.GOLD_GAINED:
			var pos := Vector2(770, 30)
			_floats.append({"pos": pos, "text": "+%d" % event.data.amount, "color": Color(1, 0.85, 0.2), "age": 0.0})
		Events.STUNNED:
			_floats.append({"pos": _hero_px(event.data.hero_id) + Vector2(0, -22), "text": "眩晕", "color": Color(0.7, 0.7, 0.8), "age": 0.0})
		Events.SKILL_CAST:
			var kind: String = event.data.kind
			var col := Color(1, 1, 1)
			match kind:
				"frost_ring": col = Color(0.4, 0.8, 1.0)
				"barrage": col = Color(1.0, 0.6, 0.2)
				"aegis": col = Color(1.0, 0.85, 0.3)
				"arrow_rain": col = Color(0.6, 1.0, 0.5)
			_rings.append({"pos": _hero_px(event.data.hero_id), "age": 0.0, "color": col, "max_r": 64.0})

func _process(delta: float) -> void:
	var dirty := false
	for f in _floats:
		f.age += delta
		f.pos.y -= 22.0 * delta
		dirty = true
	_floats = _floats.filter(func(f): return f.age < 0.9)
	for b in _bullets:
		b.age += delta
		if _mon_pos.has(b.to_id):
			b.to = _mon_px(b.to_id)
		dirty = true
	_bullets = _bullets.filter(func(b): return b.age < b.dur)
	for fl in _flashes:
		fl.age += delta
		dirty = true
	_flashes = _flashes.filter(func(fl): return fl.age < 0.18)
	for r in _rings:
		r.age += delta
		dirty = true
	_rings = _rings.filter(func(r): return r.age < 0.45)
	if dirty:
		queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for b in _bullets:
		var t: float = clampf(b.age / b.dur, 0.0, 1.0)
		var p: Vector2 = b.from.lerp(b.to, t)
		var col := Color(1, 1, 0.7)
		if b.kind == "mage":
			col = Color(0.5, 0.8, 1.0)
		elif b.kind == "cannonier":
			col = Color(1.0, 0.6, 0.3)
		draw_circle(p, 4.0 if b.kind != "cannonier" else 6.0, col)
	for fl in _flashes:
		var a: float = 1.0 - fl.age / 0.18
		draw_circle(fl.pos, 10.0 + 8.0 * fl.age / 0.18, Color(1, 1, 1, 0.55 * a))
	for r in _rings:
		var t: float = r.age / 0.45
		draw_arc(r.pos, 8.0 + r.max_r * t, 0, TAU, 40, Color(r.color.r, r.color.g, r.color.b, 1.0 - t), 3.0)
	for f in _floats:
		var a: float = 1.0 - f.age / 0.9
		draw_string(font, f.pos + Vector2(1, 1), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.6 * a))
		draw_string(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(f.color.r, f.color.g, f.color.b, a))
