import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { Router } from '@angular/router';
import { TablePagerComponent } from '../../shared/data/table-pager.component';
import { AuthService } from '../../core/auth.service';
import { EnvironmentApi, ZoneSummary } from './environment.api';
import { ToastService } from '../../shared/ui/toast.service';

/**
 * Все зоны с правилами - таблицей; правила самой зоны - на её подстранице.
 *
 * Прежде список зон стоял колонкой слева от редактора: отбирать в нём было
 * нечем, а увидеть, где правил много, а где их нет вовсе, - только глазами по
 * всему столбцу.
 */
@Component({
  imports: [FormsModule, TablePagerComponent],
  providers: [EnvironmentApi],
  selector: 'app-environment-zones-page',
  styleUrl: './environment-zones.page.scss',
  templateUrl: './environment-zones.page.html',
})
export class EnvironmentZonesPage implements OnInit {
  private readonly toast = inject(ToastService);
  private readonly api = inject(EnvironmentApi);
  private readonly router = inject(Router);
  private readonly auth = inject(AuthService);
  private searchTimer: ReturnType<typeof setTimeout> | undefined;

  readonly zones = signal<readonly ZoneSummary[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  readonly filter = signal('');
  readonly onlyGlobal = signal(false);
  readonly page = signal(1);
  readonly perPage = signal(10);

  /** Поиск по всему справочнику зон: чтобы завести правила там, где их нет. */
  readonly search = signal('');
  readonly searchHits = signal<readonly Pick<ZoneSummary, 'zone_id' | 'name'>[]>([]);

  readonly canEdit = computed(() => this.auth.actor()?.role !== 'viewer');

  readonly filtered = computed(() => {
    const needle = this.filter().trim().toLocaleLowerCase();
    const global = this.onlyGlobal();
    return this.zones().filter(
      (zone) =>
        (!global || zone.global) &&
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
    this.toast.announce(this.error, 'error');
  }

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  async load(): Promise<void> {
    this.loading.set(true);
    try {
      const zones = await firstValueFrom(this.api.zones());
      // Общемировые правила - такая же строка, как зона: без неё до них было
      // бы не добраться, а живут они под номером ноль.
      this.zones.set(
        zones.some((zone) => zone.global)
          ? zones
          : [
              {
                zone_id: 0,
                name: 'Общемировые правила',
                global: true,
                buffs: 0,
                debuffs: 0,
                disabled: 0,
              },
              ...zones,
            ],
      );
      this.error.set(null);
    } catch {
      this.error.set('Не удалось получить список зон.');
    } finally {
      this.loading.set(false);
    }
  }

  setFilter(value: string): void {
    this.filter.set(value);
    this.page.set(1);
  }

  toggleGlobal(value: boolean): void {
    this.onlyGlobal.set(value);
    this.page.set(1);
  }

  setPerPage(value: number): void {
    this.perPage.set(value);
    this.page.set(1);
  }

  /** Поиск по справочнику - с задержкой: он ходит на сервер. */
  searchZones(query: string): void {
    this.search.set(query);
    clearTimeout(this.searchTimer);
    if (query.trim().length < 2) {
      this.searchHits.set([]);
      return;
    }
    this.searchTimer = setTimeout(async () => {
      try {
        const hits = await firstValueFrom(this.api.searchZones(query.trim()));
        // Те, у кого правила уже есть, в подсказке не нужны - они в таблице.
        const known = new Set(this.zones().map((zone) => zone.zone_id));
        this.searchHits.set(hits.filter((zone) => !known.has(zone.zone_id)));
      } catch {
        this.searchHits.set([]);
      }
    }, 250);
  }

  open(zoneId: number): void {
    void this.router.navigate(['/environment/zones', zoneId]);
  }

  total(zone: ZoneSummary): number {
    return zone.buffs + zone.debuffs;
  }
}
