import { Component, input, output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { IconComponent } from '../../shared/ui/icon.component';
import { iconUrl, useBlankIcon } from './professions.model';

/**
 * Ячейка «иконка + поле id + кнопка выбора».
 *
 * Поле id нужно не для удобства: `displayid` из собственного
 * ItemDisplayInfo.dbc (того, что приезжает в клиент через MPQ-патч) сервер не
 * знает, и в сетке выбора такой строки не будет. Вписать его руками -
 * единственный способ.
 */
@Component({
  selector: 'app-look-cell',
  imports: [FormsModule, IconComponent],
  styleUrl: './look-cell.component.scss',
  template: `
    <img [src]="src()" width="28" height="28" alt="" (error)="onError($event)" />
    <input
      class="forge-field is-small"
      type="number"
      min="0"
      [ngModel]="displayId()"
      [disabled]="disabled()"
      title="id модели (ItemDisplayInfo). Задаёт и иконку, и 3D-вид. Можно вписать свой id из MPQ - сервер его не проверяет."
      (change)="changed.emit(+$any($event.target).value || 0)"
    />
    <button
      type="button"
      class="forge-btn is-ghost is-icon is-compact"
      [disabled]="disabled()"
      title="Выбрать внешний вид из существующих предметов."
      aria-label="Выбрать внешний вид"
      (click)="pick.emit()"
    >
      <app-icon name="more" [size]="16" />
    </button>
    @if (clearable() && displayId()) {
      <button
        type="button"
        class="forge-btn is-ghost is-icon is-compact"
        [disabled]="disabled()"
        title="Вернуть внешний вид основы."
        aria-label="Вернуть внешний вид основы"
        (click)="changed.emit(0)"
      >
        <app-icon name="close" [size]="12" />
      </button>
    }
  `,
})
export class LookCellComponent {
  readonly icon = input('');
  readonly displayId = input(0);
  readonly iconBase = input('');
  readonly clearable = input(false);
  readonly disabled = input(false);
  readonly changed = output<number>();
  readonly pick = output<void>();

  src(): string {
    return iconUrl(this.icon(), this.iconBase());
  }

  onError(event: Event): void {
    useBlankIcon(event);
  }
}
