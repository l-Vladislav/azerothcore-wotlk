import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { TablePagerComponent } from '../../shared/data/table-pager.component';
import { IconComponent } from '../../shared/ui/icon.component';
import { ToastService } from '../../shared/ui/toast.service';
import { ListView } from './list-view';
import { DictRow, Material, ProfessionsApi, ProfessionsMeta } from './professions.api';
import { apiError } from './professions.model';
import { ProfessionsTabsComponent } from './professions-tabs.component';
import { AddDialogComponent } from './add-dialog.component';

type DictPath = 'part-kinds' | 'insert-types';

interface DictBook {
  path: DictPath;
  title: string;
  codeSample: string;
  nameSample: string;
  /** Строки справочника по страницам. Вид живёт в странице, а не в книге:
   *  `books` пересчитывается, и заведённый тут вид терял бы номер страницы. */
  view: ListView<DictRow>;
  /** Сколько материалов держится за строку - и почему её не дают убрать. */
  used: (row: DictRow) => number;
}

/**
 * Справочники рода ячейки и типа вставки.
 *
 * Две таблицы одной формы, поэтому и страница одна. Разведены они нарочно
 * (DESIGN §2.5): «дерево» гнезду доводки не нужно никогда, «самоцвет» ячейке
 * ковки - тоже. Раньше оба списка были перечислением в трёх местах разом - в
 * базе, в C++ и в панели, - и «кость» стоила правки всех трёх.
 */
@Component({
  imports: [
    AddDialogComponent,
    ProfessionsTabsComponent,
    FormsModule,
    IconComponent,
    TablePagerComponent,
  ],
  providers: [ProfessionsApi],
  selector: 'app-professions-dicts-page',
  styleUrl: './dicts.page.scss',
  templateUrl: './dicts.page.html',
})
export class ProfessionsDictsPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);
  readonly auth = inject(AuthService);

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly partKinds = signal<DictRow[]>([]);
  readonly insertTypes = signal<DictRow[]>([]);
  readonly materials = signal<Material[]>([]);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');

  private readonly partKindView = new ListView<DictRow>(this.partKinds, signal({}));
  private readonly insertTypeView = new ListView<DictRow>(this.insertTypes, signal({}));

  readonly books = computed<DictBook[]>(() => [
    {
      path: 'part-kinds',
      title: 'Род материала',
      codeSample: 'bone',
      nameSample: 'Кость',
      view: this.partKindView,
      used: (row) =>
        this.materials().filter((mat) => mat.role === 'base' && mat.part_kind_id === row.id).length,
    },
    {
      path: 'insert-types',
      title: 'Тип вставки',
      codeSample: 'rune',
      nameSample: 'Руна',
      view: this.insertTypeView,
      used: (row) =>
        this.materials().filter((mat) => mat.role !== 'base' && mat.insert_type_id === row.id)
          .length,
    },
  ]);

  /** Заводимая строка на каждый справочник: полосы добавления две. */
  readonly draft = signal<Record<DictPath, DictRow>>({
    'part-kinds': { id: 0, code: '', name_ru: '', sort: 50, enabled: true },
    'insert-types': { id: 0, code: '', name_ru: '', sort: 50, enabled: true },
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
      this.error.set(apiError(error, 'Не удалось загрузить справочники профессий.'));
    } finally {
      this.loading.set(false);
    }
  }

  private async reload(): Promise<void> {
    const [parts, inserts, materials] = await Promise.all([
      firstValueFrom(this.api.dictRows('part-kinds')),
      firstValueFrom(this.api.dictRows('insert-types')),
      firstValueFrom(this.api.materials()),
    ]);
    this.partKinds.set(parts.rows);
    this.insertTypes.set(inserts.rows);
    this.materials.set(materials.materials);
  }

  setDraft(path: DictPath, patch: Partial<DictRow>): void {
    this.draft.update((draft) => ({ ...draft, [path]: { ...draft[path], ...patch } }));
  }

  openAdd(dialog: AddDialogComponent): void {
    this.error.set(null);
    dialog.open();
  }

  /** Окно закрывается только после удачной записи - отказ остаётся перед глазами. */
  async submitAdd(path: DictPath, dialog: AddDialogComponent): Promise<void> {
    if (await this.add(path)) dialog.close();
  }

  async add(path: DictPath): Promise<boolean> {
    const row = this.draft()[path];
    if (!row.name_ru.trim()) {
      this.error.set('У строки должно быть имя - его видно в списках.');
      return false;
    }
    const saved = await this.save(path, { ...row, id: 0 });
    if (saved) {
      this.setDraft(path, { code: '', name_ru: '' });
    }
    return saved;
  }

  async save(path: DictPath, row: DictRow): Promise<boolean> {
    if (!this.canEdit() || this.busy()) return false;
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.saveDictRow(path, row));
      this.notice.set('Сохранено.');
      await this.reload();
      return true;
    } catch (error) {
      this.error.set(apiError(error, 'Строку сохранить не удалось.'));
      // Перечитываем и на отказе: иначе поле осталось бы стоять там, где
      // сервер его не принял, и страница врала бы о состоянии базы.
      await this.reload();
      return false;
    } finally {
      this.busy.set(false);
    }
  }

  async remove(path: DictPath, row: DictRow): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    if (!confirm(`Убрать «${row.name_ru}»?`)) return;
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.deleteDictRow(path, row.id));
      this.notice.set(`Строка «${row.name_ru}» убрана.`);
      await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Строку убрать не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }
}
