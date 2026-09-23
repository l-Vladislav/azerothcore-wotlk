import {
  Component,
  ElementRef,
  computed,
  inject,
  input,
  output,
  signal,
  viewChild,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { IconComponent } from './icon.component';
import { firstValueFrom } from 'rxjs';
import { ApiService } from '../../core/api.service';

interface IconEntry {
  id: number;
  texture: string;
}

const SHOWN = 240;

/**
 * Every icon the client knows, as pictures. Typing `spell_frost_frostward`
 * from memory is the thing this replaces.
 */
@Component({
  selector: 'app-icon-picker',
  imports: [FormsModule, IconComponent],
  styleUrl: './icon-picker.component.scss',
  template: `
    <dialog #dialog class="forge-dialog">
      <header>
        <h2>Иконка</h2>
        <button
          type="button"
          class="forge-btn is-icon close"
          aria-label="Закрыть"
          (click)="close()"
        >
          <app-icon name="close" [size]="14" />
        </button>
      </header>
      <div class="search">
        <input
          #field
          class="forge-field is-search"
          type="search"
          placeholder="часть имени: frost, holy, sword…"
          [ngModel]="query()"
          (ngModelChange)="query.set($event)"
          aria-label="Поиск иконки"
        />
        <span class="count">{{ countLabel() }}</span>
      </div>
      <div class="grid">
        @if (loading()) {
          <p class="muted">Читаем DBC…</p>
        } @else if (error()) {
          <p class="error">{{ error() }}</p>
        } @else {
          @for (icon of shown(); track icon.id) {
            <button
              type="button"
              class="icon-cell"
              [class.chosen]="icon.texture === current()"
              [title]="icon.texture"
              (click)="choose(icon)"
            >
              <img [src]="url(icon.texture)" width="36" height="36" alt="" (error)="hide($event)" />
              <small>{{ icon.texture }}</small>
            </button>
          }
        }
      </div>
    </dialog>
  `,
})
export class IconPickerComponent {
  private readonly api = inject(ApiService);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');
  private readonly field = viewChild<ElementRef<HTMLInputElement>>('field');

  readonly current = input('');
  readonly picked = output<string>();

  readonly query = signal('');
  readonly icons = signal<IconEntry[]>([]);
  readonly base = signal('');
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);

  /** The list is thousands long: filter here, draw the first screenful. */
  readonly matched = computed(() => {
    const needle = this.query().trim().toLocaleLowerCase();
    return needle ? this.icons().filter((icon) => icon.texture.includes(needle)) : this.icons();
  });
  readonly shown = computed(() => this.matched().slice(0, SHOWN));
  readonly countLabel = computed(() => {
    const total = this.matched().length;
    return total > SHOWN ? `показаны ${SHOWN} из ${total}` : `иконок: ${total}`;
  });

  async open(): Promise<void> {
    this.dialog().nativeElement.showModal();
    this.field()?.nativeElement.focus();
    if (this.icons().length) return;
    this.loading.set(true);
    try {
      const page = await firstValueFrom(
        this.api.get<{ items: IconEntry[]; icon_base_url: string }>('/icons'),
      );
      this.icons.set(page.items ?? []);
      this.base.set(page.icon_base_url ?? '');
      this.error.set(null);
    } catch {
      this.error.set('Иконки недоступны: каталог DBC не примонтирован.');
    } finally {
      this.loading.set(false);
    }
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  choose(icon: IconEntry): void {
    this.picked.emit(icon.texture);
    this.close();
  }

  url(texture: string): string {
    return this.base() ? `${this.base()}/${texture}.jpg` : '';
  }

  hide(event: Event): void {
    (event.target as HTMLImageElement).style.visibility = 'hidden';
  }
}
