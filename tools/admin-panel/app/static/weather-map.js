'use strict';

// Карта погоды. Тот же список зон, что и слева, но разложенный по континенту:
// «где сейчас идёт снег» глазами читается мгновенно, а списком — нет.
//
// Геометрия и подложка не в репозитории: их собирает scripts/build-map-assets.ps1
// из клиента и из серверных .map (см. gen_zone_geometry.py). Если файлов нет,
// страница не ломается — карта просто говорит, чем её собрать.
//
// Контуры зон приходят в системе координат area-сетки (1104x736 ячеек для
// Калимдора), подложка нарисована ровно на том же прямоугольнике мира, поэтому
// SVG и картинка живут в одном viewBox и масштабируются вместе.

const WeatherMap = (() => {
  // Ключи те же, что у weather.CONTINENTS на сервере: по ним же приходят зоны.
  // Запределья и Нордскола тут пока нет - для них не собраны файлы карты.
  const SRC = {
    ek: {
      art: '/static/maps/ek.jpg',
      geometry: '/static/maps/ek.zones.json',
      name: 'Восточные королевства',
    },
    kalimdor: {
      art: '/static/maps/kalimdor.jpg',
      geometry: '/static/maps/kalimdor.zones.json',
      name: 'Калимдор',
    },
  };

  // Пересчёт мировых координат в клетки карты. Ровно та же арифметика, что в
  // scripts/gen_zone_geometry.py (cell_of / crop_to_map): грид 533.33 ярда на
  // 16 клеток, X растёт на север (это строка), Y на запад (это столбец).
  // Прямоугольник континента лежит в самой геометрии, поле "rect".
  const SIZE_OF_GRIDS = 533.3333;
  const CELLS_PER_GRID = 16;
  const YARDS_PER_CELL = SIZE_OF_GRIDS / CELLS_PER_GRID;

  function cellOf(coord) {
    return CELLS_PER_GRID * (32 - coord / SIZE_OF_GRIDS);
  }

  // Цвет группы состояний. Насыщенность даёт сила погоды, поэтому базовый
  // цвет здесь один на группу — иначе карта превращается в радугу.
  // Ниже этого размера зона подписывается точкой, а не именем.
  const LABEL_MIN_CELLS = 1500;

  const GROUP_COLOR = {
    clear: '#d8c48a',
    rain: '#4aa3ff',
    snow: '#cfe9ff',
    storm: '#d59a4a',
    special: '#c77dff',
  };

  const view = {
    key: localStorage.getItem('weatherMapContinent') || 'ek',
    geometry: null,      // { width, height, zones: [...] } активного континента
    // Разобранная геометрия по континентам: переключение туда-сюда не должно
    // каждый раз ходить в сеть.
    cache: new Map(),
    byZone: new Map(),   // zone_id -> элемент <path>
    glows: new Map(),    // zone_id -> два <stop> его градиента
    labels: new Map(),   // zone_id -> элемент <text>
    svg: null,
    tip: null,
    error: null,
    // Данные страницы: карта их не грузит сама, ей их отдаёт weather.js.
    zones: null,
    selected: null,
    // Подписи зон можно убрать: на плотных участках (Кель'Талас, дренейские
    // острова) они закрывают ровно то, что человек пришёл разглядывать.
    showLabels: localStorage.getItem('weatherMapLabels') !== '0',
    labelsGroup: null,
    // Фронты, идущие сейчас по этому континенту. Рисуются под зонами:
    // свечение зоны должно читаться поверх круга, иначе непонятно, какая
    // погода в зоне СТОИТ.
    cyclones: [],
    cyclonesGroup: null,
    // Что было выбрано на прошлой перерисовке: по смене этого значения (и
    // только по ней) карта сама листается на нужный континент.
    lastSelected: null,
  };

  function host() {
    return document.getElementById('weather-map');
  }

  // SVG-узлы создаются только через namespace, а их здесь десятки — полное
  // имя занимало больше места, чем сама фигура.
  function el2(tag) {
    return document.createElementNS('http://www.w3.org/2000/svg', tag);
  }

  // --- построение -----------------------------------------------------------

  async function load() {
    if (view.cache.has(view.key)) {
      view.geometry = view.cache.get(view.key);
      view.error = view.geometry ? null : 'нет файлов карты';
      return;
    }
    const src = SRC[view.key];
    try {
      const res = await fetch(src.geometry);
      if (!res.ok) throw new Error(String(res.status));
      view.geometry = await res.json();
      view.error = null;
    } catch (_) {
      view.geometry = null;
      view.error = 'нет файлов карты';
    }
    view.cache.set(view.key, view.geometry);
  }

  // Переключение континента. Страница узнаёт об этом событием: контейнеры на
  // карте (состояние зоны, кнопки погоды) наполняет weather.js, и после
  // пересборки их надо нарисовать заново.
  async function setContinent(key) {
    if (!SRC[key] || key === view.key) return;
    view.key = key;
    localStorage.setItem('weatherMapContinent', key);
    await load();
    build();
    render();
    document.dispatchEvent(new CustomEvent('wmap:rebuilt'));
  }

  function build() {
    const box = host();
    box.innerHTML = '';
    const src = SRC[view.key];

    const head = el('div', 'wmap-head');
    Object.keys(SRC).forEach(key => {
      const tab = el('button', 'wmap-tab' + (key === view.key ? ' active' : ''),
        SRC[key].name);
      tab.addEventListener('click', () => setContinent(key));
      head.appendChild(tab);
    });
    box.appendChild(head);

    if (view.error) {
      const hint = el('div', 'hint');
      hint.textContent = 'Карта не собрана. Соберите её один раз: '
        + 'tools/admin-panel/scripts/build-map-assets.ps1 — подложка берётся из '
        + 'клиента, контуры зон из серверных .map. В репозиторий эти файлы не '
        + 'кладутся.';
      box.appendChild(hint);
      // Кнопки всё равно нужны: без собранной карты режиссёра иначе нечем
      // переключить. Ряд тот же, просто не поверх картинки, а под подсказкой.
      const inline = el('div', 'wmap-tools-inline');
      inline.appendChild(tools());
      box.appendChild(inline);
      return;
    }
    if (!view.geometry) return;

    const g = view.geometry;
    const wrap = el('div', 'wmap-canvas');
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', `0 0 ${g.width} ${g.height}`);
    svg.classList.add('wmap-svg');

    const image = document.createElementNS('http://www.w3.org/2000/svg', 'image');
    image.setAttribute('href', src.art);
    image.setAttribute('x', '0');
    image.setAttribute('y', '0');
    image.setAttribute('width', String(g.width));
    image.setAttribute('height', String(g.height));
    svg.appendChild(image);

    view.byZone.clear();
    view.glows.clear();
    view.labels.clear();

    // Каждая зона светится из своего центра, поэтому у каждой свой градиент:
    // общий на всех не поставить, координаты центра зашиты в него самого.
    const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
    svg.appendChild(defs);

    // Фронты идут сразу за подложкой, до зон: круг — это «где сейчас
    // непогода», а цвет зоны — «что в ней стоит», и второе должно быть сверху.
    const fronts = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    fronts.classList.add('wmap-cyclones');
    svg.appendChild(fronts);
    view.cyclonesGroup = fronts;

    const shapes = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    const texts = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    texts.classList.add('wmap-labels');
    if (!view.showLabels) texts.classList.add('hidden');
    view.labelsGroup = texts;

    g.zones.forEach(z => {
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', z.path);
      path.setAttribute('fill-rule', 'evenodd');
      path.classList.add('wmap-zone');
      path.setAttribute('fill', `url(#wglow-${z.id})`);
      defs.appendChild(glow(z));
      path.addEventListener('click', () => {
        if (view.byZone.get(z.id).classList.contains('inert')) return;
        if (typeof select === 'function') select(z.id);
      });
      path.addEventListener('mousemove', ev => showTip(ev, z.id));
      path.addEventListener('mouseleave', hideTip);
      shapes.appendChild(path);
      view.byZone.set(z.id, path);

      // Подпись получают только зоны, в которых она помещается. Города
      // (Оргриммар, Дарнас) занимают пару сотен ячеек: их имя перекрыло бы
      // соседей, поэтому им достаётся точка, а имя — во всплывающей подсказке.
      const small = z.cells < LABEL_MIN_CELLS;
      const mark = document.createElementNS(
        'http://www.w3.org/2000/svg', small ? 'circle' : 'text');
      if (small) {
        mark.setAttribute('cx', String(z.label[0]));
        mark.setAttribute('cy', String(z.label[1]));
        mark.setAttribute('r', '4.5');
        mark.classList.add('wmap-pin');
      } else {
        mark.setAttribute('x', String(z.label[0]));
        mark.setAttribute('y', String(z.label[1]));
        mark.setAttribute('text-anchor', 'middle');
        mark.setAttribute('font-size', z.cells > 9000 ? '14' : '11.5');
        mark.textContent = z.name;
      }
      texts.appendChild(mark);
      view.labels.set(z.id, mark);
    });

    svg.appendChild(shapes);
    svg.appendChild(texts);
    wrap.appendChild(svg);

    wrap.appendChild(tools());

    // Что стоит в выбранной зоне - здесь же, над картой: смотреть на зону и
    // читать про неё в другой колонке неудобно. Наполняет weather.js.
    wrap.appendChild(el('div', 'wmap-zoneinfo', ''));

    // Плашка в углу с открытым морем: она же обозначения, она же сводка.
    // Цветная точка объясняет карту, число рядом говорит, сколько зон сейчас
    // под этой погодой - двум спискам про одно и то же места нет.
    const legendBox = el('div', 'wmap-legend-box');
    legendBox.appendChild(el('div', 'wmap-legend-title', 'Сейчас на континенте'));
    legendBox.appendChild(el('div', 'wmap-legend', ''));
    wrap.appendChild(legendBox);

    // Быстрые кнопки погоды. Наполняет их weather.js: там и список состояний,
    // и та же ручка, что жмёт «Применить» в редакторе.
    wrap.appendChild(el('div', 'wmap-states', ''));

    view.tip = el('div', 'wmap-tip');
    wrap.appendChild(view.tip);
    box.appendChild(wrap);
    view.svg = svg;
  }

  // Радиус свечения считаем по габаритам самой зоны: у Степей и у Дарнаса
  // одинаковое пятно смотрелось бы одинаково глупо - у первого как точка, у
  // второго как клякса на пол-континента.
  function glowRadius(z) {
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    z.path.split(/[MZ]/).forEach(part => {
      part.trim().split(' ').forEach(point => {
        if (!point) return;
        const [x, y] = point.split(',').map(Number);
        if (Number.isNaN(x) || Number.isNaN(y)) return;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      });
    });
    if (minX === Infinity) return 40;
    return Math.max(24, 0.55 * Math.max(maxX - minX, maxY - minY));
  }

  function glow(z) {
    const grad = document.createElementNS(
      'http://www.w3.org/2000/svg', 'radialGradient');
    grad.setAttribute('id', `wglow-${z.id}`);
    // userSpaceOnUse: центр задан в тех же ячейках, что и контур, иначе
    // градиент растянуло бы по габаритам зоны и центр уехал бы.
    grad.setAttribute('gradientUnits', 'userSpaceOnUse');
    grad.setAttribute('cx', String(z.label[0]));
    grad.setAttribute('cy', String(z.label[1]));
    grad.setAttribute('r', String(glowRadius(z)));

    const inner = document.createElementNS('http://www.w3.org/2000/svg', 'stop');
    inner.setAttribute('offset', '0');
    const outer = document.createElementNS('http://www.w3.org/2000/svg', 'stop');
    outer.setAttribute('offset', '1');
    outer.setAttribute('stop-opacity', '0');

    grad.appendChild(inner);
    grad.appendChild(outer);
    view.glows.set(z.id, { inner, outer });
    return grad;
  }

  // --- раскраска ------------------------------------------------------------

  // Ниже этого порога клиент всё равно рисует ясное небо, поэтому и карта
  // не должна показывать «дождь», которого игрок не увидит.
  function intensity(zone) {
    const grade = Math.max(0, Math.min(100, zone.grade || 0));
    // Ясное небо почти не красим: карту под ним должно быть видно, а «ясно» —
    // это отсутствие погоды, а не ещё один её вид.
    if (zone.state_group === 'clear') return 0.12;
    // В центре пятна цвет плотнее, чем была плоская заливка: к краям он всё
    // равно уходит в ноль, и средняя «залитость» зоны остаётся прежней.
    return 0.28 + 0.42 * (grade / 100);
  }

  function paint(zone, path, label, glowStops, selected) {
    path.classList.remove('inert', 'selected');
    label.style.fill = '';

    if (!zone) {
      // Зона есть на карте, но панель ей не распоряжается (Хиджал, Врата
      // Ан'Киража): еле заметное серое пятно, чтобы было видно, что она тут,
      // и не кликается.
      path.classList.add('inert');
      setGlow(glowStops, '#8a8578', .10);
      label.style.opacity = '.3';
      return;
    }

    const color = GROUP_COLOR[zone.state_group] || GROUP_COLOR.clear;
    const known = zone.known && zone.state !== undefined;
    // Выбранная зона просто светится плотнее. Через CSS-фильтр это не сделать:
    // у снега пятно почти белое, и brightness на нём не виден.
    const alpha = (known ? intensity(zone) : .05) + (selected ? .3 : 0);
    setGlow(glowStops, known ? color : '#c8c2b2', Math.min(alpha, .95));
    label.style.opacity = '1';
    // Закреплённую руками зону обводить теперь нечем, поэтому её выдаёт
    // золотая подпись: решение человека должно быть видно без наведения.
    if (zone.source === 2) label.style.fill = 'var(--gold-bright)';
    // Точка города - единственное, что о его погоде вообще видно.
    if (label.tagName === 'circle') label.style.fill = hexA(color, known ? .95 : .35);
  }

  function setGlow(stops, color, alpha) {
    if (!stops) return;
    stops.inner.setAttribute('stop-color', color);
    stops.inner.setAttribute('stop-opacity', alpha.toFixed(2));
    stops.outer.setAttribute('stop-color', color);
  }

  function hexA(hex, alpha) {
    const n = parseInt(hex.slice(1), 16);
    return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${alpha.toFixed(2)})`;
  }

  // Раскраска идёт по данным, которые уже загрузила страница: карта — второй
  // взгляд на тот же state, а не второй источник правды.
  function render(pageZones, selected) {
    if (pageZones) view.zones = pageZones;
    if (selected !== undefined) view.selected = selected;

    // Зону можно выбрать в списке слева, а он про все континенты сразу: если
    // выбрана зона с другой карты, показываем ту карту. Только В МОМЕНТ
    // выбора: раньше проверка стояла на каждой перерисовке, и вкладки не
    // работали вовсе - страница тут же возвращалась к континенту выбранной
    // зоны (а перерисовка идёт ещё и по таймеру, раз в 15 секунд).
    const picked = view.selected !== view.lastSelected;
    view.lastSelected = view.selected;
    if (picked) {
      const chosen = (view.zones || []).find(z => z.zone_id === view.selected);
      if (chosen && SRC[chosen.continent] && chosen.continent !== view.key) {
        setContinent(chosen.continent);
        return;
      }
    }
    if (!view.geometry || !view.zones) return;
    const zones = new Map(view.zones.map(z => [z.zone_id, z]));

    view.byZone.forEach((path, id) => {
      const label = view.labels.get(id);
      const selected = id === view.selected;
      paint(zones.get(id), path, label, view.glows.get(id), selected);
      if (selected) path.classList.add('selected');
    });

    renderSummary();

    // Зоны, которые панель считает Калимдором, но которых на этой карте нет:
    // дренейский старт лежит на карте Запределья. Их всё равно надо показать,
    // иначе они пропадут из вида целиком.
    const box = document.getElementById('map-offmap');
    if (!box) return;
    box.innerHTML = '';
    const off = view.zones.filter(
      z => z.continent === view.key && !view.byZone.has(z.zone_id));
    // Пустой блок в колонке — мусор: с тех пор как дренейские острова
    // переносятся на карту через WorldMapTransforms, он обычно пуст.
    const block = box.closest('.side-block');
    if (block) block.style.display = off.length ? '' : 'none';
    if (!off.length) return;
    off.forEach(z => {
      const chip = el('button', 'wmap-chip'
        + (z.zone_id === view.selected ? ' active' : ''));
      const dot = el('span', 'wmap-dot');
      dot.style.background = z.known
        ? hexA(GROUP_COLOR[z.state_group] || GROUP_COLOR.clear, .9)
        : 'rgba(200,190,170,.3)';
      chip.appendChild(dot);
      chip.appendChild(el('span', null, z.name));
      chip.addEventListener('click', () => {
        if (typeof select === 'function') select(z.zone_id);
      });
      box.appendChild(chip);
    });
  }

  // По карте видно, ГДЕ идёт снег, но не сколько зон он накрыл. Строки с
  // нулём остаются: плашка заодно объясняет цвета, а пропавший «снег» пришлось
  // бы вспоминать по памяти.
  // Кнопки поверх карты: подписи зон и переключатель режиссёра. Обе про то,
  // что человек видит прямо здесь, поэтому обе здесь, а не в шапке.
  //
  // showTip/hideTip зовутся через window: в этом модуле есть свои функции с
  // теми же именами (подсказка по зоне под курсором), и они перекрывают общие
  // из common.js.
  function tools() {
    const box = el('div', 'wmap-tools');
    const btn = el('button', 'wmap-tool' + (view.showLabels ? ' active' : ''));

    // Иконка - подпись на бирке: прямоугольник с «Аа» внутри. Когда подписи
    // сняты, поверх ложится косая черта - привычный знак «выключено».
    const draw = () => {
      btn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"'
        + ' stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">'
        + '<rect x="2.5" y="6.5" width="19" height="11" rx="2"/>'
        + '<text x="12" y="15.6" text-anchor="middle" font-size="9.4"'
        + ' font-family="Palatino Linotype, Georgia, serif"'
        + ' fill="currentColor" stroke="none">Аа</text>'
        + (view.showLabels ? '' : '<path d="M4 20L20 4"/>')
        + '</svg>';
    };
    draw();

    const tip = () => view.showLabels ? 'Скрыть названия зон' : 'Показать названия зон';
    btn.setAttribute('aria-label', tip());
    btn.addEventListener('mouseenter', () => window.showTip(tip(), btn));
    btn.addEventListener('mouseleave', () => window.hideTip());
    btn.addEventListener('click', () => {
      view.showLabels = !view.showLabels;
      localStorage.setItem('weatherMapLabels', view.showLabels ? '1' : '0');
      btn.classList.toggle('active', view.showLabels);
      btn.setAttribute('aria-label', tip());
      draw();
      window.showTip(tip(), btn);
      if (view.labelsGroup) view.labelsGroup.classList.toggle('hidden', !view.showLabels);
    });
    box.appendChild(btn);
    return box;
  }

  // Фронты приезжают со страницы вместе с зонами: карта их только рисует.
  function setCyclones(list) {
    view.cyclones = Array.isArray(list) ? list : [];
    drawCyclones();
  }

  // Текстура вихря. Рисованная, лежит в репозитории; готовит её из исходника
  // scripts/make_cyclone_texture.py. Процедурный фрактальный шум, стоявший тут
  // раньше, давал облака, но не давал спирали, а спутниковый снимок пришлось
  // бы перекрашивать и он спорил с рисованной картой.
  //
  // Прозрачность живёт в CSS (.wmap-cyclone-texture), а не здесь: её правят
  // чаще, чем что-либо ещё в этом файле.
  const CYCLONE_TEXTURE = '/static/cyclone.png';

  function drawCyclones() {
    const g = view.cyclonesGroup;
    if (!g) return;
    g.innerHTML = '';

    const geo = view.geometry;
    if (!geo || !geo.rect) return;

    // rect = [left, right, top, bottom]; left/right — это Y мира, top/bottom — X.
    const c0 = Math.round(cellOf(geo.rect[0]));
    const r0 = Math.round(cellOf(geo.rect[2]));

    view.cyclones.forEach(c => {
      // Фронт живёт на конкретной карте. Кель'Талас и дренейские острова
      // нарисованы на этих листах, но физически лежат на карте Запределья —
      // их фронты сюда и не попадут, это честно, а не забыто.
      if (c.map !== geo.map) return;

      const cx = cellOf(c.y) - c0;
      const cy = cellOf(c.x) - r0;
      const r = c.radius / YARDS_PER_CELL;
      if (r <= 0) return;

      const eye = (c.eye || 0) / YARDS_PER_CELL;
      const color = GROUP_COLOR[c.family_group] || GROUP_COLOR.clear;
      const node = el2('g');
      node.classList.add('wmap-cyclone');

      // Текстура вращается вместе с фронтом. Своих рукавов поверх неё не
      // рисуем: на ней они уже есть, и вторая, нарисованная спираль
      // читалась бы как два вихря в одном месте.
      const swirl = el2('g');
      swirl.classList.add('wmap-cyclone-swirl');

      const photo = el2('image');
      photo.setAttribute('href', CYCLONE_TEXTURE);
      photo.setAttribute('x', String(cx - r));
      photo.setAttribute('y', String(cy - r));
      photo.setAttribute('width', String(r * 2));
      photo.setAttribute('height', String(r * 2));
      photo.classList.add('wmap-cyclone-texture');
      swirl.appendChild(photo);

      // Оборот ровно за столько же, за сколько крутит сервер: период тоже
      // приезжает в протоколе, потому что настройка правится на лету и
      // зашитая тут константа разошлась бы с ней на первой же правке.
      // Промежуточные кадры рисует CSS, а каждые 15 секунд угол
      // подтверждается сервером — расхождение не копится.
      //
      // Начальный угол ставим трансформацией самой группы, а вращение —
      // анимацией внутри: иначе поворот с сервера и анимация перетирали бы
      // друг друга, и спираль дёргалась бы на каждом обновлении.
      const spun = el2('g');
      spun.setAttribute('transform',
        `rotate(${(-(c.spin || 0)).toFixed(1)} ${cx.toFixed(1)} ${cy.toFixed(1)})`);
      spun.appendChild(swirl);
      if (c.spin_minutes > 0) {
        swirl.style.transformOrigin = `${cx}px ${cy}px`;
        swirl.style.transformBox = 'view-box';
        swirl.style.animation =
          `wmap-cyclone-spin ${c.spin_minutes * 60}s linear infinite`;
      }
      node.appendChild(spun);

      // Кромка и глаз не крутятся: они круглые, вращать их нечего, а лишний
      // анимированный узел — лишняя перерисовка.
      const ring = el2('circle');
      ring.setAttribute('cx', String(cx));
      ring.setAttribute('cy', String(cy));
      ring.setAttribute('r', String(r));
      ring.setAttribute('stroke', color);
      ring.setAttribute('stroke-dasharray', '6 5');
      ring.classList.add('wmap-cyclone-ring');
      node.appendChild(ring);

      if (eye > 1) {
        const pupil = el2('circle');
        pupil.setAttribute('cx', String(cx));
        pupil.setAttribute('cy', String(cy));
        pupil.setAttribute('r', String(eye));
        pupil.setAttribute('stroke', color);
        pupil.classList.add('wmap-cyclone-eye');
        node.appendChild(pupil);
      }

      // Стрелка курса из центра. Курс сервер считает в мировых осях, поэтому
      // и здесь он раскладывается по тем же осям, а не по экранным.
      const rad = c.heading * Math.PI / 180;
      const dx = Math.cos(rad);   // вдоль мирового X — это строка, экранный Y
      const dy = Math.sin(rad);   // вдоль мирового Y — это столбец, экранный X
      const len = Math.min(r * 0.72, 46);
      const arrow = el2('path');
      // cellOf убывает при росте координаты, поэтому у обеих осей знак минус.
      const ex = cx - dy * len;
      const ey = cy - dx * len;
      arrow.setAttribute('d', `M${cx.toFixed(1)} ${cy.toFixed(1)}`
        + ` L${ex.toFixed(1)} ${ey.toFixed(1)}`);
      arrow.setAttribute('stroke', color);
      arrow.setAttribute('fill', 'none');
      arrow.classList.add('wmap-cyclone-arrow');
      node.appendChild(arrow);

      const head = el2('path');
      const wing = 7;
      const px = -dx, py = dy;      // перпендикуляр к курсу в экранных осях
      head.setAttribute('d',
        `M${ex.toFixed(1)} ${ey.toFixed(1)}`
        + ` l${(dy * wing + px * wing * 0.6).toFixed(1)} ${(dx * wing + py * wing * 0.6).toFixed(1)}`
        + ` M${ex.toFixed(1)} ${ey.toFixed(1)}`
        + ` l${(dy * wing - px * wing * 0.6).toFixed(1)} ${(dx * wing - py * wing * 0.6).toFixed(1)}`);
      head.setAttribute('stroke', color);
      head.setAttribute('fill', 'none');
      head.classList.add('wmap-cyclone-arrow');
      node.appendChild(head);

      const label = el2('text');
      label.setAttribute('x', String(cx));
      label.setAttribute('y', String(cy - r - 6));
      label.classList.add('wmap-cyclone-label');
      label.textContent = c.family_name;
      node.appendChild(label);

      g.appendChild(node);
    });
  }

  function renderSummary() {
    const box = host().querySelector('.wmap-legend');
    if (!box || !view.zones) return;
    box.innerHTML = '';

    const mine = view.zones.filter(z => view.byZone.has(z.zone_id));
    const counts = new Map();
    mine.forEach(z => {
      const key = z.known ? (z.state_group || 'clear') : 'unknown';
      counts.set(key, (counts.get(key) || 0) + 1);
    });

    const rows = [['rain', 'дождь'], ['snow', 'снег'], ['storm', 'песчаная буря'],
                  ['special', 'особые'], ['clear', 'ясно'],
                  ['unknown', 'не ведётся']];
    rows.forEach(([key, name]) => {
      const count = counts.get(key) || 0;
      // «Не ведётся» — не вид погоды, а исключение: показываем, только когда
      // такие зоны есть.
      if (!count && key === 'unknown') return;
      const row = el('div', 'wmap-summary-row' + (count ? '' : ' empty'));
      const dot = el('span', 'wmap-dot');
      dot.style.background = key === 'unknown'
        ? 'rgba(200,190,170,.3)' : GROUP_COLOR[key];
      row.appendChild(dot);
      row.appendChild(el('span', 'wmap-summary-name', name));
      row.appendChild(el('span', 'wmap-summary-count', String(count)));
      box.appendChild(row);
    });

    // Закреплённые вручную стоит видеть отдельно: это единственное, что
    // режиссёр сам не отпустит.
    const pinned = mine.filter(z => z.source === 2).length;
    if (pinned) {
      box.appendChild(el('div', 'wmap-summary-pinned',
        `закреплено вручную: ${pinned}`));
    }
  }

  // --- подсказка ------------------------------------------------------------

  function showTip(ev, zoneId) {
    if (!view.tip) return;
    const zone = (view.zones || []).find(z => z.zone_id === zoneId);
    const geo = view.geometry.zones.find(z => z.id === zoneId);
    const lines = [];
    if (zone) {
      lines.push(zone.name);
      lines.push(zone.known
        ? `${zone.state_label}, ${zone.grade}% (${zone.source_label})`
        : 'режиссёр эту зону не вёл');
      if (zone.origin) lines.push(`связь из «${zone.origin_name}» (${zone.origin_strength}%)`);
    } else {
      lines.push(geo ? geo.name : `Зона ${zoneId}`);
      lines.push('панель этой зоной не распоряжается');
    }
    view.tip.innerHTML = '';
    lines.forEach((line, i) => {
      const row = el('div', i ? 'muted' : null, line);
      view.tip.appendChild(row);
    });
    const box = view.tip.parentElement.getBoundingClientRect();
    view.tip.style.left = `${ev.clientX - box.left + 14}px`;
    view.tip.style.top = `${ev.clientY - box.top + 14}px`;
    view.tip.classList.add('show');
  }

  function hideTip() {
    if (view.tip) view.tip.classList.remove('show');
  }

  async function init() {
    await load();
    build();
    render();
  }

  return {
    init, render, setCyclones,
    continent: () => view.key,
    hasMap: key => !!SRC[key],
    show: setContinent,
  };
})();
