extends RefCounted
# Story conversations, written as plays in data/dialogues/*.dlg (the format is in docs/dialogues.md).
# Each file is read once into SCENES: id -> {"id", "when": [terms], "place", "ops": [...], "labels": {label: op index}}.
# place is where it happens (art/backgrounds/<place>.png behind the portrait); without place: it's the openspace,
# by day in the morning and still lit in the evening (office_night is the empty one, everyone gone).
# rules.gd walks the ops; main.gd shows them on their own screen.
#
# Ops:
#   {"op": "line", "who", "emo", "ru", "en", "if": [terms]}   who: a person id, "you", or "" for narration
#   {"op": "choices", "items": [{"ru", "en", "to", "if", "ask", "open"}]}
#       "* text -> label" is a choice; "? text (open +1) -> label" a question in a talk (ask, and how it moves openness)
#   {"op": "fx", "words": [String], "if"}
#   {"op": "jump", "to", "if"}
#   {"op": "label", "name"}                                    reached by falling through: the scene ends
# A condition term is [word, args...]: chapter / day / here / flag / not.
#
# Which conditions, effects and places exist is in data/dialogue_catalog.json, with what each one means:
# the text editor (tools/text_editor) reads the same file. A new one in rules.gd goes there too.

const DIR := "res://data/dialogues"
const CATALOG := "res://data/dialogue_catalog.json"
static var FX: Array = []
static var PLACES: Array = []
static var TERMS: Array = ["not"]
static var TOPICS := {} # talk topics: {"heat", "ru"}

static var SCENES := {}
# Talk scenes (one-on-ones, rules.gd) by topic: they have "topic:" and "who:" and never start on their own.
static var TALKS := {}
static var ORDER: Array[String] = []
static var ERRORS: Array[String] = []


static func _static_init() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if catalog is Dictionary:
		FX = catalog["fx"].keys()
		PLACES = catalog["places"].keys()
		TERMS = ["not"] + catalog["terms"].keys()
		TOPICS = catalog["topics"]
	else:
		ERRORS.append("%s: can't read" % CATALOG)
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".dlg"):
			files.append(f)
	files.sort()
	for f in files:
		_parse(DIR + "/" + f)


static func _parse(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		ERRORS.append("%s: can't open" % path)
		return
	var scene := {}
	var last := {} # the line or choice an "en:" belongs to
	var n := 0
	while not file.eof_reached():
		var raw := file.get_line()
		n += 1
		var s := raw.strip_edges()
		var where := "%s:%d" % [path.get_file(), n]
		if s == "" or s.begins_with("#"):
			continue
		if s.begins_with("=="):
			if not scene.is_empty():
				_finish(scene)
			var id := s.substr(2).strip_edges()
			if SCENES.has(id):
				ERRORS.append("%s: scene %s defined twice" % [where, id])
			scene = {"id": id, "when": [], "at": "morning", "ops": [], "labels": {}, "where": where, "topic": "", "who": ""}
			last = {}
			continue
		if scene.is_empty():
			ERRORS.append("%s: text before the first == scene" % where)
			continue
		var ops: Array = scene["ops"]
		if s.begins_with("en:"):
			if last.is_empty():
				ERRORS.append("%s: en: with nothing to translate" % where)
			else:
				last["en"] = s.substr(3).strip_edges()
			continue
		if s.begins_with("at:"):
			scene["at"] = s.substr(3).strip_edges()
			if not scene["at"] in ["morning", "evening"]:
				ERRORS.append("%s: at: is morning or evening" % where)
			continue
		if s.begins_with("place:"):
			scene["place"] = s.substr(6).strip_edges()
			if not scene["place"] in PLACES:
				ERRORS.append("%s: place: is one of %s" % [where, ", ".join(PLACES)])
			continue
		if s.begins_with("topic:") or s.begins_with("who:"):
			var key := s.substr(0, s.find(":"))
			scene[key] = s.substr(key.length() + 1).strip_edges()
			continue
		if s.begins_with("when:"):
			scene["when"] = _terms(s.substr(5), where)
			continue
		if s.begins_with("--"):
			var name := s.substr(2).strip_edges()
			scene["labels"][name] = ops.size()
			ops.append({"op": "label", "name": name})
			last = {}
			continue
		var cond: Array = []
		if s.begins_with("{if "):
			var close := s.find("}")
			cond = _terms(s.substr(4, close - 4), where)
			s = s.substr(close + 1).strip_edges()
		if s.begins_with("*") or s.begins_with("?"):
			var body := s.substr(1).strip_edges()
			var arrow := body.rfind("->")
			if arrow < 0:
				ERRORS.append("%s: a choice needs -> where it leads" % where)
				continue
			var text := body.substr(0, arrow).strip_edges()
			var opened := 0
			var mark := text.rfind("(open ")
			if mark >= 0 and text.ends_with(")"):
				opened = int(text.substr(mark + 6, text.length() - mark - 7))
				text = text.substr(0, mark).strip_edges()
			var item := {"ru": text, "en": "", "to": body.substr(arrow + 2).strip_edges(), "if": cond, "where": where,
				"ask": s.begins_with("?"), "open": opened}
			if ops.is_empty() or ops[-1]["op"] != "choices":
				ops.append({"op": "choices", "items": []})
			ops[-1]["items"].append(item)
			last = item
			continue
		if s.begins_with(">"):
			var words := Array(s.substr(1).strip_edges().split(" ", false))
			if words.is_empty() or not FX.has(words[0]):
				ERRORS.append("%s: unknown effect %s" % [where, s])
			ops.append({"op": "fx", "words": words, "if": cond})
			last = {}
			continue
		if s.begins_with("->"):
			ops.append({"op": "jump", "to": s.substr(2).strip_edges(), "if": cond, "where": where})
			last = {}
			continue
		if s.begins_with("- "):
			var line := {"op": "line", "who": "", "emo": "", "ru": s.substr(2).strip_edges(), "en": "", "if": cond, "where": where}
			ops.append(line)
			last = line
			continue
		var colon := s.find(":")
		if colon < 0:
			ERRORS.append("%s: can't read this line" % where)
			continue
		var head := s.substr(0, colon).strip_edges()
		var who := head
		var emo := ""
		var bracket := head.find("[")
		if bracket >= 0:
			who = head.substr(0, bracket).strip_edges()
			emo = head.substr(bracket + 1, head.find("]") - bracket - 1).strip_edges()
		var spoken := {"op": "line", "who": who, "emo": emo, "ru": s.substr(colon + 1).strip_edges(), "en": "", "if": cond, "where": where}
		ops.append(spoken)
		last = spoken
	if not scene.is_empty():
		_finish(scene)


static func _terms(text: String, where: String) -> Array:
	var out: Array = []
	for part in text.split(",", false):
		var words := Array(part.strip_edges().split(" ", false))
		if words.is_empty():
			continue
		if not TERMS.has(words[0]):
			ERRORS.append("%s: unknown condition %s" % [where, part.strip_edges()])
		out.append(words)
	return out


# Every jump and choice has to land somewhere.
static func _finish(scene: Dictionary) -> void:
	if not scene.has("place"):
		scene["place"] = "office_evening" if scene["at"] == "evening" else "office_day"
	for op in scene["ops"]:
		var targets: Array = []
		if op["op"] == "jump":
			targets.append([op["to"], op["where"]])
		elif op["op"] == "choices":
			for item in op["items"]:
				targets.append([item["to"], item["where"]])
		for t in targets:
			if t[0] != "end" and not scene["labels"].has(t[0]):
				ERRORS.append("%s: no -- %s in scene %s" % [t[1], t[0], scene["id"]])
	if scene["topic"] != "":
		if not TALKS.has(scene["topic"]):
			TALKS[scene["topic"]] = []
		TALKS[scene["topic"]].append(scene["id"])
	SCENES[scene["id"]] = scene
	ORDER.append(scene["id"])


# "3-6" or "3" as an inclusive range.
static func in_range(text: String, value: int) -> bool:
	var parts := text.split("-")
	var lo := int(parts[0])
	var hi := int(parts[1]) if parts.size() > 1 else lo
	return value >= lo and value <= hi
