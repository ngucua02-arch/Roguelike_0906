# HeroShowdown P2（战斗完整）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一场战斗内容全量、操作闭环：5 英雄（各带 1 主动技能）+ 5 怪 + boss（特性）、6 波波次调度、局内金币（击杀/波奖/购买/升级）、波间休整购买、×2 加速、完整 HUD。

**Architecture:** 规则层拆分模块：`battle/entities.gd`（英雄/怪物状态）、`battle/economy.gd`（金币账目）、`battle/skill_system.gd`（5 技能效果）、`battle/wave_director.gd`（波次/休整）、`battle/default_defs.gd`（内置默认数值表），`battle_sim.gd` 收敛为编排器并新增请求层 `try_deploy/try_upgrade/try_skill`；`game.gd` 转发请求 + ×2 加速；`battle_view/main` 补 HUD 操作闭环。波次表本阶段为内置数据（`waves/*.tres` 随 P3 关卡递进入库）。

**Tech Stack:** Godot 4.7 标准版、GDScript、GUT 9.7.1。

**Spec:** `docs/superpowers/specs/2026-09-05-heroshowdown-demo-design.md`（实现路线图 P2；城堡 10HP、漏小怪扣 1 漏 boss 扣 3、波间休整约 5 秒、每次升级 攻击力/攻速 二选一）

**设计改编（需知悉）:** 牧师「范围治疗友军/圣盾·短时减伤」——英雄无 HP 模型下治疗/减伤无法成立；改编为**圣盾：范围内友军英雄攻速提升 + 免疫巨魔王踩踏眩晕**（支援定位不变，数值 P5 复核）。

**数值口径（P5 统一调平衡前首版）:**
- 英雄（cost/伤害/间隔秒/射程/技能 kind,cd,伤害,半径,附加）：剑士 60/12/0.8/1.5/whirl,8s,20,1.5；弓手 80/9/0.6/3.5/arrow_rain,12s,24,1.5（以当前目标为中心，无目标则失败）；法师 100/14/1.2/3.0/frost_ring,10s,12,2.0,减速50%3秒；炮手 140/32/2.2/4.5/barrage,15s,55,2.5；牧师 90/6/1.5/2.5/aegis,12s,半径2.0,急速30%持续4秒
- 怪物（HP/速/甲/金/特性）：哥布林 30/1.2/0/3；疾行狼 25/2.0/0/4；兽人 60/1.0/2/5；萨满 45/0.9/1/6/治疗光环 r2.0 +8HP/3秒；石魔 150/0.6/8/8；巨魔王 800/0.5/6/50/boss·踩踏 r2.5 每6秒 眩晕2秒·漏怪扣3
- 经济：初始 100；升级 40 金币/次，伤害 ×1.3 或 间隔 ×0.85（乘算叠加）；波次奖励 20+5×波序
- 波次表（6 波，groups=[{def_id,count,interval}]）：W1 哥布林×6@1.2；W2 哥布林×6@1.0+狼×3@1.5；W3 兽人×6@1.6；W4 狼×4@0.9+萨满×1@2.0+兽人×4@1.6；W5 石魔×3@3.0+萨满×2@2.0+兽人×6@1.4；W6 兽人×8@1.2+石魔×2@3.0+萨满×2@2.0+巨魔王×1@1.0

## Global Constraints

- 延续 P1 全部约束：`src/core/` 仅 RefCounted（Def 为 Resource）、禁 Node 引用、20tps、事件字典不可变、`TICK` 恒为每步首事件、格单位坐标、GUT 用 preload、每任务全绿才提交。
- 请求层（表现层 → `Game` → sim）：`request_deploy(def_id, cell)` / `request_upgrade(hero_id, stat)` / `request_skill(hero_id)`；合法性校验在规则层，失败发 `buy_failed`/`skill_failed` 事件，不改状态。
- 部署合法性：格在界内、非路径格、未被占、四邻至少一路径格、金币足够。
- 技能规则：冷却自**释放成功**起转；眩晕中不可放；`arrow_rain` 需有当前目标。
- 事件新增（常量入 `events.gd`）：`deployed/buy_failed/upgraded/skill_cast/skill_failed/gold_gained/wave_started/wave_cleared/slowed/healed/stunned`。
- 部署预设合法格（测试与自动玩家用）：`(12,2)/(11,2)/(12,3)/(12,4)/(12,5)`（均四邻路径）。
- 数值断言若与实测偏差（浮点/节奏），以执行期实测微调**数值**并回写本计划，结构断言不可放宽。

## 运行测试的命令（每个 Task 复用）

```bash
GODOT="G:/Zcode/tools/godot/Godot_v4.7-stable_win64.exe"
cd "G:/Zcode/project/HeroShowdown"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
"$GODOT" --headless --path . res://tests/smoke/smoke_battle.tscn 2>&1 | tail -3
```

---

### Task 1: Def 全量扩展 + 11 张 .tres 数据表

**Files:**
- Rewrite: `src/core/def/hero_def.gd`、`src/core/def/monster_def.gd`
- Create: `resources/heroes/{swordsman,archer,mage,cannonier,priest}.tres`（swordsman 重写）
- Create: `resources/monsters/{goblin,wolf,orc,shaman,golem,ogre_lord}.tres`（goblin 重写）
- Modify: `tests/unit/test_def_pipeline.gd`

**Interfaces:**
- Produces: `HeroDef`（`id/display_name/cost/attack_damage/attack_interval/range_tiles/skill_name/skill_kind/skill_cooldown/skill_damage/skill_radius/skill_slow_pct/skill_slow_duration/skill_haste_pct/skill_duration`）与 `MonsterDef`（`id/display_name/max_hp/move_speed/armor/gold_drop/leak_damage/heal_radius/heal_amount/heal_interval/is_boss/stomp_radius/stomp_interval/stomp_stun_duration`）。

- [ ] Step 1: 改写两个 Def 类（上方 Interfaces 即全部字段与默认值：HeroDef 默认 cost=50、skill_cooldown=10、skill_radius=1.5；MonsterDef 默认 leak_damage=1、heal_interval=3、stomp_interval=6、stomp_stun_duration=2）
- [ ] Step 2: 写 11 张 .tres（数值口径见上；.tres 头 `script_class="HeroDef"/"MonsterDef"`，ext_resource 引各自脚本，id=文件名）
- [ ] Step 3: `test_def_pipeline.gd` 改写：逐张加载断言关键字段（每张至少 3 断言：id、数值、技能/特性字段）
- [ ] Step 4: `--import` + 全量 GUT 绿（27 + 新增 − 旧 2）→ `git commit -m "feat: Def 全量扩展+11张英雄怪物数据表"`

---

### Task 2: entities + 索敌

**Files:**
- Create: `src/core/battle/entities.gd`（`Hero`/`Monster` 内部类）、`src/core/battle/targeting.gd`
- Test: `tests/unit/test_entities.gd`

**Interfaces:**
- Produces: `Entities.Hero.new(id, def, cell)`——属性 `id/def/cell/level/damage_mult(1.0)/interval_mult(1.0)/attack_cd(0)/skill_cd(0)/stun_timer/haste_timer/aegis_timer`；方法 `damage() -> int`（`round(def.attack_damage*damage_mult)`）、`attack_interval() -> float`（`def.attack_interval*interval_mult`，急速时 `×100/(100+skill_haste_pct)`）。`Entities.Monster.new(id, def)`——`id/def/path_dist(0)/hp/alive(true)/slow_timer(0)/slow_factor(1.0)/heal_timer(=heal_interval)/stomp_timer(=stomp_interval)`；方法 `move_speed()`（`def.move_speed×(slow_factor if slow_timer>0 else 1)`）、`pos(grid)`（`grid.point_at(path_dist)`）。`Targeting.nearest_in_range(monsters, grid, from_pos, range_tiles)` → 怪或 null。

- [ ] Step 1: 失败测试：英雄伤害乘算/急速间隔、怪物减速移速、索敌最近且超程返回 null（怪 path_dist 手工设置）
- [ ] Step 2: RED → 实现 → GREEN（全量 GUT）→ `git commit -m "feat: 英雄/怪物实体与最近索敌"`

---

### Task 3: 经济

**Files:**
- Create: `src/core/battle/economy.gd`
- Test: `tests/unit/test_economy.gd`

**Interfaces:**
- Produces: `Economy.new(start_gold)`；`gold`、`can_afford(n)`、`spend(n)`（调用方保证可负担）、`gain(n)`；常量 `UPGRADE_COST=40`、`UPGRADE_DAMAGE_MULT=1.3`、`UPGRADE_INTERVAL_MULT=0.85`。
- [ ] Step 1-3: TDD（初始/收入/支出/不足判断/常量值）→ `git commit -m "feat: 局内经济——金币账本与升级乘算常量"`

---

### Task 4: 技能系统（5 技能）

**Files:**
- Create: `src/core/battle/skill_system.gd`
- Test: `tests/unit/test_skill_system.gd`

**Interfaces:**
- Consumes: `Entities.Hero/Monster`、grid（`point_at/cell_to_pos`）。
- Produces: `SkillSystem.cast(sim, hero) -> Array`（成功=效果事件数组（含 `skill_cast`）；失败=`[]`，由 sim 发 `skill_failed`）。效果：`whirl`=立即对 hero 周围 `skill_radius` 全体怪 `skill_damage`；`arrow_rain`=需 hero 当前有射程内目标（传入 `sim` 查），以**目标怪**为中心半径内全体 `skill_damage`；`frost_ring`=hero 周围 `skill_radius` 伤害+`slowed{id,duration}`（怪 `slow_timer=max(现,skill_slow_duration)`、`slow_factor=1-skill_slow_pct/100`）；`barrage`=hero 周围 `skill_radius` 高伤；`aegis`=`skill_radius` 内友军（不含自己? 含自己）`haste_timer=skill_duration`、`aegis_timer=skill_duration`、事件 `hasted`（表现层用）。伤害走 `sim.apply_damage(monster, dmg, events)`（护甲、死亡、`HURT/MONSTER_DIED` 复用）。
- [ ] Step 1: 失败测试（构造 sim+hero：5 技能各 1-2 断言：效果命中数/伤害值/slow 后移速/失败分支 arrow_rain 无目标返回 []）
- [ ] Step 2: RED → 实现 → GREEN → `git commit -m "feat: 技能系统——旋风斩/箭雨/冰环/轰击/圣盾"`

---

### Task 5: 波次调度

**Files:**
- Create: `src/core/battle/wave_director.gd`
- Test: `tests/unit/test_wave_director.gd`

**Interfaces:**
- Produces: `WaveDirector.new(waves)`（waves 结构见数值口径）；`index`（-1 起）、`phase`（`idle/wave/break/finished`）、`break_left`；`start_next_wave()`（index+1、组深拷贝 `{def_id,left,timer}`、timer 初值=组 interval）、`tick(dt) -> Array[String]`（wave：推进组计时出队 def_id；break：倒计时到 0 自动 `start_next_wave`；返回本 tick 出场 id 列表）、`exhausted()`（全部组 left==0）、`announce_clear() -> Dictionary`（`{cleared:true,is_last:bool}`；末波 phase=`finished`，否则 phase=`break`、`break_left=BREAK_SECONDS`）、`is_finished()`、`current_bonus()`（`20+5×(index+1)`）。
- [ ] Step 1: 失败测试（2 波迷你表：首波出场节奏/耗尽判定/清波转休整/休整 5 秒自动下一波/末波 finished）
- [ ] Step 2: RED → 实现 → GREEN → `git commit -m "feat: 波次调度——逐波出场/波间休整5秒/末波收尾"`

---

### Task 6: BattleSim 整合（请求层/特性/事件）

**Files:**
- Create: `src/core/battle/default_defs.gd`
- Rewrite: `src/core/battle_sim.gd`
- Modify: `src/core/events.gd`（追加 11 常量）
- Rewrite: `tests/unit/test_battle_sim.gd`（保留 P1 可复用断言，改多英雄/请求层形态）

**Interfaces:**
- Consumes: T2-T5 全部。
- Produces: `BattleSim.new(config={})`——config 键：`hero_defs(Array[HeroDef],默认 default_defs.heroes())`、`monster_defs(Array[MonsterDef],默认 default_defs.monsters())`、`waves(默认 default_defs.waves())`、`start_gold(100)`、`castle_hp(10)`、`waypoints`。属性：`tick_count/castle_hp/result/grid/gold/director/heroes/monsters/hero_defs/monster_defs`（monster_defs 转成 id→def 字典 `monster_def_by_id`）；方法：`step() -> Array`（TICK 首位，序：波调度 spawn→移动/漏怪→英雄攻击→特性(萨满治疗/踩踏眩晕)→清波/胜负）、`try_deploy(def_id,cell) -> bool`（合法性见 Global Constraints；成功发 `deployed{hero_id,def_id,cell}`）、`try_upgrade(hero_id,stat) -> bool`（stat `"damage"/"interval"`；乘算叠加、`upgraded{hero_id,stat,level}`）、`try_skill(hero_id) -> bool`（`skill_cast{hero_id,kind}` 或 `skill_failed{hero_id,reason}`）、`apply_damage(m,dmg,events)`（护甲≥伤则 0 伤仍发 HURT；`MONSTER_DIED`）、`kill_reward(m,events)`（`gold_gained{amount,total,reason:"kill"}`）。特性：萨满 `heal_timer` 到点治疗半径内受伤怪（`healed{id,hp}`）；boss `stomp_timer` 到点眩晕半径内非圣盾英雄（`stunned{hero_id,duration}`）；英雄 `stun/haste/aegis` 计时随 tick 回落，眩晕不攻击、技能请求被拒。胜负：城堡 ≤0 判负；末波清空且场上无存活怪判胜；锁定语义同 P1。
- [ ] Step 1: 失败测试（①部署合法/非法三态与扣费 ②升级乘算与扣费 ③技能请求冷却/眩晕拒绝 ④萨满治疗掉血怪 ⑤踩踏眩晕与圣盾免疫 ⑥漏 boss 扣 3 ⑦6 波默认表跑通胜负锁定）
- [ ] Step 2: RED → 实现 → GREEN（含 `--import` 生成 .uid）→ `git commit -m "feat: BattleSim 整合——请求层/波次/特性/胜负（P2 规则层完成）"`

---

### Task 7: Game 请求层+×2 加速 + HUD 闭环 + 自动玩家冒烟

**Files:**
- Rewrite: `src/autoload/game.gd`、`src/autoload/main.gd`、`src/view/battle_view.gd`、`tests/smoke/smoke_battle.gd`

**Interfaces:**
- Produces: `Game.speed_multiplier`（1.0/2.0，`_physics_process` 用 `delta*multiplier`）、`Game.request_deploy/request_upgrade/request_skill`、`Game.battle`（sim 只读约定）、`Game.toggle_speed()`；HUD：顶部金币/波次/加速按钮，买英雄面板（5 按钮+放置模式：点按钮→点战场格部署），底部英雄卡（技能按钮含 CD 秒数、升攻/升速按钮），城堡 HP/胜负文本沿 P1。`battle_view` 补 `_unhandled_input` 点击换格（`get_global_mouse_position()/48` 取整）。冒烟：自动玩家（开局部署剑士@`(12,2)`；每次清波按 弓手→法师→炮手→牧师 优先在预设格购买，否则升级伤害；每 tick 全英雄 `try_skill`）跑到终局，断言：终局分出胜负、`wave_started×6`、boss 至少 1 只出场、金币全程 ≥0、默认策略**胜利**（数值若实测不可达：微调数值口径并回写本计划）。
- [ ] Step 1: 实装 + `--import` + headless 900 帧零报错 + GUT 全绿
- [ ] Step 2: 冒烟重写并跑到 `SMOKE_OK result=victory ... waves=6`（实测 tick 数回写此处）
- [ ] Step 3: `git commit -m "feat: HUD 操作闭环+×2加速+自动玩家冒烟——P2 完成"`

---

## Self-Review 记录

- Spec 覆盖：P2 行五要素——全量内容（T1/T6）、技能系统冷却/目标/效果（T4）、局内金币（T3/T6）、波间购买+升级（T5/T6/T7 HUD）、×2 加速（T7）；完成标志「内容全量、操作闭环」由 T7 冒烟+HUD 达成。波间休整 5 秒（T5）。
- 占位符扫描：无 TBD；所有效果/请求/事件给出确切名称与语义。
- 类型一致性：`try_deploy/try_upgrade/try_skill`、`SkillSystem.cast(sim,hero)`、`WaveDirector.tick(dt)`、`Entities.Hero.damage()/attack_interval()`、`Targeting.nearest_in_range(...)` 各任务引用一致；事件常量名唯一。
- 牧师改编已显式标注；数值偏差处理规则已写入 Global Constraints。
