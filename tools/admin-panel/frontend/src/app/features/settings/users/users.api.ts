import { Injectable, inject } from '@angular/core';
import { ApiService } from '../../../core/api.service';

export type UserRole = 'viewer' | 'editor' | 'owner';

export interface RoleOption {
  id: UserRole;
  label: string;
}

export interface PanelUser {
  id: number;
  login: string;
  name: string;
  role: UserRole;
  disabled: boolean;
  invited_by: string;
  created_at: string;
  last_seen: string | null;
  sessions: number;
}

export interface Invite {
  id: number;
  role: UserRole;
  note: string;
  created_by: string;
  created_at: string;
  expires_at: string | null;
  max_uses: number;
  uses: number;
  state: 'live' | 'spent' | 'expired' | 'revoked';
  url?: string;
}

interface AuthState {
  roles: RoleOption[];
}

@Injectable()
export class UsersApi {
  private readonly api = inject(ApiService);

  state() {
    return this.api.get<AuthState>('/auth/state');
  }

  users() {
    return this.api.get<PanelUser[]>('/users');
  }

  invites() {
    return this.api.get<Invite[]>('/invites');
  }

  updateUser(id: number, changes: Partial<Pick<PanelUser, 'role' | 'disabled'>>) {
    return this.api.patch<PanelUser>(`/users/${id}`, changes);
  }

  deleteUser(id: number) {
    return this.api.delete<PanelUser>(`/users/${id}`);
  }

  closeSessions(id: number) {
    return this.api.post<{ closed: number }>(`/users/${id}/sessions/close`);
  }

  createInvite(payload: { role: UserRole; note: string; expires_hours: number; max_uses: number }) {
    return this.api.post<Invite>('/invites', payload);
  }

  revokeInvite(id: number) {
    return this.api.post<{ ok: boolean }>(`/invites/${id}/revoke`);
  }
}
