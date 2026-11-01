extends SceneTree
# Checks every scene in data/dialogues: format errors, speakers, moods, effects, missing English.
# Run: Godot --headless --path . -s tools/check_dialogues.gd
const D = preload("res://teamlead/dialogue.gd")
const C = preload("res://teamlead/content.gd")
const Loc = preload("res://teamlead/locale.gd")
func _initialize() -> void:
	var bad: Array = D.ERRORS.duplicate()
	for id in D.ORDER:
		var sc: Dictionary = D.SCENES[id]
		for op in sc["ops"]:
			var where: String = op.get("where", sc["where"])
			if op["op"] == "line":
				if op["who"] == "them" and sc["topic"] == "":
					bad.append("%s: them speaks only in talk scenes" % where)
				elif op["who"] in ["", "you", "them"]:
					pass
				elif not Loc.has_key("name.%s.nom" % op["who"]):
					bad.append("%s: unknown speaker %s" % [where, op["who"]])
				if not op["who"] in ["", "you", "them"] and not Loc.has_key("name.%s.ins" % op["who"]):
					bad.append("%s: no name.%s.ins" % [where, op["who"]])
				if op["emo"] != "" and not Loc.has_key("emo." + op["emo"]):
					bad.append("%s: unknown mood %s" % [where, op["emo"]])
				if op["en"] == "":
					bad.append("%s: no en:" % where)
			if op["op"] == "choices":
				for item in op["items"]:
					if item["en"] == "":
						bad.append("%s: choice without en:" % item["where"])
			if op["op"] == "fx":
				var w: Array = op["words"]
				if w[0] == "give" and not C.TASKS.has(w[1]):
					bad.append("%s: give %s — no such task" % [sc["where"], w[1]])
				if w[0] in ["task", "shrink"] and w[1] != "incident" and not C.TASKS.has(w[1]):
					bad.append("%s: %s %s — no such task" % [sc["where"], w[0], w[1]])
				if w[0] in ["mood", "trust", "energy", "give", "days", "grab", "drop"] and w.size() < 3:
					bad.append("%s: %s needs more words" % [sc["where"], " ".join(w)])
		if sc["topic"] != "" and not D.TOPICS.has(sc["topic"]):
			bad.append("%s: unknown topic %s" % [sc["where"], sc["topic"]])
		if sc["topic"] != "" and sc["who"] == "":
			bad.append("%s: a talk scene needs who:" % sc["where"])
	print("scenes: ", D.ORDER.size(), "  talks: ", D.ORDER.filter(func(x): return D.SCENES[x]["topic"] != "").size(), "  problems: ", bad.size())
	for b in bad: print("  ", b)
	quit()
