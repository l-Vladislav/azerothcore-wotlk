import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { ToastService } from '../../shared/ui/toast.service';
import {
  ItemType,
  Material,
  MatchResult,
  NamedMatchResult,
  ProfessionsApi,
  ProfessionsMeta,
  Recipe,
  TypePart,
} from './professions.api';
import { apiError, qualityName, statName } from './professions.model';
import { ProfessionsTabsComponent } from './professions-tabs.component';

/**
 * Проверка набора: что выйдет у верстака, не заходя в игру.
 *
 * Две проверки, а не одна (решение владельца 2026-09-23):
 *  - «Основа» - набор в ячейках: какая основа совпала, шанс, качество, изделия;
 *  - «Именной» - основа выбирается из списка, в слоты кладутся вставки: какое
 *    сочетание выйдет. Раньше, чтобы проверить эскиз, приходилось сначала
 *    собрать саму основу по ячейкам, хотя к камням она отношения не имеет.
 *
 * Ответ считает СЕРВЕР (`/aprof/match`, `/aprof/match-named`) - иначе
 * страница показывала бы свою версию правил, и расхождение с игрой заметили бы
 * последним.
 */
@Component({
  imports: [ProfessionsTabsComponent, FormsModule, ForgeSelectDirective],
  providers: [ProfessionsApi],
  selector: 'app-professions-preview-page',
  styleUrl: './preview.page.scss',
  templateUrl: './preview.page.html',
})
export class ProfessionsPreviewPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly types = signal<ItemType[]>([]);
  readonly materials = signal<Material[]>([]);
  readonly parts = signal<TypePart[]>([]);
  readonly loading = signal(true);
  /** Ячейки типа читаются отдельно: форма не ждёт их, чтобы показаться. */
  readonly partsLoading = signal(false);
  /**
   * Список, у которого варианты нарисованы целиком. Вставок ~500, и пять
   * полных списков слотов плюс ячейки давали пять тысяч `<option>` - страница
   * замирала на их отрисовке. Меню кита читает варианты в момент раскрытия, а к
   * этому моменту мышь или фокус уже на списке.
   */
  readonly openList = signal<string | null>(null);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);

  readonly mode = signal<'base' | 'named'>('base');
  readonly modes = [
    ['base', 'Основа'],
    ['named', 'Именной'],
  ] as const;

  readonly typeId = signal(0);
  readonly skill = signal(300);
  readonly slots = signal<number[]>([]);
  /** Набор по ячейкам: ключ - номер части, значение - предмет и его расход. */
  readonly partMats = signal<Record<number, number>>({});
  readonly partCounts = signal<Record<number, number>>({});
  readonly result = signal<MatchResult | null>(null);

  // --- именной: основа из списка, ячейки не нужны ---
  /** Основы читаются, только когда открыли именную проверку: это 1.1 МБ. */
  readonly recipes = signal<Recipe[]>([]);
  readonly recipesLoading = signal(false);
  readonly namedTypeId = signal(0);
  readonly baseId = signal(0);
  readonly namedResult = signal<NamedMatchResult | null>(null);
  /** Основы выбранного типа - список короткий (у меча их под две сотни). */
  readonly typeBases = computed(() =>
    this.recipes()
      .filter((rec) => rec.type_id === this.namedTypeId())
      .sort((a, b) => a.name_ru.localeCompare(b.name_ru, 'ru')),
  );

  readonly inserts = computed(() => this.materials().filter((mat) => mat.role !== 'base'));
  private readonly byEntry = computed(
    () => new Map(this.materials().map((mat) => [mat.entry, mat] as const)),
  );
  /** Материалы ячеек по роду - один раз на загрузку, а не фильтром на каждую отрисовку. */
  private readonly byKind = computed(() => {
    const out = new Map<number, Material[]>();
    for (const mat of this.materials()) {
      if (mat.role !== 'base') continue;
      const list = out.get(mat.part_kind_id) ?? [];
      list.push(mat);
      out.set(mat.part_kind_id, list);
    }
    return out;
  });

  constructor() {
    this.toast.announce(this.error, 'error');
    void this.load();
  }

  async load(): Promise<void> {
    this.loading.set(true);
    try {
      // Три чтения разом, а не цепочкой: справочники от `meta` не зависят, и
      // ждать его ответа, чтобы только потом их спросить, - лишний круг.
      // Если модуля нет, два лишних ответа просто выбрасываются.
      const [meta, types, materials] = await Promise.all([
        firstValueFrom(this.api.meta()),
        firstValueFrom(this.api.types()),
        firstValueFrom(this.api.materials()),
      ]);
      this.meta.set(meta);
      if (meta.available) {
        this.slots.set(Array.from({ length: meta.max_slots }, () => 0));
        this.types.set(types.types);
        this.materials.set(materials.materials);
        // Ячейки не ждём: форма показывается сразу, ячейки дорисуются сами.
        if (types.types.length) {
          void this.onType(types.types[0].id);
          this.namedTypeId.set(types.types[0].id);
        }
      }
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось загрузить справочники.'));
    } finally {
      this.loading.set(false);
    }
  }

  /** Ячейки зависят от типа, поэтому читаются заново при каждой смене. */
  async onType(id: number): Promise<void> {
    this.typeId.set(id);
    this.partMats.set({});
    this.partCounts.set({});
    this.result.set(null);
    // Ячейки прежнего типа убираются СРАЗУ: пока новые в пути, на экране
    // висели бы чужие части (клинок у щита). Ответ, пришедший уже после
    // следующей смены типа, выбрасывается.
    this.parts.set([]);
    this.partsLoading.set(true);
    try {
      const parts = (await firstValueFrom(this.api.parts(id))).parts;
      if (this.typeId() === id) this.parts.set(parts);
    } catch {
      // У типа может не быть ячеек вовсе - это не отказ, а пустая схема.
      if (this.typeId() === id) this.parts.set([]);
    } finally {
      if (this.typeId() === id) this.partsLoading.set(false);
    }
  }

  async setMode(mode: 'base' | 'named'): Promise<void> {
    this.mode.set(mode);
    this.error.set(null);
    if (mode !== 'named' || this.recipes().length || this.recipesLoading()) return;
    this.recipesLoading.set(true);
    try {
      this.recipes.set((await firstValueFrom(this.api.recipes())).recipes);
      this.pickFirstBase();
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось загрузить основы.'));
    } finally {
      this.recipesLoading.set(false);
    }
  }

  onNamedType(id: number): void {
    this.namedTypeId.set(id);
    this.namedResult.set(null);
    this.pickFirstBase();
  }

  onBase(id: number): void {
    this.baseId.set(id);
    this.namedResult.set(null);
  }

  private pickFirstBase(): void {
    this.baseId.set(this.typeBases()[0]?.id ?? 0);
  }

  /** Подставить в слоты набор сочетания - сверить его, не набирая руками. */
  useSynergy(mats: number[]): void {
    const size = this.slots().length;
    this.slots.set(Array.from({ length: size }, (_, i) => mats[i] ?? 0));
    void this.checkNamed();
  }

  synergyMats(mats: number[]): string {
    return mats.map((entry) => this.entryName(entry)).join(', ');
  }

  matName(mat: Material): string {
    return mat.name_ru || mat.item?.name || String(mat.entry);
  }

  /** Ячейка «лезвие» ждёт металл: ткань в ней сделала бы набор несобираемым. */
  partOptions(kindId: number): Material[] {
    return this.byKind().get(kindId) ?? [];
  }

  /** Подпись выбранного материала, пока полный список не нарисован. */
  entryName(entry: number): string {
    const mat = this.byEntry().get(entry);
    return mat ? this.matName(mat) : String(entry);
  }

  partMat(idx: number): number {
    return this.partMats()[idx] ?? 0;
  }

  partCount(idx: number): number {
    return this.partCounts()[idx] ?? 1;
  }

  setSlot(index: number, entry: number): void {
    this.slots.update((slots) => slots.map((slot, at) => (at === index ? entry : slot)));
  }

  setPartMat(idx: number, entry: number): void {
    this.partMats.update((mats) => ({ ...mats, [idx]: entry }));
  }

  setPartCount(idx: number, count: number): void {
    this.partCounts.update((counts) => ({ ...counts, [idx]: count }));
  }

  tierName(quality: number): string {
    return qualityName(this.meta(), quality);
  }

  statLabel(id: number): string {
    return statName(this.meta(), id);
  }

  spendText(out: MatchResult): string {
    return out.spend.map((row) => `${row.name} ×${row.count}`).join(', ');
  }

  async check(): Promise<void> {
    if (this.busy()) return;
    this.busy.set(true);
    try {
      const parts = this.parts();
      this.result.set(
        await firstValueFrom(
          this.api.match({
            type_id: this.typeId(),
            skill: this.skill(),
            // Вставки проверяет именная проверка: ковке они ни к чему.
            mats: [],
            part_mats: parts.map((part) => this.partMat(part.idx)),
            part_counts: parts.map((part) => this.partCount(part.idx)),
          }),
        ),
      );
      this.error.set(null);
    } catch (error) {
      this.result.set(null);
      this.error.set(apiError(error, 'Проверка не ответила.'));
    } finally {
      this.busy.set(false);
    }
  }

  async checkNamed(): Promise<void> {
    if (this.busy()) return;
    if (!this.baseId()) {
      this.error.set('Выберите основу.');
      return;
    }
    this.busy.set(true);
    try {
      this.namedResult.set(
        await firstValueFrom(
          this.api.matchNamed({ recipe_id: this.baseId(), mats: this.slots().filter(Boolean) }),
        ),
      );
      this.error.set(null);
    } catch (error) {
      this.namedResult.set(null);
      this.error.set(apiError(error, 'Проверка не ответила.'));
    } finally {
      this.busy.set(false);
    }
  }
}
