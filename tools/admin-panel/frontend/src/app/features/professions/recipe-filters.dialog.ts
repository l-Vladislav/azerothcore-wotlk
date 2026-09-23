import { Component, ElementRef, inject, input, output, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { IconComponent } from '../../shared/ui/icon.component';
import { ProfItemComponent } from './item-cell.component';
import { DictRow, Material, ProfessionsApi, ProfessionsMeta, Recipe } from './professions.api';
import { apiError, dictName, qualityName, statName } from './professions.model';

/**
 * Чем основе дают себя украшать.
 *
 * Два слоя разного назначения: набор ТИПОВ вставки - массовый («костяные
 * основы принимают кость», один раз на семейство), поимённый СПИСОК - точный
 * («в этот клинок идут вот эти три камня»).
 *
 * Список СТАРШЕ набора типов, и держать оба сервер не даст: как только в
 * списке появляется камень, типы снимаются сами - иначе владелец упирался бы
 * в отказ на ровном месте.
 */
@Component({
  selector: 'app-recipe-filters-dialog',
  imports: [FormsModule, IconComponent, ProfItemComponent],
  styleUrl: './recipe-dialog.scss',
  template: `
    <dialog #dialog class="forge-dialog" (close)="shown.set(false); closed.emit()">
      <header>
        <h2>Гнёзда: {{ recipe()?.name_ru }}</h2>
        <button
          type="button"
          class="forge-btn is-icon close"
          aria-label="Закрыть"
          (click)="close()"
        >
          <app-icon name="close" [size]="14" />
        </button>
      </header>

      <!-- Тело рисуется только в открытом окне: поимённый список - это все
           вставки модуля (~500 строк, 11 тысяч узлов), и закрытое окно
           держало их в каждой открытой странице основ. -->
      @if (shown()) {
        <div class="body">
          @if (error(); as text) {
            <p class="forge-alert is-error">{{ text }}</p>
          }

          <table>
            <thead>
              <tr>
                <th>Ступень</th>
                <th>Гнёзд</th>
                <th>Подходит камней</th>
                <th>Эскизов</th>
              </tr>
            </thead>
            <tbody>
              @for (step of recipe()?.inlay ?? []; track step.quality) {
                <tr [class.off]="step.slots && !step.gems">
                  <td>{{ tierName(step.quality) }}</td>
                  <td class="num">{{ step.slots }}</td>
                  <td class="num">{{ step.gems }}</td>
                  <td class="num">{{ step.patterns }}</td>
                </tr>
              } @empty {
                <tr>
                  <td colspan="4" class="empty">
                    У основы нет изделий - гнёзда считать не от чего.
                  </td>
                </tr>
              }
            </tbody>
          </table>

          <h3>Типы вставки</h3>
          <div class="checks">
            @for (type of insertTypes(); track type.id) {
              <label [class.is-off]="named().length">
                <input
                  class="forge-check"
                  type="checkbox"
                  [checked]="types().includes(type.id)"
                  [disabled]="!canEdit() || !!named().length"
                  (change)="toggleType(type.id, $any($event.target).checked)"
                />
                {{ type.name_ru }}
              </label>
            }
          </div>

          <h3>Поимённый список</h3>
          <table>
            <tbody>
              @for (mat of inserts(); track mat.entry) {
                <tr [class.off]="!mat.enabled">
                  <td class="pick">
                    <input
                      class="forge-check"
                      type="checkbox"
                      [checked]="named().includes(mat.entry)"
                      [disabled]="!canEdit()"
                      (change)="toggleNamed(mat.entry, $any($event.target).checked)"
                    />
                  </td>
                  <td>
                    <app-prof-item [item]="mat.item" [entry]="mat.entry" [iconBase]="iconBase()" />
                  </td>
                  <td class="muted">{{ typeName(mat.insert_type_id) }}</td>
                  <td class="muted">{{ tierName(mat.quality || 0) }}</td>
                  <td class="muted">{{ statLabel(mat.stat_type) }} +{{ mat.stat_value }}</td>
                </tr>
              } @empty {
                <tr>
                  <td colspan="5" class="empty">Вставок не заведено.</td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      }
    </dialog>
  `,
})
export class RecipeFiltersDialogComponent {
  private readonly api = inject(ProfessionsApi);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');

  readonly meta = input<ProfessionsMeta | null>(null);
  readonly materials = input<readonly Material[]>([]);
  readonly canEdit = input(false);
  readonly closed = output<void>();

  readonly recipe = signal<Recipe | null>(null);
  readonly types = signal<number[]>([]);
  readonly named = signal<number[]>([]);
  readonly error = signal<string | null>(null);
  readonly shown = signal(false);

  open(recipe: Recipe): void {
    this.shown.set(true);
    this.recipe.set(recipe);
    this.types.set([...recipe.insert_types]);
    this.named.set([...recipe.materials]);
    this.error.set(null);
    this.dialog().nativeElement.showModal();
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  iconBase(): string {
    return this.meta()?.icon_base_url ?? '';
  }

  insertTypes(): readonly DictRow[] {
    return this.meta()?.insert_types ?? [];
  }

  /** В гнездо идут все роли, кроме материала ячейки. */
  inserts(): Material[] {
    return this.materials().filter((mat) => mat.role !== 'base');
  }

  tierName(quality: number): string {
    return qualityName(this.meta(), quality);
  }

  typeName(id: number): string {
    return dictName(this.insertTypes(), id);
  }

  statLabel(id: number): string {
    return statName(this.meta(), id);
  }

  toggleType(id: number, on: boolean): void {
    this.types.update((list) => (on ? [...list, id] : list.filter((item) => item !== id)));
    void this.save();
  }

  toggleNamed(entry: number, on: boolean): void {
    this.named.update((list) => (on ? [...list, entry] : list.filter((item) => item !== entry)));
    // Список старше типов: снимаем их сами, чтобы не упираться в отказ.
    if (this.named().length) this.types.set([]);
    void this.save();
  }

  private async save(): Promise<void> {
    const recipe = this.recipe();
    if (!recipe || !this.canEdit()) return;
    try {
      await firstValueFrom(
        this.api.saveRecipeFilters(recipe.id, {
          insert_types: this.types(),
          materials: this.named(),
        }),
      );
      this.error.set(null);
      // Числа гнёзд считает сервер - перечитываем саму основу, а не свой снимок.
      const fresh = (await firstValueFrom(this.api.recipes())).recipes.find(
        (row) => row.id === recipe.id,
      );
      if (fresh) {
        this.recipe.set(fresh);
        this.types.set([...fresh.insert_types]);
        this.named.set([...fresh.materials]);
      }
    } catch (error) {
      this.error.set(apiError(error, 'Гнёзда сохранить не удалось.'));
      this.types.set([...recipe.insert_types]);
      this.named.set([...recipe.materials]);
    }
  }
}
