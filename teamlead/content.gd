extends RefCounted
# Content for the team lead prototype: two working weeks. All text lives in locale.gd.
#
# Every number here is hidden. The player sees moods, energy and progress in words and bars,
# and learns skills and motives through results and one-on-ones.

# A four-week probation. Irina names three key projects on day one; Marina surveys the team
# halfway and at the end. The final attestation weighs results against what the team says.
const WEEKS := 4
const DAYS := 20
const REVIEW_DAYS := [5, 10, 15, 20]
const SURVEY_DAYS := [10, 20]
const KEY_PROJECTS := ["new_feature", "board_deck", "quarter_report"]
const DUMPS := ["board_memo", "slides_fix", "vip_call", "competitor_brief"]

const TEAM := ["alex", "vika", "dima", "gena"]
const CATEGORIES := ["tech", "analytics", "people", "routine"]

# skills 0..4 (each run jitters them by up to ±1). drive: what motivates them.
# likes / hates: task categories that lift or sink their mood while they work on them.
# idle: mood change per day with nothing to do. stamina: energy at full rest.
const PEOPLE := {
	"alex": {"skills": {"tech": 4, "analytics": 1, "people": 0, "routine": 2}, "drive": "craft", "likes": ["tech"], "hates": ["people"], "idle": 0.0, "stamina": 9},
	"vika": {"skills": {"tech": 1, "analytics": 3, "people": 3, "routine": 0}, "drive": "visibility", "likes": ["analytics"], "hates": ["routine"], "idle": -0.6, "stamina": 8},
	"dima": {"skills": {"tech": 1, "analytics": 0, "people": 1, "routine": 1}, "drive": "growth", "likes": [], "hates": [], "idle": -0.4, "stamina": 10, "fast_learner": true},
	"gena": {"skills": {"tech": 2, "analytics": 0, "people": 1, "routine": 4}, "drive": "peace", "likes": ["routine"], "hates": ["people"], "idle": 0.3, "stamina": 7},
}

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


# size: days of work for someone decent at it. due: days after arrival (0 = today). public: the boss will look at it.
# There's more work than the team can do; something will slip, and the question is what.
const TASKS := {
	"client_report": {"cat": "analytics", "size": 3, "due": 4, "public": true, "from": "boss"},
	"minutes": {"cat": "routine", "size": 1, "due": 2, "public": false, "from": "boss"},
	"corporate": {"cat": "people", "size": 2, "due": 5, "public": false, "from": "marina"},
	"weekly_report": {"cat": "routine", "size": 1, "due": 1, "public": true, "from": "boss"},
	"integration": {"cat": "tech", "size": 2, "due": 5, "public": false, "from": "taras"},
	"timesheets": {"cat": "routine", "size": 1, "due": 2, "public": false, "from": "marina"},
	"security_patch": {"cat": "tech", "size": 1, "due": 2, "public": false, "from": "taras"},
	"onboarding": {"cat": "people", "size": 2, "due": 3, "public": false, "from": "marina"},
	"okr": {"cat": "analytics", "size": 2, "due": 3, "public": true, "from": "boss"},
	"ab_test": {"cat": "analytics", "size": 1, "due": 2, "public": false, "from": "taras"},
	"inventory": {"cat": "routine", "size": 1, "due": 2, "public": false, "from": "marina"},
	"prod_fix": {"cat": "tech", "size": 1, "due": 1, "public": true, "from": "boss"},
	"pricing": {"cat": "analytics", "size": 2, "due": 3, "public": true, "from": "boss"},
	"newsletter": {"cat": "people", "size": 1, "due": 3, "public": false, "from": "marina"},
	"survey": {"cat": "people", "size": 1, "due": 3, "public": false, "from": "marina"},
	"new_feature": {"cat": "tech", "size": 3, "due": 5, "public": true, "from": "boss"},
	"angry_client": {"cat": "people", "size": 1, "due": 1, "public": true, "from": "boss"},
	"vendor_contract": {"cat": "routine", "size": 1, "due": 3, "public": false, "from": "boss"},
	"board_deck": {"cat": "analytics", "size": 3, "due": 4, "public": true, "from": "boss"},
	"legacy_export": {"cat": "routine", "size": 2, "due": 3, "public": false, "from": "boss"},
	"forecast": {"cat": "analytics", "size": 1, "due": 3, "public": false, "from": "taras"},
	"client_bug": {"cat": "tech", "size": 2, "due": 2, "public": true, "from": "boss"},
	"docs": {"cat": "routine", "size": 1, "due": 3, "public": false, "from": "taras"},
	"client_demo": {"cat": "people", "size": 2, "due": 3, "public": true, "from": "boss"},
	"budget": {"cat": "analytics", "size": 2, "due": 2, "public": true, "from": "boss"},
	"migration": {"cat": "tech", "size": 3, "due": 2, "public": false, "from": "taras"},
	"interviews": {"cat": "people", "size": 2, "due": 3, "public": false, "from": "marina"},
	"load_test": {"cat": "tech", "size": 2, "due": 3, "public": false, "from": "taras"},
	"mentoring": {"cat": "people", "size": 1, "due": 1, "public": false, "from": "marina"},
	"perf_reviews": {"cat": "people", "size": 1, "due": 1, "public": false, "from": "marina"},
	"dashboard": {"cat": "analytics", "size": 1, "due": 3, "public": false, "from": "taras"},
	"audit": {"cat": "routine", "size": 1, "due": 2, "public": true, "from": "boss"},
	"hiring_plan": {"cat": "people", "size": 2, "due": 3, "public": false, "from": "marina"},
	"data_cleanup": {"cat": "analytics", "size": 2, "due": 3, "public": false, "from": "taras"},
	"release": {"cat": "tech", "size": 3, "due": 4, "public": true, "from": "boss"},
	"partner_meeting": {"cat": "people", "size": 1, "due": 1, "public": true, "from": "boss"},
	"office_move": {"cat": "routine", "size": 2, "due": 3, "public": false, "from": "marina"},
	"quarter_report": {"cat": "analytics", "size": 3, "due": 4, "public": true, "from": "boss"},
	"retro": {"cat": "people", "size": 1, "due": 2, "public": false, "from": "marina"},
	"tax_report": {"cat": "routine", "size": 1, "due": 2, "public": false, "from": "boss"},
	"client_followup": {"cat": "people", "size": 2, "due": 3, "public": true, "from": "boss"},
	# Dropped on you by Irina outside the plan; you can try to refuse.
	"board_memo": {"cat": "analytics", "size": 1, "due": 1, "public": true, "from": "boss"},
	"slides_fix": {"cat": "routine", "size": 1, "due": 1, "public": true, "from": "boss"},
	"vip_call": {"cat": "people", "size": 1, "due": 1, "public": true, "from": "boss"},
	"competitor_brief": {"cat": "analytics", "size": 2, "due": 2, "public": true, "from": "boss"},
}

# Key projects arrive on fixed days; everything else comes from a shuffled deck, a few cards each
# morning. Events add and remove cards: neglect adds trouble, improvements take it away, good work
# brings more work.
const KEY_DAYS := {5: "new_feature", 6: "board_deck", 15: "quarter_report"}
const DECK := [
	"client_report", "integration", "corporate", "security_patch", "security_patch", "okr", "survey",
	"prod_fix", "prod_fix", "minutes", "angry_client", "angry_client", "interviews", "client_bug",
	"client_bug", "inventory", "pricing", "onboarding", "audit", "ab_test", "timesheets", "partner_meeting",
	"migration", "hiring_plan", "data_cleanup", "docs", "legacy_export", "client_demo", "tax_report",
	"release", "budget", "office_move", "forecast", "retro", "perf_reviews", "dashboard",
]
# Size of work drawn each morning, roughly; a day never brings two cards of the same kind.
const DAILY_LOAD := 3.4
const ATTENTION := 3

# What free people propose to do on their own, in order. Each is a small internal task; when it's
# done, it changes the decks or the people.
const INITIATIVES := {
	"alex": ["tech_debt", "automate_report"],
	"vika": ["showcase", "showcase"],
	"dima": ["self_study", "self_study"],
	"gena": ["write_docs", "automate_report"],
}
const INIT_TASKS := {
	"tech_debt": {"cat": "tech", "size": 2},
	"automate_report": {"cat": "routine", "size": 2},
	"showcase": {"cat": "analytics", "size": 1},
	"self_study": {"cat": "tech", "size": 2},
	"write_docs": {"cat": "routine", "size": 2},
}

# Things that happen inside a task while it's being worked on. Each comes up at most once per task.
# who: "owner" (the person doing it) or "from" (whoever asked for it).
# Choice effects: size / due / quality (added to the task's average) / rework (share of progress lost) /
# block (days it stands still) / hours (your own time; you were involved) / learn (owner xp) /
# mood / energy (owner) / boss / special (handled in scenes.gd).
# check: owner skill needed; "pass" and "fail" hold the effects for each outcome.
# Complications are drawn by weight; improvements set weights to zero.
const COMPLICATIONS := {
	"legacy_bug": {"cats": ["tech"], "who": "owner", "choices": {
		"fix": {"check": 3, "pass": {"size": 0.5, "quality": 0.8}, "fail": {"size": 1.5, "quality": 0.3}},
		"hack": {"quality": -1.0},
		"together": {"hours": 3, "size": 0.5, "quality": 0.5, "learn": 1.0}}},
	"needs_access": {"cats": ["tech"], "who": "owner", "choices": {
		"ask_taras": {"special": "taras"},
		"escalate": {"boss": -0.5, "special": "grudge"},
		"wait": {"block": 1}}},
	"scope_creep": {"cats": ["tech", "analytics", "people", "routine"], "who": "from", "choices": {
		"accept": {"size": 1.0, "special": "please_from"},
		"deadline": {"size": 1.0, "due": 1},
		"push_back": {"special": "annoy_from"}}},
	"bad_data": {"cats": ["analytics"], "who": "owner", "choices": {
		"clean": {"check": 3, "pass": {"size": 0.5, "quality": 0.6}, "fail": {"size": 1.5, "quality": 0.3}},
		"as_is": {"quality": -1.0},
		"together": {"hours": 2, "size": 0.5, "quality": 0.4, "learn": 1.0}}},
	"client_changes": {"cats": ["analytics", "people"], "who": "owner", "choices": {
		"redo": {"rework": 0.4},
		"negotiate": {"hours": 2, "special": "negotiate"},
		"ignore": {"quality": -1.0}}},
	"no_reply": {"cats": ["people"], "who": "owner", "choices": {
		"wait": {"block": 1},
		"push": {"energy": -1.0, "mood": -0.5},
		"you_call": {"hours": 2}}},
	"conflict": {"cats": ["people"], "who": "owner", "choices": {
		"owner_handles": {"check": 3, "pass": {"learn": 1.5, "mood": 0.5}, "fail": {"block": 1, "mood": -1.0}},
		"mediate": {"hours": 2},
		"escalate": {"block": 1}}},
	"old_system": {"cats": ["routine"], "who": "owner", "choices": {
		"manual": {"size": 1.0, "mood": -0.5},
		"ask_gena": {"special": "gena"},
		"corners": {"quality": -0.8}}},
	"missing_docs": {"cats": ["routine", "tech"], "who": "owner", "choices": {
		"dig": {"check": 2, "pass": {"size": 0.3, "learn": 1.0}, "fail": {"size": 1.0, "learn": 1.0}},
		"together": {"hours": 2},
		"corners": {"quality": -0.6}}},
}
