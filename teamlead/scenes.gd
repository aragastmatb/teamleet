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

const MAX_PER_MORNING := 2

# Checked in this order; the first MAX_PER_MORNING that fire are shown.
const ORDER := [
	"probation", "boss_dump", "boss_deadline", "boss_details", "complication", "marina_warns", "alex_offer", "vika_lie_found", "alex_vika_clash", "gena_forgot",
	"dima_mistake", "vika_raise", "vika_promise_check", "alex_tired", "dima_bored", "vika_takes_task", "gena_mentor", "taras_brag", "vika_rising", "taras_borrow",
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


func task_names(r, t: Dictionary) -> Dictionary:
	return {"task": "@taskname." + t["id"], "from": "@name.%s.nom" % t["from"], "owner": "@name.%s.nom" % t["owner"],
		"owner_gen": "@name.%s.gen" % t["owner"], "owner_acc": "@name.%s.acc" % t["owner"]}


# ---------- conditions ----------

# Irina checks on a public task that's clearly not going to make it.
func _check_boss_deadline(r) -> Dictionary:
	for t in r.tasks:
		if t["status"] != "active" or not t["public"] or t["asked"] or not C.TEAM.has(t["owner"]):
			continue
		var left: int = t["due"] - r.day
		if left < 1 or left > 2 or r.days_needed(t) <= left + 0.3:
			continue
		t["asked"] = true
		return {"who": "boss", "uid": t["uid"], "names": task_names(r, t),
			"lines": [{"who": "boss", "key": "event.boss_deadline.ask"}], "choices": ["yes", "warn"]}
	return {}


# Day one: Irina explains the probation and names the key projects.
func _check_probation(r) -> Dictionary:
	if r.day != 1 or not once(r, "probation"):
		return {}
	var names := {}
	for i in C.KEY_PROJECTS.size():
		names["k%d" % (i + 1)] = "@taskname." + C.KEY_PROJECTS[i]
	return {"who": "boss", "names": names, "lines": [{"who": "boss", "key": "event.probation.ask"}, {"who": "boss", "key": "event.probation.ask2"}],
		"choices": ["ok"]}


# Irina drops something urgent on you. Day 2 the first time (you can't refuse yet), then now and
# then when the team is loaded, at most once a week.
func _check_boss_dump(r) -> Dictionary:
	var first: bool = r.day == 2 and not r.flags.has("dump_w0")
	var load := 0
	for t in r.tasks:
		if t["status"] == "active" and C.TEAM.has(t["owner"]):
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
		if t["status"] != "active" or t["complicated"] or not C.TEAM.has(t["owner"]) or not here(r, t["owner"]):
			continue
		if t["progress"] < 0.2 * t["size"] or t["size"] - t["progress"] < 0.6:
			continue
		candidates.append(t)
	candidates.shuffle()
	for t in candidates:
		if r.rng.randf() > 0.35:
			continue
		var options: Array = []
		for cid in C.COMPLICATIONS:
			var c: Dictionary = C.COMPLICATIONS[cid]
			if c["cats"].has(t["cat"]):
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
	for p in C.TEAM:
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
		if t["status"] == "active" and t["public"] and t["progress"] == 0.0 and C.TEAM.has(t["owner"]) and t["owner"] != "vika":
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
	if r.day < 3 or r.day > C.DAYS - 3 or r.flags.has("scene_taras_borrow"):
		return {}
	if r.day < 12 and r.rng.randf() > 0.15:
		return {}
	var choices := []
	for p in C.TEAM:
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
	if not C.TEAM.has(p) or t["status"] != "active":
		return
	var reply := "event.comp_%s.%s.reply" % [cid, c]
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
		r.add_my_hours(fx["hours"])
		t["involved"] = true
	if fx.has("learn"):
		r.learn(p, t["cat"], fx["learn"])
	r.people[p]["mood"] += fx.get("mood", 0.0)
	r.people[p]["energy"] += fx.get("energy", 0.0)
	r.boss += fx.get("boss", 0.0)
	if fx.has("boss") or fx.get("special", "") in ["please_from", "annoy_from"]:
		r.weight_cause = t["id"]
	r.say(who, reply, [], names)


func resolve(r, ev: Dictionary, choice: String) -> void:
	var parts := choice.split(":")
	var c: String = parts[0]
	var arg: String = parts[1] if parts.size() > 1 else ""
	var t: Dictionary = r.task(ev["uid"]) if ev["uid"] >= 0 else {}
	var names: Dictionary = ev["names"].duplicate()
	if arg != "":
		names["who"] = "@name.%s.acc" % arg
	r.history.append({"who": "you", "key": "event.%s.choice.%s" % [ev["id"], c], "args": [], "names": names, "day": r.day})
	var who: String = ev["who"]
	var reply := "event.%s.%s.reply" % [ev["id"], c]
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
			r.add_my_hours(1)
		"marina_warns/dismiss":
			r.boss -= 1
			r.people[ev["target"]]["mood"] -= 1.0
			r.people[ev["target"]]["trust"] -= 1

		"vika_takes_task/give":
			var prev: String = t["owner"]
			if not C.TEAM.has(prev) or t["status"] != "active":
				r.say("vika", reply, [], names)
				return
			t["owner"] = "vika"
			t["helper"] = "" if t["helper"] == "vika" else t["helper"]
			r.people["vika"]["mood"] += 1.0
			r.people["vika"]["ambition"] += 1
			var keen: bool = C.PEOPLE[prev]["likes"].has(t["cat"])
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
			r.add_my_hours(3)
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
			r.add_my_hours(2)
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
			r.learn("dima", "tech", 2.0)
			r.people["dima"]["mood"] += 0.5
			r.say("dima", reply)
			reply = "event.dima_bored.study.reply_gena"
			who = "gena" if r.available("gena") else ""

		"taras_borrow/lend":
			var st: Dictionary = r.people[arg]
			st["absent"] = true
			st["absent_reason"] = "taras"
			st["mood"] += {"alex": 0.5, "vika": -0.5, "dima": 1.0, "gena": -1.5}[arg]
			r.learn(arg, "tech", 2.0)
			r.flags["taras_owes"] = true
			r.say(arg, "event.taras_borrow.lent." + arg)
		"taras_borrow/refuse":
			r.flags["taras_grudge"] = true
	for p in C.TEAM:
		r.people[p]["mood"] = clampf(r.people[p]["mood"], -5.0, 5.0)
	if who != "":
		r.say(who, reply, [], names)
	if ev["id"] == "alex_vika_clash":
		r.say("vika", "event.alex_vika_clash.%s.reply_vika" % c)
