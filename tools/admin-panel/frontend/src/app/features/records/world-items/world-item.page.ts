import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, ParamMap, Router, RouterLink } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../../core/auth.service';
import { IconComponent } from '../../../shared/ui/icon.component';
import { ToastService } from '../../../shared/ui/toast.service';
import { WorldItemPlacement, WorldItemsApi } from './world-items.api';

const blankIcon = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

type Draft = Pick<
  WorldItemPlacement,
  'item_entry' | 'item_count' | 'respawn_secs' | 'one_per_char' | 'enabled' | 'comment'
>;

/**
 * Одно размещение: где оно стоит, что отдаёт и кому уже отдало.
 *
 * Своей ручки на одно размещение у сервера нет - берём список и находим в нём
 * строку. Их десятки, а не тысячи, и заводить ради карточки вторую ручку с
 * тем же SQL значило бы держать два места, где строка собирается по-разному.
 */
@Component({
  imports: [FormsModule, RouterLink, IconComponent],
  providers: [WorldItemsApi],
  selector: 'app-world-item-page',
  styleUrl: './world-item.page.scss',
  templateUrl: './world-item.page.html',
})
export class WorldItemPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(WorldItemsApi);
  private readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  private readonly params = toSignal(this.route.paramMap, {
    initialValue: this.route.snapshot.paramMap,
  });

  readonly row = signal<WorldItemPlacement | null>(null);
  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);
  readonly iconBaseUrl = signal('');
  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');
  readonly title = computed(() => {
    const row = this.row();
    if (!row) return 'Размещение';
    return row.item_missing ? `Предмета ${row.item_entry} больше нет` : row.item_name;
  });

  draft: Draft = {
    item_entry: 0,
    item_count: 1,
    respawn_secs: 0,
    one_per_char: false,
    enabled: true,
    comment: '',
  };

  constructor() {
    this.toast.announce(this.error, 'error');
    this.toast.announce(this.notice);
    effect(() => {
      const params = this.params();
      untracked(() => void this.load(params));
    });
  }

  private async load(params: ParamMap): Promise<void> {
    this.loading.set(true);
    try {
      if (!this.iconBaseUrl()) {
        try {
          const meta = await firstValueFrom(this.api.meta());
          this.iconBaseUrl.set(meta.icon_base_url ?? '');
        } catch {
          // Без адреса иконок карточка работает - просто без картинки.
        }
      }

      const id = Number(params.get('id'));
      if (!Number.isSafeInteger(id) || id <= 0) {
        this.row.set(null);
        return;
      }
      const response = await firstValueFrom(this.api.list(false));
      this.apply(response.items.find((item) => item.id === id) ?? null);
    } catch (error) {
      this.row.set(null);
      this.error.set(this.errorText(error, 'Не удалось открыть размещение.'));
    } finally {
      this.loading.set(false);
    }
  }

  private apply(row: WorldItemPlacement | null): void {
    this.row.set(row);
    if (!row) return;
    this.draft = {
      item_entry: row.item_entry,
      item_count: row.item_count,
      respawn_secs: row.respawn_secs,
      one_per_char: row.one_per_char,
      enabled: row.enabled,
      comment: row.comment,
    };
  }

  async save(): Promise<void> {
    const row = this.row();
    if (!row || !this.canEdit() || this.saving()) return;
    this.saving.set(true);
    try {
      const saved = await firstValueFrom(
        this.api.update(row.id, {
          item_entry: Math.max(1, Number(this.draft.item_entry) || 1),
          item_count: Math.max(1, Number(this.draft.item_count) || 1),
          respawn_secs: Math.max(0, Number(this.draft.respawn_secs) || 0),
          one_per_char: this.draft.one_per_char,
          enabled: this.draft.enabled,
          comment: this.draft.comment,
        }),
      );
      this.apply(saved);
      this.notice.set(`Размещение #${row.id} сохранено.`);
    } catch (error) {
      this.error.set(this.errorText(error, `Не удалось сохранить размещение #${row.id}.`));
    } finally {
      this.saving.set(false);
    }
  }

  async resetLoot(): Promise<void> {
    const row = this.row();
    if (!row || !this.canEdit() || this.saving()) return;
    if (!confirm(`Забыть всех, кто забрал размещение #${row.id}?`)) return;
    this.saving.set(true);
    try {
      const result = await firstValueFrom(this.api.resetLoot(row.id));
      this.notice.set(`Забыто записей: ${result.forgotten}.`);
      await this.load(this.route.snapshot.paramMap);
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось сбросить список подобравших.'));
    } finally {
      this.saving.set(false);
    }
  }

  async remove(): Promise<void> {
    const row = this.row();
    if (!row || !this.canEdit() || this.saving()) return;
    if (!confirm(`Удалить размещение #${row.id}? Объект останется стоять в игровом мире.`)) return;
    this.saving.set(true);
    try {
      await firstValueFrom(this.api.delete(row.id));
      this.notice.set(`Размещение #${row.id} удалено.`);
      void this.router.navigate(['/catalog/world-items']);
    } catch (error) {
      this.error.set(this.errorText(error, `Не удалось удалить размещение #${row.id}.`));
    } finally {
      this.saving.set(false);
    }
  }

  iconUrl(row: WorldItemPlacement): string {
    return row.item_icon && this.iconBaseUrl()
      ? `${this.iconBaseUrl()}/${row.item_icon}.jpg`
      : blankIcon;
  }

  useBlankIcon(event: Event): void {
    (event.target as HTMLImageElement).src = blankIcon;
  }

  coords(row: WorldItemPlacement): string {
    return row.pos.map((value) => value.toFixed(1)).join(' ');
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
