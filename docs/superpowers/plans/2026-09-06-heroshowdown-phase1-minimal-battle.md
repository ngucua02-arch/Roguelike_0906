# HeroShowdown P1（最小战斗）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付 P1 最小战斗：网格+路径渲染、怪走路径、1 英雄自动索敌攻击、城堡 HP/漏怪、胜负判定——headless 打完默认配置一场战斗稳定获胜，窗口里能看到最糙但能分出胜负的一仗。

**Architecture:** 延续"规则层/表现层分离 + 事件流"。规则层新增 `src/core/battle/grid.gd`（网格与折线路径，格单位坐标）并重写 `battle_sim.gd`（生成/移动/漏怪/索敌/伤害/胜负，全字典配置驱动，无 Node 引用）；表现层新增 `src/view/battle_view.gd` 只消费 `Game.event_emitted` 与只读布局。胜负后 sim 锁定：`step()` 恒返回空数组且 tick 冻结。

**Tech Stack:** Godot 4.7 标准版（`G:/Zcode/tools/godot/Godot_v4.7-stable_win64.exe`）、GDScript、GUT 9.7.1。

**Spec:** `docs/superpowers/specs/2026-09-05-heroshowdown-demo-design.md`（本计划实现其路线图 P1；格子 16×10、城堡 10HP、漏怪扣 1、剑士/哥布林数值沿用 P0 已入库 .tres）

**数值已用原型验证**（勿改断言数字）：默认配置（哥布林 30HP/1.2 格秒、剑士 12 伤/0.8s/1.5 格射程、10 只、间隔 2.5s）→ 胜利、城堡 10/10、10 杀、约 681 tick；`hero_damage=0` → 10 漏、城堡 0、约 803 tick 判负；20 tick 位移 = 1.2 格，位置 (0.7, 1.5)；护甲 5 对 12 伤 → HURT damage=7、hp=23。

## Global Constraints

- 工程根 = git 仓库根 = `G:\Zcode\project\HeroShowdown`；引擎 Godot 4.7 标准版。
- `src/core/` 内脚本只允许 `extends RefCounted`（Def 数据类 `extends Resource`）；禁止引用任何 Node/场景类型；内部实体类用内部 class（`class Monster: extends RefCounted`）。
- 逻辑固定 20tps；sim 内部步长常量 `DT := 1.0 / 20.0`；事件统一字典 `{type: String, data: Dictionary}`，一经发出视为不可变；事件类型常量集中在 `src/core/events.gd`；`TICK` 事件恒为每步事件数组第一个元素。
- 规则层坐标一律用格单位（1 格 = 1.0，格中心 = 格坐标 + 0.5）；像素换算只发生在表现层（`CELL := 48`）。
- 网格坐标 `Vector2i`；网格 16×10；视口 960×560、integer 缩放。
- `src/autoload/game.gd`（单例名 `Game`）是唯一调度门面；表现层只允许连接 `Game.event_emitted` 消费事件、只读 `Game.battle_grid / hero_cell / castle_cell`，不得改规则层状态。
- `BattleSim.new(config: Dictionary = {})` 全部键可省略；键：`waypoints / castle_hp / hero_cell / hero_damage / hero_attack_interval / hero_range_tiles / monster_max_hp / monster_move_speed / monster_armor / total_spawns / spawn_interval`。
- 测试框架 GUT 9.7.1，测试放 `tests/unit/`，命名 `test_<被测类>.gd`；用 `const X = preload("res://...")` 加载被测类；规则层测试不加载 .tres（`test_def_pipeline.gd` 仍是唯一例外）。
- 脚本新建后跑一次 `--import` 生成 `.uid` 并一并提交。
- 每个 Task 结束必须"全量 GUT 绿 + 相关冒烟绿"再 git 提交；提交信息 `feat:`/`test:`/`chore:` 前缀；注释与文档全中文。

## 运行测试的命令（每个 Task 复用）

```bash
GODOT="G:/Zcode/tools/godot/Godot_v4.7-stable_win64.exe"
cd "G:/Zcode/project/HeroShowdown"
"$GODOT" --headless --path . --import          # 新增脚本/资源后导入
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit          # 全量单测
"$GODOT" --headless --path . res://tests/smoke/smoke_battle.tscn 2>&1 | tail -3               # 冒烟
```

> 注意（P0 勘误延续）：GUT 单文件运行用 `-gconfig=` 跳过 .gutconfig.json 才能真隔离：
> `-s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_x.gd -gexit`

---

### Task 1: P0 审查遗留清理（事件不可变约定 / stepper 边界 / 类型标注）

**Files:**
- Modify: `src/core/events.gd`
- Modify: `src/core/fixed_stepper.gd:18`
- Modify: `tests/unit/test_fixed_stepper.gd`（追加 1 个测试）
- Modify: `src/autoload/game.gd`

**Interfaces:**
- Consumes: 无
- Produces: `FixedStepper.add_delta()` 边界语义定版（残留 ≥ 一个 step_interval 时丢弃）；`game.gd` 私有字段带 preload 类型标注。后续任务依赖这些最终形态。

- [ ] **Step 1: 追加失败测试（stepper 边界回归）**

在 `tests/unit/test_fixed_stepper.gd` 末尾追加：

```gdscript

func test_flushes_remainder_equal_to_interval():
	# 封顶后残留恰好一个 interval 也应丢弃：否则下一帧 add_delta(0) 会连补 1 步
	# （0.25/1.0 二进制精确，避免浮点噪声吃掉边界）
	var s = FixedStepper.new(0.25, 3)
	assert_eq(s.add_delta(1.0), 3)
	assert_eq(s.add_delta(0.0), 0)
	assert_eq(s.add_delta(0.25), 1)
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_fixed_stepper.gd -gexit
```

Expected: `test_flushes_remainder_equal_to_interval` FAIL（当前 `>` 边界会把残留 0.05 保留，最后一步返回 2）。

- [ ] **Step 3: 修 `fixed_stepper.gd`**

将 `add_delta` 末尾的：

```gdscript
	if _accumulator > step_interval:
		_accumulator = 0.0
```

改为：

```gdscript
	if _accumulator >= step_interval:
		_accumulator = 0.0
```

- [ ] **Step 4: `events.gd` 加不可变约定注释**

`src/core/events.gd` 整体替换为（仅多一行注释，常量不变）：

```gdscript
class_name Events
## 事件类型常量：规则层 → 表现层的唯一输出词汇表。
## 约定：事件字典 {type, data} 一经发出视为不可变，消费方不得改写（广播为引用共享）。

const TICK := "tick"
```

- [ ] **Step 5: `game.gd` 类型标注**

将 `src/autoload/game.gd` 中：

```gdscript
var _stepper = null
var _sim = null
```

改为：

```gdscript
var _stepper: FixedStepper = null
var _sim: BattleSim = null
```

- [ ] **Step 6: 全量回归 + Commit**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
git add -A
git commit -m "chore: P0 审查遗留——事件不可变约定+stepper封顶边界+类型标注"
```

Expected: `12 passed / 0 failed`（原 11 + 新增 1）。

---

### Task 2: Grid 网格与路径（格单位）

**Files:**
- Create: `src/core/battle/grid.gd`
- Test: `tests/unit/test_grid.gd`

**Interfaces:**
- Consumes: 无
- Produces: `GridScript.new(width: int, height: int, waypoints: Array) -> Grid`；属性 `width`、`height`、`waypoints`、`path_cells: Dictionary`（Vector2i→true，含场外起点格）、`path_length: float`；方法 `in_bounds(cell: Vector2i) -> bool`、`is_path(cell: Vector2i) -> bool`、`cell_to_pos(cell: Vector2i) -> Vector2`（格中心）、`point_at(dist: float) -> Vector2`（沿线取点，两端截断）。Task 3 的 BattleSim 依赖全部签名。

- [ ] **Step 1: 写失败测试**

`tests/unit/test_grid.gd`：

```gdscript
extends GutTest
## Grid：正交折线路径栅格化、沿线取点、格中心换算。

const GridScript = preload("res://src/core/battle/grid.gd")

const WPS: Array = [Vector2i(-1, 1), Vector2i(13, 1), Vector2i(13, 8), Vector2i(2, 8)]

func test_rasterizes_path_cells():
	var g = GridScript.new(16, 10, WPS)
	assert_true(g.is_path(Vector2i(0, 1)))
	assert_true(g.is_path(Vector2i(13, 4)))
	assert_true(g.is_path(Vector2i(7, 8)))
	assert_false(g.is_path(Vector2i(5, 5)))

func test_in_bounds():
	var g = GridScript.new(16, 10, WPS)
	assert_true(g.in_bounds(Vector2i(0, 0)))
	assert_true(g.in_bounds(Vector2i(15, 9)))
	assert_false(g.in_bounds(Vector2i(-1, 1)))
	assert_false(g.in_bounds(Vector2i(16, 0)))

func test_path_length_sums_segments():
	var g = GridScript.new(16, 10, WPS)
	assert_almost_eq(g.path_length, 32.0, 0.001)  # 14 + 7 + 11

func test_point_at_ends_corners_and_clamp():
	var g = GridScript.new(16, 10, WPS)
	var p0: Vector2 = g.point_at(0.0)
	assert_almost_eq(p0.x, -0.5, 0.001)
	assert_almost_eq(p0.y, 1.5, 0.001)
	var neg: Vector2 = g.point_at(-3.0)
	assert_almost_eq(neg.x, -0.5, 0.001)  # 负距离截断到起点
	var corner: Vector2 = g.point_at(14.0)
	assert_almost_eq(corner.x, 13.5, 0.001)
	assert_almost_eq(corner.y, 1.5, 0.001)
	var down: Vector2 = g.point_at(15.0)
	assert_almost_eq(down.x, 13.5, 0.001)
	assert_almost_eq(down.y, 2.5, 0.001)
	var end: Vector2 = g.point_at(32.0)
	assert_almost_eq(end.x, 2.5, 0.001)
	assert_almost_eq(end.y, 8.5, 0.001)
	var over: Vector2 = g.point_at(999.0)
	assert_almost_eq(over.x, 2.5, 0.001)  # 超长截断到终点

func test_cell_to_pos_is_center():
	var g = GridScript.new(16, 10, WPS)
	var p: Vector2 = g.cell_to_pos(Vector2i(3, 4))
	assert_almost_eq(p.x, 3.5, 0.001)
	assert_almost_eq(p.y, 4.5, 0.001)
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_grid.gd -gexit
```

Expected: FAIL（脚本不存在，解析错误）。

- [ ] **Step 3: 写实现**

`src/core/battle/grid.gd`：

```gdscript
extends RefCounted
## 网格与路径：正交折线路径的栅格化与沿线取点。
## 规则层一律用格单位（1 格 = 1.0，格中心 = 格坐标 + 0.5）；像素换算只发生在表现层。

const CELL_SIZE := 48  # 仅供表现层参考；规则层不使用

var width: int
var height: int
var waypoints: Array
var path_cells := {}  # Vector2i -> true（含场外起点格，spawn 用）
var path_length := 0.0
var _segment_lengths: Array = []

func _init(p_width: int, p_height: int, p_waypoints: Array) -> void:
	width = p_width
	height = p_height
	waypoints = p_waypoints
	for i in waypoints.size() - 1:
		var a: Vector2i = waypoints[i]
		var b: Vector2i = waypoints[i + 1]
		assert(a.x == b.x or a.y == b.y, "路径段必须正交")
		var c := a
		while true:
			path_cells[c] = true
			if c == b:
				break
			c += Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		_segment_lengths.append(float(absi(b.x - a.x) + absi(b.y - a.y)))
	for l in _segment_lengths:
		path_length += l

static func signi(v: int) -> int:
	return 1 if v > 0 else (-1 if v < 0 else 0)

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func is_path(cell: Vector2i) -> bool:
	return path_cells.has(cell)

func cell_to_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)

func point_at(dist: float) -> Vector2:
	var d := clampf(dist, 0.0, path_length)
	for i in waypoints.size() - 1:
		var seg: float = _segment_lengths[i]
		if d <= seg or i == waypoints.size() - 2:
			var a: Vector2i = waypoints[i]
			var b: Vector2i = waypoints[i + 1]
			var dir := (Vector2(b - a) / seg) if seg > 0.0 else Vector2.ZERO
			return cell_to_pos(a) + dir * d
		d -= seg
	return cell_to_pos(waypoints[waypoints.size() - 1])
```

- [ ] **Step 4: 导入 + 跑测试确认通过**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_grid.gd -gexit
```

Expected: `5 passed / 0 failed`。

- [ ] **Step 5: 全量回归 + Commit**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
git add -A
git commit -m "feat: Grid 网格与折线路径——栅格化/沿线取点(格单位)"
```

Expected: `17 passed / 0 failed`（12 + 5）。

---

### Task 3: BattleSim 实体战——生成/移动/漏怪/城堡扣血/败北锁定

**Files:**
- Modify: `src/core/events.gd`（追加 SPAWN/MOVE/LEAK/DEFEAT）
- Rewrite: `src/core/battle_sim.gd`
- Rewrite: `tests/unit/test_battle_sim.gd`
- Rename+Rewrite: `tests/smoke/smoke_tick.gd` → `tests/smoke/smoke_battle.gd`；`tests/smoke/smoke_tick.tscn` → `tests/smoke/smoke_battle.tscn`

**Interfaces:**
- Consumes: `Events.*`（Task 1/本任务）、`GridScript`（Task 2）。
- Produces（Task 4 与 Game/表现层依赖）: `BattleSim.new(config: Dictionary = {})`；属性 `tick_count: int`、`castle_hp: int`、`result: String`（`""`/`"victory"`/`"defeat"`）、`grid`（Grid 实例）、`hero: Dictionary`（`cell/damage/attack_interval/range_tiles/cooldown`）、`monster_def: Dictionary`、`monsters: Array[Monster]`（Monster: `id/def/path_dist/hp/alive`）；`step() -> Array`——`result != ""` 时恒返回 `[]` 且 `tick_count` 冻结；否则 `TICK` 恒为首事件，其后按序 spawn/move/leak。config 全键可省略（默认值见 Global Constraints 与实现）。

- [ ] **Step 1: 写失败测试**

`tests/unit/test_battle_sim.gd` 整体替换为（P0 的 tick 桩测试退役）：

```gdscript
extends GutTest
## BattleSim P1：生成/移动/漏怪/城堡扣血/败北锁定（索敌攻击在 Task 4 追加）。

const BattleSim = preload("res://src/core/battle_sim.gd")
const Events = preload("res://src/core/events.gd")

func _run_to_end(sim, max_ticks := 20000) -> int:
	var t := 0
	while sim.result == "" and t < max_ticks:
		t += 1
		sim.step()
	return t

func test_step_emits_tick_first():
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0})
	var events: Array = sim.step()
	assert_eq(sim.tick_count, 1)
	assert_eq(events[0].type, Events.TICK)
	assert_eq(events[0].data.tick, 1)

func test_monster_moves_along_path():
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0})
	for i in 20:
		sim.step()
	var m = sim.monsters[0]
	assert_almost_eq(m.path_dist, 1.2, 0.001)  # 1.2 格/秒 × 1 秒
	var pos: Vector2 = sim.grid.point_at(m.path_dist)
	assert_almost_eq(pos.x, 0.7, 0.001)
	assert_almost_eq(pos.y, 1.5, 0.001)

func test_first_step_has_spawn_and_move():
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0})
	var events: Array = sim.step()
	var types := []
	for e in events:
		types.append(e.type)
	assert_has(types, Events.SPAWN)
	assert_has(types, Events.MOVE)

func test_leak_decrements_castle_and_resolves_monster():
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0})
	var t := _run_to_end(sim)
	assert_gt(t, 0)
	assert_eq(sim.castle_hp, 9)
	assert_false(sim.monsters[0].alive)

func test_cleared_battle_with_leak_still_wins_on_castle_alive():
	# 1 只全漏但城堡 9>0：波次清空即胜利（塔防语义：守住 = 城堡存活）
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0})
	_run_to_end(sim)
	assert_eq(sim.result, "victory")

func test_ten_leaks_trigger_defeat():
	var sim = BattleSim.new({"hero_damage": 0})
	var leaks := 0
	var defeats := 0
	var t := 0
	while sim.result == "" and t < 2000:
		t += 1
		for e in sim.step():
			if e.type == Events.LEAK:
				leaks += 1
			elif e.type == Events.DEFEAT:
				defeats += 1
	assert_eq(sim.result, "defeat")
	assert_eq(sim.castle_hp, 0)
	assert_eq(leaks, 10)
	assert_eq(defeats, 1)
	assert_eq(sim.monsters.size(), 10)

func test_defeat_locks_sim():
	var sim = BattleSim.new({"total_spawns": 2, "hero_damage": 0})
	_run_to_end(sim)
	assert_eq(sim.result, "defeat")
	var frozen_tick: int = sim.tick_count
	var events: Array = sim.step()
	assert_eq(events.size(), 0)
	assert_eq(sim.tick_count, frozen_tick)
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_battle_sim.gd -gexit
```

Expected: FAIL（`SPAWN/LEAK/DEFEAT` 常量不存在、`monsters/grid/result` 属性不存在）。

- [ ] **Step 3: 事件常量追加**

`src/core/events.gd` 的 `const TICK := "tick"` 之后追加：

```gdscript

const SPAWN := "spawn"
const MOVE := "move"
const LEAK := "leak"
const DEFEAT := "defeat"
```

- [ ] **Step 4: 重写 `src/core/battle_sim.gd`**

```gdscript
extends RefCounted
## 战斗模拟（20tps 确定性步进）。P1：单英雄自动索敌 + 单种怪沿路径推进
## + 漏怪扣城堡 + 胜负一次锁定。全部配置可省略，键见 Global Constraints。

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
var monsters: Array = []  # Array[Monster]（含已出场即离场的，按 alive 区分）

var _hero_damage: int
var _hero_attack_interval: float
var _hero_range_tiles: float
var _hero_cooldown := 0.0
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
	}
	_hero_damage = hero.damage
	_hero_attack_interval = hero.attack_interval
	_hero_range_tiles = hero.range_tiles
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
```

注意：本任务 `_check_result` 引用了尚未定义的 `Events.VICTORY`——在 Step 3 的 events.gd 追加中**同时**加上 `const VICTORY := "victory"`（Task 4 只再补攻击类常量），否则脚本解析失败。

- [ ] **Step 5: 冒烟场景替换（重命名 tick→battle）**

```bash
git rm -q tests/smoke/smoke_tick.gd tests/smoke/smoke_tick.tscn
```

`tests/smoke/smoke_battle.gd`：

```gdscript
extends Node
## P1 冒烟：headless 打完一场战斗，断言能分出胜负且胜负事件恰好一次。
## 契约：result 为空时每 tick 至少产出一个事件（TICK 恒在），这里显式校验。

const BattleSim = preload("res://src/core/battle_sim.gd")
const Events = preload("res://src/core/events.gd")

const MAX_TICKS := 20000

func _ready() -> void:
	var sim = BattleSim.new({"hero_damage": 0})  # 无伤害英雄：必败路径，可确定终止
	var ticks := 0
	while sim.result == "" and ticks < MAX_TICKS:
		ticks += 1
		var events: Array = sim.step()
		if events.is_empty():
			push_error("第 %d tick 未产出事件" % ticks)
			get_tree().quit(1)
			return
	if ticks >= MAX_TICKS:
		push_error("超出 tick 上限仍未分出胜负")
		get_tree().quit(1)
		return
	if sim.result != "defeat" or sim.castle_hp != 0:
		push_error("无伤害配置应判负且城堡归零: result=%s castle=%d" % [sim.result, sim.castle_hp])
		get_tree().quit(1)
		return
	print("SMOKE_OK result=%s castle_hp=%d ticks=%d" % [sim.result, sim.castle_hp, ticks])
	get_tree().quit(0)
```

`tests/smoke/smoke_battle.tscn`：

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/smoke/smoke_battle.gd" id="1_smoke"]

[node name="SmokeBattle" type="Node"]
script = ExtResource("1_smoke")
```

- [ ] **Step 6: 导入 + 单测 + 冒烟**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
"$GODOT" --headless --path . res://tests/smoke/smoke_battle.tscn 2>&1 | tail -3
```

Expected: GUT `19 passed / 0 failed`（17 + 7 新增 − 3 退役 P0 tick 测试）；冒烟输出 `SMOKE_OK result=defeat castle_hp=0 ticks=803` 附近（约 800±10，以实际为准≥700 且 ≤900）。

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: BattleSim 实体战——生成/移动/漏怪/城堡扣血+败北锁定"
```

---

### Task 4: 英雄索敌攻击 + 击杀 + 胜利锁定（P1 规则层完成）

**Files:**
- Modify: `src/core/events.gd`（追加 ATTACK/HURT/MONSTER_DIED/VICTORY）
- Modify: `src/core/battle_sim.gd`（加 `_step_attack` 并在 `step()` 接线）
- Modify: `tests/unit/test_battle_sim.gd`（追加攻击/击杀/默认胜利测试）
- Modify: `tests/smoke/smoke_battle.gd`（断言翻转为默认配置可守住）

**Interfaces:**
- Consumes: Task 3 全部 Produces。
- Produces: 每步事件序 = `[TICK, (SPAWN), MOVE…, (ATTACK, HURT, MONSTER_DIED), (LEAK…), (VICTORY|DEFEAT)]`；攻击规则——冷却随时间回落至 0，射程内最近存活怪为目标，无目标不空转 CD；伤害 `max(0, hero_damage - armor)`；`hp<=0` 即死并停发 MOVE。P1 完成标志（默认配置 headless 稳定获胜）在本任务达成。

- [ ] **Step 1: 追加失败测试**

在 `tests/unit/test_battle_sim.gd` 末尾追加：

```gdscript

func test_hero_attacks_in_range_and_damage_applied():
	var sim = BattleSim.new({"total_spawns": 1})
	var attacks := 0
	var hurts := 0
	var first_damage := -1
	for i in 300:
		for e in sim.step():
			if e.type == Events.ATTACK:
				attacks += 1
				if first_damage < 0:
					first_damage = e.data.damage
			elif e.type == Events.HURT:
				hurts += 1
	assert_gt(attacks, 0)
	assert_eq(attacks, hurts)
	assert_eq(first_damage, 12)

func test_hero_out_of_range_never_attacks():
	var sim = BattleSim.new({"hero_range_tiles": 0.5, "total_spawns": 1})
	var attacks := 0
	for i in 300:
		for e in sim.step():
			if e.type == Events.ATTACK:
				attacks += 1
	assert_eq(attacks, 0)  # 射程 0.5 < 离路 1.0，够不到任何怪

func test_armor_reduces_damage():
	var sim = BattleSim.new({"monster_armor": 5, "total_spawns": 1})
	var hurt_hp := -1
	for i in 300:
		for e in sim.step():
			if e.type == Events.HURT and hurt_hp < 0:
				hurt_hp = e.data.hp
				assert_eq(e.data.damage, 7)
	assert_eq(hurt_hp, 23)

func test_kill_emits_monster_died():
	var sim = BattleSim.new({"total_spawns": 1})
	var died := 0
	var t := 0
	while sim.result == "" and t < 2000:
		t += 1
		for e in sim.step():
			if e.type == Events.MONSTER_DIED:
				died += 1
	assert_eq(died, 1)
	assert_eq(sim.result, "victory")

func test_default_config_holds_castle_victory():
	# P1 完成标志：默认数值 10 只全歼、城堡满血（数值已原型验证：约 681 tick）
	var sim = BattleSim.new()
	var victories := 0
	var died := 0
	var t := 0
	while sim.result == "" and t < 20000:
		t += 1
		for e in sim.step():
			if e.type == Events.VICTORY:
				victories += 1
			elif e.type == Events.MONSTER_DIED:
				died += 1
	assert_eq(sim.result, "victory")
	assert_eq(sim.castle_hp, 10)
	assert_eq(died, 10)
	assert_eq(victories, 1)
	assert_lt(t, 20000)

func test_victory_locks_sim():
	var sim = BattleSim.new({"total_spawns": 1})
	_run_to_end(sim)
	assert_eq(sim.result, "victory")
	var frozen_tick: int = sim.tick_count
	var events: Array = sim.step()
	assert_eq(events.size(), 0)
	assert_eq(sim.tick_count, frozen_tick)
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_battle_sim.gd -gexit
```

Expected: 新增测试 FAIL（`ATTACK/HURT/MONSTER_DIED/VICTORY` 常量缺失，攻击从未发生）。

- [ ] **Step 3: 事件常量追加**

`src/core/events.gd` 追加：

```gdscript

const ATTACK := "attack"
const HURT := "hurt"
const MONSTER_DIED := "monster_died"
const VICTORY := "victory"
```

- [ ] **Step 4: `battle_sim.gd` 实装攻击**

`_init` 里 `hero` 字典追加键（`"cooldown": 0.0` 之前的写法若已存在则保持）：

```gdscript
	hero = {
		"cell": config.get("hero_cell", DEFAULT_HERO_CELL),
		"damage": config.get("hero_damage", 12),
		"attack_interval": config.get("hero_attack_interval", 0.8),
		"range_tiles": config.get("hero_range_tiles", 1.5),
		"cooldown": 0.0,
	}
```

`step()` 中 `_step_move(events)` 之后插入一行 `_step_attack(events)`（在 `_check_result(events)` 之前）：

```gdscript
	_step_spawn(events)
	_step_move(events)
	_step_attack(events)
	_check_result(events)
```

文件末尾追加两个方法：

```gdscript

func _step_attack(events: Array) -> void:
	hero.cooldown = maxf(0.0, hero.cooldown - DT)
	if hero.cooldown > 0.0:
		return  # 冷却中：不索敌不结算
	var target = _nearest_monster_in_range()
	if target == null:
		return  # 无目标：冷却停在 0，目标进射程立即开火
	var damage: int = maxi(0, _hero_damage - target.def.armor)
	target.hp -= damage
	hero.cooldown = _hero_attack_interval  # 释放成功才转 CD
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
	if best == null or best_d > _hero_range_tiles:
		return null
	return best
```

同时删除 `_init` 中的临时冗余字段 `_hero_damage/_hero_attack_interval/_hero_range_tiles` 与对应赋值（改为直接读 `hero.damage` 等），即攻击方法里用 `hero.damage / hero.attack_interval / hero.range_tiles`。最终 `_init` 不再保留这三个下划线字段。

- [ ] **Step 5: 冒烟翻转为默认配置**

`tests/smoke/smoke_battle.gd` 中：

```gdscript
	var sim = BattleSim.new({"hero_damage": 0})  # 无伤害英雄：必败路径，可确定终止
```

替换为：

```gdscript
	var sim = BattleSim.new()  # 默认数值：P1 完成标志——默认可守住
```

并把结果校验替换为：

```gdscript
	if sim.result != "victory" or sim.castle_hp <= 0:
		push_error("默认配置应守住: result=%s castle=%d" % [sim.result, sim.castle_hp])
		get_tree().quit(1)
		return
```

（`SMOKE_OK` 打印行保持不变。）

- [ ] **Step 6: 导入 + 单测 + 冒烟 + 全量**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
"$GODOT" --headless --path . res://tests/smoke/smoke_battle.tscn 2>&1 | tail -3
```

Expected: GUT `25 passed / 0 failed`；冒烟输出 `SMOKE_OK result=victory castle_hp=10 ticks=681` 附近（600–800 均可，超出即回查数值）。

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: 英雄索敌攻击+击杀+胜利锁定——P1 规则层完成"
```

---

### Task 5: Game 接线 .tres 数据 + 只读布局暴露

**Files:**
- Modify: `src/autoload/game.gd`

**Interfaces:**
- Consumes: `HeroDef/MonsterDef` .tres（P0 Task 4）；`BattleSim.new(config)`（Task 3/4）。
- Produces（表现层依赖）: `Game.battle_grid`（Grid 只读引用）、`Game.hero_cell: Vector2i`、`Game.castle_cell: Vector2i`。战斗数值改由 `resources/` .tres 注入（与 sim 默认值同值）。

- [ ] **Step 1: `game.gd` 整体替换**

```gdscript
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
var battle_grid = null          # 只读：Grid（网格/路径）
var hero_cell := Vector2i.ZERO  # 只读：英雄所在格
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
```

- [ ] **Step 2: 导入 + headless 实跑验证**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --quit-after 600 2>&1 | grep -iE "error|script" | head -5; echo "exit=${PIPESTATUS[0]}"
```

Expected: 无脚本报错栈，`exit=0`（600 帧 ≈ 30 秒 ≈ 战斗中段，加载 .tres 与事件广播均无异常）。

- [ ] **Step 3: 全量回归 + Commit**

```bash
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
git add -A
git commit -m "feat: Game 接线 .tres 战斗数值+暴露只读战场布局"
```

Expected: `25 passed / 0 failed`。

---

### Task 6: 战场渲染 + HUD（P1 完成标志收尾）

**Files:**
- Create: `src/view/battle_view.gd`
- Modify: `src/autoload/main.gd`

**Interfaces:**
- Consumes: `Game.event_emitted`、`Game.battle_grid / hero_cell / castle_cell`（Task 5）。
- Produces: 运行窗口内可见：网格线、路径格（深色）、城堡（金色格）、英雄（蓝圆）、怪物（红圆，沿路径移动、死亡/漏怪即消失）；底部 HUD 显示城堡 HP 与「胜利！」/「冒险失败」。P1 完成标志达成：能打一场最糙的仗分出胜负。

- [ ] **Step 1: 写 `src/view/battle_view.gd`**

```gdscript
extends Node2D
## P1 战场渲染（最糙版）：网格线/路径格/城堡/英雄/怪物色块。
## 只消费 Game 的事件与只读布局，不改规则层状态。

const Events = preload("res://src/core/events.gd")
const CELL := 48

var _monster_pos := {}  # id -> Vector2（格单位）

func _ready() -> void:
	Game.event_emitted.connect(_on_event)

func _on_event(event: Dictionary) -> void:
	match event.type:
		Events.SPAWN:
			_monster_pos[event.data.id] = event.data.pos
		Events.MOVE:
			_monster_pos[event.data.id] = event.data.pos
		Events.LEAK, Events.MONSTER_DIED:
			_monster_pos.erase(event.data.id)
	queue_redraw()

func _draw() -> void:
	if Game.battle_grid == null:
		return
	var grid = Game.battle_grid
	for x in grid.width + 1:
		draw_line(Vector2(x, 0) * CELL, Vector2(x, grid.height) * CELL, Color(0.22, 0.22, 0.24))
	for y in grid.height + 1:
		draw_line(Vector2(0, y) * CELL, Vector2(grid.width, y) * CELL, Color(0.22, 0.22, 0.24))
	for cell in grid.path_cells.keys():
		if grid.in_bounds(cell):
			draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), Color(0.35, 0.28, 0.18))
	draw_rect(Rect2(Vector2(Game.castle_cell) * CELL, Vector2(CELL, CELL)), Color(0.85, 0.7, 0.2))
	var hero_px: Vector2 = Vector2(Game.hero_cell) * CELL + Vector2(CELL / 2.0, CELL / 2.0)
	draw_circle(hero_px, 16.0, Color(0.3, 0.55, 1.0))
	for id in _monster_pos.keys():
		draw_circle(_monster_pos[id] * CELL, 12.0, Color(0.85, 0.25, 0.2))
```

- [ ] **Step 2: `main.gd` 整体替换**

```gdscript
extends Node2D
## P1 主场景：战场渲染 + 城堡 HP 与胜负 HUD。

const Events = preload("res://src/core/events.gd")
const BattleView = preload("res://src/view/battle_view.gd")

var _label: Label

func _ready() -> void:
	add_child(BattleView.new())
	_label = Label.new()
	_label.position = Vector2(16, 496)
	_label.text = "城堡 HP: 10"
	add_child(_label)
	Game.event_emitted.connect(_on_event)

func _on_event(event: Dictionary) -> void:
	match event.type:
		Events.LEAK:
			_label.text = "城堡 HP: %d" % event.data.castle_hp
		Events.VICTORY:
			_label.text = "胜利！城堡 HP %d——P1 完成" % event.data.castle_hp
		Events.DEFEAT:
			_label.text = "冒险失败……"
```

- [ ] **Step 3: 导入 + headless 实跑 + 全量回归**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --quit-after 900 2>&1 | grep -iE "error|script" | head -5; echo "exit=${PIPESTATUS[0]}"
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: 无脚本报错栈、`exit=0`；GUT `25 passed / 0 failed`。再手动 `F5`（或跑 Godot 编辑器）确认：怪物红点沿深色路径移动、被蓝点英雄击杀消失、漏怪扣 HP、约 35 秒后显示「胜利！城堡 HP 10——P1 完成」。

- [ ] **Step 4: Commit（P1 收尾）**

```bash
git add -A
git commit -m "feat: 战场渲染+城堡HP/胜负 HUD——P1 最小战斗完成"
```

---

## Self-Review 记录

- Spec 覆盖：P1 行五要素——网格+路径渲染（T2 规则层 + T6 渲染）、怪走路径（T3）、1 英雄索敌攻击（T4）、城堡HP/漏怪（T3）、胜负（T3 败北 / T4 胜利+锁定）；完成标志"能打一场最糙的仗分出胜负"由 T4 默认胜利冒烟 + T6 可视收尾共同达成。
- 占位符扫描：无 TBD/TODO；所有步骤含逐字代码。
- 类型一致性：`Events.SPAWN/MOVE/LEAK/DEFEAT/ATTACK/HURT/MONSTER_DIED/VICTORY`、`BattleSim(config)`、`step()->Array`、`result/castle_hp/grid/hero/monsters`、`Game.battle_grid/hero_cell/castle_cell` 各任务间引用一致；VICTORY 常量提前至 T3 定义（T3 的 sim 代码即引用），T4 补攻击类常量。
- 数值断言均已用原型实测验证（默认胜利 681 tick / 无伤害判负 803 tick / 位移 (0.7,1.5) / 护甲后 hp 23）。
