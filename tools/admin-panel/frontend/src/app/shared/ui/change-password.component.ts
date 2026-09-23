import { Component, ElementRef, inject, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { IconComponent } from './icon.component';
import { firstValueFrom } from 'rxjs';
import { ApiService } from '../../core/api.service';

/**
 * Changing a password closes every other session, so it says so before it is
 * done rather than after.
 */
@Component({
  selector: 'app-change-password',
  imports: [FormsModule, IconComponent],
  styleUrl: './change-password.component.scss',
  template: `
    <dialog #dialog class="forge-dialog" (close)="reset()">
      <form (submit)="save($event)">
        <header>
          <h2>Смена пароля</h2>
          <button
            type="button"
            class="forge-btn is-icon close"
            aria-label="Закрыть"
            (click)="close()"
          >
            <app-icon name="close" [size]="13" />
          </button>
        </header>
        <label>
          <span>Текущий пароль</span>
          <input
            class="forge-field"
            #first
            type="password"
            [(ngModel)]="current"
            name="current"
            autocomplete="current-password"
            required
          />
        </label>
        <label>
          <span>Новый пароль</span>
          <input
            class="forge-field"
            type="password"
            [(ngModel)]="next"
            name="next"
            autocomplete="new-password"
            minlength="8"
            required
          />
        </label>
        <label>
          <span>Новый пароль ещё раз</span>
          <input
            class="forge-field"
            type="password"
            [(ngModel)]="repeat"
            name="repeat"
            autocomplete="new-password"
            required
          />
        </label>
        @if (error()) {
          <p class="error" role="alert">{{ error() }}</p>
        }
        @if (done()) {
          <p class="done" role="status">Пароль изменён; остальные сессии закрыты.</p>
        }
        <footer>
          <button type="submit" class="forge-btn is-primary is-compact" [disabled]="saving()">
            Сменить
          </button>
          <button type="button" class="forge-btn is-ghost is-compact" (click)="close()">
            Закрыть
          </button>
        </footer>
      </form>
    </dialog>
  `,
})
export class ChangePasswordComponent {
  private readonly api = inject(ApiService);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');
  private readonly first = viewChild<ElementRef<HTMLInputElement>>('first');

  readonly saving = signal(false);
  readonly error = signal<string | null>(null);
  readonly done = signal(false);
  current = '';
  next = '';
  repeat = '';

  open(): void {
    this.reset();
    this.dialog().nativeElement.showModal();
    this.first()?.nativeElement.focus();
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  reset(): void {
    this.current = '';
    this.next = '';
    this.repeat = '';
    this.error.set(null);
    this.done.set(false);
  }

  async save(event: Event): Promise<void> {
    event.preventDefault();
    if (this.next.length < 8) {
      this.error.set('Новый пароль короче восьми знаков.');
      return;
    }
    if (this.next !== this.repeat) {
      this.error.set('Пароли не совпадают.');
      return;
    }
    this.saving.set(true);
    try {
      await firstValueFrom(
        this.api.post('/auth/password', { current: this.current, password: this.next }),
      );
      this.done.set(true);
      this.error.set(null);
      this.current = '';
      this.next = '';
      this.repeat = '';
    } catch (error) {
      const detail = (error as { error?: { detail?: unknown } })?.error?.detail;
      this.error.set(typeof detail === 'string' ? detail : 'Пароль сменить не удалось.');
    } finally {
      this.saving.set(false);
    }
  }
}
