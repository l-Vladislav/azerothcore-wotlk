import { Injectable, inject } from '@angular/core';
import { ApiService } from '../../core/api.service';

export interface ZoneSummary {
  zone_id: number;
  name: string;
  global: boolean;
  buffs: number;
  debuffs: number;
  disabled: number;
}

export interface EffectSpell {
  spell_id: number;
  name_ru: string;
  description_ru: string;
  icon_texture: string;
  in_spell_dbc: boolean;
  used_by_rules: number;
  kind: number;
}

export interface EffectRule {
  spell_id: number;
  trigger_type: number;
  time_flag: number;
  enabled: boolean;
  spell?: EffectSpell;
}

export interface ZoneRules {
  zone_id: number;
  name: string;
  global: boolean;
  buffs: EffectRule[];
  debuffs: EffectRule[];
}

export interface ValidationProblem {
  level: 'error' | 'warning';
  message: string;
}

export interface SaveResult {
  saved: number;
  problems: ValidationProblem[];
  reloaded: boolean;
  reload_output: string | null;
}

@Injectable()
export class EnvironmentApi {
  private readonly api = inject(ApiService);

  zones() {
    return this.api.get<ZoneSummary[]>('/zones');
  }

  searchZones(query: string) {
    return this.api.get<Pick<ZoneSummary, 'zone_id' | 'name'>[]>(
      `/zones/search?q=${encodeURIComponent(query)}`,
    );
  }

  zone(id: number) {
    return this.api.get<ZoneRules>(`/zones/${id}`);
  }

  meta() {
    return this.api.get<{ icon_base_url: string }>('/envfx/meta');
  }

  spells() {
    return this.api.get<EffectSpell[]>('/envfx/spells');
  }

  save(id: number, rules: Pick<ZoneRules, 'buffs' | 'debuffs'>, force = false) {
    return this.api.put<SaveResult>(`/zones/${id}?force=${force ? 1 : 0}`, rules);
  }

  delete(id: number) {
    return this.api.delete<{ deleted: number }>(`/zones/${id}`);
  }

  reload() {
    return this.api.post<{ ok: boolean; output: string }>('/reload');
  }
}
