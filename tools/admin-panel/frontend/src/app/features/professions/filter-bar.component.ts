import { Component, input } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { FilterState, PickOption } from './list-view';

/**
 * Полоса отбора: поиск, выпадающие отборы, сброс и действия листа.
 *
 * Счёта строк тут нет: его показывает подвал таблицы (`app-table-pager`), и
 * два счёта над и под листом повторяли друг друга.
 */
@Component({
  selector: 'app-prof-filters',
  imports: [FormsModule, ForgeSelectDirective],
  styleUrl: './filter-bar.component.scss',
  template: `
    <div class="filters">
      <input
        class="forge-field is-small is-search"
        type="search"
        [placeholder]="placeholder()"
        [ngModel]="view().query()"
        (ngModelChange)="view().onQuery($event)"
      />
      @for (pick of picks(); track pick.key) {
        <select
          class="forge-field is-small is-select"
          [title]="pick.label"
          [ngModel]="view().picked()[pick.key] ?? ''"
          (ngModelChange)="view().onPick(pick.key, $event)"
        >
          <option value="">{{ pick.label }}</option>
          @for (option of pick.options; track option[0]) {
            <option [value]="option[0]">{{ option[1] }}</option>
          }
        </select>
      }
      @if (view().dirty()) {
        <button type="button" class="forge-btn is-ghost is-compact" (click)="view().reset()">
          Сбросить
        </button>
      }
      <!-- Действия листа («Добавить») - у правого края, над таблицей. -->
      <span class="actions"><ng-content /></span>
    </div>
  `,
})
export class ProfFiltersComponent {
  readonly view = input.required<FilterState>();
  readonly picks = input<readonly PickOption[]>([]);
  readonly placeholder = input('поиск');
}
