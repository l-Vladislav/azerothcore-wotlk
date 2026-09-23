import { Component, ElementRef, computed, input, output, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { IconComponent } from '../../shared/ui/icon.component';
import { ItemTooltipDirective } from '../../shared/ui/item-tooltip.directive';
import { Material, ProfessionsMeta, Recipe } from './professions.api';
import { BLANK_ICON, dictName, iconUrl, statName, useBlankIcon } from './professions.model';

/** Качество строки item_template - шкала игры, а не ступени верстака. */
const ITEM_QUALITY: Record<number, string> = {
  0: 'Низкое',
  1: 'Обычное',
  2: 'Необычное',
  3: 'Редкое',
  4: 'Эпическое',
  5: 'Легендарное',
  6: 'Артефакт',
  7: 'Фамильное',
};

/**
 * Меню гнезда: чем его заполнить.
 *
 * Список сужен до камней, которые ЭТА основа вообще принимает - те же четыре
 * условия, что проверяет сервер (качество, границы уровня и фильтры основы).
 * Иначе панель предлагала бы набор, который в игре не собрать.
 *
 * Исключение - у основы ещё нет изделий: сужать тогда нечем, и пустое меню
 * выглядело бы поломкой. Показываем всё; замечание об изделиях и так висит.
 *
 * Заголовка нет (решение владельца 2026-09-23) - вместо него отборы: имя,
 * тип вставки, качество, характеристика. В списках только то, что есть среди
 * подходящих камней, иначе отбор приводил бы в пустоту. Наведение на камень
 * показывает игровую подсказку.
 */
@Component({
  selector: 'app-gem-picker',
  imports: [FormsModule, ForgeSelectDirective, IconComponent, ItemTooltipDirective],
  styleUrl: './gem-picker.dialog.scss',
  template: `
    <dialog #dialog class="forge-dialog" aria-label="Вставка в гнездо">
      <div class="search">
        <input
          class="forge-field is-small is-search"
          type="search"
          placeholder="имя камня"
          [ngModel]="query()"
          (ngModelChange)="query.set($event)"
        />
        <button
          type="button"
          class="forge-btn is-icon is-compact close"
          aria-label="Закрыть"
          (click)="close()"
        >
          <app-icon name="close" [size]="12" />
        </button>
      </div>
      <div class="filters">
        <select
          class="forge-field is-small is-select"
          [ngModel]="typeId()"
          (ngModelChange)="typeId.set($event)"
          aria-label="Тип вставки"
        >
          <option value="">любой тип</option>
          @for (opt of typeOptions(); track opt[0]) {
            <option [value]="opt[0]">{{ opt[1] }}</option>
          }
        </select>
        <select
          class="forge-field is-small is-select"
          [ngModel]="quality()"
          (ngModelChange)="quality.set($event)"
          aria-label="Качество"
        >
          <option value="">любое качество</option>
          @for (opt of qualityOptions(); track opt[0]) {
            <option [value]="opt[0]">{{ opt[1] }}</option>
          }
        </select>
        <select
          class="forge-field is-small is-select"
          [ngModel]="stat()"
          (ngModelChange)="stat.set($event)"
          aria-label="Характеристика"
        >
          <option value="">любая характеристика</option>
          @for (opt of statOptions(); track opt[0]) {
            <option [value]="opt[0]">{{ opt[1] }}</option>
          }
        </select>
      </div>

      <div class="grid">
        <button type="button" class="gem" (click)="choose(0)">
          <img [src]="blank" width="32" height="32" alt="" />
          <span class="nm">
            <b>— пусто —</b>
            <small>убрать из набора</small>
          </span>
        </button>
        @for (gem of shown(); track gem.entry) {
          <button
            type="button"
            class="gem"
            [class.is-on]="gem.entry === current()"
            [appItemTooltip]="gem.item ? gem.entry : 0"
            (click)="choose(gem.entry)"
          >
            <img [src]="src(gem)" width="32" height="32" alt="" (error)="onError($event)" />
            <span class="nm">
              <b [class]="'q' + (gem.item?.quality ?? 0)">{{ name(gem) }}</b>
              <small>{{ statLine(gem) }}</small>
            </span>
          </button>
        } @empty {
          <p class="muted">Под отбор не подошёл ни один камень.</p>
        }
      </div>
      <p class="count">Камней: {{ shown().length }} из {{ gems().length }}</p>
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

  readonly query = signal('');
  readonly typeId = signal('');
  readonly quality = signal('');
  readonly stat = signal('');

  readonly typeOptions = computed(() =>
    this.options(
      this.gems().map((gem) => gem.insert_type_id),
      (id) => dictName(this.meta()?.insert_types ?? [], id),
    ),
  );
  readonly qualityOptions = computed(() =>
    this.options(
      this.gems().map((gem) => gem.item?.quality ?? gem.quality),
      (q) => ITEM_QUALITY[q] ?? String(q),
      true,
    ),
  );
  readonly statOptions = computed(() =>
    this.options(
      this.gems()
        .map((gem) => gem.stat_type)
        .filter(Boolean),
      (id) => statName(this.meta(), id),
    ),
  );

  readonly shown = computed(() => {
    const needle = this.query().trim().toLocaleLowerCase();
    const type = this.typeId();
    const quality = this.quality();
    const stat = this.stat();
    return this.gems().filter(
      (gem) =>
        (!needle || this.name(gem).toLocaleLowerCase().includes(needle)) &&
        (type === '' || String(gem.insert_type_id) === type) &&
        (quality === '' || String(gem.item?.quality ?? gem.quality) === quality) &&
        (stat === '' || String(gem.stat_type) === stat),
    );
  });

  open(recipe: Recipe | null, current: number): void {
    // Каждое открытие - с чистыми отборами: гнездо другое, и прошлый отбор
    // мог спрятать как раз то, что в нём стоит.
    this.query.set('');
    this.typeId.set('');
    this.quality.set('');
    this.stat.set('');
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
  statLine(gem: Material): string {
    return `${statName(this.meta(), gem.stat_type)} +${gem.stat_value}`;
  }

  /** Варианты отбора - только встречающиеся значения; качество - по шкале, прочее - по имени. */
  private options(
    values: number[],
    label: (value: number) => string,
    byValue = false,
  ): [string, string][] {
    const out = [...new Set(values)].map(
      (value) => [String(value), label(value)] as [string, string],
    );
    return byValue
      ? out.sort((a, b) => +a[0] - +b[0])
      : out.sort((a, b) => a[1].localeCompare(b[1], 'ru'));
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
