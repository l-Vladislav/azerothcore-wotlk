import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, ParamMap, Router, RouterLink } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { apiError } from './loot-format';
import { LootNameTagComponent } from './loot-name-tag.component';
import { LootTreeComponent } from './loot-tree.component';
import { LootApi, LootMeta, LootOwner, TableEntries, TableEntryDetail } from './loot.api';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { ToastService } from '../../shared/ui/toast.service';

@Component({
  providers: [LootApi],
  selector: 'app-loot-tables-page',
  imports: [FormsModule, RouterLink, LootTreeComponent, LootNameTagComponent, ForgeSelectDirective],
  styleUrl: './loot-tables.page.scss',
  templateUrl: './loot-tables.page.html',
})
export class LootTablesPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(LootApi);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  readonly auth = inject(AuthService);

  private readonly params = toSignal(this.route.queryParamMap, {
    initialValue: this.route.snapshot.queryParamMap,
  });
  private searchTimer: ReturnType<typeof setTimeout> | null = null;
  private lastList = '';
  private lastEntry = '';

  readonly meta = signal<LootMeta | null>(null);
  readonly list = signal<TableEntries | null>(null);
  readonly detail = signal<TableEntryDetail | null>(null);
  readonly loadingList = signal(false);
  readonly loadingDetail = signal(false);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  readonly table = signal('creature');
  readonly query = signal('');
  readonly entry = signal(0);
  readonly onlyNamed = signal('');
  readonly withRefs = signal('');
  readonly withGroups = signal('');

  readonly tables = computed(() => this.meta()?.tables ?? []);
  readonly current = computed(() => this.tables().find((table) => table.id === this.table()));
  readonly canEditRows = computed(() => this.auth.actor()?.role === 'owner');
  readonly canLabel = computed(() =>
    ['editor', 'owner'].includes(this.auth.actor()?.role ?? 'viewer'),
  );
  readonly filtersUsed = computed(
    () => !!(this.onlyNamed() || this.withRefs() || this.withGroups()),
  );

  readonly entries = computed(() => {
    const named = this.onlyNamed();
    const refs = this.withRefs();
    const groups = this.withGroups();
    return (this.list()?.entries ?? []).filter((row) => {
      if (named && (row.label?.name ? '1' : '0') !== named) return false;
      if (refs && (row.refs ? '1' : '0') !== refs) return false;
      if (groups && (row.grouped ? '1' : '0') !== groups) return false;
      return true;
    });
  });

  constructor() {
    this.toast.announce(this.error, 'error');
    this.toast.announce(this.notice);
    effect(() => {
      const params = this.params();
      untracked(() => this.applyParams(params));
    });
    void this.loadMeta();
  }

  private async loadMeta(): Promise<void> {
    try {
      this.meta.set(await firstValueFrom(this.api.meta()));
    } catch (error) {
      this.error.set(apiError(error, 'Таблиц добычи в этой базе нет.'));
    }
  }

  private applyParams(params: ParamMap): void {
    this.table.set(params.get('table') || 'creature');
    this.query.set(params.get('q') ?? '');
    this.entry.set(Number(params.get('entry')) || 0);

    const key = `${this.table()}|${this.query()}`;
    if (key !== this.lastList) {
      this.lastList = key;
      void this.loadList();
    }
    const entryKey = `${this.table()}|${this.entry()}`;
    if (entryKey !== this.lastEntry) {
      this.lastEntry = entryKey;
      void this.loadDetail();
    }
  }

  private patch(changes: Record<string, string | null>, replaceUrl = false): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: changes,
      queryParamsHandling: 'merge',
      replaceUrl,
    });
  }

  chooseTable(id: string): void {
    this.patch({ table: id, entry: null });
  }

  onQuery(value: string): void {
    this.query.set(value);
    if (this.searchTimer) clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => this.patch({ q: value || null }, true), 250);
  }

  select(entry: number): void {
    this.patch({ entry: String(entry) });
  }

  resetFilters(): void {
    this.onlyNamed.set('');
    this.withRefs.set('');
    this.withGroups.set('');
  }

  ownerLabel(owner: LootOwner): string {
    return `${owner.name_ru || owner.name || owner.entry} (${owner.entry})`;
  }

  async loadList(): Promise<void> {
    this.loadingList.set(true);
    try {
      this.list.set(await firstValueFrom(this.api.tableEntries(this.table(), this.query())));
      this.error.set(null);
    } catch (error) {
      this.list.set(null);
      this.error.set(apiError(error, 'Не удалось прочитать таблицу.'));
    } finally {
      this.loadingList.set(false);
    }
  }

  async loadDetail(): Promise<void> {
    const entry = this.entry();
    if (!entry) {
      this.detail.set(null);
      return;
    }
    this.loadingDetail.set(true);
    try {
      this.detail.set(await firstValueFrom(this.api.tableEntry(this.table(), entry)));
      this.error.set(null);
    } catch (error) {
      this.detail.set(null);
      this.error.set(apiError(error, `Не удалось прочитать запись ${entry}.`));
    } finally {
      this.loadingDetail.set(false);
    }
  }

  onNotice(message: string): void {
    this.notice.set(message);
  }

  async afterChange(): Promise<void> {
    await Promise.all([this.loadDetail(), this.loadList()]);
  }
}
