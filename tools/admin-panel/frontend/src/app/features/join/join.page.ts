import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { Actor, AuthService, Role } from '../../core/auth.service';
import { ApiService } from '../../core/api.service';

interface InviteInfo {
  role: Role;
  role_label: string;
  note: string;
}

@Component({
  imports: [FormsModule],
  selector: 'app-join-page',
  styleUrl: './join.page.scss',
  templateUrl: './join.page.html',
})
export class JoinPage implements OnInit {
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly token = decodeURIComponent(window.location.hash.slice(1));

  readonly invite = signal<InviteInfo | null>(null);
  readonly loading = signal(true);
  readonly pending = signal(false);
  readonly error = signal<string | null>(null);
  readonly unavailable = signal<string | null>(null);

  login = '';
  name = '';
  password = '';
  passwordRepeat = '';

  async ngOnInit(): Promise<void> {
    if (!this.token) {
      this.unavailable.set(
        'В ссылке нет приглашения. Скопируйте её целиком, вместе с частью после решётки.',
      );
      this.loading.set(false);
      return;
    }
    try {
      this.invite.set(
        await firstValueFrom(
          this.api.get<InviteInfo>(`/auth/invite?token=${encodeURIComponent(this.token)}`),
        ),
      );
    } catch (error) {
      this.unavailable.set(this.errorText(error, 'Не удалось проверить приглашение.'));
    } finally {
      this.loading.set(false);
    }
  }

  async submit(): Promise<void> {
    if (this.pending()) return;
    if (this.password !== this.passwordRepeat) {
      this.error.set('Пароли не совпадают.');
      return;
    }
    this.pending.set(true);
    this.error.set(null);
    try {
      const response = await firstValueFrom(
        this.api.post<{ actor: Actor }>('/auth/join', {
          token: this.token,
          login: this.login.trim(),
          name: this.name.trim(),
          password: this.password,
        }),
      );
      history.replaceState(null, '', '/join');
      this.auth.adoptActor(response.actor);
      await this.router.navigateByUrl('/');
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось создать профиль.'));
    } finally {
      this.pending.set(false);
    }
  }

  private errorText(error: unknown, fallback: string): string {
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
