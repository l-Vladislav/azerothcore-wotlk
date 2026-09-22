import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../../core/auth.service';
import { ClientPatchApi, PatchStatus } from './client-patch.api';
import { Artefact, DeployApi } from '../deploy/deploy.api';
import { ToastService } from '../../../shared/ui/toast.service';

const healthLabels: Readonly<Record<string, string>> = {
  build_py: 'скрипт сборки',
  workdir: 'рабочий каталог',
  base_ready: 'база DBC',
  cdn: 'каталог CDN',
  stormlib: 'StormLib',
};

@Component({
  imports: [],
  providers: [ClientPatchApi, DeployApi],
  selector: 'app-client-patch-page',
  styleUrl: './client-patch.page.scss',
  templateUrl: './client-patch.page.html',
})
export class ClientPatchPage implements OnInit, OnDestroy {
  private readonly api = inject(ClientPatchApi);
  private readonly deployApi = inject(DeployApi);
  private readonly auth = inject(AuthService);
  private readonly toast = inject(ToastService);
  private refreshTimer: ReturnType<typeof setTimeout> | undefined;

  readonly status = signal<PatchStatus | null>(null);
  // Сырьё сборки: CSV, из которых собирается MPQ. Живёт здесь, а не на
  // «Выкатке», потому что это тот же шаг - и потому что собранный из
  // устаревших файлов патч выглядит удачным, а у игрока всё по-старому.
  readonly clientFiles = signal<Artefact[]>([]);
  readonly exporting = signal<string | null>(null);
  readonly loading = signal(true);
  readonly actionPending = signal(false);
  readonly fullLog = signal<string | null>(null);
  readonly canBuild = computed(() => this.auth.actor()?.role === 'owner');
  readonly disabled = computed(
    () =>
      !this.canBuild() ||
      this.actionPending() ||
      !this.status()?.reachable ||
      this.status()?.running,
  );

  async ngOnInit(): Promise<void> {
    await Promise.all([this.refresh(), this.loadFiles()]);
  }

  private async loadFiles(): Promise<void> {
    try {
      const result = await firstValueFrom(this.deployApi.artefacts('client'));
      this.clientFiles.set(result.artefacts);
    } catch {
      this.toast.show('Не удалось прочитать состояние клиентских файлов.', 'error');
    }
  }

  async exportArtefact(item: Artefact): Promise<void> {
    if (this.exporting()) return;
    this.exporting.set(item.key);
    try {
      await firstValueFrom(this.deployApi.export(item.endpoint));
      await this.loadFiles();
      this.toast.show(`${item.label}: выгружено.`, 'ok');
    } catch {
      this.toast.show(`${item.label}: выгрузить не удалось.`, 'error');
    } finally {
      this.exporting.set(null);
    }
  }

  exportTime(value: string | null): string {
    if (!value) return 'ни разу';
    const at = new Date(value.replace(' ', 'T'));
    return Number.isNaN(at.getTime()) ? value : at.toLocaleString('ru-RU');
  }

  /** «нет в клиенте: 3, устарело: 1» - или пусто, когда всё совпадает. */
  behind(item: Artefact): string {
    const pending = item.pending;
    if (!pending) return '';
    if (!pending.known) return pending.reason ?? 'сверить не удалось';
    const groups = pending.groups?.length
      ? pending.groups
      : [{ name: '', missing: pending.missing ?? 0, changed: pending.changed ?? 0, total: 0 }];
    const parts = groups
      .filter((group) => group.missing || group.changed)
      .map((group) => {
        const counts = [
          group.missing ? `нет ${group.missing}` : '',
          group.changed ? `устарело ${group.changed}` : '',
        ]
          .filter(Boolean)
          .join(', ');
        return group.name ? `${group.name.toLowerCase()}: ${counts}` : counts;
      });
    return parts.join(' · ');
  }

  ngOnDestroy(): void {
    clearTimeout(this.refreshTimer);
  }

  async refresh(): Promise<void> {
    clearTimeout(this.refreshTimer);
    try {
      const status = await firstValueFrom(this.api.status());
      this.status.set(status);
      this.fullLog.set(null);
      if (status.running) this.refreshTimer = setTimeout(() => void this.refresh(), 3000);
    } catch {
      this.toast.show('Не удалось получить состояние сборщика.', 'error');
    } finally {
      this.loading.set(false);
    }
  }

  async build(options: 'check' | 'local' | 'publish'): Promise<void> {
    if (this.disabled()) return;
    if (options === 'publish' && !confirm('Собрать патч и опубликовать его на CDN?')) return;

    const payload =
      options === 'check' ? { dry_run: true } : options === 'local' ? { no_publish: true } : {};
    await this.run(() => this.api.build(payload));
  }

  async bootstrap(): Promise<void> {
    if (this.disabled()) return;
    if (!confirm('Снять базу DBC заново? Текущая база сборщика будет перезаписана.')) return;
    await this.run(() => this.api.bootstrap());
  }

  async showFullLog(): Promise<void> {
    try {
      this.fullLog.set(await firstValueFrom(this.api.log()));
    } catch {
      this.toast.show('Не удалось загрузить лог сборки.', 'error');
    }
  }

  // Огонёк слева от состояния: тот же словарь, что у плиток «Обзора».
  dotClass(status: PatchStatus): string {
    if (!status.reachable) return 'is-offline';
    if (status.running) return 'is-busy';
    if (!status.finished) return 'is-maintenance';
    return status.code === 0 ? 'is-online' : 'is-away';
  }

  stateLabel(status: PatchStatus): string {
    if (!status.reachable) return 'Сборщик недоступен';
    if (status.running) return 'Идёт сборка';
    if (!status.finished) return 'Сборка ещё не запускалась';
    return status.code === 0
      ? 'Последняя сборка успешна'
      : `Сборка завершилась с кодом ${status.code}`;
  }

  missing(status: PatchStatus): string[] {
    return Object.entries(status.health ?? {})
      .filter(([, available]) => !available)
      .map(([key]) => healthLabels[key] ?? key);
  }

  formatTime(value?: string | null): string {
    if (!value) return '';
    const time = new Date(value);
    return Number.isNaN(time.getTime()) ? value : time.toLocaleString('ru-RU');
  }

  private async run(request: () => ReturnType<ClientPatchApi['build']>): Promise<void> {
    this.actionPending.set(true);
    try {
      this.status.set(await firstValueFrom(request()));
      await this.refresh();
    } catch {
      this.toast.show('Сборщик не принял команду. Проверьте его состояние и лог.', 'error');
    } finally {
      this.actionPending.set(false);
    }
  }
}
