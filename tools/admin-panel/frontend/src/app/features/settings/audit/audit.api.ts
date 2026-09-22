import { Injectable, inject } from '@angular/core';
import { ApiService } from '../../../core/api.service';

export interface AuditArea {
  id: string;
  label: string;
}

export interface AuditActor {
  actor_login: string;
  actor_name: string;
  n: number;
}

export interface AuditMeta {
  areas: AuditArea[];
  actors: AuditActor[];
  stats: { total: number; last_day: number };
}

export interface AuditEntry {
  id: number;
  at: string;
  actor_login: string;
  actor_name: string;
  actor_role: string;
  area: string;
  area_label: string;
  target: string;
  summary: string;
  method: string;
  path: string;
  payload: string | null;
  status: number;
  ok: boolean;
}

export interface AuditFilters {
  area: string;
  actor: string;
  q: string;
  failures: boolean;
  beforeId: number;
}

@Injectable()
export class AuditApi {
  private readonly api = inject(ApiService);

  meta() {
    return this.api.get<AuditMeta>('/audit/meta');
  }

  entries(filters: AuditFilters, limit = 100) {
    const params = new URLSearchParams({ limit: String(limit) });
    if (filters.area) params.set('area', filters.area);
    if (filters.actor) params.set('actor', filters.actor);
    if (filters.q) params.set('q', filters.q);
    if (filters.failures) params.set('failures', 'true');
    if (filters.beforeId) params.set('before_id', String(filters.beforeId));
    return this.api.get<AuditEntry[]>(`/audit?${params}`);
  }
}
