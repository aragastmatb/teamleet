"use strict";
// The scheme editor: a scene as a map of its branches, edited on the map and in the panel on the right.
// The scene comes from the server as structure (scenes.py) and goes back whole on "Сохранить".
// Also here: the reference of conditions and effects, the flag map, and the check of every scene.

const S = {
  cat: null,        // /api/catalog
  scene: null,      // the scene being edited (structure, see scenes.py)
  src: "",          // its text when loaded: the server refuses to save over a file changed since
  dirty: false,
  sel: 0,           // selected node index
  pos: {},          // label -> {x, y} on the map
  view: { x: 40, y: 40, k: 1 },
  problems: [],
  drag: null,
};
const NODE_W = 260;
const START = "";

async function getJSON(url) {
  const r = await fetch(url);
  const j = await r.json();
  if (!r.ok) throw new Error(j.error || "ошибка " + r.status);
  return j;
}

async function postJSON(url, body) {
  const r = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json", "X-Team1337": "1" }, body: JSON.stringify(body) });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.error || "ошибка " + r.status);
  return j;
}

async function catalogLoad(force) {
  if (!S.cat || force) S.cat = await getJSON("/api/catalog");
  return S.cat;
}

const nameOf = who => (DATA && DATA.names[who]) || who;
const short = (s, n) => (s.length > n ? s.slice(0, n - 1) + "…" : s);

// ---------- terms: "not flag x" <-> {neg, name, args} ----------

function termParse(str) {
  const w = str.trim().split(/\s+/).filter(Boolean);
  const neg = w[0] === "not";
  if (neg) w.shift();
  return { neg, name: w[0] || "", args: w.slice(1) };
}

function termText(t) {
  return [t.neg ? "not" : "", t.name, ...t.args].filter(Boolean).join(" ");
}

// How a term reads in Russian on a chip: "не: в команде alex".
function termHuman(str, table) {
  const t = termParse(str);
  const spec = table[t.name];
  const head = spec ? spec.ru : t.name;
  return (t.neg ? "НЕ " : "") + head + (t.args.length ? ": " + t.args.map(a => (DATA.names[a] ? nameOf(a) : a)).join(" ") : "");
}

// One input for an argument of a given kind (data/dialogue_catalog.json "args").
function argInput(kind, value, onChange) {
  const cat = S.cat;
  let el;
  const opts = (list, labels) => {
    el = document.createElement("select");
    el.innerHTML = `<option value=""></option>` + list.map(v => `<option value="${esc(v)}" ${v === value ? "selected" : ""}>${esc(labels ? labels(v) : v)}</option>`).join("");
  };
  if (kind === "person" || kind === "candidate") opts(S.cat.speakers.filter(p => p !== "you"), v => `${nameOf(v)} (${v})`);
  else if (kind === "cmp") opts([">=", ">", "<", "<="]);
  else if (kind === "style") opts(["P", "A", "E", "I"]);
  else if (kind === "known") opts(["drive", "skill.pipelines", "skill.infra", "skill.portal", "skill.support"]);
  else {
    el = document.createElement("input");
    el.value = value || "";
    el.placeholder = { range: "2 или 2-4", number: "число", delta: "+1", people: "alex vika", styles: "P A", bosses: "P X", flag: "отметка", task: "id задачи" }[kind] || kind;
    const list = { flag: "dl-flags", task: "dl-tasks", people: "dl-people" }[kind];
    if (list) el.setAttribute("list", list);
    el.size = Math.max(6, (value || el.placeholder).length + 1);
  }
  el.title = cat.catalog.args[kind] || kind;
  el.addEventListener("change", () => onChange(el.value.trim()));
  return el;
}

// An editable list of terms (conditions or effects): each row a word from the catalog and its arguments.
function termsEditor(list, table, { allowNot = true, single = false, onChange }) {
  const box = document.createElement("div");
  box.className = "terms";
  const draw = () => {
    box.innerHTML = "";
    list.forEach((str, i) => {
      const t = termParse(str);
      const row = document.createElement("div");
      row.className = "term";
      if (allowNot) {
        const neg = document.createElement("label");
        neg.className = "neg";
        neg.innerHTML = `<input type="checkbox" ${t.neg ? "checked" : ""}> не`;
        neg.firstChild.addEventListener("change", e => { t.neg = e.target.checked; list[i] = termText(t); onChange(); });
        row.append(neg);
      }
      const pick = document.createElement("select");
      pick.innerHTML = Object.keys(table).map(k => `<option value="${k}" ${k === t.name ? "selected" : ""}>${esc(table[k].ru)} (${k})</option>`).join("")
        + (table[t.name] ? "" : `<option selected>${esc(t.name)}</option>`);
      pick.addEventListener("change", () => { t.name = pick.value; t.args = []; list[i] = termText(t); onChange(); draw(); });
      row.append(pick);
      const spec = table[t.name];
      (spec ? spec.args : []).forEach((kind, j) => {
        const many = ["people", "styles", "bosses"].includes(kind);
        const val = many ? t.args.slice(j).join(" ") : t.args[j];
        row.append(argInput(kind, val, v => {
          if (many) t.args = t.args.slice(0, j).concat(v.split(/\s+/).filter(Boolean));
          else t.args[j] = v;
          list[i] = termText(t);
          onChange();
        }));
      });
      if (t.name === "give") {
        const helper = argInput("person", t.args[3] || "", v => { t.args = t.args.slice(0, 2).concat(v ? ["helper", v] : []); list[i] = termText(t); onChange(); });
        const lbl = document.createElement("span");
        lbl.className = "hint";
        lbl.textContent = "напарник";
        row.append(lbl, helper);
      }
      const del = document.createElement("button");
      del.className = "x";
      del.textContent = "✕";
      del.title = "убрать";
      del.addEventListener("click", () => { list.splice(i, 1); onChange(); draw(); });
      row.append(del);
      if (spec) {
        const ex = document.createElement("span");
        ex.className = "hint";
        ex.textContent = "как в файле: " + termText(t);
        row.append(ex);
      }
      box.append(row);
    });
    if (!single || list.length === 0) {
      const add = document.createElement("button");
      add.className = "add";
      add.textContent = single ? "+ выбрать" : "+ условие";
      add.addEventListener("click", () => { list.push(Object.keys(table)[0]); onChange(); draw(); });
      box.append(add);
    }
  };
  draw();
  return box;
}

// ---------- the scene as a map ----------

function labels() {
  return S.scene.nodes.slice(1).map(n => n.label);
}

function exitsOf(node) {
  const out = [];
  node.items.forEach((it, i) => {
    if (it.type === "choice" || it.type === "jump") out.push({ i, it });
  });
  const last = node.items.filter(it => it.type !== "comment").slice(-1)[0];
  const ends = !last || !((last.type === "jump" && !last.cond.length) || last.type === "choice");
  return { out, ends };
}

function nodeTitle(node) {
  return node.label === START ? "Начало" : node.label;
}

function nodeHTML(node, n) {
  const lines = node.items.filter(it => it.type === "line" || it.type === "narr");
  const fx = node.items.filter(it => it.type === "fx");
  const { out, ends } = exitsOf(node);
  const probs = S.problems.filter(p => p.node === node.label);
  const level = probs.some(p => p.level === "error") ? "error" : probs.length ? "warn" : "";
  let h = `<div class="n-title"><span>${esc(nodeTitle(node))}</span>${level ? `<span class="n-bad ${level}">${probs.length}</span>` : ""}</div>`;
  if (n === 0) {
    const when = S.scene.header.find(x => x.key === "when");
    if (when) h += `<div class="n-when">${when.value.split(",").map(t => `<span class="chip cond">${esc(termHuman(t, S.cat.catalog.terms))}</span>`).join(" ")}</div>`;
  }
  lines.slice(0, 3).forEach(it => {
    const who = it.type === "narr" ? "" : `<b>${esc(nameOf(it.who))}:</b> `;
    h += `<div class="n-line ${it.cond.length ? "if" : ""}">${who}${esc(short(it.ru, 70))}</div>`;
  });
  if (lines.length > 3) h += `<div class="n-more">ещё ${lines.length - 3}</div>`;
  if (fx.length) h += `<div class="n-fx">${fx.map(it => `<span class="chip">${esc(it.words.join(" "))}</span>`).join(" ")}</div>`;
  out.forEach(({ i, it }) => {
    const cond = it.cond.length ? `<span class="n-if" title="${esc(it.cond.join(", "))}">если</span>` : "";
    const to = it.to === "end" ? `<span class="n-end">конец</span>` : "";
    const text = it.type === "choice" ? "«" + esc(short(it.ru, 46)) + "»" : "→ переход";
    h += `<div class="n-exit ${it.type}" data-exit="${i}">${cond}<span class="t">${text}</span>${to}<span class="port" data-port="${i}" title="Тяни на другую ветку или в пустое место"></span></div>`;
  });
  if (ends) h += `<div class="n-exit fall"><span class="t">сцена заканчивается</span></div>`;
  return h;
}

function layout(force) {
  const nodes = S.scene.nodes;
  const index = Object.fromEntries(nodes.map((n, i) => [n.label, i]));
  const depth = { [START]: 0 };
  const queue = [START];
  while (queue.length) {
    const l = queue.shift();
    const node = nodes[index[l]];
    for (const { it } of exitsOf(node).out) {
      if (it.to in index && !(it.to in depth)) { depth[it.to] = depth[l] + 1; queue.push(it.to); }
    }
  }
  const maxd = Math.max(0, ...Object.values(depth));
  const cols = {};
  nodes.forEach(n => { const d = n.label in depth ? depth[n.label] : maxd + 1; (cols[d] = cols[d] || []).push(n); });
  for (const d in cols) {
    let y = 0;
    for (const n of cols[d]) {
      if (force || !S.pos[n.label]) S.pos[n.label] = { x: d * (NODE_W + 90), y };
      const el = document.querySelector(`.node[data-label="${CSS.escape(n.label)}"]`);
      y += (el ? el.offsetHeight : 120) + 36;
    }
  }
}

function savePos() {
  try { localStorage.setItem("scheme-pos:" + S.scene.id, JSON.stringify(S.pos)); } catch (e) { /* only a convenience */ }
}

function loadPos() {
  try { S.pos = JSON.parse(localStorage.getItem("scheme-pos:" + S.scene.id) || "{}"); } catch (e) { S.pos = {}; }
}

function drawMap() {
  const layer = $("#nodes");
  if (!layer) return;
  layer.innerHTML = S.scene.nodes.map((n, i) => `<div class="node ${i === S.sel ? "sel" : ""} ${i === 0 ? "start" : ""}" data-n="${i}" data-label="${esc(n.label)}">${nodeHTML(n, i)}</div>`).join("");
  const missing = S.scene.nodes.some(n => !S.pos[n.label]);
  if (missing) layout(false);
  layer.querySelectorAll(".node").forEach(el => {
    const p = S.pos[el.dataset.label];
    el.style.transform = `translate(${p.x}px, ${p.y}px)`;
  });
  drawEdges();
  applyView();
}

function portXY(nodeEl, port) {
  const p = S.pos[nodeEl.dataset.label];
  return { x: p.x + nodeEl.offsetWidth, y: p.y + port.offsetTop + port.offsetHeight / 2 + port.parentElement.offsetTop };
}

function curve(a, b) {
  const dx = Math.max(60, Math.abs(b.x - a.x) / 2);
  return `M${a.x},${a.y} C${a.x + dx},${a.y} ${b.x - dx},${b.y} ${b.x},${b.y}`;
}

function drawEdges() {
  const svg = $("#edges");
  let h = "";
  S.scene.nodes.forEach((n, i) => {
    const el = document.querySelector(`.node[data-n="${i}"]`);
    for (const { i: k, it } of exitsOf(n).out) {
      if (it.to === "end") continue;
      const target = document.querySelector(`.node[data-label="${CSS.escape(it.to)}"]`);
      const port = el.querySelector(`[data-port="${k}"]`);
      if (!target || !port) continue;
      const a = portXY(el, port);
      const p = S.pos[it.to];
      const b = { x: p.x, y: p.y + 16 };
      const hot = i === S.sel || it.to === S.scene.nodes[S.sel].label;
      h += `<path d="${curve(a, b)}" class="edge ${it.type} ${it.cond.length ? "if" : ""} ${hot ? "hot" : ""}" marker-end="url(#arr)"/>`;
    }
  });
  if (S.drag && S.drag.kind === "wire") h += `<path d="${curve(S.drag.from, S.drag.to)}" class="edge wire"/>`;
  svg.innerHTML = `<defs><marker id="arr" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#8993a4"/></marker></defs>` + h;
}

function applyView() {
  const v = S.view;
  const t = `translate(${v.x}px, ${v.y}px) scale(${v.k})`;
  $("#nodes").style.transform = t;
  $("#edges").style.transform = t;
}

function toMap(e) {
  const r = $("#canvas").getBoundingClientRect();
  return { x: (e.clientX - r.left - S.view.x) / S.view.k, y: (e.clientY - r.top - S.view.y) / S.view.k };
}

function nodeAt(e) {
  const el = document.elementFromPoint(e.clientX, e.clientY);
  return el && el.closest(".node");
}

function newLabel(base) {
  let name = (base || "branch").toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "") || "branch";
  if (/^\d/.test(name)) name = "b" + name;
  let n = name, i = 2;
  while (labels().includes(n)) n = name + "_" + i++;
  return n;
}

function addNode(at, name) {
  const label = newLabel(name || prompt("Как назвать ветку? Латиницей, например agree или later", "") || "");
  S.scene.nodes.push({ label, items: [{ type: "jump", to: "end", cond: [] }], lead: [] });
  S.pos[label] = at || { x: 0, y: 0 };
  return label;
}

function canvasEvents() {
  const cv = $("#canvas");
  cv.addEventListener("pointerdown", e => {
    const port = e.target.closest(".port");
    const node = e.target.closest(".node");
    if (port) {
      const el = port.closest(".node");
      const from = portXY(el, port);
      S.drag = { kind: "wire", node: +el.dataset.n, item: +port.dataset.port, from, to: from };
    } else if (node) {
      selectNode(+node.dataset.n);
      const m = toMap(e), p = S.pos[node.dataset.label];
      S.drag = { kind: "node", label: node.dataset.label, dx: m.x - p.x, dy: m.y - p.y, moved: false };
    } else {
      S.drag = { kind: "pan", x: e.clientX - S.view.x, y: e.clientY - S.view.y };
    }
    cv.setPointerCapture(e.pointerId);
  });
  cv.addEventListener("pointermove", e => {
    const d = S.drag;
    if (!d) return;
    if (d.kind === "pan") { S.view.x = e.clientX - d.x; S.view.y = e.clientY - d.y; applyView(); }
    else if (d.kind === "node") {
      const m = toMap(e);
      S.pos[d.label] = { x: Math.round(m.x - d.dx), y: Math.round(m.y - d.dy) };
      d.moved = true;
      const el = document.querySelector(`.node[data-label="${CSS.escape(d.label)}"]`);
      el.style.transform = `translate(${S.pos[d.label].x}px, ${S.pos[d.label].y}px)`;
      drawEdges();
    } else if (d.kind === "wire") { d.to = toMap(e); drawEdges(); }
  });
  cv.addEventListener("pointerup", e => {
    const d = S.drag;
    S.drag = null;
    if (!d) return;
    if (d.kind === "node" && d.moved) savePos();
    if (d.kind === "wire") {
      const it = S.scene.nodes[d.node].items[d.item];
      const target = nodeAt(e);
      if (target && +target.dataset.n !== 0) it.to = target.dataset.label;
      else if (!target && Math.hypot(d.to.x - d.from.x, d.to.y - d.from.y) > 30) {
        const label = addNode({ x: d.to.x, y: d.to.y - 16 }, it.type === "choice" ? short(translit(it.ru), 18) : "");
        it.to = label;
        savePos();
      }
      changed(true);
    }
    drawEdges();
  });
  cv.addEventListener("dblclick", e => {
    if (nodeAt(e)) return;
    const label = addNode(toMap(e));
    savePos();
    changed();
    selectNode(S.scene.nodes.findIndex(n => n.label === label));
  });
  cv.addEventListener("wheel", e => {
    e.preventDefault();
    if (e.ctrlKey || e.metaKey) {
      const r = cv.getBoundingClientRect();
      const k = Math.min(1.6, Math.max(0.3, S.view.k * Math.exp(-e.deltaY * 0.01)));
      const mx = e.clientX - r.left, my = e.clientY - r.top;
      S.view.x = mx - (mx - S.view.x) * k / S.view.k;
      S.view.y = my - (my - S.view.y) * k / S.view.k;
      S.view.k = k;
    } else { S.view.x -= e.deltaX; S.view.y -= e.deltaY; }
    applyView();
  }, { passive: false });
}

// A branch name from a choice's words: "Позвони." -> pozvoni.
function translit(s) {
  const map = { а: "a", б: "b", в: "v", г: "g", д: "d", е: "e", ё: "e", ж: "zh", з: "z", и: "i", й: "y", к: "k", л: "l", м: "m", н: "n", о: "o", п: "p", р: "r", с: "s", т: "t", у: "u", ф: "f", х: "h", ц: "c", ч: "ch", ш: "sh", щ: "sch", ъ: "", ы: "y", ь: "", э: "e", ю: "yu", я: "ya" };
  return s.toLowerCase().split("").map(c => (c in map ? map[c] : c)).join("").replace(/[^a-z0-9]+/g, "_").split("_").filter(Boolean).slice(0, 3).join("_");
}

// ---------- the panel on the right ----------

function selectNode(n) {
  S.sel = n;
  document.querySelectorAll(".node").forEach(el => el.classList.toggle("sel", +el.dataset.n === n));
  drawEdges();
  drawPanel();
}

function field(labelText, el) {
  const w = document.createElement("label");
  w.className = "field";
  w.innerHTML = `<span>${esc(labelText)}</span>`;
  w.append(el);
  return w;
}

function textArea(value, cls, onInput) {
  const t = document.createElement("textarea");
  t.className = cls;
  t.rows = 1;
  t.value = value || "";
  t.addEventListener("input", () => { grow(t); onInput(t.value); });
  setTimeout(() => grow(t), 0);
  return t;
}

function select(options, value, onChange) {
  const s = document.createElement("select");
  s.innerHTML = options.map(([v, l]) => `<option value="${esc(v)}" ${v === value ? "selected" : ""}>${esc(l)}</option>`).join("");
  s.addEventListener("change", () => onChange(s.value));
  return s;
}

function targetSelect(it) {
  const opts = [["end", "конец сцены"], ...labels().map(l => [l, "ветка " + l]), ["+new", "+ новая ветка…"]];
  return select(opts, it.to, v => {
    if (v === "+new") {
      const from = S.pos[S.scene.nodes[S.sel].label] || { x: 0, y: 0 };
      it.to = addNode({ x: from.x + NODE_W + 90, y: from.y }, it.type === "choice" ? translit(it.ru) : "");
      savePos();
    } else it.to = v;
    changed(true);
  });
}

const ITEM_NAMES = { line: "Реплика", narr: "Описание", choice: "Вариант игрока", jump: "Переход", fx: "Эффект", comment: "Комментарий" };

function itemCard(node, it, i) {
  const card = document.createElement("div");
  card.className = "item " + it.type;
  const head = document.createElement("div");
  head.className = "item-head";
  head.innerHTML = `<b>${ITEM_NAMES[it.type]}</b>`;
  const tools = document.createElement("span");
  tools.className = "item-tools";
  [["↑", -1, "выше"], ["↓", 1, "ниже"]].forEach(([s, d, title]) => {
    const b = document.createElement("button");
    b.textContent = s;
    b.title = title;
    b.disabled = i + d < 0 || i + d >= node.items.length;
    b.addEventListener("click", () => { const [x] = node.items.splice(i, 1); node.items.splice(i + d, 0, x); changed(true); });
    tools.append(b);
  });
  const del = document.createElement("button");
  del.textContent = "✕";
  del.title = "удалить";
  del.addEventListener("click", () => { node.items.splice(i, 1); changed(true); });
  tools.append(del);
  head.append(tools);
  card.append(head);
  const C = S.cat.catalog;
  if (it.type === "line") {
    const row = document.createElement("div");
    row.className = "row2";
    row.append(field("Кто", select(S.cat.speakers.map(p => [p, p === "you" ? "игрок (you)" : `${nameOf(p)} (${p})`]), it.who, v => { it.who = v; changed(); })));
    row.append(field("Эмоция", select([["", "без эмоции"], ...Object.entries(C.emotions)], it.emo, v => { it.emo = v; changed(); })));
    card.append(row);
  }
  if (it.type === "line" || it.type === "narr" || it.type === "choice") {
    card.append(textArea(it.ru, "ru", v => { it.ru = v; changed(); }));
    card.append(textArea(it.en, "en", v => { it.en = v; changed(); }));
  }
  if (it.type === "choice" || it.type === "jump") card.append(field("Ведёт в", targetSelect(it)));
  if (it.type === "fx") {
    const list = [it.words.join(" ")];
    card.append(termsEditor(list, C.fx, { allowNot: false, single: true, onChange: () => { it.words = (list[0] || "").split(/\s+/).filter(Boolean); changed(); } }));
  }
  if (it.type === "comment") {
    const t = textArea(it.text, "", v => { it.text = v; changed(); });
    card.append(t);
  }
  if (it.type !== "comment") {
    const cond = document.createElement("details");
    cond.className = "cond";
    cond.open = it.cond.length > 0;
    cond.innerHTML = `<summary>${it.cond.length ? "Только если: " + esc(it.cond.map(t => termHuman(t, C.terms)).join("; ")) : "Показывать всегда"}</summary>`;
    cond.append(termsEditor(it.cond, C.terms, { onChange: () => changed() }));
    card.append(cond);
  }
  return card;
}

function headerEditor() {
  const C = S.cat.catalog;
  const box = document.createElement("div");
  box.className = "scene-head";
  const get = key => S.scene.header.find(h => h.key === key);
  const set = (key, value) => {
    let h = get(key);
    if (!h) { h = { key, value: "" }; S.scene.header.push(h); }
    h.value = value;
    changed();
  };
  const when = get("when") ? get("when").value.split(",").map(s => s.trim()).filter(Boolean) : [];
  const w = document.createElement("div");
  w.innerHTML = `<div class="panel-sub">Когда начинается (все условия сразу)</div>`;
  w.append(termsEditor(when, C.terms, { onChange: () => set("when", when.join(", ")) }));
  box.append(w);
  const row = document.createElement("div");
  row.className = "row2";
  row.append(field("Время", select([["", "утром (по умолчанию)"], ["evening", "вечером"]], get("at") ? get("at").value : "", v => set("at", v))));
  row.append(field("Место", select([["", "опенспейс (по умолчанию)"], ...Object.entries(C.places).map(([k, v]) => [k, v])], get("place") ? get("place").value : "", v => set("place", v))));
  box.append(row);
  return box;
}

function drawPanel() {
  const panel = $("#panel");
  if (!panel) return;
  const node = S.scene.nodes[S.sel];
  panel.innerHTML = "";
  const top = document.createElement("div");
  top.className = "panel-top";
  if (S.sel === 0) {
    top.innerHTML = `<div class="panel-title">Начало сцены</div>`;
    panel.append(top, headerEditor());
  } else {
    const name = document.createElement("input");
    name.value = node.label;
    name.className = "branch-name";
    name.title = "Имя ветки: латиница, цифры и _. Переименование поправит все ссылки на неё.";
    name.addEventListener("change", () => {
      const old = node.label, now = newLabelKeep(name.value, old);
      for (const n of S.scene.nodes) for (const it of n.items) if (it.to === old) it.to = now;
      S.pos[now] = S.pos[old];
      node.label = now;
      savePos();
      changed(true);
    });
    const del = document.createElement("button");
    del.className = "danger";
    del.textContent = "Удалить ветку";
    del.addEventListener("click", () => {
      if (!confirm(`Удалить ветку ${node.label}? Ссылки на неё станут ошибкой, пока их не перенаправишь.`)) return;
      S.scene.nodes.splice(S.sel, 1);
      S.sel = 0;
      changed(true);
    });
    top.append(field("Ветка", name), del);
    panel.append(top);
  }
  const probs = S.problems.filter(p => p.node === node.label);
  if (probs.length) {
    const pb = document.createElement("div");
    pb.className = "probs";
    pb.innerHTML = probs.map(p => `<div class="${p.level}">${p.level === "error" ? "Ошибка" : "Внимание"}: ${esc(p.text)}</div>`).join("");
    panel.append(pb);
  }
  const items = document.createElement("div");
  items.className = "items";
  node.items.forEach((it, i) => items.append(itemCard(node, it, i)));
  panel.append(items);
  const add = document.createElement("div");
  add.className = "adds";
  const blank = {
    line: () => ({ type: "line", who: S.cat.speakers[0], emo: "", ru: "", en: "", cond: [] }),
    narr: () => ({ type: "narr", ru: "", en: "", cond: [] }),
    choice: () => ({ type: "choice", ru: "", en: "", to: "end", cond: [], open: "" }),
    fx: () => ({ type: "fx", words: ["flag", "new_flag"], cond: [] }),
    jump: () => ({ type: "jump", to: "end", cond: [] }),
    comment: () => ({ type: "comment", text: "" }),
  };
  for (const k of ["line", "narr", "choice", "fx", "jump", "comment"]) {
    const b = document.createElement("button");
    b.textContent = "+ " + ITEM_NAMES[k].toLowerCase();
    b.addEventListener("click", () => {
      // New lines go before the first choice or jump, so they're said before you answer; the rest go last.
      let at = node.items.length;
      if (["line", "narr", "fx"].includes(k)) {
        const first = node.items.findIndex(x => x.type === "choice" || x.type === "jump");
        if (first >= 0) at = first;
      }
      // A choice replaces the branch's plain "-> …" at the end: with choices it would never be reached.
      const last = node.items[node.items.length - 1];
      if (k === "choice" && last && last.type === "jump" && !last.cond.length) { node.items.pop(); at = node.items.length; }
      node.items.splice(at, 0, blank[k]());
      changed(true);
    });
    add.append(b);
  }
  panel.append(add);
}

function newLabelKeep(v, old) {
  const clean = v.toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "");
  if (!clean || clean === old) return old;
  return labels().includes(clean) ? old : clean;
}

// ---------- changes, checking, saving ----------

let checkTimer = 0;
function changed(redrawPanel) {
  S.dirty = true;
  $("#save").disabled = false;
  $("#state").textContent = "есть несохранённые изменения";
  drawMap();
  if (redrawPanel) drawPanel();
  clearTimeout(checkTimer);
  checkTimer = setTimeout(async () => {
    try {
      S.problems = await postJSON("/api/scene/check", { scene: S.scene });
      showProblems();
      drawMap();
    } catch (e) { $("#state").textContent = e.message; }
  }, 400);
}

function showProblems() {
  const errs = S.problems.filter(p => p.level === "error").length, warns = S.problems.length - errs;
  const el = $("#probsum");
  el.className = "probsum " + (errs ? "error" : warns ? "warn" : "ok");
  el.textContent = errs ? `ошибок ${errs}, замечаний ${warns}` : warns ? `замечаний ${warns}` : "ошибок нет";
  el.title = S.problems.map(p => `${p.node || "начало"}: ${p.text}`).join("\n");
}

async function save() {
  try {
    const scene = Object.assign({}, S.scene, { old_id: S.loadedId });
    const r = await postJSON("/api/scene/save", { scene, src: S.src });
    S.scene = r.scene;
    S.src = r.scene.src;
    S.loadedId = r.scene.id;
    S.problems = r.problems;
    S.dirty = false;
    $("#save").disabled = true;
    $("#state").textContent = "сохранено в " + r.scene.file;
    showProblems();
    drawMap();
    drawPanel();
    reloadTexts();
    catalogLoad(true);
  } catch (e) {
    $("#state").textContent = e.message;
    $("#state").className = "state err";
    setTimeout(() => ($("#state").className = "state"), 4000);
  }
}

// The text view reads /api/all: after a save it has to see the new scene too.
async function reloadTexts() {
  const r = await fetch("/api/all");
  DATA = await r.json();
  rebuildGroups();
  renderNav();
}

async function openScheme(id, main) {
  await catalogLoad();
  const r = await getJSON("/api/scene?id=" + encodeURIComponent(id));
  S.scene = r.scene;
  S.src = r.scene.src;
  S.loadedId = r.scene.id;
  S.problems = r.problems;
  S.dirty = false;
  S.sel = 0;
  S.view = { x: 40, y: 30, k: 1 };
  loadPos();
  main.classList.add("wide");
  main.innerHTML = `
    <div class="scheme">
      <div class="bar">
        ${viewTabs(id, "scheme")}
        <b class="scene-id" title="id сцены">${esc(S.scene.id)}</b><span class="key">${esc(S.scene.file)}</span>
        <span id="probsum" class="probsum"></span>
        <span id="state" class="state"></span>
        <span class="grow"></span>
        <button id="relayout" title="Разложить ветки заново">Разложить</button>
        <button id="addnode" title="Новая ветка (или двойной клик по пустому месту)">+ ветка</button>
        <button id="delscene" class="danger">Удалить сцену</button>
        <button id="save" class="primary" disabled>Сохранить</button>
      </div>
      <div class="split">
        <div id="canvas" class="canvas"><svg id="edges"></svg><div id="nodes"></div>
          <div class="help">Тяни кружок у варианта на ветку, чтобы перенаправить, или в пустое место, чтобы создать новую. Двойной клик: новая ветка. Колёсико: прокрутка, с Ctrl/⌘: масштаб.</div>
        </div>
        <div id="panel" class="panel"></div>
      </div>
    </div>
    ${datalists()}`;
  showProblems();
  drawMap();
  drawPanel();
  canvasEvents();
  $("#save").addEventListener("click", save);
  $("#relayout").addEventListener("click", () => { layout(true); savePos(); drawMap(); });
  $("#addnode").addEventListener("click", () => {
    const from = S.pos[S.scene.nodes[S.sel].label] || { x: 0, y: 0 };
    const label = addNode({ x: from.x + NODE_W + 90, y: from.y + 40 });
    savePos();
    changed();
    selectNode(S.scene.nodes.findIndex(n => n.label === label));
  });
  $("#delscene").addEventListener("click", async () => {
    if (!confirm(`Удалить сцену ${S.scene.id} из ${S.scene.file}? Это нельзя отменить из редактора (только через git).`)) return;
    try {
      await postJSON("/api/scene/delete", { id: S.loadedId, src: S.src });
      S.dirty = false;
      await reloadTexts();
      location.hash = "";
    } catch (e) { $("#state").textContent = e.message; }
  });
}

function datalists() {
  const flags = Object.keys(S.cat.flags).filter(f => !f.includes("*")).sort();
  return `<datalist id="dl-flags">${flags.map(f => `<option value="${esc(f)}">`).join("")}</datalist>
    <datalist id="dl-tasks">${S.cat.tasks.map(f => `<option value="${esc(f)}">`).join("")}</datalist>`;
}

function viewTabs(id, on) {
  return `<span class="tabs"><a href="#scene:${esc(id)}" class="${on === "text" ? "on" : ""}">Текст</a><a href="#scheme:${esc(id)}" class="${on === "scheme" ? "on" : ""}">Схема</a></span>`;
}

window.addEventListener("beforeunload", e => { if (S.dirty) { e.preventDefault(); e.returnValue = ""; } });
document.addEventListener("keydown", e => {
  if ((e.metaKey || e.ctrlKey) && e.key === "s" && $("#save") && !e.target.matches("textarea[data-lang]")) { e.preventDefault(); if (S.dirty) save(); }
});

// ---------- reference, flags, check, new scene ----------

async function openTool(name, main) {
  await catalogLoad(name === "flags" || name === "check");
  main.classList.remove("wide");
  if (name === "catalog") main.innerHTML = catalogPage();
  else if (name === "flags") { main.innerHTML = flagsPage(); bindFlagFilter(); }
  else if (name === "check") main.innerHTML = await checkPage();
  else if (name === "new") { main.innerHTML = newScenePage(); bindNewScene(); }
}

function catalogPage() {
  const C = S.cat.catalog;
  const rows = (table, cols) => Object.entries(table).map(([k, v]) => `<tr><td><code>${esc(k)}</code></td><td>${esc(v.ru)}</td><td><code>${esc(v.example)}</code></td><td>${v.args.map(a => `<span class="chip" title="${esc(C.args[a] || a)}">${esc(a)}</span>`).join(" ")}</td></tr>`).join("");
  return `<h2>Справочник сцен</h2>
    <p class="intro">Всё, что можно написать в сцене. Список берётся из <code>data/dialogue_catalog.json</code>, тот же файл читает игра, так что здесь всегда то, что она понимает.</p>
    <h3>Условия</h3><p class="intro">В «Когда начинается» и в «Только если» у любой строки. ${esc(C.not)}</p>
    <table class="ref"><tr><th>Слово</th><th>Выполнено, если</th><th>Пример</th><th>Что нужно указать</th></tr>${rows(C.terms)}</table>
    <h3>Эффекты</h3><p class="intro">Что меняется в игре, когда сцена доходит до этой строки.</p>
    <table class="ref"><tr><th>Слово</th><th>Что делает</th><th>Пример</th><th>Что нужно указать</th></tr>${rows(C.fx)}</table>
    <h3>Что указывать</h3>
    <table class="ref">${Object.entries(C.args).map(([k, v]) => `<tr><td><code>${esc(k)}</code></td><td>${esc(v)}</td></tr>`).join("")}</table>
    <h3>Места</h3><table class="ref">${Object.entries(C.places).map(([k, v]) => `<tr><td><code>${esc(k)}</code></td><td>${esc(v)}</td></tr>`).join("")}</table>
    <h3>Эмоции</h3><table class="ref">${Object.entries(C.emotions).map(([k, v]) => `<tr><td><code>${esc(k)}</code></td><td>${esc(v)}</td></tr>`).join("")}</table>
    <h3>Кто говорит</h3><p>${S.cat.speakers.map(p => `<span class="chip">${esc(p)}: ${esc(nameOf(p))}</span>`).join(" ")}</p>
    <h3>Память о выборах</h3><p class="intro">Каждый выбранный вариант сам ставит отметку <code>сцена:ветка</code>. Ответ, ведущий в ветку <code>wait</code> сцены <code>reveal_alex</code>, ставит <code>reveal_alex:wait</code>, и любая сцена потом может спросить «отметка reveal_alex:wait». Сыгранная сцена ставит <code>story_&lt;id&gt;</code>.</p>`;
}

function flagsPage() {
  const F = S.cat.flags;
  const names = Object.keys(F).filter(f => !/^story_./.test(f)).sort();
  const row = f => {
    const v = F[f];
    const pat = f.includes("*");
    const warn = !pat && !v.set.length ? "warn" : "";
    const unused = !pat && !v.read.length ? "unused" : "";
    const list = a => a.map(w => {
      const m = w.match(/^сцена ([A-Za-z_0-9]+)/);
      return m ? `<a href="#scheme:${esc(m[1])}">${esc(w)}</a>` : `<span>${esc(w)}</span>`;
    }).join("<br>") || `<span class="none">никто</span>`;
    const auto = !pat && f.includes(":") && !v.read.length ? "auto" : "";
    return `<tr class="${warn} ${unused} ${auto}" data-flag="${esc(f)}"><td><code>${esc(f)}</code>${pat ? `<div class="hint">${f === "*:*" ? "выбор в чате или в сцене: событие:ответ" : "шаблон: код собирает имя из кусков"}</div>` : ""}</td><td>${list(v.set)}</td><td>${list(v.read)}</td></tr>`;
  };
  return `<h2>Отметки (флаги)</h2>
    <p class="intro">Отметки связывают сцены между собой и с игрой: одна сцена или код ставит, другая спрашивает. Жёлтым: спрашивают, но нигде не ставят (сцена с таким условием не начнётся). Бледным: ставят, но никто не спрашивает.</p>
    <input type="search" id="flagq" placeholder="Найти отметку…" class="search">
    <label class="showauto"><input type="checkbox" id="flagauto"> показать отметки выборов, которые никто не спрашивает (<code>сцена:ветка</code>)</label>
    <table class="ref flags"><tr><th>Отметка</th><th>Ставит</th><th>Спрашивает</th></tr>${names.map(row).join("")}</table>`;
}

function bindFlagFilter() {
  const apply = () => {
    const q = $("#flagq").value.trim().toLowerCase(), all = $("#flagauto").checked;
    document.querySelectorAll("tr[data-flag]").forEach(tr => (tr.hidden = (q && !tr.dataset.flag.toLowerCase().includes(q)) || (!all && tr.classList.contains("auto"))));
  };
  $("#flagq").addEventListener("input", apply);
  $("#flagauto").addEventListener("change", apply);
  apply();
}

async function checkPage() {
  const all = await getJSON("/api/check");
  const by = {};
  all.forEach(p => (by[p.scene] = by[p.scene] || []).push(p));
  const errs = all.filter(p => p.level === "error").length;
  let h = `<h2>Проверка всех сцен</h2><p class="intro">${errs ? `Ошибок: ${errs}. Сцена с ошибкой в игре сломается или не начнётся.` : "Ошибок нет."} Замечаний: ${all.length - errs}.</p>`;
  for (const sid in by) {
    h += `<h3><a href="#scheme:${esc(sid)}">${esc(sid)}</a></h3>` + by[sid].map(p => `<div class="probline ${p.level}">${p.level === "error" ? "Ошибка" : "Внимание"}${p.node ? ` в ветке ${esc(p.node)}` : ""}: ${esc(p.text)}</div>`).join("");
  }
  return h;
}

function newScenePage() {
  return `<h2>Новая сцена</h2>
    <p class="intro">Сцена появится в конце выбранного файла. Дальше её можно строить на схеме.</p>
    <div class="newform">
      <label class="field"><span>id сцены (латиницей, уникальный)</span><input id="ns-id" placeholder="vika_coffee"></label>
      <label class="field"><span>Файл</span><select id="ns-file">${S.cat.files.map(f => `<option>${esc(f)}</option>`).join("")}<option value="+">+ новый файл…</option></select></label>
      <label class="field" id="ns-newfile" hidden><span>Имя нового файла</span><input id="ns-fname" placeholder="ch2_extra.dlg"></label>
      <button id="ns-go" class="primary">Создать</button> <span id="ns-msg" class="state"></span>
    </div>`;
}

function bindNewScene() {
  $("#ns-file").addEventListener("change", e => ($("#ns-newfile").hidden = e.target.value !== "+"));
  $("#ns-go").addEventListener("click", async () => {
    const id = $("#ns-id").value.trim();
    const file = $("#ns-file").value === "+" ? $("#ns-fname").value.trim() : $("#ns-file").value;
    const scene = { id, file, header: [{ key: "when", value: "chapter 1" }],
      nodes: [{ label: "", lead: [], items: [{ type: "narr", ru: "Здесь начинается сцена.", en: "The scene starts here.", cond: [] }, { type: "jump", to: "end", cond: [] }] }] };
    try {
      await postJSON("/api/scene/save", { scene, src: "" });
      await reloadTexts();
      await catalogLoad(true);
      location.hash = "scheme:" + id;
    } catch (e) { $("#ns-msg").textContent = e.message; $("#ns-msg").className = "state err"; }
  });
}
