import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { IconComponent } from '../../shared/ui/icon.component';
import { ApiService } from '../../core/api.service';
import { AuthService } from '../../core/auth.service';
import { FeatureNavigationRegistry, groupItems } from '../../core/navigation/feature-navigation';
import { ToastService } from '../../shared/ui/toast.service';
// Только тип: в сборке он стирается, и «Обзор» не тянет за собой кусок
// страницы патча.
import type { PatchStatus } from '../settings/client-patch/client-patch.api';

interface Health {
  schema: string;
  db: { ok: boolean; rules?: number; error?: string };
  soap: { ok: boolean; host?: string; error?: string };
  board: { ok: boolean; open?: number; total?: number; error?: string };
  zones_known: number;
  files_ok: boolean;
  file_problems: string[];
}

@Component({
  imports: [RouterLink, IconComponent],
  selector: 'app-dashboard-page',
  styleUrl: './dashboard.page.scss',
  templateUrl: './dashboard.page.html',
})
export class DashboardPage implements OnInit {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);
  private readonly navigation = inject(FeatureNavigationRegistry);
  /**
   * Карта строится из того же списка, что верхнее меню и боковая панель, и
   * теми же группами: страницы раздела «Мир» приходят от разных модулей.
   */
  readonly sections = computed(() =>
    this.navigation
      .all()
      .filter((section) => !section.ownerOnly || this.auth.actor()?.role === 'owner')
      .map((section) => ({
        ...section,
        groups: groupItems(section.items),
      })),
  );
  readonly health = signal<Health | null>(null);
  readonly patch = signal<PatchStatus | null>(null);
  readonly error = signal<string | null>(null);
  readonly loading = signal(true);

  /**
   * CDN в порядке, когда сборщик задан, отвечает и видит каталог, в который
   * кладёт то, что качают игроки. Пишет туда не панель, а `ac-patch-builder`
   * (см. `app/patch.py`), поэтому и состояние спрашиваем у него.
   */
  readonly cdnOk = computed(() => {
    const state = this.patch();
    return !!state?.configured && !!state.reachable && state.health?.cdn !== false;
  });

  readonly cdnState = computed(() => {
    const state = this.patch();
    if (!state) return 'Неизвестно';
    if (!state.configured) return 'Не настроен';
    if (!state.reachable) return 'Недоступен';
    if (state.running) return 'Идёт сборка';
    return state.health?.cdn === false ? 'Нет каталога' : 'Готов';
  });

  readonly cdnHint = computed(() => {
    const state = this.patch();
    if (!state) return '—';
    if (!state.configured) return 'Сборщик патча не задан';
    if (!state.reachable) return state.error ?? 'Сборщик не отвечает';
    if (state.health?.cdn === false) return 'Нет доступа к launcher/cdn';
    if (state.running) return state.command ?? 'Сборка выполняется';
    if (state.finished)
      return state.code === 0 ? 'Последняя сборка удалась' : 'Последняя сборка с ошибкой';
    return 'Сборщик на связи';
  });

  /** Самоцвет состояния из набора: зелёный на связи, красный - нет. */
  dotClass(ok: boolean): string {
    return 'forge-dot ' + (ok ? 'is-online' : 'is-offline');
  }

  constructor() {
    // Сообщения об удаче и отказе - всплывающими плашками.
    this.toast.announce(this.error, 'error');
  }

  async ngOnInit(): Promise<void> {
    try {
      this.health.set((await this.api.get<Health>('/health').toPromise()) ?? null);
    } catch {
      this.error.set('Не удалось получить данные панели. Проверьте соединение с API.');
    } finally {
      this.loading.set(false);
    }

    // Отдельно и молча: сборщик патча живёт в своём контейнере, и его
    // молчание - повод показать плитку красной, а не уронить всю страницу.
    try {
      this.patch.set((await this.api.get<PatchStatus>('/patch/status').toPromise()) ?? null);
    } catch {
      this.patch.set({ configured: true, reachable: false, error: 'Сборщик не отвечает' });
    }
  }
}
