import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '../../core/auth.service';

@Component({
  imports: [FormsModule],
  selector: 'app-login-page',
  styleUrl: './login.page.scss',
  templateUrl: './login.page.html',
})
export class LoginPage {
  login = '';
  password = '';
  token = '';
  readonly pending = signal(false);
  readonly error = signal<string | null>(null);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  private returnUrl(): string {
    const url = this.route.snapshot.queryParamMap.get('returnUrl');
    return url?.startsWith('/') && !url.startsWith('//') && !url.startsWith('/login') ? url : '/';
  }

  async submit(): Promise<void> {
    if (this.pending() || !this.login.trim() || !this.password) return;
    this.pending.set(true);
    this.error.set(null);
    try {
      await this.auth.login(this.login, this.password);
      await this.router.navigateByUrl(this.returnUrl());
    } catch {
      this.error.set('Не удалось войти. Проверьте имя пользователя и пароль.');
    } finally {
      this.pending.set(false);
    }
  }

  async submitToken(): Promise<void> {
    if (this.pending() || !this.token.trim()) return;
    this.pending.set(true);
    this.error.set(null);
    try {
      await this.auth.loginWithToken(this.token.trim());
      await this.router.navigateByUrl(this.returnUrl());
    } catch {
      this.error.set('Токен не подошёл или панель недоступна.');
    } finally {
      this.pending.set(false);
    }
  }
}
