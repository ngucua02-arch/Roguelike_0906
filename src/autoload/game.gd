extends Node
## 全局调度门面：固定 20tps 步进规则层，把事件广播给表现层订阅者。
## 规则层状态只在这里被驱动；表现层只允许连接 event_emitted 消费事件。

signal event_emitted(event: Dictionary)

const FixedStepper = preload("res://src/core/fixed_stepper.gd")
const BattleSim = preload("res://src/core/battle_sim.gd")

const TICKS_PER_SECOND := 20.0

var _stepper = null
var _sim = null
var running := false

func _ready() -> void:
	start_battle()

func start_battle() -> void:
	_sim = BattleSim.new()
	_stepper = FixedStepper.new(1.0 / TICKS_PER_SECOND)
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
