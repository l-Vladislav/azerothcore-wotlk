import { Injectable, inject } from '@angular/core';
import { ApiService } from '../../core/api.service';

export interface WeatherState {
  id: number;
  label: string;
  group: string;
}

export interface WeatherZone {
  zone_id: number;
  name: string;
  continent: string;
  continent_name: string;
  state: number;
  state_label: string;
  state_group: string;
  grade: number;
  source: number;
  source_label: string;
  seconds_left: number;
  has_climate: boolean;
  module_only: boolean;
  known: boolean;
  players: boolean;
  origin: number;
  origin_name: string | null;
  origin_strength: number;
  links_out: number;
  links_in: number;
}

/** Заготовленный фронт: что выпустить, когда подойдёт его черёд. */
export interface QueueEntry {
  id: number;
  ord: number;
  map: number;
  map_name: string;
  zone: number;
  zone_name: string;
  family: number;
  family_name: string;
  /** Нули значат «как у самозародившегося»: из настроек модуля. */
  peak: number;
  /** Ступень словом: «Гроза», «Метель», «Чёрный дождь». */
  peak_name: string;
  radius: number;
  minutes: number;
  enabled: boolean;
  comment: string;
  /** Собрана жребием: такую расходуют насовсем, взамен придёт свежая. */
  auto: boolean;
  /** Эту запись выпустят следующей на своей карте. */
  current: boolean;
}

/** Что мир помнит об очереди одного континента. */
export interface QueueMap {
  map: number;
  map_name: string;
  /** Номер записи, которую выпустят следующей. */
  current: number;
  /** Секунд до выпуска. 0 - либо вот-вот, либо небо занято. */
  wait: number;
  /** Сколько заготовок ждёт своей очереди. */
  waiting: number;
  /** Сколько фронтов над картой сейчас. */
  live: number;
  /** Фронты сюда не ходят, а строки остались. */
  off?: boolean;
}

export interface WeatherQueue {
  available: boolean;
  reason?: string;
  entries: QueueEntry[];
  maps: QueueMap[];
  /** Сколько заготовок мир держит наготове на каждом континенте. */
  fill: number;
  /** Пауза между фронтами, минуты. */
  gap: number;
  /** Потолок неба: сколько фронтов держать над картой. */
  per_map: number;
}

export type QueueDraft = Omit<
  QueueEntry,
  'id' | 'map_name' | 'zone_name' | 'family_name' | 'peak_name' | 'current' | 'auto'
>;

/** Шансы осадков зоны по сезонам - ядровая таблица `game_weather`. */
export interface ZoneClimate {
  zone_id: number;
  known: boolean;
  seasons: Record<string, Record<string, number>>;
  season_names: Record<string, string>;
  kind_names: Record<string, string>;
  /** Ядро читает эти строки только на старте мира. */
  needs_restart: boolean;
}

/** Континент карты: ключ группы и подпись для списка зон. */
export interface WeatherContinent {
  key: string;
  name: string;
}

export interface WeatherOverview {
  module: {
    ok: boolean;
    protocol: string;
    enabled: boolean;
    can_toggle: boolean;
    stored: boolean;
  };
  protocol_expected: string;
  states: WeatherState[];
  grade_min: number;
  continents: WeatherContinent[];
  zones: WeatherZone[];
  season: string;
  live_count: number;
  known_count: number;
  link_count: number;
  links_table: boolean;
  cyclones?: Cyclone[];
}

export interface WeatherDraft {
  state: number;
  grade: number;
  minutes: number;
}

export interface WeatherSettingGroup {
  key: string;
  name: string;
  hint?: string;
}

export interface WeatherSetting {
  name: string;
  value: number;
  default: number;
  stored: boolean;
  min: number;
  max: number;
  label: string;
  hint: string;
  unit: string;
  kind: 'bool' | 'int' | 'choice';
  options: { value: number; label: string }[];
  group: string;
}

export interface WeatherSettings {
  groups: WeatherSettingGroup[];
  settings: WeatherSetting[];
  supported: boolean;
}

export interface Cyclone {
  id: number;
  map: number;
  x: number;
  y: number;
  radius: number;
  eye: number;
  heading: number;
  arms: number;
  spin: number;
  twist: number;
  spin_minutes: number;
  family_name: string;
  family_group: string;
  peak: number;
  speed: number;
  seconds_left: number;
  zones: number;
  /** Семейство числом - его принимает `cycset family`. */
  family: number;
  /** Поставлен руками: переживает перезапуск фронтов и правку настроек. */
  manual: boolean;
}

/** Что задают, ставя свой фронт. Ноль - «возьми из настроек модуля». */
export interface CycloneDraft {
  family: number;
  peak: number;
  radius: number;
  minutes: number;
  heading?: number;
  speed?: number;
}

export interface WeatherLinkPreview {
  state: number;
  grade: number;
  label: string;
  adapted: boolean;
  from_label: string;
}

export interface WeatherZoneLink {
  zone_id: number;
  name: string;
  strength: number;
  enabled: boolean;
  comment: string;
  incoming: boolean;
  mirror: boolean;
  preview: WeatherLinkPreview | null;
}

export interface WeatherLinks {
  zone_id: number;
  name: string;
  season: string;
  out: WeatherZoneLink[];
  in: WeatherZoneLink[];
}

export interface WeatherLinkDraft {
  linked_zone: number;
  strength: number;
  enabled: boolean;
  comment: string;
  mirror: boolean;
}

@Injectable()
export class WeatherApi {
  private readonly api = inject(ApiService);

  overview() {
    return this.api.get<WeatherOverview>('/weather');
  }

  setDirector(enabled: boolean) {
    return this.api.put<{ enabled: boolean; stored: boolean }>('/weather/director', { enabled });
  }

  setZone(zoneId: number, draft: WeatherDraft) {
    return this.api.put<WeatherZone>(`/weather/zones/${zoneId}`, draft);
  }

  pin(zoneId: number) {
    return this.api.post<WeatherZone>(`/weather/zones/${zoneId}/pin`);
  }

  releaseAll() {
    return this.api.post<{ released: number }>('/weather/release');
  }

  queue() {
    return this.api.get<WeatherQueue>('/weather/queue');
  }

  queueAdd(draft: Partial<QueueDraft>) {
    return this.api.post<WeatherQueue>('/weather/queue', draft);
  }

  queueSave(id: number, draft: Partial<QueueDraft>) {
    return this.api.put<WeatherQueue>(`/weather/queue/${id}`, draft);
  }

  queueDelete(id: number) {
    return this.api.delete<WeatherQueue>(`/weather/queue/${id}`);
  }

  climate(zoneId: number) {
    return this.api.get<ZoneClimate>(`/weather/zones/${zoneId}/climate`);
  }

  saveClimate(zoneId: number, seasons: Record<string, Record<string, number>>) {
    return this.api.put<ZoneClimate>(`/weather/zones/${zoneId}/climate`, { seasons });
  }

  links(zoneId: number) {
    return this.api.get<WeatherLinks>(`/weather/zones/${zoneId}/links`);
  }

  saveLinks(zoneId: number, links: WeatherLinkDraft[]) {
    return this.api.put<WeatherLinks>(`/weather/zones/${zoneId}/links`, { links });
  }

  settings() {
    return this.api.get<WeatherSettings>('/weather/settings');
  }

  setSetting(name: string, value: number | null) {
    return this.api.put<Pick<WeatherSetting, 'name' | 'value' | 'default' | 'stored'>>(
      `/weather/settings/${name}`,
      { value },
    );
  }

  addCyclone(draft: CycloneDraft & { map: number; x: number; y: number }) {
    return this.api.post<Cyclone>('/weather/cyclones', draft);
  }

  setCyclone(id: number, field: string, value: number) {
    return this.api.put<Cyclone>(
      `/weather/cyclones/${id}?field=${field}&value=${value}`,
      null,
    );
  }

  removeCyclone(id: number) {
    return this.api.delete<{ removed: number }>(`/weather/cyclones/${id}`);
  }

  resetCyclones() {
    return this.api.post<{ cyclones: Cyclone[] }>('/weather/cyclones/reset');
  }
}
