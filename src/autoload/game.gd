extends Node
## 全局调度门面：固定 20tps 步进规则层，把事件广播给表现层订阅者。
## 规则层状态只在这里被驱动；表现层只允许连接 event_emitted（消费）与
## 只读布局 battle_grid/hero_cell/castle_cell，不得改规则层状态。

signal event_emitted(event: Dictionary)

const FixedStepper = preload("res://src/core/fixed_stepper.gd")
const BattleSim = preload("res://src/core/battle_sim.gd")

const TICKS_PER_SECOND := 20.0

var _stepper: FixedStepper = null
var _sim: BattleSim = null
var running := false
var battle_grid = null            # 只读：Grid（网格/路径）
var hero_cell := Vector2i.ZERO    # 只读：英雄所在格
var castle_cell := Vector2i.ZERO  # 只读：城堡格（路径终点）

func _ready() -> void:
	start_battle()

func _build_config() -> Dictionary:
	var hero_res: Resource = load("res://resources/heroes/swordsman.tres")
	var monster_res: Resource = load("res://resources/monsters/goblin.tres")
	return {
		"hero_damage": hero_res.attack_damage,
		"hero_attack_interval": hero_res.attack_interval,
		"hero_range_tiles": hero_res.range_tiles,
		"monster_max_hp": monster_res.max_hp,
		"monster_move_speed": monster_res.move_speed,
		"monster_armor": monster_res.armor,
	}

func start_battle() -> void:
	_sim = BattleSim.new(_build_config())
	_stepper = FixedStepper.new(1.0 / TICKS_PER_SECOND)
	battle_grid = _sim.grid
	hero_cell = _sim.hero.cell
	castle_cell = _sim.grid.waypoints[_sim.grid.waypoints.size() - 1]
	running = true

func stop_battle() -> void:
	running = false

func _physics_process(delta: float) -> void:
	if not running:
		return
	var steps: int = _stepper.add_delta(delta)
	for i in steps:
		for event in _sim.step():
			event_emitted.emit(event)
