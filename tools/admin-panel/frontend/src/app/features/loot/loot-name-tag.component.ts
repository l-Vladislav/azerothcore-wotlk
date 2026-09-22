import { Component, inject, input, output, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { apiError } from './loot-format';
import { LootApi, LootLabel } from './loot.api';

/**
 * "Запись 16507" and "Группа 1" tell a person nothing, so a record can carry
 * a name of its own. Own name first, then the one computed from the data,
 * then the number.
 */
@Component({
  selector: 'app-loot-name-tag',
  imports: [FormsModule],
  styleUrl: './loot-name-tag.component.scss',
  template: `
    @if (editing()) {
      <form class="editor" (submit)="save($event)">
        <input
          class="forge-field"
          #field
          type="text"
          [(ngModel)]="draftName"
          name="name"
          [placeholder]="label()?.auto || fallback()"
          aria-label="Имя записи"
        />
        <input
          class="forge-field"
          type="text"
          [(ngModel)]="draftNote"
          name="note"
          placeholder="пояснение, необязательно"
          aria-label="Пояснение"
        />
        <button class="forge-btn is-compact" type="submit" [disabled]="saving()">Сохранить</button>
        <button type="button" class="forge-btn is-ghost is-compact" (click)="cancel()">
          Отмена
        </button>
      </form>
    } @else {
      <span class="tag">
        <b [class.auto]="!label()?.name">{{ text() }}</b>
        @if (label()?.note; as note) {
          <span class="note" [title]="note" aria-label="Пояснение">?</span>
        }
        @if (canEdit()) {
          <button type="button" class="link" (click)="edit()">
            {{ label()?.name ? 'переименовать' : 'назвать' }}
          </button>
        }
      </span>
    }
    @if (error()) {
      <span class="error">{{ error() }}</span>
    }
  `,
})
export class LootNameTagComponent {
  private readonly api = inject(LootApi);

  readonly tableId = input.required<string>();
  readonly entry = input.required<number>();
  readonly kind = input<'entry' | 'group'>('entry');
  readonly groupId = input(0);
  readonly label = input<LootLabel | undefined>(undefined);
  readonly fallback = input.required<string>();
  readonly canEdit = input(false);
  readonly saved = output<LootLabel>();

  readonly editing = signal(false);
  readonly saving = signal(false);
  readonly error = signal<string | null>(null);
  draftName = '';
  draftNote = '';

  text(): string {
    return this.label()?.name || this.label()?.auto || this.fallback();
  }

  edit(): void {
    this.draftName = this.label()?.name ?? '';
    this.draftNote = this.label()?.note ?? '';
    this.error.set(null);
    this.editing.set(true);
  }

  cancel(): void {
    this.editing.set(false);
  }

  async save(event: Event): Promise<void> {
    event.preventDefault();
    this.saving.set(true);
    try {
      const label = await firstValueFrom(
        this.api.saveLabel(this.tableId(), this.entry(), {
          kind: this.kind(),
          group_id: this.groupId(),
          name: this.draftName,
          note: this.draftNote,
        }),
      );
      this.saved.emit(label);
      this.editing.set(false);
      this.error.set(null);
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось сохранить подпись.'));
    } finally {
      this.saving.set(false);
    }
  }
}
