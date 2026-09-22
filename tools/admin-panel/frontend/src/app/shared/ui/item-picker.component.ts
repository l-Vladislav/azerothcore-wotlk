import { Component, ElementRef, inject, input, output, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { IconComponent } from './icon.component';
import { firstValueFrom } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { ForgeSelectDirective } from './forge-select.directive';

export interface PickedItem {
  entry: number;
  name: string;
  name_ru: string;
  quality: number;
  icon?: string;
  item_level?: number;
}

const BLANK_ICON = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

/**
 * Item search in a native dialog: Esc, the backdrop and focus trapping come
 * from the browser rather than from us.
 */
@Component({
  selector: 'app-item-picker',
  imports: [FormsModule, ForgeSelectDirective, IconComponent],
  styleUrl: './item-picker.component.scss',
  template: `
    <dialog #dialog (close)="query.set('')">
      <header>
        <h2>{{ title() }}</h2>
        <button
          type="button"
          class="forge-btn is-icon close"
          aria-label="Закрыть"
          (click)="close()"
        >
          <app-icon name="close" [size]="14" />
        </button>
      </header>
      @if (hint()) {
        <p class="hint">{{ hint() }}</p>
      }
      <div class="search">
        <input
          #field
          class="forge-field is-search"
          type="search"
          placeholder="имя или номер предмета"
          [ngModel]="query()"
          (ngModelChange)="onQuery($event)"
          (keydown.enter)="search()"
        />
        <select
          class="forge-field is-select"
          [ngModel]="block()"
          (ngModelChange)="onBlock($event)"
          aria-label="Где искать"
        >
          <option value="">везде</option>
          <option value="custom">только свои</option>
          <option value="professions">только изделия профессий</option>
        </select>
      </div>
      <div class="results">
        @if (loading()) {
          <p class="muted">Ищем…</p>
        } @else if (error()) {
          <p class="error">{{ error() }}</p>
        } @else if (!results().length) {
          <p class="muted">Ничего не нашлось.</p>
        } @else {
          @for (item of results(); track item.entry) {
            <button type="button" class="item-row" (click)="choose(item)">
              <img
                [src]="iconUrl(item)"
                width="32"
                height="32"
                alt=""
                (error)="onIconError($event)"
              />
              <span class="name">
                <b [class]="'q' + item.quality">{{ item.name_ru || item.name }}</b>
                <small>id {{ item.entry }}</small>
              </span>
            </button>
          }
        }
      </div>
    </dialog>
  `,
})
export class ItemPickerComponent {
  private readonly api = inject(ApiService);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');
  private readonly field = viewChild<ElementRef<HTMLInputElement>>('field');
  private timer: ReturnType<typeof setTimeout> | null = null;

  readonly title = input('Выбор предмета');
  readonly hint = input('');
  readonly iconBase = input('');
  readonly picked = output<PickedItem>();

  readonly query = signal('');
  readonly block = signal('');
  readonly results = signal<PickedItem[]>([]);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);

  open(query = ''): void {
    this.query.set(query);
    this.dialog().nativeElement.showModal();
    this.field()?.nativeElement.focus();
    this.search();
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  onQuery(value: string): void {
    this.query.set(value);
    if (this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(() => this.search(), 250);
  }

  onBlock(value: string): void {
    this.block.set(value);
    this.search();
  }

  choose(item: PickedItem): void {
    this.picked.emit(item);
    this.close();
  }

  iconUrl(item: PickedItem): string {
    return item.icon && this.iconBase() ? `${this.iconBase()}/${item.icon}.jpg` : BLANK_ICON;
  }

  onIconError(event: Event): void {
    (event.target as HTMLImageElement).src = BLANK_ICON;
  }

  async search(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    const params = new URLSearchParams({ q: this.query(), limit: '40' });
    if (this.block()) params.set('block', this.block());
    try {
      const page = await firstValueFrom(this.api.get<{ items: PickedItem[] }>(`/items?${params}`));
      this.results.set(page.items ?? []);
    } catch {
      this.error.set('Поиск предметов не ответил.');
      this.results.set([]);
    } finally {
      this.loading.set(false);
    }
  }
}
