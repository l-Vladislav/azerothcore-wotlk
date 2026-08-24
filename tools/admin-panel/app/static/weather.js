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
  // Связи выбранной зоны: ответ /api/weather/zones/<id>/links.
  links: null,
  // Набранные, но не сохранённые исходящие связи. Живут отдельно от state.links,
  // иначе автообновление страницы затирало бы правку на полуслове.
  linkDraft: null,
};

const SEASON_NAMES = {
  spring: 'весна', summer: 'лето', fall: 'осень', winter: 'зима',
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
    renderZoneCard();
    renderZoneClimate();
    renderMapStates();
    WeatherMap.render(state.zones, state.selected);
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

  // Старый протокол = worldserver не пересобран. Страница работает, но про
  // связи он ещё не знает, и молча делать вид, что всё на месте, нельзя.
  const want = state.data.protocol_expected;
  const stale = want && mod.protocol && mod.protocol !== want;
  const proto = el('span', stale ? 'bad' : '', `протокол ${mod.protocol}`
    + (stale ? ` (страница ждёт ${want}: связи зон появятся после пересборки)` : ''));
  box.appendChild(proto);
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
    head.appendChild(el('span', 'zone-group-count', String(zones.length)));
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

      // Погода идёт независимо от игроков, поэтому строка зоны больше не
      // блёкнет от того, что в ней сейчас пусто.
      item.appendChild(el('div', 'counts', z.known ? z.state_label : '-'));

      // Зона со связями помечена стрелкой: иначе непонятно, почему в ней
      // погода меняется «сама», когда её никто не трогал.
      if (z.links_out || z.links_in) {
        const mark = el('div', 'counts', `⇄${z.links_out || 0}`);
        mark.title = `исходящих связей: ${z.links_out || 0}, `
          + `входящих: ${z.links_in || 0}`;
        item.appendChild(mark);
      }

      item.addEventListener('click', () => select(z.zone_id));
      list.appendChild(item);
    });
  });

  if (!shownTotal) {
    list.appendChild(el('div', 'hint', needle
      ? 'Ничего не найдено.'
      : 'Список зон пуст.'));
  }


}

function select(zoneId) {
  state.selected = zoneId;
  state.draft = null;
  state.links = null;
  state.linkDraft = null;
  renderList();
  renderEditor();
  renderZoneCard();
  renderZoneClimate();
  renderMapStates();
  WeatherMap.render(state.zones, state.selected);
  loadLinks(zoneId);
}

// Связи тянутся отдельным запросом и НЕ обновляются по таймеру: пока человек
// набирает список, дёргать его под руками нельзя.
async function loadLinks(zoneId) {
  try {
    const data = await api(`/api/weather/zones/${zoneId}/links`);
    if (state.selected !== zoneId) return;   // успели переключиться
    state.links = data;
    state.linkDraft = data.out.map(l => ({
      linked_zone: l.zone_id,
      strength: l.strength,
      enabled: l.enabled,
      comment: l.comment,
      mirror: l.mirror,
    }));
    renderEditor();
  } catch (err) {
    if (state.selected !== zoneId) return;
    state.links = { error: err.message, out: [], in: [] };
    renderEditor();
  }
}

// --- редактор -------------------------------------------------------------

function renderEditor() {
  const box = document.getElementById('editor');
  box.innerHTML = '';

  const zone = zoneById(state.selected);
  if (!zone) {
    box.appendChild(el('div', 'empty', 'Выберите зону на карте или в списке.'));
    return;
  }

  // Заголовок не дублируем: имя зоны написано на карте, под которой стоит
  // редактор. Про принесённую связью погоду тоже не пишем: это видно в плашке
  // зоны («источник: по связи») и в списке входящих связей ниже.
  // Погода зоны целиком живёт на карте: состояния, сила, удержание, действия.
  // Здесь остаются связи. Если карта не собрана, управлять было бы нечем —
  // тогда весь набор возвращается сюда.
  if (!document.querySelector('.wmap-states')) {
    box.appendChild(statePicker(zone));
    box.appendChild(gradeRow(zone));
    box.appendChild(actions(zone));
  }
  box.appendChild(linksBlock(zone));
}

// --- быстрые кнопки погоды на карте ---------------------------------------

// Иконки погоды. Рисуются здесь, а не берутся картинками: у панели принцип
// «без изображений и вебшрифтов» (см. шапку style.css), а инлайновый SVG —
// это разметка, которая ещё и красится currentColor под состояние кнопки.
//
// Все иконки в одной сетке 24x24 и собраны из общих кусков: облако одно на все
// осадки, отличаются только знаки под ним и их количество.
const ICON_CLOUD =
  'M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z';

function svgIcon(body) {
  const wrap = el('span', 'wmap-icon');
  wrap.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"'
    + ' stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">'
    + body + '</svg>';
  return wrap;
}

// Знаки под облаком: капли, снежинки. Их количество и отличает морось от ливня.
function marks(count, draw) {
  const xs = { 1: [12], 2: [9.5, 14.5], 3: [7.5, 12, 16.5] }[count] || [12];
  return xs.map(draw).join('');
}

const RAIN_DROP = x => `<path d="M${x} 17.5l-1 3"/>`;
const SNOW_FLAKE = x => `<path d="M${x} 17.4v3.8M${x - 1.9} 18.4l3.8 1.9`
  + `M${x + 1.9} 18.4l-3.8 1.9"/>`;
const SAND_LINE = y => `<path d="M4 ${y}h10.5a1.8 1.8 0 1 0-1.8-1.8"/>`;
// Порченые осадки отличает залитая туча: одними каплями «чёрный дождь» от
// обычного не отличить.
const DARK_CLOUD = `<path d="${ICON_CLOUD}" fill="currentColor" fill-opacity=".55"/>`;

function stateIcon(id) {
  switch (id) {
    case 0:                                   // ясно
      return svgIcon('<circle cx="12" cy="12" r="4.2"/>'
        + '<path d="M12 3.4v2.2M12 18.4v2.2M3.4 12h2.2M18.4 12h2.2'
        + 'M6 6l1.6 1.6M16.4 16.4L18 18M18 6l-1.6 1.6M7.6 16.4L6 18"/>');
    case 1:                                   // туман
      return svgIcon(`<path d="${ICON_CLOUD}"/><path d="M5 18.5h11M7.5 21h9"/>`);
    case 3: case 4: case 5: {                 // дождь: 1, 2, 3 капли
      const n = { 3: 1, 4: 2, 5: 3 }[id];
      return svgIcon(`<path d="${ICON_CLOUD}"/>` + marks(n, RAIN_DROP));
    }
    case 6: case 7: case 8: {                 // снег: 1, 2, 3 снежинки
      const n = { 6: 1, 7: 2, 8: 3 }[id];
      return svgIcon(`<path d="${ICON_CLOUD}"/>` + marks(n, SNOW_FLAKE));
    }
    case 22: case 41: case 42: {              // песчаная буря: 1, 2, 3 полосы
      const ys = { 22: [12], 41: [9.5, 14.5], 42: [7, 12, 17] }[id];
      return svgIcon(ys.map(SAND_LINE).join(''));
    }
    case 91:                                  // гроза
      return svgIcon(`<path d="${ICON_CLOUD}"/>`
        + '<path d="M12.8 17l-2.6 3.2h2.8L11.4 23"/>');
    case 90:                                  // чёрный дождь
      return svgIcon(DARK_CLOUD + marks(2, RAIN_DROP));
    case 106:                                 // чёрный снег
      return svgIcon(DARK_CLOUD + marks(2, SNOW_FLAKE));
    default:
      return svgIcon('<circle cx="12" cy="12" r="6"/>');
  }
}

// Ставят погоду сразу, без «Применить»: смысл кнопок на карте в том, чтобы
// щёлкнуть зону и тут же увидеть в ней погоду. Сила и удержание берутся те,
// что набраны в редакторе, — отдельного набора состояния карта не заводит.
async function applyState(zone, stateId, btn) {
  const draft = draftOf(zone);
  draft.state = stateId;
  btn.disabled = true;
  try {
    const updated = await api(`/api/weather/zones/${zone.zone_id}`, {
      method: 'PUT',
      body: JSON.stringify(draft),
    });
    merge(updated);
    toast(`${updated.name}: ${updated.state_label}`, 'ok');
  } catch (err) {
    toast(err.message, 'err');
    btn.disabled = false;
  }
}

function renderMapStates() {
  const box = document.querySelector('.wmap-states');
  if (!box || !state.data) return;
  box.innerHTML = '';

  const zone = zoneById(state.selected);
  if (!zone) {
    box.appendChild(el('div', 'wmap-states-hint',
      'Выберите зону — здесь появятся кнопки погоды.'));
    return;
  }

  box.appendChild(el('div', 'wmap-states-title', zone.name));

  const groups = {};
  state.data.states.forEach(s => {
    (groups[s.group] = groups[s.group] || []).push(s);
  });

  Object.keys(GROUP_NAMES).forEach(group => {
    if (!groups[group]) return;
    box.appendChild(el('div', 'wmap-states-group', GROUP_NAMES[group]));

    const grid = el('div', 'wmap-state-grid');
    groups[group].forEach(s => {
      // Активна та погода, которая в зоне СТОИТ, а не набрана в редакторе:
      // кнопки на карте показывают мир, а не черновик.
      const active = zone.known && zone.state === s.id;
      const btn = el('button', 'wmap-state' + (active ? ' active' : ''));
      btn.appendChild(stateIcon(s.id));
      btn.setAttribute('aria-label', s.label);
      // Название — во всплывающей подсказке: на квадрате оно не помещается, а
      // рисунок сам по себе не отличит слабый дождь от ливня.
      const tip = active ? `${s.label} — стоит сейчас` : s.label;
      btn.addEventListener('mouseenter', () => showTip(tip, btn));
      btn.addEventListener('mouseleave', hideTip);
      btn.addEventListener('focus', () => showTip(tip, btn));
      btn.addEventListener('blur', hideTip);
      btn.addEventListener('click', () => {
        hideTip();
        applyState(zone, s.id, btn);
      });
      grid.appendChild(btn);
    });
    box.appendChild(grid);
  });

  // Сила, удержание и действия — тут же: это то, С ЧЕМ жмётся кнопка погоды,
  // и держать их в другой колонке значило бы задавать параметры вслепую.
  box.appendChild(gradeRow(zone));
  box.appendChild(actions(zone));
}

// --- карточка зоны (правая колонка) ---------------------------------------

// Состояние выбранной зоны - плашкой на самой карте, слева вверху. Континент
// и число связей отсюда убраны: первое видно по самой карте, второе живёт в
// редакторе связей, где им и занимаются.
function renderZoneCard() {
  const box = document.querySelector('.wmap-zoneinfo');
  if (!box) return;
  box.innerHTML = '';

  const zone = zoneById(state.selected);
  if (!zone) {
    box.appendChild(el('div', 'wmap-states-hint', 'Зона не выбрана'));
    return;
  }

  const head = el('div', 'wmap-zoneinfo-head');
  head.appendChild(el('span', 'wmap-zoneinfo-name', zone.name));
  head.appendChild(el('span', 'wmap-zoneinfo-id', `id ${zone.zone_id}`));
  box.appendChild(head);

  const rows = el('div', 'card-rows');
  const row = (name, value, cls) => {
    const line = el('div', 'card-row');
    line.appendChild(el('span', 'card-name', name));
    line.appendChild(el('span', 'card-value' + (cls ? ' ' + cls : ''), value));
    rows.appendChild(line);
  };

  if (zone.known) {
    row('погода', `${zone.state_label}, ${zone.grade}%`);
    const left = fmtLeft(zone.seconds_left);
    row('источник', zone.source_label + (left ? `, ещё ${left}` : ''));
  } else {
    row('погода', 'режиссёр не вёл', 'dim');
  }
  row('игроки', zone.players ? 'есть' : 'нет', zone.players ? '' : 'dim');
  box.appendChild(rows);

  // Зона может быть не на той карте, что открыта: либо просто на соседней,
  // либо на континенте, для которого файлы карты не собраны вовсе.
  if (zone.continent !== WeatherMap.continent()) {
    const where = zone.continent_name || 'другой континент';
    if (WeatherMap.hasMap(zone.continent)) {
      const link = el('button', 'wmap-jump', `показать: ${where}`);
      link.addEventListener('click', () => WeatherMap.show(zone.continent));
      box.appendChild(link);
    } else {
      box.appendChild(el('div', 'wmap-states-hint', `${where} — карта не собрана`));
    }
  }
}

// Климат — отдельным блоком в самом низу колонки, под связями: это справка о
// том, из чего режиссёр выбирает, а не ежедневное управление.
function renderZoneClimate() {
  const box = document.getElementById('zone-climate');
  if (!box) return;
  box.innerHTML = '';

  const zone = zoneById(state.selected);
  if (!zone) return;

  if (!zone.has_climate) {
    box.appendChild(el('div', 'side-title', 'Климат'));
    box.appendChild(el('div', 'problem warning',
      'Нет строки в game_weather: режиссёру не из чего выбирать, сама погода '
      + 'в зоне не начнётся. Ручную поставить можно.'));
    return;
  }
  if (!zone.seasons) return;

  // Пояснение живёт под знаком вопроса: строки мелким текстом под таблицей
  // читались как ещё одна её часть.
  const title = el('div', 'side-title', 'Климат по сезонам');
  title.appendChild(helpBadge(
    'Шансы из game_weather в порядке «дождь / снег / буря», в процентах: по '
    + 'ним режиссёр катает погоду и по ним же связь переводит осадки под '
    + 'климат соседа. Сезон ядро берёт из календарной даты сервера — четыре '
    + 'отрезка по 91 дню с отсчётом от 20 марта; сегодняшний помечен точкой.'));
  box.appendChild(title);

  const names = { spring: 'весна', summer: 'лето', fall: 'осень', winter: 'зима' };
  const seasons = el('div', 'card-rows');
  Object.keys(names).forEach(season => {
    const s = zone.seasons[season];
    if (!s) return;
    const line = el('div', 'card-row');
    line.appendChild(el('span', 'card-name', names[season]
      + (season === state.data.season ? ' •' : '')));
    line.appendChild(el('span', 'card-value',
      `${s.rain} / ${s.snow} / ${s.storm}`));
    seasons.appendChild(line);
  });
  box.appendChild(seasons);
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
  const title = el('h2', null, 'Сила и удержание');
  title.appendChild(helpBadge(
    'Сила — плотность осадков: ливень на 35% это редкие капли, на 95% стена '
    + `воды. Ниже ${state.data.grade_min}% клиент рисует ясное небо независимо `
    + 'от состояния, поэтому ползунок оттуда и начинается. Удержание — сколько '
    + 'минут ручная погода держится, прежде чем зона вернётся режиссёру; 0 '
    + 'берёт AdvancedWeather.ManualHoldMinutes из конфига модуля, а «Закрепить» '
    + 'держит её до «Вернуть режиссёру».'));
  pool.appendChild(title);

  // Своя метка: в узкой полосе на карте ряды кнопок ставятся столбиком, а этот
  // ряд - ползунок с подписями, и его ломать нельзя.
  const row = el('div', 'zone-actions grade-row');

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
    updated.links_out = prev.links_out;
    updated.links_in = prev.links_in;
    updated.name = updated.name || prev.name;
    state.zones[idx] = updated;
  }
  state.draft = null;
  renderList();
  renderEditor();
  renderZoneCard();
  renderZoneClimate();
  renderMapStates();
  WeatherMap.render(state.zones, state.selected);
}

// --- связи зон ------------------------------------------------------------
// Правится ровно один список: исходящие связи выбранной зоны. Входящие рядом
// только для чтения — их владелец другая зона, и правятся они у неё.

function linksBlock(zone) {
  const pool = el('div', 'pool');
  const title = el('h2', null, 'Связи с зонами');
  title.appendChild(helpBadge(
    'Погода этой зоны переезжает соседу с ослаблением: 100% — та же самая, '
    + 'слабее — на столько же ступеней ниже по лестнице (гроза → ливень → '
    + 'дождь → морось). Связь делает ровно один шаг: дальше по цепочке погода '
    + 'не идёт. Ручную и закреплённую погоду соседа связь не перебивает.'));
  pool.appendChild(title);

  if (!state.links) {
    pool.appendChild(el('div', 'hint', 'Загружаю связи…'));
    return pool;
  }
  if (state.links.error) {
    const warn = el('div', 'problem error');
    warn.textContent = state.links.error;
    pool.appendChild(warn);
    return pool;
  }

  const draft = state.linkDraft || [];

  pool.appendChild(el('div', 'hint',
    `Отсюда погода уходит в ${draft.length} зон(ы). Сезон сейчас: `
    + `${SEASON_NAMES[state.links.season] || state.links.season} — по нему `
    + 'считается перевод осадков под климат соседа.'));

  draft.forEach((link, idx) => pool.appendChild(linkRow(zone, link, idx)));

  if (!draft.length) {
    pool.appendChild(el('div', 'hint',
      'Исходящих связей нет: погода этой зоны никуда не переезжает.'));
  }

  pool.appendChild(linkAddRow(zone));
  pool.appendChild(linkSaveRow(zone));

  const incoming = state.links.in || [];
  const inTitle = el('h2', null, 'Приходит из зон');
  inTitle.appendChild(helpBadge(
    'Это связи соседей, а не наши: правятся они на странице той зоны. '
    + 'Показано, во что превратится их сегодняшняя погода здесь.'));
  pool.appendChild(inTitle);

  if (!incoming.length) {
    pool.appendChild(el('div', 'hint', 'Никто сюда погоду не приносит.'));
  } else {
    incoming.forEach(link => {
      const row = el('div', 'hint');
      row.textContent = `${link.name} — ${link.strength}%`
        + (link.enabled ? '' : ' (выключена)')
        + (link.preview
          ? `: ${link.preview.from_label} → ${link.preview.label}`
            + ` (${link.preview.grade}%)`
          : '');
      pool.appendChild(row);
    });
  }

  return pool;
}

function linkRow(zone, link, idx) {
  const row = el('div', 'slot' + (link.enabled ? '' : ' off'));
  const body = el('div', 'body');

  // Предпросмотр берётся из сохранённого ответа сервера, поэтому он показывает
  // силу, которая сейчас в базе, а не набранную в поле.
  const saved = (state.links.out || []).find(l => l.zone_id === link.linked_zone);

  // Имя из ответа сервера точнее списка слева: связь может вести в зону, которой
  // в курируемом списке нет вовсе.
  const title = el('div', 'title', (saved && saved.name)
    || zoneName(link.linked_zone));
  title.appendChild(el('span', 'sid', `id ${link.linked_zone}`));
  body.appendChild(title);

  const desc = el('div', 'desc');
  if (saved && saved.preview) {
    desc.textContent = `сейчас там: ${saved.preview.from_label} → `
      + `${saved.preview.label} (${saved.preview.grade}%)`
      + (saved.preview.adapted ? ', переведено под климат зоны' : '')
      + (saved.strength !== link.strength ? ' — при сохранённых '
        + saved.strength + '%' : '');
  } else {
    desc.textContent = 'в зоне-источнике сейчас ясно — переносить нечего';
  }
  body.appendChild(desc);

  const controls = el('div', 'controls');

  const slider = document.createElement('input');
  slider.type = 'range';
  slider.min = '1';
  slider.max = '100';
  slider.value = String(link.strength);
  const value = el('span', 'muted', link.strength + '%');
  slider.addEventListener('input', () => {
    link.strength = Number(slider.value);
    value.textContent = link.strength + '%';
    hint.textContent = strengthHint(link.strength);
  });
  controls.appendChild(slider);
  controls.appendChild(value);

  const hint = el('span', 'muted', strengthHint(link.strength));
  controls.appendChild(hint);

  controls.appendChild(checkbox('двусторонняя', link.mirror, on => {
    link.mirror = on;
  }, 'Держать такую же связь в обратную сторону. Снятая галочка обратную '
   + 'связь удаляет.'));

  controls.appendChild(checkbox('включена', link.enabled, on => {
    link.enabled = on;
    renderEditor();
  }));

  const comment = document.createElement('input');
  comment.type = 'text';
  comment.className = 'input';
  comment.style.flex = '1';
  comment.style.minWidth = '160px';
  comment.placeholder = 'зачем связь';
  comment.value = link.comment || '';
  comment.addEventListener('change', () => { link.comment = comment.value; });
  controls.appendChild(comment);

  body.appendChild(controls);
  row.appendChild(body);

  const rm = el('button', 'btn tiny rm', '✕');
  rm.title = 'Убрать связь';
  rm.addEventListener('click', () => {
    state.linkDraft.splice(idx, 1);
    renderEditor();
  });
  row.appendChild(rm);

  return row;
}

// Словами то же, что делает лестница: чтобы силу не приходилось подбирать
// вслепую. Ступени считаются от грозы — самой заметной погоды.
function strengthHint(strength) {
  const level = Math.round(4 * strength / 100);
  const words = ['ничего', 'морось', 'дождь', 'ливень', 'та же гроза'];
  return `гроза придёт как «${words[level]}»`;
}

function checkbox(label, checked, onChange, help) {
  const wrap = el('label', 'muted');
  wrap.style.display = 'inline-flex';
  wrap.style.alignItems = 'center';
  wrap.style.gap = '4px';
  const box = document.createElement('input');
  box.type = 'checkbox';
  box.checked = !!checked;
  box.addEventListener('change', () => onChange(box.checked));
  wrap.appendChild(box);
  wrap.appendChild(document.createTextNode(label));
  if (help) wrap.appendChild(helpBadge(help));
  return wrap;
}

function zoneName(zoneId) {
  const zone = zoneById(zoneId);
  return zone ? zone.name : `Зона ${zoneId}`;
}

function linkAddRow(zone) {
  const row = el('div', 'zone-actions');

  const taken = new Set((state.linkDraft || []).map(l => l.linked_zone));
  const pick = document.createElement('select');
  pick.className = 'sel';
  pick.appendChild(new Option('добавить зону…', ''));
  state.zones
    .filter(z => z.zone_id !== zone.zone_id && !taken.has(z.zone_id))
    .forEach(z => pick.appendChild(new Option(
      `${z.name} (${z.continent_name || 'вне мира'})`, String(z.zone_id))));

  pick.addEventListener('change', () => {
    const id = Number(pick.value);
    if (!id) return;
    // Соседи по умолчанию двусторонние: география симметрична, а одностороннюю
    // связь ставят осознанно (город внутри зоны, парящий Даларан).
    state.linkDraft.push({
      linked_zone: id, strength: 49, enabled: true, comment: '', mirror: true,
    });
    renderEditor();
  });

  row.appendChild(pick);
  row.appendChild(helpBadge(
    'Новая связь заводится на 49% — соседняя зона получит грозу дождём. '
    + '100% ставят там, где зоны неразделимы: город внутри леса.'));
  return row;
}

function linkSaveRow(zone) {
  const row = el('div', 'zone-actions');

  const save = el('button', 'btn primary', 'Сохранить связи');
  save.addEventListener('click', async () => {
    save.disabled = true;
    try {
      const data = await api(`/api/weather/zones/${zone.zone_id}/links`, {
        method: 'PUT',
        body: JSON.stringify({ links: state.linkDraft }),
      });
      state.links = data;
      state.linkDraft = data.out.map(l => ({
        linked_zone: l.zone_id,
        strength: l.strength,
        enabled: l.enabled,
        comment: l.comment,
        mirror: l.mirror,
      }));
      toast('Связи сохранены и перечитаны сервером', 'ok');
      load(true);
    } catch (err) {
      toast(err.message, 'err');
    } finally {
      save.disabled = false;
      renderEditor();
    }
  });
  row.appendChild(save);

  const reset = el('button', 'btn', 'Отменить правку');
  reset.addEventListener('click', () => loadLinks(zone.zone_id));
  row.appendChild(reset);

  row.appendChild(helpBadge(
    'Сохранение пишет таблицу mod_advanced_weather_zone_link и сразу шлёт '
    + '".aw linkreload": рестарт не нужен.'));
  return row;
}

// --- запуск ---------------------------------------------------------------

document.getElementById('zone-filter').addEventListener('input', ev => {
  state.filter = ev.target.value;
  renderList();
});

// Список зон сворачивается: на карте зона выбирается мышью, и тогда левая
// колонка только отъедает место у редактора.
const layout = document.getElementById('layout');
const btnSidebar = document.getElementById('btn-sidebar');

function syncSidebarButton() {
  btnSidebar.textContent = layout.classList.contains('no-sidebar')
    ? 'Показать список' : 'Скрыть список';
}

if (localStorage.getItem('weatherSidebarHidden') === '1') {
  layout.classList.add('no-sidebar');
}
syncSidebarButton();

btnSidebar.addEventListener('click', () => {
  const hidden = layout.classList.toggle('no-sidebar');
  localStorage.setItem('weatherSidebarHidden', hidden ? '1' : '0');
  syncSidebarButton();
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

// Карта грузит свои файлы сама и молча: она украшение поверх тех же данных,
// её отсутствие не должно мешать редактору работать.
document.addEventListener('wmap:rebuilt', () => {
  renderZoneCard();
  renderMapStates();
});

WeatherMap.init().then(() => {
  renderZoneCard();
  renderMapStates();
});
load(false);
