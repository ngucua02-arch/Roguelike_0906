extends Node
## 全局调度门面 + 冒险状态机：事件 3 选 1 → 备战（暂停的 sim）→ 战斗 → 结算
## → 下一关 / 冒险失败 / 冒险通关；restart_adventure 重开。
## 表现层只允许连接 event_emitted（消费）、调用 request_*/pick_event/continue_to_event/
## start_battle_phase/restart_adventure（请求）、读取 battle/battle_grid/castle_cell/
## level_def/run/phase/event_choices（只读约定）。

signal event_emitted(event: Dictionary)

const FixedStepper = preload("res://src/core/fixed_stepper.gd")
const BattleSim = preload("res://src/core/battle_sim.gd")
const RunState = preload("res://src/core/run/run_state.gd")

const Events = preload("res://src/core/events.gd")
const TICKS_PER_SECOND := 20.0
const LEVEL_IDS := ["level_1", "level_2", "level_3", "level_4", "level_5"]
const EVENT_IDS := ["attack_plus", "speed_plus", "gold_plus", "castle_plus", "cd_plus", "levelup", "elite_challenge", "free_chest"]

var phase := "prep"            # event/prep/battle/level_result/adventure_win/adventure_lose
var run = null                 # RunState（只读约定）
var level_def = null           # 当前 LevelDef（只读约定）
var event_choices: Array = []  # 当前事件 3 选 1（只读约定）
var battle_grid = null
var castle_cell := Vector2i.ZERO
var speed_multiplier := 1.0

var _stepper: FixedStepper = null
var _sim: BattleSim = null
var _running := false
var _event_pool: Array = []

func _ready() -> void:
	restart_adventure()

## ---- 冒险流程 ----

func restart_adventure(seed_value := 0) -> void:
	run = RunState.new(seed_value)
	phase = "prep"
	_begin_prep()

func pick_event(index: int) -> void:
	if phase != "event" or index < 0 or index >= event_choices.size():
		return
	run.apply_event(event_choices[index])
	_begin_prep()

func continue_to_event() -> void:
	if phase != "level_result":
		return
	run.next_level()
	_enter_event_or_prep()

func start_battle_phase() -> void:
	if phase != "prep":
		return
	_running = true
	phase = "battle"

## ---- 请求层（备战与战斗阶段均可）----

func request_deploy(def_id: String, cell: Vector2i) -> void:
	_emit(_sim.try_deploy(def_id, cell))

func request_upgrade(hero_id: int, stat: String) -> void:
	_emit(_sim.try_upgrade(hero_id, stat))

func request_skill(hero_id: int) -> void:
	_emit(_sim.try_skill(hero_id))

func toggle_speed() -> void:
	speed_multiplier = 2.0 if speed_multiplier == 1.0 else 1.0

## ---- 只读约定 ----

func battle() -> BattleSim:
	return _sim

## ---- 内部流程 ----

func _enter_event_or_prep() -> void:
	if run.level_index > 0:
		event_choices = run.draw_events(_get_event_pool(), 3)
		phase = "event"
	else:
		_begin_prep()

func _begin_prep() -> void:
	level_def = load("res://resources/levels/%s.tres" % LEVEL_IDS[run.level_index])
	var waves_config: Array = []
	for w in level_def.waves:
		var groups: Array = []
		for part in w.split(","):
			var p: PackedStringArray = part.split(":")
			groups.append({"def_id": p[0], "count": int(p[1]), "interval": float(p[2])})
		waves_config.append({"groups": groups})
	var cfg := {
		"roster": run.roster,
		"start_gold": run.gold,
		"castle_hp": run.castle_hp,
		"attack_mult": run.attack_mult * run.temp_attack_mult,
		"interval_mult": run.interval_mult,
		"cd_mult": run.cd_mult,
		"monster_hp_mult": level_def.hp_mult * run.elite_hp_mult,
		"gold_mult": run.elite_gold_mult,
		"waves": waves_config,
	}
	_sim = BattleSim.new(cfg)
	_stepper = FixedStepper.new(1.0 / TICKS_PER_SECOND)
	battle_grid = _sim.grid
	castle_cell = _sim.grid.waypoints[_sim.grid.waypoints.size() - 1]
	_running = false
	phase = "prep"

func _on_level_cleared() -> void:
	_running = false
	run.gold = _sim.gold
	run.castle_hp = _sim.castle_hp
	run.kills_total += _sim.kill_count
	run.ticks_total += _sim.tick_count
	run.roster.clear()
	for h in _sim.heroes:
		run.roster.append({
			"def_id": h.def.id, "cell": h.cell, "level": h.level,
			"damage_mult": h.damage_mult, "interval_mult": h.interval_mult,
		})
	if run.level_index >= LEVEL_IDS.size() - 1:
		phase = "adventure_win"
	else:
		phase = "level_result"

func _on_level_failed() -> void:
	_running = false
	run.kills_total += _sim.kill_count
	run.ticks_total += _sim.tick_count
	phase = "adventure_lose"

func _get_event_pool() -> Array:
	if _event_pool.is_empty():
		for id in EVENT_IDS:
			_event_pool.append(load("res://resources/events/%s.tres" % id))
	return _event_pool

func _emit(events: Array) -> void:
	for e in events:
		event_emitted.emit(e)

func _physics_process(delta: float) -> void:
	if not _running or phase != "battle":
		return
	var steps: int = _stepper.add_delta(delta * speed_multiplier)
	for i in steps:
		for event in _sim.step():
			event_emitted.emit(event)
			if event.type == Events.VICTORY:
				_on_level_cleared()
			elif event.type == Events.DEFEAT:
				_on_level_failed()
