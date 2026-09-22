import { Component, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { ToastService } from '../../shared/ui/toast.service';
import { ProfItemComponent } from './item-cell.component';
import { RelationsGraphComponent } from './relations-graph.component';
import {
  ItemType,
  Material,
  ProfessionsApi,
  ProfessionsMeta,
  Recipe,
  RecipeCell,
  Synergy,
} from './professions.api';
import { ACQUIRE, BLANK_ICON, apiError, iconUrl, qualityName, useBlankIcon } from './professions.model';

type Dir = 'base' | 'named' | 'graph';

/**
 * Карта связей: что из чего выходит.
 *
 * Три вида одной и той же сетки. «Основы → эскизы» отвечает на вопрос «что я
 * могу сделать», обратный - «откуда берётся вот эта вещь», а диаграмма
 * показывает всё разом, без выбора типа.
 *
 * Своих запросов у карточных видов нет: данные те же, что у страниц рецептов
 * и именных, - карта их только раскладывает.
 */
@Component({
  imports: [ProfItemComponent, RelationsGraphComponent, RouterLink],
  providers: [ProfessionsApi],
  selector: 'app-professions-relations-page',
  styleUrl: './relations.page.scss',
  templateUrl: './relations.page.html',
})
export class ProfessionsRelationsPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  readonly modes: readonly (readonly [Dir, string])[] = [
    ['base', 'Основы → эскизы'],
    ['named', 'Эскизы → основы'],
    ['graph', 'Диаграмма'],
  ];

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly types = signal<ItemType[]>([]);
  readonly recipes = signal<Recipe[]>([]);
  readonly synergies = signal<Synergy[]>([]);
  readonly materials = signal<Material[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  readonly dir = signal<Dir>('base');
  readonly typeId = signal(0);

  readonly iconBase = computed(() => this.meta()?.icon_base_url ?? '');

  /** Основы выбранного типа, по возрастанию требуемого навыка. */
  readonly typeRecipes = computed(() =>
    this.recipesOf(this.typeId()).sort(
      (a, b) => a.req_skill - b.req_skill || a.id - b.id,
    ),
  );

  readonly typeSynergies = computed(() =>
    this.synergies().filter((syn) => this.typeRecipes().some((rec) => rec.id === syn.recipe_id)),
  );

  readonly stepCount = computed(() =>
    this.typeRecipes().reduce((sum, rec) => sum + rec.results.length, 0),
  );

  constructor() {
    this.toast.announce(this.error, 'error');
    const params = this.route.snapshot.queryParamMap;
    const dir = params.get('view');
    if (dir === 'base' || dir === 'named' || dir === 'graph') this.dir.set(dir);
    this.typeId.set(Number(params.get('type')) || 0);
    void this.load();
  }

  async load(): Promise<void> {
    this.loading.set(true);
    try {
      const meta = await firstValueFrom(this.api.meta());
      this.meta.set(meta);
      if (meta.available) {
        const [types, recipes, synergies, materials] = await Promise.all([
          firstValueFrom(this.api.types()),
          firstValueFrom(this.api.recipes()),
          firstValueFrom(this.api.synergies()),
          firstValueFrom(this.api.materials()),
        ]);
        this.types.set(types.types);
        this.recipes.set(recipes.recipes);
        this.synergies.set(synergies.synergies);
        this.materials.set(materials.materials);
        if (!this.typeId() && types.types.length) this.typeId.set(types.types[0].id);
      }
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось собрать карту связей.'));
    } finally {
      this.loading.set(false);
    }
  }

  // --- вид ------------------------------------------------------------------

  setDir(dir: Dir): void {
    this.dir.set(dir);
    this.patchUrl();
  }

  setType(id: number): void {
    this.typeId.set(id);
    this.patchUrl();
  }

  /** Вид и тип живут в адресе: «вот эта сетка» должна открываться ссылкой. */
  private patchUrl(): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      replaceUrl: true,
      queryParamsHandling: 'merge',
      queryParams: {
        view: this.dir() === 'base' ? null : this.dir(),
        type: this.typeId() || null,
      },
    });
  }

  // --- данные ---------------------------------------------------------------

  recipesOf(typeId: number): Recipe[] {
    return this.recipes().filter((rec) => rec.type_id === typeId);
  }

  synergiesOf(recipeId: number): Synergy[] {
    return this.synergies().filter((syn) => syn.recipe_id === recipeId);
  }

  ownerOf(syn: Synergy): Recipe | null {
    return this.recipes().find((rec) => rec.id === syn.recipe_id) ?? null;
  }

  filledCells(rec: Recipe): RecipeCell[] {
    return rec.cells.filter((cell) => cell.item_entry);
  }

  acquireName(acquire: string): string {
    return ACQUIRE[acquire] ?? acquire;
  }

  tierName(quality: number): string {
    return qualityName(this.meta(), quality);
  }

  // --- камни ----------------------------------------------------------------

  private mat(entry: number): Material | null {
    return this.materials().find((row) => row.entry === entry) ?? null;
  }

  gemIcon(entry: number): string {
    const item = this.mat(entry)?.item;
    return item?.icon ? iconUrl(item.icon, this.iconBase()) : BLANK_ICON;
  }

  gemName(entry: number): string {
    const mat = this.mat(entry);
    return mat?.name_ru || mat?.item?.name || `id ${entry}`;
  }

  gemClass(entry: number): string {
    const item = this.mat(entry)?.item;
    return item ? `q${item.quality}` : 'warn';
  }

  onIconError(event: Event): void {
    useBlankIcon(event);
  }

  // --- ступени --------------------------------------------------------------

  tierFacts(rec: Recipe, quality: number): string {
    const step = rec.inlay.find((row) => row.quality === quality);
    return step?.slots
      ? `${step.slots} гн. · камней ${step.gems} · эскизов ${step.patterns}`
      : 'гнёзд нет';
  }

  tierDry(rec: Recipe, quality: number): boolean {
    const step = rec.inlay.find((row) => row.quality === quality);
    return !!step?.slots && !step.gems;
  }

  /** Сколько гнёзд даёт лучшая ступень основы: по ней и судим достижимость. */
  private bestSlots(rec: Recipe | null): number {
    return Math.max(0, ...(rec?.inlay ?? []).map((step) => step.slots));
  }

  /**
   * Достижимость - главное, что карта обязана показать: эскиз длиннее, чем
   * гнёзд у лучшей ступени основы, не соберёт никто (DESIGN §5.6).
   */
  reachNote(rec: Recipe, syn: Synergy): string {
    const need = syn.mats.length;
    if (!need) return 'набор пуст';
    const best = this.bestSlots(rec);
    return best && need > best
      ? `нужно гнёзд: ${need}, а лучшая ступень основы даёт ${best}`
      : `гнёзд нужно: ${need}`;
  }

  reachWarn(rec: Recipe | null, syn: Synergy): boolean {
    const need = syn.mats.length;
    if (!need) return true;
    if (!rec) return true;
    const fit = rec.inlay.filter((step) => step.slots >= need);
    return !fit.length;
  }

  fitNote(rec: Recipe | null, syn: Synergy): string {
    const need = syn.mats.length;
    const fit = (rec?.inlay ?? []).filter((step) => step.slots >= need);
    return fit.length
      ? `собирается на ступенях: ${fit.map((step) => this.tierName(step.quality)).join(', ')}`
      : 'ни одна ступень основы не даёт столько гнёзд';
  }
}
