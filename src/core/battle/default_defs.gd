extends RefCounted
## 内置默认数值表（与 resources/*.tres 同值）：默认战斗与规则层测试用，不读 .tres。

static func heroes() -> Array:
	return [
		_hero("swordsman", "剑士", 60, 12, 0.8, 1.5, "旋风斩", "whirl", 8.0, 20, 1.5, 0, 0.0, 0, 0.0),
		_hero("archer", "弓手", 80, 9, 0.6, 3.5, "箭雨", "arrow_rain", 12.0, 24, 1.5, 0, 0.0, 0, 0.0),
		_hero("mage", "法师", 100, 14, 1.2, 3.0, "冰环", "frost_ring", 10.0, 12, 2.0, 50, 3.0, 0, 0.0),
		_hero("cannonier", "炮手", 140, 32, 2.2, 4.5, "轰击", "barrage", 15.0, 55, 2.5, 0, 0.0, 0, 0.0),
		_hero("priest", "牧师", 90, 6, 1.5, 2.5, "圣盾", "aegis", 12.0, 0, 2.0, 0, 0.0, 30, 4.0),
	]

static func _hero(id: String, display_name: String, cost: int, dmg: int, itv: float, rng: float,
		sname: String, kind: String, scd: float, sdmg: int, srad: float,
		slow_pct: int, slow_dur: float, haste_pct: int, dur: float) -> HeroDef:
	var d := HeroDef.new()
	d.id = id
	d.display_name = display_name
	d.cost = cost
	d.attack_damage = dmg
	d.attack_interval = itv
	d.range_tiles = rng
	d.skill_name = sname
	d.skill_kind = kind
	d.skill_cooldown = scd
	d.skill_damage = sdmg
	d.skill_radius = srad
	d.skill_slow_pct = slow_pct
	d.skill_slow_duration = slow_dur
	d.skill_haste_pct = haste_pct
	d.skill_duration = dur
	return d

static func monsters() -> Array:
	return [
		_mon("goblin", "哥布林", 30, 1.2, 0, 3, 1),
		_mon("wolf", "疾行狼", 25, 2.0, 0, 4, 1),
		_mon("orc", "兽人", 60, 1.0, 2, 5, 1),
		_mon("shaman", "萨满", 45, 0.9, 1, 6, 1, 2.0, 8, 3.0),
		_mon("golem", "石魔", 150, 0.6, 8, 8, 1),
		_mon("ogre_lord", "巨魔王", 800, 0.5, 6, 50, 3, 0.0, 0, 3.0, true, 2.5, 6.0, 2.0),
	]

static func _mon(id: String, display_name: String, hp: int, speed: float, armor: int, gold: int, leak: int,
		heal_r := 0.0, heal_a := 0, heal_i := 3.0, boss := false, stomp_r := 0.0, stomp_i := 6.0, stomp_s := 2.0) -> MonsterDef:
	var d := MonsterDef.new()
	d.id = id
	d.display_name = display_name
	d.max_hp = hp
	d.move_speed = speed
	d.armor = armor
	d.gold_drop = gold
	d.leak_damage = leak
	d.heal_radius = heal_r
	d.heal_amount = heal_a
	d.heal_interval = heal_i
	d.is_boss = boss
	d.stomp_radius = stomp_r
	d.stomp_interval = stomp_i
	d.stomp_stun_duration = stomp_s
	return d

static func waves() -> Array:
	return [
		{"groups": [{"def_id": "goblin", "count": 6, "interval": 1.2}]},
		{"groups": [{"def_id": "goblin", "count": 6, "interval": 1.0}, {"def_id": "wolf", "count": 3, "interval": 1.5}]},
		{"groups": [{"def_id": "orc", "count": 6, "interval": 1.6}]},
		{"groups": [{"def_id": "wolf", "count": 4, "interval": 0.9}, {"def_id": "shaman", "count": 1, "interval": 2.0}, {"def_id": "orc", "count": 4, "interval": 1.6}]},
		{"groups": [{"def_id": "golem", "count": 3, "interval": 3.0}, {"def_id": "shaman", "count": 2, "interval": 2.0}, {"def_id": "orc", "count": 6, "interval": 1.4}]},
		{"groups": [{"def_id": "orc", "count": 8, "interval": 1.2}, {"def_id": "golem", "count": 2, "interval": 3.0}, {"def_id": "shaman", "count": 2, "interval": 2.0}, {"def_id": "ogre_lord", "count": 1, "interval": 1.0}]},
	]
