import { AfterViewInit, Component, computed, signal } from '@angular/core';

/** Образец цвета: либо константа темы, либо число, снятое с листа. */
interface Swatch {
  token?: string;
  value?: string;
  what: string;
}
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { IconComponent } from '../../shared/ui/icon.component';
import { TablePagerComponent } from '../../shared/data/table-pager.component';

/**
 * Витрина кита `styles/forge.scss` - всё нарезанное со стайлгайда в одном
 * месте и в рабочем виде. Нужна, чтобы кромки и состояния было где смотреть
 * живьём: на картинке кнопка всегда хороша, а тянется она только здесь.
 *
 * Переключатели тут настоящие, а не нарисованные, - иначе `:checked` и
 * `:disabled` не проверить.
 */
@Component({
  imports: [ForgeSelectDirective, IconComponent, TablePagerComponent],
  selector: 'app-style-kit-page',
  styleUrl: './style-kit.page.scss',
  templateUrl: './style-kit.page.html',
})
export class StyleKitPage implements AfterViewInit {
  // Свой набор: имя - то, что пишется в `[name]`, подпись - о чём значок.
  // Разбит по назначению, иначе это просто сетка из полусотни картинок.
  readonly iconGroups: { label: string; items: [string, string][] }[] = [
    {
      label: 'Разделы панели',
      items: [
        ['world', 'Мир'],
        ['records', 'Справочники'],
        ['board', 'Доска'],
        ['server', 'Сервер'],
        ['loot', 'Добыча'],
        ['weather', 'Погода'],
        ['weather-settings', 'Настройки погоды'],
        ['effects', 'Эффекты'],
        ['talents', 'Таланты'],
        ['professions', 'Профессии'],
        ['spells', 'Заклинания'],
        ['items', 'Предметы'],
        ['world-items', 'Предметы мира'],
        ['patch', 'Клиентский патч'],
        ['news', 'Новости'],
        ['users', 'Люди и доступ'],
        ['audit', 'Журнал'],
      ],
    },
    {
      label: 'Карточки доски',
      items: [
        ['bug', 'Баг'],
        ['idea', 'Идея'],
        ['task', 'Задача'],
        ['tag', 'Метка'],
        ['module', 'Модуль'],
        ['archive', 'Архив'],
      ],
    },
    {
      label: 'Действия',
      items: [
        ['plus', 'Добавить'],
        ['close', 'Закрыть'],
        ['check', 'Готово'],
        ['edit', 'Править'],
        ['trash', 'Удалить'],
        ['refresh', 'Обновить'],
        ['search', 'Поиск'],
        ['filter', 'Фильтр'],
        ['external', 'Внешняя ссылка'],
        ['lock', 'Заперто'],
        ['unlock', 'Открыто'],
        ['question', 'Справка'],
      ],
    },
    {
      label: 'Стрелки и мелочь',
      items: [
        ['arrow-up', 'Выше'],
        ['arrow-down', 'Ниже'],
        ['sort', 'Сортировка'],
        ['caret', 'Раскрыть'],
        ['caret-right', 'Свернуто'],
        ['calendar', 'Дата'],
        ['bell', 'Оповещение'],
        ['dot', 'Точка'],
      ],
    },
  ];
  readonly shields = ['gold', 'steel', 'alliance', 'horde'];
  readonly badges = [
    ['new', 'Новое'],
    ['published', 'Выпущено'],
    ['scheduled', 'В очереди'],
    ['draft', 'Черновик'],
    ['beta', 'Бета'],
    ['maintenance', 'Работы'],
    ['deprecated', 'Устарело'],
    ['featured', 'На витрине'],
  ];
  readonly dots = [
    ['online', 'В сети'],
    ['offline', 'Не в сети'],
    ['away', 'Отошёл'],
    ['busy', 'Занят'],
    ['maintenance', 'Обслуживание'],
  ];

  /**
   * Четыре фоновые плитки набора. Присланные листы - рендеры, плитку из
   * них делает `seamless_tile` в нарезчике, поэтому здесь они показаны
   * повтором: швы видно только так, на одном квадрате их не поймать.
   */
  readonly textures = [
    {
      file: 'stone-dark',
      label: 'Тёмный камень',
      token: '--texture-sidebar',
      use: 'боковая панель - самый тёмный из набора',
    },
    {
      file: 'stone-carved',
      label: 'Резной камень',
      token: '--texture-stone',
      use: 'фон страницы и нутро панелей (--forge-inner)',
    },
    {
      file: 'stone-fine',
      label: 'Мелкий камень',
      token: '--texture-metal',
      use: 'шапка и металлические полосы',
    },
    {
      file: 'slate',
      label: 'Сланец',
      token: '--texture-slate',
      use: 'доска и плотные списки (--forge-inner-slate)',
    },
  ];

  // --- таблица (лист 8 стайлгайда) -----------------------------------------
  //
  // Строки настоящие и сортируются по-настоящему: на картинке стрелка у
  // заголовка всегда на месте, а на живой таблице видно, что она значит.
  readonly columns = [
    { id: 'id', label: 'ID' },
    { id: 'name', label: 'Имя' },
    { id: 'state', label: 'Состояние' },
    { id: 'role', label: 'Роль' },
    { id: 'seen', label: 'Был' },
  ];
  readonly stateLabels: Readonly<Record<string, string>> = {
    online: 'В сети',
    offline: 'Не в сети',
    away: 'Отошёл',
  };
  private readonly people = [
    { id: 1001, name: 'Arthasx', state: 'online', role: 'Владелец', seen: '21.11.2019, 14:32' },
    { id: 1002, name: 'Jaina', state: 'offline', role: 'Редактор', seen: '20.11.2019, 09:14' },
    { id: 1003, name: 'Thrall', state: 'online', role: 'Мастер игры', seen: '19.11.2019, 22:08' },
    { id: 1004, name: 'SylvanasFan', state: 'away', role: 'Смотрящий', seen: '18.11.2019, 16:45' },
    { id: 1005, name: 'Illidan', state: 'offline', role: 'Редактор', seen: '17.11.2019, 11:20' },
  ];
  readonly sort = signal<{ by: string; down: boolean }>({ by: 'id', down: false });
  readonly rows = computed(() => {
    const { by, down } = this.sort();
    const sorted = [...this.people].sort((a, b) => {
      const left = a[by as keyof typeof a];
      const right = b[by as keyof typeof b];
      return left === right ? 0 : left < right ? -1 : 1;
    });
    return down ? sorted.reverse() : sorted;
  });
  readonly perPage = signal(10);

  sortBy(column: string): void {
    this.sort.update((now) =>
      now.by === column ? { by: column, down: !now.down } : { by: column, down: false },
    );
  }

  // --- цвета ----------------------------------------------------------------
  //
  // Значения НЕ вписаны руками: те, у кого есть переменная темы, страница
  // читает из неё же (`getComputedStyle` по `:root`), поэтому витрина не
  // может разойтись с `styles/theme.scss`. Вписаны только числа, снятые
  // пипеткой с листов стайлгайда, - у них своей переменной нет.
  readonly colorGroups: { label: string; hint: string; items: Swatch[] }[] = [
    {
      label: 'Золото',
      hint: 'Заголовки и кромки. Замерено с классических текстур игры, поэтому золото бурое, а не лимонное.',
      items: [
        { token: '--gold', what: 'Заголовки, NORMAL_FONT_COLOR игры' },
        { token: '--gold-bright', what: 'Наведение, выбранное' },
        { token: '--gold-dim', what: 'Подписи-ссылки, тихое золото' },
        { token: '--edge-gold', what: 'Кромка панели' },
        { token: '--edge-gold-bright', what: 'Блик на кромке' },
      ],
    },
    {
      label: 'Поверхности и линии',
      hint: 'Панель в классике чёрная, вся нарядность - в кромке. Линия-разделитель холодная: тёплой в стайлгайде нет.',
      items: [
        { token: '--bg', what: 'Фон страницы под камнем' },
        { token: '--panel', what: 'Плоская панель' },
        { token: '--panel-2', what: 'Полоса заголовка панели' },
        { token: '--line', what: 'Разделитель' },
        { token: '--line-title', what: 'Нить под заголовком панели' },
        { token: '--line-strong', what: 'Заметная граница' },
      ],
    },
    {
      label: 'Текст',
      hint: 'Холодный и светлый - как на листах. Белый акцент отдельным именем: им набраны числа показателей и шапки таблиц.',
      items: [
        { token: '--text', what: 'Основной' },
        { token: '--text-bright', what: 'Ячейка таблицы' },
        { token: '--text-strong', what: 'Число, шапка таблицы' },
        { token: '--muted', what: 'Подписи и пояснения' },
        { token: '--link', what: 'Ссылка, раскрывашка' },
        { token: '--text-warning', what: 'Предупреждение' },
        { token: '--text-danger', what: 'Отказ' },
      ],
    },
    {
      label: 'Состояния',
      hint: 'Цвета огоньков и подписей рядом с ними сняты с листа 8; зелёный и красный самой игры - рядом для сравнения.',
      items: [
        { token: '--state-online', what: 'В сети (.forge-state.is-online)' },
        { token: '--state-offline', what: 'Не в сети, занят' },
        { token: '--state-away', what: 'Отошёл' },
        { token: '--state-steel', what: 'Обслуживание, стрелка сортировки' },
        { token: '--ok', what: 'GREEN_FONT_COLOR игры' },
        { token: '--danger', what: 'RED_FONT_COLOR игры' },
      ],
    },
    {
      label: 'Приоритет карточки',
      hint: 'Обводка карточки на доске. Имена свои, значения - те же цвета состояний плюс красный игры у критичного.',
      items: [
        { token: '--priority-low', what: 'Низкий - тихая стальная нить' },
        { token: '--priority-normal', what: 'Обычный - без подсветки' },
        { token: '--priority-high', what: 'Высокий' },
        { token: '--priority-critical', what: 'Критичный' },
      ],
    },
    {
      label: 'Таблица (замеры листа 8)',
      hint: 'Снято пипеткой с «Data Table»: у таблицы своя холодная гамма, к общему золоту панели она не сводится.',
      items: [
        { token: '--table-head', what: 'Фон шапки' },
        { token: '--table-row', what: 'Фон строк, ровный - зебры нет' },
        { token: '--table-head-line', what: 'Линия под шапкой' },
        { token: '--table-row-line', what: 'Линия между строками' },
        { token: '--table-col-line', what: 'Линия между колонками' },
      ],
    },
    {
      label: 'Качество предметов',
      hint: 'Как их красит сама игра. Классы .q0-.q7, общие для каталога, добычи и подборщиков.',
      items: [
        { value: '#9d9d9d', what: 'Мусор (q0)' },
        { value: '#ffffff', what: 'Обычное (q1)' },
        { value: '#1eff00', what: 'Необычное (q2)' },
        { value: '#0070dd', what: 'Редкое (q3)' },
        { value: '#a335ee', what: 'Эпическое (q4)' },
        { value: '#ff8000', what: 'Легендарное (q5)' },
        { value: '#e6cc80', what: 'Артефакт (q6)' },
        { value: '#00ccff', what: 'Наследие (q7)' },
      ],
    },
  ];

  readonly priorityDemo = [
    { cls: 'p0', label: 'Низкий' },
    { cls: 'p1', label: 'Обычный' },
    { cls: 'p2', label: 'Высокий' },
    { cls: 'p3', label: 'Критичный' },
  ];

  /** Значения переменных темы - прочитанные, а не переписанные. */
  readonly tokenValues = signal<Record<string, string>>({});

  ngAfterViewInit(): void {
    const style = getComputedStyle(document.documentElement);
    const values: Record<string, string> = {};
    for (const group of this.colorGroups) {
      for (const item of group.items) {
        const token = (item as { token?: string }).token;
        if (token) values[token] = style.getPropertyValue(token).trim();
      }
    }
    this.tokenValues.set(values);
  }

  swatch(item: { token?: string; value?: string }): string {
    return item.token ? `var(${item.token})` : (item.value ?? 'transparent');
  }

  swatchValue(item: { token?: string; value?: string }): string {
    return item.token ? (this.tokenValues()[item.token] ?? item.token) : (item.value ?? '');
  }

  // --- шрифты ---------------------------------------------------------------
  //
  // Гарнитур в панели ровно три, и держатся они на системных шрифтах: своих
  // файлов мы не грузим - ни один веб-шрифт не подключён (сеть у панели своя,
  // и за иконками заклинаний она ходит наружу только по просьбе страницы).
  // Замеры взяты с этой же страницы через getComputedStyle.
  readonly faces = [
    {
      label: 'Palatino Linotype',
      token: '--serif',
      stack: "'Palatino Linotype', 'Book Antiqua', Palatino, Georgia, serif",
      sample: 'Пробуждение снаряжения · 1234',
      use: 'Заголовки, кнопки, вкладки, пункты меню, плашки, шапки таблиц. Запасные - Book Antiqua, Palatino, Georgia.',
    },
    {
      label: 'Segoe UI',
      token: 'body',
      stack: "'Segoe UI', system-ui, sans-serif",
      sample: 'Обычный текст страницы · 1234',
      use: 'Всё, что читается подряд: абзацы, ячейки таблиц, поля ввода, подписи. Запасные - system-ui и системный без засечек.',
    },
    {
      label: 'Моноширинный',
      token: 'monospace',
      stack: 'monospace',
      sample: 'SELECT * FROM item_template',
      use: 'Код в тексте, лог сборки, JSON в журнале. Берётся системный - свой файл сюда не тянем.',
    },
  ];

  readonly fontSizes = [
    { what: 'Заголовок страницы (h1)', face: 'Palatino', size: '27px', weight: '500' },
    { what: 'Заголовок раздела набора', face: 'Palatino', size: '17px', weight: '400' },
    { what: 'Заголовок в панели (h3)', face: 'Palatino', size: '16px', weight: '500' },
    { what: 'Текст страницы', face: 'Segoe UI', size: '14px / 1.45', weight: '400' },
    { what: 'Шапка таблицы', face: 'Palatino', size: '16px', weight: '500' },
    { what: 'Ячейка таблицы', face: 'Segoe UI', size: '15px', weight: '400' },
    { what: 'Кнопка обычная / большая', face: 'Palatino', size: '15px / 19px', weight: '400' },
    { what: 'Кнопка мелкая (is-small, is-compact)', face: 'Palatino', size: '13px', weight: '400' },
    { what: 'Плашка состояния', face: 'Palatino', size: '13px', weight: '400' },
    { what: 'Подпись, подсказка', face: 'Segoe UI', size: '11-13px', weight: '400' },
  ];

  readonly tab = signal('overview');
  readonly page = signal(1);
  readonly pages = [1, 2, 3, 4, 5];
  readonly progress = signal(68);
}
