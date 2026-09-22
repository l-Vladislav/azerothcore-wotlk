import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Observable, firstValueFrom } from 'rxjs';
import { AuthService } from '../../../core/auth.service';
import { Invite, PanelUser, RoleOption, UserRole, UsersApi } from './users.api';
import { ForgeSelectDirective } from '../../../shared/ui/forge-select.directive';
import { IconComponent } from '../../../shared/ui/icon.component';
import { TablePagerComponent } from '../../../shared/data/table-pager.component';
import { ToastService } from '../../../shared/ui/toast.service';

/** Порядок состояний ссылки - в том же смысле, в каком их читает человек. */
const inviteRank: Readonly<Record<Invite['state'], number>> = {
  live: 0,
  spent: 1,
  expired: 2,
  revoked: 3,
};

const roleHelp: Readonly<Record<UserRole, string>> = {
  viewer: 'Читает данные и работает с доской: создаёт, комментирует и переносит карточки.',
  editor: 'Плюс редакторы модулей. Правки отправляются на PTR.',
  owner: 'Плюс экспорт, мастерская заклинаний, клиентский патч и управление доступом.',
};

@Component({
  imports: [FormsModule, ForgeSelectDirective, IconComponent, TablePagerComponent],
  providers: [UsersApi],
  selector: 'app-users-page',
  styleUrl: './users.page.scss',
  templateUrl: './users.page.html',
  host: { '(document:keydown.escape)': 'closeInvite()' },
})
export class UsersPage {
  private readonly api = inject(UsersApi);
  private readonly auth = inject(AuthService);
  private readonly toast = inject(ToastService);

  readonly roles = signal<readonly RoleOption[]>([]);
  readonly users = signal<readonly PanelUser[]>([]);
  readonly invites = signal<readonly Invite[]>([]);
  readonly loading = signal(true);
  readonly pending = signal(false);
  readonly inviteOpen = signal(false);
  readonly issuedInvite = signal<Invite | null>(null);

  // --- таблицы -------------------------------------------------------------
  //
  // Обе таблицы страницы ведут себя как таблица с листа 8 стайлгайда (её
  // живой образец - на витрине кита): заголовок сортирует, снизу подпись
  // «показано столько-то из стольких» и выбор строк на странице. Сортировка
  // и листание идут ЗДЕСЬ, а не в запросе: людей и ссылок десятки, и гонять
  // за ними сервер незачем.
  readonly userColumns = [
    { id: 'who', label: 'Кто' },
    { id: 'role', label: 'Роль' },
    { id: 'state', label: 'Состояние' },
    { id: 'seen', label: 'Был' },
    { id: 'sessions', label: 'Сессий' },
    { id: 'invited', label: 'Позвал' },
  ];
  readonly inviteColumns = [
    { id: 'id', label: '#' },
    { id: 'role', label: 'Роль' },
    { id: 'note', label: 'Подпись' },
    { id: 'state', label: 'Состояние' },
    { id: 'uses', label: 'Использований' },
    { id: 'expires', label: 'Годна до' },
    { id: 'author', label: 'Выдал' },
  ];
  readonly userSort = signal({ by: 'who', down: false });
  readonly userPage = signal(1);
  /** Размеры страницы этих таблиц: профилей и приглашений сотнями не бывает. */
  readonly pageSizes = [10, 25, 50];
  readonly userPerPage = signal(10);
  readonly inviteSort = signal({ by: 'id', down: true });
  readonly invitePage = signal(1);
  readonly invitePerPage = signal(10);

  readonly sortedUsers = computed(() =>
    this.ordered(this.users(), this.userSort(), (user, by) => this.userKey(user, by)),
  );
  readonly shownUsers = computed(() =>
    this.slice(this.sortedUsers(), this.userPage(), this.userPerPage()),
  );

  readonly sortedInvites = computed(() =>
    this.ordered(this.invites(), this.inviteSort(), (invite, by) => this.inviteKey(invite, by)),
  );
  readonly shownInvites = computed(() =>
    this.slice(this.sortedInvites(), this.invitePage(), this.invitePerPage()),
  );

  invite = this.emptyInvite();

  constructor() {
    void this.refresh();
  }

  roleHelp(role: UserRole): string {
    return roleHelp[role];
  }

  activeCount(role: UserRole): number {
    return this.users().filter((user) => user.role === role && !user.disabled).length;
  }

  liveInvites(): number {
    return this.invites().filter((invite) => invite.state === 'live').length;
  }

  isCurrentUser(user: PanelUser): boolean {
    return user.id === this.auth.actor()?.id;
  }

  displayName(user: PanelUser): string {
    return user.name || user.login;
  }

  formatDate(value: string | null): string {
    if (!value) return '—';
    const date = new Date(value.replace(' ', 'T'));
    return Number.isNaN(date.getTime()) ? value.slice(0, 16) : date.toLocaleString('ru-RU');
  }

  inviteState(invite: Invite): string {
    return {
      live: 'можно использовать',
      spent: 'использована',
      expired: 'срок истёк',
      revoked: 'отозвана',
    }[invite.state];
  }

  // Огонёк рядом с состоянием ссылки - тот же словарь, что у профилей.
  inviteDot(invite: Invite): string {
    return {
      live: 'is-online',
      spent: 'is-maintenance',
      expired: 'is-away',
      revoked: 'is-offline',
    }[invite.state];
  }

  openInvite(): void {
    this.invite = this.emptyInvite();
    this.inviteOpen.set(true);
  }

  closeInvite(): void {
    if (!this.pending()) this.inviteOpen.set(false);
  }

  async refresh(): Promise<void> {
    this.pending.set(true);
    try {
      const [state, users, invites] = await Promise.all([
        firstValueFrom(this.api.state()),
        firstValueFrom(this.api.users()),
        firstValueFrom(this.api.invites()),
      ]);
      this.roles.set(state.roles);
      this.users.set(users);
      this.invites.set(invites);
    } catch (error) {
      this.toast.show(this.errorText(error, 'Не удалось загрузить управление доступом.'), 'error');
    } finally {
      this.pending.set(false);
      this.loading.set(false);
    }
  }

  async changeRole(user: PanelUser, role: UserRole): Promise<void> {
    if (this.isCurrentUser(user) || user.role === role) return;
    await this.run(
      () => this.api.updateUser(user.id, { role }),
      `Роль «${this.displayName(user)}» изменена.`,
    );
  }

  async toggleUser(user: PanelUser): Promise<void> {
    if (this.isCurrentUser(user)) return;
    const action = user.disabled ? 'включить' : 'отключить';
    if (
      !confirm(`${action[0].toUpperCase()}${action.slice(1)} профиль «${this.displayName(user)}»?`)
    )
      return;
    await this.run(
      () => this.api.updateUser(user.id, { disabled: !user.disabled }),
      user.disabled ? 'Профиль включён.' : 'Профиль отключён.',
    );
  }

  async closeSessions(user: PanelUser): Promise<void> {
    if (!confirm(`Закрыть все сессии пользователя «${this.displayName(user)}»?`)) return;
    await this.run(
      () => this.api.closeSessions(user.id),
      `Сессии «${this.displayName(user)}» закрыты.`,
    );
  }

  async deleteUser(user: PanelUser): Promise<void> {
    if (!confirm(`Удалить профиль «${this.displayName(user)}»? Это действие нельзя отменить.`))
      return;
    await this.run(
      () => this.api.deleteUser(user.id),
      `Профиль «${this.displayName(user)}» удалён.`,
    );
  }

  async createInvite(): Promise<void> {
    if (this.pending()) return;
    this.pending.set(true);
    try {
      const created = await firstValueFrom(this.api.createInvite(this.invite));
      this.issuedInvite.set({ ...created, url: this.angularInviteUrl(created.url) });
      this.inviteOpen.set(false);
      this.toast.show('Одноразовая ссылка создана. Скопируйте её до закрытия окна.');
      await this.refresh();
    } catch (error) {
      this.toast.show(this.errorText(error, 'Не удалось создать приглашение.'), 'error');
    } finally {
      this.pending.set(false);
    }
  }

  async revokeInvite(invite: Invite): Promise<void> {
    if (!confirm(`Отозвать приглашение #${invite.id}?`)) return;
    await this.run(() => this.api.revokeInvite(invite.id), 'Приглашение отозвано.');
  }

  async copyInvite(): Promise<void> {
    const link = this.issuedInvite()?.url;
    if (!link) return;
    try {
      await navigator.clipboard.writeText(link);
      this.toast.show('Ссылка скопирована.');
    } catch {
      this.toast.show('Не удалось скопировать ссылку. Выделите её и скопируйте вручную.', 'error');
    }
  }

  closeIssuedInvite(): void {
    this.issuedInvite.set(null);
  }

  sortUsers(column: string): void {
    this.userSort.update((now) =>
      now.by === column ? { by: column, down: !now.down } : { by: column, down: false },
    );
    this.userPage.set(1);
  }

  sortInvites(column: string): void {
    this.inviteSort.update((now) =>
      now.by === column ? { by: column, down: !now.down } : { by: column, down: false },
    );
    this.invitePage.set(1);
  }

  /** Стрелка у заголовка: куда сортируем сейчас и чем можно сортировать. */
  /**
   * Имя значка, а не символ: «▲ ▼ ⇅» рисует системный шрифт, и в шапке
   * таблицы они выходили разного веса. Тон `plain` - потому что стрелка на
   * листе 8 стальная (#9bb8ce) и белая у активной колонки, а не золотая.
   */
  arrow(sort: { by: string; down: boolean }, column: string): string {
    if (sort.by !== column) return 'sort';
    return sort.down ? 'caret' : 'caret-up';
  }

  setUserPerPage(value: number): void {
    this.userPerPage.set(value);
    this.userPage.set(1);
  }

  setInvitePerPage(value: number): void {
    this.invitePerPage.set(value);
    this.invitePage.set(1);
  }

  private ordered<T>(
    rows: readonly T[],
    sort: { by: string; down: boolean },
    key: (row: T, by: string) => string | number,
  ): readonly T[] {
    const sorted = [...rows].sort((left, right) => {
      const a = key(left, sort.by);
      const b = key(right, sort.by);
      if (a === b) return 0;
      return a < b ? -1 : 1;
    });
    return sort.down ? sorted.reverse() : sorted;
  }

  // Страница зажата в пределах списка: после удаления последней строки на
  // третьей странице третьей страницы больше нет, а сигнал о ней ещё помнит.
  private slice<T>(rows: readonly T[], page: number, perPage: number): readonly T[] {
    const last = Math.max(1, Math.ceil(rows.length / perPage));
    const safe = Math.min(Math.max(1, page), last);
    return rows.slice((safe - 1) * perPage, safe * perPage);
  }

  private userKey(user: PanelUser, by: string): string | number {
    switch (by) {
      case 'who':
        return this.displayName(user).toLowerCase();
      case 'role':
        return this.roles().findIndex((role) => role.id === user.role);
      case 'state':
        return user.disabled ? 1 : 0;
      case 'seen':
        return user.last_seen ?? '';
      case 'sessions':
        return user.sessions;
      case 'invited':
        return (user.invited_by || '').toLowerCase();
      default:
        return user.id;
    }
  }

  private inviteKey(invite: Invite, by: string): string | number {
    switch (by) {
      case 'role':
        return this.roles().findIndex((role) => role.id === invite.role);
      case 'note':
        return (invite.note || '').toLowerCase();
      case 'state':
        return inviteRank[invite.state];
      case 'uses':
        return invite.uses;
      case 'expires':
        return invite.expires_at ?? '';
      case 'author':
        return (invite.created_by || '').toLowerCase();
      default:
        return invite.id;
    }
  }

  private async run(request: () => Observable<unknown>, notice: string): Promise<void> {
    if (this.pending()) return;
    this.pending.set(true);
    try {
      await firstValueFrom(request());
      this.toast.show(notice);
      await this.refresh();
    } catch (error) {
      this.toast.show(this.errorText(error, 'Операция не выполнена.'), 'error');
    } finally {
      this.pending.set(false);
    }
  }

  private emptyInvite(): { role: UserRole; note: string; expires_hours: number; max_uses: number } {
    return { role: 'viewer', note: '', expires_hours: 72, max_uses: 1 };
  }

  private angularInviteUrl(url?: string): string | undefined {
    if (!url) return undefined;
    const invite = new URL(url, window.location.origin);
    invite.pathname = '/join';
    invite.search = '';
    invite.protocol = window.location.protocol;
    invite.host = window.location.host;
    return invite.toString();
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
