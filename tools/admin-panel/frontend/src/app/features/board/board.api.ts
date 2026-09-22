import { Injectable, inject } from '@angular/core';
import { ApiService } from '../../core/api.service';

export type BoardKind = 'bug' | 'feature' | 'task';
export type BoardStatus = 'backlog' | 'todo' | 'doing' | 'review' | 'done';

export interface BoardModule {
  id: string;
  name: string;
}

export interface BoardMeta {
  kinds: BoardKind[];
  statuses: BoardStatus[];
  modules: BoardModule[];
}

export interface BoardComment {
  id: number;
  author: string;
  body: string;
  created_at: string;
}

export interface BoardCard {
  id: number;
  kind: BoardKind;
  status: BoardStatus;
  priority: number;
  title: string;
  body: string;
  module: string;
  tags: string[];
  author: string;
  assignee: string;
  archived: boolean;
  created_at: string;
  updated_at: string;
  comments: number | BoardComment[];
}

export interface BoardCardInput {
  kind: BoardKind;
  status: BoardStatus;
  priority: number;
  title: string;
  body: string;
  module: string;
  tags: string[];
  assignee: string;
}

export interface BoardFilters {
  q?: string;
  module?: string;
  kind?: string;
  archived?: boolean;
}

@Injectable()
export class BoardApi {
  private readonly api = inject(ApiService);

  meta() {
    return this.api.get<BoardMeta>('/board/meta');
  }

  cards(filters: BoardFilters) {
    const params = new URLSearchParams();
    if (filters.q) params.set('q', filters.q);
    if (filters.module) params.set('module', filters.module);
    if (filters.kind) params.set('kind', filters.kind);
    if (filters.archived) params.set('archived', 'true');
    const suffix = params.size ? `?${params}` : '';
    return this.api.get<BoardCard[]>(`/board/cards${suffix}`);
  }

  card(id: number) {
    return this.api.get<BoardCard>(`/board/cards/${id}`);
  }

  create(payload: BoardCardInput) {
    return this.api.post<BoardCard>('/board/cards', payload);
  }

  update(id: number, payload: BoardCardInput) {
    return this.api.patch<BoardCard>(`/board/cards/${id}`, payload);
  }

  move(id: number, status: BoardStatus, position: number) {
    return this.api.post<BoardCard[]>(`/board/cards/${id}/move`, { status, position });
  }

  archive(id: number) {
    return this.api.delete<{ ok: boolean }>(`/board/cards/${id}`);
  }

  restore(id: number) {
    return this.api.post<BoardCard>(`/board/cards/${id}/restore`);
  }

  addComment(id: number, body: string) {
    return this.api.post<BoardCard>(`/board/cards/${id}/comments`, { body });
  }
}
