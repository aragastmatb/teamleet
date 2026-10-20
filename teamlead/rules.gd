extends RefCounted
# Team lead prototype rules, no UI. main.gd drives it; tests can drive it headless.
#
# Each day: tasks arrive, you assign them (people may push back), pair people up, and hold one one-on-one.
# Ending the day simulates the work: progress, quality, fatigue, mood, growth. Fridays end with a
# review where you decide who gets the credit and who takes the blame. Skills and motives are hidden
# until results and conversations reveal them.

const C = preload("res://teamlead/content.gd")
const L = preload("res://teamlead/locale.gd")
const Scenes = preload("res://teamlead/scenes.gd")

const SPEED_BASE := 0.5
const SPEED_PER_SKILL := 0.35
const GOOD_Q := 2.6
const OK_Q := 1.6
const WEIRD_Q := 0.8
# Energy: a normal 8-hour day on work you can do barely tires anyone; staying late, work beyond you and
# being pushed do. Weekends put people back on their feet.
const DRAIN := 0.15
const HARD_DRAIN := 0.4
const OVERTIME_DRAIN := 0.35 # per hour past the 8
const WEEKEND_REST := 4.0
const MY_WEEKEND_REST := 3.0
const OVERLOAD_AT := 3
const IDLE_REST := 2.0
const DAYOFF_REST := 4.0
const SICK_DAYS := 2
const QUIT_MOOD := -5.0
const UNHAPPY_MOOD := -3.0
const TIRED_ENERGY := 2.0
const MY_HOURS := 8
const XP_BASE := 3.0
const XP_PER_SKILL := 2.0
const PUSH_DAYS := 2
const PUSH_SPEED := 0.2
# Below this much leaning overall you haven't really led at all (Adizes' "deadwood").
const STYLE_MIN := 6.0
# Getting stuck on a new task: chance on its first day, by how sure they are of it, and days until they see it.
const STUCK_CHANCE_WEAK := 0.3
const STUCK_CHANCE := 0.15
const STUCK_DAYS := 3

var rng := RandomNumberGenerator.new()
var scenes := Scenes.new()
var day := 1
# Which chapter (1..4) of C.CHAPTERS; days run on through the chapters.
var chapter := 1
var phase := "title" # plan, event, evening, report, review, end
var people := {}
var tasks: Array[Dictionary] = []
# Weight with Irina: how much she listens to you. Grows when you're visible (key projects, credit
# taken, honest warnings), drops with slips and lies, and is spent to protect the team.
var boss := 0.0
var weight_level := 1
var weight_cause := ""
# Results the boss can see: visible tasks delivered or slipped. Separate from weight, which you spend.
var merit := 0.0
var promoted := false
var vika_standing := 0
var hours := 0
var my_week_hours := []
# Hours you spent helping the team through their problems: managing, not doing.
var my_week_mgmt := []
# Marina's latest team survey: {"day", "quotes": [locale keys], "verdict": "for" / "wary" / "against"}.
var survey := {}
var quits := 0
# Who you've already talked to today.
var talked := {}
# The task deck still to come, and complications switched off by improvements.
var deck: Array = []
# When each card last arrived, by id: it isn't dealt again too soon, and a repeat is marked as one.
var seen_day := {}
# Chain cards on their way: [{"id", "day"}], dealt the morning of that day.
var chain_due: Array = []
var comp_off := {}
# Your attention: a few tokens a day for managing. Past them you stay late, and that wears you out.
var attention := 0
var overtime_today := 0
var my_energy := 10.0
var my_sick := 0
var sick_today := false
var visited_today := false
var init_next := {}
# Who feels like volunteering today: decided each morning from their energy, mood and character.
var offer_today := {}
# Which Irina this run has (a key of C.BOSSES) and how your leading leans, overall and this week.
var boss_type: String = C.DEFAULT_BOSS
# Who you were before this job: a key of C.PROFILES.
var profile: String = C.DEFAULT_PROFILE
var style := {}
var week_style := {}
var events: Array[Dictionary] = []
# The morning's cards, held back until the morning scenes are answered.
var arriving: Array = []
var review: Array[Dictionary] = []
var flags := {}
var ending := ""
var evening_from := 0
var next_uid := 0
# An objection waiting for your answer: {"uid", "p", "reason"}. Empty when none.
var pending := {}
# Times you invoked the boss without her asking: [{"p", "uid"}], checked that evening.
var lies: Array = []
# Today's pairs: task uid -> share of the helper's day spent on it. Fixed at the start of the evening.
var shares := {}
# Chat entries: {"who": speaker id, "you" or "" for narration; "key"; "args": [] for %s; "names": {} for {placeholders}; "day"}.
# Values starting with "@" are locale keys.
var history: Array = []
# Gena's first-steps tips in the chat (see update_tips).
var tips := true


# ---------- run and day flow ----------

func start_run(seed_value: int = -1, boss_kind: String = C.DEFAULT_BOSS, profile_kind: String = C.DEFAULT_PROFILE) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	day = 1
	chapter = 1
	people.clear()
	for p in C.TEAM:
		var base: Dictionary = C.PEOPLE[p]
		var skills := {}
		var xp := {}
		for cat in C.CATEGORIES:
			skills[cat] = clampi(base["skills"][cat] + rng.randi_range(-1, 1), 0, 4)
			xp[cat] = 0.0
		people[p] = {
			"skills": skills, "xp": xp, "energy": float(base["stamina"]), "mood": 1.0, "trust": 0,
			"sick": 0, "absent": false, "absent_reason": "", "off_next": false, "pushed": 0, "promised": false, "ambition": 0,
			"gone": false, "known": {}, "warned_mood": false, "warned_tired": false,
			"last_done": -10, "idle_said": false, "idle_days": 0, "promised_day": 0,
			"week_hours": _zeros(), "week_overtime": _zeros(), "week_extra": _zeros(), "week_absent": _zeros(), "week_done": _zeros(), "debts": 0, "caught_flattery": false, "done_cats": {}, "start": skills.duplicate(),
		}
	tasks.clear()
	comp_off.clear()
	flags.clear()
	deck.clear()
	seen_day.clear()
	chain_due.clear()
	_refill_deck()
	my_energy = 10.0
	my_sick = 0
	init_next.clear()
	boss_type = boss_kind
	profile = profile_kind
	if C.PROFILES[profile].get("knows_team", false):
		for p in C.TEAM:
			for cat in C.CATEGORIES:
				people[p]["known"]["skill." + cat] = true
	for x in C.PAEI:
		style[x] = 0.0
		week_style[x] = 0.0
	boss = 0.0
	weight_level = 1
	weight_cause = ""
	merit = 0.0
	vika_standing = 0
	hours = 0
	my_week_hours = _zeros()
	my_week_mgmt = _zeros()
	survey = {}
	quits = 0
	events.clear()
	review.clear()
	pending = {}
	lies.clear()
	flags.clear()
	history.clear()
	ending = ""
	_start_day()


func _start_day() -> void:
	_narrate("log.morning", [day_key()])
	var monday := day % 5 == 1 and day > 1
	if monday:
		my_energy = minf(10.0, my_energy + MY_WEEKEND_REST)
	for p in C.TEAM:
		var st: Dictionary = people[p]
		if st["gone"]:
			continue
		if monday:
			st["energy"] = minf(_stamina(p), st["energy"] + WEEKEND_REST)
		st["absent"] = st["sick"] > 0 or st["off_next"]
		st["absent_reason"] = "dayoff" if st["off_next"] else ("sick" if st["sick"] > 0 else "")
		if st["off_next"]:
			st["off_next"] = false
			st["energy"] = minf(_stamina(p), st["energy"] + DAYOFF_REST)
			_say(p, "absent.dayoff")
		elif st["sick"] > 0:
			st["sick"] -= 1
			_say(p, "absent.sick")
	# Today's cards come in once the morning's questions are answered, so the chat reads in order.
	arriving = _arrivals()
	talked.clear()
	offer_today.clear()
	for p in C.TEAM:
		if day > 1 and available(p) and not people[p]["absent"] and _wants_to_volunteer(p):
			offer_today[p] = true
	visited_today = false
	overtime_today = 0
	attention = 0 if my_sick > 0 else max_attention()
	sick_today = my_sick > 0
	if my_sick > 0:
		my_sick -= 1
	elif not queue_of("me").is_empty():
		# Doing a task yourself takes most of your day.
		attention = maxi(0, attention - 2)
	_queue_events()
	if events.is_empty():
		_deliver_arrivals()
		phase = "plan"
	else:
		phase = "event"


func _deliver_arrivals() -> void:
	for id in arriving:
		add_task(id)
	arriving = []


# This morning's work: the weekly report on Mondays (unless automated), key projects on their days,
# and a few cards from the deck — no more than two of one kind on one day.
func _arrivals() -> Array:
	var out: Array = []
	if day % 5 == 1 and not flags.has("automated_report"):
		out.append_array(C.tasks_with("kind", "weekly"))
	var keys: Dictionary = C.KEY_DAYS.get(chapter, {})
	if keys.has(chapter_day()):
		out.append(keys[chapter_day()])
	out.append_array(C.START_DAYS.get(chapter, {}).get(chapter_day(), []))
	for due in chain_due.duplicate():
		if due["day"] <= day:
			chain_due.erase(due)
			out.append(due["id"])
	var load := 0.0
	for id in out:
		load += C.TASKS[id]["size"]
	var target: float = C.DAILY_LOAD
	if flags.get("relief", false):
		flags["relief"] = false
		target -= 1.5
	while load < target and out.size() < C.MAX_CARDS_A_DAY:
		if deck.size() < 4:
			_refill_deck()
		var picked := -1
		for i in deck.size():
			var info: Dictionary = C.TASKS[deck[i]]
			var same := 0
			for id in out:
				if C.TASKS[id]["cat"] == info["cat"]:
					same += 1
			if same < C.MAX_SAME_KIND and day + info["size"] - 1 <= last_day() and _can_come_again(deck[i]) and not out.has(deck[i]):
				picked = i
				break
		if picked < 0:
			break
		var id: String = deck.pop_at(picked)
		out.append(id)
		load += C.TASKS[id]["size"]
	return out


# The same card doesn't come back while it's still on the board, nor within REPEAT_GAP working days.
func _can_come_again(id: String) -> bool:
	if day - seen_day.get(id, -100) < C.REPEAT_GAP:
		return false
	# Variants of one template (the same trouble at another team) keep a couple of days apart too.
	var tpl: String = C.TASKS[id].get("tpl", id)
	if tpl != id and day - seen_day.get(tpl, -100) < C.TEMPLATE_GAP:
		return false
	return not tasks.any(func(t): return t["id"] == id and not t["status"] in ["done", "declined"])


# A fresh shuffle of the base deck goes under what's left. Improvements keep their cards out.
func _refill_deck() -> void:
	var fresh: Array = C.DECK.get(chapter, []).duplicate()
	if flags.has("tech_debt_done"):
		fresh = fresh.filter(func(id): return not C.TASKS[id]["tags"].has("debt"))
	for i in range(fresh.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = fresh[i]
		fresh[i] = fresh[j]
		fresh[j] = tmp
	deck.append_array(fresh)


func add_task(id: String) -> void:
	var info: Dictionary = C.TASKS[id]
	# Near the end of the probation, deadlines squeeze into what's left of it.
	add_task_raw(id, info["cat"], info["size"], mini(day + info["due"], last_day()), info["public"], info["from"])
	_say(info["from"], "task.%s.ask" % id)


func add_task_raw(id: String, cat: String, size: float, due: int, public: bool, from: String) -> void:
	tasks.append({
		"uid": next_uid, "id": id, "cat": cat, "size": size, "progress": 0.0,
		"due": due, "public": public, "from": from, "owner": "", "helper": "",
		"q_sum": 0.0, "q_days": 0.0, "status": "inbox", "late": false, "quality": "",
		"done_day": 0, "reviewed": false, "assigned_day": 0, "helped": {}, "first": false,
		"asked": false, "vouched": false, "flaw": false, "complicated": false, "blocked": 0, "q_bonus": 0.0, "involved": false,
		"key": chapter_keys().has(id), "sit_today": false, "again": seen_day.has(id),
	})
	seen_day[id] = day
	seen_day[C.TASKS.get(id, {}).get("tpl", id)] = day
	next_uid += 1


func _queue_events() -> void:
	scenes.queue(self)
	_say_event_lines()


func _say_event_lines() -> void:
	if events.is_empty():
		return
	var ev: Dictionary = events[0]
	for line in ev["lines"]:
		_say(line["who"], line["key"], [], ev["names"])


func resolve_event(choice: String) -> void:
	if phase != "event" or events.is_empty() or not events[0]["choices"].has(choice):
		return
	scenes.resolve(self, events.pop_front(), choice)
	_weight_check()
	if events.is_empty():
		_deliver_arrivals()
		phase = "plan"
	else:
		_say_event_lines()


# ---------- planning ----------

func task(uid: int) -> Dictionary:
	for t in tasks:
		if t["uid"] == uid:
			return t
	return {}


func inbox() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in tasks:
		if t["status"] == "inbox":
			result.append(t)
	return result


func queue_of(p: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in tasks:
		if t["status"] == "active" and t["owner"] == p:
			result.append(t)
	result.sort_custom(func(a, b):
		if a["first"] != b["first"]:
			return a["first"]
		return a["due"] < b["due"] or (a["due"] == b["due"] and a["uid"] < b["uid"]))
	return result


func available(p: String) -> bool:
	return C.TEAM.has(p) and not people[p]["gone"]


func assign(uid: int, p: String) -> void:
	var t := task(uid)
	if phase != "plan" or not pending.is_empty() or t.is_empty() or t["status"] == "done" or t["status"] == "taras" or p == t["owner"]:
		return
	_tip_used("inbox")
	var previous: String = t["owner"]
	if p == "taras":
		_hand_to_taras(t)
		return
	if p != "me" and not available(p):
		return
	var names := {"task": "@taskname." + t["id"]}
	if p != "me":
		history.append({"who": "you", "key": "assign.say", "args": [], "names": names, "to": p, "day": day})
	if C.TEAM.has(previous) and t["progress"] > 0.0 and not people[previous]["gone"]:
		people[previous]["mood"] -= 0.5
		_say(previous, "taken_away", [], names)
	_check_commitments(t, p)
	var reason := _objection(p, t) if p != "me" else ""
	t["owner"] = p
	t["status"] = "active"
	t["assigned_day"] = day
	t["first"] = false
	if t["helper"] == p:
		t["helper"] = ""
	if p == "me":
		lead("P", 2.0)
		_say("", "you.myself_note", [], names)
		for q in C.TEAM:
			if available(q) and not people[q]["absent"] and people[q]["skills"][t["cat"]] >= 3 and queue_of(q).size() <= 1:
				people[q]["mood"] = clampf(people[q]["mood"] - 0.7, -5.0, 5.0)
				_say(q, "slighted", [], names)
				break
		return
	if reason != "":
		pending = {"uid": uid, "p": p, "reason": reason}
		_say(p, _first_key(["object.%s.%s" % [p, reason], "object.any." + reason]), [], names)
		return
	_accept(p, t, 0.0, "")


# Things you promised in one-on-ones get checked when you hand out work.
func _check_commitments(t: Dictionary, p: String) -> void:
	var names := {"task": "@taskname." + t["id"]}
	if t["key"]:
		for q in C.TEAM:
			if flags.has("stretch_" + q) and available(q):
				flags.erase("stretch_" + q)
				if q == p:
					people[q]["trust"] += 1
				else:
					people[q]["trust"] -= 2
					people[q]["mood"] -= 1.0
					_say(q, "talk.stretch.broken", [], names)
	if C.TEAM.has(p) and flags.get("calm_" + p, 0) >= day and t["due"] - day <= 1:
		flags.erase("calm_" + p)
		people[p]["trust"] -= 2
		_say(p, "talk.calm.broken", [], names)


# Why this person would push back on this task right now, or "" if they just take it.
func _objection(p: String, t: Dictionary) -> String:
	var st: Dictionary = people[p]
	var load := 0.0
	var count := 0
	for q in queue_of(p):
		if q["uid"] != t["uid"]:
			load += q["size"] - q["progress"]
			count += 1
	if _feels_tired(p):
		return "tired"
	if count >= 2 and load >= 2.5:
		return "overload"
	if C.PEOPLE[p]["hates"].has(t["cat"]):
		return "hates"
	if C.PEOPLE[p]["drive"] == "peace" and t["due"] - day <= 1:
		return "rush"
	if st["skills"][t["cat"]] <= 1 and C.PEOPLE[p]["drive"] != "growth":
		return "weak"
	if st["mood"] <= -2.0:
		return "mood"
	return ""


# Is what you'd say with this intent actually true here?
func intent_true(intent: String) -> bool:
	if pending.is_empty():
		return true
	var t := task(pending["uid"])
	var p: String = pending["p"]
	match intent:
		"flatter":
			return people[p]["skills"][t["cat"]] >= 3
		"boss":
			return t["public"] or t["from"] == "boss"
	return true


func persuade(intent: String) -> void:
	if pending.is_empty():
		return
	var t := task(pending["uid"])
	var p: String = pending["p"]
	var reason: String = pending["reason"]
	pending = {}
	var st: Dictionary = people[p]
	var names := {"task": "@taskname." + t["id"]}
	history.append({"who": "you", "key": _first_key(["say.%s.%s" % [intent, reason], "say." + intent]), "args": [], "names": names, "to": p, "day": day})
	lead({"order": "P", "honest": "I", "boss": "A", "promise": "I", "flatter": "I", "back_off": "I"}[intent], 0.5 if intent == "order" else 0.3)
	if intent == "back_off":
		unassign_now(t)
		st["mood"] = clampf(st["mood"] + 0.3, -5.0, 5.0)
		_say(p, "persuade.back_off.reply")
		return
	var drive: String = C.PEOPLE[p]["drive"]
	var taste: int = C.INTENT_TASTE[drive][intent]
	var delta: float = -1.0 + taste + C.PROFILES[profile]["talk"]
	var reply := ""
	match intent:
		"honest":
			if reason == "tired" or reason == "overload":
				delta -= 0.5
			if reason == "weak" and drive == "growth":
				delta += 1.0
		"flatter":
			if not intent_true("flatter") or st["caught_flattery"]:
				st["caught_flattery"] = true
				st["trust"] -= 1
				delta = -1.5
				reply = "persuade.flatter_fake"
		"boss":
			if not intent_true("boss"):
				lies.append({"p": p, "uid": t["uid"]})
		"promise":
			if st["debts"] > 0:
				st["trust"] -= 1
				delta = -1.5
				reply = "persuade.promise_again"
			else:
				st["debts"] += 1
		"order":
			if reason == "tired" or reason == "overload":
				st["trust"] -= 1
	_accept(p, t, delta, reply)
	if absi(taste) >= 2 and reply == "":
		_reveal(p, "drive")


# They take the task. Mood moves with what it is and how you got them to take it.
func _accept(p: String, t: Dictionary, delta: float, reply: String) -> void:
	var st: Dictionary = people[p]
	if C.PEOPLE[p]["likes"].has(t["cat"]):
		delta += 1.0
	if C.PEOPLE[p]["hates"].has(t["cat"]):
		delta -= 1.0
	if p == "vika" and t["public"]:
		delta += 1.0
	if leans("I"):
		delta += 0.4
	if delta < 0.0 and C.PEOPLE[p].get("touchy", false):
		delta *= 1.3
	var terms_line := ""
	if p == "alex" and flags.has("alex_terms"):
		if t["cat"] == "support":
			delta -= 1.0
			terms_line = "alex.terms_broken"
		elif t["cat"] == "infra":
			delta += 0.5
	st["mood"] = clampf(st["mood"] + delta, -5.0, 5.0)
	if reply == "":
		reply = "react.%s.%s" % [p, "pos" if delta >= 1.0 else ("neg" if delta <= -1.0 else "neu")]
	_say(p, reply, [], {"task": "@taskname." + t["id"]})
	if terms_line != "":
		_say(p, terms_line)


# A role isn't given, it's what someone ends up doing: three or more tasks done, most in one area.
func role_of(p: String) -> String:
	var done: Dictionary = people[p]["done_cats"]
	var total := 0
	var best := ""
	for cat in done:
		total += done[cat]
		if best == "" or done[cat] > done[best]:
			best = cat
	if total >= 3 and done[best] >= 2 and done[best] * 2 > total:
		return best
	return ""


func _first_key(keys: Array) -> String:
	for k in keys:
		if L.has_key(k):
			return k
	return keys[keys.size() - 1]


func _hand_to_taras(t: Dictionary) -> void:
	history.append({"who": "you", "key": "you.to_taras", "args": [], "names": {}, "day": day})
	if t["from"] != "taras" and flags.get("taras_owes", false):
		flags["taras_owes"] = false
		t["owner"] = "taras"
		t["status"] = "taras"
		t["helper"] = ""
		_say("taras", "taras.accept_owed", [], {"task": "@taskname." + t["id"]})
		return
	if t["from"] == "taras" or flags.has("taras_grudge") or flags.get("taras_said_no", 0) >= 2 or rng.randf() < 0.5:
		flags["taras_said_no"] = flags.get("taras_said_no", 0) + 1
		var no := "taras.refuse_own" if t["from"] == "taras" else ("taras.refuse_grudge" if flags.has("taras_grudge") else "taras.refuse")
		_say("taras", no, [], {"task": "@taskname." + t["id"]})
		return
	t["owner"] = "taras"
	t["status"] = "taras"
	t["helper"] = ""
	_say("taras", "taras.accept", [], {"task": "@taskname." + t["id"]})


# Move a task to the front of its owner's queue. Dropping something half-done costs a little mood.
func prioritize(uid: int) -> void:
	var t := task(uid)
	if phase != "plan" or t.is_empty() or t["status"] != "active" or not C.TEAM.has(t["owner"]):
		return
	var p: String = t["owner"]
	var head: Dictionary = queue_of(p)[0]
	if head["uid"] == uid:
		return
	for other in queue_of(p):
		other["first"] = false
	t["first"] = true
	lead("A", 0.3)
	if head["progress"] > 0.0:
		people[p]["mood"] = clampf(people[p]["mood"] - 0.3, -5.0, 5.0)
	history.append({"who": "you", "key": "prioritize.say", "args": [], "names": {"task": "@taskname." + t["id"]}, "to": p, "day": day})
	_say(p, _first_key(["prioritize.reply." + p, "prioritize.reply"]))


func set_helper(uid: int, p: String) -> void:
	var t := task(uid)
	if phase != "plan" or t.is_empty() or t["status"] != "active" or p == t["owner"] or (p != "" and not available(p)):
		return
	if flags.has("no_pair_alex_vika") and [p, t["owner"]].has("alex") and [p, t["owner"]].has("vika"):
		_say("alex", "helper.no_vika")
		return
	t["helper"] = p
	if p != "":
		lead("I", 0.2)
		_say(p, "helper.join", [], {"task": "@taskname." + t["id"], "owner": "@name.%s.nom" % t["owner"]})


func unassign(uid: int) -> void:
	var t := task(uid)
	if phase != "plan" or t.is_empty() or t["status"] != "active":
		return
	unassign_now(t)


func unassign_now(t: Dictionary) -> void:
	t["owner"] = ""
	t["helper"] = ""
	t["status"] = "inbox"
	t["first"] = false


# A one-on-one: they come with whatever is on their mind (see scenes.gd), you answer.
func start_talk(p: String) -> void:
	if not can_talk(p):
		return
	talked[p] = true
	_tip_used("talk")
	lead("I", 0.3)
	spend_attention()
	history.append({"who": "you", "key": "talk.open", "args": [], "names": {}, "to": p, "day": day})
	_open_conversation(scenes.talk_event(self, p))


# Going to Irina: one visit a day, one topic per visit.
func visit_boss() -> void:
	if phase != "plan" or not pending.is_empty() or visited_today:
		return
	visited_today = true
	spend_attention()
	history.append({"who": "you", "key": "visit.open", "args": [], "names": {}, "day": day})
	_open_conversation(scenes.boss_visit(self))


func _open_conversation(ev: Dictionary) -> void:
	ev.merge({"names": {}, "uid": -1}, false)
	events.push_front(ev)
	_say_event_lines()
	phase = "event"


# Tell them what you've learned about yourself, in their own words.
func reveal_next(p: String) -> void:
	var key := _next_unknown(p)
	if key == "":
		_say(p, "talk.listen.nothing")
		return
	var line := "talk.listen.%s.%s" % [p, key.replace("skill.", "")]
	_say(p, line if L.has_key(line) else "talk.listen.any")
	_reveal(p, key)


func give_day_off(p: String) -> void:
	var st: Dictionary = people[p]
	st["off_next"] = true
	if st["debts"] > 0:
		st["debts"] = 0
		st["trust"] += 1


# Take one non-key task off someone's plate back to the inbox; true if there was one.
func lighten(p: String) -> bool:
	var q := queue_of(p)
	for i in range(q.size() - 1, -1, -1):
		if not q[i]["key"] and q[i]["progress"] == 0.0:
			unassign_now(q[i])
			return true
	return false


# Does this answer to a morning scene take your attention?
func choice_costs(ev: Dictionary, choice: String) -> bool:
	if ev.has("comp"):
		var fx: Dictionary = C.COMPLICATIONS[ev["comp"]]["choices"].get(choice, {})
		return fx.get("hours", 0) > 0
	return ["dima_mistake/help", "marina_warns/listen", "vika_promise_check/do_now"].has(ev["id"] + "/" + choice)


func can_talk(p: String) -> bool:
	return phase == "plan" and pending.is_empty() and not talked.has(p) and available(p) and not people[p]["absent"]


# Every bit of managing costs a token of attention; past them you're staying late.
func spend_attention() -> void:
	if attention > 0:
		attention -= 1
	else:
		overtime_today += 1


# Sit down with someone over their task today: it goes faster and better, they learn, and you were
# personally involved (which makes "under my personal control" true at the review).
func sit_with(uid: int) -> void:
	var t := task(uid)
	if phase != "plan" or not pending.is_empty() or t.is_empty() or t["status"] != "active" or t.get("sit_today", false):
		return
	var p: String = t["owner"]
	if not C.TEAM.has(p) or not available(p) or people[p]["absent"]:
		return
	spend_attention()
	lead("P", 0.5)
	lead("I", 0.5)
	my_week_mgmt[week()] += 2
	t["sit_today"] = true
	t["involved"] = true
	history.append({"who": "you", "key": "sit.say", "args": [], "names": {"task": "@taskname." + t["id"]}, "to": p, "day": day})
	if C.PEOPLE[p]["drive"] == "craft" and people[p]["skills"][t["cat"]] >= 3:
		people[p]["mood"] -= 0.5
		_say(p, "sit.micro")
	else:
		people[p]["mood"] += 0.5
		_say(p, "sit.ok")


# Step into someone's task: ask how it's going and steer it (see scenes.gd intervene). Once a day per task.
func intervene(uid: int) -> void:
	var t := task(uid)
	if phase != "plan" or not pending.is_empty() or t.is_empty() or t["status"] != "active" or t.get("checked_day", 0) == day:
		return
	_tip_used("active")
	var p: String = t["owner"]
	if not C.TEAM.has(p) or not available(p) or people[p]["absent"]:
		return
	t["checked_day"] = day
	spend_attention()
	history.append({"who": "you", "key": "intervene.open", "args": [], "names": {"task": "@taskname." + t["id"]}, "to": p, "day": day})
	_open_conversation(scenes.intervene_event(self, t))


func can_intervene(t: Dictionary) -> bool:
	return phase == "plan" and pending.is_empty() and t["status"] == "active" and C.TEAM.has(t["owner"]) and available(t["owner"]) \
		and not people[t["owner"]]["absent"] and t.get("checked_day", 0) != day


# You take it off their hands mid-way. Getting into someone else's half-done work loses half of it.
func take_over(t: Dictionary) -> void:
	t["progress"] *= 0.5
	t["owner"] = "me"
	t["helper"] = ""
	t["first"] = false
	t["involved"] = true
	t["pace"] = 1.0
	t["assigned_day"] = day


# What a free person offers to do on their own, or "" if nothing (or they're busy).
func initiative_offer(p: String) -> String:
	if phase != "plan" or not offer_today.has(p) or not available(p) or people[p]["absent"] or not queue_of(p).is_empty():
		return ""
	for t in tasks:
		if t["status"] == "active" and t["helper"] == p:
			return ""
	var list: Array = C.INITIATIVES[p]
	var i: int = init_next.get(p, 0)
	while i < list.size() and _initiative_done(list[i]):
		i += 1
	return list[i] if i < list.size() else ""


func _initiative_done(id: String) -> bool:
	return id != "showcase" and id != "self_study" and flags.has("init_" + id)


func accept_initiative(p: String) -> void:
	var id := initiative_offer(p)
	if id == "" or not pending.is_empty():
		return
	init_next[p] = C.INITIATIVES[p].find(id) + 1
	for pair in INIT_STYLE.get(id, []):
		lead(pair[0], pair[1])
	flags["init_" + id] = true
	var info: Dictionary = C.INIT_TASKS[id]
	add_task_raw("init_" + id, info["cat"], info["size"], last_day() + 10, false, p)
	var t: Dictionary = tasks[tasks.size() - 1]
	t["owner"] = p
	t["status"] = "active"
	t["assigned_day"] = day
	history.append({"who": "you", "key": "init.yes", "args": [], "names": {}, "to": p, "day": day})
	var drive: String = C.PEOPLE[p]["drive"]
	people[p]["mood"] = clampf(people[p]["mood"] + (1.5 if drive == "craft" or drive == "growth" else 1.0), -5.0, 5.0)
	_say(p, "react.%s.pos" % p)


# An initiative is finished: it changes the decks or the people.
func _initiative_effect(t: Dictionary) -> void:
	var id: String = t["id"].trim_prefix("init_")
	var names := {"who": "@name.%s.nom" % t["owner"]}
	match id:
		"tech_debt":
			flags["tech_debt_done"] = true
			comp_off["legacy_bug"] = true
			deck = deck.filter(func(id): return not C.TASKS[id]["tags"].has("debt"))
		"automate_report":
			flags["automated_report"] = true
		"showcase":
			vika_up()
		"self_study":
			var weakest: String = C.CATEGORIES[0]
			for cat in C.CATEGORIES:
				if people[t["owner"]]["skills"][cat] < people[t["owner"]]["skills"][weakest]:
					weakest = cat
			learn(t["owner"], weakest, 4.0)
			names["cat"] = "@cat." + weakest
		"write_docs":
			comp_off["missing_docs"] = true
			comp_off["old_system"] = true
	_narrate("init.done." + id, [], names)


func _next_unknown(p: String) -> String:
	var known: Dictionary = people[p]["known"]
	if not known.has("drive"):
		return "drive"
	var best := ""
	for cat in C.CATEGORIES:
		var key: String = "skill." + cat
		if not known.has(key) and (best == "" or people[p]["skills"][cat] > people[p]["skills"][best.replace("skill.", "")]):
			best = key
	return best


func _reveal(p: String, key: String) -> void:
	var known: Dictionary = people[p]["known"]
	if known.has(key):
		return
	known[key] = true
	if key == "drive":
		_narrate("know.drive", [], {"who": "@name.%s.nom" % p, "drive": "@drive." + C.PEOPLE[p]["drive"]})
	else:
		var cat := key.replace("skill.", "")
		_narrate("know.skill", [], {"who": "@name.%s.nom" % p, "cat": "@cat." + cat, "level": "@level.%d" % people[p]["skills"][cat]})


# ---------- the day's work ----------

func end_day() -> void:
	if phase != "plan" or not pending.is_empty():
		return
	flags.erase("tip_hl")
	evening_from = history.size()
	_narrate("log.evening")
	shares.clear()
	for t in tasks:
		var share := help_share(t)
		if share > 0.0:
			shares[t["uid"]] = share
	for p in C.TEAM:
		_work(p)
	_work_myself()
	for t in tasks:
		t["sit_today"] = false
		if t["blocked"] > 0:
			t["blocked"] -= 1
	_end_of_my_day()
	shares.clear()
	for t in tasks:
		if t["status"] == "taras" and t["due"] <= day:
			t["status"] = "done"
			t["quality"] = "ok"
			t["done_day"] = day
			if t["owner"] == "contractor":
				_narrate("contractor.done", [], {"task": "@taskname." + t["id"]})
			else:
				_say("taras", "taras.done", [], {"task": "@taskname." + t["id"]})
	for t in tasks:
		if (t["status"] == "inbox" or t["status"] == "active") and t["due"] == day and not t["late"]:
			t["late"] = true
			t["late_day"] = day
			_late(t)
			if t["vouched"]:
				boss -= 1
				_say("boss", "boss.vouched_late", [], {"task": "@taskname." + t["id"]})
	_advance_chains()
	_check_lies()
	for p in C.TEAM:
		_check_person(p)
	_weight_check()
	if C.SURVEY_AT.has(chapter_day()):
		_run_survey()
	if day % 5 == 0:
		_style_week()
		_build_review()
		if review.is_empty():
			_narrate("review.empty")
		phase = "report"
	else:
		phase = "evening"


# Staying late wears you down; rest days bring you back. Run yourself into the ground and you're
# off sick tomorrow, and the team works without you.
func _end_of_my_day() -> void:
	if overtime_today > 0:
		my_energy -= 2.0 * overtime_today
	elif not queue_of("me").is_empty():
		my_energy -= 1.0
	else:
		my_energy = minf(10.0, my_energy + 1.5)
	if my_energy <= 0.0:
		my_sick = 1
		my_energy = 6.0
		_narrate("you.burnout")
	# Untouched tech debt makes itself felt: each Friday another outage goes into the deck.
	if day % 5 == 0 and day < last_day() and not flags.has("tech_debt_done"):
		var fires := C.tasks_with("tag", "debt")
		if not fires.is_empty():
			deck.insert(mini(2, deck.size()), fires[rng.randi() % fires.size()])
		_narrate("deck.neglect_tech")


func my_state() -> String:
	if my_energy >= 7.0:
		return "fresh"
	if my_energy >= 4.0:
		return "ok"
	if my_energy > 2.0:
		return "tired"
	return "drained"


# Half the time, whoever you told "the boss asked" goes and mentions it to her.
func _check_lies() -> void:
	for lie in lies:
		var p: String = lie["p"]
		if not available(p) or rng.randf() > 0.5:
			continue
		people[p]["trust"] -= 2
		people[p]["mood"] = clampf(people[p]["mood"] - 1.0, -5.0, 5.0)
		flags["lied_" + p] = true
		_say(p, "lie.boss_found." + p, [], {"task": "@taskname." + task(lie["uid"])["id"]})
	lies.clear()


# The boss minds every slipped task she asked for or will look at. Others' requests only reach her
# when the same person has complained twice.
func _late(t: Dictionary) -> void:
	var names := {"task": "@taskname." + t["id"]}
	if t["public"] or t["from"] == "boss":
		boss -= 2.0 if t["key"] else 1.0
		merit -= 1.0
		weight_cause = t["id"]
		_narrate("late.key" if t["key"] else "late", [], names)
		return
	var who: String = t["from"]
	flags["complaints_" + who] = flags.get("complaints_" + who, 0) + 1
	_say(who, "late.complain.%s" % who, [], names)
	if flags["complaints_" + who] == 2:
		boss -= 1
		_narrate("late.escalated", [], {"who": "@name.%s.nom" % who, "who_gen": "@name.%s.gen" % who})


# After the Friday report: the review if there's anything to discuss, otherwise the evening.
func continue_report() -> void:
	if phase != "report":
		return
	phase = "review" if not review.is_empty() else "evening"


# Announce when Irina starts listening to you more or less, and why.
func _weight_check() -> void:
	var level := _level_of(boss)
	if level != weight_level:
		var names := {"level": "@weight.w%d" % level, "cause": ""}
		if weight_cause != "":
			names["cause"] = "@weight.after"
			names["task"] = "@taskname." + weight_cause
		_narrate("weight.up" if level > weight_level else "weight.down", [], names)
		weight_level = level
	weight_cause = ""


func has_weight() -> bool:
	return _level_of(boss) >= 2


func vika_up() -> void:
	vika_standing += 1
	_narrate("vika.visit")


# Spend weight on an outside contractor who takes a task off the team.
func hire_contractor(uid: int) -> void:
	var t := task(uid)
	if t.is_empty() or t["status"] == "done" or t["status"] == "taras":
		return
	if not has_weight():
		_say("boss", "contractor.no", [], {"task": "@taskname." + t["id"]})
		return
	if C.TEAM.has(t["owner"]) and t["progress"] > 0.0:
		people[t["owner"]]["mood"] -= 0.5
	t["owner"] = "contractor"
	t["status"] = "taras"
	t["helper"] = ""
	boss -= 1.5
	weight_cause = t["id"]
	_say("boss", "contractor.yes", [], {"task": "@taskname." + t["id"]})
	_weight_check()


# The day's name inside the chapter, "Wednesday, week 2", as a locale reference.
func day_key() -> String:
	return "@day.%d" % chapter_day()


func week() -> int:
	return clampi(int((day - 1) / 5.0), 0, C.WEEKS - 1)


func _zeros() -> Array:
	var a := []
	a.resize(C.WEEKS)
	a.fill(0)
	return a


func add_mgmt_hours(n: int) -> void:
	my_week_mgmt[week()] += n
	spend_attention()


func add_my_hours(n: int) -> void:
	hours += n
	my_week_hours[week()] += n


func _speed(p: String, t: Dictionary) -> float:
	var st: Dictionary = people[p]
	var skill: int = st["skills"][t["cat"]]
	var s := SPEED_BASE + SPEED_PER_SKILL * skill
	s *= 1.0 + st["mood"] * 0.04
	if st["pushed"] > 0:
		s *= 1.0 + PUSH_SPEED
	if leans("P"):
		s *= 1.05
	# Told to hurry or to take care when you stepped in.
	s *= t.get("pace", 1.0)
	var share: float = shares.get(t["uid"], 0.0)
	if share > 0.0 and people.has(t["helper"]):
		var hs: int = people[t["helper"]]["skills"][t["cat"]]
		if hs > skill:
			s += share * 0.5 * (SPEED_BASE + SPEED_PER_SKILL * hs)
		elif hs < skill:
			s *= 1.0 - 0.15 * share # explaining takes time
		else:
			s += share * 0.3 * (SPEED_BASE + SPEED_PER_SKILL * hs)
	return s


# How much of the helper's day goes to this task: all of it if they have nothing of their own,
# half if they do. Someone listed as helper on several tasks only helps with the first.
func help_share(t: Dictionary) -> float:
	var h: String = t["helper"]
	if t["status"] != "active" or h == "" or not C.TEAM.has(t["owner"]) or not available(h) or people[h]["absent"]:
		return 0.0
	if not available(t["owner"]) or people[t["owner"]]["absent"]:
		return 0.0
	for other in tasks:
		if other["status"] == "active" and other["helper"] == h:
			if other["uid"] != t["uid"]:
				return 0.0
			break
	return 1.0 if queue_of(h).is_empty() else 0.5


func _helping_task(p: String) -> Dictionary:
	for t in tasks:
		if t["helper"] == p and shares.has(t["uid"]):
			return t
	return {}


# The helper's half (or whole) day in the pair: they learn, faster from someone who knows more.
func _help(p: String, t: Dictionary, share: float) -> void:
	var owner: String = t["owner"]
	var hs: int = people[p]["skills"][t["cat"]]
	var os: int = people[owner]["skills"][t["cat"]]
	var mentor := 1.3 if flags.has("gena_mentor") and [p, owner].has("gena") and [p, owner].has("dima") else 1.0
	_learn(p, t["cat"], 1.2 * share * mentor * (1.0 + 0.25 * maxi(0, os - hs)))
	var kind := "learn" if hs < os else ("boost" if hs > os else "even")
	_narrate("pair." + kind, [], {"helper": "@name.%s.nom" % p, "owner_ins": "@name.%s.ins" % owner,
		"task": "@taskname." + t["id"], "half": "@pair.half" if share < 1.0 else ""})


# Days of work left on a task for this person (and its helper, if any). Known skills give a real
# estimate; unknown ones are the lead's rough guess, as if someone decent did it.
func estimate(t: Dictionary, p: String = "") -> Dictionary:
	var who: String = p if p != "" else t["owner"]
	var left: float = maxf(0.0, t["size"] - t["progress"])
	if who == "me":
		return {"days": left / my_speed(t["cat"]) + t["blocked"], "sure": true}
	var sure := true
	var skill := 2
	if C.TEAM.has(who) and people[who]["known"].has("skill." + t["cat"]):
		skill = people[who]["skills"][t["cat"]]
	else:
		sure = false
	var speed := SPEED_BASE + SPEED_PER_SKILL * skill
	var h: String = t["helper"] if p == "" or p == t["owner"] else ""
	if h != "" and available(h):
		var share := 1.0 if queue_of(h).is_empty() else 0.5
		var hs := 2
		if people[h]["known"].has("skill." + t["cat"]):
			hs = people[h]["skills"][t["cat"]]
		else:
			sure = false
		if hs > skill:
			speed += share * 0.5 * (SPEED_BASE + SPEED_PER_SKILL * hs)
		elif hs < skill:
			speed *= 1.0 - 0.15 * share
		else:
			speed += share * 0.3 * (SPEED_BASE + SPEED_PER_SKILL * hs)
	return {"days": left / speed + t["blocked"], "sure": sure}


func _work(p: String) -> void:
	var st: Dictionary = people[p]
	if st["gone"]:
		return
	if st["absent"]:
		if st["absent_reason"] == "taras":
			st["energy"] -= 0.5
			st["week_hours"][week()] += 8
		else:
			st["energy"] = minf(_stamina(p), st["energy"] + IDLE_REST)
			st["week_absent"][week()] += 1
		return
	var q := queue_of(p)
	var helping := _helping_task(p)
	var help_part: float = shares.get(helping["uid"], 0.0) if not helping.is_empty() else 0.0
	# Half the day went on the boss's urgent meeting.
	var meeting: float = 0.5 if flags.get("meeting_day", -1) == day else 1.0
	if not q.is_empty():
		# The day is spent down the queue: whatever's left after finishing one task goes to the next.
		# Half of it goes to the pair if they're helping someone.
		var first: Dictionary = q[0]
		var late := late_hours(p)
		var time := (1.0 - help_part) * meeting + late / 8.0
		var stuck: Array = []
		for t in q:
			if time < 0.05:
				break
			if t["blocked"] > 0:
				stuck.append(t)
				continue
			var skill: int = st["skills"][t["cat"]]
			if _stuck_today(p, t, skill):
				time = 0.0
				continue
			var step := _speed(p, t) * (1.2 if t["sit_today"] else 1.0)
			var spend := minf(time, (t["size"] - t["progress"]) / step)
			time -= spend
			t["progress"] += step * spend
			var quality: float = skill + st["mood"] * 0.1 + rng.randf_range(-0.7, 0.7)
			var h: String = t["helper"]
			var share: float = shares.get(t["uid"], 0.0)
			if share > 0.0:
				t["helped"][h] = t["helped"].get(h, 0) + 1
				if people[h]["skills"][t["cat"]] > skill:
					quality += 0.5 * share
			if t["sit_today"]:
				quality += 0.6
				_learn(p, t["cat"], 0.5 * spend)
			t["q_sum"] += quality * spend
			t["q_days"] += spend
			_learn(p, t["cat"], spend)
			if C.PEOPLE[p]["likes"].has(t["cat"]):
				st["mood"] += 0.3 * spend
			if C.PEOPLE[p]["hates"].has(t["cat"]):
				st["mood"] -= 0.4 * spend
			if t["progress"] >= t["size"] - 0.001:
				_finish(p, t)
			else:
				# How far they got today, relative to the task: the main way to read someone's skill.
				var part: float = step * spend / t["size"]
				var pace := "big" if part >= 0.45 else ("mid" if part >= 0.25 else "small")
				_narrate("pace." + pace, [], {"who": "@name.%s.nom" % p, "task": "@taskname." + t["id"]})
		for t in stuck:
			_narrate("blocked", [], {"task": "@taskname." + t["id"], "who": "@name.%s.nom" % p})
		var drain: float = DRAIN
		if st["skills"][first["cat"]] < 2:
			drain += HARD_DRAIN
		if q.size() >= OVERLOAD_AT:
			st["mood"] -= 0.3
		# The late hours are what wear people down.
		st["week_hours"][week()] += 8
		if late > 0:
			st["week_extra"][week()] += late
			st["week_overtime"][week()] += 1
			drain += OVERTIME_DRAIN * late
			_narrate("stayed_late", [], {"who": "@name.%s.nom" % p, "hours": late, "task": "@taskname." + first["id"]})
		st["energy"] -= drain
		st["idle_said"] = false
		st["idle_days"] = 0
	if help_part > 0.0:
		_help(p, helping, help_part)
	if q.is_empty():
		st["idle_days"] = 0 if help_part > 0.0 else st["idle_days"] + 1
		if help_part > 0.0:
			st["week_hours"][week()] += 8
			st["energy"] -= DRAIN
		else:
			st["energy"] = minf(_stamina(p), st["energy"] + IDLE_REST)
			st["mood"] += C.PEOPLE[p]["idle"]
			if not st["idle_said"]:
				st["idle_said"] = true
				_say(p, "idle.%s" % p)
	if st["pushed"] > 0:
		st["pushed"] -= 1
	st["mood"] = clampf(st["mood"], -5.0, 5.0)


# Saying no to a request in the inbox: a conversation with whoever brought it (see scenes.gd decline).
# Key projects can't be turned down.
func can_decline(t: Dictionary) -> bool:
	return phase == "plan" and pending.is_empty() and t.get("status", "") == "inbox" and not t["key"]


func decline(uid: int) -> void:
	var t := task(uid)
	if t.is_empty() or not can_decline(t):
		return
	_tip_used("inbox")
	history.append({"who": "you", "key": "decline.open", "args": [], "names": {"task": "@taskname." + t["id"]}, "to": t["from"], "day": day})
	_open_conversation(scenes.decline_event(self, t))


# A turned-down task leaves the board; put off "for later", it goes back into the deck to come round again.
func drop_task(t: Dictionary, again_later: bool) -> void:
	t["status"] = "declined"
	if again_later and C.TASKS.get(t["id"], {}).get("kind", "") in ["start", "chain"]:
		# A step of a chain put off comes back in a week, and the chain waits for it.
		t["chained"] = true
		chain_due.append({"id": t["id"], "day": day + 5})
	elif again_later and C.TASKS.has(t["id"]):
		deck.insert(mini(8, deck.size()), t["id"])


# ---------- chains ----------

# Each evening, a chain card that has an outcome (done well or badly, turned down, late) sends on
# whatever its table row says comes next.
func _advance_chains() -> void:
	for t in tasks:
		var branches: Array = C.TASKS.get(t["id"], {}).get("then", [])
		if branches.is_empty() or t.get("chained", false):
			continue
		var outcome := _outcome(t)
		if outcome == "":
			continue
		t["chained"] = true
		for b in branches:
			if b["on"] == outcome or (b["on"] == "done" and outcome in ["good", "bad"]):
				chain_due.append({"id": b["next"], "day": day + maxi(1, b["after"])})
				break


func _outcome(t: Dictionary) -> String:
	if t["status"] == "declined":
		return "declined"
	if t["late"]:
		return "late"
	if t["status"] == "done":
		return "good" if t["quality"] in ["good", "ok"] else "bad"
	return ""


# How many hours past the 8 this person will stay tonight, as things stand. The same answer drives the
# hint on their card during the day and the evening's work. People stay for a deadline they won't make
# otherwise (each by their own character), because you asked, because the queue has piled up, or
# because you told them to pull themselves together.
func late_hours(p: String) -> int:
	var st: Dictionary = people[p]
	if not available(p) or st["absent"]:
		return 0
	var q := queue_of(p)
	if q.is_empty():
		return 0
	var info: Dictionary = C.PEOPLE[p]
	var first: Dictionary = q[0]
	var late := 0
	var tired := _feels_tired(p)
	# A deadline today or tomorrow that a normal day won't cover.
	var speed := _speed(p, first)
	var left: float = first["size"] - first["progress"]
	var due_in: int = first["due"] - day
	var behind: bool = first["blocked"] == 0 and ((due_in <= 0 and left > speed) or (due_in == 1 and left > 2.0 * speed))
	if behind and not tired:
		if info.get("workaholic", false):
			late = 3
		elif info.get("guards_energy", false):
			late = 0
		elif p == "vika":
			late = 2 if first["public"] or first["key"] else 0
		else:
			late = 2
	elif behind and info.get("workaholic", false):
		late = 2
	if first.get("stay_asked", -1) == day and st.get("agreed_late", -1) == day:
		late += 2
	if q.size() >= OVERLOAD_AT:
		late = maxi(late, 2 + mini(2, q.size() - OVERLOAD_AT))
	if st["pushed"] > 0:
		late = maxi(late, 2)
	if info.get("workaholic", false) and q.size() >= 2:
		late = maxi(late, 1)
	if late > 0 and leans("P"):
		late += 1
	return mini(late, 4)


# You ask someone to stay late on a task tonight. How they take it depends on who they are, how tired
# they are, and how often you've asked this week.
func ask_stay(uid: int) -> void:
	var t := task(uid)
	if phase != "plan" or not pending.is_empty() or t.is_empty() or t["status"] != "active" or t.get("stay_asked", -1) == day:
		return
	var p: String = t["owner"]
	if not C.TEAM.has(p) or not available(p) or people[p]["absent"]:
		return
	var st: Dictionary = people[p]
	t["stay_asked"] = day
	lead("P", 0.5)
	history.append({"who": "you", "key": "stay.ask", "args": [], "names": {"task": "@taskname." + t["id"]}, "to": p, "day": day})
	var asked: int = st.get("asked_late_week", {}).get(week(), 0) + 1
	if not st.has("asked_late_week"):
		st["asked_late_week"] = {}
	st["asked_late_week"][week()] = asked
	var info: Dictionary = C.PEOPLE[p]
	if _feels_tired(p) and not info.get("workaholic", false):
		_say(p, "stay.no_tired")
		return
	st["agreed_late"] = day
	var reply := "yes"
	if info.get("workaholic", false):
		st["mood"] += 0.2
		reply = "glad"
	elif info.get("guards_energy", false):
		st["mood"] -= 1.0 * asked
		if asked >= 2:
			st["trust"] -= 1
		reply = "grudging"
	elif p == "vika" and not (t["public"] or t["key"]):
		st["mood"] -= 0.5
		reply = "grudging"
	else:
		st["mood"] -= 0.3 * asked
	st["mood"] = clampf(st["mood"], -5.0, 5.0)
	_say(p, _first_key(["stay.%s.%s" % [reply, p], "stay." + reply]), [], {"task": "@taskname." + t["id"]})


# Looking in the wrong place: on the first day of a task someone unsure of it may get stuck. The day goes
# by with nothing to show, and they say they're working on it. Someone stronger sitting with them, or
# stepping in and asking, gets them out; on their own they find it after a few days.
func _stuck_today(p: String, t: Dictionary, skill: int) -> bool:
	var names := {"who": "@name.%s.nom" % p, "task": "@taskname." + t["id"]}
	if t["q_days"] == 0.0 and not t.has("stuck"):
		t["stuck"] = 0
		if rng.randf() < (STUCK_CHANCE_WEAK if skill <= 1 else (STUCK_CHANCE if skill == 2 else 0.0)):
			t["stuck"] = 1
	if t.get("stuck", 0) <= 0:
		return false
	var h: String = t["helper"]
	if t["sit_today"] or (shares.get(t["uid"], 0.0) > 0.0 and people.has(h) and people[h]["skills"][t["cat"]] > skill):
		t["stuck"] = 0
		_narrate("stuck.found_help", [], names)
		return false
	t["stuck"] += 1
	if t["stuck"] > STUCK_DAYS:
		t["stuck"] = 0
		_narrate("stuck.found_self", [], names)
	else:
		_narrate("pace.stuck", [], names)
	return true


func _learn(p: String, cat: String, amount: float) -> void:
	var st: Dictionary = people[p]
	if C.PEOPLE[p].get("fast_learner", false):
		amount *= 1.6
	st["xp"][cat] += amount
	var need: float = XP_BASE + XP_PER_SKILL * st["skills"][cat]
	if st["xp"][cat] >= need and st["skills"][cat] < 4:
		st["xp"][cat] = 0.0
		st["skills"][cat] += 1
		_narrate("grew", [], {"who": "@name.%s.nom" % p, "cat": "@cat." + cat})
		if st["known"].has("skill." + cat):
			_narrate("know.skill", [], {"who": "@name.%s.nom" % p, "cat": "@cat." + cat, "level": "@level.%d" % st["skills"][cat]})


func _finish(p: String, t: Dictionary) -> void:
	t["quality"] = _quality_of(t)
	if t["id"].begins_with("init_"):
		t["reviewed"] = true
		_initiative_effect(t)
	# A client who liked the work comes back with more.
	var followups := C.tasks_with("kind", "followup")
	if C.TASKS.get(t["id"], {}).get("tags", []).has("client") and t["quality"] == "good" and flags.get("followups", 0) < 2 and not followups.is_empty():
		flags["followups"] = flags.get("followups", 0) + 1
		deck.insert(mini(rng.randi_range(0, 3), deck.size()), followups[0])
		_narrate("deck.followup", [], {"task": "@taskname." + t["id"]})
	if t["public"] and (t["quality"] == "good" or t["quality"] == "ok") and day <= t["due"]:
		merit += 0.5
		# A key project delivered is visible as yours: you led it.
		if t["key"]:
			boss += boss_like("P", 1.0)
			lead("P", 1.0)
			weight_cause = t["id"]
	t["status"] = "done"
	t["done_day"] = day
	people[p]["last_done"] = day
	people[p]["week_done"][week()] += 1
	var before := role_of(p)
	people[p]["done_cats"][t["cat"]] = people[p]["done_cats"].get(t["cat"], 0) + 1
	var after := role_of(p)
	if after != "" and after != before:
		_narrate("role.emerged", [], {"who": "@name.%s.nom" % p, "role": "@role." + after})
	if p == "vika" and t["public"] and (t["quality"] == "good" or t["quality"] == "ok"):
		people[p]["ambition"] += 1
	_say(p, _result_line(p, t["id"], t["quality"]), [], {"task": "@taskname." + t["id"]})
	_reveal(p, "skill." + t["cat"])


# How it turned out: the average over the days of work, plus whatever happened along the way.
# A hidden flaw spoils it; a task cut down to the minimum can't come out better than "ok".
func _quality_of(t: Dictionary) -> String:
	var avg: float = t["q_sum"] / maxf(0.01, t["q_days"]) + t["q_bonus"]
	var q := "good" if avg >= GOOD_Q else ("ok" if avg >= OK_Q else ("weird" if avg >= WEIRD_Q else "poor"))
	if t["flaw"] and (q == "good" or q == "ok"):
		q = "weird"
	if t.get("cut", false) and q == "good":
		q = "ok"
	return q


func my_skill(cat: String) -> int:
	return C.PROFILES[profile]["skills"][cat]


func max_attention() -> int:
	return C.PROFILES[profile]["attention"]


# Irina's letter for what she likes; the chaotic one likes what an E likes.
func boss_letter() -> String:
	return "E" if boss_type == "X" else boss_type


func my_speed(cat: String) -> float:
	return SPEED_BASE + SPEED_PER_SKILL * my_skill(cat)


func _result_line(p: String, id: String, quality: String) -> String:
	for k in ["result.%s.%s.%s" % [p, id, quality], "result.%s.%s" % [p, quality]]:
		if L.has_key(k):
			return k
	return "result.any.%s" % quality


func _work_myself() -> void:
	var q := queue_of("me")
	if q.is_empty():
		return
	var t: Dictionary = q[0]
	var skill: int = my_skill(t["cat"])
	t["progress"] += my_speed(t["cat"])
	t["q_sum"] += skill + rng.randf_range(-0.7, 0.7)
	t["q_days"] += 1.0
	add_my_hours(MY_HOURS)
	if t["progress"] >= t["size"]:
		t["status"] = "done"
		t["done_day"] = day
		t["quality"] = _quality_of(t)
		_narrate("result.mine", [], {"task": "@taskname." + t["id"]})


func _check_person(p: String) -> void:
	var st: Dictionary = people[p]
	if st["gone"]:
		return
	if st["mood"] <= QUIT_MOOD or (p == "alex" and flags.has("alex_leaving") and day > flags["alex_leaving"] and st["mood"] < -1.0):
		st["gone"] = true
		quits += 1
		_say(p, "quit.%s" % p)
		_drop_tasks(p)
		return
	if st["energy"] <= 0.0 and st["sick"] == 0:
		st["sick"] = SICK_DAYS
		st["energy"] = _stamina(p) * 0.6
		st["mood"] -= 1.0
		_say(p, "sick.%s" % p)
		return
	if st["mood"] <= UNHAPPY_MOOD and not st["warned_mood"]:
		st["warned_mood"] = true
		_say(p, "unhappy.%s" % p)
	elif st["mood"] > UNHAPPY_MOOD + 1.0:
		st["warned_mood"] = false
	if _feels_tired(p) and not st["warned_tired"]:
		st["warned_tired"] = true
		_say(p, "tired.%s" % p)
	elif st["energy"] > TIRED_ENERGY + 2.0:
		st["warned_tired"] = false


func _drop_tasks(p: String) -> void:
	for t in tasks:
		if t["status"] == "active" and t["owner"] == p:
			t["owner"] = ""
			t["status"] = "inbox"
		if t["helper"] == p:
			t["helper"] = ""


func _stamina(p: String) -> float:
	return float(C.PEOPLE[p]["stamina"])


func stamina(p: String) -> float:
	return _stamina(p)


func learn(p: String, cat: String, amount: float) -> void:
	_learn(p, cat, amount)


func make_promise(p: String) -> void:
	people[p]["promised"] = true
	people[p]["promised_day"] = day


# Rough days of work left before this task is done, counting what's ahead of it in the owner's queue.
func days_needed(t: Dictionary) -> float:
	var p: String = t["owner"]
	var total := 0.0
	for q in queue_of(p):
		total += (q["size"] - q["progress"]) / _speed(p, q)
		if q["uid"] == t["uid"]:
			break
	return total + (1.0 if people[p]["absent"] else 0.0)


# ---------- Friday review ----------

# Irina doesn't go through everything: she asks about the week's most visible success and its
# most painful failure. The rest she notes quietly.
func _build_review() -> void:
	review.clear()
	var w := week()
	var best := {}
	var worst := {}
	for t in tasks:
		if t["reviewed"]:
			continue
		var by_team: bool = C.TEAM.has(t["owner"]) and available(t["owner"])
		var done: bool = t["status"] == "done"
		var good: bool = done and (t["quality"] == "good" or t["quality"] == "ok") and not t["late"]
		if done and t["owner"] == "me":
			t["reviewed"] = true
		elif by_team and good and t["public"]:
			if best.is_empty() or t["size"] > best["size"]:
				best = t
		elif by_team and (t["late"] or (done and t["public"] and not good)):
			if worst.is_empty() or _pain(t) > _pain(worst):
				worst = t
	if not best.is_empty():
		review.append({"uid": best["uid"], "kind": "success"})
	if not worst.is_empty():
		review.append({"uid": worst["uid"], "kind": "failure"})
	# Everything else from this week she notes quietly; it counts toward results, not toward you.
	for t in tasks:
		if t["reviewed"] or (not best.is_empty() and t["uid"] == best["uid"]) or (not worst.is_empty() and t["uid"] == worst["uid"]):
			continue
		if t["status"] == "done" or t["late"]:
			t["reviewed"] = true
	# A lead who does the work instead of leading isn't what she hired.
	if my_week_hours[w] >= 16:
		boss -= 1.0
		# The chaotic one somehow never notices you were there all week.
		_say("boss", "review.boss.workaholic.X" if boss_type == "X" else "review.boss.workaholic", [], {"hours": my_week_hours[w]})
	if not review.is_empty():
		_ask_review()


func _pain(t: Dictionary) -> float:
	return (2.0 if t["public"] or t["from"] == "boss" else 0.0) + t["size"] * 0.1


func _review_names(t: Dictionary) -> Dictionary:
	var p: String = t["owner"]
	return {"task": "@taskname." + t["id"], "owner": "@name.%s.nom" % p, "owner_gen": "@name.%s.gen" % p, "owner_dat": "@name.%s.dat" % p}


func _ask_review() -> void:
	var item: Dictionary = review[0]
	var t := task(item["uid"])
	var key := "review.q.success"
	if item["kind"] == "failure":
		key = "review.q.late" if t["late"] else "review.q.poor"
	_say("boss", key, [], _review_names(t))


func review_choices(item: Dictionary) -> Array:
	if item["kind"] == "success":
		return ["credit_owner", "team", "self"]
	return ["own", "overload", "blame"]


# Is this answer true? The weekly report is the evidence for "we were swamped".
func review_true(item: Dictionary, choice: String) -> bool:
	var t := task(item["uid"])
	var p: String = t["owner"]
	match choice:
		"self":
			return t.get("involved", false)
		"blame":
			return people[p]["skills"][t["cat"]] >= 2 and people[p]["week_overtime"][week()] == 0
		"overload":
			var overtime := 0
			for q in C.TEAM:
				overtime += people[q]["week_overtime"][week()]
			return overtime >= 4 or people[p]["week_overtime"][week()] >= 2
	return true


func answer_review(choice: String) -> void:
	if phase != "review" or review.is_empty() or not review_choices(review[0]).has(choice):
		return
	var item: Dictionary = review.pop_front()
	var t := task(item["uid"])
	t["reviewed"] = true
	var p: String = t["owner"]
	var st: Dictionary = people[p]
	var names := _review_names(t)
	var truth := review_true(item, choice)
	weight_cause = t["id"]
	history.append({"who": "you", "key": "review.a." + choice, "args": [], "names": names, "day": day})
	for pair in REVIEW_STYLE[choice]:
		lead(pair[0], pair[1])
	match choice:
		"credit_owner":
			boss += boss_like("I", 0.3)
			st["mood"] += 1.0
			st["trust"] += 1
			_say("boss", "review.boss.credit_owner", [], names)
			if st["promised"]:
				st["promised"] = false
			if p == "vika" and t["quality"] == "good":
				vika_up()
		"team":
			boss += boss_like("I", 0.5)
			for q in C.TEAM:
				if available(q):
					people[q]["mood"] += 0.3
			if C.PEOPLE[p]["drive"] == "visibility":
				st["mood"] -= 0.8
				_say(p, "review.team." + p if L.has_key("review.team." + p) else "review.hurt", [], names)
			_say("boss", "review.boss.team", [], names)
		"self":
			boss += boss_like("P", 2.0)
			_say("boss", "review.boss.self", [], names)
			if truth:
				st["mood"] -= 0.5
			else:
				st["mood"] -= 1.5
				st["trust"] -= 1
				if not flags.has("credit_taken"):
					flags["credit_taken"] = []
				flags["credit_taken"].append({"uid": t["uid"], "owner": p, "day": day})
				if p == "vika":
					st["ambition"] += 1
					if st["ambition"] >= 3:
						vika_up()
						_say("vika", "review.vika_goes_to_boss", [], names)
				else:
					_say(p, "review.hurt", [], names)
		"own":
			st["trust"] += 1
			_say("boss", "review.boss.own", [], names)
		"blame":
			st["mood"] -= 2.0
			st["trust"] -= 1 if truth else 2
			if truth:
				boss += 1.0
				_say("boss", "review.boss.blame", [], names)
			else:
				_say("boss", "review.boss.blame_false", [], names)
			_say(p, "review.blamed", [], names)
		"overload":
			if truth:
				boss += boss_like("A", 1.0)
				flags["relief"] = true
				_say("boss", "review.boss.overload_true", [], names)
			else:
				boss -= 1.0
				_say("boss", "review.boss.overload_false", [], names)
	st["mood"] = clampf(st["mood"], -5.0, 5.0)
	_weight_check()
	if not review.is_empty():
		_ask_review()
	elif day >= last_day():
		_finish_chapter()
	else:
		phase = "evening"


# ---------- first steps ----------

# In the first chapter Gena, who has seen leads come and go, shows the new one around: one line in the chat
# at the moment it's needed, and the board lights up where to look until you've used it. Each tip once a run.
const TIP_TARGETS := {"assign": "inbox", "end_day": "end_day", "talk": "talk", "decline": "inbox", "intervene": "active"}


func update_tips() -> void:
	if not tips or chapter != 1:
		return
	var id := _next_tip()
	if id == "":
		return
	flags["tip_" + id] = true
	flags["tip_last"] = id
	flags["tip_day"] = day
	flags["tip_hl"] = TIP_TARGETS.get(id, "")
	_say("gena", "tip." + id)


func _next_tip() -> String:
	var due: Array = []
	match phase:
		"plan":
			if not pending.is_empty():
				due.append("pushback")
			elif day == 1:
				due.append("assign")
				if C.TEAM.any(func(p): return not queue_of(p).is_empty()):
					due.append("end_day")
			elif flags.get("tip_day", 0) != day: # after day one, one tip a day at most
				due.append("talk")
				if day >= 3 and not inbox().is_empty():
					due.append("decline")
				if tasks.any(func(t): return can_intervene(t)):
					due.append("intervene")
				if C.TEAM.any(func(p): return available(p) and late_hours(p) > 0):
					due.append("overtime")
		"evening":
			due.append("evening")
		"report":
			due.append("friday")
	for id in due:
		if not flags.has("tip_" + id):
			return id
	return ""


# The board element a tip pointed at, lit until you use it.
func tip_target() -> String:
	return flags.get("tip_hl", "")


func _tip_used(target: String) -> void:
	if flags.get("tip_hl", "") == target:
		flags.erase("tip_hl")


# ---------- saving ----------

const SAVE_PATH := "user://save.bin"
# Bump when the saved state changes shape; older saves are then dropped instead of loaded half-broken.
const SAVE_VERSION := 1


# Everything about the run is in this object's variables, so a save is all of them plus where the dice are.
func save_game() -> void:
	var state := {"version": SAVE_VERSION, "rng_seed": rng.seed, "rng_state": rng.state}
	for prop in get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not prop["name"] in ["rng", "scenes"]:
			state[prop["name"]] = get(prop["name"])
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var(state)


static func has_save() -> bool:
	return _read_save() != null


static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func load_game() -> bool:
	var state = _read_save()
	if state == null:
		return false
	for key in state:
		if key in ["version", "rng_seed", "rng_state"]:
			continue
		var current = get(key)
		if current is Array:
			current.assign(state[key]) # keeps typed arrays typed
		else:
			set(key, state[key])
	rng.seed = state["rng_seed"]
	rng.state = state["rng_state"]
	return true


# The save if it's there, readable and still fits this version of the game (its cards still exist).
static func _read_save():
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var state = f.get_var()
	if not state is Dictionary or state.get("version") != SAVE_VERSION or state.get("phase", "end") in ["title", "end"] or (state.get("phase") == "chapter_end" and not C.CHAPTERS[state.get("chapter", 1)]["ready"]):
		return null
	if not C.BOSSES.has(state.get("boss_type", "")) or not C.PROFILES.has(state.get("profile", "")):
		return null
	for id in state.get("deck", []):
		if not C.TASKS.has(id):
			return null
	for t in state.get("tasks", []):
		if not (C.TASKS.has(t["id"]) or C.INIT_TASKS.has(String(t["id"]).trim_prefix("init_"))):
			return null
	return state


# ---------- moving on and the end ----------

func next() -> void:
	if phase != "evening":
		return
	if day >= last_day():
		_finish_chapter()
		return
	day += 1
	_start_day()


# The chapter is over and the next one is ready to play: a new month, a new deck and new key projects.
# The team, Irina and everything they remember carry over.
func start_next_chapter() -> void:
	if phase != "chapter_end" or not next_chapter_ready():
		return
	chapter += 1
	day += 1
	ending = ""
	deck.clear()
	_refill_deck()
	_start_day()


func next_chapter_ready() -> bool:
	return chapter < C.CHAPTERS.size() and C.CHAPTERS[chapter]["ready"]


func last_day() -> int:
	return C.chapter_last_day(chapter)


# 1..20: how far into this chapter's month we are.
func chapter_day() -> int:
	return day - C.chapter_first_day(chapter) + 1


func chapter_keys() -> Array:
	return C.KEY_PROJECTS.get(chapter, [])


# The end of a chapter: results (the boss's view, mostly the key projects) against what the team says.
# Passing it leads on to the next chapter; anything else ends the run.
func _finish_chapter() -> void:
	var r := results_score()
	var team := team_score()
	if quits >= 2:
		ending = "team_gone"
	elif vika_standing >= 4 and vika_standing > boss:
		ending = "replaced"
	elif hours >= 60:
		ending = "workhorse"
	elif r >= RESULTS_OK and team >= TEAM_OK:
		ending = "leader"
	elif r >= RESULTS_OK:
		ending = "puppeteer"
	elif team >= TEAM_OK:
		ending = "beloved"
	else:
		ending = "fired"
	promoted = _level_of(boss) >= 3 and ending in ["leader", "puppeteer"]
	phase = "chapter_end" if passed() and chapter < C.CHAPTERS.size() else "end"


func passed() -> bool:
	return ending in ["leader", "puppeteer"]


const RESULTS_OK := 3.0
const TEAM_OK := 5.0


# Key projects: done well and on time, done badly, slipped, still open, not here yet.
func key_status() -> Dictionary:
	var out := {"good": 0, "bad": 0, "late": 0, "open": 0, "ahead": 0}
	var seen := {}
	for t in tasks:
		if not t["key"] or not chapter_keys().has(t["id"]):
			continue
		seen[t["id"]] = true
		if t["late"]:
			out["late"] += 1
		elif t["status"] == "done":
			out["good" if t["quality"] == "good" or t["quality"] == "ok" else "bad"] += 1
		else:
			out["open"] += 1
	out["ahead"] = chapter_keys().size() - seen.size()
	return out


func results_score() -> float:
	var k := key_status()
	return merit + 2.0 * k["good"] - 2.0 * (k["late"] + k["open"] + k["ahead"]) + style_fit()


# How the team sees you: trust, mood, and anyone who left.
func team_score() -> float:
	var sum := 0.0
	for p in C.TEAM:
		var st: Dictionary = people[p]
		sum += -3.0 if st["gone"] else st["trust"] + clampf(st["mood"], -3.0, 3.0) / 3.0
	return sum / C.TEAM.size()


# Marina asks everyone anonymously. Each answer comes from what actually happened to that person.
func _run_survey() -> void:
	var quotes: Array = []
	for p in C.TEAM:
		if not people[p]["gone"]:
			var q := _survey_quote(p)
			# The same answer twice reads as a copy-paste; people phrase things differently.
			for variant in [q, q + ".2", q + ".3"]:
				if not quotes.has(variant) and L.has_key(variant):
					q = variant
					break
			quotes.append(q)
	quotes.shuffle()
	var team := team_score()
	survey = {"day": day, "quotes": quotes, "verdict": "for" if team >= TEAM_OK else ("wary" if team >= 0.0 else "against")}


func _survey_quote(p: String) -> String:
	var st: Dictionary = people[p]
	var credit_taken := false
	for c in flags.get("credit_taken", []):
		if c["owner"] == p:
			credit_taken = true
	var extra := 0
	for x in st["week_extra"]:
		extra += x
	if credit_taken and st["trust"] < 0:
		return "survey.credit"
	if flags.has("lied_" + p):
		return "survey.lies"
	if st["trust"] <= -2:
		return "survey.distrust"
	if st["debts"] > 0 or (st["promised"] and day - st["promised_day"] >= 5):
		return "survey.promises"
	if extra >= 12 or st["energy"] <= TIRED_ENERGY:
		return "survey.overworked"
	if st["idle_days"] >= 2:
		return "survey.idle"
	if not skills_grown(p).is_empty():
		return "survey.growth"
	if st["trust"] >= 1:
		return "survey.trust"
	if st["mood"] >= 2.0:
		return "survey.happy"
	if st["mood"] <= -2.0:
		return "survey.unhappy"
	return "survey.neutral"


func broken_promises() -> Array[String]:
	var result: Array[String] = []
	for p in C.TEAM:
		if people[p]["promised"] or people[p]["debts"] > 0 or flags.has("mention_" + p) or flags.has("stretch_" + p):
			result.append(p)
	return result


func skills_grown(p: String) -> Array[String]:
	var result: Array[String] = []
	for cat in C.CATEGORIES:
		if people[p]["skills"][cat] > people[p]["start"][cat]:
			result.append(cat)
	return result


# ---------- words for the UI ----------

func mood_word(p: String) -> String:
	var m: float = people[p]["mood"]
	if m >= 3.0:
		return "happy"
	if m >= 1.0:
		return "good"
	if m > -1.0:
		return "neutral"
	if m > UNHAPPY_MOOD:
		return "down"
	return "angry"


func energy_word(p: String) -> String:
	var e: float = people[p]["energy"]
	if e >= 6.0:
		return "fresh"
	if e >= 4.0:
		return "ok"
	if e > TIRED_ENERGY:
		return "tired"
	return "drained"


func boss_word() -> String:
	return "w%d" % _level_of(boss)


func _level_of(w: float) -> int:
	if w >= 8.0:
		return 3
	if w >= 1.0:
		return 2
	if w > -2.0:
		return 1
	return 0


# ---------- leadership style (Adizes) ----------

# What each review answer and each initiative says about you as a lead.
const REVIEW_STYLE := {
	"credit_owner": [["I", 0.5]], "team": [["I", 0.5]], "self": [["P", 0.5], ["I", -0.5]],
	"own": [["A", 0.5]], "blame": [["P", 0.3], ["I", -0.7]], "overload": [["A", 0.5]],
}
# Some kinds of leading come up every hour (talking to people), some rarely (changing how things
# are done). Each letter is weighed by how hard it is to show, so a few bold moves count.
const STYLE_SCALE := {"P": 1.0, "A": 1.3, "E": 2.0, "I": 0.6}
const INIT_STYLE := {
	"tech_debt": [["E", 1.0], ["A", 0.5]], "automate_report": [["A", 1.5]], "write_docs": [["A", 1.5]],
	"showcase": [["E", 1.0]], "self_study": [["E", 0.5], ["I", 0.5]],
}


# Whatever you do as a lead leans toward one of the four roles. Nobody sees these numbers;
# Irina's Friday remarks and the team's mood are how you find out.
func lead(letter: String, amount: float) -> void:
	style[letter] += amount
	week_style[letter] += amount


func style_shares(s: Dictionary = style) -> Dictionary:
	var total := 0.0
	for x in C.PAEI:
		total += maxf(0.0, s[x]) * STYLE_SCALE[x]
	var out := {}
	for x in C.PAEI:
		out[x] = maxf(0.0, s[x]) * STYLE_SCALE[x] / total if total > 0.0 else 0.25
	return out


func _style_total(s: Dictionary) -> float:
	var total := 0.0
	for x in C.PAEI:
		total += maxf(0.0, s[x])
	return total


func _style_top(s: Dictionary) -> String:
	var top := "P"
	for x in C.PAEI:
		if s[x] * STYLE_SCALE[x] > s[top] * STYLE_SCALE[top]:
			top = x
	return top


# Has your leading so far leaned clearly this way? The team adapts to it.
func leans(letter: String) -> bool:
	return _style_total(style) >= 4.0 and style_shares()[letter] >= 0.3


# The same move earns more with an Irina who values it, less with one who doesn't.
func boss_like(letter: String, amount: float) -> float:
	return amount * (1.0 + 0.5 * C.BOSSES[boss_type][letter])


# Your Adizes code: capitals for strong roles, small letters for some, dashes for none ("PaEi", "-A--").
func adizes_code() -> String:
	var sh := style_shares()
	var code := ""
	for x in C.PAEI:
		code += x if sh[x] >= 0.28 else (x.to_lower() if sh[x] >= 0.12 else "-")
	return code


# One role crowding out the others is one of Adizes' mismanagement styles; too little of anything is deadwood.
func adizes_type() -> String:
	if _style_total(style) < STYLE_MIN:
		return "deadwood"
	var sh := style_shares()
	var top := _style_top(style)
	if sh[top] >= 0.55:
		return {"P": "lone_ranger", "A": "bureaucrat", "E": "arsonist", "I": "superfollower"}[top]
	var strong := 0
	for x in C.PAEI:
		if sh[x] >= 0.28:
			strong += 1
	if strong >= 2:
		return "combo"
	return {"P": "producer", "A": "administrator", "E": "entrepreneur", "I": "integrator"}[top]


func mismanaged() -> bool:
	return adizes_type() in ["deadwood", "lone_ranger", "bureaucrat", "arsonist", "superfollower"]


# How Irina sees your style at the assessment: what she values, minus a lopsided or absent lead.
func style_fit() -> float:
	var sh := style_shares()
	var fit := 0.0
	for x in C.PAEI:
		fit += sh[x] * C.BOSSES[boss_type][x]
	return 3.0 * fit - (1.5 if mismanaged() else 0.0)


# Friday: a week with nothing late is a week of order. Irina remarks on how you led this week,
# the people whose kind of lead that was warm up, and someone who got none of what they need says so.
func _style_week() -> void:
	var w := week()
	var late := 0
	for t in tasks:
		if t["late"] and int((t["late_day"] - 1) / 5.0) == w:
			late += 1
	if late == 0:
		lead("A", 1.0)
	if _style_total(week_style) >= 2.0:
		var top := _style_top(week_style)
		boss += 0.5 * C.BOSSES[boss_type][top]
		_say("boss", "style.boss.%s.%s" % [boss_letter(), top])
		var sh := style_shares(week_style)
		var missing := ""
		for p in C.TEAM:
			if not available(p):
				continue
			var mine: String = C.PEOPLE[p]["paei"]
			if mine == top:
				people[p]["mood"] = clampf(people[p]["mood"] + 0.7, -5.0, 5.0)
				_say(p, "style.team.%s.pos" % p)
			elif sh[mine] < 0.1:
				people[p]["mood"] = clampf(people[p]["mood"] - 0.5, -5.0, 5.0)
				if missing == "":
					missing = p
		if missing != "":
			_say(missing, "style.team.%s.neg" % missing)
	for x in C.PAEI:
		week_style[x] = 0.0


# Tired enough to say so: a workaholic only when they're about to drop, someone who guards their
# energy well before that.
func _feels_tired(p: String) -> bool:
	var e: float = people[p]["energy"]
	if C.PEOPLE[p].get("workaholic", false):
		return e <= 0.5
	if C.PEOPLE[p].get("guards_energy", false):
		return e <= 0.4 * _stamina(p)
	return e <= TIRED_ENERGY


# Will they offer to do something on their own today? Only with energy to spare, and (for some)
# after hearing something good. A team led toward change volunteers more.
func _wants_to_volunteer(p: String) -> bool:
	var info: Dictionary = C.PEOPLE[p]
	var st: Dictionary = people[p]
	if st["energy"] < info["rest_at"] * _stamina(p):
		return false
	if info.get("needs_approval", false) and st["mood"] < 1.5:
		return false
	return rng.randf() < info["initiative"] + (0.2 if leans("E") else 0.0)


# ---------- helpers ----------

func say(who: String, key: String, args: Array = [], names: Dictionary = {}) -> void:
	_say(who, key, args, names)


func _say(who: String, key: String, args: Array = [], names: Dictionary = {}) -> void:
	history.append({"who": who, "key": key, "args": args, "names": names, "day": day})


func _narrate(key: String, args: Array = [], names: Dictionary = {}) -> void:
	history.append({"who": "", "key": key, "args": args, "names": names, "day": day})
