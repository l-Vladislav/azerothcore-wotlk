import { Injectable, OnDestroy, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { WeatherApi, WeatherOverview, WeatherZone } from './weather.api';

const refreshMs = 15_000;

/**
 * Состояние погоды, общее для карты и для страницы связей.
 *
 * Обе страницы читают один и тот же обзор модуля, ведут один и тот же выбор
 * зоны и одинаково обновляются раз в пятнадцать секунд. Без этого хранилища
 * разделение страницы на две означало бы вторую копию загрузки, опроса и
 * слияния ответов - то есть два места, где одна и та же ошибка чинится
 * по-разному.
 *
 * Даётся НЕ в корне, а страницей: у каждой свой выбор зоны и свой опрос,
 * который должен останавливаться вместе с ней.
 */
@Injectable()
export class WeatherOverviewStore implements OnDestroy {
  private readonly api = inject(WeatherApi);
  private readonly auth = inject(AuthService);
  private timer: ReturnType<typeof setInterval> | undefined;
  private requestId = 0;

  readonly overview = signal<WeatherOverview | null>(null);
  readonly selectedId = signal<number | null>(null);
  readonly loading = signal(true);
  readonly pending = signal<string | null>(null);
  readonly error = signal<string | null>(null);

  readonly canEdit = computed(() => this.auth.actor()?.role !== 'viewer');
  readonly zones = computed(() => this.overview()?.zones ?? []);
  readonly selectedZone = computed(() => {
    const id = this.selectedId();
    return this.zones().find((zone) => zone.zone_id === id) ?? null;
  });
  readonly hasManualOverrides = computed(() =>
    this.zones().some((zone) => zone.source === 1 || zone.source === 2),
  );

  /** Вызывается страницей: что делать при смене зоны, знает только она. */
  onSelect?: (zoneId: number | null) => void;

  ngOnDestroy(): void {
    this.stop();
  }

  async start(): Promise<void> {
    await this.load();
    this.timer = setInterval(() => {
      if (this.pending() === null) void this.load(true);
    }, refreshMs);
  }

  stop(): void {
    clearInterval(this.timer);
    ++this.requestId;
  }

  async load(silent = false): Promise<void> {
    const requestId = ++this.requestId;
    if (!silent) this.loading.set(true);
    try {
      const response = await firstValueFrom(this.api.overview());
      if (requestId !== this.requestId) return;
      this.overview.set(response);
      const selected = this.selectedId();
      if (selected === null || !response.zones.some((zone) => zone.zone_id === selected)) {
        this.select(response.zones[0]?.zone_id ?? null);
      }
      this.error.set(null);
    } catch (error) {
      if (requestId === this.requestId) {
        this.error.set(this.errorText(error, 'Не удалось получить состояние модуля погоды.'));
      }
    } finally {
      if (requestId === this.requestId && !silent) this.loading.set(false);
    }
  }

  select(zoneId: number | null): void {
    if (this.selectedId() === zoneId) return;
    this.selectedId.set(zoneId);
    this.onSelect?.(zoneId);
  }

  /** Ответ сервера про одну зону - в общий список, без полной перезагрузки. */
  merge(saved: WeatherZone): void {
    this.overview.update((overview) =>
      overview
        ? {
            ...overview,
            zones: overview.zones.map((zone) =>
              zone.zone_id === saved.zone_id ? { ...zone, ...saved } : zone,
            ),
          }
        : overview,
    );
  }

  errorText(error: unknown, fallback: string): string {
    if (typeof error === 'object' && error && 'error' in error) {
      const body = (error as { error?: unknown }).error;
      if (typeof body === 'object' && body && 'detail' in body) {
        const detail = (body as { detail?: unknown }).detail;
        if (typeof detail === 'string') return detail;
      }
    }
    return fallback;
  }
}
