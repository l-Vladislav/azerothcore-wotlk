// Прогон страницы /loot.html в jsdom против ЖИВОЙ панели PTR.
//
//   npm install jsdom      (разово, где угодно - модуль ищется по NODE_PATH)
//   node tools/admin-panel/scripts/check_loot_page.js
//
// Смотрим то же, что увидит владелец: три вкладки рисуются, дерево добычи
// разворачивается, переход по #item= с вкладки предметов приводит куда надо.
//
// Адрес и токен - из окружения или из корневого .env (ADMIN_PANEL_BIND,
// ADMIN_PANEL_TOKEN). В файл их не вписывать: .env не в репозитории.
const fs = require('fs');
const path = require('path');
const { JSDOM, VirtualConsole } = require('jsdom');

const ROOT = path.resolve(__dirname, '..', '..', '..');

function env(name, fallback) {
  if (process.env[name]) return process.env[name];
  const file = path.join(ROOT, '.env');
  if (fs.existsSync(file)) {
    for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
      if (line.trim().startsWith(name + '=')) return line.split('=')[1].trim();
    }
  }
  return fallback;
}

const BASE = env('ADMIN_PANEL_URL',
                 'http://' + env('ADMIN_PANEL_BIND', '127.0.0.1') + ':8091');
const TOKEN = env('ADMIN_PANEL_TOKEN', '');

if (!TOKEN) {
  console.log('Нет токена: задайте ADMIN_PANEL_TOKEN в окружении или в .env');
  process.exit(2);
}

const errors = [];
const failures = [];

function check(name, ok, detail) {
  console.log((ok ? 'ok   ' : 'FAIL ') + name + (detail ? ': ' + detail : ''));
  if (!ok) failures.push(name);
}

async function open(hash) {
  const html = await (await fetch(BASE + '/loot.html', {
    headers: { 'X-Admin-Token': TOKEN },
  })).text();

  const vc = new VirtualConsole();
  vc.on('jsdomError', e => errors.push(String(e.message || e)));
  vc.on('error', (...a) => errors.push(a.join(' ')));

  const dom = new JSDOM(html, {
    url: BASE + '/loot.html' + (hash || ''),
    runScripts: 'dangerously',
    virtualConsole: vc,
  });
  const win = dom.window;
  win.localStorage.setItem('adminToken', TOKEN);
  win.fetch = (url, opts) => {
    const full = String(url).startsWith('http') ? String(url) : BASE + url;
    const headers = Object.assign({}, (opts && opts.headers) || {},
                                  { 'X-Admin-Token': TOKEN });
    return fetch(full, Object.assign({}, opts, { headers }));
  };
  for (const tag of [...win.document.querySelectorAll('script[src]')]) {
    const code = await (await fetch(BASE + tag.getAttribute('src'), {
      headers: { 'X-Admin-Token': TOKEN },
    })).text();
    const el = win.document.createElement('script');
    el.textContent = code;
    win.document.body.appendChild(el);
  }
  const tabs = () => [...win.document.querySelectorAll('#tabs button')]
    .filter(b => !b.classList.contains('apply'));
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline && tabs().length < 3) {
    await new Promise(r => setTimeout(r, 200));
  }
  return { win, tabs };
}

(async () => {
  // 1. Обычное открытие: вкладка «Моб».
  let { win, tabs } = await open('');
  check('страница поднялась', tabs().length === 3, 'кнопок ' + tabs().length);

  const view = () => win.document.getElementById('view');
  check('вкладка «Моб» нарисована',
        view().textContent.includes('Выберите существо'),
        view().textContent.slice(0, 60));

  // Поиск существа и выбор первой строки: дерево добычи должно появиться.
  const q = win.document.querySelector('.searchbar input[type=search]');
  q.value = '16507';
  q.dispatchEvent(new win.Event('input'));
  await new Promise(r => setTimeout(r, 1500));
  const rows = [...win.document.querySelectorAll('.rows .listrow')];
  check('поиск существа нашёл строки', rows.length > 0, rows.length);
  if (rows.length) {
    rows[0].click();
    await new Promise(r => setTimeout(r, 4000));
    const text = view().textContent;
    check('дерево добычи показано', text.includes('Группа')
          || win.document.querySelectorAll('.lootrow').length > 0,
          win.document.querySelectorAll('.lootrow').length + ' строк');
    check('про mod-worn-drops сказано честно',
          text.includes('mod-worn-drops'));
  }

  // 2. Переход с вкладки предметов: #item=<entry>.
  ({ win, tabs } = await open('#item=40431'));
  await new Promise(r => setTimeout(r, 3000));
  const text = win.document.getElementById('view').textContent;
  check('переход по #item открывает вкладку «Предмет»',
        [...win.document.querySelectorAll('#tabs button')]
          .find(b => b.classList.contains('active')).textContent === 'Предмет');
  // Отбор путей: у ходового предмета их сотни, и без полосы список не читается.
  check('на путях есть полоса отбора',
        !!win.document.querySelector('.filter-bar'),
        win.document.querySelectorAll('.filter-bar select').length + ' отборов');
  check('заголовки путей сортируемые',
        win.document.querySelectorAll('th.sortable').length > 0,
        win.document.querySelectorAll('th.sortable').length);
  check('пути показаны', win.document.querySelectorAll('table.grid tr').length > 1,
        win.document.querySelectorAll('table.grid tr').length + ' строк');
  check('в цепочке видно, через что падает', text.includes('Ссылки')
        || text.includes('→'), text.slice(0, 120));

  // 3. Вкладка «Таблица»: сырой доступ.
  ({ win, tabs } = await open(''));
  tabs().find(b => b.textContent === 'Таблица').click();
  await new Promise(r => setTimeout(r, 2000));
  const pick = win.document.querySelector('.searchbar select');
  check('выбор таблицы есть', !!pick && pick.options.length === 13,
        pick ? pick.options.length : 'нет');
  const list = [...win.document.querySelectorAll('.rows .listrow')];
  check('записи таблицы перечислены', list.length > 0, list.length);
  check('в списке видны имена, а не только номера',
        list.length > 0 && /[А-Яа-я]/.test(list[0].textContent),
        list[0] && list[0].textContent.slice(0, 50));
  if (list.length) {
    list[0].click();
    await new Promise(r => setTimeout(r, 4000));
    check('запись раскрыта',
          win.document.querySelectorAll('.lootrow').length > 0,
          win.document.querySelectorAll('.lootrow').length);
    // Подписи: у записи имя (своё или посчитанное), у группы - кнопка «назвать».
    const tags = win.document.querySelectorAll('.nametag');
    check('подписи записи и групп на месте', tags.length > 1, tags.length);
    check('редактору предложено назвать',
          win.document.querySelectorAll('.nametag .linkbtn').length > 0,
          win.document.querySelectorAll('.nametag .linkbtn').length);

    // Правка строк: у строки инструменты, у записи - «+ строка», у группы -
    // перенос. Форма должна разворачиваться прямо под строкой.
    check('у строк есть правка и удаление',
          win.document.querySelectorAll('.rowtools').length > 0,
          win.document.querySelectorAll('.rowtools').length);
    const addBtn = win.document.querySelector('.addrow button');
    check('есть кнопка добавления строки', !!addBtn,
          addBtn && addBtn.textContent);
    if (addBtn) {
      addBtn.click();
      await new Promise(r => setTimeout(r, 300));
      check('форма строки раскрылась',
            !!win.document.querySelector('.roweditor'));
      const editor = win.document.querySelector('.roweditor');
      check('в форме есть выбор предмета и числа',
            editor && editor.querySelectorAll('input[type=number]').length >= 5,
            editor ? editor.querySelectorAll('input[type=number]').length : 0);
    }
    check('отбор записей на месте',
          !!win.document.querySelector('.col-list .filter-bar'));

    // Сборка группы: у строк галочки, внизу полоса, и по отметке появляются
    // кнопки. Без этого «сделать группу» приходилось бы вписывать номером.
    const ticks = [...win.document.querySelectorAll('.pickrow')];
    check('у строк есть галочки выбора', ticks.length > 0, ticks.length);
    check('полоса сборки на месте',
          !!win.document.querySelector('.pickbar'),
          (win.document.querySelector('.pickbar') || {}).textContent);
    // Полоса сборки у КАЖДОГО узла своя: раскрытая ссылка - отдельная запись,
    // и собирать её строки в группу соседней записи нельзя. Поэтому жать
    // галочку и читать полосу надо в одном узле, а не первые попавшиеся.
    const bar = win.document.querySelector('.pickbar');
    const own = bar
      ? [...bar.parentNode.querySelectorAll(':scope > .lootrow > .pickrow')]
      : [];
    check('галочки и полоса нашлись в одном узле', own.length > 0, own.length);
    if (own.length) {
      own[0].click();
      await new Promise(r => setTimeout(r, 200));
      check('по отметке предложено собрать в группу',
            /В новую группу/.test(bar.textContent),
            bar.textContent.slice(0, 80));
    }
    check('у группы есть «+ строка сюда»',
          [...win.document.querySelectorAll('.group-head .linkbtn')]
            .some(b => b.textContent.includes('строка сюда')));
    check('кнопка «Применить на сервере» есть',
          !!win.document.querySelector('#tabs button.apply'));
  }

  // Стили модалки: скрипт выбора предмета скопировали со страницы профессий, а
  // CSS сперва забыли - окно приезжало голым. jsdom стилей не считает, поэтому
  // проверяем прямо: каждый класс, который рисует скрипт, где-то объявлен.
  const css = [
    ...[...win.document.querySelectorAll('style')].map(n => n.textContent),
    await (await fetch(BASE + '/static/style.css',
                       { headers: { 'X-Admin-Token': TOKEN } })).text(),
  ].join('\n');
  for (const cls of ['ap-modal-back', 'ap-modal', 'look-grid', 'look-cell',
                     'look-icon', 'roweditor', 'listrow', 'filter-bar']) {
    check(`класс .${cls} описан в стилях`, css.includes('.' + cls));
  }
  // И наоборот: строка списка не должна прятаться под общим именем `.row` -
  // иначе общий код (модалка, форма строки) приезжает строкой списка.
  const listRows = [...win.document.querySelectorAll('.rows .listrow')];
  check('строка списка не занимает общее имя .row',
        listRows.length > 0 && !listRows.some(n => n.classList.contains('row')),
        listRows.length ? listRows[0].className : 'строк нет');

  const real = errors.filter(e => !/Not implemented|Could not load img|canvas/i.test(e));
  check('ошибок на странице нет', real.length === 0, real.slice(0, 3).join(' | '));

  console.log();
  if (failures.length) {
    console.log('ПРОВАЛОВ: ' + failures.length);
    process.exit(1);
  }
  console.log('всё зелено');
  process.exit(0);
})();
