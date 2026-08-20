'use strict';

// Редактор mod-item-talents («Пробуждение снаряжения»).
//
// Модель, которую здесь правят (детали — в app/italents.py):
//   * КАТЕГОРИЯ решает, из какого меню предмет берёт варианты. Кому какая
//     категория — правила по (класс, подкласс, слот, качество, entry);
//     побеждает наибольший приоритет. Это замена захардкоженных пулов A..H.
//   * МЕНЮ РЯДА может быть любой длины (до 30). В UI игрока всегда 3 слота,
//     значит из меню роллится roll_count вариантов: 10 вариантов и roll_count
//     3 = «3 случайных из 10»; ровно 3 варианта = «всегда эти три».
//   * ПЕРСОНАЛЬНЫЙ ПУЛ предмета (вкладка «Предметы») перекрывает меню
//     категории для этого entry — так эпикам назначают перки вручную.
//   * ПОРОГИ убийств берутся из кривой по (качество, ilvl), а не одной
//     строкой конфига на все предметы.
//
// Сохранение идёт посекционно и сразу зовёт `.itemtalent reload` — как у
// погоды. Уже разданные предметам роллы правка меню не меняет: у предмета
// останется прежний выбор, пока его не перекатают `.itemtalent reroll`.

let META = null;
let CATS = [];          // категории
let RULES = [];         // правила подбора
let CURRENT_TAB = 'categories';
let CURRENT_CODE = null;
let CURRENT_ITEM = null;
let ITEMS = [];
let LIBRARY = [];

const TABS = [
  { id: 'categories', title: 'Категории' },
  { id: 'menus', title: 'Меню категорий' },
  { id: 'items', title: 'Предметы (эпик+)' },
  { id: 'procs', title: 'Проки ряда 5' },
  { id: 'curves', title: 'Пороги убийств' },
  { id: 'library', title: 'Библиотека перков' },
];

// --- мелкие помощники -----------------------------------------------------

function num(v) { return Number(v) || 0; }

function effectOptions() {
  return META.effects.map(e => ({ id: e.code, label: `${e.label} (${e.code})` }));
}

function effectKind(code) {
  const hit = META.effects.find(e => e.code === code);
  return hit ? hit.kind : 'flat';
}

// Значение перка так, как его посчитает модуль (CalcValue):
// flat = max(1, ceil(base + per_ilvl * ilvl)); pct = base как есть;
// PROC = ceil(per_ilvl * ilvl), base — id триггер-спелла.
function calcValue(choice, ilvl) {
  const kind = effectKind(choice.effect);
  if (kind === 'pct') return `${num(choice.base)}%`;
  if (kind === 'proc') {
    const v = Math.ceil(num(choice.per_ilvl) * ilvl);
    return v > 0 ? `${v} (спелл ${num(choice.base)})` : `спелл ${num(choice.base)}`;
  }
  const v = Math.ceil(num(choice.base) + num(choice.per_ilvl) * ilvl);
  return String(Math.max(1, v));
}

function subclassName(cls, sub) {
  if (sub < 0) return 'любой';
  const table = cls === 2 ? META.weapon_subclasses : META.armor_subclasses;
  return (table && table[sub]) ? `${sub} — ${table[sub]}` : String(sub);
}

function selectEl(options, value, onChange) {
  const s = el('select');
  options.forEach(o => {
    const opt = el('option', null, o.label);
    opt.value = o.id;
    s.appendChild(opt);
  });
  if (!options.some(o => String(o.id) === String(value))) {
    const opt = el('option', null, `${value} — вне списка`);
    opt.value = value;
    s.appendChild(opt);
  }
  s.value = value;
  s.addEventListener('change', () => onChange(s.value));
  return s;
}

function problemsBox() {
  const box = el('div', 'problems');
  box.id = 'problems';
  return box;
}

function showProblems(list) {
  const box = document.getElementById('problems');
  if (!box) return;
  box.innerHTML = '';
  (list || []).forEach(p => box.appendChild(el('div', 'problem ' + p.level, p.message)));
}

// Общий цикл сохранения секции: 422 = только ошибки валидации, их можно
// продавить (иногда промежуточное состояние обязано быть невалидным).
async function put(path, body, after) {
  async function attempt(force) {
    try {
      const res = await api(`${path}?reload=true&force=${force ? 1 : 0}`, {
        method: 'PUT', body: JSON.stringify(body),
      });
      showProblems(res.problems);
      toast(res.reloaded
        ? 'Сохранено, модуль перечитал таблицы.'
        : `Сохранено. Модуль НЕ перечитал: ${res.reload_output}`,
        res.reloaded ? 'ok' : 'err');
      if (after) await after();
    } catch (err) {
      if (err.payload && err.payload.problems) {
        showProblems(err.payload.problems);
        if (confirm('Есть ошибки — сохранить всё равно?')) return attempt(true);
        toast('Не сохранено.', 'err');
      } else {
        toast(err.message, 'err');
      }
    }
  }
  return attempt(false);
}

// --- универсальная таблица ------------------------------------------------
// cols: { key, head, type: num|text|bool|select|ro|calc, options, calc }

function gridTable(rows, cols, opts) {
  const wrap = el('div', 'grid-wrap');
  const table = el('table', 'grid');
  const thead = el('thead');
  const hr = el('tr');
  cols.forEach(c => hr.appendChild(el('th', null, c.head || c.key)));
  hr.appendChild(el('th', null, ''));
  thead.appendChild(hr);
  table.appendChild(thead);
  const tbody = el('tbody');
  table.appendChild(tbody);
  wrap.appendChild(table);

  function cell(row, c) {
    if (c.type === 'ro') return el('span', null, String(c.value ? c.value(row) : row[c.key]));
    if (c.type === 'calc') return el('span', null, c.calc(row));
    if (c.type === 'bool') {
      const box = el('input');
      box.type = 'checkbox';
      box.checked = !!row[c.key];
      box.addEventListener('change', () => {
        row[c.key] = box.checked;
        if (c.redraw) draw();
      });
      return box;
    }
    if (c.type === 'select') {
      return selectEl(c.options(row), row[c.key], v => {
        row[c.key] = c.numeric === false ? v : Number(v);
        draw();
      });
    }
    const input = el('input');
    input.type = c.type === 'num' ? 'number' : 'text';
    if (c.step) input.step = c.step;
    input.value = row[c.key] === undefined || row[c.key] === null ? '' : row[c.key];
    input.addEventListener('input', () => {
      row[c.key] = c.type === 'num' ? Number(input.value) : input.value;
      if (c.redraw) draw();
    });
    return input;
  }

  function draw() {
    tbody.innerHTML = '';
    rows.forEach(row => {
      const tr = el('tr');
      cols.forEach(c => {
        const td = el('td', c.type === 'num' ? 'num'
          : c.type === 'bool' ? 'tiny'
            : c.type === 'calc' ? 'calc' : null);
        td.appendChild(cell(row, c));
        tr.appendChild(td);
      });
      const act = el('td', 'act');
      const del = el('button', 'btn tiny danger', '×');
      del.title = 'Удалить строку';
      del.addEventListener('click', () => {
        rows.splice(rows.indexOf(row), 1);
        draw();
        if (opts && opts.onChange) opts.onChange();
      });
      act.appendChild(del);
      tr.appendChild(act);
      tbody.appendChild(tr);
    });
    if (opts && opts.onChange) opts.onChange();
  }

  draw();
  wrap.redraw = draw;
  return wrap;
}

// --- вкладка «Категории» --------------------------------------------------

async function renderCategories() {
  const view = document.getElementById('view');
  view.innerHTML = '';
  const data = await api('/api/italents/categories');
  CATS = data.categories;
  RULES = data.rules;

  view.appendChild(el('p', 'note',
    'Категория — набор меню перков. Правила решают, кому какая категория ' +
    'достанется: предмет проверяется по правилам сверху вниз (по убыванию ' +
    'приоритета), побеждает первое совпавшее. -1 в поле = «любое». ' +
    'Столбец «предметов» считается ровно этим же порядком.'));

  const bar = el('div', 'toolbar');
  const addCat = el('button', 'btn ghost', '+ категория');
  addCat.addEventListener('click', () => {
    CATS.push({ code: '', name_ru: '', comment: '', enabled: true, sort: 0, choices: 0, items: 0 });
    catsGrid.redraw();
  });
  const addRule = el('button', 'btn ghost', '+ правило');
  addRule.addEventListener('click', () => {
    RULES.push({
      code: CATS.length ? CATS[0].code : '', item_class: -1, subclass: -1,
      inv_type: -1, quality_min: 0, quality_max: 7, entry_lo: 0, entry_hi: 0,
      priority: 0, comment: '',
    });
    rulesGrid.redraw();
  });
  const saveBtn = el('button', 'btn primary', 'Сохранить и применить');
  saveBtn.addEventListener('click', () => put('/api/italents/categories', {
    categories: CATS.map(c => ({
      code: c.code, name_ru: c.name_ru, comment: c.comment,
      enabled: c.enabled, sort: num(c.sort),
    })),
    rules: RULES.map(r => ({
      code: r.code, item_class: num(r.item_class), subclass: num(r.subclass),
      inv_type: num(r.inv_type), quality_min: num(r.quality_min),
      quality_max: num(r.quality_max), entry_lo: num(r.entry_lo),
      entry_hi: num(r.entry_hi), priority: num(r.priority), comment: r.comment,
    })),
  }, renderCategories));

  bar.appendChild(addCat);
  bar.appendChild(addRule);
  bar.appendChild(el('span', 'grow'));
  bar.appendChild(saveBtn);
  view.appendChild(bar);
  view.appendChild(problemsBox());

  view.appendChild(el('h3', null, 'Категории'));
  const catsGrid = gridTable(CATS, [
    { key: 'code', head: 'Код', type: 'text' },
    { key: 'name_ru', head: 'Название', type: 'text' },
    { key: 'comment', head: 'Комментарий', type: 'text' },
    { key: 'enabled', head: 'Вкл', type: 'bool' },
    { key: 'sort', head: 'Порядок', type: 'num' },
    { key: 'choices', head: 'Вариантов', type: 'ro' },
    { key: 'items', head: 'Предметов', type: 'ro' },
  ]);
  view.appendChild(catsGrid);

  view.appendChild(el('h3', null, 'Правила подбора'));
  const classOptions = () => [{ id: -1, label: 'любой класс' }].concat(
    Object.keys(META.item_classes).map(k => ({ id: Number(k), label: META.item_classes[k] })));
  const rulesGrid = gridTable(RULES, [
    {
      key: 'code', head: 'Категория', type: 'select', numeric: false,
      options: () => CATS.map(c => ({ id: c.code, label: `${c.code} — ${c.name_ru}` })),
    },
    { key: 'item_class', head: 'Класс', type: 'select', options: classOptions },
    { key: 'subclass', head: 'Подкласс', type: 'num' },
    {
      key: 'subclass_name', head: '', type: 'ro',
      value: r => subclassName(num(r.item_class), num(r.subclass)),
    },
    { key: 'inv_type', head: 'Слот (InvType)', type: 'num' },
    { key: 'quality_min', head: 'Качество от', type: 'num' },
    { key: 'quality_max', head: 'до', type: 'num' },
    { key: 'entry_lo', head: 'entry от', type: 'num' },
    { key: 'entry_hi', head: 'до', type: 'num' },
    { key: 'priority', head: 'Приоритет', type: 'num' },
    { key: 'comment', head: 'Комментарий', type: 'text' },
  ]);
  view.appendChild(rulesGrid);
}

// --- редактор рядов (общий для категорий и предметов) ---------------------

function rowCard(rowData, ctx) {
  // ctx: { ilvl, withSubclass, itemClass, onSave, onClear, inherited }
  const card = el('div', 'row-card' + (ctx.inherited ? ' inherited' : ''));
  const head = el('header');
  head.appendChild(el('span', 'title', `Ряд ${rowData.row} — ${rowData.name}`));

  const pill = el('span', 'pill' + (ctx.inherited ? '' : ' own'),
    ctx.inherited ? 'как в категории' : `вариантов: ${rowData.choices.length}`);
  head.appendChild(pill);

  const rollLabel = el('label', null, 'роллится ');
  const roll = selectEl([1, 2, 3].map(n => ({ id: n, label: String(n) })),
    rowData.roll_count, v => { rowData.roll_count = Number(v); });
  rollLabel.appendChild(roll);
  rollLabel.appendChild(helpBadge(
    'Сколько вариантов из меню выпадет игроку. Слотов в аддоне всегда 3, ' +
    'поэтому больше 3 не бывает. Меню из 10 и «роллится 3» = 3 случайных из 10.'));
  head.appendChild(rollLabel);

  const qLabel = el('label', null, ' качество ');
  const qBox = el('input');
  qBox.type = 'checkbox';
  qBox.checked = !!rowData.quality_enabled;
  qBox.addEventListener('change', () => { rowData.quality_enabled = qBox.checked; });
  qLabel.insertBefore(qBox, qLabel.firstChild);
  qLabel.appendChild(helpBadge(
    'Катать ли качество ролла (обычный x1.0 / отличный x1.25 / совершенный ' +
    'x1.5). Для проков ряда 5 качество не применяется — выключайте.'));
  head.appendChild(qLabel);

  head.appendChild(el('span', 'grow'));

  const addBtn = el('button', 'btn tiny ghost', '+ вариант');
  addBtn.addEventListener('click', () => {
    const used = rowData.choices.map(c => c.choice);
    let next = 1;
    while (used.includes(next) && next < META.max_choices) next++;
    rowData.choices.push({
      choice: next, name_ru: '', desc_ru: '', effect: 'STAT_STA',
      base: 0, per_ilvl: 0, subclass: -1,
    });
    grid.redraw();
  });
  head.appendChild(addBtn);

  if (LIBRARY.length) {
    const fromLib = el('button', 'btn tiny ghost', 'из библиотеки');
    fromLib.addEventListener('click', () => {
      const names = LIBRARY.map((p, i) => `${i + 1}. ${p.name_ru} (${p.effect})`).join('\n');
      const pick = prompt(`Номер перка:\n${names}`);
      const idx = parseInt(pick, 10) - 1;
      if (!(idx >= 0 && idx < LIBRARY.length)) return;
      const p = LIBRARY[idx];
      const used = rowData.choices.map(c => c.choice);
      let next = 1;
      while (used.includes(next) && next < META.max_choices) next++;
      rowData.choices.push({
        choice: next, name_ru: p.name_ru, desc_ru: p.desc_ru, effect: p.effect,
        base: p.base, per_ilvl: p.per_ilvl, subclass: -1,
      });
      grid.redraw();
    });
    head.appendChild(fromLib);
  }

  const saveBtn = el('button', 'btn tiny primary', 'Сохранить ряд');
  saveBtn.addEventListener('click', () => ctx.onSave(rowData));
  head.appendChild(saveBtn);

  if (ctx.onClear && !ctx.inherited) {
    const clr = el('button', 'btn tiny danger', 'Сбросить в категорию');
    clr.title = 'Удалить персональный пул — предмет вернётся к меню категории';
    clr.addEventListener('click', () => {
      if (confirm('Убрать персональный пул этого ряда?')) ctx.onClear(rowData);
    });
    head.appendChild(clr);
  }

  card.appendChild(head);

  const body = el('div', 'body');
  const cols = [
    { key: 'choice', head: '#', type: 'num' },
    { key: 'name_ru', head: 'Название', type: 'text' },
    { key: 'desc_ru', head: 'Описание ({N} — значение)', type: 'text' },
    {
      key: 'effect', head: 'Эффект', type: 'select', numeric: false,
      options: () => effectOptions(), redraw: true,
    },
    { key: 'base', head: 'base', type: 'num', step: '0.01', redraw: true },
    { key: 'per_ilvl', head: 'за ilvl', type: 'num', step: '0.01', redraw: true },
    {
      key: 'calc', head: `≈ ilvl ${ctx.ilvl}`, type: 'calc',
      calc: c => calcValue(c, ctx.ilvl),
    },
  ];
  if (ctx.withSubclass) {
    cols.splice(1, 0, { key: 'subclass', head: 'Подкласс', type: 'num' });
  }
  const grid = gridTable(rowData.choices, cols);
  body.appendChild(grid);
  card.appendChild(body);
  return card;
}

function rowPayload(rowData, withSubclass) {
  return {
    row: rowData.row,
    roll_count: num(rowData.roll_count) || 3,
    quality_enabled: !!rowData.quality_enabled,
    choices: rowData.choices.map(c => ({
      choice: num(c.choice), name_ru: c.name_ru || '', desc_ru: c.desc_ru || '',
      effect: c.effect, base: num(c.base), per_ilvl: num(c.per_ilvl),
      subclass: withSubclass ? num(c.subclass) : -1,
    })),
  };
}

// --- вкладка «Меню категорий» --------------------------------------------

async function renderMenus() {
  const view = document.getElementById('view');
  view.innerHTML = '';

  if (!CATS.length) {
    const data = await api('/api/italents/categories');
    CATS = data.categories;
    RULES = data.rules;
  }
  if (!CURRENT_CODE && CATS.length) CURRENT_CODE = CATS[0].code;

  view.appendChild(el('p', 'note',
    'Меню ряда для всей категории — сюда попадают неэпические предметы. ' +
    'Подкласс -1 = меню для всех предметов категории; конкретный подкласс ' +
    'перекрывает его (так сделаны проки ряда 5 по типам оружия).'));

  const bar = el('div', 'toolbar');
  CATS.forEach(c => {
    const b = el('button', 'btn ghost' + (c.code === CURRENT_CODE ? ' active' : ''),
      `${c.code} — ${c.name_ru}`);
    b.addEventListener('click', () => { CURRENT_CODE = c.code; renderMenus(); });
    bar.appendChild(b);
  });
  view.appendChild(bar);
  view.appendChild(problemsBox());

  if (!CURRENT_CODE) {
    view.appendChild(el('div', 'empty', 'Сначала заведите категорию.'));
    return;
  }

  const rows = await api(`/api/italents/categories/${CURRENT_CODE}/rows`);
  rows.forEach(rowData => {
    view.appendChild(rowCard(rowData, {
      ilvl: 200,
      withSubclass: true,
      onSave: rd => put(
        `/api/italents/categories/${CURRENT_CODE}/rows/${rd.row}`,
        rowPayload(rd, true), renderMenus),
    }));
  });
}

// --- вкладка «Предметы» ---------------------------------------------------

async function loadItems(term, qualityMin, itemClass, onlyCustom) {
  const params = new URLSearchParams({
    q: term || '', quality_min: String(qualityMin),
    item_class: String(itemClass), only_custom: onlyCustom ? 'true' : 'false',
    limit: '300',
  });
  ITEMS = await api('/api/italents/items?' + params.toString());
}

async function renderItems() {
  const view = document.getElementById('view');
  view.innerHTML = '';

  view.appendChild(el('p', 'note',
    'Персональный пул перекрывает меню категории для этого entry. Заведите ' +
    '10 вариантов и оставьте «роллится 3» — игроку выпадут 3 случайных; ' +
    'заведите ровно 3 — они будут у предмета всегда (именной набор).'));

  const split = el('div', 'split');
  const left = el('div', 'left');
  const right = el('div', 'right');
  split.appendChild(left);
  split.appendChild(right);

  const bar = el('div', 'toolbar');
  const search = el('input', 'input');
  search.type = 'search';
  search.placeholder = 'Название или entry…';
  const qMin = selectEl(
    Object.keys(META.quality_names).map(k => ({
      id: Number(k), label: `от ${META.quality_names[k]}`,
    })), 4, () => refresh());
  const cls = selectEl([{ id: -1, label: 'все' }].concat(
    Object.keys(META.item_classes).map(k => ({
      id: Number(k), label: META.item_classes[k],
    }))), -1, () => refresh());
  const onlyCustom = el('input');
  onlyCustom.type = 'checkbox';
  const ocLabel = el('label', null, ' только со своим пулом');
  ocLabel.insertBefore(onlyCustom, ocLabel.firstChild);
  onlyCustom.addEventListener('change', refresh);

  bar.appendChild(search);
  bar.appendChild(qMin);
  bar.appendChild(cls);
  bar.appendChild(ocLabel);
  left.appendChild(bar);

  const list = el('div', 'item-list');
  left.appendChild(list);

  let timer = null;
  search.addEventListener('input', () => {
    clearTimeout(timer);
    timer = setTimeout(refresh, 300);
  });

  async function refresh() {
    list.innerHTML = '<div class="empty">Ищем…</div>';
    await loadItems(search.value, Number(qMin.value), Number(cls.value),
      onlyCustom.checked);
    list.innerHTML = '';
    if (!ITEMS.length) {
      list.appendChild(el('div', 'empty', 'Ничего не нашлось.'));
      return;
    }
    ITEMS.forEach(it => {
      const row = el('div', 'item-row'
        + (CURRENT_ITEM && CURRENT_ITEM.entry === it.entry ? ' active' : ''));
      const nm = el('span', 'nm q' + it.quality, it.name);
      // Имя — русское (item_template_locale ruRU), как его видит игрок;
      // английское оставляем в подсказке, по нему тоже работает поиск.
      if (it.name_en && it.name_en !== it.name) nm.title = it.name_en;
      row.appendChild(nm);
      if (it.own_choices) row.appendChild(el('span', 'pill own', 'свой пул'));
      row.appendChild(el('span', 'meta', `ilvl ${it.ilvl} · ${it.entry}`));
      row.addEventListener('click', () => openItem(it.entry, right));
      list.appendChild(row);
    });
  }

  view.appendChild(split);
  view.appendChild(problemsBox());
  right.appendChild(el('div', 'empty', 'Выберите предмет слева.'));
  await refresh();
  if (CURRENT_ITEM) await openItem(CURRENT_ITEM.entry, right);
}

async function openItem(entry, right) {
  CURRENT_ITEM = await api(`/api/italents/items/${entry}`);
  const it = CURRENT_ITEM;
  right.innerHTML = '';

  const head = el('div', 'toolbar');
  const title = el('h3', 'q' + it.quality, it.name);
  if (it.name_en && it.name_en !== it.name) title.title = it.name_en;
  head.appendChild(title);
  head.appendChild(el('span', 'muted',
    `entry ${it.entry} · ilvl ${it.ilvl} · ${META.quality_names[it.quality]} · `
    + `${subclassName(it.class, it.subclass)}`));
  right.appendChild(head);

  right.appendChild(el('p', 'note', it.category
    ? `Категория по правилам: ${it.category}. Рядов открыто качеством: ${it.rows_open}.`
    : 'Ни одно правило не выбирает этот предмет — он вне системы талантов, '
      + 'пока не появится подходящее правило или персональный пул.'));

  it.rows.forEach(rowData => {
    right.appendChild(rowCard(rowData, {
      ilvl: it.ilvl,
      withSubclass: false,
      inherited: !rowData.own,
      onSave: rd => put(`/api/italents/items/${it.entry}/rows/${rd.row}`,
        rowPayload(rd, false), () => openItem(it.entry, right)),
      onClear: rd => put(`/api/italents/items/${it.entry}/rows/${rd.row}`,
        { row: rd.row, roll_count: 3, quality_enabled: true, choices: [] },
        () => openItem(it.entry, right)),
    }));
  });
}

// --- вкладка «Проки ряда 5» ----------------------------------------------
// Строка item_talent_procs — это МЕХАНИКА прока: когда срабатывает, что
// делает, с каким шансом. Сам перк ссылается на неё через base = trigger_spell
// (вкладки «Меню категорий» / «Предметы», эффект PROC).

async function renderProcs() {
  const view = document.getElementById('view');
  view.innerHTML = '';
  const data = await api('/api/italents/procs');
  const rows = data.procs;
  const spells = data.spells;

  view.appendChild(el('p', 'note',
    'Механика проков ряда 5. `trigger_spell` — ключ: перк с эффектом PROC ' +
    'ссылается на него полем base, а per_ilvl перка задаёт силу. ' +
    '`visible_spell` — то, что реально кастуется: из него берутся визуал, ' +
    'школа и длительность, а значение подставляется как basepoints.'));
  view.appendChild(el('p', 'note',
    `Свободных id в диапазоне ${spells.range[0]}-${spells.range[1]}: ` +
    `${spells.free.length}` +
    (spells.free.length ? ` (${spells.free.slice(0, 8).join(', ')}` +
      (spells.free.length > 8 ? ', …' : '') + ')' : '') +
    '. За пределами диапазона каст перестаёт считаться «своим» — модуль ' +
    'больше не отсекает рекурсию проков. Новые строки spell_dbc требуют ' +
    'РЕСТАРТА worldserver, одного «Применить» мало.'));

  const bar = el('div', 'toolbar');
  const add = el('button', 'btn ghost', '+ прок');
  add.addEventListener('click', () => {
    rows.push({
      trigger_spell: spells.free.length ? spells.free[0] : 0,
      visible_spell: 0, trigger_type: 'MELEE_HIT', effect_type: 'DAMAGE',
      school: 0, chance: 10, icd_secs: 8, coef: 1, duration_secs: 0,
      hp_threshold: 0, perks: [], trigger_in_dbc: false, visible_in_dbc: false,
    });
    grid.redraw();
  });
  const save = el('button', 'btn primary', 'Сохранить и применить');
  save.addEventListener('click', () => put('/api/italents/procs',
    rows.map(r => ({
      trigger_spell: num(r.trigger_spell), visible_spell: num(r.visible_spell),
      trigger_type: r.trigger_type, effect_type: r.effect_type,
      school: num(r.school), chance: num(r.chance), icd_secs: num(r.icd_secs),
      coef: num(r.coef), duration_secs: num(r.duration_secs),
      hp_threshold: num(r.hp_threshold),
    })), renderProcs));
  bar.appendChild(add);
  bar.appendChild(el('span', 'grow'));
  bar.appendChild(save);
  view.appendChild(bar);
  view.appendChild(problemsBox());

  const grid = gridTable(rows, [
    { key: 'trigger_spell', head: 'Триггер (base перка)', type: 'num' },
    { key: 'visible_spell', head: 'Видимый спелл', type: 'num' },
    {
      key: 'dbc', head: 'В spell_dbc', type: 'ro',
      value: r => (r.trigger_in_dbc ? 'триггер ✓' : 'триггер ✗')
        + ' / ' + (r.visible_in_dbc ? 'визуал ✓' : 'визуал ✗'),
    },
    {
      key: 'trigger_type', head: 'Когда', type: 'select', numeric: false,
      options: () => META.proc_triggers.map(t => ({ id: t.code, label: t.label })),
    },
    {
      key: 'effect_type', head: 'Что делает', type: 'select', numeric: false,
      options: () => META.proc_effects.map(t => ({ id: t.code, label: t.label })),
    },
    { key: 'chance', head: 'Шанс %', type: 'num' },
    { key: 'icd_secs', head: 'ICD, с', type: 'num' },
    { key: 'coef', head: 'Коэф. за ilvl', type: 'num', step: '0.01' },
    {
      key: 'calc', head: '≈ ilvl 200', type: 'calc',
      calc: r => String(Math.ceil(num(r.coef) * 200)),
    },
    { key: 'duration_secs', head: 'Длит., с', type: 'num' },
    { key: 'hp_threshold', head: 'Порог HP %', type: 'num' },
    { key: 'school', head: 'Школа', type: 'num' },
    {
      key: 'perks', head: 'Используется перками', type: 'ro',
      value: r => (r.perks && r.perks.length) ? r.perks.join(', ') : '— никем',
    },
  ]);
  view.appendChild(grid);
}

// --- вкладка «Пороги убийств» --------------------------------------------

async function renderCurves() {
  const view = document.getElementById('view');
  view.innerHTML = '';
  const rows = await api('/api/italents/curves');

  view.appendChild(el('p', 'note',
    'Сколько убийств нужно ЗА каждый уровень пробуждения. Счётчик не ' +
    'накопительный: взятие уровня обнуляет его. Строка подбирается по ' +
    'качеству И уровню предмета, побеждает наибольший приоритет; если ни ' +
    'одна не подошла — модуль возьмёт ItemTalents.PointThresholds из конфига.'));

  const bar = el('div', 'toolbar');
  const add = el('button', 'btn ghost', '+ строка');
  add.addEventListener('click', () => {
    rows.push({
      id: 0, name: '', quality_min: 0, quality_max: 7, ilvl_min: 0,
      ilvl_max: 999, lvl1: 50, lvl2: 150, lvl3: 400, lvl4: 1000, lvl5: 2500,
      priority: 0,
    });
    grid.redraw();
  });
  const save = el('button', 'btn primary', 'Сохранить и применить');
  save.addEventListener('click', () => put('/api/italents/curves',
    rows.map(r => ({
      id: num(r.id), name: r.name || '', quality_min: num(r.quality_min),
      quality_max: num(r.quality_max), ilvl_min: num(r.ilvl_min),
      ilvl_max: num(r.ilvl_max), lvl1: num(r.lvl1), lvl2: num(r.lvl2),
      lvl3: num(r.lvl3), lvl4: num(r.lvl4), lvl5: num(r.lvl5),
      priority: num(r.priority),
    })), renderCurves));
  bar.appendChild(add);
  bar.appendChild(el('span', 'grow'));
  bar.appendChild(save);
  view.appendChild(bar);
  view.appendChild(problemsBox());

  const grid = gridTable(rows, [
    { key: 'name', head: 'Название', type: 'text' },
    { key: 'quality_min', head: 'Качество от', type: 'num' },
    { key: 'quality_max', head: 'до', type: 'num' },
    { key: 'ilvl_min', head: 'ilvl от', type: 'num' },
    { key: 'ilvl_max', head: 'до', type: 'num' },
    { key: 'lvl1', head: 'ур. 1', type: 'num' },
    { key: 'lvl2', head: 'ур. 2', type: 'num' },
    { key: 'lvl3', head: 'ур. 3', type: 'num' },
    { key: 'lvl4', head: 'ур. 4', type: 'num' },
    { key: 'lvl5', head: 'ур. 5', type: 'num' },
    { key: 'priority', head: 'Приоритет', type: 'num' },
    {
      key: 'total', head: 'Всего', type: 'calc',
      calc: r => String(num(r.lvl1) + num(r.lvl2) + num(r.lvl3)
        + num(r.lvl4) + num(r.lvl5)),
    },
  ]);
  view.appendChild(grid);
}

// --- вкладка «Библиотека перков» -----------------------------------------

async function renderLibrary() {
  const view = document.getElementById('view');
  view.innerHTML = '';
  LIBRARY = await api('/api/italents/library');

  view.appendChild(el('p', 'note',
    'Заготовки перков: из них собираются и меню категорий, и персональные ' +
    'пулы предметов (кнопка «из библиотеки» в редакторе ряда). Ядро эту ' +
    'таблицу не читает — она только для панели.'));

  const bar = el('div', 'toolbar');
  const add = el('button', 'btn ghost', '+ перк');
  add.addEventListener('click', () => {
    LIBRARY.push({
      id: 0, name_ru: '', desc_ru: '', effect: 'STAT_STA', base: 0,
      per_ilvl: 0, tags: '',
    });
    grid.redraw();
  });
  const save = el('button', 'btn primary', 'Сохранить');
  save.addEventListener('click', async () => {
    try {
      await api('/api/italents/library', {
        method: 'PUT',
        body: JSON.stringify(LIBRARY.map(p => ({
          id: num(p.id), name_ru: p.name_ru || '', desc_ru: p.desc_ru || '',
          effect: p.effect, base: num(p.base), per_ilvl: num(p.per_ilvl),
          tags: p.tags || '',
        }))),
      });
      toast('Библиотека сохранена.', 'ok');
      await renderLibrary();
    } catch (err) {
      toast(err.message, 'err');
    }
  });
  bar.appendChild(add);
  bar.appendChild(el('span', 'grow'));
  bar.appendChild(save);
  view.appendChild(bar);

  const grid = gridTable(LIBRARY, [
    { key: 'name_ru', head: 'Название', type: 'text' },
    { key: 'desc_ru', head: 'Описание', type: 'text' },
    {
      key: 'effect', head: 'Эффект', type: 'select', numeric: false,
      options: () => effectOptions(), redraw: true,
    },
    { key: 'base', head: 'base', type: 'num', step: '0.01' },
    { key: 'per_ilvl', head: 'за ilvl', type: 'num', step: '0.01' },
    {
      key: 'calc', head: '≈ ilvl 200', type: 'calc',
      calc: p => calcValue(p, 200),
    },
    { key: 'tags', head: 'Теги', type: 'text' },
  ]);
  view.appendChild(grid);
}

// --- каркас ---------------------------------------------------------------

const RENDERERS = {
  categories: renderCategories,
  menus: renderMenus,
  items: renderItems,
  procs: renderProcs,
  curves: renderCurves,
  library: renderLibrary,
};

function renderTabs() {
  const box = document.getElementById('tabs');
  box.innerHTML = '';
  TABS.forEach(t => {
    const b = el('button', 'btn ghost' + (t.id === CURRENT_TAB ? ' active' : ''),
      t.title);
    b.addEventListener('click', () => {
      CURRENT_TAB = t.id;
      renderTabs();
      show();
    });
    box.appendChild(b);
  });
}

async function show() {
  const view = document.getElementById('view');
  view.innerHTML = '<div class="empty">Загрузка…</div>';
  try {
    await RENDERERS[CURRENT_TAB]();
  } catch (err) {
    view.innerHTML = '';
    view.appendChild(el('div', 'problem error', err.message));
  }
}

async function init() {
  document.getElementById('btn-reload').addEventListener('click', async () => {
    try {
      const res = await api('/api/italents/reload', { method: 'POST' });
      toast(`Модуль перечитал таблицы: ${res.output || 'ok'}`, 'ok');
    } catch (err) {
      toast(err.message, 'err');
    }
  });

  try {
    META = await api('/api/italents/meta');
  } catch (err) {
    document.getElementById('view').innerHTML = '';
    document.getElementById('view').appendChild(el('div', 'problem error', err.message));
    return;
  }

  if (!META.installed) {
    const view = document.getElementById('view');
    view.innerHTML = '';
    const box = el('div', 'warn-box');
    box.appendChild(el('div', null,
      'Миграция редактора не применена: в acore_world нет item_talent_category '
      + '/ item_talent_category_rule.'));
    box.appendChild(el('div', null,
      'Примените data/sql/updates/pending_db_world/mod_item_talents_v3_admin.sql '
      + 'и нажмите «Применить» — модуль подхватит таблицы без рестарта.'));
    view.appendChild(box);
    return;
  }

  // Библиотека нужна кнопке «из библиотеки» на любой вкладке.
  try { LIBRARY = await api('/api/italents/library'); } catch (_) { LIBRARY = []; }

  renderTabs();
  await show();
}

init();
