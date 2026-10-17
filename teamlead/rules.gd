extends RefCounted
# Team lead prototype rules, no UI. main.gd drives it; tests can drive it headless.
#
# Each day: tasks arrive, you assign them (with a tone), pair people up, and hold one one-on-one.
# Ending the day simulates the work: progress, quality, fatigue, mood, growth. Fridays end with a
# review where you decide who gets the credit and who takes the blame. Skills and motives are hidden
# until results and conversations reveal them.

const C = preload("res://teamlead/content.gd")
const L = preload("res://teamlead/locale.gd")

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
var day := 1
var phase := "title" # plan, event, evening, review, end
var people := {}
var tasks: Array[Dictionary] = []
var boss := 0
var vika_standing := 0
var hours := 0
var quits := 0
var talked_today := false
var events: Array[Dictionary] = []
var review: Array[Dictionary] = []
var flags := {}
var ending := ""
var evening_from := 0
var next_uid := 0
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
			"gone": false, "known": {}, "favors": 0, "warned_mood": false, "warned_tired": false,
			"last_done": -10, "idle_said": false,
		}
	tasks.clear()
	boss = 0
	vika_standing = 0
	hours = 0
	quits = 0
	events.clear()
	review.clear()
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
	for id in C.SCHEDULE.get(day, []):
		var info: Dictionary = C.TASKS[id]
		tasks.append({
			"uid": next_uid, "id": id, "cat": info["cat"], "size": info["size"], "progress": 0.0,
			"due": day + info["due"], "public": info["public"], "from": info["from"], "owner": "", "helper": "",
			"tone": "plain", "q_sum": 0.0, "q_days": 0, "status": "inbox", "late": false, "quality": "",
			"done_day": 0, "reviewed": false,
		})
		next_uid += 1
		_say(info["from"], "task.%s.ask" % id)
	talked_today = false
	_queue_events()
	phase = "event" if not events.is_empty() else "plan"


func _queue_events() -> void:
	var vika: Dictionary = people["vika"]
	if not vika["gone"] and not vika["absent"] and vika["ambition"] >= 2 and not flags.has("vika_raise"):
		flags["vika_raise"] = true
		events.append({"id": "vika_raise", "who": "vika", "choices": ["promise", "not_yet"]})
	var alex: Dictionary = people["alex"]
	if not alex["gone"] and not alex["absent"] and alex["energy"] <= TIRED_ENERGY and not flags.has("alex_tired"):
		flags["alex_tired"] = true
		events.append({"id": "alex_tired", "who": "alex", "choices": ["dayoff", "hold_on"]})
	if not events.is_empty():
		_say(events[0]["who"], "event.%s.ask" % events[0]["id"])


func resolve_event(choice: String) -> void:
	if phase != "event" or events.is_empty():
		return
	var ev: Dictionary = events.pop_front()
	var st: Dictionary = people[ev["who"]]
	history.append({"who": "you", "key": "event.%s.%s" % [ev["id"], choice], "args": [], "names": {}, "day": day})
	match ev["id"] + "/" + choice:
		"vika_raise/promise":
			st["promised"] = true
			st["mood"] += 2.0
		"vika_raise/not_yet":
			st["mood"] -= 2.0
			vika_standing += 1
		"alex_tired/dayoff":
			st["absent"] = true
			st["absent_reason"] = "dayoff"
			st["energy"] = minf(_stamina("alex"), st["energy"] + DAYOFF_REST)
			st["mood"] += 1.0
		"alex_tired/hold_on":
			st["mood"] -= 1.0
	_say(ev["who"], "event.%s.%s.reply" % [ev["id"], choice])
	if events.is_empty():
		phase = "plan"
	else:
		_say(events[0]["who"], "event.%s.ask" % events[0]["id"])


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
	result.sort_custom(func(a, b): return a["due"] < b["due"] or (a["due"] == b["due"] and a["uid"] < b["uid"]))
	return result


func available(p: String) -> bool:
	return C.TEAM.has(p) and not people[p]["gone"]


func assign(uid: int, p: String, tone: String) -> void:
	var t := task(uid)
	if phase != "plan" or t.is_empty() or t["status"] == "done" or t["status"] == "taras" or p == t["owner"]:
		return
	var previous: String = t["owner"]
	if p == "taras":
		_hand_to_taras(t)
		return
	if p != "me" and not available(p):
		return
	history.append({"who": "you", "key": "tone." + tone, "args": [], "names": {}, "to": p, "day": day})
	if C.TEAM.has(previous) and t["progress"] > 0.0 and not people[previous]["gone"]:
		people[previous]["mood"] -= 0.5
		_say(previous, "taken_away", [], {"task": "@taskname." + t["id"]})
	t["owner"] = p
	t["tone"] = tone
	t["status"] = "active"
	if t["helper"] == p:
		t["helper"] = ""
	if p == "me":
		_say("", "you.myself_note", [], {"task": "@taskname." + t["id"]})
		return
	var st: Dictionary = people[p]
	var drive: String = C.PEOPLE[p]["drive"]
	var taste: int = C.TONE_TASTE[drive].get(tone, 0)
	var delta := float(taste)
	if C.PEOPLE[p]["likes"].has(t["cat"]):
		delta += 1.0
	if C.PEOPLE[p]["hates"].has(t["cat"]):
		delta -= 1.0
	if p == "vika" and t["public"]:
		delta += 1.0
	if drive == "peace" and t["due"] - day <= 1:
		delta -= 1.0
	if tone == "favor":
		delta -= st["favors"]
		st["favors"] += 1
	st["mood"] = clampf(st["mood"] + delta, -5.0, 5.0)
	_say(p, _tone_line(p, tone, delta), [], {"task": "@taskname." + t["id"]})
	if absi(taste) >= 2:
		_reveal(p, "drive")


func _tone_line(p: String, tone: String, delta: float) -> String:
	var mood := "pos" if delta >= 1.0 else ("neg" if delta <= -1.0 else "neu")
	for k in ["tone.%s.%s.%s" % [p, tone, mood], "react.%s.%s" % [p, mood]]:
		if L.has_key(k):
			return k
	return "react.any.%s" % mood


func _hand_to_taras(t: Dictionary) -> void:
	history.append({"who": "you", "key": "you.to_taras", "args": [], "names": {}, "day": day})
	if t["from"] == "taras" or flags.get("taras_said_no", 0) >= 2 or rng.randf() < 0.5:
		flags["taras_said_no"] = flags.get("taras_said_no", 0) + 1
		_say("taras", "taras.refuse_own" if t["from"] == "taras" else "taras.refuse", [], {"task": "@taskname." + t["id"]})
		return
	t["owner"] = "taras"
	t["status"] = "taras"
	t["helper"] = ""
	_say("taras", "taras.accept", [], {"task": "@taskname." + t["id"]})


func set_helper(uid: int, p: String) -> void:
	var t := task(uid)
	if phase != "plan" or t.is_empty() or t["status"] != "active" or p == t["owner"] or (p != "" and not available(p)):
		return
	t["helper"] = p
	if p != "":
		_say(p, "helper.join", [], {"task": "@taskname." + t["id"], "owner": "@name.%s.nom" % t["owner"]})


func unassign(uid: int) -> void:
	var t := task(uid)
	if phase != "plan" or t.is_empty() or t["status"] != "active":
		return
	t["owner"] = ""
	t["helper"] = ""
	t["status"] = "inbox"


func one_on_one(p: String, approach: String) -> void:
	if phase != "plan" or talked_today or not available(p) or people[p]["absent"]:
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
				st["promised"] = true
				st["mood"] += 3.0 if p == "vika" else 2.0
				_say(p, "talk.promise.%s" % p)
		"dayoff":
			st["off_next"] = true
			st["mood"] += 1.0
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
	if phase != "plan":
		return
	evening_from = history.size()
	_narrate("log.evening")
	for p in C.TEAM:
		_work(p)
	_work_myself()
	for t in tasks:
		if t["status"] == "taras" and t["due"] == day:
			t["status"] = "done"
			t["quality"] = "ok"
			t["done_day"] = day
			_say("taras", "taras.done", [], {"task": "@taskname." + t["id"]})
	for t in tasks:
		if (t["status"] == "inbox" or t["status"] == "active") and t["due"] == day and not t["late"]:
			t["late"] = true
			boss -= 1
			_narrate("late", [], {"task": "@taskname." + t["id"]})
	for p in C.TEAM:
		_check_person(p)
	if C.REVIEW_DAYS.has(day):
		_build_review()
		phase = "review" if not review.is_empty() else "evening"
		if review.is_empty():
			_narrate("review.empty")
	else:
		phase = "evening"


func _speed(p: String, t: Dictionary) -> float:
	var st: Dictionary = people[p]
	var skill: int = st["skills"][t["cat"]]
	var s := SPEED_BASE + SPEED_PER_SKILL * skill
	s *= 1.0 + st["mood"] * 0.04
	s *= 1.0 + C.TONES[t["tone"]].get("speed", 0.0)
	if st["pushed"] > 0:
		s *= 1.0 + PUSH_SPEED
	var h: String = t["helper"]
	if h != "" and _helping_now(h):
		var hs: int = people[h]["skills"][t["cat"]]
		if hs >= 2:
			s += 0.5 * (SPEED_BASE + SPEED_PER_SKILL * hs)
		if hs < skill:
			s *= 0.85
	return s


# A helper only helps when they have nothing of their own on their plate.
func _helping_now(h: String) -> bool:
	return available(h) and not people[h]["absent"] and queue_of(h).is_empty()


func _work(p: String) -> void:
	var st: Dictionary = people[p]
	if st["gone"]:
		return
	if st["absent"]:
		st["energy"] = minf(_stamina(p), st["energy"] + IDLE_REST)
		return
	var q := queue_of(p)
	if not q.is_empty():
		var t: Dictionary = q[0]
		var skill: int = st["skills"][t["cat"]]
		var step := _speed(p, t)
		t["progress"] += step
		var quality: float = skill + st["mood"] * 0.1 + rng.randf_range(-0.7, 0.7) + C.TONES[t["tone"]].get("quality", 0.0)
		var h: String = t["helper"]
		if h != "" and _helping_now(h) and people[h]["skills"][t["cat"]] > skill:
			quality += 0.5
		t["q_sum"] += quality
		t["q_days"] += 1
		_learn(p, t["cat"], 1.0)
		var drain: float = DRAIN + C.TONES[t["tone"]].get("drain", 0.0)
		if skill < 2:
			drain += HARD_DRAIN
		if q.size() >= OVERLOAD_AT:
			drain += OVERLOAD_DRAIN
			st["mood"] -= 0.3
		st["energy"] -= drain
		if C.PEOPLE[p]["likes"].has(t["cat"]):
			st["mood"] += 0.3
		if C.PEOPLE[p]["hates"].has(t["cat"]):
			st["mood"] -= 0.4
		st["idle_said"] = false
		if t["progress"] >= t["size"]:
			_finish(p, t)
		else:
			# How far they got today, relative to the task: the main way to read someone's skill.
			var pace := "big" if step / t["size"] >= 0.45 else ("mid" if step / t["size"] >= 0.25 else "small")
			_narrate("pace." + pace, [], {"who": "@name.%s.nom" % p, "task": "@taskname." + t["id"]})
	else:
		var helping := false
		for t in tasks:
			if t["status"] == "active" and t["helper"] == p and available(t["owner"]) and not people[t["owner"]]["absent"]:
				helping = true
				_learn(p, t["cat"], 1.5)
				st["energy"] -= 0.7
				break
		if not helping:
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
	var avg: float = t["q_sum"] / maxi(1, t["q_days"])
	t["quality"] = "good" if avg >= GOOD_Q else ("ok" if avg >= OK_Q else ("weird" if avg >= WEIRD_Q else "poor"))
	t["status"] = "done"
	t["done_day"] = day
	people[p]["last_done"] = day
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
	hours += MY_HOURS
	if t["progress"] >= t["size"]:
		t["status"] = "done"
		t["done_day"] = day
		t["quality"] = "good" if rng.randf() < 0.5 else "ok"
		_narrate("result.mine", [], {"task": "@taskname." + t["id"]})


func _check_person(p: String) -> void:
	var st: Dictionary = people[p]
	if st["gone"]:
		return
	if st["mood"] <= QUIT_MOOD:
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


# ---------- Friday review ----------

func _build_review() -> void:
	review.clear()
	for t in tasks:
		if t["reviewed"]:
			continue
		var done: bool = t["status"] == "done"
		var by_team: bool = C.TEAM.has(t["owner"])
		if done and t["owner"] == "me":
			t["reviewed"] = true
			boss += 1
			_narrate("review.mine", [], {"task": "@taskname." + t["id"]})
		elif done and t["owner"] == "taras":
			t["reviewed"] = true
		elif done and by_team and (t["public"] or t["late"]):
			var kind := "success" if (t["quality"] == "good" or t["quality"] == "ok") and not t["late"] else "failure"
			review.append({"uid": t["uid"], "kind": kind, "weird": t["quality"] == "weird"})
		elif not done and t["late"] and by_team:
			review.append({"uid": t["uid"], "kind": "failure", "weird": false})


func review_choices(item: Dictionary) -> Array:
	if item["kind"] == "success":
		return ["self", "owner"]
	return ["blame", "own", "spin"] if item["weird"] else ["blame", "own"]


func resolve_review(choices: Dictionary) -> void:
	if phase != "review":
		return
	for item in review:
		var t := task(item["uid"])
		var p: String = t["owner"]
		var st: Dictionary = people[p]
		var choice: String = choices.get(item["uid"], review_choices(item)[0])
		t["reviewed"] = true
		var names := {"task": "@taskname." + t["id"], "owner": "@name.%s.nom" % p, "owner_gen": "@name.%s.gen" % p, "owner_dat": "@name.%s.dat" % p}
		history.append({"who": "you", "key": "review.%s" % choice, "args": [], "names": names, "day": day})
		match choice:
			"self":
				boss += 2
				st["mood"] -= 1.5
				st["trust"] -= 1
				_say("boss", "review.boss.self", [], names)
				if p == "vika":
					st["ambition"] += 1
					if st["ambition"] >= 3:
						vika_standing += 1
						_say("vika", "review.vika_goes_to_boss", [], names)
				else:
					_say(p, "review.hurt", [], names)
			"owner":
				boss += 1
				st["mood"] += 1.0
				st["trust"] += 1
				st["promised"] = false
				_say("boss", "review.boss.owner", [], names)
				if p == "vika":
					vika_standing += 1
			"blame":
				st["mood"] -= 2.0
				st["trust"] -= 1
				_say("boss", "review.boss.blame", [], names)
				_say(p, "review.blamed", [], names)
			"own":
				boss -= 1
				st["trust"] += 1
				_say("boss", "review.boss.own", [], names)
			"spin":
				if rng.randf() < 0.5:
					boss += 1
					_say("boss", "review.boss.spin_ok", [], names)
				else:
					boss -= 1
					_say("boss", "review.boss.spin_bad", [], names)
		st["mood"] = clampf(st["mood"], -5.0, 5.0)
	review.clear()
	if day >= C.DAYS:
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


func _finish_run() -> void:
	var trust_sum := 0
	for p in C.TEAM:
		trust_sum += -3 if people[p]["gone"] else people[p]["trust"]
	var trust_avg := float(trust_sum) / C.TEAM.size()
	if quits >= 2:
		ending = "team_gone"
	elif boss <= -4:
		ending = "fired"
	elif vika_standing >= 3 and vika_standing > boss:
		ending = "replaced"
	elif hours >= 24:
		ending = "workhorse"
	elif hours <= 8 and boss >= 2 and trust_avg < 0.0:
		ending = "puppeteer"
	elif trust_avg >= 1.0 and boss >= 1 and quits == 0:
		ending = "leader"
	elif hours <= 8 and boss >= 2:
		ending = "puppeteer"
	else:
		ending = "middle"
	phase = "end"


func broken_promises() -> Array[String]:
	var result: Array[String] = []
	for p in C.TEAM:
		if people[p]["promised"]:
			result.append(p)
	return result


func skills_grown(p: String) -> Array[String]:
	var result: Array[String] = []
	for cat in C.CATEGORIES:
		var start: int = C.PEOPLE[p]["skills"][cat]
		if people[p]["skills"][cat] > start + 1:
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


func size_word(t: Dictionary) -> String:
	return "size.%d" % clampi(t["size"], 1, 4)


# ---------- helpers ----------

func _say(who: String, key: String, args: Array = [], names: Dictionary = {}) -> void:
	history.append({"who": who, "key": key, "args": args, "names": names, "day": day})


func _narrate(key: String, args: Array = [], names: Dictionary = {}) -> void:
	history.append({"who": "", "key": key, "args": args, "names": names, "day": day})
