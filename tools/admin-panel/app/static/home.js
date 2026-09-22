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

// --- клиентский патч ------------------------------------------------------
// Кнопки сборки patch-ruRU-X.MPQ. Собирает не панель, а соседний контейнер
// ac-patch-builder (см. app/patch.py): у него есть StormLib и право писать в
// launcher/cdn. Раздела нет вовсе, если сборщик к панели не подключён -
// пустой ADMIN_PATCH_BUILDER_URL значит «в этой установке его не бывает».

const PATCH_CHECKS = {
  build_py: 'build.py',
  workdir: 'рабочий каталог',
  base_ready: 'база DBC',
  cdn: 'CDN',
  stormlib: 'StormLib',
};

// Сборка идёт минутами, поэтому страница опрашивает состояние, пока она
// живая, и перестаёт, как только та кончилась. Таймер один: его сбрасывает
// каждый заход в loadPatch, иначе два нажатия дали бы две цепочки опроса.
let patchTimer = null;

function patchTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleString('ru-RU');
}

async function patchPost(path, body, question) {
  if (question && !confirm(question)) return;
  try {
    await api(path, { method: 'POST', body: JSON.stringify(body) });
    toast('Сборщик принял команду.', 'ok');
  } catch (e) {
    toast(e.message, 'err');
  }
  loadPatch();
}

function patchStateLine(st) {
  const box = document.getElementById('patch-state');
  box.innerHTML = '';
  const add = (cls, text) => box.appendChild(el('span', cls, text));
  if (!st.reachable) {
    add('err', 'сборщик не отвечает');
    return;
  }
  if (st.running) {
    add('run', 'идёт сборка');
    add('cmd', st.command || '');
    add('muted', 'начата ' + patchTime(st.started));
    return;
  }
  if (!st.finished) {
    add('muted', 'сборка ни разу не запускалась');
    return;
  }
  add(st.code === 0 ? 'ok' : 'err',
      st.code === 0 ? 'успех' : 'код возврата ' + st.code);
  add('cmd', st.command || '');
  add('muted', 'завершена ' + patchTime(st.finished));
}

function patchActions(st) {
  const box = document.getElementById('patch-actions');
  box.innerHTML = '';
  const log = document.getElementById('patch-log');

  const add = (label, title, cls, fn) => {
    const b = el('button', 'btn ' + cls, label);
    b.title = title;
    b.addEventListener('click', () => fn(b));
    box.appendChild(b);
    return b;
  };

  if (can('owner')) {
    // Пока сборка идёт, вторая кнопка всё равно получит 409 от сборщика -
    // гасим их сами, чтобы отказ не выглядел поломкой.
    const off = st.running || !st.reachable;
    const build = (label, title, cls, body, question) => {
      const b = add(label, title, cls,
                    () => patchPost('/api/patch/build', body, question));
      b.disabled = off;
    };
    build('Проверить', 'build --dry-run: показать, что изменилось бы, ' +
          'ничего не записывая', '', { dry_run: true });
    build('Собрать и опубликовать',
          'build: архив, копия на CDN, пересборка манифеста', 'primary', {},
          'Собрать патч и выложить на CDN? Его скачают все игроки.');
    build('Собрать без публикации',
          'build --no-publish: архив собирается, CDN не трогаем', 'ghost',
          { no_publish: true });
    const boot = add('Снять базу заново',
                     'bootstrap --force: взять базу DBC из нынешних архивов ' +
                     'CDN. Нужно после смены самого клиента', 'ghost',
                     () => patchPost('/api/patch/bootstrap', { force: true },
                                     'Снять базу DBC заново с архивов CDN? ' +
                                     'Нынешняя база будет перезаписана.'));
    boot.disabled = off;
  } else {
    box.appendChild(el('span', 'hint', 'Сборку запускает владелец.'));
  }

  // Эти две работают всегда: посмотреть, что случилось, полезнее всего как
  // раз тогда, когда сборка сломалась или сборщик замолчал.
  add('Обновить', 'Перечитать состояние сборщика', 'ghost', () => loadPatch());
  add('Весь лог', 'Лог последней сборки целиком', 'ghost', async () => {
    try {
      log.textContent = (await api('/api/patch/log')) || '(лог пуст)';
      log.classList.remove('hidden');
    } catch (e) {
      toast(e.message, 'err');
    }
  });
}

function patchRender(st) {
  const hint = document.getElementById('patch-hint');
  const log = document.getElementById('patch-log');
  const health = st.health || {};

  if (!st.reachable) {
    hint.className = 'hint err';
    hint.textContent = st.error || 'Сборщик не отвечает.';
  } else {
    const missing = Object.keys(PATCH_CHECKS).filter(k => health[k] === false);
    hint.className = missing.length ? 'hint err' : 'hint';
    hint.textContent = missing.length
      ? ('Сборщику не хватает: ' +
         missing.map(k => PATCH_CHECKS[k]).join(', ') +
         (health.base_ready === false
           ? ' — начни со «Снять базу заново».' : ''))
      : 'Оверлеи .claude/dbc → patch-ruRU-X.MPQ → CDN. Игроки получат патч ' +
        'лаунчером при следующем запуске.';
  }

  patchStateLine(st);
  patchActions(st);

  const tail = st.log_tail || '';
  log.textContent = tail;
  log.classList.toggle('hidden', !tail);
}

async function loadPatch() {
  const box = document.getElementById('patch');
  if (!box) return;
  clearTimeout(patchTimer);
  let st;
  try {
    st = await api('/api/patch/status');
  } catch (e) {
    box.classList.add('hidden');
    return;
  }
  if (!st.configured) { box.classList.add('hidden'); return; }
  box.classList.remove('hidden');
  patchRender(st);
  if (st.running) patchTimer = setTimeout(loadPatch, 3000);
}

loadHealth();
loadModules();
// Ждём профиль: кнопки сборки видит только владелец, а can() до mountSession()
// врёт всем «нет».
mountSession().then(loadPatch);
