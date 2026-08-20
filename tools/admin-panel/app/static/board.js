'use strict';

// Kanban board over /api/board/*. Drag-and-drop is plain HTML5 DnD: a drop
// sends one /move with the target column and the index it landed on, and the
// server answers with the whole board so the two never drift apart.

const COLUMNS = [
  ['backlog', 'Идеи / бэклог'],
  ['todo', 'К работе'],
  ['doing', 'В работе'],
  ['review', 'На проверке'],
  ['done', 'Готово'],
];

const KINDS = [['bug', '🐞 Баг'], ['feature', '💡 Идея'], ['task', '🔧 Задача']];
const PRIORITIES = [[0, 'Низкий'], [1, 'Обычный'], [2, 'Высокий'], [3, 'Критично']];

let cards = [];
let modules = [];
let filters = { q: '', module: '', kind: '', archived: false };
let editing = null;      // card object, or {} for a new one
let dragId = null;

const kindLabel = k => (KINDS.find(x => x[0] === k) || [, k])[1];
const moduleName = id => (modules.find(m => m.id === id) || {}).name || id;

// --- data -----------------------------------------------------------------

async function load() {
  const p = new URLSearchParams();
  if (filters.q) p.set('q', filters.q);
  if (filters.module) p.set('module', filters.module);
  if (filters.kind) p.set('kind', filters.kind);
  if (filters.archived) p.set('archived', 'true');
  cards = await api('/api/board/cards?' + p.toString());
  render();
}

// --- rendering ------------------------------------------------------------

function cardNode(card) {
  const n = el('div', 'tcard p' + card.priority + ' k-' + card.kind);
  n.draggable = !filters.archived;
  n.dataset.id = card.id;

  const head = el('div', 'tcard-head');
  head.appendChild(el('span', 'tcard-kind', kindLabel(card.kind).split(' ')[0]));
  head.appendChild(el('span', 'tcard-id', '#' + card.id));
  if (card.priority >= 2) {
    head.appendChild(el('span', 'chip prio p' + card.priority,
      card.priority === 3 ? 'критично' : 'высокий'));
  }
  n.appendChild(head);

  n.appendChild(el('div', 'tcard-title', card.title));

  const foot = el('div', 'tcard-foot');
  if (card.module) foot.appendChild(el('span', 'chip', moduleName(card.module)));
  for (const t of card.tags) foot.appendChild(el('span', 'chip ghost-chip', t));
  if (card.assignee) foot.appendChild(el('span', 'chip', '@' + card.assignee));
  if (card.comments) foot.appendChild(el('span', 'chip ghost-chip',
    '💬 ' + card.comments));
  n.appendChild(foot);

  n.addEventListener('click', () => openCard(card.id));
  n.addEventListener('dragstart', e => {
    dragId = card.id;
    n.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', String(card.id));
  });
  n.addEventListener('dragend', () => {
    dragId = null;
    n.classList.remove('dragging');
  });
  return n;
}

function dropIndex(listNode, y) {
  // Index the dragged card would take: count the cards whose midpoint is above
  // the pointer, ignoring the card being dragged.
  let index = 0;
  for (const node of listNode.querySelectorAll('.tcard')) {
    if (node.classList.contains('dragging')) continue;
    const box = node.getBoundingClientRect();
    if (y > box.top + box.height / 2) index++;
  }
  return index;
}

function render() {
  const board = document.getElementById('board');
  board.innerHTML = '';
  if (filters.archived) board.classList.add('archived');
  else board.classList.remove('archived');

  for (const [status, label] of COLUMNS) {
    const col = el('section', 'col');
    const inCol = cards.filter(c => c.status === status);

    const head = el('div', 'col-head');
    head.appendChild(el('span', 'col-name', label));
    head.appendChild(el('span', 'col-count', String(inCol.length)));
    const add = el('button', 'btn ghost tiny', '＋');
    add.title = 'Новая карточка в этой колонке';
    add.addEventListener('click', () => newCard(status));
    head.appendChild(add);
    col.appendChild(head);

    const list = el('div', 'col-list');
    list.dataset.status = status;
    for (const c of inCol) list.appendChild(cardNode(c));
    if (!inCol.length) list.appendChild(el('div', 'col-empty', 'пусто'));

    list.addEventListener('dragover', e => {
      if (dragId === null) return;
      e.preventDefault();
      list.classList.add('over');
    });
    list.addEventListener('dragleave', () => list.classList.remove('over'));
    list.addEventListener('drop', async e => {
      e.preventDefault();
      list.classList.remove('over');
      const id = dragId;
      if (id === null) return;
      const position = dropIndex(list, e.clientY);
      try {
        cards = await api(`/api/board/cards/${id}/move`, {
          method: 'POST',
          body: JSON.stringify({ status, position }),
        });
        // The move endpoint answers with the unfiltered board; re-apply the
        // active filters rather than showing rows the user filtered out.
        if (filters.q || filters.module || filters.kind) await load();
        else render();
      } catch (err) {
        toast(err.message, 'err');
      }
    });

    col.appendChild(list);
    board.appendChild(col);
  }
}

// --- card modal -----------------------------------------------------------

function field(label, node) {
  const wrap = el('label', 'field');
  wrap.appendChild(el('span', 'field-label', label));
  wrap.appendChild(node);
  return wrap;
}

function pick(options, value) {
  const s = el('select', 'sel');
  for (const [v, label] of options) {
    const o = el('option', null, label);
    o.value = String(v);
    if (String(v) === String(value)) o.selected = true;
    s.appendChild(o);
  }
  return s;
}

function newCard(status) {
  editing = {
    kind: 'bug', status: status || 'backlog', priority: 1, title: '', body: '',
    module: filters.module || '', tags: [], author: '', assignee: '',
  };
  renderModal();
}

async function openCard(id) {
  try {
    editing = await api('/api/board/cards/' + id);
    renderModal();
  } catch (e) {
    toast(e.message, 'err');
  }
}

function renderModal() {
  const box = document.getElementById('card-form');
  box.innerHTML = '';
  const c = editing;
  const isNew = !c.id;

  document.getElementById('card-modal-title').textContent =
    isNew ? 'Новая карточка' : `#${c.id} · ${kindLabel(c.kind)}`;
  document.getElementById('card-delete').classList.toggle('hidden', isNew);
  document.getElementById('card-delete').textContent =
    c.archived ? 'Вернуть из архива' : 'В архив';
  document.getElementById('card-meta').textContent = isNew ? '' :
    `создано ${c.created_at} · изменено ${c.updated_at}`;

  const title = el('input', 'input');
  title.value = c.title;
  title.placeholder = 'Коротко: что сломано или что хочется';
  title.addEventListener('input', () => { c.title = title.value; });
  box.appendChild(field('Заголовок', title));

  const row = el('div', 'form-row');
  const kind = pick(KINDS, c.kind);
  kind.addEventListener('change', () => { c.kind = kind.value; });
  row.appendChild(field('Тип', kind));

  const prio = pick(PRIORITIES, c.priority);
  prio.addEventListener('change', () => { c.priority = Number(prio.value); });
  row.appendChild(field('Приоритет', prio));

  const status = pick(COLUMNS, c.status);
  status.addEventListener('change', () => { c.status = status.value; });
  row.appendChild(field('Колонка', status));

  const mod = pick([['', '— без модуля —']].concat(
    modules.map(m => [m.id, m.name])), c.module);
  mod.addEventListener('change', () => { c.module = mod.value; });
  row.appendChild(field('Модуль', mod));
  box.appendChild(row);

  const body = el('textarea', 'input area');
  body.rows = 10;
  body.value = c.body || '';
  body.placeholder = 'Шаги воспроизведения, ожидаемое поведение, ссылки, ' +
    'id спеллов/предметов…';
  body.addEventListener('input', () => { c.body = body.value; });
  box.appendChild(field('Описание', body));

  const row2 = el('div', 'form-row');
  const tags = el('input', 'input');
  tags.value = (c.tags || []).join(', ');
  tags.placeholder = 'через запятую';
  tags.addEventListener('input', () => {
    c.tags = tags.value.split(',').map(s => s.trim()).filter(Boolean);
  });
  row2.appendChild(field('Теги', tags));

  const who = el('input', 'input');
  who.value = c.assignee || '';
  who.placeholder = 'кто делает';
  who.addEventListener('input', () => { c.assignee = who.value; });
  row2.appendChild(field('Исполнитель', who));
  box.appendChild(row2);

  if (!isNew) {
    const cbox = el('div', 'comments');
    cbox.appendChild(el('div', 'field-label', 'Комментарии'));
    for (const cm of (c.comments || [])) {
      const n = el('div', 'comment');
      n.appendChild(el('div', 'comment-meta',
        (cm.author || 'аноним') + ' · ' + cm.created_at));
      n.appendChild(el('div', 'comment-body', cm.body));
      cbox.appendChild(n);
    }
    const input = el('textarea', 'input area');
    input.rows = 2;
    input.placeholder = 'Добавить комментарий (Ctrl+Enter)';
    input.addEventListener('keydown', async e => {
      if (e.key !== 'Enter' || !(e.ctrlKey || e.metaKey)) return;
      const text = input.value.trim();
      if (!text) return;
      try {
        editing = await api(`/api/board/cards/${c.id}/comments`, {
          method: 'POST', body: JSON.stringify({ body: text }),
        });
        renderModal();
        load();
      } catch (err) { toast(err.message, 'err'); }
    });
    cbox.appendChild(input);
    box.appendChild(cbox);
  }

  document.getElementById('card-modal').classList.remove('hidden');
  title.focus();
}

function closeModal() {
  editing = null;
  document.getElementById('card-modal').classList.add('hidden');
}

async function saveCard() {
  const c = editing;
  if (!c || !c.title.trim()) { toast('Нужен заголовок.', 'err'); return; }
  const payload = {
    kind: c.kind, status: c.status, priority: c.priority,
    title: c.title.trim(), body: c.body || '', module: c.module || '',
    tags: c.tags || [], assignee: c.assignee || '',
  };
  try {
    if (c.id) {
      await api('/api/board/cards/' + c.id,
        { method: 'PATCH', body: JSON.stringify(payload) });
    } else {
      await api('/api/board/cards',
        { method: 'POST', body: JSON.stringify(payload) });
    }
    closeModal();
    await load();
    toast('Сохранено.', 'ok');
  } catch (e) {
    toast(e.message, 'err');
  }
}

async function archiveCard() {
  const c = editing;
  if (!c || !c.id) return;
  try {
    if (c.archived) await api(`/api/board/cards/${c.id}/restore`, { method: 'POST' });
    else await api('/api/board/cards/' + c.id, { method: 'DELETE' });
    closeModal();
    await load();
    toast(c.archived ? 'Возвращено на доску.' : 'В архиве.', 'ok');
  } catch (e) {
    toast(e.message, 'err');
  }
}

// --- wiring ---------------------------------------------------------------

function debounce(fn, ms) {
  let t = null;
  return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
}

async function init() {
  const meta = await api('/api/board/meta');
  modules = meta.modules;

  const sel = document.getElementById('f-module');
  sel.appendChild(new Option('Все модули', ''));
  for (const m of modules) sel.appendChild(new Option(m.name, m.id));

  const params = new URLSearchParams(location.search);
  if (params.get('module')) {
    filters.module = params.get('module');
    sel.value = filters.module;
  }

  sel.addEventListener('change', () => {
    filters.module = sel.value;
    load();
  });
  document.getElementById('f-kind').addEventListener('change', e => {
    filters.kind = e.target.value;
    load();
  });
  document.getElementById('q').addEventListener('input', debounce(e => {
    filters.q = e.target.value.trim();
    load();
  }, 250));
  document.getElementById('btn-archive').addEventListener('click', e => {
    filters.archived = !filters.archived;
    e.target.classList.toggle('active', filters.archived);
    e.target.textContent = filters.archived ? 'На доску' : 'Архив';
    load();
  });
  document.getElementById('btn-new').addEventListener('click', () => newCard());
  document.getElementById('card-close').addEventListener('click', closeModal);
  document.getElementById('card-save').addEventListener('click', saveCard);
  document.getElementById('card-delete').addEventListener('click', archiveCard);
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && editing) closeModal();
  });

  await load();
  if (params.get('new')) newCard();
}

init().catch(e => toast(e.message, 'err'));
