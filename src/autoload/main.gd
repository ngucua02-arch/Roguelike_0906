extends Node2D
## P2 主场景：战场渲染 + 完整 HUD 操作闭环。
## 金币/波次/加速、买英雄（放置模式：点按钮→点格子）、英雄卡（技能/升攻/升速）、胜负提示。

const Events = preload("res://src/core/events.gd")
const BattleView = preload("res://src/view/battle_view.gd")

var _gold_label: Label
var _wave_label: Label
var _msg_label: Label
var _speed_btn: Button
var _buy_buttons := {}      # def_id -> Button
var _cards_box: HBoxContainer
var _cards := {}            # hero_id -> {skill: Button, dmg: Button, itv: Button}
var _placing := ""          # 放置模式中的 def_id（空 = 非放置）
var _castle_hp := 10

func _ready() -> void:
	var view: Node2D = BattleView.new()
	view.cell_clicked.connect(_on_cell_clicked)
	add_child(view)

	# 右侧信息栏（战场 768px 右侧留白）
	_gold_label = _label(Vector2(784, 16), "金币: 100")
	_wave_label = _label(Vector2(784, 40), "波次 -/-")
	_speed_btn = _button(Vector2(784, 68), Vector2(170, 30), "加速 ×1", _on_speed)
	_msg_label = _label(Vector2(16, 484), "点右侧买英雄，再点路径旁格子布阵")

	# 买英雄面板
	var sim = Game.battle()
	var y := 104.0
	for d in sim.hero_defs:
		var b := _button(Vector2(784, y), Vector2(170, 30), "%s %d金" % [d.display_name, d.cost], _on_buy.bind(d.id))
		_buy_buttons[d.id] = b
		y += 36.0

	# 英雄卡容器
	_cards_box = HBoxContainer.new()
	_cards_box.position = Vector2(16, 508)
	_cards_box.size = Vector2(940, 48)
	add_child(_cards_box)

	Game.event_emitted.connect(_on_event)

func _process(_delta: float) -> void:
	var sim = Game.battle()
	if sim == null:
		return
	_gold_label.text = "金币: %d" % sim.gold
	var ph: String = sim.director.phase
	if ph == "break":
		_wave_label.text = "休整 %.1f 秒" % sim.director.break_left
	elif ph == "wave":
		_wave_label.text = "波次 %d/%d" % [sim.director.index + 1, sim.director.wave_count()]
	elif ph == "finished":
		_wave_label.text = "战斗结束"
	for hid in _cards.keys():
		var card: Dictionary = _cards[hid]
		for h in sim.heroes:
			if h.id == hid:
				var cd: float = h.skill_cd
				card.skill.text = "%s %s" % [h.def.skill_name, ("%0.1f" % cd) if cd > 0.0 else "就绪"]
				card.dmg.text = "升攻 40"
				card.itv.text = "升速 40"

func _on_event(event: Dictionary) -> void:
	match event.type:
		Events.LEAK:
			_castle_hp = event.data.castle_hp
			_msg_label.text = "漏怪！城堡 HP: %d" % _castle_hp
		Events.VICTORY:
			_msg_label.text = "胜利！城堡 HP %d——P2 完成" % event.data.castle_hp
		Events.DEFEAT:
			_msg_label.text = "冒险失败……"
		Events.BUY_FAILED:
			_msg_label.text = "操作失败: %s" % event.data.get("reason", "")
			if event.data.get("reason", "") == "no_gold":
				_placing = ""
		Events.DEPLOYED:
			_placing = ""
			_rebuild_cards()
		Events.UPGRADED:
			_rebuild_cards()

func _on_cell_clicked(cell: Vector2i) -> void:
	if _placing != "":
		Game.request_deploy(_placing, cell)

func _on_buy(def_id: String) -> void:
	_placing = def_id
	_msg_label.text = "放置模式：点击路径旁的格子部署"

func _on_speed() -> void:
	Game.toggle_speed()
	_speed_btn.text = "加速 ×%d" % int(Game.speed_multiplier)

func _on_skill(hero_id: int) -> void:
	Game.request_skill(hero_id)

func _on_upgrade(hero_id: int, stat: String) -> void:
	Game.request_upgrade(hero_id, stat)

func _rebuild_cards() -> void:
	for c in _cards_box.get_children():
		c.queue_free()
	_cards.clear()
	var sim = Game.battle()
	for h in sim.heroes:
		var card := VBoxContainer.new()
		var title := Label.new()
		title.text = "%s Lv%d" % [h.def.display_name, h.level]
		var skill := Button.new()
		skill.pressed.connect(_on_skill.bind(h.id))
		var row := HBoxContainer.new()
		var dmg := Button.new()
		dmg.text = "升攻 40"
		dmg.pressed.connect(_on_upgrade.bind(h.id, "damage"))
		var itv := Button.new()
		itv.text = "升速 40"
		itv.pressed.connect(_on_upgrade.bind(h.id, "interval"))
		row.add_child(dmg)
		row.add_child(itv)
		card.add_child(title)
		card.add_child(skill)
		card.add_child(row)
		_cards_box.add_child(card)
		_cards[h.id] = {"skill": skill, "dmg": dmg, "itv": itv}

func _label(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	add_child(l)
	return l

func _button(pos: Vector2, size: Vector2, text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = size
	b.text = text
	b.pressed.connect(handler)
	add_child(b)
	return b
