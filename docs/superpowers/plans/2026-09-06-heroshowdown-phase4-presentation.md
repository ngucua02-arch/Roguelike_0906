# HeroShowdown P4（表现）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans。

**Goal:** 视觉可展示：Kenney CC0 像素素材替换全部色块、攻击弹道/命中闪白/伤害飘字/技能圆环特效、HUD 统一风格打磨。

**Architecture:** 纯表现层改动，规则层零改动——特效全部由既有事件流驱动（ATTACK/HURT/HEALED/GOLD_GAINED/SLOWED/STUNNED/MONSTER_DIED 等）。新增 `src/view/sprite_catalog.gd`（数据驱动 atlas 坐标表，同前作模式）与 `src/view/fx.gd`（飘字/弹道/圆环/闪白管理）。

**数据驱动 sprite:** `sprite_catalog.gd` 常量表：`def_id → {atlas: Texture2D, region: Rect2, scale: float}`；缺省回退色块（素材缺失不崩溃）。

**任务:**
1. **T1 资产+单位 sprite**：下载 Kenney 包入 `assets/sprites/`（附 LICENSE）；sprite_catalog 坐标表（剑士/弓手/法师/炮手/牧师/6 怪/城堡/路面）；battle_view 换 sprite 渲染（缺省回退色块）。验证：headless 零报错 + 手动 F5。
2. **T2 特效**：`fx.gd`——HURT→受击闪白+伤害飘字（暴击无、护甲减伤照常显示实际伤害）、MONSTER_DIED→淡出、ATTACK→远程弹道（弓箭/法球/炮弹 by hero id）近战闪弧、HEALED→绿色 +n 飘字、GOLD_GAINED(reason=kill/wave)→金色 +n、技能→施放者处扩张圆环（whirl 白/frost 蓝/barrage 橙/aegis 金）；battle_view 挂载。验证同上。
3. **T3 HUD 打磨**：StyleBoxFlat 统一按钮/面板、城堡 HP 条（顶部）、波次进度、布阵模式合法格高亮、关卡开始横幅（第 X 关·主题名）；全套 GUT+双冒烟+headless 回归。→ `git push`

**约束:** 延续全部既有约束；表现层不得改规则层状态；素材 CC0 附许可文件；缺素材回退色块；每任务全绿提交。
