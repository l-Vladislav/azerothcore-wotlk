import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../../core/auth.service';
import { DeployService } from '../../../core/deploy.service';
import { IconComponent } from '../../../shared/ui/icon.component';
import { ToastService } from '../../../shared/ui/toast.service';
import { AppliedCommand, Artefact, DeployApi, DeployTarget } from './deploy.api';

/**
 * Одно место для всего, что раньше было кнопками по страницам.
 *
 * Их было тринадцать на девяти страницах, и под одинаковой одеждой прятались
 * три разных дела: перечитать модуль в живом мире, перезапросить данные
 * страницы и записать файл на диск. Первое собрано здесь и считается само
 * (`app/apply.py`), второе оказалось не нужно - страницы и так перечитывают
 * себя после своих действий, третье лежит ниже, рядом со сборкой патча,
 * потому что это один конвейер.
 */
@Component({
  imports: [IconComponent],
  providers: [DeployApi],
  selector: 'app-deploy-page',
  styleUrl: './deploy.page.scss',
  templateUrl: './deploy.page.html',
})
export class DeployPage implements OnInit {
  private readonly api = inject(DeployApi);
  private readonly auth = inject(AuthService);
  private readonly deploy = inject(DeployService);
  private readonly toast = inject(ToastService);

  readonly loading = signal(true);
  readonly busy = signal<string | null>(null);
  readonly log = signal<AppliedCommand[]>([]);
  readonly artefacts = signal<Artefact[]>([]);

  readonly state = this.deploy.state;
  readonly waiting = computed(() => this.state()?.waiting ?? []);
  readonly manual = computed(() => this.state()?.manual ?? []);
  readonly isOwner = computed(() => this.auth.actor()?.role === 'owner');
  readonly canExport = this.isOwner;

  /** Модули, которые ждут, но требуют роли выше моей. */
  readonly blocked = computed(() =>
    this.waiting().filter((entry) => entry.role === 'owner' && !this.isOwner()),
  );

  readonly migrations = computed(() => this.artefacts().filter((a) => a.kind === 'sql'));

  async ngOnInit(): Promise<void> {
    await Promise.all([this.deploy.refresh(), this.loadArtefacts()]);
    this.loading.set(false);
  }

  private async loadArtefacts(): Promise<void> {
    try {
      const result = await firstValueFrom(this.api.artefacts('sql'));
      this.artefacts.set(result.artefacts);
    } catch {
      this.toast.show('Не удалось прочитать состояние выгрузок.', 'error');
    }
  }

  async apply(target = ''): Promise<void> {
    if (this.busy()) return;
    this.busy.set(target || 'all');
    try {
      const result = await firstValueFrom(this.api.apply(target));
      this.deploy.set(result.state);
      this.log.set([...result.applied, ...result.failed]);
      if (result.failed.length) {
        this.toast.show(`Не отозвались: ${result.failed.length}.`, 'error');
      } else if (result.applied.length) {
        this.toast.show(`Применено: ${result.applied.length}.`, 'ok');
      } else {
        this.toast.show('Применять нечего - мир уже в курсе.', 'ok');
      }
    } catch (error) {
      this.toast.show(this.errorText(error, 'Не удалось применить.'), 'error');
    } finally {
      this.busy.set(null);
    }
  }

  async exportArtefact(item: Artefact): Promise<void> {
    if (this.busy()) return;
    this.busy.set(item.key);
    try {
      await firstValueFrom(this.api.export(item.endpoint));
      await this.loadArtefacts();
      this.toast.show(`${item.label}: выгружено.`, 'ok');
    } catch (error) {
      this.toast.show(this.errorText(error, 'Не удалось выгрузить.'), 'error');
    } finally {
      this.busy.set(null);
    }
  }

  canApply(entry: DeployTarget): boolean {
    return entry.role !== 'owner' || this.isOwner();
  }

  /** Что именно выполнится: у добычи - по команде на каждую правленую таблицу. */
  commandText(entry: DeployTarget): string {
    const details = entry.details ?? [];
    if (!details.length) return entry.command;
    return details.map((detail) => entry.command.replace('{detail}', detail)).join(' · ');
  }

  time(value: string | null | undefined): string {
    if (!value) return 'ни разу';
    const at = new Date(value.replace(' ', 'T'));
    return Number.isNaN(at.getTime()) ? value : at.toLocaleString('ru-RU');
  }

  /** «правок после выгрузки: 3» - файл собирают целиком, сверяем по журналу. */
  behind(item: Artefact): string {
    const edits = item.edits;
    if (!item.written_at) return 'не выгружали ни разу';
    if (!edits?.count) return '';
    return `правок после выгрузки: ${edits.count}`;
  }

  size(bytes: number): string {
    if (!bytes) return '';
    if (bytes < 1024) return `${bytes} Б`;
    if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} КБ`;
    return `${(bytes / 1024 / 1024).toFixed(1)} МБ`;
  }

  private errorText(error: unknown, fallback: string): string {
    const detail = (error as { error?: { detail?: unknown } })?.error?.detail;
    return typeof detail === 'string' ? detail : fallback;
  }
}
