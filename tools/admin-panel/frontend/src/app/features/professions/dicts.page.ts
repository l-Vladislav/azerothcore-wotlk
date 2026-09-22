import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { ToastService } from '../../shared/ui/toast.service';
import { DictRow, Material, ProfessionsApi, ProfessionsMeta } from './professions.api';
import { apiError } from './professions.model';

type DictPath = 'part-kinds' | 'insert-types';

interface DictBook {
  path: DictPath;
  title: string;
  hint: string;
  codeSample: string;
  nameSample: string;
  rows: DictRow[];
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
  imports: [FormsModule],
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

  readonly books = computed<DictBook[]>(() => [
    {
      path: 'part-kinds',
      title: 'Род материала',
      hint: 'Что кладут в ЯЧЕЙКУ схемы: металл, дерево, кожа. Ячейка требует род, а конкретный слиток выбирает игрок у верстака.',
      codeSample: 'bone',
      nameSample: 'Кость',
      rows: this.partKinds(),
      used: (row) =>
        this.materials().filter((mat) => mat.role === 'base' && mat.part_kind_id === row.id).length,
    },
    {
      path: 'insert-types',
      title: 'Тип вставки',
      hint: 'Чем украшают ГОТОВУЮ вещь: самоцвет, руна, пыльца. Рецепт называет типы, которые основа пускает в свои гнёзда.',
      codeSample: 'rune',
      nameSample: 'Руна',
      rows: this.insertTypes(),
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

  async add(path: DictPath): Promise<void> {
    const row = this.draft()[path];
    if (!row.name_ru.trim()) {
      this.error.set('У строки должно быть имя - его видно в списках.');
      return;
    }
    const saved = await this.save(path, { ...row, id: 0 });
    if (saved) {
      this.setDraft(path, { code: '', name_ru: '' });
    }
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
