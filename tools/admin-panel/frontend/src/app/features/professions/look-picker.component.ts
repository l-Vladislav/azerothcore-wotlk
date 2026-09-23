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
import { ItemTooltipDirective } from '../../shared/ui/item-tooltip.directive';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { IconComponent } from '../../shared/ui/icon.component';
import { DisplayLook, ProfessionsApi } from './professions.api';
import { apiError, iconUrl, useBlankIcon } from './professions.model';

const PAGE = 120;

/**
 * Выбор ВНЕШНЕГО ВИДА, а не картинки.
 *
 * Иконка не отдельное поле: она лежит в ItemDisplayInfo.dbc вместе с 3D-моделью,
 * поэтому выбирается `displayid` существующего предмета - и вместе с иконкой
 * меняется то, как предмет выглядит в руках.
 *
 * Постранично нарочно: одних мечей в базе под тысячу видов, и без листания
 * выбор молча обрезался на первой сотне - страница выглядела как «это всё».
 *
 * Заголовка с чертой нет (решение владельца 2026-09-23): что выбираем, видно по
 * кнопке, открывшей окно. Наведение на вид показывает игровую подсказку его
 * предмета-образца - по ней видно, чей это вид.
 */
@Component({
  selector: 'app-look-picker',
  imports: [FormsModule, ForgeSelectDirective, IconComponent, ItemTooltipDirective],
  styleUrl: './look-picker.component.scss',
  template: `
    <dialog #dialog class="forge-dialog" [attr.aria-label]="title()" (close)="onClose()">
      <div class="tools">
        <input
          #field
          class="forge-field is-small is-search"
          type="search"
          placeholder="поиск по названию предмета (рус. или англ.)"
          [ngModel]="query()"
          (ngModelChange)="onQuery($event)"
        />
        @if (itemClass() !== null) {
          <select
            class="forge-field is-small is-select"
            [ngModel]="scope()"
            (ngModelChange)="onScope($event)"
            aria-label="Где искать вид"
          >
            <option value="self">этот тип</option>
            <option value="class">весь класс</option>
            <option value="any">любые предметы</option>
          </select>
        }
        <button
          type="button"
          class="forge-btn is-icon is-compact close"
          aria-label="Закрыть"
          (click)="close()"
        >
          <app-icon name="close" [size]="12" />
        </button>
      </div>

      <div class="grid">
        @for (look of looks(); track look.display_id) {
          <button type="button" class="look" [appItemTooltip]="look.entry" (click)="choose(look)">
            <img [src]="src(look)" width="40" height="40" alt="" (error)="onIconError($event)" />
            <span class="id">{{ look.display_id }}</span>
            <span class="used" [title]="'так выглядят предметов: ' + look.used_by">{{
              look.used_by
            }}</span>
          </button>
        }
      </div>

      <footer>
        @if (pages() > 1) {
          <div class="pager">
            <button
              type="button"
              class="forge-btn is-ghost is-compact"
              [disabled]="page() === 0"
              (click)="step(-1)"
            >
              ← Назад
            </button>
            <span>{{ range() }}</span>
            <button
              type="button"
              class="forge-btn is-ghost is-compact"
              [disabled]="last()"
              (click)="step(1)"
            >
              Вперёд →
            </button>
          </div>
        }
        @if (status()) {
          <p class="hint">{{ status() }}</p>
        }
      </footer>
    </dialog>
  `,
})
export class LookPickerComponent {
  private readonly api = inject(ProfessionsApi);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');
  private readonly field = viewChild<ElementRef<HTMLInputElement>>('field');
  private timer: ReturnType<typeof setTimeout> | null = null;

  readonly iconBase = input('');
  readonly picked = output<number>();

  readonly title = signal('Выбор внешнего вида');
  readonly itemClass = signal<number | null>(null);
  readonly itemSubclass = signal<number | null>(null);
  readonly scope = signal<'self' | 'class' | 'any'>('self');
  readonly query = signal('');
  readonly looks = signal<DisplayLook[]>([]);
  readonly total = signal(0);
  readonly page = signal(0);
  readonly status = signal('');

  readonly pages = computed(() => Math.max(1, Math.ceil(this.total() / PAGE)));
  readonly last = computed(() => (this.page() + 1) * PAGE >= this.total());
  readonly range = computed(() => {
    const from = this.looks().length ? this.page() * PAGE + 1 : 0;
    return `${from}–${this.page() * PAGE + this.looks().length} из ${this.total()}`;
  });

  open(options: { title: string; itemClass?: number; itemSubclass?: number }): void {
    this.title.set(options.title);
    this.itemClass.set(options.itemClass ?? null);
    this.itemSubclass.set(options.itemSubclass ?? null);
    this.scope.set(options.itemClass === undefined ? 'any' : 'self');
    this.query.set('');
    this.page.set(0);
    this.dialog().nativeElement.showModal();
    this.field()?.nativeElement.focus();
    void this.load();
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  onClose(): void {
    this.looks.set([]);
  }

  onQuery(value: string): void {
    this.query.set(value);
    if (this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      this.page.set(0);
      void this.load();
    }, 350);
  }

  onScope(value: 'self' | 'class' | 'any'): void {
    this.scope.set(value);
    this.page.set(0);
    void this.load();
  }

  step(delta: number): void {
    this.page.update((page) => Math.max(0, page + delta));
    void this.load();
  }

  choose(look: DisplayLook): void {
    this.picked.emit(look.display_id);
    this.close();
  }

  src(look: DisplayLook): string {
    return iconUrl(look.icon, this.iconBase());
  }

  onIconError(event: Event): void {
    useBlankIcon(event);
  }

  private async load(): Promise<void> {
    this.status.set('Загрузка…');
    const mode = this.itemClass() === null ? 'any' : this.scope();
    try {
      const found = await firstValueFrom(
        this.api.displays({
          q: this.query().trim(),
          itemClass: mode === 'any' ? undefined : this.itemClass()!,
          itemSubclass:
            mode === 'self' && this.itemSubclass() !== null ? this.itemSubclass()! : undefined,
          limit: PAGE,
          offset: this.page() * PAGE,
        }),
      );
      this.looks.set(found.displays ?? []);
      this.total.set(found.total ?? this.looks().length);
      this.status.set(this.looks().length ? '' : 'Ничего не нашлось.');
    } catch (error) {
      this.looks.set([]);
      this.total.set(0);
      this.status.set(apiError(error, 'Поиск видов не ответил.'));
    }
  }
}
