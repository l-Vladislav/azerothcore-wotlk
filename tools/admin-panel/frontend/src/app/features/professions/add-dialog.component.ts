import { Component, ElementRef, input, output, viewChild } from '@angular/core';
import { IconComponent } from '../../shared/ui/icon.component';

/**
 * Окно «завести новую запись» для страниц профессий.
 *
 * Раньше поля добавления стояли над листом постоянной полосой и занимали
 * место, даже когда добавлять нечего. Теперь они в окне, которое открывает
 * кнопка в шапке страницы; сами поля по-прежнему описывает страница
 * (`<ng-content>`), окно даёт только оправу, ошибку и кнопки.
 *
 * Закрывает окно СТРАНИЦА и только после удачной записи: отказ сервера
 * («нет имени», «предмет уже заведён») должен остаться перед глазами вместе с
 * заполненными полями. Ошибка показывается внутри окна - всплывающее
 * сообщение живёт под модальным слоем и было бы не видно.
 */
@Component({
  selector: 'app-add-dialog',
  imports: [IconComponent],
  styleUrl: './add-dialog.component.scss',
  template: `
    <dialog #dialog class="forge-dialog">
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

      <div class="body" (keydown.enter)="onEnter($event)">
        @if (error(); as text) {
          <p class="forge-alert is-error">{{ text }}</p>
        }
        <ng-content />
      </div>

      <footer>
        <button type="button" class="forge-btn is-ghost is-compact" (click)="close()">
          Отмена
        </button>
        <button
          type="button"
          class="forge-btn is-primary is-compact"
          [disabled]="busy()"
          (click)="submitted.emit()"
        >
          {{ submitLabel() }}
        </button>
      </footer>
    </dialog>
  `,
})
export class AddDialogComponent {
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');

  readonly title = input('Новая запись');
  readonly submitLabel = input('Добавить');
  readonly busy = input(false);
  readonly error = input<string | null>(null);
  readonly submitted = output<void>();

  open(): void {
    const dialog = this.dialog().nativeElement;
    dialog.showModal();
    dialog.querySelector<HTMLElement>('.body input:not([type="checkbox"])')?.focus();
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  /** Enter в текстовом поле - «Добавить», как было в полосе. В списке и на кнопке он свой. */
  onEnter(event: Event): void {
    const target = event.target as HTMLElement;
    if (target.tagName !== 'INPUT' || (target as HTMLInputElement).type === 'checkbox') return;
    event.preventDefault();
    if (!this.busy()) this.submitted.emit();
  }
}
