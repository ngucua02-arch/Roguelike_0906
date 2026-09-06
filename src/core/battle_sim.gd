extends RefCounted
## 战斗模拟编排器（20tps 确定性步进）。P2：多英雄部署/索敌攻击、技能请求、
## 局内经济、波次调度、怪物特性（萨满治疗/踩踏眩晕）、漏怪扣城堡（boss 扣 3）、
## 胜负一次锁定。请求入口 try_deploy/try_upgrade/try_skill，失败也以事件回执。

const Events = preload("res://src/core/events.gd")
const GridScript = preload("res://src/core/battle/grid.gd")
const Entities = preload("res://src/core/battle/entities.gd")
const Targeting = preload("res://src/core/battle/targeting.gd")
const EconomyScript = preload("res://src/core/battle/economy.gd")
const SkillSystem = preload("res://src/core/battle/skill_system.gd")
const WaveDirector = preload("res://src/core/battle/wave_director.gd")
const DefaultDefs = preload("res://src/core/battle/default_defs.gd")

const DT := 1.0 / 20.0  # 每 tick 步长（秒），与 Game.TICKS_PER_SECOND 对应

const GRID_W := 16
const GRID_H := 10
const DEFAULT_WAYPOINTS: Array = [
	Vector2i(-1, 1), Vector2i(13, 1), Vector2i(13, 8), Vector2i(2, 8),
]

var tick_count := 0
var castle_hp: int
var result := ""  # "" / "victory" / "defeat"
var grid
var economy
var director
var heroes: Array = []        # Array[Entities.Hero]
var monsters: Array = []      # Array[Entities.Monster]
var hero_defs: Array = []     # Array[HeroDef]
var monster_def_by_id := {}   # id -> MonsterDef

var gold: int:
	get:
		return economy.gold

var attack_mult := 1.0
var interval_mult := 1.0
var cd_mult := 1.0
var gold_mult := 1.0
var monster_hp_mult := 1.0
var kill_count := 0

var _next_hero_id := 1
var _next_monster_id := 1
var _occupied := {}           # Vector2i -> Hero
var _announced_wave := -1

func _init(config: Dictionary = {}) -> void:
	grid = GridScript.new(GRID_W, GRID_H, config.get("waypoints", DEFAULT_WAYPOINTS))
	castle_hp = config.get("castle_hp", 10)
	economy = EconomyScript.new(config.get("start_gold", 100))
	hero_defs = config.get("hero_defs", DefaultDefs.heroes())
	for d in config.get("monster_defs", DefaultDefs.monsters()):
		monster_def_by_id[d.id] = d
	director = WaveDirector.new(config.get("waves", DefaultDefs.waves()))
	attack_mult = config.get("attack_mult", 1.0)
	interval_mult = config.get("interval_mult", 1.0)
	cd_mult = config.get("cd_mult", 1.0)
	gold_mult = config.get("gold_mult", 1.0)
	monster_hp_mult = config.get("monster_hp_mult", 1.0)
	for r in config.get("roster", []):
		var def0 = _hero_def_by_id(r.def_id)
		if def0 == null:
			continue
		var h0 = Entities.Hero.new(_next_hero_id, def0, r.cell)
		_next_hero_id += 1
		h0.level = r.level
		h0.damage_mult = r.damage_mult
		h0.interval_mult = r.interval_mult
		h0.global_damage_mult = attack_mult
		h0.global_interval_mult = interval_mult
		heroes.append(h0)
		_occupied[r.cell] = h0
	director.start_next_wave()  # 开局即第一波

func step() -> Array:
	if result != "":
		return []  # 胜负已锁定：战斗冻结，不再产出任何事件
	tick_count += 1
	var events: Array = [{"type": Events.TICK, "data": {"tick": tick_count}}]
	if director.index != _announced_wave:
		_announced_wave = director.index
		events.append({"type": Events.WAVE_STARTED, "data": {"index": director.index + 1, "total": director.wave_count()}})
	for def_id in director.tick(DT):
		_spawn(def_id, events)
	_step_move(events)
	_step_heroes(events)
	_step_traits(events)
	_check_wave_and_result(events)
	return events

# ---- 请求层（表现层经 Game 调用；返回待广播事件，失败含 buy_failed/skill_failed）----

func try_deploy(def_id: String, cell: Vector2i) -> Array:
	var events: Array = []
	var def = _hero_def_by_id(def_id)
	var reason := ""
	if def == null:
		reason = "no_such_def"
	elif not economy.can_afford(def.cost):
		reason = "no_gold"
	elif not grid.in_bounds(cell):
		reason = "out_of_bounds"
	elif grid.is_path(cell):
		reason = "on_path"
	elif _occupied.has(cell):
		reason = "occupied"
	elif not _has_path_neighbor(cell):
		reason = "not_adjacent_path"
	if reason != "":
		events.append({"type": Events.BUY_FAILED, "data": {"reason": reason, "def_id": def_id, "cell": cell}})
		return events
	economy.spend(def.cost)
	var h = Entities.Hero.new(_next_hero_id, def, cell)
	_next_hero_id += 1
	h.global_damage_mult = attack_mult
	h.global_interval_mult = interval_mult
	heroes.append(h)
	_occupied[cell] = h
	events.append({"type": Events.DEPLOYED, "data": {"hero_id": h.id, "def_id": def_id, "cell": cell}})
	return events

func try_upgrade(hero_id: int, stat: String) -> Array:
	var events: Array = []
	var h = _hero_by_id(hero_id)
	var reason := ""
	if h == null:
		reason = "no_such_hero"
	elif stat != "damage" and stat != "interval":
		reason = "bad_stat"
	elif not economy.can_afford(EconomyScript.UPGRADE_COST):
		reason = "no_gold"
	if reason != "":
		events.append({"type": Events.BUY_FAILED, "data": {"reason": reason, "hero_id": hero_id, "stat": stat}})
		return events
	economy.spend(EconomyScript.UPGRADE_COST)
	h.level += 1
	if stat == "damage":
		h.damage_mult *= EconomyScript.UPGRADE_DAMAGE_MULT
	else:
		h.interval_mult *= EconomyScript.UPGRADE_INTERVAL_MULT
	events.append({"type": Events.UPGRADED, "data": {"hero_id": hero_id, "stat": stat, "level": h.level}})
	return events

func try_skill(hero_id: int) -> Array:
	var events: Array = []
	var h = _hero_by_id(hero_id)
	var reason := ""
	if h == null:
		reason = "no_such_hero"
	elif h.def.skill_kind == "":
		reason = "no_skill"
	elif h.skill_cd > 0.0:
		reason = "cooldown"
	elif h.stun_timer > 0.0:
		reason = "stunned"
	if reason != "":
		events.append({"type": Events.SKILL_FAILED, "data": {"hero_id": hero_id, "reason": reason}})
		return events
	var ev: Array = SkillSystem.cast(self, h)
	if ev.is_empty():
		events.append({"type": Events.SKILL_FAILED, "data": {"hero_id": hero_id, "reason": "no_target"}})
		return events
	h.skill_cd = h.def.skill_cooldown * cd_mult  # 释放成功才转 CD
	return ev

# ---- 规则步进 ----

func _spawn(def_id: String, events: Array) -> void:
	var def = monster_def_by_id.get(def_id)
	if def == null:
		return
	var m = Entities.Monster.new(_next_monster_id, def, monster_hp_mult)
	_next_monster_id += 1
	monsters.append(m)
	events.append({"type": Events.SPAWN, "data": {"id": m.id, "def_id": def_id, "pos": grid.point_at(m.path_dist)}})

func _step_move(events: Array) -> void:
	for m in monsters:
		if not m.alive:
			continue
		m.slow_timer = maxf(0.0, m.slow_timer - DT)
		m.path_dist += m.move_speed() * DT
		if m.path_dist >= grid.path_length:
			m.alive = false
			castle_hp -= m.def.leak_damage
			events.append({"type": Events.LEAK, "data": {"id": m.id, "castle_hp": castle_hp}})
		else:
			events.append({"type": Events.MOVE, "data": {"id": m.id, "pos": grid.point_at(m.path_dist)}})

func _step_heroes(events: Array) -> void:
	for h in heroes:
		h.attack_cd = maxf(0.0, h.attack_cd - DT)
		h.skill_cd = maxf(0.0, h.skill_cd - DT)
		h.stun_timer = maxf(0.0, h.stun_timer - DT)
		h.haste_timer = maxf(0.0, h.haste_timer - DT)
		h.aegis_timer = maxf(0.0, h.aegis_timer - DT)
		if h.stun_timer > 0.0:
			continue  # 眩晕：不索敌不攻击，冷却照常回落
		var target = Targeting.nearest_in_range(monsters, grid, grid.cell_to_pos(h.cell), h.def.range_tiles)
		if target == null or h.attack_cd > 0.0:
			continue
		h.attack_cd = h.attack_interval()
		events.append({"type": Events.ATTACK, "data": {"hero_id": h.id, "target_id": target.id, "damage": h.damage()}})
		apply_damage(target, h.damage(), events)

func _step_traits(events: Array) -> void:
	for m in monsters:
		if not m.alive:
			continue
		if m.def.heal_radius > 0.0:
			m.heal_timer -= DT
			if m.heal_timer <= 0.0:
				m.heal_timer += m.def.heal_interval
				var mp: Vector2 = grid.point_at(m.path_dist)
				for t in monsters:
					if t.alive and t.hp < t.max_hp and mp.distance_to(grid.point_at(t.path_dist)) <= m.def.heal_radius:
						t.hp = mini(t.max_hp, t.hp + m.def.heal_amount)
						events.append({"type": Events.HEALED, "data": {"id": t.id, "hp": t.hp}})
		if m.def.stomp_radius > 0.0:
			m.stomp_timer -= DT
			if m.stomp_timer <= 0.0:
				m.stomp_timer += m.def.stomp_interval
				var bp: Vector2 = grid.point_at(m.path_dist)
				for h in heroes:
					if h.aegis_timer <= 0.0 and h.stun_timer <= 0.0 and bp.distance_to(grid.cell_to_pos(h.cell)) <= m.def.stomp_radius:
						h.stun_timer = m.def.stomp_stun_duration
						events.append({"type": Events.STUNNED, "data": {"hero_id": h.id, "duration": m.def.stomp_stun_duration}})

func _check_wave_and_result(events: Array) -> void:
	if castle_hp <= 0:
		result = "defeat"
		events.append({"type": Events.DEFEAT, "data": {"castle_hp": 0}})
		return
	if director.phase == "wave" and director.exhausted() and _alive_count() == 0:
		var bonus: int = director.current_bonus()
		economy.gain(bonus)
		events.append({"type": Events.GOLD_GAINED, "data": {"amount": bonus, "total": economy.gold, "reason": "wave"}})
		events.append({"type": Events.WAVE_CLEARED, "data": {"index": director.index + 1, "bonus": bonus}})
		var r: Dictionary = director.announce_clear()
		if r.is_last:
			result = "victory"
			events.append({"type": Events.VICTORY, "data": {"castle_hp": castle_hp}})

func apply_damage(m, dmg: int, events: Array) -> void:
	var real: int = maxi(0, dmg - m.def.armor)
	m.hp -= real
	events.append({"type": Events.HURT, "data": {"id": m.id, "hp": maxi(m.hp, 0), "damage": real}})
	if m.hp <= 0 and m.alive:
		m.alive = false
		kill_count += 1
		events.append({"type": Events.MONSTER_DIED, "data": {"id": m.id}})
		var drop: int = int(ceil(m.def.gold_drop * gold_mult))
		economy.gain(drop)
		events.append({"type": Events.GOLD_GAINED, "data": {"amount": drop, "total": economy.gold, "reason": "kill"}})

func _alive_count() -> int:
	var n := 0
	for m in monsters:
		if m.alive:
			n += 1
	return n

func _has_path_neighbor(cell: Vector2i) -> bool:
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if grid.is_path(cell + off):
			return true
	return false

func _hero_by_id(hero_id: int):
	for h in heroes:
		if h.id == hero_id:
			return h
	return null

func _hero_def_by_id(def_id: String):
	for d in hero_defs:
		if d.id == def_id:
			return d
	return null
