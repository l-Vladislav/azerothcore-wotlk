'use strict';

// Home page: server status tiles + the module grid. Modules come from
// app/registry.py, so adding one there is enough to make it show up here.

const ICONS = {
  weather: '🌩', pet: '🐾', skull: '💀', tree: '🌳', 'arrow-up': '⬆',
  loot: '🎒', sparkle: '✨', shirt: '👕', chat: '💬', bot: '🤖',
  hammer: '🔨', cube: '📦',
};

function statusTile(label, value, ok, hint) {
  const t = el('div', 'tile ' + (ok === undefined ? '' : (ok ? 'ok' : 'bad')));
  t.appendChild(el('div', 'tile-label', label));
  t.appendChild(el('div', 'tile-value', value));
  if (hint) t.appendChild(el('div', 'tile-hint', hint));
  return t;
}

async function loadHealth() {
  const box = document.getElementById('health');
  const tiles = document.getElementById('status-tiles');
  box.innerHTML = '';
  tiles.innerHTML = '';
  let h;
  try {
    h = await api('/api/health');
  } catch (e) {
    box.appendChild(el('span', 'bad', 'панель недоступна'));
    return;
  }

  const add = (label, ok, title) => {
    const s = el('span', ok ? 'good' : 'bad', label);
    if (title) s.title = title;
    box.appendChild(s);
  };
  add(h.schema, h.db && h.db.ok, h.db && h.db.error);
  add(h.soap && h.soap.ok ? 'SOAP' : 'SOAP ✕', h.soap && h.soap.ok,
      h.soap && h.soap.error);

  const db = h.db || {};
  const brd = h.board || {};
  tiles.appendChild(statusTile('База данных', db.ok ? 'на связи' : 'нет связи',
    !!db.ok, h.schema + (db.ok ? '' : ' — ' + (db.error || ''))));
  tiles.appendChild(statusTile('Worldserver (SOAP)',
    h.soap && h.soap.ok ? 'отвечает' : 'молчит', !!(h.soap && h.soap.ok),
    (h.soap && (h.soap.host || h.soap.error)) || ''));
  tiles.appendChild(statusTile('Правил окружения',
    db.ok ? String(db.rules) : '—', db.ok, h.zones_known + ' зон в справочнике'));
  const dex = h.dex || {};
  const dexTile = statusTile('Каталог спеллов',
    dex.ok ? 'доступен' : 'нет DBC', !!dex.ok,
    dex.ok ? 'все спеллы сервера: DBC + spell_dbc' : (dex.dir || ''));
  if (dex.ok) {
    dexTile.classList.add('clickable');
    dexTile.addEventListener('click', () => { location.href = '/dex.html'; });
  }
  tiles.appendChild(dexTile);

  const boardTile = statusTile('Открыто на доске',
    brd.ok ? String(brd.open) : '—', brd.ok !== false,
    brd.ok ? ('всего карточек: ' + brd.total) : (brd.error || ''));
  boardTile.classList.add('clickable');
  boardTile.addEventListener('click', () => { location.href = '/board.html'; });
  tiles.appendChild(boardTile);

  if (!h.files_ok && (h.file_problems || []).length) {
    const warn = el('div', 'banner warn');
    warn.appendChild(el('strong', null, 'Проблемы с файлами: '));
    warn.appendChild(document.createTextNode(h.file_problems.join(' · ')));
    document.querySelector('.home').insertBefore(
      warn, document.getElementById('status-tiles'));
  }
}

function moduleCard(m) {
  // A div, not an <a>: the footer chips are links themselves, and anchors do
  // not nest. The whole tile still navigates on click when an editor exists.
  const card = el('div', 'card ' + m.status);
  if (m.status === 'ready') {
    card.classList.add('clickable');
    card.tabIndex = 0;
    card.addEventListener('click', () => { location.href = m.url; });
    card.addEventListener('keydown', e => {
      if (e.key === 'Enter') location.href = m.url;
    });
  }

  const head = el('div', 'card-head');
  head.appendChild(el('div', 'card-icon', ICONS[m.icon] || ICONS.cube));
  const titles = el('div', 'card-titles');
  titles.appendChild(el('div', 'card-name', m.name));
  titles.appendChild(el('div', 'card-state',
    m.status === 'ready' ? 'редактор готов' : 'редактора пока нет'));
  head.appendChild(titles);
  card.appendChild(head);

  card.appendChild(el('p', 'card-summary', m.summary));

  const foot = el('div', 'card-foot');
  for (const tag of m.tags) foot.appendChild(el('span', 'chip', tag));
  if (m.open_cards) {
    const b = el('a', 'chip cards-open', m.open_cards + ' в работе');
    b.href = '/board.html?module=' + encodeURIComponent(m.id);
    b.addEventListener('click', e => e.stopPropagation());
    foot.appendChild(b);
  }
  const file = el('a', 'chip ghost-chip', '＋ карточка');
  file.href = '/board.html?module=' + encodeURIComponent(m.id) + '&new=1';
  file.title = 'Завести баг или идею для этого модуля';
  file.addEventListener('click', e => e.stopPropagation());
  foot.appendChild(file);
  card.appendChild(foot);
  return card;
}

async function loadModules() {
  const box = document.getElementById('module-cards');
  const hint = document.getElementById('modules-hint');
  try {
    const mods = await api('/api/modules');
    box.innerHTML = '';
    const ready = mods.filter(m => m.status === 'ready').length;
    hint.textContent = `${mods.length} модулей, редакторов готово: ${ready}. ` +
      'Для остальных пока можно вести задачи на доске.';
    for (const m of mods) box.appendChild(moduleCard(m));
  } catch (e) {
    hint.textContent = 'Не удалось загрузить список модулей: ' + e.message;
  }
}

loadHealth();
loadModules();
