class_name Events
## 事件类型常量：规则层 → 表现层的唯一输出词汇表。
## 约定：事件字典 {type, data} 一经发出视为不可变，消费方不得改写（广播为引用共享）。

const TICK := "tick"

const SPAWN := "spawn"
const MOVE := "move"
const LEAK := "leak"
const DEFEAT := "defeat"
const ATTACK := "attack"
const HURT := "hurt"
const MONSTER_DIED := "monster_died"
const VICTORY := "victory"
