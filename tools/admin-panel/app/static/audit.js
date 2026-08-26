'use strict';

// The change log. Owner-only, read-only, newest first.
//
// One entry = one mutating API call. The payload it carries is what was
// *submitted*, not a diff — see the note at the top of app/audit.py. In
// practice that reads fine, because the editors send whole objects: the row
// above is what the same target looked like before.

const PAGE = 100;

let FILTERS = { area: '', actor: '', q: '', failures: false };
let OLDEST = 0;          // id of the last row shown, for "показать ещё"
let META = { areas: [], actors: [], stats: {} };

function query(extra) {
  const params = new URLSearchParams();
  if (FILTERS.area) params.set('area', FILTERS.area);
  if (FILTERS.actor) params.set('actor', FILTERS.actor);
  if (FILTERS.q) params.set('q', FILTERS.q);
  if (FILTERS.failures) params.set('failures', 'true');
  params.set('limit', String(PAGE));
  if (extra) params.set('before_id', String(extra));
  return '/api/audit?' + params.toString();
}

function prettyPayload(text) {
  if (!text) return '';
  try {
    return JSON.stringify(JSON.parse(text), null, 2);
  } catch (_) {
    return text;                       // truncated or not JSON to begin with
  }
}

function entry(row) {
  const node = el('div', 'log-row' + (row.ok ? '' : ' log-bad'));

  const when = el('div', 'log-when');
  when.appendChild(el('div', '', row.at.slice(11, 16)));
  when.appendChild(el('div', 'muted', row.at.slice(0, 10)));
  node.appendChild(when);

  const body = el('div', 'log-body');

  const line = el('div', 'log-line');
  line.appendChild(el('span', 'chip', row.area_label));
  line.appendChild(el('strong', '', row.summary));
  if (row.target) line.appendChild(el('span', 'log-target', row.target));
  if (!row.ok) {
    line.appendChild(el('span', 'chip log-status', 'отказ ' + row.status));
  }
  body.appendChild(line);

  const who = el('div', 'muted log-who');
  who.textContent = `${row.actor_name || row.actor_login} `
    + `(${row.actor_login}, ${row.actor_role}) · ${row.method} ${row.path}`;
  body.appendChild(who);

  if (row.payload) {
    const fold = el('details', 'log-payload');
    fold.appendChild(el('summary', '', 'что отправлено'));
    fold.appendChild(el('pre', '', prettyPayload(row.payload)));
    body.appendChild(fold);
  }

  node.appendChild(body);
  return node;
}

async function load(append) {
  const box = document.getElementById('log');
  const hint = document.getElementById('log-hint');
  if (!append) { box.innerHTML = ''; OLDEST = 0; }
  let rows;
  try {
    rows = await api(query(append ? OLDEST : 0));
  } catch (e) {
    hint.textContent = e.message;
    return;
  }
  for (const row of rows) box.appendChild(entry(row));
  if (rows.length) OLDEST = rows[rows.length - 1].id;

  const shown = box.childElementCount;
  hint.textContent = shown
    ? `Показано записей: ${shown}.`
    : 'Ничего не найдено — попробуй снять фильтры.';
  document.getElementById('btn-more').classList.toggle('hidden',
                                                       rows.length < PAGE);
}

function fillFilters() {
  const area = document.getElementById('f-area');
  area.innerHTML = '';
  const all = el('option', '', 'Все разделы');
  all.value = '';
  area.appendChild(all);
  for (const a of META.areas) {
    const opt = el('option', '', a.label);
    opt.value = a.id;
    area.appendChild(opt);
  }

  const actor = document.getElementById('f-actor');
  actor.innerHTML = '';
  const anyone = el('option', '', 'Все люди');
  anyone.value = '';
  actor.appendChild(anyone);
  for (const a of META.actors) {
    const opt = el('option', '', `${a.actor_name || a.actor_login} (${a.n})`);
    opt.value = a.actor_login;
    actor.appendChild(opt);
  }
}

function tiles() {
  const box = document.getElementById('audit-tiles');
  box.innerHTML = '';
  const add = (label, value, hint) => {
    const t = el('div', 'tile');
    t.appendChild(el('div', 'tile-label', label));
    t.appendChild(el('div', 'tile-value', String(value)));
    if (hint) t.appendChild(el('div', 'tile-hint', hint));
    box.appendChild(t);
  };
  add('Записей всего', META.stats.total ?? '—');
  add('За сутки', META.stats.last_day ?? '—');
  add('Людей в журнале', META.actors.length,
      'Считая общий токен, если им пользовались.');
}

async function init() {
  try {
    META = await api('/api/audit/meta');
  } catch (e) {
    document.getElementById('log-hint').textContent = e.message;
    return;
  }
  fillFilters();
  tiles();

  const debounce = (fn, ms) => {
    let timer = null;
    return (...args) => {
      clearTimeout(timer);
      timer = setTimeout(() => fn(...args), ms);
    };
  };

  document.getElementById('f-area').addEventListener('change', ev => {
    FILTERS.area = ev.target.value;
    load(false);
  });
  document.getElementById('f-actor').addEventListener('change', ev => {
    FILTERS.actor = ev.target.value;
    load(false);
  });
  document.getElementById('q').addEventListener('input', debounce(ev => {
    FILTERS.q = ev.target.value.trim();
    load(false);
  }, 250));
  document.getElementById('f-failed').addEventListener('click', ev => {
    FILTERS.failures = !FILTERS.failures;
    ev.target.classList.toggle('active', FILTERS.failures);
    load(false);
  });
  document.getElementById('btn-reload').addEventListener('click', async () => {
    META = await api('/api/audit/meta');
    fillFilters();
    tiles();
    load(false);
  });
  document.getElementById('btn-more').addEventListener('click', () => load(true));

  load(false);
}

document.addEventListener('DOMContentLoaded', init);
