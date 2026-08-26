// Мировые предметы: присмотр за тем, что уже разложено по карте.
//
// Правки уходят по одной строке, а не общей кнопкой «Сохранить всё»: строк
// здесь немного, зато каждая — живой объект в мире, и массовое сохранение
// означало бы «я нажал не туда, и поехало всё сразу».

let ROWS = [];
let ICON_BASE = '';

const BLANK_ICON =
  'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

function iconUrl(t) { return (t && ICON_BASE) ? `${ICON_BASE}/${t}.jpg` : BLANK_ICON; }

function itemCell(row) {
  const box = el('div', 'item-cell');

  const img = el('img');
  img.loading = 'lazy';
  img.src = iconUrl(row.item_icon);
  img.addEventListener('error', () => { img.src = BLANK_ICON; }, { once: true });
  box.appendChild(img);

  const nm = el('div', 'nm');
  if (row.item_missing) {
    // Предмет удалили, а размещение осталось — сундук будет пуст, и понять
    // почему, глядя в игру, невозможно. Поэтому кричим прямо в списке.
    nm.appendChild(el('b', 'warn', `предмета ${row.item_entry} больше нет`));
  } else {
    nm.appendChild(el('b', 'q' + row.item_quality, row.item_name));
  }
  nm.appendChild(el('small', null,
    `id ${row.item_entry}` + (row.item_block ? ` · ${row.item_block}` : '')));
  box.appendChild(nm);
  return box;
}

function numInput(row, col, min) {
  const input = el('input');
  input.type = 'number';
  input.value = row[col];
  if (min !== undefined) input.min = min;
  input.addEventListener('change', () => {
    save(row.id, { [col]: parseInt(input.value, 10) || 0 });
  });
  return input;
}

function checkbox(row, col) {
  const input = el('input');
  input.type = 'checkbox';
  input.checked = !!row[col];
  input.addEventListener('change', () => {
    save(row.id, { [col]: input.checked ? 1 : 0 });
  });
  return input;
}

function render() {
  const view = document.getElementById('view');
  view.innerHTML = '';

  if (!ROWS.length) {
    view.appendChild(el('div', 'empty',
      'Ничего не разложено. Поставьте объект в игре и выполните ' +
      '".rc go item <id предмета>".'));
    document.getElementById('count').textContent = '';
    return;
  }

  const table = el('table', 'grid');
  const head = el('tr');
  ['#', 'Предмет', 'Кол-во', 'Оболочка', 'Где', 'Один раз', 'Респавн, с',
   'Вкл', 'Забрали', 'Комментарий', 'Поставил', ''].forEach(h => {
    head.appendChild(el('th', null, h));
  });
  table.appendChild(head);

  ROWS.forEach(row => {
    const tr = el('tr', row.enabled ? '' : 'off');

    tr.appendChild(el('td', null, String(row.id)));
    tr.appendChild(el('td')).appendChild(itemCell(row));

    const count = el('td', 'num');
    count.appendChild(numInput(row, 'item_count', 1));
    tr.appendChild(count);

    tr.appendChild(el('td', null, `${row.go_entry} / guid ${row.go_guid ?? '—'}`));
    tr.appendChild(el('td', null,
      `карта ${row.map}, зона ${row.zone}\n` +
      row.pos.map(v => v.toFixed(1)).join(' ')));

    const once = el('td');
    once.appendChild(checkbox(row, 'one_per_char'));
    tr.appendChild(once);

    const resp = el('td', 'num');
    resp.appendChild(numInput(row, 'respawn_secs', 0));
    tr.appendChild(resp);

    const on = el('td');
    on.appendChild(checkbox(row, 'enabled'));
    tr.appendChild(on);

    // null — счётчик недоступен (база персонажей молчит). Показываем это
    // как «?», а не как 0: ноль здесь читался бы как «никто не забирал».
    tr.appendChild(el('td', null,
      row.looted_by === null || row.looted_by === undefined
        ? '?' : String(row.looted_by)));

    const comment = el('td');
    const ci = el('input');
    ci.type = 'text';
    ci.value = row.comment;
    ci.addEventListener('change', () => save(row.id, { comment: ci.value }));
    comment.appendChild(ci);
    tr.appendChild(comment);

    tr.appendChild(el('td', null, row.created_by || '—'));

    const act = el('td', 'act');
    const reset = el('button', 'btn ghost', 'Забыть');
    reset.title = 'Забыть, кто это подобрал — предмет снова станет им виден. ' +
                  'Нужно после смены привязанного предмета.';
    reset.addEventListener('click', () => resetLoot(row.id));
    act.appendChild(reset);

    const del = el('button', 'btn ghost', 'Удалить');
    del.title = 'Убрать размещение. Сам объект останется стоять в мире — ' +
                'им распоряжается ядро, снимать его надо там же, где ставили.';
    del.addEventListener('click', () => remove(row.id));
    act.appendChild(del);
    tr.appendChild(act);

    table.appendChild(tr);
  });

  view.appendChild(table);
  document.getElementById('count').textContent = `${ROWS.length} размещений`;
}

async function load() {
  const view = document.getElementById('view');
  view.innerHTML = '<div class="empty">Загрузка…</div>';
  const only = document.getElementById('only-on').checked;
  try {
    const res = await api('/api/worlditems?only_enabled=' + (only ? 'true' : 'false'));
    ROWS = res.items;
    render();
  } catch (e) {
    view.innerHTML = '';
    view.appendChild(el('div', 'empty', e.message));
  }
}

async function save(id, fields) {
  try {
    const row = await api('/api/worlditems/' + id, {
      method: 'PATCH', body: JSON.stringify({ fields }),
    });
    ROWS = ROWS.map(r => (r.id === id ? row : r));
    render();
    toast('Сохранено.', 'ok');
  } catch (e) { toast(e.message, 'err'); load(); }
}

async function resetLoot(id) {
  if (!confirm('Забыть всех, кто подобрал это размещение?')) return;
  try {
    const res = await api(`/api/worlditems/${id}/reset-loot`, { method: 'POST' });
    toast(`Забыто записей: ${res.forgotten}.`, 'ok');
    load();
  } catch (e) { toast(e.message, 'err'); }
}

async function remove(id) {
  if (!confirm(`Удалить размещение ${id}? Объект останется стоять в мире.`)) return;
  try {
    await api('/api/worlditems/' + id, { method: 'DELETE' });
    load();
  } catch (e) { toast(e.message, 'err'); }
}

async function boot() {
  await mountSession();
  try {
    ICON_BASE = (await api('/api/worlditems/meta')).icon_base_url || '';
  } catch (e) { /* иконки — не повод не показать список */ }

  document.getElementById('only-on').addEventListener('change', load);
  document.getElementById('btn-reload').addEventListener('click', load);
  load();
}

boot();
