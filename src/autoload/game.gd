extends Node
## 全局调度门面：固定 20tps 步进规则层 + 玩家请求转发 + ×2 加速。
## 表现层只允许连接 event_emitted（消费）、调用 request_*（请求）、
## 读取 battle/battle_grid/castle_cell（只读约定），不得改规则层状态。

signal event_emitted(event: Dictionary)

const FixedStepper = preload("res://src/core/fixed_stepper.gd")
const BattleSim = preload("res://src/core/battle_sim.gd")

const TICKS_PER_SECOND := 20.0

var _stepper: FixedStepper = null
var _sim: BattleSim = null
var running := false
var speed_multiplier := 1.0     # 1.0 / 2.0
var battle_grid = null          # 只读：Grid（网格/路径）
var castle_cell := Vector2i.ZERO  # 只读：城堡格（路径终点）

func _ready() -> void:
	start_battle()

func _build_config() -> Dictionary:
	var hero_defs: Array = []
	for p in ["swordsman", "archer", "mage", "cannonier", "priest"]:
		hero_defs.append(load("res://resources/heroes/%s.tres" % p))
	var monster_defs: Array = []
	for p in ["goblin", "wolf", "orc", "shaman", "golem", "ogre_lord"]:
		monster_defs.append(load("res://resources/monsters/%s.tres" % p))
	return {"hero_defs": hero_defs, "monster_defs": monster_defs}

func start_battle() -> void:
	_sim = BattleSim.new(_build_config())
	_stepper = FixedStepper.new(1.0 / TICKS_PER_SECOND)
	battle_grid = _sim.grid
	castle_cell = _sim.grid.waypoints[_sim.grid.waypoints.size() - 1]
	running = true

func stop_battle() -> void:
	running = false

## 只读战场（英雄列表/金币/波次等经 battle 查询，禁止改其状态）
func battle() -> BattleSim:
	return _sim

func toggle_speed() -> void:
	speed_multiplier = 2.0 if speed_multiplier == 1.0 else 1.0

func request_deploy(def_id: String, cell: Vector2i) -> void:
	_emit(_sim.try_deploy(def_id, cell))

func request_upgrade(hero_id: int, stat: String) -> void:
	_emit(_sim.try_upgrade(hero_id, stat))

func request_skill(hero_id: int) -> void:
	_emit(_sim.try_skill(hero_id))

func _emit(events: Array) -> void:
	for e in events:
		event_emitted.emit(e)

func _physics_process(delta: float) -> void:
	if not running:
		return
	var steps: int = _stepper.add_delta(delta * speed_multiplier)
	for i in steps:
		for event in _sim.step():
			event_emitted.emit(event)
