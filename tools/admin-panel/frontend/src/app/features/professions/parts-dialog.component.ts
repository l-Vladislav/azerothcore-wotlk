import { Component, ElementRef, inject, input, output, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { IconComponent } from '../../shared/ui/icon.component';
import { DictRow, ItemType, ProfessionsApi, TypePart } from './professions.api';
import { apiError, dictOptions, firstDictId } from './professions.model';

/**
 * Схема типа: из каких частей он собирается.
 *
 * Части - это и есть реагенты. Часть требует РОД («металл»), а конкретный
 * слиток выбирает игрок у верстака. Свойств у ячейки три: подпись, род и
 * обязательность; проценты вклада, флаг прока, координаты выноски, расход и
 * текстура убраны миграцией v15 - числа изделия приходят из результата
 * основы, расход задаёт основа, геометрия живёт в аддоне (DESIGN §5.4.1).
 */
@Component({
  selector: 'app-parts-dialog',
  imports: [FormsModule, ForgeSelectDirective, IconComponent],
  styleUrl: './parts-dialog.component.scss',
  template: `
    <dialog #dialog class="forge-dialog" (close)="closed.emit()">
      <header>
        <h2>Части типа: {{ itemType()?.name_ru }}</h2>
        <button type="button" class="forge-btn is-icon close" aria-label="Закрыть" (click)="close()">
          <app-icon name="close" [size]="14" />
        </button>
      </header>

      <div class="body">
        @if (error(); as text) {
          <p class="forge-alert is-error">{{ text }}</p>
        }
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Подпись</th>
              <th>Род</th>
              <th title="Без этой части предмет не собрать.">Обязательна</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            @for (part of parts(); track part.idx) {
              <tr>
                <td class="num">{{ part.idx }}</td>
                <td>
                  <input
                    class="forge-field is-small"
                    [ngModel]="part.label_ru"
                    [disabled]="!canEdit()"
                    (change)="save({ ...part, label_ru: $any($event.target).value })"
                  />
                </td>
                <td>
                  <select
                    class="forge-field is-small is-select"
                    [ngModel]="part.part_kind_id"
                    [disabled]="!canEdit()"
                    (ngModelChange)="save({ ...part, part_kind_id: +$event })"
                  >
                    @for (kind of kinds(part.part_kind_id); track kind.id) {
                      <option [ngValue]="kind.id">{{ kind.name_ru }}</option>
                    }
                  </select>
                  @if (!part.choices) {
                    <div class="warn">нет материалов этого рода</div>
                  }
                </td>
                <td>
                  <input
                    class="forge-check"
                    type="checkbox"
                    title="Без этой части предмет не собрать: пустой её не оставить, и каждая основа этого типа обязана её называть."
                    [ngModel]="!!part.required"
                    [disabled]="!canEdit()"
                    (change)="save({ ...part, required: $any($event.target).checked ? 1 : 0 })"
                  />
                </td>
                <td class="act">
                  @if (canEdit()) {
                    <button
                      type="button"
                      class="forge-btn is-danger is-compact"
                      (click)="remove(part)"
                    >
                      Убрать
                    </button>
                  }
                </td>
              </tr>
            } @empty {
              <tr>
                <td colspan="5" class="empty">Ни одной ячейки: ковать нечем.</td>
              </tr>
            }
          </tbody>
        </table>

        @if (canEdit()) {
          <div class="add">
            <input
              class="forge-field is-small"
              placeholder="Клинок"
              [ngModel]="draftLabel()"
              (ngModelChange)="draftLabel.set($event)"
              (keydown.enter)="add()"
            />
            <select
              class="forge-field is-small is-select"
              [ngModel]="draftKind()"
              (ngModelChange)="draftKind.set(+$event)"
            >
              @for (kind of kinds(draftKind()); track kind.id) {
                <option [ngValue]="kind.id">{{ kind.name_ru }}</option>
              }
            </select>
            <label class="need">
              <input
                class="forge-check"
                type="checkbox"
                [ngModel]="draftRequired()"
                (ngModelChange)="draftRequired.set($event)"
              />
              обязательна
            </label>
            <button type="button" class="forge-btn is-primary is-compact" (click)="add()">
              Добавить часть
            </button>
          </div>
        }
      </div>
    </dialog>
  `,
})
export class PartsDialogComponent {
  private readonly api = inject(ProfessionsApi);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');

  readonly partKinds = input<readonly DictRow[]>([]);
  readonly canEdit = input(false);
  /** Закрыли окно - счётчики частей у типа изменились, лист надо перечитать. */
  readonly closed = output<void>();

  readonly itemType = signal<ItemType | null>(null);
  readonly parts = signal<TypePart[]>([]);
  readonly error = signal<string | null>(null);
  readonly draftLabel = signal('');
  readonly draftKind = signal(0);
  readonly draftRequired = signal(false);

  open(itemType: ItemType): void {
    this.itemType.set(itemType);
    this.error.set(null);
    this.draftLabel.set('');
    this.draftRequired.set(false);
    this.draftKind.set(firstDictId(this.partKinds()));
    this.dialog().nativeElement.showModal();
    void this.load();
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  kinds(current: number): DictRow[] {
    return dictOptions(this.partKinds(), current);
  }

  private async load(): Promise<void> {
    const type = this.itemType();
    if (!type) return;
    try {
      this.parts.set((await firstValueFrom(this.api.parts(type.id))).parts);
      this.error.set(null);
    } catch (error) {
      this.parts.set([]);
      this.error.set(apiError(error, 'Схему типа прочитать не удалось.'));
    }
  }

  async save(part: TypePart): Promise<void> {
    const type = this.itemType();
    if (!type || !this.canEdit()) return;
    try {
      await firstValueFrom(
        this.api.savePart(type.id, {
          type_id: type.id,
          idx: part.idx,
          label_ru: part.label_ru,
          part_kind_id: part.part_kind_id,
          required: part.required,
        }),
      );
      this.error.set(null);
    } catch (error) {
      this.error.set(apiError(error, 'Ячейку сохранить не удалось.'));
    }
    // Перечитываем и на отказе: иначе галочка осталась бы стоять там, где
    // сервер её не принял, и окно врало бы о состоянии базы.
    await this.load();
  }

  async add(): Promise<void> {
    const type = this.itemType();
    if (!type || !this.canEdit()) return;
    const next = this.parts().length ? Math.max(...this.parts().map((p) => p.idx)) + 1 : 1;
    await this.save({
      type_id: type.id,
      idx: next,
      label_ru: this.draftLabel(),
      part_kind_id: this.draftKind(),
      // Новая часть выходит НЕобязательной: обязательность - решение о самом
      // предмете, и принимает его владелец галочкой, а не умолчание.
      required: this.draftRequired() ? 1 : 0,
      choices: 0,
    });
    this.draftLabel.set('');
    this.draftRequired.set(false);
  }

  async remove(part: TypePart): Promise<void> {
    const type = this.itemType();
    if (!type || !this.canEdit()) return;
    if (
      !confirm(
        `Убрать часть ${part.idx}? Уже собранные предметы держат материалы по порядку частей - ` +
          'их смысл сдвинется, а условия основ на эту часть будут удалены.',
      )
    ) {
      return;
    }
    try {
      await firstValueFrom(this.api.deletePart(type.id, part.idx));
      this.error.set(null);
    } catch (error) {
      this.error.set(apiError(error, 'Ячейку убрать не удалось.'));
    }
    await this.load();
  }
}
