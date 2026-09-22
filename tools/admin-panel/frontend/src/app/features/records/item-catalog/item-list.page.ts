import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, ParamMap, Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { TablePagerComponent } from '../../../shared/data/table-pager.component';
import { ForgeSelectDirective } from '../../../shared/ui/forge-select.directive';
import { ToastService } from '../../../shared/ui/toast.service';
import { ItemCatalogApi, ItemMeta, ItemResult } from './item-catalog.api';

const PAGE_SIZES = [10, 25, 50, 100];
const DEFAULT_PER_PAGE = 10;

/**
 * Все предметы таблицей; свойства одного - на его подстранице.
 *
 * Прежде каталог был узким списком слева от карточки: в строке помещались имя
 * и номер, а качество, класс, слот и уровень - те самые признаки, по которым
 * предмет и ищут, - оставались невидимыми, хотя отбор по ним уже был.
 *
 * Отбор и листалка СЕРВЕРНЫЕ: в item_template четыреста тысяч строк, и
 * отбирать присланную страницу в браузере значит отбирать не из того.
 */
@Component({
  providers: [ItemCatalogApi],
  imports: [FormsModule, ForgeSelectDirective, TablePagerComponent],
  selector: 'app-item-list-page',
  styleUrl: './item-list.page.scss',
  templateUrl: './item-list.page.html',
})
export class ItemListPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ItemCatalogApi);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  private readonly params = toSignal(this.route.queryParamMap, {
    initialValue: this.route.snapshot.queryParamMap,
  });
  private searchTimer: ReturnType<typeof setTimeout> | null = null;
  private lastSearch = '';
  private requestId = 0;

  readonly meta = signal<ItemMeta | null>(null);
  readonly items = signal<ItemResult[]>([]);
  readonly total = signal(0);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);

  readonly query = signal('');
  readonly block = signal('');
  readonly quality = signal('');
  readonly itemClass = signal('');
  readonly slot = signal('');
  readonly levelMin = signal('');
  readonly levelMax = signal('');
  readonly requiredMin = signal('');
  readonly requiredMax = signal('');
  readonly offset = signal(0);
  readonly perPage = signal(DEFAULT_PER_PAGE);

  readonly page = computed(() => Math.floor(this.offset() / this.perPage()) + 1);
  readonly filtersUsed = computed(
    () =>
      !!(
        this.query() ||
        this.block() ||
        this.quality() ||
        this.itemClass() ||
        this.slot() ||
        this.levelMin() ||
        this.levelMax() ||
        this.requiredMin() ||
        this.requiredMax()
      ),
  );

  constructor() {
    this.toast.announce(this.error, 'error');
    effect(() => {
      const params = this.params();
      untracked(() => this.applyParams(params));
    });
    void this.loadMeta();
  }

  private async loadMeta(): Promise<void> {
    try {
      this.meta.set(await firstValueFrom(this.api.meta()));
    } catch {
      this.error.set('Не удалось получить блоки и списки значений каталога.');
    }
  }

  private applyParams(params: ParamMap): void {
    // Старый адрес карточки в отборе (`/catalog/items?open=25`) теперь ведёт
    // на саму карточку: ссылки из заметок не должны упираться в список.
    const legacy = Number(params.get('open')) || 0;
    if (legacy) {
      void this.router.navigate(['/catalog/items', legacy], { replaceUrl: true });
      return;
    }

    this.query.set(params.get('q') ?? '');
    this.block.set(params.get('block') ?? '');
    this.quality.set(params.get('quality') ?? '');
    this.itemClass.set(params.get('cls') ?? '');
    this.slot.set(params.get('slot') ?? '');
    this.levelMin.set(params.get('ilmin') ?? '');
    this.levelMax.set(params.get('ilmax') ?? '');
    this.requiredMin.set(params.get('rlmin') ?? '');
    this.requiredMax.set(params.get('rlmax') ?? '');
    this.offset.set(Math.max(0, Number(params.get('from')) || 0));
    this.perPage.set(
      PAGE_SIZES.includes(Number(params.get('per'))) ? Number(params.get('per')) : DEFAULT_PER_PAGE,
    );

    const key = [
      this.query(),
      this.block(),
      this.quality(),
      this.itemClass(),
      this.slot(),
      this.levelMin(),
      this.levelMax(),
      this.requiredMin(),
      this.requiredMax(),
      this.offset(),
      this.perPage(),
    ].join('|');
    if (key !== this.lastSearch) {
      this.lastSearch = key;
      void this.search();
    }
  }

  /** Отбор живёт в адресе: найденный предмет - это ссылка, а не состояние. */
  patch(changes: Record<string, string | null>, replaceUrl = false): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: changes,
      queryParamsHandling: 'merge',
      replaceUrl,
    });
  }

  onQuery(value: string): void {
    this.query.set(value);
    if (this.searchTimer) clearTimeout(this.searchTimer);
    // Новый отбор начинает список сначала: остаться на пятой странице чужого
    // поиска - значит увидеть пустую таблицу и решить, что ничего нет.
    this.searchTimer = setTimeout(() => this.patch({ q: value || null, from: null }, true), 250);
  }

  onLevel(from: string, to: string): void {
    this.patch({ ilmin: from || null, ilmax: to || null, from: null });
  }

  onRequired(from: string, to: string): void {
    this.patch({ rlmin: from || null, rlmax: to || null, from: null });
  }

  onPerPage(value: string | number): void {
    const per = String(value);
    this.patch({ per: Number(per) === DEFAULT_PER_PAGE ? null : per, from: null });
  }

  goToPage(page: number): void {
    const next = Math.max(0, (page - 1) * this.perPage());
    this.patch({ from: next ? String(next) : null });
  }

  resetFilters(): void {
    this.patch({
      q: null,
      block: null,
      quality: null,
      cls: null,
      slot: null,
      ilmin: null,
      ilmax: null,
      rlmin: null,
      rlmax: null,
      from: null,
    });
  }

  open(entry: number): void {
    void this.router.navigate(['/catalog/items', entry]);
  }

  enums(name: string): Array<{ value: number; label: string }> {
    return this.meta()?.enums[name] ?? [];
  }

  enumLabel(name: string, value: number): string {
    return this.enums(name).find((item) => item.value === value)?.label ?? '—';
  }

  blockName(id?: string | null): string {
    if (!id) return 'стоковый';
    return this.meta()?.blocks.find((block) => block.id === id)?.name ?? id;
  }

  iconUrl(icon?: string): string {
    const base = this.meta()?.icon_base_url;
    return icon && base ? `${base}/${icon}.jpg` : '';
  }

  async search(): Promise<void> {
    const requestId = ++this.requestId;
    this.loading.set(true);
    try {
      const page = await firstValueFrom(
        this.api.search({
          q: this.query(),
          block: this.block(),
          quality: this.quality(),
          itemClass: this.itemClass(),
          inventoryType: this.slot(),
          itemLevelMin: this.levelMin(),
          itemLevelMax: this.levelMax(),
          requiredLevelMin: this.requiredMin(),
          requiredLevelMax: this.requiredMax(),
          offset: this.offset(),
          limit: this.perPage(),
        }),
      );
      if (requestId !== this.requestId) return;
      this.items.set(page.items);
      this.total.set(page.total);
      this.error.set(null);
    } catch {
      if (requestId !== this.requestId) return;
      this.error.set('Поиск предметов не ответил.');
      this.items.set([]);
      this.total.set(0);
    } finally {
      if (requestId === this.requestId) this.loading.set(false);
    }
  }
}
