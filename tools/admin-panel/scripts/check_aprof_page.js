// Прогон страницы /aprof.html в jsdom против ЖИВОЙ панели PTR.
//
//   npm install jsdom      (разово, где угодно - модуль ищется по NODE_PATH)
//   node tools/admin-panel/scripts/check_aprof_page.js
//
// Страница берёт данные с PTR, поэтому проверяется не выдумка, а то, что
// владелец увидит в браузере: все вкладки рисуются без ошибок, а в полосах
// добавления «Рецептов» и «Именных» есть выбор обучающего предмета и он
// открывает поиск по каталогу.
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

const errors = [];
const failures = [];

function check(name, ok, detail) {
  console.log((ok ? 'ok   ' : 'FAIL ') + name + (detail ? ': ' + detail : ''));
  if (!ok) failures.push(name);
}

if (!TOKEN) {
  console.log('Нет токена: задайте ADMIN_PANEL_TOKEN в окружении или в .env');
  process.exit(2);
}

(async () => {
  const html = await (await fetch(BASE + '/aprof.html', {
    headers: { 'X-Admin-Token': TOKEN },
  })).text();

  const vc = new VirtualConsole();
  vc.on('jsdomError', e => errors.push(String(e.message || e)));
  vc.on('error', (...a) => errors.push(a.join(' ')));

  const dom = new JSDOM(html, {
    url: BASE + '/aprof.html',
    runScripts: 'dangerously',
    resources: undefined,
    virtualConsole: vc,
    // Без этого в окне нет requestAnimationFrame, а страница на него
    // опирается: прокрутка к строке после перехода и первая отрисовка
    // диаграммы (ей до вставки в страницу неоткуда взять ширину).
    pretendToBeVisual: true,
  });
  const win = dom.window;

  // Токен страница берёт из localStorage, а картинки в jsdom не грузятся.
  win.localStorage.setItem('adminToken', TOKEN);
  win.fetch = (url, opts) => {
    const full = String(url).startsWith('http') ? String(url) : BASE + url;
    const headers = Object.assign({}, (opts && opts.headers) || {},
                                  { 'X-Admin-Token': TOKEN });
    return fetch(full, Object.assign({}, opts, { headers }));
  };

  // Скрипты страницы (app.js, aprof.js) грузятся тегами, а jsdom без
  // resources их не тянет - подставляем сами, в том же порядке.
  for (const tag of [...win.document.querySelectorAll('script[src]')]) {
    const src = tag.getAttribute('src');
    const code = await (await fetch(BASE + src, {
      headers: { 'X-Admin-Token': TOKEN },
    })).text();
    const el = win.document.createElement('script');
    el.textContent = code;
    win.document.body.appendChild(el);
  }

  // Ждём, пока boot() догрузит справочники и нарисует вкладку. Заглянуть в
  // переменные скрипта нельзя - `let` верхнего уровня не лежит на window,
  // - поэтому смотрим на то же, что видит владелец: на DOM.
  const tabButtons = () => [...win.document.querySelectorAll('#tabs button')];
  const deadline = Date.now() + 20000;
  while (Date.now() < deadline) {
    if (tabButtons().length > 1) break;
    await new Promise(r => setTimeout(r, 200));
  }

  check('страница поднялась', tabButtons().length > 1,
        'кнопок вкладок ' + tabButtons().length);

  const labels = () => [...win.document.querySelectorAll('.add-bar .add-field > span')]
    .map(s => s.textContent);

  // Вкладку переключаем кнопкой, а не переменной: TAB живёт в области видимости
  // скрипта, снаружи его не видно.
  const TAB_LABELS = {
    types: 'Типы предметов', materials: 'Материалы', recipes: 'Рецепты',
    named: 'Именные', merge: 'Объединение', dicts: 'Справочники',
    balance: 'Баланс', preview: 'Проверка', pool: 'Пул id', map: 'Связи',
  };
  // «Баланс», «Объединение» и «Пул id» рисуются после запроса к панели, и
  // сколько тот идёт - зависит от того, сколько накопилось данных. Поэтому
  // ждём не время, а результат: пустой #view значит «ещё рисует».
  async function openTab(tab) {
    const btn = tabButtons().find(b => b.textContent === TAB_LABELS[tab]);
    if (!btn) throw new Error('нет кнопки вкладки ' + tab);
    btn.click();
    const until = Date.now() + 15000;
    do {
      await new Promise(r => setTimeout(r, 200));
    } while (!win.document.querySelector('#view').children.length
             && Date.now() < until);
  }

  await openTab('recipes');
  check('рецепты загружены',
        win.document.querySelectorAll('table.grid tbody tr, table.grid tr').length > 1,
        'строк ' + win.document.querySelectorAll('table.grid tr').length);

  // Страницы. Справочники выросли - материалов под тысячу, эскизов под девять
  // сотен, - и без страниц вкладка «Именные» строила четыреста тысяч узлов и
  // вешала браузер секунд на пятнадцать. Скорость jsdom честно не измерит,
  // поэтому проверяем то, от чего она зависит: что лист режется, листалка
  // листает, а список основ в строке не наполняется, пока в него не заглянули.
  await openTab('named');
  const rows = () => [...win.document.querySelectorAll('tr[data-syn-id]')];
  const count = () =>
    (win.document.querySelector('.filter-count') || {}).textContent || '';

  check('«Именные»: лист порезан на страницы', rows().length <= 100,
        'строк ' + rows().length);
  check('«Именные»: счёт говорит о странице',
        /строки 1-\d+ из \d+/.test(count()), count());

  const next = [...win.document.querySelectorAll('.list-pager button')]
    .find(b => b.textContent === '›');
  check('«Именные»: листалка есть', !!next);
  if (next) {
    const first = rows()[0] && rows()[0].dataset.synId;
    next.click();
    await new Promise(r => setTimeout(r, 500));
    check('«Именные»: «вперёд» перелистывает',
          !!rows()[0] && rows()[0].dataset.synId !== first, count());
  }

  const lazy = win.document.querySelector('tr[data-syn-id] select.lazy');
  check('«Именные»: список основ ленивый', !!lazy && lazy.options.length === 1,
        lazy ? 'опций ' + lazy.options.length : 'нет такого списка');
  if (lazy) {
    const before = lazy.value;
    lazy.dispatchEvent(new win.MouseEvent('mousedown', { bubbles: true }));
    check('«Именные»: список наполняется по касанию', lazy.options.length > 1,
          'опций ' + lazy.options.length);
    check('«Именные»: выбранное после наполнения не съехало',
          lazy.value === before, before + ' -> ' + lazy.value);
  }

  for (const [tab, want] of [['recipes', 'обучение'], ['named', 'обучение']]) {
    await openTab(tab);
    const found = labels();
    check(`вкладка «${tab}»: полоса добавления есть`, found.length > 0,
          found.join(', '));
    check(`вкладка «${tab}»: в полосе есть «${want}»`, found.includes(want),
          found.join(', '));

    // Кнопка выбора должна открывать модалку поиска предметов.
    const field = [...win.document.querySelectorAll('.add-bar .add-field')]
      .find(f => f.querySelector('span') && f.querySelector('span').textContent === want);
    const btn = field && field.querySelector('button');
    check(`вкладка «${tab}»: у «${want}» есть кнопка`, !!btn,
          btn ? btn.textContent : 'нет');
    if (btn) {
      btn.click();
      await new Promise(r => setTimeout(r, 400));
      const modal = win.document.querySelector('.ap-modal-back');
      check(`вкладка «${tab}»: выбор предмета открывается`, !!modal);
      if (modal) modal.remove();
    }
  }

  // Вкладка «Связи»: три вида, и третий из них - диаграмма на canvas. В jsdom
  // холст не рисует, поэтому проверяется не картинка, а всё остальное:
  // переключатель, раскладка, отбор и кнопки масштаба. Раскладку зовём прямо -
  // она чистая функция и от холста не зависит.
  await openTab('map');
  const modes = [...win.document.querySelectorAll('.map-modes .chip')]
    .map(b => b.textContent);
  check('«Связи»: в переключателе три вида', modes.length === 3,
        modes.join(', '));

  const graphChip = [...win.document.querySelectorAll('.map-modes .chip')]
    .find(b => b.textContent === 'Диаграмма');
  check('«Связи»: вид «Диаграмма» есть', !!graphChip);
  if (graphChip) {
    graphChip.click();
    await new Promise(r => setTimeout(r, 400));
    check('диаграмма: холст на странице',
          !!win.document.querySelector('canvas.graph-canvas'));
    check('диаграмма: панель управления на месте',
          !!win.document.querySelector('.graph-bar'));
    const buttons = [...win.document.querySelectorAll('.graph-bar .btn')]
      .map(b => b.textContent);
    check('диаграмма: кнопки масштаба на месте',
          buttons.includes('+') && buttons.includes('Вместить'),
          buttons.join(' '));

    const all = win.graphLayout('all');
    const forge = win.graphLayout('forge');
    check('диаграмма: раскладка даёт узлы и связи',
          all.nodes.length > 0 && all.edges.length > 0,
          'узлов ' + all.nodes.length + ', связей ' + all.edges.length);
    check('диаграмма: в раскладке есть все три рода узлов',
          ['type', 'base', 'syn'].every(
            k => all.nodes.some(n => n.kind === k)));
    check('диаграмма: отбор «ковка» уже полного',
          forge.nodes.length < all.nodes.length,
          forge.nodes.length + ' против ' + all.nodes.length);

    // Фильтры: один тип и одно качество обязаны сужать картину, а не менять
    // её молча на ту же самую.
    const firstType = all.nodes.find(n => n.kind === 'type');
    const oneType = win.graphLayout({ show: 'all', types: [firstType.id],
                                      quals: [] });
    check('диаграмма: отбор по типу сужает',
          oneType.nodes.length > 0 && oneType.nodes.length < all.nodes.length,
          oneType.nodes.length + ' против ' + all.nodes.length);
    check('диаграмма: в отборе по типу остался один тип',
          oneType.nodes.filter(n => n.kind === 'type').length === 1);

    const epic = win.graphLayout({ show: 'all', types: [], quals: [4] });
    check('диаграмма: отбор по качеству сужает',
          epic.nodes.length > 0 && epic.nodes.length < all.nodes.length,
          epic.nodes.length + ' против ' + all.nodes.length);

    // Ряды отбора: типы, качество, полоса и поиск. Считать их числом нельзя -
    // ряд полос не рисуется вовсе на базе без ap_band, - поэтому проверяем
    // поимённо и по названию, а не по количеству.
    const rows = [...win.document.querySelectorAll('.graph-filters')];
    const titles = rows.map(r => r.querySelector('span').textContent);
    check('диаграмма: есть отбор по типам', titles.includes('Типы:'),
          titles.join(' '));
    check('диаграмма: есть отбор по качеству', titles.includes('Качество:'),
          titles.join(' '));
    check('диаграмма: есть строка поиска',
          !!win.document.querySelector('.graph-find'), titles.join(' '));
    check('диаграмма: есть чип замечаний',
          [...win.document.querySelectorAll('.graph-bar .chip')]
            .some(b => /замечани/.test(b.textContent)));

    // Отбор по полосе: сузить должен так же, как тип и качество. Полос может
    // не быть (база без v32) - тогда проверку пропускаем, а не валим.
    // META объявлена через `let`, в window её нет - настоящего номера полосы
    // отсюда не достать. Поэтому проверяем две вещи, которым он не нужен:
    // чипы нарисованы, и отбор ДЕЙСТВУЕТ (заведомо чужая полоса даёт пусто).
    const bandRow = rows.find(r => r.querySelector('span').textContent === 'Полоса:');
    if (bandRow) {
      const chips = [...bandRow.querySelectorAll('.chip')];
      check('диаграмма: у полос есть чипы', chips.length > 1,
            'чипов ' + chips.length
            + (chips[1] ? ', первый ' + chips[1].textContent : ''));
      const nobody = win.graphLayout({ show: 'all', bands: [999999] });
      check('диаграмма: отбор по полосе действует',
            nobody.nodes.length === 0, 'узлов ' + nobody.nodes.length);
    }

    // Поиск: строка, которой заведомо нет, обязана оставить пусто - иначе
    // отбор не применяется вовсе, а это молчаливая поломка.
    const nothing = win.graphLayout({ show: 'all', find: 'zzzнеттакого' });
    check('диаграмма: поиск отсекает', nothing.nodes.length === 0,
          'узлов ' + nothing.nodes.length);
    const onlyBad = win.graphLayout({ show: 'all', bad: true });
    check('диаграмма: отбор замечаний не шире полного',
          onlyBad.nodes.length <= all.nodes.length,
          onlyBad.nodes.length + ' против ' + all.nodes.length);

    // Раскрытие узла: щелчок по холсту в том месте, где по раскладке стоит
    // основа. Коробка растёт НА ПОЛОТНЕ, поэтому проверяется не разметка, а
    // раскладка и её содержимое: высота узла, строки и то, что крестик
    // закрывает.
    const canvas = win.document.querySelector('canvas.graph-canvas');
    check('диаграмма: холст на месте для щелчка', !!canvas);
    if (canvas) {
      // jsdom не считает раскладку, поэтому размеры холсту подсказываем сами.
      canvas.getBoundingClientRect = () => ({ left: 0, top: 0,
                                              width: 900, height: 620 });
      const state = win.graphState();
      const target = all.nodes.find(n => n.kind === 'base');
      const point = {
        clientX: (target.x + 10) * state.scale + state.x,
        clientY: (target.y + 6) * state.scale + state.y,
      };
      canvas.dispatchEvent(new win.MouseEvent('mousedown', point));
      win.dispatchEvent(new win.MouseEvent('mouseup', point));
      // Характеристики приезжают отдельным запросом на предмет, поэтому ждём
      // не кадр, а ответ: иначе проверка ловила бы «читаю…».
      await new Promise(r => setTimeout(r, 1500));

      const open = win.graphState();
      check('раскрытие: узел отмечен раскрытым',
            !!open.open && open.open.kind === 'base',
            JSON.stringify(open.open));
      const text = (open.openLines || []).map(l => l.text).join(' | ');
      check('раскрытие: показаны материалы ковки',
            /Для ковки|выбивают/.test(text), text.slice(0, 90));
      check('раскрытие: характеристики предмета прочитаны',
            /Урон|Броня|Прочность|характеристик нет/.test(text)
            && !/читаю/.test(text),
            (text.match(/Урон[^|]*/) || [''])[0].slice(0, 60));

      const grown = win.graphLayout(open);
      const node = grown.nodes.find(
        n => n.kind === 'base' && n.id === open.open.id);
      check('раскрытие: коробка выросла на полотне',
            !!node && node.h > 40, node ? 'высота ' + node.h : 'узла нет');
      check('раскрытие: соседи разъехались',
            grown.height > all.height,
            Math.round(grown.height) + ' против ' + Math.round(all.height));

      // Крестик в углу раскрытой коробки закрывает её.
      const close = {
        clientX: (node.x + node.w - 12) * state.scale + state.x,
        clientY: (node.y + 6) * state.scale + state.y,
      };
      canvas.dispatchEvent(new win.MouseEvent('mousedown', close));
      win.dispatchEvent(new win.MouseEvent('mouseup', close));
      await new Promise(r => setTimeout(r, 200));
      check('раскрытие: крестик закрывает', !win.graphState().open);

      // Эскиз раскрывается тем же щелчком, но показывает другое: набор камней
      // в порядке укладки и приз.
      const syn = all.nodes.find(n => n.kind === 'syn');
      const at = {
        clientX: (syn.x + 10) * state.scale + state.x,
        clientY: (syn.y + 6) * state.scale + state.y,
      };
      canvas.dispatchEvent(new win.MouseEvent('mousedown', at));
      win.dispatchEvent(new win.MouseEvent('mouseup', at));
      await new Promise(r => setTimeout(r, 1500));
      const synState = win.graphState();
      const synText = (synState.openLines || []).map(l => l.text).join(' | ');
      check('раскрытие эскиза: набор камней показан',
            synState.open && synState.open.kind === 'syn'
            && /Для инкрустации/.test(synText), synText.slice(0, 90));
      check('раскрытие эскиза: приз показан',
            /Выходит/.test(synText),
            (synText.match(/Выходит[^|]*/) || [''])[0].slice(0, 60));
    }

    check('диаграмма: у каждой связи есть оба конца',
          all.edges.every(e => [e.x1, e.y1, e.x2, e.y2]
            .every(v => Number.isFinite(v))));
    check('диаграмма: высота посчитана',
          all.height > 0 && all.width > 0,
          all.width + 'x' + Math.round(all.height));

    // Рисование: jsdom холст не поддерживает, поэтому подсовываем поддельный
    // и считаем вызовы. Проверяем две вещи разом - что код отрисовки вообще
    // проходит и что он ОТСЕКАЕТ невидимое: при высоте в шестьдесят тысяч
    // точек рисовать все три тысячи узлов на каждый кадр нельзя.
    const calls = { rect: 0, text: 0, stroke: 0 };
    const ctx = {
      setTransform() {}, clearRect() {}, save() {}, restore() {},
      translate() {}, scale() {}, beginPath() {}, moveTo() {},
      bezierCurveTo() {}, fill() {},
      stroke() { calls.stroke++; },
      rect() { calls.rect++; },
      fillText() { calls.text++; },
      measureText(t) { return { width: String(t).length * 6 }; },
    };
    const fake = {
      clientWidth: 900, clientHeight: 620, width: 0, height: 0,
      getContext: () => ctx,
    };
    win.graphDraw(fake, all, { scale: 1, x: 0, y: 0, hover: null });
    check('диаграмма: отрисовка проходит и рисует узлы',
          calls.rect > 0 && calls.text > 0,
          'узлов ' + calls.rect + ', подписей ' + calls.text);
    check('диаграмма: невидимое отсекается',
          calls.rect < all.nodes.length,
          calls.rect + ' из ' + all.nodes.length);

    const far = { rect: 0, text: 0, stroke: 0 };
    Object.assign(ctx, {
      rect() { far.rect++; }, fillText() { far.text++; },
      stroke() { far.stroke++; },
    });
    win.graphDraw(fake, all, { scale: 0.05, x: 0, y: 0, hover: null });
    check('диаграмма: на обзорном масштабе подписей нет',
          far.rect > 0 && far.text === 0,
          'узлов ' + far.rect + ', подписей ' + far.text);
  }

  // Прочие вкладки - просто чтобы правка ничего не уронила рядом.
  for (const tab of ['types', 'materials', 'dicts', 'merge', 'balance',
                     'preview', 'pool']) {
    await openTab(tab);
    check(`вкладка «${tab}» отрисована`,
          win.document.querySelector('#view').children.length > 0);
  }

  // Стили модалки переехали из этой страницы в общий style.css (их попросила
  // страница добычи). Проверяем, что они по-прежнему видны отсюда: иначе окно
  // выбора приедет голым, а jsdom про CSS ничего не скажет.
  const css = [
    ...[...win.document.querySelectorAll('style')].map(n => n.textContent),
    await (await fetch(BASE + '/static/style.css',
                       { headers: { 'X-Admin-Token': TOKEN } })).text(),
  ].join(String.fromCharCode(10));
  for (const cls of ['ap-modal-back', 'ap-modal', 'look-grid', 'look-cell',
                     'look-icon', 'gem-socket', 'list-pager', 'filter-tail',
                     'graph-bar', 'graph-wrap', 'graph-canvas', 'graph-tip',
                     'graph-filters']) {
    check(`класс .${cls} описан в стилях`, css.includes('.' + cls));
  }

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
