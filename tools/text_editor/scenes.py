"""Scenes as structure for the visual editor: read a scene out of its .dlg file, check it, write it back.

A scene is {"id", "file", "src", "header": [{"key", "value"} | {"comment"}], "nodes": [node]}.
The first node is the start (label ""), the rest are the "-- label" branches in file order.
A node is {"label", "items": [item], "lead": [comment above the branch]}; an item is one of
  {"type": "line", "who", "emo", "ru", "en", "cond": [term]}
  {"type": "narr", "ru", "en", "cond"}
  {"type": "choice", "ru", "en", "to", "cond", "open"}     open: how the question moves openness (talks), or ""
  {"type": "fx", "words": [str], "cond"}
  {"type": "jump", "to", "cond"}
  {"type": "comment", "text"}
A term is a string as written in the file: "flag x", "not here vika".
"src" is the scene's text as it was read: saving refuses if the file has changed under you since.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DLG_DIR = ROOT / "data" / "dialogues"
CATALOG = ROOT / "data" / "dialogue_catalog.json"
CODE_DIR = ROOT / "teamlead"
ID_RE = re.compile(r"^[A-Za-z_][A-Za-z_0-9]*$")
HEAD_KEYS = ("who", "topic", "when", "at", "place")


def catalog():
    return json.loads(CATALOG.read_text(encoding="utf-8"))


# ---------- reading ----------

def _blocks(lines):
    """Where each scene sits in a file: (id, first line, last content line). Comments and blank lines
    right before the next scene belong to that next scene's lead-in, not to this one."""
    out = []
    starts = [i for i, raw in enumerate(lines) if raw.strip().startswith("==")]
    for n, a in enumerate(starts):
        b = (starts[n + 1] if n + 1 < len(starts) else len(lines)) - 1
        while b > a and (not lines[b].strip() or lines[b].strip().startswith("#")):
            b -= 1
        out.append((lines[a].strip()[2:].strip(), a, b))
    return out


def _cond(s):
    if s.startswith("{if "):
        close = s.find("}")
        if close > 0:
            terms = [t.strip() for t in s[4:close].split(",") if t.strip()]
            return terms, s[close + 1:].strip()
    return [], s


def _item(rest, cond):
    if rest.startswith("->"):
        return {"type": "jump", "to": rest[2:].strip(), "cond": cond}
    if rest.startswith(">"):
        return {"type": "fx", "words": rest[1:].split(), "cond": cond}
    if rest.startswith("- "):
        return {"type": "narr", "ru": rest[2:].strip(), "en": "", "cond": cond}
    if rest.startswith("*") or rest.startswith("?"):
        body = rest[1:].strip()
        arrow = body.rfind("->")
        to = body[arrow + 2:].strip() if arrow >= 0 else ""
        text = body[:arrow].strip() if arrow >= 0 else body
        m = re.search(r"\s*\(open ([+-]?\d+)\)$", text)
        opened = ""
        if m:
            opened, text = m.group(1), text[: m.start()]
        return {"type": "choice", "ru": text, "en": "", "to": to, "cond": cond, "open": opened, "ask": rest.startswith("?")}
    m = re.match(r"^([A-Za-z_0-9]+)(?:\s*\[([a-z_]+)\])?:\s?(.*)$", rest)
    if m:
        return {"type": "line", "who": m.group(1), "emo": m.group(2) or "", "ru": m.group(3).strip(), "en": "", "cond": cond}
    return {"type": "comment", "text": "(не разобрано) " + rest}


def parse_block(lines):
    sid = lines[0].strip()[2:].strip()
    scene = {"id": sid, "header": [], "nodes": [{"label": "", "items": []}]}
    node = scene["nodes"][0]
    last = None
    in_head = True
    for raw in lines[1:]:
        s = raw.strip()
        if not s:
            continue
        if s.startswith("#"):
            (scene["header"] if in_head else node["items"]).append({"type": "comment", "text": s[1:].strip()} if not in_head else {"comment": s[1:].strip()})
            continue
        key = s.split(":")[0]
        if in_head and key in HEAD_KEYS and ":" in s:
            scene["header"].append({"key": key, "value": s[len(key) + 1:].strip()})
            continue
        in_head = False
        if s.startswith("en:") and raw.startswith(" "):
            if last is not None:
                last["en"] = s[3:].strip()
            continue
        if s.startswith("--"):
            # Comments right above a branch are about that branch.
            lead = []
            while node["items"] and node["items"][-1]["type"] == "comment":
                lead.insert(0, node["items"].pop()["text"])
            node = {"label": s[2:].strip(), "items": [], "lead": lead}
            scene["nodes"].append(node)
            last = None
            continue
        cond, rest = _cond(s)
        item = _item(rest, cond)
        node["items"].append(item)
        last = item if item["type"] in ("line", "narr", "choice") else None
    return scene


def read_scene(sid):
    for path in sorted(DLG_DIR.glob("*.dlg")):
        lines = path.read_text(encoding="utf-8").split("\n")
        for bid, a, b in _blocks(lines):
            if bid == sid:
                scene = parse_block(lines[a:b + 1])
                scene["file"] = path.name
                scene["src"] = "\n".join(lines[a:b + 1])
                return scene
    raise ValueError("нет сцены " + sid)


def all_scenes():
    out = []
    for path in sorted(DLG_DIR.glob("*.dlg")):
        lines = path.read_text(encoding="utf-8").split("\n")
        for bid, a, b in _blocks(lines):
            sc = parse_block(lines[a:b + 1])
            sc["file"] = path.name
            out.append(sc)
    return out


# ---------- writing ----------

def _prefix(cond):
    return "{if %s} " % ", ".join(cond) if cond else ""


def write_block(scene):
    out = ["== " + scene["id"]]
    for h in scene["header"]:
        if "comment" in h:
            out.append("# " + h["comment"])
        elif h.get("value", "").strip():
            out.append("%s: %s" % (h["key"], h["value"].strip()))
    for n, node in enumerate(scene["nodes"]):
        if n > 0:
            out.append("")
            out += ["# " + c for c in node.get("lead", [])]
            out.append("-- " + node["label"])
        elif node["items"]:
            out.append("")
        for it in node["items"]:
            t = it["type"]
            pre = _prefix(it.get("cond", []))
            if t == "comment":
                out.append("# " + it["text"])
                continue
            if t == "jump":
                out.append(pre + "-> " + it["to"])
                continue
            if t == "fx":
                out.append(pre + "> " + " ".join(it["words"]))
                continue
            text = " ".join(it.get("ru", "").split())
            if t == "narr":
                out.append(pre + "- " + text)
            elif t == "choice":
                mark = "?" if it.get("ask") else "*"
                opened = " (open %s)" % it["open"] if it.get("open") else ""
                out.append("%s%s %s%s -> %s" % (pre, mark, text, opened, it["to"]))
            else:
                out.append("%s%s%s: %s" % (pre, it["who"], " [%s]" % it["emo"] if it.get("emo") else "", text))
            out.append("  en: " + " ".join(it.get("en", "").split()))
    return "\n".join(out)


def save_scene(scene, src):
    """Write a scene back where it was (or at the end of its file if it's new). src is what the editor
    started from: if the file has something else there now, nothing is written."""
    problems = [p for p in check_scene(scene) if p["level"] == "error"]
    if problems:
        raise ValueError("не сохранено, в сцене ошибки: " + "; ".join(p["text"] for p in problems[:5]))
    name = scene["file"]
    if not re.match(r"^[a-z0-9_]+\.dlg$", name):
        raise ValueError("имя файла: латиница, цифры и _, на конце .dlg")
    path = DLG_DIR / name
    block = write_block(scene).split("\n")
    old_id = scene.get("old_id") or scene["id"]
    if path.exists():
        lines = path.read_text(encoding="utf-8").split("\n")
    else:
        lines = ["# " + name, ""]
    where = [x for x in _blocks(lines) if x[0] == old_id]
    if where:
        _, a, b = where[0]
        if "\n".join(lines[a:b + 1]) != src:
            raise ValueError("сцену в файле уже поменяли, обновите страницу")
        lines[a:b + 1] = block
    else:
        if src:
            raise ValueError("сцены в файле больше нет, обновите страницу")
        if any(x[0] == scene["id"] for f in DLG_DIR.glob("*.dlg") for x in _blocks(f.read_text(encoding="utf-8").split("\n"))):
            raise ValueError("сцена %s уже есть" % scene["id"])
        while lines and not lines[-1].strip():
            lines.pop()
        lines += [""] + block + [""]
    path.write_text("\n".join(lines), encoding="utf-8")
    return read_scene(scene["id"])


def delete_scene(sid, src):
    for path in sorted(DLG_DIR.glob("*.dlg")):
        lines = path.read_text(encoding="utf-8").split("\n")
        for bid, a, b in _blocks(lines):
            if bid == sid:
                if "\n".join(lines[a:b + 1]) != src:
                    raise ValueError("сцену в файле уже поменяли, обновите страницу")
                del lines[a:b + 1]
                # One blank line where the scene was, one newline at the end of the file.
                while a < len(lines) and a > 0 and not lines[a].strip() and not lines[a - 1].strip():
                    del lines[a]
                while len(lines) > 1 and not lines[-1].strip() and not lines[-2].strip():
                    lines.pop()
                path.write_text("\n".join(lines), encoding="utf-8")
                return
    raise ValueError("нет сцены " + sid)


# ---------- what's known: speakers, tasks, flags ----------

def speakers():
    text = (ROOT / "teamlead" / "locale.gd").read_text(encoding="utf-8")
    ids = sorted(set(re.findall(r'"name\.([a-z_0-9]+)\.nom"', text)))
    return [i for i in ids if not i.startswith("hire")] + ["you"]


def task_ids():
    out = []
    for name in ("tasks.tsv", "improvements.tsv"):
        rows = (ROOT / "data" / name).read_text(encoding="utf-8").split("\n")[1:]
        out += [r.split("\t")[0] for r in rows if r.strip()]
    return out


# flags["x"] = …, flags["x_" + p] = …, flags["x_%s" % [p]] = …; and reading them with has/get/erase or [].
_KEY = r'"([^"]+)"\s*(\+[^\]\)]*|%\s*(?:\[(?:[^\[\]]|\[[^\]]*\])*\]|[^\]\)]+))?'
FLAG_SET_RE = re.compile(r'flags\[\s*' + _KEY + r'\]\s*=(?!=)')
FLAG_READ_RE = re.compile(r'flags\.(?:has|get|erase)\(\s*' + _KEY + r'|flags\[\s*' + _KEY + r'\](?!\s*=(?!=))')


def _pattern(name, tail=""):
    """A key built in code ("thread_%s_%d", "story_" + id) as a pattern: thread_*_*, story_*."""
    return re.sub(r"%[sd]", "*", name) + ("*" if (tail or "").strip().startswith("+") else "")


def flag_map():
    """Every flag: which scenes and which code set it, and which read it."""
    flags = {}

    def add(name, kind, where):
        f = flags.setdefault(name, {"set": [], "read": []})
        if where not in f[kind]:
            f[kind].append(where)

    for sc in all_scenes():
        sid = sc["id"]
        add("story_" + sid, "set", "сцена %s (сама, когда сыграна)" % sid)
        for node in sc["nodes"]:
            for it in node["items"]:
                for term in it.get("cond", []):
                    w = term.split()
                    if w[:1] == ["not"]:
                        w = w[1:]
                    if w[:1] == ["flag"] and len(w) > 1:
                        add(w[1], "read", "сцена " + sid)
                if it["type"] == "choice" and it["to"]:
                    add("%s:%s" % (sid, it["to"]), "set", "сцена %s (выбор ведёт в %s)" % (sid, it["to"]))
                if it["type"] == "fx" and it["words"][:1] in (["flag"], ["days"]) and len(it["words"]) > 1:
                    add(it["words"][1], "set", "сцена " + sid)
                if it["type"] == "fx" and it["words"][:1] == ["unflag"] and len(it["words"]) > 1:
                    add(it["words"][1], "read", "сцена %s (снимает)" % sid)
                if it["type"] == "fx" and it["words"][:1] == ["openings"]:
                    add("asked_people", "set", "сцена %s (> openings)" % sid)
        for h in sc["header"]:
            if h.get("key") == "when":
                for term in h["value"].split(","):
                    w = term.split()
                    if w[:1] == ["not"]:
                        w = w[1:]
                    if w[:1] == ["flag"] and len(w) > 1:
                        add(w[1], "read", "сцена %s (условие запуска)" % sid)
    for path in sorted(CODE_DIR.glob("*.gd")):
        for n, raw in enumerate(path.read_text(encoding="utf-8").split("\n"), start=1):
            where = "код %s:%d" % (path.name, n)
            sets = set()
            for m in FLAG_SET_RE.finditer(raw):
                add(_pattern(m.group(1), m.group(2)), "set", where)
                sets.add(m.start())
            for m in FLAG_READ_RE.finditer(raw):
                if m.start() in sets:
                    continue
                name, tail = (m.group(1), m.group(2)) if m.group(1) else (m.group(3), m.group(4))
                add(_pattern(name, tail), "read", where)
    # Flags built in code ("thread_*_*") cover the concrete ones the scenes use (thread_alex_3).
    patterns = [k for k in flags if "*" in k]
    for name, f in flags.items():
        if "*" in name or f["set"]:
            continue
        for p in patterns:
            if re.fullmatch(re.escape(p).replace(r"\*", "[^ ]+"), name):
                f["set"] += [w + " (как %s)" % p for w in flags[p]["set"] if w + " (как %s)" % p not in f["set"]]
                f["read"] += [w + " (как %s)" % p for w in flags[p]["read"] if w + " (как %s)" % p not in f["read"]]
    return flags


# ---------- checking ----------

def _range_ok(s):
    return re.fullmatch(r"\d+(-\d+)?", s) is not None


def _arg_ok(kind, value, ctx):
    if kind == "range":
        return _range_ok(value)
    if kind in ("person",):
        return value in ctx["people"] or value == "them"
    if kind == "work_state":
        return value in ("on_track", "behind", "stuck")
    if kind == "drives":
        return value in ("craft", "growth", "visibility", "peace")
    if kind == "category":
        return value in ("pipelines", "infra", "portal", "support", "done")
    if kind == "cmp":
        return value in (">=", ">", "<", "<=")
    if kind == "number":
        return re.fullmatch(r"[+-]?\d+(\.\d+)?", value) is not None
    if kind == "delta":
        return re.fullmatch(r"[+-]?\d+(\.\d+)?", value) is not None
    if kind in ("style", "styles"):
        return value in ("P", "A", "E", "I")
    if kind == "bosses":
        return value in ("P", "A", "E", "I", "X")
    if kind == "task":
        return value in ctx["tasks"] or value == "incident"
    if kind == "known":
        return value in ("drive", "hates") or value in ("skill.pipelines", "skill.infra", "skill.portal", "skill.support")
    return bool(value)


def _check_words(words, table, what, ctx):
    """Problems with a condition term or an effect, as text; [] if it's fine."""
    if not words:
        return ["пустое " + what]
    spec = table.get(words[0])
    if spec is None:
        return ["неизвестное %s «%s»" % (what, " ".join(words))]
    args, given = spec["args"], words[1:]
    out = []
    many = args and args[-1] in ("people", "styles", "bosses", "drives")
    if len(given) < len(args) or (not many and len(given) > len(args) and words[0] != "give"):
        out.append("«%s»: нужно так: %s" % (" ".join(words), spec["example"]))
        return out
    for i, kind in enumerate(args):
        values = given[i:] if kind in ("people", "styles", "bosses", "drives") else [given[i]]
        kind1 = {"people": "person"}.get(kind, kind)
        for v in values:
            if not _arg_ok(kind1, v, ctx):
                out.append("«%s»: «%s» — не %s" % (" ".join(words), v, ctx["catalog"]["args"].get(kind, kind)))
    return out


def context():
    cat = catalog()
    return {"catalog": cat, "people": speakers(), "tasks": task_ids()}


def check_scene(scene, ctx=None, flags=None):
    """[{"level": "error"|"warn", "node", "text"}]: errors break the scene in the game, warnings are worth a look."""
    ctx = ctx or context()
    cat = ctx["catalog"]
    out = []

    def bad(level, node, text):
        out.append({"level": level, "node": node, "text": text})

    if not ID_RE.match(scene["id"]):
        bad("error", "", "id сцены: латиница, цифры и _")
    labels = [n["label"] for n in scene["nodes"][1:]]
    for l in set(labels):
        if labels.count(l) > 1:
            bad("error", l, "ветка %s есть дважды" % l)
    for l in labels:
        if not ID_RE.match(l or "-"):
            bad("error", l, "имя ветки «%s»: латиница, цифры и _" % l)
    has_when = False
    talk = any(h.get("key") == "topic" for h in scene["header"])
    for h in scene["header"]:
        if h.get("key") == "topic" and h["value"] not in cat["topics"]:
            bad("error", "", "тема «%s» не из списка" % h["value"])
        if h.get("key") == "who" and not (h["value"] in ctx["people"] or h["value"] in ("any", "hire") or h["value"].startswith("hire_")):
            bad("error", "", "who: «%s» — нет такого" % h["value"])
        if h.get("key") == "when":
            has_when = True
            for term in [t.strip() for t in h["value"].split(",") if t.strip()]:
                w = term.split()
                for p in _check_words(w[1:] if w[0] == "not" else w, cat["terms"], "условие", ctx):
                    bad("error", "", "условие запуска: " + p)
        if h.get("key") == "place" and h["value"] not in cat["places"]:
            bad("error", "", "место «%s» не из списка" % h["value"])
        if h.get("key") == "at" and h["value"] not in cat["at"]:
            bad("error", "", "время «%s»: morning или evening" % h["value"])
    if talk and not any(h.get("key") == "who" for h in scene["header"]):
        bad("error", "", "у разговорной сцены нет who:")
    if not has_when and not talk:
        bad("warn", "", "нет условия запуска: сцена начнётся в первое же утро")
    reached = {""}
    for node in scene["nodes"]:
        lbl = node["label"]
        for it in node["items"]:
            for term in it.get("cond", []):
                w = term.split()
                for p in _check_words(w[1:] if w and w[0] == "not" else w, cat["terms"], "условие", ctx):
                    bad("error", lbl, p)
                if flags is not None and w and (w[1:2] if w[0] == "not" else w[:1]) == ["flag"]:
                    name = w[2] if w[0] == "not" else w[1]
                    if not flags.get(name, {}).get("set"):
                        bad("warn", lbl, "отметку %s нигде не ставят" % name)
            t = it["type"]
            if t in ("choice", "jump"):
                if it["to"] != "end" and it["to"] not in labels:
                    bad("error", lbl, "ведёт в несуществующую ветку «%s»" % it["to"])
                reached.add(it["to"])
            if t == "fx":
                for p in _check_words(it["words"], cat["fx"], "эффект", ctx):
                    bad("error", lbl, p)
            if t == "choice" and it.get("ask") and not talk:
                bad("error", lbl, "вопрос (?) бывает только в разговоре один на один")
            if t == "line":
                if it["who"] == "them" and talk:
                    pass
                elif it["who"] not in ctx["people"]:
                    bad("error", lbl, "неизвестно, кто говорит: %s" % it["who"])
                if it.get("emo") and it["emo"] not in cat["emotions"]:
                    bad("error", lbl, "неизвестная эмоция %s" % it["emo"])
            if t in ("line", "narr", "choice"):
                if not it.get("ru", "").strip():
                    bad("warn", lbl, "пустая строка")
                if not it.get("en", "").strip():
                    bad("warn", lbl, "нет перевода: «%s»" % it.get("ru", "")[:40])
                if "—" in it.get("ru", ""):
                    bad("warn", lbl, "длинное тире: «%s»" % it.get("ru", "")[:40])
    react = talk and any(h.get("key") == "topic" and h["value"] == "react" for h in scene["header"])
    for l in labels:
        if l not in reached and not react:
            bad("warn", l, "в ветку %s ничего не ведёт" % l)
    return out


def check_all():
    ctx = context()
    flags = flag_map()
    out = []
    seen = {}
    for sc in all_scenes():
        if sc["id"] in seen:
            out.append({"scene": sc["id"], "level": "error", "node": "", "text": "сцена есть дважды: %s и %s" % (seen[sc["id"]], sc["file"])})
        seen[sc["id"]] = sc["file"]
        for p in check_scene(sc, ctx, flags):
            p["scene"] = sc["id"]
            out.append(p)
    return out
