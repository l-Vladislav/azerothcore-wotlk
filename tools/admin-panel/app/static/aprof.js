// Продвинутые профессии: справочники хардкорного крафта.
//
// Правки уходят по строке, а не общей кнопкой «сохранить всё»: строк тут
// немного, зато каждая — это рецепт, по которому игрок необратимо тратит
// материалы. Исключение — вкладка «Баланс»: качества, корзины и веса
// проверяются друг относительно друга (дыры между корзинами, нулевые веса),
// поэтому уезжают одним куском.

let META = null;
let MATS = [];
// Справочники рода и типа вставки (DESIGN §2.5). Отдельными списками, а не в
// META: META читается один раз при загрузке страницы, а справочники правятся
// прямо тут же, на вкладке «Справочники».
let PART_KINDS = [];
let INSERT_TYPES = [];
let TYPES = [];
let RECIPES = [];
let SYNS = [];
let MERGES = [];
let TAB = 'types';

const BLANK_ICON =
  'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

const TABS = [
  ['types', 'Типы предметов'],
  ['materials', 'Материалы'],
  ['recipes', 'Рецепты'],
  ['named', 'Именные'],
  ['map', 'Связи'],
  ['merge', 'Объединение'],
  ['dicts', 'Справочники'],
  ['balance', 'Баланс'],
  ['preview', 'Проверка'],
  ['pool', 'Пул id'],
];

// Роль двоичная: «только для сочетаний» отменена 2026-09-07 (DESIGN §2.5).
const ROLES = { base: 'на основу', insert: 'вставка' };

// Способ получения основы. Низ куётся, верх выбивается: профессия становится
// способом ДОВЕСТИ добытое, а не заменить его (DESIGN §2.5).
const ACQUIRE = { forge: 'куётся', drop: 'только добыча' };

// Варианты для выпадающего списка: только включённые строки, плюс та, что уже
// стоит у записи. Выключенную не прячем, если она выбрана, - иначе список молча
// подменил бы её первой попавшейся.
function dictOptions(rows, current) {
  return rows.filter(r => r.enabled || r.id === current)
             .map(r => [String(r.id), r.name_ru + (r.enabled ? '' : ' (выкл)')]);
}

function dictName(rows, id) {
  const row = rows.find(r => r.id === id);
  return row ? row.name_ru : (id ? `строка ${id}` : '—');
}

// Первая включённая строка справочника: ею заполняется признак, когда роль
// материала переключили и прежний признак стал не тем.
function firstDictId(rows) {
  const row = rows.find(r => r.enabled);
  return row ? row.id : 0;
}

function iconUrl(t) {
  return (t && META && META.icon_base_url) ? `${META.icon_base_url}/${t}.jpg`
                                           : BLANK_ICON;
}

function statName(id) { return (META.stats || {})[id] || `стат ${id}`; }

function itemCell(item, fallback) {
  const box = el('div', 'item-cell');
  const img = el('img');
  img.loading = 'lazy';
  img.src = iconUrl(item && item.icon);
  img.addEventListener('error', () => { img.src = BLANK_ICON; }, { once: true });
  box.appendChild(img);
  const nm = el('div', 'nm');
  if (item) {
    nm.appendChild(el('b', 'q' + item.quality, item.name));
    nm.appendChild(el('small', null, 'id ' + item.entry));
  } else {
    // Предмета в item_template нет: рецепт будет ссылаться в пустоту, и в игре
    // это выглядит как «крафт молча не работает». Поэтому кричим в списке.
    nm.appendChild(el('b', 'warn', 'предмета нет'));
    nm.appendChild(el('small', null, 'id ' + fallback));
  }
  box.appendChild(nm);
  return box;
}

function select(options, value, onChange) {
  const s = el('select');
  options.forEach(([v, label]) => {
    const o = el('option', null, label);
    o.value = v;
    if (String(v) === String(value)) o.selected = true;
    s.appendChild(o);
  });
  if (onChange) s.addEventListener('change', () => onChange(s.value));
  return s;
}

// Выпадающий список, который наполняется при первом открытии.
//
// Список основ - это четыре с половиной сотни строк. В таблице «Именных» такой
// список стоит в каждой строке, а строк восемь сотен: браузер строил под
// четыреста тысяч узлов ТОЛЬКО на эти списки и вставал колом на добрый десяток
// секунд. Пока список закрыт, в нём лежит одна строка - выбранная; остальные
// приезжают по первому касанию, то есть ровно тогда, когда их собрались
// читать.
//
// options - функция, а не массив: сам массив тоже стоит денег, и строить его
// на каждую строку незачем. label - подпись выбранного; взять её из массива
// нельзя, массива ещё нет.
function lazySelect(options, value, label, onChange) {
  // Класс несёт ширину: у обычного списка её задаёт самая длинная строка, а у
  // этого строк пока нет, и без ширины колонка схлопывается до «Медн...».
  const s = el('select', 'lazy');
  // Подпись длиннее колонки - обычное дело («Бронзовый клинок»), поэтому
  // полное имя висит подсказкой: обрезанное «Бронзов...» ни о чём не говорит.
  s.title = label;
  const stub = el('option', null, label);
  stub.value = String(value);
  s.appendChild(stub);

  let filled = false;
  const fill = () => {
    if (filled) return;
    filled = true;
    s.innerHTML = '';
    options().forEach(([v, text]) => {
      const o = el('option', null, text);
      o.value = v;
      s.appendChild(o);
    });
    s.value = String(value);
  };
  // mousedown приходит ДО того, как браузер раскроет список, focus ловит
  // приход с клавиатуры: к моменту, когда список видно, он уже полный.
  s.addEventListener('mousedown', fill);
  s.addEventListener('focus', fill);
  if (onChange) s.addEventListener('change', () => onChange(s.value));
  return s;
}

function num(value, onChange, min) {
  const i = el('input');
  i.type = 'number';
  i.value = value;
  if (min !== undefined) i.min = min;
  if (onChange) i.addEventListener('change', () => onChange(parseInt(i.value, 10) || 0));
  return i;
}

function text(value, onChange) {
  const i = el('input');
  i.type = 'text';
  i.value = value || '';
  if (onChange) i.addEventListener('change', () => onChange(i.value));
  return i;
}

function statOptions() {
  return Object.entries(META.stats).map(([id, label]) => [id, label]);
}

// Вставки - и те, что дают стат, и «только для сочетаний»: в слот идут
// обе роли, разница лишь в том, что вторые чисел не дают (DESIGN §5.7).
function insertMats() { return MATS.filter(m => m.role !== 'base'); }

// --- полоса добавления ----------------------------------------------------
// Добавление устроено одинаково на каждой вкладке: несколько полей и кнопка.
// Раньше это была карточка ПОД таблицей - до неё приходилось пролистывать
// весь список, а на «Типах» список длинный. Теперь это строка НАД листом,
// и форма у неё общая: вкладка задаёт только поля и что делать по кнопке.
//
// fields - массив [подпись, элемент]; onAdd вызывается по кнопке и по Enter
// в любом из полей ввода.
function addBar(fields, onAdd) {
  const bar = el('div', 'add-bar');
  fields.forEach(([label, node]) => {
    const wrap = el('label', 'add-field');
    wrap.appendChild(el('span', null, label));
    wrap.appendChild(node);
    bar.appendChild(wrap);
    if (node.tagName === 'INPUT') {
      node.addEventListener('keydown', ev => {
        if (ev.key === 'Enter') { ev.preventDefault(); onAdd(); }
      });
    }
  });
  const btn = el('button', 'btn', 'Добавить');
  btn.addEventListener('click', () => onAdd());
  bar.appendChild(btn);
  return bar;
}

// Полоса добавления переживает перерисовку. Сохранение зовёт loadAll(), тот
// строит вкладку заново - и списки возвращались к умолчанию. Заводя подряд
// полсотни камней одного рода, выставлять роль, тип и стат каждый раз заново
// невозможно, поэтому выбор живёт до перезагрузки страницы.
const ADD_MEMORY = {};

function addMemory(tab, defaults) {
  if (!ADD_MEMORY[tab]) ADD_MEMORY[tab] = { ...defaults };
  return ADD_MEMORY[tab];
}

// --- выбор внешнего вида --------------------------------------------------
// Иконка не отдельное поле: она лежит в ItemDisplayInfo.dbc вместе с 3D-моделью,
// поэтому выбирается не картинка, а `displayid` существующего предмета — и
// вместе с иконкой меняется то, как предмет выглядит в руках.

function iconImg(texture, size) {
  const img = el('img', 'look-icon');
  img.width = size || 32;
  img.height = size || 32;
  img.src = iconUrl(texture);
  img.addEventListener('error', () => { img.src = BLANK_ICON; }, { once: true });
  return img;
}

// onPick(displayId) вызывается по клику; окно закрывается само.
function openLookPicker(opts, onPick) {
  const back = el('div', 'ap-modal-back');
  const box = el('div', 'ap-modal');
  back.appendChild(box);

  const head = el('div', 'row');
  head.appendChild(el('h2', null, opts.title || 'Выбор внешнего вида'));
  const gap = el('span');
  gap.style.flex = '1';
  head.appendChild(gap);
  const closeBtn = el('button', 'btn ghost', 'Закрыть');
  closeBtn.addEventListener('click', () => back.remove());
  head.appendChild(closeBtn);
  box.appendChild(head);

  const tools = el('div', 'row');
  const search = el('input');
  search.type = 'text';
  search.placeholder = 'поиск по названию предмета (рус. или англ.)';
  search.style.minWidth = '320px';
  tools.appendChild(search);

  // Класс сужает выбор до осмысленного: основе-щиту незачем показывать посохи.
  // У синергии класс неизвестен — там только «любые».
  const scope = select([['self', 'этот тип'], ['class', 'весь класс'],
                        ['any', 'любые предметы']], 'self');
  if (opts.itemClass !== undefined) tools.appendChild(scope);
  box.appendChild(tools);

  const grid = el('div', 'look-grid');
  box.appendChild(grid);

  // Постранично: одних мечей в базе под тысячу видов, и без листания выбор
  // молча обрезался на первой сотне - страница выглядела как «это всё».
  const PAGE_SIZE = 120;
  let page = 0;

  const pager = el('div', 'pager');
  const prev = el('button', 'btn ghost', '← Назад');
  const next = el('button', 'btn ghost', 'Вперёд →');
  const counter = el('span', 'pager-count');
  pager.appendChild(prev);
  pager.appendChild(counter);
  pager.appendChild(next);
  box.appendChild(pager);

  const status = el('p', 'hint');
  box.appendChild(status);

  prev.addEventListener('click', () => { if (page > 0) { page -= 1; load(); } });
  next.addEventListener('click', () => { page += 1; load(); });

  async function load() {
    grid.innerHTML = '';
    status.textContent = 'Загрузка…';
    const params = new URLSearchParams();
    if (search.value.trim()) params.set('q', search.value.trim());
    const mode = opts.itemClass === undefined ? 'any' : scope.value;
    if (mode !== 'any') params.set('item_class', opts.itemClass);
    if (mode === 'self' && opts.itemSubclass !== undefined) {
      params.set('item_subclass', opts.itemSubclass);
    }
    params.set('limit', String(PAGE_SIZE));
    params.set('offset', String(page * PAGE_SIZE));
    try {
      const res = await api('/api/aprof/displays?' + params.toString());
      const total = res.total || res.displays.length;
      const from = res.displays.length ? page * PAGE_SIZE + 1 : 0;
      const to = page * PAGE_SIZE + res.displays.length;

      counter.textContent = total
        ? `${from}–${to} из ${total}` : 'ничего не найдено';
      prev.disabled = page === 0;
      next.disabled = to >= total;
      pager.style.display = total > PAGE_SIZE ? '' : 'none';

      status.textContent = res.displays.length
        ? 'Число под иконкой — сколько предметов в игре уже так выглядят; '
          + 'самые расхожие виды идут первыми.'
        : 'Ничего не нашлось.';
      res.displays.forEach(look => {
        const cell = el('button', 'look-cell');
        cell.appendChild(iconImg(look.icon, 40));
        cell.appendChild(el('span', 'look-id', String(look.display_id)));
        cell.appendChild(el('span', 'look-n', String(look.used_by)));
        cell.title = look.name + '\ndisplayid ' + look.display_id
                     + ' · предмет-образец ' + look.entry;
        cell.addEventListener('click', () => {
          back.remove();
          onPick(look.display_id);
        });
        grid.appendChild(cell);
      });
    } catch (e) {
      status.textContent = e.message;
    }
  }

  let timer = null;
  search.addEventListener('input', () => {
    clearTimeout(timer);
    timer = setTimeout(() => { page = 0; load(); }, 350);
  });
  scope.addEventListener('change', () => { page = 0; load(); });
  back.addEventListener('click', ev => { if (ev.target === back) back.remove(); });

  document.body.appendChild(back);
  search.focus();
  load();
}

// Ячейка «иконка + поле id + кнопка выбора» — одинаковая у основ и у синергий.
//
// Поле id нужно не для удобства: displayid из собственного ItemDisplayInfo.dbc
// (то, что приезжает в клиент через MPQ-патч) сервер не знает, и в сетке выбора
// такой строки не будет. Вписать её вручную — единственный способ.
function lookCell(icon, displayId, opts, onPick) {
  const cell = el('td', 'look-td');
  const wrap = el('div', 'row');
  wrap.appendChild(iconImg(icon, 28));

  const manual = el('input');
  manual.type = 'number';
  manual.min = 0;
  manual.value = displayId || 0;
  manual.style.width = '76px';
  manual.title = 'id модели (ItemDisplayInfo). Задаёт и иконку, и 3D-вид. ' +
                 'Можно вписать свой id из MPQ — сервер его не проверяет.';
  manual.addEventListener('change', () => onPick(parseInt(manual.value, 10) || 0));
  wrap.appendChild(manual);

  const button = el('button', 'btn ghost', 'Выбрать');
  button.title = 'Выбрать внешний вид из существующих предметов.';
  button.addEventListener('click', () => openLookPicker(opts, onPick));
  wrap.appendChild(button);

  if (opts.clearable && displayId) {
    const clear = el('button', 'btn ghost', '×');
    clear.title = 'Вернуть внешний вид основы.';
    clear.addEventListener('click', () => onPick(0));
    wrap.appendChild(clear);
  }

  cell.appendChild(wrap);
  return cell;
}

// --- фильтр и сортировка --------------------------------------------------
// Списки выросли: типов десяток, материалов и основ будет больше. Вкладки
// разные, а поведение нужно одно - строка поиска и пара выпадающих отборов
// сверху, клик по заголовку сортирует. Поэтому механика лежит здесь, а вкладка
// приносит только описание: чем искать, чем отбирать, чем сортировать.
//
// Состояние живёт по вкладкам и переживает перерисовку: правка строки
// перезагружает справочники целиком, и без этого список после каждого
// сохранения прыгал бы к началу, теряя отбор.
const VIEW = {};

// Размер страницы. Лист рисуется целиком, и цена отрисовки растёт вместе со
// справочником: восемьсот строк «Именных» - это под четыреста тысяч узлов, и
// вкладка встаёт на добрый десяток секунд, а потом ещё и тормозит на прокрутке.
// Страница разрывает эту связь: сколько бы ни было строк, рисуем сотню.
//
// «Все строки» оставлены нарочно - иногда нужно свернуть лист целиком в поиск
// браузера (Ctrl+F) или скопировать всю таблицу. Цена такого показа - на
// совести того, кто его выбрал.
const PAGE_SIZES = [[50, 'по 50'], [100, 'по 100'], [200, 'по 200'],
                    [500, 'по 500'], [0, 'все строки']];
const PAGE_SIZE = 100;

function viewState(tab) {
  if (!VIEW[tab]) {
    VIEW[tab] = { q: '', pick: {}, sort: '', dir: 1, page: 0, size: PAGE_SIZE };
  }
  return VIEW[tab];
}

// Отбор сузил лист - страница должна вернуться к началу: иначе набранная в
// поиске буква оставляет пустой экран, хотя строки нашлись.
function viewReset(tab) {
  viewState(tab).page = 0;
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

// spec: { search: строка для поиска, picks: [{key, label, options, get}],
//         sorts: { 'Заголовок колонки': элемент => значение } }
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
    out = out.filter(item => String(pick.get(item)) === String(chosen));
  });

  const sorter = (spec.sorts || {})[st.sort];
  if (sorter) {
    // Копия: сортировать сам справочник нельзя, его же читают другие вкладки.
    out = out.slice().sort((a, b) => compareValues(sorter(a), sorter(b)) * st.dir);
  }

  // Счёт запоминаем здесь, а не отдаём наружу: полоса отбора и листалка
  // рисуются после таблицы и все три числа - всего, отобрано, показано -
  // должны говорить об одном и том же проходе.
  st.total = items.length;
  st.found = out.length;
  st.pages = st.size ? Math.max(1, Math.ceil(out.length / st.size)) : 1;
  if (st.page >= st.pages) st.page = st.pages - 1;
  if (st.page < 0) st.page = 0;
  st.from = st.size ? st.page * st.size : 0;
  const page = st.size ? out.slice(st.from, st.from + st.size) : out;
  st.shown = page.length;
  return page;
}

// Листалка. Стрелки по краям, номер посередине - как в каталоге предметов.
// Выбор размера страницы только сверху: снизу он попадался бы под руку тому,
// кто пришёл нажать «вперёд».
function pager(tab, withSize) {
  const st = viewState(tab);
  const box = el('div', 'list-pager');

  const step = delta => {
    st.page = Math.min(Math.max(st.page + delta, 0), st.pages - 1);
    render();
  };
  const prev = el('button', 'btn ghost', '‹');
  prev.title = 'Предыдущая страница';
  prev.disabled = st.page <= 0;
  prev.addEventListener('click', () => step(-1));
  box.appendChild(prev);

  box.appendChild(el('span', 'pager-count',
                     `${st.page + 1} / ${st.pages}`));

  const next = el('button', 'btn ghost', '›');
  next.title = 'Следующая страница';
  next.disabled = st.page >= st.pages - 1;
  next.addEventListener('click', () => step(1));
  box.appendChild(next);

  if (withSize) {
    const size = select(PAGE_SIZES, st.size, v => {
      st.size = parseInt(v, 10) || 0;
      st.page = 0;
      render();
    });
    size.title = 'Сколько строк рисовать за раз. Чем больше, тем дольше '
      + 'открывается вкладка.';
    box.appendChild(size);
  }
  return box;
}

function filterBar(tab, spec) {
  const st = viewState(tab);
  const bar = el('div', 'filter-bar');

  const search = el('input');
  search.type = 'search';
  search.className = 'filter-q';
  search.placeholder = spec.placeholder || 'поиск';
  search.value = st.q;
  // input, а не change: отбор из трёх строк должен сужаться по мере набора.
  // Значение уже в состоянии, поэтому перерисовка не теряет курсор - фокус
  // возвращаем руками, иначе он уезжает после первой же буквы.
  search.addEventListener('input', () => {
    st.q = search.value;
    viewReset(tab);
    render().then(() => {
      const next = document.querySelector('.filter-bar .filter-q');
      if (next) { next.focus(); next.setSelectionRange(next.value.length,
                                                       next.value.length); }
    });
  });
  bar.appendChild(search);

  (spec.picks || []).forEach(pick => {
    const options = [['', pick.label]].concat(pick.options);
    const sel = select(options, st.pick[pick.key] || '', v => {
      st.pick[pick.key] = v;
      viewReset(tab);
      render();
    });
    sel.title = pick.label;
    bar.appendChild(sel);
  });

  const dirty = st.q || st.sort
             || Object.values(st.pick).some(v => v !== '' && v !== undefined);
  if (dirty) {
    const reset = el('button', 'btn ghost', 'Сбросить');
    reset.addEventListener('click', () => {
      // Размер страницы - не часть отбора: его выбрали под свой экран, и
      // «Сбросить» отбор не повод возвращать сотню.
      VIEW[tab] = { q: '', pick: {}, sort: '', dir: 1, page: 0, size: st.size };
      render();
    });
    bar.appendChild(reset);
  }

  // Счёт и листалка стоят одной группой у правого края: порознь они не
  // помещаются в строку, и полоса отбора разъезжается на два ряда.
  const tailBox = el('div', 'filter-tail');
  bar.appendChild(tailBox);

  // Три числа, а не одно: сколько видно сейчас, сколько нашлось отбором и
  // сколько строк всего. Без первого страница выглядит потерянными строками,
  // без последнего - непонятно, много ли отбор отсёк.
  const count = el('span', 'filter-count');
  const tail = st.found === st.total ? '' : ` · отобрано из ${st.total}`;
  if (st.pages > 1) {
    count.textContent =
      `строки ${st.from + 1}-${st.from + st.shown} из ${st.found}${tail}`;
  } else {
    count.textContent = st.found === st.total
      ? `строк: ${st.total}` : `показано ${st.found} из ${st.total}`;
  }
  tailBox.appendChild(count);

  if (st.pages > 1 || st.found > PAGE_SIZES[0][0]) {
    tailBox.appendChild(pager(tab, true));
  }
  return bar;
}

// Заголовок колонки. Сортируемым он становится сам - по тому, есть ли для его
// подписи ключ в spec.sorts; вкладке остаётся только перечислить подписи.
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
    viewReset(tab);
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

// --- материалы ------------------------------------------------------------

function renderMaterials(view) {
  // Предмет выбирается поиском, а не набирается номером: id самоцвета никто
  // наизусть не помнит, а заводить их предстоит сотнями. Поиск ходит и по
  // русскому имени, и по номеру, так что путь «знаю id» тоже остался.
  const mem = addMemory('materials', { role: 'insert', stat: 3, value: 4 });
  let picked = null;
  const pickBox = el('div', 'row');
  const pickName = el('span', 'muted', 'не выбран');
  const pickBtn = el('button', 'btn ghost', 'Выбрать');
  pickBox.appendChild(pickName);
  pickBox.appendChild(pickBtn);
  pickBtn.addEventListener('click', () => openItemPicker({
    title: 'Материал верстака',
  }, (entry, item) => {
    picked = { entry, item };
    pickName.className = '';
    pickName.textContent = `${item.name_ru || item.name} · id ${entry}`;
    // Подпись у материала своя: она едет в аддон вместо клиентского имени.
    // Подставляем имя предмета, пока владелец не написал другое.
    if (!name.value) name.value = item.name_ru || item.name || '';
  }));

  const role = select(Object.entries(ROLES), mem.role);
  // Признак у материала один, и какой - решает роль: у материала ячейки род,
  // у камня тип вставки (DESIGN §2.5). Поэтому список один, а его содержимое
  // меняется вместе с ролью.
  const kind = el('select');
  const fillKind = () => {
    kind.innerHTML = '';
    const rows = role.value === 'base' ? PART_KINDS : INSERT_TYPES;
    dictOptions(rows, 0).forEach(([v, label]) => {
      const o = el('option', null, label);
      o.value = v;
      kind.appendChild(o);
    });
  };
  fillKind();
  if (mem.kind) kind.value = mem.kind;
  role.addEventListener('change', () => { fillKind(); mem.role = role.value; });
  kind.addEventListener('change', () => { mem.kind = kind.value; });
  const stat = select(statOptions(), mem.stat);
  stat.addEventListener('change', () => { mem.stat = stat.value; });
  const value = el('input'); value.type = 'number';
  value.value = mem.value; value.min = 0;
  value.addEventListener('change', () => { mem.value = value.value; });
  const lo = el('input'); lo.type = 'number'; lo.value = mem.lo || 0; lo.min = 0;
  lo.addEventListener('change', () => { mem.lo = lo.value; });
  const hi = el('input'); hi.type = 'number'; hi.value = mem.hi || 0; hi.min = 0;
  hi.addEventListener('change', () => { mem.hi = hi.value; });
  const name = el('input'); name.type = 'text'; name.placeholder = 'необязательно';
  view.appendChild(addBar(
    [['предмет', pickBox], ['роль', role], ['род / тип', kind],
     ['стат', stat], ['величина', value], ['илвл от', lo], ['илвл до', hi],
     ['подпись', name]],
    () => {
      if (!picked) { toast('Сначала выберите предмет.', 'err'); return; }
      return saveMaterial({
      entry: picked.entry,
      role: role.value,
      part_kind_id: role.value === 'base' ? parseInt(kind.value, 10) : 0,
      insert_type_id: role.value === 'base' ? 0 : parseInt(kind.value, 10),
      stat_type: parseInt(stat.value, 10),
      stat_value: parseInt(value.value, 10) || 0,
      ilvl_min: parseInt(lo.value, 10) || 0,
      ilvl_max: parseInt(hi.value, 10) || 0,
      name_ru: name.value,
      enabled: true,
      });
    }));

  const spec = {
    placeholder: 'поиск по имени, подписи или id',
    search: m => [m.entry, m.name_ru, m.item && m.item.name].join(' '),
    picks: [
      { key: 'role', label: 'любая роль', options: Object.entries(ROLES),
        get: m => m.role },
      { key: 'kind', label: 'любой род и тип',
        options: PART_KINDS.map(r => ['k' + r.id, r.name_ru])
          .concat(INSERT_TYPES.map(r => ['t' + r.id, r.name_ru])),
        get: m => (m.role === 'base' ? 'k' + m.part_kind_id
                                     : 't' + m.insert_type_id) },
      // Качество самой строки item_template: по нему идёт строгое совпадение,
      // пока границы не заданы, и «сколько у нас зелёных камней» - первый
      // вопрос при раскладке эскизов (DESIGN §2.5).
      { key: 'q', label: 'любое качество',
        options: (META.qualities || []).map(q => [String(q.quality), q.name_ru]),
        get: m => String(m.quality || 0) },
      { key: 'on', label: 'вкл и выкл',
        options: [['1', 'только включённые'], ['0', 'только выключенные']],
        get: m => m.enabled ? '1' : '0' },
    ],
    sorts: {
      'Предмет': m => (m.item && m.item.name) || String(m.entry),
      'Роль': m => ROLES[m.role] || m.role,
      'Род / тип': m => (m.role === 'base'
        ? dictName(PART_KINDS, m.part_kind_id)
        : dictName(INSERT_TYPES, m.insert_type_id)),
      'Стат': m => statName(m.stat_type),
      'Величина': m => m.stat_value,
      'Илвл от': m => m.ilvl_min,
      'Илвл до': m => m.ilvl_max,
      'Кач. от': m => m.quality_min,
      'Кач. до': m => m.quality_max,
      'Подпись': m => m.name_ru,
      'Вкл': m => (m.enabled ? 1 : 0),
    },
  };
  const rows = applyView('materials', MATS, spec);
  view.appendChild(filterBar('materials', spec));

  const table = el('table', 'grid');
  table.appendChild(headRow('materials',
    ['Предмет', 'Роль', 'Род / тип', 'Стат', 'Величина', 'Илвл от', 'Илвл до',
     'Кач. от', 'Кач. до', 'Подпись', 'Вкл', ''], spec, (th, h) => {
      if (h === 'Кач. от' || h === 'Кач. до') {
        th.title = 'Пока обе границы пусты, действует строгое совпадение: '
          + 'камень идёт только в вещь СВОЕГО качества. Границы - это '
          + 'исключение, 0 значит «с этой стороны предела нет».';
      }
      if (h === 'Илвл от') {
        th.title = 'Нижняя граница: вставка не идёт в предмет уровнем ниже. '
          + '0 - без ограничения.';
      }
      if (h === 'Илвл до') {
        th.title = 'Верхняя граница: вставка не идёт в предмет уровнем выше. '
          + '0 - потолка нет.';
      }
    }));

  rows.forEach(mat => {
    const tr = el('tr', mat.enabled ? '' : 'off');
    const patch = fields => saveMaterial({ ...mat, ...fields });

    tr.appendChild(el('td')).appendChild(itemCell(mat.item, mat.entry));

    // Смена роли уносит с собой и признак: род у камня сервер не примет, а
    // пустой признак - тем более. Подставляем первую включённую строку нужного
    // справочника, дальше владелец поправит одним щелчком.
    tr.appendChild(el('td')).appendChild(
      select(Object.entries(ROLES), mat.role, v => patch({
        role: v,
        part_kind_id: v === 'base' ? firstDictId(PART_KINDS) : 0,
        insert_type_id: v === 'base' ? 0 : firstDictId(INSERT_TYPES),
      })));

    const isBase = mat.role === 'base';
    const dictRows = isBase ? PART_KINDS : INSERT_TYPES;
    const dictValue = isBase ? mat.part_kind_id : mat.insert_type_id;
    tr.appendChild(el('td')).appendChild(
      select(dictOptions(dictRows, dictValue), String(dictValue),
             v => patch(isBase ? { part_kind_id: parseInt(v, 10) }
                               : { insert_type_id: parseInt(v, 10) })));

    tr.appendChild(el('td')).appendChild(
      select(statOptions(), mat.stat_type,
             v => patch({ stat_type: parseInt(v, 10) })));

    const val = el('td', 'num');
    val.appendChild(num(mat.stat_value, v => patch({ stat_value: v }), 0));
    tr.appendChild(val);

    // Границы уровня и качества - свойства вставки: материал ячейки кладут в
    // схему, а не в готовый предмет, и сравнивать там не с чем.
    const isInsert = !isBase;
    [['ilvl_min', mat.ilvl_min], ['ilvl_max', mat.ilvl_max],
     ['quality_min', mat.quality_min], ['quality_max', mat.quality_max]]
      .forEach(([col, current]) => {
        const td = el('td', isInsert ? 'num' : 'num dim');
        const input = num(current, v => patch({ [col]: v }), 0);
        input.disabled = !isInsert;
        // Пустые границы качества - это не «не заполнено», а действующее
        // правило: строгое совпадение с качеством самого камня. Говорим об
        // этом прямо в поле, иначе ноль читается как «ограничения нет».
        if (isInsert && col.startsWith('quality')
            && !mat.quality_min && !mat.quality_max) {
          input.title = 'Строгое совпадение: только вещь качества «'
            + qualityName(mat.quality || 0) + '».';
        }
        td.appendChild(input);
        tr.appendChild(td);
      });

    tr.appendChild(el('td')).appendChild(
      text(mat.name_ru, v => patch({ name_ru: v })));

    const on = el('td');
    const chk = el('input');
    chk.type = 'checkbox';
    chk.checked = mat.enabled;
    chk.addEventListener('change', () => patch({ enabled: chk.checked }));
    on.appendChild(chk);
    tr.appendChild(on);

    const act = el('td', 'act');
    const del = el('button', 'btn ghost', 'Удалить');
    del.addEventListener('click', () => removeMaterial(mat));
    act.appendChild(del);
    tr.appendChild(act);

    table.appendChild(tr);
  });
  view.appendChild(table);
}

async function saveMaterial(mat) {
  try {
    await api('/api/aprof/materials', { method: 'PUT', body: JSON.stringify(mat) });
    toast('Сохранено.', 'ok');
    await loadAll();
  } catch (e) { toast(e.message, 'err'); await loadAll(); }
}

async function removeMaterial(mat) {
  if (!confirm(`Убрать материал ${mat.name_ru || mat.entry}?`)) return;
  try {
    await api('/api/aprof/materials/' + mat.entry, { method: 'DELETE' });
    await loadAll();
  } catch (e) { toast(e.message, 'err'); }
}

// --- справочники рода и типа вставки ---------------------------------------
// Две таблицы одной формы, поэтому и рисуются они одной функцией. Разведены
// они нарочно (DESIGN §2.5): «дерево» гнезду доводки не нужно никогда,
// «самоцвет» ячейке ковки - тоже. Раньше оба списка были перечислением в трёх
// местах разом - в базе, в C++ и здесь, - и «кость» стоила правки всех трёх.

async function saveDictRow(path, row) {
  try {
    await api('/api/aprof/' + path, { method: 'PUT', body: JSON.stringify(row) });
    toast('Сохранено.', 'ok');
    await loadAll();
  } catch (e) { toast(e.message, 'err'); await loadAll(); }
}

async function removeDictRow(path, row) {
  if (!confirm(`Убрать «${row.name_ru}»?`)) return;
  try {
    await api(`/api/aprof/${path}/${row.id}`, { method: 'DELETE' });
    await loadAll();
  } catch (e) { toast(e.message, 'err'); }
}

function dictTable(title, path, rows, usedBy) {
  const box = el('div', 'card');
  box.appendChild(el('h2', null, title));

  const code = el('input'); code.type = 'text'; code.placeholder = 'bone';
  const name = el('input'); name.type = 'text'; name.placeholder = 'Кость';
  const sort = el('input'); sort.type = 'number'; sort.value = 50; sort.min = 0;
  box.appendChild(addBar(
    [['код', code], ['имя', name], ['порядок', sort]],
    () => saveDictRow(path, {
      id: 0, code: code.value, name_ru: name.value,
      sort: parseInt(sort.value, 10) || 0, enabled: true,
    })));

  const table = el('table', 'grid');
  const head = el('tr');
  ['Код', 'Имя', 'Порядок', 'Материалов', 'Вкл', ''].forEach(
    h => head.appendChild(el('th', null, h)));
  table.appendChild(head);

  rows.forEach(row => {
    const tr = el('tr', row.enabled ? '' : 'off');
    const patch = fields => saveDictRow(path, { ...row, ...fields });

    tr.appendChild(el('td')).appendChild(
      text(row.code, v => patch({ code: v })));
    tr.appendChild(el('td')).appendChild(
      text(row.name_ru, v => patch({ name_ru: v })));
    const sortTd = el('td', 'num');
    sortTd.appendChild(num(row.sort, v => patch({ sort: v }), 0));
    tr.appendChild(sortTd);

    // Сколько материалов на строку ссылается. Это и есть ответ на вопрос,
    // почему её не дают убрать, - без него отказ выглядел бы капризом. Ячейки
    // схемы сюда не входят: они грузятся по одному типу за раз. Их считает
    // сервер и называет в отказе.
    const used = usedBy(row);
    tr.appendChild(el('td', 'num', String(used)));

    const on = el('td');
    const chk = el('input');
    chk.type = 'checkbox';
    chk.checked = row.enabled;
    chk.title = 'Выключенная строка не предлагается в списках, но уже '
      + 'проставленная остаётся на месте.';
    chk.addEventListener('change', () => patch({ enabled: chk.checked }));
    on.appendChild(chk);
    tr.appendChild(on);

    const act = el('td', 'act');
    const del = el('button', 'btn ghost', 'Убрать');
    del.disabled = used > 0;
    if (used > 0) {
      del.title = 'На строку ссылаются материалы - сперва переведите их.';
    }
    del.addEventListener('click', () => removeDictRow(path, row));
    act.appendChild(del);
    tr.appendChild(act);

    table.appendChild(tr);
  });

  box.appendChild(table);
  return box;
}

function renderDicts(view) {
  view.appendChild(dictTable(
    'Род материала',
    'part-kinds', PART_KINDS,
    row => MATS.filter(m => m.role === 'base'
                            && m.part_kind_id === row.id).length));

  view.appendChild(dictTable(
    'Тип вставки',
    'insert-types', INSERT_TYPES,
    row => MATS.filter(m => m.role !== 'base'
                            && m.insert_type_id === row.id).length));
}

// --- основы ---------------------------------------------------------------

function subclassOptions(itemClass) {
  const map = itemClass === 4 ? META.armor_subclasses : META.weapon_subclasses;
  return Object.entries(map);
}

// --- рецепты --------------------------------------------------------------
// Разворот 2026-09-02: рецепт - это точный набор предметов по ячейкам и
// готовое изделие на каждую ступень качества. Ничего не вычисляется, поэтому
// вкладка занимается не числами, а содержанием: что кладут, что выходит и
// каким качеством это может выйти.

function qualityOptions() {
  return (META.qualities || []).map(
    q => [q.quality, `${q.name_ru} (${q.slots} сл.)`]);
}

function qualityName(quality) {
  const q = (META.qualities || []).find(x => x.quality === quality);
  return q ? q.name_ru : String(quality);
}

// Список претензий к строке. Показываем их прямо под ней, а не прячем в
// подсказку кнопки: рецепт с дырой выглядит рабочим, а в игре это «кнопка
// молча не работает».
function issuesRow(issues, span) {
  const tr = el('tr', 'issues');
  const td = el('td');
  td.colSpan = span;
  issues.forEach(text => td.appendChild(el('div', 'warn', '• ' + text)));
  tr.appendChild(td);
  return tr;
}

function renderRecipes(view) {

  const typeName = id => {
    const t = TYPES.find(x => x.id === id);
    return t ? t.name_ru : String(id);
  };

  // Полоса добавления заводит основу ЦЕЛИКОМ: строку рецепта, изделие на
  // каждую ступень диапазона и слайс пула под каждое. Раньше здесь были имя и
  // тип, а всё остальное - три захода в модалки, и на полусотне основ это
  // складывалось в сотни кликов.
  const mem = addMemory('recipes', { qmin: 1, qmax: 1, acquire: 'forge' });
  const name = el('input');
  name.type = 'text';
  name.placeholder = 'Стальной клинок';
  const type = select(TYPES.map(t => [t.id, t.name_ru]), mem.type);
  type.addEventListener('change', () => { mem.type = type.value; });
  const qmin = select(qualityOptions(), mem.qmin);
  qmin.addEventListener('change', () => { mem.qmin = qmin.value; });
  const qmax = select(qualityOptions(), mem.qmax);
  qmax.addEventListener('change', () => { mem.qmax = qmax.value; });
  const acquire = select(Object.entries(ACQUIRE), mem.acquire);

  // Образец - предмет игры, с которого изделия снимут всё: урон, слот, вид,
  // звук, флаги. Без него основа заводится пустой, и изделия придётся
  // заводить отдельно.
  const sample = itemPickBox({
    title: 'Образец основы',
  });

  // Книга задаётся сразу, а не отдельным заходом в строку таблицы: рецепт без
  // неё можно только угадать, и «завести основу» без этого выбора - половина
  // дела. В памяти полосы книга НЕ живёт: одна книга учит одному рецепту
  // (сервер берёт первого владельца перебором), и подставленная от прошлой
  // строки она гарантировала бы отказ.
  const teach = itemPickBox({
    title: 'Обучающий предмет основы',
    empty: 'только угадать',
  });

  const acquireChanged = () => {
    mem.acquire = acquire.value;
    // Дроп-основу не куют, и книга обещала бы рецепт, которого не сковать
    // (DESIGN §2.5). Сервер такую пару отказывается принимать - гасим до
    // отказа, а не после.
    teach.disable(acquire.value === 'drop',
      'Дроп-основу не куют: книга ей ничего не даст. Именные эскизы учатся '
      + 'своими книгами.');
  };
  acquire.addEventListener('change', acquireChanged);
  acquireChanged();

  view.appendChild(addBar(
    [['имя', name], ['тип', type], ['качество от', qmin], ['до', qmax],
     ['откуда', acquire], ['обучение', teach], ['образец', sample]],
    () => createRecipe({
      id: 0, type_id: parseInt(type.value, 10) || 0, name_ru: name.value,
      req_skill: acquire.value === 'drop' ? 0 : 1,
      teach_item: teach.entry,
      quality_min: parseInt(qmin.value, 10) || 1,
      quality_max: parseInt(qmax.value, 10) || 1,
      acquire: acquire.value,
      enabled: false,
    }, sample.entry)));

  const spec = {
    placeholder: 'поиск по имени рецепта или типу',
    search: r => [r.name_ru, r.type_name].join(' '),
    picks: [
      { key: 'type', label: 'любой тип',
        options: TYPES.map(t => [t.id, t.name_ru]), get: r => r.type_id },
      { key: 'on', label: 'вкл и выкл',
        options: [['1', 'только включённые'], ['0', 'только выключенные']],
        get: r => r.enabled ? '1' : '0' },
      { key: 'ready', label: 'готовые и нет',
        options: [['1', 'без замечаний'], ['0', 'с замечаниями']],
        get: r => (r.issues || []).length ? '0' : '1' },
      { key: 'acquire', label: 'ковка и добыча',
        options: Object.entries(ACQUIRE),
        get: r => r.acquire || 'forge' },
      { key: 'teach', label: 'как достаётся',
        options: [['1', 'есть обучающий предмет'], ['0', 'только угадать']],
        get: r => r.teach_item ? '1' : '0' },
    ],
    sorts: {
      'Имя': r => r.name_ru,
      'Тип': r => r.type_name,
      'Откуда': r => r.acquire || 'forge',
      'Набор': r => (r.cells || []).filter(c => c.item_entry).length,
      'Навык': r => r.req_skill,
      'Качество': r => r.quality_min * 10 + r.quality_max,
      'Изделия': r => r.ready_steps,
      'Гнёзда': r => Math.max(0, ...(r.inlay || []).map(i => i.patterns)),
      'Вкл': r => (r.enabled ? 1 : 0),
    },
  };
  const rows = applyView('recipes', RECIPES, spec);
  view.appendChild(filterBar('recipes', spec));

  const heads = ['Имя', 'Тип', 'Откуда', 'Набор', 'Навык', 'Обучение',
                 'Качество', 'Изделия', 'Гнёзда', 'Вкл', ''];
  const table = el('table', 'grid');
  table.appendChild(headRow('recipes', heads, spec, (th, h) => {
    if (h === 'Навык') {
      th.title = 'Требуемый навык. От разрыва с ним считается шанс успеха.';
    }
    if (h === 'Обучение') {
      th.title = 'Обучающий предмет. Пусто — рецепт можно только угадать.';
    }
    if (h === 'Откуда') {
      th.title = 'Куётся на верстаке или приходит только добычей. Дроп-основе '
        + 'ковочная половина не нужна вовсе: ни набора, ни навыка, ни книги.';
    }
    if (h === 'Гнёзда') {
      th.title = 'Сколько разных наборов вставок даёт основа на верхней '
        + 'ступени и сколько камней ей подходит. Оба фильтра только сужают: '
        + 'чем уже основа, тем дешевле она пулу id.';
    }
  }));

  rows.forEach(rec => {
    const tr = el('tr', rec.enabled ? '' : 'off');
    // Якорь для перехода со «Связей»: карта приводит к строке, а не просто
    // открывает вкладку с восемью десятками рецептов.
    tr.dataset.recipeId = rec.id;
    const patch = fields => saveRecipe({
      id: rec.id, type_id: rec.type_id, name_ru: rec.name_ru,
      req_skill: rec.req_skill, teach_item: rec.teach_item,
      quality_min: rec.quality_min, quality_max: rec.quality_max,
      acquire: rec.acquire, enabled: rec.enabled, ...fields,
    });

    // Дроп-основу не куют: её ковочная половина не то что не нужна, она
    // обманывает - обещает набор, навык и книгу, которых не существует
    // (DESIGN §2.5). Поэтому не прячем, а гасим: столбцы остаются на своих
    // местах, и таблица не разъезжается от строки к строке.
    const drop = rec.acquire === 'drop';

    tr.appendChild(el('td')).appendChild(
      text(rec.name_ru, v => patch({ name_ru: v })));
    tr.appendChild(el('td')).appendChild(
      select(TYPES.map(t => [t.id, t.name_ru]), rec.type_id,
             v => patch({ type_id: parseInt(v, 10) })));

    // Набор. Сколько ячеек схемы заполнено — по этому числу видно, дописан ли
    // рецепт: пустые ячейки в точном сравнении значат «пусто», а не «любой».
    // Способ получения. Поле несущее: без него игрок сковал бы эпическую
    // основу на верстаке и обошёл рейд.
    tr.appendChild(el('td')).appendChild(
      select(Object.entries(ACQUIRE), rec.acquire || 'forge', v => patch({
        acquire: v,
        // Ковочная половина уезжает вместе со способом: сервер её у дроп-основы
        // не примет, а оставленная книга обещала бы рецепт, которого не сковать.
        teach_item: v === 'drop' ? 0 : rec.teach_item,
        req_skill: v === 'drop' ? 0 : rec.req_skill,
      })));

    const cells = rec.cells || [];
    const filled = cells.filter(c => c.item_entry).length;
    const cellsTd = el('td');
    if (drop) {
      cellsTd.appendChild(el('span', 'hint', '—'));
      cellsTd.title = 'Дроп-основу не куют: набор ячеек ей не нужен.';
    } else {
      const cellsBtn = el('button', filled ? 'btn ghost' : 'btn ghost warn',
                          `ячеек: ${filled} из ${cells.length}`);
      cellsBtn.title = 'Что и в какой ячейке должно лежать.';
      cellsBtn.addEventListener('click', () => openCellsEditor(rec));
      cellsTd.appendChild(cellsBtn);
    }
    tr.appendChild(cellsTd);

    const skill = el('td', 'num');
    const skillInput = num(rec.req_skill, v => patch({ req_skill: v }), 0);
    skillInput.disabled = drop;
    if (drop) {
      skill.title = 'Навык растёт на ковке, а ковки у дроп-основы нет.';
    }
    skill.appendChild(skillInput);
    tr.appendChild(skill);

    if (drop) {
      const teachTd = el('td');
      teachTd.appendChild(el('span', 'hint', '—'));
      teachTd.title = 'Книга обещала бы рецепт, которого не сковать. Именные '
        + 'эскизы учатся своими книгами.';
      tr.appendChild(teachTd);
    } else {
      tr.appendChild(itemPickCell(rec.teach, rec.teach_item, {
        title: 'Обучающий предмет: ' + rec.name_ru,
        empty: 'только угадать',
      }, entry => patch({ teach_item: entry })));
    }

    // Границы качества у основы: проценты общие, а диапазон свой (§5.4.5).
    const qual = el('td');
    const qrow = el('div', 'row');
    qrow.appendChild(select(qualityOptions(), rec.quality_min,
                            v => patch({ quality_min: parseInt(v, 10) })));
    qrow.appendChild(el('span', null, '—'));
    qrow.appendChild(select(qualityOptions(), rec.quality_max,
                            v => patch({ quality_max: parseInt(v, 10) })));
    qual.appendChild(qrow);
    tr.appendChild(qual);

    const res = el('td');
    const ready = rec.ready_steps === rec.steps && rec.steps > 0;
    const resBtn = el('button', ready ? 'btn ghost' : 'btn ghost warn',
                      `готово ${rec.ready_steps} из ${rec.steps}`);
    resBtn.title = 'Изделия рецепта: по строке item_template на ступень.';
    resBtn.addEventListener('click', () => openResultsEditor(rec));
    res.appendChild(resBtn);
    tr.appendChild(res);

    // Гнёзда: сколько эскизов даёт верхняя ступень и сколько камней ей
    // подходит. Ступень берём верхнюю - она самая дорогая пулу id, и именно
    // по ней считается запас слайса.
    const slots = el('td');
    const steps = rec.inlay || [];
    const top = steps.length ? steps[steps.length - 1] : null;
    const dry = steps.some(st => st.slots && !st.gems);
    const label = top
      ? `${top.patterns} эскиз. · ${top.gems} кам.`
      : 'нет ступеней';
    const slotBtn = el('button', dry ? 'btn ghost warn' : 'btn ghost', label);
    slotBtn.title = steps.length
      ? steps.map(st => `${qualityName(st.quality)}: гнёзд ${st.slots}, `
          + `камней ${st.gems}, эскизов ${st.patterns}`).join(String.fromCharCode(10))
      : 'Изделий нет — считать нечего.';
    slotBtn.addEventListener('click', () => openFiltersEditor(rec));
    slots.appendChild(slotBtn);
    tr.appendChild(slots);

    const on = el('td');
    const chk = el('input');
    chk.type = 'checkbox';
    chk.checked = rec.enabled;
    chk.addEventListener('change', () => patch({ enabled: chk.checked }));
    on.appendChild(chk);
    tr.appendChild(on);

    const act = el('td', 'act');
    const del = el('button', 'btn ghost', 'Удалить');
    del.addEventListener('click', () => removeRecipe(rec));
    act.appendChild(del);
    tr.appendChild(act);

    table.appendChild(tr);
    if ((rec.issues || []).length) {
      table.appendChild(issuesRow(rec.issues, heads.length));
    }
  });
  view.appendChild(table);
}

// Завести основу целиком: строка рецепта, изделие на каждую ступень диапазона
// и слайс пула под каждое изделие. Без образца заводится одна строка - тогда
// изделия привязываются вручную на «Изделиях».
async function createRecipe(rec, sample) {
  if (!rec.name_ru.trim()) { toast('Дайте основе имя.', 'err'); return; }
  try {
    const res = await api('/api/aprof/recipes',
                          { method: 'PUT', body: JSON.stringify(rec) });
    let made = null;
    if (sample) {
      made = await api(`/api/aprof/recipes/${res.id}/results/generate`, {
        method: 'POST', body: JSON.stringify({ sample_entry: sample }),
      });
    }
    const done = made ? made.created.length : 0;
    toast(done
      ? `Основа заведена: изделий ${done}, слайсы нарезаны. Осталось задать `
        + 'набор ячеек и включить.'
      : 'Основа заведена. Теперь изделия и набор ячеек.', 'ok');
    await loadAll();
  } catch (e) { toast(e.message, 'err'); await loadAll(); }
}

async function saveRecipe(rec) {
  try {
    const res = await api('/api/aprof/recipes',
                          { method: 'PUT', body: JSON.stringify(rec) });
    toast(res.note || 'Сохранено.', res.note ? 'warn' : 'ok');
    await loadAll();
  } catch (e) { toast(e.message, 'err'); await loadAll(); }
}

async function removeRecipe(rec) {
  if (!confirm(`Удалить рецепт «${rec.name_ru}»? Заведённые изделия `
               + `останутся в каталоге предметов.`)) return;
  try {
    await api('/api/aprof/recipes/' + rec.id, { method: 'DELETE' });
    await loadAll();
  } catch (e) { toast(e.message, 'err'); }
}

// --- типы предметов -------------------------------------------------------
// Тип — то, что игрок выбирает в левом списке верстака: «меч», «щит». Ему
// принадлежит схема ячеек, и только она. Скорость и слот надевания убраны
// (разворот 2026-09-02): это свойства ОСНОВЫ, то есть строки-результата
// рецепта, и живут они там же, где урон и качество. Класс с подклассом пока
// оставлены — по ним панель ищет донора внешнего вида и фильтрует материалы.

function renderTypes(view) {
  const name = el('input'); name.type = 'text'; name.placeholder = 'Булава';
  const code = el('input'); code.type = 'text'; code.placeholder = 'mace';
  const preset = select(META.type_presets.map(p => [p.id, p.label]), 'sword1h');
  view.appendChild(addBar(
    [['имя', name], ['код', code], ['заготовка', preset]],
    () => {
      const p = META.type_presets.find(x => x.id === preset.value)
                || META.type_presets[0];
      saveType({
        id: 0, code: code.value || p.id, name_ru: name.value, sub_ru: '',
        item_class: p.item_class, item_subclass: p.item_subclass,
        displayid: p.displayid, sheet_art: '', sort: 100, enabled: true,
      });
    }));

  const spec = {
    placeholder: 'поиск по имени, коду или подписи',
    search: t => [t.name_ru, t.sub_ru, t.code, t.sheet_art].join(' '),
    picks: [
      { key: 'class', label: 'любой класс',
        options: Object.entries(META.item_classes),
        get: t => t.item_class },
      { key: 'on', label: 'вкл и выкл',
        options: [['1', 'только включённые'], ['0', 'только выключенные']],
        get: t => t.enabled ? '1' : '0' },
      { key: 'parts', label: 'части: любые',
        options: [['1', 'со схемой'], ['0', 'без частей']],
        get: t => t.parts ? '1' : '0' },
    ],
    sorts: {
      'Имя': t => t.name_ru,
      'Подпись': t => t.sub_ru,
      'Код': t => t.code,
      'Класс': t => (META.item_classes || {})[t.item_class] || t.item_class,
      'Подкласс': t => t.item_subclass,
      'Чертёж': t => t.sheet_art || '',
      'Порядок': t => t.sort,
      'Вкл': t => (t.enabled ? 1 : 0),
      'Частей': t => t.parts,
      'Рецептов': t => t.recipes,
    },
  };
  const rows = applyView('types', TYPES, spec);
  view.appendChild(filterBar('types', spec));

  const table = el('table', 'grid');
  table.appendChild(headRow('types',
    ['Имя', 'Подпись', 'Код', 'Класс', 'Подкласс', 'Внешний вид', 'Чертёж',
     'Поделка', 'Порядок', 'Вкл', 'Частей', 'Рецептов', ''], spec, (th, h) => {
      if (h === 'Чертёж') {
        th.title = 'Имя файла из textures аддона, без пути и расширения: '
          + 'item-sword. Пусто — аддон возьмёт своё умолчание по классу.';
      }
      if (h === 'Поделка') {
        th.title = 'Серая вещь, которую выдаёт набор без рецепта. Нужна, пока '
          + 'fail_mode = 2.';
      }
    }));

  rows.forEach(t => {
    const tr = el('tr', t.enabled ? '' : 'off');
    const patch = fields => saveType({ ...t, ...fields });

    tr.appendChild(el('td')).appendChild(text(t.name_ru, v => patch({ name_ru: v })));
    tr.appendChild(el('td')).appendChild(text(t.sub_ru, v => patch({ sub_ru: v })));
    tr.appendChild(el('td')).appendChild(text(t.code, v => patch({ code: v })));

    tr.appendChild(el('td')).appendChild(
      select(Object.entries(META.item_classes), t.item_class,
             v => patch({ item_class: parseInt(v, 10) })));
    tr.appendChild(el('td')).appendChild(
      select(subclassOptions(t.item_class), t.item_subclass,
             v => patch({ item_subclass: parseInt(v, 10) })));

    tr.appendChild(lookCell(t.icon, t.displayid, {
      title: 'Внешний вид по умолчанию: ' + t.name_ru,
      itemClass: t.item_class, itemSubclass: t.item_subclass,
    }, id => patch({ displayid: id })));

    // Соответствие «тип - рисунок» правится здесь, а не в Lua: рисунки
    // делались руками, и какой файл какому оружию отвечает - содержание.
    const art = el('td');
    const artInput = text(t.sheet_art || '', v => patch({ sheet_art: v }));
    artInput.placeholder = 'item-sword';
    art.appendChild(artInput);
    tr.appendChild(art);

    // Поделка: одна серая строка на тип. Заводится копией образца, дальше
    // правится в каталоге - как и изделия рецептов.
    const failTd = itemPickCell(t.fail_item, t.fail_entry, {
      title: 'Поделка: ' + t.name_ru, empty: 'не заведена',
    }, entry => patch({ fail_entry: entry }));
    if (!t.fail_entry) {
      const make = el('button', 'btn ghost', 'Создать');
      make.title = 'Копия образца станет поделкой: серое качество и имя '
        + '«Испорченный …» проставятся сами.';
      make.addEventListener('click', () => openItemPicker({
        title: 'Образец для поделки: ' + t.name_ru,
      }, entry => makeFailItem(t, entry)));
      failTd.querySelector('.row').appendChild(make);
    }
    tr.appendChild(failTd);

    const sort = el('td', 'num');
    sort.appendChild(num(t.sort, v => patch({ sort: v }), 0));
    tr.appendChild(sort);

    const on = el('td');
    const chk = el('input');
    chk.type = 'checkbox';
    chk.checked = t.enabled;
    chk.addEventListener('change', () => patch({ enabled: chk.checked }));
    on.appendChild(chk);
    tr.appendChild(on);

    // Тип без частей не выкуешь, и в игре это выглядит как мёртвая строка.
    const partsTd = el('td', t.parts ? 'num' : 'num warn');
    // Через дробь - сколько из них обязательные: столько гнёзд игрок обязан
    // заполнить, иначе «Ковать» у него не нажмётся (DESIGN §5.4.1).
    partsTd.textContent = t.required_parts
      ? `${t.parts} / ${t.required_parts}` : String(t.parts);
    partsTd.title = t.required_parts
      ? `Ячеек ${t.parts}, из них обязательных ${t.required_parts}.`
      : 'Ни одной обязательной ячейки: любую можно оставить пустой.';
    tr.appendChild(partsTd);
    tr.appendChild(el('td', 'num', String(t.recipes)));

    const act = el('td', 'act');
    const partsBtn = el('button', 'btn ghost', 'Части');
    partsBtn.title = 'Схема: из каких частей собирается этот тип.';
    partsBtn.addEventListener('click', () => openPartsEditor(t));
    act.appendChild(partsBtn);

    const del = el('button', 'btn ghost', 'Удалить');
    del.addEventListener('click', () => removeType(t));
    act.appendChild(del);
    tr.appendChild(act);

    table.appendChild(tr);
    if ((t.issues || []).length) table.appendChild(issuesRow(t.issues, 13));
  });
  view.appendChild(table);
}

async function makeFailItem(itemType, sampleEntry) {
  try {
    const res = await api(`/api/aprof/types/${itemType.id}/fail-item`, {
      method: 'POST', body: JSON.stringify({ sample_entry: sampleEntry }),
    });
    toast('Заведена поделка ' + res.entry + '. Правьте её в каталоге.', 'ok');
    await loadAll();
  } catch (e) { toast(e.message, 'err'); }
}

async function saveType(t) {
  try {
    await api('/api/aprof/types', { method: 'PUT', body: JSON.stringify(t) });
    toast('Сохранено.', 'ok');
    await loadAll();
  } catch (e) { toast(e.message, 'err'); await loadAll(); }
}

async function removeType(t) {
  if (!confirm(`Удалить тип «${t.name_ru}» вместе с его частями?`)) return;
  try {
    await api('/api/aprof/types/' + t.id, { method: 'DELETE' });
    await loadAll();
  } catch (e) { toast(e.message, 'err'); }
}

// --- части типа -----------------------------------------------------------
// Части — это и есть реагенты: чем куётся основа и что она получит от каждого
// материала. Часть требует РОД («металл»), а конкретный слиток выбирает игрок
// у верстака.

async function openPartsEditor(itemType) {
  const back = el('div', 'ap-modal-back');
  const box = el('div', 'ap-modal');
  back.appendChild(box);
  back.addEventListener('click', ev => { if (ev.target === back) back.remove(); });

  const head = el('div', 'row');
  head.appendChild(el('h2', null, 'Части типа: ' + itemType.name_ru));
  const gap = el('span');
  gap.style.flex = '1';
  head.appendChild(gap);
  const closeBtn = el('button', 'btn ghost', 'Закрыть');
  closeBtn.addEventListener('click', () => { back.remove(); loadAll(); });
  head.appendChild(closeBtn);
  box.appendChild(head);

  const body = el('div');
  box.appendChild(body);
  document.body.appendChild(back);

  async function save(part) {
    try {
      await api(`/api/aprof/types/${itemType.id}/parts`, {
        method: 'PUT', body: JSON.stringify({ ...part, type_id: itemType.id }),
      });
      toast('Сохранено.', 'ok');
      draw();
    } catch (e) {
      toast(e.message, 'err');
      // Перерисовываем и на отказе: иначе галочка «обязательна» осталась бы
      // стоять там, где сервер её не принял, и окно врало бы о состоянии базы.
      draw();
    }
  }

  async function remove(idx) {
    if (!confirm('Убрать часть ' + idx + '? Уже собранные предметы держат ' +
                 'материалы по порядку частей — их смысл сдвинется, а условия ' +
                 'рецептов на эту часть будут удалены.')) return;
    try {
      await api(`/api/aprof/types/${itemType.id}/parts/${idx}`, { method: 'DELETE' });
      draw();
    } catch (e) { toast(e.message, 'err'); }
  }

  async function draw() {
    body.innerHTML = '';
    let rows;
    try {
      rows = (await api(`/api/aprof/types/${itemType.id}/parts`)).parts;
    } catch (e) {
      body.appendChild(el('div', 'empty', e.message));
      return;
    }

    const table = el('table', 'grid');
    const headRow = el('tr');
    // У ячейки три свойства: подпись, род и обязательность. Проценты вклада,
    // флаг прока, координаты выноски, расход, текстура и материал по умолчанию
    // убраны миграцией v15 - числа изделия приходят из результата рецепта,
    // расход задаёт рецепт, геометрия живёт в аддоне, а пустая ячейка стала
    // законной частью набора (DESIGN §5.4.1).
    ['#', 'Подпись', 'Род', 'Обязательна', '']
      .forEach(h => {
        const th = el('th', null, h);
        headRow.appendChild(th);
      });
    table.appendChild(headRow);

    rows.forEach(part => {
      const tr = el('tr');
      const patch = fields => save({ ...part, ...fields });

      tr.appendChild(el('td', null, String(part.idx)));
      tr.appendChild(el('td')).appendChild(
        text(part.label_ru, v => patch({ label_ru: v })));

      const kindTd = el('td');
      // Отсеивать «самоцвет» больше не нужно: он живёт в другом справочнике, и
      // выбрать его ячейке ковки нечем (DESIGN §2.5).
      kindTd.appendChild(select(dictOptions(PART_KINDS, part.part_kind_id),
        String(part.part_kind_id),
        v => patch({ part_kind_id: parseInt(v, 10) })));
      // Часть, для рода которой нет ни одного материала, делает основу
      // некуемой — а в игре это выглядит как «кнопка не работает».
      if (!part.choices) {
        kindTd.appendChild(el('div', 'warn', 'нет материалов этого рода'));
      }
      tr.appendChild(kindTd);

      // Обязательная ячейка - часть, без которой предмета не существует:
      // клинок у меча, древко у древкового. Игрок не сможет ковать, пока она
      // пуста, а рецепт, который её не называет, панель не даст включить.
      const needTd = el('td');
      const need = el('input');
      need.type = 'checkbox';
      need.checked = !!part.required;
      need.title = 'Без этой части предмет не собрать: пустой её не оставить, '
        + 'и каждый рецепт этого типа обязан её называть.';
      need.addEventListener('change',
        () => patch({ required: need.checked ? 1 : 0 }));
      needTd.appendChild(need);
      tr.appendChild(needTd);

      const act = el('td', 'act');
      const del = el('button', 'btn ghost', 'Убрать');
      del.addEventListener('click', () => remove(part.idx));
      act.appendChild(del);
      tr.appendChild(act);

      table.appendChild(tr);
    });
    body.appendChild(table);

    const addRow = el('div', 'row');
    addRow.style.marginTop = '10px';
    const label = el('input');
    label.type = 'text';
    label.placeholder = 'Клинок';
    const kind = select(dictOptions(PART_KINDS, 0),
                        String(firstDictId(PART_KINDS)));
    const needBox = el('label', 'hint');
    const needNew = el('input');
    needNew.type = 'checkbox';
    needNew.title = 'Без этой части предмет не собрать.';
    needBox.appendChild(needNew);
    needBox.appendChild(document.createTextNode(' обязательна'));
    const add = el('button', 'btn', 'Добавить часть');
    // Проценты, прок, координаты, число и текстура не шлём вовсе: недостающие
    // поля сервер добирает умолчаниями модели, а в игре они уже ни на что не
    // влияют. Новая часть выходит НЕобязательной: обязательность - это решение
    // о самом предмете, и принимает его владелец галочкой, а не умолчание.
    add.addEventListener('click', () => save({
      idx: rows.length ? Math.max(...rows.map(r => r.idx)) + 1 : 1,
      label_ru: label.value, part_kind_id: parseInt(kind.value, 10),
      required: needNew.checked ? 1 : 0,
    }));
    addRow.appendChild(label);
    addRow.appendChild(kind);
    addRow.appendChild(needBox);
    addRow.appendChild(add);
    body.appendChild(addRow);
  }

  draw();
}

// --- рецепт основы --------------------------------------------------------
// Условия вида «в части N лежит материал X». Пустое условие = «любой»: чем
// подробнее рецепт, тем он сильнее, поэтому частный случай не обязан
// перечислять весь набор.

// --- выбор предмета -------------------------------------------------------
// Рецепту нужны чужие предметы: обучающий свиток, образец для изделия, готовое
// изделие. Все они ищутся в общем каталоге (тот же поиск, что на странице
// «Каталог предметов»), поэтому выбор здесь один на все случаи.

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


  const bar = el('div', 'row');
  const q = el('input');
  q.type = 'search';
  q.placeholder = 'имя или id предмета';
  q.style.flex = '1';
  bar.appendChild(q);
  const only = select([['', 'везде'], ['custom', 'только свои'],
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
      // Вторым доводом уезжает вся строка: тому, кто заводит материал, нужны
      // имя и качество выбранного, а второй запрос за ними был бы лишним.
      cell.addEventListener('click', () => {
        back.remove();
        onPick(item.entry, item);
      });
      list.appendChild(cell);
    });
  }

  q.addEventListener('input', () => {
    clearTimeout(timer);
    timer = setTimeout(search, 250);
  });
  only.addEventListener('change', search);
  search();
}

// Тот же выбор предмета, но для ПОЛОСЫ добавления, а не для ячейки таблицы.
// Разница в том, откуда берётся значение: строка таблицы уже сохранена и
// отдаёт выбор наружу сразу, а полоса копит его до нажатия «Добавить» - и
// хранит сама, в `box.entry`.
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
  // Гасим, а не прячем - как и в строке таблицы: столбец на месте, а подсказка
  // объясняет, почему в нём нечего выбирать.
  box.disable = (off, why) => {
    pick.disabled = off;
    clear.disabled = off;
    box.title = off ? (why || '') : '';
    if (off) box.set(0);
  };

  pick.addEventListener('click',
    () => openItemPicker(opts || {}, (entry, item) => box.set(entry, item)));
  clear.addEventListener('click', () => box.set(0));

  box.appendChild(label);
  box.appendChild(pick);
  box.appendChild(clear);
  return box;
}

// Ячейка таблицы «предмет + выбрать/убрать». Показывает то же, что itemCell,
// плюс две кнопки: без них выбранный предмет некуда было бы поменять.
function itemPickCell(item, entry, opts, onPick) {
  const td = el('td', 'item-pick');
  if (entry) {
    td.appendChild(itemCell(item, entry));
  } else {
    td.appendChild(el('span', 'muted', (opts && opts.empty) || 'не задан'));
  }
  const act = el('div', 'row');
  const pick = el('button', 'btn ghost', entry ? 'Сменить' : 'Выбрать');
  pick.addEventListener('click', () => openItemPicker(opts || {}, onPick));
  act.appendChild(pick);
  if (entry && !(opts && opts.required)) {
    const clear = el('button', 'btn ghost', 'Убрать');
    clear.addEventListener('click', () => onPick(0));
    act.appendChild(clear);
  }
  td.appendChild(act);
  return td;
}

// --- набор рецепта --------------------------------------------------------
// Точное сравнение: тот же предмет в той же ячейке. Единственная поблажка -
// «любой материал»: ячейке безразлично, чем её заполнили (DESIGN §5.4).

async function openCellsEditor(rec) {
  const back = el('div', 'ap-modal-back');
  const box = el('div', 'ap-modal');
  back.appendChild(box);
  back.addEventListener('click', ev => { if (ev.target === back) back.remove(); });

  const head = el('div', 'row');
  head.appendChild(el('h2', null, 'Набор: ' + rec.name_ru));
  const gap = el('span');
  gap.style.flex = '1';
  head.appendChild(gap);
  const closeBtn = el('button', 'btn ghost', 'Закрыть');
  closeBtn.addEventListener('click', () => { back.remove(); loadAll(); });
  head.appendChild(closeBtn);
  box.appendChild(head);

  const body = el('div');
  box.appendChild(body);
  document.body.appendChild(back);

  async function save(row, fields) {
    try {
      await api(`/api/aprof/recipes/${rec.id}/cells`, {
        method: 'PUT',
        body: JSON.stringify({
          part_idx: row.part_idx, item_entry: row.item_entry,
          count: row.count, ...fields,
        }),
      });
      toast('Сохранено.', 'ok');
      draw();
    } catch (e) { toast(e.message, 'err'); }
  }

  async function draw() {
    body.innerHTML = '';
    let data;
    try {
      data = await api(`/api/aprof/recipes/${rec.id}/cells`);
    } catch (e) {
      body.appendChild(el('div', 'empty', e.message));
      return;
    }
    if (!data.rows.length) {
      body.appendChild(el('div', 'empty',
        'У типа нет ни одной ячейки — задайте их на вкладке «Типы предметов».'));
      return;
    }

    const table = el('table', 'grid');
    const hr = el('tr');
    ['Ячейка', 'Род', 'Что должно лежать', 'Расход'].forEach(
      h => hr.appendChild(el('th', null, h)));
    table.appendChild(hr);

    data.rows.forEach(row => {
      const tr = el('tr');
      // Обязательную ячейку помечаем звёздочкой: пустой она быть не может, и
      // рецепт, который её не называет, включить не дадут (DESIGN §5.4.1).
      const nameTd = el('td', null,
        `${row.part_idx}. ${row.label_ru}${row.required ? ' *' : ''}`);
      if (row.required) {
        nameTd.title = 'Обязательная ячейка: без этой части предмета не '
          + 'существует. Оставить её пустой рецепт не может.';
      }
      tr.appendChild(nameTd);
      tr.appendChild(el('td', null, dictName(PART_KINDS, row.part_kind_id)));

      // «Не задано» - это не «всё равно», а требование ПУСТОЙ ячейки: набор
      // сравнивается целиком, и что не лежит, тоже часть набора (DESIGN §5.4).
      // У обязательной ячейки этого выбора нет вовсе - её нечем оставить
      // пустой, поэтому «пусто» там называется отказом.
      const options = [['0', row.required ? '— не задано —' : '— пусто —']]
        .concat(row.options.map(o => [String(o.entry), o.name]));
      const sel = select(options, String(row.item_entry || 0), v => {
        save(row, { item_entry: parseInt(v, 10) || 0 });
      });
      sel.title = row.required
        ? 'Ячейка обязательная: пока материал не выбран, рецепт нельзя '
          + 'включить — сковать его не выйдет.'
        : 'Пусто — рецепт требует, чтобы игрок оставил эту ячейку '
          + 'пустой. Материал — чтобы в ней лежал именно он и именно в '
          + 'указанном количестве.';
      if (row.required && !row.item_entry) sel.classList.add('warn');
      tr.appendChild(el('td')).appendChild(sel);

      const countTd = el('td', 'num');
      const field = num(row.count, v => save(row, { count: v }), 1);
      field.title = 'Сколько единиц уходит из сумки за эту ячейку.';
      countTd.appendChild(field);
      tr.appendChild(countTd);

      table.appendChild(tr);
    });
    body.appendChild(table);
  }

  draw();
}

// --- изделия рецепта ------------------------------------------------------
// Качество тянет за собой число слотов доводки, поэтому «то же изделие, но
// редкое» — это ДРУГАЯ строка item_template (DESIGN §5.4.5). Руками их
// заводить нельзя: четыре ступени = четыре почти одинаковых предмета на
// каждый рецепт. Отсюда кнопка «создать варианты» — копия образца на каждую
// ступень, с проставленным качеством и склонённым именем.

// Чем основе дают себя украшать. Два слоя, разного назначения: набор типов -
// массовый («костяные основы принимают кость», один раз на семейство), список
// материалов - точный («в этот клинок идут вот эти три камня»).
//
// Список СТАРШЕ набора типов, поэтому вместе их не держим: сервер типы просто
// не посмотрит, а в панели они выглядели бы действующим правилом.
async function openFiltersEditor(rec) {
  const back = el('div', 'ap-modal-back');
  const box = el('div', 'ap-modal');
  back.appendChild(box);
  back.addEventListener('click', ev => { if (ev.target === back) back.remove(); });

  const head = el('div', 'row');
  head.appendChild(el('h2', null, 'Гнёзда: ' + rec.name_ru));
  const gap = el('span');
  gap.style.flex = '1';
  head.appendChild(gap);
  const closeBtn = el('button', 'btn ghost', 'Закрыть');
  closeBtn.addEventListener('click', () => { back.remove(); loadAll(); });
  head.appendChild(closeBtn);
  box.appendChild(head);

  const body = el('div');
  box.appendChild(body);
  document.body.appendChild(back);

  let types = (rec.insert_types || []).slice();
  let named = (rec.materials || []).slice();

  async function save() {
    try {
      await api(`/api/aprof/recipes/${rec.id}/filters`, {
        method: 'PUT',
        body: JSON.stringify({ insert_types: types, materials: named }),
      });
      toast('Сохранено.', 'ok');
      const fresh = (await api('/api/aprof/recipes')).recipes
        .find(r => r.id === rec.id);
      if (fresh) {
        rec.inlay = fresh.inlay;
        rec.insert_types = fresh.insert_types;
        rec.materials = fresh.materials;
        types = fresh.insert_types.slice();
        named = fresh.materials.slice();
      }
      draw();
    } catch (e) { toast(e.message, 'err'); draw(); }
  }

  function draw() {
    body.innerHTML = '';

    // Что выходит на каждой ступени. Это и есть ответ на вопрос «не сузил ли
    // я до пустоты»: ноль камней при живых гнёздах рецепт включить не даст.
    const stats = el('table', 'grid');
    const sh = el('tr');
    ['Ступень', 'Гнёзд', 'Подходит камней', 'Эскизов'].forEach(
      h => sh.appendChild(el('th', null, h)));
    stats.appendChild(sh);
    (rec.inlay || []).forEach(st => {
      const tr = el('tr', (st.slots && !st.gems) ? 'off' : '');
      tr.appendChild(el('td', null, qualityName(st.quality)));
      tr.appendChild(el('td', 'num', String(st.slots)));
      tr.appendChild(el('td', 'num', String(st.gems)));
      tr.appendChild(el('td', 'num', String(st.patterns)));
      stats.appendChild(tr);
    });
    body.appendChild(stats);
    if (!(rec.inlay || []).length) {
      body.appendChild(el('div', 'warn',
        'У рецепта нет изделий — гнёзда считать не от чего.'));
    }

    body.appendChild(el('h2', null, 'Типы вставки'));
    const typeBox = el('div', 'row');
    INSERT_TYPES.forEach(t => {
      const lab = el('label', 'hint');
      const chk = el('input');
      chk.type = 'checkbox';
      chk.checked = types.indexOf(t.id) >= 0;
      chk.disabled = named.length > 0;
      chk.addEventListener('change', () => {
        types = chk.checked ? types.concat([t.id])
                            : types.filter(x => x !== t.id);
        save();
      });
      lab.appendChild(chk);
      lab.appendChild(document.createTextNode(' ' + t.name_ru));
      typeBox.appendChild(lab);
    });
    body.appendChild(typeBox);
    if (named.length) {
    }

    body.appendChild(el('h2', null, 'Поимённый список'));
    const matTable = el('table', 'grid');
    insertMats().forEach(m => {
      const tr = el('tr', m.enabled ? '' : 'off');
      const pick = el('td');
      const chk = el('input');
      chk.type = 'checkbox';
      chk.checked = named.indexOf(m.entry) >= 0;
      chk.addEventListener('change', () => {
        named = chk.checked ? named.concat([m.entry])
                            : named.filter(x => x !== m.entry);
        // Список старше типов, и держать оба сервер не даст: снимаем типы
        // сами, чтобы владелец не упирался в отказ на ровном месте.
        if (named.length) types = [];
        save();
      });
      pick.appendChild(chk);
      tr.appendChild(pick);
      tr.appendChild(el('td')).appendChild(itemCell(m.item, m.entry));
      tr.appendChild(el('td', null,
        dictName(INSERT_TYPES, m.insert_type_id)));
      tr.appendChild(el('td', null, qualityName(m.quality || 0)));
      tr.appendChild(el('td', null,
        `${statName(m.stat_type)} +${m.stat_value}`));
      matTable.appendChild(tr);
    });
    body.appendChild(matTable);
  }

  draw();
}

async function openResultsEditor(rec) {
  const back = el('div', 'ap-modal-back');
  const box = el('div', 'ap-modal');
  back.appendChild(box);
  back.addEventListener('click', ev => { if (ev.target === back) back.remove(); });

  const head = el('div', 'row');
  head.appendChild(el('h2', null, 'Изделия: ' + rec.name_ru));
  const gap = el('span');
  gap.style.flex = '1';
  head.appendChild(gap);
  const closeBtn = el('button', 'btn ghost', 'Закрыть');
  closeBtn.addEventListener('click', () => { back.remove(); loadAll(); });
  head.appendChild(closeBtn);
  box.appendChild(head);

  const body = el('div');
  box.appendChild(body);
  document.body.appendChild(back);

  async function setResult(quality, entry) {
    try {
      await api(`/api/aprof/recipes/${rec.id}/results`, {
        method: 'PUT',
        body: JSON.stringify({ quality: quality, result_entry: entry }),
      });
      toast('Сохранено.', 'ok');
      draw();
    } catch (e) { toast(e.message, 'err'); }
  }

  async function generate(sampleEntry) {
    try {
      const res = await api(`/api/aprof/recipes/${rec.id}/results/generate`, {
        method: 'POST', body: JSON.stringify({ sample_entry: sampleEntry }),
      });
      const made = res.created.map(c => `${qualityName(c.quality)} → ${c.entry}`);
      toast(made.length ? 'Заведено: ' + made.join(', ')
                        : 'Все ступени уже заведены.',
            made.length ? 'ok' : 'warn');
      draw();
    } catch (e) { toast(e.message, 'err'); }
  }

  async function draw() {
    body.innerHTML = '';
    let fresh;
    try {
      fresh = (await api('/api/aprof/recipes')).recipes.find(r => r.id === rec.id);
    } catch (e) {
      body.appendChild(el('div', 'empty', e.message));
      return;
    }
    if (!fresh) {
      body.appendChild(el('div', 'empty', 'Рецепт пропал.'));
      return;
    }

    const bar = el('div', 'row');
    const gen = el('button', 'btn', 'Создать варианты по образцу');
    gen.title = 'Копия выбранного предмета на каждую ступень диапазона: '
      + 'качество и имя проставляются сами, остальное наследуется.';
    gen.addEventListener('click', () => openItemPicker({
      title: 'Образец для изделий: ' + fresh.name_ru,
    }, entry => generate(entry)));
    bar.appendChild(gen);
    body.appendChild(bar);

    const table = el('table', 'grid');
    const hr = el('tr');
    ['Качество', 'Слотов', 'Изделие', ''].forEach(
      h => hr.appendChild(el('th', null, h)));
    table.appendChild(hr);

    for (let q = fresh.quality_min; q <= fresh.quality_max; q++) {
      const row = (fresh.results || []).find(r => r.quality === q);
      const meta = (META.qualities || []).find(x => x.quality === q);
      const tr = el('tr');
      tr.appendChild(el('td', null, qualityName(q)));
      tr.appendChild(el('td', 'num', meta ? String(meta.slots) : '?'));
      tr.appendChild(itemPickCell(row && row.item, row && row.result_entry,
                                  { title: `Изделие: ${fresh.name_ru}, `
                                           + qualityName(q),
                                    empty: 'изделия нет' },
                                  entry => setResult(q, entry)));
      const act = el('td', 'act');
      if (row && row.result_entry) {
        const open = el('a', 'btn ghost', 'В каталоге');
        open.href = '/items.html';
        open.target = '_blank';
        open.title = 'Править строку предмета ' + row.result_entry;
        act.appendChild(open);
      }
      tr.appendChild(act);
      table.appendChild(tr);
    }
    body.appendChild(table);

  }

  draw();
}

// --- именные предметы за сочетание вставок --------------------------------

// --- гнездо самоцвета -----------------------------------------------------
// Набор именного сочетания собирается ГНЁЗДАМИ, а не рядом выпадающих списков.
// Камни в игре различаются цветом и картинкой, а в узком select от них
// остаётся обрезанное имя; в игре тот же набор игрок собирает иконками, и
// панель должна показывать то же самое.
//
// Список гнезда сужен до камней, которые эта основа вообще принимает
// (качество, границы уровня и фильтры рецепта - те же четыре условия, что
// проверяет сервер). Иначе панель предлагала бы набор, который в игре не
// собрать: сервер такой камень в гнездо не пустит.

function fittingGems(recipe) {
  const all = insertMats();
  if (!recipe) return all;
  const seen = new Set();
  (recipe.inlay || []).forEach(step => {
    (step.gem_entries || []).forEach(entry => seen.add(entry));
  });
  // Ступеней нет (изделия ещё не заведены) - сужать нечем, и пустое меню
  // выглядело бы поломкой. Показываем всё, замечание об изделиях уже висит.
  if (!seen.size) return all;
  return all.filter(m => seen.has(m.entry));
}

function gemName(entry) {
  const m = MATS.find(x => x.entry === entry);
  if (!m) return String(entry);
  return m.name_ru || (m.item && m.item.name) || String(entry);
}

function openGemMenu(recipe, current, onPick) {
  const back = el('div', 'ap-modal-back');
  const box = el('div', 'ap-modal');
  back.appendChild(box);
  back.addEventListener('click', ev => { if (ev.target === back) back.remove(); });

  const head = el('div', 'row');
  head.appendChild(el('h2', null, 'Вставка в гнездо'));
  const gap = el('span');
  gap.style.flex = '1';
  head.appendChild(gap);
  const closeBtn = el('button', 'btn ghost', 'Закрыть');
  closeBtn.addEventListener('click', () => back.remove());
  head.appendChild(closeBtn);
  box.appendChild(head);

  const gems = fittingGems(recipe);

  const list = el('div', 'look-grid');
  const empty = el('button', 'look-cell');
  empty.appendChild(iconImg(null, 32));
  const emptyNm = el('div', 'nm');
  emptyNm.appendChild(el('b', null, '— пусто —'));
  emptyNm.appendChild(el('small', null, 'убрать из набора'));
  empty.appendChild(emptyNm);
  empty.addEventListener('click', () => { back.remove(); onPick(0); });
  list.appendChild(empty);

  gems.forEach(m => {
    const cell = el('button', 'look-cell' + (m.entry === current ? ' on' : ''));
    cell.appendChild(iconImg(m.item && m.item.icon, 32));
    const nm = el('div', 'nm');
    nm.appendChild(el('b', 'q' + ((m.item && m.item.quality) || 0),
                      m.name_ru || (m.item && m.item.name) || m.entry));
    // Что камень даёт: на вкладке набора это единственный способ отличить
    // два одинаковых на вид самоцвета.
    nm.appendChild(el('small', null,
      `${statName(m.stat_type)} +${m.stat_value}`));
    cell.appendChild(nm);
    cell.addEventListener('click', () => { back.remove(); onPick(m.entry); });
    list.appendChild(cell);
  });
  box.appendChild(list);
  document.body.appendChild(back);
}

// Одно гнездо набора: картинка камня и его имя, клик открывает меню.
function gemSocket(entry, recipe, onPick) {
  const btn = el('button', 'gem-socket' + (entry ? '' : ' empty'));
  const mat = MATS.find(x => x.entry === entry);
  btn.appendChild(iconImg(mat && mat.item && mat.item.icon, 28));
  btn.appendChild(el('span', 'nm', entry ? gemName(entry) : 'пусто'));
  btn.title = entry
    ? 'Сменить вставку или убрать её из набора'
    : 'Выбрать вставку. Пустое гнездо в набор не входит: «малахит и цитрин» '
      + 'в трёх гнёздах — это набор из двух';
  btn.addEventListener('click', () => openGemMenu(recipe, entry, onPick));
  return btn;
}

function matPicker(value, onChange, allowEmpty) {
  // Материалов под тысячу, и такой список тоже незачем строить, пока в него
  // не заглянули.
  const options = () => {
    const rows = insertMats().map(m => [m.entry, m.name_ru]);
    if (allowEmpty) rows.unshift(['0', '— пусто —']);
    return rows;
  };
  const first = insertMats()[0];
  const current = value || (allowEmpty ? 0 : (first && first.entry) || 0);
  const label = current ? gemName(current) : '— пусто —';
  return lazySelect(options, current, label,
                    v => onChange(parseInt(v, 10)));
}

function renderNamed(view) {
  const matName = entry => {
    const m = MATS.find(x => x.entry === entry);
    return m ? (m.name_ru || (m.item && m.item.name) || entry) : entry;
  };
  const recipeOptions = () => RECIPES.map(r => [r.id, r.name_ru]);

  const mem = addMemory('named', {});
  const name = el('input');
  name.type = 'text';
  name.placeholder = 'Клинок ловчего';
  const owner = select(recipeOptions(), mem.recipe);
  owner.addEventListener('change', () => { mem.recipe = owner.value; draw(); });

  // Набор задаётся целиком прямо в полосе добавления: раньше здесь была
  // «первая вставка», а остальные дописывались в строке таблицы - то есть
  // сочетание из трёх камней заводилось в четыре захода.
  let draft = [];
  const sockets = el('div', 'row');
  const counter = el('span', 'muted');

  const ownerRecipe = () => RECIPES.find(
    r => r.id === parseInt(owner.value, 10));

  function draw() {
    const rec = ownerRecipe();
    const q = (META.qualities || []).find(
      x => rec && x.quality === rec.quality_max);
    const width = Math.min(Math.max((q && q.slots) || 1, 1), META.max_slots);
    draft = draft.slice(0, width);
    sockets.innerHTML = '';
    for (let i = 0; i < width; i++) {
      sockets.appendChild(gemSocket(draft[i] || 0, rec, v => {
        draft[i] = v;
        draw();
      }));
    }
    // Сколько эскизов у основы вообще есть и сколько уже разобрано именными.
    // Берём ЛУЧШУЮ ступень, а не последнюю: обычно это верхняя - у неё больше
    // всего гнёзд, - но если камней её качества никто не завёл, эскизы даёт
    // ступень пожиже, и написать «ноль» было бы неправдой.
    const steps = (rec && rec.inlay) || [];
    const best = steps.reduce(
      (a, b) => (!a || b.patterns > a.patterns ? b : a), null);
    const taken = SYNS.filter(s => rec && s.recipe_id === rec.id).length;
    if (!steps.length) {
      counter.textContent = 'у основы нет изделий — эскизов пока ноль';
      counter.className = 'muted';
    } else if (!best || !best.patterns) {
      counter.textContent = 'основа не принимает ни одного камня: эскизов ноль';
      counter.className = 'warn';
    } else {
      counter.textContent =
        `эскизов у основы: занято ${taken} из ${best.patterns}`;
      counter.className = taken >= best.patterns ? 'warn' : 'muted';
      counter.title = steps.map(
        st => `${qualityName(st.quality)}: гнёзд ${st.slots}, камней `
          + `${st.gems}, эскизов ${st.patterns}`).join(String.fromCharCode(10));
    }
  }
  draw();

  // Книга сочетания - ровно то же, что книга основы, и заводится там же, в
  // полосе: без неё эскиз добывается только перебором. В памяти полосы её нет
  // по той же причине - одна книга учит одному.
  const teach = itemPickBox({
    title: 'Обучающий предмет сочетания',
    empty: 'только угадать',
  });

  view.appendChild(addBar(
    [['имя', name], ['основа', owner], ['набор', sockets],
     ['обучение', teach], ['', counter]],
    () => {
      const mats = draft.filter(x => x);
      if (!mats.length) { toast('Положите в набор хотя бы один камень.', 'err'); return; }
      return saveNamed({
        id: 0, name_ru: name.value, recipe_id: parseInt(owner.value, 10) || 0,
        mats, result_entry: 0, teach_item: teach.entry,
        order_matters: false, enabled: false,
      });
    }));

  const spec = {
    placeholder: 'поиск по имени, основе или материалу набора',
    search: sy => [sy.name_ru, sy.recipe_name]
      .concat((sy.mats || []).map(matName)).join(' '),
    picks: [
      { key: 'recipe', label: 'любая основа', options: recipeOptions(),
        get: sy => sy.recipe_id },
      { key: 'len', label: 'любая длина набора',
        options: [1, 2, 3, 4, 5].map(n => [n, 'вставок: ' + n]),
        get: sy => (sy.mats || []).length },
      { key: 'on', label: 'вкл и выкл',
        options: [['1', 'только включённые'], ['0', 'только выключенные']],
        get: sy => sy.enabled ? '1' : '0' },
      { key: 'ready', label: 'готовые и нет',
        options: [['1', 'без замечаний'], ['0', 'с замечаниями']],
        get: sy => (sy.issues || []).length ? '0' : '1' },
      { key: 'teach', label: 'как достаётся',
        options: [['1', 'есть обучающий предмет'], ['0', 'только угадать']],
        get: sy => sy.teach_item ? '1' : '0' },
    ],
    sorts: {
      'Имя': sy => sy.name_ru,
      'Основа': sy => sy.recipe_name,
      'Набор вставок': sy => (sy.mats || []).length,
      'Вкл': sy => (sy.enabled ? 1 : 0),
    },
  };
  const rows = applyView('named', SYNS, spec);
  view.appendChild(filterBar('named', spec));

  const heads = ['Имя', 'Основа', 'Набор вставок', 'Порядок', 'Обучение',
                 'Именной предмет', 'Вкл', ''];
  const table = el('table', 'grid');
  table.appendChild(headRow('named', heads, spec, (th, h) => {
    if (h === 'Порядок') {
      th.title = 'Важен ли порядок вставок по слотам. Выключено — «красный, '
        + 'зелёный» и «зелёный, красный» это один набор.';
    }
    if (h === 'Обучение') {
      th.title = 'Обучающий предмет. Пусто — сочетание можно только угадать: '
        + 'в списке рецептов игрока его не будет, но собрать его он всё '
        + 'равно сможет.';
    }
  }));

  rows.forEach(syn => {
    const tr = el('tr', syn.enabled ? '' : 'off');
    tr.dataset.synId = syn.id;
    const patch = fields => saveNamed({ ...syn, ...fields });

    tr.appendChild(el('td')).appendChild(
      text(syn.name_ru, v => patch({ name_ru: v })));

    tr.appendChild(el('td')).appendChild(
      lazySelect(recipeOptions, syn.recipe_id, syn.recipe_name || '—',
                 v => patch({ recipe_id: parseInt(v, 10) })));

    // Гнёзд показываем ровно столько, сколько даёт лучший вариант основы:
    // набор длиннее не соберёт никто, и предлагать такие поля незачем.
    const cell = el('td');
    const row = el('div', 'row');
    const slots = syn.mats.slice();
    const width = Math.max(syn.recipe_slots || 0, slots.length, 1);
    const owner = RECIPES.find(r => r.id === syn.recipe_id);
    for (let i = 0; i < Math.min(width, META.max_slots); i++) {
      row.appendChild(gemSocket(slots[i] || 0, owner, v => {
        const next = slots.slice();
        next[i] = v;
        patch({ mats: next.filter(x => x) });
      }));
    }
    cell.appendChild(row);
    tr.appendChild(cell);

    const ord = el('td');
    const ordChk = el('input');
    ordChk.type = 'checkbox';
    ordChk.checked = syn.order_matters;
    ordChk.addEventListener('change',
                            () => patch({ order_matters: ordChk.checked }));
    ord.appendChild(ordChk);
    tr.appendChild(ord);

    // Книга: рецепт основы и именной рецепт достаются одинаково (§5.6).
    tr.appendChild(itemPickCell(syn.teach, syn.teach_item, {
      title: 'Обучающий предмет: ' + syn.name_ru,
      empty: 'только угадать',
    }, entry => patch({ teach_item: entry })));

    // Именной предмет: либо указать готовый, либо завести копией образца.
    const named = itemPickCell(syn.result, syn.result_entry, {
      title: 'Именной предмет: ' + syn.name_ru,
      empty: 'не заведён',
    }, entry => patch({ result_entry: entry }));
    if (!syn.result_entry) {
      const make = el('button', 'btn ghost', 'Создать');
      make.title = 'Копия образца станет именным предметом: дальше правьте '
        + 'её в каталоге — вид, уровень, умения.';
      make.addEventListener('click', () => openItemPicker({
        title: 'Образец для «' + syn.name_ru + '»',
      }, entry => generateNamed(syn, entry)));
      named.querySelector('.row').appendChild(make);
    }
    tr.appendChild(named);

    const on = el('td');
    const chk = el('input');
    chk.type = 'checkbox';
    chk.checked = syn.enabled;
    chk.addEventListener('change', () => patch({ enabled: chk.checked }));
    on.appendChild(chk);
    tr.appendChild(on);

    const act = el('td', 'act');
    const del = el('button', 'btn ghost', 'Удалить');
    del.addEventListener('click', () => removeNamed(syn));
    act.appendChild(del);
    tr.appendChild(act);

    table.appendChild(tr);
    if ((syn.issues || []).length) {
      table.appendChild(issuesRow(syn.issues, heads.length));
    }
  });
  view.appendChild(table);
}

async function saveNamed(syn) {
  try {
    const res = await api('/api/aprof/synergies',
                          { method: 'PUT', body: JSON.stringify(syn) });
    toast(res.note || 'Сохранено.', res.note ? 'warn' : 'ok');
    await loadAll();
  } catch (e) { toast(e.message, 'err'); await loadAll(); }
}

async function generateNamed(syn, sampleEntry) {
  try {
    const res = await api(`/api/aprof/synergies/${syn.id}/named-item`, {
      method: 'POST', body: JSON.stringify({ sample_entry: sampleEntry }),
    });
    toast('Заведён предмет ' + res.entry + '. Правьте его в каталоге.', 'ok');
    await loadAll();
  } catch (e) { toast(e.message, 'err'); }
}

async function removeNamed(syn) {
  if (!confirm(`Удалить сочетание «${syn.name_ru}»? Именной предмет останется `
               + `в каталоге предметов.`)) return;
  try {
    await api('/api/aprof/synergies/' + syn.id, { method: 'DELETE' });
    await loadAll();
  } catch (e) { toast(e.message, 'err'); }
}

// --- объединение ----------------------------------------------------------
// Третий стол профессии (DESIGN §5.8): в середину кладут ЛЮБУЮ вещь
// подходящего рода - выбитую, купленную, скованную здесь, - в пять ячеек что
// угодно, и выходит готовый предмет. Навыка стол не требует, а несовпавший
// набор не тратит ничего, поэтому цены ошибки у игрока тут нет.

const MERGE_CELLS = 5;

async function renderMerge(view) {
  const typeOptions = () => TYPES.map(t => [t.id, t.name_ru]);


  const name = el('input');
  name.type = 'text';
  name.placeholder = 'Клинок, скованный заново';
  const owner = select(typeOptions());
  view.appendChild(addBar(
    [['имя', name], ['тип вещи в середине', owner]],
    () => saveMerge({
      id: 0, name_ru: name.value, type_id: parseInt(owner.value, 10) || 0,
      items: [], result_entry: 0, teach_item: 0, enabled: false,
    })));

  const spec = {
    placeholder: 'поиск по имени, типу или предмету набора',
    search: m => [m.name_ru, m.type_name]
      .concat((m.item_rows || []).map(i => (i && i.name) || '')).join(' '),
    picks: [
      { key: 'type', label: 'любой тип', options: typeOptions(),
        get: m => m.type_id },
      { key: 'on', label: 'вкл и выкл',
        options: [['1', 'только включённые'], ['0', 'только выключенные']],
        get: m => m.enabled ? '1' : '0' },
      { key: 'ready', label: 'готовые и нет',
        options: [['1', 'без замечаний'], ['0', 'с замечаниями']],
        get: m => (m.issues || []).length ? '0' : '1' },
      { key: 'teach', label: 'как достаётся',
        options: [['1', 'есть обучающий предмет'], ['0', 'только найти']],
        get: m => m.teach_item ? '1' : '0' },
    ],
    sorts: {
      'Имя': m => m.name_ru,
      'Тип': m => m.type_name,
      'Набор': m => (m.items || []).length,
      'Вкл': m => (m.enabled ? 1 : 0),
    },
  };
  const rows = applyView('merge', MERGES, spec);
  view.appendChild(filterBar('merge', spec));

  const heads = ['Имя', 'Тип', 'Набор', 'Обучение', 'Результат', 'Вкл', ''];
  const table = el('table', 'grid');
  table.appendChild(headRow('merge', heads, spec, (th, h) => {
    if (h === 'Тип') {
      th.title = 'Какого рода вещь кладут в середину стола. Броня сюда не '
        + 'попадает вовсе: у профессии её типов нет.';
    }
    if (h === 'Набор') {
      th.title = 'До пяти любых предметов игры. Порядок не важен.';
    }
  }));

  rows.forEach(merge => {
    const tr = el('tr', merge.enabled ? '' : 'off');
    const patch = fields => saveMerge({
      id: merge.id, name_ru: merge.name_ru, type_id: merge.type_id,
      items: merge.items, result_entry: merge.result_entry,
      teach_item: merge.teach_item, enabled: merge.enabled, ...fields,
    });

    tr.appendChild(el('td')).appendChild(
      text(merge.name_ru, v => patch({ name_ru: v })));

    tr.appendChild(el('td')).appendChild(
      select(typeOptions(), merge.type_id,
             v => patch({ type_id: parseInt(v, 10) })));

    // Набор: пять кнопок в строку. Каждая открывает общий выбор предмета -
    // в ячейку идёт что угодно, а не только материал верстака.
    const cell = el('td');
    const row = el('div', 'row');
    for (let i = 0; i < MERGE_CELLS; i++) {
      const entry = merge.items[i] || 0;
      const info = (merge.item_rows || [])[i];
      const pick = el('button', entry ? 'btn ghost' : 'btn ghost warn',
                      entry ? ((info && info.name) || String(entry)) : '+');
      pick.title = entry ? 'Сменить предмет ячейки' : 'Положить предмет';
      pick.addEventListener('click', () => openItemPicker({
        title: 'Ячейка ' + (i + 1) + ': ' + merge.name_ru,
      }, chosen => {
        const next = merge.items.slice();
        next[i] = chosen;
        patch({ items: next.filter(x => x) });
      }));
      row.appendChild(pick);

      if (entry) {
        const drop = el('button', 'btn ghost', '×');
        drop.title = 'Убрать из ячейки';
        drop.addEventListener('click', () => {
          const next = merge.items.slice();
          next.splice(i, 1);
          patch({ items: next });
        });
        row.appendChild(drop);
      }
    }
    cell.appendChild(row);
    tr.appendChild(cell);

    tr.appendChild(itemPickCell(merge.teach, merge.teach_item, {
      title: 'Обучающий предмет: ' + merge.name_ru,
      empty: 'только найти',
    }, entry => patch({ teach_item: entry })));

    const result = itemPickCell(merge.result, merge.result_entry, {
      title: 'Результат: ' + merge.name_ru,
      empty: 'не заведён',
    }, entry => patch({ result_entry: entry }));
    if (!merge.result_entry) {
      const make = el('button', 'btn ghost', 'Создать');
      make.title = 'Копия образца станет результатом: дальше правьте её в '
        + 'каталоге предметов.';
      make.addEventListener('click', () => openItemPicker({
        title: 'Образец для «' + merge.name_ru + '»',
      }, entry => generateMergeItem(merge, entry)));
      result.querySelector('.row').appendChild(make);
    }
    tr.appendChild(result);

    const on = el('td');
    const chk = el('input');
    chk.type = 'checkbox';
    chk.checked = merge.enabled;
    chk.addEventListener('change', () => patch({ enabled: chk.checked }));
    on.appendChild(chk);
    tr.appendChild(on);

    const act = el('td', 'act');
    const del = el('button', 'btn ghost', 'Удалить');
    del.addEventListener('click', () => removeMerge(merge));
    act.appendChild(del);
    tr.appendChild(act);

    table.appendChild(tr);
    if ((merge.issues || []).length) {
      table.appendChild(issuesRow(merge.issues, heads.length));
    }
  });
  view.appendChild(table);
}

async function saveMerge(merge) {
  try {
    await api('/api/aprof/merges',
              { method: 'PUT', body: JSON.stringify(merge) });
    await loadAll();
  } catch (e) { toast(e.message, 'err'); await loadAll(); }
}

async function generateMergeItem(merge, sampleEntry) {
  try {
    const res = await api(`/api/aprof/merges/${merge.id}/result-item`, {
      method: 'POST', body: JSON.stringify({ sample_entry: sampleEntry }),
    });
    toast('Заведён предмет ' + res.entry + '. Правьте его в каталоге.', 'ok');
    await loadAll();
  } catch (e) { toast(e.message, 'err'); }
}

async function removeMerge(merge) {
  if (!confirm(`Удалить рецепт «${merge.name_ru}»? Предмет-результат `
               + `останется в каталоге предметов.`)) return;
  try {
    await api('/api/aprof/merges/' + merge.id, { method: 'DELETE' });
    await loadAll();
  } catch (e) { toast(e.message, 'err'); }
}

// --- баланс ---------------------------------------------------------------

async function renderBalance(view) {
  let data, settings;
  try {
    data = await api('/api/aprof/balance');
    settings = (await api('/api/aprof/settings')).settings;
  } catch (e) {
    view.appendChild(el('div', 'empty', e.message));
    return;
  }

  const state = {
    qualities: data.qualities.map(q => ({ ...q })),
    chances: { ...data.chances },
  };


  const qCard = el('div', 'card');
  qCard.appendChild(el('h2', null, 'Качество изделия'));
  const qTable = el('table', 'grid');
  const qHead = el('tr');
  ['Качество', 'Имя', 'Слотов доводки', 'Вес при ковке']
    .forEach(h => qHead.appendChild(el('th', null, h)));
  qTable.appendChild(qHead);

  const totalCell = el('td', 'num');
  const retotal = () => {
    const sum = state.qualities.reduce(
      (acc, q) => acc + (state.chances[String(q.quality)] || 0), 0);
    totalCell.textContent = String(sum);
    totalCell.className = sum > 0 ? 'num' : 'num warn';
  };

  state.qualities.forEach(q => {
    const tr = el('tr');
    tr.appendChild(el('td', 'q' + q.quality, String(q.quality)));
    tr.appendChild(el('td')).appendChild(text(q.name_ru, v => { q.name_ru = v; }));
    const slots = el('td', 'num');
    slots.appendChild(num(q.slots, v => { q.slots = v; }, 1));
    tr.appendChild(slots);
    const w = el('td', 'num');
    w.appendChild(num(state.chances[String(q.quality)] || 0, v => {
      state.chances[String(q.quality)] = v;
      retotal();
    }, 0));
    tr.appendChild(w);
    qTable.appendChild(tr);
  });

  const sumRow = el('tr');
  sumRow.appendChild(el('td', null, 'сумма весов'));
  sumRow.appendChild(el('td'));
  sumRow.appendChild(el('td'));
  sumRow.appendChild(totalCell);
  qTable.appendChild(sumRow);
  retotal();

  qCard.appendChild(qTable);
  const save = el('button', 'btn', 'Сохранить баланс');
  save.addEventListener('click', async () => {
    try {
      await api('/api/aprof/balance', {
        method: 'PUT', body: JSON.stringify(state),
      });
      toast('Баланс сохранён.', 'ok');
    } catch (e) { toast(e.message, 'err'); }
  });
  qCard.appendChild(el('div', 'toolbar')).appendChild(save);
  view.appendChild(qCard);

  // Уровень предмета -> требуемый уровень персонажа. Без этой таблицы у вещи
  // нет требуемого уровня, то есть мифриловый меч надевается с первого.
  const lCard = el('div', 'card');
  const lHead = el('h2', null, 'Уровень предмета → уровень персонажа');
  lHead.appendChild(unused());
  lCard.appendChild(lHead);

  let levels = [];
  try {
    levels = (await api('/api/aprof/ilvl-levels')).rows;
  } catch (e) {
    lCard.appendChild(el('div', 'empty', e.message));
  }

  const lTable = el('table', 'grid');
  function drawLevels() {
    lTable.innerHTML = '';
    const head = el('tr');
    ['Уровень предмета до', 'Требует уровня', ''].forEach(
      h => head.appendChild(el('th', null, h)));
    lTable.appendChild(head);
    levels.forEach((row, i) => {
      const tr = el('tr');
      tr.appendChild(el('td', 'num')).appendChild(
        num(row.ilvl_max, v => { row.ilvl_max = v; }, 1));
      tr.appendChild(el('td', 'num')).appendChild(
        num(row.req_level, v => { row.req_level = v; }, 1));
      const del = el('button', 'btn ghost', 'убрать');
      del.addEventListener('click', () => { levels.splice(i, 1); drawLevels(); });
      tr.appendChild(el('td')).appendChild(del);
      lTable.appendChild(tr);
    });
  }
  drawLevels();
  lCard.appendChild(lTable);

  const lBar = el('div', 'toolbar');
  const lAdd = el('button', 'btn ghost', 'Добавить строку');
  lAdd.addEventListener('click', () => {
    const last = levels[levels.length - 1];
    levels.push({ ilvl_max: (last ? last.ilvl_max : 0) + 10,
                  req_level: last ? last.req_level : 1 });
    drawLevels();
  });
  const lSave = el('button', 'btn', 'Сохранить уровни');
  lSave.addEventListener('click', async () => {
    try {
      levels = (await api('/api/aprof/ilvl-levels', {
        method: 'PUT', body: JSON.stringify(levels),
      })).rows;
      drawLevels();
      toast('Уровни сохранены.', 'ok');
    } catch (e) { toast(e.message, 'err'); }
  });
  lBar.appendChild(lAdd);
  lBar.appendChild(lSave);
  lCard.appendChild(lBar);
  view.appendChild(lCard);

  // Кривая шанса успеха. Числа лежат в «Числах модуля» ниже, но глазами по
  // ним не видно, во что они складываются, - поэтому показываем таблицей.
  const chCard = el('div', 'card');
  // Кривую сервер читает с 2026-09-02 (§11 п.7): плашки «не читает» здесь нет.
  chCard.appendChild(el('h2', null, 'Шанс успеха'));
  const cfg = {};
  settings.forEach(s => { cfg[s.name] = parseInt(s.value, 10) || 0; });
  const chTable = el('table', 'grid');
  const chHead = el('tr');
  ['Разрыв навык − req_skill рецепта', 'Шанс успеха'].forEach(
    h => chHead.appendChild(el('th', null, h)));
  chTable.appendChild(chHead);
  [100, 50, 0, -50, -100, -200].forEach(gap => {
    const raw = (cfg.base_chance || 75) + gap * (cfg.chance_step || 1);
    const chance = Math.max(cfg.fail_floor || 10, Math.min(100, raw));
    const tr = el('tr');
    tr.appendChild(el('td', null, (gap > 0 ? '+' : '') + gap));
    tr.appendChild(el('td', 'num', chance + ' %'));
    chTable.appendChild(tr);
  });
  chCard.appendChild(chTable);
  view.appendChild(chCard);

  const sCard = el('div', 'card');
  sCard.appendChild(el('h2', null, 'Числа модуля'));
  const sTable = el('table', 'grid');
  const changed = {};
  settings.forEach(s => {
    const tr = el('tr');
    tr.appendChild(el('td', null, s.name));
    tr.appendChild(el('td')).appendChild(text(s.value, v => { changed[s.name] = v; }));
    tr.appendChild(el('td', null, s.comment));
    sTable.appendChild(tr);
  });
  sCard.appendChild(sTable);
  const sSave = el('button', 'btn', 'Сохранить числа');
  sSave.addEventListener('click', async () => {
    try {
      await api('/api/aprof/settings', {
        method: 'PUT', body: JSON.stringify(changed),
      });
      toast('Сохранено.', 'ok');
    } catch (e) { toast(e.message, 'err'); }
  });
  sCard.appendChild(el('div', 'toolbar')).appendChild(sSave);
  view.appendChild(sCard);
}

// Раздел, который в ковке не участвует, но оставлен в схеме.
function unused() {
  const tag = el('span', 'wip', 'не используется');
  tag.title = 'Таблица осталась в схеме под возможное развитие вставок '
            + '(DESIGN §5.5, §5.7). Ковка её не читает.';
  return tag;
}

// --- проверка -------------------------------------------------------------

function renderPreview(view) {
  // Та же проверка, что делает сервер: набор в ячейках сравнивается с
  // рецептами ТОЧНО (предмет и количество), а не «считается предмет». Числа
  // изделия здесь не показываются вовсе - их не из чего считать, они стоят в
  // строке item_template, которую видно в «Каталоге предметов».

  const card = el('div', 'card');
  const row = el('div', 'row');

  const base = select(TYPES.map(t => [t.id, t.name_ru]));
  const skill = el('input');
  skill.type = 'number'; skill.value = 300; skill.min = 1; skill.max = 500;
  const pickers = [];
  for (let i = 0; i < META.max_slots; i++) {
    pickers.push(matPicker(0, () => {}, true));
  }

  // Ячейки схемы зависят от типа, поэтому строятся заново при каждой смене.
  const partsBox = el('div', 'row');
  const partPickers = [];

  async function drawParts() {
    partsBox.innerHTML = '';
    partPickers.length = 0;
    let rows = [];
    try {
      rows = (await api(`/api/aprof/types/${parseInt(base.value, 10)}/parts`)).parts;
    } catch (e) { /* у типа может не быть ячеек */ }

    rows.forEach(part => {
      // Пустая ячейка - законный вариант набора, поэтому она первая в списке.
      // У обязательной такого варианта нет: проверка на ней и остановится,
      // как остановится сервер (DESIGN §5.4.1).
      const options = [['0', '— пусто —']].concat(
        MATS.filter(m => m.role === 'base'
                         && m.part_kind_id === part.part_kind_id)
            .map(m => [m.entry, m.name_ru]));
      const picker = select(options);
      // Количество - часть набора: «те же предметы, но по три» это другой
      // рецепт (DESIGN §5.4.2), поэтому его задают здесь, а не берут из схемы.
      const count = el('input');
      count.type = 'number'; count.value = 1; count.min = 1; count.max = 50;
      count.style.width = '52px';
      partPickers.push({ picker, count, idx: part.idx });

      const wrap = el('div');
      const cap = el('label', null,
                     part.label_ru + (part.required ? ' *' : ''));
      if (part.required) {
        cap.title = 'Обязательная часть: пустой её не оставить.';
      }
      wrap.appendChild(cap);
      wrap.appendChild(el('br'));
      wrap.appendChild(picker);
      wrap.appendChild(count);
      partsBox.appendChild(wrap);
    });
  }

  base.addEventListener('change', drawParts);

  const add = (label, node) => {
    const wrap = el('div');
    wrap.appendChild(el('label', null, label));
    wrap.appendChild(el('br'));
    wrap.appendChild(node);
    row.appendChild(wrap);
  };
  add('тип', base);
  add('навык', skill);
  pickers.forEach((p, i) => add('слот ' + (i + 1), p));
  card.appendChild(row);
  card.appendChild(el('p', 'hint', 'Набор по ячейкам (ковка):'));
  card.appendChild(partsBox);
  drawParts();

  const go = el('button', 'btn', 'Проверить');
  const goRow = el('div', 'row');
  goRow.style.marginTop = '8px';
  goRow.appendChild(go);
  card.appendChild(goRow);

  const out = el('div', 'preview-out');
  card.appendChild(out);
  view.appendChild(card);

  go.addEventListener('click', async () => {
    out.innerHTML = '';
    const mats = pickers.map(p => parseInt(p.value, 10) || 0).filter(x => x);
    try {
      const res = await api('/api/aprof/match', {
        method: 'POST',
        body: JSON.stringify({
          type_id: parseInt(base.value, 10),
          skill: parseInt(skill.value, 10) || 1,
          mats,
          part_mats: partPickers.map(p => parseInt(p.picker.value, 10) || 0),
          part_counts: partPickers.map(p => parseInt(p.count.value, 10) || 1),
        }),
      });

      (res.cells || []).forEach(c => out.appendChild(el('div', null,
        `${c.label}: ` + (c.entry ? `${c.name} ×${c.count}` : 'пусто'))));
      if ((res.spend || []).length) {
        out.appendChild(el('div', null, 'Уйдёт из сумки: '
          + res.spend.map(x => `${x.name} ×${x.count}`).join(', ')));
      }

      if (!res.recipe) {
        out.appendChild(el('div', 'warn', res.note));
        if (res.fail_mode === 2) {
          out.appendChild(el('div', 'hint', 'Поделка: '
            + (res.fail_item ? `${res.fail_item.name} (id ${res.fail_entry})`
                             : 'у типа не заведена — ковка откажет')));
        }
      } else {
        const r = res.recipe;
        out.appendChild(el('div', null,
          `Совпал рецепт «${r.name_ru}» (id ${r.id}), требует навыка ${r.req_skill}`));
        const c = res.chance;
        out.appendChild(el('div', c.chance < 50 ? 'warn' : null,
          `Шанс успеха: ${c.chance} % (разрыв ${c.gap > 0 ? '+' : ''}${c.gap})`));
        if (c.chance <= c.floor) {
          out.appendChild(el('div', 'hint',
            'Это нижняя граница: работа далеко за пределами навыка. Провал ' +
            'сжигает материалы и оставляет поделку.'));
        }
        out.appendChild(el('div', null, 'Качество: от '
          + qualityName(r.quality_min) + ' до ' + qualityName(r.quality_max)));
        r.results.forEach(res2 => out.appendChild(el('div', null,
          `  ${qualityName(res2.quality)}: `
          + (res2.item ? `${res2.item.name} (id ${res2.result_entry})`
                       : `изделие ${res2.result_entry} отсутствует`))));
        (r.issues || []).forEach(i => out.appendChild(el('div', 'warn', i)));
      }

      // Вставки: сырые статы, без единого множителя.
      (res.inserts || []).forEach((s2, i) => out.appendChild(el('div', null,
        `слот ${i + 1}: ${s2.name} → `
        + (s2.stat_type ? `${statName(s2.stat_type)} +${s2.value}`
                        : 'чисел не даёт'))));
      const totals = el('div', 'totals');
      (res.totals || []).forEach(t => totals.appendChild(
        el('span', null, `${statName(t.stat_type)} +${t.value}`)));
      if (!(res.totals || []).length) {
        totals.appendChild(el('span', null, 'без бонусов'));
      }
      out.appendChild(totals);

      if (res.synergy) {
        const named = res.synergy.result;
        out.appendChild(el('div', null,
          `Сочетание «${res.synergy.name}» → `
          + (named ? `${named.name} (id ${named.entry})`
                   : 'именной предмет не заведён')));
      } else if (res.finish_warning) {
        out.appendChild(el('div', 'warn',
          'Этот набор вставок не совпадает ни с одним сочетанием основы: ' +
          '«Завершить доводку» испортит вещь, как поделку.'));
      }
    } catch (e) {
      out.appendChild(el('div', 'warn', e.message));
    }
  });
}

// --- пул id ---------------------------------------------------------------

// Нарезать слайс ступени и засеять его по виду изделия. Одна кнопка на два
// случая: у основы слайса нет вовсе или её вид правили в каталоге предметов.
async function reslice(recipeId, quality) {
  try {
    const res = await api(
      `/api/aprof/recipes/${recipeId}/results/${quality}/slice`,
      { method: 'POST' });
    toast(`Слайс ${res.lo}-${res.hi}, заготовок обновлено: ${res.seeded}.`,
          'ok');
    await loadAll();
  } catch (e) { toast(e.message, 'err'); }
}

async function renderPool(view) {
  let data;
  try {
    data = await api('/api/aprof/generated');
  } catch (e) {
    view.appendChild(el('div', 'empty', e.message));
    return;
  }


  // Сколько заготовок осталось. Это единственное место, где видно приближение
  // к «кончились свободные id»: каждая вставка самоцвета - новая комбинация,
  // поэтому пул тратится быстрее, чем кажется по числу готовых вещей.
  const p = data.pool;
  const stats = el('div', 'card');
  stats.appendChild(el('h2', null, 'Заготовки'));
  const sTab = el('table', 'grid');
  const low = p.blanks && p.free / p.blanks < 0.1;
  [['Заведено заготовок в item_template', String(p.blanks)],
   ['Занято', String(data.total)],
   ['Свободно', String(p.free)],
   ['Сборка мусора на старте мира', p.gc_enabled ? 'включена' : 'ВЫКЛЮЧЕНА'],
   ['Строк без изделия (id зарезервирован)', String(p.orphans)]]
    .forEach(([label, value]) => {
      const tr = el('tr');
      tr.appendChild(el('td', null, label));
      tr.appendChild(el('td', 'num', value));
      sTab.appendChild(tr);
    });
  stats.appendChild(sTab);
  if (p.blanks < p.size) {
  }
  if (low) {
    stats.appendChild(el('div', 'warn',
      'Свободных заготовок меньше десятой части. Когда они кончатся, ковка ' +
      'начнёт отказывать с «кончились свободные id»: расширьте блок ' +
      'миграцией или проверьте, что сборка мусора включена.'));
  }
  // Слайсы. Кончиться может слайс ОДНОЙ основы, пока у остальных полно
  // свободного, - по общему числу этого не видно, а отказ игрок получит.
  if ((p.types || []).length) {
    const sl = el('table', 'grid');
    const slHead = el('tr');
    ['Основа', 'Изделие', 'Слайс', 'Заготовок', 'Занято', 'Свободно', '']
      .forEach(h => slHead.appendChild(el('th', null, h)));
    sl.appendChild(slHead);
    p.types.forEach(t => {
      const tr = el('tr');
      tr.appendChild(el('td', null, t.name_ru));
      tr.appendChild(el('td', 'num', String(t.result_entry)));
      tr.appendChild(el('td', 'num', `${t.lo}-${t.hi}`));
      tr.appendChild(el('td', 'num', String(t.blanks)));
      tr.appendChild(el('td', 'num', String(t.used)));
      const free = el('td', 'num', String(t.free));
      if (t.blanks && t.free / t.blanks < 0.1) free.className = 'num warn';
      tr.appendChild(free);
      // Вид основы правится обычным редактором предмета, а заготовки его
      // копию несут в себе - после правки их надо перечитать, иначе копия
      // приедет игроку с прежней моделью.
      const act = el('button', 'btn small', 'Обновить вид');
      act.title = 'Перечитать строку основы в заготовки слайса. Выданные id '
        + 'не трогаются, в клиент новый вид уедет следующей выгрузкой Item.dbc.';
      act.addEventListener('click', () => reslice(t.recipe_id, t.quality));
      tr.appendChild(el('td')).appendChild(act);
      sl.appendChild(tr);
    });
    stats.appendChild(el('h2', null, 'Слайсы по основам'));
    stats.appendChild(sl);
  }

  // Основы без слайса. Опаснее пустого списка: рецепт выглядит готовым, ковка
  // по нему идёт, а доводка отвечает «кончились свободные id» - на вид
  // беспричинно. Панель режет слайс сама при заведении изделия, так что сюда
  // попадают строки, заведённые до этой правки.
  if ((p.missing || []).length) {
    const box = el('div', 'warn');
    box.appendChild(el('div', null,
      `Основ без слайса пула: ${p.missing.length}. Доводка у них не работает.`));
    const ms = el('table', 'grid');
    const mHead = el('tr');
    ['Основа', 'Изделие', ''].forEach(h => mHead.appendChild(el('th', null, h)));
    ms.appendChild(mHead);
    p.missing.forEach(m => {
      const tr = el('tr');
      tr.appendChild(el('td', null, m.name_ru));
      tr.appendChild(el('td', 'num', String(m.result_entry)));
      const act = el('button', 'btn small', 'Нарезать');
      act.addEventListener('click', () => reslice(m.recipe_id, m.quality));
      tr.appendChild(el('td')).appendChild(act);
      ms.appendChild(tr);
    });
    box.appendChild(ms);
    stats.appendChild(box);
  }

  if (p.orphans) {
    stats.appendChild(el('div', 'warn',
      `${p.orphans} строк ссылаются на исчезнувшее изделие. Их id ` +
      'зарезервированы и в оборот не вернутся — это защита от того, чтобы ' +
      'вещь в сумке игрока молча стала другой вещью. Изделия удалять нельзя, ' +
      'только выключать рецепт.'));
  }
  view.appendChild(stats);

  if (!data.rows.length) {
    view.appendChild(el('div', 'empty', 'Пока ничего не выдано.'));
    return;
  }

  const table = el('table', 'grid');
  const head = el('tr');
  ['id', 'Изделие', 'Рецепт', 'Вставки', 'Когда']
    .forEach(h => head.appendChild(el('th', null, h)));
  table.appendChild(head);
  // Снимок доводки: поверх какой строки item_template она идёт и что в неё
  // вставлено. Числа не хранятся - они берутся у изделия (DESIGN §4).
  const recipeName = id => (RECIPES.find(r => r.id === id) || {}).name_ru || id;
  const matName = id => {
    const m = MATS.find(x => x.entry === parseInt(id, 10));
    return m ? m.name_ru : id;
  };
  data.rows.forEach(r => {
    const tr = el('tr');
    tr.appendChild(el('td', null, String(r.entry)));
    tr.appendChild(el('td', null, String(r.source_entry)));
    tr.appendChild(el('td', null, recipeName(r.recipe_id)));
    tr.appendChild(el('td', null,
      (r.mats || '').split(',').filter(x => x).map(matName).join(' + ')));
    tr.appendChild(el('td', null, r.created_at));
    table.appendChild(tr);
  });
  view.appendChild(table);
  view.appendChild(el('p', 'hint', `Всего выдано: ${data.total}.`));
}

// --- вкладка «Связи» ------------------------------------------------------
// Карта, а не таблица. Таблицы отвечают на вопрос «какие поля у этой строки»;
// здесь другой вопрос - ЧТО ИЗ ЧЕГО выходит: какая основа даёт какие ступени,
// какие эскизы на них висят и во что эти эскизы превращаются. По таблицам
// «Рецепты» и «Именные» это собиралось в голове, сверкой номеров.
//
// Данные все уже на руках (RECIPES, SYNS, MATS): своего запроса у вкладки нет,
// она их только раскладывает.

// Переход к правке: вкладка плюс прокрутка к нужной строке. Без прокрутки
// карта приводила бы к таблице из восьми десятков рецептов, и дальше пришлось
// бы искать глазами.
async function mapGoto(tab, attr, id) {
  TAB = tab;
  // Ждём отрисовку: у вкладок «Баланс», «Объединение» и «Пул» она ходит в
  // сеть, и без ожидания прокрутка искала бы строку в ещё пустом кадре.
  await render();
  requestAnimationFrame(() => {
    const row = document.querySelector('[data-' + attr + '="' + id + '"]');
    if (!row) return;
    row.scrollIntoView({ block: 'center', behavior: 'smooth' });
    row.classList.add('flash');
    setTimeout(() => row.classList.remove('flash'), 1600);
  });
}

// Кнопка-ссылка «править»: выглядит подписью, ведёт себя кнопкой.
function mapEdit(label, tab, attr, id) {
  const b = el('button', 'map-edit', label);
  b.addEventListener('click', () => mapGoto(tab, attr, id));
  return b;
}

function mapGem(entry) {
  const mat = MATS.find(m => m.entry === entry);
  const item = mat && mat.item;
  const chip = el('span', 'map-gem');
  const img = el('img');
  img.loading = 'lazy';
  img.src = iconUrl(item && item.icon);
  img.addEventListener('error', () => { img.src = BLANK_ICON; }, { once: true });
  chip.appendChild(img);
  chip.appendChild(el('span', item ? 'q' + item.quality : 'warn',
    (mat && (mat.name_ru || (item && item.name))) || ('id ' + entry)));
  return chip;
}

// Ветка эскиза: набор камней, стрелка и то, что из него выходит.
function mapSynergy(syn, slotsBest) {
  const row = el('div', 'map-branch' + (syn.enabled ? '' : ' off'));
  const head = el('div', 'map-branch-head');
  head.appendChild(el('b', null, syn.name_ru || ('эскиз ' + syn.id)));
  if (syn.order_matters) {
    head.appendChild(el('span', 'chip ghost-chip', 'порядок важен'));
  }
  if (syn.teach_item) head.appendChild(el('span', 'chip ghost-chip', 'есть книга'));
  head.appendChild(mapEdit('править', 'named', 'syn-id', syn.id));
  row.appendChild(head);

  const line = el('div', 'map-line');
  (syn.mats || []).forEach((entry, i) => {
    if (i) line.appendChild(el('span', 'map-plus', '+'));
    line.appendChild(mapGem(entry));
  });
  line.appendChild(el('span', 'map-arrow', '→'));
  line.appendChild(itemCell(syn.result, syn.result_entry));
  row.appendChild(line);

  // Достижимость - главное, что карта обязана показать: эскиз длиннее, чем
  // гнёзд у лучшей ступени основы, не соберёт никто (§5.6).
  const need = (syn.mats || []).length;
  const note = el('div', 'map-note');
  if (!need) {
    note.className = 'map-note warn';
    note.textContent = 'набор пуст';
  } else if (slotsBest && need > slotsBest) {
    note.className = 'map-note warn';
    note.textContent = 'нужно гнёзд: ' + need
      + ', а лучшая ступень основы даёт ' + slotsBest;
  } else {
    note.textContent = 'гнёзд нужно: ' + need;
  }
  row.appendChild(note);
  (syn.issues || []).forEach(
    t => row.appendChild(el('div', 'map-note warn', '• ' + t)));
  return row;
}

// Карточка основы: набор ячеек, ступени качества и висящие на них эскизы.
function mapRecipe(rec, syns) {
  const card = el('div', 'map-card' + (rec.enabled ? '' : ' off'));

  const head = el('div', 'map-head');
  head.appendChild(el('b', null, rec.name_ru || ('рецепт ' + rec.id)));
  head.appendChild(el('span', 'muted', 'навык ' + rec.req_skill));
  head.appendChild(el('span', 'chip ghost-chip',
    ACQUIRE[rec.acquire] || rec.acquire));
  if (!rec.enabled) head.appendChild(el('span', 'chip ghost-chip warn', 'выключен'));
  if (rec.teach_item) head.appendChild(el('span', 'chip ghost-chip', 'есть книга'));
  head.appendChild(mapEdit('править основу', 'recipes', 'recipe-id', rec.id));
  card.appendChild(head);

  // Набор ячеек: то, что кладут на верстак. Дроп-основу не куют вовсе.
  if (rec.acquire === 'drop') {
    card.appendChild(el('div', 'map-set muted', 'добывается: набора нет'));
  } else {
    const set = el('div', 'map-set');
    (rec.cells || []).filter(c => c.item_entry).forEach(cell => {
      const piece = el('span', 'map-piece');
      piece.appendChild(el('span', 'muted', cell.label_ru + ':'));
      piece.appendChild(mapGem(cell.item_entry));
      if (cell.count > 1) piece.appendChild(el('span', 'map-mult', '×' + cell.count));
      set.appendChild(piece);
    });
    if (!set.childNodes.length) set.appendChild(el('span', 'warn', 'набор пуст'));
    card.appendChild(set);
  }

  // Ступени: у каждой своё изделие, свои гнёзда и свой запас камней.
  const tiers = el('div', 'map-tiers');
  let slotsBest = 0;
  (rec.results || []).forEach(res => {
    const step = (rec.inlay || []).find(i => i.quality === res.quality) || {};
    slotsBest = Math.max(slotsBest, step.slots || 0);
    const tier = el('div', 'map-tier');
    tier.appendChild(el('div', 'map-tier-head', qualityName(res.quality)));
    tier.appendChild(itemCell(res.item, res.result_entry));
    const facts = el('div', 'muted');
    facts.textContent = step.slots
      ? step.slots + ' гн. · камней ' + step.gems + ' · эскизов ' + step.patterns
      : 'гнёзд нет';
    tier.appendChild(facts);
    if (step.slots && !step.gems) {
      tier.appendChild(el('div', 'map-note warn', 'вставить нечего'));
    }
    tiers.appendChild(tier);
  });
  if (!tiers.childNodes.length) {
    tiers.appendChild(el('div', 'map-note warn', 'у основы нет ни одного изделия'));
  }
  card.appendChild(tiers);

  const branches = el('div', 'map-branches');
  syns.forEach(syn => branches.appendChild(mapSynergy(syn, slotsBest)));
  if (!syns.length) {
    branches.appendChild(el('div', 'map-note muted',
      'эскизов нет: из этой основы выходит только она сама'));
  }
  card.appendChild(branches);
  return card;
}

// Обратный вид: именной предмет во главе, основа под ним. Отвечает на вопрос
// «откуда берётся вот эта вещь», тогда как прямой - на «что я могу сделать».
function mapNamedCard(syn) {
  const rec = RECIPES.find(r => r.id === syn.recipe_id);
  const card = el('div', 'map-card' + (syn.enabled ? '' : ' off'));

  const head = el('div', 'map-head');
  head.appendChild(itemCell(syn.result, syn.result_entry));
  head.appendChild(el('b', null, syn.name_ru || ('эскиз ' + syn.id)));
  if (syn.order_matters) head.appendChild(el('span', 'chip ghost-chip', 'порядок важен'));
  head.appendChild(mapEdit('править эскиз', 'named', 'syn-id', syn.id));
  card.appendChild(head);

  const line = el('div', 'map-line');
  line.appendChild(el('span', 'muted', 'из основы:'));
  line.appendChild(el('b', null, rec ? rec.name_ru : 'основы нет'));
  if (rec) {
    line.appendChild(el('span', 'muted', 'навык ' + rec.req_skill));
    line.appendChild(mapEdit('править основу', 'recipes', 'recipe-id', rec.id));
  }
  card.appendChild(line);

  const gems = el('div', 'map-line');
  (syn.mats || []).forEach((entry, i) => {
    if (i) gems.appendChild(el('span', 'map-plus', '+'));
    gems.appendChild(mapGem(entry));
  });
  card.appendChild(gems);

  const need = (syn.mats || []).length;
  const fit = ((rec && rec.inlay) || []).filter(i => i.slots >= need);
  const note = el('div', 'map-note' + (fit.length ? '' : ' warn'));
  note.textContent = fit.length
    ? 'собирается на ступенях: '
      + fit.map(i => qualityName(i.quality)).join(', ')
    : 'ни одна ступень основы не даёт столько гнёзд';
  card.appendChild(note);
  (syn.issues || []).forEach(
    t => card.appendChild(el('div', 'map-note warn', '• ' + t)));
  return card;
}

// --- диаграмма связей ------------------------------------------------------
// Та же мысль, что у карточной карты - тип, основа, эскизы, - но всё разом и
// без выбора типа. Рисуется на CANVAS, а не в разметке: узлов под четыре
// тысячи, и вкладка «Именные» уже показывала, чем кончается такая россыпь в
// DOM - четырнадцать секунд на открытие (§8).
//
// Масштаб и сдвиг живут в памяти вкладки, поэтому уход в таблицу и обратно не
// сбрасывает вид.

const GRAPH_COL = { type: 24, base: 330, syn: 730 };   // левый край колонок
const GRAPH_W   = { type: 250, base: 360, syn: 420 };  // ширина узла
const GRAPH_ROW = 20;    // шаг строки эскиза
const GRAPH_GAP = 12;    // зазор между основами
const GRAPH_H   = 620;   // высота полотна на странице
const GRAPH_LABEL_AT = 0.42;  // с какого масштаба подписи читаемы

let GRAPH_PAL = null;

function graphPalette() {
  // Цвета берём из темы панели, а не зашиваем: canvas - такой же элемент
  // страницы, и своей палитры у него быть не должно.
  const css = getComputedStyle(document.documentElement);
  const pick = (name, fallback) =>
    ((css.getPropertyValue(name) || '').trim() || fallback);
  return {
    line: pick('--line', '#33302a'),
    lineStrong: pick('--line-strong', '#4a4133'),
    text: pick('--text', '#e6e0d4'),
    muted: pick('--muted', '#969184'),
    gold: pick('--gold', '#c8aa6e'),
    goldDim: pick('--gold-dim', '#8b7440'),
    panel: pick('--panel-2', '#1f232c'),
    panelHi: pick('--panel-3', '#262b35'),
    quality: [
      pick('--q-poor', '#9d9d9d'), pick('--text', '#e6e0d4'),
      pick('--q-uncommon', '#4ade5a'), pick('--q-rare', '#4aa3ff'),
      pick('--q-epic', '#c77dff'), pick('--q-legendary', '#ff9a3c'),
    ],
  };
}

// Цвет качества по номеру; отдельной строкой, чтобы раскладка не знала про
// палитру, а палитра - про качество предметов.
function graphQualityColor(quality) {
  if (!GRAPH_PAL) GRAPH_PAL = graphPalette();
  const q = Math.max(0, Math.min(5, parseInt(quality, 10) || 0));
  return GRAPH_PAL.quality[q];
}

// Раскладка: один проход по типам, внутри - по основам, внутри - по эскизам.
// Эскизы идут строками, основа встаёт посередине своих строк, тип - посередине
// своих основ. Высота известна заранее - по ней и работает «Вместить».
function graphLayout(state) {
  // Отбор может приехать одной строкой («всё» / «ковка» / «добыча») - так его
  // зовёт проверка страницы, и так он выглядел до фильтров.
  const pick = (typeof state === 'string')
    ? { show: state, types: [], quals: [] } : state;
  const show = pick.show || 'all';
  const types = pick.types || [];
  const quals = (pick.quals || []).map(Number);
  // Полоса. Своего поля у рецепта нет - лестница живёт в ap_band, а связь с
  // ней одна: требуемый навык. Отбор поэтому идёт по `skill` полосы, а не по
  // её номеру: номер у рецепта взять неоткуда.
  const bands = (pick.bands || []).map(Number);
  // Поиск. Одной строкой по всему, чем узел себя называет: имя эскиза, имя
  // основы, имя типа. Регистр не важен - в справочнике соседствуют «Клинок
  // Рассвета» и «Клинок рассвета».
  const find = (pick.find || '').trim().toLowerCase();
  // Только то, к чему есть замечания. `issues` считает сервер и уже везёт их
  // в каждом узле - до этого фильтра их показывала только раскрытая коробка.
  const bad = !!pick.bad;
  const hit = text => !find || String(text || '').toLowerCase().includes(find);

  // Раскрытый узел занимает столько, сколько нужно его содержимому, а соседи
  // разъезжаются - за это и берётся раскладка: коробка не накрывает чужие
  // строки, она их раздвигает.
  const open = pick.open || null;
  const openLines = pick.openLines || [];
  const openH = 4 + GRAPH_ROW + openLines.length * GRAPH_LINE + 6;
  const isOpen = (kind, id) =>
    open && open.kind === kind && open.id === id;
  const boxOf = (kind, id) => (isOpen(kind, id)
    ? { h: openH, w: GRAPH_OPEN_W } : { h: GRAPH_ROW - 4, w: 0 });

  const nodes = [];
  const edges = [];
  let y = 20;

  TYPES.forEach(type => {
    if (types.length && !types.includes(type.id)) return;
    const recs = RECIPES
      .filter(r => r.type_id === type.id
        && (show === 'all' || (r.acquire || 'forge') === show))
      .sort((a, b) =>
        (a.acquire === b.acquire ? 0 : a.acquire === 'forge' ? -1 : 1)
        || (a.req_skill - b.req_skill) || (a.id - b.id));
    if (!recs.length) return;

    const typeTop = y;
    const baseYs = [];
    // Отбор внутри основ (полоса, поиск, замечания) может не оставить ни
    // одной - а `recs` при этом не пуст, он считан до них. Тогда колонку типа
    // рисовать не за чем: столбец-одиночка без единой основы читается как
    // «тип есть, но пуст», хотя на деле он просто не прошёл отбор.
    const nodesBefore = nodes.length;

    recs.forEach(rec => {
      // Качество отбирает и эскизы, и основы: эскиз - по качеству своего
      // приза, основа - по ступеням, которые у неё заведены. Основа, чьи
      // ступени под отбор не подходят, но эскизы подходят, остаётся: без неё
      // эскизам было бы не на чем висеть.
      // Полоса отсекает основу целиком - вместе со всеми её эскизами: эскиз
      // живёт на своей основе и в чужой полосе смысла не имеет.
      if (bands.length && !bands.includes(Number(rec.req_skill))) return;

      const syns = SYNS.filter(sy => sy.recipe_id === rec.id
        && (!quals.length
            || quals.includes(Number((sy.result || {}).quality)))
        && (!bad || (sy.issues || []).length)
        // Совпало имя основы - показываем все её эскизы: искали основу, а не
        // строку в ней. Иначе поиск «бронзовый» оставлял бы пустую основу.
        && (hit(sy.name_ru) || hit(rec.name_ru) || hit(type.name_ru)));

      const baseFits = (!quals.length || (rec.results || [])
          .some(r => quals.includes(Number(r.quality))))
        && (!bad || (rec.issues || []).length)
        && (hit(rec.name_ru) || hit(type.name_ru));
      if (!baseFits && !syns.length) return;
      const rowTop = y;

      syns.forEach(syn => {
        const item = syn.result || null;
        const box = boxOf('syn', syn.id);
        nodes.push({
          kind: 'syn', id: syn.id, tab: 'named', attr: 'syn-id',
          x: GRAPH_COL.syn, y: y, w: box.w || GRAPH_W.syn, h: box.h,
          label: syn.name_ru || ('эскиз ' + syn.id),
          note: (syn.mats || []).length + ' камн.'
            + ((syn.issues || []).length ? ' · замечание' : ''),
          color: graphQualityColor(item ? item.quality : 0),
          warn: (syn.issues || []).length > 0 || !syn.result_entry,
        });
        y += Math.max(GRAPH_ROW, box.h + 4);
      });
      // Строки раскрытия кладём в сам узел: рисованию проще спросить узел, чем
      // сверяться с отбором.
      nodes.filter(n => n.kind === 'syn' && isOpen('syn', n.id))
        .forEach(n => { n.lines = openLines; });
      // Основа без единого эскиза - законное состояние («сковать можно, а
      // дальше дороги нет»), и на диаграмме она обязана быть видна.
      if (!syns.length) y += GRAPH_ROW;

      const baseBox = boxOf('base', rec.id);
      const baseY = (rowTop + y - GRAPH_ROW) / 2;
      baseYs.push(baseY);
      // Раскрытая основа может оказаться выше своей стопки эскизов - тогда
      // место под неё добирается снизу, чтобы следующая основа не наехала.
      const overflow = baseY + baseBox.h - y;
      if (overflow > 0) y += overflow;
      nodes.push({
        kind: 'base', id: rec.id, tab: 'recipes', attr: 'recipe-id',
        x: GRAPH_COL.base, y: baseY, w: baseBox.w || GRAPH_W.base,
        h: baseBox.h,
        label: rec.name_ru,
        note: ((rec.acquire === 'drop') ? 'добыча' : 'навык ' + rec.req_skill)
          + ' · ст. ' + (rec.results || []).length
          + ' · эск. ' + syns.length,
        warn: (rec.issues || []).length > 0,
        off: !rec.enabled,
        lines: isOpen('base', rec.id) ? openLines : null,
      });

      syns.forEach((syn, i) => edges.push({
        x1: GRAPH_COL.base + GRAPH_W.base, y1: baseY + GRAPH_ROW / 2,
        x2: GRAPH_COL.syn, y2: rowTop + i * GRAPH_ROW + GRAPH_ROW / 2,
      }));
      y += GRAPH_GAP;
    });

    if (nodes.length === nodesBefore) {
      y = typeTop;            // место, занятое под пустой тип, возвращаем
      return;
    }

    const typeBox = boxOf('type', type.id);
    const typeY = (typeTop + y - GRAPH_GAP - GRAPH_ROW) / 2;
    if (typeY + typeBox.h - y > 0) y += typeY + typeBox.h - y;
    nodes.push({
      kind: 'type', id: type.id, x: GRAPH_COL.type, y: typeY,
      w: typeBox.w || GRAPH_W.type, h: typeBox.h,
      label: type.name_ru, note: 'основ ' + recs.length,
      lines: isOpen('type', type.id) ? openLines : null,
    });
    baseYs.forEach(by => edges.push({
      x1: GRAPH_COL.type + GRAPH_W.type, y1: typeY + GRAPH_ROW / 2,
      x2: GRAPH_COL.base, y2: by + GRAPH_ROW / 2,
    }));
    y += GRAPH_GAP * 2;
  });

  return {
    nodes: nodes, edges: edges,
    width: GRAPH_COL.syn + GRAPH_W.syn + 40,
    height: Math.max(y + 20, 200),
  };
}

// Текущий масштаб и сдвиг наружу - для проверки страницы и для отладки из
// консоли. Память вкладки объявлена через `const`, а такие имена в окне не
// видны: функция видна.
function graphState() {
  return (ADD_MEMORY.map || {}).graph || null;
}

function graphNodeAt(g, x, y) {
  // Узлов тысячи, но проход по плоскому списку на движение мыши дешевле, чем
  // поиск по разметке, - а разметки тут и нет.
  for (let i = g.nodes.length - 1; i >= 0; i--) {
    const n = g.nodes[i];
    const h = n.h || (GRAPH_ROW - 4);
    if (x >= n.x && x <= n.x + n.w && y >= n.y && y <= n.y + h) return n;
  }
  return null;
}

// Подпись, обрезанная по ширине: длинное имя не должно наползать на соседнюю
// колонку.
function graphClip(ctx, text, width) {
  const s = String(text == null ? '' : text);
  if (ctx.measureText(s).width <= width) return s;
  let lo = 0;
  let hi = s.length;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (ctx.measureText(s.slice(0, mid) + '…').width <= width) lo = mid;
    else hi = mid - 1;
  }
  return s.slice(0, lo) + '…';
}

function graphDraw(cv, g, state) {
  const ctx = cv.getContext && cv.getContext('2d');
  // Проверка страницы гоняет её в jsdom, а там canvas не рисует. Пустой холст
  // - не повод падать: всё остальное на вкладке обязано работать.
  if (!ctx) return;

  const pal = GRAPH_PAL || (GRAPH_PAL = graphPalette());
  const ratio = window.devicePixelRatio || 1;
  const cw = cv.clientWidth || 900;
  const ch = cv.clientHeight || GRAPH_H;
  if (cv.width !== Math.round(cw * ratio)) cv.width = Math.round(cw * ratio);
  if (cv.height !== Math.round(ch * ratio)) cv.height = Math.round(ch * ratio);

  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  ctx.clearRect(0, 0, cw, ch);
  ctx.save();
  ctx.translate(state.x, state.y);
  ctx.scale(state.scale, state.scale);

  // Видимое окно в координатах раскладки: что за ним - не рисуем вовсе.
  const vy1 = -state.y / state.scale;
  const vy2 = vy1 + ch / state.scale;

  ctx.lineWidth = 1 / state.scale;
  ctx.strokeStyle = pal.line;
  ctx.beginPath();
  g.edges.forEach(e => {
    if (Math.max(e.y1, e.y2) < vy1 || Math.min(e.y1, e.y2) > vy2) return;
    const mid = (e.x1 + e.x2) / 2;
    ctx.moveTo(e.x1, e.y1);
    ctx.bezierCurveTo(mid, e.y1, mid, e.y2, e.x2, e.y2);
  });
  ctx.stroke();

  const labels = state.scale >= GRAPH_LABEL_AT;
  ctx.font = '12px "Segoe UI", system-ui, sans-serif';
  ctx.textBaseline = 'middle';

  g.nodes.forEach(n => {
    const h = n.h || (GRAPH_ROW - 4);
    if (n.y + h < vy1 || n.y > vy2) return;
    const hot = state.hover === n;
    const open = !!n.lines;
    ctx.globalAlpha = n.off ? 0.45 : 1;
    ctx.fillStyle = (hot || open) ? pal.panelHi : pal.panel;
    ctx.strokeStyle = open ? pal.gold
      : n.kind === 'type' ? pal.gold
      : n.kind === 'base' ? (n.warn ? pal.quality[5] : pal.goldDim)
      : (n.color || pal.muted);
    ctx.lineWidth = (open ? 2 : 1) / state.scale;
    ctx.beginPath();
    ctx.rect(n.x, n.y, n.w, h);
    ctx.fill();
    ctx.stroke();
    ctx.lineWidth = 1 / state.scale;

    // Раскрытая коробка показывает содержимое, даже если мелкий масштаб гасит
    // обычные подписи: её ради содержимого и раскрывали.
    if (labels || open) {
      const cy = n.y + (GRAPH_ROW - 4) / 2;
      ctx.fillStyle = n.kind === 'type' ? pal.gold
        : n.kind === 'syn' ? (n.color || pal.text) : pal.text;
      ctx.fillText(graphClip(ctx, n.label, n.w - (open ? 28 : 110)),
                   n.x + 8, cy);
      if (!open) {
        ctx.fillStyle = pal.muted;
        ctx.fillText(graphClip(ctx, n.note, 100), n.x + n.w - 102, cy);
      }
    }

    if (open) {
      // Крестик в углу: щелчок по нему закрывает - это ближе, чем искать тот
      // же узел под курсором второй раз.
      ctx.fillStyle = pal.muted;
      ctx.fillText('×', n.x + n.w - 16, n.y + (GRAPH_ROW - 4) / 2);

      let ly = n.y + GRAPH_ROW + GRAPH_LINE / 2;
      n.lines.forEach(line => {
        let lx = n.x + 10;
        if (line.icon) {
          const img = graphIcon(line.icon, state.redraw);
          if (img) {
            ctx.drawImage(img, lx, ly - 6, 13, 13);
          }
          lx += 17;
        }
        ctx.fillStyle = line.link ? pal.gold
          : line.warn ? pal.quality[5]
          : line.head ? pal.gold
          : line.dim ? pal.muted
          : line.quality ? pal.quality[Math.min(5, line.quality)]
          : pal.text;
        const text = graphClip(ctx, line.text, n.w - (lx - n.x) - 12);
        const tx = lx + (line.pad ? 10 : 0);
        ctx.fillText(text, tx, ly);
        // Строка-ссылка подчёркивается и запоминает, куда её нажали: полотно
        // не разметка, попадание по строке считать больше негде.
        if (line.link) {
          const w = ctx.measureText(text).width;
          ctx.fillRect(tx, ly + 7, w, 1);
          line._hit = { x: tx, y: ly, w: w };
        }
        ly += GRAPH_LINE;
      });
    }
    ctx.globalAlpha = 1;
  });

  ctx.restore();
}

// --- раскрытый узел --------------------------------------------------------
// Узел раскрывается НА МЕСТЕ: коробка растёт вниз, соседи разъезжаются, внутри
// - характеристики предмета и материалы. Карточка под полотном была первой
// попыткой, но она отрывала сведения от узла: глаз искал, о чём именно речь.
//
// Полную строку предмета отдаёт общий `/api/items/{entry}` - тот же, которым
// живёт «Каталог предметов». Своего эндпоинта заводить незачем, а ходить за
// строкой заранее нельзя: предметов на диаграмме три тысячи, поэтому запрос
// идёт по требованию и ложится в кэш.

const GRAPH_ITEMS = new Map();   // entry -> строка item_template или null
const GRAPH_ICONS = new Map();   // url -> Image
const GRAPH_OPEN_W = 520;        // ширина раскрытой коробки
const GRAPH_LINE = 16;           // высота строки внутри неё

let ITEM_ENUMS = null;

async function itemEnums() {
  // Имена характеристик берём из справочников редактора предметов, а не
  // заводим свой список тех же чисел: второй такой разошёлся бы с первым на
  // первой же правке.
  if (!ITEM_ENUMS) {
    try {
      ITEM_ENUMS = (await api('/api/items/meta')).enums || {};
    } catch (err) {
      ITEM_ENUMS = {};
    }
  }
  return ITEM_ENUMS;
}

function statTypeName(type) {
  const list = (ITEM_ENUMS && ITEM_ENUMS.statType) || [];
  const hit = list.find(o => Number(o.value) === Number(type));
  return hit ? hit.label : ('стат ' + type);
}

async function graphItem(entry) {
  const id = parseInt(entry, 10) || 0;
  if (!id) return null;
  if (!GRAPH_ITEMS.has(id)) {
    try {
      GRAPH_ITEMS.set(id, await api('/api/items/' + id));
    } catch (err) {
      GRAPH_ITEMS.set(id, null);   // строки нет - так и скажем в коробке
    }
  }
  return GRAPH_ITEMS.get(id);
}

// Иконка для полотна: картинки грузятся сами по себе, и когда догрузились -
// просим перерисовать. Кэш общий, потому что один и тот же слиток стоит в
// сотне рецептов.
function graphIcon(texture, onLoad) {
  const url = iconUrl(texture);
  if (!url) return null;
  if (!GRAPH_ICONS.has(url)) {
    const img = new Image();
    img.onload = () => { img.ready = true; if (onLoad) onLoad(); };
    img.onerror = () => { img.failed = true; };
    img.src = url;
    GRAPH_ICONS.set(url, img);
  }
  const img = GRAPH_ICONS.get(url);
  return (img && img.ready) ? img : null;
}

// Характеристики строки предмета человеческим списком. Пустые поля молчат:
// «броня 0» у меча - не сведение, а шум.
function graphStatLines(row) {
  if (!row || !row.fields) return [];
  const f = row.fields;
  const num = name => Number(f[name] || 0);
  const out = [];

  const dmgMin = num('dmg_min1');
  const dmgMax = num('dmg_max1');
  const delay = num('delay');
  if (dmgMax > 0) {
    let line = 'Урон ' + Math.round(dmgMin) + '-' + Math.round(dmgMax);
    if (delay > 0) {
      line += ' · скорость ' + (delay / 1000).toFixed(1)
        + ' · ' + ((dmgMin + dmgMax) / 2 / (delay / 1000)).toFixed(1)
        + ' ур/сек';
    }
    out.push(line);
  }
  if (num('armor')) out.push('Броня ' + num('armor'));
  if (num('block')) out.push('Блок ' + num('block'));
  if (num('MaxDurability')) out.push('Прочность ' + num('MaxDurability'));
  if (num('RequiredLevel')) out.push('Требует уровень ' + num('RequiredLevel'));

  const stats = [];
  for (let i = 1; i <= 10; i++) {
    const type = num('stat_type' + i);
    const value = num('stat_value' + i);
    if (type && value) stats.push(statTypeName(type) + ' +' + value);
  }
  if (stats.length) out.push(stats.join(', '));

  const sockets = [1, 2, 3]
    .map(i => num('socketColor_' + i)).filter(Boolean).length;
  if (sockets) out.push('Ванильных гнёзд ' + sockets);
  return out;
}

// Строка материала: иконка и подпись с количеством.
function graphMatLine(entry, count, prefix) {
  const mat = MATS.find(m => m.entry === entry);
  const item = mat && mat.item;
  const name = (mat && (mat.name_ru || (item && item.name)))
    || ('предмет ' + entry);
  return {
    text: (prefix || '') + name + (count > 1 ? ' x' + count : ''),
    icon: item && item.icon,
    quality: item ? item.quality : 0,
  };
}

// Содержимое раскрытой коробки. Сначала - то, что уже известно странице, а
// характеристики дописываются, когда придёт ответ на предмет.
// Где падает предмет - спрашиваем у страницы добычи её же запросом. Ответ
// кладём в кэш: раскрытие узла дёргается на каждый пересчёт раскладки, а
// обход ссылок вверх стоит недёшево.
const GRAPH_DROPS = new Map();

async function graphDrops(entry) {
  if (!entry) return null;
  if (GRAPH_DROPS.has(entry)) return GRAPH_DROPS.get(entry);
  let out = null;
  try {
    out = await api('/api/loot/item/' + entry);
  } catch (e) {
    out = { paths: [], error: e.message };
  }
  GRAPH_DROPS.set(entry, out);
  return out;
}

// Строки «откуда падает» для раскрытого узла. Показываем три самых щедрых
// пути и общий счёт: список из сорока источников в коробке не читается, а
// вопрос у владельца обычно один - «часто ли и с кого».
function graphDropLines(drops, entry) {
  const lines = [];
  if (!drops || drops.error) {
    lines.push({ text: 'Добыча: ' + ((drops && drops.error) || 'нет ответа'),
                 dim: true });
    return lines;
  }
  const paths = drops.paths || [];
  if (!paths.length) {
    lines.push({ text: 'Нигде не падает', warn: true });
  } else {
    lines.push({ text: 'Падает: источников ' + paths.length
      + (drops.truncated ? ' (список обрезан)' : ''), head: true });
    paths.slice(0, 3).forEach(p => lines.push({
      text: '• ' + (p.owner_name || '?')
        + ' — ' + (p.chance >= 0.01 ? p.chance.toFixed(2) : p.chance) + ' %',
      pad: true,
    }));
    if (paths.length > 3) {
      lines.push({ text: '…и ещё ' + (paths.length - 3), pad: true, dim: true });
    }
  }
  lines.push({ text: 'Открыть в «Добыче» →', link: '/loot.html#item=' + entry });
  return lines;
}

async function graphOpenLines(open) {
  await itemEnums();
  const lines = [];

  if (open.kind === 'type') {
    const type = TYPES.find(t => t.id === open.id);
    if (!type) return [{ text: 'тип не найден' }];
    const recs = RECIPES.filter(r => r.type_id === type.id);
    const syns = SYNS.filter(s => recs.some(r => r.id === s.recipe_id));
    lines.push({ text: 'основ ' + recs.length
      + ' · ковочных ' + recs.filter(r => r.acquire !== 'drop').length
      + ' · добычных ' + recs.filter(r => r.acquire === 'drop').length });
    lines.push({ text: 'эскизов ' + syns.length });
    return lines;
  }

  if (open.kind === 'base') {
    const rec = RECIPES.find(r => r.id === open.id);
    if (!rec) return [{ text: 'основа не найдена' }];
    const type = TYPES.find(t => t.id === rec.type_id);
    lines.push({ text: (type ? type.name_ru : 'тип ?')
      + ' · ' + (rec.acquire === 'drop' ? 'только добыча'
                                        : 'навык ' + rec.req_skill)
      + ' · качество ' + qualityName(rec.quality_min)
      + '-' + qualityName(rec.quality_max)
      + (rec.enabled ? '' : ' · выключен'), dim: true });

    if (rec.acquire === 'drop') {
      lines.push({ text: 'Куётся: нет, эту основу выбивают', dim: true });
    } else {
      lines.push({ text: 'Для ковки:', head: true });
      const cells = (rec.cells || []).filter(c => c.item_entry);
      if (!cells.length) lines.push({ text: 'ячейки пусты', dim: true });
      cells.forEach(c => lines.push(graphMatLine(c.item_entry, c.count)));
    }

    lines.push({ text: 'Ступени:', head: true });
    for (const step of (rec.results || [])) {
      const slot = (rec.inlay || []).find(i => i.quality === step.quality);
      const row = await graphItem(step.result_entry);
      const item = step.item || {};
      lines.push({
        text: qualityName(step.quality)
          + (slot ? ' · гнёзд ' + slot.slots : '')
          + ' · ' + (item.name || ('предмет ' + step.result_entry))
          + (item.ilvl ? ' · ур. ' + item.ilvl : ''),
        icon: item.icon, quality: item.quality || 0,
      });
      graphStatLines(row).forEach(t => lines.push({ text: t, pad: true }));
    }

    // Откуда берётся сама основа. Для заготовки это главный вопрос вообще -
    // выковать её нельзя, - а прежде узел говорил лишь «эту основу выбивают».
    // Берём нижнюю ступень: имя у ступеней общее, а падает именно она.
    const dropStep = (rec.results || [])[0];
    if (dropStep && dropStep.result_entry) {
      graphDropLines(await graphDrops(dropStep.result_entry),
                     dropStep.result_entry)
        .forEach(l => lines.push(l));
    }

    const syns = SYNS.filter(s => s.recipe_id === rec.id);
    lines.push({ text: 'Эскизов: ' + syns.length
      + (syns.length ? ' — ' + syns.slice(0, 4).map(s => s.name_ru).join(', ')
                       + (syns.length > 4 ? ' и ещё ' + (syns.length - 4) : '')
                     : ''), dim: true });
    (rec.issues || []).forEach(t => lines.push({ text: '• ' + t, warn: true }));
    return lines;
  }

  const syn = SYNS.find(s => s.id === open.id);
  if (!syn) return [{ text: 'эскиз не найден' }];
  const rec = RECIPES.find(r => r.id === syn.recipe_id);
  lines.push({ text: 'из основы: ' + (rec ? rec.name_ru : 'основы нет')
    + (syn.order_matters ? ' · порядок значим' : '')
    + (syn.enabled ? '' : ' · выключен'), dim: true });

  lines.push({ text: 'Для инкрустации:', head: true });
  (syn.mats || []).forEach((entry, i) =>
    lines.push(graphMatLine(entry, 0, (i + 1) + '. ')));

  const prize = syn.result || {};
  lines.push({ text: 'Выходит: ' + (prize.name || ('предмет ' + syn.result_entry))
    + (prize.ilvl ? ' · ур. ' + prize.ilvl : ''),
    icon: prize.icon, quality: prize.quality || 0, head: true });
  const row = await graphItem(syn.result_entry);
  const stats = graphStatLines(row);
  if (stats.length) stats.forEach(t => lines.push({ text: t, pad: true }));
  else lines.push({ text: 'характеристик нет', pad: true, dim: true });

  const need = (syn.mats || []).length;
  const fit = ((rec && rec.inlay) || []).filter(i => i.slots >= need);
  lines.push({
    text: fit.length
      ? 'собирается на ступенях: '
        + fit.map(i => qualityName(i.quality)).join(', ')
      : 'ни одна ступень основы не даёт столько гнёзд',
    warn: !fit.length, dim: fit.length > 0,
  });

  if (syn.teach_item) {
    const book = await graphItem(syn.teach_item);
    lines.push({ text: 'Учит книга: '
      + ((book && book.fields && book.fields.name_ru)
         || ('предмет ' + syn.teach_item)), dim: true });
  } else {
    lines.push({ text: 'Книги нет: эскиз только угадывается', dim: true });
  }
  (syn.issues || []).forEach(t => lines.push({ text: '• ' + t, warn: true }));
  return lines;
}

// Вид диаграммы в адресе: отбор из шести чипов и строки поиска руками не
// пересобрать, а показать коллеге «вот эти сорок узлов» хочется ссылкой.
// Пишем в hash, а не в query: перезагрузки страницы он не вызывает и на
// маршрутизацию панели не влияет.
//
// Ключи короткие нарочно - адрес читается глазами: s=show, t=types, q=quals,
// b=bands, f=find, w=warn.
function graphWriteUrl(state) {
  const p = new URLSearchParams();
  if (state.show && state.show !== 'all') p.set('s', state.show);
  if ((state.types || []).length) p.set('t', state.types.join(','));
  if ((state.quals || []).length) p.set('q', state.quals.join(','));
  if ((state.bands || []).length) p.set('b', state.bands.join(','));
  if (state.find) p.set('f', state.find);
  if (state.bad) p.set('w', '1');
  const s = p.toString();
  // replaceState, а не push: отбор - это не шаг истории, и «назад» после
  // десяти щелчков по чипам должен уводить со страницы, а не отматывать их.
  history.replaceState(null, '', s ? ('#graph?' + s) : location.pathname);
}

function graphReadUrl(state) {
  const hash = location.hash || '';
  const at = hash.indexOf('?');
  if (!hash.startsWith('#graph') || at < 0) return;
  const p = new URLSearchParams(hash.slice(at + 1));
  const nums = key => (p.get(key) || '').split(',')
    .map(Number).filter(n => !isNaN(n) && n !== 0);
  if (p.get('s')) state.show = p.get('s');
  if (p.get('t')) state.types = nums('t');
  if (p.get('q')) state.quals = nums('q');
  if (p.get('b')) state.bands = nums('b');
  if (p.get('f')) state.find = p.get('f');
  if (p.get('w')) state.bad = true;
}

function renderGraph(view, mem) {
  GRAPH_PAL = graphPalette();
  if (!mem.graph) {
    mem.graph = { show: 'all', types: [], quals: [], bands: [], find: '',
                  bad: false, scale: 0, x: 0, y: 0 };
    graphReadUrl(mem.graph);
  }
  const state = mem.graph;
  if (!state.types) state.types = [];
  if (!state.quals) state.quals = [];
  if (!state.bands) state.bands = [];
  if (typeof state.find !== 'string') state.find = '';
  let g = graphLayout(state);

  const bar = el('div', 'graph-bar');
  [['all', 'Всё'], ['forge', 'Ковка'], ['drop', 'Добыча']].forEach(pair => {
    const b = el('button', state.show === pair[0] ? 'chip active' : 'chip',
                 pair[1]);
    b.addEventListener('click', () => {
      state.show = pair[0];
      state.scale = 0;   // другой отбор - другая высота, вид подгоняем заново
      graphWriteUrl(state);
      render();
    });
    bar.appendChild(b);
  });

  // Чип замечаний стоит рядом с «Всё/Ковка/Добыча»: это тоже отбор «что
  // показывать», а не «чего именно», и выбор у него один - да или нет.
  const badChip = el('button', state.bad ? 'chip active' : 'chip',
                     'только с замечаниями');
  badChip.addEventListener('click', () => {
    state.bad = !state.bad;
    state.scale = 0;
    graphWriteUrl(state);
    render();
  });
  bar.appendChild(badChip);

  bar.appendChild(el('span', 'muted',
    'узлов ' + g.nodes.length + ' · связей ' + g.edges.length));

  // Отбор меняет высоту раскладки, поэтому вид подгоняем заново - иначе
  // после сужения картинка осталась бы стоять в пустоте за нижним краем.
  const refilter = () => { state.scale = 0; graphWriteUrl(state); render(); };

  // Переключатель списка: щелчок добавляет или убирает, «все» очищает отбор.
  const pickRow = (title, items, chosen, key) => {
    const row = el('div', 'graph-filters');
    row.appendChild(el('span', 'muted', title));
    const any = el('button', chosen.length ? 'chip' : 'chip active', 'все');
    any.addEventListener('click', () => { state[key] = []; refilter(); });
    row.appendChild(any);
    items.forEach(it => {
      const on = chosen.includes(it.id);
      const b = el('button', on ? 'chip active' : 'chip', it.label);
      b.addEventListener('click', () => {
        state[key] = on ? chosen.filter(x => x !== it.id) : chosen.concat([it.id]);
        refilter();
      });
      row.appendChild(b);
    });
    return row;
  };

  const zoomOut = el('button', 'btn', '−');
  const zoomIn = el('button', 'btn', '+');
  const fit = el('button', 'btn', 'Вместить');
  const whole = el('button', 'btn', 'Целиком');
  const level = el('span', 'muted', '');
  [zoomOut, zoomIn, fit, whole, level].forEach(b => bar.appendChild(b));
  view.appendChild(bar);

  view.appendChild(pickRow('Типы:',
    TYPES.map(t => ({ id: t.id, label: t.name_ru })), state.types, 'types'));
  view.appendChild(pickRow('Качество:',
    (META.qualities || [])
      .filter(q => q.quality >= 1 && q.quality <= 5)
      .map(q => ({ id: q.quality, label: q.name_ru })),
    state.quals, 'quals'));

  // Полосы. Ключ чипа - НАВЫК полосы, а не её номер: именно им рецепт с ней и
  // связан. Базы без v32 полос не отдают вовсе - тогда строки просто нет.
  if ((META.bands || []).length) {
    view.appendChild(pickRow('Полоса:',
      META.bands.map(b => ({ id: b.skill, label: b.name_ru })),
      state.bands, 'bands'));
  }

  // Поиск. Перерисовываем по вводу, но вид НЕ подгоняем: подгонка на каждой
  // букве дёргала бы масштаб под руками у того, кто ещё печатает.
  const findRow = el('div', 'graph-filters');
  findRow.appendChild(el('span', 'muted', 'Поиск:'));
  const findBox = document.createElement('input');
  findBox.className = 'graph-find';
  findBox.type = 'search';
  findBox.placeholder = 'имя эскиза, основы или типа';
  findBox.value = state.find;
  findBox.addEventListener('input', () => {
    state.find = findBox.value;
    graphWriteUrl(state);
    g = graphLayout(state);
    draw();
  });
  findRow.appendChild(findBox);
  const clear = el('button', 'btn', 'Сбросить всё');
  clear.addEventListener('click', () => {
    state.show = 'all';
    state.types = [];
    state.quals = [];
    state.bands = [];
    state.find = '';
    state.bad = false;
    state.scale = 0;
    graphWriteUrl(state);
    render();
  });
  findRow.appendChild(clear);
  view.appendChild(findRow);

  const wrap = el('div', 'graph-wrap');
  const cv = document.createElement('canvas');
  cv.className = 'graph-canvas';
  cv.style.height = GRAPH_H + 'px';
  wrap.appendChild(cv);
  const tip = el('div', 'graph-tip');
  tip.style.display = 'none';
  wrap.appendChild(tip);
  view.appendChild(wrap);

  // Раскрытие: узел растёт на месте, соседи разъезжаются. Раскладка считается
  // заново - иначе коробка накрыла бы чужие строки вместо того, чтобы их
  // раздвинуть.
  const relayout = () => { g = graphLayout(state); draw(); };

  const openNode = node => {
    if (!node) {
      state.open = null;
      state.openLines = [];
      relayout();
      return;
    }
    // Тот же узел вторым щелчком - закрыть.
    if (state.open && state.open.kind === node.kind
        && state.open.id === node.id) {
      openNode(null);
      return;
    }
    state.open = { kind: node.kind, id: node.id };
    state.openLines = [{ text: 'читаю…', dim: true }];
    relayout();
    const asked = state.open;
    graphOpenLines(asked).then(lines => {
      // Пока ходили за предметом, могли раскрыть другой узел - тогда ответ
      // уже ни к чему.
      if (state.open !== asked) return;
      state.openLines = lines;
      relayout();
    });
  };

  // Иконки догружаются сами; когда догрузились - просим кадр.
  state.redraw = () => draw();

  const draw = () => {
    graphDraw(cv, g, state);
    level.textContent = Math.round(state.scale * 100) + '%';
  };

  // «Вместить» - по ШИРИНЕ, а не целиком: раскладка высотой под шестьдесят
  // тысяч точек, и попытка уместить её в полотно даёт масштаб в один процент,
  // где узел тоньше волоса. По ширине же всё читается, а вниз полотно
  // протаскивается мышью.
  const doFit = () => {
    const cw = cv.clientWidth || 900;
    state.scale = Math.min(cw / g.width, 1) || 0.05;
    state.x = (cw - g.width * state.scale) / 2;
    state.y = 8;
    draw();
  };

  // А «Целиком» - именно вся картина разом: увидеть форму сетки, где густо, а
  // где пусто. Подписи на таком масштабе не рисуются, и это честно.
  const doWhole = () => {
    const cw = cv.clientWidth || 900;
    state.scale = Math.max(0.02, Math.min(cw / g.width, GRAPH_H / g.height));
    state.x = (cw - g.width * state.scale) / 2;
    state.y = (GRAPH_H - g.height * state.scale) / 2;
    draw();
  };

  const zoomAt = (px, py, factor) => {
    const next = Math.max(0.02, Math.min(4, state.scale * factor));
    const k = next / state.scale;
    state.x = px - (px - state.x) * k;
    state.y = py - (py - state.y) * k;
    state.scale = next;
    draw();
  };

  cv.addEventListener('wheel', e => {
    e.preventDefault();
    const r = cv.getBoundingClientRect();
    zoomAt(e.clientX - r.left, e.clientY - r.top,
           e.deltaY < 0 ? 1.15 : 1 / 1.15);
  }, { passive: false });

  let drag = null;
  cv.addEventListener('mousedown', e => {
    drag = { x: e.clientX, y: e.clientY, ox: state.x, oy: state.y, moved: 0 };
    cv.classList.add('dragging');
  });
  window.addEventListener('mouseup', e => {
    // Щелчок и протаскивание начинаются одинаково, поэтому различаем их по
    // пройденному пути: сдвинул полотно - значит не выбирал узел.
    if (drag && drag.moved < 4) {
      const r = cv.getBoundingClientRect();
      const lx = (e.clientX - r.left - state.x) / state.scale;
      const ly = (e.clientY - r.top - state.y) / state.scale;
      const node = graphNodeAt(g, lx, ly);
      // Ссылка внутри раскрытой коробки старше и крестика, и самого узла:
      // по ней щёлкают нарочно, а закрыть узел можно чем угодно ещё.
      const hit = node && node.lines && node.lines.find(l => l._hit
        && lx >= l._hit.x && lx <= l._hit.x + l._hit.w
        && ly >= l._hit.y - 7 && ly <= l._hit.y + 8);
      if (hit) {
        window.open(hit.link, '_blank');
      } else if (node && node.lines
          && lx > node.x + node.w - 24 && ly < node.y + GRAPH_ROW) {
        openNode(null);          // крестик в углу раскрытой коробки
      } else if (node) {
        openNode(node);
      }
    }
    drag = null;
    cv.classList.remove('dragging');
  });
  cv.addEventListener('mousemove', e => {
    const r = cv.getBoundingClientRect();
    if (drag) {
      drag.moved = Math.max(drag.moved,
        Math.abs(e.clientX - drag.x) + Math.abs(e.clientY - drag.y));
      state.x = drag.ox + (e.clientX - drag.x);
      state.y = drag.oy + (e.clientY - drag.y);
      draw();
      return;
    }
    const node = graphNodeAt(g,
      (e.clientX - r.left - state.x) / state.scale,
      (e.clientY - r.top - state.y) / state.scale);
    if (node !== state.hover) {
      state.hover = node;
      draw();
    }
    if (node) {
      tip.textContent = node.label + ' — ' + node.note;
      tip.style.display = '';
      tip.style.left = Math.min(e.clientX - r.left + 14, r.width - 260) + 'px';
      tip.style.top = (e.clientY - r.top + 14) + 'px';
    } else {
      tip.style.display = 'none';
    }
  });
  cv.addEventListener('mouseleave', () => {
    tip.style.display = 'none';
    state.hover = null;
    draw();
  });
  cv.addEventListener('dblclick', e => {
    const r = cv.getBoundingClientRect();
    const node = graphNodeAt(g,
      (e.clientX - r.left - state.x) / state.scale,
      (e.clientY - r.top - state.y) / state.scale);
    if (node && node.tab) mapGoto(node.tab, node.attr, node.id);
  });

  zoomIn.addEventListener('click',
    () => zoomAt((cv.clientWidth || 900) / 2, GRAPH_H / 2, 1.25));
  zoomOut.addEventListener('click',
    () => zoomAt((cv.clientWidth || 900) / 2, GRAPH_H / 2, 1 / 1.25));
  fit.addEventListener('click', doFit);
  whole.addEventListener('click', doWhole);

  // Первая отрисовка ждёт кадра: до вставки в страницу у полотна нет ширины,
  // и «Вместить» посчитало бы по нулю.
  requestAnimationFrame(() => {
    if (!state.scale) doFit();
    else draw();
  });
}

function renderMap(view) {
  const mem = addMemory('map', { type: (TYPES[0] || {}).id, dir: 'base' });

  // Переключатель вида: две стороны одной связи и общая диаграмма.
  const modes = el('div', 'map-modes');
  [['base', 'Основы → эскизы'],
   ['named', 'Эскизы → основы'],
   ['graph', 'Диаграмма']].forEach(pair => {
    const b = el('button', mem.dir === pair[0] ? 'chip active' : 'chip', pair[1]);
    b.addEventListener('click', () => { mem.dir = pair[0]; render(); });
    modes.appendChild(b);
  });
  view.appendChild(modes);

  // Диаграмма показывает ВСЁ разом и типом не ограничена - полоса типов ей ни
  // к чему, у неё свой отбор.
  if (mem.dir === 'graph') {
    renderGraph(view, mem);
    return;
  }

  // Полоса типов: вся сетка разом - это две с лишним сотни карточек, и читать
  // её никто не станет.
  const strip = el('div', 'map-types');
  TYPES.forEach(t => {
    const count = RECIPES.filter(r => r.type_id === t.id).length;
    const b = el('button',
      String(t.id) === String(mem.type) ? 'chip active' : 'chip',
      t.name_ru + ' · ' + count);
    b.addEventListener('click', () => { mem.type = t.id; render(); });
    strip.appendChild(b);
  });
  view.appendChild(strip);

  const typeId = parseInt(mem.type, 10);
  const recs = RECIPES
    .filter(r => r.type_id === typeId)
    .sort((a, b) => (a.req_skill - b.req_skill) || (a.id - b.id));
  const syns = SYNS.filter(s => recs.some(r => r.id === s.recipe_id));
  const steps = recs.reduce((n, r) => n + (r.results || []).length, 0);

  view.appendChild(el('p', 'muted',
    'основ ' + recs.length + ' · ступеней ' + steps + ' · эскизов ' + syns.length));

  if (!recs.length) {
    view.appendChild(el('div', 'empty', 'у этого типа нет ни одной основы'));
    return;
  }

  const box = el('div', 'map-box');
  if (mem.dir === 'base') {
    recs.forEach(rec => box.appendChild(
      mapRecipe(rec, SYNS.filter(s => s.recipe_id === rec.id))));
  } else if (!syns.length) {
    box.appendChild(el('div', 'empty', 'у этого типа нет ни одного эскиза'));
  } else {
    syns.forEach(syn => box.appendChild(mapNamedCard(syn)));
  }
  view.appendChild(box);
}

// --- каркас ---------------------------------------------------------------

async function reloadServer() {
  try {
    const res = await api('/api/aprof/reload', { method: 'POST' });
    toast('Сервер перечитал справочники.', 'ok');
    console.log(res.output);
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

  // Панель пишет в базу, модуль держит справочники в памяти: без этой кнопки
  // правка доедет до игры только на следующем рестарте мира.
  const apply = el('button', 'apply', 'Применить на сервере');
  apply.title = 'Выполняет ".aprof reload" на PTR по SOAP.';
  apply.addEventListener('click', reloadServer);
  box.appendChild(apply);
}

// Заголовок таблицы липнет под вкладками, но только из настоящего <thead>:
// Chrome не держит sticky на <th> внутри неявного <tbody>, и строка уезжает
// вниз на величину своего top, наезжая на данные. Строители таблиц про это
// знать не обязаны - переносим первую строку сюда, в одном месте.
function stickHeads(root) {
  root.querySelectorAll('table.grid').forEach(table => {
    if (table.tHead || !table.rows.length) return;
    const first = table.rows[0];
    if (!first.cells.length || first.cells[0].tagName !== 'TH') return;
    const head = document.createElement('thead');
    head.appendChild(first);
    table.insertBefore(head, table.firstChild);
  });
}

async function render() {
  renderTabs();
  const view = document.getElementById('view');
  view.innerHTML = '';
  if (TAB === 'types') renderTypes(view);
  else if (TAB === 'materials') renderMaterials(view);
  else if (TAB === 'recipes') renderRecipes(view);
  else if (TAB === 'named') renderNamed(view);
  else if (TAB === 'map') renderMap(view);
  else if (TAB === 'dicts') renderDicts(view);
  else if (TAB === 'balance') await renderBalance(view);
  else if (TAB === 'preview') renderPreview(view);
  else if (TAB === 'merge') await renderMerge(view);
  else if (TAB === 'pool') await renderPool(view);
  stickHeads(view);
  tailPager(view);
}

// Листалка ещё и под листом. Сверху она тоже есть, но страницу дочитывают
// снизу, и возвращаться за «вперёд» к началу - лишний ход.
function tailPager(root) {
  const st = VIEW[TAB];
  if (!st || !(st.pages > 1)) return;
  root.appendChild(pager(TAB, false));
}

async function loadAll() {
  PART_KINDS = (await api('/api/aprof/part-kinds')).rows;
  INSERT_TYPES = (await api('/api/aprof/insert-types')).rows;
  MATS = (await api('/api/aprof/materials')).materials;
  TYPES = (await api('/api/aprof/types')).types;
  RECIPES = (await api('/api/aprof/recipes')).recipes;
  SYNS = (await api('/api/aprof/synergies')).synergies;
  MERGES = (await api('/api/aprof/merges')).merges;
  await render();
}

async function boot() {
  await mountSession();
  const view = document.getElementById('view');
  try {
    META = await api('/api/aprof/meta');
  } catch (e) {
    view.innerHTML = '';
    view.appendChild(el('div', 'empty', e.message));
    return;
  }
  if (!META.available) {
    view.innerHTML = '';
    view.appendChild(el('div', 'empty',
      'Таблиц модуля нет. Примените миграцию ' +
      'data/sql/updates/pending_db_world/mod_advanced_professions_v1.sql'));
    return;
  }
  try {
    await loadAll();
  } catch (e) {
    view.innerHTML = '';
    view.appendChild(el('div', 'empty', e.message));
  }
}

boot();
