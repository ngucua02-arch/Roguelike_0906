extends RefCounted
## 战场实体状态：英雄与怪物（纯数据 + 状态计时器，无 Node 引用）。

class Hero:
	extends RefCounted
	var id: int
	var def: Resource
	var cell: Vector2i
	var level := 1
	var damage_mult := 1.0
	var interval_mult := 1.0
	var attack_cd := 0.0
	var skill_cd := 0.0
	var stun_timer := 0.0
	var haste_timer := 0.0
	var aegis_timer := 0.0
	var global_damage_mult := 1.0    # 冒险级全局攻（事件）
	var global_interval_mult := 1.0 # 冒险级全局攻速（事件）

	func _init(p_id: int, p_def: Resource, p_cell: Vector2i) -> void:
		id = p_id
		def = p_def
		cell = p_cell

	func damage() -> int:
		return int(round(def.attack_damage * damage_mult * global_damage_mult))

	func attack_interval() -> float:
		var it: float = def.attack_interval * interval_mult * global_interval_mult
		if haste_timer > 0.0:
			it *= 100.0 / (100.0 + def.skill_haste_pct)
		return it

class Monster:
	extends RefCounted
	var id: int
	var def: Resource
	var path_dist := 0.0
	var max_hp: int
	var hp: int
	var alive := true
	var slow_timer := 0.0
	var slow_factor := 1.0
	var heal_timer := 0.0
	var stomp_timer := 0.0

	func _init(p_id: int, p_def: Resource, hp_mult := 1.0) -> void:
		id = p_id
		def = p_def
		max_hp = int(ceil(p_def.max_hp * hp_mult))
		hp = max_hp
		heal_timer = p_def.heal_interval
		stomp_timer = p_def.stomp_interval

	func move_speed() -> float:
		return def.move_speed * (slow_factor if slow_timer > 0.0 else 1.0)
