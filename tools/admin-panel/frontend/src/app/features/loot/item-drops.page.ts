import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, ParamMap, Router, RouterLink } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { ItemPickerComponent, PickedItem } from '../../shared/ui/item-picker.component';
import { IconComponent } from '../../shared/ui/icon.component';
import { apiError, chanceText, chanceWidth, itemName, labelText } from './loot-format';
import { DropPath, ItemDrops, LootApi, LootHop, LootMeta } from './loot.api';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { ToastService } from '../../shared/ui/toast.service';

type SortKey = 'chance' | 'table' | 'owner';

const OWNER_KINDS: readonly { id: string; label: string }[] = [
  { id: 'creature', label: 'существа' },
  { id: 'gameobject', label: 'объекты' },
  { id: 'item', label: 'предметы' },
  { id: 'reference', label: 'ничьи ссылки' },
];

@Component({
  providers: [LootApi],
  selector: 'app-item-drops-page',
  imports: [FormsModule, RouterLink, IconComponent, ItemPickerComponent, ForgeSelectDirective],
  styleUrl: './item-drops.page.scss',
  templateUrl: './item-drops.page.html',
})
export class ItemDropsPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(LootApi);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  private readonly params = toSignal(this.route.queryParamMap, {
    initialValue: this.route.snapshot.queryParamMap,
  });
  private lastEntry = '';

  readonly meta = signal<LootMeta | null>(null);
  readonly drops = signal<ItemDrops | null>(null);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly entry = signal(0);
  readonly draftEntry = signal('');

  readonly ownerKinds = OWNER_KINDS;
  readonly filterTable = signal('');
  readonly filterKind = signal('');
  readonly filterFloor = signal('');
  readonly filterQuest = signal('');
  readonly filterOwner = signal('');
  readonly sortKey = signal<SortKey>('chance');
  readonly sortDir = signal(-1);

  readonly chanceText = chanceText;
  readonly chanceWidth = chanceWidth;
  readonly itemName = itemName;

  readonly tables = computed(() => this.meta()?.tables ?? []);
  readonly paths = computed(() => this.drops()?.paths ?? []);
  readonly filtersUsed = computed(
    () =>
      !!(
        this.filterTable() ||
        this.filterKind() ||
        this.filterFloor() ||
        this.filterQuest() ||
        this.filterOwner()
      ),
  );

  /** A busy item has hundreds of paths; without a filter the list is unreadable. */
  readonly shown = computed(() => {
    const owner = this.filterOwner().trim().toLocaleLowerCase();
    const floor = Number(this.filterFloor()) || 0;
    const quest = this.filterQuest();
    const table = this.filterTable();
    const kind = this.filterKind();

    const rows = this.paths().filter((path) => {
      if (table && path.table !== table) return false;
      if (kind && path.owner_kind !== kind) return false;
      if (floor && path.chance < floor) return false;
      if (quest && (path.chain.some((hop) => hop.quest) ? '1' : '0') !== quest) return false;
      if (owner && !path.owner_name.toLocaleLowerCase().includes(owner)) return false;
      return true;
    });

    const key = this.sortKey();
    const dir = this.sortDir();
    return rows.slice().sort((left, right) => {
      if (key === 'chance') return (left.chance - right.chance) * dir;
      const a = key === 'table' ? left.table_name : left.owner_name;
      const b = key === 'table' ? right.table_name : right.owner_name;
      return a.localeCompare(b, 'ru') * dir;
    });
  });

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
    } catch (error) {
      this.error.set(apiError(error, 'Таблиц добычи в этой базе нет.'));
    }
  }

  private applyParams(params: ParamMap): void {
    const entry = Number(params.get('item')) || 0;
    this.entry.set(entry);
    this.draftEntry.set(entry ? String(entry) : '');
    if (String(entry) !== this.lastEntry) {
      this.lastEntry = String(entry);
      void this.load();
    }
  }

  open(entry: number): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { item: entry || null },
      queryParamsHandling: 'merge',
    });
  }

  submit(event: Event): void {
    event.preventDefault();
    this.open(Number(this.draftEntry()) || 0);
  }

  onPicked(item: PickedItem): void {
    this.open(item.entry);
  }

  sortBy(key: SortKey): void {
    if (this.sortKey() === key) this.sortDir.update((dir) => -dir);
    else {
      this.sortKey.set(key);
      this.sortDir.set(key === 'chance' ? -1 : 1);
    }
  }

  /** Имя значка (`tone="plain"`), а не символ шрифта; пусто - колонка не та. */
  sortArrow(key: SortKey): string {
    if (this.sortKey() !== key) return '';
    return this.sortDir() > 0 ? 'caret-up' : 'caret';
  }

  resetFilters(): void {
    this.filterTable.set('');
    this.filterKind.set('');
    this.filterFloor.set('');
    this.filterQuest.set('');
    this.filterOwner.set('');
  }

  hopTitle(hop: LootHop): string {
    const parts = [`запись ${hop.entry}`, `шанс ${chanceText(hop.chance)}`];
    if (hop.group) parts.push(`группа ${hop.group}`);
    const head = parts.join(', ');
    return hop.comment ? `${head}\n${hop.comment}` : head;
  }

  hopName(hop: LootHop): string {
    const named = labelText(hop.label, '');
    return named ? `${hop.table_name} · ${named}` : `${hop.table_name} ${hop.entry}`;
  }

  lastHop(path: DropPath): LootHop | undefined {
    return path.chain[path.chain.length - 1];
  }

  async load(): Promise<void> {
    const entry = this.entry();
    if (!entry) {
      this.drops.set(null);
      return;
    }
    this.loading.set(true);
    try {
      this.drops.set(await firstValueFrom(this.api.itemDrops(entry)));
      this.error.set(null);
    } catch (error) {
      this.drops.set(null);
      this.error.set(apiError(error, `Не удалось найти пути предмета ${entry}.`));
    } finally {
      this.loading.set(false);
    }
  }
}
