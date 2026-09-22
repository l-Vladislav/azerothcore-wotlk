import { Component, input, output } from '@angular/core';
import { IconComponent } from './icon.component';

/**
 * Замок в углу карточки: пока заперт, поля видно, но не тронуть.
 *
 * Зачем он вообще: карточку открывают, чтобы ПОСМОТРЕТЬ, а правят изредка -
 * и промахнуться мимо поля в чужой записи неприятно. Поэтому правка включается
 * осознанно, одним нажатием, и так же выключается.
 *
 * Замка нет у того, чего ещё нет в базе: черновик копии правят сразу, запирать
 * там нечего.
 */
@Component({
  selector: 'app-edit-lock',
  imports: [IconComponent],
  template: `
    <button
      type="button"
      class="edit-lock"
      [class.open]="!locked()"
      [attr.aria-pressed]="!locked()"
      [title]="
        locked()
          ? 'Правка выключена. Нажмите, чтобы разрешить'
          : 'Правка включена. Нажмите, чтобы запереть'
      "
      (click)="toggled.emit(!locked())"
    >
      <app-icon [name]="locked() ? 'lock' : 'unlock'" [size]="16" />
      <span>{{ locked() ? 'Заперто' : 'Правка' }}</span>
    </button>
  `,
  styles: `
    :host {
      display: inline-flex;
    }
    .edit-lock {
      align-items: center;
      background: #0a0a0acc;
      border: 1px solid #4a4438;
      border-radius: 3px;
      color: var(--muted);
      cursor: pointer;
      display: inline-flex;
      font: 12px var(--serif);
      gap: 6px;
      padding: 4px 9px;
      text-shadow: none;
    }
    .edit-lock:hover {
      border-color: var(--edge-gold);
      color: var(--gold-bright);
    }
    .edit-lock.open {
      border-color: var(--gold-dim);
      color: var(--gold);
    }
  `,
})
export class EditLockComponent {
  readonly locked = input(true);
  readonly toggled = output<boolean>();
}
