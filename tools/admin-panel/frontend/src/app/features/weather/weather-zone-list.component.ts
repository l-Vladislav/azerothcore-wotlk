import { Component, computed, input, output, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { IconComponent } from '../../shared/ui/icon.component';
import { WeatherContinent, WeatherZone } from './weather.api';

/**
 * Список зон для боковой панели: поиск, континенты, состояние погоды.
 *
 * Отдельным компонентом потому, что его ставят в свою боковую панель обе
 * страницы погоды - карта и связи. Разметка на сотню строк, скопированная
 * дважды, разошлась бы при первой же правке.
 */
@Component({
  imports: [FormsModule, IconComponent],
  selector: 'app-weather-zone-list',
  styleUrl: './weather-zone-list.component.scss',
  template: `
    <aside class="forge-panel zone-list" aria-label="Список зон">
      <label class="search">
        <span class="sr-only">Найти зону</span>
        <input
          class="forge-field is-search"
          type="search"
          [ngModel]="filter()"
          (ngModelChange)="filter.set($event)"
          placeholder="Найти зону или ID"
        />
      </label>
      <div class="zone-scroll">
        @for (group of groups(); track group.key) {
          <section class="zone-group">
            <button type="button" class="group-head" (click)="toggleGroup(group.key)">
              <app-icon
                tone="plain"
                [name]="isOpen(group.key) ? 'caret' : 'caret-right'"
                [size]="12"
              />
              <strong>{{ group.name }}</strong>
              <small>{{ group.zones.length }}</small>
            </button>
            @if (isOpen(group.key)) {
              <div class="zone-rows">
                @for (zone of group.zones; track zone.zone_id) {
                  <button
                    type="button"
                    class="zone-row"
                    [class.active]="selectedId() === zone.zone_id"
                    [class.unknown]="!zone.known"
                    (click)="picked.emit(zone.zone_id)"
                  >
                    <span class="weather-mark" [class]="'weather-mark ' + zone.state_group"></span>
                    <span class="zone-name">{{ zone.name }}</span>
                    @if (zone.links_out || zone.links_in) {
                      <span class="link-count" title="Исходящие / входящие связи">
                        <app-icon name="external" [size]="11" />{{ zone.links_out }}
                      </span>
                    }
                    <small>{{ zone.known ? zone.state_label : 'нет данных' }}</small>
                  </button>
                }
              </div>
            }
          </section>
        } @empty {
          <p class="empty">Ничего не найдено.</p>
        }
      </div>
    </aside>
  `,
})
export class WeatherZoneListComponent {
  readonly zones = input.required<readonly WeatherZone[]>();
  readonly continents = input.required<readonly WeatherContinent[]>();
  readonly selectedId = input<number | null>(null);
  readonly picked = output<number>();

  readonly filter = signal('');
  private readonly collapsed = signal<ReadonlySet<string>>(new Set());

  readonly groups = computed(() => {
    const needle = this.filter().trim().toLocaleLowerCase();
    return this.continents()
      .map((continent) => ({
        ...continent,
        zones: this.zones().filter(
          (zone) =>
            zone.continent === continent.key &&
            (!needle ||
              zone.name.toLocaleLowerCase().includes(needle) ||
              String(zone.zone_id) === needle),
        ),
      }))
      .filter((group) => group.zones.length > 0);
  });

  /** Поиск раскрывает все группы: иначе находка прячется в свёрнутой. */
  isOpen(key: string): boolean {
    return Boolean(this.filter().trim()) || !this.collapsed().has(key);
  }

  toggleGroup(key: string): void {
    const next = new Set(this.collapsed());
    if (next.has(key)) next.delete(key);
    else next.add(key);
    this.collapsed.set(next);
  }
}
