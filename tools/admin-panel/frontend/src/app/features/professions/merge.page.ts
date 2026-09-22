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
import { ItemType, Merge, MergePatch, ProfessionsApi, ProfessionsMeta } from './professions.api';
import { apiError } from './professions.model';

/** Ячеек у стола объединения ровно пять (DESIGN §5.8). */
const CELLS = 5;

type PickMode =
  | { kind: 'cell'; row: Merge; index: number }
  | { kind: 'teach'; row: Merge }
  | { kind: 'result'; row: Merge }
  | { kind: 'sample'; row: Merge };

/**
 * Объединение - третий род рецепта: в середину стола кладут любую вещь
 * подходящего ТИПА, в пять ячеек что угодно, и выходит готовый предмет.
 *
 * Ячейка тут не материал верстака, а любой предмет игры, поэтому выбор идёт
 * общим каталогом, а не списком материалов.
 */
@Component({
  imports: [
    FormsModule,
    ForgeSelectDirective,
    ItemPickerComponent,
    ProfFiltersComponent,
    ProfItemPickComponent,
    SortHeadComponent,
    TablePagerComponent,
  ],
  providers: [ProfessionsApi],
  selector: 'app-professions-merge-page',
  styleUrl: './merge.page.scss',
  templateUrl: './merge.page.html',
})
export class ProfessionsMergePage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);
  private readonly itemPicker = viewChild.required(ItemPickerComponent);
  readonly auth = inject(AuthService);

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly rows = signal<Merge[]>([]);
  readonly types = signal<ItemType[]>([]);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');
  readonly iconBase = computed(() => this.meta()?.icon_base_url ?? '');

  readonly spec = computed<ListSpec<Merge>>(() => ({
    search: (row) =>
      [row.name_ru, row.type_name, ...row.item_rows.map((item) => item?.name ?? '')].join(' '),
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
        key: 'teach',
        label: 'как достаётся',
        options: [
          ['1', 'есть обучающий предмет'],
          ['0', 'только найти'],
        ],
        get: (row) => (row.teach_item ? '1' : '0'),
      },
    ],
    sorts: {
      Имя: (row) => row.name_ru,
      Тип: (row) => row.type_name,
      Набор: (row) => row.items.length,
      Вкл: (row) => (row.enabled ? 1 : 0),
    },
  }));

  readonly view = new ListView<Merge>(this.rows.asReadonly(), this.spec);
  readonly picks = computed(() => this.spec().picks ?? []);

  readonly draft = signal({ name_ru: '', type_id: 0 });
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
      if (meta.available) await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось загрузить объединение.'));
    } finally {
      this.loading.set(false);
    }
  }

  private async reload(): Promise<void> {
    const [merges, types] = await Promise.all([
      firstValueFrom(this.api.merges()),
      firstValueFrom(this.api.types()),
    ]);
    this.rows.set(merges.merges);
    this.types.set(types.types);
    if (!this.draft().type_id && types.types.length) {
      this.setDraft({ type_id: types.types[0].id });
    }
  }

  /** Пять ячеек всегда: пустые тоже видно, иначе некуда класть. */
  cells(row: Merge): { entry: number; name: string }[] {
    return Array.from({ length: CELLS }, (_, index) => {
      const entry = row.items[index] ?? 0;
      return { entry, name: row.item_rows[index]?.name ?? String(entry) };
    });
  }

  setDraft(patch: Partial<{ name_ru: string; type_id: number }>): void {
    this.draft.update((draft) => ({ ...draft, ...patch }));
  }

  async add(): Promise<void> {
    const draft = this.draft();
    if (!draft.name_ru.trim()) {
      this.error.set('Дайте рецепту имя.');
      return;
    }
    const saved = await this.put({
      id: 0,
      name_ru: draft.name_ru,
      type_id: draft.type_id,
      items: [],
      result_entry: 0,
      teach_item: 0,
      enabled: false,
    });
    if (saved) this.setDraft({ name_ru: '' });
  }

  // --- набор ----------------------------------------------------------------

  pickCell(row: Merge, index: number): void {
    this.pickMode = { kind: 'cell', row, index };
    this.itemPicker().open();
  }

  async dropCell(row: Merge, index: number): Promise<void> {
    const next = [...row.items];
    next.splice(index, 1);
    await this.patch(row, { items: next });
  }

  pickTeach(row: Merge): void {
    this.pickMode = { kind: 'teach', row };
    this.itemPicker().open();
  }

  pickResult(row: Merge): void {
    this.pickMode = { kind: 'result', row };
    this.itemPicker().open();
  }

  pickResultSample(row: Merge): void {
    this.pickMode = { kind: 'sample', row };
    this.itemPicker().open();
  }

  async onItemPicked(item: PickedItem): Promise<void> {
    const mode = this.pickMode;
    this.pickMode = null;
    if (!mode) return;
    switch (mode.kind) {
      case 'cell': {
        const next = [...mode.row.items];
        next[mode.index] = item.entry;
        await this.patch(mode.row, { items: next.filter(Boolean) });
        return;
      }
      case 'teach':
        await this.patch(mode.row, { teach_item: item.entry });
        return;
      case 'result':
        await this.patch(mode.row, { result_entry: item.entry });
        return;
      case 'sample':
        await this.makeResultItem(mode.row, item.entry);
    }
  }

  // --- правка ---------------------------------------------------------------

  async patch(row: Merge, fields: Partial<MergePatch>): Promise<void> {
    await this.put({
      id: row.id,
      name_ru: row.name_ru,
      type_id: row.type_id,
      items: row.items,
      result_entry: row.result_entry,
      teach_item: row.teach_item,
      enabled: row.enabled,
      ...fields,
    });
  }

  async remove(row: Merge): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    if (
      !confirm(
        `Удалить рецепт «${row.name_ru}»? Предмет-результат останется в каталоге предметов.`,
      )
    ) {
      return;
    }
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.deleteMerge(row.id));
      this.notice.set(`Рецепт «${row.name_ru}» удалён.`);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Рецепт удалить не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }

  private async makeResultItem(row: Merge, sample: number): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    this.busy.set(true);
    try {
      const made = await firstValueFrom(this.api.makeMergeItem(row.id, sample));
      this.notice.set(`Заведён предмет ${made.entry}. Правьте его в каталоге.`);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Предмет-результат завести не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }

  private async put(merge: MergePatch): Promise<boolean> {
    if (!this.canEdit() || this.busy()) return false;
    this.busy.set(true);
    try {
      const saved = await firstValueFrom(this.api.saveMerge(merge));
      this.notice.set(saved.note || 'Сохранено.');
      await this.reload();
      return true;
    } catch (error) {
      this.error.set(apiError(error, 'Рецепт сохранить не удалось.'));
      await this.reload();
      return false;
    } finally {
      this.busy.set(false);
    }
  }
}
