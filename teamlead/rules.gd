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
const Dialogue = preload("res://teamlead/dialogue.gd")

const SPEED_BASE := 0.65
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
# "story": the four chapters with the team and the scenes. "endless": the tycoon, a made-up team and
# period after period of PERIOD_DAYS on one common deck (C.ENDLESS_DECK). A period closes with the budget
# split; the run ends on running out of money, the team or yourself (see _bankrupt). No named teammates
# and no story scenes there.
var mode := "story"
var period := 1
var period_start := 1
# Endless run: the money you have, in thousands of roubles. Irina's budget comes in at the start of each
# period, salaries go out every Friday; not enough for them, and the run is over.
var money := 0
# Before the first day: the CVs you're choosing the team from, and who you've picked.
var draft_picked: Array = []
# Taras's department this period: what it has delivered so far and what it's on course for. Who delivers
# more gets the bigger share of next month's budget (see _split_budget).
var taras_points := 0.0
var taras_target := 0.0
# Last period's race, for the summary: {"mine", "taras", "budget"}.
var last_race := {}
var phase := "title" # plan, event, evening, report, review, end
var people := {}
# Everyone who has been on the team this run, the first four and those hired since; people[p]["gone"]
# marks who has left (quit or let go). hires[p]: the made-up person behind a hire (see info()).
var team: Array = []
var hires := {}
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
# Improvements to Chainer that are done: id -> the day.
var improved := {}
# The banks with us: id -> {"mood": how they feel about us, "since": day}. Reputation: how the platform's
# deliveries have gone lately; it makes the next sale come sooner.
var banks := {}
var reputation := 0.0
var comp_off := {}
# Your attention: the day's points for managing. Spend past them and you're borrowing from tomorrow
# (overtime_today, up to borrow_cap()); in the endless run hitting the cap ends the day for you.
# The weekend clears the debt; start too many days in a row in debt and you burn out.
var attention := 0
var overtime_today := 0
# The endless run's day comes in steps: "triage" (the morning: hand out and turn down work), "work"
# (the middle of the day: step in where it's needed), then the evening after end_day.
var step := "triage"
# Where the game goes once the open events are answered: back to the board, or on to the evening.
var after_events := "plan"
# The endless run's questions don't stop the day: they come as messages and wait in the messenger.
# Unanswered by the end of the day (by the next morning for the evening's), they settle as if you said nothing.
var letters: Array = []
# Incidents that break out in the middle of the day.
var arriving_midday: Array = []
# Cards missed deadlines have put into the deck for good (the endless run's curses).
var curses: Array = []
# The endless run's upgrade tree (C.UPGRADES): id -> {"state": "building"|"done", "done": [card ids]},
# the effects you have from it, and the upkeep cards finished upgrades keep in the deck.
var upgrades := {}
var perks: Array = []
var upkeep: Array = []
var debt := 0
var debt_days := 0
var my_sick := 0
# A late night (a scene says so): tomorrow you have this much less attention.
var my_hangover := 0
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
# A story conversation under way (data/dialogues): {"id", "pos", "wait": "line"/"choice", "log": [{"who", "emo", "ru", "en"}]}.
var story := {}
var standup := {} # this morning's stand-up: {"lines": [...], "reacted": n}, see _open_standup
# The morning's cards, held back until the morning scenes are answered.
var arriving: Array = []
var review: Array[Dictionary] = []
var flags := {}
var ending := ""
var evening_from := 0
# Where the day started, for the evening's summary: money, race points, points to spend.
var day_start := {}
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
# Marina's first-steps tips in the chat (see update_tips).
var tips := true


# ---------- run and day flow ----------

func start_run(seed_value: int = -1, boss_kind: String = C.DEFAULT_BOSS, profile_kind: String = C.DEFAULT_PROFILE, run_mode: String = "story") -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	mode = run_mode
	day = 1
	chapter = 1
	period = 1
	period_start = 1
	people.clear()
	hires.clear()
	candidates.clear()
	openings = 0
	next_hire = 1
	L.EXTRA = {"ru": {}, "en": {}}
	L.STAND_IN = {}
	if endless():
		team = []
		money = START_MONEY
		draft_picked.clear()
		last_race = {}
		for i in DRAFT_SIZE:
			_draft_add()
	else:
		team = C.TEAM.duplicate()
		for p in team:
			_new_person(p, true)
	tasks.clear()
	comp_off.clear()
	flags.clear()
	deck.clear()
	seen_day.clear()
	chain_due.clear()
	improved.clear()
	banks.clear()
	for b in C.START_BANKS:
		banks[b] = {"mood": 0.0, "since": 1}
	reputation = 0.0
	_refill_deck()
	debt = 0
	debt_days = 0
	my_sick = 0
	my_hangover = 0
	init_next.clear()
	boss_type = boss_kind
	profile = profile_kind
	if C.PROFILES[profile].get("knows_team", false):
		for p in team:
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
	letters.clear()
	review.clear()
	pending = {}
	lies.clear()
	flags.clear()
	history.clear()
	ending = ""
	_fill_backlog()
	if endless():
		phase = "draft"
		return
	_start_day()


func _start_day() -> void:
	_narrate("log.morning", [day_key()])
	for t in tasks:
		t["gain_today"] = 0.0
	var monday := day % 5 == 1 and day > 1
	if monday:
		debt = 0
		debt_days = 0
	for p in team:
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
		elif archetype(p) == "life_first" and day - st["joined"] > 1 and rng.randf() < LIFE_AWAY * (0.4 if warned(p) else 1.0):
			st["absent"] = true
			st["absent_reason"] = "life"
			_say(p, "absent.life.%d" % rng.randi_range(1, 5))
	# A genius on the team: Irina loves them, everyone else gets a little greyer each day.
	for g in team:
		if archetype(g) == "genius" and available(g) and not people[g]["absent"]:
			for p in team:
				if p != g and available(p):
					people[p]["mood"] = clampf(people[p]["mood"] - GENIUS_GLOOM, -5.0, 5.0)
	# Today's cards come in once the morning's questions are answered, so the chat reads in order.
	arriving = _arrivals()
	talked.clear()
	offer_today.clear()
	for p in team:
		if day > 1 and available(p) and not people[p]["absent"] and _wants_to_volunteer(p):
			offer_today[p] = true
	visited_today = false
	overtime_today = 0
	day_start = {"money": money, "race": my_points() if endless() else 0.0, "taras": taras_total() if endless() else 0.0}
	step = "triage"
	after_events = "plan"
	attention = 0 if my_sick > 0 else maxi(0, max_attention() - debt)
	debt = 0
	sick_today = my_sick > 0
	if my_sick > 0:
		my_sick -= 1
	elif not queue_of("me").is_empty():
		# Doing a task yourself takes a good part of your day.
		attention = maxi(0, attention - own_task_cost())
	attention = maxi(0, attention - my_hangover)
	my_hangover = 0
	# A story conversation comes first, on its own screen; the morning's chat waits for it.
	_queue_story()
	if story.is_empty():
		_open_morning()


func _open_morning() -> void:
	# In the endless run the cards are on the table before the stand-up, so people can grab some.
	if endless() and step == "triage" and flags.get("delivered_day", -1) != day:
		_deliver_arrivals()
		_team_pulls()
	if _open_standup():
		return
	_queue_events()
	if endless():
		_post_letters()
	if events.is_empty():
		_deliver_arrivals()
		phase = "plan"
	else:
		phase = "event"


func _deliver_arrivals() -> void:
	if step == "work":
		for id in arriving_midday:
			add_task(id)
			tasks[-1]["midday"] = day
		arriving_midday = []
		return
	if flags.get("delivered_day", -1) == day:
		return
	flags["delivered_day"] = day
	_maybe_sell()
	_layoff_rush()
	_hiring_morning()
	if flags.get("auto_today", 0) > 0:
		_narrate("up.auto", [flags["auto_today"]])
		flags["auto_today"] = 0
	for id in arriving:
		if endless() and C.TASKS[id]["tags"].has("incident"):
			arriving_midday.append(id)
		else:
			add_task(id)
	arriving = []


# ---------- initiative ----------

# How readily someone grabs work without being asked, hidden: you only see who takes what.
# Praise feeds it, taking a card back crushes it, and the others on the call notice.
const PULL_BASE := {"solid": 0.35, "junior": 0.5, "faker": 0.4, "stump": 0.05, "life_first": 0.1, "genius": 0.45}
const PULL_PRAISE := 0.12
const PULL_SCOLD := -0.3
const PULL_FEAR := -0.06
const PULL_SILENCE := 0.02
const PULL_MAX := 0.75
const PULL_SETTLE := 0.08 # each morning it drifts this share of the way back to the person's nature
const PULL_FLOOR := 0.1 # below this they don't take anything, even when you're not there
const PULL_ALONE := 1.5 # on a day without you everyone's keener


func pull(p: String) -> float:
	return people[p].get("pull", _pull_nature(p))


func _pull_nature(p: String) -> float:
	return PULL_BASE.get(archetype(p), 0.3) + perk_add("initiative")


func _nudge_pull(p: String, by: float) -> void:
	people[p]["pull"] = clampf(pull(p) + by, 0.0, PULL_MAX)


# Which waiting card this person would grab, by their kind: the strong take what they're good at, the
# keen beginner takes the biggest, the faker and the ones who'd rather not take the smallest.
func _pull_choice(p: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for t in inbox():
		if t.get("midday", -1) == day or only_me(t):
			continue
		var skill: int = people[p]["skills"][t["cat"]]
		var score: float
		match archetype(p):
			"genius":
				score = skill * 2.0 + t["size"]
			"junior":
				score = t["size"] * 2.0 + (1.0 if t["key"] else 0.0)
			"faker", "stump", "life_first":
				score = -t["size"]
			_:
				score = skill * 2.0 + (1.0 if info(p)["likes"].has(t["cat"]) else 0.0)
		score += rng.randf() * 0.5
		if score > best_score:
			best = t
			best_score = score
	return best


func _take(p: String, t: Dictionary) -> void:
	t["owner"] = p
	t["status"] = "active"
	t["assigned_day"] = day
	t["first"] = false
	t["pulled"] = day


func _will_pull(p: String, keen: float) -> bool:
	if not available(p) or people[p]["absent"] or pull(p) < PULL_FLOOR:
		return false
	var load := queue_of(p).size()
	var chance := pull(p) * keen * (1.0 if load == 0 else (0.5 if load == 1 else 0.0))
	return rng.randf() < chance


# The morning: before the stand-up, whoever feels like it takes a card for themselves.
func _team_pulls() -> void:
	if day == 1:
		return
	for p in team:
		if available(p):
			_nudge_pull(p, (_pull_nature(p) - pull(p)) * PULL_SETTLE)
	var pulled := 0
	for p in team:
		if _will_pull(p, 1.0):
			var t := _pull_choice(p)
			if not t.is_empty():
				_take(p, t)
				pulled += 1
	if pulled >= 3:
		flags["self_org"] = true


# A day without you: the team shares out the waiting cards among themselves, each as they see fit.
# Those who've learned not to take anything leave theirs where it is.
func _team_picks() -> void:
	var order: Array = team.filter(func(p): return available(p))
	order.sort_custom(func(a, b): return pull(a) > pull(b))
	for _pass in 2:
		for p in order:
			if inbox().is_empty():
				return
			if _will_pull(p, PULL_ALONE):
				var t := _pull_choice(p)
				if not t.is_empty():
					_take(p, t)
					_say(p, _own_key("pulled.alone", p), [], {"task": "@taskname." + t["id"]})


# The endless run's actions belong to steps of the day; the story lets you do anything on the board.
const TRIAGE_ACTIONS := ["assign", "decline", "prioritize", "unassign", "react", "initiative"]
const WORK_ACTIONS := ["sit", "intervene", "pair", "talk", "stay"]


func allowed(kind: String) -> bool:
	if not endless():
		return true
	if kind in TRIAGE_ACTIONS:
		return step == "triage"
	if kind in WORK_ACTIONS:
		return step == "work"
	return true


# Can this card be handed out now? In the middle of the day only what broke out since the morning.
func can_assign(t: Dictionary) -> bool:
	return allowed("assign") or (step == "work" and t.get("midday", -1) == day)


# The morning's done: half the day goes by, and what came up in it shows.
func start_work() -> void:
	if not endless() or phase != "plan" or step != "triage" or not pending.is_empty():
		return
	step = "work"
	flags.erase("tip_hl")
	_half_day()
	_narrate("log.midday")
	scenes.queue(self, "midday")
	if endless():
		_post_letters()
	_say_event_lines()
	if events.is_empty():
		_deliver_arrivals()
	else:
		phase = "event"


# This morning's work: the weekly report on Mondays (unless automated), key projects on their days,
# and a few cards from the deck — no more than two of one kind on one day.
func _arrivals() -> Array:
	var out: Array = []
	if day % 5 == 1 and not flags.has("automated_report"):
		out.append_array(C.tasks_with("kind", "weekly"))
	# The endless run has no key projects and no story chains, only the deck.
	var keys: Dictionary = {} if endless() else C.KEY_DAYS.get(chapter, {})
	if keys.has(chapter_day()):
		out.append(keys[chapter_day()])
	for id in ({} if endless() else C.START_DAYS.get(chapter, {})).get(chapter_day(), []):
		# A chain that only starts if something hasn't happened yet (unless:<flag>).
		if not C.TASKS[id]["tags"].any(func(tag): return tag.begins_with("unless:") and flags.has(tag.substr(7))):
			out.append(id)
	for due in chain_due.duplicate():
		if due["day"] <= day:
			chain_due.erase(due)
			out.append(due["id"])
	var load := 0.0
	for id in out:
		load += C.TASKS[id]["size"]
	# More banks than chapter one's three bring more work.
	var ramp := ramp_now()
	var target: float = C.DAILY_LOAD * ramp["load"] * (RUSH_LOAD if flags.has("rush") else 1.0) + C.BANK_LOAD * maxi(0, banks.size() - 3)
	if endless():
		target = C.DAILY_LOAD * ramp["load"] + BANK_WORK * extra_banks()
	if flags.get("relief", false):
		flags["relief"] = false
		target -= 1.5
	var cards: int = ramp["cards"] + (RUSH_CARDS if flags.has("rush") else 0)
	while load < target and out.size() < cards:
		if deck.size() < 4:
			_refill_deck()
		var picked := -1
		var i := 0
		while i < deck.size():
			# What the upgrades now take care of goes by without reaching anyone, and counts as done.
			if endless() and _bank_here(deck[i]) and _automated(deck[i]):
				var gone: String = deck.pop_at(i)
				_automation_credit(gone)
				load += C.TASKS[gone]["size"]
				if load >= target:
					break
				continue
			var info: Dictionary = C.TASKS[deck[i]]
			var same := 0
			for id in out:
				if C.TASKS[id]["cat"] == info["cat"]:
					same += 1
			if same < C.MAX_SAME_KIND and (endless() or day + info["size"] - 1 <= last_day()) and _can_come_again(deck[i]) and not out.has(deck[i]) and _improved_by("remove", deck[i]).is_empty() and _bank_here(deck[i]):
				picked = i
				break
			i += 1
		if picked < 0:
			break
		var id: String = deck.pop_at(picked)
		out.append(id)
		load += C.TASKS[id]["size"]
	return out


# How hard this week of the chapter pushes (C.RAMP): past the listed weeks, full load.
func ramp_now() -> Dictionary:
	if endless():
		return endless_ramp()
	var weeks: Array = C.RAMP.get(chapter, C.RAMP[0])
	var w := (chapter_day() - 1) / 5
	return weeks[w] if w < weeks.size() else {"load": 1.0, "cards": C.MAX_CARDS_A_DAY, "slack": 0}


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
# Array.shuffle() draws from the global generator; this one keeps a seeded run repeatable.
func shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp


# The endless run's load: a made-up team is weaker than the story's, so it starts lighter, eases in over
# the first week and then grows a little every period, so that sooner or later something gives.
const ENDLESS_LOAD := 0.65
const ENDLESS_LOAD_GROWTH := 0.15 # a period
const ENDLESS_LOAD_MAX := 3.0
const ENDLESS_CARDS := 3 # a day at first, one more every ENDLESS_CARDS_EVERY periods, up to ENDLESS_CARDS_MAX
const ENDLESS_CARDS_EVERY := 1
const ENDLESS_CARDS_MAX := 9


func endless_ramp() -> Dictionary:
	if period == 1 and chapter_day() <= 5:
		return {"load": ENDLESS_LOAD * 0.8, "cards": 3, "slack": 2}
	var load := minf(ENDLESS_LOAD_MAX, ENDLESS_LOAD * (1.0 + ENDLESS_LOAD_GROWTH * (period - 1)))
	return {"load": load, "cards": mini(ENDLESS_CARDS_MAX, ENDLESS_CARDS + (period - 1) / ENDLESS_CARDS_EVERY), "slack": 1}


func deck_source() -> Array:
	return C.ENDLESS_DECK if endless() else C.DECK.get(chapter, [])


func _refill_deck() -> void:
	var fresh: Array = deck_source().duplicate()
	if flags.has("tech_debt_done"):
		fresh = fresh.filter(func(id): return not C.TASKS[id]["tags"].has("debt"))
	fresh.append_array(curses)
	fresh.append_array(upkeep)
	# (in the endless run removed cards stay in: drawn, they count as done by the upgrades)
	fresh = fresh.filter(func(id): return (endless() or _improved_by("remove", id).is_empty()) and _bank_here(id))
	for i in range(fresh.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = fresh[i]
		fresh[i] = fresh[j]
		fresh[j] = tmp
	deck.append_array(fresh)


func add_task(id: String) -> void:
	var info: Dictionary = C.TASKS[id]
	if info["tags"].has("joins"):
		_join_bank(info["bank"])

	# What the teams can now do through the portal, they do; it only shows in the chat.
	if not _improved_by("self", id).is_empty():
		seen_day[id] = day
		seen_day[info["tpl"]] = day
		_narrate("imp.self", [], {"who": "@name.%s.gen" % info["from"], "task": "@taskname." + id})
		if endless():
			_automation_credit(id)
		return
	var size: float = info["size"] * flags.get("shrink:" + id, 1.0)
	for imp in _improved_by("shrink", id):
		if imp == "perk":
			continue
		for e in C.IMPROVEMENTS[imp]["effects"]:
			if e["kind"] == "shrink":
				size *= e["factor"]
	for e in perks:
		if e["kind"] == "shrink" and e["targets"].any(func(target): return C.covers(target, id)):
			size *= e["value"]
	# Near the end of the probation, deadlines squeeze into what's left of it.
	var due: int = day + info["due"] + ramp_now()["slack"]
	if endless():
		due += int(perk_add("due", info["cat"]))
	else:
		due = mini(due, last_day())
	add_task_raw(id, info["cat"], maxf(0.5, size), due, info["public"], info["from"])
	_say(info["from"], "task.%s.ask" % id)


# ---------- people ----------

const NEWBIE_DAYS := 5 # a hire works at half speed this long, unless someone who knows the work pairs up
const FAKER_PACE := 0.35 # how fast a faker really works, whatever they say
const LIFE_AWAY := 0.15 # a life-first hire's chance of being away on any given day
const GENIUS_GLOOM := 0.15 # how much a genius sinks everyone else's mood a day
const CANDIDATE_DAYS := 5 # how long a candidate waits for an answer
const MAX_CANDIDATES := 3


# What someone is like: the four from content.gd, or a hire made up at hiring time (same keys).
func info(p: String) -> Dictionary:
	return hires[p] if hires.has(p) else C.PEOPLE[p]


func archetype(p: String) -> String:
	return info(p).get("arch", "")


func _new_person(p: String, jitter: bool) -> void:
	var base: Dictionary = info(p)
	var skills := {}
	var xp := {}
	for cat in C.CATEGORIES:
		skills[cat] = clampi(base["skills"][cat] + (rng.randi_range(-1, 1) if jitter else 0), 0, 4)
		xp[cat] = 0.0
	people[p] = {
		"skills": skills, "xp": xp, "energy": float(base["stamina"]), "mood": 1.0, "trust": 0,
		"sick": 0, "absent": false, "absent_reason": "", "off_next": false, "pushed": 0, "promised": false, "ambition": 0,
		"gone": false, "known": {}, "warned_mood": false, "warned_tired": false,
		"last_done": -10, "idle_said": false, "idle_days": 0, "promised_day": 0,
		"week_hours": _zeros(), "week_overtime": _zeros(), "week_extra": _zeros(), "week_absent": _zeros(), "week_done": _zeros(), "debts": 0, "caught_flattery": false, "done_cats": {}, "start": skills.duplicate(),
		"joined": day if hires.has(p) else -100,
	}


# ---------- hiring ----------

# Openings Irina has given and not yet filled; candidates Marina has sent: [{"id", "until", "asked", "known"}].
var openings := 0
var candidates: Array = []
var next_hire := 1


# A made-up person: a name nobody on the team has yet, an archetype, and what that makes them.
func _new_candidate() -> void:
	var id := _roll_hire()
	candidates.append({"id": id, "until": day + CANDIDATE_DAYS, "asked": [], "known": {}})
	_say("marina", "hire.cv", [], {"who": "@name.%s.nom" % id})


func _roll_hire() -> String:
	var id := "hire%d" % next_hire
	next_hire += 1
	var used := hires.values().map(func(h): return h["name"])
	var names: Array = range(C.HIRE_NAMES.size()).filter(func(i): return not used.has(i))
	if names.is_empty():
		names = range(C.HIRE_NAMES.size())
	var total := 0
	for a in C.ARCHETYPES:
		total += C.ARCHETYPES[a]["weight"]
	var roll := rng.randi_range(1, total)
	var arch := "solid"
	for a in C.ARCHETYPES:
		roll -= C.ARCHETYPES[a]["weight"]
		if roll <= 0:
			arch = a
			break
	var cats: Array = C.CATEGORIES.duplicate()
	for i in range(cats.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cats[i]
		cats[i] = cats[j]
		cats[j] = tmp
	# Real skills by archetype; the CV says what they'd like you to think.
	var levels: Array = {"solid": [3, 2, 1, 1], "junior": [2, 1, 1, 0], "faker": [1, 1, 1, 0], "stump": [2, 1, 1, 1],
		"life_first": [3, 3, 1, 1], "genius": [4, 4, 3, 1]}[arch]
	var skills := {}
	var cv := {}
	for i in cats.size():
		skills[cats[i]] = levels[i]
		cv[cats[i]] = 3 if arch == "faker" and i < 2 else levels[i]
	var drives: Array = {"solid": ["craft", "growth", "peace", "visibility"], "junior": ["growth"], "faker": ["visibility"], "stump": ["peace"],
		"life_first": ["peace", "craft"], "genius": ["craft", "visibility"]}[arch]
	hires[id] = {
		"name": names[rng.randi() % names.size()], "arch": arch, "skills": skills, "cv": cv,
		"drive": drives[rng.randi() % drives.size()], "likes": [cats[0]], "hates": [cats[3]] if arch != "stump" else [],
		"idle": 0.0 if arch == "stump" else -0.3, "stamina": 10 if arch == "life_first" else 8,
		"paei": C.PAEI[rng.randi() % 4], "rest_at": 0.4, "initiative": 0.0 if arch in ["stump", "faker"] else 0.4,
		"fast_learner": arch == "junior", "touchy": arch == "genius",
	}
	_register_hire(id)
	return id


# Palych: the one candidate who isn't made up. Kind, keen, slow, and without a check halfway through he
# brings back something other than what was asked. Chapter two's first candidate (docs/characters.md).
const PALYCH := {
	"name": -1, "arch": "plodder", "skills": {"pipelines": 2, "infra": 2, "portal": 1, "support": 1},
	"cv": {"pipelines": 2, "infra": 2, "portal": 1, "support": 1}, "drive": "peace", "likes": ["support"], "hates": [],
	"idle": -0.5, "stamina": 7, "paei": "I", "rest_at": 0.3, "initiative": 0.7, "fast_learner": false, "touchy": false,
}
const PLODDER_PACE := 0.75
const PLODDER_WARMTH := 0.1 # mood a day for everyone else while he's around


func _new_palych() -> void:
	flags["palych_sent"] = true
	hires["palych"] = PALYCH.duplicate(true)
	_register_hire("palych")
	candidates.append({"id": "palych", "until": day + CANDIDATE_DAYS + 2, "asked": [], "known": {}})
	_say("marina", "hire.cv", [], {"who": "@name.palych.nom"})


# A hire's name in every case, and whose lines they borrow (their archetype's, then any hire's).
func _register_hire(id: String) -> void:
	L.STAND_IN[id] = ["hire_" + hires[id]["arch"], "hire"]
	if hires[id]["name"] < 0:
		return # a named character: their names are in locale.gd
	var n: Dictionary = C.HIRE_NAMES[hires[id]["name"]]
	if n.get("f", false):
		L.FEMALE[id] = true
	else:
		L.FEMALE.erase(id)
	var cases := ["nom", "gen", "dat", "acc", "ins"]
	for i in cases.size():
		L.EXTRA["ru"]["name.%s.%s" % [id, cases[i]]] = n["ru"][i]
		L.EXTRA["en"]["name.%s.%s" % [id, cases[i]]] = n["en"] + ("'s" if cases[i] == "gen" else "")


# Each morning: candidates who waited too long take another offer, and Marina sends more while there are openings.
func _hiring_morning() -> void:
	if flags.get("openings_said", 0) < openings:
		flags["openings_said"] = openings
		_say("boss", "hire.openings", [openings])
	for c in candidates.duplicate():
		if c["until"] < day:
			candidates.erase(c)
			_narrate("hire.gone", [], {"who": "@name.%s.nom" % c["id"]})
	if openings > 0 and candidates.size() < MAX_CANDIDATES and not flags.has("palych_sent") and not endless():
		_new_palych()
	elif openings > 0 and candidates.size() < MAX_CANDIDATES and (candidates.is_empty() or day % 2 == 0):
		_new_candidate()
	elif endless() and candidates.size() < MAX_CANDIDATES and day % CANDIDATE_EVERY == 0:
		_new_candidate()


func candidate(id: String) -> Dictionary:
	for c in candidates:
		if c["id"] == id:
			return c
	return {}


# ---------- conversations ----------
# A sitting with someone in the conversation window: you pick what to ask, they answer from what's really
# going on with them, and the window shows it all as one conversation. convo is {"who", "kind", "left",
# "log": [{"who", "key", "names"}]}; while it's open, the window is over everything else.
var convo := {}

# An interview is one kind: one attention a sitting (Palych's first, straight after Marina brings him in,
# is free), three questions out of seven a sitting, and you can call them back once for three more.
const INTERVIEW_QUESTIONS := 3
const INTERVIEW_SITTINGS := 2


func _convo_line(who: String, key: String, names: Dictionary = {}) -> void:
	var said := names.duplicate()
	said["_by"] = who
	convo["log"].append({"who": who, "key": key, "names": said})


func convo_choices() -> Array:
	if convo.is_empty():
		return []
	var out: Array = []
	if convo["kind"] == "interview" and convo["left"] > 0:
		out = interview_topics(convo["who"])
	elif convo["kind"] == "talk":
		out = _talk_choices()
	out.append("end")
	return out


# What a choice in the window says.
func convo_label(c: String) -> String:
	if c == "end":
		var over: bool = convo.get("done", false) or convo.get("shut", false) or convo["left"] <= 0
		return L.t("convo.choice.end.%s%s" % [convo["kind"], ".over" if over and convo["kind"] == "talk" else ""])
	if convo["kind"] == "talk":
		var item := _talk_item(c)
		return L.fill(item["ru"], item["en"], convo["names"])
	return L.t("event.interview.choice." + c)


func convo_choose(choice: String) -> void:
	if not choice in convo_choices():
		return
	if choice != "end" and convo["kind"] == "talk":
		if not can_afford(cost("reply")):
			return
		spend_attention(cost("reply"))
	if choice == "end":
		_convo_close()
	elif convo["kind"] == "interview":
		_interview_ask(choice)
	elif convo["kind"] == "talk":
		_talk_choose(choice)


func _convo_close() -> void:
	var who: String = convo["who"]
	if not convo.get("done", false) and not convo.get("shut", false):
		_convo_line("you", "convo.end." + convo["kind"])
	# A talk stays in the conversation with them, line by line.
	if convo["kind"] == "talk":
		for e in convo["log"]:
			var line := {"who": e["who"], "key": e.get("key", "convo.line"), "args": [], "names": e.get("names", {}), "thread": who, "day": day}
			if e.has("ru"):
				line["ru"] = e["ru"]
				line["en"] = e["en"]
			history.append(line)
	history.append({"who": "", "key": "convo.log." + convo["kind"], "args": [], "names": {"who": "@name.%s.ins" % who}, "thread": who, "day": day})
	convo = {}


func interview_topics(id: String) -> Array:
	var c := candidate(id)
	if c.is_empty():
		return []
	return C.INTERVIEW_TOPICS.filter(func(x): return not c["asked"].has(x))


func can_interview(id: String) -> bool:
	var c := candidate(id)
	return phase == "plan" and pending.is_empty() and convo.is_empty() and not c.is_empty() \
		and c.get("sittings", 0) < INTERVIEW_SITTINGS and not interview_topics(id).is_empty()


func interview(id: String, free: bool = false) -> void:
	var c := candidate(id)
	if c.is_empty() or (not free and not can_interview(id)):
		return
	if not free:
		spend_attention(cost("interview"))
	lead("I", 0.2)
	c["sittings"] = c.get("sittings", 0) + 1
	convo = {"who": id, "kind": "interview", "left": INTERVIEW_QUESTIONS, "log": []}
	_convo_line(id, "hire.interview.hello" if c["asked"].is_empty() else "hire.interview.again")


# What a question gives away. Talk is cheap: a faker talks up their CV, and only the task on the spot
# shows anyone's real level.
func _interview_ask(topic: String) -> void:
	var id: String = convo["who"]
	var c := candidate(id)
	var h: Dictionary = hires[id]
	var arch: String = h["arch"]
	c["asked"].append(topic)
	convo["left"] -= 1
	_convo_line("you", "event.interview.choice." + topic)
	var who := {"who": "@name.%s.nom" % id}
	match topic:
		"tech":
			# They talk about the strongest thing on their CV that hasn't been checked yet.
			var best := ""
			for cat in C.CATEGORIES:
				if not c["known"].has(cat) and (best == "" or h["cv"][cat] > h["cv"][best]):
					best = cat
			if best == "":
				best = C.CATEGORIES[0]
			var lvl: int = h["cv"][best] if arch == "faker" else h["skills"][best]
			_convo_line(id, "hire.answer.tech.%d" % clampi(lvl, 0, 4), {"cat": "@cat." + best})
			if arch != "faker":
				c["known"][best] = true
		"task":
			# The category their CV is proudest of that nobody has checked yet.
			var pick := ""
			for cat in C.CATEGORIES:
				if not c["known"].has(cat) and (pick == "" or h["cv"][cat] > h["cv"][pick]):
					pick = cat
			if pick == "":
				pick = C.CATEGORIES[0]
			var lvl: int = h["skills"][pick]
			_convo_line(id, "hire.answer.task." + id, {"cat": "@cat." + pick})
			_convo_line("", "hire.task.%d" % clampi(lvl, 0, 4), who.merged({"cat": "@cat." + pick}))
			c["known"][pick] = true
		"drive":
			_convo_line(id, _first_key(["hire.answer.drive." + id, "hire.answer.drive." + h["drive"]]))
			c["drive_known"] = true
		"not_want":
			var hates: Array = h["hates"]
			if hates.is_empty() or arch == "faker":
				_convo_line(id, "hire.answer.not_want." + id)
			else:
				_convo_line(id, "hire.answer.not_want.any", {"cat": "@cat." + hates[0]})
				c["hates_known"] = true
		_:
			_convo_line(id, "hire.answer.%s.%s" % [topic, arch])


# ---------- one-on-ones ----------
# A talk is a sitting in the conversation window (docs/talks.md). What's going on with them right now
# gives the topics (_talk_topics); everything said and done is written in scenes, data/dialogues/talk_*.dlg,
# one scene per topic per person ("who: alex", "topic: tired"; "who: any" for whoever has no own one).
#
# - The sharpest topic's scene opens the talk: its lines before the first question are what they're
#   ready to show.
# - Its questions ("? … (open +1) -> branch") are offered in full, the next topic's first question, how
#   the work goes and how they are. A question spends one of three and moves their openness: it starts
#   from trust, and lines marked {if open 3} are the real answers. At zero they shut the talk (the
#   "react" scene says how they take it).
# - In an answer, "?" asks further, "*" does something about it and ends the talk.
# - Their story (topic thread) goes a step at a time: ready (_thread_ready), then the scene's own
#   when: picks the step; "> thread them" marks a step taken.
# In a talk scene "them" is whoever you're talking to: a speaker, and a person in conditions and effects.
const TALK_QUESTIONS := 3
const TALK_THREAD_GAP := 5 # days between steps of someone's story


func _open_talk(p: String) -> void:
	var st: Dictionary = people[p]
	var open := clampi(2 + int(st["trust"]), 1, 4)
	if st["mood"] <= -2.0 or day - int(st.get("talk_shut", -99)) <= 3:
		open = maxi(1, open - 1)
	convo = {"who": p, "kind": "talk", "left": TALK_QUESTIONS, "open": open, "log": [], "asked": [], "here": [],
		"scene": "", "emo": _talk_emo(p), "names": _talk_names(p)}
	convo["topics"] = _talk_topics(p)
	if not convo["topics"].is_empty():
		_talk_run(convo["topics"][0][1], 0)
		convo["here"] = []


# What's on their mind right now, sharpest first, each with the scene that will play it: [[topic, scene]].
# "work" and "how" are always there.
func _talk_topics(p: String) -> Array:
	var st: Dictionary = people[p]
	var found: Array = []
	for c in flags.get("credit_taken", []):
		if c["owner"] == p and day - int(c["day"]) <= 7 and not flags.has("credit_said_%d" % c["uid"]):
			found.append("credit")
			break
	if st["energy"] <= 4.0:
		found.append("tired")
	if _stuck_task(p) >= 0:
		found.append("stuck")
	var q := queue_of(p)
	if q.size() >= 3:
		found.append("load")
	if st["idle_days"] >= 2 and q.is_empty():
		found.append("idle")
	if not q.is_empty() and info(p)["hates"].has(q[0]["cat"]):
		found.append("hate")
	if st["mood"] <= -1.5 and found.is_empty():
		found.append("mood")
	if _thread_ready(p):
		found.append("thread")
	if info(p)["drive"] in ["growth", "visibility"] and day >= 3 and not flags.has("asked_growth_" + p):
		found.append("grow")
	if day - st["last_done"] <= 2 and scenes._last_good(self, p) >= 0:
		found.append("proud")
	if not q.is_empty():
		found.append("work")
	found.append("how")
	found.sort_custom(func(a, b): return Dialogue.TOPICS[a]["heat"] > Dialogue.TOPICS[b]["heat"])
	# One topic per task, the sharpest: "stuck", "hate" and "work" can all be about the same card.
	var about := {"stuck": _stuck_task(p), "hate": -1 if q.is_empty() else q[0]["uid"], "work": -1 if q.is_empty() else q[0]["uid"]}
	var covered: Array = []
	var out: Array = []
	for topic in found:
		var uid: int = about.get(topic, -1)
		if uid >= 0:
			if covered.has(uid):
				continue
			covered.append(uid)
		var sid := _talk_scene(p, topic)
		if sid != "":
			out.append([topic, sid])
	return out


# Their own scene for the topic if there is one, else their kind's (hires), else anyone's; the first
# whose when: holds.
func _talk_scene(p: String, topic: String) -> String:
	var whos: Array = [p]
	if hires.has(p):
		whos += ["hire_" + archetype(p), "hire"]
	whos.append("any")
	for who in whos:
		for id in Dialogue.TALKS.get(topic, []):
			var sc: Dictionary = Dialogue.SCENES[id]
			if sc["who"] == who and story_true(sc["when"]):
				return id
	return ""


func _stuck_task(p: String) -> int:
	for t in queue_of(p):
		if t.get("stuck", 0) > 0:
			return t["uid"]
	return -1


func _talk_names(p: String) -> Dictionary:
	var names := {"who": "@name.%s.nom" % p, "days": str(people[p]["idle_days"])}
	var q := queue_of(p)
	if not q.is_empty():
		names["task"] = "@taskname." + q[0]["id"]
		names["cat"] = "@cat." + q[0]["cat"]
	var stuck := _stuck_task(p)
	if stuck >= 0:
		names["stuck"] = "@taskname." + task(stuck)["id"]
	var good: int = scenes._last_good(self, p)
	if good >= 0:
		names["done"] = "@taskname." + task(good)["id"]
	return names


func _talk_emo(p: String) -> String:
	var st: Dictionary = people[p]
	if st["mood"] <= -1.5 or st["energy"] <= 3.0:
		return "sad"
	if st["mood"] >= 2.0:
		return "happy"
	return "neutral"


# Their story is ready for another step: from chapter two, while they trust you at least as much as when
# they told you the last bit, never two steps in a week. Which step it is, the scenes decide.
func _thread_ready(p: String) -> bool:
	var st: Dictionary = people[p]
	return chapter >= 2 and st["trust"] >= 1 and st["trust"] >= st.get("thread_trust", 0) \
		and day - int(st.get("thread_day", -99)) >= TALK_THREAD_GAP


# Plays a talk scene from an op until a label (the branch is over), a jump, or choices (they wait in "here").
func _talk_run(sid: String, pos: int) -> void:
	convo["scene"] = sid
	var ops: Array = Dialogue.SCENES[sid]["ops"]
	while pos < ops.size():
		var op: Dictionary = ops[pos]
		match op["op"]:
			"label":
				return
			"line":
				if story_true(op["if"]):
					_talk_line(op)
			"choices":
				convo["here"] = [sid, pos]
				return
			"fx":
				if story_true(op["if"]):
					_story_fx(op["words"])
			"jump":
				if story_true(op["if"]):
					_talk_goto(sid, op["to"])
					return
		pos += 1


func _talk_goto(sid: String, to: String) -> void:
	if to != "end":
		_talk_run(sid, Dialogue.SCENES[sid]["labels"][to] + 1)


func _talk_line(op: Dictionary) -> void:
	var who: String = convo["who"] if op["who"] == "them" else op["who"]
	if who == convo["who"] and op["emo"] != "":
		convo["emo"] = op["emo"]
	var said: Dictionary = convo["names"].duplicate()
	said["_by"] = who
	convo["log"].append({"who": who, "ru": op["ru"], "en": op["en"], "names": said})


# What you can say now: what the answer leaves open, then the topics not yet touched.
func _talk_choices() -> Array:
	var out: Array = []
	if convo.get("done", false) or convo.get("shut", false):
		return out
	if not convo["here"].is_empty():
		var sid: String = convo["here"][0]
		var at: int = convo["here"][1]
		var items: Array = Dialogue.SCENES[sid]["ops"][at]["items"]
		for i in items.size():
			if story_true(items[i]["if"]) and (not items[i]["ask"] or convo["left"] > 0):
				out.append("%s:%s:%d:%d" % ["q" if items[i]["ask"] else "a", sid, at, i])
	if convo["left"] <= 0:
		return out
	var shown := 0
	for pair in convo["topics"]:
		var topic: String = pair[0]
		if convo["asked"].has(topic):
			continue
		var qs := _talk_questions(pair[1])
		if qs.is_empty():
			continue
		var take := 1
		if not topic in ["work", "how"]:
			if shown >= 2:
				continue
			take = qs.size() if shown == 0 else 1
			shown += 1
		out.append_array(qs.slice(0, take))
	return out


# The questions a topic's scene starts with: the first choices before any branch.
func _talk_questions(sid: String) -> Array:
	var out: Array = []
	var ops: Array = Dialogue.SCENES[sid]["ops"]
	for at in ops.size():
		if ops[at]["op"] == "label":
			break
		if ops[at]["op"] == "choices":
			var items: Array = ops[at]["items"]
			for i in items.size():
				if items[i]["ask"] and story_true(items[i]["if"]):
					out.append("q:%s:%d:%d" % [sid, at, i])
			break
	return out


func _talk_item(c: String) -> Dictionary:
	var parts := c.split(":")
	return Dialogue.SCENES[parts[1]]["ops"][int(parts[2])]["items"][int(parts[3])]


func _talk_choose(c: String) -> void:
	var p: String = convo["who"]
	var sid: String = c.split(":")[1]
	var item := _talk_item(c)
	convo["log"].append({"who": "you", "ru": item["ru"], "en": item["en"], "names": convo["names"]})
	convo["here"] = []
	if c.begins_with("a:"):
		_talk_goto(sid, item["to"])
		people[p]["mood"] = clampf(people[p]["mood"], -5.0, 5.0)
		convo["done"] = true
		convo["left"] = 0
		return
	convo["left"] -= 1
	var topic: String = Dialogue.SCENES[sid]["topic"]
	if not convo["asked"].has(topic):
		convo["asked"].append(topic)
		_talk_touched(p, topic)
	var moved: int = item["open"]
	convo["open"] += moved
	if moved != 0:
		_talk_react("up" if moved > 0 else "down")
		if moved < 0:
			convo["emo"] = "annoyed"
	if convo["open"] <= 0:
		_talk_react("shut")
		people[p]["mood"] -= 0.5
		people[p]["talk_shut"] = day
		convo["emo"] = "annoyed"
		convo["shut"] = true
		convo["left"] = 0
		return
	_talk_goto(sid, item["to"])
	people[p]["mood"] = clampf(people[p]["mood"], -5.0, 5.0)


# Bringing a thing up at all settles some of it: they've told you about growing, you've talked about the review.
func _talk_touched(p: String, topic: String) -> void:
	match topic:
		"grow":
			flags["asked_growth_" + p] = true
		"credit":
			for c in flags.get("credit_taken", []):
				if c["owner"] == p:
					flags["credit_said_%d" % c["uid"]] = true


# How they take the way you asked: a branch (up, down, shut) of their "react" scene.
func _talk_react(branch: String) -> void:
	var sid := _talk_scene(convo["who"], "react")
	if sid == "" or not Dialogue.SCENES[sid]["labels"].has(branch):
		return
	var keep: String = convo["scene"]
	_talk_goto(sid, branch)
	convo["scene"] = keep
	convo["here"] = []


# How their first task really goes; the scenes only let someone open with you say it as it is.
func _work_state(p: String) -> String:
	var q := queue_of(p)
	if q.is_empty():
		return ""
	var t: Dictionary = q[0]
	if t.get("stuck", 0) > 0 or t["blocked"] > 0:
		return "stuck"
	if days_needed(t) > t["due"] - day + 1.3:
		return "behind"
	return "on_track"


# What only a talk can do (_story_fx): the person is always the first word after the effect's name.
func _talk_fx(w: Array) -> void:
	var p: String = w[1]
	if not people.has(p):
		return
	var st: Dictionary = people[p]
	match w[0]:
		"dayoff":
			give_day_off(p)
		"lighten":
			lighten(p)
		"push":
			st["pushed"] = PUSH_DAYS
			st["energy"] -= 0.5
		"sit":
			if _stuck_task(p) >= 0:
				sit_with(_stuck_task(p))
		"initiative":
			offer_today[p] = true
			if initiative_offer(p) != "":
				accept_initiative(p)
		"calm":
			flags["calm_" + p] = day + int(w[2])
		"mention":
			flags["mention_" + p] = scenes._last_good(self, p)
		"stretch":
			flags["stretch_" + p] = true
		"promise":
			make_promise(p)
		"learn":
			var cat: String = w[2]
			if cat == "done":
				var good: int = scenes._last_good(self, p)
				cat = task(good)["cat"] if good >= 0 else ""
			if cat in C.CATEGORIES:
				learn(p, cat, float(w[3]))
		"visible":
			if p == "vika":
				vika_up()
		"confide":
			_confide(p)
		"thread":
			st["thread"] = int(st.get("thread", 0)) + 1
			st["thread_trust"] = st["trust"]
			st["thread_day"] = day
			lead("I", 0.3)


# They tell you something about themselves you didn't know: their words in the window, the note in the chat.
func _confide(p: String) -> void:
	var key := _next_unknown(p)
	if key == "":
		return
	var line := "talk.listen.%s.%s" % [p, key.replace("skill.", "")]
	var names: Dictionary = convo.get("names", {}).duplicate()
	if hires.has(p) and key.begins_with("skill."):
		line = "talk.listen.hire.level.%d" % people[p]["skills"][key.replace("skill.", "")]
		names["cat"] = "@cat." + key.replace("skill.", "")
	if not L.has_key(line):
		line = "talk.listen.any"
	if not convo.is_empty():
		var said := names.duplicate()
		said["_by"] = p
		convo["log"].append({"who": p, "key": line, "names": said})
	_reveal(p, key)
	var note: Dictionary = history[-1]
	if not convo.is_empty() and note["key"].begins_with("know."):
		convo["log"].append({"who": "", "key": note["key"], "names": note["names"]})


func can_hire(id: String) -> bool:
	if endless():
		return phase == "plan" and pending.is_empty() and money >= HIRE_FEE and not candidate(id).is_empty()
	return phase == "plan" and pending.is_empty() and openings > 0 and not candidate(id).is_empty()


func hire(id: String) -> void:
	if not can_hire(id):
		return
	var c := candidate(id)
	candidates.erase(c)
	if endless():
		money -= HIRE_FEE
	else:
		openings -= 1
	team.append(id)
	_new_person(id, false)
	# What the interview showed, you know about them from day one.
	for cat in c["known"]:
		people[id]["known"]["skill." + cat] = true
	if c.get("drive_known", false):
		people[id]["known"]["drive"] = true
	lead("P", 0.3)
	_say("marina", "hire.joined", [], {"who": "@name.%s.nom" % id})
	_say(id, "hello." + id)


func reject_candidate(id: String) -> void:
	var c := candidate(id)
	if c.is_empty() or phase != "plan":
		return
	candidates.erase(c)
	_narrate("hire.rejected", [], {"who": "@name.%s.nom" % id})


# ---------- letting people go ----------

const WARNING_DAYS := 5 # after a warning, this long before you can decide


# From chapter two: a serious talk first (a warning), a decision a week later. Doing it without the
# warning is possible, and Marina will make sure everyone hears about it.
func can_fire(p: String) -> bool:
	return (chapter >= 2 or endless()) and phase == "plan" and pending.is_empty() and available(p)


func warned(p: String) -> bool:
	return people[p].get("warned_day", -1) >= 0


func fire_ready(p: String) -> bool:
	return warned(p) and day - people[p]["warned_day"] >= WARNING_DAYS


func start_fire(p: String) -> void:
	if not can_fire(p) or not can_afford(cost("fire")):
		return
	spend_attention(cost("fire"))
	history.append({"who": "you", "key": "fire.open", "args": [], "names": {}, "to": p, "day": day})
	_open_conversation(scenes.fire_event(self, p))


func warn(p: String) -> void:
	var st: Dictionary = people[p]
	st["warned_day"] = day
	st["mood"] = clampf(st["mood"] - 1.5, -5.0, 5.0)
	st["trust"] -= 1
	lead("A", 0.5)
	# The rest of the team notices.
	for q in team:
		if q != p and available(q):
			people[q]["mood"] = clampf(people[q]["mood"] - 0.2, -5.0, 5.0)


# They're gone: their work goes back to the inbox, the team reacts, and the opening is yours again.
func let_go(p: String, with_warning: bool) -> void:
	flags["stat_fired"] = flags.get("stat_fired", 0) + 1
	var st: Dictionary = people[p]
	st["gone"] = true
	st["fired"] = true
	if endless():
		var severance := weekly_pay(p) * SEVERANCE_WEEKS
		money -= severance
		_narrate("money.severance", [cash_arg(severance)], {"who": "@name.%s.nom" % p})
	taras_like(2.0)
	_drop_tasks(p)
	lead("P", 1.0)
	var arch := archetype(p)
	var team_mood := -0.3
	var line := "fire.team.sad"
	if layoff_on():
		# The cut the board asked for: no scandal, no opening back, and everyone feels it.
		flags.erase("layoff_until")
		flags["layoff_done"] = true
		flags["laid_off"] = p
		team_mood = -0.5
		line = "layoff.team"
		# Cutting someone who once stood in for Alex is his old story all over again.
		if p != "alex" and available("alex") and ((p == "gena" and flags.has("alex_hotfix_helped")) or (p == "vika" and flags.has("alex_reports:pair_insist"))):
			people["alex"]["mood"] -= 2.0
			people["alex"]["trust"] -= 1
			flags["alex_lost_helper"] = true
			_narrate("layoff.alex_breaks")
		elif p != "alex":
			for h in ["gena", "vika"]:
				var helped: bool = flags.has("alex_hotfix_helped") if h == "gena" else flags.has("alex_reports:pair_insist")
				if h != p and helped and available(h) and not flags.has("alex_helper"):
					flags["alex_helper"] = h
					flags["alex_helper_" + h] = true
	elif not with_warning:
		team_mood = -0.8
		line = "fire.team.shock"
		boss -= 1.0
	elif C.PEOPLE.has(p):
		team_mood = -0.8
	elif arch == "genius":
		team_mood = 0.8
		line = "fire.team.relief"
	elif arch in ["faker", "stump"]:
		team_mood = 0.3
		line = "fire.team.relief"
	if line != "layoff.team":
		openings += 1
	for q in team:
		if q != p and available(q):
			people[q]["mood"] = clampf(people[q]["mood"] + team_mood, -5.0, 5.0)
	_narrate(line, [], {"who": "@name.%s.nom" % p, "who_gen": "@name.%s.gen" % p})
	if arch == "genius":
		boss -= 1.5
		_say("boss", "fire.boss_genius", [], {"who": "@name.%s.acc" % p})


# The board's order in chapter three: one person has to go by the deadline.
func layoff_on() -> bool:
	return flags.has("layoff_until")


# Nobody picked by the deadline: Irina picks by the numbers — whoever closed the fewest tasks over the
# last two weeks. Not the one you'd have picked, often: she doesn't know who fixed what at night.
func _layoff_deadline() -> void:
	if not layoff_on() or day < flags["layoff_until"]:
		return
	var pick := ""
	var fewest := 1 << 30
	var w := week()
	for p in team:
		if not available(p):
			continue
		var done: int = people[p]["week_done"][w] + (people[p]["week_done"][w - 1] if w > 0 else 0)
		if done < fewest:
			fewest = done
			pick = p
	if pick == "":
		# Nobody left to cut: the order has nothing to act on.
		flags.erase("layoff_until")
		return
	boss -= 0.5
	_say("boss", "layoff.irina_chose", [], {"who": "@name.%s.acc" % pick})
	let_go(pick, true)


# What the candidate's CV claims, unless an interview showed the truth.
func cv_level(id: String, cat: String) -> int:
	var c := candidate(id)
	if not c.is_empty() and c["known"].has(cat):
		return hires[id]["skills"][cat]
	return hires[id]["cv"][cat]


# The progress a task seems to have: a faker's own reports, until someone looks.
func shown_progress(t: Dictionary) -> float:
	return maxf(t["progress"], t.get("claimed", 0.0)) if not t.get("exposed", false) else t["progress"]


func _expose_faker(t: Dictionary) -> void:
	if t.get("claimed", 0.0) <= t["progress"] + 0.05 or t.get("exposed", false):
		return
	t["exposed"] = true
	_narrate("faker.exposed", [], {"who": "@name.%s.gen" % t["owner"], "task": "@taskname." + t["id"]})


# ---------- banks ----------

const SALE_CHANCE := 0.3 # each Monday, plus REPUTATION_SALE for each point of reputation
const REPUTATION_SALE := 0.1
const BANK_LEAVES := -3.0
const BANK_MOOD := {"good": 1.0, "bad": -1.0, "late": -1.5, "declined": -0.5}


# A card about a bank comes only while that bank is with us.
func _bank_here(id: String) -> bool:
	var b: String = C.TASKS[id].get("bank", "")
	return b == "" or banks.has(b)


func _join_bank(b: String) -> void:
	if banks.has(b):
		return
	banks[b] = {"mood": 0.0, "since": day}
	_narrate("bank.joined", [], {"bank": "@bankphrase." + b})
	# Its deliveries mix into the deck from here on.
	for id in deck_source():
		if C.TASKS[id].get("bank", "") == b:
			deck.insert(rng.randi_range(0, deck.size()), id)


# A few days after the order to cut one, sales close two banks at once, and from then on there's a lot more
# work than the team can take: the irony the hiring in chapter three hangs on. The first time you go to
# Irina about it is a story scene (data/dialogues/ch3_hiring.dlg); after that, ask_people().
const RUSH_AFTER := 4 # days after the layoff order
const RUSH_BANKS := ["harbor", "till"]
const RUSH_LOAD := 1.15


func _layoff_rush() -> void:
	var at := layoff_day()
	if at == 0 or flags.has("rush") or chapter_day() < at + RUSH_AFTER:
		return
	flags["rush"] = true
	_say("boss", "rush.sold", [], {"b1": "@bankphrase." + RUSH_BANKS[0], "b2": "@bankphrase." + RUSH_BANKS[1]})
	for b in RUSH_BANKS:
		_join_bank(b)


# Asking Irina for people again, after the first time: she looks at how much is piling up and at your weight.
const PEOPLE_ASK_GAP := 5 # days between two asks
const PEOPLE_OVERLOAD := 3.0 # days of unfinished work per person that counts as drowning
const OVERLOAD_STORY := 2.0 # and enough of a pile-up for the first trip to Irina (the "overload" condition)
const RUSH_CARDS := 1 # more cards a day can come in once the rush is on


func workload() -> float:
	var left := 0.0
	for t in tasks:
		if t["status"] in ["inbox", "queued", "active"] and t["due"] < NO_DEADLINE:
			left += t["size"] * (1.0 - t["progress"])
	var heads := team.filter(func(p): return available(p)).size()
	return left / maxf(1.0, heads)


func can_ask_people() -> bool:
	return phase == "plan" and pending.is_empty() and convo.is_empty() and flags.has("asked_people") and openings == 0 \
		and day - flags.get("people_asked_day", -100) >= PEOPLE_ASK_GAP


func ask_people() -> void:
	if not can_ask_people():
		return
	spend_attention(cost("people"))
	flags["people_asked_day"] = day
	history.append({"who": "you", "key": "people.ask", "args": [], "names": {}, "day": day})
	if workload() < PEOPLE_OVERLOAD:
		boss -= 0.5
		_say("boss", "people.no")
	elif has_weight():
		openings += 1
		_say("boss", "people.yes")
	else:
		_say("boss", "people.later")


# ---------- clients (endless run) ----------

# Every bank past the first brings this much more work a day. Not more cards: each card costs you a point
# to hand out, so more of them would burn you out rather than keep the team busy.
const BANK_WORK := 1.2
# What a bank pays the company a week (thousands), by how it feels about us. It isn't your money: it's
# what you show Irina when the budget is split.
const BANK_FEE := 150
const FEE_SHARE := {"happy": 1.0, "fine": 1.0, "unhappy": 0.5, "leaving": 0.0}


func extra_banks() -> int:
	return maxi(0, banks.size() - C.START_BANKS.size())


func bank_fee(b: String) -> int:
	return int(BANK_FEE * FEE_SHARE[bank_word(b)])


func revenue() -> int:
	var sum := 0
	for b in banks:
		sum += bank_fee(b)
	return sum


# Banks you could go and win over: not with us yet, and not ones that left us.
func prospects() -> Array:
	return C.BANKS.keys().filter(func(b): return not banks.has(b) and not flags.has("bank_lost_" + b))


func pitched_this_week() -> bool:
	return flags.get("pitched_week", -1) == int((day - 1) / 5.0)


func can_pitch(b: String) -> bool:
	return endless() and phase == "plan" and pending.is_empty() and prospects().has(b) and not pitched_this_week() and can_afford(cost("pitch"))


# You go and talk a bank into our stands. They come on right away, with their first delivery.
func pitch_bank(b: String) -> void:
	if not can_pitch(b):
		return
	spend_attention(cost("pitch"))
	flags["pitched_week"] = int((day - 1) / 5.0)
	history.append({"who": "you", "key": "bank.pitch", "args": [], "names": {"bank": "@bankphrase." + b}, "to": "boss", "day": day})
	_join_bank(b)
	flags["bank_won_p%d" % period] = true
	if C.TASKS.has("bank_delivery@" + b):
		add_task("bank_delivery@" + b)
	boss += 0.5


# Roughly how much work comes in a day, and how much the team gets through: what tells you whether
# to go after another client.
func daily_load() -> float:
	return C.DAILY_LOAD * ramp_now()["load"] + BANK_WORK * extra_banks()


func team_capacity() -> float:
	var sum := 0.0
	for p in team:
		if available(p):
			var skills: Dictionary = people[p]["skills"]
			var avg := 0.0
			for cat in skills:
				avg += skills[cat]
			sum += SPEED_BASE + SPEED_PER_SKILL * avg / maxf(1.0, skills.size())
	return sum


# On a Monday sales may close a deal with the next bank of the chapter; good deliveries make it likelier.
func _maybe_sell() -> void:
	# In the endless run you go and get clients yourself (pitch_bank).
	if endless() or day % 5 != 1 or day == first_day():
		return
	var pool: Array = []
	for ch in range(1, (C.CHAPTERS.size() if endless() else chapter) + 1):
		pool.append_array(C.BANK_POOL.get(ch, []))
	pool = pool.filter(func(b): return not banks.has(b) and not flags.has("bank_lost_" + b))
	if pool.is_empty() or rng.randf() > SALE_CHANCE + REPUTATION_SALE * maxf(0.0, reputation) + perk_add("sales"):
		return
	var b: String = pool[0]
	reputation = 0.0
	_say("boss", "bank.sold", [], {"bank": "@bankphrase." + b})
	_join_bank(b)


# How a card about a bank went moves that bank, and the platform's name with the next ones.
func _settle_bank(t: Dictionary, outcome: String) -> void:
	var b: String = C.TASKS.get(t["id"], {}).get("bank", "")
	if b == "" or not banks.has(b) or not BANK_MOOD.has(outcome):
		return
	var info: Dictionary = C.TASKS[t["id"]]
	var was := bank_word(b)
	banks[b]["mood"] += BANK_MOOD[outcome]
	if endless() and was != "happy" and bank_word(b) == "happy":
		boss += 0.3
	if outcome == "good" and info["tags"].has("client"):
		banks[b]["shipped"] = true
	reputation += 1.0 if outcome == "good" else -0.5
	if (info["tags"].has("last_chance") and outcome in ["late", "declined"]) or banks[b]["mood"] <= BANK_LEAVES:
		banks.erase(b)
		flags["bank_lost_" + b] = true
		deck = deck.filter(func(id): return _bank_here(id))
		boss -= 1.0
		_say("boss", "bank.left", [], {"bank": "@bankphrase." + b})


func bank_word(b: String) -> String:
	var m: float = banks[b]["mood"]
	return "happy" if m >= 2.0 else ("fine" if m > -1.0 else ("unhappy" if m > -2.5 else "leaving"))


# ---------- improvements to Chainer ----------

const BACKLOG_SIZE := 3
const NO_DEADLINE := 100000 # improvements and initiatives: done when they're done


# The improvements done that act on this card in this way ("remove", "shrink", "self").
func _improved_by(kind: String, id: String) -> Array:
	var out: Array = []
	for e in perks:
		if e["kind"] == kind and e["targets"].any(func(target): return C.covers(target, id)):
			out.append("perk")
			break
	for imp in improved:
		for e in C.IMPROVEMENTS[imp]["effects"]:
			if e["kind"] == kind and e["targets"].any(func(target): return C.covers(target, id)):
				out.append(imp)
				break
	return out


# Keep three improvements on offer, next in line first.
func _fill_backlog() -> void:
	if endless():
		return
	var open := tasks.filter(func(t): return t.get("backlog", false) and t["status"] == "inbox").size()
	var ids: Array = []
	for ch in range(1, (C.CHAPTERS.size() if endless() else chapter) + 1):
		ids.append_array(C.improvements_of(ch))
	for id in ids:
		if open >= BACKLOG_SIZE:
			return
		if flags.has("imp_added_" + id) or flags.has("init_" + id):
			continue
		_add_improvement(id)
		open += 1


func _add_improvement(id: String) -> Dictionary:
	flags["imp_added_" + id] = true
	var info: Dictionary = C.IMPROVEMENTS[id]
	add_task_raw("init_" + id, info["cat"], info["size"], NO_DEADLINE, false, "me")
	var t: Dictionary = tasks[tasks.size() - 1]
	t["backlog"] = true
	return t


func backlog() -> Array:
	return tasks.filter(func(t): return t.get("backlog", false) and t["status"] == "inbox")


# An improvement is done: its cards change from now on.
func _improve(id: String) -> void:
	improved[id] = day
	deck = deck.filter(func(card): return _improved_by("remove", card).is_empty())
	_narrate("imp.done", [], {"task": "@taskname.init_" + id, "effect": "@imp.%s.effect" % id})
	_fill_backlog()


func add_task_raw(id: String, cat: String, size: float, due: int, public: bool, from: String) -> void:
	tasks.append({
		"uid": next_uid, "id": id, "cat": cat, "size": size, "progress": 0.0,
		"due": due, "public": public, "from": from, "owner": "", "helper": "",
		"q_sum": 0.0, "q_days": 0.0, "status": "inbox", "late": false, "quality": "",
		"done_day": 0, "reviewed": false, "assigned_day": 0, "helped": {}, "first": false,
		"asked": false, "vouched": false, "flaw": false, "complicated": false, "blocked": 0, "q_bonus": 0.0, "involved": false,
		"key": chapter_keys().has(id), "sit_today": false, "again": seen_day.has(id), "day": day,
	})
	seen_day[id] = day
	seen_day[C.TASKS.get(id, {}).get("tpl", id)] = day
	next_uid += 1


func _queue_events() -> void:
	scenes.queue(self)
	if not endless():
		_say_event_lines()


# Whatever was queued goes out as messages: each one's lines into the asker's conversation, to answer when you like.
func _post_letters() -> void:
	while not events.is_empty():
		_say_event_lines()
		var ev: Dictionary = events.pop_front()
		ev["sent"] = step
		letters.append(ev)


func letter(i: int) -> Dictionary:
	return letters[i] if i >= 0 and i < letters.size() else {}


# Saying nothing costs nothing; anything else is a reply, and some replies take more of you.
func reply_cost(ev: Dictionary, choice: String) -> int:
	if choice == _silent_choice(ev):
		return 0
	return maxi(cost("reply"), choice_cost(ev, choice))


func can_answer(i: int, choice: String) -> bool:
	var ev := letter(i)
	return not ev.is_empty() and ev["choices"].has(choice) and phase in ["plan", "evening"] and can_afford(reply_cost(ev, choice))


func answer_letter(i: int, choice: String) -> void:
	if not can_answer(i, choice):
		return
	var ev: Dictionary = letters.pop_at(i)
	spend_attention(reply_cost(ev, choice))
	_settle_letter(ev, choice)


# What silence means for each question: the answer it amounts to.
const SILENCE := {"chaos_meeting": "later", "boss_deadline": "yes", "boss_details": "dodge", "boris_drunk": "refuse",
	"friday_deploy": "allow", "marina_warns": "dismiss", "stayed_late": "ignore", "conflict": "ignore", "complaint": "shrug",
	"boss_dump": "take", "taras_brag": "noted", "offer": "not_now", "deal": "let_go"}
const SILENT_WORDS := ["ignore", "stay_out", "shrug", "later", "dodge", "noted", "dismiss", "not_yet", "ok"]


func _silent_choice(ev: Dictionary) -> String:
	if SILENCE.has(ev["id"]) and ev["choices"].has(SILENCE[ev["id"]]):
		return SILENCE[ev["id"]]
	if ev.has("comp") and C.COMPLICATIONS[ev["comp"]]["who"] == "owner":
		return _own_call(ev)
	for c in ev["choices"]:
		if c in SILENT_WORDS:
			return c
	if ev.has("comp"):
		for c in ev["choices"]:
			if C.COMPLICATIONS[ev["comp"]]["choices"].get(c, {}).get("hours", 0) == 0:
				return c
	return ""


# Left to themselves with a snag in their task, people do what they're able to: someone strong takes
# it on properly, someone weaker cuts the corner or tries and stalls. Never the option that needs you.
const STRONG_ENOUGH := 3


func _own_call(ev: Dictionary) -> String:
	var t := task(ev.get("uid", -1))
	var opts: Dictionary = C.COMPLICATIONS[ev["comp"]]["choices"]
	var mine: Array = ev["choices"].filter(func(c): return opts.get(c, {}).get("hours", 0) == 0 and opts.get(c, {}).get("special", "") == "")
	if mine.is_empty():
		return ""
	var skill: int = people[t["owner"]]["skills"][t["cat"]] if not t.is_empty() and people.has(t["owner"]) else 2
	var checked: Array = mine.filter(func(c): return opts[c].has("check"))
	var corner: Array = mine.filter(func(c): return opts[c].get("quality", 0.0) < 0.0)
	if skill >= STRONG_ENOUGH:
		var clean: Array = mine.filter(func(c): return opts[c].get("quality", 0.0) >= 0.0)
		return checked[0] if not checked.is_empty() else (clean[0] if not clean.is_empty() else mine[0])
	return corner[0] if not corner.is_empty() else (checked[0] if not checked.is_empty() else mine[0])


# The day (or the evening) is over: what's still unanswered settles as silence.
func _expire_letters(sent: Array) -> void:
	var keep: Array = []
	var due: Array = []
	for ev in letters:
		if ev.get("sent", "") in sent:
			due.append(ev)
		else:
			keep.append(ev)
	letters = keep
	for ev in due:
		_narrate("letter.unanswered", [], {"who": "@name.%s.dat" % ev["who"]} if ev["who"] != "" else {})
		history[-1]["thread"] = ev["who"]
		# An idea nobody answered just doesn't happen; a question left hanging stings a little.
		if team.has(ev["who"]) and available(ev["who"]) and ev["id"] != "offer":
			people[ev["who"]]["mood"] -= 0.3
		var c := _silent_choice(ev)
		if c != "":
			ev["silent"] = true
			_settle_letter(ev, c)


func _settle_letter(ev: Dictionary, choice: String) -> void:
	flags["%s:%s" % [ev["id"], choice]] = true
	scenes.resolve(self, ev, choice)
	_weight_check()
	# An answer can bring a follow-up question; it comes as a message too.
	_post_letters()


func _say_event_lines() -> void:
	if events.is_empty():
		return
	var ev: Dictionary = events[0]
	var from := history.size()
	for line in ev["lines"]:
		_say(line["who"], line["key"], [], ev["names"])
	# The whole question, narration included, belongs to the conversation with whoever asks it.
	for i in range(from, history.size()):
		history[i]["thread"] = ev["who"]


func resolve_event(choice: String) -> void:
	if phase != "event" or events.is_empty() or not events[0]["choices"].has(choice):
		return
	# Remembered like story answers (<event>:<choice>), so a later scene can quote what was said back then.
	flags["%s:%s" % [events[0]["id"], choice]] = true
	# What you say at Irina's is a reply like any other.
	if endless() and _visit_event(events[0]):
		spend_attention(choice_cost(events[0], choice))
	scenes.resolve(self, events.pop_front(), choice)
	_weight_check()
	if events.is_empty():
		phase = after_events
		if phase == "plan":
			_deliver_arrivals()
	else:
		_say_event_lines()


# ---------- Taras ----------

# How much you lead like Taras, counted by deeds, not by style: people let go, people who quit, late hours
# asked for, credit taken or blame passed at reviews, weeks without a one-on-one; giving people credit counts
# the other way. It never sinks below TARAS_FLOOR, so a lead who hardens later can still get there.
# Story scenes ask about it (taras >= 3) and Taras warms to you as it grows.
const TARAS_FLOOR := -3.0


func taras_like(amount: float) -> void:
	flags["taras"] = maxf(TARAS_FLOOR, flags.get("taras", 0.0) + amount)


func taras_score() -> float:
	return flags.get("taras", 0.0)


# ---------- story conversations ----------

# The first scene in data/dialogues for this time of day whose conditions hold, once per run.
# An evening scene remembers where the day was going (the summary or the Friday report) and goes there after.
func _queue_story(at: String = "morning") -> void:
	story = {}
	if endless():
		return
	for id in Dialogue.ORDER:
		var sc: Dictionary = Dialogue.SCENES[id]
		if sc["topic"] == "" and sc["at"] == at and not flags.has("story_" + id) and story_true(sc["when"]):
			flags["story_" + id] = true
			story = {"id": id, "pos": 0, "wait": "", "log": [], "then": phase if at == "evening" else ""}
			phase = "story"
			_story_run()
			return


func story_true(terms: Array) -> bool:
	for term in terms:
		var t: Array = term
		if t.has("them"):
			# In a talk, "them" is whoever you're talking to.
			t = t.map(func(x): return convo.get("who", "") if x == "them" else x)
		var neg: bool = t[0] == "not"
		if neg:
			t = t.slice(1)
			if t.is_empty():
				continue
		var ok := false
		match t[0]:
			"chapter":
				ok = Dialogue.in_range(t[1], chapter)
			"day":
				ok = Dialogue.in_range(t[1], chapter_day())
			"here":
				ok = t.slice(1).all(func(p): return available(p) and not people[p]["absent"])
			"flag":
				ok = flags.has(t[1])
			"taras":
				ok = _compare(taras_score(), t[1], float(t[2]))
			"irina":
				ok = t.slice(1).has(boss_type)
			"style":
				ok = t.slice(1).has(_style_top(style))
			"laid_off":
				ok = flags.get("laid_off", "") == t[1]
			"incident":
				ok = not _open_incidents().is_empty()
			"busy":
				ok = people.has(t[1]) and _compare(queue_of(t[1]).size(), t[2], float(t[3]))
			"overload":
				ok = workload() >= OVERLOAD_STORY
			"open":
				ok = int(convo.get("open", 0)) >= int(t[1])
			"work":
				ok = convo.has("who") and _work_state(convo["who"]) == t[1]
			"drive":
				ok = people.has(t[1]) and t.slice(2).has(info(t[1])["drive"])
			"known":
				ok = people.has(t[1]) and people[t[1]]["known"].has(t[2])
			"promised":
				ok = people.has(t[1]) and people[t[1]]["promised"]
			"good_work":
				ok = people.has(t[1]) and scenes._last_good(self, t[1]) >= 0 and task(scenes._last_good(self, t[1])).get("quality", "") == "good"
			"can_sit":
				ok = people.has(t[1]) and _stuck_task(t[1]) >= 0 and not task(_stuck_task(t[1])).get("sit_today", false)
			_:
				ok = flags.has(t[0])
		if ok == neg:
			return false
	return true


# Walks the scene to the next thing to show: a line (wait for "next") or a choice.
func _story_run() -> void:
	var sc: Dictionary = Dialogue.SCENES[story["id"]]
	var ops: Array = sc["ops"]
	while story["pos"] < ops.size():
		var op: Dictionary = ops[story["pos"]]
		story["pos"] += 1
		match op["op"]:
			"label":
				break
			"line":
				if story_true(op["if"]):
					story["log"].append({"who": op["who"], "emo": op["emo"], "ru": op["ru"], "en": op["en"]})
					story["wait"] = "line"
					return
			"choices":
				story["pos"] -= 1
				if not story_choices().is_empty():
					story["wait"] = "choice"
					return
				story["pos"] += 1
			"fx":
				if story_true(op["if"]):
					_story_fx(op["words"])
			"jump":
				if story_true(op["if"]):
					_story_jump(op["to"])
	_story_end()


func _compare(value: float, op: String, than: float) -> bool:
	match op:
		">=":
			return value >= than
		"<":
			return value < than
		">":
			return value > than
		"<=":
			return value <= than
	return false


func _story_jump(to: String) -> void:
	var sc: Dictionary = Dialogue.SCENES[story["id"]]
	story["pos"] = sc["ops"].size() if to == "end" else sc["labels"][to] + 1


# The choices you can make right now: [{"i", "ru", "en"}].
func story_choices() -> Array:
	var out: Array = []
	if story.is_empty():
		return out
	var ops: Array = Dialogue.SCENES[story["id"]]["ops"]
	if story["pos"] >= ops.size() or ops[story["pos"]]["op"] != "choices":
		return out
	var items: Array = ops[story["pos"]]["items"]
	for i in items.size():
		if story_true(items[i]["if"]):
			out.append({"i": i, "ru": items[i]["ru"], "en": items[i]["en"]})
	return out


func story_next() -> void:
	if phase != "story" or story.get("wait", "") != "line":
		return
	story["wait"] = ""
	_story_run()


func story_choose(i: int) -> void:
	if phase != "story" or story.get("wait", "") != "choice":
		return
	if not story_choices().any(func(c): return c["i"] == i):
		return
	var item: Dictionary = Dialogue.SCENES[story["id"]]["ops"][story["pos"]]["items"][i]
	story["log"].append({"who": "you", "emo": "", "ru": item["ru"], "en": item["en"]})
	# Every answer is remembered as <scene>:<where it led>, so later scenes can ask about it.
	flags["%s:%s" % [story["id"], item["to"]]] = true
	story["wait"] = ""
	_story_jump(item["to"])
	_story_run()


# What a scene can change: see docs/dialogues.md and data/dialogue_catalog.json.
const TALK_FX := ["dayoff", "lighten", "push", "sit", "initiative", "calm", "mention", "stretch", "promise", "learn", "visible", "confide", "thread"]
func _story_fx(words: Array) -> void:
	var w: Array = words.map(func(x): return convo.get("who", "") if x == "them" else x)
	if w[0] in TALK_FX:
		_talk_fx(w)
		return
	match w[0]:
		"flag":
			flags[w[1]] = true
		"unflag":
			flags.erase(w[1])
		"days":
			flags[w[1]] = day + int(w[2])
		"mood", "trust", "energy":
			if people.has(w[1]) and available(w[1]):
				people[w[1]][w[0]] += float(w[2])
				people[w[1]]["mood"] = clampf(people[w[1]]["mood"], -5.0, 5.0)
		"style":
			lead(w[1], float(w[2]))
		"boss":
			boss += float(w[1])
		"taras":
			taras_like(float(w[1]))
		"hangover":
			my_hangover = 1
		"interview":
			interview(w[1], true)
		"openings":
			openings += int(w[1])
			flags["asked_people"] = true
		"reveal":
			if people.has(w[1]):
				_reveal(w[1], w[2])
		"give":
			_story_give(w)
		"grab":
			_story_grab(w[1], int(w[2]))
		"drop":
			_story_drop(w[1], int(w[2]))
		"task":
			if C.TASKS.has(w[1]):
				add_task(w[1])
		"shrink":
			_story_shrink(w[1], float(w[2]))


# give <improvement or task id> <who> [helper <who>]: handed over right there in the conversation, no objections.
func _story_give(w: Array) -> void:
	var id: String = w[1]
	var p: String = w[2]
	if not available(p):
		return
	var t: Dictionary = {}
	for x in tasks:
		if (x["id"] == "init_" + id or x["id"] == id) and x["status"] == "inbox":
			t = x
	if t.is_empty():
		if C.IMPROVEMENTS.has(id) and not improved.has(id):
			t = _add_improvement(id)
		elif C.TASKS.has(id):
			add_task(id)
			t = tasks[tasks.size() - 1]
	if t.is_empty():
		return
	t["owner"] = p
	t["status"] = "active"
	t["assigned_day"] = day
	if w.size() >= 5 and w[3] == "helper" and available(w[4]) and w[4] != p:
		t["helper"] = w[4]


# grab <who> <N>: they took work on themselves overnight until they have N. Smallest waiting tasks first,
# then this morning's arrivals, then fresh ones from the deck, so the scene's "five" is really five.
func _story_grab(p: String, n: int) -> void:
	if not available(p):
		return
	var waiting := inbox()
	waiting.sort_custom(func(a, b): return a["size"] < b["size"])
	for t in waiting:
		if queue_of(p).size() >= n:
			return
		_story_take(t, p)
	while queue_of(p).size() < n and not arriving.is_empty():
		_story_take_new(arriving.pop_front(), p)
	var tries := 0
	while queue_of(p).size() < n and tries < 20:
		tries += 1
		if deck.size() < 4:
			_refill_deck()
		var id: String = deck.pop_front()
		if day + C.TASKS[id]["size"] - 1 <= last_day() and _improved_by("remove", id).is_empty() and _bank_here(id):
			_story_take_new(id, p)


func _story_take_new(id: String, p: String) -> void:
	var before := tasks.size()
	add_task(id)
	if tasks.size() > before:
		_story_take(tasks[tasks.size() - 1], p)


func _story_take(t: Dictionary, p: String) -> void:
	t["owner"] = p
	t["status"] = "active"
	t["assigned_day"] = day
	t["first"] = false


# drop <who> <N>: keep the N they've got furthest with, the rest go back to the inbox.
func _story_drop(p: String, n: int) -> void:
	# Late ones stay: they're already on Friday's review, and handing them over now helps nobody.
	var q := queue_of(p).filter(func(t): return not t["late"])
	q.sort_custom(func(a, b): return a["progress"] > b["progress"])
	for i in range(n, q.size()):
		unassign_now(q[i])


# shrink <task id> <factor>: the work turns out smaller than it looked (someone's docs, a hint on the phone).
# Applies to the open task and to one that hasn't arrived yet. "incident" means every open incident.
func _story_shrink(id: String, factor: float) -> void:
	var targets: Array = _open_incidents() if id == "incident" else tasks.filter(func(t): return t["id"] == id and t["status"] != "done")
	for t in targets:
		t["size"] = maxf(t["progress"] + 0.3, t["size"] * factor)
	if id != "incident":
		flags["shrink:" + id] = factor


func _open_incidents() -> Array:
	return tasks.filter(func(t): return t["status"] != "done" and C.TASKS.get(t["id"], {}).get("tags", []).has("incident"))


func _story_end() -> void:
	var who := ""
	for e in story["log"]:
		if e["who"] != "you" and e["who"] != "":
			who = e["who"]
			break
	var then: String = story.get("then", "")
	story = {}
	if who != "":
		history.append({"who": "", "key": "story.log", "args": [], "names": {"who": "@name.%s.ins" % who}, "day": day})
	if then == "":
		_open_morning()
	else:
		phase = then


# ---------- the morning stand-up ----------

# Every morning after any story scene, before the chat: everyone at work says one line, built from how they
# really are. Nobody says "I'm stuck" or "I'm worn out" in so many words; you hear it the way you would on a
# real call. One reaction is free, each next one costs attention.
const STANDUP_REACTIONS := {"stuck": "sit", "tired": "rest", "swamped": "lighten", "idle": "backlog", "done": "praise"}


func _open_standup() -> bool:
	if day == 1 or flags.get("standup_day", -1) == day or sick_today:
		return false
	flags["standup_day"] = day
	var lines: Array = []
	for p in team:
		if available(p) and not people[p]["absent"]:
			lines.append(_standup_line(p))
	if lines.is_empty():
		return false
	standup = {"lines": lines, "reacted": 0}
	_narrate("standup.log")
	phase = "standup"
	return true


func _standup_line(p: String) -> Dictionary:
	var q := queue_of(p)
	var line := {"who": p, "topic": "quiet", "uid": -1, "args": [], "names": {}, "reacted": false}
	for t in q:
		if t.get("pulled", -1) == day:
			line["topic"] = "pulled"
			line["uid"] = t["uid"]
			line["key"] = _own_key("standup.pulled", p)
			line["names"] = {"task": "@taskname." + t["id"]}
			return line
	for t in q:
		if t.get("stuck", 0) > 0:
			line["topic"] = "stuck"
			line["uid"] = t["uid"]
			line["key"] = _own_key("standup.stuck%d" % mini(2, t["stuck"]), p)
			line["names"] = {"task": "@taskname." + t["id"]}
			return line
	if _feels_tired(p):
		line["topic"] = "tired"
		line["key"] = _own_key("standup.tired", p)
		return line
	if q.size() >= OVERLOAD_AT:
		line["topic"] = "swamped"
		line["key"] = _own_key("standup.swamped", p)
		return line
	for t in tasks:
		if t["status"] == "done" and t["owner"] == p and t["done_day"] == day - 1 and (t["key"] or t["size"] >= 2.0):
			line["topic"] = "done"
			line["key"] = _own_key("standup.done", p)
			line["names"] = {"task": "@taskname." + t["id"]}
			return line
	if q.is_empty():
		# Sitting without work since yesterday is worth saying; this morning's empty plate isn't.
		if people[p]["idle_days"] >= 1:
			line["topic"] = "idle"
			line["key"] = _own_key("standup.idle", p)
		else:
			line["key"] = _own_key("standup.ready", p)
		return line
	line["key"] = _own_key("standup.quiet", p)
	line["names"] = {"task": "@taskname." + q[0]["id"]}
	return line


func _own_key(key: String, p: String) -> String:
	return key + "." + p if L.has_key(key + "." + p) else key


# What you can say to this line, or "" if there's nothing to do about it.
func standup_reaction(i: int) -> String:
	var all := standup_reactions(i)
	return all[0] if not all.is_empty() else ""


# Someone who grabbed a card can be thanked for it or have it taken back; saying nothing lets it stand.
func standup_reactions(i: int) -> Array:
	if phase != "standup" or i < 0 or i >= standup["lines"].size():
		return []
	var line: Dictionary = standup["lines"][i]
	if line["reacted"] or not available(line["who"]):
		return []
	if line["topic"] == "pulled":
		return ["praise_pull", "take_back"] if not task(line["uid"]).is_empty() else []
	var r: String = STANDUP_REACTIONS.get(line["topic"], "")
	if r == "backlog" and backlog().is_empty():
		return []
	if r == "sit" and task(line["uid"]).is_empty():
		return []
	return [r] if r != "" else []


func standup_cost() -> bool:
	return endless() or standup.get("reacted", 0) > 0


func standup_react(i: int, r: String = "") -> void:
	var options := standup_reactions(i)
	if r == "":
		r = options[0] if not options.is_empty() else ""
	if not options.has(r):
		return
	var line: Dictionary = standup["lines"][i]
	var p: String = line["who"]
	if standup_cost():
		if not can_afford(cost("react")):
			return
		spend_attention(cost("react"))
	standup["reacted"] += 1
	line["reacted"] = true
	line["said"] = r
	history.append({"who": "you", "key": "standup.say." + r, "args": [], "names": line["names"], "to": p, "day": day})
	match r:
		"sit":
			# The same as sitting down with them over it: it gets unstuck, and you were personally involved.
			var t := task(line["uid"])
			t["sit_today"] = true
			t["involved"] = true
			my_week_mgmt[week()] += 2
			lead("P", 0.3)
			lead("I", 0.3)
		"rest":
			give_day_off(p)
			lead("I", 0.5)
		"lighten":
			lighten(p)
			lead("A", 0.3)
		"backlog":
			var t: Dictionary = backlog()[0]
			if not t.get("started", false):
				t["started"] = true
				lead("E", 0.7)
			t["owner"] = p
			t["status"] = "active"
			t["assigned_day"] = day
		"praise":
			people[p]["mood"] = clampf(people[p]["mood"] + 0.3, -5.0, 5.0)
			lead("I", 0.3)
		"praise_pull":
			_nudge_pull(p, PULL_PRAISE)
			people[p]["mood"] = clampf(people[p]["mood"] + 0.3, -5.0, 5.0)
			lead("E", 0.3)
		"take_back":
			unassign_now(task(line["uid"]))
			_nudge_pull(p, PULL_SCOLD)
			people[p]["mood"] = clampf(people[p]["mood"] - 0.5, -5.0, 5.0)
			# Everyone on the call saw it.
			for q in team:
				if q != p and available(q):
					_nudge_pull(q, PULL_FEAR)
			lead("A", 0.5)
	line["reply"] = _own_key("standup.reply." + r, p)
	_say(p, line["reply"], [], line["names"])


func standup_close() -> void:
	if phase != "standup":
		return
	# Saying nothing about a grabbed card is saying it's fine.
	for line in standup["lines"]:
		if line["topic"] == "pulled" and not line["reacted"]:
			_nudge_pull(line["who"], PULL_SILENCE)
	standup = {}
	_open_morning()


# ---------- planning ----------

func task(uid: int) -> Dictionary:
	for t in tasks:
		if t["uid"] == uid:
			return t
	return {}


func inbox() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in tasks:
		if t["status"] == "inbox" and not t.get("backlog", false):
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
	return team.has(p) and not people[p]["gone"]


func assign(uid: int, p: String) -> void:
	var t := task(uid)
	if phase != "plan" or not pending.is_empty() or t.is_empty() or t["status"] == "done" or t["status"] == "taras" or p == t["owner"] or not can_assign(t):
		return
	_tip_used("inbox")
	var previous: String = t["owner"]
	if p == "taras":
		if not endless():
			_hand_to_taras(t)
		return
	if p != "me" and not available(p):
		return
	if p != "me" and only_me(t):
		return
	if not can_afford(cost("assign")):
		return
	spend_attention(cost("assign"))
	var names := {"task": "@taskname." + t["id"]}
	if p != "me":
		history.append({"who": "you", "key": "assign.say", "args": [], "names": names, "to": p, "day": day})
	if team.has(previous) and t["progress"] > 0.0 and not people[previous]["gone"]:
		people[previous]["mood"] -= 0.5
		_say(previous, "taken_away", [], names)
	_check_commitments(t, p)
	var reason := _objection(p, t) if p != "me" else ""
	# Starting an improvement nobody asked for is changing how things are done.
	if t.get("backlog", false) and not t.get("started", false):
		t["started"] = true
		lead("E", 0.7)
	t["owner"] = p
	t["status"] = "active"
	t["assigned_day"] = day
	t["first"] = false
	if t["helper"] == p:
		t["helper"] = ""
	if p == "me":
		lead("P", 2.0)
		_say("", "you.myself_note", [], names)
		for q in team:
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
		for q in team:
			if flags.has("stretch_" + q) and available(q):
				flags.erase("stretch_" + q)
				if q == p:
					people[q]["trust"] += 1
				else:
					people[q]["trust"] -= 2
					people[q]["mood"] -= 1.0
					_say(q, "talk.stretch.broken", [], names)
	if team.has(p) and flags.get("calm_" + p, 0) >= day and t["due"] - day <= 1:
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
	if info(p)["hates"].has(t["cat"]):
		return "hates"
	if info(p)["drive"] == "peace" and t["due"] - day <= 1:
		return "rush"
	if st["skills"][t["cat"]] <= 1 and info(p)["drive"] != "growth":
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
	var drive: String = info(p)["drive"]
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
	if info(p)["likes"].has(t["cat"]):
		delta += 1.0
	if info(p)["hates"].has(t["cat"]):
		delta -= 1.0
	if p == "vika" and t["public"]:
		delta += 1.0
	if leans("I"):
		delta += 0.4
	if delta < 0.0 and info(p).get("touchy", false):
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
	if phase != "plan" or t.is_empty() or t["status"] != "active" or not team.has(t["owner"]) or not allowed("prioritize"):
		return
	var p: String = t["owner"]
	var head: Dictionary = queue_of(p)[0]
	if head["uid"] == uid:
		return
	for other in queue_of(p):
		other["first"] = false
	t["first"] = true
	lead("A", 0.3)
	flags["ordered_w%d" % week()] = true
	if head["progress"] > 0.0:
		people[p]["mood"] = clampf(people[p]["mood"] - 0.3, -5.0, 5.0)
	history.append({"who": "you", "key": "prioritize.say", "args": [], "names": {"task": "@taskname." + t["id"]}, "to": p, "day": day})
	_say(p, _first_key(["prioritize.reply." + p, "prioritize.reply"]))


func set_helper(uid: int, p: String) -> void:
	var t := task(uid)
	if phase != "plan" or t.is_empty() or t["status"] != "active" or p == t["owner"] or (p != "" and not available(p)) or not allowed("pair"):
		return
	if flags.has("no_pair_alex_vika") and [p, t["owner"]].has("alex") and [p, t["owner"]].has("vika"):
		_say("alex", "helper.no_vika")
		return
	if p != "" and t["owner"] == "alex" and flags.has("alex_alone"):
		_say("alex", "helper.alex_alone")
		return
	if p != "":
		if not can_afford(cost("pair")):
			return
		spend_attention(cost("pair"))
	t["helper"] = p
	if p != "":
		lead("I", 0.2)
		_say(p, "helper.join", [], {"task": "@taskname." + t["id"], "owner": "@name.%s.nom" % t["owner"]})


func unassign(uid: int) -> void:
	var t := task(uid)
	if phase != "plan" or t.is_empty() or t["status"] != "active" or not can_assign(t):
		return
	unassign_now(t)


func unassign_now(t: Dictionary) -> void:
	t["owner"] = ""
	t["helper"] = ""
	t["status"] = "inbox"
	t["first"] = false


# A one-on-one: one attention, a sitting in the conversation window (see "one-on-ones" above).
func start_talk(p: String) -> void:
	if not can_talk(p):
		return
	talked[p] = true
	flags["talks_w%d" % week()] = flags.get("talks_w%d" % week(), 0) + 1
	_tip_used("talk")
	lead("I", 0.3)
	spend_attention(cost("talk"))
	history.append({"who": "you", "key": "talk.open", "args": [], "names": {}, "to": p, "day": day})
	_open_talk(p)


# Going to Irina: one visit a day, one topic per visit.
func visit_boss() -> void:
	if not can_visit():
		return
	visited_today = true
	spend_attention(cost("boss"))
	history.append({"who": "you", "key": "visit.open", "args": [], "names": {}, "day": day})
	_open_conversation(scenes.boss_visit(self))


# Going in is free in the endless run, but there's no point without a word to say.
func can_visit() -> bool:
	return phase == "plan" and pending.is_empty() and not visited_today and can_afford(maxi(cost("boss"), cost("reply")))


func _open_conversation(ev: Dictionary) -> void:
	ev.merge({"names": {}, "uid": -1}, false)
	events.push_front(ev)
	_say_event_lines()
	phase = "event"


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
	return choice_cost(ev, choice) > 0


# The evening scenes say what each answer takes; the rest take one point or none.
const EVENING_COSTS := {"stayed_late/send_home": 1, "stayed_late/stay_with": 2, "conflict/mediate": 2, "conflict/split": 1, "complaint/apologize": 1}


func _visit_event(ev: Dictionary) -> bool:
	return ev["id"].begins_with("boss_visit") or ev["id"] == "boss_show"


func choice_cost(ev: Dictionary, choice: String) -> int:
	var key: String = ev["id"] + "/" + choice
	if endless() and _visit_event(ev):
		return 0 if choice == "leave" else cost("reply")
	if EVENING_COSTS.has(key):
		return EVENING_COSTS[key]
	return 1 if _old_choice_costs(ev, choice) else 0


func _old_choice_costs(ev: Dictionary, choice: String) -> bool:
	if ev.has("comp"):
		var fx: Dictionary = C.COMPLICATIONS[ev["comp"]]["choices"].get(choice, {})
		return fx.get("hours", 0) > 0
	return ["dima_mistake/help", "marina_warns/listen", "vika_promise_check/do_now"].has(ev["id"] + "/" + choice)


func can_talk(p: String) -> bool:
	return phase == "plan" and pending.is_empty() and allowed("talk") and can_afford(cost("talk")) and convo.is_empty() and not talked.has(p) and available(p) and not people[p]["absent"]


# Every bit of managing costs attention; past the day's points you're borrowing from tomorrow.
func spend_attention(n: int = 1) -> void:
	for i in n:
		if attention > 0:
			attention -= 1
		else:
			overtime_today += 1


# What each action takes in the endless run. The story keeps its old prices: one point for managing,
# and handing out work is free.
# Opening a conversation (a one-on-one, Irina's door) is free in the endless run; each thing you say in it is a reply.
const COSTS := {"pitch": 2, "buy": 1, "assign": 1, "pair": 1, "decline": 1, "react": 1, "sit": 2, "talk": 0, "intervene": 1, "boss": 0, "reply": 1, "people": 2, "interview": 2, "fire": 2}
const FREE_IN_STORY := ["assign", "pair", "decline", "reply"]


func cost(kind: String) -> int:
	if not endless():
		return 0 if kind in FREE_IN_STORY else 1
	return COSTS[kind]


# How much you may borrow from tomorrow in one day.
func borrow_cap() -> int:
	return ceili(C.PROFILES[profile]["attention"] * (2 if endless() else 1) / 2.0) + int(perk_add("borrow"))


func can_afford(n: int) -> bool:
	return not sick_today and n <= attention + borrow_cap() - overtime_today


# Nothing left to give today, borrowing included: in the endless run the day goes on without you.
func spent_out() -> bool:
	return endless() and (sick_today or (attention <= 0 and overtime_today >= borrow_cap()))


# Called after every action: once you're spent out and nothing is waiting on you, the day ends.
func auto_end_day() -> bool:
	if phase != "plan" or not spent_out() or not pending.is_empty() or not convo.is_empty():
		return false
	_narrate("you.spent_out")
	end_day()
	return true


func own_task_cost() -> int:
	return ceili(max_attention() / 2.0) if endless() else OWN_TASK_COST


# Sit down with someone over their task today: it goes faster and better, they learn, and you were
# personally involved (which makes "under my personal control" true at the review).
func sit_with(uid: int) -> void:
	var t := task(uid)
	if phase != "plan" or not pending.is_empty() or t.is_empty() or t["status"] != "active" or t.get("sit_today", false) or not allowed("sit"):
		return
	var p: String = t["owner"]
	if not team.has(p) or not available(p) or people[p]["absent"] or not can_afford(cost("sit")):
		return
	spend_attention(cost("sit"))
	lead("P", 0.5)
	lead("I", 0.5)
	my_week_mgmt[week()] += 2
	t["sit_today"] = true
	t["involved"] = true
	history.append({"who": "you", "key": "sit.say", "args": [], "names": {"task": "@taskname." + t["id"]}, "to": p, "day": day})
	if info(p)["drive"] == "craft" and people[p]["skills"][t["cat"]] >= 3:
		people[p]["mood"] -= 0.5
		_say(p, "sit.micro")
	else:
		people[p]["mood"] += 0.5
		_say(p, "sit.ok")


# Step into someone's task: ask how it's going and steer it (see scenes.gd intervene). Once a day per task.
func intervene(uid: int) -> void:
	var t := task(uid)
	if phase != "plan" or not pending.is_empty() or t.is_empty() or t["status"] != "active" or t.get("checked_day", 0) == day or not allowed("intervene"):
		return
	_tip_used("active")
	var p: String = t["owner"]
	if not team.has(p) or not available(p) or people[p]["absent"]:
		return
	# Looking closely at a faker's task shows how far it really got.
	_expose_faker(t)
	t["checked_day"] = day
	spend_attention(cost("intervene"))
	history.append({"who": "you", "key": "intervene.open", "args": [], "names": {"task": "@taskname." + t["id"]}, "to": p, "day": day})
	_open_conversation(scenes.intervene_event(self, t))


func can_intervene(t: Dictionary) -> bool:
	return phase == "plan" and pending.is_empty() and allowed("intervene") and can_afford(cost("intervene")) and t["status"] == "active" and team.has(t["owner"]) and available(t["owner"]) \
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
	if phase != "plan" or not allowed("initiative") or not offer_today.has(p) or not available(p) or people[p]["absent"] or not queue_of(p).is_empty():
		return ""
	for t in tasks:
		if t["status"] == "active" and t["helper"] == p:
			return ""
	var list: Array = C.INITIATIVES.get(p, [])
	var i := _initiative_index(p)
	return list[i] if i < list.size() else ""


# Where in their list they are: past what they've offered and had taken up, and past what's already done.
func _initiative_index(p: String) -> int:
	var list: Array = C.INITIATIVES.get(p, [])
	var i: int = init_next.get(p, 0)
	while i < list.size() and _initiative_done(list[i], p):
		i += 1
	return i


func _initiative_done(id: String, p: String) -> bool:
	if id == "showcase":
		return false
	if id == "self_study":
		return study_target(p) == "" # nothing left they'd learn on their own
	return flags.has("init_" + id) or tasks.any(func(t): return t["id"] == "init_" + id and t["owner"] != "")


# What someone would study on their own: their weakest category, while it's still below confident.
func study_target(p: String) -> String:
	var weakest := ""
	for cat in C.CATEGORIES:
		if weakest == "" or people[p]["skills"][cat] < people[p]["skills"][weakest]:
			weakest = cat
	return weakest if people[p]["skills"][weakest] < 3 else ""


func accept_initiative(p: String) -> void:
	var id := initiative_offer(p)
	if id == "" or not pending.is_empty():
		return
	init_next[p] = _initiative_index(p) + 1
	for pair in INIT_STYLE.get(id, []):
		lead(pair[0], pair[1])
	flags["init_" + id] = true
	# An improvement they take from the backlog, or put there and take; anything else is just theirs.
	var t: Dictionary = {}
	for b in backlog():
		if b["id"] == "init_" + id:
			t = b
	if t.is_empty() and C.IMPROVEMENTS.has(id):
		t = _add_improvement(id)
	if t.is_empty():
		var info: Dictionary = C.INIT_TASKS[id]
		add_task_raw("init_" + id, info["cat"], info["size"], NO_DEADLINE, false, p)
		t = tasks[tasks.size() - 1]
		if id == "self_study":
			# What they'll study is settled when they start: their weakest thing at the time.
			t["study"] = study_target(p)
			t["cat"] = t["study"]
	t["owner"] = p
	t["status"] = "active"
	t["assigned_day"] = day
	history.append({"who": "you", "key": "init.yes", "args": [], "names": {}, "to": p, "day": day})
	var drive: String = info(p)["drive"]
	people[p]["mood"] = clampf(people[p]["mood"] + (1.5 if drive == "craft" or drive == "growth" else 1.0), -5.0, 5.0)
	_say(p, "react.%s.pos" % p)


# An initiative is finished: it changes the decks or the people.
func _initiative_effect(t: Dictionary) -> void:
	var id: String = t["id"].trim_prefix("init_")
	var names := {"who": "@name.%s.nom" % t["owner"]}
	if C.IMPROVEMENTS.has(id):
		_improve(id)
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
			var target: String = t.get("study", study_target(t["owner"]))
			if target != "":
				learn(t["owner"], target, 4.0)
				names["cat"] = "@cat." + target
		"write_docs":
			comp_off["missing_docs"] = true
			comp_off["old_system"] = true
	if L.has_key("init.done." + id): # improvements have said their piece in _improve
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
		_narrate("know.drive", [], {"who": "@name.%s.nom" % p, "drive": "@drive." + info(p)["drive"]})
	else:
		var cat := key.replace("skill.", "")
		_narrate("know.skill", [], {"who": "@name.%s.nom" % p, "cat": "@cat." + cat, "level": "@level.%d" % people[p]["skills"][cat]})


# ---------- the day's work ----------

func _share_help() -> void:
	shares.clear()
	for t in tasks:
		var share := help_share(t)
		if share > 0.0:
			shares[t["uid"]] = share


# The morning half of the day's work, so midday shows who's moving and who isn't.
func _half_day() -> void:
	flags["half_day"] = day
	_share_help()
	for p in team:
		_work(p, 0.5, false)
	_work_myself(0.5, false)
	shares.clear()


func end_day() -> void:
	if phase != "plan" or not pending.is_empty():
		return
	flags.erase("tip_hl")
	# Skipped straight past the morning: whatever broke out today came in all the same, and the team
	# shared out the work as it saw fit.
	if endless() and step == "triage":
		step = "work"
		_deliver_arrivals()
		_team_picks()
	evening_from = history.size()
	_narrate("log.evening")
	if endless():
		_expire_letters(["triage", "work"])
	_alex_nights()
	_share_help()
	var part: float = 0.5 if flags.get("half_day", -1) == day else 1.0
	for p in team:
		_work(p, part)
	_work_myself(part)
	for t in tasks:
		t["sit_today"] = false
		if t["blocked"] > 0:
			t["blocked"] -= 1
	_end_of_my_day()
	if endless():
		_taras_day()
		_upgrade_progress()
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
		# Improvements and initiatives have no real deadline.
		if (t["status"] == "inbox" or t["status"] == "active") and t["due"] == day and not t["late"] and not t["id"].begins_with("init_"):
			_expose_faker(t)
			t["late"] = true
			t["late_day"] = day
			_late(t)
			if endless():
				_penalty(t)
			if t["vouched"]:
				boss -= 1
				_say("boss", "boss.vouched_late", [], {"task": "@taskname." + t["id"]})
	_advance_chains()
	_layoff_deadline()
	_check_lies()
	for p in team:
		_check_person(p)
	if team.has("palych") and available("palych") and not people["palych"]["absent"]:
		for q in team:
			if q != "palych" and available(q):
				people[q]["mood"] = clampf(people[q]["mood"] + PLODDER_WARMTH, -5.0, 5.0)
	_weight_check()
	if C.SURVEY_AT.has(chapter_day()):
		_run_survey()
	if day % 5 == 0:
		if endless():
			_payday()
		_style_week()
		_build_review()
		if review.is_empty():
			_narrate("review.empty")
		phase = "report"
	else:
		phase = "evening"
	if endless():
		step = "evening"
		scenes.queue(self, "evening")
		_post_letters()
	# An evening conversation comes before the day's summary.
	_queue_story("evening")


# Staying late wears you down; rest days bring you back. Run yourself into the ground and you're
# off sick tomorrow, and the team works without you.
func _end_of_my_day() -> void:
	if overtime_today > 0:
		flags["borrowed_p%d" % period] = true
	debt = overtime_today
	debt_days = debt_days + 1 if debt > 0 else 0
	if debt_days >= BURNOUT_DEBT_DAYS:
		my_sick = 1
		debt = 0
		debt_days = 0
		_narrate("you.burnout")
		flags[burnout_key()] = flags.get(burnout_key(), 0) + 1
		# One short of quitting: the body says so first.
		if flags[burnout_key()] == burnouts_to_quit() - 1:
			_narrate("you.burnout_warning_run" if endless() else "you.burnout_warning")
	# Untouched tech debt makes itself felt: each Friday another outage goes into the deck.
	if day % 5 == 0 and day < last_day() and not flags.has("tech_debt_done"):
		var fires := C.tasks_with("tag", "debt").filter(func(id): return _improved_by("remove", id).is_empty())
		if not fires.is_empty():
			deck.insert(mini(2, deck.size()), fires[rng.randi() % fires.size()])
			_narrate("deck.neglect_tech")


const OWN_TASK_COST := 2
const BURNOUT_DEBT_DAYS := 3 # start this many days in a row in debt and you're off sick


# How you're holding up: days in a row you've run on tomorrow's points, today included.
func my_state() -> String:
	var strain := debt_days + (1 if overtime_today > 0 else 0)
	return ["fresh", "ok", "tired", "drained"][mini(strain, 3)]


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
	# In the endless run the penalty's own line says what slipped and what it cost: one message, not two.
	var told := endless() and not penalty_of(t).is_empty()
	if t["public"] or t["from"] == "boss":
		boss -= 2.0 if t["key"] else 1.0
		merit -= 1.0
		weight_cause = t["id"]
		if not told:
			_narrate("late.key" if t["key"] else "late", [], names)
		return
	var who: String = t["from"]
	flags["complaints_" + who] = flags.get("complaints_" + who, 0) + 1
	if not told:
		_say(who, "late.complain.%s" % who, [], names)
	if flags["complaints_" + who] == 2:
		boss -= 1
		_narrate("late.escalated", [], {"who": "@name.%s.nom" % who, "who_gen": "@name.%s.gen" % who})


# ---------- the upgrade tree ----------

const UPGRADE_DECK_AHEAD := 6 # a bought upgrade's cards are shuffled into the next this many of the deck


func upgrade_state(id: String) -> String:
	if upgrades.has(id):
		return upgrades[id]["state"]
	for r in C.UPGRADES[id]["requires"]:
		if upgrade_state(r) != "done":
			return "locked"
	return "open"


func upgrade_price(id: String) -> int:
	return int(round(C.UPGRADES[id]["price"] * (1.0 - C.PROFILES[profile].get("upgrade_discount", 0.0))))


func can_buy(id: String) -> bool:
	return endless() and phase == "plan" and pending.is_empty() and upgrade_state(id) == "open" \
		and money >= upgrade_price(id) and can_afford(cost("buy"))


func buy_upgrade(id: String) -> void:
	if not can_buy(id):
		return
	var up: Dictionary = C.UPGRADES[id]
	spend_attention(cost("buy"))
	money -= upgrade_price(id)
	upgrades[id] = {"state": "building", "done": []}
	_apply_effects(up["start"])
	for card in up["cards"]:
		deck.insert(rng.randi_range(0, mini(UPGRADE_DECK_AHEAD, deck.size())), card)
	history.append({"who": "you", "key": "up.bought", "args": [cash_arg(upgrade_price(id))], "names": {"up": "@up.%s.name" % id}, "day": day})


# How far its rollout has got: implementation cards done well enough, out of all of them.
func upgrade_done_count(id: String) -> int:
	return upgrades.get(id, {}).get("done", []).size()


# Implementation cards finished today: done badly, one goes back in the deck; all done, the upgrade works.
func _upgrade_progress() -> void:
	for t in tasks:
		if t["status"] != "done" or t.get("up_counted", false) or not t["id"].begins_with("up_"):
			continue
		t["up_counted"] = true
		var id: String = t["id"].substr(3, t["id"].rfind("_") - 3)
		if not upgrades.has(id):
			continue
		if t["quality"] == "bad":
			deck.insert(rng.randi_range(0, mini(UPGRADE_DECK_AHEAD, deck.size())), t["id"])
			_narrate("up.redo", [], {"task": "@taskname." + t["id"]})
			continue
		if not upgrades[id]["done"].has(t["id"]):
			upgrades[id]["done"].append(t["id"])
		if upgrades[id]["state"] == "building" and upgrades[id]["done"].size() >= C.UPGRADES[id]["cards"].size():
			_complete_upgrade(id)


func _complete_upgrade(id: String) -> void:
	var up: Dictionary = C.UPGRADES[id]
	upgrades[id]["state"] = "done"
	_apply_effects(up["final"])
	flags["up_done_p%d" % period] = true
	boss += 0.3
	var old: String = up["replaces"]
	if old != "" and C.UPGRADES.has(old):
		for card in C.UPGRADES[old]["maint"]:
			upkeep.erase(card)
			deck.erase(card)
	for card in up["maint"]:
		upkeep.append(card)
		deck.insert(rng.randi_range(0, deck.size()), card)
	_narrate("up.done", [], {"up": "@up.%s.name" % id})


func _apply_effects(effects: Array) -> void:
	for e in effects:
		match e["kind"]:
			"money":
				money += int(e["value"])
			"clean":
				# Only what missed deadlines added goes; the deck's own copies stay.
				for target in e["targets"]:
					var gone: Array = curses.filter(func(c): return C.covers(target, c))
					curses = curses.filter(func(c): return not C.covers(target, c))
					for c in gone:
						deck.erase(c)
				_narrate("up.cleaned")
			_:
				perks.append(e)


# Multiplying effects (speed, freq, learn, newbie) for this kind of work, or all of it.
func perk_mult(kind: String, cat: String = "") -> float:
	var m := 1.0
	for e in perks:
		if e["kind"] == kind and (e["cat"] == "" or e["cat"] == cat):
			m *= e["value"]
	return m


func perk_add(kind: String, cat: String = "") -> float:
	var sum := 0.0
	for e in perks:
		if e["kind"] == kind and (e["cat"] == "" or e["cat"] == cat):
			sum += e["value"]
	return sum


# Fewer cards of a kind come in: each draw of one is let through only so often.
func _freq_ok(id: String) -> bool:
	var m := perk_mult("freq", C.TASKS[id]["cat"])
	return m >= 1.0 or rng.randf() < m


func _automated(id: String) -> bool:
	return not _improved_by("remove", id).is_empty() or not _freq_ok(id)


# Work the platform did for you counts in the race as if the team had done it decently.
func _automation_credit(id: String) -> void:
	var key := "auto_points_%d" % period
	flags[key] = flags.get(key, 0.0) + C.TASKS[id]["size"] * QUALITY_POINTS["ok"]
	flags["auto_today"] = flags.get("auto_today", 0) + 1
	# Taras counts these as work that came in.
	if flags.get("auto_day", -1) != day:
		flags["auto_day"] = day
		flags["auto_size"] = 0.0
	flags["auto_size"] += C.TASKS[id]["size"]


# ---------- the run's record ----------

# Months the endless run has got through.
func done_periods() -> int:
	return period - 1 + (1 if phase == "chapter_end" else 0)


func run_stats() -> Dictionary:
	var done := tasks.filter(func(t): return t["status"] == "done" and not t["id"].begins_with("up_"))
	return {
		"periods": done_periods(), "days": day,
		"done": done.size(), "good": done.filter(func(t): return t["quality"] == "good").size(),
		"late": tasks.filter(func(t): return t["late"]).size(),
		"hired": team.size(), "quit": quits, "fired": flags.get("stat_fired", 0),
		"upgrades": upgrades.values().filter(func(u): return u["state"] == "done").size(),
		"race_wins": flags.get("race_wins", 0),
	}


# The achievements this run has earned so far (the endless run only); the game keeps them across runs.
const ACHIEVEMENTS := ["first_period", "five_periods", "ten_periods", "clean_period", "beat_taras", "taras_streak",
	"clean_week", "self_org", "branch_done", "openshift", "rich"]


func run_achievements() -> Array:
	if not endless():
		return []
	var out: Array = []
	var n := done_periods()
	if n >= 1:
		out.append("first_period")
	if n >= 5:
		out.append("five_periods")
	if n >= 10:
		out.append("ten_periods")
	for f in ["clean_period", "clean_week", "self_org"]:
		if flags.has(f):
			out.append(f)
	if flags.get("race_wins", 0) >= 1:
		out.append("beat_taras")
	if flags.get("race_streak", 0) >= 3:
		out.append("taras_streak")
	for b in C.UPGRADE_BRANCHES:
		var ids: Array = C.UPGRADES.keys().filter(func(id): return C.UPGRADES[id]["branch"] == b)
		if ids.all(func(id): return upgrade_state(id) == "done"):
			out.append("branch_done")
			break
	if upgrade_state("openshift") == "done":
		out.append("openshift")
	if money >= 5000:
		out.append("rich")
	return out


# ---------- penalties ----------

const PENALTY_RACE := 2.0 # points off per day of work in a card Irina was waiting for
const CALL_SIZE := 0.5


# What missing this card's deadline costs, as written on it: {"kind", "amount"}, or {} for nothing.
func penalty_of(t: Dictionary) -> Dictionary:
	var text: String = C.TASKS.get(t["id"], {}).get("penalty", "")
	if text == "" or not endless():
		return {}
	var parts := text.split(":")
	return {"kind": parts[0], "amount": int(parts[1]) if parts.size() > 1 else 0}


func _penalty(t: Dictionary) -> void:
	var pen := penalty_of(t)
	if pen.is_empty():
		return
	var names := {"task": "@taskname." + t["id"], "who": "@name.%s.nom" % t["from"]}
	match pen["kind"]:
		"boss":
			flags["race_penalty_%d" % period] = flags.get("race_penalty_%d" % period, 0.0) + PENALTY_RACE * t["size"]
			boss -= 0.5
			_narrate("penalty.boss.hit", [], names)
		"call":
			add_task_raw("escalation_call", "support", CALL_SIZE, day + 1, false, t["from"])
			_say(t["from"] if t["from"] != "product" else "boss", "penalty.call.hit", [], names)
		"incident":
			var fires := C.tasks_with("tag", "incident")
			if not fires.is_empty():
				chain_due.append({"id": fires[rng.randi() % fires.size()], "day": day + 1})
			_narrate("penalty.incident.hit", [], names)
		"debt":
			var debts := C.tasks_with("tag", "debt").filter(func(id): return _improved_by("remove", id).is_empty())
			if not debts.is_empty():
				var id: String = debts[rng.randi() % debts.size()]
				curses.append(id)
				deck.insert(rng.randi_range(0, deck.size()), id)
				names["fire"] = "@taskname." + id
			_narrate("penalty.debt.hit", [], names)
		"money":
			money -= pen["amount"]
			_narrate("penalty.money.hit", [cash_arg(pen["amount"])], names)


func only_me(t: Dictionary) -> bool:
	return C.TASKS.get(t["id"], {}).get("tags", []).has("only_me")


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
	if team.has(t["owner"]) and t["progress"] > 0.0:
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


# Chapter 4, after the one who stood in for him was cut: Alex works nights, alone, on his first task.
func _alex_nights() -> void:
	if not flags.has("alex_alone") or not available("alex") or people["alex"]["absent"]:
		return
	var q := queue_of("alex")
	if q.is_empty():
		return
	for t in q:
		t["helper"] = ""
	people["alex"]["energy"] -= 0.3
	q[0]["progress"] = minf(q[0]["size"], q[0]["progress"] + 0.3)


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
	s *= tools_factor(p) * perk_mult("speed", t["cat"])
	if t["id"].begins_with("up_"):
		s *= C.PROFILES[profile].get("rollout", 1.0)
	if archetype(p) == "plodder":
		s *= PLODDER_PACE
	var share: float = shares.get(t["uid"], 0.0)
	# New people are slow at first, unless someone who knows the work sits with them.
	if day - st["joined"] < NEWBIE_DAYS * perk_mult("newbie") and not (share > 0.0 and people.has(t["helper"]) and people[t["helper"]]["skills"][t["cat"]] >= 2):
		s *= 0.5
	if share > 0.0 and people.has(t["helper"]):
		var hs: int = people[t["helper"]]["skills"][t["cat"]]
		if hs > skill:
			s += share * 0.5 * (SPEED_BASE + SPEED_PER_SKILL * hs)
		elif hs < skill:
			s *= 1.0 - 0.15 * share # explaining takes time
		else:
			s += share * 0.3 * (SPEED_BASE + SPEED_PER_SKILL * hs)
		# The first time he asks for it himself, he actually listens.
		if p == "alex" and flags.has("alex_asks_help"):
			s *= 1.1
	return s


# The team's new tools (the AI assistant from Alex, then every finished improvement) speed up whoever uses
# them. Gena sticks to vim unless he's made to switch, and for the first days after that he's slower, not faster.
const TOOLS_BASE := 0.1
const TOOLS_PER_IMPROVEMENT := 0.03
const TOOLS_MAX := 0.25
const GENA_SWITCH_DAYS := 3


func tools_factor(p: String) -> float:
	if not flags.has("team_tools"):
		return 1.0
	if p == "gena":
		if not flags.has("gena_tools"):
			return 1.0
		if day < flags.get("gena_slow_until", 0):
			return 0.7
	return 1.0 + minf(TOOLS_MAX, TOOLS_BASE + TOOLS_PER_IMPROVEMENT * improved.size())


# How much of the helper's day goes to this task: all of it if they have nothing of their own,
# half if they do. Someone listed as helper on several tasks only helps with the first.
func help_share(t: Dictionary) -> float:
	var h: String = t["helper"]
	if t["status"] != "active" or h == "" or not team.has(t["owner"]) or not available(h) or people[h]["absent"]:
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
	if team.has(who) and people[who]["known"].has("skill." + t["cat"]):
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


# The day's work comes in two halves in endless: the morning's progress shows at midday, and the
# evening adds the rest and everything that belongs to the whole day (tiredness, hours, idling).
func _work(p: String, part: float = 1.0, upkeep: bool = true) -> void:
	var st: Dictionary = people[p]
	if st["gone"]:
		return
	if st["absent"] and not upkeep:
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
	# Whatever of the morning went unused (nothing to do yet) carries over to the afternoon, so a card
	# handed out at midday still gets the day's work.
	var base: float = (1.0 - help_part) * meeting * part
	if upkeep and part < 1.0:
		base += st.get("morning_left", 0.0)
	if not q.is_empty():
		# The day is spent down the queue: whatever's left after finishing one task goes to the next.
		# Half of it goes to the pair if they're helping someone.
		var first: Dictionary = q[0]
		var late := late_hours(p)
		var time := base + (late / 8.0 if upkeep else 0.0)
		var stuck: Array = []
		for t in q:
			if time < 0.05:
				break
			if t["blocked"] > 0:
				stuck.append(t)
				continue
			var skill: int = st["skills"][t["cat"]]
			if _stuck_today(p, t, skill, upkeep):
				time = 0.0
				continue
			var step := _speed(p, t) * (1.2 if t["sit_today"] else 1.0)
			var told := step
			if archetype(p) == "faker":
				# Reports a normal day's work; does a third of it, and gets stuck just short of "done".
				# A warning scares them into doing some real work.
				step *= FAKER_PACE * (2.0 if warned(p) else 1.0)
				t["claimed"] = minf(t["size"] * 0.95, maxf(t.get("claimed", 0.0), t["progress"]) + told * minf(time, 1.0))
			var spend := minf(time, (t["size"] - t["progress"]) / step)
			time -= spend
			t["progress"] += step * spend
			t["gain_today"] = t.get("gain_today", 0.0) + (told if archetype(p) == "faker" and not t.get("exposed", false) else step) * spend
			var quality: float = skill + st["mood"] * 0.1 + rng.randf_range(-0.7, 0.7) + perk_add("quality", t["cat"])
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
			if info(p)["likes"].has(t["cat"]):
				st["mood"] += 0.3 * spend
			if info(p)["hates"].has(t["cat"]):
				st["mood"] -= 0.25 * spend
			if t["progress"] >= t["size"] - 0.001:
				_finish(p, t)
			elif upkeep:
				# How far they got today, relative to the task: the main way to read someone's skill.
				var got: float = t["gain_today"] / t["size"]
				var pace := "big" if got >= 0.45 else ("mid" if got >= 0.25 else "small")
				_narrate("pace." + pace, [], {"who": "@name.%s.nom" % p, "task": "@taskname." + t["id"]})
		if not upkeep:
			st["morning_left"] = time
			return
		for t in stuck:
			_narrate("blocked", [], {"task": "@taskname." + t["id"], "who": "@name.%s.nom" % p})
		var drain: float = DRAIN
		if st["skills"][first["cat"]] < 2:
			drain += HARD_DRAIN
		if q.size() >= OVERLOAD_AT:
			st["mood"] -= 0.2
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
	if not upkeep:
		st["morning_left"] = base
		return
	if help_part > 0.0:
		_help(p, helping, help_part)
	if q.is_empty():
		st["idle_days"] = 0 if help_part > 0.0 else st["idle_days"] + 1
		if help_part > 0.0:
			st["week_hours"][week()] += 8
			st["energy"] -= DRAIN
		else:
			st["energy"] = minf(_stamina(p), st["energy"] + IDLE_REST)
			st["mood"] += info(p)["idle"]
			if not st["idle_said"]:
				st["idle_said"] = true
				_say(p, "idle.%s" % p)
	if st["pushed"] > 0:
		st["pushed"] -= 1
	st["mood"] = clampf(st["mood"], -5.0, 5.0)


# Saying no to a request in the inbox: a conversation with whoever brought it (see scenes.gd decline).
# Key projects can't be turned down.
func can_decline(t: Dictionary) -> bool:
	return phase == "plan" and pending.is_empty() and allowed("decline") and can_afford(cost("decline")) and t.get("status", "") == "inbox" and not t["key"] and not t.get("backlog", false) and not only_me(t)


func decline(uid: int) -> void:
	var t := task(uid)
	if t.is_empty() or not can_decline(t):
		return
	_tip_used("inbox")
	spend_attention(cost("decline"))
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
	# An outage becomes a serious incident if it's fixed late or badly (or not at all).
	for t in tasks:
		if not t.get("incident_settled", false) and C.TASKS.get(t["id"], {}).get("tags", []).has("incident"):
			var outcome := _outcome(t)
			if outcome != "":
				t["incident_settled"] = true
				if outcome != "good":
					flags["incidents_%d" % stage()] = flags.get("incidents_%d" % stage(), 0) + 1
					_narrate("incident.counted", [], {"task": "@taskname." + t["id"]})
	for t in tasks:
		if not t.get("flagged", false) and C.TASKS.get(t["id"], {}).get("tags", []).any(func(tag): return tag.begins_with("sets:")):
			var outcome := _outcome(t)
			if outcome != "":
				t["flagged"] = true
				if outcome == "good":
					for tag in C.TASKS[t["id"]]["tags"]:
						if tag.begins_with("sets:"):
							flags[tag.substr(5)] = true
							_narrate("flag." + tag.substr(5))
	for t in tasks:
		if not t.get("settled", false) and C.TASKS.get(t["id"], {}).get("bank", "") != "":
			var outcome := _outcome(t)
			if outcome != "":
				t["settled"] = true
				_settle_bank(t, outcome)
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
	if not available(p) or st["absent"] or archetype(p) == "life_first":
		return 0
	var q := queue_of(p)
	if q.is_empty():
		return 0
	var info: Dictionary = info(p)
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
	if phase != "plan" or not pending.is_empty() or t.is_empty() or t["status"] != "active" or t.get("stay_asked", -1) == day or not allowed("stay"):
		return
	var p: String = t["owner"]
	if not team.has(p) or not available(p) or people[p]["absent"]:
		return
	var st: Dictionary = people[p]
	t["stay_asked"] = day
	taras_like(0.5)
	lead("P", 0.5)
	history.append({"who": "you", "key": "stay.ask", "args": [], "names": {"task": "@taskname." + t["id"]}, "to": p, "day": day})
	var asked: int = st.get("asked_late_week", {}).get(week(), 0) + 1
	if not st.has("asked_late_week"):
		st["asked_late_week"] = {}
	st["asked_late_week"][week()] = asked
	var info: Dictionary = info(p)
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
func _stuck_today(p: String, t: Dictionary, skill: int, upkeep: bool = true) -> bool:
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
	# At midday they're simply still stuck; the day counts in the evening.
	if not upkeep:
		return true
	t["stuck"] += 1
	if t["stuck"] > STUCK_DAYS:
		t["stuck"] = 0
		_narrate("stuck.found_self", [], names)
	else:
		_narrate("pace.stuck", [], names)
	return true


func _learn(p: String, cat: String, amount: float) -> void:
	if archetype(p) == "stump":
		return
	var st: Dictionary = people[p]
	if info(p).get("fast_learner", false):
		amount *= 1.6
	amount *= perk_mult("learn")
	st["xp"][cat] += amount
	var need: float = XP_BASE + XP_PER_SKILL * st["skills"][cat]
	if st["xp"][cat] >= need and st["skills"][cat] < 4:
		st["xp"][cat] = 0.0
		st["skills"][cat] += 1
		_narrate("grew", [], {"who": "@name.%s.nom" % p, "cat": "@cat." + cat})
		if st["known"].has("skill." + cat):
			_narrate("know.skill", [], {"who": "@name.%s.nom" % p, "cat": "@cat." + cat, "level": "@level.%d" % st["skills"][cat]})


func _finish(p: String, t: Dictionary) -> void:
	# Nobody looked in halfway (stepped in, sat with him, paired someone up): he did it the way he understood it.
	if archetype(p) == "plodder" and not t.get("redone", false) and not t["involved"] and t.get("checked_day", 0) == 0 and t["helped"].is_empty():
		t["redone"] = true
		t["progress"] = t["size"] * 0.2
		_say(p, "plodder.oops", [], {"task": "@taskname." + t["id"]})
		_narrate("plodder.redo", [], {"who": "@name.%s.nom" % p, "task": "@taskname." + t["id"]})
		return
	t["quality"] = _quality_of(t)
	# Irina adores a genius: anything visible they deliver lifts them in her eyes, and you with them.
	if archetype(p) == "genius" and t["public"] and t["quality"] in ["good", "ok"]:
		boss += 0.3
		if not flags.has("genius_praised_" + p):
			flags["genius_praised_" + p] = true
			_say("boss", "hire.genius_praised", [], {"who": "@name.%s.nom" % p})
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
	# What she asked for herself, done on time: she sees that.
	if endless() and t["from"] == "boss" and day <= t["due"] and t["quality"] != "bad":
		boss += 0.2
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


# The endless run lives on attention: almost everything costs it, so the day holds twice as much.
func max_attention() -> int:
	if not endless():
		return C.PROFILES[profile]["attention"]
	return C.PROFILES[profile]["attention"] * 2 + int(perk_add("attention"))


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


func _work_myself(part: float = 1.0, upkeep: bool = true) -> void:
	var q := queue_of("me")
	if q.is_empty():
		return
	var t: Dictionary = q[0]
	var skill: int = my_skill(t["cat"])
	t["progress"] += my_speed(t["cat"]) * part
	t["gain_today"] = t.get("gain_today", 0.0) + my_speed(t["cat"]) * part
	t["q_sum"] += (skill + rng.randf_range(-0.7, 0.7)) * part
	t["q_days"] += part
	if upkeep:
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
		taras_like(1.0)
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
	return float(info(p)["stamina"])


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
		var by_team: bool = team.has(t["owner"]) and available(t["owner"])
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
	# Irina doesn't ask who did what went well in the endless run: she cares that it's done.
	if not best.is_empty() and endless():
		best["reviewed"] = true
	elif not best.is_empty():
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
		return ["credit_owner", "team", "self", "scale"]
	if endless():
		return ["own", "blame"]
	return ["own", "overload", "blame", "change"]


# Something slipped this week, and Irina asks you: you're the lead, so it costs you either way. Take it
# on yourself and it costs more, but the team sees you cover them; name who did it and it costs less,
# but they're hurt and the others see you hand people over. Then it's yours to deal with them.
const REVIEW_HIT := 0.5
const REVIEW_OWN := 0.5
# Blaming your people again and again makes her wonder whether you can lead them at all: each time
# within the last BLAME_MEMORY days costs this much more.
const BLAME_GROWS := 0.4
const BLAME_MEMORY := 20


func blamed_lately() -> int:
	return flags.get("blames", []).filter(func(d): return d > day - BLAME_MEMORY).size()


func _review_failure(t: Dictionary, choice: String, names: Dictionary) -> void:
	var p: String = t["owner"]
	boss -= REVIEW_HIT
	if choice == "own":
		boss -= REVIEW_OWN
		people[p]["trust"] += 1
		for q in team:
			if available(q) and q != p:
				people[q]["mood"] += 0.2
		_say("boss", "review.boss.own", [], names)
	else:
		var before: int = blamed_lately()
		var blames: Array = flags.get("blames", [])
		blames.append(day)
		flags["blames"] = blames
		boss -= BLAME_GROWS * before
		people[p]["mood"] -= 1.0
		people[p]["trust"] -= 1
		for q in team:
			if available(q) and q != p:
				people[q]["mood"] -= 0.3
		_say("boss", "review.boss.named" if before == 0 else ("review.boss.named_again" if before == 1 else "review.boss.named_doubt"), [], names)
	# Now it's between you and them, in their conversation.
	events.append({"id": "deal", "who": p, "uid": t["uid"], "names": names, "choices": ["scold", "talk", "let_go"],
		"lines": [{"who": p, "key": "event.deal.ask." + choice}]})
	_post_letters()


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
			for q in team:
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
	if not people.has(p):
		return
	var st: Dictionary = people[p]
	var names := _review_names(t)
	var truth := review_true(item, choice)
	weight_cause = t["id"]
	history.append({"who": "you", "key": "review.a." + choice, "args": [], "names": names, "to": "boss", "day": day})
	for pair in REVIEW_STYLE[choice]:
		lead(pair[0], pair[1])
	# The endless run's review is only about what went wrong, and works its own way (below).
	if endless() and item["kind"] == "failure":
		_review_failure(t, choice, names)
		choice = ""
	match choice:
		"credit_owner":
			taras_like(-0.5)
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
			for q in team:
				if available(q):
					people[q]["mood"] += 0.3
			if info(p)["drive"] == "visibility":
				st["mood"] -= 0.8
				_say(p, "review.team." + p if L.has_key("review.team." + p) else "review.hurt", [], names)
			_say("boss", "review.boss.team", [], names)
		"self":
			taras_like(1.0)
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
			taras_like(1.0)
			st["mood"] -= 2.0
			st["trust"] -= 1 if truth else 2
			if truth:
				boss += 1.0
				_say("boss", "review.boss.blame", [], names)
			else:
				_say("boss", "review.boss.blame_false", [], names)
			_say(p, "review.blamed", [], names)
		"scale":
			# What worked here, everywhere: Irina likes it as much as she likes change.
			boss += boss_like("E", 0.6) - 0.3
			st["mood"] += 0.3
			_say("boss", "review.boss.scale", [], names)
		"change":
			# Not who failed but how it's done: an E-minded Irina hears a plan, another hears an excuse.
			boss += boss_like("E", 0.6) - 0.6
			_say("boss", "review.boss.change", [], names)
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

# In the first month Marina from HR shows the new lead around: one line in the chat at the moment it's
# needed, and the board lights up where to look until you've used it. Each tip once a run.
const TIP_TARGETS := {"assign": "inbox", "end_day": "end_day", "talk": "talk", "decline": "inbox", "intervene": "active", "backlog": "backlog",
	"start_work": "end_day", "upgrades": "upgrades"}


func update_tips() -> void:
	# The endless run teaches by pointing at things instead (main.gd, the coach).
	if not tips or endless() or chapter != 1:
		return
	var id := _next_tip()
	if id == "":
		return
	flags["tip_" + id] = true
	flags["tip_last"] = id
	flags["tip_day"] = day
	flags["tip_hl"] = TIP_TARGETS.get(id, "")
	# The endless run has its own set, about its own rules.
	_say(tip_who(), tip_key(id))


func tip_who() -> String:
	return "marina"


func tip_key(id: String) -> String:
	return ("tip.run." if endless() else "tip.") + id


func _next_tip() -> String:
	if endless():
		return _next_run_tip()
	var due: Array = []
	match phase:
		"plan":
			if not pending.is_empty():
				due.append("pushback")
			elif day == 1:
				due.append("assign")
				if team.any(func(p): return not queue_of(p).is_empty()):
					due.append("end_day")
			elif flags.get("tip_day", 0) != day: # after day one, one tip a day at most
				due.append("talk")
				if day >= 3 and not inbox().is_empty():
					due.append("decline")
				if day >= 4 and not backlog().is_empty():
					due.append("backlog")
				if tasks.any(func(t): return can_intervene(t)):
					due.append("intervene")
				if team.any(func(p): return available(p) and late_hours(p) > 0):
					due.append("overtime")
		"evening":
			due.append("evening")
		"report":
			due.append("friday")
	for id in due:
		if not flags.has("tip_" + id):
			return id
	return ""


# The endless run's first month, as Marina walks the new lead through it.
func _next_run_tip() -> String:
	var due: Array = []
	match phase:
		"plan":
			if not pending.is_empty():
				due.append("pushback")
			elif step == "triage":
				if day == 1:
					due.append("assign")
					if team.any(func(p): return not queue_of(p).is_empty()):
						due.append("start_work")
				elif flags.get("tip_day", 0) != day:
					if inbox().any(func(t): return not penalty_of(t).is_empty()):
						due.append("penalty")
					if day >= 3 and not inbox().is_empty():
						due.append("decline")
					if day >= 4 and C.UPGRADES.keys().any(func(id): return upgrade_state(id) == "open" and money >= upgrade_price(id)):
						due.append("upgrades")
			elif step == "work" and (flags.get("tip_day", 0) != day or day == 1):
				due.append("midday")
		"standup":
			if standup.get("lines", []).any(func(l): return l["topic"] == "pulled"):
				due.append("standup")
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
const SAVE_VERSION := 11


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
	L.EXTRA = {"ru": {}, "en": {}}
	L.STAND_IN = {}
	for id in hires:
		_register_hire(id)
	return true


# The save if it's there, readable and still fits this version of the game (its cards still exist).
static func _read_save():
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var state = f.get_var()
	if not state is Dictionary or state.get("version") != SAVE_VERSION or state.get("phase", "end") in ["title", "end"] or (state.get("phase") == "chapter_end" and state.get("mode") != "endless" and not C.CHAPTERS[state.get("chapter", 1)]["ready"]):
		return null
	if not C.BOSSES.has(state.get("boss_type", "")) or not C.PROFILES.has(state.get("profile", "")):
		return null
	for id in state.get("deck", []):
		if not C.TASKS.has(id):
			return null
	for t in state.get("tasks", []):
		var bare := String(t["id"]).trim_prefix("init_")
		if not (C.TASKS.has(t["id"]) or C.INIT_TASKS.has(bare) or C.IMPROVEMENTS.has(bare)):
			return null
	# Saved in the middle of a conversation the scripts no longer have (or have rewritten past that point).
	var st: Dictionary = state.get("story", {})
	if not st.is_empty() and (not Dialogue.SCENES.has(st.get("id", "")) or st.get("pos", 0) > Dialogue.SCENES[st["id"]]["ops"].size()):
		return null
	return state


# ---------- moving on and the end ----------

func next() -> void:
	if phase != "evening":
		return
	if _bankrupt():
		return
	if endless():
		_expire_letters(["evening"])
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
	if can_defend():
		defend_budget("take")
	day += 1
	if endless():
		period += 1
		period_start = day
		_period_budget()
	else:
		chapter += 1
	ending = ""
	hours = 0
	events.clear()
	pending = {}
	openings += C.CHAPTERS[chapter - 1].get("openings", 0)
	deck.clear()
	_refill_deck()
	_fill_backlog()
	_start_day()


func next_chapter_ready() -> bool:
	return endless() or (chapter < C.CHAPTERS.size() and C.CHAPTERS[chapter]["ready"])


func endless() -> bool:
	return mode == "endless"


# The endless run: periods of a month.
const PERIOD_DAYS := 20

# The player sees money in the game's own currency, coonics (куники), a tenth of the thousands it's
# counted in here; salaries stay exact underneath. cash_arg() is that amount for a history line.
static func cash(n: int) -> int:
	return roundi(n / 10.0)


static func cash_arg(n: int) -> String:
	return "$cash:%d" % cash(n)


# Money, in thousands of roubles. A salary is what the CV asks for: SALARY_BASE plus SALARY_PER_LEVEL for
# each level it claims, so a faker costs like the engineer they pretend to be. It's paid a quarter a week.
const START_MONEY := 1500
const PERIOD_BUDGET := 1000
const SALARY_BASE := 60
const SALARY_PER_LEVEL := 25
const HIRE_FEE := 100 # the recruiter's cut
const SEVERANCE_WEEKS := 2
const DRAFT_SIZE := 6
const DRAFT_REROLL := 50
const DRAFT_MAX := 6
const CANDIDATE_EVERY := 3 # days between CVs in the endless run, while there's room in the list


func salary(p: String) -> int:
	var cv: Dictionary = info(p).get("cv", info(p)["skills"])
	var levels := 0
	for cat in cv:
		levels += cv[cat]
	return SALARY_BASE + SALARY_PER_LEVEL * levels


# ---------- Taras, the rival (endless run) ----------

# Points for work delivered this period: its size, by how well it was done; a slipped deadline costs.
const QUALITY_POINTS := {"good": 1.0, "ok": 0.7, "bad": 0.3}
const LATE_PENALTY := 0.5
# Taras's department gets about as much work as yours; he scores a share of what came to you each day.
# Close all of it decently and on time ("ok" quality is 0.7) and you're ahead; let it slip and he is.
const TARAS_RATE := 0.7
const TARAS_GROWTH := 0.02 # a period, up to TARAS_RATE_MAX
const TARAS_RATE_MAX := 0.9
const BUDGET_POT := 2000 # both departments' budget together
const SHARE_MIN := 0.3
const SHARE_MAX := 0.7


func _task_points(t: Dictionary) -> float:
	return t["size"] * QUALITY_POINTS.get(t["quality"], 0.5)


func my_points() -> float:
	var sum := 0.0
	for t in tasks:
		if t["status"] == "done" and t.get("done_day", 0) >= first_day() and t["owner"] != "taras":
			sum += _task_points(t)
		if t["late"] and t.get("late_day", 0) >= first_day():
			sum -= t["size"] * LATE_PENALTY
	sum -= flags.get("race_penalty_%d" % period, 0.0)
	sum += flags.get("auto_points_%d" % period, 0.0)
	return snappedf(sum, 0.1)


# Taras runs his own department and never touches yours.
func taras_total() -> float:
	return snappedf(taras_points, 0.1)


func _taras_period() -> void:
	taras_points = 0.0
	taras_target = minf(TARAS_RATE_MAX, TARAS_RATE + TARAS_GROWTH * (period - 1))


func _taras_day() -> void:
	var came := 0.0
	for t in tasks:
		if t.get("day", -1) == day and t["owner"] != "taras" and not t.get("backlog", false):
			came += t["size"]
	if flags.get("auto_day", -1) == day:
		came += flags.get("auto_size", 0.0)
	taras_points += came * taras_target * rng.randf_range(0.8, 1.2)


# The month is over: the pot is split by how the two departments did.
func _split_budget() -> void:
	var mine := maxf(0.0, my_points())
	var his := maxf(0.0, taras_total())
	var share := 0.5 if mine + his <= 0.0 else clampf(mine / (mine + his), SHARE_MIN, SHARE_MAX)
	var offer: float = BUDGET_BASE + REVENUE_SHARE * flags.get("revenue_p%d" % period, 0) + RACE_BUDGET * (share - 0.5) * 2.0 + OPINION_BUDGET[_level_of(boss)]
	offer = maxf(BUDGET_MIN, roundf(offer / 10.0) * 10.0)
	last_race = {"mine": int(round(my_points())), "taras": int(round(taras_total())), "budget": int(offer), "offer": int(offer),
		"args": budget_args(), "defended": ""}
	# For the run's record and achievements.
	if last_race["mine"] > last_race["taras"]:
		flags["race_wins"] = flags.get("race_wins", 0) + 1
		flags["race_streak"] = flags.get("race_streak", 0) + 1
	else:
		flags["race_streak"] = 0
	if not flags.has("borrowed_p%d" % period):
		flags["clean_period"] = true


# ---------- defending the budget (endless run) ----------

# What Irina offers at the end of a month: a base, half of what your clients paid the company, the
# race with Taras, and what she thinks of you. You can take it or argue for more; what you have to
# show for the month is your argument.
const BUDGET_BASE := 300
const BUDGET_MIN := 200
const REVENUE_SHARE := 0.5
const RACE_BUDGET := 300
const OPINION_BUDGET := [-200, 0, 100, 200]
const ASK_MORE := 0.2
const ASK_LOTS := 0.5


# What you can point to: beating Taras, a bank you brought in, an upgrade rolled out, a month without misses.
func budget_args() -> Array:
	var out: Array = []
	if my_points() > taras_total():
		out.append("race")
	if flags.has("bank_won_p%d" % period):
		out.append("bank")
	if flags.has("up_done_p%d" % period):
		out.append("upgrade")
	if not tasks.any(func(t): return t["late"] and t.get("late_day", 0) >= first_day()):
		out.append("clean")
	return out


func can_defend() -> bool:
	return endless() and phase == "chapter_end" and not last_race.is_empty() and last_race.get("defended", "x") == ""


# "take", "more" (one argument and she listens to you at least half-way) or "lots" (two arguments and
# she listens to you). Asking without the grounds annoys her and she cuts instead.
func defend_budget(choice: String) -> void:
	if not can_defend() or not choice in ["take", "more", "lots"]:
		return
	var offer: int = last_race["offer"]
	var args: int = last_race["args"].size()
	var level := _level_of(boss)
	var result := "take"
	var budget := offer
	match choice:
		"more":
			if args >= 1 and level >= 1:
				result = "more_yes"
				budget = int(roundf(offer * (1.0 + ASK_MORE) / 10.0) * 10.0)
			else:
				result = "more_no"
				boss -= 0.5
		"lots":
			if args >= 2 and level >= 2:
				result = "lots_yes"
				budget = int(roundf(offer * (1.0 + ASK_LOTS) / 10.0) * 10.0)
			else:
				result = "lots_no"
				boss -= 1.0
				budget = int(roundf(offer * 0.9 / 10.0) * 10.0)
	last_race["defended"] = result
	last_race["budget"] = budget
	history.append({"who": "you", "key": "budget.ask." + choice, "args": [], "names": {}, "to": "boss", "day": day})
	_say("boss", "budget." + result, [cash_arg(budget)])


func weekly_pay(p: String) -> int:
	return int(round(salary(p) / 4.0))


func payroll() -> int:
	var sum := 0
	for p in team:
		if available(p):
			sum += weekly_pay(p)
	return sum


# Weeks the money lasts at this payroll, budgets aside.
func weeks_left() -> int:
	var pay := payroll()
	return 99 if pay == 0 else money / pay


func _draft_add() -> void:
	var id := _roll_hire()
	candidates.append({"id": id, "until": 9999, "asked": [], "known": {}})


func draft_toggle(id: String) -> void:
	if phase != "draft" or candidate(id).is_empty():
		return
	if draft_picked.has(id):
		draft_picked.erase(id)
	elif draft_picked.size() < DRAFT_MAX:
		draft_picked.append(id)


# New CVs in place of everyone not picked.
func draft_reroll() -> void:
	if phase != "draft" or money < DRAFT_REROLL:
		return
	money -= DRAFT_REROLL
	for c in candidates.duplicate():
		if not draft_picked.has(c["id"]):
			candidates.erase(c)
			hires.erase(c["id"])
			_draft_add()


func draft_payroll() -> int:
	var sum := 0
	for id in draft_picked:
		sum += salary(id)
	return sum


func draft_start() -> void:
	if phase != "draft" or draft_picked.is_empty():
		return
	for id in draft_picked:
		team.append(id)
		_new_person(id, false)
		people[id]["joined"] = -100 # the team you start with, not new hires
		if C.PROFILES[profile].get("knows_team", false):
			for cat in C.CATEGORIES:
				people[id]["known"]["skill." + cat] = true
	for c in candidates:
		if not draft_picked.has(c["id"]):
			hires.erase(c["id"])
	candidates.clear()
	draft_picked.clear()
	_period_budget()
	_start_day()


func _period_budget() -> void:
	_taras_period()
	if last_race.is_empty():
		money += PERIOD_BUDGET
		_say("boss", "money.budget", [cash_arg(PERIOD_BUDGET)])
		return
	money += last_race["budget"]
	_say("boss", "money.split", [last_race["mine"], last_race["taras"], cash_arg(last_race["budget"])])


func _payday() -> void:
	# A week with five or more cards done and none missed.
	var done := tasks.filter(func(t): return t["status"] == "done" and t.get("done_day", 0) > day - 5).size()
	var missed := tasks.any(func(t): return t["late"] and t.get("late_day", 0) > day - 5)
	if done >= 5 and not missed:
		flags["clean_week"] = true
	# Irina notices a week where nothing slipped and things got done, whoever did them.
	if done >= 3 and not missed:
		boss += 0.6
		_say("boss", "boss.clean_week", [done])
	var pay := payroll()
	flags["revenue_p%d" % period] = flags.get("revenue_p%d" % period, 0) + revenue()
	money -= pay
	_narrate("money.payday", [cash_arg(pay), cash_arg(money)])
	if money < 0:
		flags["bankrupt"] = true


# The endless run ends the moment it can't go on: no money for salaries, or you've burned out for good.
func _bankrupt() -> bool:
	if not endless():
		return false
	if flags.has("bankrupt"):
		ending = "bankrupt"
	elif flags.get(burnout_key(), 0) >= burnouts_to_quit():
		ending = "burned_out"
	elif not team.any(func(p): return available(p)):
		ending = "team_gone_run"
	else:
		return false
	phase = "end"
	return true


# The chapter, or in the endless run the period: what per-month counters are kept by.
func stage() -> int:
	return period if endless() else chapter


func first_day() -> int:
	return period_start if endless() else C.chapter_first_day(chapter)


func last_day() -> int:
	return period_start + PERIOD_DAYS - 1 if endless() else C.chapter_last_day(chapter)


# The day of chapter three when Irina orders a cut; the endless run has none.
func layoff_day() -> int:
	return 0 if endless() else C.CHAPTERS[chapter - 1].get("layoff_day", 0)


# 1..20: how far into this chapter's month we are.
func chapter_day() -> int:
	return day - first_day() + 1


func chapter_keys() -> Array:
	return [] if endless() else C.KEY_PROJECTS.get(chapter, [])


# The end of a chapter: results (the boss's view, mostly the key projects) against what the team says.
# Passing it leads on to the next chapter; anything else ends the run.
func _finish_chapter() -> void:
	if _bankrupt():
		return
	# The endless run has no verdicts: the month closes, the budget is split, and on you go.
	if endless():
		_split_budget()
		ending = "period_pass"
		phase = "chapter_end"
		return
	if chapter > 1:
		_chapter_verdict()
		return
	var r := results_score()
	var team := team_score()
	if flags.get(burnout_key(), 0) >= burnouts_to_quit():
		ending = "burned_out"
	elif quits >= 2:
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
	phase = "chapter_end" if passed() and (chapter < C.CHAPTERS.size() or endless()) else "end"


func passed() -> bool:
	return ending in ["leader", "puppeteer", "cto", "stayed_lead"] or ending.ends_with("_pass") or ending.ends_with("_partial")


# Chapters after the probation are judged by the company's goals: all met, some, or none.
func _chapter_verdict() -> void:
	var info: Dictionary = C.CHAPTERS[chapter - 1]
	var met := 0
	for g in goal_progress():
		if goal_met(g):
			met += 1
	if flags.get(burnout_key(), 0) >= burnouts_to_quit():
		ending = "burned_out"
	elif quits >= 2:
		ending = "team_gone"
	elif vika_standing >= 4 and vika_standing > boss:
		ending = "replaced"
	elif hours >= 60:
		ending = "workhorse"
	elif met == info["goals"].size():
		ending = _final_standing() if info.get("final", false) else info["id"] + "_pass"
	elif met > 0:
		ending = "optimized" if info.get("final", false) else info["id"] + "_partial"
		boss -= 1.5
	else:
		ending = info["fail"]
	promoted = false
	phase = "chapter_end" if passed() and (chapter < C.CHAPTERS.size() or endless()) else "end"


const BURNOUTS_TO_QUIT := 4
const BURNOUTS_ENDLESS := 3 # in the whole endless run


# Burnouts count by the month in the story, over the whole run in the endless one.
func burnout_key() -> String:
	return "burnouts_run" if endless() else "burnouts_%d" % stage()


func burnouts_to_quit() -> int:
	return BURNOUTS_ENDLESS if endless() else BURNOUTS_TO_QUIT


# The deal went through: what becomes of you depends on Irina's view of you and on the team.
# Weight and the team's say add up over four months, so the bar is set for the whole run.
const CTO_WEIGHT := 25.0
const CTO_TEAM := 20.0
const LEAD_WEIGHT := 8.0


func _final_standing() -> String:
	if boss >= CTO_WEIGHT and team_score() >= CTO_TEAM:
		return "cto"
	if boss >= LEAD_WEIGHT:
		return "stayed_lead"
	return "optimized"


func goal_met(g: Dictionary) -> bool:
	return g["have"] <= g["need"] if g.get("max", false) else g["have"] >= g["need"]


# This chapter's goals and how far along they are: [{"id", "have", "need"}].
func goal_progress() -> Array:
	var out: Array = []
	if endless():
		return out
	for g in C.CHAPTERS[chapter - 1].get("goals", []):
		var have := 0
		match g["kind"]:
			"flags":
				for f in g["flags"]:
					if flags.has(f):
						have += 1
			"banks_shipped":
				for b in banks:
					if banks[b].get("shipped", false):
						have += 1
			"max_incidents":
				have = flags.get("incidents_%d" % stage(), 0)
			"improvements":
				for imp in improved:
					if improved[imp] >= first_day():
						have += 1
		out.append({"id": g["id"], "have": have, "need": g["need"], "max": g["kind"].begins_with("max_")})
	return out


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
	for p in team:
		var st: Dictionary = people[p]
		sum += -3.0 if st["gone"] else st["trust"] + clampf(st["mood"], -3.0, 3.0) / 3.0
	return sum / team.size()


# Marina asks everyone anonymously. Each answer comes from what actually happened to that person.
func _run_survey() -> void:
	var quotes: Array = []
	for p in team:
		if not people[p]["gone"]:
			var q := _survey_quote(p)
			# The same answer twice reads as a copy-paste; people phrase things differently.
			for variant in [q, q + ".2", q + ".3"]:
				if not quotes.has(variant) and L.has_key(variant):
					q = variant
					break
			quotes.append(q)
	shuffle(quotes)
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
	for p in team:
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
	"scale": [["E", 0.6]], "change": [["E", 0.6]],
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
	# A week without a single one-on-one.
	if not flags.has("talks_w%d" % w):
		taras_like(0.5)
	var late := 0
	for t in tasks:
		if t["late"] and int((t["late_day"] - 1) / 5.0) == w:
			late += 1
	# A clean week is order only if you were the one keeping it.
	if late == 0:
		lead("A", 1.0 if flags.has("ordered_w%d" % w) else 0.3)
	if _style_total(week_style) >= 2.0:
		var top := _style_top(week_style)
		boss += 0.5 * C.BOSSES[boss_type][top]
		_say("boss", "style.boss.%s.%s" % [boss_letter(), top])
		var sh := style_shares(week_style)
		var missing := ""
		for p in team:
			if not available(p):
				continue
			var mine: String = info(p)["paei"]
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
	if info(p).get("workaholic", false):
		return e <= 0.5
	if info(p).get("guards_energy", false):
		return e <= 0.4 * _stamina(p)
	return e <= TIRED_ENERGY


# Will they offer to do something on their own today? Only with energy to spare, and (for some)
# after hearing something good. A team led toward change volunteers more.
func _wants_to_volunteer(p: String) -> bool:
	var info: Dictionary = info(p)
	var st: Dictionary = people[p]
	if st["energy"] < info["rest_at"] * _stamina(p):
		return false
	if info.get("needs_approval", false) and st["mood"] < 1.5:
		return false
	# Told to finish one thing before grabbing the next.
	if day <= flags.get("focus_until_" + p, 0):
		return false
	return rng.randf() < info["initiative"] + (0.2 if leans("E") else 0.0)


# ---------- helpers ----------

func say(who: String, key: String, args: Array = [], names: Dictionary = {}) -> void:
	_say(who, key, args, names)


func _say(who: String, key: String, args: Array = [], names: Dictionary = {}) -> void:
	# Who says it, so the line takes their grammatical gender ({сказал|сказала}).
	var said := names.duplicate()
	said["_by"] = who
	history.append({"who": who, "key": key, "args": args, "names": said, "day": day})


func _narrate(key: String, args: Array = [], names: Dictionary = {}) -> void:
	history.append({"who": "", "key": key, "args": args, "names": names, "day": day})
