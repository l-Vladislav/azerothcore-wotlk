import { Component, computed, inject, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { TablePagerComponent } from '../../shared/data/table-pager.component';
import { ItemPickerComponent, PickedItem } from '../../shared/ui/item-picker.component';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { ToastService } from '../../shared/ui/toast.service';
import { ProfFiltersComponent } from './filter-bar.component';
import { ProfItemComponent } from './item-cell.component';
import { ListSpec, ListView, SortHeadComponent } from './list-view';
import {
  DictRow,
  Material,
  MaterialPatch,
  ProfessionsApi,
  ProfessionsMeta,
} from './professions.api';
import {
  ROLES,
  apiError,
  dictName,
  dictOptions,
  firstDictId,
  qualityName,
  statName,
} from './professions.model';
import { IconComponent } from '../../shared/ui/icon.component';
import { ProfessionsTabsComponent } from './professions-tabs.component';
import { AddDialogComponent } from './add-dialog.component';

/**
 * Материалы верстака: что кладут в ячейки схемы и чем украшают готовую вещь.
 *
 * Признак у материала РОВНО ОДИН, и какой - решает роль: у материала ячейки
 * род («металл»), у камня тип вставки («самоцвет») (DESIGN §2.5). Поэтому
 * колонка одна, а её список меняется вместе с ролью; смена роли уносит с собой
 * и признак - род у камня сервер не примет, а пустой признак тем более.
 */
@Component({
  imports: [
    AddDialogComponent,
    ProfessionsTabsComponent,
    IconComponent,
    FormsModule,
    ForgeSelectDirective,
    ItemPickerComponent,
    ProfFiltersComponent,
    ProfItemComponent,
    SortHeadComponent,
    TablePagerComponent,
  ],
  providers: [ProfessionsApi],
  selector: 'app-professions-materials-page',
  styleUrl: './materials.page.scss',
  templateUrl: './materials.page.html',
})
export class ProfessionsMaterialsPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);
  private readonly picker = viewChild.required(ItemPickerComponent);
  readonly auth = inject(AuthService);

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly rows = signal<Material[]>([]);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');
  readonly iconBase = computed(() => this.meta()?.icon_base_url ?? '');
  readonly partKinds = computed<DictRow[]>(() => this.meta()?.part_kinds ?? []);
  readonly insertTypes = computed<DictRow[]>(() => this.meta()?.insert_types ?? []);
  readonly stats = computed(() => Object.entries(this.meta()?.stats ?? {}));
  readonly roles = Object.entries(ROLES);

  readonly spec = computed<ListSpec<Material>>(() => ({
    search: (row) => [row.entry, row.name_ru, row.item?.name].join(' '),
    picks: [
      { key: 'role', label: 'любая роль', options: this.roles, get: (row) => row.role },
      {
        key: 'kind',
        label: 'любой род и тип',
        options: [
          ...this.partKinds().map((row) => [`k${row.id}`, row.name_ru] as const),
          ...this.insertTypes().map((row) => [`t${row.id}`, row.name_ru] as const),
        ],
        get: (row) => (row.role === 'base' ? `k${row.part_kind_id}` : `t${row.insert_type_id}`),
      },
      {
        key: 'quality',
        label: 'любое качество',
        options: (this.meta()?.qualities ?? []).map(
          (tier) => [String(tier.quality), tier.name_ru] as const,
        ),
        get: (row) => String(row.quality || 0),
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
    ],
    sorts: {
      Предмет: (row) => row.item?.name ?? String(row.entry),
      Роль: (row) => ROLES[row.role] ?? row.role,
      'Род / тип': (row) => this.kindName(row),
      Стат: (row) => statName(this.meta(), row.stat_type),
      Величина: (row) => row.stat_value,
      'Илвл от': (row) => row.ilvl_min,
      'Илвл до': (row) => row.ilvl_max,
      'Кач. от': (row) => row.quality_min,
      'Кач. до': (row) => row.quality_max,
      Подпись: (row) => row.name_ru,
      Вкл: (row) => (row.enabled ? 1 : 0),
    },
  }));

  readonly view = new ListView<Material>(this.rows.asReadonly(), this.spec);
  readonly picks = computed(() => this.spec().picks ?? []);

  /**
   * Заводимая строка переживает перерисовку: заводя подряд полсотни камней
   * одного рода, выставлять роль, тип и стат каждый раз заново невозможно.
   */
  readonly draft = signal<MaterialPatch>({
    entry: 0,
    role: 'insert',
    part_kind_id: 0,
    insert_type_id: 0,
    stat_type: 3,
    stat_value: 4,
    name_ru: '',
    enabled: true,
    ilvl_min: 0,
    ilvl_max: 0,
    quality_min: 0,
    quality_max: 0,
  });
  readonly draftItem = signal<PickedItem | null>(null);

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
        this.setDraft({
          part_kind_id: firstDictId(meta.part_kinds),
          insert_type_id: firstDictId(meta.insert_types),
        });
        await this.reload();
      }
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось загрузить справочник профессий.'));
    } finally {
      this.loading.set(false);
    }
  }

  private async reload(): Promise<void> {
    this.rows.set((await firstValueFrom(this.api.materials())).materials);
  }

  // --- полоса добавления ---------------------------------------------------

  openPicker(): void {
    this.picker().open();
  }

  onPicked(item: PickedItem): void {
    this.draftItem.set(item);
    const name = item.name_ru || item.name || '';
    // Подпись у материала своя: она едет в аддон вместо клиентского имени.
    // Подставляем имя предмета, пока владелец не написал другое.
    this.setDraft({ entry: item.entry, name_ru: this.draft().name_ru || name });
  }

  setDraft(patch: Partial<MaterialPatch>): void {
    this.draft.update((draft) => ({ ...draft, ...patch }));
  }

  onDraftRole(role: 'base' | 'insert'): void {
    this.setDraft({
      role,
      part_kind_id: role === 'base' ? firstDictId(this.partKinds()) : 0,
      insert_type_id: role === 'base' ? 0 : firstDictId(this.insertTypes()),
    });
  }

  onDraftKind(id: number): void {
    this.setDraft(this.draft().role === 'base' ? { part_kind_id: id } : { insert_type_id: id });
  }

  draftKindId(): number {
    const draft = this.draft();
    return draft.role === 'base' ? draft.part_kind_id : draft.insert_type_id;
  }

  /** Окно добавления: поля живут там, а не полосой над листом. */
  private readonly adder = viewChild(AddDialogComponent);

  openAdd(): void {
    this.error.set(null);
    this.adder()?.open();
  }

  /** Окно закрывается только после удачной записи - отказ остаётся перед глазами. */
  async submitAdd(): Promise<void> {
    if (await this.add()) this.adder()?.close();
  }

  async add(): Promise<boolean> {
    if (!this.draft().entry) {
      this.error.set('Сначала выберите предмет.');
      return false;
    }
    if (!(await this.put(this.draft()))) return false;
    this.draftItem.set(null);
    this.setDraft({ entry: 0, name_ru: '' });
    return true;
  }

  // --- строки --------------------------------------------------------------

  kindRows(row: Material): DictRow[] {
    const rows = row.role === 'base' ? this.partKinds() : this.insertTypes();
    return dictOptions(rows, row.role === 'base' ? row.part_kind_id : row.insert_type_id);
  }

  kindId(row: Material): number {
    return row.role === 'base' ? row.part_kind_id : row.insert_type_id;
  }

  kindName(row: Material): string {
    return row.role === 'base'
      ? dictName(this.partKinds(), row.part_kind_id)
      : dictName(this.insertTypes(), row.insert_type_id);
  }

  /** Границы уровня и качества - свойства ВСТАВКИ: материал ячейки кладут в
   * схему, а не в готовый предмет, и сравнивать там не с чем. */
  isInsert(row: Material): boolean {
    return row.role !== 'base';
  }

  strictHint(row: Material): string {
    return this.isInsert(row) && !row.quality_min && !row.quality_max
      ? `Строгое совпадение: только вещь качества «${qualityName(this.meta(), row.quality || 0)}».`
      : '';
  }

  statLabel(id: number): string {
    return statName(this.meta(), id);
  }

  async patch(row: Material, fields: Partial<MaterialPatch>): Promise<void> {
    await this.put({ ...this.strip(row), ...fields });
  }

  async onRole(row: Material, role: 'base' | 'insert'): Promise<void> {
    await this.patch(row, {
      role,
      part_kind_id: role === 'base' ? firstDictId(this.partKinds()) : 0,
      insert_type_id: role === 'base' ? 0 : firstDictId(this.insertTypes()),
    });
  }

  async onKind(row: Material, id: number): Promise<void> {
    await this.patch(row, row.role === 'base' ? { part_kind_id: id } : { insert_type_id: id });
  }

  async remove(row: Material): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    if (!confirm(`Убрать материал ${row.name_ru || row.item?.name || row.entry}?`)) return;
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.deleteMaterial(row.entry));
      this.notice.set(`Материал #${row.entry} убран.`);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, `Не удалось убрать материал #${row.entry}.`));
    } finally {
      this.busy.set(false);
    }
  }

  private strip(row: Material): MaterialPatch {
    const { item, missing, quality, ...rest } = row;
    void item;
    void missing;
    void quality;
    return rest;
  }

  private async put(material: MaterialPatch): Promise<boolean> {
    if (!this.canEdit() || this.busy()) return false;
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.saveMaterial(material));
      this.notice.set('Сохранено.');
      await this.reload();
      return true;
    } catch (error) {
      this.error.set(apiError(error, `Не удалось сохранить материал #${material.entry}.`));
      // И на отказе: иначе поле осталось бы стоять там, где сервер его не
      // принял, и страница врала бы о состоянии базы.
      await this.reload();
      return false;
    } finally {
      this.busy.set(false);
    }
  }
}
