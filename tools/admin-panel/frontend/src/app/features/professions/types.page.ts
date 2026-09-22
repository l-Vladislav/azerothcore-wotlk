import { Component, computed, inject, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { TablePagerComponent } from '../../shared/data/table-pager.component';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { ItemPickerComponent, PickedItem } from '../../shared/ui/item-picker.component';
import { ToastService } from '../../shared/ui/toast.service';
import { ProfFiltersComponent } from './filter-bar.component';
import { ProfItemPickComponent } from './item-pick-cell.component';
import { ListSpec, ListView, SortHeadComponent } from './list-view';
import { LookCellComponent } from './look-cell.component';
import { LookPickerComponent } from './look-picker.component';
import { PartsDialogComponent } from './parts-dialog.component';
import { ItemType, ProfessionsApi, ProfessionsMeta, TypePatch } from './professions.api';
import { apiError, subclassOptions } from './professions.model';

/**
 * Типы предметов - то, что игрок выбирает в левом списке верстака.
 *
 * Схема частей принадлежит ТИПУ, а не основе: у меча всегда клинок, гарда,
 * рукоять и навершие, из какого бы металла его ни собрали. Класс с подклассом
 * тут не про игру, а про панель: по ним ищется донор внешнего вида и
 * отсеиваются материалы, которым в типе не место (DESIGN §5.4).
 */
@Component({
  imports: [
    FormsModule,
    ForgeSelectDirective,
    ItemPickerComponent,
    LookCellComponent,
    LookPickerComponent,
    PartsDialogComponent,
    ProfFiltersComponent,
    ProfItemPickComponent,
    SortHeadComponent,
    TablePagerComponent,
  ],
  providers: [ProfessionsApi],
  selector: 'app-professions-types-page',
  styleUrl: './types.page.scss',
  templateUrl: './types.page.html',
})
export class ProfessionsTypesPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);
  private readonly itemPicker = viewChild.required(ItemPickerComponent);
  private readonly lookPicker = viewChild.required(LookPickerComponent);
  private readonly partsDialog = viewChild.required(PartsDialogComponent);
  readonly auth = inject(AuthService);

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly rows = signal<ItemType[]>([]);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');
  readonly iconBase = computed(() => this.meta()?.icon_base_url ?? '');
  readonly classes = computed(() => Object.entries(this.meta()?.item_classes ?? {}));
  readonly presets = computed(() => this.meta()?.type_presets ?? []);

  readonly spec = computed<ListSpec<ItemType>>(() => ({
    search: (row) => [row.name_ru, row.sub_ru, row.code, row.sheet_art].join(' '),
    picks: [
      {
        key: 'class',
        label: 'любой класс',
        options: this.classes().map(([id, name]) => [id, name] as const),
        get: (row) => row.item_class,
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
        key: 'parts',
        label: 'части: любые',
        options: [
          ['1', 'со схемой'],
          ['0', 'без частей'],
        ],
        get: (row) => (row.parts ? '1' : '0'),
      },
    ],
    sorts: {
      Имя: (row) => row.name_ru,
      Подпись: (row) => row.sub_ru,
      Код: (row) => row.code,
      Класс: (row) => this.meta()?.item_classes?.[row.item_class] ?? String(row.item_class),
      Подкласс: (row) => row.item_subclass,
      Чертёж: (row) => row.sheet_art ?? '',
      Порядок: (row) => row.sort,
      Вкл: (row) => (row.enabled ? 1 : 0),
      Частей: (row) => row.parts,
      Рецептов: (row) => row.recipes,
    },
  }));

  readonly view = new ListView<ItemType>(this.rows.asReadonly(), this.spec);
  readonly picks = computed(() => this.spec().picks ?? []);

  readonly draft = signal({ name_ru: '', code: '', preset: '' });
  /** Какой строке предназначен ответ окна выбора предмета. */
  private pickTarget: { row: ItemType; mode: 'fail' | 'sample' } | null = null;
  private lookTarget: ItemType | null = null;

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
        this.draft.update((draft) => ({
          ...draft,
          preset: draft.preset || meta.type_presets[0]?.id || '',
        }));
        await this.reload();
      }
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось загрузить типы предметов.'));
    } finally {
      this.loading.set(false);
    }
  }

  async reload(): Promise<void> {
    this.rows.set((await firstValueFrom(this.api.types())).types);
  }

  subclasses(itemClass: number): [string, string][] {
    return subclassOptions(this.meta(), itemClass);
  }

  partsLabel(row: ItemType): string {
    return row.required_parts ? `${row.parts} / ${row.required_parts}` : String(row.parts);
  }

  partsHint(row: ItemType): string {
    return row.required_parts
      ? `Ячеек ${row.parts}, из них обязательных ${row.required_parts}.`
      : 'Ни одной обязательной ячейки: любую можно оставить пустой.';
  }

  // --- заведение нового типа ------------------------------------------------

  setDraft(patch: Partial<{ name_ru: string; code: string; preset: string }>): void {
    this.draft.update((draft) => ({ ...draft, ...patch }));
  }

  async add(): Promise<void> {
    const draft = this.draft();
    const preset =
      this.presets().find((item) => item.id === draft.preset) ?? this.presets()[0] ?? null;
    if (!preset) {
      this.error.set('Панель не знает ни одной заготовки типа.');
      return;
    }
    if (!draft.name_ru.trim()) {
      this.error.set('У типа должно быть имя - его видит игрок в списке.');
      return;
    }
    const saved = await this.put({
      id: 0,
      code: draft.code.trim() || preset.id,
      name_ru: draft.name_ru,
      sub_ru: '',
      item_class: preset.item_class,
      item_subclass: preset.item_subclass,
      displayid: preset.displayid,
      sheet_art: '',
      sort: 100,
      fail_entry: 0,
      enabled: true,
    });
    if (saved) this.setDraft({ name_ru: '', code: '' });
  }

  // --- правка строки --------------------------------------------------------

  async patch(row: ItemType, fields: Partial<TypePatch>): Promise<void> {
    await this.put({ ...this.strip(row), ...fields });
  }

  async remove(row: ItemType): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    if (!confirm(`Удалить тип «${row.name_ru}» вместе с его частями?`)) return;
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.deleteType(row.id));
      this.notice.set(`Тип «${row.name_ru}» удалён.`);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Тип удалить не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }

  // --- окна -----------------------------------------------------------------

  openParts(row: ItemType): void {
    this.partsDialog().open(row);
  }

  /** Части меняют счётчики у типа - после закрытия лист перечитываем. */
  onPartsClosed(): void {
    void this.reload();
  }

  openLook(row: ItemType): void {
    this.lookTarget = row;
    this.lookPicker().open({
      title: `Внешний вид по умолчанию: ${row.name_ru}`,
      itemClass: row.item_class,
      itemSubclass: row.item_subclass,
    });
  }

  onLookPicked(displayId: number): void {
    const row = this.lookTarget;
    this.lookTarget = null;
    if (row) void this.patch(row, { displayid: displayId });
  }

  openFailPick(row: ItemType): void {
    this.pickTarget = { row, mode: 'fail' };
    this.itemPicker().open();
  }

  openFailSample(row: ItemType): void {
    this.pickTarget = { row, mode: 'sample' };
    this.itemPicker().open();
  }

  async onItemPicked(item: PickedItem): Promise<void> {
    const target = this.pickTarget;
    this.pickTarget = null;
    if (!target) return;
    if (target.mode === 'fail') {
      await this.patch(target.row, { fail_entry: item.entry });
      return;
    }
    await this.makeFailItem(target.row, item.entry);
  }

  private async makeFailItem(row: ItemType, sample: number): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    this.busy.set(true);
    try {
      const made = await firstValueFrom(this.api.makeFailItem(row.id, sample));
      this.notice.set(`Заведена поделка ${made.entry}. Правьте её в каталоге.`);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Поделку завести не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }

  private strip(row: ItemType): TypePatch {
    const { parts, required_parts, recipes, fail_item, icon, issues, ...rest } = row;
    void parts;
    void required_parts;
    void recipes;
    void fail_item;
    void icon;
    void issues;
    return rest;
  }

  private async put(type: TypePatch): Promise<boolean> {
    if (!this.canEdit() || this.busy()) return false;
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.saveType(type));
      this.notice.set('Сохранено.');
      await this.reload();
      return true;
    } catch (error) {
      this.error.set(apiError(error, 'Тип сохранить не удалось.'));
      await this.reload();
      return false;
    } finally {
      this.busy.set(false);
    }
  }
}
