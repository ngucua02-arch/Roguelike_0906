class_name MonsterDef
extends Resource
## 怪物数值定义（P0 最小字段；P2 补特性：减伤/治疗光环/boss 技能）。

@export var display_name: String = ""
@export var max_hp: int = 10
@export var move_speed: float = 1.0        # 移速（格/秒）
@export var armor: int = 0                 # 护甲，减固定值伤害
@export var gold_drop: int = 1             # 击杀掉落金币
