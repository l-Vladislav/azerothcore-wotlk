import { Component, OnDestroy, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { AuditApi, AuditEntry, AuditMeta } from './audit.api';
import { ForgeSelectDirective } from '../../../shared/ui/forge-select.directive';
import { ToastService } from '../../../shared/ui/toast.service';

// Сразу видно последние пять записей: журнал - это «что изменилось только
// что», а не лента для чтения. Остальное открывается кнопкой, и открывается
// уже пачками по двадцать - иначе до вчерашнего дня пришлось бы дожимать
// пятёрками.
const firstPage = 5;
const morePage = 20;

@Component({
  imports: [FormsModule, ForgeSelectDirective],
  providers: [AuditApi],
  selector: 'app-audit-page',
  styleUrl: './audit.page.scss',
  templateUrl: './audit.page.html',
})
export class AuditPage implements OnInit, OnDestroy {
  private readonly api = inject(AuditApi);
  private readonly toast = inject(ToastService);
  private searchTimer: ReturnType<typeof setTimeout> | undefined;
  private requestId = 0;

  readonly meta = signal<AuditMeta | null>(null);
  readonly entries = signal<readonly AuditEntry[]>([]);
  readonly loading = signal(true);
  readonly loadingMore = signal(false);
  readonly hasMore = signal(false);

  filters = { area: '', actor: '', q: '', failures: false };

  async ngOnInit(): Promise<void> {
    await this.refresh();
  }

  ngOnDestroy(): void {
    clearTimeout(this.searchTimer);
    ++this.requestId;
  }

  async refresh(): Promise<void> {
    this.loading.set(true);
    try {
      this.meta.set(await firstValueFrom(this.api.meta()));
      await this.load();
    } catch (error) {
      this.toast.show(this.errorText(error, 'Не удалось загрузить журнал изменений.'), 'error');
    } finally {
      this.loading.set(false);
    }
  }

  scheduleLoad(): void {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => void this.load(), 250);
  }

  async load(append = false): Promise<void> {
    const requestId = ++this.requestId;
    const beforeId = append ? (this.entries().at(-1)?.id ?? 0) : 0;
    const limit = append ? morePage : firstPage;
    if (append) this.loadingMore.set(true);
    else this.entries.set([]);
    try {
      const rows = await firstValueFrom(this.api.entries({ ...this.filters, beforeId }, limit));
      if (requestId !== this.requestId) return;
      this.entries.update((current) => (append ? [...current, ...rows] : rows));
      this.hasMore.set(rows.length === limit);
    } catch (error) {
      if (requestId === this.requestId) {
        this.toast.show(this.errorText(error, 'Не удалось загрузить журнал изменений.'), 'error');
      }
    } finally {
      if (requestId === this.requestId) this.loadingMore.set(false);
    }
  }

  toggleFailures(): void {
    this.filters.failures = !this.filters.failures;
    void this.load();
  }

  formatDate(value: string): string {
    const date = new Date(value.replace(' ', 'T'));
    return Number.isNaN(date.getTime()) ? value : date.toLocaleString('ru-RU');
  }

  actorName(entry: AuditEntry): string {
    return entry.actor_name || entry.actor_login || 'неизвестно';
  }

  prettyPayload(value: string): string {
    try {
      return JSON.stringify(JSON.parse(value), null, 2);
    } catch {
      return value;
    }
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
