#!/usr/bin/env python3
"""Team1337 text editor: every line of dialogue and text in the game on one page, edited in place.

Run from the project root:  python3 tools/text_editor/server.py
It opens http://127.0.0.1:8765 and writes straight back into the game's files:
  data/dialogues/*.dlg   story scenes (the line's text and its en: translation)
  teamlead/locale.gd     chat events, talks, reactions, interface (the "ru" and "en" tables)
  data/*.tsv             task and improvement texts (the *_ru / *_en columns)
Notes and "done" marks live in data/text_notes.json. Standard library only; listens on this machine only.
"""
import json
import os
import re
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, unquote

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
DLG_DIR = ROOT / "data" / "dialogues"
LOCALE = ROOT / "teamlead" / "locale.gd"
NOTES = ROOT / "data" / "text_notes.json"
PORT = 8765

PEOPLE = ["alex", "vika", "dima", "gena", "taras", "boss", "marina", "boris", "stas", "olga", "oleg", "palych", "buyer", "you"]

# ---------- story scenes (.dlg) ----------

LINE_RE = re.compile(r"^(?P<who>[a-z_0-9]+)(?:\s*\[(?P<emo>[a-z_]+)\])?:\s(?P<text>.*)$")
CHOICE_RE = re.compile(r"^\*\s(?P<text>.*?)\s->\s(?P<to>[A-Za-z_0-9]+)\s*$")
COND_RE = re.compile(r"^(?P<cond>\{if [^}]*\})\s*(?P<rest>.*)$")


def _split_cond(s):
    m = COND_RE.match(s)
    return (m.group("cond"), m.group("rest")) if m else ("", s)


def parse_dlg(path):
    """A file as scenes, each a list of rows in order: text rows are editable, the rest is context."""
    lines = path.read_text(encoding="utf-8").split("\n")
    scenes, scene, last = [], None, None
    for i, raw in enumerate(lines):
        s = raw.strip()
        if not s:
            continue
        if s.startswith("#"):
            if scene is not None:
                scene["rows"].append({"type": "comment", "text": s[1:].strip()})
            continue
        if s.startswith("=="):
            scene = {"id": s[2:].strip(), "file": path.name, "meta": [], "rows": []}
            scenes.append(scene)
            last = None
            continue
        if scene is None:
            continue
        if s.startswith("en:") and raw.startswith(" "):
            if last is not None:
                last["en"] = s[3:].strip()
                last["en_line"] = i
            continue
        if s.split(":")[0] in ("when", "at", "place") and ":" in s:
            scene["meta"].append(s)
            continue
        cond, rest = _split_cond(s)
        row = None
        if rest.startswith("-- "):
            row = {"type": "label", "label": rest[3:].strip(), "cond": cond}
        elif rest.startswith("->"):
            row = {"type": "jump", "to": rest[2:].strip(), "cond": cond}
        elif rest.startswith(">"):
            row = {"type": "fx", "text": rest[1:].strip(), "cond": cond}
        elif rest.startswith("- "):
            row = {"type": "text", "kind": "narration", "who": "", "emo": "", "ru": rest[2:], "cond": cond}
        elif rest.startswith("* "):
            m = CHOICE_RE.match(rest)
            if m:
                row = {"type": "text", "kind": "choice", "who": "you", "emo": "", "ru": m.group("text"), "to": m.group("to"), "cond": cond}
        else:
            m = LINE_RE.match(rest)
            if m:
                row = {"type": "text", "kind": "line", "who": m.group("who"), "emo": m.group("emo") or "", "ru": m.group("text"), "cond": cond}
        if row is None:
            row = {"type": "comment", "text": "(не разобрано) " + s}
        if row["type"] == "text":
            row["id"] = "dlg:%s:%d" % (path.name, i)
            row["line"] = i
            row["en"] = ""
            row["en_line"] = -1
            last = row
        else:
            last = None
        scene["rows"].append(row)
    return scenes


def save_dlg(item_id, lang, old, new):
    _, name, line = item_id.split(":")
    path = DLG_DIR / name
    if path.parent != DLG_DIR or not path.exists():
        raise ValueError("нет такого файла")
    lines = path.read_text(encoding="utf-8").split("\n")
    line = int(line)
    row = None
    for sc in parse_dlg(path):
        for r in sc["rows"]:
            if r.get("id") == item_id:
                row = r
    if row is None:
        raise ValueError("строка сдвинулась, обновите страницу")
    if row[lang] != old:
        raise ValueError("текст в файле уже другой, обновите страницу")
    new = new.replace("\n", " ").strip()
    if lang == "en":
        if row["en_line"] < 0:
            indent = "  "
            lines.insert(line + 1, indent + "en: " + new)
        else:
            raw = lines[row["en_line"]]
            lines[row["en_line"]] = raw[: len(raw) - len(raw.lstrip())] + "en: " + new
    else:
        raw = lines[line]
        lead = raw[: len(raw) - len(raw.lstrip())]
        cond = (row["cond"] + " ") if row["cond"] else ""
        if row["kind"] == "narration":
            body = "- " + new
        elif row["kind"] == "choice":
            body = "* %s -> %s" % (new, row["to"])
        else:
            body = row["who"] + (" [%s]" % row["emo"] if row["emo"] else "") + ": " + new
        lines[line] = lead + cond + body
    path.write_text("\n".join(lines), encoding="utf-8")


# ---------- locale.gd ----------

ENTRY_RE = re.compile(r'"([^"\\]+)":\s*"((?:[^"\\]|\\.)*)"')


def _unescape(s):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def _escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def _locale_sections(text):
    start = text.index("const S := {")
    ru = text.index('"ru": {', start)
    en = text.index('"en": {', ru)
    end = text.index("\n}", en)
    return {"ru": (ru, en), "en": (en, end)}


def parse_locale():
    text = LOCALE.read_text(encoding="utf-8")
    sec = _locale_sections(text)
    order, ru, en = [], {}, {}
    for lang, table in (("ru", ru), ("en", en)):
        a, b = sec[lang]
        for m in ENTRY_RE.finditer(text, a, b):
            table[m.group(1)] = _unescape(m.group(2))
            if m.group(1) not in order and lang == "ru":
                order.append(m.group(1))
    for k in en:
        if k not in ru:
            order.append(k)
    return order, ru, en


def save_locale(key, lang, old, new):
    text = LOCALE.read_text(encoding="utf-8")
    a, b = _locale_sections(text)[lang]
    pat = re.compile(r'"%s":\s*"((?:[^"\\]|\\.)*)"' % re.escape(key))
    m = pat.search(text, a, b)
    if m is None:
        if old != "":
            raise ValueError("ключа нет в файле")
        # A missing translation: add it as a line of its own at the end of that language's table.
        close = text.rindex("\t},", a, b) if "\t}," in text[a:b] else b
        line = '\t\t"%s": "%s",\n' % (key, _escape(new))
        text = text[:close] + line + text[close:]
    else:
        if _unescape(m.group(1)) != old:
            raise ValueError("текст в файле уже другой, обновите страницу")
        text = text[: m.start(1)] + _escape(new) + text[m.end(1):]
    LOCALE.write_text(text, encoding="utf-8")


def _locale_group(key):
    parts = key.split(".")
    if parts[0] in ("event", "talk", "init", "hire", "standup", "react", "story", "chapter", "ending", "fire", "review", "convo"):
        return ".".join(parts[:2])
    return parts[0]


def _speaker(key):
    parts = key.split(".")
    for p in parts:
        for who in PEOPLE:
            if p == who or p.startswith(who + "_"):
                return who
    return ""


# ---------- tables (.tsv) ----------

def parse_tsv(path):
    rows = path.read_text(encoding="utf-8").split("\n")
    head = rows[0].split("\t")
    pairs = [c[:-3] for c in head if c.endswith("_ru") and c[:-3] + "_en" in head]
    items = []
    for i, raw in enumerate(rows[1:], start=1):
        if not raw.strip():
            continue
        cols = raw.split("\t")
        if len(cols) < len(head):
            cols += [""] * (len(head) - len(cols))
        for field in pairs:
            ru = cols[head.index(field + "_ru")]
            en = cols[head.index(field + "_en")]
            if ru or en:
                items.append({"id": "tsv:%s:%s:%s" % (path.name, cols[0], field), "kind": field, "who": cols[head.index("from")] if "from" in head else "",
                              "ru": ru, "en": en, "group": "%s / %s" % (path.stem, cols[0])})
    return items


def save_tsv(item_id, lang, old, new):
    _, name, row_id, field = item_id.split(":")
    path = ROOT / "data" / name
    if path.parent != ROOT / "data" or path.suffix != ".tsv" or not path.exists():
        raise ValueError("нет такого файла")
    rows = path.read_text(encoding="utf-8").split("\n")
    head = rows[0].split("\t")
    col = head.index(field + "_" + lang)
    for i, raw in enumerate(rows):
        cols = raw.split("\t")
        if i > 0 and cols and cols[0] == row_id:
            if len(cols) <= col:
                cols += [""] * (col + 1 - len(cols))
            if cols[col] != old:
                raise ValueError("текст в файле уже другой, обновите страницу")
            cols[col] = new.replace("\t", " ").replace("\n", " ").strip()
            rows[i] = "\t".join(cols)
            path.write_text("\n".join(rows), encoding="utf-8")
            return
    raise ValueError("строка не найдена")


# ---------- everything together ----------

def collect():
    order, ru, en = parse_locale()
    names = {p: ru.get("name.%s.nom" % p, p) for p in PEOPLE}
    names["you"] = "Вы"
    names[""] = ""
    scenes = []
    for path in sorted(DLG_DIR.glob("*.dlg")):
        scenes += parse_dlg(path)
    groups = {}
    for k in order:
        g = _locale_group(k)
        groups.setdefault(g, []).append({"id": "loc:" + k, "key": k, "who": _speaker(k), "ru": ru.get(k, ""), "en": en.get(k, "")})
    tables = []
    for path in sorted((ROOT / "data").glob("*.tsv")):
        tables += parse_tsv(path)
    notes = json.loads(NOTES.read_text(encoding="utf-8")) if NOTES.exists() else {}
    return {"names": names, "scenes": scenes, "locale": groups, "tables": tables, "notes": notes, "emotions": EMOTIONS}


EMOTIONS = ["", "neutral", "happy", "excited", "annoyed", "angry", "tired", "sad", "worried", "embarrassed", "sarcastic"]


def save_emotion(item_id, old, new):
    """A scene line's emotion, the [tag] after the speaker: it picks the portrait."""
    if new not in EMOTIONS:
        raise ValueError("нет такой эмоции")
    _, name, line = item_id.split(":")
    path = DLG_DIR / name
    lines = path.read_text(encoding="utf-8").split("\n")
    line = int(line)
    row = None
    for sc in parse_dlg(path):
        for r in sc["rows"]:
            if r.get("id") == item_id:
                row = r
    if row is None or row["kind"] != "line" or row["emo"] != old:
        raise ValueError("строка уже другая, обновите страницу")
    raw = lines[line]
    lead = raw[: len(raw) - len(raw.lstrip())]
    cond = (row["cond"] + " ") if row["cond"] else ""
    lines[line] = lead + cond + row["who"] + (" [%s]" % new if new else "") + ": " + row["ru"]
    path.write_text("\n".join(lines), encoding="utf-8")


def save(item_id, lang, old, new):
    if lang == "emo" and item_id.startswith("dlg:"):
        return save_emotion(item_id, old, new)
    if lang not in ("ru", "en"):
        raise ValueError("язык ru или en")
    kind = item_id.split(":")[0]
    if kind == "dlg":
        save_dlg(item_id, lang, old, new)
    elif kind == "loc":
        save_locale(item_id[4:], lang, old, new)
    elif kind == "tsv":
        save_tsv(item_id, lang, old, new)
    else:
        raise ValueError("неизвестный источник")


def save_note(item_id, note, done):
    notes = json.loads(NOTES.read_text(encoding="utf-8")) if NOTES.exists() else {}
    entry = {k: v for k, v in (("note", note.strip()), ("done", bool(done))) if v}
    if entry:
        notes[item_id] = entry
    else:
        notes.pop(item_id, None)
    NOTES.write_text(json.dumps(notes, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        data = body if isinstance(body, bytes) else body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/":
            return self._send(200, (HERE / "index.html").read_bytes(), "text/html; charset=utf-8")
        if path == "/api/all":
            return self._send(200, json.dumps(collect(), ensure_ascii=False))
        if path.startswith("/portrait/"):
            name = os.path.basename(unquote(path[len("/portrait/"):]))
            f = ROOT / "art" / "portraits" / name
            if f.suffix == ".png" and f.exists():
                return self._send(200, f.read_bytes(), "image/png")
        return self._send(404, '{"error": "нет"}')

    def do_POST(self):
        # Only the page itself may write: a request from another site can't set this header without asking first.
        if self.headers.get("X-Team1337") != "1":
            return self._send(403, '{"error": "нет"}')
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))).decode("utf-8"))
            if self.path == "/api/save":
                save(body["id"], body["lang"], body["old"], body["new"])
            elif self.path == "/api/note":
                save_note(body["id"], body.get("note", ""), body.get("done", False))
            else:
                return self._send(404, '{"error": "нет"}')
            return self._send(200, '{"ok": true}')
        except (ValueError, KeyError, IndexError) as e:
            return self._send(409, json.dumps({"error": str(e)}, ensure_ascii=False))


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    url = "http://127.0.0.1:%d" % PORT
    print("Редактор текстов: %s  (остановить: Ctrl+C)" % url)
    if "--no-browser" not in sys.argv:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
