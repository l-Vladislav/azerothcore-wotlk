import {
  Component,
  OnDestroy,
  OnInit,
  TemplateRef,
  ViewChild,
  computed,
  inject,
  signal,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { SidebarService } from '../../core/sidebar/sidebar.service';
import { ToastService } from '../../shared/ui/toast.service';
import { WeatherApi, WeatherDraft, WeatherState, WeatherZone } from './weather.api';
import { WeatherMapComponent } from './weather-map.component';
import { WeatherOverviewStore } from './weather-overview.store';
import { WeatherStateIconComponent } from './weather-state-icon.component';
import { WeatherZoneListComponent } from './weather-zone-list.component';

const seasonLabels: Record<string, string> = {
  spring: 'весна',
  summer: 'лето',
  fall: 'осень',
  winter: 'зима',
};

const groupLabels: Record<string, string> = {
  clear: 'Ясное небо',
  rain: 'Дождь',
  snow: 'Снег',
  storm: 'Песчаная буря',
  special: 'Особые состояния',
};

/**
 * Карта погоды и ничего кроме: выбрал зону - поставил погоду.
 *
 * Раньше карта делила страницу со сводкой, состоянием режиссёра и редактором
 * связей, и до самой карты приходилось прокручивать. Связи остались на своей
 * странице: там правят то, что живёт дольше одного щелчка по карте.
 */
@Component({
  imports: [FormsModule, WeatherMapComponent, WeatherStateIconComponent, WeatherZoneListComponent],
  providers: [WeatherApi, WeatherOverviewStore],
  selector: 'app-weather-map-page',
  styleUrl: './weather-map.page.scss',
  templateUrl: './weather-map.page.html',
})
export class WeatherMapPage implements OnInit, OnDestroy {
  /**
   * Запрос вида пересчитывается после каждой перерисовки страницы - в том
   * числе когда выбор зоны создаёт панель инструментов карты. Шаблон при этом
   * тот же самый, и перерегистрировать его незачем: иначе щелчок по карте
   * каждый раз распахивал бы список зон, который хозяин только что свернул.
   */
  @ViewChild('sidebar')
  set sidebarTemplate(template: TemplateRef<unknown> | undefined) {
    if (!template || template === this.registeredTemplate) return;
    this.unregisterSidebar?.();
    this.registeredTemplate = template;
    this.unregisterSidebar = this.sidebar.register({ label: 'Зоны', template });
    if (this.sidebar.collapsed()) this.sidebar.toggle();
  }

  private readonly api = inject(WeatherApi);
  private readonly sidebar = inject(SidebarService);
  private readonly toast = inject(ToastService);
  private unregisterSidebar?: () => void;
  private registeredTemplate?: TemplateRef<unknown>;

  readonly store = inject(WeatherOverviewStore);
  readonly draft = signal<WeatherDraft | null>(null);

  readonly groupedStates = computed(() => {
    const groups = new Map<string, WeatherState[]>();
    for (const state of this.store.overview()?.states ?? []) {
      groups.set(state.group, [...(groups.get(state.group) ?? []), state]);
    }
    return [...groups.entries()];
  });

  constructor() {
    // Сообщения об удаче и отказе показываются всплывающими
    // плашками: строка наверху страницы сдвигала содержимое и
    // висела до следующего действия.
    this.toast.announce(this.store.error, 'error');
  }

  async ngOnInit(): Promise<void> {
    this.store.onSelect = () => this.draft.set(null);
    await this.store.start();
  }

  ngOnDestroy(): void {
    this.store.stop();
    this.unregisterSidebar?.();
    this.registeredTemplate = undefined;
  }

  draftFor(zone: WeatherZone): WeatherDraft {
    return (
      this.draft() ?? {
        state: zone.state,
        grade: Math.max(zone.grade || 0, this.store.overview()?.grade_min ?? 0),
        minutes: 0,
      }
    );
  }

  private editableDraft(zone: WeatherZone): WeatherDraft {
    const draft = this.draftFor(zone);
    this.draft.set(draft);
    return draft;
  }

  chooseState(zone: WeatherZone, state: number): void {
    this.draft.set({ ...this.editableDraft(zone), state });
  }

  /** Щелчок по значку состояния ставит погоду сразу: карта - это пульт. */
  async applyState(zone: WeatherZone, state: number): Promise<void> {
    this.chooseState(zone, state);
    await this.save(zone);
  }

  setGrade(zone: WeatherZone, grade: number): void {
    this.draft.set({ ...this.editableDraft(zone), grade: Number(grade) });
  }

  setMinutes(zone: WeatherZone, minutes: number): void {
    this.draft.set({
      ...this.editableDraft(zone),
      minutes: Math.max(0, Math.min(1440, Number(minutes) || 0)),
    });
  }

  groupLabel(group: string): string {
    return groupLabels[group] ?? group;
  }

  seasonLabel(season: string): string {
    return seasonLabels[season] ?? season;
  }

  timeLeft(seconds: number): string {
    if (!seconds) return 'без таймера';
    const minutes = Math.floor(seconds / 60);
    return minutes ? `${minutes} мин.` : `${seconds} сек.`;
  }

  async save(zone: WeatherZone): Promise<void> {
    if (!this.store.canEdit()) return;
    this.store.pending.set('zone');
    this.store.error.set(null);
    try {
      const saved = await firstValueFrom(this.api.setZone(zone.zone_id, this.draftFor(zone)));
      this.store.merge(saved);
      this.draft.set(null);
      this.toast.show(`${saved.name}: ${saved.state_label}.`);
    } catch (error) {
      this.store.error.set(
        this.store.errorText(error, `Не удалось изменить погоду в зоне «${zone.name}».`),
      );
    } finally {
      this.store.pending.set(null);
    }
  }

  async pin(zone: WeatherZone): Promise<void> {
    if (!this.store.canEdit()) return;
    this.store.pending.set('pin');
    this.store.error.set(null);
    try {
      const saved = await firstValueFrom(this.api.pin(zone.zone_id));
      this.store.merge(saved);
      this.draft.set(null);
      this.toast.show(`${zone.name}: погода закреплена.`);
    } catch (error) {
      this.store.error.set(
        this.store.errorText(error, `Не удалось закрепить погоду в зоне «${zone.name}».`),
      );
    } finally {
      this.store.pending.set(null);
    }
  }

  async releaseAll(): Promise<void> {
    if (!this.store.canEdit() || !this.store.hasManualOverrides()) return;
    this.store.pending.set('release-all');
    this.store.error.set(null);
    try {
      const result = await firstValueFrom(this.api.releaseAll());
      this.toast.show(`Режиссёру возвращено зон: ${result.released}.`);
      await this.store.load(true);
    } catch (error) {
      this.store.error.set(this.store.errorText(error, 'Не удалось вернуть зоны режиссёру.'));
    } finally {
      this.store.pending.set(null);
    }
  }
}
