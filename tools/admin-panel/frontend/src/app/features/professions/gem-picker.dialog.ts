import { Component, ElementRef, input, output, signal, viewChild } from '@angular/core';
import { IconComponent } from '../../shared/ui/icon.component';
import { Material, ProfessionsMeta, Recipe } from './professions.api';
import { BLANK_ICON, iconUrl, statName, useBlankIcon } from './professions.model';

/**
 * Меню гнезда: чем его заполнить.
 *
 * Список сужен до камней, которые ЭТА основа вообще принимает - те же четыре
 * условия, что проверяет сервер (качество, границы уровня и фильтры рецепта).
 * Иначе панель предлагала бы набор, который в игре не собрать.
 *
 * Исключение - у основы ещё нет изделий: сужать тогда нечем, и пустое меню
 * выглядело бы поломкой. Показываем всё; замечание об изделиях и так висит.
 */
@Component({
  selector: 'app-gem-picker',
  imports: [IconComponent],
  styleUrl: './gem-picker.dialog.scss',
  template: `
    <dialog #dialog>
      <header>
        <h2>Вставка в гнездо</h2>
        <button type="button" class="forge-btn is-icon close" aria-label="Закрыть" (click)="close()">
          <app-icon name="close" [size]="14" />
        </button>
      </header>

      <div class="grid">
        <button type="button" class="gem" (click)="choose(0)">
          <img [src]="blank" width="32" height="32" alt="" />
          <span class="nm">
            <b>— пусто —</b>
            <small>убрать из набора</small>
          </span>
        </button>
        @for (gem of gems(); track gem.entry) {
          <button
            type="button"
            class="gem"
            [class.is-on]="gem.entry === current()"
            (click)="choose(gem.entry)"
          >
            <img [src]="src(gem)" width="32" height="32" alt="" (error)="onError($event)" />
            <span class="nm">
              <b [class]="'q' + (gem.item?.quality ?? 0)">{{ name(gem) }}</b>
              <small>{{ stat(gem) }}</small>
            </span>
          </button>
        }
      </div>
    </dialog>
  `,
})
export class GemPickerDialogComponent {
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');

  readonly meta = input<ProfessionsMeta | null>(null);
  readonly materials = input<readonly Material[]>([]);
  readonly picked = output<number>();

  readonly gems = signal<Material[]>([]);
  readonly current = signal(0);
  readonly blank = BLANK_ICON;

  open(recipe: Recipe | null, current: number): void {
    this.current.set(current);
    this.gems.set(this.fitting(recipe));
    this.dialog().nativeElement.showModal();
  }

  close(): void {
    this.dialog().nativeElement.close();
  }

  choose(entry: number): void {
    this.picked.emit(entry);
    this.close();
  }

  src(gem: Material): string {
    return gem.item?.icon ? iconUrl(gem.item.icon, this.meta()?.icon_base_url) : BLANK_ICON;
  }

  name(gem: Material): string {
    return gem.name_ru || gem.item?.name || String(gem.entry);
  }

  /** Что камень даёт: единственный способ отличить два одинаковых на вид. */
  stat(gem: Material): string {
    return `${statName(this.meta(), gem.stat_type)} +${gem.stat_value}`;
  }

  onError(event: Event): void {
    useBlankIcon(event);
  }

  private fitting(recipe: Recipe | null): Material[] {
    const all = this.materials().filter((mat) => mat.role !== 'base');
    if (!recipe) return [...all];
    const seen = new Set<number>();
    for (const step of recipe.inlay ?? []) {
      for (const entry of step.gem_entries ?? []) seen.add(entry);
    }
    if (!seen.size) return [...all];
    return all.filter((mat) => seen.has(mat.entry));
  }
}
