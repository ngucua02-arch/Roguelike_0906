class_name HeroDef
extends Resource
## 英雄数值定义（P0 最小字段；P2 补技能/索敌类型/升级字段）。

@export var display_name: String = ""
@export var attack_damage: int = 1
@export var attack_interval: float = 1.0   # 攻击间隔（秒）
@export var range_tiles: float = 1.5       # 射程（格）
