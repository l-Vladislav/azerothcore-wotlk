// Каталог предметов: поиск по item_template, копии в блоках панели, правка.
//
// Форма не описана здесь ни одним полем — её присылает сервер
// (`/api/items/meta` → groups). Добавить поле в редактор значит дописать одну
// строку в FIELD_GROUPS на бэкенде, а не править этот файл. То же решение, что
// в мастерской спеллов, и по той же причине: полей у предмета сотня, и держать
// их список в двух местах — гарантированно развести их со временем.

let META = null;          // { blocks, groups, enums, icon_base_url }
let BLOCK = 'custom';     // выбранный фильтр списка
let PAGE = 0;
const PAGE_SIZE = 60;
let TOTAL = 0;
let CURRENT = null;       // { entry, block, icon, fields } — то, что в редакторе
let DIRTY = false;

const BLANK_ICON =
  'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

function iconUrl(texture) {
  if (!texture || !META || !META.icon_base_url) return BLANK_ICON;
  return `${META.icon_base_url}/${texture}.jpg`;
}

function iconImg(texture, cls) {
  const img = el('img', cls || 'ic');
  img.loading = 'lazy';
  img.alt = '';
  img.src = iconUrl(texture);
  img.addEventListener('error', () => { img.src = BLANK_ICON; }, { once: true });
  return img;
}

// --- список ---------------------------------------------------------------

function blockLabel(id) {
  if (!id) return '';
  const blk = (META.blocks || []).find(b => b.id === id);
  return blk ? blk.name : id;
}

function renderBlocks() {
  const box = document.getElementById('blocks');
  box.innerHTML = '';

  const choices = [{ id: '', name: 'Все' }, { id: 'custom', name: 'Только наши' }]
    .concat(META.blocks.map(b => ({ id: b.id, name: b.name, blk: b })));

  choices.forEach(ch => {
    const btn = el('button', 'btn ghost' + (BLOCK === ch.id ? ' on' : ''), ch.name);
    if (ch.blk) {
      btn.title = `${ch.blk.summary}\n${ch.blk.lo}–${ch.blk.hi}: ` +
                  `занято ${ch.blk.used}, свободно ${ch.blk.free}`;
    }
    btn.addEventListener('click', () => {
      BLOCK = ch.id;
      PAGE = 0;
      renderBlocks();
      loadList();
    });
    box.appendChild(btn);
  });
}

async function loadList() {
  const rows = document.getElementById('rows');
  rows.innerHTML = '<div class="empty">Загрузка…</div>';

  const q = document.getElementById('q').value.trim();
  const params = new URLSearchParams({
    q, limit: PAGE_SIZE, offset: PAGE * PAGE_SIZE,
  });
  if (BLOCK) params.set('block', BLOCK);

  let res;
  try {
    res = await api('/api/items?' + params.toString());
  } catch (e) {
    rows.innerHTML = '';
    rows.appendChild(el('div', 'empty', e.message));
    return;
  }

  TOTAL = res.total;
  rows.innerHTML = '';
  if (!res.items.length) {
    rows.appendChild(el('div', 'empty', q ? 'Ничего не найдено.' : 'Пусто.'));
  }

  res.items.forEach(item => {
    const row = el('div', 'row' + (CURRENT && CURRENT.entry === item.entry ? ' sel' : ''));
    row.appendChild(iconImg(item.icon));

    const nm = el('div', 'nm');
    const title = el('b', 'q' + item.quality, item.name_ru || item.name);
    nm.appendChild(title);
    // Русское имя показываем первым, базовое — второй строкой: искать глазами
    // проще по тому, что видно в игре.
    nm.appendChild(el('small', null,
      `${item.entry} · ур. ${item.item_level}` +
      (item.name_ru && item.name_ru !== item.name ? ` · ${item.name}` : '')));
    row.appendChild(nm);

    if (item.block) row.appendChild(el('span', 'tag', blockLabel(item.block)));

    row.addEventListener('click', () => openItem(item.entry));
    rows.appendChild(row);
  });

  const pages = Math.max(1, Math.ceil(TOTAL / PAGE_SIZE));
  document.getElementById('page-info').textContent =
    TOTAL ? `${PAGE + 1} / ${pages}  ·  ${TOTAL} шт.` : '—';
}

// --- редактор -------------------------------------------------------------

function fieldInput(field, value) {
  const wrap = el('div', 'fld' + (field.width === 'wide' ? ' wide' : ''));
  const label = el('label', null, field.label);
  if (field.hint) label.appendChild(helpBadge(field.hint));
  wrap.appendChild(label);

  let input;
  if (field.kind === 'enum' && META.enums[field.options]) {
    input = el('select');
    META.enums[field.options].forEach(opt => {
      const o = el('option', null, `${opt.label} (${opt.value})`);
      o.value = opt.value;
      input.appendChild(o);
    });
    // Значение может быть вне справочника (подклассов у предмета десятки, а в
    // списке только ходовые) — тогда добавляем его как есть, чтобы правка
    // соседнего поля его не затёрла.
    if (![...input.options].some(o => Number(o.value) === Number(value))) {
      const o = el('option', null, String(value));
      o.value = value;
      input.appendChild(o);
    }
    input.value = value;
  } else if (field.kind === 'text') {
    input = el('input');
    input.type = 'text';
    input.value = value === null || value === undefined ? '' : value;
  } else {
    input = el('input');
    input.type = 'number';
    if (field.kind === 'float') input.step = '0.01';
    input.value = value === null || value === undefined ? 0 : value;
  }

  input.dataset.col = field.col;
  input.dataset.kind = field.kind;
  input.addEventListener('input', () => { DIRTY = true; });
  if (CURRENT && !CURRENT.block) input.disabled = true;   // стоковый — только чтение

  wrap.appendChild(input);
  return wrap;
}

function renderEditor() {
  const box = document.getElementById('editor');
  box.innerHTML = '';

  if (!CURRENT) {
    box.appendChild(el('div', 'empty', 'Выберите предмет слева.'));
    return;
  }

  const f = CURRENT.fields;
  const head = el('div', 'edit-head');
  head.appendChild(iconImg(CURRENT.icon, 'ic'));

  const title = el('div');
  title.appendChild(el('h2', 'q' + (f.Quality || 0), f.name_ru || f.name || '—'));
  title.appendChild(el('div', 'sub',
    `id ${CURRENT.entry}` +
    (CURRENT.block ? ` · ${blockLabel(CURRENT.block)}` : ' · стоковый') +
    (CURRENT.source ? ` · копия ${CURRENT.source}` : '')));
  head.appendChild(title);

  const actions = el('div', 'actions');

  // Копировать можно что угодно, править — только своё. Поэтому кнопка копии
  // есть всегда, а сохранение появляется лишь у предметов из блоков панели.
  META.blocks.forEach(blk => {
    const btn = el('button', 'btn ghost', `Копия → ${blk.name}`);
    btn.title = `${blk.summary}\nСвободных id: ${blk.free}`;
    btn.addEventListener('click', () => cloneInto(blk.id));
    actions.appendChild(btn);
  });

  if (CURRENT.block) {
    const save = el('button', 'btn', CURRENT.draft ? 'Создать' : 'Сохранить');
    save.addEventListener('click', saveItem);
    actions.appendChild(save);

    if (!CURRENT.draft) {
      const client = el('button', 'btn ghost', 'Строка для Item.dbc');
      client.addEventListener('click', showClientRow);
      actions.appendChild(client);

      const del = el('button', 'btn ghost', 'Удалить');
      del.addEventListener('click', deleteItem);
      actions.appendChild(del);
    }
  }
  head.appendChild(actions);
  box.appendChild(head);

  if (!CURRENT.block) {
    box.appendChild(el('p', 'note ro',
      'Стоковый предмет — только чтение. Правка стоковых строк разошлась бы ' +
      'с базой ядра молча: следующий импорт мира её затрёт, и откуда взялось ' +
      'расхождение, уже не вспомнить. Сделайте копию.'));
  }

  const groups = el('div', 'groups');
  META.groups.forEach(group => {
    const g = el('div', 'group');
    g.appendChild(el('h3', null, group.name));
    const body = el('div', 'group-body');

    group.rows.forEach(row => {
      const line = el('div', 'frow');
      if (row.label) line.appendChild(el('div', 'rl', row.label));
      row.fields.forEach(field => {
        line.appendChild(fieldInput(field, f[field.col]));
      });
      body.appendChild(line);
    });

    g.appendChild(body);
    groups.appendChild(g);
  });
  box.appendChild(groups);
}

function collect() {
  const out = {};
  document.querySelectorAll('#editor [data-col]').forEach(input => {
    const kind = input.dataset.kind;
    let value = input.value;
    if (kind === 'int' || kind === 'enum') value = parseInt(value, 10) || 0;
    else if (kind === 'float') value = parseFloat(value) || 0;
    out[input.dataset.col] = value;
  });
  return out;
}

async function openItem(entry) {
  if (DIRTY && !confirm('Несохранённые правки пропадут. Продолжить?')) return;
  try {
    CURRENT = await api('/api/items/' + entry);
    CURRENT.draft = false;
    DIRTY = false;
    renderEditor();
    loadList();
  } catch (e) { toast(e.message, 'err'); }
}

async function cloneInto(blockId) {
  const source = CURRENT ? CURRENT.entry : null;
  if (!source) return;
  try {
    const draft = await api(`/api/items/clone/${source}?block=${blockId}`);
    CURRENT = draft;
    CURRENT.draft = true;      // ещё не в базе: сохранение создаст строку
    DIRTY = true;
    renderEditor();
    toast(`Черновик копии: id ${draft.entry}. Нажмите «Создать».`, 'ok');
  } catch (e) { toast(e.message, 'err'); }
}

async function saveItem() {
  if (!CURRENT || !CURRENT.block) return;
  try {
    const saved = await api('/api/items/' + CURRENT.entry, {
      method: 'PUT',
      body: JSON.stringify({ fields: collect() }),
    });
    CURRENT = saved;
    CURRENT.draft = false;
    DIRTY = false;
    renderEditor();
    await refreshBlocks();
    loadList();
    toast('Сохранено.', 'ok');
  } catch (e) { toast(e.message, 'err'); }
}

async function deleteItem() {
  if (!CURRENT || !CURRENT.block) return;
  if (!confirm(`Удалить предмет ${CURRENT.entry}? Если он где-то лежит в мире, ` +
               'размещение останется без предмета.')) return;
  try {
    await api('/api/items/' + CURRENT.entry, { method: 'DELETE' });
    CURRENT = null;
    DIRTY = false;
    renderEditor();
    await refreshBlocks();
    loadList();
    toast('Удалено.', 'ok');
  } catch (e) { toast(e.message, 'err'); }
}

// Клиентская половина: строка для Item.dbc внутри MPQ. Без неё предмет не
// получит трёхмерного вида на персонаже — тултип и иконку клиент спрашивает у
// сервера, а вид, ножны и материал берёт из своей DBC.
async function showClientRow() {
  if (!CURRENT) return;
  try {
    const row = await api(`/api/items/${CURRENT.entry}/client-row`);
    const box = document.getElementById('editor');
    const old = box.querySelector('.client-row-wrap');
    if (old) old.remove();

    const wrap = el('div', 'client-row-wrap');
    wrap.appendChild(el('p', 'note',
      'Строка для Item.dbc внутри MPQ. Скопируйте в Item_custom.csv и ' +
      'пересоберите патч — сборка MPQ остаётся ручной.'));
    wrap.appendChild(el('pre', 'client-row', row.header + '\n' + row.line));
    box.insertBefore(wrap, box.querySelector('.groups'));
  } catch (e) { toast(e.message, 'err'); }
}

async function refreshBlocks() {
  try {
    META.blocks = (await api('/api/items/meta')).blocks;
    renderBlocks();
  } catch (e) { /* занятость блоков — не повод падать */ }
}

// --- запуск ---------------------------------------------------------------

async function boot() {
  await mountSession();
  try {
    META = await api('/api/items/meta');
  } catch (e) {
    document.getElementById('rows').innerHTML = '';
    document.getElementById('rows').appendChild(el('div', 'empty', e.message));
    return;
  }

  if (!META.icons_available) {
    toast('Иконки недоступны: не примонтирован client-data.', 'warn');
  }

  renderBlocks();
  renderEditor();
  loadList();

  const q = document.getElementById('q');
  // Дебаунс, а не поиск на каждую букву: запрос уходит в таблицу на 277 тысяч
  // строк с LIKE, и держать её под непрерывной нагрузкой незачем.
  let timer = null;
  q.addEventListener('input', () => {
    clearTimeout(timer);
    timer = setTimeout(() => { PAGE = 0; loadList(); }, 350);
  });
  q.addEventListener('keydown', ev => {
    if (ev.key === 'Enter') { clearTimeout(timer); PAGE = 0; loadList(); }
  });

  document.getElementById('btn-find')
    .addEventListener('click', () => { PAGE = 0; loadList(); });
  document.getElementById('btn-prev').addEventListener('click', () => {
    if (PAGE > 0) { PAGE--; loadList(); }
  });
  document.getElementById('btn-next').addEventListener('click', () => {
    if ((PAGE + 1) * PAGE_SIZE < TOTAL) { PAGE++; loadList(); }
  });
  document.getElementById('btn-export').addEventListener('click', async () => {
    try {
      const res = await api('/api/items/export/sql', { method: 'POST' });
      toast(`Выгружено: ${res.items} предметов, ${res.locales} локалей.`, 'ok');
    } catch (e) { toast(e.message, 'err'); }
  });

  window.addEventListener('beforeunload', ev => {
    if (DIRTY) { ev.preventDefault(); ev.returnValue = ''; }
  });
}

boot();
