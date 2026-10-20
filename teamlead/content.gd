extends RefCounted
# Content for the team lead prototype: two working weeks. All text lives in locale.gd.
#
# Every number here is hidden. The player sees moods, energy and progress in words and bars,
# and learns skills and motives through results and one-on-ones.

# The run is four chapters, a month (four working weeks) each; days are counted through the whole run.
# Each chapter has its own key projects and deck (the `chapter` column in data/tasks.tsv); Irina names the
# key projects on its first day, Marina surveys the team halfway and at the end, and the chapter closes
# with a verdict. ready: playable already; the others are announced and come later.
const CHAPTERS := [
	{"id": "probation", "days": 20, "ready": true},
	{"id": "round_a", "days": 20, "ready": false},
	{"id": "round_b", "days": 20, "ready": false},
	{"id": "deal", "days": 20, "ready": false},
]
const SURVEY_AT := [10, 20] # days into the chapter
const WEEKS := 16 # in the whole run


static func chapter_first_day(ch: int) -> int:
	var d := 1
	for i in ch - 1:
		d += CHAPTERS[i]["days"]
	return d


static func chapter_last_day(ch: int) -> int:
	return chapter_first_day(ch) + CHAPTERS[ch - 1]["days"] - 1

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
# it when you talk them into a task. knows_team: you start out knowing everyone's skills.
const PROFILES := {
	# Strong hands; talking people round is the hard part.
	"techie": {"skills": {"pipelines": 3, "infra": 3, "portal": 2, "support": 1}, "attention": 3, "talk": 0.0},
	# Weak hands, but more time for people and better at it.
	"manager": {"skills": {"pipelines": 1, "infra": 1, "portal": 2, "support": 2}, "attention": 4, "talk": 0.5},
	# Grew up in this very team: knows who's good at what, but the old colleagues don't take orders well.
	"insider": {"skills": {"pipelines": 2, "infra": 2, "portal": 2, "support": 2}, "attention": 3, "talk": -0.4, "knows_team": true},
}
const PROFILE_KINDS := ["techie", "manager", "insider"]
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
# Columns: id, kind, chapter, category, from, size, due, public, copies, key_day, tags, name_ru, ask_ru, name_en, ask_en.
# chapter: which chapter's deck it's in (empty = 1). key_day: the day of that chapter a key project arrives.
# size: days of work for someone decent at it. due: days after arrival (0 = today). public: the boss will look.
# kind: key (key project, arrives on key_day), weekly (Monday report), deck (shuffled, `copies` of it),
# followup (a client coming back for more), dump (Irina drops it on you). tags: debt (fires that cleaning up
# tech debt removes and neglect brings back), client (good work here brings the client back for more).
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
}
const START_BANKS := ["meridian"]
const BANK_POOL := {1: ["sahara"], 2: ["alpine", "baltic"], 3: ["pacific"]}
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

# Improvements to Chainer live in data/improvements.tsv: the team's own backlog, no deadline. Three are on
# offer at a time, in `order`; finishing one brings up the next. Columns: id, chapter, order, category, size,
# effect, name/about/effect in both languages. effect, ";"-separated:
#   remove:a,b      those cards stop coming
#   shrink:a,b*0.5  those cards get smaller
#   self:a,b        those requests get done by the teams themselves through the portal
#   init            a special one the code knows (tech debt, the weekly report, the old docs)
# a, b are card ids, template ids (red_build covers red_build@kyc and the rest) or #tags.
const IMPROVEMENTS_PATH := "res://data/improvements.tsv"
static var IMPROVEMENTS := {}
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
		var ch := maxi(1, int(row.get("chapter", "1")))
		if not DECK.has(ch):
			DECK[ch] = []
			KEY_DAYS[ch] = {}
			KEY_PROJECTS[ch] = []
			START_DAYS[ch] = {}
		for v in _variants(row, ch):
			_add_card(row, ch, v)
	_load_improvements()
	for b in BANKS:
		for lang in ["ru", "en"]:
			TASK_TEXT[lang]["bankphrase." + b] = bank_phrase(b, lang)
	for id in TASKS:
		for b in TASKS[id]["then"]:
			if not TASKS.has(b["next"]):
				push_error("%s leads to %s, which isn't in %s" % [id, b["next"], TASKS_PATH])


static func _load_improvements() -> void:
	var f := FileAccess.open(IMPROVEMENTS_PATH, FileAccess.READ)
	if f == null:
		push_error("Can't read " + IMPROVEMENTS_PATH)
		return
	var header := f.get_csv_line("\t")
	while not f.eof_reached():
		var cells := f.get_csv_line("\t")
		if cells.size() < header.size() or cells[0].strip_edges() == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = cells[i].strip_edges()
		var id: String = row["id"]
		var effects: Array = []
		for part in row["effect"].split(";", false):
			var kind_targets: PackedStringArray = part.strip_edges().split(":", false)
			var targets: String = kind_targets[1] if kind_targets.size() > 1 else ""
			var factor := 1.0
			if targets.contains("*"):
				factor = float(targets.get_slice("*", 1))
				targets = targets.get_slice("*", 0)
			effects.append({"kind": kind_targets[0].strip_edges(), "targets": Array(targets.split(",", false)).map(func(x): return x.strip_edges()), "factor": factor})
		IMPROVEMENTS[id] = {"chapter": int(row["chapter"]), "order": int(row["order"]), "cat": row["category"], "size": float(row["size"]), "effects": effects}
		for lang in ["ru", "en"]:
			TASK_TEXT[lang]["taskname.init_" + id] = row["name_" + lang]
			TASK_TEXT[lang]["imp.%s.about" % id] = row["about_" + lang]
			TASK_TEXT[lang]["imp.%s.effect" % id] = row["effect_" + lang]


# The improvements of a chapter in the order they come up.
static func improvements_of(ch: int) -> Array:
	var ids := IMPROVEMENTS.keys().filter(func(id): return IMPROVEMENTS[id]["chapter"] == ch)
	ids.sort_custom(func(a, b): return IMPROVEMENTS[a]["order"] < IMPROVEMENTS[b]["order"])
	return ids


# Does an improvement's target (an id, a template id or a #tag) cover this card?
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
		"from": v["from"], "kind": row["kind"], "tags": tags, "tpl": row["id"], "then": _branches(row.get("then", "")), "bank": v.get("bank", "")}
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
const MAX_SAME_KIND := 2
const REPEAT_GAP := 5 # working days before the same card can come again
const TEMPLATE_GAP := 2 # and before the same trouble comes from another team

# What free people propose to do on their own, in order. Each is a small internal task; when it's
# done, it changes the decks or the people.
const INITIATIVES := {
	"alex": ["tech_debt", "automate_report"],
	"vika": ["showcase", "showcase"],
	"dima": ["self_study", "self_study"],
	"gena": ["write_docs", "automate_report"],
}
# The rest of what people offer (tech debt, the weekly report and the old docs are improvements: see below).
const INIT_TASKS := {
	"showcase": {"cat": "portal", "size": 1},
	"self_study": {"cat": "infra", "size": 2},
}

# Things that happen inside a task while it's being worked on. Each comes up at most once per task.
# who: "owner" (the person doing it) or "from" (whoever asked for it).
# Choice effects: size / due / quality (added to the task's average) / rework (share of progress lost) /
# block (days it stands still) / hours (your own time; you were involved) / learn (owner xp) /
# mood / energy (owner) / boss / special (handled in scenes.gd).
# check: owner skill needed; "pass" and "fail" hold the effects for each outcome.
# Complications are drawn by weight; improvements set weights to zero.
const COMPLICATIONS := {
	"legacy_bug": {"cats": ["pipelines"], "who": "owner", "choices": {
		"fix": {"check": 3, "pass": {"size": 0.5, "quality": 0.8}, "fail": {"size": 1.5, "quality": 0.3}},
		"hack": {"quality": -1.0},
		"together": {"hours": 3, "size": 0.5, "quality": 0.5, "learn": 1.0}}},
	"needs_access": {"cats": ["infra", "pipelines"], "who": "owner", "choices": {
		"ask_taras": {"special": "taras"},
		"escalate": {"boss": -0.5, "special": "grudge"},
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
