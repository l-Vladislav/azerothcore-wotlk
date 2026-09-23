import { Component, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { TablePagerComponent } from '../../shared/data/table-pager.component';
import { ToastService } from '../../shared/ui/toast.service';
import { ListView } from './list-view';
import {
  Generated,
  GeneratedRow,
  Material,
  PoolSlice,
  PoolState,
  ProfessionsApi,
  ProfessionsMeta,
  Recipe,
} from './professions.api';
import { apiError } from './professions.model';
import { ProfessionsTabsComponent } from './professions-tabs.component';

/** Ниже этой доли свободного слайс считается кончающимся. */
const LOW = 0.1;

/**
 * Пул id: сколько заготовок осталось и что уже выдано.
 *
 * Единственное место, где видно приближение к «кончились свободные id»: каждая
 * вставка самоцвета - новая комбинация, поэтому пул тратится быстрее, чем
 * кажется по числу готовых вещей.
 *
 * Считать надо ПО ОСНОВАМ, а не общим числом: кончиться может слайс одной
 * основы, пока у остальных полно свободного, - по общему числу этого не
 * видно, а отказ игрок получит.
 */
@Component({
  imports: [ProfessionsTabsComponent, TablePagerComponent],
  providers: [ProfessionsApi],
  selector: 'app-professions-pool-page',
  styleUrl: './pool.page.scss',
  templateUrl: './pool.page.html',
})
export class ProfessionsPoolPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);
  readonly auth = inject(AuthService);

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly data = signal<Generated | null>(null);
  readonly recipes = signal<Recipe[]>([]);
  readonly materials = signal<Material[]>([]);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');
  readonly pool = computed(() => this.data()?.pool ?? null);
  /** Три листа страницы - по десять строк, как и остальные листы профессий. */
  readonly sliceView = new ListView<PoolSlice>(
    computed(() => this.pool()?.types ?? []),
    signal({}),
  );
  readonly missingView = new ListView<PoolState['missing'][number]>(
    computed(() => this.pool()?.missing ?? []),
    signal({}),
  );
  readonly issuedView = new ListView<GeneratedRow>(
    computed(() => this.data()?.rows ?? []),
    signal({}),
  );
  readonly low = computed(() => {
    const pool = this.pool();
    return !!pool?.blanks && pool.free / pool.blanks < LOW;
  });

  readonly summary = computed<[string, string][]>(() => {
    const pool = this.pool();
    if (!pool) return [];
    return [
      ['Заведено заготовок в item_template', String(pool.blanks)],
      ['Занято', String(this.data()?.total ?? 0)],
      ['Свободно', String(pool.free)],
      ['Сборка мусора на старте мира', pool.gc_enabled ? 'включена' : 'ВЫКЛЮЧЕНА'],
      ['Строк без изделия (id зарезервирован)', String(pool.orphans)],
    ];
  });

  constructor() {
    this.toast.announce(this.error, 'error');
    this.toast.announce(this.notice);
    void this.load();
  }

  async load(): Promise<void> {
    this.loading.set(true);
    try {
      const meta = await firstValueFrom(this.api.meta());
      this.meta.set(meta);
      if (meta.available) await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось прочитать пул id.'));
    } finally {
      this.loading.set(false);
    }
  }

  private async reload(): Promise<void> {
    const [data, recipes, materials] = await Promise.all([
      firstValueFrom(this.api.generated()),
      firstValueFrom(this.api.recipes()),
      firstValueFrom(this.api.materials()),
    ]);
    this.data.set(data);
    this.recipes.set(recipes.recipes);
    this.materials.set(materials.materials);
  }

  isLow(blanks: number, free: number): boolean {
    return !!blanks && free / blanks < LOW;
  }

  recipeName(id: number): string {
    return this.recipes().find((recipe) => recipe.id === id)?.name_ru ?? String(id);
  }

  /** Снимок доводки: что вставлено в эту строку. Числа берутся у изделия. */
  matNames(row: GeneratedRow): string {
    return (row.mats || '')
      .split(',')
      .filter(Boolean)
      .map((raw) => {
        const entry = parseInt(raw, 10);
        return this.materials().find((mat) => mat.entry === entry)?.name_ru ?? raw;
      })
      .join(' + ');
  }

  async reslice(recipeId: number, quality: number): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    this.busy.set(true);
    try {
      const cut = await firstValueFrom(this.api.reslice(recipeId, quality));
      this.notice.set(`Слайс ${cut.lo}-${cut.hi}: засеяно заготовок ${cut.seeded}.`);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Нарезать слайс не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }
}
