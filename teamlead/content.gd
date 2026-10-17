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

# How each motive takes an assignment tone (mood change on assigning).
const TONE_TASTE := {
	"craft": {"plain": 0, "growth": -1, "only_you": 2, "urgent": -1, "favor": 1, "formality": -1, "visible": 0},
	"visibility": {"plain": 0, "growth": 1, "only_you": 1, "urgent": 0, "favor": -1, "formality": -2, "visible": 2},
	"growth": {"plain": 0, "growth": 2, "only_you": 1, "urgent": 0, "favor": 0, "formality": -1, "visible": 1},
	"peace": {"plain": 0, "growth": -2, "only_you": -1, "urgent": -2, "favor": 1, "formality": 2, "visible": -1},
}

# urgent: faster but more tiring. formality: they take it lightly, quality drops.
const TONES := {
	"plain": {},
	"growth": {},
	"only_you": {},
	"urgent": {"speed": 0.25, "drain": 0.5},
	"favor": {},
	"formality": {"quality": -0.6},
	"visible": {},
}

const ONE_ON_ONE := ["praise", "listen", "push", "promise", "dayoff"]

# size: days of work for someone decent at it. due: days after arrival. public: the boss will look at it.
const TASKS := {
	"client_report": {"cat": "analytics", "size": 3, "due": 4, "public": true, "from": "boss"},
	"minutes": {"cat": "routine", "size": 1, "due": 2, "public": false, "from": "boss"},
	"corporate": {"cat": "people", "size": 2, "due": 5, "public": false, "from": "marina"},
	"integration": {"cat": "tech", "size": 3, "due": 5, "public": false, "from": "taras"},
	"onboarding": {"cat": "people", "size": 2, "due": 3, "public": false, "from": "marina"},
	"okr": {"cat": "analytics", "size": 2, "due": 3, "public": true, "from": "boss"},
	"prod_fix": {"cat": "tech", "size": 1, "due": 1, "public": true, "from": "boss"},
	"survey": {"cat": "people", "size": 1, "due": 3, "public": false, "from": "marina"},
	"board_deck": {"cat": "analytics", "size": 3, "due": 4, "public": true, "from": "boss"},
	"legacy_export": {"cat": "routine", "size": 2, "due": 3, "public": false, "from": "boss"},
	"client_bug": {"cat": "tech", "size": 2, "due": 2, "public": true, "from": "boss"},
	"docs": {"cat": "routine", "size": 2, "due": 4, "public": false, "from": "taras"},
	"migration": {"cat": "tech", "size": 4, "due": 5, "public": false, "from": "taras"},
	"interviews": {"cat": "people", "size": 2, "due": 3, "public": false, "from": "marina"},
	"budget": {"cat": "analytics", "size": 3, "due": 4, "public": true, "from": "boss"},
	"audit": {"cat": "routine", "size": 2, "due": 2, "public": true, "from": "boss"},
}

# Which tasks arrive on which morning.
const SCHEDULE := {
	1: ["client_report", "minutes", "corporate"],
	2: ["integration"],
	3: ["onboarding", "okr"],
	4: ["prod_fix"],
	5: ["survey"],
	6: ["board_deck", "legacy_export"],
	7: ["client_bug", "docs"],
	8: ["migration", "interviews"],
	9: ["budget"],
	10: ["audit"],
}
