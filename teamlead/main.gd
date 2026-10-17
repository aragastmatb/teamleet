extends Control
# UI for the team lead prototype. Rules live in rules.gd, content in content.gd, text in locale.gd.

const Rules = preload("res://teamlead/rules.gd")
const Loc = preload("res://teamlead/locale.gd")
const C = preload("res://teamlead/content.gd")

const BASE_FONT := 18
const COL_BG := Color("1d2027")
const COL_PANEL := Color("2a2e37")
const COL_PANEL_BORDER := Color("3a3f4b")
const COL_TEXT := Color("ece8e1")
const COL_MUTED := Color("9aa0ab")
const COL_ACCENT := Color("f0b44c")
const COL_DANGER := Color("e2645a")
const COL_GOOD := Color("6fcf97")
const COL_INK := Color("2a2a2e")
const COL_PAPER := Color("f4efe6")
const COL_INK_MUTED := Color("6b6b73")
const MOOD_COLORS := {"happy": COL_GOOD, "good": COL_GOOD, "neutral": COL_TEXT, "down": COL_ACCENT, "angry": COL_DANGER}
const ENERGY_COLORS := {"fresh": COL_GOOD, "ok": COL_TEXT, "tired": COL_ACCENT, "drained": COL_DANGER}
const BOSS_COLORS := {"thrilled": COL_GOOD, "pleased": COL_GOOD, "watching": COL_TEXT, "doubts": COL_ACCENT, "angry": COL_DANGER}
const CAT_COLORS := {"tech": Color("4a8fd9"), "analytics": Color("9b6cd6"), "people": Color("d46a9f"), "routine": Color("7d9a6a")}

var rules := Rules.new()
var ui: Control
var selected := -1
var picked := ""
var picked_helper := ""
# Replies to your last action, shown in the bottom panel where you're looking.
var feedback_from := -1
var talk_with := ""
var review_choices := {}


func _ready() -> void:
	Loc.lang = "ru" if OS.get_locale_language() == "ru" else "en"
	var ui_theme := Theme.new()
	ui_theme.default_font_size = BASE_FONT
	ui_theme.set_color("font_color", "Label", COL_TEXT)
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
	picked = ""
	talk_with = ""
	_render()


func _pick(p: String) -> void:
	picked = p
	if picked_helper == p:
		picked_helper = ""
	_render()


func _pick_helper(p: String) -> void:
	picked_helper = "" if picked_helper == p else p
	_render()


func _assign(tone: String) -> void:
	feedback_from = rules.history.size()
	var uid := selected
	rules.assign(uid, picked, tone)
	if picked_helper != "" and rules.task(uid)["owner"] == picked:
		rules.set_helper(uid, picked_helper)
	_clear_selection()


func _direct(p: String) -> void:
	feedback_from = rules.history.size()
	rules.assign(selected, p, "plain")
	_clear_selection()


func _helper(p: String) -> void:
	feedback_from = rules.history.size()
	rules.set_helper(selected, p)
	_render()


func _unassign() -> void:
	rules.unassign(selected)
	_render()


func _talk_to(p: String) -> void:
	talk_with = p
	selected = -1
	picked = ""
	_render()


func _talk(approach: String) -> void:
	feedback_from = rules.history.size()
	rules.one_on_one(talk_with, approach)
	talk_with = ""
	_render()


func _end_day() -> void:
	feedback_from = -1
	_clear_selection()
	talk_with = ""
	review_choices.clear()
	rules.end_day()
	_render()


func _next() -> void:
	rules.next()
	_render()


func _continue_report() -> void:
	rules.continue_report()
	_render()


func _event(choice: String) -> void:
	feedback_from = rules.history.size()
	rules.resolve_event(choice)
	_render()


func _review_pick(uid: int, choice: String) -> void:
	review_choices[uid] = choice
	_render()


func _confirm_review() -> void:
	rules.resolve_review(review_choices)
	review_choices.clear()
	_render()


func _start_run() -> void:
	rules.start_run()
	_clear_selection()
	_render()


func _clear_selection() -> void:
	selected = -1
	picked = ""
	picked_helper = ""
	_render()


func _toggle_lang() -> void:
	Loc.lang = "en" if Loc.lang == "ru" else "ru"
	_render()


# ---------- screens ----------

func _render() -> void:
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
	match rules.phase:
		"event":
			_build_event()
		"evening":
			_build_evening()
		"report":
			_build_report()
		"review":
			_build_review()
		"end":
			_build_end()


func _build_title() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var v := _vbox(18)
	v.custom_minimum_size.x = 1000
	center.add_child(v)
	v.add_child(_label(Loc.t("title"), 40, COL_ACCENT, true))
	v.add_child(_label(Loc.t("tagline"), 22, COL_TEXT, true))
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.text = Loc.t("rules")
	text.add_theme_font_size_override("normal_font_size", 18)
	text.add_theme_font_size_override("bold_font_size", 18)
	text.add_theme_color_override("default_color", COL_TEXT)
	v.add_child(text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	v.add_child(buttons)
	buttons.add_child(_button(Loc.t("start"), _start_run, 300, true))
	buttons.add_child(_button(Loc.t("lang_button"), _toggle_lang, 160))


func _build_office() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	ui.add_child(margin)
	var v := _vbox(8)
	margin.add_child(v)
	v.add_child(_top_bar())
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	v.add_child(middle)
	var board_scroll := ScrollContainer.new()
	board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(board_scroll)
	var board := _vbox(6)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_scroll.add_child(board)
	for p in C.TEAM:
		board.add_child(_person_row(p))
	board.add_child(_me_row())
	middle.add_child(_side())
	v.add_child(_action_panel())


func _top_bar() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	var header := _label(Loc.t("day.%d" % rules.day), 21)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	var word := rules.boss_word()
	top.add_child(_label(Loc.t("boss_label", ["@boss." + word]), 17, BOSS_COLORS[word]))
	var lang := _button(Loc.t("lang_button"), _toggle_lang, 110)
	lang.custom_minimum_size.y = 36
	top.add_child(lang)
	return top


func _person_row(p: String) -> Control:
	var st: Dictionary = rules.people[p]
	var row := PanelContainer.new()
	var highlight: bool = picked == p or talk_with == p
	row.add_theme_stylebox_override("panel", _box(COL_PANEL, COL_ACCENT if highlight else COL_PANEL_BORDER, 2 if highlight else 1, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var card := _vbox(1)
	card.custom_minimum_size.x = 330
	h.add_child(card)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	card.add_child(name_row)
	name_row.add_child(_label(Loc.person(p), 18))
	name_row.add_child(_label(Loc.t("role." + p), 13, COL_MUTED))
	if st["gone"]:
		card.add_child(_label(Loc.t("gone_label"), 14, COL_DANGER))
		row.modulate = Color(1, 1, 1, 0.5)
		return row
	var state := HBoxContainer.new()
	state.add_theme_constant_override("separation", 8)
	card.add_child(state)
	if st["absent"]:
		state.add_child(_label(Loc.t("absent.%s_label" % st["absent_reason"]), 14, COL_ACCENT))
	var mood := rules.mood_word(p)
	state.add_child(_label(Loc.t("mood." + mood), 14, MOOD_COLORS[mood]))
	var energy := rules.energy_word(p)
	state.add_child(_label("· " + Loc.t("energy." + energy), 14, ENERGY_COLORS[energy]))
	var trust := _trust_word(p)
	if trust != "":
		state.add_child(_label("· " + Loc.t("trust." + trust), 14, COL_GOOD if trust == "trusts" else COL_DANGER))
	var known: Dictionary = st["known"]
	var drive_text: String = Loc.t("drive." + C.PEOPLE[p]["drive"]) if known.has("drive") else Loc.t("unknown")
	card.add_child(_label(Loc.t("known.drive", [drive_text]), 12, COL_MUTED, true))
	var skills := PackedStringArray()
	for cat in C.CATEGORIES:
		var level: String = Loc.t("level.%d" % st["skills"][cat]) if known.has("skill." + cat) else Loc.t("unknown")
		skills.append("%s: %s" % [Loc.t("cat." + cat), level])
	card.add_child(_label(Loc.t("known.skills", [", ".join(skills)]), 12, COL_MUTED, true))
	var middle := _vbox(6)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(middle)
	var queue := HFlowContainer.new()
	queue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue.add_theme_constant_override("h_separation", 6)
	queue.add_theme_constant_override("v_separation", 6)
	middle.add_child(queue)
	var said := _said_today(p)
	if said != "":
		middle.add_child(_bubble(said))
	for t in rules.queue_of(p):
		queue.add_child(_task_chip(t))
	for t in rules.tasks:
		if t["status"] == "active" and t["helper"] == p:
			var helping := _label(Loc.t("helper_badge", ["«%s»" % Loc.t("taskname." + t["id"])]), 12, COL_MUTED, true)
			helping.custom_minimum_size.x = 150
			queue.add_child(helping)
	var talk := _button(Loc.t("talk_button"), _talk_to.bind(p), 0)
	talk.custom_minimum_size = Vector2(110, 34)
	talk.disabled = rules.phase != "plan" or rules.talked_today or st["absent"]
	talk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(talk)
	return row


# The last thing this person said today, if anything.
func _said_today(p: String) -> String:
	for i in range(rules.history.size() - 1, -1, -1):
		var e: Dictionary = rules.history[i]
		if e["day"] != rules.day:
			break
		if e["who"] == p:
			var body := Loc.render(e["key"], e.get("args", []), e.get("names", {}))
			return body if body.begins_with("(") or body.begins_with("«") or body.begins_with("\"") else Loc.t("quote", [body])
	return ""


func _bubble(text_value: String) -> Control:
	var box := PanelContainer.new()
	var style := _box(COL_BG.lightened(0.06), COL_PANEL_BORDER, 1, 6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", style)
	box.add_child(_label(text_value, 13, COL_TEXT, true))
	return box


func _me_row() -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _box(COL_PANEL.darkened(0.15), COL_PANEL_BORDER, 1, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var name := _label(Loc.t("me_row"), 16, COL_MUTED)
	name.custom_minimum_size.x = 330
	h.add_child(name)
	var queue := HFlowContainer.new()
	queue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue.add_theme_constant_override("h_separation", 6)
	h.add_child(queue)
	for t in rules.queue_of("me"):
		queue.add_child(_task_chip(t))
	return row


func _side() -> Control:
	var side := _vbox(8)
	side.custom_minimum_size.x = 330
	var inbox := PanelContainer.new()
	inbox.add_theme_stylebox_override("panel", _box(COL_PANEL.darkened(0.2), COL_PANEL_BORDER, 1, 8))
	inbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(inbox)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inbox.add_child(scroll)
	var iv := _vbox(6)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(iv)
	iv.add_child(_label(Loc.t("inbox"), 12, COL_MUTED))
	var items := rules.inbox()
	if items.is_empty():
		iv.add_child(_label(Loc.t("inbox_empty"), 14, COL_MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	iv.add_child(flow)
	for t in items:
		flow.add_child(_task_chip(t))
	return side


func _task_chip(t: Dictionary) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(160, 70)
	var chosen: bool = selected == t["uid"]
	var color: Color = CAT_COLORS[t["cat"]]
	var normal := _box(COL_PAPER if not chosen else COL_PAPER.lightened(0.5), COL_ACCENT if chosen else color, 3 if chosen else 2, 6)
	normal.border_width_left = 6
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", _box(COL_PAPER.lightened(0.5), COL_ACCENT, 2, 6))
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("disabled", normal)
	b.disabled = rules.phase != "plan"
	b.pressed.connect(_select.bind(t["uid"]))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	b.add_child(margin)
	var v := _vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)
	v.add_child(_label(Loc.t("taskname." + t["id"]), 13, COL_INK, true))
	var due := _due_text(t)
	if t["helper"] != "" and t["status"] == "active":
		due += "  " + Loc.t("chip_helper", [Loc.person(t["helper"])])
	v.add_child(_label(due, 11, COL_DANGER if t["late"] or t["due"] - rules.day <= 0 else COL_INK_MUTED))
	if t["status"] == "active":
		var bar := ProgressBar.new()
		bar.max_value = t["size"]
		bar.value = minf(t["progress"], t["size"])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _box(COL_PAPER.darkened(0.15), COL_PAPER.darkened(0.15), 0, 0))
		bar.add_theme_stylebox_override("fill", _box(color, color, 0, 0))
		v.add_child(bar)
	return b


func _due_text(t: Dictionary) -> String:
	if t["late"]:
		return Loc.t("due.late")
	var left: int = t["due"] - rules.day
	if left <= 0:
		return Loc.t("due.today")
	if left == 1:
		return Loc.t("due.tomorrow")
	return Loc.t("due.days", [left])


func _action_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 168
	panel.add_theme_stylebox_override("panel", _box(COL_PANEL, COL_PANEL_BORDER, 1, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)
	var v := _vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	if talk_with != "":
		_talk_actions(v)
	elif selected >= 0 and not rules.task(selected).is_empty() and rules.task(selected)["status"] in ["inbox", "active"]:
		_task_actions(v, rules.task(selected))
	else:
		var replies := _feedback_lines()
		for line in replies:
			v.add_child(_label(line, 18, COL_TEXT, true))
		if replies.is_empty():
			v.add_child(_label(Loc.t("pick_task"), 16, COL_MUTED, true))
		if rules.talked_today:
			v.add_child(_label(Loc.t("talk_used"), 14, COL_MUTED, true))
	var end := _button(Loc.t("end_day"), _end_day, 220, true)
	end.disabled = rules.phase != "plan"
	end.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(end)
	return panel


func _task_actions(v: VBoxContainer, t: Dictionary) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_label(Loc.t("taskname." + t["id"]), 18, COL_ACCENT))
	head.add_child(_chip(Loc.t("cat." + t["cat"]), CAT_COLORS[t["cat"]]))
	head.add_child(_chip(Loc.t(rules.size_word(t)), COL_MUTED))
	head.add_child(_chip(_due_text(t), COL_DANGER if t["due"] - rules.day <= 1 else COL_MUTED))
	if t["public"]:
		head.add_child(_chip(Loc.t("public"), COL_ACCENT))
	v.add_child(_label("%s — %s" % [Loc.t("from", [Loc.person(t["from"])]), Loc.t("quote", [Loc.t("task.%s.ask" % t["id"])])], 14, COL_MUTED, true))
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 6)
	v.add_child(who)
	who.add_child(_label(Loc.t("to_whom"), 14, COL_MUTED))
	for p in C.TEAM:
		if not rules.available(p):
			continue
		var b := _button(Loc.person(p), _pick.bind(p), 0, picked == p)
		b.disabled = t["owner"] == p
		who.add_child(b)
	who.add_child(_button(Loc.t("myself"), _direct.bind("me"), 0))
	who.add_child(_button(Loc.t("to_taras"), _direct.bind("taras"), 0))
	if t["status"] == "active":
		who.add_child(_button(Loc.t("unassign"), _unassign, 0))
	if picked != "":
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		v.add_child(pair)
		pair.add_child(_label(Loc.t("helper_optional"), 14, COL_MUTED))
		for p in C.TEAM:
			if p != picked and rules.available(p):
				pair.add_child(_button(Loc.person(p), _pick_helper.bind(p), 0, picked_helper == p))
		pair.add_child(_label(Loc.t("helper_hint"), 12, COL_MUTED, true))
		pair.get_child(pair.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tones := HFlowContainer.new()
		tones.add_theme_constant_override("h_separation", 6)
		tones.add_theme_constant_override("v_separation", 6)
		v.add_child(tones)
		tones.add_child(_label(Loc.t("how"), 14, COL_MUTED))
		for tone in C.TONES:
			tones.add_child(_button(Loc.t("tone." + tone), _assign.bind(tone), 0))
	elif t["status"] == "active" and C.TEAM.has(t["owner"]):
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		v.add_child(pair)
		pair.add_child(_label(Loc.t("helper_optional"), 14, COL_MUTED))
		for p in C.TEAM:
			if p != t["owner"] and rules.available(p):
				pair.add_child(_button(Loc.person(p), _helper.bind(p), 0, t["helper"] == p))
		pair.add_child(_button(Loc.t("no_helper"), _helper.bind(""), 0, t["helper"] == ""))
		pair.add_child(_label(Loc.t("helper_hint"), 12, COL_MUTED, true))
		pair.get_child(pair.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _feedback_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if feedback_from < 0:
		return out
	for i in range(feedback_from, rules.history.size()):
		var e: Dictionary = rules.history[i]
		if e["who"] != "you":
			out.append(_entry_text(e))
	return out.slice(maxi(0, out.size() - 3))


func _talk_actions(v: VBoxContainer) -> void:
	v.add_child(_label(Loc.t("talk_title", [Loc.person(talk_with)]), 18, COL_ACCENT))
	var options := HFlowContainer.new()
	options.add_theme_constant_override("h_separation", 6)
	options.add_theme_constant_override("v_separation", 6)
	v.add_child(options)
	for approach in C.ONE_ON_ONE:
		options.add_child(_button(Loc.t("talk." + approach), _talk.bind(approach), 0))


# ---------- overlays ----------

func _overlay(width: int) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(COL_PANEL, COL_ACCENT, 2, 22))
	center.add_child(panel)
	var v := _vbox(10)
	v.custom_minimum_size.x = width
	panel.add_child(v)
	return v


func _build_event() -> void:
	var ev: Dictionary = rules.events[0]
	var v := _overlay(700)
	for line in ev["lines"]:
		v.add_child(_label(Loc.person(line["who"]), 15, COL_MUTED))
		v.add_child(_label(Loc.t("quote", [Loc.render(line["key"], [], ev["names"])]), 21, COL_TEXT, true))
	v.add_child(_spacer(6))
	for choice in ev["choices"]:
		var parts: PackedStringArray = choice.split(":")
		var names: Dictionary = ev["names"].duplicate()
		if parts.size() > 1:
			names["who"] = "@name.%s.acc" % parts[1]
		v.add_child(_button(Loc.render("event.%s.choice.%s" % [ev["id"], parts[0]], [], names), _event.bind(choice), 0))


func _build_evening() -> void:
	var v := _overlay(760)
	v.add_child(_label(Loc.t("evening_title"), 22, COL_ACCENT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 380
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := _vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in range(rules.evening_from + 1, rules.history.size()):
		var entry: Dictionary = rules.history[i]
		var color := COL_MUTED if entry["who"] == "" else (COL_ACCENT if entry["who"] == "you" else COL_TEXT)
		list.add_child(_label(_entry_text(entry), 16, color, true))
	v.add_child(_button(Loc.t("to_end" if rules.day >= C.DAYS else "next_day"), _next, 260, true))


func _build_report() -> void:
	var w := rules.week()
	var v := _overlay(720)
	v.add_child(_label(Loc.t("report_title", [w + 1]), 24, COL_ACCENT))
	v.add_child(_label(Loc.t("report_hint"), 14, COL_MUTED, true))
	for p in C.TEAM:
		var st: Dictionary = rules.people[p]
		var hours: int = st["week_hours"][w]
		var line := Loc.render("report.row", [], {"who": Loc.person(p), "hours": hours, "done": st["week_done"][w]})
		if st["week_overtime"][w] > 0:
			line += Loc.render("report.overtime", [], {"days": st["week_overtime"][w]})
		if st["gone"]:
			line += " — " + Loc.t("gone_label")
		var color := COL_DANGER if hours >= 46 else (COL_ACCENT if hours <= 16 else COL_TEXT)
		v.add_child(_label(line, 18, color, true))
	v.add_child(_label(Loc.render("report.me", [], {"hours": rules.my_week_hours[w]}), 18, COL_GOOD if rules.my_week_hours[w] == 0 else COL_ACCENT))
	var late := 0
	for t in rules.tasks:
		if t["late"] and int((t["late_day"] - 1) / 5.0) == w:
			late += 1
	v.add_child(_label(Loc.render("report.late", [], {"count": late}), 16, COL_DANGER if late > 0 else COL_MUTED))
	v.add_child(_spacer(6))
	v.add_child(_button(Loc.t("report.to_review" if not rules.review.is_empty() else "report.next"), _continue_report, 260, true))


func _build_review() -> void:
	var v := _overlay(820)
	v.add_child(_label(Loc.t("review_title"), 22, COL_ACCENT))
	v.add_child(_label(Loc.t("review_hint"), 14, COL_MUTED, true))
	for item in rules.review:
		var t := rules.task(item["uid"])
		var line := Loc.t("review.kind." + item["kind"], [Loc.t("taskname." + t["id"]), Loc.person(t["owner"])])
		v.add_child(_label(line, 17, COL_GOOD if item["kind"] == "success" else COL_DANGER, true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		v.add_child(row)
		var options: Array = rules.review_choices(item)
		var current: String = review_choices.get(item["uid"], options[0])
		for choice in options:
			row.add_child(_button(Loc.t("review.choice." + choice), _review_pick.bind(item["uid"], choice), 0, current == choice))
	v.add_child(_button(Loc.t("review_confirm"), _confirm_review, 220, true))


func _build_end() -> void:
	var v := _overlay(760)
	var good := rules.ending in ["leader", "puppeteer"]
	v.add_child(_label(Loc.t("ending.%s.title" % rules.ending), 30, COL_GOOD if good else COL_DANGER, true))
	v.add_child(_label(Loc.t("ending.%s.text" % rules.ending), 18, COL_TEXT, true))
	v.add_child(_label(Loc.t("summary.hours", [rules.hours]), 17, COL_GOOD if rules.hours == 0 else COL_DANGER))
	var done := 0
	var late := 0
	for t in rules.tasks:
		if t["status"] == "done":
			done += 1
		if t["late"]:
			late += 1
	v.add_child(_label(Loc.t("summary.done", [done, late]), 16))
	v.add_child(_label(Loc.t("summary.boss", ["@boss." + rules.boss_word()]), 16))
	v.add_child(_label(Loc.t("summary.team"), 14, COL_MUTED))
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
		v.add_child(_label("• %s — %s" % [Loc.person(p), ", ".join(parts)], 15, COL_TEXT, true))
	var promises := PackedStringArray()
	for p in rules.broken_promises():
		promises.append(Loc.person(p))
	if not promises.is_empty():
		v.add_child(_label(Loc.t("summary.promises", [", ".join(promises)]), 15, COL_DANGER, true))
	v.add_child(_button(Loc.t("again"), _start_run, 300, true))


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

func _chip(text_value: String, color: Color) -> Control:
	var chip := PanelContainer.new()
	var style := _box(COL_BG, color.darkened(0.2), 1, 0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(_label(text_value, 13, color.lightened(0.2)))
	return chip


func _label(text_value: String = "", size: int = BASE_FONT, color: Color = COL_TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _vbox(separation: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c


func _button(text_value: String, action: Callable, min_width: int, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_width, 36)
	b.add_theme_font_size_override("font_size", 16 if primary else 14)
	var fill := COL_ACCENT if primary else COL_PANEL.lightened(0.1)
	var text_color := COL_INK if primary else COL_TEXT
	b.add_theme_stylebox_override("normal", _box(fill, fill.lightened(0.15), 1, 8))
	b.add_theme_stylebox_override("hover", _box(fill.lightened(0.15), COL_ACCENT, 1, 8))
	b.add_theme_stylebox_override("pressed", _box(fill.darkened(0.15), COL_ACCENT, 1, 8))
	b.add_theme_stylebox_override("disabled", _box(COL_PANEL.darkened(0.2), COL_PANEL_BORDER, 1, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, text_color)
	b.add_theme_color_override("font_disabled_color", COL_MUTED)
	b.pressed.connect(action)
	return b


func _box(fill: Color, border: Color, border_width: int, padding: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(padding)
	return s
