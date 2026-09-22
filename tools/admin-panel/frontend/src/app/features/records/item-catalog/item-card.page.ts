import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, ParamMap, Router, RouterLink } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../../core/auth.service';
import { CollapsibleSectionComponent } from '../../../shared/data/collapsible-section.component';
import { EditLockComponent } from '../../../shared/ui/edit-lock.component';
import { ForgeSelectDirective } from '../../../shared/ui/forge-select.directive';
import { IconComponent } from '../../../shared/ui/icon.component';
import { ToastService } from '../../../shared/ui/toast.service';
import {
  ClientRow,
  ItemCatalogApi,
  ItemDetail,
  ItemField,
  ItemFields,
  ItemMeta,
} from './item-catalog.api';

/**
 * Карточка одного предмета: свойства, клиентская строка и правка.
 *
 * Черновик копии живёт в АДРЕСЕ (`/catalog/items/new?clone=25&block=custom1`),
 * а не в памяти страницы: иначе обновление вкладки теряло бы заготовку, а
 * ссылку на «копию вот этого» некому было бы передать.
 */
@Component({
  providers: [ItemCatalogApi],
  imports: [
    FormsModule,
    RouterLink,
    IconComponent,
    EditLockComponent,
    CollapsibleSectionComponent,
    ForgeSelectDirective,
  ],
  selector: 'app-item-card-page',
  styleUrl: './item-card.page.scss',
  templateUrl: './item-card.page.html',
})
export class ItemCardPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ItemCatalogApi);
  private readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  private readonly params = toSignal(this.route.paramMap, {
    initialValue: this.route.snapshot.paramMap,
  });

  readonly meta = signal<ItemMeta | null>(null);
  readonly item = signal<ItemDetail | null>(null);
  readonly clientRow = signal<ClientRow | null>(null);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  /**
   * Замок: карточку открывают смотреть, а правят изредка. Заперт по
   * умолчанию, у черновика копии его нет вовсе - там править и так надо.
   */
  readonly locked = signal(true);
  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');
  readonly editable = computed(() => Boolean(this.item()?.block) && this.canEdit());
  readonly showLock = computed(() => this.editable() && !this.draft);
  readonly canEditNow = computed(() => this.editable() && (this.draft || !this.locked()));
  readonly title = computed(() => {
    const item = this.item();
    if (!item) return 'Предмет';
    return String(this.fields['name_ru'] || this.fields['name'] || `#${item.entry}`);
  });

  fields: ItemFields = {};
  draft = false;

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
      if (!this.meta()) this.meta.set(await firstValueFrom(this.api.meta()));

      const raw = params.get('entry') ?? '';
      const clone = Number(this.route.snapshot.queryParamMap.get('clone')) || 0;
      const block = this.route.snapshot.queryParamMap.get('block') ?? '';

      if (raw === 'new' && clone) {
        this.apply(await firstValueFrom(this.api.clone(clone, block)), true);
        return;
      }

      const entry = Number(raw);
      if (!Number.isSafeInteger(entry) || entry <= 0) {
        this.item.set(null);
        return;
      }
      this.apply(await firstValueFrom(this.api.detail(entry)), false);
    } catch {
      this.item.set(null);
      this.error.set('Не удалось открыть предмет.');
    } finally {
      this.loading.set(false);
    }
  }

  private apply(detail: ItemDetail, draft: boolean): void {
    this.clientRow.set(null);
    // Новая карточка - снова заперта; черновик правят сразу.
    this.locked.set(!draft);
    this.item.set(detail);
    this.fields = { ...detail.fields };
    this.draft = draft;
    this.error.set(null);
  }

  /** Клиентская половина предмета: строка, которой ждёт Item.dbc в MPQ. */
  async showClientRow(): Promise<void> {
    const item = this.item();
    if (!item) return;
    if (this.clientRow()) {
      this.clientRow.set(null);
      return;
    }
    try {
      this.clientRow.set(await firstValueFrom(this.api.clientRow(item.entry)));
    } catch {
      this.error.set('Клиентскую строку получить не удалось.');
    }
  }

  async copyClientRow(): Promise<void> {
    const row = this.clientRow();
    if (!row) return;
    try {
      await navigator.clipboard.writeText(`${row.header}\n${row.line}`);
      this.notice.set('Клиентская строка скопирована.');
    } catch {
      this.error.set('Буфер обмена недоступен - скопируйте строку вручную.');
    }
  }

  /** Копия - это новый адрес: черновик должен переживать обновление вкладки. */
  clone(block: string): void {
    const item = this.item();
    if (!item || !this.canEdit()) return;
    void this.router.navigate(['/catalog/items', 'new'], {
      queryParams: { clone: item.entry, block },
    });
  }

  async save(): Promise<void> {
    const item = this.item();
    if (!item || !this.editable()) return;
    try {
      const saved = await firstValueFrom(this.api.save(item.entry, this.fields));
      this.apply(saved, false);
      this.notice.set(`Предмет #${saved.entry} сохранён.`);
      // Черновик стал записью - адрес должен говорить о ней, а не о заготовке.
      if (!this.route.snapshot.paramMap.get('entry')?.match(/^\d+$/)) {
        void this.router.navigate(['/catalog/items', saved.entry], { replaceUrl: true });
      }
    } catch {
      this.error.set('Не удалось сохранить предмет. Проверьте заполнение полей.');
    }
  }

  async deleteItem(): Promise<void> {
    const item = this.item();
    if (!item || !this.editable() || !confirm(`Удалить предмет #${item.entry}?`)) return;
    try {
      await firstValueFrom(this.api.delete(item.entry));
      this.notice.set(`Предмет #${item.entry} удалён.`);
      void this.router.navigate(['/catalog/items']);
    } catch {
      this.error.set('Не удалось удалить предмет: возможно, он используется в крафте.');
    }
  }

  enumOptions(field: ItemField): Array<{ value: number; label: string }> {
    return this.meta()?.enums[field.options ?? ''] ?? [];
  }

  blockName(id?: string | null): string {
    if (!id) return 'стоковый предмет';
    return this.meta()?.blocks.find((block) => block.id === id)?.name ?? id;
  }

  iconUrl(icon?: string): string {
    const base = this.meta()?.icon_base_url;
    return icon && base ? `${base}/${icon}.jpg` : '';
  }
}
