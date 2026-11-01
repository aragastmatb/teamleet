extends RefCounted
# Content for Team1337. All text lives in locale.gd.
#
# Every number here is hidden. The player sees moods, energy and progress in words and bars,
# and learns skills and motives through results and one-on-ones.

# The story is four chapters, one period (four working weeks) each; days are counted through the whole run.
# Each chapter has its own key projects and deck (the `chapter` column in data/tasks.tsv); Irina names the
# key projects on its first day, and the chapter closes with a verdict. ready: playable already; the others
# are announced and come later.
# goals (chapter 2 on): what the company needs this month. "flags": that many of these flags set (a card
# tagged sets:<flag> done well sets it); "banks_shipped": that many banks with us that got a good delivery;
# "max_incidents": no more than that many serious incidents (cards tagged incident) this month.
# All goals met: on to the next chapter. Some: on, but Irina remembers. None: `fail` is the ending.
const CHAPTERS := [
	{"id": "probation", "days": 20, "ready": true},
	# Growing without new people: automate. The better it goes, the more people sit idle, and that's what
	# chapter three's order to cut one is about. No openings here; hiring comes after the cut (see _layoff_rush).
	{"id": "round_a", "days": 20, "ready": true, "fail": "company_closed", "goals": [
		{"id": "teams_onboarded", "kind": "flags", "flags": ["onboarded_kyc", "onboarded_payments", "onboarded_regulatory"], "need": 3},
		{"id": "automation", "kind": "improvements", "need": 3},
	]},
	{"id": "round_b", "days": 20, "ready": true, "fail": "scapegoat", "layoff_day": 8, "goals": [
		{"id": "audit_passed", "kind": "flags", "flags": ["audit_access", "audit_secrets", "audit_trail"], "need": 3},
	]},
	# The last one: the deal. final: the run ends here, and how depends on where you stand (see _final_standing).
	{"id": "deal", "days": 20, "ready": true, "final": true, "fail": "deal_failed", "goals": [
		{"id": "few_incidents", "kind": "max_incidents", "need": 2},
		{"id": "final_release", "kind": "flags", "flags": ["final_release"], "need": 1},
	]},
]


const TEAM := ["alex", "vika", "dima", "gena"]
const CATEGORIES := ["pipelines", "infra", "portal", "support"]

# skills 0..4 (each run jitters them by up to ±1). drive: what motivates them.
# likes / hates: task categories that lift or sink their mood while they work on them.
# idle: mood change per day with nothing to do. stamina: energy at full rest.
# paei: their own Adizes letter, the kind of lead they warm to (see BOSSES).
# rest_at: share of stamina they need before they volunteer anything; initiative: daily chance they do.
# Traits: workaholic (ignores tiredness until it drops them), guards_energy (says no early when tired),
# needs_approval (only volunteers after praise), touchy (takes hits harder).
const PEOPLE := {
	"alex": {"skills": {"pipelines": 3, "infra": 4, "portal": 1, "support": 0}, "drive": "craft", "likes": ["infra"], "hates": ["support"], "idle": 0.0, "stamina": 9,
		"paei": "P", "rest_at": 0.25, "initiative": 0.6, "workaholic": true},
	"vika": {"skills": {"pipelines": 1, "infra": 0, "portal": 2, "support": 3}, "drive": "visibility", "likes": ["portal"], "hates": ["infra"], "idle": -0.6, "stamina": 8,
		"paei": "E", "rest_at": 0.35, "initiative": 0.7},
	"dima": {"skills": {"pipelines": 1, "infra": 1, "portal": 2, "support": 1}, "drive": "growth", "likes": [], "hates": [], "idle": -0.4, "stamina": 10, "fast_learner": true,
		"paei": "I", "rest_at": 0.5, "initiative": 0.6, "needs_approval": true, "touchy": true},
	"gena": {"skills": {"pipelines": 4, "infra": 2, "portal": 0, "support": 1}, "drive": "peace", "likes": ["pipelines"], "hates": ["support"], "idle": 0.3, "stamina": 7,
		"paei": "A", "rest_at": 0.75, "initiative": 0.35, "guards_energy": true},
}

# Hiring, from chapter two: Irina gives openings, Marina sends candidates. A hire is made up from a name
# and an archetype, and nobody tells you which archetype: it shows in how they work.
#   solid       an ordinary decent engineer
#   junior      weak at first, learns fast
#   faker       a great CV and great stand-ups; the work itself crawls (stepping in shows it)
#   stump       does the minimum, never complains, never grows
#   life_first  honest, pleasant and good, but now and then the dog, the car or the marathon comes first
#   genius      very strong and Irina adores them; the team around them wilts
# Names: Russian in the five cases the texts need (nom, gen, dat, acc, ins), and English.
const HIRE_NAMES := [
	{"ru": ["Артём", "Артёма", "Артёму", "Артёма", "Артёмом"], "en": "Artem"},
	{"ru": ["Ксения", "Ксении", "Ксении", "Ксению", "Ксенией"], "en": "Ksenia", "f": true},
	{"ru": ["Олег", "Олега", "Олегу", "Олега", "Олегом"], "en": "Oleg"},
	{"ru": ["Полина", "Полины", "Полине", "Полину", "Полиной"], "en": "Polina", "f": true},
	{"ru": ["Руслан", "Руслана", "Руслану", "Руслана", "Русланом"], "en": "Ruslan"},
	{"ru": ["Яна", "Яны", "Яне", "Яну", "Яной"], "en": "Yana", "f": true},
	{"ru": ["Тимур", "Тимура", "Тимуру", "Тимура", "Тимуром"], "en": "Timur"},
	{"ru": ["Нина", "Нины", "Нине", "Нину", "Ниной"], "en": "Nina", "f": true},
	{"ru": ["Егор", "Егора", "Егору", "Егора", "Егором"], "en": "Egor"},
	{"ru": ["Лиза", "Лизы", "Лизе", "Лизу", "Лизой"], "en": "Liza", "f": true},
	{"ru": ["Марк", "Марка", "Марку", "Марка", "Марком"], "en": "Mark"},
	{"ru": ["Соня", "Сони", "Соне", "Соню", "Соней"], "en": "Sonya", "f": true},
]
const ARCHETYPES := {
	"solid": {"weight": 30}, "junior": {"weight": 20}, "faker": {"weight": 15},
	"stump": {"weight": 15}, "life_first": {"weight": 10}, "genius": {"weight": 10},
}
# What you can ask a candidate, in the order the window lists it (rules.gd, "conversations").
const INTERVIEW_TOPICS := ["tech", "task", "last_job", "drive", "not_want", "overtime", "team"]

# Adizes' four roles of a manager: P produces results, A keeps order, E brings change, I holds people
# together. Everything you do as a lead leans one way; nobody is strong in all four.
const PAEI := ["P", "A", "E", "I"]
# Irina comes in four kinds, one per letter: what she values in a lead (taste, -1..1).
# The game will let you pick her at the start; for now every run uses DEFAULT_BOSS.
const BOSSES := {
	"P": {"P": 1.0, "A": 0.3, "E": 0.2, "I": -0.3},
	"A": {"P": 0.3, "A": 1.0, "E": -0.3, "I": 0.2},
	"E": {"P": 0.2, "A": -0.3, "E": 1.0, "I": 0.3},
	"I": {"P": -0.3, "A": 0.2, "E": 0.3, "I": 1.0},
	# The chaotic one: an E who rushes in for two hours, calls everyone to the meeting room and runs off.
	"X": {"P": 0.2, "A": -0.3, "E": 1.0, "I": 0.3},
}
const BOSS_KINDS := ["P", "A", "E", "I", "X"]
const DEFAULT_BOSS := "A"

# Who you were before this job, picked at the start. skills: yours when you do the work yourself or step
# into someone's (same 0..4 scale as the team). attention: tokens a day. talk: added to how people take
# it when you talk them into a task.
# upgrade_discount: off the price of every upgrade; rollout: how much faster upgrade rollout cards go.
const PROFILES := {
	# Strong hands; talking people round is the hard part.
	"techie": {"skills": {"pipelines": 3, "infra": 3, "portal": 2, "support": 1}, "attention": 3, "talk": 0.0},
	# Weak hands, but more time for people and better at it.
	"manager": {"skills": {"pipelines": 1, "infra": 1, "portal": 2, "support": 2}, "attention": 4, "talk": 0.5},
	# The endless run's third: designed platforms before, so upgrades come cheaper and roll out faster;
	# the price is weaker hands than an engineer's.
	"architect": {"skills": {"pipelines": 2, "infra": 3, "portal": 2, "support": 1}, "attention": 3, "talk": 0.0,
		"upgrade_discount": 0.3, "rollout": 1.5},
}
# The story's choice; the endless run hires its own team, so knowing it from before makes no sense there.
const PROFILE_KINDS := ["techie", "manager", "architect"]
const DEFAULT_PROFILE := "techie"

# When someone pushes back on a task, you answer with an intent. Each motive takes each intent
# differently (mood change on top of grudgingly accepting). Some intents only work when true:
# flattery when they really are good at it, the boss when she really asked or will look.
const INTENTS := ["honest", "flatter", "boss", "promise", "order"]
const INTENT_TASTE := {
	"craft": {"honest": 1, "flatter": 1, "boss": -1, "promise": 0, "order": -2},
	"visibility": {"honest": 0, "flatter": 2, "boss": 1, "promise": 1, "order": -1},
	"growth": {"honest": 1, "flatter": 1, "boss": 0, "promise": 1, "order": -1},
	"peace": {"honest": 1, "flatter": 0, "boss": 1, "promise": 1, "order": -1},
}


# The task deck lives in data/tasks.tsv, a table anyone can edit (Excel, Google Sheets, a text editor).
# Columns: id, kind, chapter, category, from, size, due, public, copies, key_day, tags, name_ru, ask_ru, name_en, ask_en, penalty.
# chapter: which chapter's deck it's in (empty = 1). key_day: the day of that chapter a key project arrives.
# size: days of work for someone decent at it. due: days after arrival (0 = today). public: the boss will look.
# kind: key (key project, arrives on key_day), weekly (Monday report), deck (shuffled, `copies` of it),
# followup (a client coming back for more), dump (Irina drops it on you), penalty (brought by a missed
# deadline, never dealt). tags: debt (fires that cleaning up tech debt removes and neglect brings back),
# client (good work here brings the client back for more), only_me (nobody but you can take it).
# penalty (the endless run only): what missing the deadline costs, on top of the complaints:
#   boss       Irina is displeased: points off in the race with Taras
#   call       an escalation call goes into your inbox, and only you can take it
#   incident   an incident breaks out the next day
#   debt       a tech-debt fire goes into the deck for good
#   money:N    a fine of N thousand
#
# Chains: a card of kind start arrives on its key_day; its `then` column says what comes next, by how it
# went: "good:kyc_pipelines+2; bad:kyc_rollback+1; declined:kyc_escalation+3" — done well (or ok), done
# badly, turned down, late (missed its deadline, done or not), done (well or badly). The first branch that
# fits wins; +N is days later. The cards it leads to are of kind chain: dealt only by a chain.
#
# Templates: a row brought "from" product becomes one card per product team, brought by that team's lead;
# a row with {bank} in its text becomes one card per client bank of its chapter. In the text, {team} and
# {bank} become the names, {hi} and {push} the lead's own way of opening and of leaning on you.
# Such a card's id is the row's id plus "@" and the team or bank, e.g. red_build@kyc.
const TASKS_PATH := "res://data/tasks.tsv"

const PRODUCT_TEAMS := {
	"payments": {"lead": "stas", "ru": "«Платежи»", "en": "Payments"},
	"kyc": {"lead": "olga", "ru": "KYC", "en": "KYC"},
	"regulatory": {"lead": "boris", "ru": "«Регуляторка»", "en": "Regulatory"},
}
# Client banks. A bank's cards ({bank} templates, and cards tagged bank:<id>) come only while it's with
# us. The run starts with START_BANKS; sales bring in the chapter's BANK_POOL; some arrive with a card
# tagged "joins" (a chain), and one tagged "last_chance" left undone loses the bank.
const BANKS := {
	"meridian": {"ru": "«Кредит Доверия»", "en": "Trust Credit Bank"},
	"fjord": {"ru": "«Цифровая Трансформация»", "en": "Digital Transformation Bank"},
	"sahara": {"ru": "«ОКР-Банк»", "en": "OKR Bank"},
	"alpine": {"ru": "«Мы Одна Семья»", "en": "One Family Bank"},
	"baltic": {"ru": "«Беги Заплати»", "en": "Run & Pay Bank"},
	"pacific": {"ru": "«Банановый Банк»", "en": "Banana Bank"},
	# The two sales close right after the cut in chapter three (rules.gd, _layoff_rush).
	"harbor": {"ru": "«Тихая Гавань»", "en": "Quiet Harbour Bank"},
	"till": {"ru": "«Своя Касса»", "en": "Own Till Bank"},
}
const START_BANKS := ["meridian"]
# Banks sales can bring in, by chapter; one not sold yet stays on offer later.
const BANK_POOL := {1: ["sahara"], 2: ["alpine"], 3: ["pacific"]}
# How each lead opens and pushes; a card picks one of the three by its id, so it reads the same every time.
const LEAD_VOICE := {
	"stas": {
		"hi_ru": ["Опять. ", "Так, срочно. ", "Ребята, горим. "], "hi_en": ["Again. ", "Right, urgent. ", "Guys, we're on fire. "],
		"push_ru": [" У нас релиз у банка, нужно вчера.", " Я уже банку пообещал, не подведите.", " Сколько можно, а?"],
		"push_en": [" We've got a bank release, we needed it yesterday.", " I've already promised the bank, don't let me down.", " How many times, eh?"],
	},
	"olga": {
		"hi_ru": ["Добрый день! ", "Коллеги, привет! ", "Извините, что отвлекаю. "], "hi_en": ["Good afternoon! ", "Hi, colleagues! ", "Sorry to bother you. "],
		"push_ru": [" Если несложно, на этой неделе? Я потом уточню.", " Я понимаю, что у вас много всего, но нам очень нужно.", " Напомню завтра, хорошо?"],
		"push_en": [" If it's not too much trouble, this week? I'll check in later.", " I know you have a lot on, but we really need it.", " I'll remind you tomorrow, all right?"],
	},
	"boris": {
		"hi_ru": ["Слушай-слушай. ", "Коллега! ", "Тут такое дело. "], "hi_en": ["Listen, listen. ", "Colleague! ", "Here's the thing. "],
		"push_ru": [" Я там уже сказал, что вы быстро.", " Ну вы же можете, я знаю.", " Регулятор ждать не будет, хе-хе."],
		"push_en": [" I've already told them you're quick.", " You can do it, I know you can.", " The regulator won't wait, heh."],
	},
}
static var TASKS := {}
# By chapter: DECK[ch] the deck cards, KEY_DAYS[ch][day of the chapter] the key project, KEY_PROJECTS[ch] all of them.
static var DECK := {}
static var KEY_DAYS := {}
static var KEY_PROJECTS := {}
static var DUMPS: Array = []
# By chapter: START_DAYS[ch][day of the chapter] the chains that begin that day.
static var START_DAYS := {}

static var TASK_TEXT := {"ru": {}, "en": {}}


static func _static_init() -> void:
	var f := FileAccess.open(TASKS_PATH, FileAccess.READ)
	if f == null:
		push_error("Can't read " + TASKS_PATH)
		return
	var header := f.get_csv_line("\t")
	while not f.eof_reached():
		var cells := f.get_csv_line("\t")
		if cells.size() < header.size() or cells[0].strip_edges() == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = cells[i].strip_edges()
		# chapter "*": a card of the common base, in every chapter's deck.
		var chapters: Array = range(1, CHAPTERS.size() + 1) if row.get("chapter", "1") == "*" else [maxi(1, int(row.get("chapter", "1")))]
		for ch in chapters:
			if not DECK.has(ch):
				DECK[ch] = []
				KEY_DAYS[ch] = {}
				KEY_PROJECTS[ch] = []
				START_DAYS[ch] = {}
			for v in _variants(row, ch):
				_add_card(row, ch, v)
	_build_endless_deck()
	_load_upgrades()
	for b in BANKS:
		for lang in ["ru", "en"]:
			TASK_TEXT[lang]["bankphrase." + b] = bank_phrase(b, lang)
	for id in TASKS:
		for b in TASKS[id]["then"]:
			if not TASKS.has(b["next"]):
				push_error("%s leads to %s, which isn't in %s" % [id, b["next"], TASKS_PATH])


# The endless run's upgrade tree lives in data/upgrades.tsv. Columns: id, branch, requires (ids, all of
# them done first), price (thousands), cards, start, final, maint, replaces, name/about in both languages.
# Buying one puts its implementation cards (`cards`: "cat:size;cat:size") into the deck and gives the
# `start` effect at once; once every one of them is done it gives the `final` effect, and its maintenance
# cards (`maint`, same form) join the deck for good, taking out those of the upgrade it `replaces`.
# Implementation cards have no deadline; one done badly comes back to be redone.
# Effects, ";"-separated (cat is pipelines, infra, portal or support):
#   speed:cat*1.1   that work goes faster        freq:cat*0.8    fewer such cards come
#   due:cat+1       their deadlines are further  quality:cat+0.3 better work on them
#   remove:a,b / shrink:a,b*0.5 / self:a,b     as in improvements.tsv
#   attention+1     a point more a day           borrow+1        borrow one more from tomorrow
#   initiative+0.1  people grab work more        learn*1.3       everyone learns faster
#   newbie*0.6      newcomers settle in sooner   sales+0.1       banks sign up more readily
#   clean:#tag      the deck's cards with that tag that missed deadlines put there go away
#   money+100       money at once
const UPGRADES_PATH := "res://data/upgrades.tsv"
const UPGRADE_BRANCHES := ["pipelines", "infra", "portal", "support", "team"]
static var UPGRADES := {}


static func _load_upgrades() -> void:
	var f := FileAccess.open(UPGRADES_PATH, FileAccess.READ)
	if f == null:
		push_error("Can't read " + UPGRADES_PATH)
		return
	var header := f.get_csv_line("\t")
	var order := 0
	while not f.eof_reached():
		var cells := f.get_csv_line("\t")
		if cells.size() < header.size() or cells[0].strip_edges() == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = cells[i].strip_edges()
		var id: String = row["id"]
		var up := {"branch": row["branch"], "price": int(row["price"]), "order": order,
			"requires": Array(row["requires"].split(",", false)).map(func(x): return x.strip_edges()),
			"start": parse_effects(row["start"]), "final": parse_effects(row["final"]),
			"replaces": row["replaces"], "cards": [], "maint": []}
		order += 1
		for lang in ["ru", "en"]:
			TASK_TEXT[lang]["up.%s.name" % id] = row["name_" + lang]
			TASK_TEXT[lang]["up.%s.about" % id] = row["about_" + lang]
		var specs: Array = Array(row["cards"].split(";", false))
		for i in specs.size():
			var card := "up_%s_%d" % [id, i + 1]
			_upgrade_card(card, specs[i], NO_DEADLINE_DAYS, "")
			for lang in ["ru", "en"]:
				TASK_TEXT[lang]["taskname." + card] = "%s (%d/%d)" % [row["name_" + lang], i + 1, specs.size()]
				TASK_TEXT[lang]["task.%s.ask" % card] = ("Внедряем «%s», шаг %d из %d." if lang == "ru" else "Rolling out \"%s\", step %d of %d.") % [row["name_" + lang], i + 1, specs.size()]
			up["cards"].append(card)
		var maint: Array = Array(row["maint"].split(";", false))
		for i in maint.size():
			var card := "upm_%s_%d" % [id, i + 1]
			_upgrade_card(card, maint[i], MAINT_DUE, "incident")
			for lang in ["ru", "en"]:
				TASK_TEXT[lang]["taskname." + card] = ("%s: обслуживание" if lang == "ru" else "%s: upkeep") % row["name_" + lang]
				TASK_TEXT[lang]["task.%s.ask" % card] = ("Плановые работы по «%s»." if lang == "ru" else "Routine work on \"%s\".") % row["name_" + lang]
			up["maint"].append(card)
		UPGRADES[id] = up
	for id in UPGRADES:
		for r in UPGRADES[id]["requires"] + ([UPGRADES[id]["replaces"]] if UPGRADES[id]["replaces"] != "" else []):
			if not UPGRADES.has(r):
				push_error("%s needs %s, which isn't in %s" % [id, r, UPGRADES_PATH])


const NO_DEADLINE_DAYS := 100000
const MAINT_DUE := 3


static func _upgrade_card(id: String, spec: String, due: int, penalty: String) -> void:
	var parts := spec.strip_edges().split(":")
	TASKS[id] = {"cat": parts[0], "size": float(parts[1]) if parts.size() > 1 else 1.0, "due": due, "public": false,
		"from": "boss", "kind": "upgrade", "tags": ["upgrade"], "tpl": id, "then": [], "bank": "", "penalty": penalty}


# "speed:infra*1.1; remove:a,b; attention+1" -> [{"kind", "cat", "targets", "value"}, ...]
static func parse_effects(text: String) -> Array:
	var out: Array = []
	for part in text.split(";", false):
		part = part.strip_edges()
		var e := {"kind": "", "cat": "", "targets": [], "value": 0.0}
		var body := part
		var sign_at := -1
		for op in ["*", "+"]:
			var i := part.rfind(op)
			if i > sign_at:
				sign_at = i
		if sign_at > 0:
			e["value"] = float(part.substr(sign_at + 1))
			body = part.substr(0, sign_at)
		var kind_rest := body.split(":", false)
		e["kind"] = kind_rest[0].strip_edges()
		if kind_rest.size() > 1:
			var rest: String = kind_rest[1].strip_edges()
			if e["kind"] in ["speed", "freq", "due", "quality"]:
				e["cat"] = rest
			else:
				e["targets"] = Array(rest.split(",", false)).map(func(x): return x.strip_edges())
		out.append(e)
	return out


# The endless run's one deck: every chapter's dealt cards, each as many times as its row says, except
# the story line's own (tagged story in data/tasks.tsv: the round, the investors, the sale) and any that
# names one of the story's own people. The story's cards are like an expansion's deck, mixed in only there.
static var ENDLESS_DECK: Array = []
static var _TEAM_NAMES := RegEx.create_from_string("\\b(Alex|Vika|Dima|Gena|Palych)\\b|Алекс|Палыч|Ген[аыеуо]й?\\b|Вик[аиеуо]й?\\b|Дим[аыеуо]й?\\b")


static func _build_endless_deck() -> void:
	var copies := {}
	for ch in DECK:
		var count := {}
		for id in DECK[ch]:
			count[id] = count.get(id, 0) + 1
		for id in count:
			copies[id] = maxi(copies.get(id, 0), count[id])
	for id in copies:
		var text := ""
		for lang in ["ru", "en"]:
			text += TASK_TEXT[lang].get("taskname." + id, "") + " " + TASK_TEXT[lang].get("task.%s.ask" % id, "")
		if _TEAM_NAMES.search(text) != null or TASKS[id]["tags"].has("story"):
			continue
		for i in copies[id]:
			ENDLESS_DECK.append(id)


# Does an upgrade's target (an id, a template id or a #tag) cover this card?
static func covers(target: String, id: String) -> bool:
	if target.begins_with("#"):
		return TASKS.has(id) and TASKS[id]["tags"].has(target.substr(1))
	return target == id or (TASKS.has(id) and TASKS[id]["tpl"] == target)


# "good:x+2; bad:y+1" -> [{"on": "good", "next": "x", "after": 2}, ...]
static func _branches(text: String) -> Array:
	var out: Array = []
	for part in text.split(";", false):
		var on_next := part.strip_edges().split(":", false)
		if on_next.size() != 2:
			continue
		var next_after := on_next[1].strip_edges().split("+")
		out.append({"on": on_next[0].strip_edges(), "next": next_after[0].strip_edges(), "after": int(next_after[1]) if next_after.size() > 1 else 1})
	return out


# What one table row becomes: a single card, or one per product team or per bank.
static func _variants(row: Dictionary, ch: int) -> Array:
	if row["from"] == "product":
		return PRODUCT_TEAMS.keys().map(func(k): return {"id": row["id"] + "@" + k, "from": PRODUCT_TEAMS[k]["lead"], "team": k})
	var text: String = row["name_ru"] + row["ask_ru"] + row["name_en"] + row["ask_en"]
	if text.contains("{bank}"):
		return BANKS.keys().map(func(k): return {"id": row["id"] + "@" + k, "from": row["from"], "bank": k})
	return [{"id": row["id"], "from": row["from"]}]


static func _add_card(row: Dictionary, ch: int, v: Dictionary) -> void:
	var id: String = v["id"]
	var tags: Array = Array(row["tags"].split(",", false)).map(func(x): return x.strip_edges())
	TASKS[id] = {"cat": row["category"], "size": float(row["size"]), "due": int(row["due"]), "public": row["public"] == "1",
		"from": v["from"], "kind": row["kind"], "tags": tags, "tpl": row["id"], "then": _branches(row.get("then", "")), "bank": v.get("bank", ""),
		"penalty": row.get("penalty", "")}
	for tag in tags:
		if tag.begins_with("bank:"):
			TASKS[id]["bank"] = tag.substr(5)
	match row["kind"]:
		"deck":
			for i in maxi(1, int(row["copies"])):
				DECK[ch].append(id)
		"key":
			KEY_DAYS[ch][int(row["key_day"])] = id
			KEY_PROJECTS[ch].append(id)
		"dump":
			DUMPS.append(id)
		"start":
			if not START_DAYS[ch].has(int(row["key_day"])):
				START_DAYS[ch][int(row["key_day"])] = []
			START_DAYS[ch][int(row["key_day"])].append(id)
	for lang in ["ru", "en"]:
		var name := _fill(row["name_" + lang], v, lang, ch)
		# A task's name is always shown «in quotes», so quotes inside it are the nested kind.
		if lang == "ru":
			name = name.replace("«", "„").replace("»", "“")
		TASK_TEXT[lang]["taskname." + id] = name
		TASK_TEXT[lang]["task.%s.ask" % id] = _fill(row["ask_" + lang], v, lang, ch)


# "банк «Кредит Доверия»", but just "«ОКР-Банк»" when the name says it already. English names all do.
static func bank_phrase(b: String, lang: String) -> String:
	var name: String = BANKS[b][lang]
	if lang == "ru" and not name.to_lower().contains("банк"):
		return "банк " + name
	return name


static func _cap(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


static func _fill(text: String, v: Dictionary, lang: String, ch: int) -> String:
	if v.has("team"):
		text = text.replace("{team}", PRODUCT_TEAMS[v["team"]][lang])
	if v.has("bank"):
		text = text.replace("{bank_name}", BANKS[v["bank"]][lang])
		text = text.replace("{bank}", bank_phrase(v["bank"], lang))
		text = text.replace("{Bank}", _cap(bank_phrase(v["bank"], lang)))
	var voice: Dictionary = LEAD_VOICE.get(v["from"], {})
	var pick: int = abs(hash(v["id"]))
	text = text.replace("{hi}", voice["hi_" + lang][pick % 3] if voice else "")
	text = text.replace("{push}", voice["push_" + lang][(pick / 3) % 3] if voice else "")
	return text


# Cards of a kind or with a tag, e.g. the weekly report or the fires tech debt brings.
static func tasks_with(field: String, value: String) -> Array:
	var out: Array = []
	for id in TASKS:
		var info: Dictionary = TASKS[id]
		if (field == "tag" and info["tags"].has(value)) or (field == "kind" and info["kind"] == value):
			out.append(id)
	return out


# Size of work drawn each morning, roughly; a day brings at most two cards of one kind. A team that
# hands work out well gets through about 4.3 days of work a day; with key projects, the weekly report
# and the rest on top, this brings in about one and a half times that. Not everything is meant to get done.
const DAILY_LOAD := 7.5
const MAX_CARDS_A_DAY := 5
# Work ramps up week by week: the probation starts gently so there's room to learn, later chapters only ease
# the first week. Per week of the chapter: share of DAILY_LOAD, most cards a day, extra days on deadlines.
const RAMP := {
	1: [{"load": 0.55, "cards": 3, "slack": 2}, {"load": 0.7, "cards": 4, "slack": 1}, {"load": 0.85, "cards": 4, "slack": 0}, {"load": 0.95, "cards": 5, "slack": 0}],
	# Automation month: less work comes in as the month goes on, so the team starts to have time on its hands.
	2: [{"load": 0.85, "cards": 4, "slack": 1}, {"load": 0.8, "cards": 4, "slack": 0}, {"load": 0.7, "cards": 4, "slack": 0}, {"load": 0.6, "cards": 3, "slack": 0}],
}
const RAMP_LATER := [{"load": 0.8, "cards": 4, "slack": 1}] # story chapters with no ramp of their own
const MAX_SAME_KIND := 2
const REPEAT_GAP := 5 # working days before the same card can come again
const TEMPLATE_GAP := 2 # and before the same trouble comes from another team

# Things that happen inside a task while it's being worked on. Each comes up at most once per task.
# who: "owner" (the person doing it) or "from" (whoever asked for it).
# Choice effects: size / due / quality (added to the task's average) / rework (share of progress lost) /
# block (days it stands still) / hours (your own time; you were involved) / learn (owner xp) /
# mood / energy (owner) / boss / special (handled in scenes.gd).
# check: owner skill needed; "pass" and "fail" hold the effects for each outcome.
const COMPLICATIONS := {
	"legacy_bug": {"cats": ["pipelines"], "who": "owner", "choices": {
		"fix": {"check": 3, "pass": {"size": 0.5, "quality": 0.8}, "fail": {"size": 1.5, "quality": 0.3}},
		"hack": {"quality": -1.0},
		"together": {"hours": 3, "size": 0.5, "quality": 0.5, "learn": 1.0}}},
	"needs_access": {"cats": ["infra", "pipelines"], "who": "owner", "choices": {
		"escalate": {"boss": -0.5},
		"wait": {"block": 1}}},
	"scope_creep": {"cats": ["pipelines", "infra", "portal", "support"], "who": "from", "choices": {
		"accept": {"size": 1.0, "special": "please_from"},
		"deadline": {"size": 1.0, "due": 1},
		"push_back": {"special": "annoy_from"}}},
	"bad_data": {"cats": ["pipelines"], "who": "owner", "choices": {
		"clean": {"check": 3, "pass": {"size": 0.5, "quality": 0.6}, "fail": {"size": 1.5, "quality": 0.3}},
		"as_is": {"quality": -1.0},
		"together": {"hours": 2, "size": 0.5, "quality": 0.4, "learn": 1.0}}},
	"client_changes": {"cats": ["infra", "support"], "who": "owner", "choices": {
		"redo": {"rework": 0.4},
		"negotiate": {"hours": 2, "special": "negotiate"},
		"ignore": {"quality": -1.0}}},
	"no_reply": {"cats": ["support"], "who": "owner", "choices": {
		"wait": {"block": 1},
		"push": {"energy": -1.0, "mood": -0.5},
		"you_call": {"hours": 2}}},
	"conflict": {"cats": ["support"], "who": "owner", "choices": {
		"owner_handles": {"check": 3, "pass": {"learn": 1.5, "mood": 0.5}, "fail": {"block": 1, "mood": -1.0}},
		"mediate": {"hours": 2},
		"escalate": {"block": 1}}},
	"old_system": {"cats": ["infra"], "who": "owner", "choices": {
		"manual": {"size": 1.0, "mood": -0.5},
		"ask_gena": {"special": "gena"},
		"corners": {"quality": -0.8}}},
	"missing_docs": {"cats": ["portal", "infra"], "who": "owner", "choices": {
		"dig": {"check": 2, "pass": {"size": 0.3, "learn": 1.0}, "fail": {"size": 1.0, "learn": 1.0}},
		"together": {"hours": 2},
		"corners": {"quality": -0.6}}},
	# One user can't press a button and nothing shows up in the logs. Only digging finds it (a character
	# in their name the old Python can't read); the obvious fixes change nothing.
	"one_user_bug": {"cats": ["portal"], "who": "owner", "choices": {
		"dig": {"check": 3, "pass": {"size": 0.3, "quality": 0.6, "learn": 1.0}, "fail": {"block": 1, "mood": -0.5}},
		"restart": {"quality": -1.0},
		"together": {"hours": 2, "size": 0.3, "quality": 0.5, "learn": 1.0}}},
}
