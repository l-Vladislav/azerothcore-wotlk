import { Component, computed, input, output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ForgeSelectDirective } from '../ui/forge-select.directive';
import { IconComponent } from '../ui/icon.component';

const SIZES = [10, 25, 50, 100];

/**
 * Подвал таблицы: страницы, «Показано 1-10 из 9004» и выбор размера страницы.
 *
 * Один на все таблицы панели. Раньше эта разметка жила копиями в «Людях и
 * доступе» и в витрине кита, и копии успели разойтись - в одной номера
 * страниц, в другой только «Назад/Вперёд».
 *
 * НОМЕРА СВОРАЧИВАЮТСЯ. Показывать их все нельзя: у списка существ девять
 * тысяч строк, это девятьсот кнопок в подвале. Видны первая, последняя и
 * соседи текущей, между ними - многоточие.
 */
@Component({
  selector: 'app-table-pager',
  imports: [FormsModule, ForgeSelectDirective, IconComponent],
  styleUrl: './table-pager.component.scss',
  template: `
    <div class="table-foot">
      @if (lastPage() > 1) {
        <div class="pages">
          <button
            type="button"
            class="forge-page-btn is-prev"
            [disabled]="page() <= 1"
            aria-label="Предыдущая страница"
            (click)="go(page() - 1)"
          >
            <app-icon class="back" tone="plain" name="caret-right" [size]="11" />
          </button>
          @for (slot of slots(); track $index) {
            @if (slot) {
              <button
                type="button"
                class="forge-page-btn"
                [class.is-current]="slot === page()"
                (click)="go(slot)"
              >
                {{ slot }}
              </button>
            } @else {
              <span class="gap">…</span>
            }
          }
          <button
            type="button"
            class="forge-page-btn is-next"
            [disabled]="page() >= lastPage()"
            aria-label="Следующая страница"
            (click)="go(page() + 1)"
          >
            <app-icon tone="plain" name="caret-right" [size]="11" />
          </button>
        </div>
      }
      <span class="summary">{{ range() }}</span>
      <select
        class="forge-field is-select"
        [ngModel]="perPage()"
        (ngModelChange)="perPageChange.emit(+$event)"
        aria-label="Строк на странице"
      >
        @for (size of sizes(); track size) {
          <option [value]="size">по {{ size }}</option>
        }
      </select>
    </div>
  `,
})
export class TablePagerComponent {
  readonly total = input.required<number>();
  readonly page = input(1);
  readonly perPage = input(10);
  readonly sizes = input<readonly number[]>(SIZES);
  readonly pageChange = output<number>();
  readonly perPageChange = output<number>();

  readonly lastPage = computed(() => Math.max(1, Math.ceil(this.total() / this.perPage())));

  /** Номера страниц; `null` - многоточие между ними. */
  readonly slots = computed<(number | null)[]>(() => {
    const last = this.lastPage();
    const here = Math.min(Math.max(1, this.page()), last);
    if (last <= 7) return Array.from({ length: last }, (_, index) => index + 1);
    const near = new Set([1, last, here, here - 1, here + 1]);
    if (here <= 3) [2, 3, 4].forEach((n) => near.add(n));
    if (here >= last - 2) [last - 3, last - 2, last - 1].forEach((n) => near.add(n));
    const out: (number | null)[] = [];
    let previous = 0;
    for (const number of [...near].filter((n) => n >= 1 && n <= last).sort((a, b) => a - b)) {
      if (previous && number - previous > 1) out.push(null);
      out.push(number);
      previous = number;
    }
    return out;
  });

  readonly range = computed(() => {
    const total = this.total();
    if (!total) return 'Пусто';
    const from = (this.page() - 1) * this.perPage() + 1;
    const to = Math.min(total, this.page() * this.perPage());
    return `Показано ${from}-${to} из ${total}`;
  });

  go(page: number): void {
    const next = Math.min(Math.max(1, page), this.lastPage());
    if (next !== this.page()) this.pageChange.emit(next);
  }
}
