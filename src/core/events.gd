class_name Events
## 事件类型常量：规则层 → 表现层的唯一输出词汇表。
## 约定：事件字典 {type, data} 一经发出视为不可变，消费方不得改写（广播为引用共享）。

const TICK := "tick"

const SPAWN := "spawn"
const MOVE := "move"
const LEAK := "leak"
const ATTACK := "attack"
const HURT := "hurt"
const MONSTER_DIED := "monster_died"
const VICTORY := "victory"
const DEFEAT := "defeat"

const DEPLOYED := "deployed"
const BUY_FAILED := "buy_failed"
const UPGRADED := "upgraded"
const SKILL_CAST := "skill_cast"
const SKILL_FAILED := "skill_failed"
const GOLD_GAINED := "gold_gained"
const WAVE_STARTED := "wave_started"
const WAVE_CLEARED := "wave_cleared"
const SLOWED := "slowed"
const HEALED := "healed"
const HASTED := "hasted"
const STUNNED := "stunned"
