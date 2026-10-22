extends RefCounted
# Opens the game right where a test starts (tools/test.sh <point>), so a playtest doesn't begin with
# a fortnight of getting there. A point is a story scene id (data/dialogues), a chat scene id
# (scenes.gd, e.g. dima_question), or chapter2..chapter4 for the first morning of a chapter.
# The days before are played by a stand-in who gives work to whoever is best at it and least busy,
# answers everything with the first option, and lets other conversations play out on the way.

const C = preload("res://teamlead/content.gd")
const Dialogue = preload("res://teamlead/dialogue.gd")

const MAX_STEPS := 4000
const ATTEMPTS := 12


static func points() -> Array:
	return Dialogue.ORDER + ["dima_question", "chapter2", "chapter3", "chapter4"]


# Plays on until the point; false if the run ended or the point never came up.
static func reach(r, point: String) -> bool:
	var target_chapter := int(point.trim_prefix("chapter")) if point.begins_with("chapter") else 0
	for i in MAX_STEPS:
		if _arrived(r, point, target_chapter):
			return true
		if not r.convo.is_empty():
			r.convo_choose("end")
			continue
		match r.phase:
			"story":
				if r.story["wait"] == "line":
					r.story_next()
				else:
					r.story_choose(r.story_choices()[0]["i"])
			"standup":
				r.standup_close()
			"event":
				r.resolve_event(r.events[0]["choices"][0])
			"plan":
				_plan(r)
				r.end_day()
			"review":
				r.answer_review(r.review_choices(r.review[0])[0])
			"report":
				r.continue_report()
			"evening":
				r.next()
			"chapter_end":
				if not r.next_chapter_ready():
					return false
				r.start_next_chapter()
			_:
				return false
	return false


static func _arrived(r, point: String, target_chapter: int) -> bool:
	if target_chapter > 0:
		return r.chapter == target_chapter and r.phase in ["plan", "event", "story"]
	if r.phase == "story":
		return r.story["id"] == point
	if r.phase == "event":
		return r.events[0]["id"] == point
	return false


static func _plan(r) -> void:
	for t in r.inbox():
		var best := ""
		var best_score := -99.0
		for p in r.team:
			if not r.available(p) or r.people[p]["absent"]:
				continue
			var load := 0.0
			for q in r.queue_of(p):
				load += q["size"] - q["progress"]
			var score: float = 0.7 * r.people[p]["skills"][t["cat"]] - load
			if score > best_score:
				best = p
				best_score = score
		if best == "":
			continue
		r.assign(t["uid"], best)
		if not r.pending.is_empty():
			r.persuade("back_off" if r.pending["reason"] == "tired" else "honest")
