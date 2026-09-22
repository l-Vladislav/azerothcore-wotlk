import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, ParamMap, Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { apiError } from './loot-format';
import { CreatureBrief, LootApi, LootMeta } from './loot.api';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { TablePagerComponent } from '../../shared/data/table-pager.component';
import { ToastService } from '../../shared/ui/toast.service';

const PAGE_SIZES = [10, 25, 50, 100];
const DEFAULT_PER_PAGE = 10;

/**
 * Список существ таблицей. Раньше он жил узкой колонкой слева от добычи, и
 * места в нём хватало ровно на имя: ни уровня, ни ранга, ни того, какие виды
 * добычи у существа есть, не видно было вовсе.
 *
 * Отбор и листалка - СЕРВЕРНЫЕ. Существ в базе три десятка тысяч; фильтровать
 * присланную страницу в браузере значит фильтровать не то, что искали, а
 * «показано 1-50 из 3184» без общего числа не написать.
 *
 * Порядок строк задаёт сервер (ранг, затем уровень, затем номер), и колонки
 * тут не сортируются нарочно: сортировка страницы переставила бы полсотни
 * присланных строк, делая вид, что переставила все три тысячи.
 */
@Component({
  providers: [LootApi],
  selector: 'app-creature-list-page',
  imports: [FormsModule, ForgeSelectDirective, TablePagerComponent],
  styleUrl: './creature-list.page.scss',
  templateUrl: './creature-list.page.html',
})
export class CreatureListPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(LootApi);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  private readonly params = toSignal(this.route.queryParamMap, {
    initialValue: this.route.snapshot.queryParamMap,
  });
  private searchTimer: ReturnType<typeof setTimeout> | null = null;
  private lastSearch = '';

  readonly meta = signal<LootMeta | null>(null);
  readonly creatures = signal<CreatureBrief[]>([]);
  readonly total = signal(0);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);

  readonly query = signal('');
  readonly rank = signal('');
  readonly levelMin = signal('');
  readonly levelMax = signal('');
  readonly onlyLoot = signal(true);
  readonly offset = signal(0);
  readonly perPage = signal(DEFAULT_PER_PAGE);

  readonly ranks = computed(() => Object.entries(this.meta()?.ranks ?? {}));
  /** Подвалу удобнее номер страницы, серверу - смещение; считаем из него. */
  readonly page = computed(() => Math.floor(this.offset() / this.perPage()) + 1);
  readonly filtersUsed = computed(
    () => !!(this.query() || this.rank() || this.levelMin() || this.levelMax() || !this.onlyLoot()),
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
    } catch (error) {
      this.error.set(apiError(error, 'Таблиц добычи в этой базе нет.'));
    }
  }

  private applyParams(params: ParamMap): void {
    // Прежний адрес со списком и выбранным существом в одном месте
    // (`/loot/creatures?creature=17`) теперь ведёт на карточку - ссылки из
    // старых заметок и переписки не должны упираться в пустой список.
    const legacy = Number(params.get('creature')) || 0;
    if (legacy) {
      void this.router.navigate(['/loot/creatures', legacy], {
        queryParams: { creature: null },
        queryParamsHandling: 'merge',
        replaceUrl: true,
      });
      return;
    }

    this.query.set(params.get('q') ?? '');
    this.rank.set(params.get('rank') ?? '');
    this.levelMin.set(params.get('lvlmin') ?? '');
    this.levelMax.set(params.get('lvlmax') ?? '');
    this.onlyLoot.set(params.get('all') !== '1');
    this.offset.set(Math.max(0, Number(params.get('from')) || 0));
    this.perPage.set(
      PAGE_SIZES.includes(Number(params.get('per'))) ? Number(params.get('per')) : DEFAULT_PER_PAGE,
    );

    const key = [
      this.query(),
      this.rank(),
      this.levelMin(),
      this.levelMax(),
      this.onlyLoot(),
      this.offset(),
      this.perPage(),
    ].join('|');
    if (key !== this.lastSearch) {
      this.lastSearch = key;
      void this.search();
    }
  }

  /** Отбор живёт в адресе: найденное существо - это ссылка, а не состояние. */
  private patch(changes: Record<string, string | null>, replaceUrl = false): void {
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
    // поиска - значит увидеть пустую таблицу и решить, что ничего не нашлось.
    this.searchTimer = setTimeout(() => this.patch({ q: value || null, from: null }, true), 250);
  }

  onRank(value: string): void {
    this.patch({ rank: value || null, from: null });
  }

  onLevel(from: string, to: string): void {
    this.patch({ lvlmin: from || null, lvlmax: to || null, from: null });
  }

  onOnlyLoot(value: boolean): void {
    this.patch({ all: value ? null : '1', from: null });
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
    this.patch({ q: null, rank: null, lvlmin: null, lvlmax: null, all: null, from: null });
  }

  open(entry: number): void {
    void this.router.navigate(['/loot/creatures', entry], {
      queryParams: this.route.snapshot.queryParams,
    });
  }

  /** Какие виды добычи у существа заведены - по ним и колонка. */
  kinds(creature: CreatureBrief): string[] {
    const out: string[] = [];
    if (creature.lootid) out.push('с трупа');
    if (creature.pickpocketloot) out.push('из карманов');
    if (creature.skinloot) out.push('освежеванием');
    return out;
  }

  async search(): Promise<void> {
    this.loading.set(true);
    try {
      const found = await firstValueFrom(
        this.api.creatures({
          q: this.query(),
          onlyLoot: this.onlyLoot(),
          rank: this.rank(),
          levelMin: this.levelMin(),
          levelMax: this.levelMax(),
          limit: this.perPage(),
          offset: this.offset(),
        }),
      );
      this.creatures.set(found.creatures);
      this.total.set(found.total ?? found.creatures.length);
      this.error.set(null);
    } catch (error) {
      this.error.set(apiError(error, 'Поиск существ не ответил.'));
      this.creatures.set([]);
      this.total.set(0);
    } finally {
      this.loading.set(false);
    }
  }
}
