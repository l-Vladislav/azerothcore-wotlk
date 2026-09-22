import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { ToastService } from '../../shared/ui/toast.service';
import {
  Cyclone,
  CycloneDraft,
  QueueDraft,
  QueueEntry,
  QueueMap,
  WeatherApi,
  WeatherQueue,
} from './weather.api';
import { WeatherMapComponent } from './weather-map.component';
import { WeatherOverviewStore } from './weather-overview.store';

const familyNames: Record<number, string> = {
  1: 'дождь',
  2: 'снег',
  3: 'песчаная буря',
  4: 'туман',
};

/** Сколько ступеней у семейства: выше - уже порченая погода, её фронт не ставит. */
const familyPeak: Record<number, number> = { 1: 4, 2: 3, 3: 3, 4: 1 };

/**
 * Фронты: что идёт по картам сейчас и как поставить свой.
 *
 * Самозарождающиеся фронты хороши тем, что мир живёт сам, но когда нужен шторм
 * над определённым местом, ждать у моря погоды нельзя. Свой фронт ставится
 * щелчком по карте и переживает и «перезапустить фронты», и правку настроек -
 * но живёт в памяти мира и не переживает его перезапуск. Так честнее, чем
 * обещать вечность и потерять её на первом же рестарте.
 */
@Component({
  imports: [FormsModule, ForgeSelectDirective, WeatherMapComponent],
  providers: [WeatherApi, WeatherOverviewStore],
  selector: 'app-weather-fronts-page',
  styleUrl: './weather-fronts.page.scss',
  templateUrl: './weather-fronts.page.html',
})
export class WeatherFrontsPage implements OnInit, OnDestroy {
  private readonly api = inject(WeatherApi);
  private readonly toast = inject(ToastService);
  readonly store = inject(WeatherOverviewStore);

  readonly selectedId = signal<number | null>(null);
  readonly placing = signal(false);
  readonly draft = signal<CycloneDraft>({
    family: 1,
    peak: 0,
    radius: 0,
    minutes: 0,
  });

  // Очередь: заготовки, которые выпускаются по одной с паузой между ними.
  // Живёт в своей таблице, поэтому грузится отдельно от обзора погоды.
  readonly queue = signal<WeatherQueue | null>(null);
  readonly queueDraft = signal<Partial<QueueDraft>>({ map: 0, family: 1 });
  readonly maps = [
    { id: 0, name: 'Восточные королевства' },
    { id: 1, name: 'Калимдор' },
    { id: 530, name: 'Запределье' },
    { id: 571, name: 'Нордскол' },
  ];

  readonly cyclones = computed(() => this.store.overview()?.cyclones ?? []);
  readonly selected = computed(
    () => this.cyclones().find((c) => c.id === this.selectedId()) ?? null,
  );
  readonly families = [1, 2, 3, 4];

  constructor() {
    // Сообщения об удаче и отказе показываются всплывающими
    // плашками: строка наверху страницы сдвигала содержимое и
    // висела до следующего действия.
    this.toast.announce(this.store.error, 'error');
  }

  async ngOnInit(): Promise<void> {
    await Promise.all([this.store.start(), this.loadQueue()]);
  }

  private async loadQueue(): Promise<void> {
    try {
      this.queue.set(await firstValueFrom(this.api.queue()));
    } catch (error) {
      this.toast.show(this.store.errorText(error, 'Не удалось прочитать очередь.'), 'error');
    }
  }

  patchQueueDraft(patch: Partial<QueueDraft>): void {
    this.queueDraft.update((draft) => ({ ...draft, ...patch }));
  }

  async queueAdd(): Promise<void> {
    if (!this.store.canEdit()) return;
    this.store.pending.set('queue-add');
    try {
      this.queue.set(await firstValueFrom(this.api.queueAdd(this.queueDraft())));
      this.queueDraft.set({ map: 0, family: 1 });
      this.toast.show('Заготовка добавлена в очередь.');
    } catch (error) {
      this.toast.show(this.store.errorText(error, 'Сервер не принял заготовку.'), 'error');
    } finally {
      this.store.pending.set(null);
    }
  }

  async queueSave(entry: QueueEntry, patch: Partial<QueueDraft>): Promise<void> {
    if (!this.store.canEdit()) return;
    this.store.pending.set('queue-save');
    try {
      const { id, map_name, zone_name, family_name, peak_name, current, auto, ...rest } =
        entry;
      this.queue.set(await firstValueFrom(this.api.queueSave(id, { ...rest, ...patch })));
    } catch (error) {
      this.toast.show(this.store.errorText(error, 'Сервер не принял правку.'), 'error');
    } finally {
      this.store.pending.set(null);
    }
  }

  async queueDelete(entry: QueueEntry): Promise<void> {
    if (!this.store.canEdit()) return;
    if (!confirm(`Убрать заготовку №${entry.id} из очереди?`)) return;
    this.store.pending.set('queue-del');
    try {
      this.queue.set(await firstValueFrom(this.api.queueDelete(entry.id)));
      this.toast.show('Заготовка убрана.');
    } catch (error) {
      this.toast.show(this.store.errorText(error, 'Не удалось убрать заготовку.'), 'error');
    } finally {
      this.store.pending.set(null);
    }
  }

  /** Заготовки одного континента - в порядке выпуска. */
  entriesOf(map: number): QueueEntry[] {
    return (this.queue()?.entries ?? []).filter((entry) => entry.map === map);
  }

  /** «по 10 на континент, пауза 10 мин.» - чем очередь держится. */
  queueNote(): string {
    const list = this.queue();
    if (!list?.available) return '';
    const parts: string[] = [];
    if (list.fill) parts.push(`по ${list.fill} на континент`);
    if (list.gap) parts.push(`пауза ${list.gap} мин.`);
    return parts.join(', ');
  }

  /**
   * Что сейчас с очередью этого континента.
   *
   * Пустая пауза значит разное: небо может быть занято идущим фронтом, а может
   * ждать ближайшего тика. Разница видна только вместе с потолком неба, иначе
   * страница обещала бы фронт «вот-вот» там, где ему ещё сорок минут негде
   * встать.
   */
  groupNote(group: QueueMap): string {
    if (group.off) return 'фронты сюда не ходят';

    const list = this.queue();
    const waiting = `ждут: ${group.waiting}`;
    if (list?.per_map && group.live >= list.per_map) {
      return `${waiting} · небо занято`;
    }
    if (group.wait) {
      const minutes = Math.floor(group.wait / 60);
      const left = minutes ? `${minutes} мин.` : `${group.wait} сек.`;
      return `${waiting} · следующий через ${left}`;
    }
    return `${waiting} · следующий вот-вот`;
  }

  ngOnDestroy(): void {
    this.store.stop();
  }

  familyName(family: number): string {
    return familyNames[family] ?? String(family);
  }

  peakMax(family: number): number {
    return familyPeak[family] ?? 1;
  }

  /** «через 12 мин.» - сколько фронту осталось идти. */
  timeLeft(seconds: number): string {
    if (!seconds) return 'уходит';
    const minutes = Math.floor(seconds / 60);
    return minutes ? `${minutes} мин.` : `${seconds} сек.`;
  }

  select(id: number): void {
    this.selectedId.set(this.selectedId() === id ? null : id);
  }

  /** Щелчок по карте в режиме постановки ставит фронт в эту точку. */
  async placeAt(point: { map: number; x: number; y: number }): Promise<void> {
    if (!this.placing() || !this.store.canEdit()) return;
    this.store.pending.set('cyclone-add');
    try {
      const front = await firstValueFrom(
        this.api.addCyclone({ ...this.draft(), map: point.map, x: point.x, y: point.y }),
      );
      await this.store.load(true);
      this.selectedId.set(front.id);
      this.placing.set(false);
      this.toast.show(`Фронт №${front.id} поставлен.`);
    } catch (error) {
      this.toast.show(this.store.errorText(error, 'Не удалось поставить фронт.'), 'error');
    } finally {
      this.store.pending.set(null);
    }
  }

  async edit(front: Cyclone, field: string, value: number): Promise<void> {
    if (!this.store.canEdit()) return;
    this.store.pending.set('cyclone-set');
    try {
      await firstValueFrom(this.api.setCyclone(front.id, field, Math.round(value)));
      await this.store.load(true);
    } catch (error) {
      this.toast.show(this.store.errorText(error, 'Сервер не принял правку.'), 'error');
    } finally {
      this.store.pending.set(null);
    }
  }

  async remove(front: Cyclone): Promise<void> {
    if (!this.store.canEdit()) return;
    if (!confirm(`Убрать фронт №${front.id}?`)) return;
    this.store.pending.set('cyclone-del');
    try {
      await firstValueFrom(this.api.removeCyclone(front.id));
      if (this.selectedId() === front.id) this.selectedId.set(null);
      await this.store.load(true);
      this.toast.show('Фронт убран.');
    } catch (error) {
      this.toast.show(this.store.errorText(error, 'Не удалось убрать фронт.'), 'error');
    } finally {
      this.store.pending.set(null);
    }
  }

  async resetAll(): Promise<void> {
    if (!this.store.canEdit()) return;
    this.store.pending.set('cyclone-reset');
    try {
      await firstValueFrom(this.api.resetCyclones());
      await this.store.load(true);
      this.toast.show('Самозародившиеся фронты перезапущены.');
    } catch (error) {
      this.toast.show(this.store.errorText(error, 'Не удалось перезапустить фронты.'), 'error');
    } finally {
      this.store.pending.set(null);
    }
  }

  patchDraft(patch: Partial<CycloneDraft>): void {
    this.draft.update((draft) => ({ ...draft, ...patch }));
  }
}
