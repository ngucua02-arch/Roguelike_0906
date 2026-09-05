extends RefCounted
## 战斗模拟（20tps 确定性步进）。P1：单英雄自动索敌 + 单种怪沿路径推进
## + 漏怪扣城堡 + 胜负一次锁定。全部配置可省略，键见 P1 计划 Global Constraints。

const Events = preload("res://src/core/events.gd")
const GridScript = preload("res://src/core/battle/grid.gd")

const DT := 1.0 / 20.0  # 每 tick 步长（秒），与 Game.TICKS_PER_SECOND 对应

const GRID_W := 16
const GRID_H := 10
const DEFAULT_WAYPOINTS: Array = [
	Vector2i(-1, 1), Vector2i(13, 1), Vector2i(13, 8), Vector2i(2, 8),
]
const DEFAULT_HERO_CELL := Vector2i(12, 2)

class Monster:
	extends RefCounted
	var id: int
	var def: Dictionary
	var path_dist := 0.0
	var hp: int
	var alive := true
	func _init(p_id: int, p_def: Dictionary) -> void:
		id = p_id
		def = p_def
		hp = p_def.max_hp

var tick_count := 0
var castle_hp: int
var result := ""  # "" / "victory" / "defeat"
var grid
var hero: Dictionary
var monster_def: Dictionary
var monsters: Array = []  # Array[Monster]（含已离场的，按 alive 区分）

var _total_spawns: int
var _spawn_interval: float
var _spawned := 0
var _spawn_timer := 0.0

func _init(config: Dictionary = {}) -> void:
	grid = GridScript.new(GRID_W, GRID_H, config.get("waypoints", DEFAULT_WAYPOINTS))
	castle_hp = config.get("castle_hp", 10)
	hero = {
		"cell": config.get("hero_cell", DEFAULT_HERO_CELL),
		"damage": config.get("hero_damage", 12),
		"attack_interval": config.get("hero_attack_interval", 0.8),
		"range_tiles": config.get("hero_range_tiles", 1.5),
		"cooldown": 0.0,
	}
	monster_def = {
		"max_hp": config.get("monster_max_hp", 30),
		"move_speed": config.get("monster_move_speed", 1.2),
		"armor": config.get("monster_armor", 0),
	}
	_total_spawns = config.get("total_spawns", 10)
	_spawn_interval = config.get("spawn_interval", 2.5)

func step() -> Array:
	if result != "":
		return []  # 胜负已锁定：战斗冻结，不再产出任何事件
	tick_count += 1
	var events: Array = [{"type": Events.TICK, "data": {"tick": tick_count}}]
	_step_spawn(events)
	_step_move(events)
	_step_attack(events)
	_check_result(events)
	return events

func _step_spawn(events: Array) -> void:
	_spawn_timer -= DT
	while _spawn_timer <= 0.0 and _spawned < _total_spawns:
		_spawned += 1
		var m := Monster.new(_spawned, monster_def)
		monsters.append(m)
		events.append({"type": Events.SPAWN, "data": {"id": m.id, "pos": grid.point_at(m.path_dist)}})
		_spawn_timer += _spawn_interval

func _step_move(events: Array) -> void:
	for m in monsters:
		if not m.alive:
			continue
		m.path_dist += monster_def.move_speed * DT
		if m.path_dist >= grid.path_length:
			m.alive = false
			castle_hp -= 1
			events.append({"type": Events.LEAK, "data": {"id": m.id, "castle_hp": castle_hp}})
		else:
			events.append({"type": Events.MOVE, "data": {"id": m.id, "pos": grid.point_at(m.path_dist)}})

func _resolved_count() -> int:
	var n := 0
	for m in monsters:
		if not m.alive:
			n += 1
	return n

func _check_result(events: Array) -> void:
	if castle_hp <= 0:
		result = "defeat"
		events.append({"type": Events.DEFEAT, "data": {"castle_hp": 0}})
		return
	if _spawned >= _total_spawns and _resolved_count() >= _total_spawns:
		result = "victory"
		events.append({"type": Events.VICTORY, "data": {"castle_hp": castle_hp}})


func _step_attack(events: Array) -> void:
	hero.cooldown = maxf(0.0, hero.cooldown - DT)
	if hero.cooldown > 0.0:
		return  # 冷却中：不索敌不结算
	var target = _nearest_monster_in_range()
	if target == null:
		return  # 无目标：冷却停在 0，目标进射程立即开火
	var damage: int = maxi(0, hero.damage - target.def.armor)
	target.hp -= damage
	hero.cooldown = hero.attack_interval  # 释放成功才转 CD
	events.append({"type": Events.ATTACK, "data": {"target_id": target.id, "damage": damage}})
	events.append({"type": Events.HURT, "data": {"id": target.id, "hp": maxi(target.hp, 0), "damage": damage}})
	if target.hp <= 0:
		target.alive = false
		events.append({"type": Events.MONSTER_DIED, "data": {"id": target.id}})

func _nearest_monster_in_range():
	var best = null
	var best_d := INF
	var hero_pos: Vector2 = grid.cell_to_pos(hero.cell)
	for m in monsters:
		if not m.alive:
			continue
		var d := hero_pos.distance_to(grid.point_at(m.path_dist))
		if d < best_d:
			best_d = d
			best = m
	if best == null or best_d > hero.range_tiles:
		return null
	return best
