'use strict';

// Zone-rule editor for mod-environmental-effects. Shared helpers (api, el,
// toast, the token prompt) live in common.js.

let ICON_BASE = '';

// 4-7 ядро само не генерирует - только ручная команда (RemoteControlUI).
// У каждой погоды РОВНО ОДИН триггер: гроза - это не дождь, а чёрный снег -
// не снег. Чего у зоны нет, то берётся из глобального пула (zone_id 0).
const TRIGGERS = [[0, 'Всегда'], [1, 'Дождь'], [2, 'Снег'], [3, 'Песчаная буря'],
                  [4, 'Туман'], [5, 'Гроза'], [6, 'Чёрный дождь'], [7, 'Чёрный снег']];
const TIMES = [[0, 'Любое время'], [1, 'Только днём'], [2, 'Только ночью']];

// zone_id 0 - не зона, а пул умолчаний: подставляется по корзинам (постоянные
// дебаффы / конкретная погода / баффы текущего времени суток) тем зонам, у
// которых своего правила в этой корзине нет.
const GLOBAL_ZONE = 0;

let zones = [];
let spells = [];
let current = null;   // { zone_id, name, buffs: [], debuffs: [] }
let dirty = false;

// --- helpers --------------------------------------------------------------

// 1x1 transparent GIF — shown when a texture has no local PNG and the remote
// icon host is unavailable, so the layout never breaks on a missing icon.
const BLANK_ICON = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

// A local app/static/icons/<texture>.png always wins; ICON_BASE (Blizzard icon
// names on a public CDN) is the fallback until the icons are extracted locally.
function iconImg(texture, cls) {
  const img = el('img', cls);
  img.alt = '';
  img.title = texture || 'иконка не задана';
  if (!texture) { img.src = BLANK_ICON; return img; }
  const remote = ICON_BASE ? `${ICON_BASE}/${texture}.jpg` : null;
  img.src = `/static/icons/${texture}.png`;
  img.addEventListener('error', function onErr() {
    img.removeEventListener('error', onErr);
    if (remote) {
      img.src = remote;
      img.addEventListener('error', () => { img.src = BLANK_ICON; }, { once: true });
    } else {
      img.src = BLANK_ICON;
    }
  });
  return img;
}

function select(options, value, onChange) {
  const s = el('select');
  for (const [v, label] of options) {
    const o = el('option', null, label);
    o.value = String(v);
    if (Number(value) === v) o.selected = true;
    s.appendChild(o);
  }
  s.addEventListener('change', () => onChange(Number(s.value)));
  return s;
}

// --- health ---------------------------------------------------------------

async function loadHealth() {
  const box = document.getElementById('health');
  box.innerHTML = '';
  try {
    const h = await api('/api/health');
    ICON_BASE = h.icon_base_url || '';
    const add = (label, ok, title) => {
      const s = el('span', ok ? 'good' : 'bad', label);
      if (title) s.title = title;
      box.appendChild(s);
    };
    add(h.schema, h.db && h.db.ok, h.db && h.db.error);
    add(`правил: ${h.db && h.db.ok ? h.db.rules : '?'}`, h.db && h.db.ok);
    add(h.soap.ok ? 'SOAP' : 'SOAP ✕', h.soap.ok, h.soap.error);
    add(h.files_ok ? 'файлы' : 'файлы ✕', h.files_ok,
        h.files_ok ? h.export_path : (h.file_problems || []).join('\n'));
    if (!h.files_ok && (h.file_problems || []).length)
      toast(h.file_problems.join(' · '), 'err');
  } catch (e) {
    box.appendChild(el('span', 'bad', 'нет связи с API'));
  }
}

// --- zone list ------------------------------------------------------------

async function loadZones() {
  zones = await api('/api/zones');
  // Глобальный пул есть в списке всегда, даже когда в нём ещё ноль правил, -
  // иначе его нечем было бы завести.
  if (!zones.some(z => z.zone_id === GLOBAL_ZONE)) {
    zones.unshift({ zone_id: GLOBAL_ZONE, name: 'Глобальные правила',
                    global: true, buffs: 0, debuffs: 0, disabled: 0 });
  }
  renderZoneList();
}

function renderZoneList() {
  const filter = document.getElementById('zone-filter').value.trim().toLowerCase();
  const list = document.getElementById('zone-list');
  list.innerHTML = '';
  for (const z of zones) {
    // Глобальный пул из фильтра не выпадает: он влияет на любую зону, которую
    // сейчас ищут, и прятать его под поиском вредно.
    if (filter && !z.global && !z.name.toLowerCase().includes(filter)
        && String(z.zone_id) !== filter) continue;
    const item = el('div', 'zone-item' + (z.global ? ' global' : '')
      + (current && current.zone_id === z.zone_id ? ' active' : ''));
    item.appendChild(el('span', 'name', z.name));
    const counts = el('span', 'counts', `${z.buffs}/${z.debuffs}`);
    counts.title = `баффов: ${z.buffs}, дебаффов: ${z.debuffs}` +
      (z.disabled ? `, выключено: ${z.disabled}` : '');
    item.appendChild(counts);
    item.addEventListener('click', () => openZone(z.zone_id));
    list.appendChild(item);
  }
}

// --- zone add -------------------------------------------------------------

let addTimer = null;
function setupZoneAdd() {
  const input = document.getElementById('zone-add');
  const results = document.getElementById('zone-add-results');
  input.addEventListener('input', () => {
    clearTimeout(addTimer);
    const q = input.value.trim();
    if (!q) { results.classList.remove('show'); return; }
    addTimer = setTimeout(async () => {
      const hits = await api('/api/zones/search?q=' + encodeURIComponent(q));
      results.innerHTML = '';
      for (const h of hits) {
        const row = el('div', null, `${h.name} — ${h.zone_id}`);
        row.addEventListener('click', () => {
          results.classList.remove('show');
          input.value = '';
          openZone(h.zone_id);
        });
        results.appendChild(row);
      }
      results.classList.toggle('show', hits.length > 0);
    }, 200);
  });
  document.addEventListener('click', (e) => {
    if (!results.contains(e.target) && e.target !== input) results.classList.remove('show');
  });
}

// --- editor ---------------------------------------------------------------

async function openZone(zoneId) {
  if (dirty && !confirm('Несохранённые изменения будут потеряны. Продолжить?')) return;
  current = await api('/api/zones/' + zoneId);
  dirty = false;
  renderZoneList();
  renderEditor();
}

function markDirty() {
  dirty = true;
  const btn = document.getElementById('btn-save');
  if (btn) { btn.disabled = false; btn.textContent = 'Применить на PTR'; }
}

function renderEditor(problems) {
  const root = document.getElementById('editor');
  root.innerHTML = '';
  if (!current) { root.appendChild(el('div', 'empty', 'Выберите зону слева.')); return; }

  const isGlobal = current.zone_id === GLOBAL_ZONE;

  const head = el('div', 'zone-head');
  head.appendChild(el('h1', null, current.name));
  head.appendChild(el('span', 'zid', isGlobal ? 'zone_id 0 — все зоны'
                                             : 'zone_id ' + current.zone_id));
  root.appendChild(head);

  root.appendChild(el('div', 'hint', isGlobal
    ? 'Умолчания для всех зон таблицы. Подставляются по корзинам: если у зоны '
      + 'нет ни одного своего правила на этот эффект (постоянный дебафф, дождь, '
      + 'снег, гроза…) или ни одного баффа для текущего времени суток — берётся '
      + 'отсюда. Свой пул зоны глобальный не дополняет, а полностью перебивает. '
      + 'Зоне без единой своей строки глобальные правила не выдаются.'
    : 'Свои правила зоны важнее глобальных. Корзина, которая здесь пуста '
      + '(например «Гроза»), берётся из глобального пула.'));

  const actions = el('div', 'zone-actions');
  const save = el('button', 'btn primary', 'Применить на PTR');
  save.id = 'btn-save';
  save.disabled = !dirty;
  save.addEventListener('click', () => saveZone(false));
  actions.appendChild(save);

  const del = el('button', 'btn danger',
    isGlobal ? 'Удалить все глобальные правила' : 'Удалить все правила зоны');
  del.addEventListener('click', async () => {
    if (!confirm(isGlobal
      ? 'Удалить все глобальные правила? Зоны останутся только со своими.'
      : `Удалить все правила зоны «${current.name}»?`)) return;
    await api('/api/zones/' + current.zone_id, { method: 'DELETE' });
    await api('/api/reload', { method: 'POST' }).catch(() => {});
    toast(isGlobal ? 'Глобальные правила удалены' : 'Правила зоны удалены', 'ok');
    current = null; dirty = false;
    await loadZones(); await loadHealth(); renderEditor();
  });
  actions.appendChild(del);
  root.appendChild(actions);

  if (problems && problems.length) {
    const box = el('div', 'problems');
    for (const p of problems) box.appendChild(el('div', 'problem ' + p.level, p.message));
    root.appendChild(box);
  }

  const pools = el('div', 'pools');
  pools.appendChild(renderPool('buffs', isGlobal));
  pools.appendChild(renderPool('debuffs', isGlobal));
  root.appendChild(pools);
}

function renderPool(kind, isGlobal) {
  const isBuff = kind === 'buffs';
  const pool = el('div', 'pool ' + kind);
  pool.appendChild(el('h2', null, isBuff ? 'Баффы' : 'Дебаффы'));
  pool.appendChild(el('div', 'hint', isBuff
    ? 'Активен один, выбирается случайно среди подходящих по времени суток.'
      + (isGlobal ? ' Достаётся зонам, у которых на это время суток нет своего баффа.' : '')
    : 'Активен один, среди постоянных и подходящих под текущую погоду и время суток.'
      + (isGlobal ? ' Каждая погода — своя корзина: правило «Дождь» в грозу не сработает.' : '')));

  current[kind].forEach((rule, idx) => pool.appendChild(renderSlot(kind, rule, idx)));

  const add = el('button', 'btn', '+ Добавить');
  add.addEventListener('click', () => openPicker(isBuff ? 0 : 1, (spell) => {
    current[kind].push({
      spell_id: spell.spell_id, trigger_type: 0, time_flag: 0, enabled: true,
      spell: spell,
    });
    markDirty();
    renderEditor();
  }));
  pool.appendChild(add);
  return pool;
}

function renderSlot(kind, rule, idx) {
  const isBuff = kind === 'buffs';
  const slot = el('div', 'slot' + (rule.enabled ? '' : ' off'));
  const meta = rule.spell || {};

  const img = iconImg(meta.icon_texture, 'icon');
  img.addEventListener('click', () => openPicker(isBuff ? 0 : 1, (spell) => {
    rule.spell_id = spell.spell_id;
    rule.spell = spell;
    markDirty();
    renderEditor();
  }));
  slot.appendChild(img);

  const body = el('div', 'body');
  const title = el('div', 'title');
  title.appendChild(el('span', null, meta.name_ru || '(без имени)'));
  title.appendChild(el('span', 'sid', '#' + rule.spell_id));
  if (meta.in_spell_dbc === false) {
    const b = el('span', 'badge missing', 'нет в spell_dbc');
    b.title = 'Сервер пропустит это правило при загрузке.';
    title.appendChild(b);
  }
  body.appendChild(title);
  body.appendChild(el('div', 'desc', meta.description_ru || ''));

  const controls = el('div', 'controls');
  // Погода - только у дебаффов, время суток - у обоих: дебафф можно повесить
  // на погоду, на время суток или на то и другое сразу.
  if (!isBuff) {
    controls.appendChild(select(TRIGGERS, rule.trigger_type, (v) => { rule.trigger_type = v; markDirty(); }));
  }
  controls.appendChild(select(TIMES, rule.time_flag, (v) => { rule.time_flag = v; markDirty(); }));

  const toggle = el('button', 'btn ghost', rule.enabled ? 'Включён' : 'Выключен');
  toggle.addEventListener('click', () => { rule.enabled = !rule.enabled; markDirty(); renderEditor(); });
  controls.appendChild(toggle);

  const rm = el('button', 'btn ghost rm', 'Убрать');
  rm.addEventListener('click', () => {
    current[kind].splice(idx, 1);
    markDirty();
    renderEditor();
  });
  controls.appendChild(rm);

  body.appendChild(controls);
  slot.appendChild(body);
  return slot;
}

function payload() {
  const strip = (r) => ({
    spell_id: r.spell_id, trigger_type: r.trigger_type,
    time_flag: r.time_flag, enabled: r.enabled,
  });
  return { buffs: current.buffs.map(strip), debuffs: current.debuffs.map(strip) };
}

async function saveZone(force) {
  const btn = document.getElementById('btn-save');
  if (btn) { btn.disabled = true; btn.textContent = 'Сохранение…'; }
  try {
    const res = await api(`/api/zones/${current.zone_id}?force=${force ? 1 : 0}`, {
      method: 'PUT', body: JSON.stringify(payload()),
    });
    dirty = false;
    current = await api('/api/zones/' + current.zone_id);
    renderEditor(res.problems);
    await loadZones();
    await loadHealth();
    toast(res.reloaded
      ? `Сохранено (${res.saved} правил) и применено на PTR`
      : `Сохранено (${res.saved} правил), но reload не прошёл: ${res.reload_output}`,
      res.reloaded ? 'ok' : 'err');
  } catch (e) {
    const p = e.payload;
    if (p && p.problems) {
      renderEditor(p.problems);
      const errs = p.problems.filter(x => x.level === 'error').length;
      if (confirm(`Ошибок: ${errs}. Сохранить всё равно?`)) return saveZone(true);
      toast('Не сохранено', 'err');
    } else {
      toast('Ошибка: ' + e.message, 'err');
    }
    if (btn) { btn.disabled = false; btn.textContent = 'Применить на PTR'; }
  }
}

// --- spell picker ---------------------------------------------------------

let pickerCb = null;
let pickerKind = 0;

async function openPicker(kind, cb) {
  pickerCb = cb;
  pickerKind = kind;
  if (!spells.length) spells = await api('/api/envfx/spells');
  document.getElementById('picker-title').textContent =
    kind === 0 ? 'Выбор баффа' : 'Выбор дебаффа';
  document.getElementById('picker-search').value = '';
  renderPicker('');
  document.getElementById('picker').classList.remove('hidden');
  document.getElementById('picker-search').focus();
}

function renderPicker(query) {
  const q = query.trim().toLowerCase();
  const list = document.getElementById('picker-list');
  list.innerHTML = '';
  const matches = spells.filter(s => {
    if (s.kind !== pickerKind) return false;
    if (!q) return true;
    return (s.name_ru || '').toLowerCase().includes(q)
      || (s.description_ru || '').toLowerCase().includes(q)
      || String(s.spell_id).includes(q);
  }).slice(0, 300);

  if (!matches.length) { list.appendChild(el('div', 'empty', 'Ничего не найдено')); return; }

  for (const s of matches) {
    const row = el('div', 'picker-row');
    row.appendChild(iconImg(s.icon_texture));
    const meta = el('div', 'meta');
    meta.appendChild(el('b', null, s.name_ru || '(без имени)'));
    meta.appendChild(el('span', null,
      `#${s.spell_id} · ${s.description_ru || 'без описания'} · используется в ${s.used_by_rules} прав.`));
    row.appendChild(meta);
    if (!s.in_spell_dbc) row.appendChild(el('span', 'badge missing', 'нет в spell_dbc'));
    row.addEventListener('click', () => {
      document.getElementById('picker').classList.add('hidden');
      if (pickerCb) pickerCb(s);
    });
    list.appendChild(row);
  }
}

// --- boot -----------------------------------------------------------------

function setup() {
  document.getElementById('zone-filter').addEventListener('input', renderZoneList);
  document.getElementById('picker-search').addEventListener('input', (e) => renderPicker(e.target.value));
  document.getElementById('picker-close').addEventListener('click', () =>
    document.getElementById('picker').classList.add('hidden'));
  document.getElementById('picker').addEventListener('click', (e) => {
    if (e.target.id === 'picker') e.target.classList.add('hidden');
  });

  document.getElementById('btn-reload').addEventListener('click', async () => {
    try {
      const r = await api('/api/reload', { method: 'POST' });
      toast('Правила перезагружены: ' + (r.output || 'ok'), 'ok');
    } catch (e) { toast('SOAP: ' + e.message, 'err'); }
  });

  document.getElementById('btn-export').addEventListener('click', async () => {
    try {
      const r = await api('/api/export', { method: 'POST' });
      toast(`Выгружено ${r.rows} правил (${r.zones} зон) в ${r.path}`, 'ok');
    } catch (e) { toast('Экспорт: ' + e.message, 'err'); }
  });

  window.addEventListener('beforeunload', (e) => {
    if (dirty) { e.preventDefault(); e.returnValue = ''; }
  });

  setupZoneAdd();
  loadHealth();
  loadZones().catch(e => toast(e.message, 'err'));
}

setup();
