extends RefCounted
## 技能系统：按 HeroDef.skill_kind 施放主动技能。
## cast 成功返回事件数组（含 skill_cast），失败返回 []（由 sim 发 skill_failed）。
## 伤害统一走 sim.apply_damage（护甲/死亡/事件复用）。

const Events = preload("res://src/core/events.gd")

static func cast(sim, hero) -> Array:
	var def: Resource = hero.def
	if def.skill_kind == "":
		return []
	var events: Array = []
	var hero_pos: Vector2 = sim.grid.cell_to_pos(hero.cell)
	match def.skill_kind:
		"whirl":
			_damage_around(sim, hero_pos, def.skill_radius, def.skill_damage, events)
		"arrow_rain":
			var target = _sim_target(sim, hero)
			if target == null:
				return []
			_damage_around(sim, sim.grid.point_at(target.path_dist), def.skill_radius, def.skill_damage, events)
		"frost_ring":
			_slow_around(sim, hero_pos, def, events)
			_damage_around(sim, hero_pos, def.skill_radius, def.skill_damage, events)
		"barrage":
			_damage_around(sim, hero_pos, def.skill_radius, def.skill_damage, events)
		"aegis":
			for ally in sim.heroes:
				if ally.cell.distance_to(hero.cell) <= def.skill_radius:
					ally.haste_timer = maxf(ally.haste_timer, def.skill_duration)
					ally.aegis_timer = maxf(ally.aegis_timer, def.skill_duration)
					events.append({"type": Events.HASTED, "data": {"hero_id": ally.id, "duration": def.skill_duration}})
		_:
			return []
	events.push_front({"type": Events.SKILL_CAST, "data": {"hero_id": hero.id, "kind": def.skill_kind}})
	return events

static func _sim_target(sim, hero):
	for m in sim.monsters:
		if not m.alive:
			continue
		var d: float = sim.grid.cell_to_pos(hero.cell).distance_to(sim.grid.point_at(m.path_dist))
		if d <= hero.def.range_tiles:
			return m  # 与普攻最近索敌同序：这里取首个射程内目标即可
	return null

static func _damage_around(sim, center: Vector2, radius: float, dmg: int, events: Array) -> void:
	for m in sim.monsters:
		if not m.alive:
			continue
		if center.distance_to(sim.grid.point_at(m.path_dist)) <= radius:
			sim.apply_damage(m, dmg, events)

static func _slow_around(sim, center: Vector2, def: Resource, events: Array) -> void:
	for m in sim.monsters:
		if not m.alive:
			continue
		if center.distance_to(sim.grid.point_at(m.path_dist)) <= def.skill_radius:
			m.slow_timer = maxf(m.slow_timer, def.skill_slow_duration)
			m.slow_factor = 1.0 - def.skill_slow_pct / 100.0
			events.append({"type": Events.SLOWED, "data": {"id": m.id, "duration": def.skill_slow_duration}})
