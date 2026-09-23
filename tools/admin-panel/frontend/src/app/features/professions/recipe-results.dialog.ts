import { Component, ElementRef, computed, inject, input, output, signal, viewChild } from '@angular/core';
import { RouterLink } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { IconComponent } from '../../shared/ui/icon.component';
import { ProfItemPickComponent } from './item-pick-cell.component';
import { ProfessionsApi, ProfessionsMeta, Recipe, RecipeResult } from './professions.api';
import { apiError, qualityName } from './professions.model';

/**
 * Изделия основы: по строке `item_template` на ступень качества.
 *
 * Качество тянет за собой число слотов доводки, поэтому «то же изделие, но
 * редкое» - это ДРУГАЯ строка (DESIGN §5.4.5). Руками их заводить нельзя:
 * четыре ступени = четыре почти одинаковых предмета на каждую основу. Отсюда
 * «создать варианты» - копия образца на каждую ступень, с проставленным
 * качеством и склонённым именем.
 */
@Component({
  selector: 'app-recipe-results-dialog',
  imports: [IconComponent, ProfItemPickComponent, RouterLink],
  styleUrl: './recipe-dialog.scss',
  template: `
    <dialog #dialog class="forge-dialog" (close)="closed.emit()">
      <header>
        <h2>Изделия: {{ recipe()?.name_ru }}</h2>
        <button type="button" class="forge-btn is-icon close" aria-label="Закрыть" (click)="close()">
          <app-icon name="close" [size]="14" />
        </button>
      </header>

      <div class="body">
        @if (error(); as text) {
          <p class="forge-alert is-error">{{ text }}</p>
        }
        @if (canEdit()) {
          <div class="bar">
            <button
              type="button"
              class="forge-btn is-primary is-compact"
              title="Копия выбранного предмета на каждую ступень диапазона: качество и имя проставляются сами, остальное наследуется."
              (click)="sample.emit()"
            >
              Создать варианты по образцу
            </button>
          </div>
        }

        <table>
          <thead>
            <tr>
              <th>Качество</th>
              <th>Слотов</th>
              <th>Изделие</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            @for (step of steps(); track step.quality) {
              <tr>
                <td>{{ tierName(step.quality) }}</td>
                <td class="num">{{ step.slots }}</td>
                <td>
                  <app-prof-item-pick
                    [item]="step.row?.item ?? null"
                    [entry]="step.row?.result_entry ?? 0"
                    [iconBase]="iconBase()"
                    [readonly]="!canEdit()"
                    empty="изделия нет"
                    (pick)="pick.emit(step.quality)"
                    (changed)="setResult(step.quality, $event)"
                  />
                </td>
                <td>
                  @if (step.row?.result_entry) {
                    <a
                      class="forge-btn is-ghost is-compact"
                      [routerLink]="['/catalog/items', step.row!.result_entry]"
                      [title]="'Править строку предмета ' + step.row!.result_entry"
                    >
                      В каталоге
                    </a>
                  }
                </td>
              </tr>
            } @empty {
              <tr>
                <td colspan="4" class="empty">Диапазон качества пуст.</td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </dialog>
  `,
})
export class RecipeResultsDialogComponent {
  private readonly api = inject(ProfessionsApi);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');

  readonly meta = input<ProfessionsMeta | null>(null);
  readonly canEdit = input(false);
  readonly closed = output<void>();
  /** Просят окно выбора предмета: образец для всех ступеней либо одна ступень. */
  readonly sample = output<void>();
  readonly pick = output<number>();

  readonly recipe = signal<Recipe | null>(null);
  readonly error = signal<string | null>(null);

  readonly steps = computed(() => {
    const recipe = this.recipe();
    if (!recipe) return [];
    const out: { quality: number; slots: number; row: RecipeResult | undefined }[] = [];
    for (let quality = recipe.quality_min; quality <= recipe.quality_max; quality += 1) {
      out.push({
        quality,
        slots: this.meta()?.qualities?.find((tier) => tier.quality === quality)?.slots ?? 0,
        row: recipe.results.find((row) => row.quality === quality),
      });
    }
    return out;
  });

  open(recipe: Recipe): void {
    this.recipe.set(recipe);
    this.error.set(null);
    this.dialog().nativeElement.showModal();
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  iconBase(): string {
    return this.meta()?.icon_base_url ?? '';
  }

  tierName(quality: number): string {
    return qualityName(this.meta(), quality);
  }

  async setResult(quality: number, entry: number): Promise<void> {
    const recipe = this.recipe();
    if (!recipe || !this.canEdit()) return;
    try {
      await firstValueFrom(this.api.saveRecipeResult(recipe.id, { quality, result_entry: entry }));
      this.error.set(null);
      await this.refresh();
    } catch (error) {
      this.error.set(apiError(error, 'Изделие привязать не удалось.'));
    }
  }

  /** Перечитать саму основу: слайсы и счётчики ступеней считает сервер. */
  async refresh(): Promise<void> {
    const recipe = this.recipe();
    if (!recipe) return;
    try {
      const fresh = (await firstValueFrom(this.api.recipes())).recipes.find(
        (row) => row.id === recipe.id,
      );
      if (fresh) this.recipe.set(fresh);
    } catch (error) {
      this.error.set(apiError(error, 'Основу перечитать не удалось.'));
    }
  }
}
