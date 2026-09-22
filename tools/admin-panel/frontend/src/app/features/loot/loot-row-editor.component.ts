import { Component, computed, inject, input, linkedSignal, output, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { ItemPickerComponent, PickedItem } from '../../shared/ui/item-picker.component';
import { apiError } from './loot-format';
import { LootApi, LootItem } from './loot.api';

export interface RowDraft {
  item: number;
  itemInfo?: LootItem | null;
  reference: number;
  chance: number;
  group: number;
  min: number;
  max: number;
  mode: number;
  quest: boolean;
  comment: string;
  /** A prefilled new row: it has no previous key, same as an empty one. */
  fresh?: boolean;
}

export function blankRow(group = 0, chance = 100): RowDraft {
  return {
    item: 0,
    reference: 0,
    chance,
    group,
    min: 1,
    max: 1,
    mode: 1,
    quest: false,
    comment: '',
    fresh: true,
  };
}

@Component({
  selector: 'app-loot-row-editor',
  imports: [FormsModule, ItemPickerComponent],
  styleUrl: './loot-row-editor.component.scss',
  template: `
    <form (submit)="save($event)">
      <fieldset class="what">
        <legend>Что кладём</legend>
        <p class="hint">
          Строка несёт либо предмет, либо ссылку на общий кусок: при непустой ссылке ядро поле
          предмета не читает вовсе.
        </p>
        <div class="choice">
          <div class="side" [class.dimmed]="!!draft().reference">
            <span class="caption">Предмет</span>
            @if (draft().item) {
              <span class="picked">
                <b [class]="'q' + (draft().itemInfo?.quality ?? 0)">{{ itemLabel() }}</b>
                <small>id {{ draft().item }}</small>
              </span>
              <button type="button" class="forge-btn is-ghost is-compact" (click)="picker.open()">
                Сменить
              </button>
              <button type="button" class="forge-btn is-ghost is-compact" (click)="clearItem()">
                Убрать
              </button>
            } @else {
              <button type="button" class="forge-btn is-ghost is-compact" (click)="picker.open()">
                Выбрать предмет
              </button>
            }
          </div>
          <span class="or">или</span>
          <div class="side" [class.dimmed]="!!draft().item">
            <label>
              <span class="caption">Ссылка</span>
              <input
                class="forge-field"
                type="number"
                min="0"
                [ngModel]="draft().reference"
                (ngModelChange)="setReference($event)"
                name="reference"
                title="Номер записи в reference_loot_template. Ноль — строка про предмет."
              />
            </label>
          </div>
        </div>
      </fieldset>

      <div class="numbers">
        <label>
          <span class="caption">Шанс, %</span>
          <input
            class="forge-field"
            type="number"
            min="0"
            max="100"
            step="0.01"
            [(ngModel)]="draft().chance"
            name="chance"
            title="Ноль вне группы значит «никогда». В группе ноль законен: такие строки делят остаток поровну."
          />
        </label>
        <label>
          <span class="caption">Группа</span>
          <input
            class="forge-field"
            type="number"
            min="0"
            max="255"
            [(ngModel)]="draft().group"
            name="group"
            title="Ноль — строка катится сама по себе. Больше нуля — из группы выпадет не больше одной строки."
          />
        </label>
        <label>
          <span class="caption">Штук от</span>
          <input
            class="forge-field"
            type="number"
            min="0"
            max="255"
            [(ngModel)]="draft().min"
            name="min"
          />
        </label>
        <label>
          <span class="caption">до</span>
          <input
            class="forge-field"
            type="number"
            min="0"
            max="255"
            [(ngModel)]="draft().max"
            name="max"
          />
        </label>
        <label>
          <span class="caption">Режим</span>
          <input
            class="forge-field"
            type="number"
            min="1"
            max="65535"
            [(ngModel)]="draft().mode"
            name="mode"
            title="Битовая маска сложности: 1 обычный, 2 героический."
          />
        </label>
      </div>

      <div class="extra">
        <label class="check">
          <input class="forge-check" type="checkbox" [(ngModel)]="draft().quest" name="quest" />
          <span>только для взявших задание</span>
        </label>
        <label class="comment">
          <span class="caption">Комментарий</span>
          <input
            class="forge-field"
            type="text"
            [(ngModel)]="draft().comment"
            name="comment"
            placeholder="виден только в базе"
          />
        </label>
      </div>

      @if (error()) {
        <p class="error" role="alert">{{ error() }}</p>
      }

      <div class="actions">
        <button class="forge-btn is-compact" type="submit" [disabled]="saving()">
          {{ isNew() ? 'Добавить' : 'Сохранить' }}
        </button>
        <button type="button" class="forge-btn is-ghost is-compact" (click)="done.emit(false)">
          Отмена
        </button>
      </div>
    </form>

    <app-item-picker
      #picker
      title="Что кладём в добычу"
      [iconBase]="iconBase()"
      (picked)="setItem($event)"
    />
  `,
})
export class LootRowEditorComponent {
  private readonly api = inject(LootApi);

  readonly tableId = input.required<string>();
  readonly entry = input.required<number>();
  readonly row = input<RowDraft | null>(null);
  readonly iconBase = input('');
  readonly done = output<boolean>();
  readonly noticed = output<string>();

  readonly saving = signal(false);
  readonly error = signal<string | null>(null);
  readonly draft = linkedSignal<RowDraft>(() => ({ ...(this.row() ?? blankRow()) }));
  readonly isNew = computed(() => {
    const row = this.row();
    return !row || !!row.fresh;
  });

  itemLabel(): string {
    const info = this.draft().itemInfo;
    return info?.name_ru || info?.name || `предмет ${this.draft().item}`;
  }

  setItem(item: PickedItem): void {
    this.draft.update((draft) => ({
      ...draft,
      item: item.entry,
      itemInfo: { ...item, missing: false } as LootItem,
      reference: 0,
    }));
  }

  clearItem(): void {
    this.draft.update((draft) => ({ ...draft, item: 0, itemInfo: null }));
  }

  setReference(value: number): void {
    const reference = Number(value) || 0;
    this.draft.update((draft) => ({
      ...draft,
      reference,
      item: reference ? 0 : draft.item,
      itemInfo: reference ? null : draft.itemInfo,
    }));
  }

  async save(event: Event): Promise<void> {
    event.preventDefault();
    const draft = this.draft();
    if (!draft.item && !draft.reference) {
      this.error.set('Строка пустая: выберите предмет или укажите ссылку.');
      return;
    }
    const previous = this.row();
    const editing = !this.isNew() && previous;
    this.saving.set(true);
    try {
      const result = await firstValueFrom(
        this.api.saveRow(this.tableId(), this.entry(), {
          item: draft.item || 0,
          reference: Number(draft.reference) || 0,
          chance: Number(draft.chance) || 0,
          group: Number(draft.group) || 0,
          min: Number(draft.min) || 0,
          max: Number(draft.max) || 0,
          mode: Number(draft.mode) || 1,
          quest: !!draft.quest,
          comment: draft.comment ?? '',
          was_item: editing ? previous.item : -1,
          was_reference: editing ? previous.reference : -1,
          was_group: editing ? previous.group : -1,
        }),
      );
      this.noticed.emit(result.note || (this.isNew() ? 'Строка добавлена.' : 'Строка сохранена.'));
      this.done.emit(true);
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось сохранить строку.'));
    } finally {
      this.saving.set(false);
    }
  }
}
