extends Node2D
## P3 主场景：冒险阶段 UI——事件 3 选 1 / 备战 / 战斗 HUD / 结算与重开。

const Events = preload("res://src/core/events.gd")
const BattleView = preload("res://src/view/battle_view.gd")

var _hud: Control
var _gold_label: Label
var _wave_label: Label
var _msg_label: Label
var _speed_btn: Button
var _buy_buttons := {}
var _cards_box: HBoxContainer
var _cards := {}
var _placing := ""
var _castle_hp := 10
var _hp_bar: ProgressBar
var _banner: Label
var _banner_age := 0.0
var _view: Node2D

var _overlay: Control
var _overlay_title: Label
var _overlay_body: Label
var _event_btns: Array = []
var _continue_btn: Button
var _restart_btn: Button

func _ready() -> void:
	var view: Node2D = BattleView.new()
	view.cell_clicked.connect(_on_cell_clicked)
	add_child(view)
	_view = view
	_build_hud()
	_build_overlay()
	Game.event_emitted.connect(_on_event)

func _process(delta: float) -> void:
	var ph: String = Game.phase
	_hud.visible = ph == "prep" or ph == "battle"
	_overlay.visible = not _hud.visible
	_view.place_mode = _placing != "" and ph == "prep"
	_hp_bar.max_value = Game.run.castle_max
	_hp_bar.value = _castle_hp
	if _banner.visible:
		_banner_age += delta
		_banner.modulate.a = clampf(2.2 - _banner_age, 0.0, 1.0)
		if _banner_age > 2.2:
			_banner.visible = false
	match ph:
		"event":
			_overlay_title.text = "肉鸽事件（3 选 1）"
			_overlay_body.text = "第 %d 关 %s 即将开始" % [Game.run.level_index + 1, Game.level_def.display_name]
			_show_event_buttons()
			_continue_btn.visible = false
			_restart_btn.visible = false
		"level_result":
			_overlay_title.text = "第 %d 关守住！" % (Game.run.level_index + 1)
			_overlay_body.text = "金币结余 %d，城堡 %d/%d\n点击继续：事件 → 备战" % [Game.run.gold, Game.run.castle_hp, Game.run.castle_max]
			_hide_event_buttons()
			_continue_btn.visible = true
			_continue_btn.text = "继续冒险"
			_restart_btn.visible = false
		"adventure_win":
			_overlay_title.text = "冒险通关！"
			_overlay_body.text = "总击杀 %d · 城堡 %d/%d · 用时 %s" % [Game.run.kills_total, Game.run.castle_hp, Game.run.castle_max, _fmt_time(Game.run.ticks_total)]
			_hide_event_buttons()
			_continue_btn.visible = false
			_restart_btn.visible = true
		"adventure_lose":
			_overlay_title.text = "冒险失败……"
			_overlay_body.text = "倒在第 %d 关 · 总击杀 %d · 用时 %s" % [Game.run.level_index + 1, Game.run.kills_total, _fmt_time(Game.run.ticks_total)]
			_hide_event_buttons()
			_continue_btn.visible = false
			_restart_btn.visible = true
		"prep":
			_msg_label.text = "备战：买好英雄点【开战】" if _placing == "" else "放置模式：点击路径旁格子"
		"battle":
			_gold_label.text = "金币: %d" % Game.battle().gold
			var d = Game.battle().director
			_wave_label.text = "波次 %d/%d" % [d.index + 1, d.wave_count()] if d.phase == "wave" else "波间休整 %.1f 秒" % d.break_left
			_refresh_cards()

func _show_event_buttons() -> void:
	for i in 3:
		var d = Game.event_choices[i]
		_event_btns[i].visible = true
		_event_btns[i].text = "%s\n%s" % [d.title, d.desc]

func _hide_event_buttons() -> void:
	for b in _event_btns:
		b.visible = false

func _on_pick_event(i: int) -> void:
	Game.pick_event(i)

func _on_continue() -> void:
	Game.continue_to_event()

func _on_restart() -> void:
	Game.restart_adventure()

func _fmt_time(ticks: int) -> String:
	var sec := int(ticks / 20.0)
	return "%d:%02d" % [sec / 60, sec % 60]

func _on_event(event: Dictionary) -> void:
	match event.type:
		Events.LEAK:
			_castle_hp = event.data.castle_hp
			_msg_label.text = "漏怪！城堡 HP: %d" % _castle_hp
		Events.BUY_FAILED:
			_msg_label.text = "操作失败: %s" % event.data.get("reason", "")
			if event.data.get("reason", "") == "no_gold":
				_placing = ""
		Events.DEPLOYED:
			_placing = ""
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

func _on_start_battle() -> void:
	Game.start_battle_phase()
	_banner.text = "第 %d 关 · %s" % [Game.run.level_index + 1, Game.level_def.display_name]
	_banner.visible = true
	_banner_age = 0.0

func _refresh_cards() -> void:
	var sim = Game.battle()
	if sim == null:
		return
	for hid in _cards.keys():
		var card: Dictionary = _cards[hid]
		for h in sim.heroes:
			if h.id == hid:
				var cd: float = h.skill_cd
				card.skill.text = "%s %s" % [h.def.skill_name, ("%0.1f" % cd) if cd > 0.0 else "就绪"]

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

func _on_upgrade(hero_id: int, stat: String) -> void:
	Game.request_upgrade(hero_id, stat)

func _build_hud() -> void:
	_hud = Control.new()
	add_child(_hud)
	_hp_bar = ProgressBar.new()
	_hp_bar.position = Vector2(16, 10)
	_hp_bar.size = Vector2(220, 20)
	_hp_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12)
	bg.set_corner_radius_all(5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.9, 0.55, 0.25)
	fg.set_corner_radius_all(5)
	_hp_bar.add_theme_stylebox_override("background", bg)
	_hp_bar.add_theme_stylebox_override("fill", fg)
	_hud.add_child(_hp_bar)
	var hp_text := Label.new()
	hp_text.position = Vector2(24, 11)
	hp_text.text = "城堡"
	hp_text.add_theme_font_size_override("font_size", 12)
	_hud.add_child(hp_text)
	_banner = Label.new()
	_banner.position = Vector2(0, 200)
	_banner.size = Vector2(960, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.visible = false
	_hud.add_child(_banner)
	_gold_label = _label(_hud, Vector2(784, 16), "金币: 100")
	_wave_label = _label(_hud, Vector2(784, 40), "备战中")
	_speed_btn = _button(_hud, Vector2(784, 68), Vector2(170, 30), "加速 ×1", _on_speed)
	var start_btn := _button(_hud, Vector2(784, 104), Vector2(170, 36), "开 战", _on_start_battle)
	start_btn.add_theme_font_size_override("font_size", 18)
	_msg_label = _label(_hud, Vector2(16, 484), "备战：买英雄→点格子布阵")
	var sim = Game.battle()
	var y := 146.0
	for d in sim.hero_defs:
		_buy_buttons[d.id] = _button(_hud, Vector2(784, y), Vector2(170, 30), "%s %d金" % [d.display_name, d.cost], _on_buy.bind(d.id))
		y += 36.0
	_cards_box = HBoxContainer.new()
	_cards_box.position = Vector2(16, 508)
	_cards_box.size = Vector2(940, 48)
	_hud.add_child(_cards_box)
	_rebuild_cards()

func _build_overlay() -> void:
	_overlay = Control.new()
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = Vector2(960, 560)
	_overlay.add_child(dim)
	_overlay_title = Label.new()
	_overlay_title.position = Vector2(0, 120)
	_overlay_title.size = Vector2(960, 40)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 26)
	_overlay.add_child(_overlay_title)
	_overlay_body = Label.new()
	_overlay_body.position = Vector2(0, 170)
	_overlay_body.size = Vector2(960, 60)
	_overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_overlay_body)
	for i in 3:
		var b := Button.new()
		b.position = Vector2(110 + i * 260, 260)
		b.size = Vector2(240, 90)
		b.visible = false
		b.pressed.connect(_on_pick_event.bind(i))
		_overlay.add_child(b)
		_event_btns.append(b)
	_continue_btn = Button.new()
	_continue_btn.position = Vector2(400, 400)
	_continue_btn.size = Vector2(160, 40)
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_on_continue)
	_overlay.add_child(_continue_btn)
	_restart_btn = Button.new()
	_restart_btn.position = Vector2(400, 400)
	_restart_btn.size = Vector2(160, 40)
	_restart_btn.text = "重新开始"
	_restart_btn.visible = false
	_restart_btn.pressed.connect(_on_restart)
	_overlay.add_child(_restart_btn)

func _label(parent: Control, pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	parent.add_child(l)
	return l

func _button(parent: Control, pos: Vector2, size: Vector2, text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = size
	b.text = text
	b.pressed.connect(handler)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.15, 0.2) if state == "normal" else (Color(0.2, 0.25, 0.34) if state == "hover" else Color(0.09, 0.11, 0.15))
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.38, 0.58, 0.92) if state == "hover" else Color(0.27, 0.3, 0.38)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.7, 0.8, 1.0))
	parent.add_child(b)
	return b
