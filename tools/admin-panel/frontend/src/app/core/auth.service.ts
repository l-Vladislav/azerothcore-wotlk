import { Injectable, computed, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { ApiService } from './api.service';

export type Role = 'viewer' | 'editor' | 'owner';

export interface Actor {
  id: number;
  login: string;
  role: Role;
}

interface AuthState {
  signed_in: boolean;
  actor: Actor | null;
  bootstrap: boolean;
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  readonly actor = signal<Actor | null>(null);
  readonly ready = signal(false);
  readonly signedIn = computed(() => this.actor() !== null);

  constructor(private readonly api: ApiService) {}

  async loadState(): Promise<AuthState> {
    const state = await firstValueFrom(this.api.get<AuthState>('/auth/state'));
    this.actor.set(state.actor);
    this.ready.set(true);
    return state;
  }

  async login(login: string, password: string): Promise<void> {
    const response = await firstValueFrom(
      this.api.post<{ actor: Actor }>('/auth/login', { login, password }),
    );
    this.actor.set(response.actor);
    this.ready.set(true);
  }

  async loginWithToken(token: string): Promise<void> {
    localStorage.setItem('adminToken', token);
    try {
      const state = await this.loadState();
      if (!state.signed_in) throw new Error('Token rejected.');
    } catch (error) {
      localStorage.removeItem('adminToken');
      throw error;
    }
  }

  adoptActor(actor: Actor): void {
    this.actor.set(actor);
    this.ready.set(true);
  }

  /** Сессия кончилась на стороне сервера: помним об этом, но не ходим к нему. */
  forget(): void {
    this.actor.set(null);
    this.ready.set(true);
  }

  async logout(): Promise<void> {
    await firstValueFrom(this.api.post('/auth/logout'));
    localStorage.removeItem('adminToken');
    this.actor.set(null);
  }
}
