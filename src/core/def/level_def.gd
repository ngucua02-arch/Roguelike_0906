class_name LevelDef
extends Resource
## 关卡定义：主题 + 怪物强度倍率 + 波次表（紧凑字符串格式）。
## waves 每项一波，组内逗号连接，组格式 def_id:count:interval。

@export var id: String = ""
@export var display_name: String = ""
@export var theme_color: Color = Color(0.12, 0.25, 0.12, 1)
@export var hp_mult: float = 1.0
@export var waves: PackedStringArray = PackedStringArray()
