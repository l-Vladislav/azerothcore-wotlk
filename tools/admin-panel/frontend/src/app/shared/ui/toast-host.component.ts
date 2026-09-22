import { Component, inject } from '@angular/core';
import { ToastService } from './toast.service';

/**
 * Полоса всплывающих сообщений внизу по центру. Сама ничего не решает:
 * показывает то, что положили в `ToastService`, и пропускает мышь сквозь
 * себя везде, кроме самих плашек.
 */
@Component({
  selector: 'app-toast-host',
  styleUrl: './toast-host.component.scss',
  template: `
    <div class="toasts" role="status" aria-live="polite">
      @for (toast of toasts.toasts(); track toast.id) {
        <button
          type="button"
          class="toast"
          [class.error]="toast.kind === 'error'"
          [class.fading]="toast.fading"
          (click)="toasts.dismiss(toast.id)"
          title="Убрать сообщение"
        >
          {{ toast.text }}
        </button>
      }
    </div>
  `,
})
export class ToastHostComponent {
  readonly toasts = inject(ToastService);
}
