import { Component, computed, forwardRef, inject, input, output, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Observable, firstValueFrom } from 'rxjs';
import { apiError, chanceText, chanceWidth, itemName, labelText } from './loot-format';
import { IconComponent } from '../../shared/ui/icon.component';
import { LootNameTagComponent } from './loot-name-tag.component';
import { LootRowEditorComponent, RowDraft, blankRow } from './loot-row-editor.component';
import {
  LootApi,
  LootGroupLabel,
  LootLabel,
  LootRow,
  LootTree,
  RowKey,
  SaveResult,
} from './loot.api';

interface RowGroup {
  id: number;
  label: LootGroupLabel | undefined;
  rows: LootRow[];
}

function keyOf(row: LootRow): string {
  return `${row.item?.entry ?? 0}:${row.reference}:${row.group}`;
}

/**
 * One loot record, references unfolded. A reference is a node with a table
 * inside it rather than a line in the common list: its chance and the chance
 * of the item inside it are two independent rolls, and standing side by side
 * they would read as one.
 */
@Component({
  selector: 'app-loot-tree',
  imports: [
    FormsModule,
    RouterLink,
    IconComponent,
    LootNameTagComponent,
    LootRowEditorComponent,
    forwardRef(() => LootTreeComponent),
  ],
  styleUrl: './loot-tree.component.scss',
  template: `
    @if (!tree().rows.length) {
      <p class="empty">
        {{
          tree().truncated
            ? 'Глубже не разворачиваем: ссылки закольцованы.'
            : 'В этой записи нет ни одной строки.'
        }}
      </p>
    } @else {
      @for (group of groups(); track group.id) {
        @if (group.id) {
          <div class="group-head">
            <app-loot-name-tag
              [tableId]="tree().table"
              [entry]="tree().entry"
              kind="group"
              [groupId]="group.id"
              [label]="groupLabel(group)"
              [fallback]="'Группа ' + group.id"
              [canEdit]="canLabel()"
              (saved)="onGroupLabel(group.id, $event)"
            />
            <span class="group-note"
              >выпадет не больше одной строки из {{ group.rows.length }}</span
            >
            @if (canEditRows()) {
              <span class="group-tools">
                <button type="button" class="link" (click)="toggleMove(group.id)">перенести</button>
                <button type="button" class="link" (click)="startAdd(group.id)">
                  + строка сюда
                </button>
              </span>
            }
          </div>
          @if (movingGroup() === group.id) {
            <form class="inline-form" (submit)="moveGroup($event, group.id)">
              <label>
                <span>перенести строки группы {{ group.id }} в группу</span>
                <input
                  class="forge-field"
                  type="number"
                  min="0"
                  max="255"
                  [(ngModel)]="moveTarget"
                  name="target"
                />
              </label>
              <span class="hint">0 — выпустить строки из группы</span>
              <button class="forge-btn is-compact" type="submit" [disabled]="busy()">
                Перенести
              </button>
              <button
                type="button"
                class="forge-btn is-ghost is-compact"
                (click)="movingGroup.set(null)"
              >
                Отмена
              </button>
            </form>
          }
        } @else if (groups().length > 1) {
          <div class="group-head plain">Вне групп — катится само по себе</div>
        }

        @for (row of group.rows; track keyFor(row)) {
          <div class="lootrow" [class.picked]="isPicked(row)">
            @if (canEditRows()) {
              <input
                type="checkbox"
                class="forge-check pick"
                [checked]="isPicked(row)"
                (change)="togglePick(row)"
                [attr.aria-label]="'Отметить строку для сборки в группу'"
                title="Отметить для сборки в группу."
              />
            }

            <span class="chance" [title]="'Шанс по цепочке: ' + chanceText(row.chance)">
              <span class="bar"><i [style.width.%]="chanceWidth(row.chance)"></i></span>
              <span class="value">{{ chanceText(row.chance) }}</span>
            </span>

            <span class="name">
              @if (row.reference) {
                @if (row.child?.rows?.length) {
                  <button
                    type="button"
                    class="fold"
                    (click)="toggleFold(row)"
                    [attr.aria-expanded]="isOpen(row)"
                  >
                    <app-icon
                      class="caret"
                      tone="plain"
                      [name]="isOpen(row) ? 'caret' : 'caret-right'"
                      [size]="12"
                    />
                    <b>ссылка · {{ referenceName(row) }}</b>
                  </button>
                } @else {
                  <b class="dead">ссылка · {{ referenceName(row) }}</b>
                }
                @if (row.item && !row.item.missing) {
                  <small class="muted">поле предмета ({{ row.item.entry }}) ядро не читает</small>
                }
              } @else if (row.item) {
                <a
                  [routerLink]="['/loot/items']"
                  [queryParams]="{ item: row.item.entry }"
                  [class]="'q' + row.item.quality"
                  [class.broken]="row.item.missing"
                  [title]="
                    'id ' +
                    row.item.entry +
                    (row.item.missing ? ' — строки нет в item_template!' : '')
                  "
                  >{{ itemName(row.item) }}</a
                >
              } @else {
                <span class="muted">пустая строка</span>
              }
            </span>

            @if (row.min !== 1 || row.max !== 1) {
              <span class="count">{{
                row.min === row.max ? '×' + row.min : '×' + row.min + '-' + row.max
              }}</span>
            }

            <span class="marks">
              @if (row.quest) {
                <span class="mark quest" title="Видно только тому, кто взял задание.">квест</span>
              }
              @if (row.mode && row.mode !== 1) {
                <span
                  class="mark mode"
                  title="Режим сложности: в обычном подземелье такая строка не выпадет."
                  >{{ row.mode_name }}</span
                >
              }
              @if (row.conditions.length) {
                <span class="mark cond" [title]="conditionsText(row)"
                  >условие {{ row.conditions.length }}</span
                >
              }
              @if (row.broken) {
                <span
                  class="mark bad"
                  title="Строка ссылается на запись, которой нет: выпасть из неё нечему."
                  >ссылка в никуда</span
                >
              }
            </span>

            @if (canEditRows()) {
              <span class="tools">
                <button type="button" class="link" (click)="startEdit(row)">править</button>
                <button type="button" class="link danger" (click)="askDelete(row)">удалить</button>
              </span>
            }
          </div>

          @if (deleting() === keyFor(row)) {
            <p class="confirm">
              <span>Убрать {{ rowTitle(row) }} из записи {{ tree().entry }}?</span>
              <button
                type="button"
                class="forge-btn is-danger is-compact"
                [disabled]="busy()"
                (click)="remove(row)"
              >
                Убрать
              </button>
              <button
                type="button"
                class="forge-btn is-ghost is-compact"
                (click)="deleting.set(null)"
              >
                Отмена
              </button>
            </p>
          }

          @if (editing() === keyFor(row)) {
            <app-loot-row-editor
              [tableId]="tree().table"
              [entry]="tree().entry"
              [row]="draftOf(row)"
              [iconBase]="iconBase()"
              (noticed)="noticed.emit($event)"
              (done)="afterEdit($event)"
            />
          }

          @if (row.child && isOpen(row)) {
            <div class="node">
              <app-loot-tree
                [tree]="row.child"
                [iconBase]="iconBase()"
                [canEditRows]="canEditRows()"
                [canLabel]="canLabel()"
                [depth]="depth() + 1"
                (changed)="changed.emit()"
                (noticed)="noticed.emit($event)"
              />
            </div>
          }
        }
      }

      @if (adding()) {
        <app-loot-row-editor
          [tableId]="tree().table"
          [entry]="tree().entry"
          [row]="addDraft()"
          [iconBase]="iconBase()"
          (noticed)="noticed.emit($event)"
          (done)="afterEdit($event)"
        />
      }

      @if (canEditRows()) {
        @if (picked().size) {
          <div class="pickbar">
            <b>Отмечено строк: {{ picked().size }}</b>
            <form class="inline-form" (submit)="collect($event, 0)">
              <input
                class="forge-field"
                type="text"
                [(ngModel)]="newGroupName"
                name="name"
                placeholder="имя новой группы, необязательно"
              />
              <button class="forge-btn is-compact" type="submit" [disabled]="busy()">
                В новую группу
              </button>
            </form>
            <form class="inline-form" (submit)="collect($event, targetGroup)">
              <label>
                <span>в группу</span>
                <input
                  class="forge-field"
                  type="number"
                  min="1"
                  max="255"
                  [(ngModel)]="targetGroup"
                  name="target"
                />
              </label>
              <button class="forge-btn is-compact" type="submit" [disabled]="busy()">
                Собрать
              </button>
            </form>
            <button type="button" class="link" (click)="clearPicks()">снять отметки</button>
          </div>
        }
        @if (!adding()) {
          <button
            type="button"
            class="forge-btn is-ghost is-compact ghost add"
            (click)="startAdd(0)"
          >
            + строка в запись {{ tree().entry }}
          </button>
        }
      }

      @if (error()) {
        <p class="error" role="alert">{{ error() }}</p>
      }
    }
  `,
})
export class LootTreeComponent {
  private readonly api = inject(LootApi);

  readonly tree = input.required<LootTree>();
  readonly iconBase = input('');
  readonly canEditRows = input(false);
  readonly canLabel = input(false);
  readonly depth = input(0);
  readonly changed = output<void>();
  readonly noticed = output<string>();

  readonly chanceText = chanceText;
  readonly chanceWidth = chanceWidth;
  readonly itemName = itemName;

  readonly editing = signal<string | null>(null);
  readonly deleting = signal<string | null>(null);
  readonly adding = signal(false);
  readonly addDraft = signal<RowDraft>(blankRow());
  readonly movingGroup = signal<number | null>(null);
  readonly picked = signal<Set<string>>(new Set());
  readonly folded = signal<Set<string>>(new Set());
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly ownLabels = signal<Map<number, LootLabel>>(new Map());

  moveTarget = 0;
  targetGroup = 1;
  newGroupName = '';

  /** Rows sorted into their groups: only one row of a group ever drops. */
  readonly groups = computed<RowGroup[]>(() => {
    const byGroup = new Map<number, LootRow[]>();
    for (const row of this.tree().rows) {
      const rows = byGroup.get(row.group);
      if (rows) rows.push(row);
      else byGroup.set(row.group, [row]);
    }
    const labels = new Map((this.tree().groups ?? []).map((group) => [group.id, group]));
    return [...byGroup.keys()]
      .sort((a, b) => a - b)
      .map((id) => ({ id, label: labels.get(id), rows: byGroup.get(id) ?? [] }));
  });

  keyFor(row: LootRow): string {
    return keyOf(row);
  }

  groupLabel(group: RowGroup): LootLabel {
    const own = this.ownLabels().get(group.id);
    return own ?? { name: group.label?.name ?? '', note: group.label?.note ?? '' };
  }

  onGroupLabel(groupId: number, label: LootLabel): void {
    this.ownLabels.update((labels) => new Map(labels).set(groupId, label));
  }

  referenceName(row: LootRow): string {
    return labelText(row.child?.label, `${row.reference}`);
  }

  rowTitle(row: LootRow): string {
    return row.item ? itemName(row.item) : `ссылку ${row.reference}`;
  }

  conditionsText(row: LootRow): string {
    return row.conditions
      .map(
        (condition) =>
          condition.Comment ||
          `тип ${condition.ConditionTypeOrReference} · ${condition.ConditionValue1}`,
      )
      .join('\n');
  }

  /** Deep references stay folded: everything at once is a wall of rows. */
  isOpen(row: LootRow): boolean {
    const key = keyOf(row);
    const flipped = this.folded().has(key);
    return this.depth() === 0 ? !flipped : flipped;
  }

  toggleFold(row: LootRow): void {
    const key = keyOf(row);
    this.folded.update((keys) => {
      const next = new Set(keys);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  isPicked(row: LootRow): boolean {
    return this.picked().has(keyOf(row));
  }

  togglePick(row: LootRow): void {
    const key = keyOf(row);
    this.picked.update((keys) => {
      const next = new Set(keys);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  draftOf(row: LootRow): RowDraft {
    return {
      item: row.item?.entry ?? 0,
      itemInfo: row.item,
      reference: row.reference,
      chance: row.raw_chance,
      group: row.group,
      min: row.min,
      max: row.max,
      mode: row.mode,
      quest: row.quest,
      comment: row.comment,
    };
  }

  startEdit(row: LootRow): void {
    const key = keyOf(row);
    this.adding.set(false);
    this.deleting.set(null);
    this.editing.set(this.editing() === key ? null : key);
  }

  askDelete(row: LootRow): void {
    const key = keyOf(row);
    this.editing.set(null);
    this.deleting.set(this.deleting() === key ? null : key);
  }

  startAdd(group: number): void {
    this.editing.set(null);
    // Inside a group the default chance is zero: that means "share what is
    // left", while a hundred would mean "this row always wins the group".
    this.addDraft.set(blankRow(group, group ? 0 : 100));
    this.adding.set(true);
  }

  afterEdit(saved: boolean): void {
    this.editing.set(null);
    this.adding.set(false);
    if (saved) this.changed.emit();
  }

  toggleMove(group: number): void {
    this.moveTarget = group;
    this.movingGroup.set(this.movingGroup() === group ? null : group);
  }

  async moveGroup(event: Event, source: number): Promise<void> {
    event.preventDefault();
    const target = Number(this.moveTarget) || 0;
    await this.run(
      () => this.api.moveGroup(this.tree().table, this.tree().entry, source, target),
      'Строки перенесены.',
      'Не удалось перенести группу.',
      () => this.movingGroup.set(null),
    );
  }

  async collect(event: Event, target: number): Promise<void> {
    event.preventDefault();
    const rows: RowKey[] = [...this.picked()].map((key) => {
      const [item, reference, group] = key.split(':').map(Number);
      return { item, reference, group };
    });
    const name = target ? '' : this.newGroupName;
    await this.run(
      () => this.api.collectRows(this.tree().table, this.tree().entry, rows, target, name),
      'Строки собраны в группу.',
      'Не удалось собрать группу.',
      () => {
        this.picked.set(new Set());
        this.newGroupName = '';
      },
    );
  }

  async remove(row: LootRow): Promise<void> {
    await this.run(
      () =>
        this.api.deleteRow(this.tree().table, this.tree().entry, {
          item: row.item?.entry ?? 0,
          reference: row.reference,
          group: row.group,
        }),
      'Строка убрана.',
      'Не удалось убрать строку.',
      () => this.deleting.set(null),
    );
  }

  clearPicks(): void {
    this.picked.set(new Set());
  }

  private async run(
    call: () => Observable<SaveResult>,
    success: string,
    failure: string,
    cleanup: () => void,
  ): Promise<void> {
    this.busy.set(true);
    try {
      const result = await firstValueFrom(call());
      this.noticed.emit(result.note || success);
      this.error.set(null);
      cleanup();
      this.changed.emit();
    } catch (error) {
      this.error.set(apiError(error, failure));
    } finally {
      this.busy.set(false);
    }
  }
}
