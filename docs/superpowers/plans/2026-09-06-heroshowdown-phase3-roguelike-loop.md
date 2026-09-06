# HeroShowdown P3（肉鸽循环）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans。步骤用 `- [ ]` 跟踪。

**Goal:** 从头打完 5 关一条完整冒险：肉鸽事件 3 选 1（8 事件池、冒险内不重复）、备战商店（跨关金币/布阵持久）、5 关递进（波次表+主题色+怪物强度）、通关/失败结算+重开。

**Architecture:** 新增规则层 `src/core/run/`：`run_state.gd`（冒险状态：城堡/金币/阵容/全局加成/已用事件/种子 RNG）、`run_event_system.gd`（抽 3 应用 1）；`game.gd` 升级为冒险状态机（事件→备战[暂停的 sim]→战斗→结算→下一关 / 失败 / 通关）；`BattleSim` 增加 config 扩展（roster 预部署、全局攻/速/CD 乘算、怪 HP 乘算、金币乘算、击杀计数）。波次表以紧凑字符串格式进 `resources/levels/*.tres`（格式 `def_id:count:interval`，分号分组）。

**设计改编（需知悉）:** ①主菜单/暂停不在本阶段（直接进第 1 关备战，上架前补）；②「调整布阵」简化为跨关保留布阵、商店只买新/升级（不做移除/移动）；③每关末波含精英（石魔群）或 boss（巨魔王），L5 末波双 boss 决战。

**数值口径（执行期以冒烟实测微调并回写）:**
- 事件 8（kind:value）：attack 全局攻+20%｜attack_speed 全局攻速+15%｜gold 立得 80｜castle 城堡+5HP｜cooldown 技能CD-20%｜levelup 随机英雄+1级｜elite 本关怪HP×1.3·金币×2｜chest 随机 60~120 金或本关攻+30%（50/50）
- 关卡递进（倍数=波次表内已折算；hp_mult 逐关 1.0/1.15/1.3/1.5/1.7；theme 色：森林绿/森林深绿/荒漠黄/荒漠橙/堡垒灰）：
  - L1=P2 默认表原样；L2 counts+40%·interval×0.94；L3 +80%·×0.88；L4 +120%·×0.82；L5 +160%·×0.76（末波 boss×2）
- 结算：冒险用时=各战斗 tick×DT 累加；总击杀=各战斗 kill_count 累加

## Global Constraints

- 延续 P0-P2 全部约束（规则层 RefCounted/禁 Node/20tps/事件不可变/GUT preload/每任务全绿提交/数值偏差实测微调回写）。
- RNG：`RunState.rng`（`RandomNumberGenerator`，`seed` 可注入；测试与冒烟用固定种子保证确定性）。
- 事件池：同一冒险内不重复抽取；3 选 1 每关一次（第 1 关直接备战无事件）。
- 冒险流程：L1 备战→战斗→[L2~L5：结算→事件3选1→备战]→……→L5 胜=通关结算；任一关城堡归零=失败结算；两结算屏均有「重新开始」。

---

### Task 1: RunState + EventDef/LevelDef + 事件系统 + 数据表

**Files:** Create `src/core/run/run_state.gd`、`src/core/run/run_event_system.gd`、`src/core/def/event_def.gd`、`src/core/def/level_def.gd`、`resources/events/*.tres`×8、`resources/levels/*.tres`×5；Test `tests/unit/test_run_state.gd`。

**Interfaces:**
- `EventDef`：`id/title/desc/kind/value`（kind 见数值口径）。
- `LevelDef`：`id/display_name/theme_color:Color/hp_mult:float/waves:PackedStringArray`（每项一波，组用逗号连接 `def_id:count:interval`）。
- `RunState.new(seed:=0)`：`level_index:=0`、`castle_hp:=10`、`castle_max:=10`、`gold:=100`、`attack_mult:=1.0`、`interval_mult:=1.0`、`cd_mult:=1.0`、`kills_total:=0`、`ticks_total:=0`、`roster:Array[Dictionary]`、`used_event_ids`、`elite_gold_mult:=1.0`、`elite_hp_mult:=1.0`（每关开战前重置）、`rng`；方法 `draw_events(pool:Array, n:=3) -> Array`（排除已用，rng 抽取）、`apply_event(def) -> void`（按 kind 改状态；chest 用 rng 50/50、levelup 随机 roster 成员 level+1）、`next_level()`。
- `RunEventSystem`：`load_pool() -> Array`（读 8 张 .tres）。
- 测试：固定种子抽 3 不重复、8 种 kind 效果各 1 断言、levelup/chest 的 rng 确定性。

- [ ] RED→实现→GREEN→`git commit -m "feat: RunState+事件系统+8事件5关卡数据表"`

### Task 2: BattleSim 冒险扩展（roster/全局乘算/统计）

**Files:** Modify `src/core/battle_sim.gd`；Test `tests/unit/test_battle_sim.gd` 追加。

**Interfaces:** config 新键 `roster:[{def_id,cell,level,damage_mult,interval_mult}]`（开局免费预部署）、`attack_mult/interval_mult/cd_mult/gold_mult/monster_hp_mult`（默认 1.0）；Hero 创建时 `damage_mult=attack_mult× roster 值`、`interval_mult` 同理；施放 CD=`skill_cooldown×cd_mult`；出生 HP=`ceil(max_hp×monster_hp_mult)`；击杀金=`ceil(gold_drop×gold_mult)`；新增属性 `kill_count`。测试：roster 预部署免费、三乘算各自生效、kill_count。

- [ ] RED→实现→GREEN→`git commit -m "feat: BattleSim 冒险扩展——roster预部署/全局乘算/击杀统计"`

### Task 3: Game 冒险状态机 + 阶段 UI

**Files:** Rewrite `src/autoload/game.gd`、`src/autoload/main.gd`；Modify `src/view/battle_view.gd`（主题色）。

**Interfaces:**
- Game 状态 `phase`：`event`(L2~ 关前，3 选 1)→`prep`(创建本关 sim：roster/乘算/hp_mult/gold_mult 注入，`running=false`，可 request_deploy/upgrade)→`battle`(`start_battle_phase()` 置 running)→胜利：结算数据入 RunState（kills/ticks/gold 同步）→`event` 或 `adventure_win`；城堡 0→`adventure_lose`。`restart_adventure()` 回 L1 prep。`pick_event(i)`、`begin_prep()`、`start_battle_phase()`。
- main.gd：事件面板（3 按钮 title+desc）、备战面板（买/升按钮沿用 + 「开战」按钮）、战斗 HUD（P2 沿用）、结算面板（通关/失败文案+总击杀/剩余城堡/用时+重新开始）；battle_view 背景按 `LevelDef.theme_color`。
- 验证：headless 900 帧零报错 + GUT 全绿 + 手动 F5 走通一关。

- [ ] 实现→验证→`git commit -m "feat: 冒险状态机+事件/备战/结算UI+主题色"`

### Task 4: 完整冒险冒烟 + 数值校准

**Files:** Create `tests/smoke/smoke_adventure.gd/.tscn`（保留 smoke_battle 作单关回归）。

**Interfaces:** 固定种子自动玩家：备战期按 BUY_PLAN 买满+升攻、每关事件固定选 attack>attack_speed>gold 优先、战斗期全英雄 try_skill；断言：打满 5 关、30 波全清、冒险胜利、全程 gold≥0、castle_hp>0、打印 `SMOKE_ADVENTURE_OK ...`。数值不可通关则微调 hp_mult/波次表并回写本计划。

- [ ] RED→调平→GREEN→`git commit -m "test: 完整冒险冒烟——5关通关——P3 完成"`→`git push`
