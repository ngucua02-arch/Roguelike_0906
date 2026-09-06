class_name EventDef
extends Resource
## 肉鸽事件定义：文案 + 效果类型 + 数值。

@export var id: String = ""
@export var title: String = ""
@export var desc: String = ""
@export var kind: String = ""   # attack/attack_speed/gold/castle/cooldown/levelup/elite/chest
@export var value: int = 0
