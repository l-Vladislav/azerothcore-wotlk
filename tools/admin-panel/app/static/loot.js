// Добыча: кто что роняет и где что падает. Заход первый — только чтение.
//
// Три вкладки отвечают на три разных вопроса, и разделены они именно поэтому,
// а не для красоты: «Моб» идёт сверху вниз (существо → его добыча), «Предмет»
// снизу вверх (предмет → все пути к нему), «Таблица» даёт сырой доступ к любой
// из тринадцати таблиц по номеру записи.
//
// Ссылка (`reference_loot_template`) рисуется вложенным узлом, а не строкой в
// общем списке: её шанс и шанс предмета внутри неё - два независимых броска, и
// поставленные рядом они читаются как один.

let META = null;
let TAB = 'creature';
const STATE = { creature: null, item: null, table: 'creature', entry: null };

const TABS = [
  ['creature', 'Моб'],
  ['item', 'Предмет'],
  ['table', 'Таблица'],
];

function qualityClass(q) { return 'q' + (q || 0); }

function itemName(item) {
  if (!item) return '—';
  return item.name_ru || item.name || ('предмет ' + item.entry);
}

// Шанс: 100 % пишем словом, чтобы взгляд не спотыкался о «100.0000».
function chanceText(value) {
  const n = Number(value) || 0;
  if (n >= 100) return 'всегда';
  if (n === 0) return '0 %';
  if (n < 0.01) return '<0.01 %';
  return (n < 1 ? n.toFixed(2) : n.toFixed(n < 10 ? 1 : 0)) + ' %';
}

function marks(row) {
  const box = el('div', 'marks');
  if (row.quest) {
    const m = el('span', 'mark quest', 'квест');
    m.title = 'Видно только тому, кто взял задание.';
    box.appendChild(m);
  }
  if (row.mode && row.mode !== 1) {
    const m = el('span', 'mark mode', row.mode_name);
    m.title = 'Режим сложности: в обычном подземелье такая строка не выпадет.';
    box.appendChild(m);
  }
  if (row.conditions && row.conditions.length) {
    const m = el('span', 'mark cond', 'условие ' + row.conditions.length);
    m.title = row.conditions.map(c => (c.Comment
      || ('тип ' + c.ConditionTypeOrReference + ' · ' + c.ConditionValue1))).join('\n');
    box.appendChild(m);
  }
  if (row.broken) {
    const m = el('span', 'mark bad', 'ссылка в никуда');
    m.title = 'Строка ссылается на запись, которой нет: выпасть из неё нечему.';
    box.appendChild(m);
  }
  return box;
}

// --- выбор предмета -------------------------------------------------------
//
// Двойник этих трёх функций живёт в aprof.js. Держим копию, а не общий модуль,
// сознательно: перенос в common.js трогал бы страницу профессий, которой
// сейчас пользуются, ради страницы, которую пишем. Придёт третий потребитель -
// вот тогда и переносить, разом и с прогоном обоих стендов.

const BLANK_ICON =
  'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

function iconUrl(texture) {
  return (texture && META && META.icon_base_url)
    ? `${META.icon_base_url}/${texture}.jpg` : BLANK_ICON;
}

function iconImg(texture, size) {
  const img = el('img', 'look-icon');
  img.width = size || 32;
  img.height = size || 32;
  img.src = iconUrl(texture);
  img.addEventListener('error', () => { img.src = BLANK_ICON; }, { once: true });
  return img;
}

function openItemPicker(opts, onPick) {
  const back = el('div', 'ap-modal-back');
  const box = el('div', 'ap-modal');
  back.appendChild(box);
  back.addEventListener('click', ev => { if (ev.target === back) back.remove(); });

  const head = el('div', 'row');
  head.appendChild(el('h2', null, opts.title || 'Выбор предмета'));
  const gap = el('span');
  gap.style.flex = '1';
  head.appendChild(gap);
  const closeBtn = el('button', 'btn ghost', 'Закрыть');
  closeBtn.addEventListener('click', () => back.remove());
  head.appendChild(closeBtn);
  box.appendChild(head);
  if (opts.hint) box.appendChild(el('p', 'hint', opts.hint));

  const bar = el('div', 'row');
  const q = el('input');
  q.type = 'search';
  q.placeholder = 'имя или id предмета';
  q.style.flex = '1';
  bar.appendChild(q);
  const only = pickSelect([['', 'везде'], ['custom', 'только свои'],
                           ['professions', 'только изделия профессий']], '');
  bar.appendChild(only);
  box.appendChild(bar);

  const list = el('div', 'look-grid');
  box.appendChild(list);
  document.body.appendChild(back);
  q.focus();

  let timer = null;
  async function search() {
    list.innerHTML = '';
    list.appendChild(el('div', 'muted', 'ищем…'));
    let data;
    try {
      const params = new URLSearchParams({ q: q.value, limit: '40' });
      if (only.value) params.set('block', only.value);
      data = await api('/api/items?' + params.toString());
    } catch (e) {
      list.innerHTML = '';
      list.appendChild(el('div', 'empty', e.message));
      return;
    }
    list.innerHTML = '';
    if (!data.items.length) {
      list.appendChild(el('div', 'empty', 'Ничего не нашлось.'));
      return;
    }
    data.items.forEach(item => {
      const cell = el('button', 'look-cell');
      cell.appendChild(iconImg(item.icon, 32));
      const nm = el('div', 'nm');
      nm.appendChild(el('b', 'q' + item.quality, item.name_ru || item.name));
      nm.appendChild(el('small', null, 'id ' + item.entry));
      cell.appendChild(nm);
      cell.addEventListener('click', () => { back.remove(); onPick(item.entry, item); });
      list.appendChild(cell);
    });
  }
  q.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(search, 250); });
  only.addEventListener('change', search);
  search();
}

function itemPickBox(opts) {
  const box = el('div', 'row');
  const label = el('span', 'muted', (opts && opts.empty) || 'не выбран');
  const pick = el('button', 'btn ghost', 'Выбрать');
  const clear = el('button', 'btn ghost', 'Убрать');
  clear.hidden = true;

  box.entry = 0;
  box.set = (entry, item) => {
    box.entry = entry || 0;
    const name = item && (item.name_ru || item.name);
    label.className = box.entry ? '' : 'muted';
    label.textContent = box.entry
      ? `${name || 'предмет'} · id ${box.entry}`
      : ((opts && opts.empty) || 'не выбран');
    pick.textContent = box.entry ? 'Сменить' : 'Выбрать';
    clear.hidden = !box.entry;
  };
  pick.addEventListener('click',
    () => openItemPicker(opts || {}, (entry, item) => box.set(entry, item)));
  clear.addEventListener('click', () => box.set(0));

  box.appendChild(label);
  box.appendChild(pick);
  box.appendChild(clear);
  return box;
}

// --- отбор и сортировка ---------------------------------------------------
//
// Тот же приём, что на странице профессий: строка поиска, выпадающие отборы и
// сортировка по клику на заголовок. Двойник этих функций живёт в aprof.js;
// когда их запросит третья страница, место им в common.js, а пока перенос
// значил бы трогать работающую страницу ради ещё не написанной.

const VIEW = {};

function viewState(tab) {
  if (!VIEW[tab]) VIEW[tab] = { q: '', pick: {}, sort: '', dir: 1 };
  return VIEW[tab];
}

// Числа сравниваем числами, строки - по-русски: иначе «Ё» уезжает в конец, а
// «10» встаёт перед «9».
function compareValues(a, b) {
  const an = typeof a === 'number', bn = typeof b === 'number';
  if (an && bn) return a - b;
  const as = a === null || a === undefined ? '' : String(a);
  const bs = b === null || b === undefined ? '' : String(b);
  return as.localeCompare(bs, 'ru');
}

function applyView(tab, items, spec) {
  const st = viewState(tab);
  let out = items;

  const q = st.q.trim().toLowerCase();
  if (q && spec.search) {
    out = out.filter(item => String(spec.search(item) || '').toLowerCase()
                                  .includes(q));
  }
  (spec.picks || []).forEach(pick => {
    const chosen = st.pick[pick.key];
    if (chosen === undefined || chosen === '') return;
    out = out.filter(item => pick.test
      ? pick.test(item, chosen)
      : String(pick.get(item)) === String(chosen));
  });

  const sorter = (spec.sorts || {})[st.sort];
  if (sorter) {
    out = out.slice().sort((a, b) => compareValues(sorter(a), sorter(b)) * st.dir);
  }
  return out;
}

function pickSelect(options, value, onChange) {
  const sel = el('select');
  options.forEach(([v, label]) => {
    const opt = el('option', null, label);
    opt.value = v;
    if (String(v) === String(value)) opt.selected = true;
    sel.appendChild(opt);
  });
  if (onChange) sel.addEventListener('change', () => onChange(sel.value));
  return sel;
}

function filterBar(tab, spec, total, shown) {
  const st = viewState(tab);
  const bar = el('div', 'filter-bar');

  if (spec.search) {
    const search = el('input');
    search.type = 'search';
    search.className = 'filter-q';
    search.placeholder = spec.placeholder || 'поиск';
    search.value = st.q;
    // Значение уже в состоянии, поэтому перерисовка его не теряет; фокус
    // возвращаем руками, иначе он уезжает после первой же буквы.
    search.addEventListener('input', () => {
      st.q = search.value;
      render().then(() => {
        const next = document.querySelector('.filter-bar .filter-q');
        if (next) {
          next.focus();
          next.setSelectionRange(next.value.length, next.value.length);
        }
      });
    });
    bar.appendChild(search);
  }

  (spec.picks || []).forEach(pick => {
    const sel = pickSelect([['', pick.label]].concat(pick.options),
                           st.pick[pick.key] || '', v => {
                             st.pick[pick.key] = v;
                             render();
                           });
    sel.title = pick.label;
    bar.appendChild(sel);
  });

  const dirty = st.q || st.sort
             || Object.values(st.pick).some(v => v !== '' && v !== undefined);
  if (dirty) {
    const reset = el('button', 'btn ghost', 'Сбросить');
    reset.addEventListener('click', () => { VIEW[tab] = null; render(); });
    bar.appendChild(reset);
  }

  const count = el('span', 'filter-count');
  count.textContent = shown === total ? `строк: ${total}`
                                      : `показано ${shown} из ${total}`;
  bar.appendChild(count);
  return bar;
}

function headCell(tab, label, spec) {
  const th = el('th', null, label);
  const sorter = (spec && spec.sorts || {})[label];
  if (!sorter) return th;

  const st = viewState(tab);
  th.classList.add('sortable');
  th.title = 'Сортировать по колонке.';
  if (st.sort === label) {
    th.classList.add('sorted');
    th.appendChild(el('span', 'sort-arrow', st.dir > 0 ? '▲' : '▼'));
  }
  th.addEventListener('click', () => {
    if (st.sort === label) st.dir = -st.dir;
    else { st.sort = label; st.dir = 1; }
    render();
  });
  return th;
}

function headRow(tab, labels, spec, decorate) {
  const head = el('tr');
  labels.forEach(label => {
    const th = headCell(tab, label, spec);
    if (decorate) decorate(th, label);
    head.appendChild(th);
  });
  return head;
}

// --- редактор строки добычи -----------------------------------------------
//
// Ключ строки - предмет, ссылка и группа вместе, поэтому смена любого из трёх
// меняет ключ. Сервер это знает и в таком случае удаляет прежнюю и вставляет
// новую; форма шлёт прежний ключ полями was_*.

function rowEditor(tableId, entry, row, onDone) {
  const box = el('div', 'roweditor');
  // `fresh` - заготовка новой строки с уже заполненными полями (например,
  // «+ строка сюда» у группы). Прежнего ключа у неё нет, как и у пустой.
  const isNew = !row || row.fresh;
  const cur = row || { item: 0, reference: 0, chance: 100, group: 0,
                       min: 1, max: 1, mode: 1, quest: false, comment: '' };

  const what = el('div', 'row');
  const itemBox = itemPickBox({
    title: 'Что кладём в добычу',
    empty: 'предмет не выбран',
    hint: 'Строка добычи несёт ЛИБО предмет, либо ссылку на общий кусок. '
      + 'При непустой ссылке ядро поле предмета не читает вовсе.',
  });
  if (cur.item) itemBox.set(cur.item, cur.itemInfo || null);
  what.appendChild(el('span', 'muted', 'предмет'));
  what.appendChild(itemBox);

  const ref = el('input');
  ref.type = 'number';
  ref.min = '0';
  ref.value = cur.reference || 0;
  ref.size = 8;
  ref.title = 'Номер записи в reference_loot_template. Ноль - строка про предмет.';
  what.appendChild(el('span', 'muted', 'или ссылка'));
  what.appendChild(ref);
  box.appendChild(what);

  const nums = el('div', 'row');
  const num = (label, value, min, max, title) => {
    nums.appendChild(el('span', 'muted', label));
    const input = el('input');
    input.type = 'number';
    input.value = value;
    input.min = String(min);
    input.max = String(max);
    input.step = label === 'шанс %' ? '0.01' : '1';
    input.size = 6;
    if (title) input.title = title;
    nums.appendChild(input);
    return input;
  };
  const chance = num('шанс %', cur.chance, 0, 100,
    'Ноль вне группы значит «никогда». В группе ноль законен: такие строки '
    + 'делят остаток поровну.');
  const group = num('группа', cur.group, 0, 255,
    'Ноль - строка катится сама по себе. Больше нуля - из группы выпадет не '
    + 'больше одной строки.');
  const cmin = num('от', cur.min, 0, 255, 'Сколько штук выпадет минимум.');
  const cmax = num('до', cur.max, 0, 255, 'Сколько штук выпадет максимум.');
  const mode = num('режим', cur.mode, 1, 65535,
    'Битовая маска сложности: 1 обычный, 2 героический.');
  box.appendChild(nums);

  const extra = el('div', 'row');
  const quest = el('input');
  quest.type = 'checkbox';
  quest.checked = !!cur.quest;
  const questLabel = el('label', 'muted');
  questLabel.appendChild(quest);
  questLabel.appendChild(el('span', null, ' только для взявших задание'));
  extra.appendChild(questLabel);
  const comment = el('input');
  comment.type = 'text';
  comment.value = cur.comment || '';
  comment.placeholder = 'комментарий (виден только в базе)';
  comment.size = 40;
  extra.appendChild(comment);
  box.appendChild(extra);

  const actions = el('div', 'row');
  const save = el('button', 'btn', isNew ? 'Добавить' : 'Сохранить');
  save.addEventListener('click', async () => {
    const payload = {
      item: itemBox.entry || 0,
      reference: parseInt(ref.value, 10) || 0,
      chance: parseFloat(chance.value) || 0,
      group: parseInt(group.value, 10) || 0,
      min: parseInt(cmin.value, 10) || 0,
      max: parseInt(cmax.value, 10) || 0,
      mode: parseInt(mode.value, 10) || 1,
      quest: quest.checked,
      comment: comment.value,
      was_item: isNew ? -1 : cur.item,
      was_reference: isNew ? -1 : cur.reference,
      was_group: isNew ? -1 : cur.group,
    };
    try {
      const res = await api(`/api/loot/row/${tableId}/${entry}`, {
        method: 'PUT', body: JSON.stringify(payload),
      });
      toast(res.note || (isNew ? 'Строка добавлена.' : 'Сохранено.'),
            res.note ? 'warn' : 'ok');
      onDone(true);
    } catch (e) { toast(e.message, 'err'); }
  });
  actions.appendChild(save);
  const cancel = el('button', 'btn ghost', 'Отмена');
  cancel.addEventListener('click', () => onDone(false));
  actions.appendChild(cancel);
  box.appendChild(actions);
  return box;
}

// --- имена записей и групп ------------------------------------------------
//
// «Запись 16507» и «Группа 1» человеку не говорят ничего. Показываем в таком
// порядке: своё имя, если его завели; иначе автоимя, посчитанное из данных
// (владелец записи, комментарий ссылки); иначе номер. Правка - тут же, без
// ухода со страницы: подписывать записи будут по одной, попутно.

function nameTag(tableId, entry, kind, groupId, label, fallback) {
  const box = el('span', 'nametag');
  const label0 = label || {};

  function draw() {
    box.innerHTML = '';
    const own = label0.name;
    const auto = label0.auto;
    const text = own || auto || fallback;
    const main = el('b', own ? '' : 'muted', text);
    if (!own && auto) main.title = 'Имя посчитано из данных. Можно переписать.';
    box.appendChild(main);
    if (label0.note) {
      const note = el('span', 'mark', '?');
      note.title = label0.note;
      box.appendChild(note);
    }
    if (!can('editor')) return;
    const edit = el('button', 'linkbtn', own ? 'переименовать' : 'назвать');
    edit.addEventListener('click', form);
    box.appendChild(edit);
  }

  function form() {
    box.innerHTML = '';
    const input = el('input');
    input.type = 'text';
    input.value = label0.name || '';
    input.placeholder = label0.auto || fallback;
    input.size = 24;
    const note = el('input');
    note.type = 'text';
    note.value = label0.note || '';
    note.placeholder = 'пояснение, необязательно';
    note.size = 28;
    const save = el('button', 'btn', 'Сохранить');
    const cancel = el('button', 'btn ghost', 'Отмена');
    box.appendChild(input);
    box.appendChild(note);
    box.appendChild(save);
    box.appendChild(cancel);
    input.focus();

    const commit = async () => {
      try {
        const res = await api(`/api/loot/label/${tableId}/${entry}`, {
          method: 'PUT',
          body: JSON.stringify({
            kind, group_id: groupId,
            name: input.value, note: note.value,
          }),
        });
        label0.name = res.name;
        label0.note = res.note;
        toast(res.name ? 'Названо.' : 'Подпись снята.', 'ok');
      } catch (e) { toast(e.message, 'err'); }
      draw();
    };
    save.addEventListener('click', commit);
    input.addEventListener('keydown', ev => {
      if (ev.key === 'Enter') commit();
      if (ev.key === 'Escape') draw();
    });
    cancel.addEventListener('click', draw);
  }

  draw();
  return box;
}

// --- дерево добычи --------------------------------------------------------

function renderTree(tree, depth) {
  const box = el('div');
  // Отмеченные строки этого узла. Узел - своя запись (у ссылки она своя),
  // поэтому и набор свой: собирать строки из разных записей в одну группу
  // нельзя, группа живёт внутри записи.
  const picked = new Map();
  let pickBar = null;

  function drawPickBar() {
    if (!pickBar) return;
    pickBar.innerHTML = '';
    if (!picked.size) {
      pickBar.appendChild(el('span', 'muted',
        'Отметьте строки слева, чтобы собрать их в группу.'));
      return;
    }
    pickBar.appendChild(el('b', null, `Отмечено: ${picked.size}`));

    const collect = async (target, ask) => {
      let name = '';
      if (ask) {
        name = prompt('Имя новой группы (можно оставить пустым):', '') || '';
      }
      try {
        const res = await api(
          `/api/loot/group/${tree.table}/${tree.entry}/collect`, {
            method: 'POST',
            body: JSON.stringify({
              rows: [...picked.values()], target, name,
            }),
          });
        toast(res.note || `Собрано в группу ${res.group}: строк ${res.moved}.`,
              res.note ? 'warn' : 'ok');
        render();
      } catch (e) { toast(e.message, 'err'); }
    };

    const fresh = el('button', 'btn', 'В новую группу');
    fresh.title = 'Свободный номер подберётся сам, имя спросим.';
    fresh.addEventListener('click', () => collect(0, true));
    pickBar.appendChild(fresh);

    const into = el('button', 'btn ghost', 'В группу…');
    into.addEventListener('click', () => {
      const to = prompt('В какую группу собрать? Номер от 1 до 255.', '1');
      if (to === null) return;
      collect(parseInt(to, 10) || 0, false);
    });
    pickBar.appendChild(into);

    const clear = el('button', 'linkbtn', 'снять отметки');
    clear.addEventListener('click', () => {
      picked.clear();
      box.querySelectorAll('.pickrow').forEach(n => { n.checked = false; });
      drawPickBar();
    });
    pickBar.appendChild(clear);
  }

  if (!tree || !tree.rows.length) {
    box.appendChild(el('div', 'empty', tree && tree.truncated
      ? 'Глубже не разворачиваем: ссылки закольцованы.'
      : 'В этой записи нет ни одной строки.'));
    return box;
  }

  // Группы: из группы выпадает НЕ БОЛЕЕ ОДНОЙ строки, и без заголовка это
  // читалось бы как «выпадет всё сразу».
  const byGroup = new Map();
  tree.rows.forEach(row => {
    if (!byGroup.has(row.group)) byGroup.set(row.group, []);
    byGroup.get(row.group).push(row);
  });

  const groupLabels = new Map(
    (tree.groups || []).map(g => [g.id, g]));

  [...byGroup.keys()].sort((a, b) => a - b).forEach(group => {
    if (group) {
      const head = el('div', 'group-head');
      head.appendChild(nameTag(tree.table, tree.entry, 'group', group,
                               groupLabels.get(group), 'Группа ' + group));
      head.appendChild(el('span', null,
        ` — выпадет не больше одной строки из ${byGroup.get(group).length}`));
      if (can('owner')) {
        const move = el('button', 'linkbtn', 'перенести');
        move.title = 'Сдвинуть все строки этой группы под другой номер. '
          + 'Подпись группы переезжает вместе с ними.';
        move.addEventListener('click', async () => {
          const to = prompt(`В какую группу перенести строки группы ${group}? `
                            + '0 - выпустить из группы.', String(group));
          if (to === null) return;
          try {
            await api(`/api/loot/group/${tree.table}/${tree.entry}`
                      + `?source=${group}&target=${parseInt(to, 10) || 0}`,
                      { method: 'POST' });
            toast('Перенесено.', 'ok');
            render();
          } catch (e) { toast(e.message, 'err'); }
        });
        head.appendChild(move);

        const into = el('button', 'linkbtn', '+ строка сюда');
        into.title = 'Добавить строку сразу в эту группу.';
        into.addEventListener('click', () => {
          if (head.nextSibling && head.nextSibling.classList
              && head.nextSibling.classList.contains('roweditor')) {
            head.nextSibling.remove();
            return;
          }
          // Шанс по умолчанию ноль: в группе это «делить остаток поровну», а
          // сотня означала бы «эта строка всегда выигрывает группу».
          const form = rowEditor(tree.table, tree.entry,
            { item: 0, reference: 0, chance: 0, group: group, min: 1, max: 1,
              mode: 1, quest: false, comment: '', fresh: true },
            ok => { if (ok) render(); else form.remove(); });
          head.parentNode.insertBefore(form, head.nextSibling);
        });
        head.appendChild(into);
      }
      box.appendChild(head);
    } else if (byGroup.size > 1) {
      box.appendChild(el('div', 'group-head', 'Вне групп — катится само по себе'));
    }

    byGroup.get(group).forEach(row => {
      const line = el('div', 'lootrow');
      // Галочка - для сборки группы: группа в добыче это и есть общий номер у
      // нескольких строк, и собирать её удобнее отметив, а не вписывая номер
      // в каждую строку по очереди.
      if (can('owner')) {
        const tick = el('input');
        tick.type = 'checkbox';
        tick.className = 'pickrow';
        tick.title = 'Отметить для сборки в группу.';
        tick.addEventListener('change', () => {
          const key = { item: row.item ? row.item.entry : 0,
                        reference: row.reference, group: row.group };
          const id = `${key.item}:${key.reference}:${key.group}`;
          if (tick.checked) picked.set(id, key); else picked.delete(id);
          drawPickBar();
        });
        line.appendChild(tick);
      }
      line.appendChild(el('span', 'chance', chanceText(row.chance)));

      const nm = el('span', 'nm');
      // Ссылка старше предмета: при непустом Reference ядро поле Item не
      // читает вовсе (LootMgr.cpp, `if (item->reference)`). Показать тут
      // предмет значило бы назвать то, что никогда не выпадет.
      if (row.reference) {
        const refName = row.child && row.child.label
          && (row.child.label.name || row.child.label.auto);
        nm.appendChild(el('b', null,
          refName ? `ссылка · ${refName}` : 'ссылка ' + row.reference));
        if (row.item && !row.item.missing) {
          const ignored = el('span', 'muted',
            ` · поле предмета (${row.item.entry}) ядро не читает`);
          nm.appendChild(ignored);
        }
      } else if (row.item) {
        const link = el('a', qualityClass(row.item.quality), itemName(row.item));
        link.href = '#item=' + row.item.entry;
        link.title = 'id ' + row.item.entry
          + (row.item.missing ? ' — строки нет в item_template!' : '');
        if (row.item.missing) link.classList.add('warn');
        nm.appendChild(link);
      } else {
        nm.appendChild(el('span', 'muted', 'пустая строка'));
      }
      line.appendChild(nm);

      if (row.min !== 1 || row.max !== 1) {
        line.appendChild(el('span', 'cnt',
          row.min === row.max ? `×${row.min}` : `×${row.min}-${row.max}`));
      }
      line.appendChild(marks(row));

      // Правка - только владельцу: это игровая таблица, а не подпись.
      if (can('owner')) {
        const tools = el('span', 'rowtools');
        const edit = el('button', 'linkbtn', 'править');
        edit.addEventListener('click', () => {
          if (line.nextSibling && line.nextSibling.classList
              && line.nextSibling.classList.contains('roweditor')) {
            line.nextSibling.remove();
            return;
          }
          const form = rowEditor(tree.table, tree.entry, {
            item: row.item ? row.item.entry : 0,
            itemInfo: row.item,
            reference: row.reference, chance: row.raw_chance,
            group: row.group, min: row.min, max: row.max, mode: row.mode,
            quest: row.quest, comment: row.comment,
          }, ok => { if (ok) render(); else form.remove(); });
          line.parentNode.insertBefore(form, line.nextSibling);
        });
        tools.appendChild(edit);

        const drop = el('button', 'linkbtn', 'удалить');
        drop.addEventListener('click', async () => {
          const what = row.item ? itemName(row.item) : 'ссылку ' + row.reference;
          if (!confirm(`Убрать ${what} из записи ${tree.entry}?`)) return;
          try {
            const params = new URLSearchParams({
              item: row.item ? row.item.entry : 0,
              reference: row.reference, group: row.group,
            });
            await api(`/api/loot/row/${tree.table}/${tree.entry}?`
                      + params.toString(), { method: 'DELETE' });
            toast('Строка убрана.', 'ok');
            render();
          } catch (e) { toast(e.message, 'err'); }
        });
        tools.appendChild(drop);
        line.appendChild(tools);
      }
      box.appendChild(line);

      if (row.child) {
        const node = el('div', 'node ref');
        node.appendChild(renderTree(row.child, (depth || 0) + 1));
        box.appendChild(node);
      }
    });
  });

  if (can('owner')) {
    pickBar = el('div', 'pickbar');
    box.appendChild(pickBar);
    drawPickBar();

    const add = el('div', 'addrow');
    const btn = el('button', 'btn ghost', '+ строка в запись ' + tree.entry);
    btn.addEventListener('click', () => {
      if (add.nextSibling && add.nextSibling.classList
          && add.nextSibling.classList.contains('roweditor')) {
        add.nextSibling.remove();
        return;
      }
      const form = rowEditor(tree.table, tree.entry, null,
                             ok => { if (ok) render(); else form.remove(); });
      add.parentNode.insertBefore(form, add.nextSibling);
    });
    add.appendChild(btn);
    box.appendChild(add);
  }
  return box;
}

// --- вкладка «Моб» --------------------------------------------------------

async function renderCreature(view) {
  const split = el('div', 'split');
  const left = el('div', 'col-list');
  const right = el('div', 'col-body');
  split.appendChild(left);
  split.appendChild(right);
  view.appendChild(split);

  const bar = el('div', 'searchbar');
  const q = el('input');
  q.type = 'search';
  q.placeholder = 'имя существа или его номер';
  q.value = STATE.creatureQuery || '';
  bar.appendChild(q);
  const onlyLoot = el('label', 'hint');
  const cb = el('input');
  cb.type = 'checkbox';
  cb.checked = STATE.onlyLoot !== false;
  onlyLoot.appendChild(cb);
  onlyLoot.appendChild(el('span', null, ' только с добычей'));
  bar.appendChild(onlyLoot);

  // Отбор идёт запросом, а не по загруженным восьмидесяти строкам: существ
  // тридцать тысяч, и фильтровать присланное значит фильтровать не то.
  const rank = pickSelect(
    [['', 'любой ранг']].concat(Object.entries(META.ranks || {})),
    STATE.rank || '', v => { STATE.rank = v; search(); });
  rank.title = 'Ранг существа: обычный, элита, босс, редкий.';
  bar.appendChild(rank);

  const lvlFrom = el('input');
  lvlFrom.type = 'number';
  lvlFrom.placeholder = 'ур. от';
  lvlFrom.min = '0';
  lvlFrom.max = '83';
  lvlFrom.value = STATE.levelMin || '';
  lvlFrom.title = 'Полоса уровней сравнивается с полосой существа: «от 70» '
    + 'поймает и моба 68-72.';
  const lvlTo = el('input');
  lvlTo.type = 'number';
  lvlTo.placeholder = 'до';
  lvlTo.min = '0';
  lvlTo.max = '83';
  lvlTo.value = STATE.levelMax || '';
  [lvlFrom, lvlTo].forEach(input => {
    input.className = 'lvl';
    input.addEventListener('change', () => {
      STATE.levelMin = lvlFrom.value;
      STATE.levelMax = lvlTo.value;
      search();
    });
    bar.appendChild(input);
  });
  left.appendChild(bar);

  const rows = el('div', 'rows');
  left.appendChild(rows);

  async function search() {
    rows.innerHTML = '';
    rows.appendChild(el('div', 'muted', 'ищем…'));
    let data;
    try {
      const params = new URLSearchParams({
        q: q.value, only_loot: cb.checked ? 'true' : 'false', limit: '80',
      });
      if (STATE.rank !== '' && STATE.rank !== undefined) {
        params.set('rank', STATE.rank);
      }
      if (STATE.levelMin) params.set('level_min', STATE.levelMin);
      if (STATE.levelMax) params.set('level_max', STATE.levelMax);
      data = await api('/api/loot/creatures?' + params.toString());
    } catch (e) { rows.innerHTML = ''; rows.appendChild(el('div', 'empty', e.message)); return; }
    rows.innerHTML = '';
    if (!data.creatures.length) {
      rows.appendChild(el('div', 'empty', 'Никого не нашлось.'));
      return;
    }
    data.creatures.forEach(c => {
      const row = el('div', 'listrow' + (STATE.creature === c.entry ? ' sel' : ''));
      const nm = el('span', 'nm');
      nm.appendChild(el('b', null, c.name_ru));
      nm.appendChild(el('small', null,
        `id ${c.entry} · ур. ${c.level} · ${c.rank_name}`
        + (c.subname ? ` · ${c.subname}` : '')));
      row.appendChild(nm);
      row.addEventListener('click', () => { STATE.creature = c.entry; render(); });
      rows.appendChild(row);
    });
  }

  let timer = null;
  q.addEventListener('input', () => {
    STATE.creatureQuery = q.value;
    clearTimeout(timer);
    timer = setTimeout(search, 250);
  });
  cb.addEventListener('change', () => { STATE.onlyLoot = cb.checked; search(); });
  search();

  if (!STATE.creature) {
    right.appendChild(el('div', 'empty', 'Выберите существо слева.'));
    return;
  }

  right.appendChild(el('div', 'muted', 'Загрузка добычи…'));
  let data;
  try {
    data = await api('/api/loot/creature/' + STATE.creature);
  } catch (e) {
    right.innerHTML = '';
    right.appendChild(el('div', 'empty', e.message));
    return;
  }
  right.innerHTML = '';

  const c = data.creature;
  const head = el('div', 'card');
  head.appendChild(el('h2', null, `${c.name_ru} · id ${c.entry}`));
  head.appendChild(el('div', 'hint',
    `Уровень ${c.level} · ${c.rank_name}` + (c.subname ? ` · ${c.subname}` : '')));
  if (!data.loot.length) {
    head.appendChild(el('div', 'empty', 'У этого существа нет ни одной таблицы добычи.'));
  }
  right.appendChild(head);

  data.loot.forEach(part => {
    const card = el('div', 'card');
    const title = el('h2');
    title.appendChild(el('span', null, part.label + ' · '));
    title.appendChild(nameTag(part.table, part.entry, 'entry', 0,
                              part.tree.label, 'запись ' + part.entry));
    title.appendChild(el('span', 'muted', ` · запись ${part.entry}`));
    card.appendChild(title);
    if (!part.own_entry) {
      card.appendChild(el('div', 'hint warn',
        `Номер записи не совпадает с номером существа: добыча живёт под ${part.entry}.`));
    }
    if (part.shared.length) {
      // 930 существ в базе делят чужую запись. Правка такой записи задевает
      // всех - об этом нужно знать ДО правки, а не после.
      const note = el('div', 'hint warn');
      note.textContent = `Эту же запись используют ещё ${part.shared.length}: `;
      part.shared.slice(0, 8).forEach((o, i) => {
        const a = el('a', null, o.name_ru + ' (' + o.entry + ')');
        a.href = '#creature=' + o.entry;
        note.appendChild(a);
        if (i < Math.min(part.shared.length, 8) - 1) note.appendChild(el('span', null, ', '));
      });
      if (part.shared.length > 8) {
        note.appendChild(el('span', null, ` и ещё ${part.shared.length - 8}`));
      }
      card.appendChild(note);
    }
    card.appendChild(renderTree(part.tree, 0));
    right.appendChild(card);
  });

  right.appendChild(el('div', 'hint',
    'Дроп надетого (mod-worn-drops) сюда не входит: он раздаётся кодом при '
    + 'убийстве, а не таблицами, и в базе его нет.'));
}

// --- вкладка «Предмет» ----------------------------------------------------

async function renderItem(view) {
  const bar = el('div', 'searchbar');
  const q = el('input');
  q.type = 'search';
  q.placeholder = 'номер предмета';
  q.value = STATE.item || '';
  bar.appendChild(q);
  const go = el('button', 'btn', 'Найти');
  bar.appendChild(go);
  view.appendChild(bar);

  view.appendChild(el('div', 'hint',
    'Поиск идёт ВВЕРХ по всем тринадцати таблицам: сперва прямые упоминания, '
    + 'потом - кто ссылается на найденные ссылки, и так до владельца. Шанс в '
    + 'строке - произведение шансов по всей цепочке.'));

  const body = el('div');
  view.appendChild(body);

  const run = async () => {
    const entry = parseInt(q.value, 10);
    if (!entry) { body.innerHTML = ''; return; }
    STATE.item = entry;
    location.hash = 'item=' + entry;
    body.innerHTML = '';
    body.appendChild(el('div', 'muted', 'ищем…'));
    let data;
    try { data = await api('/api/loot/item/' + entry); }
    catch (e) { body.innerHTML = ''; body.appendChild(el('div', 'empty', e.message)); return; }
    body.innerHTML = '';

    const card = el('div', 'card');
    const title = el('h2', qualityClass(data.item.quality), itemName(data.item));
    card.appendChild(title);
    card.appendChild(el('div', 'hint',
      data.item.missing
        ? 'Строки этого предмета нет в item_template.'
        : `id ${data.item.entry} · уровень ${data.item.ilvl} · требует ${data.item.req_level}`));
    body.appendChild(card);

    if (!data.paths.length) {
      body.appendChild(el('div', 'empty',
        'Ни в одной таблице добычи не встречается.'));
    } else {
      // Путей у ходового предмета сотни: без отбора список читать нечем.
      const spec = {
        placeholder: 'поиск по владельцу',
        search: p => p.owner_name,
        picks: [
          { key: 'table', label: 'любая таблица',
            options: META.tables.map(t => [t.id, t.name]),
            get: p => p.table },
          { key: 'kind', label: 'любой источник',
            options: [['creature', 'существа'], ['gameobject', 'объекты'],
                      ['item', 'предметы'], ['reference', 'ничьи ссылки']],
            get: p => p.owner_kind },
          { key: 'floor', label: 'любой шанс',
            options: [['1', 'от 1 %'], ['5', 'от 5 %'], ['25', 'от 25 %'],
                      ['100', 'только гарантированные']],
            test: (p, v) => p.chance >= parseFloat(v) },
          { key: 'quest', label: 'квест и обычные',
            options: [['0', 'без квестовых'], ['1', 'только квестовые']],
            test: (p, v) => (p.chain.some(h => h.quest) ? '1' : '0') === v },
        ],
        sorts: {
          'Шанс': p => p.chance,
          'Откуда': p => p.table_name,
          'Кто': p => p.owner_name,
        },
      };
      const shown = applyView('item', data.paths, spec);
      body.appendChild(filterBar('item', spec, data.paths.length, shown.length));

      const table = el('table', 'grid');
      table.appendChild(headRow('item',
        ['Шанс', 'Откуда', 'Кто', 'Через что', ''], spec));

      shown.forEach(p => {
        const tr = el('tr');
        tr.appendChild(el('td', 'num', chanceText(p.chance)));
        tr.appendChild(el('td', null, p.table_name));

        const who = el('td');
        if (p.owner_kind === 'creature') {
          const a = el('a', null, `${p.owner_name} (${p.owner_entry})`);
          a.href = '#creature=' + p.owner_entry;
          who.appendChild(a);
        } else {
          who.appendChild(el('span', null, `${p.owner_name} (${p.owner_entry})`));
        }
        tr.appendChild(who);

        // Цепочка: запись → ссылка → ссылка. Без неё «шанс 0.6 %» выглядит
        // взятым с потолка.
        const chain = el('td', 'chain');
        p.chain.forEach((hop, i) => {
          if (i) chain.appendChild(el('span', null, ' → '));
          const named = hop.label && (hop.label.name || hop.label.auto);
          const b = el('b', null,
            named ? `${hop.table_name} · ${named}`
                  : `${hop.table_name} ${hop.entry}`);
          b.title = `запись ${hop.entry}, шанс ${chanceText(hop.chance)}`
            + (hop.group ? `, группа ${hop.group}` : '')
            + (hop.comment ? `\n${hop.comment}` : '');
          chain.appendChild(b);
        });
        tr.appendChild(chain);

        const last = p.chain[p.chain.length - 1] || {};
        tr.appendChild(el('td')).appendChild(marks(last));
        table.appendChild(tr);
      });
      body.appendChild(table);
    }

    if (data.truncated) {
      body.appendChild(el('div', 'hint warn',
        `Показаны первые ${data.limit} путей — их больше. Так бывает у общих `
        + 'ссылок, которые тянут к себе половину мира; сузить список пока '
        + 'нечем, и это честнее, чем считать полчаса.'));
    }
    body.appendChild(el('div', 'hint',
      'Чего здесь нет: дропа mod-worn-drops (раздаётся кодом), наград за '
      + 'задания, торговцев и создания предмета ремеслом.'));
  };

  go.addEventListener('click', run);
  q.addEventListener('keydown', ev => { if (ev.key === 'Enter') run(); });
  if (STATE.item) run();
}

// --- вкладка «Таблица» ----------------------------------------------------

async function renderTable(view) {
  const bar = el('div', 'searchbar');
  const pick = el('select');
  META.tables.forEach(t => {
    const opt = el('option', null, `${t.name} · ${t.rows} строк`);
    opt.value = t.id;
    if (t.id === STATE.table) opt.selected = true;
    pick.appendChild(opt);
  });
  bar.appendChild(pick);
  const q = el('input');
  q.type = 'search';
  q.placeholder = 'номер записи';
  bar.appendChild(q);
  view.appendChild(bar);

  const current = META.tables.find(t => t.id === STATE.table);
  view.appendChild(el('div', 'hint', current ? current.hint : ''));

  const split = el('div', 'split');
  const left = el('div', 'col-list');
  const right = el('div', 'col-body');
  split.appendChild(left);
  split.appendChild(right);
  view.appendChild(split);

  const rows = el('div', 'rows');
  left.appendChild(rows);

  async function list() {
    rows.innerHTML = '';
    rows.appendChild(el('div', 'muted', 'читаем…'));
    let data;
    try {
      const params = new URLSearchParams({ q: q.value, limit: '200' });
      data = await api(`/api/loot/table/${STATE.table}?` + params.toString());
    } catch (e) { rows.innerHTML = ''; rows.appendChild(el('div', 'empty', e.message)); return; }
    rows.innerHTML = '';
    const spec = {
      picks: [
        { key: 'named', label: 'все записи',
          options: [['1', 'только подписанные'], ['0', 'без подписи']],
          test: (e, v) => ((e.label && e.label.name) ? '1' : '0') === v },
        { key: 'refs', label: 'со ссылками и без',
          options: [['1', 'есть ссылки'], ['0', 'без ссылок']],
          test: (e, v) => (e.refs ? '1' : '0') === v },
        { key: 'grouped', label: 'с группами и без',
          options: [['1', 'есть группы'], ['0', 'без групп']],
          test: (e, v) => (e.grouped ? '1' : '0') === v },
      ],
      sorts: {},
    };
    const shown = applyView('table', data.entries, spec);
    // list() зовут и поиск, и перерисовка - прежнюю полосу убираем, иначе они
    // копятся одна под другой.
    left.querySelectorAll('.filter-bar, .list-note').forEach(n => n.remove());
    left.insertBefore(filterBar('table', spec, data.entries.length,
                                shown.length), rows);
    if (data.note) {
      left.insertBefore(el('div', 'hint warn list-note', data.note), rows);
    }

    shown.forEach(e => {
      const row = el('div', 'listrow' + (STATE.entry === e.entry ? ' sel' : ''));
      const nm = el('span', 'nm');
      const named = e.label && (e.label.name || e.label.auto);
      nm.appendChild(el('b', e.label && e.label.name ? '' : 'muted',
                        named || ('запись ' + e.entry)));
      nm.appendChild(el('small', null,
        `${e.entry} · строк ${e.rows}` + (e.refs ? ` · ссылок ${e.refs}` : '')
        + (e.grouped ? ` · в группах ${e.grouped}` : '')));
      row.appendChild(nm);
      row.addEventListener('click', () => { STATE.entry = e.entry; render(); });
      rows.appendChild(row);
    });
    if (!shown.length) rows.appendChild(el('div', 'empty', 'Пусто.'));
  }

  pick.addEventListener('change', () => {
    STATE.table = pick.value;
    STATE.entry = null;
    render();
  });
  let timer = null;
  q.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(list, 250); });
  list();

  if (!STATE.entry) {
    right.appendChild(el('div', 'empty', 'Выберите запись слева.'));
    return;
  }

  let data;
  try { data = await api(`/api/loot/table/${STATE.table}/${STATE.entry}`); }
  catch (e) { right.appendChild(el('div', 'empty', e.message)); return; }

  const card = el('div', 'card');
  const head = el('h2');
  head.appendChild(nameTag(STATE.table, STATE.entry, 'entry', 0,
                           data.tree.label, 'Запись ' + STATE.entry));
  head.appendChild(el('span', 'muted', ` · запись ${STATE.entry}`));
  card.appendChild(head);
  if (data.owners.length) {
    const who = el('div', 'hint');
    who.textContent = 'Пользуются: ';
    data.owners.slice(0, 12).forEach((o, i) => {
      const label = `${o.name_ru || o.name} (${o.entry})`;
      if (o.kind === 'creature') {
        const a = el('a', null, label);
        a.href = '#creature=' + o.entry;
        who.appendChild(a);
      } else {
        who.appendChild(el('span', null, label));
      }
      if (i < Math.min(data.owners.length, 12) - 1) who.appendChild(el('span', null, ', '));
    });
    if (data.owners.length > 12) {
      who.appendChild(el('span', null, ` и ещё ${data.owners.length - 12}`));
    }
    card.appendChild(who);
  } else {
    card.appendChild(el('div', 'hint',
      STATE.table === 'reference'
        ? 'На ссылку смотрят другие таблицы — своего владельца у неё нет.'
        : 'Владельца у этой записи не нашлось: на неё никто не ссылается.'));
  }
  card.appendChild(renderTree(data.tree, 0));
  right.appendChild(card);
}

// --- каркас ---------------------------------------------------------------

async function reloadServer() {
  // Какую таблицу перечитывать, зависит от вкладки: на «Мобе» это добыча с
  // трупа, на «Таблице» - выбранная. Перечитывать все тринадцать ради одной
  // правки незачем.
  const table = TAB === 'table' ? STATE.table : 'creature';
  try {
    await api('/api/loot/reload/' + table, { method: 'POST' });
    toast('Мир перечитал таблицу.', 'ok');
  } catch (e) { toast(e.message, 'err'); }
}

function renderTabs() {
  const box = document.getElementById('tabs');
  box.innerHTML = '';
  TABS.forEach(([id, label]) => {
    const b = el('button', id === TAB ? 'active' : '', label);
    b.addEventListener('click', () => { TAB = id; render(); });
    box.appendChild(b);
  });

  // Правка ложится в базу, а мир держит таблицы добычи в памяти: без этой
  // кнопки она доедет до игры только следующим рестартом.
  if (can('owner')) {
    const apply = el('button', 'apply', 'Применить на сервере');
    apply.title = 'Выполняет ".reload <таблица>_loot_template" на PTR по SOAP.';
    apply.addEventListener('click', reloadServer);
    box.appendChild(apply);
  }
}

async function render() {
  renderTabs();
  const view = document.getElementById('view');
  view.innerHTML = '';
  try {
    if (TAB === 'creature') await renderCreature(view);
    else if (TAB === 'item') await renderItem(view);
    else await renderTable(view);
  } catch (e) {
    view.innerHTML = '';
    view.appendChild(el('div', 'empty', e.message));
  }
}

// Переход из каталога предметов и внутренние ссылки дерева: #item=123,
// #creature=456. Хеш, а не путь - страница одна, и перезагружать её незачем.
function readHash() {
  const hash = (location.hash || '').replace(/^#/, '');
  const item = hash.match(/item=(\d+)/);
  const creature = hash.match(/creature=(\d+)/);
  if (item) { TAB = 'item'; STATE.item = parseInt(item[1], 10); return true; }
  if (creature) { TAB = 'creature'; STATE.creature = parseInt(creature[1], 10); return true; }
  return false;
}

window.addEventListener('hashchange', () => { if (readHash()) render(); });

(async () => {
  await mountSessionOnce();
  try {
    META = await api('/api/loot/meta');
  } catch (e) {
    document.getElementById('view').innerHTML = '';
    document.getElementById('view').appendChild(el('div', 'empty', e.message));
    return;
  }
  readHash();
  render();
})();
