import { Injectable, inject } from '@angular/core';
import { Observable, catchError, map, shareReplay, tap, throwError } from 'rxjs';
import { ApiService } from '../../core/api.service';

/**
 * Кэш чтений, ОБЩИЙ для всех страниц профессий.
 *
 * Без него каждая вкладка при открытии заново качала одни и те же
 * справочники: материалы (460 КБ) тянули шесть страниц из десяти, основы
 * (1.1 МБ) - четыре, и переход «Основы -> Именные» стоил 4.5 МБ повторной
 * загрузки. Служба заводится на каждой странице своя (`providers`), поэтому
 * кэш лежит на уровне модуля, а не в экземпляре.
 *
 * Живёт минуту и сбрасывается ЦЕЛИКОМ любой правкой через эту службу:
 * справочники связаны накрест (материал в основе, основа в сочетании), и
 * сбрасывать по одному адресу - значит однажды забыть соседний. Каждый
 * потребитель получает свою копию (`structuredClone`): страницы правят строки
 * на месте, и без копии черновик одной вкладки уезжал бы в другую.
 */
const CACHE_TTL_MS = 60_000;
const cache = new Map<string, { at: number; data: Observable<unknown> }>();

/**
 * Одна служба на все страницы профессий, а не по службе на страницу.
 *
 * Справочники тут связаны накрест: материал ссылается на род из справочника,
 * ячейка типа - на тот же род, основа - на тип и на материалы. Разрезав вызовы
 * по страницам, мы бы получили пять описаний одного и того же `Material`,
 * которые разойдутся на первой же правке модели.
 */

/** Строка `item_template`, как её отдаёт модуль рядом со своей записью. */
export interface ItemBrief {
  entry: number;
  name: string;
  quality: number;
  ilvl: number;
  icon: string;
}

/** Строка справочника рода ячейки либо типа вставки: форма у них одна. */
export interface DictRow {
  id: number;
  code: string;
  name_ru: string;
  sort: number;
  enabled: boolean;
}

export interface QualityTier {
  quality: number;
  name_ru: string;
  slots: number;
}

export interface TypePreset {
  id: string;
  label: string;
  item_class: number;
  item_subclass: number;
  displayid: number;
}

export interface ProfessionsMeta {
  available: boolean;
  has_revision: boolean;
  revision: number;
  stats: Record<string, string>;
  item_classes: Record<string, string>;
  weapon_subclasses: Record<string, string>;
  armor_subclasses: Record<string, string>;
  part_kinds: DictRow[];
  insert_types: DictRow[];
  type_presets: TypePreset[];
  qualities: QualityTier[];
  max_slots: number;
  result_block: { lo: number; hi: number };
  bands: unknown;
  icon_base_url: string;
}

export interface Material {
  entry: number;
  role: 'base' | 'insert';
  part_kind_id: number;
  insert_type_id: number;
  stat_type: number;
  stat_value: number;
  name_ru: string;
  enabled: boolean;
  ilvl_min: number;
  ilvl_max: number;
  quality_min: number;
  quality_max: number;
  /** Качество самой строки item_template - по нему идёт строгое совпадение. */
  quality: number;
  item: ItemBrief | null;
  missing: boolean;
}

export interface ItemType {
  id: number;
  code: string;
  name_ru: string;
  sub_ru: string;
  item_class: number;
  item_subclass: number;
  displayid: number;
  sheet_art: string;
  sort: number;
  fail_entry: number;
  enabled: boolean;
  /** Считает сервер: ячеек всего, из них обязательных, и сколько основ. */
  parts: number;
  required_parts: number;
  recipes: number;
  fail_item: ItemBrief | null;
  icon: string;
  issues: string[];
}

export interface TypePart {
  type_id: number;
  idx: number;
  label_ru: string;
  part_kind_id: number;
  required: number;
  /** Сколько материалов этого рода заведено: ноль - тип некуем. */
  choices: number;
}

/** Ячейка основы: что лежит в части схемы и сколько его надо. */
export interface RecipeCell {
  part_idx: number;
  item_entry: number;
  count: number;
  label_ru: string;
  part_kind_id: number;
  required: number;
  item: ItemBrief | null;
  /** Ячейки, которой в схеме типа уже нет: схему перекроили после основы. */
  orphan?: boolean;
}

/** Изделие на ступени качества плюс нарезанный ей слайс пула id. */
export interface RecipeResult {
  quality: number;
  result_entry: number;
  pool_lo: number;
  pool_hi: number;
  item: ItemBrief | null;
}

/**
 * Что выходит на ступени качества: сколько гнёзд даёт изделие, сколько камней
 * им подходит и сколько разных наборов из этого собирается. Ноль камней при
 * живых гнёздах - основу включить не дадут.
 */
export interface InlayStep {
  quality: number;
  slots: number;
  gems: number;
  gem_entries: number[];
  patterns: number;
}

export interface Recipe {
  id: number;
  type_id: number;
  name_ru: string;
  req_skill: number;
  teach_item: number;
  quality_min: number;
  quality_max: number;
  /** 'forge' куётся на верстаке, 'drop' приходит только добычей. */
  acquire: 'forge' | 'drop';
  enabled: boolean;
  type_name: string;
  teach: ItemBrief | null;
  cells: RecipeCell[];
  results: RecipeResult[];
  insert_types: number[];
  materials: number[];
  steps: number;
  ready_steps: number;
  inlay: InlayStep[];
  issues: string[];
}

export type RecipePatch = Pick<
  Recipe,
  | 'id'
  | 'type_id'
  | 'name_ru'
  | 'req_skill'
  | 'teach_item'
  | 'quality_min'
  | 'quality_max'
  | 'acquire'
  | 'enabled'
>;

/** Ячейка схемы плюс то, что вообще можно в неё положить. */
export interface RecipeCellRow {
  part_idx: number;
  label_ru: string;
  part_kind_id: number;
  required: number;
  item_entry: number;
  count: number;
  options: { entry: number; name: string }[];
}

export interface RecipeCellsPage {
  recipe_id: number;
  name_ru: string;
  type_id: number;
  rows: RecipeCellRow[];
}

/**
 * Именное сочетание: набор вставок в одной основе даёт СВОЙ предмет.
 *
 * Принадлежит основе (DESIGN §5.6): те же два камня в щите
 * либо дадут собственное сочетание щита, либо не дадут ничего.
 */
export interface Synergy {
  id: number;
  name_ru: string;
  recipe_id: number;
  recipe_name: string;
  /** Сколько вставок влезет в лучший вариант основы. */
  recipe_slots: number;
  mats: number[];
  items: (ItemBrief | null)[];
  result_entry: number;
  result: ItemBrief | null;
  teach_item: number;
  teach: ItemBrief | null;
  order_matters: boolean;
  enabled: boolean;
  issues: string[];
}

export type SynergyPatch = Pick<
  Synergy,
  'id' | 'name_ru' | 'recipe_id' | 'mats' | 'result_entry' | 'teach_item' | 'order_matters' | 'enabled'
>;

/**
 * Объединение - третий род рецепта (DESIGN §5.8): в середину стола кладут
 * ЛЮБУЮ вещь подходящего типа, в пять ячеек что угодно, и выходит готовый
 * предмет. Навыка стол не требует, броска не делает, а несовпавший набор не
 * тратит ничего.
 */
export interface Merge {
  id: number;
  name_ru: string;
  type_id: number;
  type_name: string;
  items: number[];
  item_rows: (ItemBrief | null)[];
  result_entry: number;
  result: ItemBrief | null;
  teach_item: number;
  teach: ItemBrief | null;
  enabled: boolean;
  issues: string[];
}

export type MergePatch = Pick<
  Merge,
  'id' | 'name_ru' | 'type_id' | 'items' | 'result_entry' | 'teach_item' | 'enabled'
>;

/** Ответ проверки набора: та же выкладка, что делает сервер при ковке. */
export interface MatchResult {
  cells: { idx: number; label: string; entry: number; name: string; count: number }[];
  spend: { entry: number; name: string; count: number }[];
  fail_mode: number;
  fail_entry: number;
  fail_item: ItemBrief | null;
  recipe: {
    id: number;
    name_ru: string;
    req_skill: number;
    quality_min: number;
    quality_max: number;
    results: { quality: number; result_entry: number; item: ItemBrief | null }[];
    issues: string[];
  } | null;
  chance?: { chance: number; gap: number; floor: number };
  note: string;
  inserts: { entry: number; name: string; stat_type: number; value: number }[];
  totals: { stat_type: number; value: number }[];
  synergy: { id: number; name: string; result_entry: number; result: ItemBrief | null } | null;
  finish_warning: boolean;
}

/**
 * Проверка именного: основа выбрана прямо, ячейки не нужны. Вставки, сумма и
 * сочетание - те же, что во второй половине `MatchResult`.
 */
export interface NamedMatchResult {
  recipe: {
    id: number;
    name_ru: string;
    enabled: boolean;
    inlay: { quality: number; slots: number; gems: number; patterns: number }[];
  };
  inserts: MatchResult['inserts'];
  totals: MatchResult['totals'];
  synergy: MatchResult['synergy'];
  finish_warning: boolean;
  /** Все сочетания этой основы - чтобы было с чем сверить набор. */
  known: { id: number; name: string; mats: number[]; enabled: boolean }[];
}

/** Что уже выдано из пула и сколько заготовок осталось. */
export interface PoolSlice {
  recipe_id: number;
  quality: number;
  result_entry: number;
  name_ru: string;
  lo: number;
  hi: number;
  blanks: number;
  used: number;
  free: number;
}

export interface PoolState {
  lo: number;
  hi: number;
  size: number;
  blanks: number;
  free: number;
  types: PoolSlice[];
  missing: { recipe_id: number; quality: number; result_entry: number; name_ru: string }[];
  stride: number;
  seed: number;
  orphans: number;
  gc_enabled: boolean;
}

export interface GeneratedRow {
  entry: number;
  source_entry: number;
  recipe_id: number;
  mats: string;
  created_at: string;
}

export interface Generated {
  rows: GeneratedRow[];
  total: number;
  pool: PoolState;
}

export interface QualityRow {
  quality: number;
  name_ru: string;
  slots: number;
}

export interface Balance {
  qualities: QualityRow[];
  /** {«качество»: вес}. Проценты качества ГЛОБАЛЬНЫЕ - одна таблица на модуль. */
  chances: Record<string, number>;
}

/** Уровень предмета -> требуемый уровень персонажа (DESIGN §5.5). */
export interface IlvlRow {
  ilvl_max: number;
  req_level: number;
}

export interface SettingRow {
  name: string;
  value: string;
  comment: string;
}

export interface DisplayLook {
  display_id: number;
  entry: number;
  name: string;
  icon: string;
  used_by: number;
}

/** Тело PUT: сервер ждёт только колонки, без счётчиков и вложенных строк. */
export type MaterialPatch = Omit<Material, 'item' | 'missing' | 'quality'>;
export type TypePatch = Omit<
  ItemType,
  'parts' | 'required_parts' | 'recipes' | 'fail_item' | 'icon' | 'issues'
>;
export type PartPatch = Omit<TypePart, 'choices'>;

@Injectable()
export class ProfessionsApi {
  private readonly api = inject(ApiService);

  private get<T>(path: string): Observable<T> {
    const hit = cache.get(path);
    if (!hit || Date.now() - hit.at > CACHE_TTL_MS) {
      const data = this.api.get<T>(path).pipe(
        catchError((error) => {
          cache.delete(path);
          return throwError(() => error);
        }),
        shareReplay(1),
      );
      cache.set(path, { at: Date.now(), data });
      return data.pipe(map((value) => structuredClone(value)));
    }
    return (hit.data as Observable<T>).pipe(map((value) => structuredClone(value)));
  }

  /** Любая запись сбрасывает кэш - и при успехе, и при отказе. */
  private write<T>(request: Observable<T>): Observable<T> {
    return request.pipe(
      tap({ next: () => cache.clear(), error: () => cache.clear() }),
    );
  }

  private put<T>(path: string, body: unknown) {
    return this.write(this.api.put<T>(path, body));
  }

  private post<T>(path: string, body?: unknown) {
    return this.write(this.api.post<T>(path, body));
  }

  private delete<T>(path: string) {
    return this.write(this.api.delete<T>(path));
  }

  meta() {
    return this.get<ProfessionsMeta>('/aprof/meta');
  }

  // --- материалы ----------------------------------------------------------

  materials() {
    return this.get<{ materials: Material[] }>('/aprof/materials');
  }

  saveMaterial(material: MaterialPatch) {
    return this.put<{ entry: number }>('/aprof/materials', material);
  }

  deleteMaterial(entry: number) {
    return this.delete<{ ok: boolean }>(`/aprof/materials/${entry}`);
  }

  // --- справочники --------------------------------------------------------
  // Два адреса, а не один с параметром: так и права, и ссылки читаются без
  // оговорок. Форма тела у них общая, поэтому путь - обычный параметр.

  dictRows(path: 'part-kinds' | 'insert-types') {
    return this.get<{ rows: DictRow[] }>(`/aprof/${path}`);
  }

  saveDictRow(path: 'part-kinds' | 'insert-types', row: DictRow) {
    return this.put<{ id: number }>(`/aprof/${path}`, row);
  }

  deleteDictRow(path: 'part-kinds' | 'insert-types', id: number) {
    return this.delete<{ ok: boolean }>(`/aprof/${path}/${id}`);
  }

  // --- типы и их схемы ----------------------------------------------------

  types() {
    return this.get<{ types: ItemType[] }>('/aprof/types');
  }

  saveType(type: TypePatch) {
    return this.put<{ id: number }>('/aprof/types', type);
  }

  deleteType(id: number) {
    return this.delete<{ ok: boolean }>(`/aprof/types/${id}`);
  }

  makeFailItem(typeId: number, sampleEntry: number) {
    return this.post<{ entry: number }>(`/aprof/types/${typeId}/fail-item`, {
      sample_entry: sampleEntry,
    });
  }

  parts(typeId: number) {
    return this.get<{ parts: TypePart[] }>(`/aprof/types/${typeId}/parts`);
  }

  savePart(typeId: number, part: PartPatch) {
    return this.put<{ idx: number }>(`/aprof/types/${typeId}/parts`, {
      ...part,
      type_id: typeId,
    });
  }

  deletePart(typeId: number, idx: number) {
    return this.delete<{ ok: boolean }>(`/aprof/types/${typeId}/parts/${idx}`);
  }

  // --- основы -------------------------------------------------------------

  recipes() {
    return this.get<{ recipes: Recipe[] }>('/aprof/recipes');
  }

  saveRecipe(recipe: RecipePatch) {
    // `note` приходит, когда сервер принял строку, но с оговоркой, - например
    // выключил основу, у которой пропало изделие.
    return this.put<{ id: number; note?: string }>('/aprof/recipes', recipe);
  }

  deleteRecipe(id: number) {
    return this.delete<{ ok: boolean }>(`/aprof/recipes/${id}`);
  }

  recipeCells(recipeId: number) {
    return this.get<RecipeCellsPage>(`/aprof/recipes/${recipeId}/cells`);
  }

  saveRecipeCell(recipeId: number, cell: { part_idx: number; item_entry: number; count: number }) {
    return this.put<{ ok: boolean }>(`/aprof/recipes/${recipeId}/cells`, cell);
  }

  saveRecipeFilters(recipeId: number, filters: { insert_types: number[]; materials: number[] }) {
    return this.put<{ ok: boolean }>(`/aprof/recipes/${recipeId}/filters`, filters);
  }

  saveRecipeResult(recipeId: number, result: { quality: number; result_entry: number }) {
    return this.put<{ ok: boolean }>(`/aprof/recipes/${recipeId}/results`, result);
  }

  generateResults(recipeId: number, sampleEntry: number) {
    return this.post<{ created: number[]; skipped: number[] }>(
      `/aprof/recipes/${recipeId}/results/generate`,
      { sample_entry: sampleEntry },
    );
  }

  /** Нарезать слайс пула ступени и засеять его по виду изделия. */
  reslice(recipeId: number, quality: number) {
    return this.post<{ lo: number; hi: number; seeded: number }>(
      `/aprof/recipes/${recipeId}/results/${quality}/slice`,
    );
  }

  // --- проверка набора ----------------------------------------------------

  match(body: {
    type_id: number;
    mats: number[];
    skill: number;
    part_mats: number[];
    part_counts: number[];
  }) {
    return this.api.post<MatchResult>('/aprof/match', body); // чтение: кэш не трогает
  }

  matchNamed(body: { recipe_id: number; mats: number[] }) {
    return this.api.post<NamedMatchResult>('/aprof/match-named', body); // чтение
  }

  // --- пул id -------------------------------------------------------------

  generated(limit = 200) {
    return this.get<Generated>(`/aprof/generated?limit=${limit}`);
  }

  // --- именные сочетания --------------------------------------------------

  synergies() {
    return this.get<{ synergies: Synergy[] }>('/aprof/synergies');
  }

  saveSynergy(synergy: SynergyPatch) {
    return this.put<{ id: number; note?: string }>('/aprof/synergies', synergy);
  }

  deleteSynergy(id: number) {
    return this.delete<{ ok: boolean }>(`/aprof/synergies/${id}`);
  }

  makeNamedItem(synergyId: number, sampleEntry: number) {
    return this.post<{ entry: number }>(`/aprof/synergies/${synergyId}/named-item`, {
      sample_entry: sampleEntry,
    });
  }

  // --- объединение --------------------------------------------------------

  merges() {
    return this.get<{ merges: Merge[] }>('/aprof/merges');
  }

  saveMerge(merge: MergePatch) {
    return this.put<{ id: number; note?: string }>('/aprof/merges', merge);
  }

  deleteMerge(id: number) {
    return this.delete<{ ok: boolean }>(`/aprof/merges/${id}`);
  }

  makeMergeItem(mergeId: number, sampleEntry: number) {
    return this.post<{ entry: number }>(`/aprof/merges/${mergeId}/result-item`, {
      sample_entry: sampleEntry,
    });
  }

  // --- баланс -------------------------------------------------------------

  balance() {
    return this.get<Balance>('/aprof/balance');
  }

  saveBalance(balance: Balance) {
    return this.put<{ ok: boolean }>('/aprof/balance', balance);
  }

  ilvlLevels() {
    return this.get<{ rows: IlvlRow[] }>('/aprof/ilvl-levels');
  }

  saveIlvlLevels(rows: IlvlRow[]) {
    return this.put<{ rows: IlvlRow[] }>('/aprof/ilvl-levels', rows);
  }

  settings() {
    return this.get<{ settings: SettingRow[] }>('/aprof/settings');
  }

  saveSettings(values: Record<string, string>) {
    return this.put<{ settings: SettingRow[] }>('/aprof/settings', values);
  }

  // --- внешний вид --------------------------------------------------------

  displays(params: {
    q?: string;
    itemClass?: number;
    itemSubclass?: number;
    limit: number;
    offset: number;
  }) {
    const query = new URLSearchParams();
    if (params.q) query.set('q', params.q);
    if (params.itemClass !== undefined) query.set('item_class', String(params.itemClass));
    if (params.itemSubclass !== undefined) query.set('item_subclass', String(params.itemSubclass));
    query.set('limit', String(params.limit));
    query.set('offset', String(params.offset));
    return this.get<{ displays: DisplayLook[]; total: number }>(`/aprof/displays?${query}`);
  }
}
