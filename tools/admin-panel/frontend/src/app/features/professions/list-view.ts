import { Component, Signal, computed, input, signal } from '@angular/core';

/**
 * Отбор, сортировка и страницы для таблиц профессий.
 *
 * Страницы тут разные, а поведение нужно одно: строка поиска, пара выпадающих
 * отборов, щелчок по заголовку сортирует. Поэтому механика лежит здесь, а
 * страница приносит только описание - чем искать, чем отбирать, чем сортировать.
 *
 * Состояние - сигналы самой страницы, и оно ПЕРЕЖИВАЕТ перезагрузку списка:
 * правка строки перечитывает справочник целиком, и без этого лист после
 * каждого сохранения прыгал бы к началу, теряя отбор.
 */

/**
 * Отбор, как его видит полоса: ключ, подпись и варианты. Функции-доставалы
 * тут нет нарочно - полосе она не нужна, а без неё вид отбора не зависит от
 * типа строки, и один компонент обслуживает все страницы.
 */
export interface PickOption {
  key: string;
  label: string;
  options: readonly (readonly [string, string])[];
}

export interface ListPick<T> extends PickOption {
  get: (row: T) => string | number | boolean;
}

/** Что полосе отбора нужно знать о списке. */
export interface FilterState {
  query: Signal<string>;
  picked: Signal<Record<string, string>>;
  found: Signal<readonly unknown[]>;
  dirty: Signal<boolean>;
  onQuery(value: string): void;
  onPick(key: string, value: string): void;
  reset(): void;
}

/** Что заголовку колонки нужно знать о сортировке. */
export interface SortState {
  sort: Signal<string>;
  dir: Signal<number>;
  toggleSort(label: string): void;
}

export interface ListSpec<T> {
  /** Строка, по которой идёт поиск. */
  search?: (row: T) => string;
  picks?: readonly ListPick<T>[];
  /** Ключ - подпись колонки, значение - чем её сравнивать. */
  sorts?: Record<string, (row: T) => string | number>;
}

/** Числа сравниваем числами, строки - по-русски: иначе «10» встаёт перед «9». */
function compareValues(a: string | number, b: string | number): number {
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  return String(a ?? '').localeCompare(String(b ?? ''), 'ru');
}

export class ListView<T> implements FilterState, SortState {
  readonly query = signal('');
  readonly picked = signal<Record<string, string>>({});
  readonly sort = signal('');
  readonly dir = signal(1);
  readonly page = signal(1);
  readonly perPage = signal(50);
  /**
   * Строка, к которой привела ссылка со «Связей». Карта обязана приводить
   * именно К СТРОКЕ: страница рецептов - это восемь десятков записей на
   * нескольких страницах, и «мы открыли нужный раздел» тут не помощь.
   */
  readonly focused = signal<T | null>(null);

  /** Что нашлось отбором - до нарезки на страницы. */
  readonly found: Signal<T[]>;
  /** Строки текущей страницы. */
  readonly rows: Signal<T[]>;
  readonly lastPage: Signal<number>;
  readonly dirty: Signal<boolean>;

  constructor(
    private readonly source: Signal<readonly T[]>,
    private readonly spec: Signal<ListSpec<T>>,
  ) {
    this.found = computed(() => {
      const spec = this.spec();
      let out = [...this.source()];

      const needle = this.query().trim().toLocaleLowerCase();
      if (needle && spec.search) {
        out = out.filter((row) => String(spec.search!(row) ?? '')
          .toLocaleLowerCase()
          .includes(needle));
      }

      const picked = this.picked();
      for (const pick of spec.picks ?? []) {
        const chosen = picked[pick.key];
        if (chosen === undefined || chosen === '') continue;
        out = out.filter((row) => String(pick.get(row)) === chosen);
      }

      const sorter = spec.sorts?.[this.sort()];
      if (sorter) out.sort((a, b) => compareValues(sorter(a), sorter(b)) * this.dir());
      return out;
    });

    this.lastPage = computed(() => Math.max(1, Math.ceil(this.found().length / this.perPage())));
    this.rows = computed(() => {
      const page = Math.min(Math.max(1, this.page()), this.lastPage());
      const from = (page - 1) * this.perPage();
      return this.found().slice(from, from + this.perPage());
    });
    this.dirty = computed(
      () =>
        !!this.query() ||
        !!this.sort() ||
        Object.values(this.picked()).some((value) => value !== '' && value !== undefined),
    );
  }

  /** Новый отбор начинает список сначала: иначе на экране пусто, хотя нашлось. */
  onQuery(value: string): void {
    this.query.set(value);
    this.page.set(1);
  }

  onPick(key: string, value: string): void {
    this.picked.update((picked) => ({ ...picked, [key]: value }));
    this.page.set(1);
  }

  toggleSort(label: string): void {
    if (this.sort() === label) this.dir.update((dir) => -dir);
    else {
      this.sort.set(label);
      this.dir.set(1);
    }
    this.page.set(1);
  }

  /** Перелистнуть на страницу с этой строкой и подсветить её на полторы секунды. */
  focus(match: (row: T) => boolean): void {
    const found = this.found();
    const index = found.findIndex(match);
    if (index < 0) return;
    this.page.set(Math.floor(index / this.perPage()) + 1);
    this.focused.set(found[index]);
    setTimeout(() => this.focused.set(null), 1600);
  }

  /** Размер страницы - не часть отбора: его выбрали под свой экран. */
  reset(): void {
    this.query.set('');
    this.picked.set({});
    this.sort.set('');
    this.dir.set(1);
    this.page.set(1);
  }
}

/**
 * Заголовок сортируемой колонки. Отдельным компонентом, а не тремя привязками
 * в каждой ячейке: заголовков на странице по десятку, и копии успевают
 * разойтись - где-то стрелка, где-то нет.
 */
@Component({
  selector: 'th[appSort]',
  host: {
    class: 'sortable',
    '[class.is-sorted]': 'view().sort() === appSort()',
    '(click)': 'view().toggleSort(appSort())',
    title: 'Сортировать по колонке.',
  },
  template: `<ng-content />@if (view().sort() === appSort()) {
      <span class="sort-arrow">{{ view().dir() > 0 ? '▲' : '▼' }}</span>
    }`,
})
export class SortHeadComponent {
  readonly appSort = input.required<string>();
  readonly view = input.required<SortState>();
}
