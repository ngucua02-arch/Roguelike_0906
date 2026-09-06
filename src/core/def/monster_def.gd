class_name MonsterDef
extends Resource
## 怪物数值定义：基础属性 + 特性（萨满治疗光环 / boss 踩踏眩晕）。

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 10
@export var move_speed: float = 1.0        # 格/秒
@export var armor: int = 0
@export var gold_drop: int = 1
@export var leak_damage: int = 1           # 抵达城堡扣除城堡 HP（boss 为 3）
@export var heal_radius: float = 0.0       # >0 = 萨满治疗光环
@export var heal_amount: int = 0
@export var heal_interval: float = 3.0
@export var is_boss: bool = false
@export var stomp_radius: float = 0.0      # >0 = boss 踩踏
@export var stomp_interval: float = 6.0
@export var stomp_stun_duration: float = 2.0
