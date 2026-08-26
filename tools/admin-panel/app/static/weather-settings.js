'use strict';

// Настройки mod-advanced-weather. Своих знаний о модуле у страницы нет: реестр
// настроек живёт в C++, приезжает по ".aw cfg" и рисуется по границам, которые
// сервер же и прислал. Добавили строку в реестр — поле появилось здесь само.
//
// Отсюда и главное правило: НИЧЕГО не хранить локально. Значение показывается
// то, что подтвердил сервер, а не то, что набрано в поле, — иначе после
// неудачной записи страница врала бы.

const REFRESH_MS = 15000;

const state = {
  module: null,        // ответ /api/weather (шапка) — состояние режиссёра
  groups: [],
  settings: [],
  supported: false,
  cyclones: [],
  // Настройки, чья запись сейчас в полёте: пока сервер не ответил, поле не
  // трогаем, чтобы автообновление не подменило набранное.
  busy: new Set(),
  timer: null,
};

function setting(name) {
  return state.settings.find(s => s.name === name) || null;
}

function fmtLeft(seconds) {
  if (!seconds) return '—';
  const m = Math.floor(seconds / 60);
  return m >= 1 ? `${m} мин` : `${seconds} с`;
}

// --- загрузка -------------------------------------------------------------

async function load(silent) {
  try {
    const [overview, cfg] = await Promise.all([
      api('/api/weather'),
      api('/api/weather/settings'),
    ]);
    state.module = overview.module || {};
    state.cyclones = overview.cyclones || [];
    state.groups = cfg.groups || [];
    state.settings = cfg.settings || [];
    state.supported = !!cfg.supported;
    renderHead();
    renderDirector();
    renderGroups();
    renderCyclones();
  } catch (err) {
    renderHead(err);
    if (!silent) toast(err.message, 'err');
  }
}

function renderHead(err) {
  const box = document.getElementById('module-state');
  box.innerHTML = '';
  if (err) {
    box.appendChild(el('span', 'bad', 'модуль: ' + err.message));
    return;
  }
  const mod = state.module || {};
  const from = mod.stored ? ' (переключателем)'
    : mod.can_toggle ? ' (из конфига)' : ' (Enable = 0)';
  box.appendChild(el('span', mod.enabled ? 'good' : 'bad',
    (mod.enabled ? 'режиссёр включён' : 'режиссёр выключен') + from));
  box.appendChild(el('span', '', `протокол ${mod.protocol || '?'}`));
}

// --- главный переключатель ------------------------------------------------
// Он же настройка "enabled", но стоит отдельно и крупно: остальная страница
// без него не имеет смысла, и человек должен видеть это, не читая.

function renderDirector() {
  const box = document.getElementById('director');
  box.innerHTML = '';

  const mod = state.module || {};
  const on = !!mod.enabled;
  const row = el('div', 'wset-hero-row');

  const text = el('div', 'wset-hero-text');
  text.appendChild(el('div', 'wset-hero-name', 'Режиссёр погоды'));
  text.appendChild(el('div', 'wset-hero-hint', on
    ? 'Погоду в мире ведёт модуль: катает фронты, чинит сбитые зоны, '
      + 'разносит погоду по связям.'
    : 'Модуль в погоду не вмешивается. Зоны живут под ядровой генерацией '
      + 'по game_weather, и ничего на этой странице не действует.'));
  row.appendChild(text);

  const btn = el('button', 'wset-switch' + (on ? ' on' : ''));
  btn.appendChild(el('span', 'wset-switch-knob'));
  btn.appendChild(el('span', 'wset-switch-label', on ? 'Включён' : 'Выключен'));
  if (!mod.can_toggle) {
    btn.classList.add('off');
    btn.title = 'Переключатель появится после пересборки worldserver';
  }
  btn.addEventListener('click', async () => {
    if (!mod.can_toggle || state.busy.has('enabled')) return;
    state.busy.add('enabled');
    try {
      const res = await api('/api/weather/director', {
        method: 'PUT', body: JSON.stringify({ enabled: !on }),
      });
      toast(res.enabled
        ? 'Режиссёр включён: погоду ведёт модуль'
        : 'Режиссёр выключен: зоны вернулись к game_weather', 'ok');
    } catch (e) {
      toast(e.message, 'err');
    } finally {
      state.busy.delete('enabled');
    }
    await load(true);
  });
  row.appendChild(btn);
  box.appendChild(row);

  // Откуда взято значение — тут же, мелким шрифтом: «выключен» из конфига и
  // «выключен» кнопкой чинятся в разных местах.
  const src = setting('enabled');
  if (src) {
    box.appendChild(el('div', 'wset-hero-src', src.stored
      ? 'Значение сохранено в базе и переживёт рестарт. '
        + `В конфиге модуля — ${src.default ? 'включён' : 'выключен'}.`
      : 'Значение берётся из AdvancedWeather.Enable в конфиге модуля.'));
  }
}

// --- группы настроек ------------------------------------------------------

function renderGroups() {
  const box = document.getElementById('groups');
  box.innerHTML = '';

  if (!state.supported) {
    const hint = el('div', 'hint');
    hint.textContent = 'Worldserver не знает команду .aw cfg — модуль не '
      + 'пересобран. Настройки правятся конфигом '
      + 'env/dist/etc-ptr/modules/mod_advanced_weather.conf.';
    box.appendChild(hint);
    return;
  }

  state.groups.forEach(group => {
    // "enabled" уже стоит наверху отдельным переключателем: дублировать его
    // в списке значило бы дать две кнопки на одно и то же.
    const rows = state.settings.filter(
      s => s.group === group.key && s.name !== 'enabled');
    if (!rows.length) return;

    const block = el('section', 'wset-block');
    block.appendChild(el('h2', 'wset-title', group.name));
    if (group.hint) block.appendChild(el('div', 'wset-grouphint', group.hint));

    const grid = el('div', 'wset-grid');
    rows.forEach(row => grid.appendChild(field(row)));
    block.appendChild(grid);
    box.appendChild(block);
  });
}

function field(row) {
  const wrap = el('div', 'wset-field' + (row.stored ? ' stored' : ''));

  const head = el('div', 'wset-field-head');
  head.appendChild(el('span', 'wset-field-label', row.label));
  if (row.hint) head.appendChild(helpBadge(row.hint));
  wrap.appendChild(head);

  wrap.appendChild(row.kind === 'bool' ? boolInput(row) : intInput(row));

  const foot = el('div', 'wset-field-foot');
  foot.appendChild(el('span', 'wset-field-def',
    row.stored ? `в конфиге: ${fmtValue(row, row.default)}` : 'из конфига'));
  if (row.stored) {
    const reset = el('button', 'wset-reset', 'сбросить');
    reset.title = 'Вернуть значение из конфига модуля';
    reset.addEventListener('click', () => write(row.name, null));
    foot.appendChild(reset);
  }
  wrap.appendChild(foot);
  return wrap;
}

function fmtValue(row, value) {
  if (row.kind === 'bool') return value ? 'да' : 'нет';
  return row.unit ? `${value} ${row.unit}` : String(value);
}

function boolInput(row) {
  const btn = el('button', 'wset-switch small' + (row.value ? ' on' : ''));
  btn.appendChild(el('span', 'wset-switch-knob'));
  btn.appendChild(el('span', 'wset-switch-label', row.value ? 'Да' : 'Нет'));
  btn.addEventListener('click', () => write(row.name, row.value ? 0 : 1));
  return btn;
}

function intInput(row) {
  const line = el('div', 'wset-int');
  const input = el('input', 'input');
  input.type = 'number';
  input.min = String(row.min);
  input.max = String(row.max);
  input.value = String(row.value);
  // Запись по Enter и по уходу из поля, а не на каждое нажатие: иначе "3500"
  // по дороге успело бы съездить в "3" и смести все фронты.
  const commit = () => {
    const next = Number(input.value);
    if (!Number.isFinite(next) || next === row.value) {
      input.value = String(row.value);
      return;
    }
    if (next < row.min || next > row.max) {
      toast(`${row.label}: допустимо ${row.min}…${row.max}`, 'err');
      input.value = String(row.value);
      return;
    }
    write(row.name, next);
  };
  input.addEventListener('keydown', ev => {
    if (ev.key === 'Enter') input.blur();
    if (ev.key === 'Escape') { input.value = String(row.value); input.blur(); }
  });
  input.addEventListener('blur', commit);
  line.appendChild(input);
  if (row.unit) line.appendChild(el('span', 'wset-unit', row.unit));
  line.appendChild(el('span', 'wset-range', `${row.min}…${row.max}`));
  return line;
}

async function write(name, value) {
  if (state.busy.has(name)) return;
  state.busy.add(name);
  try {
    await api(`/api/weather/settings/${name}`, {
      method: 'PUT', body: JSON.stringify({ value }),
    });
    toast(value === null ? 'Вернули значение из конфига' : 'Сохранено', 'ok');
  } catch (e) {
    toast(e.message, 'err');
  } finally {
    state.busy.delete(name);
  }
  await load(true);
}

// --- фронты ---------------------------------------------------------------

function renderCyclones() {
  const box = document.getElementById('cyclones');
  box.innerHTML = '';

  const on = setting('cyclones_enabled');
  if (on && !on.value) {
    box.appendChild(el('div', 'hint', 'Циклоны выключены: погоду катает '
      + 'каждая зона сама, одиночными бросками. Включите их выше, чтобы по '
      + 'миру пошли фронты.'));
    return;
  }

  if (!state.cyclones.length) {
    box.appendChild(el('div', 'hint', 'Сейчас ни одного фронта — штиль. '
      + 'Ближайший тик режиссёра запустит новые.'));
    return;
  }

  state.cyclones.forEach(c => {
    const card = el('div', `wset-cyc g-${c.family_group}`);

    const head = el('div', 'wset-cyc-head');
    head.appendChild(el('span', 'wset-cyc-name', `Фронт №${c.id}`));
    head.appendChild(el('span', 'wset-cyc-family', c.family_name));
    card.appendChild(head);

    // Стрелка курса: она объясняет «идёт через карту» лучше любого числа.
    const arrow = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    arrow.setAttribute('viewBox', '0 0 24 24');
    arrow.classList.add('wset-cyc-arrow');
    arrow.style.transform = `rotate(${c.heading}deg)`;
    arrow.innerHTML = '<path d="M12 3v18M12 3l-5 5M12 3l5 5" fill="none" '
      + 'stroke="currentColor" stroke-width="1.8" stroke-linecap="round" '
      + 'stroke-linejoin="round"/>';
    card.appendChild(arrow);

    const rows = [
      ['карта', String(c.map)],
      ['радиус', `${c.radius} ярдов`],
      ['ступень в ядре', String(c.peak)],
      ['скорость', `${c.speed.toFixed(1)} ярд/с`],
      ['зон под ним', String(c.zones)],
      ['уйдёт через', fmtLeft(c.seconds_left)],
    ];
    const grid = el('div', 'wset-cyc-grid');
    rows.forEach(([k, v]) => {
      grid.appendChild(el('span', 'wset-cyc-k', k));
      grid.appendChild(el('span', 'wset-cyc-v', v));
    });
    card.appendChild(grid);
    box.appendChild(card);
  });
}

// --- страница -------------------------------------------------------------

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

document.getElementById('btn-cycreset').addEventListener('click', async () => {
  try {
    const res = await api('/api/weather/cyclones/reset', { method: 'POST' });
    toast(`Фронты перезапущены: ${(res.cyclones || []).length}`, 'ok');
    load(true);
  } catch (err) {
    toast(err.message, 'err');
  }
});

state.timer = setInterval(() => load(true), REFRESH_MS);
load(false);
