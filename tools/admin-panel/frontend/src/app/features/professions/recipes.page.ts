import { Component, computed, inject, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { TablePagerComponent } from '../../shared/data/table-pager.component';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { ItemPickerComponent, PickedItem } from '../../shared/ui/item-picker.component';
import { ToastService } from '../../shared/ui/toast.service';
import { ProfFiltersComponent } from './filter-bar.component';
import { ProfItemPickComponent } from './item-pick-cell.component';
import { ListSpec, ListView, SortHeadComponent } from './list-view';
import { RecipeCellsDialogComponent } from './recipe-cells.dialog';
import { RecipeFiltersDialogComponent } from './recipe-filters.dialog';
import { RecipeResultsDialogComponent } from './recipe-results.dialog';
import {
  ItemType,
  Material,
  ProfessionsApi,
  ProfessionsMeta,
  Recipe,
  RecipePatch,
} from './professions.api';
import { ACQUIRE, apiError, qualityName } from './professions.model';

/** Куда уедет ответ окна выбора предмета. */
type PickMode =
  | { kind: 'draft-sample' }
  | { kind: 'draft-teach' }
  | { kind: 'row-teach'; row: Recipe }
  | { kind: 'result-sample' }
  | { kind: 'result-entry'; quality: number };

/**
 * Рецепты основ: точный набор предметов по ячейкам и готовое изделие на каждую
 * ступень качества.
 *
 * Ничего не вычисляется - страница занимается не числами, а содержанием: что
 * кладут, что выходит и каким качеством это может выйти. Дроп-основу не куют,
 * и её ковочная половина не то что не нужна - она обманывает, обещая набор,
 * навык и книгу, которых не существует (DESIGN §2.5). Поэтому такие столбцы
 * гасим, а не прячем: таблица не должна разъезжаться от строки к строке.
 */
@Component({
  imports: [
    FormsModule,
    ForgeSelectDirective,
    ItemPickerComponent,
    ProfFiltersComponent,
    ProfItemPickComponent,
    RecipeCellsDialogComponent,
    RecipeFiltersDialogComponent,
    RecipeResultsDialogComponent,
    SortHeadComponent,
    TablePagerComponent,
  ],
  providers: [ProfessionsApi],
  selector: 'app-professions-recipes-page',
  styleUrl: './recipes.page.scss',
  templateUrl: './recipes.page.html',
})
export class ProfessionsRecipesPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);
  private readonly itemPicker = viewChild.required(ItemPickerComponent);
  private readonly cellsDialog = viewChild.required(RecipeCellsDialogComponent);
  private readonly filtersDialog = viewChild.required(RecipeFiltersDialogComponent);
  private readonly resultsDialog = viewChild.required(RecipeResultsDialogComponent);
  private readonly route = inject(ActivatedRoute);
  readonly auth = inject(AuthService);

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly rows = signal<Recipe[]>([]);
  readonly types = signal<ItemType[]>([]);
  readonly materials = signal<Material[]>([]);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');
  readonly iconBase = computed(() => this.meta()?.icon_base_url ?? '');
  readonly acquire = Object.entries(ACQUIRE);
  readonly qualities = computed(() => this.meta()?.qualities ?? []);

  readonly spec = computed<ListSpec<Recipe>>(() => ({
    search: (row) => [row.name_ru, row.type_name].join(' '),
    picks: [
      {
        key: 'type',
        label: 'любой тип',
        options: this.types().map((type) => [String(type.id), type.name_ru] as const),
        get: (row) => row.type_id,
      },
      {
        key: 'on',
        label: 'вкл и выкл',
        options: [
          ['1', 'только включённые'],
          ['0', 'только выключенные'],
        ],
        get: (row) => (row.enabled ? '1' : '0'),
      },
      {
        key: 'ready',
        label: 'готовые и нет',
        options: [
          ['1', 'без замечаний'],
          ['0', 'с замечаниями'],
        ],
        get: (row) => (row.issues.length ? '0' : '1'),
      },
      {
        key: 'acquire',
        label: 'ковка и добыча',
        options: this.acquire.map(([id, label]) => [id, label] as const),
        get: (row) => row.acquire || 'forge',
      },
      {
        key: 'teach',
        label: 'как достаётся',
        options: [
          ['1', 'есть обучающий предмет'],
          ['0', 'только угадать'],
        ],
        get: (row) => (row.teach_item ? '1' : '0'),
      },
    ],
    sorts: {
      Имя: (row) => row.name_ru,
      Тип: (row) => row.type_name,
      Откуда: (row) => row.acquire || 'forge',
      Набор: (row) => row.cells.filter((cell) => cell.item_entry).length,
      Навык: (row) => row.req_skill,
      Качество: (row) => row.quality_min * 10 + row.quality_max,
      Изделия: (row) => row.ready_steps,
      Гнёзда: (row) => Math.max(0, ...row.inlay.map((step) => step.patterns)),
      Вкл: (row) => (row.enabled ? 1 : 0),
    },
  }));

  readonly view = new ListView<Recipe>(this.rows.asReadonly(), this.spec);
  readonly picks = computed(() => this.spec().picks ?? []);

  readonly draft = signal({
    name_ru: '',
    type_id: 0,
    quality_min: 1,
    quality_max: 1,
    acquire: 'forge' as 'forge' | 'drop',
  });
  readonly draftSample = signal<PickedItem | null>(null);
  readonly draftTeach = signal<PickedItem | null>(null);

  private pickMode: PickMode | null = null;

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
      if (meta.available) {
        await this.reload();
        // Пришли по ссылке с карты связей - подводим к самой строке.
        const focus = Number(this.route.snapshot.queryParamMap.get('focus')) || 0;
        if (focus) this.view.focus((row) => row.id === focus);
      }
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось загрузить рецепты.'));
    } finally {
      this.loading.set(false);
    }
  }

  async reload(): Promise<void> {
    const [recipes, types, materials] = await Promise.all([
      firstValueFrom(this.api.recipes()),
      firstValueFrom(this.api.types()),
      firstValueFrom(this.api.materials()),
    ]);
    this.rows.set(recipes.recipes);
    this.types.set(types.types);
    this.materials.set(materials.materials);
    if (!this.draft().type_id && types.types.length) {
      this.setDraft({ type_id: types.types[0].id });
    }
  }

  tierName(quality: number): string {
    return qualityName(this.meta(), quality);
  }

  filledCells(row: Recipe): number {
    return row.cells.filter((cell) => cell.item_entry).length;
  }

  /** Верхняя ступень: она самая дорогая пулу id, по ней и считается запас. */
  topInlay(row: Recipe): string {
    const steps = row.inlay;
    if (!steps.length) return 'нет ступеней';
    const top = steps[steps.length - 1];
    return `${top.patterns} эскиз. · ${top.gems} кам.`;
  }

  inlayHint(row: Recipe): string {
    if (!row.inlay.length) return 'Изделий нет - считать нечего.';
    return row.inlay
      .map(
        (step) =>
          `${this.tierName(step.quality)}: гнёзд ${step.slots}, камней ${step.gems}, эскизов ${step.patterns}`,
      )
      .join('\n');
  }

  /** Гнёзда есть, а камней к ним нет: рецепт включить не дадут. */
  inlayDry(row: Recipe): boolean {
    return row.inlay.some((step) => step.slots && !step.gems);
  }

  // --- заведение основы -----------------------------------------------------

  setDraft(patch: Partial<ReturnType<typeof this.draft>>): void {
    this.draft.update((draft) => ({ ...draft, ...patch }));
  }

  onDraftAcquire(acquire: 'forge' | 'drop'): void {
    this.setDraft({ acquire });
    // Дроп-основу не куют, и книга обещала бы рецепт, которого не сковать.
    if (acquire === 'drop') this.draftTeach.set(null);
  }

  pickDraftSample(): void {
    this.pickMode = { kind: 'draft-sample' };
    this.itemPicker().open();
  }

  pickDraftTeach(): void {
    this.pickMode = { kind: 'draft-teach' };
    this.itemPicker().open();
  }

  /**
   * Заводит основу ЦЕЛИКОМ: строку рецепта, изделие на каждую ступень
   * диапазона и слайс пула под каждое. Без образца заводится одна строка -
   * тогда изделия привязываются вручную в окне «Изделия».
   */
  async add(): Promise<void> {
    const draft = this.draft();
    if (!draft.name_ru.trim()) {
      this.error.set('Дайте основе имя.');
      return;
    }
    if (!this.canEdit() || this.busy()) return;
    this.busy.set(true);
    try {
      const made = await firstValueFrom(
        this.api.saveRecipe({
          id: 0,
          type_id: draft.type_id,
          name_ru: draft.name_ru,
          req_skill: draft.acquire === 'drop' ? 0 : 1,
          teach_item: draft.acquire === 'drop' ? 0 : (this.draftTeach()?.entry ?? 0),
          quality_min: draft.quality_min,
          quality_max: draft.quality_max,
          acquire: draft.acquire,
          enabled: false,
        }),
      );
      const sample = this.draftSample()?.entry ?? 0;
      let created = 0;
      if (sample) {
        created = (await firstValueFrom(this.api.generateResults(made.id, sample))).created.length;
      }
      this.notice.set(
        created
          ? `Основа заведена: изделий ${created}, слайсы нарезаны. Осталось задать набор ячеек и включить.`
          : 'Основа заведена. Теперь изделия и набор ячеек.',
      );
      this.setDraft({ name_ru: '' });
      this.draftSample.set(null);
      this.draftTeach.set(null);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Основу завести не удалось.'));
      await this.reload();
    } finally {
      this.busy.set(false);
    }
  }

  // --- правка строки --------------------------------------------------------

  async patch(row: Recipe, fields: Partial<RecipePatch>): Promise<void> {
    await this.put({
      id: row.id,
      type_id: row.type_id,
      name_ru: row.name_ru,
      req_skill: row.req_skill,
      teach_item: row.teach_item,
      quality_min: row.quality_min,
      quality_max: row.quality_max,
      acquire: row.acquire,
      enabled: row.enabled,
      ...fields,
    });
  }

  async onAcquire(row: Recipe, acquire: 'forge' | 'drop'): Promise<void> {
    // Ковочная половина уезжает вместе со способом: сервер её у дроп-основы не
    // примет, а оставленная книга обещала бы рецепт, которого не сковать.
    await this.patch(row, {
      acquire,
      teach_item: acquire === 'drop' ? 0 : row.teach_item,
      req_skill: acquire === 'drop' ? 0 : row.req_skill,
    });
  }

  async remove(row: Recipe): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    if (
      !confirm(`Удалить рецепт «${row.name_ru}»? Заведённые изделия останутся в каталоге предметов.`)
    ) {
      return;
    }
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.deleteRecipe(row.id));
      this.notice.set(`Рецепт «${row.name_ru}» удалён.`);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Рецепт удалить не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }

  // --- окна -----------------------------------------------------------------

  openCells(row: Recipe): void {
    this.cellsDialog().open(row);
  }

  openFilters(row: Recipe): void {
    this.filtersDialog().open(row);
  }

  openResults(row: Recipe): void {
    this.resultsDialog().open(row);
  }

  /** Окна меняют счётчики строки - после закрытия лист перечитываем. */
  onDialogClosed(): void {
    void this.reload();
  }

  pickTeach(row: Recipe): void {
    this.pickMode = { kind: 'row-teach', row };
    this.itemPicker().open();
  }

  onResultSample(): void {
    this.pickMode = { kind: 'result-sample' };
    this.itemPicker().open();
  }

  onResultPick(quality: number): void {
    this.pickMode = { kind: 'result-entry', quality };
    this.itemPicker().open();
  }

  async onItemPicked(item: PickedItem): Promise<void> {
    const mode = this.pickMode;
    this.pickMode = null;
    if (!mode) return;
    switch (mode.kind) {
      case 'draft-sample':
        this.draftSample.set(item);
        return;
      case 'draft-teach':
        this.draftTeach.set(item);
        return;
      case 'row-teach':
        await this.patch(mode.row, { teach_item: item.entry });
        return;
      case 'result-entry':
        await this.resultsDialog().setResult(mode.quality, item.entry);
        return;
      case 'result-sample':
        await this.generateResults(item.entry);
    }
  }

  private async generateResults(sample: number): Promise<void> {
    const recipe = this.resultsDialog().recipe();
    if (!recipe || !this.canEdit()) return;
    try {
      const made = await firstValueFrom(this.api.generateResults(recipe.id, sample));
      this.notice.set(
        made.created.length
          ? `Заведено изделий: ${made.created.length}.`
          : 'Все ступени уже заведены.',
      );
      await this.resultsDialog().refresh();
    } catch (error) {
      this.error.set(apiError(error, 'Изделия завести не удалось.'));
    }
  }

  private async put(recipe: RecipePatch): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.saveRecipe(recipe));
      this.notice.set('Сохранено.');
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Рецепт сохранить не удалось.'));
      await this.reload();
    } finally {
      this.busy.set(false);
    }
  }
}
