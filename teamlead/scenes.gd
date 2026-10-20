extends RefCounted
# Morning scenes: small situations that grow out of what's happening on the team.
# Each scene checks the state, says its lines, offers a few choices, and leaves consequences
# that come back later (flags, task changes, follow-up scenes). All text lives in locale.gd
# under event.<id>.*; rules.gd calls queue() every morning and resolve() on a choice.
# Not static so the checks can be called by name.
#
# Event: {"id", "who" (main speaker), "lines": [{"who", "key"}], "choices": [String], "names": {}, "uid"}.
# A choice like "lend:dima" carries an argument after the colon.

const C = preload("res://teamlead/content.gd")
const L = preload("res://teamlead/locale.gd")

const MAX_PER_MORNING := 2
# How many times you can say no to one person before they complain to Irina.
const DECLINES_TO_COMPLAIN := 3

# How your answers lean as a lead (Adizes: P results, A order, E change, I people). Keyed "event/choice".
const STYLE := {
	"talk/dayoff": [["I", 0.5]], "talk/lighten": [["I", 0.5]], "talk/push": [["P", 0.7], ["I", -0.3]],
	"talk/listen": [["I", 0.5]], "talk/apologize": [["I", 0.5]], "talk/dismiss": [["P", 0.3], ["I", -0.5]],
	"talk/fix_load": [["I", 0.3], ["A", 0.3]], "talk/fix_bored": [["E", 0.5]], "talk/fix_hate": [["I", 0.3]],
	"talk/praise": [["I", 0.3]], "talk/critique": [["P", 0.3], ["A", 0.2]], "talk/mention": [["I", 0.3]],
	"talk/stretch": [["E", 0.5]], "talk/promote": [["I", 0.3]], "talk/not_yet": [["A", 0.3]],
	"talk/ask_about": [["I", 0.3]], "talk/praise_general": [["I", 0.2]],
	"talk/gift_craft": [["I", 0.5]], "talk/gift_visibility": [["I", 0.5]], "talk/gift_growth": [["I", 0.3], ["E", 0.2]], "talk/gift_peace": [["I", 0.3], ["A", 0.2]],
	"boss_visit/warn": [["A", 1.0]], "boss_visit/delay": [["A", 0.3]], "boss_visit/contractor": [["E", 0.5]],
	"boss_visit/status": [["A", 0.5]], "boss_visit/mention": [["I", 0.5]], "boss_visit/vika_promo": [["I", 0.5]],
	"boss_show/alone": [["P", 0.5], ["I", -0.3]], "boss_show/with_owner": [["I", 0.5]],
	"boss_dump/take": [["P", 0.3]], "boss_dump/refuse": [["E", 1.0]],
	"boss_deadline/warn": [["A", 0.5]], "boss_deadline/yes": [["P", 0.3]],
	"boris_drunk/take": [["P", 0.3]], "boris_drunk/irina": [["A", 0.5]], "boris_drunk/refuse": [["E", 0.5]],
	"friday_deploy/allow": [["E", 0.3]], "friday_deploy/forbid": [["A", 0.7]], "friday_deploy/on_call": [["P", 0.5]],
	"weekend_fire/own": [["A", 0.3], ["I", 0.3]], "weekend_fire/postmortem": [["A", 0.7]], "weekend_fire/blame": [["P", 0.3], ["I", -0.5]],
	"chaos_meeting/all_go": [["I", 0.3]], "chaos_meeting/me_only": [["P", 0.3]], "chaos_meeting/later": [["A", 0.3]],
	"decline/later": [["A", 0.3]], "decline/not_ours": [["E", 0.3]], "decline/irina": [["A", 0.3]], "decline/boss_no": [["E", 0.5]],
	"intervene/faster": [["P", 0.7]], "intervene/careful": [["A", 0.7]], "intervene/cut": [["E", 0.5]],
	"intervene/my_way": [["P", 0.5], ["E", 0.3]], "intervene/take_over": [["P", 2.0]], "intervene/trust": [["I", 0.5]],
}
# Calls on complications, by what they do: push through, keep order, find another way, lean on people.
const COMP_STYLE := {
	"hack": "E", "manual": "E", "negotiate": "E", "push_back": "E",
	"deadline": "A", "escalate": "A", "fix": "A", "clean": "A", "dig": "A", "redo": "A", "wait": "A",
	"as_is": "P", "corners": "P", "push": "P", "accept": "P", "ignore": "P", "together": "P", "you_call": "P",
	"ask_gena": "I", "ask_taras": "I", "owner_handles": "I", "mediate": "I",
}

# Checked in this order; the first MAX_PER_MORNING that fire are shown.
const ORDER := [
	"probation", "chapter_intro", "weekend_fire", "chaos_meeting", "boss_dump", "boss_deadline", "boss_details", "complication", "marina_warns", "alex_offer", "vika_lie_found", "alex_vika_clash", "gena_forgot",
	"dima_mistake", "vika_raise", "vika_promise_check", "alex_tired", "dima_bored", "vika_takes_task", "gena_mentor", "taras_brag", "vika_rising", "taras_borrow", "boris_drunk", "friday_deploy",
]


func queue(r) -> void:
	for id in ORDER:
		if r.events.size() >= MAX_PER_MORNING:
			break
		var ev: Dictionary = call("_check_" + id, r)
		if not ev.is_empty():
			ev["id"] = ev.get("id", id)
			ev.merge({"names": {}, "uid": -1}, false)
			r.events.append(ev)


func here(r, p: String) -> bool:
	return r.available(p) and not r.people[p]["absent"]


func once(r, id: String) -> bool:
	if r.flags.has("scene_" + id):
		return false
	r.flags["scene_" + id] = true
	return true


# Scenes add cards by tag (data/tasks.tsv), so the table can rename or replace them freely.
func _add_tagged(r, tag: String) -> void:
	for id in C.tasks_with("tag", tag).slice(0, 1):
		r.add_task(id)


# Who's best at this kind of work and here today (falls back to you).
func _strongest(r, cat: String) -> String:
	var best := "me"
	for p in r.team:
		if here(r, p) and (best == "me" or r.people[p]["skills"][cat] > r.people[best]["skills"][cat]):
			best = p
	return best


func task_names(r, t: Dictionary) -> Dictionary:
	return {"task": "@taskname." + t["id"], "from": "@name.%s.nom" % t["from"], "owner": "@name.%s.nom" % t["owner"],
		"owner_gen": "@name.%s.gen" % t["owner"], "owner_acc": "@name.%s.acc" % t["owner"]}


# ---------- conditions ----------

# Irina checks on a public task that's clearly not going to make it.
func _check_boss_deadline(r) -> Dictionary:
	for t in r.tasks:
		if t["status"] != "active" or not t["public"] or t["asked"] or not r.team.has(t["owner"]):
			continue
		var left: int = t["due"] - r.day
		if left < 1 or left > 2 or r.days_needed(t) <= left + 0.3:
			continue
		t["asked"] = true
		return {"who": "boss", "uid": t["uid"], "names": task_names(r, t),
			"lines": [{"who": "boss", "key": "event.boss_deadline.ask"}], "choices": ["yes", "warn"]}
	return {}


# The first day of a later chapter: Irina sets the company's goal for the month and names the key projects.
func _check_chapter_intro(r) -> Dictionary:
	if r.chapter == 1 or r.chapter_day() != 1 or not once(r, "intro_%d" % r.chapter):
		return {}
	var id: String = C.CHAPTERS[r.chapter - 1]["id"]
	var names := {}
	for i in r.chapter_keys().size():
		names["k%d" % (i + 1)] = "@taskname." + r.chapter_keys()[i]
	return {"who": "boss", "names": names, "lines": [{"who": "boss", "key": "event.chapter_intro.%s" % id}, {"who": "boss", "key": "event.chapter_intro.%s.keys" % id}], "choices": ["ok"]}


# Day one: Irina explains the probation and names the key projects.
func _check_probation(r) -> Dictionary:
	if r.day != 1 or not once(r, "probation"):
		return {}
	var names := {}
	for i in r.chapter_keys().size():
		names["k%d" % (i + 1)] = "@taskname." + r.chapter_keys()[i]
	return {"who": "boss", "names": names, "lines": [{"who": "boss", "key": "event.probation.ask"}, {"who": "boss", "key": "event.probation.ask2"},
		{"who": "boss", "key": "event.probation.taste." + r.boss_type}], "choices": ["ok"]}


# Irina drops something urgent on you. Day 2 the first time (you can't refuse yet), then now and
# then when the team is loaded, at most once a week.
func _check_boss_dump(r) -> Dictionary:
	var first: bool = r.day == 2 and not r.flags.has("dump_w0")
	var load := 0
	for t in r.tasks:
		if t["status"] == "active" and r.team.has(t["owner"]):
			load += 1
	if not first and (r.day < 6 or r.flags.has("dump_w%d" % r.week()) or load < 6 or r.rng.randf() > 0.4):
		return {}
	r.flags["dump_w%d" % r.week()] = true
	var used: Array = r.flags.get("dumps_used", [])
	var id: String = C.DUMPS[0]
	for d in C.DUMPS:
		if not used.has(d):
			id = d
			break
	used.append(id)
	r.flags["dumps_used"] = used
	return {"who": "boss", "dump": id, "names": {"task": "@taskname." + id},
		"lines": [{"who": "boss", "key": "event.boss_dump.ask"}], "choices": ["take", "refuse"]}


# Boris from Regulatory Reporting bursts in after lunch, merry, having promised a bank something in your name.
func _check_boris_drunk(r) -> Dictionary:
	if r.day < 7 or r.rng.randf() > 0.3 or not once(r, "boris_drunk"):
		return {}
	return {"who": "boris", "lines": [{"who": "boris", "key": "event.boris_drunk.ask"}], "choices": ["take", "irina", "refuse"]}


# Friday: Stas wants to ship tonight.
func _check_friday_deploy(r) -> Dictionary:
	if r.day % 5 != 0 or r.day < 5 or r.day >= r.last_day() or r.flags.has("no_friday_deploys") or r.flags.get("friday_asks", 0) >= 2 or r.rng.randf() > 0.6:
		return {}
	r.flags["friday_asks"] = r.flags.get("friday_asks", 0) + 1
	return {"who": "stas", "lines": [{"who": "stas", "key": "event.friday_deploy.ask"}], "choices": ["allow", "forbid", "on_call"]}


# Monday after a Friday deploy went wrong: someone spent the weekend fixing prod, and Irina wants to know.
func _check_weekend_fire(r) -> Dictionary:
	if not r.flags.has("weekend_fire") or r.day % 5 != 1:
		return {}
	var fixer: String = r.flags["weekend_fire"]
	r.flags.erase("weekend_fire")
	r.flags["last_fixer"] = fixer
	var names := {}
	# Whoever was on it has left since: it fell to you.
	if fixer == "me" or not r.available(fixer):
		r.my_energy -= 2.0
		r.my_week_hours[r.week()] += 8
		names["who"] = "@you"
	elif r.available(fixer):
		r.people[fixer]["energy"] -= 3.0
		r.people[fixer]["mood"] -= 1.0
		r.people[fixer]["week_extra"][r.week()] += 8
		names["who"] = "@name.%s.nom" % fixer
	r.say("", "event.weekend_fire.story", [], names)
	return {"who": "boss", "names": names, "lines": [{"who": "boss", "key": "event.weekend_fire.ask"}], "choices": ["own", "postmortem", "blame"]}


# The chaotic Irina: rushes in mid-day and wants everyone in the meeting room, now.
func _check_chaos_meeting(r) -> Dictionary:
	if r.boss_type != "X" or r.day < 3 or r.flags.has("chaos_w%d" % r.week()) or r.rng.randf() > 0.35:
		return {}
	r.flags["chaos_w%d" % r.week()] = true
	return {"who": "boss", "lines": [{"who": "boss", "key": "event.chaos_meeting.ask"}], "choices": ["all_go", "me_only", "later"]}


# Taras shows how weight is made: by being the one who presents.
func _check_taras_brag(r) -> Dictionary:
	if r.day < 3 or not once(r, "taras_brag"):
		return {}
	return {"who": "taras", "lines": [{"who": "taras", "key": "event.taras_brag.ask"}], "choices": ["noted", "who_did"]}


# Irina lets slip that Vika is rising.
func _check_vika_rising(r) -> Dictionary:
	if not r.available("vika") or r.vika_standing < 2 or r.vika_standing < r.boss - 1.0 or not once(r, "vika_rising"):
		return {}
	return {"who": "boss", "lines": [{"who": "boss", "key": "event.vika_rising.ask"}], "choices": ["ok", "worry"]}


# You took the credit at the review; now Irina wants the details.
func _check_boss_details(r) -> Dictionary:
	var credits: Array = r.flags.get("credit_taken", [])
	if r.flags.has("boss_details_w%d" % r.week()):
		return {}
	for c in credits:
		if r.day > c["day"] and r.available(c["owner"]) and r.rng.randf() < 0.6:
			credits.erase(c)
			r.flags["boss_details_w%d" % r.week()] = true
			var t: Dictionary = r.task(c["uid"])
			return {"who": "boss", "uid": t["uid"], "names": task_names(r, t),
				"lines": [{"who": "boss", "key": "event.boss_details.ask"}], "choices": ["call_owner", "improvise", "dodge"]}
	return {}


# Something comes up inside a task that's under way. At most one a morning, once per task.
func _check_complication(r) -> Dictionary:
	var candidates: Array = []
	for t in r.tasks:
		if t["status"] != "active" or t["complicated"] or t["id"].begins_with("init_") or not r.team.has(t["owner"]) or not here(r, t["owner"]):
			continue
		if t["progress"] < 0.2 * t["size"] or t["size"] - t["progress"] < 0.6:
			continue
		candidates.append(t)
	candidates.shuffle()
	for t in candidates:
		# A lead who keeps order sees fewer surprises.
		if r.rng.randf() > (0.25 if r.leans("A") else 0.35):
			continue
		var options: Array = []
		for cid in C.COMPLICATIONS:
			var c: Dictionary = C.COMPLICATIONS[cid]
			if c["cats"].has(t["cat"]) and not r.comp_off.has(cid):
				options.append(cid)
		if options.is_empty():
			continue
		var cid: String = options[r.rng.randi() % options.size()]
		var data: Dictionary = C.COMPLICATIONS[cid]
		t["complicated"] = true
		var who: String = t["owner"] if data["who"] == "owner" else t["from"]
		var choices: Array = data["choices"].keys()
		if cid == "old_system" and (t["owner"] == "gena" or not here(r, "gena")):
			choices.erase("ask_gena")
		return {"id": "comp_" + cid, "comp": cid, "who": who, "uid": t["uid"], "names": task_names(r, t),
			"lines": [{"who": who, "key": "event.comp_%s.ask" % cid}], "choices": choices}
	return {}


# Someone unhappy went to HR; Marina passes it on.
func _check_marina_warns(r) -> Dictionary:
	for p in r.team:
		if here(r, p) and r.people[p]["mood"] <= -3.0 and once(r, "marina_" + p):
			return {"who": "marina", "target": p, "names": {"who": "@name.%s.nom" % p, "who_ins": "@name.%s.ins" % p},
				"lines": [{"who": "marina", "key": "event.marina_warns.ask." + p}], "choices": ["listen", "dismiss"]}
	return {}


# Alex has had enough and got an offer.
func _check_alex_offer(r) -> Dictionary:
	if r.day < 3 or not here(r, "alex") or r.people["alex"]["mood"] > -2.5 or not once(r, "alex_offer"):
		return {}
	return {"who": "alex", "lines": [{"who": "alex", "key": "event.alex_offer.ask"}], "choices": ["terms", "promise", "let_go"]}


# You told Vika you'd talked to Irina. She asked Irina herself.
func _check_vika_lie_found(r) -> Dictionary:
	if not r.flags.has("vika_lied") or not here(r, "vika") or not r.people["vika"]["promised"]:
		return {}
	if r.day - r.flags["vika_lied"] < 1 or r.rng.randf() > 0.5 or not once(r, "vika_lie_found"):
		return {}
	return {"who": "vika", "lines": [{"who": "vika", "key": "event.vika_lie_found.ask"}], "choices": ["sorry", "blame_boss"]}


# Alex and Vika worked on the same thing; now they argue whose work it was.
func _check_alex_vika_clash(r) -> Dictionary:
	if not here(r, "alex") or not here(r, "vika") or r.flags.has("scene_alex_vika_clash"):
		return {}
	for t in r.tasks:
		if (t["owner"] == "vika" and t["helped"].has("alex")) or (t["owner"] == "alex" and t["helped"].has("vika")):
			once(r, "alex_vika_clash")
			return {"who": "alex", "uid": t["uid"], "names": task_names(r, t),
				"lines": [{"who": "alex", "key": "event.alex_vika_clash.ask"}, {"who": "vika", "key": "event.alex_vika_clash.ask2"}],
				"choices": ["both", "side_alex", "side_vika", "stay_out"]}
	return {}


# Something has sat at the bottom of Gena's list for days; whoever asked for it is now asking.
func _check_gena_forgot(r) -> Dictionary:
	if not here(r, "gena") or r.flags.has("scene_gena_forgot"):
		return {}
	var q: Array = r.queue_of("gena")
	for i in range(1, q.size()):
		var t: Dictionary = q[i]
		if t["progress"] == 0.0 and r.day - t["assigned_day"] >= 2 and t["due"] - r.day <= 2:
			once(r, "gena_forgot")
			var asker: String = t["from"]
			return {"who": "gena", "uid": t["uid"], "names": task_names(r, t),
				"lines": [{"who": asker, "key": "event.gena_forgot.ask"}, {"who": "gena", "key": "event.gena_forgot.ask2"}],
				"choices": ["first", "take_back", "myself"]}
	return {}


# Dima is in over his head on his current task and comes to confess.
func _check_dima_mistake(r) -> Dictionary:
	if r.day < 2 or not here(r, "dima") or r.flags.has("scene_dima_mistake"):
		return {}
	var q: Array = r.queue_of("dima")
	if q.is_empty():
		return {}
	var t: Dictionary = q[0]
	if t["progress"] < 0.4 or r.people["dima"]["skills"][t["cat"]] > 1:
		return {}
	once(r, "dima_mistake")
	return {"who": "dima", "uid": t["uid"], "names": task_names(r, t),
		"lines": [{"who": "dima", "key": "event.dima_mistake.ask"}], "choices": ["help", "redo", "ignore"]}


func _check_vika_raise(r) -> Dictionary:
	if not here(r, "vika") or r.people["vika"]["ambition"] < 2 or r.people["vika"]["promised"] or not once(r, "vika_raise"):
		return {}
	return {"who": "vika", "lines": [{"who": "vika", "key": "event.vika_raise.ask"}], "choices": ["promise", "not_yet"]}


# A few days after a promise, Vika asks how it went.
func _check_vika_promise_check(r) -> Dictionary:
	var st: Dictionary = r.people["vika"]
	if not here(r, "vika") or not st["promised"] or r.day - st["promised_day"] < 3 or not once(r, "vika_promise_check"):
		return {}
	return {"who": "vika", "lines": [{"who": "vika", "key": "event.vika_promise_check.ask"}], "choices": ["lie", "honest", "do_now"]}


func _check_alex_tired(r) -> Dictionary:
	if not here(r, "alex") or r.people["alex"]["energy"] > r.TIRED_ENERGY or not once(r, "alex_tired"):
		return {}
	return {"who": "alex", "lines": [{"who": "alex", "key": "event.alex_tired.ask"}], "choices": ["dayoff", "hold_on"]}


# Dima has been sitting without work.
func _check_dima_bored(r) -> Dictionary:
	if not here(r, "dima") or r.people["dima"]["idle_days"] < 2 or not once(r, "dima_bored"):
		return {}
	var choices := ["wait", "study"]
	if here(r, "alex") and not r.queue_of("alex").is_empty():
		choices.push_front("pair_alex")
	return {"who": "dima", "lines": [{"who": "dima", "key": "event.dima_bored.ask"}], "choices": choices}


# Vika has room and spots a visible task sitting in someone else's queue.
func _check_vika_takes_task(r) -> Dictionary:
	if not here(r, "vika") or r.queue_of("vika").size() > 1 or r.flags.has("scene_vika_takes_task"):
		return {}
	for t in r.tasks:
		if t["status"] == "active" and t["public"] and t["progress"] == 0.0 and r.team.has(t["owner"]) and t["owner"] != "vika":
			once(r, "vika_takes_task")
			return {"who": "vika", "uid": t["uid"], "names": task_names(r, t),
				"lines": [{"who": "vika", "key": "event.vika_takes_task.ask"}], "choices": ["give", "refuse"]}
	return {}


# Gena and Dima worked together for a couple of days, and Gena liked it.
func _check_gena_mentor(r) -> Dictionary:
	if not here(r, "gena") or not r.available("dima") or r.flags.has("scene_gena_mentor"):
		return {}
	for t in r.tasks:
		if (t["owner"] == "gena" and t["helped"].get("dima", 0) >= 1) or (t["owner"] == "dima" and t["helped"].get("gena", 0) >= 1):
			once(r, "gena_mentor")
			return {"who": "gena", "lines": [{"who": "gena", "key": "event.gena_mentor.ask"}], "choices": ["encourage", "work"]}
	return {}


# Taras needs a pair of hands for a day.
func _check_taras_borrow(r) -> Dictionary:
	if r.day < 3 or r.day > r.last_day() - 3 or r.flags.has("scene_taras_borrow"):
		return {}
	if r.day < 12 and r.rng.randf() > 0.15:
		return {}
	var choices := []
	for p in r.team:
		if here(r, p):
			choices.append("lend:" + p)
	if choices.is_empty():
		return {}
	once(r, "taras_borrow")
	choices.append("refuse")
	return {"who": "taras", "lines": [{"who": "taras", "key": "event.taras_borrow.ask"}], "choices": choices}


# ---------- choices ----------

func _resolve_complication(r, ev: Dictionary, c: String, t: Dictionary, names: Dictionary) -> void:
	var cid: String = ev["comp"]
	var fx: Dictionary = C.COMPLICATIONS[cid]["choices"][c]
	var p: String = t["owner"]
	if not r.team.has(p) or t["status"] != "active":
		return
	var reply := "event.comp_%s.%s.reply" % [cid, c]
	if COMP_STYLE.has(c):
		r.lead(COMP_STYLE[c], 0.6)
	if fx.has("check"):
		var passed: bool = r.people[p]["skills"][t["cat"]] >= fx["check"]
		fx = fx["pass"] if passed else fx["fail"]
		reply = "event.comp_%s.%s.%s" % [cid, c, "pass" if passed else "fail"]
	var who: String = ev["who"]
	match fx.get("special", ""):
		"taras":
			who = "taras"
			if r.flags.has("taras_grudge"):
				fx = {"block": 1}
				reply = "event.comp_needs_access.ask_taras.no"
			else:
				r.flags["taras_owes"] = false
		"grudge":
			r.flags["taras_grudge"] = true
		"please_from":
			if t["from"] == "boss":
				r.boss += 0.5
		"annoy_from":
			if t["from"] == "boss":
				r.boss -= 0.5
		"negotiate":
			fx = fx.duplicate()
			if r.rng.randf() < 0.6:
				fx["rework"] = 0.1
				reply = "event.comp_client_changes.negotiate.ok"
			else:
				fx["rework"] = 0.4
				reply = "event.comp_client_changes.negotiate.bad"
		"gena":
			who = "gena"
			r.people["gena"]["mood"] += 1.0
	t["size"] += fx.get("size", 0.0)
	t["due"] += fx.get("due", 0)
	t["q_bonus"] += fx.get("quality", 0.0)
	t["progress"] -= t["progress"] * fx.get("rework", 0.0)
	t["blocked"] = maxi(t["blocked"], fx.get("block", 0))
	if fx.get("hours", 0) > 0:
		r.add_mgmt_hours(fx["hours"])
		t["involved"] = true
	if fx.has("learn"):
		r.learn(p, t["cat"], fx["learn"])
	r.people[p]["mood"] += fx.get("mood", 0.0)
	r.people[p]["energy"] += fx.get("energy", 0.0)
	r.boss += fx.get("boss", 0.0)
	if fx.has("boss") or fx.get("special", "") in ["please_from", "annoy_from"]:
		r.weight_cause = t["id"]
	r.say(who, reply, [], names)


# ---------- one-on-ones ----------

# What's on their mind decides how the talk opens; the answers depend on the topic and on what you
# know about them (a known motive adds an answer aimed right at it).
# The serious talk: a warning first; a week later, the decision. Or straight out, without one.
func fire_event(r, p: String) -> Dictionary:
	var choices: Array = ["fire", "keep"] if r.fire_ready(p) else (["back"] if r.warned(p) else ["warn", "fire_now", "back"])
	return {"id": "fire", "who": p, "target": p, "lines": [{"who": p, "key": _own_line(r, "fire.ask", p)}], "choices": choices}


# A person's own version of a line if they have one (the four, or a hire's archetype), else the plain one.
func _own_line(r, key: String, p: String) -> String:
	var own := "%s.%s" % [key, p]
	return own if L.has_key(own) else key


func _resolve_fire(r, ev: Dictionary, c: String) -> String:
	var p: String = ev["target"]
	var names := {"who": "@name.%s.nom" % p, "who_acc": "@name.%s.acc" % p}
	match c:
		"warn":
			r.warn(p)
			return _own_line(r, "fire.react.warn", p)
		"fire_now":
			r.say(p, _own_line(r, "fire.react.fired", p))
			r.say("marina", "fire.marina_scandal", [], names)
			r.let_go(p, false)
		"fire":
			r.say(p, _own_line(r, "fire.react.fired", p))
			r.say("marina", "fire.marina_ok", [], names)
			r.let_go(p, true)
		"keep":
			r.people[p]["warned_day"] = -1
			r.people[p]["mood"] = clampf(r.people[p]["mood"] + 0.8, -5.0, 5.0)
			return _own_line(r, "fire.react.kept", p)
		"back":
			return "fire.react.back"
	return ""


# An interview: two questions out of four; each answer gives something away.
func interview_event(r, id: String) -> Dictionary:
	var c: Dictionary = r.candidate(id)
	var left: Array = C.INTERVIEW_TOPICS.filter(func(x): return not c["asked"].has(x))
	var lines := [{"who": id, "key": "hire.interview.hello"}] if c["asked"].is_empty() else []
	return {"id": "interview", "who": id, "target": id, "lines": lines, "choices": left}


func _resolve_interview(r, ev: Dictionary, c: String) -> String:
	var id: String = ev["target"]
	var cand: Dictionary = r.candidate(id)
	var arch: String = r.archetype(id)
	cand["asked"].append(c)
	if c == "tech":
		# Asking about the work shows the truth about what their CV is proudest of.
		var best: String = C.CATEGORIES[0]
		for cat in C.CATEGORIES:
			if r.hires[id]["cv"][cat] > r.hires[id]["cv"][best]:
				best = cat
		cand["known"][best] = true
		var lvl: int = r.hires[id]["skills"][best]
		r.say(id, "hire.answer.tech.%d" % clampi(lvl, 0, 4), [], {"cat": "@cat." + best})
		r.say("", "hire.tech_seen", [], {"who": "@name.%s.nom" % id, "cat": "@cat." + best, "level": "@level.%d" % lvl})
	else:
		r.say(id, "hire.answer.%s.%s" % [c, arch])
	if cand["asked"].size() < 2:
		r.events.push_front(interview_event(r, id).merged({"names": {}, "uid": -1}))
	return ""


func talk_event(r, p: String) -> Dictionary:
	var st: Dictionary = r.people[p]
	var topic := "fine"
	var names := {}
	var reason := ""
	if st["energy"] <= 3.5:
		topic = "tired"
	elif st["mood"] <= -1.5:
		topic = "upset"
		reason = _upset_reason(r, p)
	elif r.day - st["last_done"] <= 2 and _last_good(r, p) >= 0:
		topic = "proud"
		names["task"] = "@taskname." + r.task(_last_good(r, p))["id"]
	elif r.info(p)["drive"] in ["growth", "visibility"] and r.day >= 3 and not r.flags.has("asked_growth_" + p):
		topic = "grow"
		r.flags["asked_growth_" + p] = true
	var key: String = r._first_key(["event.talk_%s.ask.%s" % [topic, p], "event.talk_%s.ask.%s" % [topic, reason], "event.talk_%s.ask" % topic])
	var choices: Array = []
	match topic:
		"tired":
			choices = ["dayoff", "push"]
			if r.queue_of(p).size() >= 2:
				choices.insert(1, "lighten")
		"upset":
			choices = ["listen"]
			if reason == "credit":
				choices.append("apologize")
			elif reason != "general":
				choices.append("fix_" + reason)
			choices.append("dismiss")
		"proud":
			choices = ["praise", "critique", "mention"]
		"grow":
			choices = ["stretch", "promote", "not_yet"]
		"fine":
			choices = ["ask_about", "praise_general"]
			if st["known"].has("drive"):
				choices.append("gift_" + r.info(p)["drive"])
	return {"id": "talk_" + topic, "who": p, "target": p, "reason": reason, "names": names, "uid": _last_good(r, p) if topic == "proud" else -1,
		"lines": [{"who": p, "key": key}], "choices": choices}


func _upset_reason(r, p: String) -> String:
	for c in r.flags.get("credit_taken", []):
		if c["owner"] == p:
			return "credit"
	if r.queue_of(p).size() >= 3:
		return "load"
	if r.people[p]["idle_days"] >= 2:
		return "bored"
	var q: Array = r.queue_of(p)
	if not q.is_empty() and r.info(p)["hates"].has(q[0]["cat"]):
		return "hate"
	return "general"


func _last_good(r, p: String) -> int:
	var best := -1
	var best_day := -1
	for t in r.tasks:
		if t["owner"] == p and t["status"] == "done" and (t["quality"] == "good" or t["quality"] == "ok") and t["done_day"] > best_day and not t["id"].begins_with("init_"):
			best = t["uid"]
			best_day = t["done_day"]
	return best


func _resolve_talk(r, ev: Dictionary, c: String, names: Dictionary) -> String:
	var p: String = ev["target"]
	var st: Dictionary = r.people[p]
	var reply := "event.%s.%s.reply" % [ev["id"], c]
	match c:
		"dayoff":
			r.give_day_off(p)
			st["mood"] += 1.0
		"lighten":
			r.lighten(p)
			st["mood"] += 1.0
			st["trust"] += 1
		"push":
			st["pushed"] = r.PUSH_DAYS
			st["mood"] -= 2.0 if r.info(p)["drive"] == "peace" else 1.0
			st["energy"] -= 0.5
		"listen":
			st["mood"] += 1.0
			r.say(p, reply)
			r.reveal_next(p)
			return ""
		"apologize":
			st["mood"] += 1.5
			st["trust"] += 1
		"fix_load":
			r.lighten(p)
			st["mood"] += 1.0
		"fix_bored":
			r.offer_today[p] = true
			if r.initiative_offer(p) != "":
				r.accept_initiative(p)
			st["mood"] += 1.0
		"fix_hate":
			st["mood"] += 1.0
			r.flags["calm_" + p] = r.day + 3
		"dismiss":
			st["mood"] -= 0.5
			if ev["reason"] == "credit":
				st["trust"] -= 1
		"praise":
			st["mood"] += 1.0
			st["trust"] += 1
		"critique":
			var t: Dictionary = r.task(ev["uid"])
			if t.get("quality", "") == "good":
				st["mood"] -= 1.5
				st["trust"] -= 1
				reply = "event.talk_proud.critique.unfair"
			else:
				st["mood"] -= 0.5
				st["trust"] += 1
				r.learn(p, t["cat"], 1.0)
		"mention":
			st["mood"] += 1.5
			r.flags["mention_" + p] = ev["uid"]
		"stretch":
			st["mood"] += 2.0
			r.flags["stretch_" + p] = true
		"promote":
			if st["promised"]:
				st["trust"] -= 1
				reply = "talk.promise.again"
			else:
				r.make_promise(p)
				st["mood"] += 2.0
		"not_yet":
			st["mood"] -= 0.5
			st["trust"] += 1
		"ask_about":
			st["mood"] += 0.5
			r.reveal_next(p)
			return ""
		"praise_general":
			if r.day - st["last_done"] <= 3:
				st["mood"] += 1.0
			else:
				reply = "event.talk_fine.praise_general.empty"
		"gift_craft", "gift_visibility", "gift_growth", "gift_peace":
			st["mood"] += 1.5
			st["trust"] += 1
			match c:
				"gift_visibility":
					if p == "vika":
						r.vika_up()
				"gift_growth":
					r.learn(p, "infra", 1.5)
				"gift_peace":
					r.flags["calm_" + p] = r.day + 4
	return r._first_key(["event.%s.%s.reply.%s" % [ev["id"], c, p], reply])


# ---------- stepping into a task ----------

# They tell you how it's going. Most say it straight; Alex won't admit he's behind until it's obvious.
func intervene_event(r, t: Dictionary) -> Dictionary:
	var p: String = t["owner"]
	var state := "on_track"
	if t.get("stuck", 0) > 0:
		state = "stuck"
	elif t["blocked"] > 0:
		state = "blocked"
	elif t["progress"] >= 0.75 * t["size"]:
		state = "almost"
	elif r.days_needed(t) > t["due"] - r.day + 1.3:
		state = "behind"
	var said := state
	if state == "behind" and r.info(p).get("workaholic", false) and r.days_needed(t) < t["due"] - r.day + 3.0:
		said = "on_track"
	return {"id": "intervene", "who": p, "target": p, "uid": t["uid"], "state": state, "names": task_names(r, t),
		"lines": [{"who": p, "key": "event.intervene.ask." + said}],
		"choices": ["trust", "faster", "careful", "cut", "my_way", "take_over"]}


func _resolve_intervene(r, ev: Dictionary, c: String) -> String:
	var t: Dictionary = r.task(ev["uid"])
	var p: String = ev["target"]
	var st: Dictionary = r.people[p]
	var info: Dictionary = r.info(p)
	var reply := "event.intervene.%s.reply" % c
	# Any real question gets them out of the wrong place; a pat on the back doesn't.
	if t.get("stuck", 0) > 0 and c != "trust":
		t["stuck"] = 0
		r.say(p, "event.intervene.unstuck", [], task_names(r, t))
	match c:
		"trust":
			# Fine when it is going well; when they're behind, nothing changes and you'll find out later.
			if ev["state"] != "behind":
				st["mood"] += 0.3
				st["trust"] += 1 if info["drive"] == "craft" else 0
		"faster":
			t["pace"] = 1.3
			t["q_bonus"] -= 0.6
			if info["drive"] == "craft" or info["drive"] == "peace":
				st["mood"] -= 1.0
				reply = "event.intervene.faster.reply.unhappy"
			else:
				st["mood"] -= 0.3
		"careful":
			t["pace"] = 0.85
			t["q_bonus"] += 0.6
			if info["drive"] == "craft" or info["drive"] == "peace":
				st["mood"] += 0.5
		"cut":
			t["size"] = maxf(t["progress"] + 0.3, t["size"] * 0.6)
			t["cut"] = true
			if t["from"] == "boss":
				r.boss -= 0.3
		"my_way":
			# Your way only helps if you actually know this better than they do.
			t["involved"] = true
			var mine: int = r.my_skill(t["cat"])
			var theirs: int = st["skills"][t["cat"]]
			if mine > theirs:
				t["q_bonus"] += 0.8
				r.learn(p, t["cat"], 1.0)
				if info["drive"] == "craft" and theirs >= 3:
					st["mood"] -= 0.7
					reply = "event.intervene.my_way.right_proud"
				else:
					st["mood"] += 0.5 if info["drive"] == "growth" else 0.0
					reply = "event.intervene.my_way.right"
			else:
				t["q_bonus"] -= 0.5
				st["mood"] -= 1.0
				st["trust"] -= 1
				reply = "event.intervene.my_way.wrong"
		"take_over":
			# Some are glad to be rid of it, some feel you didn't trust them.
			var swamped: bool = r._feels_tired(p) or r.queue_of(p).size() >= r.OVERLOAD_AT or ev["state"] == "behind"
			r.take_over(t)
			if swamped:
				st["mood"] += 0.5
				reply = "event.intervene.take_over.relief"
			elif info["drive"] == "peace":
				st["mood"] -= 0.3
				reply = "event.intervene.take_over.calm"
			else:
				st["mood"] -= 1.5 if info.get("touchy", false) else 1.0
				st["trust"] -= 1
				reply = "event.intervene.take_over.hurt"
	return r._first_key(["%s.%s" % [reply, p], reply])


# ---------- saying no ----------

func decline_event(r, t: Dictionary) -> Dictionary:
	var who: String = t["from"]
	var choices: Array = ["boss_no", "keep"] if who == "boss" else ["later", "not_ours", "irina", "keep"]
	return {"id": "decline", "who": who, "uid": t["uid"], "names": task_names(r, t),
		"lines": [{"who": who, "key": "event.decline.ask"}], "choices": choices}


func _resolve_decline(r, ev: Dictionary, c: String) -> String:
	var t: Dictionary = r.task(ev["uid"])
	var who: String = ev["who"]
	var reply := "event.decline.%s.reply" % c
	# Turning down something the boss will look at doesn't go unnoticed.
	var seen: bool = t["public"] and who != "boss"
	match c:
		"later", "not_ours":
			r.drop_task(t, c == "later")
			if seen:
				r.boss -= 0.3
			# Every no adds up with the person who asked ("not ours" counts double); every third time they
			# go to Irina. Taras goes straight away when told it's not ours.
			var before: int = r.flags.get("declined_" + who, 0)
			var after: int = before + (2 if c == "not_ours" else 1)
			r.flags["declined_" + who] = after
			if (who == "taras" and c == "not_ours") or after / DECLINES_TO_COMPLAIN > before / DECLINES_TO_COMPLAIN:
				r.boss -= 0.5
				r.say("", "decline.escalated", [], {"who_gen": "@name.%s.gen" % who})
				if who == "taras":
					r.flags["taras_grudge"] = true
		"irina":
			r.spend_attention()
			if r.has_weight():
				r.drop_task(t, false)
				r.boss -= 0.2
				r.say("boss", "event.decline.irina.ok", [], ev["names"])
			else:
				r.say("boss", "event.decline.irina.no", [], ev["names"])
			return ""
		"boss_no":
			if r.has_weight():
				r.drop_task(t, false)
				r.boss -= 0.5
				reply = "event.decline.boss_no.ok"
			else:
				r.boss -= 0.3
				reply = "event.decline.boss_no.no"
	return r._first_key(["%s.%s" % [reply, who], reply])


# ---------- going to Irina ----------

# What you can bring her today. Each choice carries its own task name for the button.
func boss_visit(r) -> Dictionary:
	var choices: Array = []
	var labels := {}
	var shows := 0
	for t in r.tasks:
		if shows < 2 and t["status"] == "done" and t["public"] and r.team.has(t["owner"]) and r.day - t["done_day"] <= 5 and not t.get("shown", false) and (t["quality"] == "good" or t["quality"] == "ok"):
			choices.append("show:%d" % t["uid"])
			labels["show:%d" % t["uid"]] = {"task": "@taskname." + t["id"]}
			shows += 1
	for p in r.team:
		if r.flags.has("mention_" + p) and r.available(p):
			choices.append("mention:" + p)
			labels["mention:" + p] = {"who_gen": "@name.%s.gen" % p}
	var risky := {}
	var near := {}
	for t in r.tasks:
		if t["status"] != "active" or not r.team.has(t["owner"]):
			continue
		var left: int = t["due"] - r.day
		if t["public"] and not t["asked"] and left >= 0 and r.days_needed(t) > left + 0.3 and (risky.is_empty() or t["key"]):
			risky = t
		if not t["key"] and (near.is_empty() or t["due"] < near["due"]):
			near = t
	if not risky.is_empty():
		for c in ["warn", "delay"]:
			choices.append("%s:%d" % [c, risky["uid"]])
			labels["%s:%d" % [c, risky["uid"]]] = {"task": "@taskname." + risky["id"]}
	if not near.is_empty():
		choices.append("contractor:%d" % near["uid"])
		labels["contractor:%d" % near["uid"]] = {"task": "@taskname." + near["id"]}
	if r.people["vika"]["promised"] and r.available("vika"):
		choices.append("vika_promo")
	choices.append("status")
	choices.append("leave")
	return {"id": "boss_visit", "who": "boss", "choice_names": labels,
		"lines": [{"who": "boss", "key": "event.boss_visit.ask.w%d" % r._level_of(r.boss)}], "choices": choices}


func _resolve_visit(r, ev: Dictionary, c: String, arg: String, names: Dictionary) -> String:
	var t: Dictionary = r.task(int(arg)) if arg.is_valid_int() else {}
	var reply := "event.boss_visit.%s.reply" % c
	match c:
		"show":
			t["shown"] = true
			r.events.push_front({"id": "boss_show", "who": "boss", "uid": t["uid"], "names": names,
				"choice_names": {"with_owner": {"owner_acc": "@name.%s.acc" % t["owner"]}},
				"lines": [{"who": "boss", "key": "event.boss_show.ask"}], "choices": ["alone", "with_owner"]})
			return ""
		"mention":
			var p := arg
			r.flags.erase("mention_" + p)
			r.people[p]["trust"] += 1
			r.people[p]["mood"] += 1.0
			if p == "vika":
				r.vika_up()
		"warn":
			t["asked"] = true
			t["due"] += 1
			r.boss += r.boss_like("A", 0.5)
			r.weight_cause = t["id"]
		"delay":
			t["asked"] = true
			if r.has_weight():
				t["due"] += 2
				r.boss -= 1.0
				r.weight_cause = t["id"]
			else:
				reply = "event.boss_visit.delay.no"
		"contractor":
			r.hire_contractor(t["uid"])
			return ""
		"status":
			# Keeping her in the loop is worth a little, once a week.
			if not r.flags.has("status_w%d" % r.week()):
				r.flags["status_w%d" % r.week()] = true
				r.boss += r.boss_like("A", 0.3)
			else:
				reply = "event.boss_visit.status.again"
		"vika_promo":
			r.people["vika"]["promised"] = false
			r.people["vika"]["trust"] += 1
			r.people["vika"]["mood"] += 2.0
			r.vika_up()
	return reply


func _resolve_show(r, ev: Dictionary, c: String) -> String:
	var t: Dictionary = r.task(ev["uid"])
	var p: String = t["owner"]
	r.weight_cause = t["id"]
	if c == "alone":
		r.boss += r.boss_like("P", 0.7)
		if not r.flags.has("credit_taken"):
			r.flags["credit_taken"] = []
		r.flags["credit_taken"].append({"uid": t["uid"], "owner": p, "day": r.day})
		# Word gets around sometimes.
		if r.available(p) and r.rng.randf() < 0.35:
			r.people[p]["trust"] -= 1
			r.people[p]["mood"] -= 1.0
			r.say(p, "event.boss_show.heard", [], {"task": "@taskname." + t["id"]})
	else:
		r.boss += r.boss_like("I", 0.25)
		r.people[p]["mood"] += 1.0
		r.people[p]["trust"] += 1
		if p == "vika" and t["key"]:
			r.vika_up()
	return "event.boss_show.%s.reply" % c


func resolve(r, ev: Dictionary, choice: String) -> void:
	var parts := choice.split(":")
	var c: String = parts[0]
	var arg: String = parts[1] if parts.size() > 1 else ""
	var t: Dictionary = r.task(ev["uid"]) if ev["uid"] >= 0 else {}
	var names: Dictionary = ev["names"].duplicate()
	if ev.has("choice_names"):
		names.merge(ev["choice_names"].get(choice, {}), true)
	elif arg != "":
		names["who"] = "@name.%s.acc" % arg
	r.history.append({"who": "you", "key": "event.%s.choice.%s" % [ev["id"], c], "args": [], "names": names, "day": r.day})
	for pair in STYLE.get(("talk" if ev["id"].begins_with("talk_") else ev["id"]) + "/" + c, []):
		r.lead(pair[0], pair[1])
	var who: String = ev["who"]
	var reply := "event.%s.%s.reply" % [ev["id"], c]
	var routed := ""
	if ev["id"].begins_with("talk_"):
		routed = _resolve_talk(r, ev, c, names)
	elif ev["id"] == "boss_visit":
		routed = _resolve_visit(r, ev, c, arg, names)
	elif ev["id"] == "boss_show":
		routed = _resolve_show(r, ev, c)
	elif ev["id"] == "intervene":
		routed = _resolve_intervene(r, ev, c)
	elif ev["id"] == "decline":
		routed = _resolve_decline(r, ev, c)
	elif ev["id"] == "interview":
		routed = _resolve_interview(r, ev, c)
	elif ev["id"] == "fire":
		routed = _resolve_fire(r, ev, c)
	if ev["id"].begins_with("talk_") or ev["id"] in ["boss_visit", "boss_show", "intervene", "decline", "interview", "fire"]:
		if routed != "":
			r.say(who, routed, [], names)
		for q in r.team:
			r.people[q]["mood"] = clampf(r.people[q]["mood"], -5.0, 5.0)
		return
	if ev.has("comp"):
		_resolve_complication(r, ev, c, t, names)
		who = ""
	if ev["id"] == "boss_details":
		r.weight_cause = t["id"]
	match ev["id"] + "/" + c:
		"boss_deadline/yes":
			t["vouched"] = true
		"boss_deadline/warn":
			t["due"] += 1
			r.weight_cause = t["id"]
			r.flags["warned_late"] = r.flags.get("warned_late", 0) + 1
			if r.flags["warned_late"] >= 2:
				r.boss -= 1
				reply = "event.boss_deadline.warn.reply_again"
			else:
				r.boss += 0.5

		"boss_dump/take":
			r.add_task(ev["dump"])
		"boss_dump/refuse":
			if r.has_weight():
				r.boss -= 1.0
			else:
				r.add_task(ev["dump"])
				reply = "event.boss_dump.refuse.weak_early" if r.day <= 5 else "event.boss_dump.refuse.weak"

		"boss_details/call_owner":
			r.boss -= 1
			r.people[t["owner"]]["mood"] += 1.0
			r.people[t["owner"]]["trust"] += 1
		"boss_details/improvise":
			if r.rng.randf() >= 0.4:
				r.boss -= 2
				reply = "event.boss_details.improvise.reply_bad"
		"boss_details/dodge":
			# She asks whoever did the work. If they resent you, they tell her.
			var owner: String = t["owner"]
			if r.people[owner]["trust"] < 0:
				r.boss -= 2
				r.say(owner, "event.boss_details.reveal." + owner, [], names)
				reply = "event.boss_details.dodge.reply_bad"
			else:
				r.people[owner]["mood"] -= 1.0
				r.say(owner, "event.boss_details.cover", [], names)

		"marina_warns/listen":
			r.people[ev["target"]]["mood"] += 1.5
			r.add_mgmt_hours(1)
		"marina_warns/dismiss":
			r.boss -= 1
			r.people[ev["target"]]["mood"] -= 1.0
			r.people[ev["target"]]["trust"] -= 1

		"vika_takes_task/give":
			var prev: String = t["owner"]
			if not r.team.has(prev) or t["status"] != "active":
				r.say("vika", reply, [], names)
				return
			t["owner"] = "vika"
			t["helper"] = "" if t["helper"] == "vika" else t["helper"]
			r.people["vika"]["mood"] += 1.0
			r.people["vika"]["ambition"] += 1
			var keen: bool = r.info(prev)["likes"].has(t["cat"])
			r.people[prev]["mood"] += -1.0 if keen else 0.5
			r.say(prev, "event.vika_takes_task.given_" + ("keen" if keen else "glad"), [], names)
		"vika_takes_task/refuse":
			r.people["vika"]["mood"] -= 1.0

		"gena_mentor/encourage":
			r.people["gena"]["mood"] += 1.5
			r.flags["gena_mentor"] = true
		"gena_mentor/work":
			r.people["gena"]["mood"] -= 1.0
			r.people["dima"]["mood"] -= 0.5

		"alex_offer/terms":
			r.people["alex"]["mood"] += 2.0
			r.flags["alex_terms"] = true
		"alex_offer/promise":
			r.make_promise("alex")
			r.people["alex"]["mood"] += 2.5
		"alex_offer/let_go":
			r.people["alex"]["mood"] -= 1.0
			r.flags["alex_leaving"] = r.day

		"vika_lie_found/sorry":
			r.flags["lied_vika"] = true
			r.people["vika"]["mood"] -= 2.5
			r.people["vika"]["trust"] -= 2
		"vika_lie_found/blame_boss":
			r.flags["lied_vika"] = true
			r.people["vika"]["mood"] -= 1.5
			r.people["vika"]["trust"] -= 1
			r.vika_up()

		"alex_vika_clash/both":
			r.people["alex"]["mood"] += 0.5
			r.people["alex"]["trust"] += 1
			r.people["vika"]["mood"] -= 0.5
		"alex_vika_clash/side_alex":
			r.people["alex"]["mood"] += 1.5
			r.people["alex"]["trust"] += 1
			r.people["vika"]["mood"] -= 2.0
			r.people["vika"]["trust"] -= 1
			r.vika_up()
		"alex_vika_clash/side_vika":
			r.people["vika"]["mood"] += 1.5
			r.people["vika"]["ambition"] += 1
			r.people["alex"]["mood"] -= 2.0
			r.people["alex"]["trust"] -= 1
			r.flags["no_pair_alex_vika"] = true
		"alex_vika_clash/stay_out":
			r.people["alex"]["mood"] -= 1.0
			r.people["vika"]["mood"] -= 1.0
			r.flags["no_pair_alex_vika"] = true

		"gena_forgot/first":
			t["first"] = true
			r.people["gena"]["mood"] -= 1.0
		"gena_forgot/take_back":
			r.unassign_now(t)
			r.people["gena"]["mood"] += 0.5
		"gena_forgot/myself":
			t["involved"] = true
			t["owner"] = "me"
			t["helper"] = ""
			t["first"] = true

		"dima_mistake/help":
			r.add_mgmt_hours(3)
			t["involved"] = true
			t["q_sum"] += 1.2 * t["q_days"]
			r.people["dima"]["mood"] += 1.0
			r.people["dima"]["trust"] += 1
			r.learn("dima", t["cat"], 2.0)
		"dima_mistake/redo":
			t["progress"] = maxf(0.0, t["progress"] - 0.5)
			t["q_sum"] += 0.6 * t["q_days"]
			r.people["dima"]["mood"] -= 1.0
			r.learn("dima", t["cat"], 1.5)
		"dima_mistake/ignore":
			t["flaw"] = true
			r.people["dima"]["mood"] += 0.5

		"vika_raise/promise":
			r.make_promise("vika")
			r.people["vika"]["mood"] += 2.0
		"vika_raise/not_yet":
			r.people["vika"]["mood"] -= 2.0
			r.vika_up()

		"vika_promise_check/lie":
			r.people["vika"]["mood"] += 1.0
			r.flags["vika_lied"] = r.day
		"vika_promise_check/honest":
			r.people["vika"]["mood"] -= 1.0
			r.people["vika"]["trust"] += 1
		"vika_promise_check/do_now":
			r.add_mgmt_hours(2)
			r.people["vika"]["promised"] = false
			r.people["vika"]["mood"] += 2.0
			r.people["vika"]["trust"] += 1
			r.vika_up()

		"alex_tired/dayoff":
			var st: Dictionary = r.people["alex"]
			st["absent"] = true
			st["absent_reason"] = "dayoff"
			st["energy"] = minf(r.stamina("alex"), st["energy"] + r.DAYOFF_REST)
			st["mood"] += 1.0
		"alex_tired/hold_on":
			r.people["alex"]["mood"] -= 1.0

		"dima_bored/pair_alex":
			var head: Dictionary = r.queue_of("alex")[0]
			head["helper"] = "dima"
			r.people["dima"]["mood"] += 1.5
			r.say("dima", reply)
			reply = "event.dima_bored.pair_alex.reply_alex"
			who = "alex"
		"dima_bored/wait":
			r.people["dima"]["mood"] -= 1.0
		"dima_bored/study":
			r.learn("dima", "pipelines", 2.0)
			r.people["dima"]["mood"] += 0.5
			r.say("dima", reply)
			reply = "event.dima_bored.study.reply_gena"
			who = "gena" if r.available("gena") else ""

		"taras_borrow/lend":
			var st: Dictionary = r.people[arg]
			st["absent"] = true
			st["absent_reason"] = "taras"
			st["mood"] += {"alex": 0.5, "vika": -0.5, "dima": 1.0, "gena": -1.5}[arg]
			r.learn(arg, "pipelines", 2.0)
			r.flags["taras_owes"] = true
			r.say(arg, "event.taras_borrow.lent." + arg)
		"taras_borrow/refuse":
			r.flags["taras_grudge"] = true

		"boris_drunk/take":
			_add_tagged(r, "boris_promise")
		"boris_drunk/irina":
			r.spend_attention()
			if r.has_weight():
				r.boss += r.boss_like("A", 0.3)
				reply = "event.boris_drunk.irina.ok"
				who = "boss"
			else:
				_add_tagged(r, "boris_promise")
				reply = "event.boris_drunk.irina.no"
				who = "boss"
		"boris_drunk/refuse":
			r.boss -= 0.5

		"friday_deploy/allow":
			if r.rng.randf() < 0.5:
				r.flags["weekend_fire"] = _strongest(r, "infra")
		"friday_deploy/forbid":
			r.flags["no_friday_deploys"] = true
		"friday_deploy/on_call":
			r.spend_attention()
			if r.rng.randf() < 0.25:
				r.flags["weekend_fire"] = "me"

		"weekend_fire/own":
			# You take it on yourself; whoever spent the weekend fixing it remembers.
			r.boss -= 0.3
			var fixer: String = r.flags.get("last_fixer", "")
			if r.team.has(fixer) and r.available(fixer):
				r.people[fixer]["trust"] += 1
		"weekend_fire/postmortem":
			for id in C.tasks_with("tag", "postmortem").slice(0, 1):
				r.add_task(id)
			r.boss += r.boss_like("A", 0.3)
		"weekend_fire/blame":
			r.boss += 0.2

		"chaos_meeting/all_go":
			r.flags["meeting_day"] = r.day
			r.boss += 0.3
			for q in r.team:
				if r.available(q):
					r.people[q]["mood"] -= 0.3
		"chaos_meeting/me_only":
			r.spend_attention()
			r.boss -= 0.2
		"chaos_meeting/later":
			r.boss -= 0.4
	for p in r.team:
		r.people[p]["mood"] = clampf(r.people[p]["mood"], -5.0, 5.0)
	if who != "":
		r.say(who, reply, [], names)
	if ev["id"] == "alex_vika_clash":
		r.say("vika", "event.alex_vika_clash.%s.reply_vika" % c)
