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
