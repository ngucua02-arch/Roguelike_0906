class_name HeroDef
extends Resource
## 英雄数值定义：攻击 + 主动技能 + 部署成本（P2 全量字段）。

@export var id: String = ""
@export var display_name: String = ""
@export var cost: int = 50                  # 部署花费（金币）
@export var attack_damage: int = 1
@export var attack_interval: float = 1.0    # 攻击间隔（秒）
@export var range_tiles: float = 1.5        # 射程（格）
@export var skill_name: String = ""         # 技能显示名（空 = 无技能）
@export var skill_kind: String = ""         # whirl/arrow_rain/frost_ring/barrage/aegis
@export var skill_cooldown: float = 10.0    # 冷却（秒），释放成功起转
@export var skill_damage: int = 0
@export var skill_radius: float = 1.5
@export var skill_slow_pct: int = 0         # frost_ring：减速百分比
@export var skill_slow_duration: float = 0.0
@export var skill_haste_pct: int = 0        # aegis：攻速提升百分比
@export var skill_duration: float = 0.0     # aegis：持续秒数
