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
const CHAT_W := 350
const TOP_H := 50
# Base sizes the screen is laid out for: a desktop, or a phone on its side, which gets the same board
# drawn tighter. A phone held upright only asks to be turned: the board is wide.
const DESKTOP_SIZE := Vector2i(1280, 800)
const COMPACT_SIZE := Vector2i(880, 420)
const PORTRAIT_SIZE := Vector2i(430, 860)
# Below this (in CSS pixels on the web, window pixels elsewhere) the desktop layout gets too small to read.
const DESKTOP_MIN := Vector2(900, 560)

# The office: a whiteboard on a grey wall, graphite bars round it like a laptop's, stickies on the board.
const COL_BG := Color("d9dcd8") # the wall behind the board
const COL_SURFACE := Color("ffffff")
const COL_BOARD := Color("fbfbf8") # the whiteboard
const COL_FRAME := Color("b9bec4") # its aluminium frame
const COL_COLUMN := Color("eceee9")
const COL_BORDER := Color("c9cdd2")
const COL_TEXT := Color("2b2f36")
const COL_MUTED := Color("555b63")
const COL_FAINT := Color("8c939b")
const COL_PRIMARY := Color("1f4fa3") # blue marker
const COL_PRIMARY_HOVER := Color("2a5fbd")
const COL_ACCENT := Color("ffd54a") # the main button, the points
const COL_ACCENT_HOVER := Color("ffdf70")
const COL_SELECTED := Color("e3ecfa")
const COL_FOCUS := Color("1f4fa3")
const COL_TOPBAR := Color("2d3138")
const COL_DANGER := Color("c0392b") # red marker
const COL_WARN := Color("a86200")
const COL_GOOD := Color("2f7a3a")
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
const COL_GAIN := Color("2f9a4a") # today's part of a progress bar
const COL_STAR := Color("e0a21b")
# On the graphite bars.
const COL_ON_TOP := Color("f4f4f2")
const COL_ON_TOP_MUTED := Color("c3c8cf")
const COL_ON_TOP_GOOD := Color("8fe3a7")
const COL_ON_TOP_DANGER := Color("ff9e8f")
# How someone feels in a story conversation: the ring around their portrait and the tag under it.
const EMO_COLORS := {
	"happy": Color("2f7a3a"), "excited": Color("e0a21b"), "annoyed": Color("c0392b"), "angry": Color("9b2a1e"),
	"tired": Color("555b63"), "sad": Color("1f4fa3"), "worried": Color("a86200"), "embarrassed": Color("c45a8c"),
	"sarcastic": Color("6554c0"),
}

const MOOD_COLORS := {"happy": COL_GOOD, "good": COL_GOOD, "neutral": COL_MUTED, "down": COL_WARN, "angry": COL_DANGER}
const ENERGY_COLORS := {"fresh": COL_GOOD, "ok": COL_MUTED, "tired": COL_WARN, "drained": COL_DANGER}
# Each kind of work has its sticky paper: the ink for its icon and marks, then the paper.
const CAT_COLORS := {
	"pipelines": [Color("2e7a33"), Color("c3efb6")],
	"infra": [Color("2858a8"), Color("b9dcff")],
	"portal": [Color("7a5d00"), Color("fff07a")],
	"support": [Color("a8335a"), Color("ffc2d4")],
}
# Category icons, drawn white in art/icons/cat_<cat>.svg and tinted with the sticky's ink.
const ICON_DIR := "res://art/icons/"
const AVATAR_COLORS := {
	"alex": Color("3d7fc4"), "vika": Color("c8603f"), "gena": Color("2f8f5b"), "dima": Color("6554c0"),
	"boss": Color("8a3f5f"), "marina": Color("a8781f"), "taras": Color("55606e"), "me": Color("5a4a8c"), "palych": Color("8777d9"), "oleg": Color("5e6c84"), "buyer": Color("403294"),
	"contractor": Color("7a869a"), "stas": Color("c0392b"), "olga": Color("8777d9"), "boris": Color("5e6c84"),
}
# The magnet a person's photo hangs on.
const MAGNETS := [Color("d6402b"), Color("2a6fd1"), Color("e0a21b"), Color("2f9a4a"), Color("8e44ad"), Color("e67e22")]

const HIRE_COLORS := [Color("2a8fa8"), Color("d9673f"), Color("3f9e6a"), Color("7a6fc4"), Color("c48a1f"), Color("3d7fc4")]
const BANK_COLORS := {"happy": COL_GOOD, "fine": COL_MUTED, "unhappy": COL_WARN, "leaving": COL_DANGER}

var rules := Rules.new()
var ui: Control
var selected := -1
var font_bold: Font
var font_hand: Font
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
# A small screen (a phone on its side): the same board, tighter, and the messenger slides over it.
var compact := false
var chat_open := false
# A phone held upright: only the note to turn it.
var portrait := false
# A sticky picked on the board waits for a column to go to: its new owner, or (pairing) the helper.
var pairing := false
# A sticky is being dragged: let go anywhere but a column and it goes back.
var dragging := false
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
# Places on screen the first month's coach can point at, by name; rebuilt with every render.
var anchors := {}
var up_branch := "" # the upgrade branch shown on the phone
# Where the chat was left. Anything new in it (a message, a question, answer buttons) brings it to the
# bottom; otherwise it stays where you scrolled it.
var chat_pos := 0
var chat_seen := ""
var chat_to_end := false # a scroll to the bottom is on its way; until it lands, the bottom is where the chat is
const HELD_WHILE_ASKED := ["_helper", "_end_day", "_visit_boss", "_unassign", "_talk_to", "_sit", "_reject_candidate",
	"_prioritize", "_pick", "_interview", "_intervene", "_hire", "_fire", "_decline", "_days", "_ask_stay"]
var press_pos := Vector2.ZERO
# The setup screen before a run, and what's picked on it (remembered between runs).
var setup_open := false
var pick_boss := "random"
var pick_profile: String = C.DEFAULT_PROFILE
var pick_tips := true
# "endless" for everyone; the story runs only in a dev build (the editor, tools/test.sh).
var pick_mode := "endless"
# The open conversation's list and scroll, and who spoke last in it (to group their lines).
var chat_list: VBoxContainer
var chat_scroll: ScrollContainer
var chat_last := ""


func _ready() -> void:
	Loc.lang = "ru" if OS.get_locale_language() == "ru" else "en"
	# Bundled fonts (the web build has no system fonts): Nunito for reading, Caveat for marker on the board,
	# a few symbols from DejaVu Sans behind both.
	var regular := _weight(load("res://fonts/Nunito.ttf"), 600)
	font_bold = _weight(load("res://fonts/Nunito.ttf"), 800)
	font_hand = _weight(load("res://fonts/Caveat.ttf"), 700)
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


# One weight of a variable font.
func _weight(base: Font, wght: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	# Neither font has the marks we use (dots, stars, ticks, arrows), and a browser lends none.
	f.fallbacks = [load("res://fonts/Symbols.ttf")]
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): wght}
	return f


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


# Upright: the note to turn the phone. Small (a phone on its side): the compact board. Windows and the
# web canvas are in device pixels, so a 3x phone or a Retina laptop is measured in points.
func _apply_layout_mode() -> bool:
	var size := Vector2(get_window().size) / maxf(1.0, DisplayServer.screen_get_scale())
	var up := size.x < size.y
	var small := up or size.x < DESKTOP_MIN.x or size.y < DESKTOP_MIN.y
	var target := PORTRAIT_SIZE if up else (COMPACT_SIZE if small else DESKTOP_SIZE)
	if up == portrait and small == compact and get_window().content_scale_size == target:
		return false
	portrait = up
	compact = small
	get_window().content_scale_size = target
	return true


func _on_resize() -> void:
	if _apply_layout_mode() and ui:
		_render()


# ---------- actions ----------

# A card's own window: what it is, who asked, and everything that can be done with it.
func _select(uid: int) -> void:
	selected = uid
	pairing = false
	deal_from = -1
	window = "task"
	_render()


# A sticky picked off the board, to stick it on someone's column next (or, pairing, to sit a helper with its owner).
func _pick_sticky(uid: int, pair: bool) -> void:
	if selected == uid and window == "":
		_clear_selection()
		return
	selected = uid
	pairing = pair
	deal_from = -1
	window = ""
	_render()


# The column someone was tapped on while a sticky waits: it goes to them, or they sit in as the pair.
func _drop_on(p: String) -> void:
	if pairing:
		var uid := selected
		_clear_selection()
		rules.set_helper(uid, p)
		_render()
	else:
		_pick(p)


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
	chat_open = true
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
		return _anchor(_button(Loc.t("to_end" if rules.day >= rules.last_day() else "next_day"), _next, width, "primary"), "day_button")
	var morning := rules.step == "triage"
	var b := _button(Loc.t("start_work" if morning else "end_day"), _start_work if morning else _end_day, width, "primary")
	b.disabled = rules.phase != "plan" or not rules.pending.is_empty()
	_anchor(b, "day_button")
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
	if not C.PROFILE_KINDS.has(pick_profile):
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
	_clear_selection()
	_render()


func _open_setup(open: bool) -> void:
	setup_open = open
	# Opened afresh, it starts from the top; picks inside it keep the place.
	scroll_memory.erase("setup")
	_render()


func _toggle_tips() -> void:
	pick_tips = not pick_tips
	_render()


func _pick_option(kind: String, value: String) -> void:
	if kind == "boss":
		pick_boss = value
	else:
		pick_profile = value
	_render()


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
	pairing = false
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
		_play(_sound_for_changes())
	# Every action ends in a render, so this keeps the save one step behind the player at most.
	if rules.phase == "end" or (rules.phase == "chapter_end" and not rules.next_chapter_ready()):
		Rules.delete_save()
	elif rules.phase != "title":
		rules.save_game()
	cue = ""
	anchors.clear()
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
	if portrait:
		_build_turn_phone()
		return
	if rules.phase == "title":
		if setup_open:
			_build_setup()
		else:
			_build_title()
		_let_touches_through(ui)
		_restore_scrolls()
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
		chat_open = true
	asked_seen = asked_key
	# A pushback is answered in the task's window, a reloaded game included.
	if not rules.pending.is_empty() and window != "task":
		selected = rules.pending["uid"]
		window = "task"
		deal_from = maxi(0, rules.history.size() - 2)
		deal_who = rules.pending["p"]
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
	if window != "" and rules.phase in ["plan", "event", "standup", "evening"]:
		_build_window()
	if menu_open:
		_build_menu_overlay()
	_let_touches_through(ui)
	_restore_scrolls()
	_coach.call_deferred()
	_juice.call_deferred(before, juice_before)
	_check_progress()


# New achievements pop up as they come and are kept for good; so is the longest endless run.
func _check_progress() -> void:
	if rules.phase in ["title", "draft"]:
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

# The top bar is graphite, a touch warmer at midday and towards dusk in the evening.
func _sky() -> Color:
	match _moment():
		"midday":
			return Color("33383f")
		"evening":
			return Color("2a2836")
	return COL_TOPBAR


func _moment() -> String:
	if rules.phase in ["evening", "report", "review"] or rules.step == "evening":
		return "evening"
	if rules.step == "work":
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
		t.chain().tween_callback(_unflash.bind(card, calm))


# (untyped: the card may be gone by the time the tween ends)
func _unflash(card, calm: StyleBox) -> void:
	if is_instance_valid(card):
		card.add_theme_stylebox_override("panel", calm)


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
const KEY_ART := "res://art/key_art.png"
const COL_NIGHT := Color("0b1a33")


func _build_title() -> void:
	var art: Texture2D = load(KEY_ART) if ResourceLoader.exists(KEY_ART) else null
	if art == null:
		_build_title_plain()
		return
	var view := get_viewport().get_visible_rect().size
	var pic := TextureRect.new()
	pic.texture = art
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(pic)
	if compact:
		ui.add_child(_title_fade([0.3, 0.55, 1.0], [0.0, 0.82, 0.97]))
	else:
		ui.add_child(_title_fade([0.35, 0.65, 1.0], [0.0, 0.8, 0.96]))
	var margin := 24.0 if compact else 56.0
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
		var sticker := _logo(96 if compact else 84)
		sticker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(sticker)
	_menu_page(v, false)


# The menu itself, on the title screen or over the game: the list, or one of its pages.
func _menu_page(v: VBoxContainer, in_game: bool) -> void:
	match menu_page:
		"settings":
			_menu_settings(v)
		"about":
			v.add_child(_menu_title(Loc.t("menu.about")))
			v.add_child(_label(Loc.t("about.text"), 15 if compact else 16, Color(1, 1, 1, 0.85), true))
			v.add_child(_spacer(2))
			v.add_child(_menu_item(Loc.t("menu.back"), _menu_go.bind("")))
		"confirm_new":
			v.add_child(_menu_title(Loc.t("menu.new")))
			v.add_child(_label(Loc.t("confirm.new"), 15 if compact else 16, Color(1, 1, 1, 0.85), true))
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
	return _label(text_value, 24 if compact else 28, COL_ON_TOP, false, true)


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
	b.add_theme_font_size_override("font_size", _fs(22 if compact else 24))
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
	var style := _box(COL_NIGHT, COL_NIGHT, 0, 28 if compact else 36)
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
	head.add_child(_hand(Loc.t("setup.title"), 40, COL_PRIMARY))
	v.add_child(_label(Loc.t("setup.boss_head"), 17, COL_TEXT, true, true))
	var bosses: Array = C.BOSS_KINDS.duplicate()
	bosses.append("random")
	v.add_child(_option_grid("boss", bosses, pick_boss, width))
	v.add_child(_spacer(6))
	v.add_child(_label(Loc.t("setup.me_head"), 17, COL_TEXT, true, true))
	var kinds: Array = C.PROFILE_KINDS
	if not kinds.has(pick_profile):
		pick_profile = C.DEFAULT_PROFILE
	v.add_child(_option_grid("me", kinds, pick_profile, width))
	v.add_child(_spacer(2))
	var tips_row := HBoxContainer.new()
	tips_row.add_theme_constant_override("separation", 12)
	v.add_child(tips_row)
	# Marina shows the new lead around for the first month.
	tips_row.add_child(_button(Loc.t("setup.run_tips_on" if pick_tips else "setup.run_tips_off"), _toggle_tips, 0, "chosen" if pick_tips else ""))
	tips_row.add_child(_label(Loc.t("setup.run_tips_hint"), 13, COL_MUTED, true))
	v.add_child(_spacer(6))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button(Loc.t("setup.start"), _start_run, 160 if compact else 260, "primary"))
	buttons.add_child(_button(Loc.t("setup.back"), _open_setup.bind(false), 0))
	if compact:
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


# When the month closes: Irina splits the budget, and the race with Taras is counted.
func _budget_when() -> String:
	var left: int = rules.last_day() - rules.day + 1
	return Loc.t("money.budget_tomorrow") if left <= 1 else Loc.t("money.budget_in", [left])


# The balance on the top bar turns red when the salaries still due this month don't fit in it; a click opens the money window.
func _money_label(size: int, bold: bool) -> Label:
	var l := _label(_rub(rules.money) if compact else _money_text(), size, COL_ON_TOP_DANGER if rules.money_at_budget() < 0 else COL_ON_TOP, false, bold)
	l.tooltip_text = Loc.t("money.open")
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.gui_input.connect(func(event: InputEvent):
		if _tapped(event):
			_open_window.call_deferred("money"))
	juice_nodes["money"] = l
	return l


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
	head.add_child(_hand(Loc.t("draft.title"), 40, COL_PRIMARY))
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
	var sum := Loc.t("draft.sum", [rules.draft_picked.size(), _rub(month), _rub(rules.PERIOD_BUDGET)])
	v.add_child(_label(sum, 16, COL_DANGER if month > rules.PERIOD_BUDGET else COL_TEXT, true, true))
	var buttons := _flow(12, 12)
	var go := _button(Loc.t("draft.start"), _draft_start, 160 if compact else 260, "primary")
	go.disabled = rules.draft_picked.is_empty()
	buttons.add_child(go)
	var again := _button(Loc.t("draft.reroll", [rules.draft_rerolls]), _draft_reroll, 0)
	again.disabled = rules.draft_rerolls <= 0
	buttons.add_child(again)
	if compact:
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
	card.add_theme_stylebox_override("panel", _paper(COL_SURFACE, on))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := _vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(_photo(id, 40, false))
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
	v.add_child(_hand(Loc.t("draft.picked"), 24, COL_PRIMARY) if on else _label(Loc.t("draft.pick"), 13, COL_FAINT))
	card.gui_input.connect(_on_draft_input.bind(id))
	return card


func _on_draft_input(event: InputEvent, id: String) -> void:
	if _tapped(event):
		_draft_toggle.call_deferred(id)


func _draft_toggle(id: String) -> void:
	_play("select")
	rules.draft_toggle(id)
	_render()


# A tap, not the start of a scroll: let go close to where the finger (or the mouse) went down.
func _tapped(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return false
	if event.pressed:
		press_pos = event.global_position
		return false
	return event.global_position.distance_to(press_pos) < 12.0


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
		card.add_theme_stylebox_override("panel", _paper(COL_STICKY if on else COL_STICKY_PALE, on))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var key := "setup.%s.%s" % [kind, value]
		var text := _vbox(4)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(_label(Loc.t(key), 16, COL_TEXT, true, true))
		text.add_child(_label(Loc.t(key + ".desc"), 14, COL_MUTED, true))
		card.add_child(text)
		card.gui_input.connect(_on_option_input.bind("boss" if kind == "boss" else "profile", value))
		grid.add_child(card)
	return grid


func _on_option_input(event: InputEvent, kind: String, value: String) -> void:
	if _tapped(event):
		cue = "select"
		_pick_option.call_deferred(kind, value)


func _build_office() -> void:
	var v := _vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(v)
	v.add_child(_top_bar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	v.add_child(body)
	body.add_child(_board_area())
	if not compact:
		body.add_child(_messenger())
	elif chat_open:
		_chat_drawer()


# The graphite bar over the board: the day, what you have (points, money, the race), the ways into
# hiring, upgrades and the clients, the chat on a small screen, and the menu.
func _top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size.y = 44 if compact else TOP_H
	var style := _flat(_sky())
	style.content_margin_left = 10 if compact else 16
	style.content_margin_right = 8 if compact else 12
	bar.add_theme_stylebox_override("panel", style)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8 if compact else 12)
	bar.add_child(top)
	top.add_child(_logo(22 if compact else 26))
	top.add_child(_label(_day_label(), 14 if compact else 16, COL_ON_TOP, false, true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var size := 13 if compact else 15
	var points := _attention_label(size)
	juice_nodes["points"] = points
	top.add_child(points)
	top.add_child(_money_label(size, true))
	var race := _race_label(size)
	juice_nodes["race"] = race
	top.add_child(race)
	if not rules.chapter_keys().is_empty():
		var k := rules.key_status()
		top.add_child(_label(Loc.render("keys_short" if compact else "keys_label", [], {"good": k["good"], "total": rules.chapter_keys().size()}), size, COL_ON_TOP))
	# A counter means there's something to do in there, and only then: CVs waiting, upgrades you can
	# afford, clients who are unhappy.
	top.add_child(_nav_button("hire", Loc.t("hire.section"), _badge(rules.candidates.size())))
	top.add_child(_nav_button("upgrades", Loc.t("up.section"), _badge(_fresh_upgrades())))
	var unhappy := 0
	for bank in rules.banks:
		if rules.bank_word(bank) in ["unhappy", "leaving"]:
			unhappy += 1
	top.add_child(_nav_button("clients", Loc.t("nav.clients"), _badge(unhappy)))
	if compact:
		var unread := 0
		var asks := false
		for th in _contacts():
			unread += _unread(th)
			asks = asks or _letters_in(th) > 0 or _asked_thread() == th
		top.add_child(_nav_button("chat", Loc.t("tab.chat"), "!" if asks else _badge(unread)))
	top.add_child(_button(Loc.t("menu.button"), _open_menu, 0, "on_top"))
	return bar


# "Понедельник, неделя 2", and from chapter two on, which chapter.
func _day_label() -> String:
	var text := Loc.t(rules.day_key().substr(1))
	if rules.chapter == 0:
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
	_anchor(l, "points")
	l.tooltip_text = Loc.t("attention_tip")
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _attention_text() -> String:
	if rules.sick_today:
		return Loc.t("you.sick_today")
	var dots := ""
	for i in rules.max_attention():
		dots += "●" if i < rules.attention else "○"
	if compact:
		return dots
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
	card.add_theme_stylebox_override("panel", _box(COL_SELECTED if target else Color(0, 0, 0, 0), COL_FOCUS if target else Color(0, 0, 0, 0), 2 if target else 0, 2))
	var v := _vbox(5)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(_photo(p, 56, false))
	var names := _vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(names)
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
	if rules.newbie(p):
		state.add_child(_pill(Loc.t("newbie_label.alone"), COL_PRIMARY, COL_SELECTED))
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
	var fire := _button(Loc.t("fire.button"), _fire.bind(p), 0, "subtle")
	fire.disabled = fire.disabled or not rules.can_fire(p)
	fire.custom_minimum_size.y = 26
	fire.add_theme_font_size_override("font_size", _fs(12))
	fire.add_theme_color_override("font_color", COL_DANGER)
	v.add_child(talk)
	v.add_child(fire)
	return card


# You know your own strengths; they matter when you do the work or step into someone's.
func _me_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
	var v := _vbox(6)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(_photo("me", 56, false))
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
	var after := rules.money_at_budget(rules.HIRE_FEE, int(round(rules.salary(id) / 4.0)))
	if after < 0:
		v.add_child(_label(Loc.t("money.would_sink", [_rub(after)]), 13, COL_DANGER, true))
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
	if window == "money":
		_money_window(_modal(Loc.t("money.window.title"), Loc.t("money.window.hint", [_budget_when(), _rub(rules.payroll())]), minf(640.0, view.x - 16.0), true, true))
		return
	if window.begins_with("person:"):
		var p := window.substr(7)
		if not rules.people.has(p):
			window = ""
			return
		_modal(Loc.person(p), "", minf(460.0, view.x - 16.0), false, true).add_child(_person_card(p))
	elif window == "hire":
		var hint := Loc.t("money.fee", [_rub(rules.HIRE_FEE)])
		var body := _modal(Loc.t("hire.section"), hint + "   " + _money_text() + "   " + _attention_text(), minf(980.0, view.x - 16.0), true, true)
		if rules.candidates.is_empty():
			body.add_child(_label(Loc.t("win.no_candidates"), 14, COL_MUTED, true))
		var grid := GridContainer.new()
		grid.columns = 1 if compact else 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(grid)
		for c in rules.candidates:
			var card := _candidate_card(c)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(card)
	elif window == "company":
		var body := _modal(Loc.t("nav.clients_title"), _attention_text(), minf(560.0, view.x - 16.0), false, true)
		_clients(body)
	elif window == "me":
		_modal(Loc.t("me_card"), "", minf(460.0, view.x - 16.0), false, true).add_child(_me_card())
	elif window == "done":
		var body := _modal(Loc.t("col.done"), "", minf(760.0, view.x - 16.0), true, true)
		var grid := GridContainer.new()
		grid.columns = 1 if compact else 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(grid)
		for t in _lanes()["done"]:
			grid.add_child(_sticky(t, "done"))


# A dimmed screen and a panel with a title, a line under it and a close button; returns where the content goes.
func _modal(title: String, hint: String, w: float, wide_scroll: bool, fit: bool = false) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.13, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if _tapped(event):
			_close_window.call_deferred())
	ui.add_child(dim)
	var view := get_viewport().get_visible_rect().size
	# Small windows (fit) grow to what's in them, up to the screen; big ones take the screen.
	var h := view.y - (16.0 if compact else 64.0)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -w / 2.0
	panel.offset_right = w / 2.0
	panel.offset_top = -h / 2.0
	panel.offset_bottom = h / 2.0
	var style := _box(COL_BOARD, COL_FRAME, 5, 0)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var right := _vbox(0)
	panel.add_child(right)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var titles := _vbox(4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var big := _hand(title, 30 if compact else 36, COL_PRIMARY)
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(big)
	if hint != "":
		titles.add_child(_label(hint, 13, COL_MUTED, true))
	head.add_child(titles)
	var close := _button(Loc.t("up.close"), _close_window, 0, "subtle")
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.visible = rules.pending.is_empty()
	head.add_child(close)
	var head_box := _padded(head, 18 if compact else 28, 16)
	head_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(head_box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if wide_scroll or compact else ScrollContainer.SCROLL_MODE_AUTO
	right.add_child(scroll)
	# A window opened over another keeps its own scroll, so the one below stays where it was.
	scrolls["window_top" if scrolls.has("window") else "window"] = scroll
	var body := _vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := _padded(body, 18 if compact else 28, 4)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	right.add_child(_spacer(12))
	if fit:
		# Once laid out, shrink the panel around its content, keeping it centred.
		var shrink := _fit_modal.bind(panel, head_box, pad, h)
		pad.minimum_size_changed.connect(shrink)
		shrink.call_deferred()
	return body


# (untyped: the window may be gone by the time its size settles)
func _fit_modal(panel, head_box, pad, h: float) -> void:
	if not (is_instance_valid(panel) and is_instance_valid(head_box) and is_instance_valid(pad)):
		return
	var ph: float = minf(h, head_box.get_combined_minimum_size().y + pad.get_combined_minimum_size().y + 12.0)
	panel.offset_top = -ph / 2.0
	panel.offset_bottom = ph / 2.0


# Upgrades that came within reach since you last looked at the tree; what you could already afford
# when the session began isn't news.
func _fresh_upgrades() -> int:
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


func _badge(n: int) -> String:
	return str(n) if n > 0 else ""


func _nav_button(name: String, text_value: String, badge: String) -> Control:
	var action: Callable = _open_upgrades if name == "upgrades" else (_toggle_chat if name == "chat" else _open_window.bind("company" if name == "clients" else name))
	var b := _button("" if compact else text_value, action, 40 if compact else 0, "on_top")
	_anchor(b, "chat_button" if name == "chat" else "nav_" + name)
	b.tooltip_text = text_value
	b.custom_minimum_size.y = 40 if compact else 34
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var path := ICON_DIR + "nav_" + name + ".svg"
	if ResourceLoader.exists(path):
		b.icon = load(path)
		b.expand_icon = false
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if compact else HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", 20)
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(state, COL_ON_TOP)
		b.add_theme_constant_override("h_separation", 8)
	if badge == "":
		return b
	# A round counter hanging off the button's top right corner, as in games.
	var dot := PanelContainer.new()
	var ds := _flat(COL_STAR if badge == "!" else COL_DANGER)
	ds.set_corner_radius_all(10)
	ds.content_margin_left = 6
	ds.content_margin_right = 6
	dot.add_theme_stylebox_override("panel", ds)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_child(_label(badge, 11, COL_SURFACE, false, true))
	dot.anchor_left = 1.0
	dot.anchor_right = 1.0
	# Inside the bar: the window edge would cut off anything sticking out above the button.
	dot.offset_left = -14
	dot.offset_top = -1
	dot.grow_horizontal = Control.GROW_DIRECTION_END
	b.add_child(dot)
	return b


# ---------- the upgrade tree ----------

func _open_upgrades() -> void:
	for id in C.UPGRADES:
		if _upgrade_affordable(id):
			upgrades_seen[id] = true
	_open_window("upgrades")


func _buy_upgrade(id: String) -> void:
	rules.buy_upgrade(id)
	window = "upgrades"
	_render()


func _build_upgrades() -> void:
	var view := get_viewport().get_visible_rect().size
	var w := view.x - (16.0 if compact else 64.0)
	var body := _modal(Loc.t("up.title"), Loc.t("up.hint") + "   " + _money_text() + "   " + _attention_text(), w, compact)
	var ids: Array = C.UPGRADES.keys()
	if compact:
		if not C.UPGRADE_BRANCHES.has(up_branch):
			up_branch = C.UPGRADE_BRANCHES[0]
		var tabs := _flow(4, 4)
		body.add_child(tabs)
		for branch in C.UPGRADE_BRANCHES:
			var b := _button(Loc.t("up.branch." + branch), _pick_branch.bind(branch), 0, "chosen" if up_branch == branch else "subtle")
			tabs.add_child(b)
		ids = ids.filter(func(id): return C.UPGRADES[id]["branch"] == up_branch)
	body.add_child(_cork_board(ids, w - (40.0 if compact else 80.0)))


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
	if compact:
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
		if not compact:
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
		if _tapped(event):
			_open_window.call_deferred("upgrade:" + id))
	var v := _vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(v)
	var faint: bool = state == "locked"
	var name := _label(Loc.t("up.%s.name" % id), 13 if compact else 14, COL_FAINT if faint else COL_TEXT, true, true)
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
		var after := rules.money_at_budget(rules.upgrade_price(id))
		if after < 0:
			v.add_child(_label(Loc.t("money.would_sink", [_rub(after)]), 13, COL_DANGER, true))
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


# The endless run's clients: who pays the company what, whether the team has room for more, and the
# banks you could go and win over.
func _clients(v: VBoxContainer) -> void:
	v.add_child(_label(Loc.t("clients.load", [_days(rules.daily_load()), _days(rules.team_capacity())]), 14, COL_TEXT, true))
	v.add_child(_section(Loc.t("chainer.banks")))
	for b in rules.banks:
		var word := rules.bank_word(b)
		var row := _flow(6, 0)
		row.add_child(_label(Loc.t("bank." + b), 15, COL_TEXT, false, true))
		row.add_child(_label("· " + Loc.t("bank_mood." + word), 14, BANK_COLORS[word]))
		v.add_child(row)
		v.add_child(_label(Loc.t("clients.fee", [_rub(rules.bank_fee(b))]), 13, COL_MUTED, true))
	v.add_child(_label(Loc.t("clients.revenue", [_rub(rules.revenue())]), 13, COL_TEXT, true))
	var open := rules.prospects()
	if open.is_empty():
		return
	v.add_child(_spacer(4))
	v.add_child(_section(Loc.t("clients.prospects")))
	if rules.pitched_this_week():
		v.add_child(_label(Loc.t("clients.pitched"), 13, COL_MUTED, true))
	for b in open:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var info := _vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(_label(Loc.t("bank." + b), 15, COL_TEXT, false, true))
		info.add_child(_label(Loc.t("clients.prospect", [_days(rules.BANK_WORK), _rub(rules.BANK_FEE)]), 13, COL_MUTED, true))
		var go := _button(Loc.t("clients.pitch") + _cost_mark(rules.cost("pitch")), _pitch.bind(b), 0, "subtle")
		go.disabled = not rules.can_pitch(b)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(go)


func _pitch(b: String) -> void:
	rules.pitch_bank(b)
	_render()


# ---------- the first month's coach (endless run) ----------

# The first time something in the loop comes up, Marina points at it: the screen dims around it and
# her note sits beside it. The core actions have to be done by hand (the dim lets clicks through only
# where she points); the rest closes with "Got it". Only with tips on, only in the first month.
func _anchor(c: Control, name: String) -> Control:
	if not anchors.has(name):
		anchors[name] = c
	return c


func _coach_steps() -> Array:
	var r := rules
	var plan: bool = r.phase == "plan" and r.pending.is_empty() and window == ""
	var team_busy := func() -> bool:
		return r.tasks.any(func(t): return t["status"] == "active" and r.team.has(t["owner"]))
	var letter_th: String = _contact_of(r.letters[0]["who"]) if not r.letters.is_empty() else ""
	var letter_who: String = r.letters[0]["who"] if not r.letters.is_empty() else ""
	return [
		{"id": "assign", "forced": true, "targets": ["inbox_first"],
			"when": plan and r.step == "triage" and r.inbox().any(func(t): return r.can_assign(t)) and not team_busy.call(),
			"done": selected >= 0},
		{"id": "pick", "forced": true, "targets": ["team_zone"],
			"when": _picking() and not pairing and r.pending.is_empty() and not team_busy.call(),
			"done": team_busy.call()},
		{"id": "haggle", "forced": true, "targets": ["deal"],
			"when": not r.pending.is_empty(), "done": r.pending.is_empty()},
		# Not forced: there may be more cards to hand out first.
		{"id": "start_work", "forced": false, "targets": ["day_button"],
			"when": plan and r.step == "triage" and r.flags.has("coach_assign"), "done": r.step == "work"},
		{"id": "midday", "forced": false, "targets": ["team_zone"], "when": plan and r.step == "work"},
		{"id": "letter", "forced": false, "targets": ["ask_" + letter_who, "contact_" + letter_th, "chat_button"],
			"when": letter_th != "" and r.phase in ["plan", "evening"] and window == "" and chat_thread != letter_th},
		{"id": "answer", "forced": false, "targets": ["prompt"],
			"when": letter_th != "" and chat_thread != "" and r.letters.any(func(ev): return _contact_of(ev["who"]) == chat_thread)},
		{"id": "points", "forced": false, "targets": ["points"], "when": plan and r.attention <= 0},
		{"id": "end_day", "forced": false, "targets": ["day_button"], "when": plan and r.step == "work" and r.flags.has("coach_midday")},
		{"id": "evening", "forced": false, "targets": ["day_button"], "when": r.phase == "evening" and window == ""},
		{"id": "standup", "forced": false, "targets": ["standup"], "when": r.phase == "standup"},
		{"id": "late", "forced": false, "targets": ["late_card"], "when": plan and r.tasks.any(func(t): return t["late"] and t["status"] in ["inbox", "active"])},
		{"id": "review", "forced": false, "targets": ["prompt"], "when": r.phase == "review" and chat_thread == "boss"},
		{"id": "candidates", "forced": false, "targets": ["nav_hire"], "when": plan and r.day >= 2 and not r.candidates.is_empty()},
		{"id": "upgrades", "forced": false, "targets": ["nav_upgrades"], "when": plan and r.day >= 3 and _fresh_upgrades() > 0},
		{"id": "clients", "forced": false, "targets": ["nav_clients"],
			"when": plan and r.step == "work" and r.day >= 6 and r.team.any(func(p): return r.available(p) and r.queue_of(p).is_empty())},
		{"id": "budget", "forced": false, "targets": ["budget"], "when": r.phase == "chapter_end" and r.can_defend()},
	]


func _coach_on() -> bool:
	return rules.tips and rules.period == 1 and not menu_open and not rules.phase in ["title", "draft", "end"]


# What to point at now, if anything: the first step that's due and not yet seen. A forced step that's
# been done is marked seen on the way.
func _coach_step() -> Dictionary:
	if not _coach_on():
		return {}
	for step in _coach_steps():
		var key: String = "coach_" + step["id"]
		if rules.flags.has(key):
			continue
		# Done counts only once it's been shown: before that "done" can be true just because nothing's there.
		if step["forced"] and step.get("done", false) and rules.flags.has("coach_shown_" + step["id"]):
			rules.flags[key] = true
			continue
		if step["when"]:
			rules.flags["coach_shown_" + step["id"]] = true
			return step
	return {}


func _coach() -> void:
	var step := _coach_step()
	if step.is_empty():
		return
	# Layout settles a frame after the screen is built.
	await get_tree().process_frame
	if not is_instance_valid(ui):
		return
	var target: Control = null
	for name in step["targets"]:
		var c: Control = anchors.get(name)
		if is_instance_valid(c) and c.is_visible_in_tree() and c.size.x > 0.0:
			target = c
			break
	# Nothing to point at (another screen layout): a plain note, never a lock.
	var forced: bool = step["forced"] and target != null
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(layer)
	var view := get_viewport().get_visible_rect().size
	var hole := Rect2(view / 2.0, Vector2.ZERO)
	if target != null:
		var g := target.get_global_rect().grow(6.0)
		hole = Rect2(g.position.floor(), g.size.ceil())
	var dim := Color(0.12, 0.13, 0.15, 0.5)
	for r in [Rect2(0, 0, view.x, hole.position.y), Rect2(0, hole.end.y, view.x, view.y - hole.end.y),
			Rect2(0, hole.position.y, hole.position.x, hole.size.y), Rect2(hole.end.x, hole.position.y, view.x - hole.end.x, hole.size.y)]:
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var shade := ColorRect.new()
		shade.color = dim
		shade.position = r.position
		shade.size = r.size
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		if not forced:
			shade.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed:
					_coach_seen.call_deferred(step["id"]))
		layer.add_child(shade)
	if target != null:
		var ring := Panel.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0, 0, 0, 0)
		rs.border_color = COL_STAR
		rs.set_border_width_all(3)
		rs.set_corner_radius_all(10)
		ring.add_theme_stylebox_override("panel", rs)
		ring.position = hole.position
		ring.size = hole.size
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(ring)
	layer.add_child(_coach_bubble(step, forced, hole, view))


func _coach_bubble(step: Dictionary, forced: bool, hole: Rect2, view: Vector2) -> Control:
	var bubble := PanelContainer.new()
	var style := _box(COL_SURFACE, COL_STAR, 2, 14)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	bubble.add_theme_stylebox_override("panel", style)
	var w := minf(380.0, view.x - 24.0)
	bubble.custom_minimum_size.x = w
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bubble.add_child(row)
	var face := _avatar("marina", 40)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	var v := _vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(_label(Loc.person("marina"), 13, COL_MUTED, false, true))
	v.add_child(_label(Loc.t("coach." + step["id"]), 15, COL_TEXT, true))
	bubble.modulate.a = 0.0
	if not forced:
		var ok := _button(Loc.t("coach.ok"), _coach_seen.bind(step["id"]), 0, "primary")
		ok.size_flags_horizontal = Control.SIZE_SHRINK_END
		v.add_child(ok)
	# Below what it points at if there's room, else above; kept on screen.
	await_size(bubble, func(sz: Vector2):
		var x := clampf(hole.position.x, 12.0, view.x - sz.x - 12.0)
		var y := hole.end.y + 12.0
		if y + sz.y > view.y - 12.0:
			y = hole.position.y - sz.y - 12.0
		if y < 12.0:
			y = clampf(view.y - sz.y - 24.0, 12.0, view.y)
		bubble.position = Vector2(x, y)
		bubble.modulate.a = 1.0)
	return bubble


func await_size(c: Control, place: Callable) -> void:
	c.ready.connect(func():
		await get_tree().process_frame
		if is_instance_valid(c):
			place.call(c.size))


func _coach_seen(id: String) -> void:
	rules.flags["coach_" + id] = true
	_render()


# ---------- the board ----------
# A whiteboard in its frame: the inbox's pile of stickies on the left, a column for each person with
# their stickies under their photo, the week's done on the right. A sticky picked off the pile goes to
# whichever column is tapped next; one that needs a pair, to the helper's.

const INBOX_W := 270
const COMPACT_INBOX_W := 200
const COLUMN_W := 148
const COMPACT_COLUMN_W := 126
const DONE_W := 128


func _board_area() -> Control:
	var board := PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := _box(COL_BOARD, COL_FRAME, 4 if compact else 6, 0)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	board.add_theme_stylebox_override("panel", style)
	var v := _vbox(0)
	board.add_child(v)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	v.add_child(row)
	row.add_child(_inbox_column())
	# More people than fit: the columns scroll sideways.
	var people := ScrollContainer.new()
	people.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_anchor(people, "team_zone")
	row.add_child(people)
	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 0)
	people.add_child(cols)
	for p in rules.team:
		if not rules.people[p]["gone"]:
			cols.add_child(_person_column(p))
	cols.add_child(_person_column("me"))
	var outside: Array = rules.tasks.filter(func(t): return t["status"] == "taras" or (t["status"] == "active" and t["owner"] == "contractor"))
	if not outside.is_empty():
		cols.add_child(_outside_column(outside))
	if not compact:
		row.add_child(_done_column())
	if _picking():
		v.add_child(_pick_bar())
	return _padded(board, 6 if compact else 12, 6 if compact else 10)


# A sticky is waiting to be stuck somewhere.
func _picking() -> bool:
	return selected >= 0 and window == "" and not rules.task(selected).is_empty()


func _inbox_column() -> Control:
	var v := _vbox(6)
	v.custom_minimum_size.x = COMPACT_INBOX_W if compact else INBOX_W
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var items: Array = rules.inbox()
	items.sort_custom(func(a, b): return a["due"] < b["due"])
	head.add_child(_hand(Loc.t("board.inbox"), 26 if compact else 32, COL_DANGER))
	if not items.is_empty():
		var n := _hand(str(items.size()), 20 if compact else 24, COL_FAINT)
		n.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(n)
	var busy := not rules.queue_of("me").is_empty()
	v.add_child(_label(Loc.t("you.busy", [rules.own_task_cost()]) if busy else Loc.t("step.%s.hint" % rules.step), 12, COL_WARN if busy else COL_MUTED, true))
	var scroll := _scroll("col_inbox")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var pile: Container = _vbox(8) if compact else _flow(6, 8)
	pile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(pile, 2, 6))
	if items.is_empty():
		pile.add_child(_hand(Loc.t("board.empty"), 22, COL_FAINT))
	for t in items:
		pile.add_child(_sticky(t, "inbox"))
	if compact:
		v.add_child(_done_line())
	var day := _day_button(0)
	day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(day)
	var column := _padded(v, 8 if compact else 12, 8)
	column.size_flags_horizontal = Control.SIZE_FILL
	return column


# One person's column: their photo and state on top, a question of theirs if one waits, then their stickies.
func _person_column(p: String) -> Control:
	var col := PanelContainer.new()
	col.custom_minimum_size.x = COMPACT_COLUMN_W if compact else COLUMN_W
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var drop := _picking() and _can_drop(p)
	var asked: bool = rules.pending.get("p", "") == p
	col.add_theme_stylebox_override("panel", _flat(Color(COL_PRIMARY, 0.07) if drop or asked else Color(0, 0, 0, 0)))
	col.draw.connect(_dashed_edge.bind(col))
	if drop:
		col.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		col.gui_input.connect(func(event: InputEvent):
			if _tapped(event):
				col.accept_event()
				cue = "assign"
				_drop_on.call_deferred(p))
		col.set_drag_forwarding(Callable(), _column_can_drop.bind(p), _column_drop.bind(p))
	var v := _vbox(6)
	col.add_child(_padded(v, 6 if compact else 8, 8))
	v.add_child(_column_head(p))
	var scroll := _scroll("col_" + p)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := _vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(list, 2, 4))
	_column_asks(list, p)
	var items := rules.queue_of(p)
	if items.is_empty():
		var free := _hand(Loc.t("row.me_free" if p == "me" else "row.free"), 19, COL_FAINT)
		free.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		free.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(free)
	for t in items:
		list.add_child(_sticky(t, "column"))
	return col


# Dragging a sticky picks it, so the columns light up and the pick bar shows just as after a tap.
# On a touch screen a mostly vertical move is the list scrolling, not a drag.
func _sticky_drag(_at, uid, pair, card):
	if not is_instance_valid(card) or rules.task(uid).is_empty():
		return null
	var move: Vector2 = card.get_global_mouse_position() - press_pos
	if DisplayServer.is_touchscreen_available() and absf(move.y) > absf(move.x):
		return null
	var ghost := Control.new()
	var paper := _sticky(rules.task(uid), "drag")
	paper.position = -paper.custom_minimum_size / 2.0
	paper.modulate.a = 0.9
	ghost.add_child(paper)
	card.set_drag_preview(ghost)
	dragging = true
	selected = uid
	pairing = pair
	deal_from = -1
	window = ""
	_render.call_deferred()
	return {"sticky": uid}


func _column_can_drop(_at, data, p) -> bool:
	return data is Dictionary and data.has("sticky") and _picking() and _can_drop(p)


func _column_drop(_at, _data, p) -> void:
	cue = "assign"
	_drop_on.call_deferred(p)


func _bin_can_drop(_at, data) -> bool:
	return data is Dictionary and data.has("sticky") and _picking() and not pairing and rules.can_decline(rules.task(selected)) and rules.can_afford(rules.cost("decline"))


func _bin_drop(_at, _data) -> void:
	_decline.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and dragging:
		dragging = false
		if not get_viewport().gui_is_drag_successful():
			_clear_selection.call_deferred()


# Who a picked sticky can go to: anyone free to take it, or, for a pair, anyone here but its owner.
func _can_drop(p: String) -> bool:
	var t := rules.task(selected)
	if pairing:
		return p != "me" and p != t["owner"] and rules.available(p) and not rules.people[p]["absent"] and rules.allowed("pair") and rules.can_afford(rules.cost("pair"))
	if not rules.can_assign(t) or t["owner"] == p or not rules.can_afford(rules.cost("assign")):
		return false
	return p == "me" or (not rules.only_me(t) and rules.available(p) and not rules.people[p]["absent"])


func _column_head(p: String) -> Control:
	var me := p == "me"
	var v := _vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	var photo := _photo(p, 40 if compact else 56, _asks_of(p) > 0)
	photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(photo)
	var name := _hand(Loc.t("you") if me else Loc.person(p), 21 if compact else 26, COL_PRIMARY)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)
	if me:
		var prof := _label(Loc.t("me_profile." + rules.profile), 11, COL_MUTED, true)
		prof.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(prof)
		_skill_row(v, p)
	else:
		var st: Dictionary = rules.people[p]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(row)
		row.add_child(_mood_face(rules.mood_word(p), 18 if compact else 22))
		row.add_child(_battery(rules.energy_word(p)))
		_skill_row(v, p)
		var notes := PackedStringArray()
		if st["absent"]:
			notes.append(Loc.t("absent.%s_label" % st["absent_reason"]))
		if rules.newbie(p):
			notes.append(Loc.t("newbie_label.alone"))
		if rules.queue_of(p).size() >= rules.OVERLOAD_AT:
			notes.append(Loc.t("row.overload"))
		var late := rules.late_hours(p) if rules.phase == "plan" else 0
		if late > 0:
			notes.append(Loc.render("late_preview", [], {"n": late}))
		if rules.warned(p):
			notes.append(Loc.t("fire.warned_label"))
		if not notes.is_empty():
			var l := _label(" · ".join(notes), 11, COL_WARN, true, true)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(l)
	v.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	v.gui_input.connect(func(event: InputEvent):
		if _tapped(event) and not _picking():
			v.accept_event()
			_open_window.call_deferred("me" if me else "person:" + p))
	return v


# What they're good at, as four little stickies in the kinds' colours with the level in marker, "?"
# until you've seen it. While a sticky waits, its kind stands out and the level is spelled out.
func _skill_row(v: VBoxContainer, p: String) -> void:
	var me := p == "me"
	var held: String = rules.task(selected)["cat"] if _picking() else ""
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var side := 22 if compact else 26
	for cat in CAT_COLORS:
		var known: bool = me or rules.people[p]["known"].has("skill." + cat)
		var level: int = rules.my_skill(cat) if me else rules.people[p]["skills"][cat]
		var chip := PanelContainer.new()
		var style := _flat(CAT_COLORS[cat][1])
		if cat == held:
			style.border_color = CAT_COLORS[cat][0]
			style.set_border_width_all(2)
		chip.add_theme_stylebox_override("panel", style)
		chip.custom_minimum_size = Vector2(side, side)
		chip.modulate.a = 0.35 if held != "" and cat != held else 1.0
		chip.tooltip_text = "%s: %s" % [Loc.t("cat." + cat), Loc.t("level.%d" % level) if known else Loc.t("pick.unknown")]
		var l := _hand(str(level) if known else "?", 17 if compact else 20, CAT_COLORS[cat][0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(l)
		row.add_child(chip)
	if held == "":
		return
	var known: bool = me or rules.people[p]["known"].has("skill." + held)
	var level: int = rules.my_skill(held) if me else rules.people[p]["skills"][held]
	var word := _hand(Loc.t("level.%d" % level) if known else Loc.t("pick.unknown"), 18 if compact else 21, _level_color(level) if known else COL_FAINT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(word)


# Questions from this person waiting for you: the one that holds the day, and their messages.
func _asks_of(p: String) -> int:
	var n := 0
	if rules.phase == "event" and not rules.events.is_empty() and rules.events[0]["who"] == p:
		n += 1
	for ev in rules.letters:
		if ev["who"] == p:
			n += 1
	return n


# A question shows in the asker's column as their speech bubble, with the answers right under it.
func _column_asks(v: VBoxContainer, p: String) -> void:
	if p == "me":
		return
	if rules.phase == "event" and not rules.events.is_empty() and rules.events[0]["who"] == p:
		var box := _ask_bubble(v, p, rules.events[0])
		_event_choices(box, rules.events[0])
	for i in rules.letters.size():
		var ev: Dictionary = rules.letters[i]
		if ev["who"] == p:
			var box := _ask_bubble(v, p, ev)
			_letter_choices(box, i, ev)


func _ask_bubble(v: VBoxContainer, p: String, ev: Dictionary) -> VBoxContainer:
	var bubble := PanelContainer.new()
	var bs := _flat(COL_TOPBAR)
	bs.set_corner_radius_all(10)
	bs.set_content_margin_all(8)
	bubble.add_theme_stylebox_override("panel", bs)
	_anchor(bubble, "ask_" + p)
	v.add_child(bubble)
	var said := PackedStringArray()
	for line in ev["lines"]:
		if line["who"] == p:
			said.append(Loc.render(line["key"], [], ev["names"]))
	var text := _label("\n".join(said), 12, COL_ON_TOP, true)
	text.max_lines_visible = 4
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.tooltip_text = "\n".join(said)
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	bubble.add_child(text)
	var box := _vbox(3)
	box.set_meta("small", true)
	v.add_child(box)
	return box


func _outside_column(items: Array) -> Control:
	var col := PanelContainer.new()
	col.custom_minimum_size.x = COMPACT_COLUMN_W if compact else COLUMN_W
	col.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0)))
	col.draw.connect(_dashed_edge.bind(col))
	var v := _vbox(8)
	col.add_child(_padded(v, 6 if compact else 10, 10))
	var head := _hand(Loc.t("owner.outside"), 22 if compact else 26, COL_MUTED)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var scroll := _scroll("col_outside")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := _vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(list, 2, 4))
	for t in items:
		list.add_child(_sticky(t, "column"))
	return col


# What got done this week, stuck to the right edge of the board.
func _done_column() -> Control:
	var items: Array = _lanes()["done"]
	var col := PanelContainer.new()
	col.custom_minimum_size.x = DONE_W
	col.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0)))
	col.draw.connect(_dashed_edge.bind(col))
	var v := _vbox(8)
	col.add_child(_padded(v, 10, 10))
	var head := _hand(Loc.t("board.done"), 30, COL_GOOD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var late := items.filter(func(t): return t["late"]).size()
	if late > 0:
		var l := _label(Loc.t("done.strip_late", [late]), 12, COL_DANGER, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var scroll := _scroll("col_done")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := _vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(list, 2, 4))
	for t in items:
		list.add_child(_sticky(t, "done"))
	return col


# On a small screen the week's done is one line under the inbox; it opens as a window.
func _done_line() -> Control:
	var items: Array = _lanes()["done"]
	var late := items.filter(func(t): return t["late"]).size()
	var text_value := Loc.t("done.strip", [items.size()])
	if late > 0:
		text_value += " · " + Loc.t("done.strip_late", [late])
	var b := _button(text_value, _open_window.bind("done"), 0, "subtle")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = items.is_empty()
	b.custom_minimum_size.y = 30
	b.add_theme_font_size_override("font_size", _fs(12))
	return b


func _dashed_edge(c: Control) -> void:
	var y := 8.0
	while y < c.size.y - 8.0:
		c.draw_line(Vector2(0, y), Vector2(0, minf(y + 7.0, c.size.y - 8.0)), Color("b4bac1"), 2.0)
		y += 13.0


# Under the board while a sticky is picked: what to do with it now, and the way out.
func _pick_bar() -> Control:
	var t := rules.task(selected)
	var bar := PanelContainer.new()
	var style := _flat(COL_TOPBAR)
	style.content_margin_left = 12
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	var text_value := Loc.t("pick_bar.pair", [Loc.t("name.%s.dat" % t["owner"])]) if pairing else Loc.t("pick_bar.assign", [Loc.t("taskname." + t["id"])])
	var l := _label(text_value, 13, COL_ON_TOP, true, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	row.add_child(_button(Loc.t("pick_bar.more"), _select.bind(selected), 0, "on_top"))
	if not pairing and rules.can_decline(t):
		var bin := _button(Loc.t("pick_bar.bin") + _cost_mark(rules.cost("decline")), _decline, 0, "on_top")
		bin.disabled = bin.disabled or not rules.can_afford(rules.cost("decline"))
		bin.set_drag_forwarding(Callable(), _bin_can_drop, _bin_drop)
		row.add_child(bin)
	row.add_child(_button(Loc.t("pick_bar.cancel"), _clear_selection, 0, "on_top"))
	return bar


# A task as a sticky: paper in its kind's colour, what it takes and when it's due in marker, the title,
# and how it's going. In the inbox they lie in a pile at a slant; on a column they hang straighter.
func _sticky(t: Dictionary, where: String) -> Control:
	var colors: Array = CAT_COLORS[t["cat"]]
	var ink: Color = colors[0]
	var chosen: bool = selected == t["uid"] and window == "" and where not in ["preview", "drag"]
	var card := PanelContainer.new()
	var style := _flat(colors[1])
	style.set_content_margin_all(6 if compact else 8)
	style.shadow_color = Color(0, 0, 0, 0.3 if chosen else 0.2)
	style.shadow_size = 10 if chosen else 3
	style.shadow_offset = Vector2(0, 4 if chosen else 2)
	if chosen:
		style.border_color = COL_PRIMARY
		style.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", style)
	if where == "preview":
		card.custom_minimum_size = Vector2(150, 150)
	elif where == "drag":
		card.custom_minimum_size = Vector2(COMPACT_COLUMN_W - 12 if compact else COLUMN_W - 16, 52 if compact else 64)
	elif where == "inbox" and not compact:
		card.custom_minimum_size = Vector2(116, 124)
	else:
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 52 if compact else 64
	var tilt: float = -2.0 if where == "preview" else 4.0 if where == "drag" else 0.0 if chosen else float((t["uid"] * 37) % 7 - 3) * (0.9 if where == "inbox" else 0.4)
	card.rotation_degrees = tilt
	card.scale = Vector2(1.06, 1.06) if chosen else Vector2.ONE
	card.resized.connect(_center_pivot.bind(card))
	if where == "inbox" and rules.can_assign(t):
		_anchor(card, "inbox_first")
	if t["late"] and where not in ["done", "drag"]:
		_anchor(card, "late_card")
	if where == "done":
		card.modulate = Color(1, 1, 1, 0.8)
	elif where in ["inbox", "column"] and _looking() and t["status"] in ["inbox", "active"]:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event: InputEvent):
			if not _tapped(event):
				return
			# With a sticky picked, a tap on someone's column (stickies included) is where it goes.
			if where == "column" and _picking():
				return
			card.accept_event()
			cue = "select"
			_sticky_tapped.call_deferred(t["uid"], where))
		# The same stickies a tap picks can be dragged straight onto a column.
		var pair: bool = where == "column" and rules.needs_pair(t) and rules.allowed("pair")
		if (where == "inbox" and rules.can_assign(t)) or pair:
			card.set_drag_forwarding(_sticky_drag.bind(t["uid"], pair, card), Callable(), Callable())
	if flash_cards.has(t["uid"]) and where in ["inbox", "column", "done"]:
		var color: Color = flash_cards[t["uid"]]
		card.ready.connect(func(): _flash.call_deferred(card, color))
	var v := _vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var icon := TextureRect.new()
	icon.texture = _cat_icon(t["cat"])
	icon.modulate = ink
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(14, 14)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(icon)
	var marks := PackedStringArray()
	if t["key"]:
		marks.append("★")
	if t.get("again", false) and C.TASKS.get(t["id"], {}).get("kind", "") != "weekly":
		marks.append(Loc.t("chip_again"))
	if C.TASKS.get(t["id"], {}).get("kind", "") == "chain":
		marks.append(Loc.t("chip_chain"))
	if t["involved"] and t["owner"] != "me":
		marks.append(Loc.t("chip_involved").trim_prefix("· "))
	var mark := _label(" ".join(marks), 10, ink, false, true)
	mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mark.clip_text = true
	top.add_child(mark)
	if where != "done" and t["status"] != "taras":
		var est: Dictionary = rules.estimate(t)
		top.add_child(_hand(Loc.t("sticky.size" if est["sure"] else "sticky.size_guess", [_days(est["days"])]), 18 if compact else 21, COL_TEXT))
	var title := _label(Loc.t("taskname." + t["id"]), 11 if compact else 13, COL_TEXT, true, true)
	title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if where == "inbox":
		title.max_lines_visible = 2 if compact else 4
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(title)
	if t["status"] == "active":
		v.add_child(_sticky_progress(t, ink))
	var warn := ""
	if t["status"] == "active" and rules.needs_pair(t):
		warn = Loc.t("sticky.no_pair")
	elif t["blocked"] > 0:
		warn = Loc.t("chip_blocked")
	elif _stalled(t):
		warn = Loc.t("sticky.stalled")
	elif not _letter_for(t).is_empty():
		warn = Loc.t("chip_letter")
	if warn != "" and where != "done":
		v.add_child(_hand(warn, 18 if compact else 20, COL_DANGER))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 4)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	var due: String
	var urgent: bool = t["late"] or t["due"] - rules.day <= 0
	if where == "done":
		due = Loc.t("sticky.late") if t["late"] else "✓"
		urgent = t["late"]
	else:
		due = _due_hand(t)
	var due_label := _hand(due, 17 if compact else 20, COL_DANGER if urgent else (COL_GOOD if where == "done" else COL_TEXT))
	due_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	due_label.clip_text = true
	foot.add_child(due_label)
	if t["helper"] != "" and t["status"] == "active":
		foot.add_child(_avatar(t["helper"], 18))
	if rules.paid_card(t) and t["status"] != "done":
		foot.add_child(_coin(t))
	return card


func _paper(fill: Color, picked: bool) -> StyleBoxFlat:
	var st := _box(fill, COL_PRIMARY, 3 if picked else 0, 14)
	st.set_corner_radius_all(2)
	st.shadow_color = Color(0, 0, 0, 0.28 if picked else 0.18)
	st.shadow_size = 8 if picked else 3
	st.shadow_offset = Vector2(0, 3 if picked else 2)
	return st


# Stickies and photos tilt round their middle.
func _center_pivot(c) -> void:
	if is_instance_valid(c):
		c.pivot_offset = c.size / 2.0


# The bank's money on a task: a gold coin with the bonus, or a red stamp once the SLA fine is in.
func _coin(t: Dictionary) -> Control:
	var fined: bool = t.get("sla_fined", false)
	var coin := PanelContainer.new()
	var cs := _box(Color("f2c230") if not fined else Color("ffd9d2"), Color("c79a14") if not fined else COL_DANGER, 2, 0)
	cs.set_corner_radius_all(12)
	cs.content_margin_left = 5
	cs.content_margin_right = 5
	coin.add_theme_stylebox_override("panel", cs)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.tooltip_text = Loc.t("sla.fined", [_rub(rules.card_sla(t))]) if fined else Loc.t("sla.terms", [_rub(rules.card_bonus(t)), _rub(rules.card_bonus_ok(t)), _rub(rules.card_sla(t))])
	coin.add_child(_label(Loc.t("chip_sla") if fined else "+%d" % Rules.cash(rules.card_bonus(t)), 10, COL_DANGER if fined else COL_TEXT, false, true))
	return coin


func _sticky_tapped(uid: int, where: String) -> void:
	var t := rules.task(uid)
	if t.is_empty():
		return
	if where == "inbox" and rules.can_assign(t):
		_pick_sticky(uid, false)
	elif where == "column" and t["status"] == "active" and rules.needs_pair(t) and rules.allowed("pair"):
		_pick_sticky(uid, true)
	else:
		_select(uid)


# How far along, in marker: what was done before today hatched, today's part filled in. Stuck at midday,
# it's all grey.
func _sticky_progress(t: Dictionary, ink: Color) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size: float = t["size"]
	var shown: float = minf(rules.shown_progress(t), size)
	var today: float = clampf(t.get("gain_today", 0.0), 0.0, shown)
	var stalled := _stalled(t)
	bar.draw.connect(_draw_progress.bind(bar, (shown - today) / size, today / size, COL_FAINT if stalled else ink))
	return bar


func _draw_progress(bar: Control, earlier: float, today: float, pen: Color) -> void:
	var w := bar.size.x
	var h := bar.size.y
	var x := 2.0
	while x < w * earlier:
		bar.draw_line(Vector2(x, h - 1), Vector2(minf(x + h - 2, w * earlier), 1), pen, 1.5)
		x += 4.0
	bar.draw_rect(Rect2(w * earlier, 0, w * today, h), COL_GAIN)
	bar.draw_rect(Rect2(0, 0, w, h), COL_TEXT, false, 1.5)


# When it's due, the way you'd write it on a sticky: "today!", "by Thu".
const WEEKDAY_KEYS := ["wd.mon", "wd.tue", "wd.wed", "wd.thu", "wd.fri"]


func _due_hand(t: Dictionary) -> String:
	if t["due"] >= rules.NO_DEADLINE:
		return Loc.t("due.none")
	if t["late"]:
		return Loc.t("sticky.late")
	var left: int = t["due"] - rules.day
	if left <= 0:
		return Loc.t("sticky.today")
	if left == 1:
		return Loc.t("sticky.tomorrow")
	if left < 5:
		return Loc.t("sticky.by", [Loc.t(WEEKDAY_KEYS[(t["due"] - 1) % 5])])
	return Loc.t("sticky.in", [left])


# A person's photo, pinned to the board with a magnet; a red "!" on it when they're waiting for an answer.
func _photo(p: String, size: int, asks: bool) -> Control:
	var frame := PanelContainer.new()
	var style := _flat(COL_SURFACE)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = int(size / 5.0)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.rotation_degrees = float(absi(p.hash()) % 5 - 2) * 1.2
	frame.resized.connect(_center_pivot.bind(frame))
	frame.add_child(_avatar(p, size, "", true))
	frame.draw.connect(_draw_photo.bind(frame, MAGNETS[absi(p.hash()) % MAGNETS.size()], asks))
	return frame


func _draw_photo(frame: Control, magnet: Color, asks: bool) -> void:
	var c := Vector2(frame.size.x / 2.0, 1.0)
	frame.draw_circle(c + Vector2(0, 1.5), 7.0, Color(0, 0, 0, 0.25))
	frame.draw_circle(c, 7.0, magnet)
	if asks:
		var at := Vector2(frame.size.x - 2.0, 4.0)
		frame.draw_circle(at, 11.0, COL_SURFACE)
		frame.draw_circle(at, 9.0, COL_DANGER)
		frame.draw_string(font_bold, at + Vector2(-3.0, 5.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_SURFACE)


# How someone feels, drawn as a face in marker.
func _mood_face(word: String, size: int) -> Control:
	var face := Control.new()
	face.custom_minimum_size = Vector2(size, size)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.tooltip_text = Loc.t("mood." + word)
	face.draw.connect(_draw_mood.bind(face, word))
	return face


func _draw_mood(face: Control, word: String) -> void:
	var s := face.size.x
	var c := Vector2(s, s) / 2.0
	face.draw_circle(c, s / 2.0 - 1.0, Color(MOOD_COLORS.get(word, COL_MUTED), 0.18))
	face.draw_arc(c, s / 2.0 - 1.5, 0, TAU, 24, COL_TEXT, 1.6)
	face.draw_circle(c + Vector2(-s * 0.16, -s * 0.1), s * 0.05, COL_TEXT)
	face.draw_circle(c + Vector2(s * 0.16, -s * 0.1), s * 0.05, COL_TEXT)
	var m := c + Vector2(0, s * 0.14)
	if word in ["happy", "good"]:
		face.draw_arc(m - Vector2(0, s * 0.12), s * 0.22, 0.35, PI - 0.35, 10, COL_TEXT, 1.6)
	elif word in ["down", "angry"]:
		face.draw_arc(m + Vector2(0, s * 0.16), s * 0.2, PI + 0.5, TAU - 0.5, 10, COL_TEXT, 1.6)
	else:
		face.draw_line(m + Vector2(-s * 0.16, 0), m + Vector2(s * 0.16, 0), COL_TEXT, 1.6)


# How much they have left in them, as a battery.
const BATTERY := {"fresh": 1.0, "ok": 0.7, "tired": 0.4, "drained": 0.15}


func _battery(word: String) -> Control:
	var b := Control.new()
	b.custom_minimum_size = Vector2(28, 14)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.tooltip_text = Loc.t("energy." + word)
	b.draw.connect(_draw_battery.bind(b, BATTERY.get(word, 0.5), ENERGY_COLORS.get(word, COL_MUTED)))
	return b


func _draw_battery(b: Control, level: float, color: Color) -> void:
	var r := Rect2(1, 1, b.size.x - 5, b.size.y - 2)
	b.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2((r.size.x - 4) * level, r.size.y - 4)), color)
	b.draw_rect(r, COL_TEXT, false, 1.6)
	b.draw_rect(Rect2(r.end.x, r.position.y + r.size.y * 0.3, 3, r.size.y * 0.4), COL_TEXT)


# Marker handwriting, for what's written on the board.
func _hand(text_value: String, size: int, color: Color) -> Label:
	var l := _label(text_value, size, color)
	l.add_theme_font_override("font", font_hand)
	return l


# A phone held upright: one sticky asking to turn it, since the board only fits sideways.
func _build_turn_phone() -> void:
	var wall := ColorRect.new()
	wall.color = COL_BG
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(wall)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var note := PanelContainer.new()
	var style := _flat(COL_STICKY)
	style.set_content_margin_all(28)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	note.add_theme_stylebox_override("panel", style)
	note.custom_minimum_size = Vector2(300, 300)
	note.rotation_degrees = -3.0
	note.resized.connect(_center_pivot.bind(note))
	center.add_child(note)
	var v := _vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	note.add_child(v)
	var phone := Control.new()
	phone.custom_minimum_size = Vector2(90, 90)
	phone.draw.connect(_draw_turn.bind(phone))
	var holder := CenterContainer.new()
	holder.add_child(phone)
	v.add_child(holder)
	var title := _hand(Loc.t("turn.title"), 40, COL_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var text := _label(Loc.t("turn.text"), 15, COL_TEXT, true)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size.x = 240
	v.add_child(text)


# Three columns: the inbox, what's on people's plates (each person's queue, the first card being worked
# on), and what's done this week.
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

# Midday, and the task someone's on right now hasn't moved since the morning.
func _stalled(t: Dictionary) -> bool:
	if rules.step != "work" or t.get("gain_today", 0.0) > 0.0 or not rules.team.has(t["owner"]):
		return false
	var q := rules.queue_of(t["owner"])
	return not q.is_empty() and q[0]["uid"] == t["uid"]

func _due_text(t: Dictionary) -> String:
	if t["due"] >= rules.NO_DEADLINE:
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
# The sticky itself on the left; who asked, what's at stake and what it pays on the right.
func _task_window(win: VBoxContainer, t: Dictionary) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	win.add_child(top)
	var paper := _sticky(t, "preview")
	paper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(paper)
	var v := _vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(v)
	var facts := _flow(6, 4)
	v.add_child(facts)
	facts.add_child(_pill(Loc.t("cat." + t["cat"]), CAT_COLORS[t["cat"]][0], CAT_COLORS[t["cat"]][1], _cat_icon(t["cat"])))
	facts.add_child(_pill(_due_text(t), COL_DANGER if t["due"] - rules.day <= 1 else COL_TEXT, Color("ffe2dc") if t["due"] - rules.day <= 1 else COL_COLUMN))
	if t["key"]:
		facts.add_child(_pill(Loc.t("chip_key"), COL_WARN, Color("fff3cf")))
	elif t["public"]:
		facts.add_child(_pill(Loc.t("public"), COL_WARN, Color("fff3cf")))
	var waiting := _letter_for(t)
	if not waiting.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var note := _label(Loc.render("letter.waits", [], {"who": "@name.%s.nom" % waiting["who"]}), 14, COL_WARN, true)
		row.add_child(note)
		row.add_child(_button(Loc.t("letter.go"), _go_to_letter.bind(_contact_of(waiting["who"])), 0, "subtle"))
	v.add_child(_label("%s — %s" % [Loc.t("from", [Loc.person(t["from"])]), Loc.t("quote", [Loc.t("task.%s.ask" % t["id"])])], 14, COL_MUTED, true))
	var pen: Dictionary = rules.penalty_of(t)
	if not pen.is_empty() and t["status"] != "done" and not t["late"]:
		v.add_child(_label(Loc.t("penalty.%s.card" % pen["kind"], [_rub(pen["amount"])] if pen["kind"] == "money" else []), 14, COL_DANGER, true))
	if rules.paid_card(t) and t["status"] != "done":
		if t.get("sla_fined", false):
			v.add_child(_label(Loc.t("sla.fined", [_rub(rules.card_sla(t))]), 14, COL_DANGER, true))
		else:
			v.add_child(_label(Loc.t("sla.terms", [_rub(rules.card_bonus(t)), _rub(rules.card_bonus_ok(t)), _rub(rules.card_sla(t))]), 14, COL_GOOD, true))
	v = win
	if deal_from >= 0:
		_deal_block(v, t)
		return
	if rules.can_assign(t):
		v.add_child(_section(Loc.t("to_whom").trim_suffix(":")))
		var grid := GridContainer.new()
		grid.columns = 2 if compact else 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		_anchor(grid, "pick_grid")
		var best := _best_pick(t)
		for p in _pick_order(t):
			grid.add_child(_pick_tile(t, p, p == best))
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
			var step := _button(Loc.t("intervene_button.ask") + _cost_mark(rules.cost("intervene")), _intervene, 0, "subtle")
			step.disabled = step.disabled or not rules.can_intervene(t)
			acts.add_child(step)
	if t["status"] == "active" and rules.team.has(t["owner"]) and rules.allowed("pair"):
		var pair := _flow(6, 6)
		v.add_child(pair)
		pair.add_child(_row_label(Loc.t("helper_required" if rules.needs_pair(t) else "helper_optional")))
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

# Good at it reads green, weak reads as a warning, the middle stays plain.
func _level_color(level: int) -> Color:
	return COL_WARN if level <= 1 else (COL_TEXT if level == 2 else COL_GOOD)

# One person as a choice: their level at this kind of work, what's on them, how they are, and how long.
func _pick_tile(t: Dictionary, p: String, best: bool) -> Control:
	var me: bool = p == "me"
	var owner: bool = t["owner"] == p
	var can: bool = rules.can_assign(t) and not owner and rules.can_afford(rules.cost("assign")) and (me or not rules.people[p]["absent"])
	var tile := PanelContainer.new()
	if best:
		_anchor(tile, "pick_best")
	tile.custom_minimum_size.x = 170
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := COL_SELECTED if owner else (Color("f4f8ff") if best else COL_SURFACE)
	tile.add_theme_stylebox_override("panel", _box(fill, COL_FOCUS if best or owner else COL_BORDER, 2 if best or owner else 1, 10))
	if can:
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.gui_input.connect(func(event: InputEvent):
			if _tapped(event):
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
	var known: bool = me or rules.people[p]["known"].has("skill." + t["cat"])
	var level: int = rules.my_skill(t["cat"]) if me else rules.people[p]["skills"][t["cat"]]
	var skill := _label(_level_stars(level) + "  " + Loc.t("level.%d" % level) if known else "?  " + Loc.t("pick.unknown"), 14, _level_color(level) if known else COL_FAINT, true, true)
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
		grid.columns = 1 if compact else 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		_anchor(grid, "deal")
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

func _view_width() -> float:
	return get_viewport().get_visible_rect().size.x


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


# Kept in the history (the task window's haggle reads it) but not worth a message: what the board
# already shows. The chat is for what asks something of you or what you can't see on the board.
# The chat holds only what asks for an answer or is a conversation, nothing else. Whatever
# you did on the board, and news that changes nothing you'd do right now, shows on the board itself.
const CHAT_SHOWN := ["event.", "review.", "budget.", "money.budget", "money.split", "boss.clean_week", "hire.cv",
	"convo.", "story.", "talk.open", "visit.open", "fire.open", "intervene.open", "decline.open"]


func _quiet(key: String) -> bool:
	for prefix in CHAT_SHOWN:
		if key.begins_with(prefix):
			return false
	return true


func _sort_threads() -> void:
	threads = {}
	day_names = {}
	var last := GENERAL
	for i in rules.history.size():
		var e: Dictionary = rules.history[i]
		var key: String = e["key"]
		if key == "log.morning":
			day_names[e["day"]] = Loc.render(key, e.get("args", []), e.get("names", {})).replace("—", "").strip_edges()
		if _quiet(key):
			continue
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
			elif key.begins_with("up."):
				th = GENERAL
			else:
				th = last
		elif e["who"] != "":
			th = _contact_of(e["who"])
		last = th
		if not threads.has(th):
			threads[th] = []
		# A part of the day with nothing in it isn't worth its separator.
		var list: Array = threads[th]
		if key.begins_with("log.") and not list.is_empty() and rules.history[list[-1]]["key"].begins_with("log."):
			list.pop_back()
		list.append(i)


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


func _open_thread(th: String) -> void:
	chat_thread = "" if chat_thread == th and not compact else th
	chat_open = true
	_render()


# A message about this card that's still waiting for an answer, if any.
func _letter_for(t: Dictionary) -> Dictionary:
	for ev in rules.letters:
		if ev.get("uid", -1) == t["uid"]:
			return ev
	return {}


func _go_to_letter(th: String) -> void:
	if not rules.pending.is_empty():
		return
	window = ""
	selected = -1
	chat_thread = th
	chat_open = true
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
	var waiting: bool = _asked_thread() == th or _letters_in(th) > 0
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
	_anchor(holder, "contact_" + th)
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
		if _tapped(event):
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
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
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
	if compact:
		head_row.add_child(_button("‹", _close_thread, 40, "subtle"))
	head_row.add_child(_contact_face(th, 30))
	var titles := _vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(titles)
	titles.add_child(_label(_contact_name(th), 16, COL_TEXT, false, true))
	# How Irina sees you lives here now that her door is her conversation.
	if th == "boss":
		var word := rules.boss_word()
		titles.add_child(_label(Loc.t("weight." + word), 12, {"w3": COL_GOOD, "w2": COL_GOOD, "w1": COL_MUTED, "w0": COL_DANGER}[word]))
	if rules.team.has(th):
		var card := _button(Loc.t("chat.card"), _open_window.bind("person:" + th), 0, "subtle")
		card.add_theme_font_size_override("font_size", _fs(12))
		head_row.add_child(card)
	head_row.add_child(_button("×", _toggle_chat if compact else _close_thread, 40 if compact else 30, "subtle"))
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
		if not rules.can_visit():
			list.add_child(_label(Loc.t("nav.boss_seen" if rules.visited_today else "nav.boss_later"), 12, COL_MUTED, true))


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


# On a small screen the messenger slides over the board from the right; a tap beside it closes it.
func _chat_drawer() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.13, 0.15, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if _tapped(event):
			_toggle_chat.call_deferred())
	ui.add_child(dim)
	var w := minf(460.0, _view_width() * 0.62)
	var panel: Control
	if chat_thread != "" and _contacts().has(chat_thread):
		panel = _thread_view(chat_thread)
	else:
		chat_thread = ""
		panel = _contact_list()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -w
	ui.add_child(panel)


func _toggle_chat() -> void:
	chat_open = not chat_open
	_render()


# The drawer's list of conversations, each with its last line.
func _contact_list() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(COL_SURFACE))
	var outer := _vbox(0)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var head_box := _padded(head, 12, 8)
	head_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_child(head_box)
	var title := _label(Loc.t("tab.chat"), 17, COL_TEXT, false, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("×", _toggle_chat, 40, "subtle"))
	var scroll := _scroll("contacts")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var v := _vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(v, 10, 10))
	for th in _contacts():
		var row := PanelContainer.new()
		_anchor(row, "contact_" + th)
		row.add_theme_stylebox_override("panel", _box(COL_SURFACE, COL_BORDER, 1, 10))
		row.gui_input.connect(func(event: InputEvent):
			if _tapped(event):
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
	return panel


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
	_anchor(box, "prompt")
	var v := _vbox(6)
	box.add_child(v)
	if title != "":
		v.add_child(_label(title, 12, COL_PRIMARY, true, true))
	return v


# A message waiting for an answer: answering costs, saying nothing is free and settles at the end of the day.
func _letter_prompt(list: VBoxContainer, i: int, ev: Dictionary) -> void:
	var v := _prompt_box(list, Loc.t("letter.title"))
	_letter_choices(v, i, ev)
	v.add_child(_label(Loc.t("letter.hint"), 12, COL_MUTED, true))


func _letter_choices(v: VBoxContainer, i: int, ev: Dictionary) -> void:
	for choice in ev["choices"]:
		var parts: PackedStringArray = choice.split(":")
		var names: Dictionary = ev["names"].duplicate()
		if ev.has("choice_names"):
			names.merge(ev["choice_names"].get(choice, {}), true)
		elif parts.size() > 1:
			names["who"] = "@name.%s.acc" % parts[1]
		var text := Loc.render("event.%s.choice.%s" % [ev["id"], parts[0]], [], names) + _cost_mark(rules.reply_cost(ev, choice))
		var b := _answer_button(text, _answer_letter.bind(i, choice), v.has_meta("small"))
		b.disabled = not rules.can_answer(i, choice)
		v.add_child(b)


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
	_event_choices(_prompt_box(list, title), ev)


func _event_choices(v: VBoxContainer, ev: Dictionary) -> void:
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
		var answer := _answer_button(text, _event.bind(choice), v.has_meta("small"))
		answer.disabled = answer.disabled or not rules.can_afford(rules.choice_cost(ev, choice))
		v.add_child(answer)


func _review_prompt(list: VBoxContainer) -> void:
	var item: Dictionary = rules.review[0]
	var t := rules.task(item["uid"])
	var names := {"task": "@taskname." + t["id"], "owner": "@name.%s.nom" % t["owner"], "owner_gen": "@name.%s.gen" % t["owner"], "owner_dat": "@name.%s.dat" % t["owner"]}
	var v := _prompt_box(list, Loc.t("review_title"))
	v.add_child(_label(Loc.render("review.context", [], {"owner": Loc.person(t["owner"])}), 13, COL_MUTED, true))
	for choice in rules.review_choices(item):
		v.add_child(_answer_button(Loc.render("review.a." + choice, [], names), _answer.bind(choice)))
	v.add_child(_label(Loc.t("review_hint.endless"), 12, COL_MUTED, true))


func _answer_button(text_value: String, action: Callable, small: bool = false) -> Button:
	var b := _button(text_value, action, 0, "answer")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if small:
		b.add_theme_font_size_override("font_size", _fs(12))
		b.custom_minimum_size.y = 30
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
	dim.color = Color(0.12, 0.13, 0.15, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var panel := PanelContainer.new()
	var w := minf(width, _view_width() - 16.0)
	var margin := 8.0 if compact else 32.0
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
	scroll.add_child(_padded(v, 16 if compact else 28, 16 if compact else 24))
	return v


# ---------- story conversations ----------

# Its own screen: whoever is talking, big, with how they feel; the talk so far; "next" or your answers.
func _build_story() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.13, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var view := get_viewport().get_visible_rect().size
	var w := minf(880.0, view.x - (16.0 if compact else 64.0))
	var h := view.y - 16.0 if compact else minf(600.0, view.y - 64.0)
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
	var body: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
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
	scroll.add_child(_padded(list, 18 if compact else 28, 18 if compact else 24))
	for i in log.size():
		list.add_child(_story_entry(log[i], i == log.size() - 1))
	var actions := _vbox(8)
	var foot := _padded(actions, 18 if compact else 28, 16)
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
	dim.color = Color(0.12, 0.13, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var view := get_viewport().get_visible_rect().size
	var w := minf(880.0, view.x - (16.0 if compact else 64.0))
	var h := view.y - 16.0 if compact else minf(600.0, view.y - 64.0)
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
	var body: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
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
	scroll.add_child(_padded(list, 18 if compact else 28, 18 if compact else 24))
	var log: Array = rules.convo["log"]
	for i in log.size():
		var e: Dictionary = log[i]
		var said: String = Loc.render(e["key"], [], e["names"]) if e.has("key") else Loc.fill(e["ru"], e["en"], e["names"])
		list.add_child(_story_entry({"who": e["who"], "emo": "", "ru": said, "en": ""}, i == log.size() - 1))
	var actions := _vbox(8)
	var foot := _padded(actions, 18 if compact else 28, 16)
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
	dim.color = Color(0.12, 0.13, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var view := get_viewport().get_visible_rect().size
	var w := minf(960.0, view.x - (16.0 if compact else 64.0))
	var h := view.y - 16.0 if compact else minf(640.0, view.y - 64.0)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -w / 2.0
	panel.offset_right = w / 2.0
	panel.offset_top = -h / 2.0
	panel.offset_bottom = h / 2.0
	var style := _box(COL_BOARD, COL_FRAME, 5, 0)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	_anchor(panel, "standup")
	var right := _vbox(0)
	panel.add_child(right)
	var head := _vbox(4)
	head.add_child(_hand(Loc.t("standup.title"), 32 if compact else 38, COL_PRIMARY))
	head.add_child(_label(Loc.t("standup.hint_endless") + "   " + _attention_text(), 13, COL_MUTED, true))
	var head_box := _padded(head, 18 if compact else 28, 16)
	head_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(head_box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 1 if compact else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_padded(grid, 18 if compact else 28, 4))
	var lines: Array = rules.standup["lines"]
	for i in lines.size():
		grid.add_child(_standup_tile(lines[i], i))
	var foot := _padded(HBoxContainer.new(), 18 if compact else 28, 16)
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
	var style := _box(COL_COLUMN if quiet else COL_SURFACE, COL_BORDER, 1, 14)
	style.set_corner_radius_all(10)
	tile.add_theme_stylebox_override("panel", style)
	var v := _vbox(8)
	tile.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_photo(p, 36, false))
	var name := _hand(Loc.person(p), 24, COL_PRIMARY)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name)
	v.add_child(top)
	v.add_child(_label(Loc.render(line["key"], line["args"], line["names"]), 15, COL_MUTED if quiet else COL_TEXT, true))
	if Loc.has_key(line["key"] + ".aside"):
		v.add_child(_label(Loc.t(line["key"] + ".aside"), 13, COL_FAINT, true))
	var options := rules.standup_reactions(i)
	for r in options:
		var b := _answer_button(Loc.render("standup.say." + r, [], line["names"]) + _cost_mark(rules.cost("react")), _standup_react.bind(i, r))
		b.disabled = b.disabled or not rules.can_afford(rules.cost("react"))
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
	if compact:
		fade.set_color(0, Color(COL_BG, 0.45))
		fade.set_color(1, Color(COL_BG, 0.75))
	else:
		fade.set_color(0, Color(COL_BG, 0.0))
		fade.set_color(1, Color(COL_BG, 0.92))
		fade.add_point(0.55, Color(COL_BG, 0.15))
	var wash_tex := GradientTexture2D.new()
	wash_tex.gradient = fade
	wash_tex.fill_from = Vector2(0, 0)
	wash_tex.fill_to = Vector2(1, 0) if compact else Vector2(0, 1)
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
	if compact:
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
	var inner: BoxContainer = HBoxContainer.new() if compact else VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.alignment = BoxContainer.ALIGNMENT_BEGIN if compact else BoxContainer.ALIGNMENT_CENTER
	box.add_child(_padded(inner, 16 if compact else 24, 16 if compact else 24))
	var size := 64 if compact else 168
	var tex := _portrait(p, emo)
	if tex != null and not compact:
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
	if tex == null or compact:
		inner.add_child(ring)
	var names := _vbox(4)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(names)
	var name := _label(Loc.person(p), 20 if compact else 22, COL_TEXT, false, true)
	if not compact:
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.custom_minimum_size.x = 240
	names.add_child(name)
	if emo != "" and Loc.has_key("emo." + emo):
		var tag := _pill(Loc.t("emo." + emo), COL_SURFACE, EMO_COLORS.get(emo, COL_MUTED))
		tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_SHRINK_CENTER
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
	if not rules.chapter_keys().is_empty():
		v.add_child(_label(_keys_text(), 15, COL_WARN, true))
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
	var info: Dictionary = rules.chapter_info()
	if info.is_empty():
		v.add_child(_section(Loc.t("period.results", [rules.period])))
	else:
		v.add_child(_section(Loc.t("chapter.results", [rules.chapter, Loc.t("chapter.%s.name" % info["id"])])))
	var good := rules.ending == "beloved" or rules.passed()
	v.add_child(_label(Loc.t("ending.%s.title" % rules.ending), 28, COL_GOOD if good else COL_DANGER, true, true))
	v.add_child(_label(Loc.t("ending.%s.text" % rules.ending), 16, COL_TEXT, true))
	v.add_child(_label(Loc.t("period.survived", [rules.done_periods()]), 18, COL_TEXT, true, true))
	if not rules.last_race.is_empty() and rules.phase == "chapter_end":
		var race: Dictionary = rules.last_race
		v.add_child(_label(Loc.t("race.result", [race["mine"], race["taras"]]), 16, COL_GOOD if race["mine"] >= race["taras"] else COL_DANGER, true))
		_budget_block(v)
	if rules.phase == "end":
		_run_record(v)
	var done := 0
	var late := 0
	for t in rules.tasks:
		if t["status"] == "done":
			done += 1
		if t["late"]:
			late += 1
	# (the end of an endless run has these in its own table)
	if rules.phase != "end":
		v.add_child(_label(Loc.t("summary.done", [done, late]), 15, COL_TEXT, true))
	var k := rules.key_status()
	if not rules.chapter_keys().is_empty():
		v.add_child(_label(Loc.render("summary.results", [], {"good": k["good"], "total": rules.chapter_keys().size(), "boss": "@weight." + rules.boss_word()}), 15, COL_TEXT, true))
	var bank_names := PackedStringArray()
	for b in rules.banks:
		bank_names.append(Loc.t("bank." + b))
	v.add_child(_label(Loc.t("summary.banks", [", ".join(bank_names) if not bank_names.is_empty() else Loc.t("summary.no_banks")]), 15, COL_TEXT, true))
	if rules.ending in ["leader", "puppeteer"]:
		v.add_child(_label(Loc.t("promoted.yes" if rules.promoted else "promoted.no"), 15, COL_GOOD if rules.promoted else COL_MUTED, true))
	_adizes_block(v)
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
		if rules.can_defend():
			pass
		elif rules.next_chapter_ready():
			buttons.add_child(_button(Loc.t("period.start" if rules.chapter == 0 else "chapter.start", [(rules.period if rules.chapter == 0 else rules.chapter) + 1]), _start_next_chapter, 260, "primary"))
		else:
			buttons.add_child(_button(Loc.t("to_menu"), _to_title.bind(false), 260, "primary"))
	else:
		buttons.add_child(_button(Loc.t("again"), _to_title.bind(true), 260, "primary"))
	v.add_child(buttons)


# The month's budget at Irina's: what she offers, what you can point to, and whether to argue.
func _budget_block(v: VBoxContainer) -> void:
	var race: Dictionary = rules.last_race
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_BG, COL_BORDER, 1, 16))
	v.add_child(card)
	_anchor(card, "budget")
	var box := _vbox(8)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(_avatar("boss", 40))
	var said := _vbox(2)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(said)
	said.add_child(_label(Loc.person("boss") + " · " + Loc.t("weight." + rules.boss_word()), 13, COL_MUTED))
	said.add_child(_label(Loc.t("budget.offer", [_rub(race["offer"])]), 16, COL_TEXT, true))
	if race.get("sla", 0) > 0:
		said.add_child(_label(Loc.t("budget.sla", [_rub(race["sla"])]), 14, COL_DANGER, true))
	var args := PackedStringArray()
	for a in race["args"]:
		args.append(Loc.t("budget.arg." + a))
	box.add_child(_label(Loc.t("budget.args", [", ".join(args)]) if not args.is_empty() else Loc.t("budget.no_args"), 14, COL_TEXT if not args.is_empty() else COL_MUTED, true))
	if race["defended"] == "":
		box.add_child(_label(Loc.t("budget.hint"), 13, COL_MUTED, true))
		var row := _flow(8, 8)
		box.add_child(row)
		for choice in ["take", "more", "lots"]:
			row.add_child(_button(Loc.t("budget.ask." + choice), _defend.bind(choice), 0, "primary" if choice == "take" else ""))
	else:
		var ok: bool = not race["defended"].ends_with("_no")
		box.add_child(_label(Loc.t("budget." + race["defended"], [_rub(race["budget"])]), 15, COL_TEXT if ok else COL_DANGER, true))


const MONEY_KINDS := ["budget", "salary", "hire", "severance", "upgrade", "bonus", "penalty", "other"]


# Where the month's money went, on a chart and line by line, down to what's left when the next budget comes.
func _money_window(body: VBoxContainer) -> void:
	body.add_child(_money_chart())
	body.add_child(_label(Loc.t("money.legend"), 12, COL_MUTED, true))
	var month := rules.money_month()
	var rows := _vbox(4)
	body.add_child(rows)
	if month["carried"] != 0:
		rows.add_child(_money_row(Loc.t("money.kind.carried"), month["carried"], COL_TEXT, false))
	for kind in MONEY_KINDS:
		var sum: int = month["kinds"].get(kind, 0)
		if sum != 0:
			rows.add_child(_money_row(Loc.t("money.kind." + kind), sum, COL_TEXT, false))
	rows.add_child(_money_row(Loc.t("money.now"), rules.money, COL_TEXT, true))
	if month["salaries_ahead"] > 0:
		rows.add_child(_money_row(Loc.t("money.ahead"), -month["salaries_ahead"], COL_TEXT, false))
	var left := rules.money_at_budget()
	rows.add_child(_money_row(Loc.t("money.left"), left, COL_DANGER if left < 0 else COL_GOOD, true))
	if month["fines"] > 0:
		body.add_child(_label(Loc.t("money.fines", [_rub(month["fines"])]), 13, COL_DANGER, true))


func _money_row(name: String, amount: int, color: Color, bold: bool) -> Control:
	var row := HBoxContainer.new()
	var l := _label(name, 14, color, false, bold)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(_label(("+" if amount > 0 and not bold else "") + _rub(amount), 14, color, false, bold))
	return row


# The month's balance day by day: solid up to now, dashed on to the next budget, with paydays and zero marked.
func _money_chart() -> Control:
	var curve := rules.money_curve()
	var chart := Control.new()
	chart.custom_minimum_size = Vector2(0, 170)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.draw.connect(func():
		var font := chart.get_theme_default_font()
		var days: int = curve["days"]
		var lo := 0.0
		var hi := 1.0
		for pt in curve["fact"] + curve["plan"]:
			lo = minf(lo, pt.y)
			hi = maxf(hi, pt.y)
		var pad := (hi - lo) * 0.1
		lo -= pad
		hi += pad
		var area := Rect2(8, 18, chart.size.x - 16, chart.size.y - 36)
		var at := func(pt: Vector2) -> Vector2:
			return Vector2(area.position.x + area.size.x * pt.x / days, area.position.y + area.size.y * (hi - pt.y) / (hi - lo))
		# Fridays, when salaries go out.
		for x in range(1, days + 1):
			if (rules.first_day() + x - 1) % 5 == 0:
				var top: Vector2 = at.call(Vector2(x, hi))
				var bottom: Vector2 = at.call(Vector2(x, lo))
				chart.draw_line(top, bottom, COL_BORDER, 1.0)
				chart.draw_string(font, bottom + Vector2(-8, 14), Loc.t("money.payday_mark"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_FAINT)
		chart.draw_dashed_line(at.call(Vector2(0, 0)), at.call(Vector2(days, 0)), COL_FAINT, 1.0, 4.0)
		var steps := func(pts: Array, color: Color, dashed: bool):
			for i in range(1, pts.size()):
				var a: Vector2 = at.call(pts[i - 1])
				var b: Vector2 = at.call(Vector2(pts[i].x, pts[i - 1].y))
				var c: Vector2 = at.call(pts[i])
				for seg in [[a, b], [b, c]]:
					if dashed:
						chart.draw_dashed_line(seg[0], seg[1], color, 2.0, 6.0)
					else:
						chart.draw_line(seg[0], seg[1], color, 2.5)
		var end: Vector2 = curve["plan"][-1]
		var plan_col := COL_DANGER if end.y < 0 else COL_MUTED
		steps.call(curve["fact"], COL_PRIMARY, false)
		steps.call(curve["plan"], plan_col, true)
		var now: Vector2 = curve["plan"][0]
		chart.draw_circle(at.call(now), 4.0, COL_PRIMARY)
		var tag := _rub(int(end.y))
		var tag_at: Vector2 = at.call(end)
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		chart.draw_string(font, Vector2(minf(tag_at.x - tw / 2.0, area.end.x - tw), maxf(tag_at.y - 6, 12)), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, plan_col))
	return chart


func _defend(choice: String) -> void:
	rules.defend_budget(choice)
	_render()


# What the next chapter is about, or that it's still being made.
func _next_chapter_block(v: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(COL_BG, COL_BORDER, 1, 16))
	var box := _vbox(6)
	card.add_child(box)
	box.add_child(_section(Loc.t("chapter.next")))
	if rules.chapter == 0:
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
uniform float round_cut = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, region.xy + UV * region.zw);
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(c.rgb, c.a * mix(1.0, 1.0 - smoothstep(0.47, 0.5, d), round_cut));
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


func _face(p: String, size: int, emo: String = "", square: bool = false) -> Control:
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
	mat.set_shader_parameter("round_cut", 0.0 if square else 1.0)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.material = mat
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.custom_minimum_size = Vector2(size, size)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


# A round face for the chat and the lists; square (square = true) for a photo pinned to the board.
func _avatar(p: String, size: int, emo: String = "", square: bool = false) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(size, size)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := _flat(AVATAR_COLORS.get(p, HIRE_COLORS[absi(p.hash()) % HIRE_COLORS.size()] if p.begins_with("hire") else COL_MUTED))
	style.set_corner_radius_all(1 if square else int(size / 2.0))
	box.add_theme_stylebox_override("panel", style)
	var name := Loc.t("you") if p == "me" else Loc.person(p)
	box.tooltip_text = name
	var face := _face(p, size, emo, square)
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
	# The scroll range is known only once the new content is laid out, which can take a couple of frames;
	# set too early, the position gets clipped to the top.
	for _frame in 3:
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
	b.custom_minimum_size = Vector2(min_width, 44 if compact else 34)
	b.add_theme_font_size_override("font_size", _fs(14))
	var fill := COL_COLUMN
	var hover := COL_BORDER
	var text_color := COL_TEXT
	match look:
		"primary":
			fill = COL_ACCENT
			hover = COL_ACCENT_HOVER
			text_color = COL_TEXT
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
		"answer":
			fill = COL_SURFACE
			hover = COL_SELECTED
	var edge := 1 if look == "answer" else 0
	b.add_theme_stylebox_override("normal", _box(fill, COL_BORDER, edge, 8))
	b.add_theme_stylebox_override("hover", _box(hover, COL_PRIMARY, edge, 8))
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


func _draw_turn(phone: Control) -> void:
	phone.draw_rect(Rect2(28, 8, 34, 60), COL_TEXT, false, 3.5)
	phone.draw_line(Vector2(40, 60), Vector2(50, 60), COL_TEXT, 3.0)
	phone.draw_arc(Vector2(45, 45), 38, -0.6, 0.9, 12, COL_PRIMARY, 3.5)
	phone.draw_line(Vector2(73, 72), Vector2(80, 64), COL_PRIMARY, 3.5)
	phone.draw_line(Vector2(73, 72), Vector2(64, 69), COL_PRIMARY, 3.5)
