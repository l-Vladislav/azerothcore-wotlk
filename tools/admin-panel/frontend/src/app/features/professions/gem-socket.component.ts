import { Component, computed, input, output } from '@angular/core';
import { Material } from './professions.api';
import { BLANK_ICON, iconUrl, useBlankIcon } from './professions.model';

/**
 * Одно гнездо набора: картинка камня и его имя.
 *
 * Гнёздами, а не рядом выпадающих списков: камни в игре различаются цветом и
 * картинкой, а в узком `select` от них остаётся обрезанное имя. В игре тот же
 * набор игрок собирает иконками, и панель должна показывать то же самое.
 */
@Component({
  selector: 'app-gem-socket',
  styleUrl: './gem-socket.component.scss',
  host: {
    '[class.is-empty]': '!entry()',
  },
  template: `
    <button
      type="button"
      class="socket"
      [disabled]="disabled()"
      [title]="
        entry()
          ? 'Сменить вставку или убрать её из набора'
          : 'Выбрать вставку. Пустое гнездо в набор не входит: «малахит и цитрин» в трёх гнёздах - это набор из двух'
      "
      (click)="pick.emit()"
    >
      <img [src]="src()" width="28" height="28" alt="" (error)="onError($event)" />
      <span class="nm">{{ label() }}</span>
    </button>
  `,
})
export class GemSocketComponent {
  readonly entry = input(0);
  readonly material = input<Material | null>(null);
  readonly iconBase = input('');
  readonly disabled = input(false);
  readonly pick = output<void>();

  readonly src = computed(() => {
    const mat = this.material();
    return mat?.item?.icon ? iconUrl(mat.item.icon, this.iconBase()) : BLANK_ICON;
  });

  readonly label = computed(() => {
    if (!this.entry()) return 'пусто';
    const mat = this.material();
    return mat?.name_ru || mat?.item?.name || String(this.entry());
  });

  onError(event: Event): void {
    useBlankIcon(event);
  }
}
