'use strict';

// Spell catalogue: search on the left, results in the middle, one spell's
// parameters on the right. Everything is read-only — the panel's writes go
// through the workshop (/spells.html), and this page links there instead of
// growing its own save path.
//
// The server does the decoding (enum labels, durations, flag names), so this
// file only lays things out. That keeps the "what does field X mean" knowledge
// in one place, next to the enums it comes from.

let META = null;
let filters = { q: '', source: '', school: '', family: '', effect: '', aura: '',
                level_min: '', level_max: '', module: '', block: '' };
let page = { offset: 0, limit: 100, total: 0 };
let current = null;
let seq = 0;                 // guards against out-of-order search responses

const PLACEHOLDER =
  'data:image/svg+xml;utf8,' + encodeURIComponent(
    "<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40'>" +
    "<rect width='40' height='40' fill='%230a0c0f'/>" +
    "<path d='M8 32 20 10l12 22z' fill='none' stroke='%234a4133' stroke-width='2'/>" +
    '</svg>');

// Local PNGs win when the icons have been extracted from the client, but the
// choice is made once from META (`local_icons`) rather than by letting every
// one of a hundred rows 404 on a directory that usually does not exist.
function iconUrl(texture) {
  if (!texture) return PLACEHOLDER;
  if (META && META.local_icons) return '/static/icons/' + texture + '.png';
  if (META && META.icon_base_url) return META.icon_base_url + '/' + texture + '.jpg';
  return PLACEHOLDER;
}

function iconImg(texture, cls) {
  const img = el('img', cls || 'dex-icon');
  img.loading = 'lazy';
  img.src = iconUrl(texture);
  img.alt = '';
  img.addEventListener('error', () => { img.src = PLACEHOLDER; }, { once: true });
  return img;
}

const SOURCE_CLASS = { dbc: 'src-dbc', override: 'src-override', custom: 'src-custom' };
const SOURCE_SHORT = { dbc: 'DBC', override: 'изменён', custom: 'добавлен' };

// --- filters --------------------------------------------------------------

function fillSelect(id, items, allLabel) {
  const sel = document.getElementById(id);
  sel.innerHTML = '';
  sel.appendChild(new Option(allLabel, ''));
  for (const item of items) {
    const label = item.count === undefined
      ? item.label : `${item.label} (${item.count})`;
    sel.appendChild(new Option(label, String(item.id)));
  }
}

// --- module / id pool -----------------------------------------------------
// The workshop hands every module a range of spell ids, so "чьё это" and "в
// каком диапазоне" are the same question. The module select picks the union of
// a module's ranges; the pool select narrows to one of them.

const blocksOfModule = mod =>
  (META.blocks || []).filter(b => !mod || b.module === mod);

function fillBlockFilter() {
  const sel = document.getElementById('f-block');
  const keep = sel.value;
  const mine = blocksOfModule(filters.module);
  sel.innerHTML = '';
  if (filters.module) {
    const total = mine.reduce((sum, b) => sum + b.used, 0);
    sel.appendChild(new Option(`Все пулы модуля (${total})`, ''));
  } else {
    sel.appendChild(new Option('Любой пул', ''));
    sel.appendChild(new Option(
      `Все кастомные блоки (${META.block_total})`, META.any_block));
  }
  for (const b of mine) {
    sel.appendChild(new Option(`${b.name} (${b.used})`, b.id));
  }
  sel.value = Array.from(sel.options).some(o => o.value === keep) ? keep : '';
  filters.block = sel.value;
  describeBlock();
}

function describeBlock() {
  const note = document.getElementById('block-range');
  const blk = (META.blocks || []).find(b => b.id === filters.block);
  if (blk) {
    note.textContent = `${blk.lo}-${blk.hi}, занято ${blk.used} из ${blk.size}`;
    return;
  }
  const mine = filters.block === META.any_block
    ? (META.blocks || []) : blocksOfModule(filters.module);
  note.textContent = filters.module || filters.block
    ? mine.map(b => `${b.lo}-${b.hi}`).join(', ')
    : '';
}

function readFilters() {
  filters.q = document.getElementById('q').value.trim();
  filters.module = document.getElementById('f-module').value;
  filters.block = document.getElementById('f-block').value;
  filters.source = document.getElementById('f-source').value;
  filters.school = document.getElementById('f-school').value;
  filters.family = document.getElementById('f-family').value;
  filters.effect = document.getElementById('f-effect').value;
  filters.aura = document.getElementById('f-aura').value;
  filters.level_min = document.getElementById('f-lvl-min').value;
  filters.level_max = document.getElementById('f-lvl-max').value;
}

function query(offset) {
  const p = new URLSearchParams();
  if (filters.q) p.set('q', filters.q);
  // A chosen pool is the narrower of the two, and the pool list is already
  // scoped to the module — sending both would only repeat the same range.
  if (filters.block) p.set('block', filters.block);
  else if (filters.module) p.set('module', filters.module);
  if (filters.source) p.set('source', filters.source);
  if (filters.school) p.set('school', filters.school);
  if (filters.family) p.set('family', filters.family);
  if (filters.effect) p.set('effect', filters.effect);
  if (filters.aura) p.set('aura', filters.aura);
  if (filters.level_min) p.set('level_min', filters.level_min);
  if (filters.level_max) p.set('level_max', filters.level_max);
  p.set('offset', String(offset));
  p.set('limit', String(page.limit));
  return p.toString();
}

// --- results --------------------------------------------------------------

function renderRow(spell) {
  const row = el('div', 'dex-row' + (current === spell.id ? ' active' : ''));
  row.dataset.id = String(spell.id);
  row.appendChild(iconImg(spell.icon));

  const body = el('div', 'dex-row-body');
  const title = el('div', 'dex-row-title');
  title.appendChild(el('span', 'dex-name', spell.name));
  if (spell.rank) title.appendChild(el('span', 'dex-rank', spell.rank));
  body.appendChild(title);

  const meta = el('div', 'dex-row-meta');
  meta.appendChild(el('span', 'dex-id', '#' + spell.id));
  if (spell.schools.length) {
    meta.appendChild(el('span', 'dex-school', spell.schools.join(', ')));
  }
  if (spell.family) meta.appendChild(el('span', null, spell.family_name));
  if (spell.level) meta.appendChild(el('span', null, 'ур. ' + spell.level));
  body.appendChild(meta);
  row.appendChild(body);

  if (spell.source !== 'dbc') {
    row.appendChild(el('span', 'chip ' + SOURCE_CLASS[spell.source],
      SOURCE_SHORT[spell.source]));
  }
  row.addEventListener('click', () => openSpell(spell.id));
  return row;
}

function renderPager() {
  const box = document.getElementById('pager');
  box.innerHTML = '';
  if (!page.total) return;
  const from = page.offset + 1;
  const to = Math.min(page.offset + page.limit, page.total);
  box.appendChild(el('span', 'muted', `${from}–${to} из ${page.total}`));

  const prev = el('button', 'btn ghost tiny', '← назад');
  prev.disabled = page.offset === 0;
  prev.addEventListener('click', () => load(Math.max(0, page.offset - page.limit)));
  const next = el('button', 'btn ghost tiny', 'вперёд →');
  next.disabled = page.offset + page.limit >= page.total;
  next.addEventListener('click', () => load(page.offset + page.limit));
  box.appendChild(prev);
  box.appendChild(next);
}

async function load(offset) {
  readFilters();
  const mine = ++seq;
  const box = document.getElementById('results');
  try {
    const res = await api('/api/dex/search?' + query(offset || 0));
    if (mine !== seq) return;           // a newer keystroke already won
    page.offset = res.offset;
    page.total = res.total;
    box.innerHTML = '';
    if (!res.items.length) {
      box.appendChild(el('div', 'empty', 'Ничего не найдено.'));
    } else {
      for (const spell of res.items) box.appendChild(renderRow(spell));
    }
    renderPager();
  } catch (e) {
    if (mine !== seq) return;
    box.innerHTML = '';
    box.appendChild(el('div', 'empty', e.message));
  }
}

// --- detail ---------------------------------------------------------------

function kvTable(pairs) {
  const table = el('div', 'kv');
  for (const pair of pairs) {
    if (pair.value === '' || pair.value === '—' || pair.value === null) continue;
    const line = el('div', 'kv-row');
    line.appendChild(el('span', 'kv-key', pair.label));
    line.appendChild(el('span', 'kv-val', String(pair.value)));
    if (pair.raw !== null && pair.raw !== undefined && String(pair.raw) !== String(pair.value)) {
      line.title = pair.label + ' = ' + pair.raw;
    }
    table.appendChild(line);
  }
  return table;
}

function section(title, body, collapsed) {
  const box = el('section', 'dex-section');
  const head = el('button', 'dex-section-head');
  head.type = 'button';
  head.appendChild(el('span', null, title));
  head.appendChild(el('span', 'dex-section-mark', collapsed ? '+' : '−'));
  const wrap = el('div', 'dex-section-body');
  if (collapsed) wrap.classList.add('hidden');
  head.addEventListener('click', () => {
    const hidden = wrap.classList.toggle('hidden');
    head.querySelector('.dex-section-mark').textContent = hidden ? '+' : '−';
  });
  wrap.appendChild(body);
  box.appendChild(head);
  box.appendChild(wrap);
  return box;
}

function renderEffects(effects) {
  const box = el('div', 'dex-effects');
  for (const effect of effects) {
    const card = el('div', 'dex-effect');
    const head = el('div', 'dex-effect-head');
    head.appendChild(el('span', 'dex-effect-index', 'Эффект ' + effect.index));
    head.appendChild(el('strong', null, effect.effect_name));
    if (effect.aura_name) {
      head.appendChild(el('span', 'chip', effect.aura_name));
    }
    card.appendChild(head);

    const pairs = [
      { label: 'Величина', value: effect.amount },
      { label: 'Период', value: effect.period },
      { label: 'Цель', value: effect.target_a },
      { label: 'Цель B', value: effect.target_b !== 'None' ? effect.target_b : '' },
      { label: 'Радиус', value: effect.radius },
      { label: 'Механика', value: effect.mechanic !== 'None' ? effect.mechanic : '' },
      { label: 'Misc', value: effect.misc || '' },
      { label: 'Misc B', value: effect.misc_b || '' },
      { label: 'Цепь', value: effect.chain || '' },
      { label: 'Предмет', value: effect.item_type || '' },
    ];
    card.appendChild(kvTable(pairs));

    if (effect.trigger) {
      const line = el('div', 'dex-trigger');
      line.appendChild(el('span', 'kv-key', 'Триггерит'));
      const link = el('a', 'dex-link', `${effect.trigger_name || 'спелл'} #${effect.trigger}`);
      link.href = '#' + effect.trigger;
      link.addEventListener('click', ev => { ev.preventDefault(); openSpell(effect.trigger); });
      line.appendChild(link);
      card.appendChild(line);
    }
    box.appendChild(card);
  }
  return box;
}

function renderAttributes(groups) {
  const box = el('div', 'dex-attrs');
  for (const group of groups) {
    const card = el('div', 'dex-attr-group');
    const head = el('div', 'dex-attr-head');
    head.appendChild(el('span', 'kv-key', group.column));
    head.appendChild(el('code', null, group.hex));
    card.appendChild(head);
    const list = el('div', 'dex-flags');
    for (const flag of group.flags) {
      const chip = el('span', 'chip', flag.label);
      chip.title = `${flag.const} = 0x${flag.bit.toString(16)}`;
      list.appendChild(chip);
    }
    card.appendChild(list);
    box.appendChild(card);
  }
  return box;
}

function renderOverrides(rows) {
  const table = el('div', 'kv');
  for (const row of rows) {
    const line = el('div', 'kv-row');
    line.appendChild(el('span', 'kv-key', row.column));
    const val = el('span', 'kv-val');
    val.appendChild(el('span', 'dex-was', String(row.dbc)));
    val.appendChild(el('span', 'dex-arrow', ' → '));
    val.appendChild(el('span', 'dex-now', String(row.db)));
    line.appendChild(val);
    table.appendChild(line);
  }
  return table;
}

function renderRaw(raw) {
  const table = el('div', 'kv kv-dense');
  for (const key of Object.keys(raw).sort()) {
    const value = raw[key];
    if (value === 0 || value === '' || value === null) continue;
    const line = el('div', 'kv-row');
    line.appendChild(el('span', 'kv-key', key));
    line.appendChild(el('span', 'kv-val', String(value)));
    table.appendChild(line);
  }
  return table;
}

function renderSkills(skills) {
  const box = el('div', 'dex-chips');
  for (const skill of skills.slice(0, 24)) {
    const chip = el('span', 'chip', skill.skill || ('умение ' + skill.skill_id));
    chip.title = `skill ${skill.skill_id}, classmask 0x${(skill.class_mask >>> 0).toString(16)}`
      + (skill.min_rank ? `, ранг ${skill.min_rank}` : '');
    box.appendChild(chip);
  }
  return box;
}

function renderDetail(spell) {
  const root = document.getElementById('detail');
  root.innerHTML = '';

  const head = el('div', 'dex-head');
  head.appendChild(iconImg(spell.icon, 'dex-icon big'));
  const titles = el('div', 'dex-head-text');
  const h1 = el('h1', null, spell.name);
  titles.appendChild(h1);
  const sub = el('div', 'dex-head-meta');
  sub.appendChild(el('span', 'dex-id', '#' + spell.id));
  if (spell.rank) sub.appendChild(el('span', 'dex-rank', spell.rank));
  if (spell.name_en && spell.name_en !== spell.name) {
    sub.appendChild(el('span', 'muted', spell.name_en));
  }
  sub.appendChild(el('span', 'chip ' + SOURCE_CLASS[spell.source], spell.source_label));
  // The pool chip doubles as "покажи всё из этого же пула" — the same filter
  // the sidebar offers, one click away from a spell you already found.
  if (spell.block_name) {
    const chip = el('button', 'chip', spell.block_name);
    chip.type = 'button';
    chip.title = 'Показать весь пул ID';
    chip.addEventListener('click', () => {
      document.getElementById('f-module').value =
        (META.modules || []).some(m => m.id === spell.module) ? spell.module : '';
      filters.module = document.getElementById('f-module').value;
      fillBlockFilter();
      document.getElementById('f-block').value = spell.block;
      filters.block = spell.block;
      describeBlock();
      load(0);
    });
    sub.appendChild(chip);
  }
  if (spell.module) sub.appendChild(el('span', 'chip', spell.module));
  titles.appendChild(sub);
  head.appendChild(titles);
  root.appendChild(head);

  if (spell.description) {
    root.appendChild(el('p', 'dex-desc', spell.description));
  }
  if (spell.aura_description) {
    root.appendChild(el('p', 'dex-desc aura', spell.aura_description));
  }
  if (spell.notes) root.appendChild(el('p', 'dex-note', spell.notes));

  const actions = el('div', 'dex-actions');
  if (spell.editable) {
    const edit = el('a', 'btn ghost', 'Открыть в мастерской');
    edit.href = '/spells.html#' + spell.id;
    actions.appendChild(edit);
  }
  // Works for stock Blizzard spells too: the copy lands in the workshop's own
  // ID block, so nothing here is ever overwritten.
  const copy = el('a', 'btn ghost', 'Копировать в мастерскую');
  copy.href = '/spells.html?clone=' + spell.id;
  copy.title = 'Новый спелл со всеми полями этого, кроме названия.';
  actions.appendChild(copy);
  const iconName = el('span', 'muted',
    spell.icon ? `иконка: ${spell.icon} (id ${spell.icon_id})`
               : `иконка не задана (id ${spell.icon_id})`);
  actions.appendChild(iconName);
  root.appendChild(actions);

  root.appendChild(section('Параметры', kvTable(spell.summary)));
  if (spell.effects.length) {
    root.appendChild(section('Эффекты', renderEffects(spell.effects)));
  }
  if (spell.overrides.length) {
    root.appendChild(section(
      `Что меняет spell_dbc (${spell.overrides.length})`,
      renderOverrides(spell.overrides)));
  }
  if (spell.attributes.length) {
    root.appendChild(section('Атрибуты', renderAttributes(spell.attributes), true));
  }
  if (spell.skills.length) {
    root.appendChild(section('Умения', renderSkills(spell.skills), true));
  }
  if (spell.triggered_by.length) {
    const box = el('div', 'dex-chips');
    for (const caster of spell.triggered_by) {
      const chip = el('a', 'chip', `${caster.name || 'спелл'} #${caster.id}`);
      chip.href = '#' + caster.id;
      chip.addEventListener('click', ev => { ev.preventDefault(); openSpell(caster.id); });
      box.appendChild(chip);
    }
    root.appendChild(section('Кто его накладывает', box, true));
  }
  root.appendChild(section('Все поля', renderRaw(spell.raw), true));
  root.scrollTop = 0;
}

async function openSpell(id) {
  try {
    const spell = await api('/api/dex/spells/' + id);
    current = id;
    renderDetail(spell);
    location.hash = String(id);
    for (const row of document.querySelectorAll('.dex-row')) {
      row.classList.toggle('active', row.dataset.id === String(id));
    }
  } catch (e) {
    toast(e.message, 'err');
  }
}

// --- init -----------------------------------------------------------------

function debounce(fn, ms) {
  let timer = null;
  return (...args) => { clearTimeout(timer); timer = setTimeout(() => fn(...args), ms); };
}

async function init() {
  META = await api('/api/dex/meta');
  if (!META.available) {
    document.getElementById('results').innerHTML = '';
    document.getElementById('results').appendChild(
      el('div', 'empty', META.reason));
    return;
  }

  document.getElementById('dex-stats').appendChild(
    el('span', null, `${META.total} спеллов`));
  document.getElementById('dex-hint').textContent =
    `DBC: ${META.dbc_dir}. Каталог только читает — правки идут через мастерскую.`;

  fillSelect('f-module', META.modules, 'Любой модуль');
  fillBlockFilter();
  fillSelect('f-source', META.sources, 'Любой источник');
  fillSelect('f-school', META.schools, 'Любая школа');
  fillSelect('f-family', META.families, 'Любое семейство');
  fillSelect('f-effect', META.effects, 'Любой эффект');
  fillSelect('f-aura', META.auras, 'Любая аура');

  const rerun = () => load(0);
  document.getElementById('q').addEventListener('input', debounce(rerun, 250));
  for (const id of ['f-source', 'f-school', 'f-family', 'f-effect', 'f-aura']) {
    document.getElementById(id).addEventListener('change', rerun);
  }
  // Picking a module rebuilds the pool list, because the pools on offer are
  // exactly that module's ranges.
  document.getElementById('f-module').addEventListener('change', e => {
    filters.module = e.target.value;
    fillBlockFilter();
    load(0);
  });
  document.getElementById('f-block').addEventListener('change', e => {
    filters.block = e.target.value;
    describeBlock();
    load(0);
  });
  for (const id of ['f-lvl-min', 'f-lvl-max']) {
    document.getElementById(id).addEventListener('input', debounce(rerun, 400));
  }
  document.getElementById('btn-reset').addEventListener('click', () => {
    for (const id of ['q', 'f-lvl-min', 'f-lvl-max']) {
      document.getElementById(id).value = '';
    }
    for (const id of ['f-source', 'f-school', 'f-family', 'f-effect', 'f-aura',
                      'f-module', 'f-block']) {
      document.getElementById(id).value = '';
    }
    filters.module = '';
    filters.block = '';
    fillBlockFilter();
    load(0);
  });

  window.addEventListener('hashchange', () => {
    const id = parseInt(location.hash.slice(1), 10);
    if (Number.isFinite(id) && id !== current) openSpell(id);
  });

  await load(0);
  const initial = parseInt(location.hash.slice(1), 10);
  if (Number.isFinite(initial)) openSpell(initial);
}

init().catch(e => toast(e.message, 'err'));
