'use strict';

// Страница mod-advanced-weather. В отличие от остальных редакторов она ничего
// не хранит: всё состояние живёт в памяти worldserver'а, панель читает его
// командой ".aw list" по SOAP и туда же пишет. Поэтому здесь есть автообновление
// — погода меняется сама, без нашего участия.

const REFRESH_MS = 15000;

const state = {
  data: null,          // ответ /api/weather
  zones: [],
  selected: null,      // zone_id
  filter: '',
  // Набранный, но ещё не применённый выбор. Пока не нажата «Применить»,
  // зоной распоряжается режиссёр — панель молчит.
  draft: null,         // { state, grade, minutes }
  timer: null,
  // Свёрнутые континенты. Хранится «что свёрнуто», а не «что раскрыто», чтобы
  // новая группа появлялась раскрытой сама.
  collapsed: new Set(),
};

const GROUP_NAMES = {
  clear: 'Ясное небо',
  rain: 'Дождь',
  snow: 'Снег',
  storm: 'Песчаная буря',
  special: 'Особые (только модуль)',
};

function zoneById(id) {
  return state.zones.find(z => z.zone_id === id) || null;
}

function fmtLeft(seconds) {
  if (!seconds) return '';
  const m = Math.floor(seconds / 60);
  return m >= 1 ? `${m} мин` : `${seconds} с`;
}

// --- загрузка -------------------------------------------------------------

async function load(silent) {
  try {
    const data = await api('/api/weather');
    state.data = data;
    state.zones = data.zones;
    renderModuleState();
    renderList();
    renderEditor();
  } catch (err) {
    renderModuleState(err);
    if (!silent) toast(err.message, 'err');
  }
}

function renderModuleState(err) {
  const box = document.getElementById('module-state');
  box.innerHTML = '';
  if (err) {
    box.appendChild(el('span', 'bad', 'модуль: ' + err.message));
    return;
  }
  const mod = state.data.module || {};
  box.appendChild(el('span', mod.enabled ? 'good' : 'bad',
    mod.enabled ? 'режиссёр включён' : 'режиссёр выключен (Enable = 0)'));
  box.appendChild(el('span', '', `протокол ${mod.protocol}`));
}

// --- список зон -----------------------------------------------------------

function renderList() {
  const list = document.getElementById('zone-list');
  list.innerHTML = '';

  const needle = state.filter.trim().toLowerCase();
  const match = z => !needle
    || z.name.toLowerCase().includes(needle)
    || String(z.zone_id) === needle;

  const groups = state.data.continents || [];
  let shownTotal = 0;

  groups.forEach(group => {
    const zones = state.zones.filter(z => z.continent === group.key && match(z));
    if (!zones.length) return;
    shownTotal += zones.length;

    // При активном фильтре свёрнутость игнорируем: человек ищет зону, а не
    // разглядывает структуру мира.
    const open = !!needle || !state.collapsed.has(group.key);
    const head = el('div', 'zone-group' + (open ? '' : ' closed'));
    head.appendChild(el('span', 'zone-group-mark', open ? '▾' : '▸'));
    head.appendChild(el('span', 'zone-group-name', group.name));
    const live = zones.filter(z => z.players).length;
    head.appendChild(el('span', 'zone-group-count',
      live ? `${live} / ${zones.length}` : String(zones.length)));
    head.addEventListener('click', () => {
      if (state.collapsed.has(group.key)) state.collapsed.delete(group.key);
      else state.collapsed.add(group.key);
      renderList();
    });
    list.appendChild(head);

    if (!open) return;

    zones.forEach(z => {
      const item = el('div', 'zone-item' + (z.zone_id === state.selected ? ' active' : ''));
      const name = el('div', 'name', z.name);
      // Зона, которую режиссёр ещё не трогал, показана бледнее: в ней просто
      // нечего показывать, а не «нельзя».
      if (!z.known) name.style.opacity = '.55';
      item.appendChild(name);

      const counts = el('div', 'counts', z.known ? z.state_label : '-');
      if (!z.players) counts.style.opacity = '.6';
      item.appendChild(counts);

      item.addEventListener('click', () => select(z.zone_id));
      list.appendChild(item);
    });
  });

  if (!shownTotal) {
    list.appendChild(el('div', 'hint', needle
      ? 'Ничего не найдено.'
      : 'Список зон пуст.'));
  }

  document.getElementById('live-count').textContent =
    `${state.zones.length} открытых зон, из них ${state.data.known_count} ведёт `
    + `режиссёр, ${state.data.live_count} с игроками`;
}

function select(zoneId) {
  state.selected = zoneId;
  state.draft = null;
  renderList();
  renderEditor();
}

// --- редактор -------------------------------------------------------------

function renderEditor() {
  const box = document.getElementById('editor');
  box.innerHTML = '';

  const zone = zoneById(state.selected);
  if (!zone) {
    box.appendChild(el('div', 'empty', 'Выберите зону слева.'));
    return;
  }

  const head = el('div', 'zone-head');
  head.appendChild(el('h1', null, zone.name));
  head.appendChild(el('span', 'zid', `id ${zone.zone_id}`));
  if (zone.continent_name) head.appendChild(el('span', 'zid', zone.continent_name));
  box.appendChild(head);

  // Что стоит в зоне прямо сейчас — это ответ сервера, а не наш выбор.
  const now = el('div', 'hint');
  if (!zone.known) {
    now.textContent = 'Режиссёр эту зону ещё не вёл. Поставить погоду можно: '
      + 'решение запомнится и уедет в мир, как только там появится игрок.';
  } else {
    const left = fmtLeft(zone.seconds_left);
    now.textContent = `Сейчас: ${zone.state_label}, сила ${zone.grade}% `
      + `(${zone.source_label}${left ? ', ещё ' + left : ''})`;
  }
  box.appendChild(now);

  if (!zone.players) {
    const empty = el('div', 'hint');
    empty.textContent = 'В зоне нет игроков — увидеть результат сейчас некому.';
    box.appendChild(empty);
  }

  if (!zone.has_climate) {
    const warn = el('div', 'problem warning');
    warn.textContent = 'У зоны нет строки в game_weather: режиссёру не из чего '
      + 'выбирать, сама по себе погода в ней не начнётся. Ручную поставить можно.';
    box.appendChild(warn);
  }

  box.appendChild(statePicker(zone));
  box.appendChild(gradeRow(zone));
  box.appendChild(actions(zone));
  box.appendChild(climateBlock(zone));
}

function draftOf(zone) {
  if (!state.draft) {
    state.draft = {
      state: zone.state,
      grade: Math.max(zone.grade || 0, state.data.grade_min),
      minutes: 0,
    };
  }
  return state.draft;
}

function statePicker(zone) {
  const wrap = el('div');
  const draft = draftOf(zone);

  const groups = {};
  state.data.states.forEach(s => {
    (groups[s.group] = groups[s.group] || []).push(s);
  });

  Object.keys(GROUP_NAMES).forEach(group => {
    if (!groups[group]) return;
    const pool = el('div', 'pool');
    const title = el('h2', null, GROUP_NAMES[group]);
    if (group === 'special') {
      title.appendChild(helpBadge(
        'Ядро такие состояния не генерирует вообще — их ставит только этот '
        + 'модуль. Это же триггеры 4-7 в mod-environmental-effects.'));
    }
    pool.appendChild(title);

    const row = el('div', 'zone-actions');
    groups[group].forEach(s => {
      const btn = el('button', 'btn tiny' + (draft.state === s.id ? ' active' : ''),
        s.label);
      btn.addEventListener('click', () => {
        draft.state = s.id;
        renderEditor();
      });
      row.appendChild(btn);
    });
    pool.appendChild(row);
    wrap.appendChild(pool);
  });

  return wrap;
}

function gradeRow(zone) {
  const draft = draftOf(zone);
  const pool = el('div', 'pool');
  pool.appendChild(el('h2', null, 'Сила и удержание'));

  const row = el('div', 'zone-actions');

  const slider = document.createElement('input');
  slider.type = 'range';
  slider.min = String(state.data.grade_min);
  slider.max = '99';
  slider.value = String(draft.grade);
  slider.disabled = draft.state === 0;

  const value = el('span', 'muted', draft.grade + '%');
  slider.addEventListener('input', () => {
    draft.grade = Number(slider.value);
    value.textContent = draft.grade + '%';
  });

  row.appendChild(slider);
  row.appendChild(value);
  row.appendChild(helpBadge(
    `Ниже ${state.data.grade_min}% клиент показывает «ясно» независимо от `
    + 'состояния, поэтому ползунок оттуда и начинается. У тумана, грозы и '
    + 'порченых осадков градаций силы нет — значение влияет только на плотность.'));

  const minutes = document.createElement('input');
  minutes.type = 'number';
  minutes.className = 'input';
  minutes.style.width = '90px';
  minutes.min = '0';
  minutes.max = '1440';
  minutes.value = String(draft.minutes);
  minutes.addEventListener('change', () => {
    draft.minutes = Math.max(0, Number(minutes.value) || 0);
  });
  row.appendChild(el('span', 'muted', 'держать, мин:'));
  row.appendChild(minutes);
  row.appendChild(helpBadge(
    '0 — взять AdvancedWeather.ManualHoldMinutes из конфига модуля. По '
    + 'истечении зона возвращается режиссёру сама.'));

  pool.appendChild(row);
  return pool;
}

function actions(zone) {
  const row = el('div', 'zone-actions');
  const draft = draftOf(zone);

  const apply = el('button', 'btn primary', 'Применить');
  apply.addEventListener('click', async () => {
    apply.disabled = true;
    try {
      const updated = await api(`/api/weather/zones/${zone.zone_id}`, {
        method: 'PUT',
        body: JSON.stringify(draft),
      });
      merge(updated);
      toast(`${updated.name}: ${updated.state_label}`, 'ok');
    } catch (err) {
      toast(err.message, 'err');
    } finally {
      apply.disabled = false;
    }
  });
  row.appendChild(apply);

  const pin = el('button', 'btn', zone.source === 2 ? 'Закреплено' : 'Закрепить');
  pin.disabled = zone.source === 2;
  pin.addEventListener('click', () => act(zone, 'pin', 'закреплено'));
  row.appendChild(pin);
  row.appendChild(helpBadge(
    'Закреплённую погоду режиссёр не трогает вовсе — до «Вернуть режиссёру».'));

  const release = el('button', 'btn', 'Вернуть режиссёру');
  release.disabled = zone.known && zone.source === 0;
  release.addEventListener('click', () => act(zone, 'release', 'отдано режиссёру'));
  row.appendChild(release);

  return row;
}

async function act(zone, what, done) {
  try {
    const updated = await api(`/api/weather/zones/${zone.zone_id}/${what}`,
      { method: 'POST' });
    merge(updated);
    toast(`${updated.name}: ${done}`, 'ok');
  } catch (err) {
    toast(err.message, 'err');
  }
}

// Ответ команды — это уже актуальное состояние зоны: вклеиваем его вместо
// повторного запроса всего списка.
function merge(updated) {
  const idx = state.zones.findIndex(z => z.zone_id === updated.zone_id);
  if (idx >= 0) {
    // Ответ команды описывает погоду, но не знает ни климата, ни континента -
    // это наши поля, переносим их из прежней строки.
    const prev = state.zones[idx];
    updated.seasons = prev.seasons;
    updated.continent = prev.continent;
    updated.continent_name = prev.continent_name;
    updated.name = updated.name || prev.name;
    state.zones[idx] = updated;
  }
  state.draft = null;
  renderList();
  renderEditor();
}

function climateBlock(zone) {
  const pool = el('div', 'pool');
  const title = el('h2', null, 'Климат зоны');
  title.appendChild(helpBadge(
    'Шансы из game_weather: по ним режиссёр катает погоду, когда зона не '
    + 'закреплена. Правка климата — следующая версия страницы.'));
  pool.appendChild(title);

  if (!zone.seasons) {
    pool.appendChild(el('div', 'hint', 'Нет строки в game_weather.'));
    return pool;
  }

  const names = { spring: 'весна', summer: 'лето', fall: 'осень', winter: 'зима' };
  Object.keys(names).forEach(season => {
    const s = zone.seasons[season];
    pool.appendChild(el('div', 'hint',
      `${names[season]}: дождь ${s.rain}%, снег ${s.snow}%, буря ${s.storm}%`));
  });
  return pool;
}

// --- запуск ---------------------------------------------------------------

document.getElementById('zone-filter').addEventListener('input', ev => {
  state.filter = ev.target.value;
  renderList();
});

document.getElementById('btn-refresh').addEventListener('click', () => load(false));

document.getElementById('btn-reload').addEventListener('click', async () => {
  try {
    await api('/api/weather/reload', { method: 'POST' });
    toast('Конфиг модуля перечитан', 'ok');
    load(true);
  } catch (err) {
    toast(err.message, 'err');
  }
});

// Автообновление молчаливое: страница висит открытой, а сеть до worldserver'а
// может мигать — ругаться тостом на каждую такую секунду незачем.
state.timer = setInterval(() => load(true), REFRESH_MS);

load(false);
