import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../../core/api.service';
import { CatalogPage } from '../../../shared/data/readonly-catalog';

export interface Facet {
  id: string | number;
  label: string;
  count?: number;
}
export interface SpellQuery {
  q: string;
  source: string;
  school: string;
  family: string;
  effect: string;
  aura: string;
  module: string;
  block: string;
  levelMin: string;
  levelMax: string;
  offset: number;
  limit: number;
}
export interface SpellResult {
  id: number;
  name: string;
  rank?: string;
  icon?: string;
  schools: string[];
  family_name?: string;
  level?: number;
  source: 'dbc' | 'override' | 'custom';
}
export interface SpellEffect {
  index: number;
  effect_name: string;
  aura_name?: string;
  amount?: string;
  period?: string;
  target_a?: string;
  target_b?: string;
  radius?: string;
  mechanic?: string;
  trigger?: number;
  trigger_name?: string;
}
export interface SpellDetail {
  id: number;
  name: string;
  rank?: string;
  icon?: string;
  source: 'dbc' | 'override' | 'custom';
  name_en?: string;
  description?: string;
  aura_description?: string;
  notes?: string;
  source_label: string;
  editable: boolean;
  block_name?: string;
  module?: string;
  icon_id?: number;
  summary: Array<{ label: string; value: string | number; raw?: string | number }>;
  effects: SpellEffect[];
  overrides: Array<{ column: string; dbc: string | number; db: string | number }>;
  attributes: Array<{
    column: string;
    hex: string;
    flags: Array<{ label: string; const: string; bit: number }>;
  }>;
  skills: Array<{ skill: string; skill_id: number }>;
  triggered_by: Array<{ id: number; name: string }>;
  raw: Record<string, unknown>;
}
export interface SpellCatalogMeta {
  available: boolean;
  reason?: string;
  total: number;
  icon_base_url?: string;
  local_icons?: boolean;
  any_block?: string;
  sources: Facet[];
  modules: Facet[];
  blocks: Array<Facet & { module?: string; lo: number; hi: number; used: number }>;
  schools: Facet[];
  families: Facet[];
  effects: Facet[];
  auras: Facet[];
}

@Injectable()
export class SpellCatalogApi {
  private readonly api = inject(ApiService);

  meta(): Observable<SpellCatalogMeta> {
    return this.api.get<SpellCatalogMeta>('/dex/meta');
  }
  detail(id: number): Observable<SpellDetail> {
    return this.api.get<SpellDetail>(`/dex/spells/${id}`);
  }

  search(query: SpellQuery): Observable<CatalogPage<SpellResult>> {
    const params = new URLSearchParams();
    const values: Record<string, string> = {
      q: query.q,
      source: query.source,
      school: query.school,
      family: query.family,
      effect: query.effect,
      aura: query.aura,
      module: query.module,
      block: query.block,
      level_min: query.levelMin,
      level_max: query.levelMax,
      offset: String(query.offset),
      limit: String(query.limit),
    };
    Object.entries(values).forEach(([key, value]) => {
      if (value) params.set(key, value);
    });
    return this.api.get<CatalogPage<SpellResult>>(`/dex/search?${params}`);
  }
}
