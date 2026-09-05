# HeroShowdown P0（工程骨架）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付可运行的 Godot 4.7 空工程：GUT 测试链路、Def→.tres 数据管线、固定 20tps 步进循环（空战场桩），headless 跑 1000 tick 无错。

**Architecture:** 规则层 `src/core/` 纯 GDScript（无 Node 引用），由 `Game` autoload 按 20tps 固定步长驱动 `BattleSim.step()`，输出事件字典流广播给表现层。P0 的 BattleSim 只做 tick 计数桩，后续板块逐步填充实体/波次/技能。

**Tech Stack:** Godot 4.7 标准版（`G:/Zcode/tools/godot/Godot_v4.7-stable_win64.exe`）、GDScript、GUT 9.7.1（从前作仓库复制 `addons/gut/`）。

**Spec:** `docs/superpowers/specs/2026-09-05-heroshowdown-demo-design.md`（本计划实现其路线图 P0；P1~P5 由后续计划承接）

## Global Constraints

- 工程根 = git 仓库根 = `G:\Zcode\project\HeroShowdown`；引擎 Godot 4.7 标准版。
- `src/core/` 内脚本只允许 `extends RefCounted`（Def 数据类 `extends Resource`）；禁止引用任何 Node/场景类型。
- 逻辑固定 20tps；事件统一字典 `{type: String, data: Dictionary}`；事件类型常量集中在 `src/core/events.gd`。
- 网格坐标 `Vector2i`；格子 48px；视口 960×560、integer 缩放（16×10 战场 + 右侧 HUD 预留）。
- `src/autoload/game.gd`（单例名 `Game`）是唯一调度门面；表现层只允许连接 `Game.event_emitted` 消费事件，不得改规则层状态。
- 测试框架 GUT 9.7.1，测试放 `tests/unit/`，命名 `test_<被测类>.gd`；用 `const X = preload("res://...")` 加载被测类，不依赖 class_name 全局注册。
- 规则层测试不加载 .tres（唯一例外：Task 4 的 `test_def_pipeline.gd`，它专门验证数据管线）。
- 脚本新建后跑一次 `--import` 让 Godot 生成 `.uid` 文件并一并提交（前作同样做法）。
- 每个 Task 结束 git 提交一次；提交信息用 `feat:`/`test:`/`chore:` 前缀；注释与文档用中文。

## 运行测试的命令（每个 Task 复用）

```bash
GODOT="G:/Zcode/tools/godot/Godot_v4.7-stable_win64.exe"
cd "G:/Zcode/project/HeroShowdown"
"$GODOT" --headless --path . --import          # 首次或新增脚本/资源后导入
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit          # 全量
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_fixed_stepper.gd -gexit  # 单文件
```

Expected: 输出末尾总览 `x passed / 0 failed`，退出码 0。

> 勘误（P0 执行期发现）：-gtest 单文件运行会与 .gutconfig.json 的 dirs 合并跑全套，不能真正单文件隔离；需真隔离时用 -gconfig= 跳过配置：-s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_x.gd -gexit

---

### Task 1: 工程骨架 + GUT 冒烟

**Files:**
- Create: `project.godot`（P0 阶段不含 autoload 段，Task 5 再加）
- Create: `.gutconfig.json`
- Create: `addons/gut/`（从前作整目录复制）
- Create: `src/core/events.gd`
- Create: `src/autoload/main.gd` + `src/autoload/main.tscn`（占位主场景）
- Create: `tests/unit/test_smoke.gd`

**Interfaces:**
- Consumes: 无
- Produces: 可 F5 运行的空工程；事件常量表 `Events.TICK == "tick"`（后续所有任务按名引用）；GUT 命令行链路可用。

- [ ] **Step 1: 复制 GUT 插件 + 写工程配置**

```bash
cd "G:/Zcode/project/HeroShowdown"
mkdir -p addons src/core src/autoload tests/unit tests/smoke
cp -r "G:/Zcode/project/Roguelike/addons/gut" addons/gut
```

`project.godot`：

```ini
; Engine configuration file.
config_version=5

[application]

config/name="HeroShowdown"
run/main_scene="res://src/autoload/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]

window/size/viewport_width=960
window/size/viewport_height=560
window/stretch/mode="viewport"
window/stretch/scale_mode="integer"

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

`.gutconfig.json`（与前作一致）：

```json
{
  "dirs": ["res://tests/unit"],
  "include_subdirs": false,
  "should_exit": true,
  "double_strategy": "script_only"
}
```

- [ ] **Step 2: 写事件常量表与占位主场景**

`src/core/events.gd`：

```gdscript
class_name Events
## 事件类型常量：规则层 → 表现层的唯一输出词汇表。

const TICK := "tick"
```

`src/autoload/main.gd`（占位，Task 5 实装）：

```gdscript
extends Node2D
## P0 占位主场景：Task 5 实装为固定步进循环的演示画面。

func _ready() -> void:
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.text = "HeroShowdown P0"
	add_child(label)
```

`src/autoload/main.tscn`：

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/autoload/main.gd" id="1_main"]

[node name="Main" type="Node2D"]
script = ExtResource("1_main")
```

- [ ] **Step 3: 写 GUT 冒烟测试**

`tests/unit/test_smoke.gd`：

```gdscript
extends GutTest
## 工程冒烟：GUT 链路与核心脚本加载可用。

func test_gut_and_events_alive():
	assert_true(true)
	var Events = preload("res://src/core/events.gd")
	assert_eq(Events.TICK, "tick")
```

- [ ] **Step 4: 导入并跑测试，验证通过**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: `1 passed / 0 failed`。若 Godot 报 .uid 缺失属正常，`--import` 会生成。

- [ ] **Step 5: Commit（含生成的 .uid 文件）**

```bash
git add -A
git commit -m "chore: P0 工程骨架——Godot4.7 工程+GUT 接入+事件常量"
```

---

### Task 2: FixedStepper 固定步长累加器

**Files:**
- Create: `src/core/fixed_stepper.gd`
- Test: `tests/unit/test_fixed_stepper.gd`

**Interfaces:**
- Consumes: 无
- Produces: `FixedStepper.new(step_interval: float, max_steps_per_frame: int = 5)`；`add_delta(delta: float) -> int`（返回本帧应步进次数）；属性 `step_interval`、`max_steps_per_frame`。Task 5 的 Game autoload 依赖此签名。

- [ ] **Step 1: 写失败测试**

`tests/unit/test_fixed_stepper.gd`：

```gdscript
extends GutTest
## FixedStepper：把真实时间切成固定 tick 步数，限单帧上限防死亡螺旋。

const FixedStepper = preload("res://src/core/fixed_stepper.gd")

func test_full_delta_produces_one_step():
	var s = FixedStepper.new(0.05)
	assert_eq(s.add_delta(0.05), 1)

func test_accumulates_small_deltas():
	var s = FixedStepper.new(0.05)
	assert_eq(s.add_delta(0.02), 0)
	assert_eq(s.add_delta(0.02), 0)
	assert_eq(s.add_delta(0.02), 1)

func test_large_delta_produces_multiple_steps():
	var s = FixedStepper.new(0.05)
	assert_eq(s.add_delta(0.12), 2)

func test_caps_steps_per_frame():
	var s = FixedStepper.new(0.05, 3)
	assert_eq(s.add_delta(1.0), 3)

func test_drops_backlog_after_cap():
	var s = FixedStepper.new(0.05, 3)
	assert_eq(s.add_delta(1.0), 3)
	assert_eq(s.add_delta(0.0), 0)   # 积压已丢弃，不连环补步
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_fixed_stepper.gd -gexit
```

Expected: FAIL（脚本不存在，解析错误）。

- [ ] **Step 3: 写实现**

`src/core/fixed_stepper.gd`：

```gdscript
extends RefCounted
## 固定步长累加器：累积真实 delta，按 step_interval 切成整数次步进。
## 单帧步进数封顶 max_steps_per_frame，超出部分直接丢弃（防卡顿后死亡螺旋）。

var step_interval: float
var max_steps_per_frame: int
var _accumulator := 0.0

func _init(p_step_interval: float, p_max_steps_per_frame: int = 5) -> void:
	step_interval = p_step_interval
	max_steps_per_frame = p_max_steps_per_frame

func add_delta(delta: float) -> int:
	_accumulator += delta
	var steps := 0
	while _accumulator >= step_interval and steps < max_steps_per_frame:
		_accumulator -= step_interval
		steps += 1
	if _accumulator > step_interval:
		_accumulator = 0.0
	return steps
```

- [ ] **Step 4: 跑测试确认通过**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_fixed_stepper.gd -gexit
```

Expected: `5 passed / 0 failed`。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: FixedStepper 固定步长累加器(20tps 基础)"
```

---

### Task 3: BattleSim 桩（tick 计数 + 事件流）

**Files:**
- Create: `src/core/battle_sim.gd`
- Test: `tests/unit/test_battle_sim.gd`

**Interfaces:**
- Consumes: `Events.TICK`（Task 1）。
- Produces: `BattleSim.new()`；`step() -> Array`（每调用一次 tick+1，返回事件字典数组）；属性 `tick_count: int`。Task 5/6 与后续板块依赖此签名。

- [ ] **Step 1: 写失败测试**

`tests/unit/test_battle_sim.gd`：

```gdscript
extends GutTest
## BattleSim P0 桩：tick 计数与事件流。

const BattleSim = preload("res://src/core/battle_sim.gd")
const Events = preload("res://src/core/events.gd")

func test_initial_tick_count_zero():
	var sim = BattleSim.new()
	assert_eq(sim.tick_count, 0)

func test_step_emits_tick_event_and_counts():
	var sim = BattleSim.new()
	var events = sim.step()
	assert_eq(sim.tick_count, 1)
	assert_eq(events.size(), 1)
	assert_eq(events[0].type, Events.TICK)
	assert_eq(events[0].data.tick, 1)

func test_1000_steps_reaches_1000():
	var sim = BattleSim.new()
	for i in 1000:
		sim.step()
	assert_eq(sim.tick_count, 1000)
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_battle_sim.gd -gexit
```

Expected: FAIL（脚本不存在）。

- [ ] **Step 3: 写实现**

`src/core/battle_sim.gd`：

```gdscript
extends RefCounted
## 战斗模拟（P0 桩）：只统计 tick 并按步产出事件。
## P1 起逐步填充：网格/路径、实体、索敌、波次、技能、经济、胜负。

const Events = preload("res://src/core/events.gd")

var tick_count := 0

func step() -> Array:
	tick_count += 1
	return [{"type": Events.TICK, "data": {"tick": tick_count}}]
```

- [ ] **Step 4: 跑测试确认通过 + 全量回归**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_battle_sim.gd -gexit
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: 单文件 `3 passed`；全量 `9 passed / 0 failed`。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: BattleSim 桩——tick 计数与事件流"
```

---

### Task 4: Def 数据类 + .tres 管线示例

**Files:**
- Create: `src/core/def/hero_def.gd`
- Create: `src/core/def/monster_def.gd`
- Create: `resources/heroes/swordsman.tres`
- Create: `resources/monsters/goblin.tres`
- Test: `tests/unit/test_def_pipeline.gd`

**Interfaces:**
- Consumes: 无
- Produces: `HeroDef`（`display_name: String`、`attack_damage: int`、`attack_interval: float`、`range_tiles: float`）与 `MonsterDef`（`display_name: String`、`max_hp: int`、`move_speed: float`、`armor: int`、`gold_drop: int`），均为 `extends Resource` 的 @export 字段——P2 扩展技能/索敌/特性字段时向后兼容。.tres 命名规范 `resources/<类别>/<蛇形名>.tres`。

- [ ] **Step 1: 写失败测试**

`tests/unit/test_def_pipeline.gd`（全局约束中唯一允许加载 .tres 的测试）：

```gdscript
extends GutTest
## Def→.tres 数据管线：资源表可加载、字段反序列化正确。

func test_load_hero_tres():
	var hero = load("res://resources/heroes/swordsman.tres")
	assert_eq(hero.display_name, "剑士")
	assert_eq(hero.attack_damage, 12)
	assert_almost_eq(hero.attack_interval, 0.8, 0.001)
	assert_almost_eq(hero.range_tiles, 1.5, 0.001)

func test_load_monster_tres():
	var m = load("res://resources/monsters/goblin.tres")
	assert_eq(m.display_name, "哥布林")
	assert_eq(m.max_hp, 30)
	assert_almost_eq(m.move_speed, 1.2, 0.001)
	assert_eq(m.armor, 0)
	assert_eq(m.gold_drop, 3)
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_def_pipeline.gd -gexit
```

Expected: FAIL（资源不存在）。

- [ ] **Step 3: 写 Def 类与 .tres**

`src/core/def/hero_def.gd`：

```gdscript
class_name HeroDef
extends Resource
## 英雄数值定义（P0 最小字段；P2 补技能/索敌类型/升级字段）。

@export var display_name: String = ""
@export var attack_damage: int = 1
@export var attack_interval: float = 1.0   # 攻击间隔（秒）
@export var range_tiles: float = 1.5       # 射程（格）
```

`src/core/def/monster_def.gd`：

```gdscript
class_name MonsterDef
extends Resource
## 怪物数值定义（P0 最小字段；P2 补特性：减伤/治疗光环/boss 技能）。

@export var display_name: String = ""
@export var max_hp: int = 10
@export var move_speed: float = 1.0        # 移速（格/秒）
@export var armor: int = 0                 # 护甲，减固定值伤害
@export var gold_drop: int = 1             # 击杀掉落金币
```

`resources/heroes/swordsman.tres`：

```ini
[gd_resource type="Resource" script_class="HeroDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/def/hero_def.gd" id="1_hero"]

[resource]
script = ExtResource("1_hero")
display_name = "剑士"
attack_damage = 12
attack_interval = 0.8
range_tiles = 1.5
```

`resources/monsters/goblin.tres`：

```ini
[gd_resource type="Resource" script_class="MonsterDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/def/monster_def.gd" id="1_gob"]

[resource]
script = ExtResource("1_gob")
display_name = "哥布林"
max_hp = 30
move_speed = 1.2
armor = 0
gold_drop = 3
```

- [ ] **Step 4: 导入 + 跑测试确认通过 + 全量回归**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_def_pipeline.gd -gexit
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: 单文件 `2 passed`；全量 `11 passed / 0 failed`。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: HeroDef/MonsterDef + .tres 数据管线示例"
```

---

### Task 5: Game autoload 固定步进调度 + 主场景实装

**Files:**
- Create: `src/autoload/game.gd`
- Modify: `project.godot`（加 `[autoload]` 段）
- Modify: `src/autoload/main.gd`（替换占位实现）
- Test: 无新增单测（循环逻辑已被 Task 2 FixedStepper 测试覆盖；本任务验证靠 headless 实跑 + Task 6 冒烟）

**Interfaces:**
- Consumes: `FixedStepper.add_delta()`（Task 2）、`BattleSim.step()`（Task 3）。
- Produces: autoload 单例 `Game`；信号 `event_emitted(event: Dictionary)`；方法 `start_battle()`、`stop_battle()`；常量 `Game.TICKS_PER_SECOND == 20.0`。表现层后续只连 `Game.event_emitted`。主场景运行时画面显示 `P0 运行中 tick=N`（N 每 20 tick 刷新一次，即每秒 +20）。

- [ ] **Step 1: 写 Game autoload**

`src/autoload/game.gd`：

```gdscript
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
```

- [ ] **Step 2: project.godot 加 autoload 段**

在 `[editor_plugins]` 段之前插入：

```ini
[autoload]

Game="*res://src/autoload/game.gd"
```

- [ ] **Step 3: 实装主场景**

`src/autoload/main.gd` 整体替换为：

```gdscript
extends Node2D
## P0 主场景：验证实时循环活着——每秒 tick 计数 +20，画面显示计数。

const Events = preload("res://src/core/events.gd")

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.text = "HeroShowdown P0"
	add_child(_label)
	Game.event_emitted.connect(_on_event)

func _on_event(event: Dictionary) -> void:
	if event.type != Events.TICK:
		return
	var t: int = event.data.tick
	if t % 20 == 0:
		_label.text = "P0 运行中 tick=%d" % t
```

- [ ] **Step 4: headless 实跑 120 帧验证循环**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --quit-after 120 2>&1 | tail -5; echo "exit=${PIPESTATUS[0]}"
```

Expected: 无脚本报错栈，`exit=0`（120 帧 ≈ 2 秒 ≈ 40 tick，若报 `event_emitted` 或 autoload 相关错误则修）。

- [ ] **Step 5: 全量回归 + Commit**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
git add -A
git commit -m "feat: Game autoload 固定步进调度+主场景 tick 显示"
```

Expected: `11 passed / 0 failed`。

---

### Task 6: headless 1000 tick 冒烟场景

**Files:**
- Create: `tests/smoke/smoke_tick.gd` + `tests/smoke/smoke_tick.tscn`

**Interfaces:**
- Consumes: `BattleSim`（Task 3）。
- Produces: P0 完成标志——headless 跑完 1000 tick 打印 `SMOKE_OK` 并以退出码 0 退出；后续板块的冒烟场景沿用此模式（`SMOKE_OK` + `quit(0)` / 失败 `push_error` + `quit(1)`）。

- [ ] **Step 1: 写冒烟场景**

`tests/smoke/smoke_tick.gd`：

```gdscript
extends Node
## P0 冒烟：headless 步进 1000 tick，成功打印 SMOKE_OK 并以 0 退出。

const BattleSim = preload("res://src/core/battle_sim.gd")

const TOTAL_TICKS := 1000

func _ready() -> void:
	var sim = BattleSim.new()
	var last_events: Array = []
	for i in TOTAL_TICKS:
		last_events = sim.step()
		if sim.tick_count != i + 1:
			push_error("tick 计数中断: expected %d got %d" % [i + 1, sim.tick_count])
			get_tree().quit(1)
			return
		if last_events.is_empty():
			push_error("第 %d tick 未产出事件" % i)
			get_tree().quit(1)
			return
	if sim.tick_count != TOTAL_TICKS:
		push_error("最终计数错误: %d" % sim.tick_count)
		get_tree().quit(1)
		return
	print("SMOKE_OK tick_count=%d" % sim.tick_count)
	get_tree().quit(0)
```

`tests/smoke/smoke_tick.tscn`：

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/smoke/smoke_tick.gd" id="1_smoke"]

[node name="SmokeTick" type="Node"]
script = ExtResource("1_smoke")
```

- [ ] **Step 2: headless 运行验证**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . res://tests/smoke/smoke_tick.tscn 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"
```

Expected: 输出 `SMOKE_OK tick_count=1000`，`exit=0`。

- [ ] **Step 3: 全量回归（P0 收尾）+ Commit**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
git add -A
git commit -m "test: headless 1000 tick 冒烟场景——P0 完成"
```

Expected: `11 passed / 0 failed`，退出码 0。至此 P0 完成标志达成：headless 1000 tick 无错 + 示例单测全绿。
