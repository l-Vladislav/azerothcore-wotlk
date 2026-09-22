import { Component, ElementRef, inject, input, output, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { IconComponent } from '../../shared/ui/icon.component';
import { DictRow, ProfessionsApi, Recipe, RecipeCellRow } from './professions.api';
import { apiError, dictName } from './professions.model';

/**
 * Набор рецепта: что и в какой ячейке должно лежать.
 *
 * Сравнение ТОЧНОЕ - предмет и количество, - поэтому «не задано» значит не
 * «всё равно», а требование ПУСТОЙ ячейки: что не лежит, тоже часть набора
 * (DESIGN §5.4). У обязательной ячейки этого выбора нет вовсе: её нечем
 * оставить пустой, и рецепт, который её не называет, включить не дадут.
 */
@Component({
  selector: 'app-recipe-cells-dialog',
  imports: [FormsModule, ForgeSelectDirective, IconComponent],
  styleUrl: './recipe-dialog.scss',
  template: `
    <dialog #dialog (close)="closed.emit()">
      <header>
        <h2>Набор: {{ recipe()?.name_ru }}</h2>
        <button type="button" class="forge-btn is-icon close" aria-label="Закрыть" (click)="close()">
          <app-icon name="close" [size]="14" />
        </button>
      </header>

      <div class="body">
        @if (error(); as text) {
          <p class="forge-alert is-danger">{{ text }}</p>
        }
        @if (!rows().length) {
          <p class="empty">
            У типа нет ни одной ячейки - задайте их на странице «Типы предметов».
          </p>
        } @else {
          <table>
            <thead>
              <tr>
                <th>Ячейка</th>
                <th>Род</th>
                <th>Что должно лежать</th>
                <th>Расход</th>
              </tr>
            </thead>
            <tbody>
              @for (row of rows(); track row.part_idx) {
                <tr>
                  <td
                    [title]="
                      row.required
                        ? 'Обязательная ячейка: без этой части предмета не существует. Оставить её пустой рецепт не может.'
                        : ''
                    "
                  >
                    {{ row.part_idx }}. {{ row.label_ru }}{{ row.required ? ' *' : '' }}
                  </td>
                  <td class="muted">{{ kindName(row.part_kind_id) }}</td>
                  <td>
                    <select
                      class="forge-field is-select"
                      [class.is-warning]="row.required && !row.item_entry"
                      [ngModel]="row.item_entry"
                      [disabled]="!canEdit()"
                      [title]="
                        row.required
                          ? 'Ячейка обязательная: пока материал не выбран, рецепт нельзя включить - сковать его не выйдет.'
                          : 'Пусто - рецепт требует, чтобы игрок оставил эту ячейку пустой. Материал - чтобы в ней лежал именно он и именно в указанном количестве.'
                      "
                      (ngModelChange)="save(row, { item_entry: +$event })"
                    >
                      <option [ngValue]="0">
                        {{ row.required ? '— не задано —' : '— пусто —' }}
                      </option>
                      @for (option of row.options; track option.entry) {
                        <option [ngValue]="option.entry">{{ option.name }}</option>
                      }
                    </select>
                  </td>
                  <td class="num">
                    <input
                      class="forge-field"
                      type="number"
                      min="1"
                      title="Сколько единиц уходит из сумки за эту ячейку."
                      [ngModel]="row.count"
                      [disabled]="!canEdit()"
                      (change)="save(row, { count: +$any($event.target).value || 1 })"
                    />
                  </td>
                </tr>
              }
            </tbody>
          </table>
        }
      </div>
    </dialog>
  `,
})
export class RecipeCellsDialogComponent {
  private readonly api = inject(ProfessionsApi);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');

  readonly partKinds = input<readonly DictRow[]>([]);
  readonly canEdit = input(false);
  readonly closed = output<void>();

  readonly recipe = signal<Recipe | null>(null);
  readonly rows = signal<RecipeCellRow[]>([]);
  readonly error = signal<string | null>(null);

  open(recipe: Recipe): void {
    this.recipe.set(recipe);
    this.error.set(null);
    this.rows.set([]);
    this.dialog().nativeElement.showModal();
    void this.load();
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  kindName(id: number): string {
    return dictName(this.partKinds(), id);
  }

  private async load(): Promise<void> {
    const recipe = this.recipe();
    if (!recipe) return;
    try {
      this.rows.set((await firstValueFrom(this.api.recipeCells(recipe.id))).rows);
      this.error.set(null);
    } catch (error) {
      this.rows.set([]);
      this.error.set(apiError(error, 'Набор рецепта прочитать не удалось.'));
    }
  }

  async save(row: RecipeCellRow, fields: { item_entry?: number; count?: number }): Promise<void> {
    const recipe = this.recipe();
    if (!recipe || !this.canEdit()) return;
    try {
      await firstValueFrom(
        this.api.saveRecipeCell(recipe.id, {
          part_idx: row.part_idx,
          item_entry: row.item_entry,
          count: row.count,
          ...fields,
        }),
      );
      this.error.set(null);
    } catch (error) {
      this.error.set(apiError(error, 'Ячейку сохранить не удалось.'));
    }
    await this.load();
  }
}
