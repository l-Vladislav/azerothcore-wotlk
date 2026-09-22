import { Component, input, output } from '@angular/core';
import { ItemBrief } from './professions.api';
import { ProfItemComponent } from './item-cell.component';

/**
 * Предмет в строке плюс две кнопки: без них выбранный предмет некуда было бы
 * поменять. Сам поиск живёт на странице одним окном на весь лист - окно выбора
 * в каждой строке стоило бы сотню лишних узлов на строку.
 */
@Component({
  selector: 'app-prof-item-pick',
  imports: [ProfItemComponent],
  styleUrl: './item-pick-cell.component.scss',
  template: `
    @if (entry()) {
      <app-prof-item [item]="item()" [entry]="entry()" [iconBase]="iconBase()" />
    } @else {
      <span class="muted">{{ empty() }}</span>
    }
    @if (!readonly()) {
      <span class="act">
        <button type="button" class="forge-btn is-ghost is-compact" (click)="pick.emit()">
          {{ entry() ? 'Сменить' : 'Выбрать' }}
        </button>
        @if (entry() && !required()) {
          <button type="button" class="forge-btn is-ghost is-compact" (click)="changed.emit(0)">
            Убрать
          </button>
        }
        <ng-content />
      </span>
    }
  `,
})
export class ProfItemPickComponent {
  readonly item = input<ItemBrief | null>(null);
  readonly entry = input(0);
  readonly iconBase = input('');
  readonly empty = input('не задан');
  /** Предмет, без которого запись не имеет смысла: убрать его нельзя. */
  readonly required = input(false);
  readonly readonly = input(false);
  readonly pick = output<void>();
  readonly changed = output<number>();
}
