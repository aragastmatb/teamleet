extends RefCounted
# Content for the team lead prototype: two working weeks. All text lives in locale.gd.
#
# Every number here is hidden. The player sees moods, energy and progress in words and bars,
# and learns skills and motives through results and one-on-ones.

const DAYS := 10
const REVIEW_DAYS := [5, 10]

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

const ONE_ON_ONE := ["praise", "listen", "push", "promise", "dayoff"]

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
}

# Which tasks arrive on which morning. Ids can repeat (the weekly report, another outage).
const SCHEDULE := {
	1: ["client_report", "minutes", "corporate", "weekly_report"],
	2: ["integration", "timesheets", "security_patch"],
	3: ["onboarding", "okr", "ab_test", "inventory", "dashboard"],
	4: ["prod_fix", "pricing", "newsletter", "load_test"],
	5: ["survey", "new_feature", "angry_client", "vendor_contract"],
	6: ["board_deck", "legacy_export", "weekly_report", "forecast", "interviews"],
	7: ["client_bug", "docs", "client_demo", "mentoring"],
	8: ["migration", "budget", "prod_fix", "audit"],
	9: ["perf_reviews"],
	10: ["timesheets"],
}
