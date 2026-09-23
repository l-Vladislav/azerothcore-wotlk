import {
  Component,
  ElementRef,
  computed,
  inject,
  input,
  output,
  signal,
  viewChild,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { ForgeSelectDirective } from './forge-select.directive';
import { IconComponent } from './icon.component';
import { ItemTooltipDirective } from './item-tooltip.directive';

export interface PickedItem {
  entry: number;
  name: string;
  name_ru: string;
  quality: number;
  icon?: string;
  item_level?: number;
  required_level?: number;
  class?: number;
  subclass?: number;
  inventory_type?: number;
}

interface EnumPair {
  value: number;
  label: string;
}

interface ItemEnums {
  quality: EnumPair[];
  inventoryType: EnumPair[];
  itemClass: EnumPair[];
  itemSubclass: Record<string, EnumPair[]>;
}

const BLANK_ICON = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
const PAGE = 40;

/**
 * Справочники фильтров - один раз на вкладку: окон выбора на странице бывает
 * несколько, и каждому спрашивать одно и то же незачем.
 */
let enumsOnce: Promise<ItemEnums | null> | null = null;

/**
 * Выбор предмета в родном `<dialog>`: Esc, подложка и удержание фокуса - от
 * браузера.
 *
 * Заголовка нет (решение владельца 2026-09-23): что выбираем, и так видно по
 * кнопке, которая окно открыла, а заголовок с чертой под ним съедали место у
 * списка. Вместо него - отборы: где искать, класс и подкласс, качество, слот,
 * уровень предмета. Наведение на строку показывает игровую подсказку.
 */
@Component({
  selector: 'app-item-picker',
  imports: [FormsModule, ForgeSelectDirective, IconComponent, ItemTooltipDirective],
  styleUrl: './item-picker.component.scss',
  template: `
    <dialog #dialog class="forge-dialog" [attr.aria-label]="title()" (close)="query.set('')">
      <div class="search">
        <input
          #field
          class="forge-field is-small is-search"
          type="search"
          placeholder="имя или номер предмета"
          [ngModel]="query()"
          (ngModelChange)="onQuery($event)"
          (keydown.enter)="search()"
        />
        <button
          type="button"
          class="forge-btn is-icon is-compact close"
          aria-label="Закрыть"
          (click)="close()"
        >
          <app-icon name="close" [size]="12" />
        </button>
      </div>

      <div class="filters">
        <select
          class="forge-field is-small is-select"
          [ngModel]="block()"
          (ngModelChange)="setFilter('block', $event)"
          aria-label="Где искать"
        >
          <option value="">везде</option>
          <option value="custom">только свои</option>
          <option value="professions">изделия профессий</option>
        </select>
        <select
          class="forge-field is-small is-select"
          [ngModel]="itemClass()"
          (ngModelChange)="onClass($event)"
          aria-label="Класс"
        >
          <option value="">любой класс</option>
          @for (opt of enums()?.itemClass ?? []; track opt.value) {
            <option [value]="'' + opt.value">{{ opt.label }}</option>
          }
        </select>
        <select
          class="forge-field is-small is-select"
          [ngModel]="subclass()"
          [disabled]="!subclasses().length"
          (ngModelChange)="setFilter('subclass', $event)"
          aria-label="Подкласс"
        >
          <option value="">{{ subclasses().length ? 'любой подкласс' : 'подкласс' }}</option>
          @for (opt of subclasses(); track opt.value) {
            <option [value]="'' + opt.value">{{ opt.label }}</option>
          }
        </select>
        <select
          class="forge-field is-small is-select"
          [ngModel]="quality()"
          (ngModelChange)="setFilter('quality', $event)"
          aria-label="Качество"
        >
          <option value="">любое качество</option>
          @for (opt of enums()?.quality ?? []; track opt.value) {
            <option [value]="'' + opt.value">{{ opt.label }}</option>
          }
        </select>
        <select
          class="forge-field is-small is-select"
          [ngModel]="slot()"
          (ngModelChange)="setFilter('slot', $event)"
          aria-label="Слот"
        >
          <option value="">любой слот</option>
          @for (opt of enums()?.inventoryType ?? []; track opt.value) {
            <option [value]="'' + opt.value">{{ opt.label }}</option>
          }
        </select>
        <span class="range" title="Уровень предмета">
          <input
            class="forge-field is-small"
            type="number"
            min="0"
            placeholder="илвл от"
            [ngModel]="ilvlMin()"
            (ngModelChange)="setFilter('ilvlMin', $event ?? '')"
          />
          <input
            class="forge-field is-small"
            type="number"
            min="0"
            placeholder="до"
            [ngModel]="ilvlMax()"
            (ngModelChange)="setFilter('ilvlMax', $event ?? '')"
          />
        </span>
        @if (dirty()) {
          <button type="button" class="forge-btn is-ghost is-compact" (click)="reset()">
            Сбросить
          </button>
        }
      </div>

      <div class="results" [class.is-loading]="loading()" [attr.aria-busy]="loading()">
        <!-- Отбор ушёл на сервер, а строки на экране ещё прежние: без этой
             строки казалось, что отбор не сработал. -->
        @if (loading() && results().length) {
          <p class="loading">Загрузка…</p>
        }
        @if (error()) {
          <p class="error">{{ error() }}</p>
        } @else if (!results().length) {
          <p class="muted">{{ loading() ? 'Ищем…' : 'Ничего не нашлось.' }}</p>
        } @else {
          @for (item of results(); track item.entry) {
            <button
              type="button"
              class="item-row"
              [appItemTooltip]="item.entry"
              (click)="choose(item)"
            >
              <img
                [src]="iconUrl(item)"
                width="32"
                height="32"
                alt=""
                (error)="onIconError($event)"
              />
              <span class="name">
                <b [class]="'q' + item.quality">{{ item.name_ru || item.name }}</b>
                <small>
                  id {{ item.entry }}
                  @if (item.item_level) {
                    · илвл {{ item.item_level }}
                  }
                </small>
              </span>
            </button>
          }
          @if (results().length < total()) {
            <button
              type="button"
              class="forge-btn is-ghost is-compact more"
              [disabled]="loading()"
              (click)="more()"
            >
              Показать ещё
            </button>
          }
        }
      </div>
      @if (results().length) {
        <p class="count">Показано {{ results().length }} из {{ total() }}</p>
      }
    </dialog>
  `,
})
export class ItemPickerComponent {
  private readonly api = inject(ApiService);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');
  private readonly field = viewChild<ElementRef<HTMLInputElement>>('field');
  private timer: ReturnType<typeof setTimeout> | null = null;
  /** Номер запроса: ответ на прежний отбор, пришедший позже нового, выбрасывается. */
  private request = 0;

  /** Что выбираем - теперь только подпись окна для экранного диктора. */
  readonly title = input('Выбор предмета');
  readonly iconBase = input('');
  readonly picked = output<PickedItem>();

  readonly query = signal('');
  readonly block = signal('');
  readonly itemClass = signal('');
  readonly subclass = signal('');
  readonly quality = signal('');
  readonly slot = signal('');
  readonly ilvlMin = signal<string>('');
  readonly ilvlMax = signal<string>('');

  readonly enums = signal<ItemEnums | null>(null);
  readonly results = signal<PickedItem[]>([]);
  readonly total = signal(0);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);

  readonly subclasses = computed(() => {
    const cls = this.itemClass();
    return cls === '' ? [] : (this.enums()?.itemSubclass[cls] ?? []);
  });
  readonly dirty = computed(
    () =>
      !!this.block() ||
      this.itemClass() !== '' ||
      this.subclass() !== '' ||
      this.quality() !== '' ||
      this.slot() !== '' ||
      this.ilvlMin() !== '' ||
      this.ilvlMax() !== '',
  );

  open(query = ''): void {
    this.query.set(query);
    this.dialog().nativeElement.showModal();
    this.field()?.nativeElement.focus();
    void this.loadEnums();
    void this.search();
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  onQuery(value: string): void {
    this.query.set(value);
    this.later();
  }

  onClass(value: string): void {
    this.itemClass.set(value);
    // Подкласс принадлежит классу: у брони «Латы», у оружия «Меч».
    this.subclass.set('');
    void this.search();
  }

  /** Любой отбор: поменять и искать заново (числа - с задержкой, пока печатают). */
  setFilter(
    key: 'block' | 'subclass' | 'quality' | 'slot' | 'ilvlMin' | 'ilvlMax',
    value: string | number | null,
  ): void {
    this[key].set(value === null ? '' : String(value));
    if (key === 'ilvlMin' || key === 'ilvlMax') this.later();
    else void this.search();
  }

  reset(): void {
    this.block.set('');
    this.itemClass.set('');
    this.subclass.set('');
    this.quality.set('');
    this.slot.set('');
    this.ilvlMin.set('');
    this.ilvlMax.set('');
    void this.search();
  }

  choose(item: PickedItem): void {
    this.picked.emit(item);
    this.close();
  }

  iconUrl(item: PickedItem): string {
    const base = this.iconBase() || '';
    return item.icon && base ? `${base}/${item.icon}.jpg` : BLANK_ICON;
  }

  onIconError(event: Event): void {
    (event.target as HTMLImageElement).src = BLANK_ICON;
  }

  more(): void {
    void this.search(true);
  }

  async search(append = false): Promise<void> {
    const mine = ++this.request;
    this.loading.set(true);
    this.error.set(null);
    const params = new URLSearchParams({
      q: this.query(),
      limit: String(PAGE),
      offset: String(append ? this.results().length : 0),
    });
    const put = (key: string, value: string | number) => {
      if (value !== '' && value !== null && value !== undefined) params.set(key, String(value));
    };
    put('block', this.block());
    put('item_class', this.itemClass());
    put('item_subclass', this.subclass());
    put('quality', this.quality());
    put('inventory_type', this.slot());
    put('item_level_min', this.ilvlMin());
    put('item_level_max', this.ilvlMax());
    try {
      const page = await firstValueFrom(
        this.api.get<{ items: PickedItem[]; total: number }>(`/items?${params}`),
      );
      if (mine !== this.request) return;
      this.results.set(append ? [...this.results(), ...(page.items ?? [])] : (page.items ?? []));
      this.total.set(page.total ?? 0);
    } catch {
      if (mine !== this.request) return;
      this.error.set('Поиск предметов не ответил.');
      if (!append) this.results.set([]);
    } finally {
      if (mine === this.request) this.loading.set(false);
    }
  }

  private later(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(() => void this.search(), 250);
  }

  private async loadEnums(): Promise<void> {
    if (this.enums()) return;
    enumsOnce ??= firstValueFrom(this.api.get<{ enums: ItemEnums }>('/items/enums'))
      .then((answer) => answer.enums)
      .catch(() => {
        enumsOnce = null;
        return null;
      });
    this.enums.set(await enumsOnce);
  }
}
