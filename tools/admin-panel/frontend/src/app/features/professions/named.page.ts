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
import { GemPickerDialogComponent } from './gem-picker.dialog';
import { GemSocketComponent } from './gem-socket.component';
import { ProfItemPickComponent } from './item-pick-cell.component';
import { ListSpec, ListView, SortHeadComponent } from './list-view';
import {
  InlayStep,
  Material,
  ProfessionsApi,
  ProfessionsMeta,
  Recipe,
  Synergy,
  SynergyPatch,
} from './professions.api';
import { apiError, qualityName } from './professions.model';

/** Кому предназначен ответ окна выбора камня. */
type GemTarget = { kind: 'draft'; index: number } | { kind: 'row'; row: Synergy; index: number };

/** Кому предназначен ответ окна выбора предмета. */
type PickMode =
  | { kind: 'draft-teach' }
  | { kind: 'row-teach'; row: Synergy }
  | { kind: 'row-result'; row: Synergy }
  | { kind: 'row-sample'; row: Synergy };

/**
 * Именные сочетания: набор вставок в одной основе даёт СВОЙ предмет.
 *
 * Набор задаётся целиком - и в полосе добавления, и в строке: раньше здесь
 * была «первая вставка», а остальные дописывались отдельно, то есть сочетание
 * из трёх камней заводилось в четыре захода.
 */
@Component({
  imports: [
    FormsModule,
    ForgeSelectDirective,
    GemPickerDialogComponent,
    GemSocketComponent,
    ItemPickerComponent,
    ProfFiltersComponent,
    ProfItemPickComponent,
    SortHeadComponent,
    TablePagerComponent,
  ],
  providers: [ProfessionsApi],
  selector: 'app-professions-named-page',
  styleUrl: './named.page.scss',
  templateUrl: './named.page.html',
})
export class ProfessionsNamedPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);
  private readonly itemPicker = viewChild.required(ItemPickerComponent);
  private readonly gemPicker = viewChild.required(GemPickerDialogComponent);
  private readonly route = inject(ActivatedRoute);
  readonly auth = inject(AuthService);

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly rows = signal<Synergy[]>([]);
  readonly recipes = signal<Recipe[]>([]);
  readonly materials = signal<Material[]>([]);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');
  readonly iconBase = computed(() => this.meta()?.icon_base_url ?? '');

  readonly spec = computed<ListSpec<Synergy>>(() => ({
    search: (row) =>
      [row.name_ru, row.recipe_name, ...row.mats.map((entry) => this.matName(entry))].join(' '),
    picks: [
      {
        key: 'recipe',
        label: 'любая основа',
        options: this.recipes().map((recipe) => [String(recipe.id), recipe.name_ru] as const),
        get: (row) => row.recipe_id,
      },
      {
        key: 'len',
        label: 'любая длина набора',
        options: [1, 2, 3, 4, 5].map((n) => [String(n), `вставок: ${n}`] as const),
        get: (row) => row.mats.length,
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
      Основа: (row) => row.recipe_name,
      'Набор вставок': (row) => row.mats.length,
      Вкл: (row) => (row.enabled ? 1 : 0),
    },
  }));

  readonly view = new ListView<Synergy>(this.rows.asReadonly(), this.spec);
  readonly picks = computed(() => this.spec().picks ?? []);

  readonly draft = signal({ name_ru: '', recipe_id: 0 });
  readonly draftMats = signal<number[]>([]);
  readonly draftTeach = signal<PickedItem | null>(null);

  private gemTarget: GemTarget | null = null;
  private pickMode: PickMode | null = null;

  /** Основа заводимого сочетания - от неё зависят и ширина набора, и камни. */
  readonly draftRecipe = computed(
    () => this.recipes().find((recipe) => recipe.id === this.draft().recipe_id) ?? null,
  );

  /** Гнёзд ровно столько, сколько даёт лучший вариант основы. */
  readonly draftSlots = computed(() => {
    const recipe = this.draftRecipe();
    const tier = this.meta()?.qualities?.find((row) => row.quality === recipe?.quality_max);
    const width = Math.min(Math.max(tier?.slots ?? 1, 1), this.meta()?.max_slots ?? 3);
    const mats = this.draftMats();
    return Array.from({ length: width }, (_, index) => mats[index] ?? 0);
  });

  /**
   * Сколько эскизов у основы есть и сколько уже разобрано именными. Берём
   * ЛУЧШУЮ ступень, а не последнюю: обычно это верхняя, но если камней её
   * качества никто не завёл, эскизы даёт ступень пожиже, и «ноль» было бы
   * неправдой.
   */
  private readonly bestStep = computed<InlayStep | null>(() =>
    (this.draftRecipe()?.inlay ?? []).reduce<InlayStep | null>(
      (best, step) => (!best || step.patterns > best.patterns ? step : best),
      null,
    ),
  );

  readonly draftCounter = computed(() => {
    const recipe = this.draftRecipe();
    if (!recipe?.inlay.length) return 'у основы нет изделий - эскизов пока ноль';
    const best = this.bestStep();
    if (!best?.patterns) return 'основа не принимает ни одного камня: эскизов ноль';
    const taken = this.rows().filter((row) => row.recipe_id === recipe.id).length;
    return `эскизов у основы: занято ${taken} из ${best.patterns}`;
  });

  readonly draftCounterWarn = computed(() => {
    const recipe = this.draftRecipe();
    if (!recipe?.inlay.length) return false;
    const best = this.bestStep();
    if (!best?.patterns) return true;
    return this.rows().filter((row) => row.recipe_id === recipe.id).length >= best.patterns;
  });

  readonly draftCounterHint = computed(() =>
    (this.draftRecipe()?.inlay ?? [])
      .map(
        (step) =>
          `${qualityName(this.meta(), step.quality)}: гнёзд ${step.slots}, камней ${step.gems}, эскизов ${step.patterns}`,
      )
      .join('\n'),
  );

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
      this.error.set(apiError(error, 'Не удалось загрузить сочетания.'));
    } finally {
      this.loading.set(false);
    }
  }

  private async reload(): Promise<void> {
    const [synergies, recipes, materials] = await Promise.all([
      firstValueFrom(this.api.synergies()),
      firstValueFrom(this.api.recipes()),
      firstValueFrom(this.api.materials()),
    ]);
    this.rows.set(synergies.synergies);
    this.recipes.set(recipes.recipes);
    this.materials.set(materials.materials);
    if (!this.draft().recipe_id && recipes.recipes.length) {
      this.setDraft({ recipe_id: recipes.recipes[0].id });
    }
  }

  material(entry: number): Material | null {
    return this.materials().find((mat) => mat.entry === entry) ?? null;
  }

  matName(entry: number): string {
    const mat = this.material(entry);
    return mat?.name_ru || mat?.item?.name || String(entry);
  }

  /** Гнёзд у строки столько же: длиннее набор не соберёт никто. */
  slots(row: Synergy): number[] {
    const width = Math.min(
      Math.max(row.recipe_slots || 0, row.mats.length, 1),
      this.meta()?.max_slots ?? 3,
    );
    return Array.from({ length: width }, (_, index) => row.mats[index] ?? 0);
  }

  // --- полоса добавления ----------------------------------------------------

  setDraft(patch: Partial<{ name_ru: string; recipe_id: number }>): void {
    this.draft.update((draft) => ({ ...draft, ...patch }));
  }

  onDraftRecipe(id: number): void {
    this.setDraft({ recipe_id: id });
    // Другая основа - другие гнёзда и другие камни: прежний набор в них уже
    // не обязан помещаться.
    this.draftMats.set([]);
  }

  pickDraftGem(index: number): void {
    this.gemTarget = { kind: 'draft', index };
    this.gemPicker().open(this.draftRecipe(), this.draftSlots()[index] ?? 0);
  }

  pickDraftTeach(): void {
    this.pickMode = { kind: 'draft-teach' };
    this.itemPicker().open();
  }

  async add(): Promise<void> {
    const mats = this.draftSlots().filter(Boolean);
    if (!mats.length) {
      this.error.set('Положите в набор хотя бы один камень.');
      return;
    }
    const saved = await this.put({
      id: 0,
      name_ru: this.draft().name_ru,
      recipe_id: this.draft().recipe_id,
      mats,
      result_entry: 0,
      teach_item: this.draftTeach()?.entry ?? 0,
      order_matters: false,
      enabled: false,
    });
    if (saved) {
      this.setDraft({ name_ru: '' });
      this.draftMats.set([]);
      this.draftTeach.set(null);
    }
  }

  // --- строки ---------------------------------------------------------------

  pickRowGem(row: Synergy, index: number): void {
    this.gemTarget = { kind: 'row', row, index };
    this.gemPicker().open(
      this.recipes().find((recipe) => recipe.id === row.recipe_id) ?? null,
      row.mats[index] ?? 0,
    );
  }

  async onGemPicked(entry: number): Promise<void> {
    const target = this.gemTarget;
    this.gemTarget = null;
    if (!target) return;
    if (target.kind === 'draft') {
      const draft = [...this.draftSlots()];
      draft[target.index] = entry;
      this.draftMats.set(draft);
      return;
    }
    const next = this.slots(target.row);
    next[target.index] = entry;
    await this.patch(target.row, { mats: next.filter(Boolean) });
  }

  pickTeach(row: Synergy): void {
    this.pickMode = { kind: 'row-teach', row };
    this.itemPicker().open();
  }

  pickResult(row: Synergy): void {
    this.pickMode = { kind: 'row-result', row };
    this.itemPicker().open();
  }

  pickNamedSample(row: Synergy): void {
    this.pickMode = { kind: 'row-sample', row };
    this.itemPicker().open();
  }

  async onItemPicked(item: PickedItem): Promise<void> {
    const mode = this.pickMode;
    this.pickMode = null;
    if (!mode) return;
    switch (mode.kind) {
      case 'draft-teach':
        this.draftTeach.set(item);
        return;
      case 'row-teach':
        await this.patch(mode.row, { teach_item: item.entry });
        return;
      case 'row-result':
        await this.patch(mode.row, { result_entry: item.entry });
        return;
      case 'row-sample':
        await this.makeNamedItem(mode.row, item.entry);
    }
  }

  async patch(row: Synergy, fields: Partial<SynergyPatch>): Promise<void> {
    await this.put({
      id: row.id,
      name_ru: row.name_ru,
      recipe_id: row.recipe_id,
      mats: row.mats,
      result_entry: row.result_entry,
      teach_item: row.teach_item,
      order_matters: row.order_matters,
      enabled: row.enabled,
      ...fields,
    });
  }

  async remove(row: Synergy): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    if (!confirm(`Удалить сочетание «${row.name_ru}»?`)) return;
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.deleteSynergy(row.id));
      this.notice.set(`Сочетание «${row.name_ru}» удалено.`);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Сочетание удалить не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }

  private async makeNamedItem(row: Synergy, sample: number): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    this.busy.set(true);
    try {
      const made = await firstValueFrom(this.api.makeNamedItem(row.id, sample));
      this.notice.set(`Заведён предмет ${made.entry}. Правьте его в каталоге.`);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Именной предмет завести не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }

  private async put(synergy: SynergyPatch): Promise<boolean> {
    if (!this.canEdit() || this.busy()) return false;
    this.busy.set(true);
    try {
      const saved = await firstValueFrom(this.api.saveSynergy(synergy));
      this.notice.set(saved.note || 'Сохранено.');
      await this.reload();
      return true;
    } catch (error) {
      this.error.set(apiError(error, 'Сочетание сохранить не удалось.'));
      await this.reload();
      return false;
    } finally {
      this.busy.set(false);
    }
  }
}
