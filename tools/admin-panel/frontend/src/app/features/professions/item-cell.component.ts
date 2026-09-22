import { Component, computed, input } from '@angular/core';
import { ItemBrief } from './professions.api';
import { BLANK_ICON, iconUrl, useBlankIcon } from './professions.model';

/**
 * Предмет в строке списка: иконка, имя качеством и номер.
 *
 * Отдельный случай - предмета в `item_template` НЕТ. Запись тогда ссылается в
 * пустоту, и в игре это выглядит как «крафт молча не работает», поэтому ячейка
 * об этом кричит, а не показывает пустое место.
 */
@Component({
  selector: 'app-prof-item',
  styleUrl: './item-cell.component.scss',
  template: `
    <img [src]="src()" width="28" height="28" alt="" loading="lazy" (error)="onError($event)" />
    <span class="nm">
      @if (item(); as row) {
        <b [class]="'q' + row.quality" [title]="row.name">{{ row.name }}</b>
        <small>id {{ row.entry }}</small>
      } @else {
        <b class="warn">{{ entry() ? 'предмета нет' : empty() }}</b>
        @if (entry()) {
          <small>id {{ entry() }}</small>
        }
      }
    </span>
  `,
})
export class ProfItemComponent {
  readonly item = input<ItemBrief | null>(null);
  readonly entry = input(0);
  readonly iconBase = input('');
  /** Что писать, когда предмет и не выбирался. */
  readonly empty = input('не выбран');

  readonly src = computed(() =>
    this.item() ? iconUrl(this.item()!.icon, this.iconBase()) : BLANK_ICON,
  );

  onError(event: Event): void {
    useBlankIcon(event);
  }
}
