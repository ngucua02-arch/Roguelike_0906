extends RefCounted
## 局内经济：金币账本、升级费用与乘算常量（账目只在这里变动）。

const UPGRADE_COST := 40
const UPGRADE_DAMAGE_MULT := 1.3
const UPGRADE_INTERVAL_MULT := 0.85

var gold := 0

func _init(p_gold: int) -> void:
	gold = p_gold

func can_afford(amount: int) -> bool:
	return gold >= amount

func spend(amount: int) -> void:
	gold -= amount  # 调用方保证 can_afford

func gain(amount: int) -> void:
	gold += amount
