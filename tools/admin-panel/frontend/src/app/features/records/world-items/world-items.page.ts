import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { TablePagerComponent } from '../../../shared/data/table-pager.component';
import { ToastService } from '../../../shared/ui/toast.service';
import { WorldItemPlacement, WorldItemsApi } from './world-items.api';

const blankIcon = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

/**
 * Что разложено по карте - таблицей; одно размещение правится на своей
 * подстранице.
 *
 * Прежде вся правка шла прямо в строке: двенадцать колонок, в семи из них
 * поля ввода, и таблица не влезала в экран - под ней всегда была вторая полоса
 * прокрутки. Таблица теперь только показывает, а меняет карточка.
 */
@Component({
  imports: [FormsModule, TablePagerComponent],
  providers: [WorldItemsApi],
  selector: 'app-world-items-page',
  styleUrl: './world-items.page.scss',
  templateUrl: './world-items.page.html',
})
export class WorldItemsPage implements OnInit {
  private readonly toast = inject(ToastService);
  private readonly api = inject(WorldItemsApi);
  private readonly router = inject(Router);
  private requestId = 0;

  readonly rows = signal<readonly WorldItemPlacement[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly onlyEnabled = signal(false);
  readonly filter = signal('');
  readonly page = signal(1);
  readonly perPage = signal(10);
  readonly iconBaseUrl = signal('');

  readonly filtered = computed(() => {
    const needle = this.filter().trim().toLocaleLowerCase();
    if (!needle) return this.rows();
    return this.rows().filter(
      (row) =>
        row.item_name.toLocaleLowerCase().includes(needle) ||
        row.comment.toLocaleLowerCase().includes(needle) ||
        String(row.item_entry) === needle ||
        String(row.id) === needle,
    );
  });

  /** Строки текущей страницы: размещений на карте бывает много. */
  readonly pageRows = computed(() => {
    const rows = this.filtered();
    const last = Math.max(1, Math.ceil(rows.length / this.perPage()));
    const page = Math.min(Math.max(1, this.page()), last);
    return rows.slice((page - 1) * this.perPage(), page * this.perPage());
  });

  constructor() {
    // Сообщения об отказе показываются всплывающими плашками: строка наверху
    // страницы сдвигала содержимое и висела до следующего действия.
    this.toast.announce(this.error, 'error');
  }

  async ngOnInit(): Promise<void> {
    try {
      const meta = await firstValueFrom(this.api.meta());
      this.iconBaseUrl.set(meta.icon_base_url ?? '');
    } catch {
      // Адрес иконок необязателен: без него список работает, просто без картинок.
    }
    await this.load();
  }

  async load(): Promise<void> {
    const requestId = ++this.requestId;
    this.loading.set(true);
    try {
      const response = await firstValueFrom(this.api.list(this.onlyEnabled()));
      if (requestId !== this.requestId) return;
      this.rows.set(response.items);
      this.error.set(null);
    } catch (error) {
      if (requestId === this.requestId) {
        this.error.set(this.errorText(error, 'Не удалось загрузить размещения предметов.'));
      }
    } finally {
      if (requestId === this.requestId) this.loading.set(false);
    }
  }

  toggleOnlyEnabled(value: boolean): void {
    this.onlyEnabled.set(value);
    this.page.set(1);
    void this.load();
  }

  open(id: number): void {
    void this.router.navigate(['/catalog/world-items', id]);
  }

  iconUrl(row: WorldItemPlacement): string {
    return row.item_icon && this.iconBaseUrl()
      ? `${this.iconBaseUrl()}/${row.item_icon}.jpg`
      : blankIcon;
  }

  useBlankIcon(event: Event): void {
    const image = event.target as HTMLImageElement;
    image.src = blankIcon;
  }

  place(row: WorldItemPlacement): string {
    return `карта ${row.map}, зона ${row.zone}`;
  }

  private errorText(error: unknown, fallback: string): string {
    if (typeof error === 'object' && error && 'error' in error) {
      const body = (error as { error?: unknown }).error;
      if (typeof body === 'object' && body && 'detail' in body) {
        const detail = (body as { detail?: unknown }).detail;
        if (typeof detail === 'string') return detail;
      }
    }
    return fallback;
  }
}
