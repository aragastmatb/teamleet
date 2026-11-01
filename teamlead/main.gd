extends Control
# UI for the team lead prototype. Rules live in rules.gd, content in content.gd, text in locale.gd.
# Layout, tracker style: the team on the left, the board in the middle, every conversation in the chat
# on the right. Only documents (the Friday report, the assessment) open over the board.

const Rules = preload("res://teamlead/rules.gd")
const Loc = preload("res://teamlead/locale.gd")
const C = preload("res://teamlead/content.gd")
const Dialogue = preload("res://teamlead/dialogue.gd")
const DevTest = preload("res://teamlead/devtest.gd")

const BASE_FONT := 15
const SIDEBAR_W := 250
const CHAT_W := 350
const TOP_H := 50
# Base sizes the screen is laid out for: a landscape desktop, or a phone held upright.
const DESKTOP_SIZE := Vector2i(1280, 800)
const PHONE_SIZE := Vector2i(430, 860)
const PHONE_WIDE_SIZE := Vector2i(860, 430) # a phone on its side
# Below this (in CSS pixels on the web, window pixels elsewhere) the desktop layout gets too small to read.
const DESKTOP_MIN := Vector2(900, 560)
const PHONE_TOP_H := 64

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
# The upgrade tree's cork board.
const COL_CORK := Color("dcc29a")
const COL_CORK_LINE := Color("c7a878")
const COL_CORK_TEXT := Color("5b4630")
const COL_STICKY := Color("ffe46b")
const COL_STICKY_PALE := Color("fff3b8")
const COL_STICKY_LOCKED := Color("efeae0")
const COL_STICKY_BUILD := Color("c4e1ff")
const COL_STICKY_DONE := Color("c6efce")
const COL_THREAD := Color("c0392b")
const COL_THREAD_OK := Color("2e7d32")
const COL_GAIN := Color("36b37e") # today's part of a progress bar
const COL_EARLIER := Color("abf5d1") # the part done before today
const COL_STAR := Color("ff991f")
# On the dark top bar.
const COL_ON_TOP := Color("ffffff")
const COL_ON_TOP_MUTED := Color("b3d4ff")
const COL_ON_TOP_GOOD := Color("79f2c0")
const COL_ON_TOP_DANGER := Color("ffbdad")
# How someone feels in a story conversation: the ring around their portrait and the tag under it.
const EMO_COLORS := {
	"happy": Color("00875a"), "excited": Color("ff991f"), "annoyed": Color("de350b"), "angry": Color("bf2600"),
	"tired": Color("5e6c84"), "sad": Color("0065ff"), "worried": Color("b65c02"), "embarrassed": Color("e774bb"),
	"sarcastic": Color("6554c0"),
}

const MOOD_COLORS := {"happy": COL_GOOD, "good": COL_GOOD, "neutral": COL_MUTED, "down": COL_WARN, "angry": COL_DANGER}
const ENERGY_COLORS := {"fresh": COL_GOOD, "ok": COL_MUTED, "tired": COL_WARN, "drained": COL_DANGER}
const BOSS_COLORS := {"w3": COL_ON_TOP_GOOD, "w2": COL_ON_TOP_GOOD, "w1": COL_ON_TOP, "w0": COL_ON_TOP_DANGER}
# Category labels: text colour and fill, like tracker labels.
const CAT_COLORS := {
	"pipelines": [Color("006644"), Color("e3fcef")],
	"infra": [Color("0747a6"), Color("deebff")],
	"portal": [Color("403294"), Color("eae6ff")],
	"support": [Color("a3195b"), Color("ffe3f1")],
}
# Category icons, drawn white in art/icons/cat_<cat>.svg and tinted with the label's text colour.
const ICON_DIR := "res://art/icons/"
const AVATAR_COLORS := {
	"alex": Color("0065ff"), "vika": Color("ff5630"), "gena": Color("36b37e"), "dima": Color("6554c0"),
	"boss": Color("7a2048"), "marina": Color("00a3bf"), "taras": Color("ff8b00"), "me": Color("0747a6"), "palych": Color("8777d9"), "oleg": Color("5e6c84"), "buyer": Color("403294"),
	"contractor": Color("7a869a"), "stas": Color("de350b"), "olga": Color("8777d9"), "boris": Color("5e6c84"),
}

const HIRE_COLORS := [Color("00b8d9"), Color("ff7452"), Color("57d9a3"), Color("998dd9"), Color("ffab00"), Color("2684ff")]
const BANK_COLORS := {"happy": Color("00875a"), "fine": Color("5e6c84"), "unhappy": Color("b65c02"), "leaving": Color("de350b")}

var rules := Rules.new()
var ui: Control
var selected := -1
var font_bold: Font
# Scroll positions survive a re-render; the chat always jumps to the newest line.
var scroll_memory := {}
var scrolls := {}
# Sound: one cue per change on screen, the most important one wins. CC0 sounds by Kenney, sounds/.
const SOUNDS := ["click", "select", "assign", "message", "question", "day_end", "report", "weight_up", "weight_down", "trouble", "ending_good", "ending_bad"]
const SETTINGS_PATH := "user://settings.cfg"
# One player per sound, each with its stream set once: the web build plays sounds as samples and
# doesn't pick up a stream swapped on a player that's already been used.
var players := {}
var sound_on := true # false when the volume is at zero
var volume := 0.8
# Text size: every font size goes through _fs(); the layout itself stays the same.
const TEXT_SCALES := {"normal": 1.0, "large": 1.15, "larger": 1.3}
var text_scale := "normal"
# The menu: on the title screen, and over the game when opened from the top bar (or Esc).
# menu_page is "" for the list itself, or "settings", "about", "confirm_new".
var menu_open := false
# Across runs: achievements earned for good, and the most periods an endless run has lasted.
var unlocked: Array = []
var best_periods := 0
# This run's best before it started, so the end screen can say it's a new record.
var best_before := 0
# The top bar's counters as last drawn, and the nodes showing them now, so a change can be called out.
var juice_before := {}
var juice_nodes := {}
# Cards to light up on this render: uid -> colour.
var flash_cards := {}
# A window over the board (desktop): "hire", "upgrades", "boss", "company" or "person:<id>"; "" for none.
var window := ""
var menu_page := ""
var heard := 0
var last_phase := "title"
var cue := ""
# Phone layout: one screen at a time (board, team or chat) with tabs at the bottom.
var mobile := false
var tab := "board"
var lane := "inbox"
# The messenger: a column of contacts, and the one conversation that's open ("" for none).
var chat_thread := ""
# How far each conversation has been read, as an index into the history.
var thread_read := {}
# Each history line's conversation, worked out once a render; and each day's name, for the dividers.
var threads := {}
var day_names := {}
# The question the messenger last opened by itself, so it does it once.
var asked_seen := ""
# Where in the history the talk over the open task began, while it's on screen; -1 when there's none.
var deal_from := -1
var deal_who := ""
# Upgrades you could afford when you last looked at the tree; the counter only shows ones new since.
var upgrades_seen := {}
var up_branch := "" # the upgrade branch shown on the phone
# Where the chat was left. Anything new in it (a message, a question, answer buttons) brings it to the
# bottom; otherwise it stays where you scrolled it.
var chat_pos := 0
var chat_seen := ""
var chat_to_end := false # a scroll to the bottom is on its way; until it lands, the bottom is where the chat is
const HELD_WHILE_ASKED := ["_helper", "_end_day", "_visit_boss", "_unassign", "_talk_to", "_sit", "_reject_candidate",
	"_prioritize", "_pick", "_interview", "_ask_people", "_intervene", "_hire", "_fire", "_direct", "_decline", "_days", "_ask_stay",
	"_accept_initiative"]
var press_pos := Vector2.ZERO
# The setup screen before a run, and what's picked on it (remembered between runs).
var setup_open := false
var pick_boss := "random"
var pick_profile: String = C.DEFAULT_PROFILE
var pick_tips := true
# "endless" for everyone; the story runs only in a dev build (the editor, tools/test.sh).
var pick_mode := "endless"
# The last of Marina's tips the phone banner was closed on.
var tip_closed := ""
# The open conversation's list and scroll, and who spoke last in it (to group their lines).
var chat_list: VBoxContainer
var chat_scroll: ScrollContainer
var chat_last := ""


func _ready() -> void:
	Loc.lang = "ru" if OS.get_locale_language() == "ru" else "en"
	# Bundled fonts: the web build has no system fonts.
	var regular: Font = load("res://fonts/Inter-Regular.ttf")
	font_bold = load("res://fonts/Inter-Bold.ttf")
	var ui_theme := Theme.new()
	ui_theme.default_font = regular
	ui_theme.default_font_size = _fs(BASE_FONT)
	ui_theme.set_color("font_color", "Label", COL_TEXT)
	ui_theme.set_stylebox("panel", "TooltipPanel", _box(COL_TEXT, COL_TEXT, 0, 6))
	ui_theme.set_color("font_color", "TooltipLabel", COL_SURFACE)
	theme = ui_theme
	_fit_window()
	for name in SOUNDS:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://sounds/%s.ogg" % name)
		add_child(p)
		players[name] = p
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		volume = settings.get_value("audio", "volume", 0.8 if settings.get_value("audio", "sound_on", true) else 0.0)
		text_scale = settings.get_value("ui", "text_scale", text_scale)
		Loc.lang = settings.get_value("ui", "lang", Loc.lang)
		pick_boss = settings.get_value("setup", "boss", pick_boss)
		pick_profile = settings.get_value("setup", "profile", pick_profile)
		pick_tips = settings.get_value("setup", "tips", pick_tips)
		unlocked = settings.get_value("progress", "achievements", [])
		best_periods = settings.get_value("progress", "best_periods", 0)
	if not (pick_boss == "random" or C.BOSSES.has(pick_boss)):
		pick_boss = "random"
	if not C.PROFILES.has(pick_profile):
		pick_profile = C.DEFAULT_PROFILE
	if not TEXT_SCALES.has(text_scale):
		text_scale = "normal"
	theme.default_font_size = _fs(BASE_FONT)
	_apply_volume()
	_apply_layout_mode()
	get_viewport().size_changed.connect(_on_resize)
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_render()
	var args := OS.get_cmdline_user_args()
	var at := args.find("--start")
	if at >= 0 and at + 1 < args.size():
		_start_test(args[at + 1])


# tools/test.sh <point>: a fresh run, played up to where the test starts (teamlead/devtest.gd).
func _start_test(point: String) -> void:
	setup_open = false
	# The stand-in doesn't always get through a chapter's goals; a fresh run usually does.
	var reached := false
	for attempt in DevTest.ATTEMPTS:
		rules.start_run(-1, C.BOSS_KINDS[0] if pick_boss == "random" else pick_boss, pick_profile)
		rules.tips = pick_tips
		reached = DevTest.reach(rules, point)
		if reached:
			break
	# Questions before this point were answered for you; the "answer in the chat" lesson is behind you.
	rules.flags["chat_taught"] = true
	if reached:
		print("test point %s: chapter %d, day %d, %s" % [point, rules.chapter, rules.chapter_day(), rules.phase])
	else:
		push_warning("test point %s never came up; known points: %s" % [point, DevTest.points()])
	heard = rules.history.size()
	_read_all()
	_clear_selection()


# On Retina screens the window opens at physical pixels and looks tiny; scale it up to fit the screen.
func _fit_window() -> void:
	if OS.has_feature("web"):
		return # the page sizes the canvas
	var w := get_window()
	var screen := w.current_screen
	var hidpi := DisplayServer.screen_get_scale(screen)
	var usable := DisplayServer.screen_get_usable_rect(screen).size
	var target := Vector2(w.size) * hidpi
	var fit: float = minf(1.0, minf(usable.x * 0.95 / target.x, usable.y * 0.9 / target.y))
	w.size = Vector2i(target * fit)
	w.move_to_center()


# An upright window (a phone) gets the phone layout; the base size changes with it so text stays readable.
# Upright or small (a phone, also held sideways): the one-column layout. Windows and the web canvas
# are in device pixels, so a 3x phone or a Retina laptop is measured in points.
func _apply_layout_mode() -> bool:
	var size := Vector2(get_window().size) / maxf(1.0, DisplayServer.screen_get_scale())
	var phone := size.x < size.y or size.x < DESKTOP_MIN.x or size.y < DESKTOP_MIN.y
	var target := DESKTOP_SIZE if not phone else (PHONE_SIZE if size.x < size.y else PHONE_WIDE_SIZE)
	if phone == mobile and get_window().content_scale_size == target:
		return false
	mobile = phone
	get_window().content_scale_size = target
	return true


func _on_resize() -> void:
	if _apply_layout_mode() and ui:
		_render()


func _go_tab(name: String) -> void:
	tab = name
	if name != "board":
		selected = -1
	_render()


func _pick_lane(name: String) -> void:
	lane = name
	_render()


# ---------- actions ----------

func _select(uid: int) -> void:
	selected = uid
	deal_from = -1
	window = "task"
	_render()


# Picking someone hands them the task. If they push back, the window turns into the talk about it;
# if not, it closes, unless a helper can still be added right away (the story's mornings).
func _pick(p: String) -> void:
	var from := rules.history.size()
	rules.assign(selected, p)
	if not rules.pending.is_empty():
		deal_from = from
		deal_who = p
	elif p == "me" or not rules.allowed("pair"):
		selected = -1
		window = ""
	_render()


func _direct(p: String) -> void:
	_pick(p)


func _persuade(intent: String) -> void:
	rules.persuade(intent)
	_render()


# After the talk: back to the people if the task is still yours to hand out, otherwise done.
func _deal_done() -> void:
	deal_from = -1
	var t := rules.task(selected)
	if t.is_empty() or not rules.can_assign(t) or t["status"] != "inbox":
		selected = -1
		window = ""
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


func _intervene() -> void:
	var uid := selected
	_clear_selection()
	rules.intervene(uid)
	_render()


func _decline() -> void:
	var uid := selected
	_clear_selection()
	rules.decline(uid)
	_render()


func _ask_stay() -> void:
	rules.ask_stay(selected)
	_render()


func _prioritize() -> void:
	rules.prioritize(selected)
	_render()


func _unassign() -> void:
	rules.unassign(selected)
	_render()


func _talk_to(p: String) -> void:
	window = "" # what it opens is a conversation, which the window would cover
	selected = -1
	rules.start_talk(p)
	chat_thread = p
	if mobile:
		tab = "chat"
	_render()


func _visit_boss() -> void:
	window = ""
	_clear_selection()
	rules.visit_boss()
	_render()


func _end_day() -> void:
	_clear_selection()
	rules.end_day()
	_render()


func _start_work() -> void:
	_clear_selection()
	rules.start_work()
	_render()


# The board's main button: "get to work" on an endless morning, "end the day" otherwise, and on to the
# next day in the evening.
func _day_button(width: int) -> Button:
	if rules.phase == "evening":
		return _button(Loc.t("to_end" if rules.day >= rules.last_day() else "next_day"), _next, width, "primary")
	var morning := rules.endless() and rules.step == "triage"
	var b := _button(Loc.t("start_work" if morning else "end_day"), _start_work if morning else _end_day, width, "primary")
	b.disabled = rules.phase != "plan" or not rules.pending.is_empty()
	_lit(b, "end_day")
	return b


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
	setup_open = false
	if not (C.RUN_PROFILE_KINDS if pick_mode == "endless" else C.PROFILE_KINDS).has(pick_profile):
		pick_profile = C.DEFAULT_PROFILE
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("setup", "boss", pick_boss)
	settings.set_value("setup", "profile", pick_profile)
	settings.set_value("setup", "tips", pick_tips)
	settings.save(SETTINGS_PATH)
	best_before = best_periods
	rules.start_run(-1, C.BOSS_KINDS.pick_random() if pick_boss == "random" else pick_boss, pick_profile, pick_mode)
	rules.tips = pick_tips
	tip_closed = ""
	_clear_selection()
	_render()


func _open_setup(open: bool) -> void:
	setup_open = open
	_render()


func _toggle_tips() -> void:
	pick_tips = not pick_tips
	_render()


# Marina's tip lights up what it's about: a thicker orange edge on the panel or button.
func _lit(c: Control, target: String) -> void:
	if rules.tip_target() != target or rules.phase != "plan":
		return
	for name in (["panel"] if c is PanelContainer else ["normal", "hover", "disabled"]):
		var box = c.get_theme_stylebox(name)
		if box is StyleBoxFlat:
			box = box.duplicate()
			box.border_color = COL_STAR
			box.set_border_width_all(3)
			c.add_theme_stylebox_override(name, box)


# On a phone the chat is a tab away, so Marina's latest tip also shows above the board until closed.
func _tip_banner() -> Control:
	var id: String = rules.flags.get("tip_last", "")
	if id == "" or id == tip_closed or tab == "chat" or rules.phase != "plan" or rules.flags.get("tip_day", 0) != rules.day:
		return null
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("fffae6"), COL_STAR, 1, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(_avatar(rules.tip_who(), 28))
	var text := _label(Loc.t(rules.tip_key(id)), 13, COL_TEXT, true)
	text.custom_minimum_size.x = _view_width() - 120.0
	row.add_child(text)
	var close := _button("✕", func(): tip_closed = id; _render(), 36, "subtle")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(close)
	var wrap := _padded(card, 8, 6)
	wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return wrap


func _pick_option(kind: String, value: String) -> void:
	if kind == "boss":
		pick_boss = value
	else:
		pick_profile = value
	_render()


func _process(delta: float) -> void:
	if rules.phase == "title":
		_pan_title(delta)
		return


# Back to where the last session stopped, chat and all, without replaying its sounds.
func _continue_run() -> void:
	if not rules.load_game():
		_render()
		return
	heard = rules.history.size()
	last_phase = rules.phase
	_read_all()
	_clear_selection()


func _clear_selection() -> void:
	selected = -1
	_render()


func _save_setting(section: String, key: String, value) -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value(section, key, value)
	settings.save(SETTINGS_PATH)


func _apply_volume() -> void:
	sound_on = volume > 0.001
	AudioServer.set_bus_mute(0, not sound_on)
	if sound_on:
		AudioServer.set_bus_volume_db(0, linear_to_db(volume))


func _set_text_scale(key: String) -> void:
	text_scale = key
	_save_setting("ui", "text_scale", key)
	theme.default_font_size = _fs(BASE_FONT)
	_render()


func _fs(size: int) -> int:
	return int(round(size * float(TEXT_SCALES[text_scale])))


# What just happened, by what's new in the chat and where the game moved; the loudest thing wins.
func _sound_for_changes() -> String:
	if heard > rules.history.size():
		heard = 0
	var found := {}
	for i in range(heard, rules.history.size()):
		var e: Dictionary = rules.history[i]
		var key: String = e["key"]
		if key.begins_with("sick.") or key.begins_with("quit.") or key == "you.burnout":
			found["trouble"] = true
		elif key == "weight.up" or key == "weight.down":
			found[key.replace(".", "_")] = true
		elif key == "assign.say":
			found["assign"] = true
		elif e["who"] != "you" and e["who"] != "":
			found["message"] = true
	var grew := rules.history.size() > heard
	heard = rules.history.size()
	var phase: String = rules.phase
	var moved := phase != last_phase
	last_phase = phase
	if moved and (phase == "end" or phase == "chapter_end"):
		return "ending_good" if rules.passed() or rules.ending == "beloved" else "ending_bad"
	if moved and phase == "report":
		return "report"
	for name in ["trouble", "weight_down", "weight_up"]:
		if found.has(name):
			return name
	if (grew or moved) and _waiting_for_answer():
		return "question"
	if moved and phase == "evening":
		return "day_end"
	for name in ["assign", "message"]:
		if found.has(name):
			return name
	return cue


func _play(name: String) -> void:
	if sound_on and players.has(name):
		players[name].play()


func _set_lang(l: String) -> void:
	Loc.lang = l
	_save_setting("ui", "lang", l)
	_render()


func _open_menu() -> void:
	menu_open = true
	menu_page = ""
	_render()


func _close_menu() -> void:
	menu_open = false
	menu_page = ""
	_render()


func _menu_go(page: String) -> void:
	menu_page = page
	_render()


func _menu_new_game(run_mode: String) -> void:
	pick_mode = run_mode
	if Rules.has_save():
		_menu_go("confirm_new")
	else:
		_open_setup(true)


func _new_endless() -> void:
	pick_mode = "endless"
	_open_setup(true)


func _new_story() -> void:
	pick_mode = "story"
	_open_setup(true)


func _menu_new_confirmed() -> void:
	menu_page = ""
	_open_setup(true)


func _menu_to_title() -> void:
	menu_open = false
	menu_page = ""
	_to_title(false)


func _can_quit() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("mobile")


func _quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if menu_page != "":
		_menu_go("")
	elif rules.phase != "title" and not setup_open:
		if menu_open:
			_close_menu()
		else:
			_open_menu()


# ---------- screens ----------

func _render() -> void:
	if rules.auto_end_day():
		selected = -1
	var before := juice_before
	juice_before = _juice_state()
	juice_nodes.clear()
	flash_cards = _cards_to_flash(before, juice_before)
	if rules.phase != "title":
		rules.update_tips()
		_play(_sound_for_changes())
	# Every action ends in a render, so this keeps the save one step behind the player at most.
	if rules.phase == "end" or (rules.phase == "chapter_end" and not rules.next_chapter_ready()):
		Rules.delete_save()
	elif rules.phase != "title":
		rules.save_game()
	cue = ""
	if is_instance_valid(chat_scroll):
		chat_pos = 1 << 30 if chat_to_end else chat_scroll.scroll_vertical
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
		if setup_open:
			_build_setup()
		else:
			_build_title()
		_let_touches_through(ui)
		return
	if rules.phase == "draft":
		_build_draft()
		if menu_open:
			_build_menu_overlay()
		_let_touches_through(ui)
		_restore_scrolls()
		return
	_sort_threads()
	if not rules.convo.is_empty() and rules.convo["kind"] == "talk":
		chat_thread = rules.convo["who"]
	# A new question opens its conversation once; closing it leaves it closed.
	var asked := _asked_thread()
	var asked_key := ""
	if asked != "":
		asked_key = "%s/%s/%d" % [asked, rules.events[0]["id"] if rules.phase == "event" else "review", rules.day]
	if asked_key != "" and asked_key != asked_seen:
		chat_thread = asked
	asked_seen = asked_key
	if mobile:
		_build_phone()
	else:
		_build_office()
	# A talk plays out in the messenger; only an interview keeps its own window.
	if not rules.convo.is_empty() and rules.convo["kind"] != "talk":
		_build_convo()
	else:
		match rules.phase:
			"story":
				_build_story()
			"standup":
				_build_standup()
			"report":
				_build_report()
			"end", "chapter_end":
				_build_end()
	# A pushback is answered in the task's window, a reloaded game included.
	if not rules.pending.is_empty() and window != "task":
		selected = rules.pending["uid"]
		window = "task"
		deal_from = maxi(0, rules.history.size() - 2)
		deal_who = rules.pending["p"]
	if window != "" and rules.phase in ["plan", "event", "standup", "evening"]:
		_build_window()
	if menu_open:
		_build_menu_overlay()
	_let_touches_through(ui)
	_restore_scrolls()
	_juice.call_deferred(before, juice_before)
	_check_progress()


# New achievements pop up as they come and are kept for good; so is the longest endless run.
func _check_progress() -> void:
	if not rules.endless() or rules.phase in ["title", "draft"]:
		return
	var fresh: Array = rules.run_achievements().filter(func(a): return not unlocked.has(a))
	for i in fresh.size():
		unlocked.append(fresh[i])
		_achievement_toast.call_deferred(fresh[i], i)
	if not fresh.is_empty():
		_save_setting("progress", "achievements", unlocked)
	if rules.done_periods() > best_periods:
		best_periods = rules.done_periods()
		_save_setting("progress", "best_periods", best_periods)


func _achievement_toast(id: String, order: int) -> void:
	var box := PanelContainer.new()
	var style := _box(Color("fff7e6"), COL_STAR, 2, 12)
	style.set_corner_radius_all(12)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 70
	var v := _vbox(2)
	box.add_child(v)
	v.add_child(_label("★ " + Loc.t("ach.got", [Loc.t("ach.%s.name" % id)]), 16, COL_WARN, false, true))
	v.add_child(_label(Loc.t("ach.%s.text" % id), 13, COL_TEXT))
	ui.add_child(box)
	await get_tree().process_frame
	if not is_instance_valid(box):
		return
	var view := get_viewport().get_visible_rect().size
	box.position = Vector2((view.x - box.size.x) / 2.0, 96.0 + order * (box.size.y + 8.0))
	box.modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(order * 0.4)
	t.tween_property(box, "modulate:a", 1.0, 0.25)
	t.tween_interval(2.8)
	t.tween_property(box, "modulate:a", 0.0, 0.5)
	t.tween_callback(box.queue_free)


# ---------- the day's moments ----------

# The top bar takes the colour of the time of day: morning blue, brighter at midday, dusk in the evening.
func _sky() -> Color:
	match _moment():
		"midday":
			return Color("0c66e4")
		"evening":
			return Color("2d2a6e")
	return COL_TOPBAR


func _moment() -> String:
	if rules.phase in ["evening", "report", "review"] or (rules.endless() and rules.step == "evening"):
		return "evening"
	if rules.endless() and rules.step == "work":
		return "midday"
	return "morning"


# A big "Tuesday · Morning" across the screen as the day moves on; it fades by itself and stops nothing.
func _splash(text_value: String) -> void:
	var box := PanelContainer.new()
	var style := _flat(Color(COL_NIGHT, 0.82))
	style.set_corner_radius_all(18)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 60
	var l := _label(text_value, 34, COL_ON_TOP, false, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	ui.add_child(box)
	await get_tree().process_frame
	if not is_instance_valid(box):
		return
	var view := get_viewport().get_visible_rect().size
	box.position = (view - box.size) / 2.0 - Vector2(0, view.y * 0.12)
	box.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(box, "modulate:a", 1.0, 0.2)
	t.tween_interval(0.7)
	t.tween_property(box, "modulate:a", 0.0, 0.45)
	t.tween_callback(box.queue_free)


# ---------- feedback ----------

# What the player should see change: points left (borrowing counted), money, the race, who has which card.
func _juice_state() -> Dictionary:
	if not rules.phase in ["plan", "event", "standup", "evening", "report", "review"]:
		return {}
	var owners := {}
	var done := {}
	var moved := {}
	for t in rules.tasks:
		if t["status"] == "active":
			owners[t["uid"]] = t["owner"]
			moved[t["uid"]] = rules.shown_progress(t)
		elif t["status"] == "done":
			done[t["uid"]] = true
	return {"day": rules.day, "moment": _moment(), "phase": rules.phase, "points": rules.attention - rules.overtime_today, "money": rules.money,
		"race": int(round(rules.my_points())), "owners": owners, "done": done, "moved": moved}


# A card just handed to someone flashes blue; one that moved forward flashes light green, one finished
# since the last look flashes green.
func _cards_to_flash(was: Dictionary, now: Dictionary) -> Dictionary:
	var out := {}
	if was.is_empty() or now.is_empty():
		return out
	for uid in now["moved"]:
		if now["moved"][uid] > was.get("moved", {}).get(uid, INF) + 0.01:
			out[uid] = COL_GAIN
	for uid in now["owners"]:
		if was["owners"].get(uid, "") != now["owners"][uid]:
			out[uid] = COL_FOCUS
	for uid in now["done"]:
		if not was["done"].has(uid):
			out[uid] = COL_GOOD
	return out


# Numbers that changed float up off their counter and fade, and the counter blinks.
func _juice(was: Dictionary, now: Dictionary) -> void:
	if was.is_empty() or now.is_empty():
		return
	# (the Friday report says which day it is itself)
	if (was["moment"] != now["moment"] or was["day"] != now["day"]) and now["phase"] != "report":
		_splash(Loc.t(rules.day_key().substr(1)) + " · " + Loc.t("moment." + now["moment"]))
	# Layout settles a frame after the screen is built.
	await get_tree().process_frame
	# A new day refills the points: that's not something you spent.
	if was["day"] == now["day"]:
		_float_change("points", now["points"] - was["points"], "", true)
	var dc := Rules.cash(now["money"]) - Rules.cash(was["money"])
	_float_change("money", dc, " " + Loc.cash_word(dc), false)
	_float_change("race", now["race"] - was["race"], "", false)


func _float_change(node_name: String, delta: int, unit: String, cost: bool) -> void:
	var node: Control = juice_nodes.get(node_name)
	if delta == 0 or node == null or not is_instance_valid(node):
		return
	var good := delta > 0
	var tag := _label(("+%d" if good else "−%d") % absi(delta) + unit, 16, COL_ON_TOP_GOOD if good else COL_STAR, false, true)
	tag.z_index = 50
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(tag)
	var at := node.get_global_rect()
	tag.position = Vector2(at.position.x + at.size.x * (0.25 if cost else 0.5), at.position.y + at.size.y - 4)
	var t := create_tween().set_parallel()
	t.tween_property(tag, "position:y", tag.position.y + 26, 0.9).set_ease(Tween.EASE_OUT)
	t.tween_property(tag, "modulate:a", 0.0, 0.9).set_delay(0.35)
	t.chain().tween_callback(tag.queue_free)
	var blink := create_tween()
	blink.tween_property(node, "modulate", Color(1.6, 1.4, 0.8) if not good else Color(0.8, 1.6, 1.0), 0.12)
	blink.tween_property(node, "modulate", Color.WHITE, 0.35)


func _flash(card: Control, color: Color) -> void:
	if not is_instance_valid(card):
		return
	var t := create_tween()
	card.scale = Vector2(1.04, 1.04)
	card.pivot_offset = card.size / 2.0
	t.set_parallel()
	t.tween_property(card, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var glow := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if glow:
		var calm := glow.duplicate() as StyleBoxFlat
		glow.border_color = color
		glow.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", glow)
		t.chain().tween_interval(0.6)
		t.chain().tween_callback(func(): if is_instance_valid(card): card.add_theme_stylebox_override("panel", calm))


# Panels, buttons and rich text stop presses by default, so a finger that lands on them can't scroll
# the list they're in. Let presses through to the scroll container; a button whose press turns into
# a scroll cancels itself (Godot sends it NOTIFICATION_SCROLL_BEGIN).
func _let_touches_through(node: Node) -> void:
	for child in node.get_children():
		if (child is PanelContainer or child is BaseButton or child is RichTextLabel) and child.mouse_filter == Control.MOUSE_FILTER_STOP:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_let_touches_through(child)


# The chat holds a question you have to answer before anything else happens.
func _waiting_for_answer() -> bool:
	return _chat_asks() or not rules.pending.is_empty()


# A question only the chat can answer (a pushback over a task is answered in the task's window).
func _chat_asks() -> bool:
	return rules.phase == "event" or rules.phase == "review"




# The board can be looked through during the day, a question in the chat included.
func _looking() -> bool:
	return rules.phase in ["plan", "event", "review"]


# The key art fills the screen and darkens towards the bottom, where the menu sits straight on it.
# An upright phone sees a third of the picture, so the view looks round the room like the player would:
# Taras in the doorway and Gena, then Alex and Dima, then Irina and Vika, and slowly back. It never
# stops dead (a little drift while it rests on each pair), so it doesn't feel like a slideshow.
const KEY_ART := "res://art/key_art.png"
const PAN_STOPS := [0.17, 0.55, 0.83] # where each pair is, as a fraction of the picture's width
const PAN_REST := 5.0 # seconds on each pair
const PAN_MOVE := 3.5 # seconds between neighbours; the way back takes twice that
const PAN_DRIFT := 0.025
var pan_cut: AtlasTexture
var pan_time := 0.0
const COL_NIGHT := Color("0b1a33")


func _build_title() -> void:
	var art: Texture2D = load(KEY_ART) if ResourceLoader.exists(KEY_ART) else null
	if art == null:
		_build_title_plain()
		return
	var view := get_viewport().get_visible_rect().size
	var tex: Texture2D = art
	var w := art.get_height() * view.x / view.y
	pan_cut = null
	if w < art.get_width() * 0.8:
		pan_cut = AtlasTexture.new()
		pan_cut.atlas = art
		pan_cut.region = Rect2(0, 0, w, art.get_height())
		_pan_title(0.0)
		tex = pan_cut
	var pic := TextureRect.new()
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(pic)
	if mobile:
		ui.add_child(_title_fade([0.3, 0.55, 1.0], [0.0, 0.82, 0.97]))
	else:
		ui.add_child(_title_fade([0.35, 0.65, 1.0], [0.0, 0.8, 0.96]))
	var margin := 24.0 if mobile else 56.0
	var v := _vbox(14)
	v.custom_minimum_size.x = minf(440.0, view.x - margin * 2.0)
	v.anchor_top = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = margin
	v.offset_right = margin + v.custom_minimum_size.x
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.offset_top = -margin
	v.offset_bottom = -margin
	ui.add_child(v)
	# The logo is stuck on top of the menu, on the dark part of the picture, so it never covers a face.
	if menu_page == "":
		var sticker := _logo(96 if mobile else 84)
		sticker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(sticker)
	_menu_page(v, false)


# Where the view is pan_time seconds in: rest, move, rest, move, rest, then the long way back. The path is
# continuous: a rest drifts from where the view arrived to where it leaves, and at either end, where it
# turns round, it eases out a little and back. lo..hi is how far the view can go without hitting an edge.
func _pan_focus(t: float, lo: float, hi: float) -> float:
	var stops: Array = []
	for x in PAN_STOPS:
		stops.append(clampf(x, lo + PAN_DRIFT, hi - PAN_DRIFT))
	var n := stops.size()
	var loop := 0.0
	for i in n:
		loop += PAN_REST + PAN_MOVE * (2.0 if i == n - 1 else 1.0)
	t = fmod(t, loop)
	var half := PAN_DRIFT * 0.5
	for i in n:
		var here: float = stops[i]
		var dir_in := signf(here - stops[(i - 1 + n) % n])
		var dir_out := signf(stops[(i + 1) % n] - here)
		var u := t / PAN_REST
		if t < PAN_REST:
			if dir_in == dir_out:
				return here + dir_out * half * (2.0 * u - 1.0)
			return here - dir_out * half + dir_in * PAN_DRIFT * sin(PI * u) * 0.5
		t -= PAN_REST
		var move := PAN_MOVE * (2.0 if i == n - 1 else 1.0)
		if t < move:
			var next: float = stops[(i + 1) % n]
			var dir_next := signf(stops[(i + 2) % n] - next)
			var from := here + dir_out * half if dir_in == dir_out else here - dir_out * half
			# Passing through, it arrives just short of the pair; turning round there, just past it.
			var to := next - dir_out * half if dir_out == dir_next else next + dir_out * half
			return lerpf(from, to, smoothstep(0.0, 1.0, t / move))
		t -= move
	return stops[0]


func _pan_title(delta: float) -> void:
	if pan_cut == null:
		return
	pan_time += delta
	var full := float(pan_cut.atlas.get_width())
	var w := pan_cut.region.size.x
	var half := w / 2.0 / full
	pan_cut.region.position.x = clampf(full * _pan_focus(pan_time, half, 1.0 - half) - w / 2.0, 0.0, full - w)


# The menu itself, on the title screen or over the game: the list, or one of its pages.
func _menu_page(v: VBoxContainer, in_game: bool) -> void:
	match menu_page:
		"settings":
			_menu_settings(v)
		"about":
			v.add_child(_menu_title(Loc.t("menu.about")))
			v.add_child(_label(Loc.t("about.text"), 15 if mobile else 16, Color(1, 1, 1, 0.85), true))
			v.add_child(_spacer(2))
			v.add_child(_menu_item(Loc.t("menu.back"), _menu_go.bind("")))
		"confirm_new":
			v.add_child(_menu_title(Loc.t("menu.new")))
			v.add_child(_label(Loc.t("confirm.new"), 15 if mobile else 16, Color(1, 1, 1, 0.85), true))
			v.add_child(_spacer(2))
			v.add_child(_menu_item(Loc.t("confirm.yes"), _menu_new_confirmed, COL_ON_TOP_DANGER))
			v.add_child(_menu_item(Loc.t("confirm.no"), _menu_go.bind("")))
		_:
			if in_game:
				v.add_child(_menu_item(Loc.t("menu.resume"), _close_menu))
			elif Rules.has_save():
				v.add_child(_menu_item(Loc.t("menu.continue"), _continue_run))
			if not in_game:
				v.add_child(_menu_item(Loc.t("menu.new"), _menu_new_game.bind("endless")))
				if OS.is_debug_build():
					v.add_child(_menu_item(Loc.t("menu.story_dev"), _menu_new_game.bind("story")))
			v.add_child(_menu_item(Loc.t("menu.settings"), _menu_go.bind("settings")))
			v.add_child(_menu_item(Loc.t("menu.about"), _menu_go.bind("about")))
			if in_game:
				v.add_child(_menu_item(Loc.t("menu.to_title"), _menu_to_title))
			if _can_quit():
				v.add_child(_menu_item(Loc.t("menu.quit"), _quit))


func _menu_settings(v: VBoxContainer) -> void:
	v.add_child(_menu_title(Loc.t("menu.settings")))
	v.add_child(_menu_caption(Loc.t("settings.lang")))
	var langs := _flow(8, 8)
	v.add_child(langs)
	for l in ["ru", "en"]:
		langs.add_child(_button(Loc.t("lang_name." + l), _set_lang.bind(l), 120, "primary" if Loc.lang == l else "on_top"))
	v.add_child(_menu_caption(Loc.t("settings.volume")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = round(volume * 100)
	slider.custom_minimum_size = Vector2(240, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	var track := _box(Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.22), 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	track.set_corner_radius_all(3)
	var filled := _box(COL_PRIMARY_HOVER, COL_PRIMARY_HOVER, 0, 0)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	filled.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	row.add_child(slider)
	var pct := _label("%d%%" % int(slider.value), 15, COL_ON_TOP, false, true)
	pct.custom_minimum_size.x = 48
	row.add_child(pct)
	slider.value_changed.connect(func(x: float) -> void:
		volume = x / 100.0
		_apply_volume()
		pct.text = "%d%%" % int(x))
	slider.drag_ended.connect(func(_changed: bool) -> void:
		_save_setting("audio", "volume", volume)
		_play("click"))
	v.add_child(_menu_caption(Loc.t("settings.text")))
	var sizes := _flow(8, 8)
	v.add_child(sizes)
	for k in TEXT_SCALES:
		sizes.add_child(_button(Loc.t("settings.text." + k), _set_text_scale.bind(k), 0, "primary" if text_scale == k else "on_top"))
	v.add_child(_spacer(2))
	v.add_child(_menu_item(Loc.t("menu.back"), _menu_go.bind("")))


func _menu_title(text_value: String) -> Label:
	return _label(text_value, 24 if mobile else 28, COL_ON_TOP, false, true)


func _menu_caption(text_value: String) -> Label:
	return _label(text_value.to_upper(), 12, COL_ON_TOP_MUTED, false, true)


# A line of the menu: big text, no box; it turns orange under the pointer. One that throws something
# away is in red instead of white.
func _menu_item(text_value: String, action: Callable, color: Color = COL_ON_TOP) -> Button:
	var b := Button.new()
	b.text = text_value
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", _fs(22 if mobile else 24))
	for state in ["normal", "hover", "pressed", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_top = 4
		empty.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, empty)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", COL_STAR)
	b.add_theme_color_override("font_pressed_color", COL_STAR)
	b.pressed.connect(func(): cue = "click")
	b.pressed.connect(action)
	return b


# Over the game: the same menu on a dark card, the game dimmed behind it.
func _build_menu_overlay() -> void:
	var dim := ColorRect.new()
	dim.color = Color(COL_NIGHT, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center)
	var card := PanelContainer.new()
	var style := _box(COL_NIGHT, COL_NIGHT, 0, 28 if mobile else 36)
	style.set_corner_radius_all(16)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var v := _vbox(14)
	v.custom_minimum_size.x = minf(420.0, get_viewport().get_visible_rect().size.x - 88.0)
	card.add_child(v)
	_menu_page(v, true)


# A dark wash over the picture: stops are where it starts and how dark it gets (fractions of the height).
func _title_fade(at: Array, alpha: Array) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(at)
	var colors := PackedColorArray()
	for a in alpha:
		colors.append(Color(COL_NIGHT, a))
	g.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var wash := TextureRect.new()
	wash.texture = tex
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return wash


# Without the key art: the old card in the middle of the page.
func _build_title_plain() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_SURFACE, COL_BORDER, 1, 32))
	center.add_child(card)
	var v := _vbox(16)
	v.custom_minimum_size.x = mini(860, int(_view_width()) - 80)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(_logo(40))
	head.add_child(_label(Loc.t("title"), 34, COL_TEXT, false, true))
	v.add_child(_label(Loc.t("tagline"), 19, COL_MUTED, true))
	v.add_child(_spacer(4))
	var buttons := _flow(12, 12)
	v.add_child(buttons)
	if Rules.has_save():
		buttons.add_child(_button(Loc.t("continue"), _continue_run, 260, "primary"))
	buttons.add_child(_button(Loc.t("new_game"), _new_endless, 0))
	if OS.is_debug_build():
		buttons.add_child(_button(Loc.t("menu.story_dev"), _new_story, 0))


# Before a run: which Irina you get and who you were. Portraits, not letters: the letters come out at the end.
func _build_setup() -> void:
	var outer := _vbox(0)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(outer)
	var scroll := _scroll("setup")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var width := mini(960, int(_view_width()) - 32)
	var v := _vbox(14)
	v.custom_minimum_size.x = width
	center.add_child(_padded(v, 0, 24))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(_logo(32))
	head.add_child(_label(Loc.t("setup.title"), 26, COL_TEXT, false, true))
	v.add_child(_label(Loc.t("setup.boss_head"), 17, COL_TEXT, true, true))
	var bosses: Array = C.BOSS_KINDS.duplicate()
	bosses.append("random")
	v.add_child(_option_grid("boss", bosses, pick_boss, width))
	v.add_child(_spacer(6))
	v.add_child(_label(Loc.t("setup.me_head"), 17, COL_TEXT, true, true))
	var kinds: Array = C.RUN_PROFILE_KINDS if pick_mode == "endless" else C.PROFILE_KINDS
	if not kinds.has(pick_profile):
		pick_profile = C.DEFAULT_PROFILE
	v.add_child(_option_grid("me", kinds, pick_profile, width))
	v.add_child(_spacer(2))
	var tips_row := HBoxContainer.new()
	tips_row.add_theme_constant_override("separation", 12)
	v.add_child(tips_row)
	# Marina shows the new lead around for a month in the endless run, for the first week in the story.
	var tips_key := "setup.run_tips" if pick_mode == "endless" else "setup.tips"
	tips_row.add_child(_button(Loc.t(tips_key + ("_on" if pick_tips else "_off")), _toggle_tips, 0, "chosen" if pick_tips else ""))
	tips_row.add_child(_label(Loc.t(tips_key + "_hint"), 13, COL_MUTED, true))
	v.add_child(_spacer(6))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button(Loc.t("setup.start"), _start_run, 160 if mobile else 260, "primary"))
	buttons.add_child(_button(Loc.t("setup.back"), _open_setup.bind(false), 0))
	if mobile:
		# On a phone the start button stays in reach under the scrolling choices.
		var bar := PanelContainer.new()
		var style := _flat(COL_SURFACE)
		style.border_color = COL_BORDER
		style.border_width_top = 1
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 10
		style.content_margin_bottom = 12
		bar.add_theme_stylebox_override("panel", style)
		bar.add_child(buttons)
		outer.add_child(bar)
	else:
		v.add_child(buttons)


# Thousands of roubles, grouped: 1 500.
# Money as the player sees it: coonics, a tenth of the thousands the rules count in ("250 куников").
func _rub(n: int) -> String:
	return Loc.cash(Rules.cash(n))


func _money_text() -> String:
	return Loc.t("money.bar", [_rub(rules.money), Rules.cash(rules.payroll())])


func _money_color() -> Color:
	return COL_ON_TOP_DANGER if rules.weeks_left() < 2 else COL_ON_TOP


# Before the first day of an endless run: pick the team from the CVs Marina brought.
func _build_draft() -> void:
	var outer := _vbox(0)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(outer)
	var scroll := _scroll("draft")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var width := mini(960, int(_view_width()) - 32)
	var v := _vbox(14)
	v.custom_minimum_size.x = width
	center.add_child(_padded(v, 0, 24))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(_logo(32))
	head.add_child(_label(Loc.t("draft.title"), 26, COL_TEXT, false, true))
	v.add_child(_label(Loc.t("draft.hint", [_rub(rules.PERIOD_BUDGET)]), 15, COL_MUTED, true))
	var cols := 3 if width >= 760 else (2 if width >= 500 else 1)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for c in rules.candidates:
		grid.add_child(_draft_card(c["id"], (width - 12 * (cols - 1)) / float(cols)))
	var month := rules.draft_payroll()
	var sum := Loc.t("draft.sum", [rules.draft_picked.size(), _rub(month), _rub(rules.money), _rub(rules.PERIOD_BUDGET)])
	v.add_child(_label(sum, 16, COL_DANGER if month > rules.PERIOD_BUDGET else COL_TEXT, true, true))
	var buttons := _flow(12, 12)
	var go := _button(Loc.t("draft.start"), _draft_start, 160 if mobile else 260, "primary")
	go.disabled = rules.draft_picked.is_empty()
	buttons.add_child(go)
	var again := _button(Loc.t("draft.reroll", [_rub(rules.DRAFT_REROLL)]), _draft_reroll, 0)
	again.disabled = rules.money < rules.DRAFT_REROLL
	buttons.add_child(again)
	if mobile:
		var bar := PanelContainer.new()
		var style := _flat(COL_SURFACE)
		style.border_color = COL_BORDER
		style.border_width_top = 1
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 10
		style.content_margin_bottom = 12
		bar.add_theme_stylebox_override("panel", style)
		bar.add_child(buttons)
		outer.add_child(bar)
	else:
		v.add_child(buttons)


func _draft_card(id: String, w: float) -> Control:
	var on: bool = rules.draft_picked.has(id)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = w
	card.add_theme_stylebox_override("panel", _box(COL_SELECTED if on else COL_SURFACE, COL_PRIMARY if on else COL_BORDER, 2 if on else 1, 14))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := _vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(_avatar(id, 32))
	var names := _vbox(0)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(_label(Loc.person(id), 16, COL_PRIMARY if on else COL_TEXT, false, true))
	names.add_child(_label(Loc.t("money.asks", [_rub(rules.salary(id))]), 13, COL_MUTED))
	var skills := _flow(4, 4)
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(skills)
	for cat in C.CATEGORIES:
		var colors: Array = CAT_COLORS[cat]
		skills.add_child(_pill("%s: %s" % [Loc.t("cat." + cat), Loc.t("level.%d" % rules.cv_level(id, cat))], colors[0], colors[1], _cat_icon(cat)))
	v.add_child(_label(Loc.t("draft.picked" if on else "draft.pick"), 13, COL_PRIMARY if on else COL_FAINT))
	card.gui_input.connect(_on_draft_input.bind(id))
	return card


func _on_draft_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_play("select")
		rules.draft_toggle(id)
		_render()


func _draft_reroll() -> void:
	rules.draft_reroll()
	_render()


func _draft_start() -> void:
	rules.draft_start()
	_clear_selection()
	_render()


func _option_grid(kind: String, values: Array, chosen: String, width: int) -> Control:
	var cols := 3 if width >= 700 else 1
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for value in values:
		var on: bool = value == chosen
		var card := PanelContainer.new()
		card.custom_minimum_size.x = (width - 12 * (cols - 1)) / float(cols)
		card.size_flags_vertical = Control.SIZE_FILL
		card.add_theme_stylebox_override("panel", _box(COL_SELECTED if on else COL_SURFACE, COL_PRIMARY if on else COL_BORDER, 2 if on else 1, 14))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var key := "setup.%s.%s" % [kind, value]
		var text := _vbox(4)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(_label(Loc.t(key), 16, COL_PRIMARY if on else COL_TEXT, true, true))
		text.add_child(_label(Loc.t(key + ".desc"), 14, COL_MUTED, true))
		card.add_child(text)
		card.gui_input.connect(_on_option_input.bind("boss" if kind == "boss" else "profile", value))
		grid.add_child(card)
	return grid


func _on_option_input(event: InputEvent, kind: String, value: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_pos = event.global_position
		elif event.global_position.distance_to(press_pos) < 12.0:
			cue = "select"
			_pick_option.call_deferred(kind, value)


func _build_office() -> void:
	var v := _vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(v)
	v.add_child(_top_bar())
	v.add_child(_nav_strip())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	v.add_child(body)
	body.add_child(_board_area())
	body.add_child(_messenger())


func _top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size.y = TOP_H
	var style := _box(_sky(), _sky(), 0, 0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 16
	style.content_margin_right = 12
	bar.add_theme_stylebox_override("panel", style)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14 if rules.endless() else 18)
	bar.add_child(top)
	top.add_child(_logo(26))
	top.add_child(_label(Loc.t("title"), 18, COL_ON_TOP, false, true))
	top.add_child(_label(_day_label(), 15, COL_ON_TOP_MUTED))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var points := _attention_label(15)
	juice_nodes["points"] = points
	top.add_child(points)
	if rules.endless():
		var money := _label(_money_text(), 15, _money_color())
		juice_nodes["money"] = money
		top.add_child(money)
		var race := _race_label(15)
		juice_nodes["race"] = race
		top.add_child(race)
	else:
		var k := rules.key_status()
		top.add_child(_label(Loc.render("keys_label", [], {"good": k["good"], "total": rules.chapter_keys().size()}), 15, COL_ON_TOP))
	# How Irina sees you sits on her button under the bar, where there's room for it.
	top.add_child(_button(Loc.t("menu.button"), _open_menu, 0, "on_top"))
	return bar


# "Понедельник, неделя 2", and from chapter two on, which chapter.
func _day_label() -> String:
	var text := Loc.t(rules.day_key().substr(1))
	if rules.endless():
		return Loc.t("period_short", [rules.period]) + text
	return text if rules.chapter == 1 else Loc.t("chapter_short", [rules.chapter]) + text


# The logo is a sticky note with Team1337 on it in marker (art/logo.png); without it, an orange square.
const LOGO := "res://art/logo.png"


func _logo(size: int) -> Control:
	if ResourceLoader.exists(LOGO):
		var pic := TextureRect.new()
		pic.texture = load(LOGO)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(size, size) * 1.2
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return pic
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


func _attention_label(size: int) -> Label:
	var l := _label(_attention_text(), size, COL_ON_TOP if rules.overtime_today == 0 else COL_ON_TOP_DANGER)
	l.tooltip_text = Loc.t("attention_tip")
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _attention_text() -> String:
	if rules.sick_today:
		return Loc.t("you.sick_today")
	var dots := ""
	for i in rules.max_attention():
		dots += "●" if i < rules.attention else "○"
	var text := Loc.render("attention_label", [], {"dots": dots, "state": "@me." + rules.my_state()})
	if rules.overtime_today > 0:
		text += " " + Loc.render("overtime_label", [], {"n": rules.overtime_today, "cap": rules.borrow_cap()})
	return text


func _cost_mark(n: int = 1) -> String:
	if n <= 0:
		return ""
	if rules.attention >= n:
		return " " + "●".repeat(n)
	return " " + Loc.t("cost_overtime")


# ---------- the team ----------

func _team_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 0 if mobile else SIDEBAR_W
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if mobile else Control.SIZE_FILL
	var style := _flat(COL_SURFACE)
	style.border_color = COL_BORDER
	style.border_width_right = 1
	panel.add_theme_stylebox_override("panel", style)
	var scroll := _scroll("team")
	panel.add_child(scroll)
	var v := _vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(v, 12, 12))
	v.add_child(_me_card())
	v.add_child(_section(Loc.t("team_header")))
	var gone := PackedStringArray()
	for p in rules.team:
		if rules.people[p]["gone"]:
			gone.append(Loc.person(p))
		else:
			v.add_child(_person_card(p))
	if not gone.is_empty():
		v.add_child(_label(Loc.t("gone_list", [", ".join(gone)]), 12, COL_FAINT, true))
	if rules.openings > 0 or not rules.candidates.is_empty():
		v.add_child(_spacer(4))
		# (in the endless run there are no openings: candidates come anyway, and a hire costs money)
		v.add_child(_section(Loc.t("hire.section") + " · " + (Loc.t("money.fee", [_rub(rules.HIRE_FEE)]) if rules.endless() else Loc.t("hire.openings_left", [rules.openings]))))
		for c in rules.candidates:
			v.add_child(_candidate_card(c))
	if rules.endless():
		v.add_child(_spacer(4))
		v.add_child(_section(Loc.t("up.section")))
		v.add_child(_upgrades_card())
	v.add_child(_spacer(4))
	v.add_child(_section(Loc.t("boss_header")))
	v.add_child(_boss_card())
	v.add_child(_spacer(4))
	v.add_child(_section(Loc.t("chainer_header")))
	v.add_child(_chainer_card())
	if mobile:
		v.add_child(_spacer(4))
		var menu := _button(Loc.t("menu.button"), _open_menu, 0)
		menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(menu)
	return panel


# You against Taras this month, in the top bar; what it means is in the tooltip.
func _race_label(size: int) -> Label:
	var mine := int(round(rules.my_points()))
	var his := int(round(rules.taras_total()))
	var l := _label(Loc.t("race.label", [mine, his]), size, COL_ON_TOP if mine >= his else COL_ON_TOP_DANGER)
	l.tooltip_text = Loc.t("race.hint")
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


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
	if rules.day - st["joined"] < rules.NEWBIE_DAYS:
		state.add_child(_pill(Loc.t("newbie_label"), COL_PRIMARY, COL_SELECTED))
	var late := rules.late_hours(p) if rules.phase == "plan" else 0
	if late > 0:
		state.add_child(_pill(Loc.render("late_preview", [], {"n": late}), COL_WARN, Color("fff0b3")))
	var mood := rules.mood_word(p)
	state.add_child(_label(Loc.t("mood." + mood), 13, MOOD_COLORS[mood]))
	var energy := rules.energy_word(p)
	state.add_child(_label("· " + Loc.t("energy." + energy), 13, ENERGY_COLORS[energy]))
	var trust := _trust_word(p)
	if trust != "":
		state.add_child(_label("· " + Loc.t("trust." + trust), 13, COL_GOOD if trust == "trusts" else COL_DANGER))
	if rules.endless():
		v.add_child(_label(Loc.t("money.salary", [_rub(rules.salary(p))]), 12, COL_MUTED, true))
	var known: Dictionary = st["known"]
	var drive_text: String = Loc.t("drive." + rules.info(p)["drive"]) if known.has("drive") else Loc.t("unknown")
	v.add_child(_label(Loc.t("known.drive", [drive_text]), 12, COL_MUTED, true))
	var skills := _flow(4, 4)
	v.add_child(skills)
	for cat in C.CATEGORIES:
		var is_known: bool = known.has("skill." + cat)
		var level: String = Loc.t("level.%d" % st["skills"][cat]) if is_known else Loc.t("unknown")
		var colors: Array = CAT_COLORS[cat]
		skills.add_child(_pill("%s: %s" % [Loc.t("cat." + cat), level], colors[0] if is_known else COL_FAINT, colors[1] if is_known else COL_BG, _cat_icon(cat)))
	for t in rules.tasks:
		if t["status"] == "active" and t["helper"] == p:
			v.add_child(_label(Loc.t("helper_badge", ["«%s»" % Loc.t("taskname." + t["id"])]), 12, COL_MUTED, true))
	if rules.warned(p):
		state.add_child(_pill(Loc.t("fire.decide_label" if rules.fire_ready(p) else "fire.warned_label"), COL_DANGER, Color("ffebe6")))
	var talk := _button(Loc.t("talk_button") + _cost_mark(rules.cost("talk")), _talk_to.bind(p), 0, "subtle")
	talk.disabled = talk.disabled or not rules.can_talk(p)
	talk.custom_minimum_size.y = 30
	if talk.disabled == false:
		_lit(talk, "talk")
	if rules.chapter >= 2 or rules.endless():
		var fire := _button(Loc.t("fire.button"), _fire.bind(p), 0, "subtle")
		fire.disabled = fire.disabled or not rules.can_fire(p)
		fire.custom_minimum_size.y = 26
		fire.add_theme_font_size_override("font_size", _fs(12))
		fire.add_theme_color_override("font_color", COL_DANGER)
		v.add_child(talk)
		v.add_child(fire)
	else:
		v.add_child(talk)
	return card


# You know your own strengths; they matter when you do the work or step into someone's.
func _me_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_BG, COL_BORDER, 1, 10))
	var v := _vbox(6)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	head.add_child(_avatar("me", 32))
	var names := _vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(_label(Loc.t("me_card"), 15, COL_TEXT, false, true))
	names.add_child(_label(Loc.t("me_profile." + rules.profile), 12, COL_MUTED))
	var skills := _flow(4, 4)
	v.add_child(skills)
	for cat in C.CATEGORIES:
		var colors: Array = CAT_COLORS[cat]
		skills.add_child(_pill("%s: %s" % [Loc.t("cat." + cat), Loc.t("level.%d" % rules.my_skill(cat))], colors[0], colors[1], _cat_icon(cat)))
	return card


# A CV from Marina: what they claim (or what an interview showed), how long they'll wait, and what to do.
func _candidate_card(c: Dictionary) -> Control:
	var id: String = c["id"]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_BG, COL_BORDER, 1, 10))
	var v := _vbox(5)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	head.add_child(_avatar(id, 28))
	var names := _vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(_label(Loc.person(id), 15, COL_TEXT, false, true))
	names.add_child(_label(Loc.t("hire.waits", [maxi(0, c["until"] - rules.day + 1)]), 12, COL_MUTED))
	if rules.endless():
		v.add_child(_label(Loc.t("money.asks", [_rub(rules.salary(id))]), 13, COL_TEXT))
	var skills := _flow(4, 4)
	v.add_child(skills)
	for cat in C.CATEGORIES:
		var seen: bool = c["known"].has(cat)
		var colors: Array = CAT_COLORS[cat]
		var text := "%s: %s" % [Loc.t("cat." + cat), Loc.t("level.%d" % rules.cv_level(id, cat))]
		skills.add_child(_pill(text + (" ✓" if seen else ""), colors[0], colors[1], _cat_icon(cat)))
	v.add_child(_label(Loc.t("hire.cv_short") + (" · ✓ " + Loc.t("hire.seen_short") if not c["known"].is_empty() else ""), 11, COL_FAINT))
	var row := _flow(6, 6)
	v.add_child(row)
	if c.get("drive_known", false):
		v.add_child(_label(Loc.t("known.drive", [Loc.t("drive." + rules.info(id)["drive"])]), 12, COL_MUTED, true))
	if c.get("hates_known", false):
		v.add_child(_label(Loc.t("hire.hates", [Loc.t("cat." + rules.info(id)["hates"][0])]), 12, COL_MUTED, true))
	if c.get("sittings", 0) < rules.INTERVIEW_SITTINGS and not rules.interview_topics(id).is_empty():
		var again: bool = c.get("sittings", 0) > 0
		var ask := _button(Loc.t("hire.again_btn" if again else "hire.interview_btn") + _cost_mark(rules.cost("interview")), _interview.bind(id), 0, "subtle")
		ask.disabled = ask.disabled or not rules.can_interview(id)
		row.add_child(ask)
	else:
		row.add_child(_label(Loc.t("hire.asked_all"), 12, COL_MUTED))
	var take := _button(Loc.t("hire.hire_btn"), _hire.bind(id), 0, "primary")
	take.disabled = take.disabled or not rules.can_hire(id)
	row.add_child(take)
	row.add_child(_button(Loc.t("hire.reject_btn"), _reject_candidate.bind(id), 0, "subtle"))
	return card


func _fire(p: String) -> void:
	window = ""
	rules.start_fire(p)
	_render()


func _interview(id: String) -> void:
	window = ""
	rules.interview(id)
	_render()


func _hire(id: String) -> void:
	rules.hire(id)
	_render()


func _reject_candidate(id: String) -> void:
	rules.reject_candidate(id)
	_render()


# ---------- windows over the board ----------

# What's needed now and then lives in windows, so the screen holds only the team, the board and the chat.
func _open_window(name: String) -> void:
	window = name
	_render()


func _close_window() -> void:
	if not rules.pending.is_empty():
		return
	# A single upgrade's card goes back to the tree.
	window = "upgrades" if window.begins_with("upgrade:") else ""
	if selected >= 0:
		selected = -1
		deal_from = -1
	_render()


func _build_window() -> void:
	if window == "upgrades" or window.begins_with("upgrade:"):
		if not rules.endless():
			return
		# One upgrade's card opens over the tree, which stays underneath.
		_build_upgrades()
		if window != "upgrades" and C.UPGRADES.has(window.substr(8)):
			_upgrade_window(window.substr(8))
		return
	var view := get_viewport().get_visible_rect().size
	if window == "task":
		var t := rules.task(selected)
		if t.is_empty() or (t["status"] not in ["inbox", "active"] and deal_from < 0):
			window = ""
			selected = -1
			return
		_task_window(_modal(Loc.t("taskname." + t["id"]), "", minf(820.0, view.x - 16.0), true, true), t)
		return
	if window.begins_with("person:"):
		var p := window.substr(7)
		if not rules.people.has(p):
			window = ""
			return
		_modal(Loc.person(p), "", minf(460.0, view.x - 16.0), false, true).add_child(_person_card(p))
	elif window == "hire":
		var hint := Loc.t("money.fee", [_rub(rules.HIRE_FEE)]) if rules.endless() else Loc.t("hire.openings_left", [rules.openings])
		var body := _modal(Loc.t("hire.section"), hint + "   " + _money_text() + "   " + _attention_text(), minf(980.0, view.x - 16.0), true, true)
		if rules.candidates.is_empty():
			body.add_child(_label(Loc.t("win.no_candidates"), 14, COL_MUTED, true))
		var grid := GridContainer.new()
		grid.columns = 1 if mobile else 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(grid)
		for c in rules.candidates:
			var card := _candidate_card(c)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(card)
	elif window == "boss":
		_modal(Loc.person("boss"), _attention_text(), minf(460.0, view.x - 16.0), false, true).add_child(_boss_card())
	elif window == "company":
		_modal(Loc.t("nav.clients_title"), "", minf(560.0, view.x - 16.0), false, true).add_child(_chainer_card())
	elif window == "more":
		var body := _modal(Loc.t("tab.more"), "", minf(460.0, view.x - 16.0), false, true)
		var waiting := rules.candidates.size()
		if rules.endless() or rules.openings > 0 or waiting > 0:
			body.add_child(_more_row(_nav_button("hire", Loc.t("hire.section"), _badge(waiting), COL_DANGER)))
		if rules.endless():
			body.add_child(_more_row(_nav_button("upgrades", Loc.t("up.section"), _badge(_fresh_upgrades()), COL_DANGER)))
		var unhappy := 0
		for bank in rules.banks:
			if rules.bank_word(bank) in ["unhappy", "leaving"]:
				unhappy += 1
		body.add_child(_more_row(_nav_button("clients", Loc.t("nav.clients"), _badge(unhappy), COL_DANGER)))
		var me := _button(Loc.t("me_card"), _open_window.bind("me"), 0, "subtle")
		me.alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(_more_row(me))
	elif window == "me":
		_modal(Loc.t("me_card"), "", minf(460.0, view.x - 16.0), false, true).add_child(_me_card())
	elif window == "done":
		var body := _modal(Loc.t("col.done"), "", minf(760.0, view.x - 16.0), true, true)
		var grid := GridContainer.new()
		grid.columns = 1 if mobile else 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(grid)
		for t in _lanes()["done"]:
			grid.add_child(_task_card(t, "done"))


# A dimmed screen and a panel with a title, a line under it and a close button; returns where the content goes.
func _modal(title: String, hint: String, w: float, wide_scroll: bool, fit: bool = false) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.118, 0.259, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and not event.pressed:
			_close_window.call_deferred())
	ui.add_child(dim)
	var view := get_viewport().get_visible_rect().size
	# Small windows (fit) grow to what's in them, up to the screen; big ones take the screen.
	var h := view.y - (16.0 if mobile else 64.0)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -w / 2.0
	panel.offset_right = w / 2.0
	panel.offset_top = -h / 2.0
	panel.offset_bottom = h / 2.0
	var style := _box(COL_SURFACE, COL_BORDER, 1, 0)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var right := _vbox(0)
	panel.add_child(right)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var titles := _vbox(4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_label(title, 22, COL_TEXT, true, true))
	if hint != "":
		titles.add_child(_label(hint, 13, COL_MUTED, true))
	head.add_child(titles)
	var close := _button(Loc.t("up.close"), _close_window, 0, "subtle")
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.visible = rules.pending.is_empty()
	head.add_child(close)
	var head_box := _padded(head, 18 if mobile else 28, 16)
	head_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(head_box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if wide_scroll or mobile else ScrollContainer.SCROLL_MODE_AUTO
	right.add_child(scroll)
	# A window opened over another keeps its own scroll, so the one below stays where it was.
	scrolls["window_top" if scrolls.has("window") else "window"] = scroll
	var body := _vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := _padded(body, 18 if mobile else 28, 4)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	right.add_child(_spacer(12))
	if fit:
		# Once laid out, shrink the panel around its content, keeping it centred.
		var shrink := func():
			if not is_instance_valid(panel):
				return
			var want := head_box.get_combined_minimum_size().y + pad.get_combined_minimum_size().y + 12.0
			var ph := minf(h, want)
			panel.offset_top = -ph / 2.0
			panel.offset_bottom = ph / 2.0
		pad.minimum_size_changed.connect(shrink)
		shrink.call_deferred()
	return body


# Under the top bar: the way into hiring, upgrades, the clients and Irina, with a counter when something waits.
func _nav_strip() -> Control:
	var bar := PanelContainer.new()
	var style := _box(COL_SURFACE, COL_BORDER, 0, 0)
	style.set_corner_radius_all(0)
	style.border_width_bottom = 1
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	# A counter means there's something to do in there, and only then: CVs waiting, upgrades you can
	# afford, clients who are unhappy.
	var waiting := rules.candidates.size()
	if rules.endless() or rules.openings > 0 or waiting > 0:
		row.add_child(_nav_button("hire", Loc.t("hire.section"), _badge(waiting), COL_DANGER))
	if rules.endless():
		var b := _nav_button("upgrades", Loc.t("up.section"), _badge(_fresh_upgrades()), COL_DANGER)
		_lit(b, "upgrades")
		row.add_child(b)
	var unhappy := 0
	for bank in rules.banks:
		if rules.bank_word(bank) in ["unhappy", "leaving"]:
			unhappy += 1
	row.add_child(_nav_button("clients", Loc.t("nav.clients"), _badge(unhappy), COL_DANGER))
	row.add_child(_boss_button())
	return bar


# Upgrades that came within reach since you last looked at the tree; what you could already afford
# when the session began isn't news.
func _fresh_upgrades() -> int:
	if not rules.endless():
		return 0
	if upgrades_seen.is_empty():
		for id in C.UPGRADES:
			if _upgrade_affordable(id):
				upgrades_seen[id] = true
	var n := 0
	for id in C.UPGRADES:
		if _upgrade_affordable(id) and not upgrades_seen.has(id):
			n += 1
	return n


func _upgrade_affordable(id: String) -> bool:
	return rules.upgrade_state(id) == "open" and rules.money >= rules.upgrade_price(id)


func _more_row(b: Control) -> Control:
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 44
	return b


func _badge(n: int) -> String:
	return str(n) if n > 0 else ""


func _nav_button(name: String, text_value: String, badge: String, badge_color: Color) -> Control:
	var b := _button(text_value, _open_upgrades if name == "upgrades" else _open_window.bind("company" if name == "clients" else name), 0, "subtle")
	b.add_theme_font_size_override("font_size", _fs(14))
	b.custom_minimum_size.y = 34
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var path := ICON_DIR + "nav_" + name + ".svg"
	if ResourceLoader.exists(path):
		b.icon = load(path)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 18)
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(state, COL_MUTED)
		b.add_theme_constant_override("h_separation", 8)
	if badge == "":
		return b
	# A round counter hanging off the button's top right corner, as in games.
	var dot := PanelContainer.new()
	var ds := _flat(badge_color)
	ds.set_corner_radius_all(10)
	ds.content_margin_left = 6
	ds.content_margin_right = 6
	ds.content_margin_top = 0
	ds.content_margin_bottom = 0
	dot.add_theme_stylebox_override("panel", ds)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_child(_label(badge, 11, COL_ON_TOP, false, true))
	dot.anchor_left = 1.0
	dot.anchor_right = 1.0
	dot.offset_left = -14
	dot.offset_top = -8
	dot.grow_horizontal = Control.GROW_DIRECTION_END
	b.add_child(dot)
	return b


# Irina's door: her face and how she sees you; point at it and it says you can go in, and a click does.
func _boss_button() -> Control:
	var can_go: bool = rules.can_visit()
	var word := rules.boss_word()
	var resting := Loc.t("boss_label", ["@weight." + word])
	var hover := Loc.t("visit_short") + _cost_mark(rules.cost("boss")) if can_go else Loc.t("nav.boss_seen" if rules.visited_today else "nav.boss_later")
	var card := PanelContainer.new()
	var normal := _box(COL_BG, COL_BORDER, 1, 0)
	normal.content_margin_left = 6
	normal.content_margin_right = 12
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	var lit := normal.duplicate()
	lit.bg_color = COL_SELECTED
	lit.border_color = COL_FOCUS
	card.add_theme_stylebox_override("panel", normal)
	card.custom_minimum_size.y = 34
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(_avatar("boss", 26))
	var text := _label(resting, 14, {"w3": COL_GOOD, "w2": COL_GOOD, "w1": COL_TEXT, "w0": COL_DANGER}[word])
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# As wide as the longer of the two texts, or the card shrinks from under the cursor and flickers.
	var font := text.get_theme_font("font")
	var fs := text.get_theme_font_size("font_size")
	text.custom_minimum_size.x = ceilf(maxf(font.get_string_size(resting, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, font.get_string_size(hover, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x))
	row.add_child(text)
	card.mouse_entered.connect(func():
		text.text = hover
		card.add_theme_stylebox_override("panel", lit))
	card.mouse_exited.connect(func():
		text.text = resting
		card.add_theme_stylebox_override("panel", normal))
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			# In the story, once you may ask her for people, her card has two things to do: open it.
			if rules.flags.has("asked_people") and rules.openings == 0:
				_open_window.call_deferred("boss")
			elif can_go:
				_visit_boss.call_deferred())
	return card


# The left column on a desktop: you, then the team, one line each; a click opens the whole card.
func _team_strip() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = SIDEBAR_W
	var style := _flat(COL_SURFACE)
	style.border_color = COL_BORDER
	style.border_width_right = 1
	panel.add_theme_stylebox_override("panel", style)
	var scroll := _scroll("team")
	panel.add_child(scroll)
	var v := _vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(v, 10, 12))
	v.add_child(_me_card())
	v.add_child(_section(Loc.t("team_header")))
	var gone := PackedStringArray()
	for p in rules.team:
		if rules.people[p]["gone"]:
			gone.append(Loc.person(p))
		else:
			v.add_child(_person_row(p))
	if not gone.is_empty():
		v.add_child(_label(Loc.t("gone_list", [", ".join(gone)]), 12, COL_FAINT, true))
	return panel


func _person_row(p: String) -> Control:
	var st: Dictionary = rules.people[p]
	var card := PanelContainer.new()
	var target: bool = rules.pending.get("p", "") == p
	card.add_theme_stylebox_override("panel", _box(COL_SELECTED if target else COL_SURFACE, COL_FOCUS if target else COL_BORDER, 2 if target else 1, 8))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_open_window.call_deferred("person:" + p))
	_lit(card, "talk")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(_avatar(p, 32))
	var v := _vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(_label(Loc.person(p), 14, COL_TEXT, false, true))
	if rules.queue_of(p).size() >= rules.OVERLOAD_AT:
		top.add_child(_label(Loc.t("row.overload"), 12, COL_WARN))
	var line := _flow(4, 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	if st["absent"]:
		line.add_child(_label(Loc.t("absent.%s_label" % st["absent_reason"]), 12, COL_WARN))
	else:
		var mood := rules.mood_word(p)
		line.add_child(_label(Loc.t("mood." + mood), 12, MOOD_COLORS[mood]))
		var energy := rules.energy_word(p)
		line.add_child(_label("· " + Loc.t("energy." + energy), 12, ENERGY_COLORS[energy]))
	if rules.day - st["joined"] < rules.NEWBIE_DAYS:
		line.add_child(_label("· " + Loc.t("newbie_label"), 12, COL_PRIMARY))
	if rules.warned(p):
		line.add_child(_label("· " + Loc.t("fire.warned_label"), 12, COL_DANGER))
	return card


# ---------- the upgrade tree ----------

# The sidebar's short view: what's being rolled out, and the way into the tree.
func _upgrades_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_SURFACE, COL_BORDER, 1, 10))
	var v := _vbox(4)
	card.add_child(v)
	var building := 0
	for id in C.UPGRADES:
		if rules.upgrade_state(id) == "building":
			building += 1
			v.add_child(_label(Loc.t("up.building_line", [Loc.t("up.%s.name" % id), rules.upgrade_done_count(id), C.UPGRADES[id]["cards"].size()]), 13, COL_TEXT, true))
	if building == 0:
		v.add_child(_label(Loc.t("up.none"), 13, COL_MUTED, true))
	var b := _button(Loc.t("up.button"), _open_upgrades, 0, "subtle")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_lit(b, "upgrades")
	v.add_child(b)
	return card


func _open_upgrades() -> void:
	rules._tip_used("upgrades")
	for id in C.UPGRADES:
		if _upgrade_affordable(id):
			upgrades_seen[id] = true
	_open_window("upgrades")


func _close_upgrades() -> void:
	_close_window()


func _buy_upgrade(id: String) -> void:
	rules.buy_upgrade(id)
	window = "upgrades"
	_render()


func _build_upgrades() -> void:
	var view := get_viewport().get_visible_rect().size
	var w := view.x - (16.0 if mobile else 64.0)
	var body := _modal(Loc.t("up.title"), Loc.t("up.hint") + "   " + _money_text() + "   " + _attention_text(), w, mobile)
	var ids: Array = C.UPGRADES.keys()
	if mobile:
		if not C.UPGRADE_BRANCHES.has(up_branch):
			up_branch = C.UPGRADE_BRANCHES[0]
		var tabs := _flow(4, 4)
		body.add_child(tabs)
		for branch in C.UPGRADE_BRANCHES:
			var b := _button(Loc.t("up.branch." + branch), _pick_branch.bind(branch), 0, "chosen" if up_branch == branch else "subtle")
			tabs.add_child(b)
		ids = ids.filter(func(id): return C.UPGRADES[id]["branch"] == up_branch)
	body.add_child(_cork_board(ids, w - (40.0 if mobile else 80.0)))


func _pick_branch(branch: String) -> void:
	up_branch = branch
	_render()


# How deep in the tree an upgrade sits: 0 for one you can start with, one more than its deepest requirement.
func _up_tier(id: String, memo: Dictionary = {}) -> int:
	if memo.has(id):
		return memo[id]
	var t := 0
	for r in C.UPGRADES[id]["requires"]:
		t = maxi(t, _up_tier(r, memo) + 1)
	memo[id] = t
	return t


# Siblings sorted to sit near what they hang from (axis 0: across, 1: down), so threads cross less.
func _by_parents(ids: Array, places: Dictionary, axis: int) -> Array:
	var key := {}
	for id in ids:
		var sum := 0.0
		var n := 0
		for r in C.UPGRADES[id]["requires"]:
			if places.has(r):
				sum += places[r].get_center()[axis]
				n += 1
		key[id] = (sum / n if n > 0 else 1e6) + C.UPGRADES[id]["order"] * 0.001
	var out := ids.duplicate()
	out.sort_custom(func(a, b): return key[a] < key[b])
	return out


# The tree as stickers pinned to a cork board, tied with threads to what they need: green once that's
# done, red while it isn't. On a computer each branch is a strip, the tree grows left to right; on the
# phone it's one branch, growing downwards.
func _cork_board(ids: Array, width: float) -> Control:
	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", _box(COL_CORK, COL_CORK_LINE, 1, 0))
	var canvas := Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	board.add_child(canvas)
	var places := {}
	var tiers := {}
	for id in ids:
		tiers[id] = _up_tier(id)
	var size := Vector2.ZERO
	if mobile:
		var gap := 14.0
		var sw := floorf((width - gap * 3.0) / 2.0)
		var sh := 128.0
		var y := gap
		for tier in range(0, 6):
			# Each sticker goes under the column its requirement is in, then the two columns are evened out.
			var cols := [[], []]
			for id in _by_parents(ids.filter(func(id): return tiers[id] == tier), places, 0):
				var side := 0
				for r in C.UPGRADES[id]["requires"]:
					if places.has(r) and places[r].position.x > gap:
						side = 1
				cols[side].append(id)
			while absi(cols[0].size() - cols[1].size()) > 1:
				var big: int = 0 if cols[0].size() > cols[1].size() else 1
				cols[1 - big].append(cols[big].pop_back())
			for c in 2:
				for i in cols[c].size():
					places[cols[c][i]] = Rect2(gap + c * (sw + gap), y + i * (sh + gap * 2.0), sw, sh)
			var rows := maxi(cols[0].size(), cols[1].size())
			y += rows * (sh + gap * 2.0)
		size = Vector2(width, y)
	else:
		var label_w := 170.0
		var col_gap := 56.0
		var sw := clampf(floorf((width - label_w - 3.0 * col_gap - 12.0) / 4.0), 180.0, 240.0)
		var sh := 112.0
		var row_gap := 18.0
		var y := 0.0
		for branch in C.UPGRADE_BRANCHES:
			var mine: Array = ids.filter(func(id): return C.UPGRADES[id]["branch"] == branch)
			var stack := 1
			for tier in range(0, 6):
				var cell: Array = _by_parents(mine.filter(func(id): return tiers[id] == tier), places, 1)
				stack = maxi(stack, cell.size())
				for i in cell.size():
					places[cell[i]] = Rect2(label_w + tier * (sw + col_gap), y + row_gap + i * (sh + row_gap), sw, sh)
			var lane_h := row_gap + stack * (sh + row_gap)
			var head := _label(Loc.t("up.branch." + branch).to_upper(), 13, COL_CORK_TEXT, true, true)
			head.position = Vector2(16, y + row_gap)
			head.size = Vector2(label_w - 20, 40)
			canvas.add_child(head)
			if y > 0.0:
				var line := ColorRect.new()
				line.color = COL_CORK_LINE
				line.position = Vector2(0, y)
				line.size = Vector2(maxf(width, label_w + 4.0 * sw + 3.0 * col_gap + 12.0), 1)
				line.mouse_filter = Control.MOUSE_FILTER_IGNORE
				canvas.add_child(line)
			y += lane_h
		size = Vector2(maxf(width, label_w + 4.0 * sw + 3.0 * col_gap + 12.0), y)
	canvas.custom_minimum_size = size
	# Threads run under the stickers so the text stays readable; the pins sit on top.
	var threads := Control.new()
	threads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	threads.custom_minimum_size = size
	canvas.add_child(threads)
	for id in places:
		var sticker := _sticker(id, places[id].size)
		sticker.position = places[id].position
		canvas.add_child(sticker)
	var pins := Control.new()
	pins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pins.custom_minimum_size = size
	canvas.add_child(pins)
	# Where a thread is pinned at both ends. On the phone, one that would pass under another sticker goes
	# round the board's edge instead, pinned at the stickers' sides (the third value says which edge).
	var ends := func(id: String, r: String) -> Array:
		var to: Rect2 = places[id]
		var from: Rect2 = places[r]
		if not mobile:
			return [Vector2(from.end.x - 6, from.get_center().y), Vector2(to.position.x + 6, to.get_center().y), 0.0]
		var a := Vector2(from.get_center().x, from.end.y - 6)
		var b := Vector2(to.get_center().x, to.position.y + 6)
		var blocked := false
		for other in places:
			if other != id and other != r and places[other].grow(-4).intersects(Rect2(a, Vector2.ZERO).expand(b)):
				blocked = true
		if not blocked or absf(from.position.x - to.position.x) > 1.0:
			return [a, b, 0.0]
		var left: bool = from.position.x < size.x / 2.0
		var x: float = from.position.x + 6 if left else from.end.x - 6
		return [Vector2(x, from.get_center().y), Vector2(x, to.get_center().y), 3.0 if left else size.x - 3.0]
	pins.draw.connect(func():
		for id in places:
			for r in C.UPGRADES[id]["requires"]:
				if places.has(r):
					var color := COL_THREAD_OK if rules.upgrade_state(r) == "done" else COL_THREAD
					for pin in ends.call(id, r).slice(0, 2):
						pins.draw_circle(pin, 5.0, color)
						pins.draw_circle(pin + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1, 0.6)))
	threads.draw.connect(func():
		for id in places:
			for r in C.UPGRADES[id]["requires"]:
				if not places.has(r):
					continue
				var pair: Array = ends.call(id, r)
				var a: Vector2 = pair[0]
				var b: Vector2 = pair[1]
				var color := COL_THREAD_OK if rules.upgrade_state(r) == "done" else COL_THREAD
				var edge: float = pair[2]
				var sag := 10.0 + a.distance_to(b) * 0.06
				var pts := PackedVector2Array()
				for i in 25:
					var k := i / 24.0
					if edge > 0.0:
						pts.append(a.bezier_interpolate(Vector2(edge, a.y), Vector2(edge, b.y), b, k))
					else:
						pts.append(a.lerp(b, k) + Vector2(0, sag * 4.0 * k * (1.0 - k)))
				threads.draw_polyline(pts, color, 2.0, true))
	return board


# One sticker: the name, a line about it, and the price or how far along it is. A click opens the rest.
func _sticker(id: String, sz: Vector2) -> Control:
	var state := rules.upgrade_state(id)
	var fill: Color = COL_STICKY_LOCKED
	match state:
		"open":
			fill = COL_STICKY if rules.money >= rules.upgrade_price(id) else COL_STICKY_PALE
		"building":
			fill = COL_STICKY_BUILD
		"done":
			fill = COL_STICKY_DONE
	var tile := PanelContainer.new()
	var style := _box(fill, fill.darkened(0.08), 1, 10)
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0.25, 0.15, 0.05, 0.25)
	style.shadow_size = 3
	style.shadow_offset = Vector2(2, 3)
	tile.add_theme_stylebox_override("panel", style)
	tile.custom_minimum_size = sz
	tile.size = sz
	tile.pivot_offset = sz / 2.0
	# A slight tilt each, always the same for the same sticker.
	tile.rotation = deg_to_rad(float(hash(id) % 5 - 2) * 0.6)
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.tooltip_text = Loc.t("up.%s.name" % id)
	tile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_open_window.call_deferred("upgrade:" + id))
	var v := _vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(v)
	var faint: bool = state == "locked"
	var name := _label(Loc.t("up.%s.name" % id), 13 if mobile else 14, COL_FAINT if faint else COL_TEXT, true, true)
	name.max_lines_visible = 2
	v.add_child(name)
	var about := _label(Loc.t("up.%s.about" % id), 12, COL_FAINT if faint else COL_MUTED, true)
	about.max_lines_visible = 2
	about.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	about.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(about)
	match state:
		"building":
			v.add_child(_label(Loc.t("up.progress", [rules.upgrade_done_count(id), C.UPGRADES[id]["cards"].size()]), 12, COL_PRIMARY, false, true))
		"done":
			v.add_child(_label("✓ " + Loc.t("up.state.done"), 12, COL_GOOD, false, true))
		_:
			var short := rules.money < rules.upgrade_price(id)
			v.add_child(_label(_rub(rules.upgrade_price(id)), 13, COL_DANGER if short and not faint else (COL_FAINT if faint else COL_TEXT), false, true))
	return tile


# The full card of one upgrade, opened from its sticker: what it does now and when rolled out, what it
# brings into the deck, what it needs, and the buy button.
func _upgrade_window(id: String) -> void:
	var view := get_viewport().get_visible_rect().size
	var up: Dictionary = C.UPGRADES[id]
	var state := rules.upgrade_state(id)
	var v := _modal(Loc.t("up.%s.name" % id), _money_text() + "   " + _attention_text(), minf(560.0, view.x - 16.0), true, true)
	if state == "building":
		v.add_child(_label(Loc.t("up.progress", [rules.upgrade_done_count(id), up["cards"].size()]), 13, COL_PRIMARY, true, true))
	elif state == "done":
		v.add_child(_label(Loc.t("up.state.done"), 13, COL_GOOD, true, true))
	v.add_child(_label(Loc.t("up.%s.about" % id), 14, COL_MUTED, true))
	if not up["start"].is_empty():
		v.add_child(_label(Loc.t("up.start", [_fx_list(up["start"])]), 14, COL_TEXT, true))
	if not up["final"].is_empty():
		v.add_child(_label(Loc.t("up.final", [_fx_list(up["final"])]), 14, COL_TEXT, true))
	v.add_child(_label(Loc.t("up.cards", [up["cards"].size()]), 13, COL_MUTED, true))
	if not up["maint"].is_empty():
		v.add_child(_label(Loc.t("up.maint", [up["maint"].size()]), 13, COL_WARN, true))
	if up["replaces"] != "":
		v.add_child(_label(Loc.t("up.replaces", [Loc.t("up.%s.name" % up["replaces"])]), 13, COL_GOOD, true))
	if state == "locked":
		var names := PackedStringArray()
		for r in up["requires"]:
			if rules.upgrade_state(r) != "done":
				names.append("«%s»" % Loc.t("up.%s.name" % r))
		v.add_child(_label(Loc.t("up.needs", [", ".join(names)]), 13, COL_WARN, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	if state in ["open", "locked"]:
		var b := _button(Loc.t("up.buy", [_rub(rules.upgrade_price(id))]) + _cost_mark(rules.cost("buy")), _buy_upgrade.bind(id), 0, "primary" if rules.can_buy(id) else "")
		b.disabled = not rules.can_buy(id)
		row.add_child(b)
	row.add_child(_button(Loc.t("up.back"), _open_window.bind("upgrades"), 0, "subtle"))


func _fx_list(effects: Array) -> String:
	var parts := PackedStringArray()
	for e in effects:
		parts.append(_fx_text(e))
	return "; ".join(parts)


func _fx_text(e: Dictionary) -> String:
	var cat: String = Loc.t("cat." + e["cat"]) if e["cat"] != "" else ""
	var pct := int(round(absf(e["value"] - 1.0) * 100.0))
	match e["kind"]:
		"speed", "learn":
			return Loc.t("fx." + e["kind"], [cat, pct] if e["kind"] == "speed" else [pct])
		"freq":
			return Loc.t("fx.freq", [cat, pct])
		"due":
			return Loc.t("fx.due", [cat, int(e["value"])])
		"quality":
			return Loc.t("fx.quality", [cat])
		"remove", "self":
			return Loc.t("fx." + e["kind"], [_fx_targets(e)])
		"shrink":
			return Loc.t("fx.shrink", [pct, _fx_targets(e)])
		"attention", "borrow":
			return Loc.t("fx." + e["kind"], [int(e["value"])])
		"money":
			return Loc.t("fx.money", [_rub(int(e["value"]))])
	return Loc.t("fx." + e["kind"])


# The cards an effect names, as their titles (a template by one of its cards).
func _fx_targets(e: Dictionary) -> String:
	var names := PackedStringArray()
	for target in e["targets"]:
		for id in C.TASKS:
			if id == target or C.TASKS[id]["tpl"] == target:
				names.append("«%s»" % Loc.t("taskname." + id))
				break
	return ", ".join(names)


# The platform as a business: which banks are with us and how they feel, and what's been improved.
func _chainer_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_SURFACE, COL_BORDER, 1, 10))
	var v := _vbox(4)
	card.add_child(v)
	var goals := rules.goal_progress()
	if not goals.is_empty():
		v.add_child(_label(Loc.t("chainer.goal"), 13, COL_MUTED, false, true))
		for g in goals:
			var done: bool = rules.goal_met(g)
			var have: int = g["have"] if g["max"] else mini(g["have"], g["need"])
			var color := COL_GOOD if done and not g["max"] else (COL_DANGER if not done and g["max"] else COL_TEXT)
			v.add_child(_label(("✓ " if done and not g["max"] else "· ") + Loc.t("goal." + g["id"], [have, g["need"]]), 13, color, true))
		v.add_child(_spacer(4))
	v.add_child(_label(Loc.t("chainer.banks"), 13, COL_MUTED, false, true))
	if rules.banks.is_empty():
		v.add_child(_label(Loc.t("chainer.no_banks"), 13, COL_DANGER, true))
	for b in rules.banks:
		var word := rules.bank_word(b)
		var row := _flow(6, 0)
		row.add_child(_label(Loc.t("bank." + b), 14, COL_TEXT))
		row.add_child(_label("· " + Loc.t("bank_mood." + word), 13, BANK_COLORS[word]))
		v.add_child(row)
	v.add_child(_spacer(4))
	# The endless run's improvements are in the upgrade tree's own window.
	if rules.endless():
		return card
	v.add_child(_label(Loc.t("chainer.improved"), 13, COL_MUTED, false, true))
	if rules.improved.is_empty():
		v.add_child(_label(Loc.t("chainer.nothing_yet"), 13, COL_FAINT, true))
	for id in rules.improved:
		v.add_child(_label("✓ " + Loc.t("imp.%s.effect" % id), 13, COL_GOOD, true))
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
	var visit := _button(Loc.t("visit_short") + _cost_mark(rules.cost("boss")), _visit_boss, 0, "subtle")
	visit.disabled = not rules.can_visit()
	visit.custom_minimum_size.y = 30
	v.add_child(visit)
	# After the first time (a story scene in chapter three), you can go and ask for people yourself.
	if rules.flags.has("asked_people") and rules.openings == 0:
		var ask := _button(Loc.t("people.button") + _cost_mark(rules.cost("people")), _ask_people, 0, "subtle")
		ask.disabled = ask.disabled or not rules.can_ask_people()
		ask.custom_minimum_size.y = 30
		v.add_child(ask)
	return card


func _ask_people() -> void:
	window = ""
	rules.ask_people()
	_render()


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
	if rules.endless():
		hint = Loc.t("step.%s.hint" % rules.step)
	if not rules.queue_of("me").is_empty():
		hint = Loc.t("you.busy", [rules.own_task_cost()])
	titles.add_child(_label(hint, 13, COL_WARN if not rules.queue_of("me").is_empty() else COL_MUTED, true))
	var day_button := _day_button(200)
	day_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(day_button)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	v.add_child(columns)
	var lanes := _lanes()
	var inbox := _column("inbox", lanes["inbox"])
	inbox.size_flags_horizontal = Control.SIZE_FILL
	inbox.custom_minimum_size.x = INBOX_W
	_lit(inbox, "inbox")
	columns.add_child(inbox)
	var team := _team_zone()
	_lit(team, "active")
	columns.add_child(team)
	var done := _done_strip(lanes["done"])
	_lit(done, "done")
	v.add_child(done)
	return wrap


const INBOX_W := 300
const LANE_HEAD_W := 210
const LANE_CARD_W := 220


# The team: one lane per person, their face and state on the left and what's on their plate to the right.
func _team_zone() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(COL_COLUMN, COL_COLUMN, 0, 8))
	var v := _vbox(8)
	panel.add_child(v)
	v.add_child(_label(Loc.t("col.team"), 12, COL_MUTED, false, true))
	var scroll := _scroll("col_team")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := _vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var gone := PackedStringArray()
	for p in rules.team:
		if rules.people[p]["gone"]:
			gone.append(Loc.person(p))
		else:
			list.add_child(_lane_row(_person_row(p), rules.queue_of(p), Loc.t("row.free")))
	list.add_child(_lane_row(_me_head(), rules.queue_of("me"), Loc.t("row.me_free")))
	var outside: Array = []
	for t in rules.tasks:
		if t["status"] == "taras" or (t["status"] == "active" and t["owner"] == "contractor"):
			outside.append(t)
	if not outside.is_empty():
		var head := _vbox(0)
		head.add_child(_label(Loc.t("owner.outside"), 14, COL_MUTED, true, true))
		list.add_child(_lane_row(head, outside, ""))
	if not gone.is_empty():
		list.add_child(_label(Loc.t("gone_list", [", ".join(gone)]), 12, COL_FAINT, true))
	return panel


func _lane_row(head: Control, items: Array, empty: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.55), Color(0, 0, 0, 0), 0, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	head.custom_minimum_size.x = LANE_HEAD_W
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(head)
	var cards := HFlowContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	row.add_child(cards)
	if items.is_empty() and empty != "":
		var l := _label(empty, 12, COL_FAINT, true)
		l.custom_minimum_size.y = 40
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cards.add_child(l)
	for t in items:
		var card := _task_card(t, "people")
		card.size_flags_horizontal = Control.SIZE_FILL
		card.custom_minimum_size.x = LANE_CARD_W
		cards.add_child(card)
	return panel


# Your own lane: what you took on yourself; a click shows your strengths.
func _me_head() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_BG, COL_BORDER, 1, 8))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_open_window.call_deferred("me"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(_avatar("me", 32))
	var v := _vbox(1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(_label(Loc.t("me_card"), 14, COL_TEXT, false, true))
	v.add_child(_label(Loc.t("me_profile." + rules.profile), 12, COL_MUTED, true))
	return card


# What's done this week, folded into one line; a click lays the cards out.
func _done_strip(items: Array) -> Control:
	var late := 0
	for t in items:
		if t["late"]:
			late += 1
	var text_value := Loc.t("done.strip", [items.size()])
	if late > 0:
		text_value += " · " + Loc.t("done.strip_late", [late])
	var b := _button(text_value, _open_window.bind("done"), 0, "subtle")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = items.is_empty()
	b.add_theme_font_size_override("font_size", _fs(13))
	return b


# Three columns: the inbox, what's on people's plates (each person's queue, the first card being worked
# on), and what's done this week.
const LANES := ["inbox", "people", "done"]


func _lanes() -> Dictionary:
	var lanes := {"inbox": rules.inbox(), "people": [], "done": []}
	lanes["inbox"].sort_custom(func(a, b): return a["due"] < b["due"])
	for p in rules.team + ["me"]:
		lanes["people"].append_array(rules.queue_of(p))
	for t in rules.tasks:
		if t["status"] == "taras":
			lanes["people"].append(t)
		elif t["status"] == "done" and rules.week() == int((t["done_day"] - 1) / 5.0):
			lanes["done"].push_front(t)
	return lanes


# A person's name over their cards, in the people column.
func _owner_head(list: VBoxContainer, owner: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_avatar(owner, 20))
	row.add_child(_label(Loc.t("me_card") if owner == "me" else (Loc.t("owner.outside") if owner in ["taras", "contractor"] else Loc.person(owner)), 12, COL_MUTED, false, true))
	list.add_child(row)


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
	_fill_lane(list, lane, items)
	return panel


func _fill_lane(list: VBoxContainer, lane: String, items: Array) -> void:
	var last_owner := ""
	for t in items:
		if lane == "people" and t["owner"] != last_owner:
			last_owner = t["owner"]
			_owner_head(list, last_owner)
		list.add_child(_task_card(t, lane))
	if lane == "inbox":
		_backlog_section(list)


# Under the inbox: Chainer's own backlog. Nothing burns here, but what's done makes every week lighter.
func _backlog_section(list: VBoxContainer) -> void:
	var items := rules.backlog()
	if items.is_empty():
		return
	list.add_child(_spacer(6))
	var head := _section(Loc.t("col.backlog"))
	list.add_child(head)
	list.add_child(_label(Loc.t("backlog_hint"), 11, COL_FAINT, true))
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
	_lit(frame, "backlog")
	list.add_child(frame)
	var box := _vbox(6)
	frame.add_child(box)
	for t in items:
		box.add_child(_task_card(t, "inbox"))


func _task_card(t: Dictionary, lane: String) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chosen: bool = selected == t["uid"]
	var style := _box(COL_SELECTED if chosen else COL_SURFACE, COL_FOCUS if chosen else COL_BORDER, 2 if chosen else 1, 8)
	style.shadow_color = Color(0.035, 0.118, 0.259, 0.12)
	style.shadow_size = 1
	style.shadow_offset = Vector2(0, 1)
	card.add_theme_stylebox_override("panel", style)
	var clickable: bool = _looking() and (t["status"] == "inbox" or t["status"] == "active")
	if clickable:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_input.bind(t["uid"]))
	if lane == "done":
		card.modulate = Color(1, 1, 1, 0.7)
	if flash_cards.has(t["uid"]):
		var color: Color = flash_cards[t["uid"]]
		card.ready.connect(func(): _flash.call_deferred(card, color))
	var v := _vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var tags := _flow(4, 4)
	v.add_child(tags)
	var colors: Array = CAT_COLORS[t["cat"]]
	tags.add_child(_pill(Loc.t("cat." + t["cat"]), colors[0], colors[1], _cat_icon(t["cat"])))
	if t.get("again", false) and C.TASKS.get(t["id"], {}).get("kind", "") != "weekly":
		tags.add_child(_pill(Loc.t("chip_again"), COL_WARN, Color("fff0b3")))
	if C.TASKS.get(t["id"], {}).get("kind", "") == "chain":
		tags.add_child(_pill(Loc.t("chip_chain"), COL_PRIMARY, COL_SELECTED))
	if t["key"]:
		tags.add_child(_pill("★", COL_STAR, Color("fff7e6")))
	if t["blocked"] > 0:
		tags.add_child(_pill(Loc.t("chip_blocked"), COL_DANGER, Color("ffebe6")))
	if t["involved"] and t["owner"] != "me":
		tags.add_child(_pill(Loc.t("chip_involved").trim_prefix("· "), COL_PRIMARY, COL_SELECTED))
	v.add_child(_label(Loc.t("taskname." + t["id"]), 14, COL_TEXT, true))
	if t["status"] == "active":
		v.add_child(_progress_bar(t))
		if _stalled(t):
			v.add_child(_label(Loc.t("card.stalled"), 12, COL_WARN, true))
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


# What was done before today in pale green, today's gain in bright green. At midday a started task that
# hasn't moved since the morning goes grey: that's the one to look into.
func _progress_bar(t: Dictionary) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size: float = t["size"]
	var shown: float = minf(rules.shown_progress(t), size)
	var today: float = clampf(t.get("gain_today", 0.0), 0.0, shown)
	var stalled := _stalled(t)
	bar.draw.connect(func():
		var w := bar.size.x
		var h := bar.size.y
		bar.draw_rect(Rect2(0, 0, w, h), COL_COLUMN)
		var earlier := w * (shown - today) / size
		bar.draw_rect(Rect2(0, 0, earlier, h), COL_FAINT if stalled else COL_EARLIER)
		bar.draw_rect(Rect2(earlier, 0, w * today / size, h), COL_GAIN))
	return bar


# Midday, and the task someone's on right now hasn't moved since the morning.
func _stalled(t: Dictionary) -> bool:
	if not rules.endless() or rules.step != "work" or t.get("gain_today", 0.0) > 0.0 or not rules.team.has(t["owner"]):
		return false
	var q := rules.queue_of(t["owner"])
	return not q.is_empty() and q[0]["uid"] == t["uid"]


# A card is picked on release, and only if the finger didn't move: dragging scrolls the list instead.
func _on_card_input(event: InputEvent, uid: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_pos = event.global_position
		elif event.global_position.distance_to(press_pos) < 12.0:
			cue = "select"
			_select.call_deferred(uid)


func _due_text(t: Dictionary) -> String:
	if t.get("backlog", false) or t["id"].begins_with("init_") or t["due"] >= rules.NO_DEADLINE:
		return Loc.t("due.none")
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


# The open card: who asked, what it takes, and who gets it, each person shown with how they'd do it.
func _task_window(v: VBoxContainer, t: Dictionary) -> void:
	var facts := _flow(6, 4)
	v.add_child(facts)
	var colors: Array = CAT_COLORS[t["cat"]]
	facts.add_child(_pill(Loc.t("cat." + t["cat"]), colors[0], colors[1], _cat_icon(t["cat"])))
	var est: Dictionary = rules.estimate(t)
	facts.add_child(_pill(Loc.t("est.chip" if est["sure"] else "est.chip_guess", [_days(est["days"])]), COL_TEXT, COL_COLUMN))
	facts.add_child(_pill(_due_text(t), COL_DANGER if t["due"] - rules.day <= 1 else COL_TEXT, Color("ffebe6") if t["due"] - rules.day <= 1 else COL_COLUMN))
	if t["key"]:
		facts.add_child(_pill(Loc.t("chip_key"), COL_WARN, Color("fff7e6")))
	elif t["public"]:
		facts.add_child(_pill(Loc.t("public"), COL_WARN, Color("fff7e6")))
	var bare: String = t["id"].trim_prefix("init_")
	if C.IMPROVEMENTS.has(bare):
		v.add_child(_label(Loc.t("imp.%s.about" % bare), 14, COL_MUTED, true))
		v.add_child(_label(Loc.t("imp.gives", [Loc.t("imp.%s.effect" % bare)]), 14, COL_GOOD, true, true))
	else:
		v.add_child(_label("%s — %s" % [Loc.t("from", [Loc.person(t["from"])]), Loc.t("quote", [Loc.t("task.%s.ask" % t["id"])])], 14, COL_MUTED, true))
	var pen: Dictionary = rules.penalty_of(t)
	if not pen.is_empty() and t["status"] != "done" and not t["late"]:
		v.add_child(_label(Loc.t("penalty.%s.card" % pen["kind"], [_rub(pen["amount"])] if pen["kind"] == "money" else []), 14, COL_DANGER, true))
	if deal_from >= 0:
		_deal_block(v, t)
		return
	if rules.can_assign(t):
		v.add_child(_section(Loc.t("to_whom").trim_suffix(":")))
		var grid := GridContainer.new()
		grid.columns = 2 if mobile else 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		var best := _best_pick(t)
		for p in _pick_order(t):
			grid.add_child(_pick_tile(t, p, p == best))
		if not t.get("backlog", false) and not rules.endless():
			grid.add_child(_button(Loc.t("to_taras"), _direct.bind("taras"), 0))
		if rules.can_decline(t):
			var no := _button(Loc.t("decline_button") + _cost_mark(rules.cost("decline")), _decline, 0, "subtle")
			no.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			v.add_child(no)
	if t["status"] == "active":
		var acts := _flow(6, 6)
		v.add_child(acts)
		# The endless morning is for handing out, the middle of the day for stepping in.
		if rules.can_assign(t):
			acts.add_child(_button(Loc.t("unassign"), _unassign, 0, "subtle"))
		if rules.team.has(t["owner"]) and rules.queue_of(t["owner"])[0]["uid"] != t["uid"] and rules.allowed("prioritize"):
			acts.add_child(_button(Loc.t("prioritize"), _prioritize, 0, "subtle"))
		if rules.team.has(t["owner"]) and not t["sit_today"] and rules.allowed("sit"):
			var sit := _button(Loc.t("sit.button") + _cost_mark(rules.cost("sit")), _sit, 0, "subtle")
			sit.disabled = sit.disabled or not rules.can_afford(rules.cost("sit"))
			acts.add_child(sit)
		if rules.team.has(t["owner"]) and rules.allowed("stay"):
			var stay := _button(Loc.t("stay_button"), _ask_stay, 0, "subtle")
			stay.disabled = stay.disabled or t.get("stay_asked", -1) == rules.day
			acts.add_child(stay)
			var step := _button(Loc.t("intervene_button") + _cost_mark(rules.cost("intervene")), _intervene, 0, "subtle")
			step.disabled = step.disabled or not rules.can_intervene(t)
			acts.add_child(step)
	if t["status"] == "active" and rules.team.has(t["owner"]) and rules.allowed("pair"):
		var pair := _flow(6, 6)
		v.add_child(pair)
		pair.add_child(_row_label(Loc.t("helper_optional")))
		for p in rules.team:
			if p != t["owner"] and rules.available(p):
				var hb := _button(Loc.person(p) + _cost_mark(rules.cost("pair")), _helper.bind(p), 0, "chosen" if t["helper"] == p else "")
				hb.disabled = hb.disabled or t["helper"] == p or not rules.allowed("pair") or not rules.can_afford(rules.cost("pair"))
				pair.add_child(hb)
		pair.add_child(_button(Loc.t("no_helper"), _helper.bind(""), 0, "chosen" if t["helper"] == "" else ""))
		v.add_child(_label(Loc.t("helper_hint"), 12, COL_MUTED, true))


# Who can take it, best first: sooner done by them, then fewer things already on them; you last.
func _pick_order(t: Dictionary) -> Array:
	var people: Array = []
	if not rules.only_me(t):
		for p in rules.team:
			if rules.available(p):
				people.append(p)
	people.sort_custom(func(a, b): return _pick_score(t, a) < _pick_score(t, b))
	people.append("me")
	return people


func _pick_score(t: Dictionary, p: String) -> float:
	var score: float = rules.estimate(t, p)["days"] + 0.6 * rules.queue_of(p).size()
	if rules.people[p]["absent"]:
		score += 100.0
	return score


# The one to point at: first in the order, if you actually know their level at this.
func _best_pick(t: Dictionary) -> String:
	var order := _pick_order(t)
	if order.size() < 2:
		return ""
	var p: String = order[0]
	return p if rules.people[p]["known"].has("skill." + t["cat"]) and rules.people[p]["skills"][t["cat"]] >= 2 else ""


func _level_stars(level: int) -> String:
	return "★".repeat(level) + "☆".repeat(4 - level)


# One person as a choice: their level at this kind of work, what's on them, how they are, and how long.
func _pick_tile(t: Dictionary, p: String, best: bool) -> Control:
	var me: bool = p == "me"
	var owner: bool = t["owner"] == p
	var can: bool = rules.can_assign(t) and not owner and rules.can_afford(rules.cost("assign")) and (me or not rules.people[p]["absent"])
	var tile := PanelContainer.new()
	tile.custom_minimum_size.x = 170
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := COL_SELECTED if owner else (Color("f4f8ff") if best else COL_SURFACE)
	tile.add_theme_stylebox_override("panel", _box(fill, COL_FOCUS if best or owner else COL_BORDER, 2 if best or owner else 1, 10))
	if can:
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					press_pos = event.global_position
				elif event.global_position.distance_to(press_pos) < 12.0:
					cue = "assign"
					_pick.call_deferred(p))
		var hover := _box(Color("ebf2ff"), COL_FOCUS, 2, 10)
		tile.mouse_entered.connect(func(): tile.add_theme_stylebox_override("panel", hover))
		tile.mouse_exited.connect(func(): tile.add_theme_stylebox_override("panel", _box(fill, COL_FOCUS if best or owner else COL_BORDER, 2 if best or owner else 1, 10)))
	else:
		tile.modulate = Color(1, 1, 1, 0.5)
	var v := _vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(_avatar(p, 32))
	var name := _label(Loc.t("myself") if me else Loc.person(p), 15, COL_TEXT, true, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	if best:
		v.add_child(_label(Loc.t("pick.best"), 12, COL_PRIMARY, true, true))
	elif owner:
		v.add_child(_label(Loc.t("pick.owner"), 12, COL_PRIMARY, true, true))
	var colors: Array = CAT_COLORS[t["cat"]]
	var known: bool = me or rules.people[p]["known"].has("skill." + t["cat"])
	var level: int = rules.my_skill(t["cat"]) if me else rules.people[p]["skills"][t["cat"]]
	var skill := _label(_level_stars(level) + "  " + Loc.t("level.%d" % level) if known else "?  " + Loc.t("pick.unknown"), 14, colors[0] if known else COL_FAINT, true, true)
	v.add_child(skill)
	if not me:
		var st: Dictionary = rules.people[p]
		if st["absent"]:
			v.add_child(_label(Loc.t("absent.%s_label" % st["absent_reason"]), 12, COL_WARN, true))
		else:
			var line := _flow(4, 0)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(line)
			var mood := rules.mood_word(p)
			line.add_child(_label(Loc.t("mood." + mood), 12, MOOD_COLORS[mood]))
			var energy := rules.energy_word(p)
			line.add_child(_label("· " + Loc.t("energy." + energy), 12, ENERGY_COLORS[energy]))
		var load := rules.queue_of(p).size()
		v.add_child(_label(Loc.t("row.load", [load]) if load > 0 else Loc.t("row.free"), 12, COL_WARN if load >= rules.OVERLOAD_AT else COL_MUTED))
	var pe: Dictionary = rules.estimate(t, p)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	var days := _label(Loc.t("pick.days", [_days(pe["days"])]) if pe["sure"] else Loc.t("pick.days_guess"), 13, COL_TEXT if pe["sure"] else COL_FAINT, false, pe["sure"])
	days.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(days)
	if rules.cost("assign") > 0:
		foot.add_child(_label(_cost_mark(rules.cost("assign")).strip_edges(), 13, COL_MUTED))
	return tile


# The talk over a task someone pushed back on: what was said, then how you answer, or what came of it.
func _deal_block(v: VBoxContainer, t: Dictionary) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _box(COL_BG, COL_BORDER, 1, 12))
	v.add_child(box)
	var talk := _vbox(10)
	box.add_child(talk)
	for i in range(deal_from, rules.history.size()):
		var e: Dictionary = rules.history[i]
		# Just the two of you: tips and narration stay in the chat.
		if e["key"].begins_with("log.") or e["who"] not in ["you", deal_who]:
			continue
		talk.add_child(_deal_line(e))
	if not rules.pending.is_empty():
		var p: String = rules.pending["p"]
		v.add_child(_label(Loc.render("objection_title", [], {"who": Loc.person(p)}), 13, COL_PRIMARY, true, true))
		var grid := GridContainer.new()
		grid.columns = 1 if mobile else 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		for intent in C.INTENTS + ["back_off"]:
			grid.add_child(_answer_button(Loc.t("intent." + intent), _persuade.bind(intent)))
		v.add_child(_label(Loc.t("objection_hint"), 12, COL_MUTED, true))
	else:
		var ok := _button(Loc.t("deal.ok"), _deal_done, 200, "primary")
		ok.size_flags_horizontal = Control.SIZE_SHRINK_END
		v.add_child(ok)


func _deal_line(e: Dictionary) -> Control:
	var body := Loc.render(e["key"], e.get("args", []), e.get("names", {}))
	if e["who"] == "":
		return _label(body, 13, COL_MUTED, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var you: bool = e["who"] == "you"
	row.add_child(_avatar("me" if you else e["who"], 32))
	var col := _vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_label(Loc.t("you") if you else Loc.person(e["who"]), 13, COL_MUTED, false, true))
	col.add_child(_label(body, 16, COL_TEXT, true))
	return row


func _row_label(text_value: String) -> Control:
	var l := _label(text_value, 13, COL_MUTED)
	l.custom_minimum_size.y = 34
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


# ---------- the phone layout ----------

func _view_width() -> float:
	return get_viewport().get_visible_rect().size.x


# One screen at a time, and only you switch them: when the chat needs you, the other screens say so
# and point there, but nothing jumps by itself.
func _build_phone() -> void:
	var v := _vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(v)
	v.add_child(_phone_top())
	var banner := _tip_banner()
	if banner:
		v.add_child(banner)
	var body: Control = _phone_messenger() if tab == "chat" else _phone_board()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	v.add_child(_phone_tabs())


# The phone's top: the day, then what you have as game resources: points, money, the race.
func _phone_top() -> Control:
	var bar := PanelContainer.new()
	var style := _box(_sky(), _sky(), 0, 0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", style)
	var v := _vbox(8)
	bar.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(_logo(24))
	var day := _label(_day_label(), 15, COL_ON_TOP, false, true)
	day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(day)
	var menu := _button(Loc.t("menu.button"), _open_menu, 0, "on_top")
	menu.custom_minimum_size.y = 30
	row.add_child(menu)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	v.add_child(chips)
	var dots := ""
	for i in rules.max_attention():
		dots += "●" if i < rules.attention else "○"
	var points := _label(Loc.t("you.sick_today") if rules.sick_today else dots, 17, COL_ON_TOP if rules.overtime_today == 0 else COL_ON_TOP_DANGER, false, true)
	juice_nodes["points"] = points
	chips.add_child(_chip(points))
	if rules.endless():
		var money := _label(_money_text(), 14, _money_color(), false, true)
		juice_nodes["money"] = money
		chips.add_child(_chip(money))
		var race := _race_label(14)
		juice_nodes["race"] = race
		chips.add_child(_chip(race))
	else:
		var k := rules.key_status()
		chips.add_child(_chip(_label(Loc.render("keys_short", [], {"good": k["good"], "total": rules.chapter_keys().size()}), 14, COL_ON_TOP, false, true)))
	return bar


# A resource on the phone's top bar: a translucent rounded plate around its number.
func _chip(content: Control) -> Control:
	var chip := PanelContainer.new()
	var cs := _flat(Color(1, 1, 1, 0.14))
	cs.set_corner_radius_all(14)
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	cs.content_margin_top = 3
	cs.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", cs)
	chip.add_child(content)
	return chip


# The phone's bottom bar: the board, the messenger, Irina, and everything else, each with its icon and a
# counter when something waits there.
func _phone_tabs() -> Control:
	var bar := PanelContainer.new()
	var style := _flat(COL_SURFACE)
	style.border_color = COL_BORDER
	style.border_width_top = 1
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)
	var unread := 0
	var asks := false
	for th in _contacts():
		unread += _unread(th)
		asks = asks or _letters_in(th) > 0 or _asked_thread() == th
	row.add_child(_tab_item(_icon("nav_board"), Loc.t("tab.board"), "", tab == "board", _go_tab.bind("board")))
	row.add_child(_tab_item(_icon("nav_chat"), Loc.t("tab.chat"), "!" if asks else _badge(unread), tab == "chat", _go_tab.bind("chat"), asks))
	var boss := _avatar("boss", 26)
	row.add_child(_tab_item(boss, Loc.t("tab.boss"), "", window == "boss", _open_window.bind("boss")))
	row.add_child(_tab_item(_icon("nav_more"), Loc.t("tab.more"), _badge(_more_count()), window == "more", _open_window.bind("more")))
	return bar


func _icon(name: String) -> Control:
	var tex := TextureRect.new()
	var path := ICON_DIR + name + ".svg"
	if ResourceLoader.exists(path):
		tex.texture = load(path)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(24, 24)
	return tex


func _tab_item(icon: Control, text_value: String, badge: String, chosen: bool, action: Callable, urgent: bool = false) -> Control:
	var item := PanelContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_stylebox_override("panel", _box(COL_SELECTED if chosen else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6))
	item.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			action.call_deferred())
	var v := _vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(v)
	var spot := Control.new()
	spot.custom_minimum_size = Vector2(28, 26)
	spot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spot)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(1, 0)
	if icon is TextureRect:
		icon.modulate = COL_PRIMARY if chosen else COL_MUTED
	spot.add_child(icon)
	var l := _label(text_value, 12, COL_PRIMARY if chosen else COL_MUTED, false, chosen)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if badge != "":
		var dot := PanelContainer.new()
		var ds := _flat(COL_STAR if urgent else COL_DANGER)
		ds.set_corner_radius_all(9)
		ds.content_margin_left = 5
		ds.content_margin_right = 5
		dot.add_theme_stylebox_override("panel", ds)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_child(_label(badge, 10, COL_ON_TOP, false, true))
		dot.position = Vector2(18, -4)
		spot.add_child(dot)
	return item


# What waits behind "more": CVs, upgrades newly within reach, unhappy clients.
func _more_count() -> int:
	var n := rules.candidates.size() + _fresh_upgrades()
	for bank in rules.banks:
		if rules.bank_word(bank) in ["unhappy", "leaving"]:
			n += 1
	return n


# The phone's board: the inbox, or the team with each person's cards under them; the week's done
# folded into a line; the day's button.
func _phone_board() -> Control:
	var v := _vbox(8)
	var lanes := _lanes()
	var switcher := HBoxContainer.new()
	switcher.add_theme_constant_override("separation", 4)
	v.add_child(switcher)
	if lane != "team":
		lane = "inbox"
	for name in ["inbox", "team"]:
		var text_value := "%s %d" % [Loc.t("col_short.inbox"), lanes["inbox"].size()] if name == "inbox" else Loc.t("tab.team")
		var b := _button(text_value, _pick_lane.bind(name), 0, "chosen" if lane == name else "subtle")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", _fs(14))
		_lit(b, "inbox" if name == "inbox" else "active")
		switcher.add_child(b)
	var hint := Loc.t("you.busy", [rules.own_task_cost()]) if not rules.queue_of("me").is_empty() else (Loc.t("step.%s.hint" % rules.step) if rules.endless() else Loc.t("pick_task"))
	v.add_child(_label(hint, 13, COL_WARN if not rules.queue_of("me").is_empty() else COL_MUTED, true))
	var scroll := _scroll("phone_" + lane)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := _vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if lane == "inbox":
		if lanes["inbox"].is_empty():
			list.add_child(_label(Loc.t("col_empty.inbox"), 14, COL_FAINT, true))
		_fill_lane(list, "inbox", lanes["inbox"])
	else:
		for p in rules.team:
			if not rules.people[p]["gone"]:
				list.add_child(_phone_lane(_person_row(p), rules.queue_of(p), Loc.t("row.free")))
		list.add_child(_phone_lane(_me_head(), rules.queue_of("me"), Loc.t("row.me_free")))
	v.add_child(_done_strip(lanes["done"]))
	v.add_child(_day_button(0))
	return _padded(v, 10, 10)


# One person on the phone: their plate under their name, full width.
func _phone_lane(head: Control, items: Array, empty: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(COL_COLUMN, COL_COLUMN, 0, 8))
	var v := _vbox(6)
	panel.add_child(v)
	v.add_child(head)
	if items.is_empty():
		var l := _label(empty, 12, COL_FAINT, true)
		v.add_child(_indented(l))
	for t in items:
		v.add_child(_task_card(t, "people"))
	return panel


# ---------- the messenger ----------
# No common feed: a contact list, and one conversation at a time. Each line of the history belongs to
# one conversation: the person who said it or was spoken to, or the team channel for everything else.

const GENERAL := "general"


func _contacts() -> Array:
	var out: Array = [GENERAL]
	for p in rules.team:
		if not rules.people[p]["gone"]:
			out.append(p)
	out.append_array(["boss", "marina"])
	if not threads.get("taras", []).is_empty():
		out.append("taras")
	return out


func _contact_of(p: String) -> String:
	if p in ["boss", "marina", "taras"] or (rules.team.has(p) and not rules.people[p]["gone"]):
		return p
	return GENERAL


func _sort_threads() -> void:
	threads = {}
	day_names = {}
	var last := GENERAL
	for i in rules.history.size():
		var e: Dictionary = rules.history[i]
		var key: String = e["key"]
		if key == "log.morning":
			day_names[e["day"]] = Loc.render(key, e.get("args", []), e.get("names", {})).replace("—", "").strip_edges()
		var th := GENERAL
		if e.has("thread"):
			th = _contact_of(e["thread"])
		elif key.begins_with("log."):
			th = GENERAL
		elif e["who"] == "you":
			if e.has("to"):
				th = _contact_of(e["to"])
			elif key.begins_with("visit."):
				th = "boss"
			elif key == "you.to_taras":
				th = "taras"
			elif key == "people.ask":
				th = "marina"
			elif key.begins_with("up."):
				th = GENERAL
			else:
				th = last
		elif e["who"] != "":
			th = _contact_of(e["who"])
		last = th
		if not threads.has(th):
			threads[th] = []
		threads[th].append(i)


# A loaded game or a test point starts with everything read.
func _read_all() -> void:
	_sort_threads()
	for th in threads:
		thread_read[th] = rules.history.size()


func _unread(th: String) -> int:
	var n := 0
	var from: int = thread_read.get(th, 0)
	for i in threads.get(th, []):
		if i >= from and rules.history[i]["who"] not in ["you", ""]:
			n += 1
	return n


# The conversation where a question waits for you, if any.
func _asked_thread() -> String:
	if rules.phase == "event" and not rules.events.is_empty():
		return _contact_of(rules.events[0]["who"])
	if rules.phase == "review" and not rules.review.is_empty():
		return "boss"
	return ""


# Offers a person makes on their own (the story's initiative), shown in their conversation.
func _thread_offer(th: String) -> String:
	if rules.phase != "plan" or not rules.team.has(th):
		return ""
	return rules.initiative_offer(th)


func _open_thread(th: String) -> void:
	chat_thread = "" if chat_thread == th and not mobile else th
	_render()


func _close_thread() -> void:
	chat_thread = ""
	_render()


func _contact_name(th: String) -> String:
	return Loc.t("chat.general") if th == GENERAL else Loc.person(th)


func _contact_face(th: String, size: int) -> Control:
	if th != GENERAL:
		return _avatar(th, size)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(size, size)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := _flat(COL_PRIMARY)
	style.set_corner_radius_all(int(size / 2.0))
	box.add_theme_stylebox_override("panel", style)
	var l := _label("#", int(size * 0.5), COL_ON_TOP, false, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	box.tooltip_text = _contact_name(th)
	return box


# A round marker on a face: a question waiting (orange "!") or how many lines are unread.
func _letters_in(th: String) -> int:
	var n := 0
	for ev in rules.letters:
		if _contact_of(ev["who"]) == th:
			n += 1
	return n


func _contact_badge(th: String) -> Control:
	var waiting: bool = _asked_thread() == th or _thread_offer(th) != "" or _letters_in(th) > 0
	var n := _unread(th)
	if not waiting and n == 0:
		return null
	var dot := PanelContainer.new()
	var ds := _flat(COL_STAR if waiting else COL_DANGER)
	ds.set_corner_radius_all(10)
	ds.content_margin_left = 6
	ds.content_margin_right = 6
	dot.add_theme_stylebox_override("panel", ds)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_child(_label("!" if waiting else str(n), 11, COL_ON_TOP, false, true))
	return dot


# The desktop's right side: the open conversation, if any, then the column of contacts.
func _messenger() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	if chat_thread != "" and _contacts().has(chat_thread):
		var view := _thread_view(chat_thread)
		view.custom_minimum_size.x = CHAT_W
		row.add_child(view)
	else:
		chat_thread = ""
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 76
	var style := _flat(COL_SURFACE)
	style.border_color = COL_BORDER
	style.border_width_left = 1
	style.content_margin_top = 10
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var scroll := _scroll("contacts")
	panel.add_child(scroll)
	var v := _vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	for th in _contacts():
		v.add_child(_contact_dot(th))
	return row


func _contact_dot(th: String) -> Control:
	var holder := CenterContainer.new()
	# A plain box under the ring, so the counter can hang off its corner instead of being laid out.
	var spot := Control.new()
	spot.custom_minimum_size = Vector2(56, 60)
	holder.add_child(spot)
	var ring := PanelContainer.new()
	# Room above and to the right, or the scrolling list clips the counter.
	ring.position = Vector2(0, 8)
	ring.size = Vector2(52, 52)
	var open: bool = chat_thread == th
	var rs := _box(COL_SELECTED if open else Color(0, 0, 0, 0), COL_FOCUS if open else Color(0, 0, 0, 0), 2, 3)
	rs.set_corner_radius_all(30)
	ring.add_theme_stylebox_override("panel", rs)
	ring.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ring.tooltip_text = _contact_name(th)
	ring.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_open_thread.call_deferred(th))
	spot.add_child(ring)
	var face := _contact_face(th, 44)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(face)
	var badge := _contact_badge(th)
	if badge:
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.offset_left = -20
		badge.offset_top = 0
		badge.grow_horizontal = Control.GROW_DIRECTION_END
		spot.add_child(badge)
	return holder


# One conversation: the last few days of it, what waits for an answer, and what you can say first.
func _thread_view(th: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if mobile else Control.SIZE_FILL
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
	head_style.content_margin_left = 12
	head_style.content_margin_right = 10
	head_style.content_margin_top = 8
	head_style.content_margin_bottom = 8
	head.add_theme_stylebox_override("panel", head_style)
	v.add_child(head)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	head.add_child(head_row)
	if mobile:
		head_row.add_child(_button("‹", _close_thread, 36, "subtle"))
	head_row.add_child(_contact_face(th, 30))
	var title := _label(_contact_name(th), 16, COL_TEXT, false, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(title)
	if rules.team.has(th):
		var card := _button(Loc.t("chat.card"), _open_window.bind("person:" + th), 0, "subtle")
		card.add_theme_font_size_override("font_size", _fs(12))
		head_row.add_child(card)
	if not mobile:
		head_row.add_child(_button("×", _close_thread, 30, "subtle"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := _vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(list, 14, 12))
	chat_list = list
	chat_scroll = scroll
	chat_last = ""
	var items: Array = threads.get(th, [])
	var shown_day := -1
	var any := false
	for i in items:
		var e: Dictionary = rules.history[i]
		if e["day"] < rules.day - 2 or (e["key"].begins_with("log.") and th != GENERAL):
			continue
		if e["day"] != shown_day and not e["key"].begins_with("log."):
			shown_day = e["day"]
			list.add_child(_spacer(4))
			var sep := _label(day_names.get(shown_day, ""), 12, COL_FAINT, true, true)
			sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			list.add_child(sep)
			chat_last = ""
		if e["key"].begins_with("log."):
			if e["key"] == "log.morning":
				continue
			shown_day = e["day"]
		_append_entry(list, e)
		any = true
	if not any:
		list.add_child(_label(Loc.t("chat.empty"), 13, COL_FAINT, true))
	_thread_prompt(list, th)
	thread_read[th] = rules.history.size()
	var now := "%s/%d/%s/%d/%d" % [th, rules.history.size(), rules.phase, rules.events.size(), rules.review.size()]
	if now != chat_seen:
		chat_seen = now
		_scroll_to_end(scroll)
	else:
		_scroll_to(scroll, chat_pos)
	return panel


# Under a conversation: the question waiting there, an offer, or what you can start yourself.
func _thread_prompt(list: VBoxContainer, th: String) -> void:
	if not rules.convo.is_empty() and rules.convo["kind"] == "talk" and rules.convo["who"] == th:
		_talk_in_thread(list)
		return
	if _asked_thread() == th:
		if rules.phase == "event":
			_event_prompt(list, rules.events[0])
		else:
			_review_prompt(list)
		return
	for i in rules.letters.size():
		if _contact_of(rules.letters[i]["who"]) == th:
			_letter_prompt(list, i, rules.letters[i])
	var offer := _thread_offer(th)
	if offer != "":
		list.add_child(_offer_card(th, offer))
	if rules.team.has(th) and rules.phase == "plan":
		list.add_child(_spacer(8))
		var talk := _button(Loc.t("talk_button") + _cost_mark(rules.cost("talk")), _talk_to.bind(th), 0, "")
		talk.disabled = talk.disabled or not rules.can_talk(th)
		list.add_child(talk)
	elif th == "boss" and rules.phase == "plan":
		list.add_child(_spacer(8))
		var go := _button(Loc.t("visit_button") + _cost_mark(rules.cost("boss")), _visit_boss, 0, "")
		go.disabled = go.disabled or not rules.can_visit()
		list.add_child(go)


# A one-on-one going on right now: what's been said, then what you can say, each line a reply that costs.
func _talk_in_thread(list: VBoxContainer) -> void:
	for e in rules.convo["log"]:
		var line: Dictionary = e.duplicate()
		line["key"] = e.get("key", "convo.line")
		line["args"] = []
		_append_entry(list, line)
	var v := _prompt_box(list, Loc.t("convo.left", [rules.convo["left"]]) if rules.convo["left"] > 0 else "")
	var group := ""
	for c in rules.convo_choices():
		var kind: String = "act" if c.begins_with("a:") else ("ask" if c.begins_with("q:") else "")
		if kind != group and kind != "":
			v.add_child(_label(Loc.t("convo.group." + kind), 12, COL_MUTED))
		group = kind
		var text_value := rules.convo_label(c)
		if c != "end":
			text_value += _cost_mark(rules.cost("reply"))
		var b := _answer_button(text_value, _convo_choose.bind(c))
		b.disabled = c != "end" and not rules.can_afford(rules.cost("reply"))
		v.add_child(b)


# The phone's chat tab: the contact list, or the conversation picked from it.
func _phone_messenger() -> Control:
	if chat_thread != "" and _contacts().has(chat_thread):
		return _thread_view(chat_thread)
	chat_thread = ""
	var scroll := _scroll("contacts")
	var v := _vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(v, 10, 10))
	for th in _contacts():
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _box(COL_SURFACE, COL_BORDER, 1, 10))
		row.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					press_pos = event.global_position
				elif event.global_position.distance_to(press_pos) < 12.0:
					_open_thread.call_deferred(th))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		h.add_child(_contact_face(th, 40))
		var col := _vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(col)
		col.add_child(_label(_contact_name(th), 15, COL_TEXT, false, true))
		var items: Array = threads.get(th, [])
		if not items.is_empty():
			var e: Dictionary = rules.history[items[-1]]
			var line := Loc.render(e["key"], e.get("args", []), e.get("names", {})).replace("\n", " ")
			var preview := _label(line, 13, COL_MUTED)
			preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			preview.clip_text = true
			col.add_child(preview)
		var badge := _contact_badge(th)
		if badge:
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(badge)
		v.add_child(row)
	return scroll


# One chat entry: a day-part divider, narration, or a line under its speaker's name.
func _append_entry(list: VBoxContainer, e: Dictionary) -> void:
	var key: String = e["key"]
	if key.begins_with("log."):
		list.add_child(_spacer(4))
		var sep := _label(Loc.render(key, e.get("args", []), e.get("names", {})).replace("—", "").strip_edges(), 12, COL_FAINT, true, true)
		sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(sep)
		chat_last = ""
		return
	var body := Loc.fill(e["ru"], e["en"], e.get("names", {})) if e.has("ru") else Loc.render(key, e.get("args", []), e.get("names", {}))
	if e["who"] == "":
		if chat_last != "":
			list.add_child(_spacer(4))
		list.add_child(_label(body, 13, COL_MUTED, true))
		chat_last = ""
		return
	# Every message is its own bubble under its own face and name, so two in a row never run together.
	list.add_child(_spacer(4))
	var bubble := PanelContainer.new()
	var you: bool = e["who"] == "you"
	var bs := _box(Color("eef4ff") if you else COL_BG, Color("d6e4ff") if you else COL_BORDER, 1, 10)
	bubble.add_theme_stylebox_override("panel", bs)
	var v := _vbox(4)
	bubble.add_child(v)
	v.add_child(_message_head(e))
	v.add_child(_indented(_label(body, 15, COL_MUTED if body.begins_with("(") else COL_TEXT, true)))
	list.add_child(bubble)
	chat_last = e["who"]


func _message_head(e: Dictionary) -> Control:
	var who: String = e["who"]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_avatar("me" if who == "you" else who, 28))
	var name := Loc.t("you") if who == "you" else Loc.person(who)
	h.add_child(_label(name, 14, COL_TEXT, false, true))
	if who == "you" and e.has("to") and chat_thread == GENERAL:
		h.add_child(_label("→ " + Loc.t("name.%s.dat" % e["to"]), 13, COL_MUTED))
	return h


func _indented(c: Control) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 36)
	m.add_child(c)
	return m


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


# A message waiting for an answer: answering costs, saying nothing is free and settles at the end of the day.
func _letter_prompt(list: VBoxContainer, i: int, ev: Dictionary) -> void:
	var v := _prompt_box(list, Loc.t("letter.title"))
	for choice in ev["choices"]:
		var parts: PackedStringArray = choice.split(":")
		var names: Dictionary = ev["names"].duplicate()
		if ev.has("choice_names"):
			names.merge(ev["choice_names"].get(choice, {}), true)
		elif parts.size() > 1:
			names["who"] = "@name.%s.acc" % parts[1]
		var text := Loc.render("event.%s.choice.%s" % [ev["id"], parts[0]], [], names) + _cost_mark(rules.reply_cost(ev, choice))
		var b := _answer_button(text, _answer_letter.bind(i, choice))
		b.disabled = not rules.can_answer(i, choice)
		v.add_child(b)
	v.add_child(_label(Loc.t("letter.hint"), 12, COL_MUTED, true))


func _answer_letter(i: int, choice: String) -> void:
	rules.answer_letter(i, choice)
	_render()


func _event_prompt(list: VBoxContainer, ev: Dictionary) -> void:
	var title := ""
	if ev["id"].begins_with("boss_visit") or ev["id"] == "boss_show":
		title = Loc.t("visit_title")
	elif ev["id"] == "intervene":
		title = Loc.render("intervene_title", [], ev["names"]) + " — " + Loc.person(ev["target"])
	elif ev["id"] == "decline":
		title = Loc.render("decline_title", [], ev["names"])
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
			text += _cost_mark(rules.choice_cost(ev, choice))
		if ev["id"] == "boss_visit" and (parts[0] == "delay" or parts[0] == "contractor") and not rules.has_weight():
			text += " " + Loc.t("needs_weight")
		v.add_child(_answer_button(text, _event.bind(choice)))


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
	var offer_key := "init.offer." + offer
	if offer == "self_study":
		offer_key += "." + rules.study_target(p)
	v.add_child(_label(Loc.t(offer_key), 15, COL_TEXT, true))
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


func _scroll_to(scroll: ScrollContainer, pos: int) -> void:
	for i in 2:
		await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = pos
		if scroll == chat_scroll:
			chat_to_end = false


func _scroll_to_end(scroll: ScrollContainer) -> void:
	if scroll == chat_scroll:
		chat_to_end = true
	for i in 2:
		await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		if scroll == chat_scroll:
			chat_to_end = false


# ---------- documents over the board ----------

# A sheet that takes the height of the window and scrolls if it has to.
func _document(width: int) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.118, 0.259, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var panel := PanelContainer.new()
	var w := minf(width, _view_width() - 16.0)
	var margin := 8.0 if mobile else 32.0
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -w / 2.0
	panel.offset_right = w / 2.0
	panel.offset_top = margin
	panel.offset_bottom = -margin
	panel.add_theme_stylebox_override("panel", _box(COL_SURFACE, COL_BORDER, 1, 0))
	ui.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := _vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(v, 16 if mobile else 28, 16 if mobile else 24))
	return v


# ---------- story conversations ----------

# Its own screen: whoever is talking, big, with how they feel; the talk so far; "next" or your answers.
func _build_story() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.118, 0.259, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var view := get_viewport().get_visible_rect().size
	var w := minf(880.0, view.x - (16.0 if mobile else 64.0))
	var h := view.y - 16.0 if mobile else minf(600.0, view.y - 64.0)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -w / 2.0
	panel.offset_right = w / 2.0
	panel.offset_top = -h / 2.0
	panel.offset_bottom = h / 2.0
	var style := _box(COL_SURFACE, COL_BORDER, 1, 0)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var log: Array = rules.story["log"]
	var speaker := ""
	var emo := ""
	for e in log:
		if e["who"] != "you" and e["who"] != "":
			speaker = e["who"]
			emo = e["emo"]
	# Before anyone has spoken, the one who is about to.
	if speaker == "":
		for op in Dialogue.SCENES[rules.story["id"]]["ops"]:
			if op["op"] == "line" and op["who"] != "" and op["who"] != "you":
				speaker = op["who"]
				break
	var body: BoxContainer = VBoxContainer.new() if mobile else HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	panel.add_child(body)
	if speaker != "":
		body.add_child(_story_portrait(speaker, emo, Dialogue.SCENES[rules.story["id"]]["place"]))
	var right := _vbox(0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var list := _vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(list, 18 if mobile else 28, 18 if mobile else 24))
	for i in log.size():
		list.add_child(_story_entry(log[i], i == log.size() - 1))
	var actions := _vbox(8)
	var foot := _padded(actions, 18 if mobile else 28, 16)
	foot.size_flags_vertical = Control.SIZE_SHRINK_END
	right.add_child(foot)
	if rules.story["wait"] == "choice":
		for c in rules.story_choices():
			actions.add_child(_answer_button(_story_text(c), _story_choose.bind(c["i"])))
	else:
		var next := _button(Loc.t("story.next"), _story_next, 200, "primary")
		next.size_flags_horizontal = Control.SIZE_SHRINK_END
		actions.add_child(next)
	_scroll_to_end(scroll)


# A conversation you lead (an interview for now): the story window, but the choices are yours to pick
# in any order, and how many questions are left is shown under them.
func _build_convo() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.118, 0.259, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var view := get_viewport().get_visible_rect().size
	var w := minf(880.0, view.x - (16.0 if mobile else 64.0))
	var h := view.y - 16.0 if mobile else minf(600.0, view.y - 64.0)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -w / 2.0
	panel.offset_right = w / 2.0
	panel.offset_top = -h / 2.0
	panel.offset_bottom = h / 2.0
	var style := _box(COL_SURFACE, COL_BORDER, 1, 0)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var who: String = rules.convo["who"]
	var body: BoxContainer = VBoxContainer.new() if mobile else HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	panel.add_child(body)
	body.add_child(_story_portrait(who, rules.convo.get("emo", ""), "meeting_room" if rules.convo["kind"] == "interview" else "office_day"))
	var right := _vbox(0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var list := _vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(list, 18 if mobile else 28, 18 if mobile else 24))
	var log: Array = rules.convo["log"]
	for i in log.size():
		var e: Dictionary = log[i]
		var said: String = Loc.render(e["key"], [], e["names"]) if e.has("key") else Loc.fill(e["ru"], e["en"], e["names"])
		list.add_child(_story_entry({"who": e["who"], "emo": "", "ru": said, "en": ""}, i == log.size() - 1))
	var actions := _vbox(8)
	var foot := _padded(actions, 18 if mobile else 28, 16)
	foot.size_flags_vertical = Control.SIZE_SHRINK_END
	right.add_child(foot)
	if rules.convo["left"] > 0:
		actions.add_child(_label(Loc.t("convo.left", [rules.convo["left"]]), 12, COL_MUTED))
	# In a talk, what you do about it ends the talk: it's set apart from the questions.
	var group := ""
	for c in rules.convo_choices():
		var kind: String = "act" if c.begins_with("a:") else ("ask" if c.begins_with("q:") else "")
		if kind != group and kind != "" and rules.convo["kind"] == "talk":
			actions.add_child(_label(Loc.t("convo.group." + kind), 12, COL_MUTED))
		group = kind
		actions.add_child(_answer_button(rules.convo_label(c), _convo_choose.bind(c)))
	_scroll_to_end(scroll)


func _convo_choose(c: String) -> void:
	rules.convo_choose(c)
	_render()


# The morning call: a tile per person, the one line they say, and what you can answer.
func _build_standup() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.118, 0.259, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var view := get_viewport().get_visible_rect().size
	var w := minf(960.0, view.x - (16.0 if mobile else 64.0))
	var h := view.y - 16.0 if mobile else minf(640.0, view.y - 64.0)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -w / 2.0
	panel.offset_right = w / 2.0
	panel.offset_top = -h / 2.0
	panel.offset_bottom = h / 2.0
	var style := _box(COL_SURFACE, COL_BORDER, 1, 0)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var right := _vbox(0)
	panel.add_child(right)
	var head := _vbox(4)
	head.add_child(_label(Loc.t("standup.title"), 22, COL_TEXT, false, true))
	head.add_child(_label(Loc.t("standup.hint_endless" if rules.endless() else ("standup.hint_cost" if rules.standup_cost() else "standup.hint_free")) + "   " + _attention_text(), 13, COL_MUTED, true))
	var head_box := _padded(head, 18 if mobile else 28, 16)
	head_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(head_box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 1 if mobile else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(grid, 18 if mobile else 28, 4))
	var lines: Array = rules.standup["lines"]
	for i in lines.size():
		grid.add_child(_standup_tile(lines[i], i))
	var foot := _padded(HBoxContainer.new(), 18 if mobile else 28, 16)
	foot.size_flags_vertical = Control.SIZE_SHRINK_END
	right.add_child(foot)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.get_child(0).add_child(gap)
	foot.get_child(0).add_child(_button(Loc.t("standup.close"), _standup_close, 200, "primary"))


func _standup_tile(line: Dictionary, i: int) -> Control:
	var p: String = line["who"]
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quiet: bool = line["topic"] == "quiet"
	var style := _box(COL_BG if quiet else COL_SURFACE, COL_BORDER if quiet else COL_FOCUS, 1, 14)
	style.set_corner_radius_all(12)
	tile.add_theme_stylebox_override("panel", style)
	var v := _vbox(8)
	tile.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_avatar(p, 40))
	var name := _label(Loc.person(p), 15, COL_TEXT, false, true)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name)
	v.add_child(top)
	v.add_child(_label(Loc.render(line["key"], line["args"], line["names"]), 15, COL_MUTED if quiet else COL_TEXT, true))
	if Loc.has_key(line["key"] + ".aside"):
		v.add_child(_label(Loc.t(line["key"] + ".aside"), 13, COL_FAINT, true))
	var options := rules.standup_reactions(i)
	for r in options:
		var b := _answer_button(Loc.render("standup.say." + r, [], line["names"]) + (_cost_mark(rules.cost("react")) if rules.standup_cost() else ""), _standup_react.bind(i, r))
		b.disabled = b.disabled or (rules.standup_cost() and not rules.can_afford(rules.cost("react")))
		v.add_child(b)
	if options.is_empty() and line["reacted"]:
		v.add_child(_label(Loc.render("standup.say." + line.get("said", rules.STANDUP_REACTIONS.get(line["topic"], "")), [], line["names"]), 13, COL_PRIMARY, true))
		v.add_child(_label(Loc.render(line["reply"], [], line["names"]), 14, COL_TEXT, true))
	return tile


func _standup_react(i: int, r: String = "") -> void:
	rules.standup_react(i, r)
	_render()


func _standup_close() -> void:
	rules.standup_close()
	_render()


# Where the scene happens, behind the portrait: art/backgrounds/<place>.png, cut to fit (the middle of the picture
# survives both the tall column on desktop and the strip on a phone), under a light wash so the name still reads.
const BACKGROUND_DIR := "res://art/backgrounds/"


func _background(place: String) -> Control:
	var path := BACKGROUND_DIR + place + ".png"
	if place == "" or not ResourceLoader.exists(path):
		return null
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = load(path)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(pic)
	var fade := Gradient.new()
	if mobile:
		fade.set_color(0, Color(COL_BG, 0.45))
		fade.set_color(1, Color(COL_BG, 0.75))
	else:
		fade.set_color(0, Color(COL_BG, 0.0))
		fade.set_color(1, Color(COL_BG, 0.92))
		fade.add_point(0.55, Color(COL_BG, 0.15))
	var wash_tex := GradientTexture2D.new()
	wash_tex.gradient = fade
	wash_tex.fill_from = Vector2(0, 0)
	wash_tex.fill_to = Vector2(1, 0) if mobile else Vector2(0, 1)
	var wash := TextureRect.new()
	wash.texture = wash_tex
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(wash)
	return stack


func _story_portrait(p: String, emo: String, place: String = "") -> Control:
	var box := PanelContainer.new()
	var style := _flat(COL_BG)
	if mobile:
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
	else:
		style.corner_radius_top_left = 16
		style.corner_radius_bottom_left = 16
	box.add_theme_stylebox_override("panel", style)
	box.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var back := _background(place)
	if back != null:
		box.add_child(back)
	var inner: BoxContainer = HBoxContainer.new() if mobile else VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.alignment = BoxContainer.ALIGNMENT_BEGIN if mobile else BoxContainer.ALIGNMENT_CENTER
	box.add_child(_padded(inner, 16 if mobile else 24, 16 if mobile else 24))
	var size := 64 if mobile else 168
	var tex := _portrait(p, emo)
	if tex != null and not mobile:
		# The whole picture, the mood in the pill under the name.
		var pic := TextureRect.new()
		pic.texture = tex
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(220, 220)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(pic)
	# Placeholder portrait until there's art: their letter, ringed in the colour of the mood.
	var ring := PanelContainer.new()
	var ring_style := _flat(EMO_COLORS.get(emo, COL_BORDER))
	ring_style.set_corner_radius_all(int(size / 2.0) + 6)
	ring_style.set_content_margin_all(5)
	ring.add_theme_stylebox_override("panel", ring_style)
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ring.add_child(_avatar(p, size, emo))
	if tex == null or mobile:
		inner.add_child(ring)
	var names := _vbox(4)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(names)
	var name := _label(Loc.person(p), 20 if mobile else 22, COL_TEXT, false, true)
	if not mobile:
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.custom_minimum_size.x = 240
	names.add_child(name)
	if emo != "" and Loc.has_key("emo." + emo):
		var tag := _pill(Loc.t("emo." + emo), COL_SURFACE, EMO_COLORS.get(emo, COL_MUTED))
		tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if mobile else Control.SIZE_SHRINK_CENTER
		names.add_child(tag)
	return box


func _story_text(e: Dictionary) -> String:
	return e["en"] if Loc.lang == "en" and e["en"] != "" else e["ru"]


# The latest line is the big one; what came before stays above it, quieter.
func _story_entry(e: Dictionary, latest: bool) -> Control:
	var text := _story_text(e)
	var size := 19 if latest else 15
	match e["who"]:
		"":
			return _label(text, size - 1, COL_MUTED if latest else COL_FAINT, true)
		"you":
			var row := HBoxContainer.new()
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gap.size_flags_stretch_ratio = 0.25
			row.add_child(gap)
			var bubble := PanelContainer.new()
			bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var style := _box(COL_SELECTED, COL_SELECTED, 0, 10)
			style.set_corner_radius_all(12)
			bubble.add_theme_stylebox_override("panel", style)
			bubble.add_child(_label(text, size, COL_PRIMARY if latest else Color(COL_PRIMARY, 0.7), true))
			row.add_child(bubble)
			return row
	var v := _vbox(2)
	v.add_child(_label(Loc.person(e["who"]), 13, COL_MUTED, false, true))
	v.add_child(_label(text, size, COL_TEXT if latest else COL_MUTED, true))
	return v


func _story_next() -> void:
	rules.story_next()
	_render()


func _story_choose(i: int) -> void:
	rules.story_choose(i)
	_render()


func _build_report() -> void:
	var w := rules.week()
	var v := _document(780)
	v.add_child(_label(Loc.t("report_title", [w + 1 - (rules.first_day() - 1) / 5]), 24, COL_TEXT, true, true))
	v.add_child(_label(Loc.t("report_hint"), 14, COL_MUTED, true))
	v.add_child(_spacer(4))
	for p in rules.team:
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
	if not rules.endless():
		v.add_child(_label(_keys_text(), 15, COL_WARN, true))
	if rules.survey.get("day", -1) == rules.day and not rules.endless():
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


# The end of an endless run: the record, the run in numbers, and what it earned.
func _run_record(v: VBoxContainer) -> void:
	var n := rules.done_periods()
	if n > best_before and best_before > 0:
		v.add_child(_label("★ " + Loc.t("run.new_record", [n]), 20, COL_STAR, true, true))
	else:
		v.add_child(_label(Loc.t("run.best", [best_periods]), 15, COL_MUTED, true))
	var st := rules.run_stats()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for key in ["days", "done", "good", "late", "hired", "quit", "fired", "upgrades", "race_wins"]:
		var cell := _vbox(0)
		cell.add_child(_label(str(st[key]), 26, COL_TEXT, false, true))
		cell.add_child(_label(Loc.t("run.stat." + key), 12, COL_MUTED))
		grid.add_child(cell)
	var earned: Array = rules.run_achievements()
	v.add_child(_section(Loc.t("run.achievements", [unlocked.size(), rules.ACHIEVEMENTS.size()])))
	if earned.is_empty():
		v.add_child(_label(Loc.t("run.no_achievements"), 14, COL_MUTED, true))
	for id in earned:
		v.add_child(_label("★ " + Loc.t("ach.%s.name" % id) + " · " + Loc.t("ach.%s.text" % id), 14, COL_WARN, true))


# The end of a chapter or of the run: Irina's verdict, the numbers, the team, and what comes next.
func _build_end() -> void:
	var v := _document(780)
	var info: Dictionary = C.CHAPTERS[rules.chapter - 1]
	if rules.endless():
		v.add_child(_section(Loc.t("period.results", [rules.period])))
	else:
		v.add_child(_section(Loc.t("chapter.results", [rules.chapter, Loc.t("chapter.%s.name" % info["id"])])))
	var good := rules.ending == "beloved" or rules.passed()
	v.add_child(_label(Loc.t("ending.%s.title" % rules.ending), 28, COL_GOOD if good else COL_DANGER, true, true))
	v.add_child(_label(Loc.t("ending.%s.text" % rules.ending), 16, COL_TEXT, true))
	if rules.endless():
		v.add_child(_label(Loc.t("period.survived", [rules.done_periods()]), 18, COL_TEXT, true, true))
		if not rules.last_race.is_empty() and rules.phase == "chapter_end":
			var race: Dictionary = rules.last_race
			v.add_child(_label(Loc.t("race.summary", [race["mine"], race["taras"], _rub(race["budget"])]), 16, COL_GOOD if race["mine"] >= race["taras"] else COL_DANGER, true))
		if rules.phase == "end":
			_run_record(v)
	else:
		v.add_child(_label(Loc.t("summary.hours", [rules.hours]), 15, COL_GOOD if rules.hours == 0 else COL_DANGER, true))
	var done := 0
	var late := 0
	for t in rules.tasks:
		if t["status"] == "done":
			done += 1
		if t["late"]:
			late += 1
	# (the end of an endless run has these in its own table)
	if not (rules.endless() and rules.phase == "end"):
		v.add_child(_label(Loc.t("summary.done", [done, late]), 15, COL_TEXT, true))
	var k := rules.key_status()
	if not rules.endless():
		v.add_child(_label(Loc.render("summary.results", [], {"good": k["good"], "total": rules.chapter_keys().size(), "boss": "@weight." + rules.boss_word()}), 15, COL_TEXT, true))
	var bank_names := PackedStringArray()
	for b in rules.banks:
		bank_names.append(Loc.t("bank." + b))
	v.add_child(_label(Loc.t("summary.banks", [", ".join(bank_names) if not bank_names.is_empty() else Loc.t("summary.no_banks")]), 15, COL_TEXT, true))
	if not rules.improved.is_empty():
		v.add_child(_label(Loc.t("summary.improved", [rules.improved.size()]), 15, COL_TEXT, true))
	if rules.ending in ["leader", "puppeteer"]:
		v.add_child(_label(Loc.t("promoted.yes" if rules.promoted else "promoted.no"), 15, COL_GOOD if rules.promoted else COL_MUTED, true))
	_adizes_block(v)
	# Marina's survey is the story's probation verdict; an endless run has its record instead.
	if not rules.survey.is_empty() and not rules.endless():
		_survey_block(v)
	v.add_child(_spacer(4))
	v.add_child(_section(Loc.t("summary.team")))
	for p in rules.team:
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
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	if rules.phase == "chapter_end":
		_next_chapter_block(v)
		if rules.next_chapter_ready():
			buttons.add_child(_button(Loc.t("period.start" if rules.endless() else "chapter.start", [(rules.period if rules.endless() else rules.chapter) + 1]), _start_next_chapter, 260, "primary"))
		else:
			buttons.add_child(_button(Loc.t("to_menu"), _to_title.bind(false), 260, "primary"))
	else:
		buttons.add_child(_button(Loc.t("again"), _to_title.bind(true), 260, "primary"))
	v.add_child(buttons)


# What the next chapter is about, or that it's still being made.
func _next_chapter_block(v: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_BG, COL_BORDER, 1, 16))
	var box := _vbox(6)
	card.add_child(box)
	box.add_child(_section(Loc.t("chapter.next")))
	if rules.endless():
		box.add_child(_label(Loc.t("period.title", [rules.period + 1]), 20, COL_TEXT, true, true))
		box.add_child(_label(Loc.t("period.next", [_rub(rules.last_race.get("budget", 0))]), 15, COL_TEXT, true))
		v.add_child(card)
		return
	var id: String = C.CHAPTERS[rules.chapter]["id"]
	box.add_child(_label(Loc.t("chapter.title", [rules.chapter + 1, Loc.t("chapter.%s.name" % id)]), 20, COL_TEXT, true, true))
	box.add_child(_label(Loc.t("chapter.%s.goal" % id), 15, COL_TEXT, true))
	if not rules.next_chapter_ready():
		box.add_child(_label(Loc.t("chapter.soon"), 14, COL_MUTED, true))
	v.add_child(card)


func _start_next_chapter() -> void:
	rules.start_next_chapter()
	_clear_selection()


func _to_title(setup: bool) -> void:
	rules.phase = "title"
	setup_open = setup
	_render()


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

# Art, where there is some: art/portraits/<who>_<emotion>.png, falling back to <who>_neutral.png.
# Small avatars show only the face, cut out as a circle; PORTRAIT_FACE says where the face is (a square,
# in fractions of the picture). No picture yet: the coloured circle with a letter.
const PORTRAIT_DIR := "res://art/portraits/"
const PORTRAIT_FACE := {
	"gena": Rect2(0.33, 0.03, 0.5, 0.547), "alex": Rect2(0.18, 0.06, 0.62, 0.517), "vika": Rect2(0.32, 0.03, 0.52, 0.476), "marina": Rect2(0.27, 0.08, 0.46, 0.503),
	"dima": Rect2(0.17, 0.1, 0.66, 0.604), "taras": Rect2(0.18, 0.05, 0.6, 0.556), "boss": Rect2(0.12, 0.05, 0.62, 0.517),
}
# A character needs only a few pictures: an emotion without its own falls back to the nearest one there is.
const PORTRAIT_NEAREST := {
	"tired": ["sad"], "worried": ["sad"], "embarrassed": ["sad"], "angry": ["annoyed"],
	"excited": ["happy"], "sarcastic": ["happy", "annoyed"],
}
const PORTRAIT_FACE_DEFAULT := Rect2(0.2, 0.05, 0.6, 0.6)
const FACE_SHADER := """
shader_type canvas_item;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, region.xy + UV * region.zw);
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(c.rgb, c.a * (1.0 - smoothstep(0.47, 0.5, d)));
}
"""
var portrait_cache := {}
var face_shader: Shader


func _portrait(p: String, emo: String = "") -> Texture2D:
	var key := p + "_" + emo
	if not portrait_cache.has(key):
		var found: Texture2D = null
		var names: Array = []
		for e in ([emo] if emo != "" else []) + PORTRAIT_NEAREST.get(emo, []) + ["neutral"]:
			names.append(p + "_" + e)
		for name in names:
			var path: String = PORTRAIT_DIR + name + ".png"
			if ResourceLoader.exists(path):
				found = load(path)
				break
		portrait_cache[key] = found
	return portrait_cache[key]


func _face(p: String, size: int, emo: String = "") -> Control:
	var tex := _portrait(p, emo)
	if tex == null:
		return null
	if face_shader == null:
		face_shader = Shader.new()
		face_shader.code = FACE_SHADER
	var r: Rect2 = PORTRAIT_FACE.get(p, PORTRAIT_FACE_DEFAULT)
	var mat := ShaderMaterial.new()
	mat.shader = face_shader
	mat.set_shader_parameter("region", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	var pic := TextureRect.new()
	pic.texture = tex
	pic.material = mat
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.custom_minimum_size = Vector2(size, size)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


func _avatar(p: String, size: int, emo: String = "") -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(size, size)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := _flat(AVATAR_COLORS.get(p, HIRE_COLORS[absi(p.hash()) % HIRE_COLORS.size()] if p.begins_with("hire") else COL_MUTED))
	style.set_corner_radius_all(int(size / 2.0))
	box.add_theme_stylebox_override("panel", style)
	var name := Loc.t("you") if p == "me" else Loc.person(p)
	box.tooltip_text = name
	var face := _face(p, size, emo)
	if face != null:
		style.bg_color = style.bg_color.lerp(COL_SURFACE, 0.75)
		box.add_child(face)
		return box
	var l := _label(name.substr(0, 1).to_upper(), int(size * 0.46), COL_SURFACE, false, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	return box


func _cat_icon(cat: String) -> Texture2D:
	var path := ICON_DIR + "cat_" + cat + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


func _pill(text_value: String, fg: Color, bg: Color, icon: Texture2D = null) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _flat(bg)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", style)
	if icon == null:
		chip.add_child(_label(text_value, 11, fg, false, true))
		return chip
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var pic := TextureRect.new()
	pic.texture = icon
	pic.modulate = fg
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(12, 12)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	row.add_child(_label(text_value, 11, fg, false, true))
	return chip


func _section(text_value: String) -> Label:
	return _label(text_value.to_upper(), 11, COL_MUTED, false, true)


func _label(text_value: String = "", size: int = BASE_FONT, color: Color = COL_TEXT, wrap: bool = false, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", _fs(size))
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
	b.custom_minimum_size = Vector2(min_width, 44 if mobile else 34)
	b.add_theme_font_size_override("font_size", _fs(14))
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
	b.pressed.connect(func(): cue = "click")
	b.pressed.connect(action)
	if action.get_method() in HELD_WHILE_ASKED and _waiting_for_answer():
		b.disabled = true
		b.tooltip_text = Loc.t("answer_first")
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
