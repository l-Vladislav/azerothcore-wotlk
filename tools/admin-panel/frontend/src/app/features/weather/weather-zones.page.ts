import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TablePagerComponent } from '../../shared/data/table-pager.component';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { WeatherApi, WeatherZone } from './weather.api';
import { WeatherOverviewStore } from './weather-overview.store';
import { ToastService } from '../../shared/ui/toast.service';

const seasonLabels: Record<string, string> = {
  spring: 'весна',
  summer: 'лето',
  fall: 'осень',
  winter: 'зима',
};

/**
 * Все зоны таблицей: отбор сверху, связи - на подстранице зоны.
 *
 * Раньше связи правились для зоны, выбранной НА КАРТЕ, и страница молча
 * зависела от чужого выбора: пришёл по ссылке - правишь неизвестно что.
 * Теперь зона выбирается здесь и стоит в адресе подстраницы.
 */
@Component({
  imports: [FormsModule, ForgeSelectDirective, TablePagerComponent],
  providers: [WeatherApi, WeatherOverviewStore],
  selector: 'app-weather-zones-page',
  styleUrl: './weather-zones.page.scss',
  templateUrl: './weather-zones.page.html',
})
export class WeatherZonesPage implements OnInit, OnDestroy {
  private readonly toast = inject(ToastService);
  private readonly router = inject(Router);
  readonly store = inject(WeatherOverviewStore);

  readonly search = signal('');
  readonly continent = signal('');
  readonly onlyLinked = signal(false);
  readonly page = signal(1);
  readonly perPage = signal(10);

  readonly continents = computed(() => this.store.overview()?.continents ?? []);

  readonly filtered = computed(() => {
    const needle = this.search().trim().toLocaleLowerCase();
    const continent = this.continent();
    const linked = this.onlyLinked();
    return this.store.zones().filter(
      (zone) =>
        (!continent || zone.continent === continent) &&
        (!linked || zone.links_out > 0 || zone.links_in > 0) &&
        (!needle ||
          zone.name.toLocaleLowerCase().includes(needle) ||
          String(zone.zone_id) === needle),
    );
  });

  readonly rows = computed(() => {
    const from = (this.page() - 1) * this.perPage();
    return this.filtered().slice(from, from + this.perPage());
  });

  constructor() {
    // Сообщения об удаче и отказе показываются всплывающими
    // плашками: строка наверху страницы сдвигала содержимое и
    // висела до следующего действия.
    this.toast.announce(this.store.error, 'error');
  }

  async ngOnInit(): Promise<void> {
    await this.store.start();
  }

  ngOnDestroy(): void {
    this.store.stop();
  }

  /** Любой отбор возвращает на первую страницу: иначе список уезжает в пустоту. */
  setSearch(value: string): void {
    this.search.set(value);
    this.page.set(1);
  }

  setContinent(value: string): void {
    this.continent.set(value);
    this.page.set(1);
  }

  toggleLinked(value: boolean): void {
    this.onlyLinked.set(value);
    this.page.set(1);
  }

  setPerPage(value: number): void {
    this.perPage.set(value);
    this.page.set(1);
  }

  open(zone: WeatherZone): void {
    void this.router.navigate(['/weather/zones', zone.zone_id]);
  }

  seasonLabel(season: string): string {
    return seasonLabels[season] ?? season;
  }
}
