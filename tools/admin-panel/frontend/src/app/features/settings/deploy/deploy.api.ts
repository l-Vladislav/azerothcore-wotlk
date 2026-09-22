import { Injectable, inject } from '@angular/core';
import { ApiService } from '../../../core/api.service';

/** Модуль мира, который ждёт перечитки (или может её получить по просьбе). */
export interface DeployTarget {
  key: string;
  label: string;
  role: 'viewer' | 'editor' | 'owner';
  command: string;
  /** Только у ждущих: какие именно таблицы добычи правили. */
  details?: string[];
  by?: string;
  since?: string;
}

export interface DeployState {
  /** null - мир не спрашивали: ждать нечего. */
  soap: boolean | null;
  started_at: string | null;
  waiting: DeployTarget[];
  targets: DeployTarget[];
  manual: DeployTarget[];
}

export interface AppliedCommand {
  label: string;
  command: string;
  output?: string;
  error?: string;
}

export interface ApplyResult {
  ok: boolean;
  applied: AppliedCommand[];
  failed: AppliedCommand[];
  state: DeployState;
}

/** Сколько строк источника ещё не доехало до клиентского CSV. */
export interface PendingGroup {
  name: string;
  missing: number;
  changed: number;
  total: number;
}

export interface ClientPending {
  known: boolean;
  reason?: string;
  missing?: number;
  changed?: number;
  total?: number;
  groups?: PendingGroup[];
}

/** Правки области, легшие в журнал после того, как файл записали. */
export interface EditsSince {
  count: number;
  last: string | null;
}

/** Файл, который панель пишет на диск: миграция или CSV клиентского патча. */
export interface Artefact {
  key: string;
  label: string;
  kind: 'sql' | 'client';
  endpoint: string;
  path: string;
  written_at: string | null;
  size: number;
  /** У клиентских CSV - поимённая сверка с тем, что в базе. */
  pending?: ClientPending;
  /** У миграций - счёт правок по журналу: файл сверяют не построчно. */
  edits?: EditsSince;
}

@Injectable()
export class DeployApi {
  private readonly api = inject(ApiService);

  state() {
    return this.api.get<DeployState>('/apply');
  }

  apply(target = '') {
    return this.api.post<ApplyResult>(`/apply${target ? `?target=${target}` : ''}`);
  }

  artefacts(kind: '' | 'sql' | 'client' = '') {
    return this.api.get<{ artefacts: Artefact[] }>(`/exports${kind ? `?kind=${kind}` : ''}`);
  }

  /** Выгрузки живут в своих модулях; страница зовёт их по адресу из списка. */
  export(endpoint: string) {
    return this.api.post<Record<string, unknown>>(endpoint.replace(/^\/api/, ''));
  }
}
