import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../../core/api.service';

export type SpellFieldValue = string | number | null;
export type SpellFields = Record<string, SpellFieldValue>;

export interface WorkshopField {
  col: string;
  kind: 'text' | 'int' | 'float' | 'enum' | 'ref' | 'flags';
  label: string;
  hint?: string;
  enum?: string;
  ref?: string;
}

export interface WorkshopGroup {
  id: string;
  label: string;
  hint?: string;
  fields: WorkshopField[];
}

export interface WorkshopBlock {
  id: string;
  name: string;
  module: string;
  lo: number;
  hi: number;
  used: number;
  size: number;
  next_free: number | null;
}

export interface WorkshopMeta {
  enums: Record<string, Array<{ id: number; label: string }>>;
  refs: Record<string, Array<{ id: number; label: string }>>;
  groups: WorkshopGroup[];
  effect_fields: WorkshopField[];
  blocks: WorkshopBlock[];
  modules: Array<{ id: string; name: string }>;
}

export interface WorkshopSpell {
  id: number;
  name_ru: string;
  name_en: string;
  block?: string | null;
  block_name?: string;
  module: string;
  icon_texture?: string;
  /** По короткой строке на каждый занятый эффект - «что оно делает». */
  effects: string[];
  /** Шанс срабатывания, проценты; 0 - заклинание не процное. */
  proc_chance: number;
  duration_index: number;
}

export interface WorkshopPage {
  items: WorkshopSpell[];
  offset: number;
  total: number;
}

export interface WorkshopDetail {
  id: number;
  fields: SpellFields;
  block?: string | null;
  module: string;
  /** Выбранная в панели текстура; пустая у всего, что пришло из модулей. */
  icon_texture: string;
  /**
   * Та, что рисует клиент: по SpellIconID из DBC. Только для показа - обратно
   * в `spell_meta` не пишется, иначе панель записала бы её как выбор человека.
   */
  icon_resolved?: string;
  notes: string;
  author?: string;
  warnings?: string[];
}

export interface SpellSave {
  id: number;
  problems: Array<{ level: 'error' | 'warning'; text: string }>;
}

/** Spells written after the worldserver started are in the base, not in game. */
export interface PendingRestart {
  known: boolean;
  count: number;
  reason?: string;
}

@Injectable()
export class SpellWorkshopApi {
  private readonly api = inject(ApiService);

  catalog(): Observable<WorkshopMeta> {
    return this.api.get<WorkshopMeta>('/spells/catalog');
  }

  search(query: {
    q: string;
    block: string;
    module: string;
    school: string;
    effect: string;
    aura: string;
    procMin: string;
    procMax: string;
    offset: number;
    limit: number;
  }): Observable<WorkshopPage> {
    const params = new URLSearchParams();
    const filters: Record<string, string> = {
      q: query.q,
      block: query.block,
      module: query.module,
      school: query.school,
      effect: query.effect,
      aura: query.aura,
      proc_min: query.procMin,
      proc_max: query.procMax,
      offset: String(query.offset),
      limit: String(query.limit),
    };
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== '') params.set(key, value);
    });
    return this.api.get<WorkshopPage>(`/spells/page?${params}`);
  }

  detail(id: number): Observable<WorkshopDetail> {
    return this.api.get<WorkshopDetail>(`/spells/${id}`);
  }

  pendingRestart(): Observable<PendingRestart> {
    return this.api.get<PendingRestart>('/spells/pending-restart');
  }

  clone(id: number, block: string): Observable<WorkshopDetail> {
    return this.api.get<WorkshopDetail>(`/spells/clone/${id}?block=${encodeURIComponent(block)}`);
  }

  nextId(block: string): Observable<{ id: number; used: number }> {
    return this.api.get<{ id: number; used: number }>(
      `/spells/next-id?block=${encodeURIComponent(block)}`,
    );
  }

  create(payload: Omit<WorkshopDetail, 'warnings'>): Observable<SpellSave> {
    return this.api.post<SpellSave>('/spells', payload);
  }

  save(id: number, payload: Omit<WorkshopDetail, 'warnings' | 'id'>): Observable<SpellSave> {
    return this.api.put<SpellSave>(`/spells/${id}`, payload);
  }

  delete(id: number): Observable<{ ok: boolean }> {
    return this.api.delete<{ ok: boolean }>(`/spells/${id}`);
  }
}
