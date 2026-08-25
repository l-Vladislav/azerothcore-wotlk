'use strict';

// Spell workshop. The form is not hardcoded: /api/spells/catalog hands over the
// field groups, the enums (parsed from the core headers) and the *_dbc dropdown
// contents, and this file renders whatever it is given. Adding a field is a
// one-line change in app/spells.py, not here.

let CATALOG = null;      // { enums, refs, groups, effect_fields, blocks }
let list = [];
// { id, fields, module, icon_texture, notes, block, clone_of? }
let current = null;
let creating = false;
let dirty = false;
let filters = { block: '', q: '' };
// `meta` is open by default: it holds the module and the id pool, and for a new
// or copied spell those decide the id it is about to take.
let openGroups = new Set(['meta', 'main', 'text', 'effects']);

const APPLY_AURA = 6;

// --- helpers --------------------------------------------------------------

const enumList = name => (CATALOG.enums[name] || []);

function enumLabel(name, value) {
  const hit = enumList(name).find(e => e.id === Number(value));
  return hit ? hit.label : String(value);
}

function refSelect(table, value, onChange) {
  const items = (CATALOG.refs[table] || []);
  const s = el('select', 'sel');
  const seen = new Set();
  for (const it of items) {
    if (seen.has(it.id)) continue;
    seen.add(it.id);
    const o = el('option', null, `${it.id} — ${it.label}`);
    o.value = String(it.id);
    if (it.id === Number(value)) o.selected = true;
    s.appendChild(o);
  }
  if (!seen.has(Number(value))) {
    const o = el('option', null, String(value));
    o.value = String(value);
    o.selected = true;
    s.insertBefore(o, s.firstChild);
  }
  s.addEventListener('change', () => onChange(Number(s.value)));
  return s;
}

// Bitmask editor. It reads and writes current.fields[col] directly on every
// toggle, so several checkboxes compose instead of each one starting from the
// value the field had when it was first rendered.
function flagsField(col, enumName, onChange) {
  const box = el('div', 'flags');
  const read = () => Number(current.fields[col] || 0) >>> 0;
  for (const bit of enumList(enumName)) {
    const label = el('label', 'flag');
    const cb = el('input');
    cb.type = 'checkbox';
    cb.checked = (read() & bit.id) !== 0;
    cb.addEventListener('change', () => {
      const next = (cb.checked ? (read() | bit.id) : (read() & ~bit.id)) >>> 0;
      onChange(next);
    });
    label.appendChild(cb);
    label.appendChild(el('span', null, bit.label));
    label.title = `${bit.const} = 0x${bit.id.toString(16)}`;
    box.appendChild(label);
  }
  return box;
}

// --- icon picker ----------------------------------------------------------
// The icon is a Blizzard texture name, and there are 3 226 of them: typing one
// from memory is the least pleasant field in the form. The picker loads the
// whole list once and filters client-side; images are lazy, so only the
// visible rows of the grid ever hit the network.

let ICONS = null;          // [{id, texture}], loaded on first open
let ICON_BASE = '';

const BLANK_ICON =
  'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

function iconUrl(texture) {
  if (!texture) return BLANK_ICON;
  return ICON_BASE ? `${ICON_BASE}/${texture}.jpg` : BLANK_ICON;
}

function iconImg(texture, cls) {
  const img = el('img', cls || 'icon');
  img.loading = 'lazy';
  img.alt = '';
  img.title = texture || 'иконка не задана';
  img.src = iconUrl(texture);
  img.addEventListener('error', () => { img.src = BLANK_ICON; }, { once: true });
  return img;
}

async function openIconPicker(currentTexture, onPick) {
  if (!ICONS) {
    try {
      const res = await api('/api/icons');
      ICONS = res.items;
      ICON_BASE = res.icon_base_url || '';
    } catch (e) {
      toast(e.message, 'err');
      return;
    }
  }

  const overlay = el('div', 'modal');
  const box = el('div', 'modal-box wide');
  const head = el('div', 'modal-head');
  head.appendChild(el('strong', null, 'Иконка спелла'));
  const search = el('input', 'input');
  search.placeholder = 'Фильтр: frost, holy, inv_misc…';
  head.appendChild(search);
  const count = el('span', 'muted');
  head.appendChild(count);
  box.appendChild(head);

  const grid = el('div', 'icon-grid');
  box.appendChild(grid);

  const foot = el('div', 'modal-foot');
  const chosen = el('span', 'muted', currentTexture || 'не задана');
  const prev = el('button', 'btn ghost tiny', '←');
  const pageLabel = el('span', 'muted');
  const next = el('button', 'btn ghost tiny', '→');
  const clear = el('button', 'btn ghost', 'Убрать иконку');
  const cancel = el('button', 'btn ghost', 'Отмена');
  foot.appendChild(chosen);
  foot.appendChild(el('span', 'spacer'));
  foot.appendChild(prev);
  foot.appendChild(pageLabel);
  foot.appendChild(next);
  foot.appendChild(clear);
  foot.appendChild(cancel);
  box.appendChild(foot);

  overlay.appendChild(box);
  document.body.appendChild(overlay);

  const close = () => overlay.remove();
  cancel.addEventListener('click', close);
  clear.addEventListener('click', () => { onPick(''); close(); });
  overlay.addEventListener('click', ev => { if (ev.target === overlay) close(); });
  document.addEventListener('keydown', function onKey(ev) {
    if (ev.key === 'Escape') { close(); document.removeEventListener('keydown', onKey); }
  });

  // Paged rather than capped: 3 228 <img> nodes at once is a lot of DOM, but
  // "уточните фильтр" is a bad answer when you are browsing precisely because
  // you do not know the name yet.
  const PER_PAGE = 240;
  let hits = ICONS;
  let page = 0;

  function draw() {
    const pages = Math.max(1, Math.ceil(hits.length / PER_PAGE));
    page = Math.min(Math.max(page, 0), pages - 1);
    grid.innerHTML = '';
    for (const icon of hits.slice(page * PER_PAGE, (page + 1) * PER_PAGE)) {
      const cell = el('button', 'icon-cell' +
        (icon.texture === currentTexture ? ' current' : ''));
      cell.type = 'button';
      cell.title = `${icon.texture} (id ${icon.id})`;
      cell.appendChild(iconImg(icon.texture, 'icon'));
      cell.addEventListener('click', () => { onPick(icon.texture); close(); });
      grid.appendChild(cell);
    }
    count.textContent = `${hits.length} иконок`;
    pageLabel.textContent = `${page + 1} / ${pages}`;
    prev.disabled = page === 0;
    next.disabled = page >= pages - 1;
    grid.scrollTop = 0;
  }

  function filter() {
    const needle = search.value.trim().toLowerCase();
    hits = needle ? ICONS.filter(i => i.texture.includes(needle)) : ICONS;
    page = 0;
    draw();
  }

  prev.addEventListener('click', () => { page -= 1; draw(); });
  next.addEventListener('click', () => { page += 1; draw(); });
  search.addEventListener('input', debounce(filter, 150));
  overlay.addEventListener('keydown', ev => {
    if (ev.key === 'PageUp') { ev.preventDefault(); page -= 1; draw(); }
    if (ev.key === 'PageDown') { ev.preventDefault(); page += 1; draw(); }
  });

  // Open on the page holding the current icon, so "what is set now" is the
  // first thing visible instead of the alphabetical beginning.
  const at = ICONS.findIndex(i => i.texture === currentTexture);
  page = at >= 0 ? Math.floor(at / PER_PAGE) : 0;
  draw();
  search.focus();
}

function setField(col, value) {
  current.fields[col] = value;
  dirty = true;
  markDirty();
}

function markDirty() {
  const btn = document.getElementById('btn-save');
  if (btn) btn.textContent = dirty ? 'Сохранить *' : 'Сохранить';
}

// --- field rendering ------------------------------------------------------

function renderField(spec, col) {
  const wrap = el('label', 'field');
  const labelRow = el('span', 'field-label', spec.label);
  // The hint is a hover bubble rather than a line of text under the input:
  // with ~120 fields on screen, printing every explanation would bury the
  // form it explains.
  if (spec.hint) labelRow.appendChild(helpBadge(spec.hint));
  wrap.appendChild(labelRow);

  const value = current.fields[col];

  if (spec.kind === 'text') {
    const input = spec.col.indexOf('Description') >= 0
      ? el('textarea', 'input area') : el('input', 'input');
    if (input.tagName === 'TEXTAREA') input.rows = 2;
    // The one field a clone leaves empty on purpose — worth being able to
    // reach it directly after copying.
    if (col === 'Name_Lang_ruRU') input.id = 'f-name-ru';
    input.value = value == null ? '' : String(value);
    input.addEventListener('input', () => setField(col, input.value));
    wrap.appendChild(input);
  } else if (spec.kind === 'enum') {
    wrap.appendChild(comboBox(enumList(spec.enum), value,
      v => setField(col, v)));
  } else if (spec.kind === 'ref') {
    wrap.appendChild(refSelect(spec.ref, value, v => setField(col, v)));
  } else if (spec.kind === 'flags') {
    const box = flagsField(col, spec.enum, v => {
      setField(col, v);
      const shown = wrap.querySelector('.flag-value');
      if (shown) shown.textContent = '0x' + v.toString(16);
    });
    const shown = el('span', 'flag-value', '0x' + (Number(value) >>> 0).toString(16));
    labelRow.appendChild(document.createTextNode(' '));
    labelRow.appendChild(shown);
    wrap.appendChild(box);
  } else {
    // Six columns of spell_dbc are real floats (coefficients, missile speed);
    // stepping them by 1 and parsing them with parseInt would round 0.6 to 0.
    const isFloat = (CATALOG.float_columns || []).includes(col);
    const input = el('input', 'input');
    input.type = 'number';
    if (isFloat) input.step = 'any';
    input.value = value == null ? 0 : Number(value);
    input.addEventListener('input', () => setField(col,
      (isFloat ? parseFloat(input.value) : parseInt(input.value, 10)) || 0));
    wrap.appendChild(input);
  }
  return wrap;
}

function group(id, label, body, extraClass, hint) {
  const sec = el('section', 'fgroup ' + (extraClass || ''));
  const head = el('button', 'fgroup-head');
  head.type = 'button';
  const name = el('span', 'fgroup-name', label);
  if (hint) name.appendChild(helpBadge(hint));
  head.appendChild(name);
  head.appendChild(el('span', 'fgroup-mark', openGroups.has(id) ? '−' : '+'));
  const wrap = el('div', 'fgroup-body');
  if (!openGroups.has(id)) wrap.classList.add('hidden');
  head.addEventListener('click', () => {
    if (openGroups.has(id)) openGroups.delete(id); else openGroups.add(id);
    wrap.classList.toggle('hidden');
    head.querySelector('.fgroup-mark').textContent = openGroups.has(id) ? '−' : '+';
  });
  wrap.appendChild(body);
  sec.appendChild(head);
  sec.appendChild(wrap);
  return sec;
}

function renderEffects() {
  const box = el('div');
  for (const index of [1, 2, 3]) {
    const effectCol = 'Effect_' + index;
    const used = Number(current.fields[effectCol] || 0) !== 0;
    const card = el('div', 'effect' + (used ? ' used' : ''));

    const head = el('div', 'effect-head');
    head.appendChild(el('strong', null, 'Эффект ' + index));
    if (used) {
      head.appendChild(el('span', 'chip', enumLabel('effects', current.fields[effectCol])));
      const clear = el('button', 'btn ghost tiny', 'Очистить');
      clear.addEventListener('click', () => {
        for (const spec of CATALOG.effect_fields) {
          current.fields[spec.col.replace('%d', index)] = 0;
        }
        dirty = true;
        renderEditor();
      });
      head.appendChild(clear);
    }
    card.appendChild(head);

    const grid = el('div', 'field-grid');
    for (const spec of CATALOG.effect_fields) {
      const col = spec.col.replace('%d', index);
      // Keep the row short until an effect is actually chosen.
      const isCore = ['Effect_%d', 'EffectAura_%d', 'EffectBasePoints_%d',
                      'EffectMiscValue_%d', 'ImplicitTargetA_%d'].includes(spec.col);
      if (!used && !isCore) continue;
      grid.appendChild(renderField(spec, col));
    }
    card.appendChild(grid);
    box.appendChild(card);
  }
  return box;
}

// --- id pools -------------------------------------------------------------
// Every module owns a range of spell ids, and a new spell takes the first free
// one in it. Switching module therefore switches the id — so the editor asks
// the server for the number and shows it before anything is saved.

const blockById = id => (CATALOG.blocks || []).find(b => b.id === id);

const blocksOfModule = mod =>
  (CATALOG.blocks || []).filter(b => (b.module || '') === (mod || ''));

function moduleName(id) {
  if (!id) return '— без модуля —';
  const hit = (CATALOG.modules || []).find(m => m.id === id);
  return hit ? hit.name : id;
}

function blockLabel(b) {
  return `${b.name} · ${b.lo}-${b.hi} (занято ${b.used})`;
}

// Refresh one block's occupancy from the server and, while the spell is still
// a draft, move it onto that pool's first free id.
async function useBlock(blockId, opts) {
  const blk = blockById(blockId);
  if (!blk) return false;
  try {
    const st = await api('/api/spells/next-id?block=' + encodeURIComponent(blockId));
    blk.used = st.used;
    blk.next_free = st.id;
    if (creating) current.id = st.id;
  } catch (e) {
    toast(e.message, 'err');
    return false;
  }
  current.block = blockId;
  // Pools like «Мастерская» belong to no module, so picking one must not wipe
  // the module the operator chose.
  if (blk.module) current.module = blk.module;
  else if (opts && opts.module !== undefined) current.module = opts.module;
  dirty = true;
  return true;
}

// The module is the thing the operator actually thinks in, so it drives the
// pool: pick "Фамильяры" and the id jumps into the familiar range. A module
// with no range of its own falls back to the free workshop block.
async function chooseModule(moduleId) {
  current.module = moduleId;
  dirty = true;
  if (creating) {
    const mine = blocksOfModule(moduleId).filter(b => b.next_free !== null);
    if (mine.length) {
      if (!mine.some(b => b.id === current.block)) await useBlock(mine[0].id);
    } else {
      const blk = blockById(current.block);
      if (!blk || blk.module) await useBlock('workshop', { module: moduleId });
    }
  }
  renderEditor();
}

function renderPoolField() {
  const wrap = el('label', 'field');
  const label = el('span', 'field-label', 'Пул ID');
  label.appendChild(helpBadge(
    'Диапазон ID, из которого спелл получает номер. Пул привязан к модулю: ' +
    'смена модуля переносит спелл в его диапазон. Назначается первый ' +
    'свободный ID пула — у сохранённого спелла ID уже не меняется.'));
  wrap.appendChild(label);

  const note = el('div', 'muted');
  const blk = blockById(current.block);
  const describe = () => {
    const b = blockById(current.block);
    note.textContent = b
      ? `ID ${current.id} · занято ${b.used} из ${b.size} (${b.lo}-${b.hi})`
      : `ID ${current.id} · вне известных блоков`;
  };

  if (creating) {
    const sel = el('select', 'sel');
    for (const b of CATALOG.blocks) {
      const o = new Option(blockLabel(b), b.id);
      if (b.next_free === null) o.disabled = true;
      sel.appendChild(o);
    }
    if (!blk) sel.appendChild(new Option('вне блоков', current.block || ''));
    sel.value = current.block || '';
    sel.addEventListener('change', async () => {
      if (await useBlock(sel.value)) renderEditor();
      else sel.value = current.block || '';
    });
    wrap.appendChild(sel);
  } else {
    wrap.appendChild(el('div', 'input readonly',
      blk ? blk.name : 'вне известных блоков'));
  }
  describe();
  wrap.appendChild(note);
  return wrap;
}

function renderMeta() {
  const grid = el('div', 'field-grid');

  const mod = el('select', 'sel');
  const modules = (CATALOG.modules || []).map(m => m.id);
  for (const b of CATALOG.blocks) {
    if (b.module && !modules.includes(b.module)) modules.push(b.module);
  }
  mod.appendChild(new Option('— без модуля —', ''));
  for (const id of modules) mod.appendChild(new Option(moduleName(id), id));
  if (current.module && !modules.includes(current.module)) {
    mod.appendChild(new Option(current.module, current.module));
  }
  mod.value = current.module || '';
  mod.addEventListener('change', () => chooseModule(mod.value));
  const modWrap = el('label', 'field');
  const modLabel = el('span', 'field-label', 'Модуль');
  modLabel.appendChild(helpBadge(
    'Кому принадлежит спелл. По нему работает фильтр в списке и группировка ' +
    'при экспорте, а у нового спелла — ещё и выбор пула ID: модуль со своим ' +
    'диапазоном сразу выдаёт первый свободный номер из него. ' +
    'В spell_dbc поле не пишется.'));
  modWrap.appendChild(modLabel);
  modWrap.appendChild(mod);
  grid.appendChild(modWrap);

  grid.appendChild(renderPoolField());

  // Пустое поле — это «панель иконку не записывала», а не «иконки нет»:
  // спелл модуля рисуется по Spell_custom.csv / SpellIconID. Показываем то,
  // что реально видит клиент, но в поле не подставляем — иначе сохранение
  // записало бы чужой выбор как свой.
  const fallback = current.icon_resolved || '';
  const icon = el('input', 'input');
  icon.value = current.icon_texture || '';
  icon.placeholder = fallback ? `из клиента: ${fallback}`
                              : 'например spell_frost_frostward';
  const preview = iconImg(current.icon_texture || fallback, 'icon');
  const inherited = el('span', 'muted');
  const showInherited = () => {
    inherited.textContent = (!current.icon_texture && fallback)
      ? `иконка из клиента: ${fallback}` : '';
  };
  const setIcon = texture => {
    current.icon_texture = texture;
    icon.value = texture;
    preview.src = iconUrl(texture || fallback);
    preview.title = texture || fallback || 'иконка не задана';
    showInherited();
    dirty = true;
    markDirty();
  };
  icon.addEventListener('input', () => setIcon(icon.value.trim()));
  showInherited();

  const iconRow = el('div', 'icon-row');
  preview.addEventListener('click', () =>
    openIconPicker(current.icon_texture, setIcon));
  const browse = el('button', 'btn ghost', 'Выбрать…');
  browse.type = 'button';
  browse.addEventListener('click', ev => {
    ev.preventDefault();
    openIconPicker(current.icon_texture, setIcon);
  });
  iconRow.appendChild(preview);
  iconRow.appendChild(icon);
  iconRow.appendChild(browse);

  const iconWrap = el('label', 'field');
  const iconLabel = el('span', 'field-label', 'Иконка (клиент)');
  iconLabel.appendChild(helpBadge(
    'Имя текстуры Blizzard, например spell_frost_frostward — без пути и ' +
    'расширения. Настоящая иконка живёт в клиентском Spell.dbc: это поле ' +
    'попадёт туда через «Экспорт в клиент», после чего нужна пересборка MPQ.'));
  iconWrap.appendChild(iconLabel);
  iconWrap.appendChild(iconRow);
  iconWrap.appendChild(inherited);
  grid.appendChild(iconWrap);

  const notes = el('input', 'input');
  notes.value = current.notes || '';
  notes.addEventListener('input', () => { current.notes = notes.value; dirty = true; markDirty(); });
  const notesWrap = el('label', 'field');
  const notesLabel = el('span', 'field-label', 'Заметка');
  notesLabel.appendChild(helpBadge(
    'Свободный комментарий для себя: зачем спелл нужен, где используется. ' +
    'Виден в карточке спелла в каталоге.'));
  notesWrap.appendChild(notesLabel);
  notesWrap.appendChild(notes);
  grid.appendChild(notesWrap);

  return grid;
}

function renderProblems(problems) {
  const box = el('div', 'problems');
  for (const p of problems) {
    box.appendChild(el('div', 'problem ' + p.level, p.text));
  }
  return box;
}

function renderEditor(problems) {
  const root = document.getElementById('editor');
  root.innerHTML = '';
  if (!current) {
    root.appendChild(el('div', 'empty', 'Выберите спелл слева или создайте новый.'));
    return;
  }

  const head = el('div', 'zone-head');
  const title = el('h1', null, current.fields.Name_Lang_ruRU || 'Без названия');
  head.appendChild(title);
  head.appendChild(el('span', 'zid', '#' + current.id));
  const blk = CATALOG.blocks.find(b => b.id === current.block);
  if (blk) head.appendChild(el('span', 'chip', blk.name));
  if (current.clone_of) {
    const chip = el('span', 'chip src-override',
      `копия #${current.clone_of.id}` +
      (current.clone_of.name ? ` «${current.clone_of.name}»` : ''));
    chip.title = 'Все поля взяты у исходного спелла, кроме названия.';
    head.appendChild(chip);
  }
  root.appendChild(head);

  const actions = el('div', 'zone-actions');
  const save = el('button', 'btn primary', 'Сохранить');
  save.id = 'btn-save';
  save.addEventListener('click', () => saveSpell(false));
  actions.appendChild(save);

  if (!creating) {
    const copy = el('button', 'btn ghost', 'Копировать');
    copy.title = 'Создать новый спелл с этими же полями, кроме названия.';
    copy.addEventListener('click', () => cloneSpell(current.id));
    actions.appendChild(copy);

    const del = el('button', 'btn danger ghost', 'Удалить');
    del.addEventListener('click', deleteSpell);
    actions.appendChild(del);
  }
  actions.appendChild(el('span', 'muted',
    'spell_dbc читается при старте — после сохранения нужен рестарт PTR.'));
  root.appendChild(actions);

  if (problems && problems.length) root.appendChild(renderProblems(problems));

  root.appendChild(group('meta', 'Панель: модуль, иконка, заметка', renderMeta(),
    null, 'Служебные поля самой панели. В spell_dbc они не пишутся — лежат ' +
    'в схеме acore_admin и нужны, чтобы панель знала, чей это спелл и какую ' +
    'иконку он показывает в клиенте.'));
  root.appendChild(group('effects', 'Эффекты', renderEffects(), 'wide',
    'До трёх эффектов на спелл. Каждый — отдельное действие: урон, лечение, ' +
    'аура. Ядро читает эффект, только если у него задан Effect.'));

  for (const g of CATALOG.groups) {
    const grid = el('div', 'field-grid');
    for (const spec of g.fields) grid.appendChild(renderField(spec, spec.col));
    root.appendChild(group(g.id, g.label, grid, null, g.hint));
  }
  markDirty();
}

// --- list -----------------------------------------------------------------

function renderList() {
  const box = document.getElementById('spell-list');
  box.innerHTML = '';
  if (!list.length) {
    box.appendChild(el('div', 'col-empty', 'ничего не найдено'));
    return;
  }
  box.appendChild(el('div', 'muted', `${list.length} спеллов`));
  for (const s of list) {
    const row = el('div', 'zone-item' + (current && current.id === s.id ? ' active' : ''));
    row.appendChild(iconImg(s.icon_texture, 'icon list-icon'));
    const body = el('div', 'name');
    body.appendChild(el('div', null, s.name_ru || s.name_en || '(без имени)'));
    if (s.effects.length) {
      body.appendChild(el('div', 'spell-eff', s.effects.join(' · ')));
    }
    row.appendChild(body);
    row.appendChild(el('span', 'counts', '#' + s.id));
    row.addEventListener('click', () => openSpell(s.id));
    box.appendChild(row);
  }
}

async function load() {
  const p = new URLSearchParams();
  if (filters.block) p.set('block', filters.block);
  if (filters.q) p.set('q', filters.q);
  list = await api('/api/spells?' + p.toString());
  renderList();
}

async function openSpell(id) {
  if (dirty && !confirm('Есть несохранённые правки. Открыть другой спелл?')) return;
  try {
    current = await api('/api/spells/' + id);
    creating = false;
    dirty = false;
    renderEditor();
    renderList();
  } catch (e) {
    toast(e.message, 'err');
  }
}

async function newSpell() {
  const block = blockById(filters.block) ? filters.block : 'workshop';
  let st;
  try {
    st = await api('/api/spells/next-id?block=' + encodeURIComponent(block));
  } catch (e) {
    toast(e.message, 'err');
    return;
  }
  const blk = blockById(block);
  if (blk) { blk.used = st.used; blk.next_free = st.id; }
  const id = st.id;
  // Defaults that make a working aura on the first save: permanent duration,
  // the proc chance the modules use, self target, and NO_AURA_CANCEL.
  const fields = {};
  for (const g of CATALOG.groups) for (const f of g.fields) {
    fields[f.col] = f.kind === 'text' ? '' : 0;
  }
  for (const i of [1, 2, 3]) {
    for (const f of CATALOG.effect_fields) fields[f.col.replace('%d', i)] = 0;
  }
  Object.assign(fields, {
    DurationIndex: 21, ProcChance: 101, RangeIndex: 1, CastingTimeIndex: 1,
    EquippedItemClass: -1, SpellIconID: 1, SchoolMask: 1,
    Attributes: 0x80000000,
    Effect_1: APPLY_AURA, ImplicitTargetA_1: 1, EffectDieSides_1: 1,
  });
  current = {
    id, fields, module: (CATALOG.blocks.find(b => b.id === block) || {}).module || '',
    icon_texture: '', notes: '', block,
  };
  creating = true;
  dirty = true;
  renderEditor();
}

// --- clone ----------------------------------------------------------------
// "Make one like that." The server builds the draft — it is the only side that
// can read the client DBC, so a stock Blizzard spell is as copyable as one of
// ours. Nothing is written until the operator names it and presses save.

async function cloneSpell(sourceId, block) {
  if (dirty && !confirm('Есть несохранённые правки. Скопировать другой спелл?')) {
    return;
  }
  const target = block || filters.block || 'workshop';
  let draft;
  try {
    draft = await api('/api/spells/clone/' + sourceId
      + '?block=' + encodeURIComponent(target));
  } catch (e) {
    toast(e.message, 'err');
    return;
  }

  current = draft;
  creating = true;
  dirty = true;
  openGroups.add('text');
  renderEditor((draft.warnings || []).map(text => ({ level: 'warning', text })));
  renderList();
  const name = document.getElementById('f-name-ru');
  if (name) {
    name.scrollIntoView({ block: 'center' });
    name.focus();
  }
  toast(`Копия #${sourceId} → новый ID ${draft.id}. Задайте название и сохраните.`,
    'ok');
}

// Source picker. It searches the whole catalogue (all ~50 000 spells), not the
// workshop's own few hundred, because "как вон тот бладфьюри" is the usual
// starting point. Falls back to the workshop list when the DBC is not mounted.
async function openClonePicker() {
  const overlay = el('div', 'modal');
  const box = el('div', 'modal-box wide');

  const head = el('div', 'modal-head');
  head.appendChild(el('strong', null, 'Копировать спелл'));
  const search = el('input', 'input');
  search.placeholder = 'Название или ID: 133, огненный шар, blessing…';
  head.appendChild(search);
  const count = el('span', 'muted');
  head.appendChild(count);
  box.appendChild(head);

  const results = el('div', 'pick-list');
  box.appendChild(results);

  // The pool is picked before the copy, not after: it decides the id the draft
  // opens with, and the note spells that id out.
  const foot = el('div', 'modal-foot');
  foot.appendChild(el('span', 'muted', 'Копия попадёт в пул:'));
  const pool = el('select', 'sel');
  for (const b of CATALOG.blocks) {
    const o = new Option(blockLabel(b), b.id);
    if (b.next_free === null) o.disabled = true;
    pool.appendChild(o);
  }
  let target = filters.block || 'workshop';
  if (!blockById(target)) target = 'workshop';
  pool.value = target;
  foot.appendChild(pool);
  const poolNote = el('span', 'muted');
  const describePool = () => {
    const b = blockById(pool.value);
    poolNote.textContent = b
      ? `новый ID ${b.next_free} · ${moduleName(b.module)}`
      : '';
  };
  describePool();
  pool.addEventListener('change', describePool);
  foot.appendChild(poolNote);
  foot.appendChild(el('span', 'spacer'));
  const cancel = el('button', 'btn ghost', 'Отмена');
  foot.appendChild(cancel);
  box.appendChild(foot);

  overlay.appendChild(box);
  document.body.appendChild(overlay);

  const close = () => {
    overlay.remove();
    document.removeEventListener('keydown', onKey);
  };
  function onKey(ev) { if (ev.key === 'Escape') close(); }
  document.addEventListener('keydown', onKey);
  cancel.addEventListener('click', close);
  overlay.addEventListener('click', ev => { if (ev.target === overlay) close(); });

  let seq = 0;
  async function run() {
    const mine = ++seq;
    const q = search.value.trim();
    results.innerHTML = '';
    if (!q) {
      count.textContent = '';
      results.appendChild(el('div', 'col-empty', 'начните вводить название или ID'));
      return;
    }
    let items = [];
    try {
      const res = await api('/api/dex/search?limit=60&q=' + encodeURIComponent(q));
      items = res.items;
      if (mine === seq) count.textContent = `${res.total} найдено`;
    } catch (e) {
      // 503 = каталог не примонтирован; свои спеллы всё равно ищутся в БД.
      try {
        const own = await api('/api/spells?q=' + encodeURIComponent(q));
        items = own.map(s => ({ id: s.id, name: s.name_ru || s.name_en,
                                icon: s.icon_texture, rank: '', source: 'custom',
                                schools: [] }));
        if (mine === seq) count.textContent = 'только свои спеллы';
      } catch (e2) {
        if (mine === seq) results.appendChild(el('div', 'col-empty', e2.message));
        return;
      }
    }
    if (mine !== seq) return;
    if (!items.length) {
      results.appendChild(el('div', 'col-empty', 'ничего не найдено'));
      return;
    }
    for (const spell of items) {
      const row = el('button', 'pick-row');
      row.type = 'button';
      row.appendChild(iconImg(spell.icon, 'icon'));
      const body = el('div', 'pick-body');
      body.appendChild(el('div', 'pick-name',
        (spell.name || '(без названия)') + (spell.rank ? ` (${spell.rank})` : '')));
      const meta = [];
      if (spell.schools && spell.schools.length) meta.push(spell.schools.join(', '));
      if (spell.family_name) meta.push(spell.family_name);
      if (spell.level) meta.push('ур. ' + spell.level);
      body.appendChild(el('div', 'pick-meta', meta.join(' · ')));
      row.appendChild(body);
      row.appendChild(el('span', 'counts', '#' + spell.id));
      row.addEventListener('click', () => { close(); cloneSpell(spell.id, pool.value); });
      results.appendChild(row);
    }
  }

  search.addEventListener('input', debounce(run, 250));
  search.addEventListener('keydown', ev => {
    if (ev.key === 'Enter') { ev.preventDefault(); run(); }
  });
  run();
  search.focus();
}

// Occupancy after a write, so the "следующий свободный" line and the pool
// selects do not keep quoting the id that was just taken.
async function refreshBlock(blockId) {
  const blk = blockById(blockId);
  if (!blk) return;
  try {
    const st = await api('/api/spells/next-id?block=' + encodeURIComponent(blockId));
    blk.used = st.used;
    blk.next_free = st.id;
  } catch (e) {
    // Пул заполнен или сеть отвалилась — старые числа честнее выдуманных.
  }
  renderBlocks();
}

async function saveSpell(force) {
  const payload = {
    id: current.id, block: current.block, module: current.module,
    icon_texture: current.icon_texture, notes: current.notes,
    fields: current.fields,
  };
  const path = (creating ? '/api/spells' : '/api/spells/' + current.id)
    + (force ? '?force=true' : '');
  try {
    const res = await api(path, {
      method: creating ? 'POST' : 'PUT',
      body: JSON.stringify(payload),
    });
    creating = false;
    dirty = false;
    toast('Сохранено. Нужен рестарт PTR, чтобы спелл заработал.', 'ok');
    await refreshBlock(current.block);
    await load();
    await openSpell(res.id);
    if (res.problems && res.problems.length) renderEditor(res.problems);
    refreshRestart();
  } catch (e) {
    const payloadErr = e.payload;
    if (payloadErr && payloadErr.problems) {
      renderEditor(payloadErr.problems);
      const errors = payloadErr.problems.filter(p => p.level === 'error');
      if (errors.length && confirm(
        'Ошибки:\n' + errors.map(p => '• ' + p.text).join('\n') +
        '\n\nСохранить всё равно?')) {
        return saveSpell(true);
      }
      toast(payloadErr.detail || 'Не сохранено', 'err');
    } else {
      toast(e.message, 'err');
    }
  }
}

async function deleteSpell() {
  if (!confirm(`Удалить спелл #${current.id} из spell_dbc?`)) return;
  try {
    await api('/api/spells/' + current.id, { method: 'DELETE' });
    current = null;
    dirty = false;
    await load();
    renderEditor();
    toast('Удалено.', 'ok');
  } catch (e) {
    toast(e.message, 'err');
  }
}

// --- header ---------------------------------------------------------------

async function refreshRestart() {
  const box = document.getElementById('restart');
  box.innerHTML = '';
  try {
    const st = await api('/api/spells/pending-restart');
    if (!st.known) {
      box.appendChild(el('span', 'bad', 'аптайм PTR неизвестен'));
      box.title = st.reason || '';
    } else if (st.count) {
      const s = el('span', 'bad', `ждут рестарта: ${st.count}`);
      s.title = 'Спеллы записаны после старта worldserver, в игре их ещё нет.';
      box.appendChild(s);
    } else {
      box.appendChild(el('span', 'good', 'всё применено'));
    }
  } catch (e) {
    box.appendChild(el('span', 'bad', 'нет связи'));
  }
}

function renderBlocks() {
  const sel = document.getElementById('f-block');
  sel.innerHTML = '';
  sel.appendChild(new Option('Все блоки', ''));
  for (const b of CATALOG.blocks) {
    sel.appendChild(new Option(`${b.name} (${b.used})`, b.id));
  }
  sel.value = filters.block;
  const usage = document.getElementById('block-usage');
  const blk = CATALOG.blocks.find(b => b.id === filters.block);
  usage.textContent = blk
    ? `${blk.lo}-${blk.hi}, занято ${blk.used} из ${blk.size}, следующий свободный ${blk.next_free}`
    : 'Выберите блок, чтобы видеть занятость ID.';
}

function debounce(fn, ms) {
  let t = null;
  return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
}

async function init() {
  CATALOG = await api('/api/spells/catalog');
  renderBlocks();

  // Needed before the first icon preview renders, not just when the picker
  // opens; /api/health carries it and is cheap.
  try {
    ICON_BASE = (await api('/api/health')).icon_base_url || '';
  } catch (e) { /* previews fall back to the blank icon */ }

  document.getElementById('f-block').addEventListener('change', async e => {
    filters.block = e.target.value;
    renderBlocks();
    await load();
  });
  document.getElementById('q').addEventListener('input', debounce(async e => {
    filters.q = e.target.value.trim();
    await load();
  }, 250));
  document.getElementById('btn-new').addEventListener('click', newSpell);
  document.getElementById('btn-clone').addEventListener('click', openClonePicker);

  document.getElementById('btn-export-sql').addEventListener('click', async () => {
    try {
      const r = await api('/api/spells/export/sql', { method: 'POST' });
      toast(`Выгружено спеллов: ${r.spells} → ${r.path}`, 'ok');
    } catch (e) { toast(e.message, 'err'); }
  });
  document.getElementById('btn-export-client').addEventListener('click', async () => {
    try {
      const r = await api('/api/spells/export/client', { method: 'POST' });
      toast(`Строк в Spell_custom.csv: ${r.written}. Пересоберите MPQ.`, 'ok');
    } catch (e) { toast(e.message, 'err'); }
  });

  window.addEventListener('beforeunload', e => {
    if (dirty) { e.preventDefault(); e.returnValue = ''; }
  });

  await load();
  refreshRestart();

  // Entry points from the catalogue: ?clone=<id> copies that spell into a
  // draft, #<id> just opens ours for editing.
  const params = new URLSearchParams(location.search);
  const clone = parseInt(params.get('clone'), 10);
  const open = parseInt(location.hash.slice(1), 10);
  if (Number.isFinite(clone)) {
    history.replaceState(null, '', location.pathname);
    await cloneSpell(clone, params.get('block') || undefined);
  } else if (Number.isFinite(open)) {
    await openSpell(open);
  }
}

init().catch(e => toast(e.message, 'err'));
