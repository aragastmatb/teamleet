extends Control
# UI for the team lead prototype. Rules live in rules.gd, content in content.gd, text in locale.gd.
# Layout, tracker style: the team on the left, the board in the middle, every conversation in the chat
# on the right. Only documents (the Friday report, the assessment) open over the board.

const Rules = preload("res://teamlead/rules.gd")
const Loc = preload("res://teamlead/locale.gd")
const C = preload("res://teamlead/content.gd")

const BASE_FONT := 15
const SIDEBAR_W := 250
const CHAT_W := 350
const TOP_H := 50

const COL_BG := Color("f4f5f7")
const COL_SURFACE := Color("ffffff")
const COL_COLUMN := Color("ebecf0")
const COL_BORDER := Color("dfe1e6")
const COL_TEXT := Color("172b4d")
const COL_MUTED := Color("5e6c84")
const COL_FAINT := Color("a5adba")
const COL_PRIMARY := Color("0052cc")
const COL_PRIMARY_HOVER := Color("0065ff")
const COL_SELECTED := Color("deebff")
const COL_FOCUS := Color("4c9aff")
const COL_TOPBAR := Color("0747a6")
const COL_DANGER := Color("de350b")
const COL_WARN := Color("b65c02")
const COL_GOOD := Color("00875a")
const COL_STAR := Color("ff991f")
# On the dark top bar.
const COL_ON_TOP := Color("ffffff")
const COL_ON_TOP_MUTED := Color("b3d4ff")
const COL_ON_TOP_GOOD := Color("79f2c0")
const COL_ON_TOP_DANGER := Color("ffbdad")

const MOOD_COLORS := {"happy": COL_GOOD, "good": COL_GOOD, "neutral": COL_MUTED, "down": COL_WARN, "angry": COL_DANGER}
const ENERGY_COLORS := {"fresh": COL_GOOD, "ok": COL_MUTED, "tired": COL_WARN, "drained": COL_DANGER}
const BOSS_COLORS := {"w3": COL_ON_TOP_GOOD, "w2": COL_ON_TOP_GOOD, "w1": COL_ON_TOP, "w0": COL_ON_TOP_DANGER}
# Category labels: text colour and fill, like tracker labels.
const CAT_COLORS := {
	"tech": [Color("0747a6"), Color("deebff")],
	"analytics": [Color("403294"), Color("eae6ff")],
	"people": [Color("a3195b"), Color("ffe3f1")],
	"routine": [Color("006644"), Color("e3fcef")],
}
const AVATAR_COLORS := {
	"alex": Color("0065ff"), "vika": Color("ff5630"), "gena": Color("36b37e"), "dima": Color("6554c0"),
	"boss": Color("253858"), "marina": Color("00a3bf"), "taras": Color("ff8b00"), "me": Color("0747a6"),
	"contractor": Color("7a869a"),
}

var rules := Rules.new()
var ui: Control
var selected := -1
var font_bold: Font
# Scroll positions survive a re-render; the chat always jumps to the newest line.
var scroll_memory := {}
var scrolls := {}


func _ready() -> void:
	Loc.lang = "ru" if OS.get_locale_language() == "ru" else "en"
	var names := PackedStringArray(["Inter", "Helvetica Neue", "Segoe UI", "Roboto", "Arial"])
	var regular := SystemFont.new()
	regular.font_names = names
	var bold := SystemFont.new()
	bold.font_names = names
	bold.font_weight = 700
	font_bold = bold
	var ui_theme := Theme.new()
	ui_theme.default_font = regular
	ui_theme.default_font_size = BASE_FONT
	ui_theme.set_color("font_color", "Label", COL_TEXT)
	ui_theme.set_stylebox("panel", "TooltipPanel", _box(COL_TEXT, COL_TEXT, 0, 6))
	ui_theme.set_color("font_color", "TooltipLabel", COL_SURFACE)
	theme = ui_theme
	_fit_window()
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_render()


# On Retina screens the window opens at physical pixels and looks tiny; scale it up to fit the screen.
func _fit_window() -> void:
	var w := get_window()
	var screen := w.current_screen
	var hidpi := DisplayServer.screen_get_scale(screen)
	var usable := DisplayServer.screen_get_usable_rect(screen).size
	var target := Vector2(w.size) * hidpi
	var fit: float = minf(1.0, minf(usable.x * 0.95 / target.x, usable.y * 0.9 / target.y))
	w.size = Vector2i(target * fit)
	w.move_to_center()


# ---------- actions ----------

func _select(uid: int) -> void:
	selected = -1 if selected == uid else uid
	_render()


# Clicking a person hands them the task right away; the task stays selected so you can add a helper.
func _pick(p: String) -> void:
	rules.assign(selected, p)
	_render()


func _direct(p: String) -> void:
	rules.assign(selected, p)
	_clear_selection()


func _persuade(intent: String) -> void:
	rules.persuade(intent)
	_render()


func _helper(p: String) -> void:
	rules.set_helper(selected, p)
	_render()


func _accept_initiative(p: String) -> void:
	rules.accept_initiative(p)
	_render()


func _sit() -> void:
	rules.sit_with(selected)
	_render()


func _prioritize() -> void:
	rules.prioritize(selected)
	_render()


func _unassign() -> void:
	rules.unassign(selected)
	_render()


func _talk_to(p: String) -> void:
	_clear_selection()
	rules.start_talk(p)
	_render()


func _visit_boss() -> void:
	_clear_selection()
	rules.visit_boss()
	_render()


func _end_day() -> void:
	_clear_selection()
	rules.end_day()
	_render()


func _next() -> void:
	rules.next()
	_render()


func _continue_report() -> void:
	rules.continue_report()
	_render()


func _event(choice: String) -> void:
	rules.resolve_event(choice)
	_render()


func _answer(choice: String) -> void:
	rules.answer_review(choice)
	_render()


func _start_run() -> void:
	rules.start_run()
	_clear_selection()
	_render()


func _clear_selection() -> void:
	selected = -1
	_render()


func _toggle_lang() -> void:
	Loc.lang = "en" if Loc.lang == "ru" else "ru"
	_render()


# ---------- screens ----------

func _render() -> void:
	for key in scrolls:
		if is_instance_valid(scrolls[key]):
			scroll_memory[key] = scrolls[key].scroll_vertical
	scrolls.clear()
	if ui:
		ui.queue_free()
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	if rules.phase == "title":
		_build_title()
		return
	_build_office()
	if _waiting_for_answer():
		_block_board()
	match rules.phase:
		"report":
			_build_report()
		"end":
			_build_end()
	_restore_scrolls()


# The chat holds a question you have to answer before anything else happens.
func _waiting_for_answer() -> bool:
	return rules.phase == "event" or rules.phase == "review" or not rules.pending.is_empty()


func _build_title() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_SURFACE, COL_BORDER, 1, 32))
	center.add_child(card)
	var v := _vbox(16)
	v.custom_minimum_size.x = 860
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(_logo(40))
	head.add_child(_label(Loc.t("title"), 34, COL_TEXT, false, true))
	v.add_child(_label(Loc.t("tagline"), 19, COL_MUTED, true))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 380
	v.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = Loc.t("rules")
	text.add_theme_font_override("bold_font", font_bold)
	text.add_theme_font_size_override("normal_font_size", 16)
	text.add_theme_font_size_override("bold_font_size", 16)
	text.add_theme_color_override("default_color", COL_TEXT)
	scroll.add_child(text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	buttons.add_child(_button(Loc.t("start"), _start_run, 260, "primary"))
	buttons.add_child(_button(Loc.t("lang_button"), _toggle_lang, 140))


func _build_office() -> void:
	var v := _vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(v)
	v.add_child(_top_bar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	v.add_child(body)
	body.add_child(_team_sidebar())
	body.add_child(_board_area())
	body.add_child(_chat())


func _top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size.y = TOP_H
	var style := _box(COL_TOPBAR, COL_TOPBAR, 0, 0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 16
	style.content_margin_right = 12
	bar.add_theme_stylebox_override("panel", style)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	bar.add_child(top)
	top.add_child(_logo(26))
	top.add_child(_label(Loc.t("title"), 18, COL_ON_TOP, false, true))
	top.add_child(_label(Loc.t("day.%d" % rules.day), 15, COL_ON_TOP_MUTED))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(_label(_attention_text(), 15, COL_ON_TOP if rules.overtime_today == 0 else COL_ON_TOP_DANGER))
	var k := rules.key_status()
	top.add_child(_label(Loc.render("keys_label", [], {"good": k["good"], "total": C.KEY_PROJECTS.size()}), 15, COL_ON_TOP))
	var word := rules.boss_word()
	top.add_child(_label(Loc.t("boss_label", ["@weight." + word]), 15, BOSS_COLORS[word]))
	top.add_child(_button(Loc.t("lang_button"), _toggle_lang, 0, "on_top"))
	return bar


func _logo(size: int) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(size, size)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := _box(COL_STAR, COL_STAR, 0, 0)
	style.set_corner_radius_all(int(size * 0.25))
	box.add_theme_stylebox_override("panel", style)
	var l := _label("TL", int(size * 0.45), COL_SURFACE, false, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	return box


func _attention_text() -> String:
	if rules.sick_today:
		return Loc.t("you.sick_today")
	var dots := ""
	for i in C.ATTENTION:
		dots += "●" if i < rules.attention else "○"
	var text := Loc.render("attention_label", [], {"dots": dots, "state": "@me." + rules.my_state()})
	if rules.overtime_today > 0:
		text += " " + Loc.render("overtime_label", [], {"n": rules.overtime_today})
	return text


func _cost_mark() -> String:
	return " ●" if rules.attention > 0 else " " + Loc.t("cost_overtime")


# ---------- the team ----------

func _team_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = SIDEBAR_W
	var style := _flat(COL_SURFACE)
	style.border_color = COL_BORDER
	style.border_width_right = 1
	panel.add_theme_stylebox_override("panel", style)
	var scroll := _scroll("team")
	panel.add_child(scroll)
	var v := _vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(v, 12, 12))
	v.add_child(_section(Loc.t("team_header")))
	for p in C.TEAM:
		v.add_child(_person_card(p))
	v.add_child(_spacer(4))
	v.add_child(_section(Loc.t("boss_header")))
	v.add_child(_boss_card())
	return panel


func _person_card(p: String) -> Control:
	var st: Dictionary = rules.people[p]
	var card := PanelContainer.new()
	var target: bool = rules.pending.get("p", "") == p
	card.add_theme_stylebox_override("panel", _box(COL_SELECTED if target else COL_SURFACE, COL_FOCUS if target else COL_BORDER, 2 if target else 1, 10))
	var v := _vbox(5)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	head.add_child(_avatar(p, 32))
	var names := _vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(_label(Loc.person(p), 15, COL_TEXT, false, true))
	var role := rules.role_of(p)
	if role != "":
		names.add_child(_label(Loc.t("role." + role), 12, COL_MUTED, true))
	if st["gone"]:
		v.add_child(_label(Loc.t("gone_label"), 13, COL_DANGER, true))
		card.modulate = Color(1, 1, 1, 0.55)
		return card
	var state := _flow(6, 2)
	v.add_child(state)
	if st["absent"]:
		state.add_child(_pill(Loc.t("absent.%s_label" % st["absent_reason"]), COL_WARN, Color("fff0b3")))
	var mood := rules.mood_word(p)
	state.add_child(_label(Loc.t("mood." + mood), 13, MOOD_COLORS[mood]))
	var energy := rules.energy_word(p)
	state.add_child(_label("· " + Loc.t("energy." + energy), 13, ENERGY_COLORS[energy]))
	var trust := _trust_word(p)
	if trust != "":
		state.add_child(_label("· " + Loc.t("trust." + trust), 13, COL_GOOD if trust == "trusts" else COL_DANGER))
	var known: Dictionary = st["known"]
	var drive_text: String = Loc.t("drive." + C.PEOPLE[p]["drive"]) if known.has("drive") else Loc.t("unknown")
	v.add_child(_label(Loc.t("known.drive", [drive_text]), 12, COL_MUTED, true))
	var skills := _flow(4, 4)
	v.add_child(skills)
	for cat in C.CATEGORIES:
		var is_known: bool = known.has("skill." + cat)
		var level: String = Loc.t("level.%d" % st["skills"][cat]) if is_known else Loc.t("unknown")
		var colors: Array = CAT_COLORS[cat]
		skills.add_child(_pill("%s: %s" % [Loc.t("cat." + cat), level], colors[0] if is_known else COL_FAINT, colors[1] if is_known else COL_BG))
	for t in rules.tasks:
		if t["status"] == "active" and t["helper"] == p:
			v.add_child(_label(Loc.t("helper_badge", ["«%s»" % Loc.t("taskname." + t["id"])]), 12, COL_MUTED, true))
	var talk := _button(Loc.t("talk_button") + _cost_mark(), _talk_to.bind(p), 0, "subtle")
	talk.disabled = not rules.can_talk(p)
	talk.custom_minimum_size.y = 30
	v.add_child(talk)
	return card


func _boss_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_SURFACE, COL_BORDER, 1, 10))
	var v := _vbox(6)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	head.add_child(_avatar("boss", 32))
	var names := _vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(_label(Loc.person("boss"), 15, COL_TEXT, true, true))
	names.add_child(_label(Loc.t("boss_role"), 12, COL_MUTED))
	var visit := _button(Loc.t("visit_short") + _cost_mark(), _visit_boss, 0, "subtle")
	visit.disabled = rules.phase != "plan" or rules.visited_today or not rules.pending.is_empty()
	visit.custom_minimum_size.y = 30
	v.add_child(visit)
	return card


# ---------- the board ----------

func _board_area() -> Control:
	var v := _vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wrap := _padded(v, 14, 12)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var titles := _vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(_label(Loc.t("board_title"), 20, COL_TEXT, false, true))
	var hint := Loc.t("pick_task")
	if not rules.queue_of("me").is_empty():
		hint = Loc.t("you.busy")
	titles.add_child(_label(hint, 13, COL_WARN if not rules.queue_of("me").is_empty() else COL_MUTED, true))
	if rules.phase == "evening":
		head.add_child(_button(Loc.t("to_end" if rules.day >= C.DAYS else "next_day"), _next, 200, "primary"))
	else:
		var end := _button(Loc.t("end_day"), _end_day, 200, "primary")
		end.disabled = rules.phase != "plan" or not rules.pending.is_empty()
		head.add_child(end)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 8)
	v.add_child(columns)
	var lanes := _lanes()
	for lane in ["inbox", "queued", "active", "done"]:
		columns.add_child(_column(lane, lanes[lane]))
	if selected >= 0 and rules.phase == "plan":
		var t := rules.task(selected)
		if not t.is_empty() and t["status"] in ["inbox", "active"]:
			v.add_child(_task_detail(t))
	return wrap


# Which column each card sits in: waiting in someone's queue, being worked on, done this week.
func _lanes() -> Dictionary:
	var lanes := {"inbox": rules.inbox(), "queued": [], "active": [], "done": []}
	lanes["inbox"].sort_custom(func(a, b): return a["due"] < b["due"])
	for p in C.TEAM + ["me"]:
		var q := rules.queue_of(p)
		for i in q.size():
			lanes["active" if i == 0 else "queued"].append(q[i])
	for t in rules.tasks:
		if t["status"] == "taras":
			lanes["active"].append(t)
		elif t["status"] == "done" and rules.week() == int((t["done_day"] - 1) / 5.0):
			lanes["done"].push_front(t)
	return lanes


func _column(lane: String, items: Array) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(COL_COLUMN, COL_COLUMN, 0, 8))
	var v := _vbox(8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	head.add_child(_label(Loc.t("col." + lane), 12, COL_MUTED, false, true))
	head.add_child(_label(str(items.size()), 12, COL_FAINT))
	var scroll := _scroll("col_" + lane)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := _vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if items.is_empty():
		list.add_child(_label(Loc.t("col_empty." + lane), 12, COL_FAINT, true))
	for t in items:
		list.add_child(_task_card(t, lane))
	return panel


func _task_card(t: Dictionary, lane: String) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chosen: bool = selected == t["uid"]
	var style := _box(COL_SELECTED if chosen else COL_SURFACE, COL_FOCUS if chosen else COL_BORDER, 2 if chosen else 1, 8)
	style.shadow_color = Color(0.035, 0.118, 0.259, 0.12)
	style.shadow_size = 1
	style.shadow_offset = Vector2(0, 1)
	card.add_theme_stylebox_override("panel", style)
	var clickable: bool = rules.phase == "plan" and rules.pending.is_empty() and (t["status"] == "inbox" or t["status"] == "active")
	if clickable:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_input.bind(t["uid"]))
	if lane == "done":
		card.modulate = Color(1, 1, 1, 0.7)
	var v := _vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var tags := _flow(4, 4)
	v.add_child(tags)
	var colors: Array = CAT_COLORS[t["cat"]]
	tags.add_child(_pill(Loc.t("cat." + t["cat"]), colors[0], colors[1]))
	if t["key"]:
		tags.add_child(_pill("★", COL_STAR, Color("fff7e6")))
	if t["blocked"] > 0:
		tags.add_child(_pill(Loc.t("chip_blocked"), COL_DANGER, Color("ffebe6")))
	if t["involved"] and t["owner"] != "me":
		tags.add_child(_pill(Loc.t("chip_involved").trim_prefix("· "), COL_PRIMARY, COL_SELECTED))
	v.add_child(_label(Loc.t("taskname." + t["id"]), 14, COL_TEXT, true))
	if t["status"] == "active":
		var bar := ProgressBar.new()
		bar.max_value = t["size"]
		bar.value = minf(t["progress"], t["size"])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 4)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _box(COL_COLUMN, COL_COLUMN, 0, 0))
		bar.add_theme_stylebox_override("fill", _box(COL_GOOD, COL_GOOD, 0, 0))
		v.add_child(bar)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 4)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	var info := _vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(info)
	if lane == "done":
		info.add_child(_label(Loc.t("due.late") if t["late"] else "✓", 12, COL_DANGER if t["late"] else COL_GOOD))
	else:
		var urgent: bool = t["late"] or t["due"] - rules.day <= 0
		info.add_child(_label(_due_text(t), 12, COL_DANGER if urgent else COL_MUTED, true))
		if t["status"] != "taras":
			var est: Dictionary = rules.estimate(t)
			info.add_child(_label(Loc.t("est.short" if est["sure"] else "est.guess", [_days(est["days"])]), 12, COL_MUTED if est["sure"] else COL_FAINT, true))
	if t["owner"] != "":
		foot.add_child(_avatar(t["owner"], 22))
	if t["helper"] != "" and t["status"] == "active":
		foot.add_child(_avatar(t["helper"], 22))
	return card


func _on_card_input(event: InputEvent, uid: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select.call_deferred(uid)


func _due_text(t: Dictionary) -> String:
	if t["late"]:
		return Loc.t("due.late")
	var left: int = t["due"] - rules.day
	if left <= 0:
		return Loc.t("due.today")
	if left == 1:
		return Loc.t("due.tomorrow")
	return Loc.t("due.days", [left])


func _days(d: float) -> String:
	var x: float = maxf(0.5, snappedf(d, 0.5))
	if is_equal_approx(x, roundf(x)):
		return str(int(x))
	return "%d%s5" % [int(x), "," if Loc.lang == "ru" else "."]


# The open card, like an issue view: who asked, what it takes, who gets it.
func _task_detail(t: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(COL_SURFACE, COL_FOCUS, 1, 12))
	var v := _vbox(8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var colors: Array = CAT_COLORS[t["cat"]]
	head.add_child(_pill(Loc.t("cat." + t["cat"]), colors[0], colors[1]))
	var title := _label(("★ " if t["key"] else "") + Loc.t("taskname." + t["id"]), 17, COL_TEXT, true, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("×", _clear_selection, 32, "subtle")
	close.custom_minimum_size.y = 28
	head.add_child(close)
	var facts := _flow(6, 4)
	v.add_child(facts)
	var est: Dictionary = rules.estimate(t)
	facts.add_child(_pill(Loc.t("est.chip" if est["sure"] else "est.chip_guess", [_days(est["days"])]), COL_TEXT, COL_COLUMN))
	facts.add_child(_pill(_due_text(t), COL_DANGER if t["due"] - rules.day <= 1 else COL_TEXT, Color("ffebe6") if t["due"] - rules.day <= 1 else COL_COLUMN))
	if t["key"]:
		facts.add_child(_pill(Loc.t("chip_key"), COL_WARN, Color("fff7e6")))
	elif t["public"]:
		facts.add_child(_pill(Loc.t("public"), COL_WARN, Color("fff7e6")))
	v.add_child(_label("%s — %s" % [Loc.t("from", [Loc.person(t["from"])]), Loc.t("quote", [Loc.t("task.%s.ask" % t["id"])])], 13, COL_MUTED, true))
	var who := _flow(6, 6)
	v.add_child(who)
	who.add_child(_row_label(Loc.t("to_whom")))
	for p in C.TEAM:
		if not rules.available(p):
			continue
		var pe: Dictionary = rules.estimate(t, p)
		var label := "%s  ~%s" % [Loc.person(p), _days(pe["days"])] if pe["sure"] else "%s  ?" % Loc.person(p)
		var b := _button(label, _pick.bind(p), 0, "chosen" if t["owner"] == p else "")
		b.disabled = t["owner"] == p
		who.add_child(b)
	who.add_child(_button(Loc.t("myself"), _direct.bind("me"), 0))
	who.add_child(_button(Loc.t("to_taras"), _direct.bind("taras"), 0))
	if t["status"] == "active":
		var acts := _flow(6, 6)
		v.add_child(acts)
		acts.add_child(_button(Loc.t("unassign"), _unassign, 0, "subtle"))
		if C.TEAM.has(t["owner"]) and rules.queue_of(t["owner"])[0]["uid"] != t["uid"]:
			acts.add_child(_button(Loc.t("prioritize"), _prioritize, 0, "subtle"))
		if C.TEAM.has(t["owner"]) and not t["sit_today"]:
			acts.add_child(_button(Loc.t("sit.button") + _cost_mark(), _sit, 0, "subtle"))
	if t["status"] == "active" and C.TEAM.has(t["owner"]):
		var pair := _flow(6, 6)
		v.add_child(pair)
		pair.add_child(_row_label(Loc.t("helper_optional")))
		for p in C.TEAM:
			if p != t["owner"] and rules.available(p):
				pair.add_child(_button(Loc.person(p), _helper.bind(p), 0, "chosen" if t["helper"] == p else ""))
		pair.add_child(_button(Loc.t("no_helper"), _helper.bind(""), 0, "chosen" if t["helper"] == "" else ""))
		v.add_child(_label(Loc.t("helper_hint"), 12, COL_MUTED, true))
	return panel


func _row_label(text_value: String) -> Control:
	var l := _label(text_value, 13, COL_MUTED)
	l.custom_minimum_size.y = 34
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


# While a question waits in the chat, the board and the team are out of reach.
func _block_board() -> void:
	var shade := ColorRect.new()
	shade.color = Color(COL_BG, 0.6)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.offset_top = TOP_H
	shade.offset_right = -CHAT_W
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var pill := PanelContainer.new()
	var style := _box(COL_TEXT, COL_TEXT, 0, 12)
	style.set_corner_radius_all(20)
	style.content_margin_left = 20
	style.content_margin_right = 20
	pill.add_theme_stylebox_override("panel", style)
	pill.add_child(_label(Loc.t("answer_in_chat"), 16, COL_SURFACE, false, true))
	center.add_child(pill)


# ---------- the chat ----------

func _chat() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = CHAT_W
	var style := _flat(COL_SURFACE)
	style.border_color = COL_BORDER
	style.border_width_left = 1
	panel.add_theme_stylebox_override("panel", style)
	var v := _vbox(0)
	panel.add_child(v)
	var head := PanelContainer.new()
	var head_style := _flat(COL_SURFACE)
	head_style.border_color = COL_BORDER
	head_style.border_width_bottom = 1
	head_style.content_margin_left = 14
	head_style.content_margin_right = 14
	head_style.content_margin_top = 10
	head_style.content_margin_bottom = 10
	head.add_theme_stylebox_override("panel", head_style)
	v.add_child(head)
	head.add_child(_label(Loc.t("chat_title"), 16, COL_TEXT, false, true))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := _vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(list, 14, 12))
	var last := ""
	for e in rules.history:
		if e["day"] != rules.day:
			continue
		var key: String = e["key"]
		if key.begins_with("log."):
			list.add_child(_spacer(4))
			var sep := _label(Loc.render(key, e.get("args", []), e.get("names", {})).replace("—", "").strip_edges(), 12, COL_FAINT, true, true)
			sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			list.add_child(sep)
			last = ""
			continue
		var body := Loc.render(key, e.get("args", []), e.get("names", {}))
		if e["who"] == "":
			if last != "":
				list.add_child(_spacer(4))
			list.add_child(_label(body, 13, COL_MUTED, true))
			last = ""
			continue
		var speaker: String = e["who"] + ">" + e.get("to", "")
		if speaker != last:
			list.add_child(_spacer(4))
			list.add_child(_message_head(e))
		last = speaker
		list.add_child(_indented(_label(body, 15, COL_MUTED if body.begins_with("(") else COL_TEXT, true)))
	_chat_prompt(list)
	_scroll_to_end(scroll)
	return panel


func _message_head(e: Dictionary) -> Control:
	var who: String = e["who"]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_avatar("me" if who == "you" else who, 28))
	var name := Loc.t("you") if who == "you" else Loc.person(who)
	h.add_child(_label(name, 14, COL_TEXT, false, true))
	if who == "you" and e.has("to"):
		h.add_child(_label("→ " + Loc.t("name.%s.dat" % e["to"]), 13, COL_MUTED))
	return h


func _indented(c: Control) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 36)
	m.add_child(c)
	return m


# What waits for you at the bottom of the chat: a question with answers, or offers you can take.
func _chat_prompt(list: VBoxContainer) -> void:
	if rules.phase == "event" and not rules.events.is_empty():
		_event_prompt(list, rules.events[0])
	elif not rules.pending.is_empty():
		_objection_prompt(list)
	elif rules.phase == "review" and not rules.review.is_empty():
		_review_prompt(list)
	elif rules.phase == "evening":
		list.add_child(_spacer(8))
		var b := _button(Loc.t("to_end" if rules.day >= C.DAYS else "next_day"), _next, 0, "primary")
		list.add_child(b)
	elif rules.phase == "plan":
		for p in C.TEAM:
			var offer := rules.initiative_offer(p)
			if offer != "":
				list.add_child(_offer_card(p, offer))


func _prompt_box(list: VBoxContainer, title: String) -> VBoxContainer:
	list.add_child(_spacer(8))
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _box(Color("f4f8ff"), COL_FOCUS, 1, 10))
	list.add_child(box)
	var v := _vbox(6)
	box.add_child(v)
	if title != "":
		v.add_child(_label(title, 12, COL_PRIMARY, true, true))
	return v


func _event_prompt(list: VBoxContainer, ev: Dictionary) -> void:
	var title := ""
	if ev["id"].begins_with("talk_"):
		title = Loc.render("talk_title", [], {"who": "@name.%s.ins" % ev["target"]})
	elif ev["id"].begins_with("boss_visit") or ev["id"] == "boss_show":
		title = Loc.t("visit_title")
	var v := _prompt_box(list, title)
	for choice in ev["choices"]:
		var parts: PackedStringArray = choice.split(":")
		var names: Dictionary = ev["names"].duplicate()
		if ev.has("choice_names"):
			names.merge(ev["choice_names"].get(choice, {}), true)
		elif parts.size() > 1:
			names["who"] = "@name.%s.acc" % parts[1]
		var text := Loc.render("event.%s.choice.%s" % [ev["id"], parts[0]], [], names)
		if ev["id"] == "boss_dump" and choice == "refuse" and not rules.has_weight():
			text += " " + Loc.t("needs_weight")
		if rules.choice_costs(ev, choice):
			text += _cost_mark()
		if ev["id"] == "boss_visit" and (parts[0] == "delay" or parts[0] == "contractor") and not rules.has_weight():
			text += " " + Loc.t("needs_weight")
		v.add_child(_answer_button(text, _event.bind(choice)))


func _objection_prompt(list: VBoxContainer) -> void:
	var p: String = rules.pending["p"]
	var t := rules.task(rules.pending["uid"])
	var v := _prompt_box(list, Loc.render("objection_title", [], {"who": Loc.person(p)}) + " · " + Loc.t("taskname." + t["id"]))
	for intent in C.INTENTS + ["back_off"]:
		v.add_child(_answer_button(Loc.t("intent." + intent), _persuade.bind(intent)))
	v.add_child(_label(Loc.t("objection_hint"), 12, COL_MUTED, true))


func _review_prompt(list: VBoxContainer) -> void:
	var item: Dictionary = rules.review[0]
	var t := rules.task(item["uid"])
	var names := {"task": "@taskname." + t["id"], "owner": "@name.%s.nom" % t["owner"], "owner_gen": "@name.%s.gen" % t["owner"], "owner_dat": "@name.%s.dat" % t["owner"]}
	var v := _prompt_box(list, Loc.t("review_title"))
	v.add_child(_label(Loc.render("review.context", [], {"owner": Loc.person(t["owner"])}), 13, COL_MUTED, true))
	for choice in rules.review_choices(item):
		v.add_child(_answer_button(Loc.render("review.a." + choice, [], names), _answer.bind(choice)))
	v.add_child(_label(Loc.t("review_hint." + item["kind"]), 12, COL_MUTED, true))


func _offer_card(p: String, offer: String) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _box(Color("fffae6"), Color("ffe380"), 1, 10))
	var v := _vbox(6)
	box.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	head.add_child(_avatar(p, 28))
	head.add_child(_label(Loc.person(p), 14, COL_TEXT, false, true))
	v.add_child(_label(Loc.t("init.offer." + offer), 15, COL_TEXT, true))
	var b := _button(Loc.t("init.accept"), _accept_initiative.bind(p), 0, "primary")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(b)
	var wrap := _vbox(0)
	wrap.add_child(_spacer(8))
	wrap.add_child(box)
	return wrap


func _answer_button(text_value: String, action: Callable) -> Button:
	var b := _button(text_value, action, 0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _scroll_to_end(scroll: ScrollContainer) -> void:
	for i in 2:
		await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


# ---------- documents over the board ----------

# A sheet that takes the height of the window and scrolls if it has to.
func _document(width: int) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.118, 0.259, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -width / 2.0
	panel.offset_right = width / 2.0
	panel.offset_top = 32
	panel.offset_bottom = -32
	panel.add_theme_stylebox_override("panel", _box(COL_SURFACE, COL_BORDER, 1, 0))
	ui.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := _vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(v, 28, 24))
	return v


func _build_report() -> void:
	var w := rules.week()
	var v := _document(780)
	v.add_child(_label(Loc.t("report_title", [w + 1]), 24, COL_TEXT, true, true))
	v.add_child(_label(Loc.t("report_hint"), 14, COL_MUTED, true))
	v.add_child(_spacer(4))
	for p in C.TEAM:
		var st: Dictionary = rules.people[p]
		var hours: int = st["week_hours"][w]
		var norm: int = 8 * (5 - st["week_absent"][w])
		var extra: int = st["week_extra"][w]
		var line := Loc.render("report.row", [], {"who": Loc.person(p), "hours": hours, "norm": norm, "done": st["week_done"][w]})
		if extra > 0:
			line += Loc.render("report.overtime", [], {"hours": extra})
		if st["week_absent"][w] > 0:
			line += Loc.render("report.absent", [], {"days": st["week_absent"][w]})
		if st["gone"]:
			line += " — " + Loc.t("gone_label")
		var color := COL_DANGER if extra >= 6 else (COL_WARN if hours * 2 <= norm else COL_TEXT)
		v.add_child(_report_row(p, line, color))
	var mine: int = rules.my_week_hours[w]
	v.add_child(_report_row("me", Loc.render("report.me", [], {"hours": mine, "mgmt": rules.my_week_mgmt[w]}), COL_GOOD if mine < 8 else (COL_WARN if mine < 16 else COL_DANGER)))
	var late := 0
	for t in rules.tasks:
		if t["late"] and int((t["late_day"] - 1) / 5.0) == w:
			late += 1
	v.add_child(_spacer(4))
	v.add_child(_label(Loc.render("report.late", [], {"count": late}), 15, COL_DANGER if late > 0 else COL_MUTED, true))
	v.add_child(_label(_keys_text(), 15, COL_WARN, true))
	if rules.survey.get("day", -1) == rules.day:
		_survey_block(v)
	v.add_child(_spacer(6))
	var b := _button(Loc.t("report.to_review" if not rules.review.is_empty() else "report.next"), _continue_report, 260, "primary")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(b)


func _report_row(p: String, text_value: String, color: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(_avatar(p, 28))
	var l := _label(text_value, 15, color, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h


func _keys_text() -> String:
	var k := rules.key_status()
	var parts := PackedStringArray()
	for part in ["good", "bad", "late", "open", "ahead"]:
		if k[part] > 0:
			parts.append(Loc.render("key." + part, [], {"n": k[part]}))
	return Loc.render("report.keys", [], {"parts": ", ".join(parts)})


func _survey_block(v: VBoxContainer) -> void:
	v.add_child(_spacer(4))
	v.add_child(_section(Loc.t("survey_title")))
	for q in rules.survey["quotes"]:
		v.add_child(_label("— " + Loc.t("quote", [Loc.t(q)]), 15, COL_TEXT, true))
	var verdict: String = rules.survey["verdict"]
	v.add_child(_label(Loc.t("survey.verdict." + verdict), 15, COL_GOOD if verdict == "for" else (COL_WARN if verdict == "wary" else COL_DANGER), true, true))


func _build_end() -> void:
	var v := _document(780)
	var good := rules.ending in ["leader", "puppeteer", "beloved"]
	v.add_child(_label(Loc.t("ending.%s.title" % rules.ending), 28, COL_GOOD if good else COL_DANGER, true, true))
	v.add_child(_label(Loc.t("ending.%s.text" % rules.ending), 16, COL_TEXT, true))
	v.add_child(_label(Loc.t("summary.hours", [rules.hours]), 15, COL_GOOD if rules.hours == 0 else COL_DANGER, true))
	var done := 0
	var late := 0
	for t in rules.tasks:
		if t["status"] == "done":
			done += 1
		if t["late"]:
			late += 1
	v.add_child(_label(Loc.t("summary.done", [done, late]), 15, COL_TEXT, true))
	var k := rules.key_status()
	v.add_child(_label(Loc.render("summary.results", [], {"good": k["good"], "total": C.KEY_PROJECTS.size(), "boss": "@weight." + rules.boss_word()}), 15, COL_TEXT, true))
	if rules.ending in ["leader", "puppeteer"]:
		v.add_child(_label(Loc.t("promoted.yes" if rules.promoted else "promoted.no"), 15, COL_GOOD if rules.promoted else COL_MUTED, true))
	_adizes_block(v)
	if not rules.survey.is_empty():
		_survey_block(v)
	v.add_child(_spacer(4))
	v.add_child(_section(Loc.t("summary.team")))
	for p in C.TEAM:
		var parts := PackedStringArray()
		if rules.people[p]["gone"]:
			parts.append(Loc.t("gone_label"))
		else:
			parts.append(Loc.t("mood." + rules.mood_word(p)))
			if _trust_word(p) != "":
				parts.append(Loc.t("trust." + _trust_word(p)))
		var grown := PackedStringArray()
		for cat in rules.skills_grown(p):
			grown.append(Loc.t("cat." + cat))
		if not grown.is_empty():
			parts.append(Loc.t("summary.grew", [", ".join(grown)]))
		v.add_child(_report_row(p, "%s — %s" % [Loc.person(p), ", ".join(parts)], COL_TEXT))
	var promises := PackedStringArray()
	for p in rules.broken_promises():
		promises.append(Loc.person(p))
	if not promises.is_empty():
		v.add_child(_label(Loc.t("summary.promises", [", ".join(promises)]), 15, COL_DANGER, true))
	v.add_child(_spacer(6))
	var b := _button(Loc.t("again"), _start_run, 300, "primary")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(b)


# How Irina read your style: your Adizes code, what kind of lead that makes you, and what she herself is.
func _adizes_block(v: VBoxContainer) -> void:
	v.add_child(_spacer(4))
	var kind := rules.adizes_type()
	v.add_child(_label(Loc.render("adizes.title", [], {"code": rules.adizes_code()}) + " — " + Loc.t("adizes.type.%s.title" % kind), 18, COL_DANGER if rules.mismanaged() else COL_TEXT, true, true))
	v.add_child(_label(Loc.t("adizes.type.%s.text" % kind), 15, COL_TEXT, true))
	v.add_child(_label(Loc.t("adizes.boss." + rules.boss_type), 15, COL_MUTED, true))
	v.add_child(_label(Loc.t("adizes.legend"), 12, COL_FAINT, true))


# ---------- text ----------

func _trust_word(p: String) -> String:
	var t: int = rules.people[p]["trust"]
	if t <= -2:
		return "hurt"
	if t == -1:
		return "wary"
	if t >= 1:
		return "trusts"
	return ""


func _entry_text(entry: Dictionary) -> String:
	var body := Loc.render(entry["key"], entry.get("args", []), entry.get("names", {}))
	match entry["who"]:
		"":
			return body
		"you":
			if entry.has("to"):
				return "%s → %s: %s" % [Loc.t("you"), Loc.t("name.%s.dat" % entry["to"]), Loc.t("quote", [body])]
			return "%s: %s" % [Loc.t("you"), Loc.t("quote", [body])]
	return "%s: %s" % [Loc.person(entry["who"]), body if body.begins_with("(") or body.begins_with("«") or body.begins_with("\"") else Loc.t("quote", [body])]


# ---------- widget helpers ----------

func _avatar(p: String, size: int) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(size, size)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := _flat(AVATAR_COLORS.get(p, COL_MUTED))
	style.set_corner_radius_all(int(size / 2.0))
	box.add_theme_stylebox_override("panel", style)
	var name := Loc.t("you") if p == "me" else Loc.person(p)
	box.tooltip_text = name
	var l := _label(name.substr(0, 1).to_upper(), int(size * 0.46), COL_SURFACE, false, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	return box


func _pill(text_value: String, fg: Color, bg: Color) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _flat(bg)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(_label(text_value, 11, fg, false, true))
	return chip


func _section(text_value: String) -> Label:
	return _label(text_value.to_upper(), 11, COL_MUTED, false, true)


func _label(text_value: String = "", size: int = BASE_FONT, color: Color = COL_TEXT, wrap: bool = false, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _vbox(separation: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


func _flow(h_sep: int, v_sep: int) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", h_sep)
	f.add_theme_constant_override("v_separation", v_sep)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


func _padded(c: Control, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.add_child(c)
	return m


func _scroll(key: String) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scrolls[key] = s
	return s


func _restore_scrolls() -> void:
	var saved := scroll_memory.duplicate()
	var live := scrolls.duplicate()
	await get_tree().process_frame
	for key in live:
		if saved.has(key) and is_instance_valid(live[key]):
			live[key].scroll_vertical = saved[key]


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# Button looks: "" plain, "primary", "subtle" (quiet), "chosen" (the current pick), "on_top" (on the top bar).
func _button(text_value: String, action: Callable, min_width: int, look: String = "") -> Button:
	var b := Button.new()
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_width, 34)
	b.add_theme_font_size_override("font_size", 14)
	var fill := COL_COLUMN
	var hover := COL_BORDER
	var text_color := Color("42526e")
	match look:
		"primary":
			fill = COL_PRIMARY
			hover = COL_PRIMARY_HOVER
			text_color = COL_SURFACE
			b.add_theme_font_override("font", font_bold)
		"subtle":
			fill = COL_BG
			hover = COL_COLUMN
		"chosen":
			fill = COL_SELECTED
			hover = COL_SELECTED
			text_color = COL_PRIMARY
		"on_top":
			fill = Color(1, 1, 1, 0.12)
			hover = Color(1, 1, 1, 0.22)
			text_color = COL_ON_TOP
	b.add_theme_stylebox_override("normal", _box(fill, fill, 0, 8))
	b.add_theme_stylebox_override("hover", _box(hover, hover, 0, 8))
	b.add_theme_stylebox_override("pressed", _box(hover.darkened(0.08), hover, 0, 8))
	b.add_theme_stylebox_override("disabled", _box(fill if look == "chosen" else COL_BG, COL_BG, 0, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, text_color)
	b.add_theme_color_override("font_disabled_color", COL_PRIMARY if look == "chosen" else COL_FAINT)
	b.pressed.connect(action)
	return b


func _flat(fill: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	return s


func _box(fill: Color, border: Color, border_width: int, padding: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(padding)
	return s
