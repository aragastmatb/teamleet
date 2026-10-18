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
const DRAIN := 1.0
const HARD_DRAIN := 0.5
const OVERLOAD_DRAIN := 0.5
const OVERLOAD_AT := 3
const IDLE_REST := 2.0
const DAYOFF_REST := 4.0
const SICK_DAYS := 2
const QUIT_MOOD := -5.0
const UNHAPPY_MOOD := -3.0
const TIRED_ENERGY := 2.0
const MY_SPEED := 1.0
const MY_HOURS := 8
const XP_BASE := 3.0
const XP_PER_SKILL := 2.0
const PUSH_DAYS := 2
const PUSH_SPEED := 0.2

var rng := RandomNumberGenerator.new()
var scenes := Scenes.new()
var day := 1
var phase := "title" # plan, event, evening, report, review, end
var people := {}
var tasks: Array[Dictionary] = []
var boss := 0.0
var vika_standing := 0
var hours := 0
var my_week_hours := []
# Marina's latest team survey: {"day", "quotes": [locale keys], "verdict": "for" / "wary" / "against"}.
var survey := {}
var quits := 0
var talked_today := false
var events: Array[Dictionary] = []
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


# ---------- run and day flow ----------

func start_run(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	day = 1
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
	boss = 0.0
	vika_standing = 0
	hours = 0
	my_week_hours = _zeros()
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
	_narrate("log.morning", ["@day.%d" % day])
	for p in C.TEAM:
		var st: Dictionary = people[p]
		if st["gone"]:
			continue
		st["absent"] = st["sick"] > 0 or st["off_next"]
		st["absent_reason"] = "dayoff" if st["off_next"] else ("sick" if st["sick"] > 0 else "")
		if st["off_next"]:
			st["off_next"] = false
			st["energy"] = minf(_stamina(p), st["energy"] + DAYOFF_REST)
			_say(p, "absent.dayoff")
		elif st["sick"] > 0:
			st["sick"] -= 1
			_say(p, "absent.sick")
	var arrivals: Array = C.SCHEDULE.get(day, []).duplicate()
	if flags.get("relief", false):
		for id in arrivals:
			if not C.TASKS[id]["public"] and C.TASKS[id]["from"] != "boss":
				arrivals.erase(id)
				flags["relief"] = false
				_narrate("relief", [], {"task": "@taskname." + id})
				break
	for id in arrivals:
		var info: Dictionary = C.TASKS[id]
		tasks.append({
			"uid": next_uid, "id": id, "cat": info["cat"], "size": info["size"], "progress": 0.0,
			"due": day + info["due"], "public": info["public"], "from": info["from"], "owner": "", "helper": "",
			"q_sum": 0.0, "q_days": 0.0, "status": "inbox", "late": false, "quality": "",
			"done_day": 0, "reviewed": false, "assigned_day": 0, "helped": {}, "first": false,
			"asked": false, "vouched": false, "flaw": false, "complicated": false, "blocked": 0, "q_bonus": 0.0, "involved": false,
			"key": C.KEY_PROJECTS.has(id),
		})
		next_uid += 1
		_say(info["from"], "task.%s.ask" % id)
	talked_today = false
	_queue_events()
	phase = "event" if not events.is_empty() else "plan"


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
	if events.is_empty():
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
	var reason := _objection(p, t) if p != "me" else ""
	t["owner"] = p
	t["status"] = "active"
	t["assigned_day"] = day
	t["first"] = false
	if t["helper"] == p:
		t["helper"] = ""
	if p == "me":
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


# Why this person would push back on this task right now, or "" if they just take it.
func _objection(p: String, t: Dictionary) -> String:
	var st: Dictionary = people[p]
	var load := 0.0
	var count := 0
	for q in queue_of(p):
		if q["uid"] != t["uid"]:
			load += q["size"] - q["progress"]
			count += 1
	if st["energy"] <= TIRED_ENERGY:
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
	if intent == "back_off":
		unassign_now(t)
		st["mood"] = clampf(st["mood"] + 0.3, -5.0, 5.0)
		_say(p, "persuade.back_off.reply")
		return
	var drive: String = C.PEOPLE[p]["drive"]
	var taste: int = C.INTENT_TASTE[drive][intent]
	var delta := -1.0 + taste
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
	var terms_line := ""
	if p == "alex" and flags.has("alex_terms"):
		if t["cat"] == "people":
			delta -= 1.0
			terms_line = "alex.terms_broken"
		elif t["cat"] == "tech":
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


func one_on_one(p: String, approach: String) -> void:
	if phase != "plan" or not pending.is_empty() or talked_today or not available(p) or people[p]["absent"]:
		return
	talked_today = true
	var st: Dictionary = people[p]
	history.append({"who": "you", "key": "talk." + approach, "args": [], "names": {}, "to": p, "day": day})
	match approach:
		"praise":
			if day - st["last_done"] <= 2:
				st["mood"] += 1.0
				st["trust"] += 1
				_say(p, "talk.praise.ok")
			else:
				_say(p, "talk.praise.empty")
		"listen":
			st["mood"] += 0.5
			var key := _next_unknown(p)
			if key == "":
				_say(p, "talk.listen.nothing")
			else:
				var line := "talk.listen.%s.%s" % [p, key.replace("skill.", "")]
				_say(p, line if L.has_key(line) else "talk.listen.any")
				_reveal(p, key)
		"push":
			st["pushed"] = PUSH_DAYS
			st["mood"] -= 2.0 if C.PEOPLE[p]["drive"] == "peace" else 1.0
			st["energy"] -= 1.0
			_say(p, "talk.push.%s" % p)
		"promise":
			if st["promised"]:
				st["trust"] -= 1
				_say(p, "talk.promise.again")
			else:
				make_promise(p)
				st["mood"] += 3.0 if p == "vika" else 2.0
				_say(p, "talk.promise.%s" % p)
		"dayoff":
			st["off_next"] = true
			st["mood"] += 1.0
			if st["debts"] > 0:
				st["debts"] = 0
				st["trust"] += 1
				_say(p, "talk.dayoff.debt")
			else:
				_say(p, "talk.dayoff.ok")
	st["mood"] = clampf(st["mood"], -5.0, 5.0)


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
		if t["blocked"] > 0:
			t["blocked"] -= 1
	for t in tasks:
		if t["status"] == "taras" and t["due"] == day:
			t["status"] = "done"
			t["quality"] = "ok"
			t["done_day"] = day
			_say("taras", "taras.done", [], {"task": "@taskname." + t["id"]})
	for t in tasks:
		if (t["status"] == "inbox" or t["status"] == "active") and t["due"] == day and not t["late"]:
			t["late"] = true
			t["late_day"] = day
			_late(t)
			if t["vouched"]:
				boss -= 1
				_say("boss", "boss.vouched_late", [], {"task": "@taskname." + t["id"]})
	_check_lies()
	for p in C.TEAM:
		_check_person(p)
	if C.SURVEY_DAYS.has(day):
		_run_survey()
	if C.REVIEW_DAYS.has(day):
		_build_review()
		if review.is_empty():
			_narrate("review.empty")
		phase = "report"
	else:
		phase = "evening"


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


func week() -> int:
	return clampi(int((day - 1) / 5.0), 0, C.WEEKS - 1)


func _zeros() -> Array:
	var a := []
	a.resize(C.WEEKS)
	a.fill(0)
	return a


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
	var share: float = shares.get(t["uid"], 0.0)
	if share > 0.0:
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
		return {"days": left / MY_SPEED + t["blocked"], "sure": true}
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
	if not q.is_empty():
		# The day is spent down the queue: whatever's left after finishing one task goes to the next.
		# Half of it goes to the pair if they're helping someone.
		var first: Dictionary = q[0]
		var time := 1.0 - help_part
		var stuck: Array = []
		for t in q:
			if time < 0.05:
				break
			if t["blocked"] > 0:
				stuck.append(t)
				continue
			var skill: int = st["skills"][t["cat"]]
			var step := _speed(p, t)
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
			drain += OVERLOAD_DRAIN
			st["mood"] -= 0.3
		# Overloaded, rushed or pushed people stay late.
		st["week_hours"][week()] += 8
		if q.size() >= OVERLOAD_AT or st["pushed"] > 0:
			st["week_extra"][week()] += 2 + (1 if q.size() >= OVERLOAD_AT + 2 else 0)
			st["week_overtime"][week()] += 1
		st["energy"] -= drain
		st["idle_said"] = false
		st["idle_days"] = 0
	if help_part > 0.0:
		_help(p, helping, help_part)
	if q.is_empty():
		st["idle_days"] = 0 if help_part > 0.0 else st["idle_days"] + 1
		if help_part > 0.0:
			st["week_hours"][week()] += 8
			st["energy"] -= 0.7
		else:
			st["energy"] = minf(_stamina(p), st["energy"] + IDLE_REST)
			st["mood"] += C.PEOPLE[p]["idle"]
			if not st["idle_said"]:
				st["idle_said"] = true
				_say(p, "idle.%s" % p)
	if st["pushed"] > 0:
		st["pushed"] -= 1
	st["mood"] = clampf(st["mood"], -5.0, 5.0)


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
	var avg: float = t["q_sum"] / maxf(0.01, t["q_days"]) + t["q_bonus"]
	t["quality"] = "good" if avg >= GOOD_Q else ("ok" if avg >= OK_Q else ("weird" if avg >= WEIRD_Q else "poor"))
	if t["flaw"] and (t["quality"] == "good" or t["quality"] == "ok"):
		t["quality"] = "weird"
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
	t["progress"] += MY_SPEED
	add_my_hours(MY_HOURS)
	if t["progress"] >= t["size"]:
		t["status"] = "done"
		t["done_day"] = day
		t["quality"] = "good" if rng.randf() < 0.5 else "ok"
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
	if st["energy"] <= TIRED_ENERGY and not st["warned_tired"]:
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
		var by_team: bool = C.TEAM.has(t["owner"])
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
	# Everything else from this week: quiet credit for visible work done well.
	for t in tasks:
		if t["reviewed"] or (not best.is_empty() and t["uid"] == best["uid"]) or (not worst.is_empty() and t["uid"] == worst["uid"]):
			continue
		if t["status"] == "done" or t["late"]:
			t["reviewed"] = true
			if C.TEAM.has(t["owner"]) and t["public"] and (t["quality"] == "good" or t["quality"] == "ok") and not t["late"]:
				boss += 0.5
	# A lead who does the work instead of leading isn't what she hired.
	if my_week_hours[w] >= 16:
		boss -= 1.0
		_say("boss", "review.boss.workaholic", [], {"hours": my_week_hours[w]})
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
	history.append({"who": "you", "key": "review.a." + choice, "args": [], "names": names, "day": day})
	match choice:
		"credit_owner":
			boss += 1.0
			st["mood"] += 1.0
			st["trust"] += 1
			_say("boss", "review.boss.credit_owner", [], names)
			if st["promised"]:
				st["promised"] = false
			if p == "vika" and t["quality"] == "good":
				vika_standing += 1
		"team":
			boss += 1.0
			for q in C.TEAM:
				if available(q):
					people[q]["mood"] += 0.3
			if C.PEOPLE[p]["drive"] == "visibility":
				st["mood"] -= 0.8
				_say(p, "review.team." + p if L.has_key("review.team." + p) else "review.hurt", [], names)
			_say("boss", "review.boss.team", [], names)
		"self":
			boss += 2.0
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
						vika_standing += 1
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
				boss += 1.0
				flags["relief"] = true
				_say("boss", "review.boss.overload_true", [], names)
			else:
				boss -= 1.0
				_say("boss", "review.boss.overload_false", [], names)
	st["mood"] = clampf(st["mood"], -5.0, 5.0)
	if not review.is_empty():
		_ask_review()
	elif day >= C.DAYS:
		_finish_run()
	else:
		phase = "evening"


# ---------- moving on and the end ----------

func next() -> void:
	if phase != "evening":
		return
	if day >= C.DAYS:
		_finish_run()
		return
	day += 1
	_start_day()


# The attestation: results (the boss's view, mostly the key projects) against what the team says.
func _finish_run() -> void:
	var r := results_score()
	var team := team_score()
	if quits >= 2:
		ending = "team_gone"
	elif vika_standing >= 3 and vika_standing > boss:
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
	phase = "end"


const RESULTS_OK := 3.0
const TEAM_OK := 1.5


# Key projects: done well and on time, done badly, slipped, still open, not here yet.
func key_status() -> Dictionary:
	var out := {"good": 0, "bad": 0, "late": 0, "open": 0, "ahead": 0}
	var seen := {}
	for t in tasks:
		if not t["key"]:
			continue
		seen[t["id"]] = true
		if t["late"]:
			out["late"] += 1
		elif t["status"] == "done":
			out["good" if t["quality"] == "good" or t["quality"] == "ok" else "bad"] += 1
		else:
			out["open"] += 1
	out["ahead"] = C.KEY_PROJECTS.size() - seen.size()
	return out


func results_score() -> float:
	var k := key_status()
	return boss + 2.0 * k["good"] - 2.0 * (k["late"] + k["open"] + k["ahead"])


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
		if people[p]["promised"] or people[p]["debts"] > 0:
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
	if boss >= 5:
		return "thrilled"
	if boss >= 2:
		return "pleased"
	if boss >= -1:
		return "watching"
	if boss >= -3:
		return "doubts"
	return "angry"


# ---------- helpers ----------

func say(who: String, key: String, args: Array = [], names: Dictionary = {}) -> void:
	_say(who, key, args, names)


func _say(who: String, key: String, args: Array = [], names: Dictionary = {}) -> void:
	history.append({"who": who, "key": key, "args": args, "names": names, "day": day})


func _narrate(key: String, args: Array = [], names: Dictionary = {}) -> void:
	history.append({"who": "", "key": key, "args": args, "names": names, "day": day})
