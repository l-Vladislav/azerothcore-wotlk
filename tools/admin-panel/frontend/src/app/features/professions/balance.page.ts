import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { ToastService } from '../../shared/ui/toast.service';
import { Balance, IlvlRow, ProfessionsApi, ProfessionsMeta, SettingRow } from './professions.api';
import { apiError } from './professions.model';

/** Точки кривой, по которым видно, во что складываются числа модуля. */
const GAPS = [100, 50, 0, -50, -100, -200];

/**
 * Баланс ковки: качество изделия, требуемый уровень, кривая успеха и числа
 * модуля.
 *
 * Единственная страница профессий, где правка уезжает НЕ построчно, а куском:
 * качества, веса и уровни проверяются друг относительно друга (дыры между
 * ступенями, нулевые веса), и строка, сохранённая сама по себе, прошла бы
 * проверку, которой на самом деле не проходит.
 */
@Component({
  imports: [FormsModule],
  providers: [ProfessionsApi],
  selector: 'app-professions-balance-page',
  styleUrl: './balance.page.scss',
  templateUrl: './balance.page.html',
})
export class ProfessionsBalancePage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);
  readonly auth = inject(AuthService);

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly balance = signal<Balance>({ qualities: [], chances: {} });
  readonly levels = signal<IlvlRow[]>([]);
  readonly settings = signal<SettingRow[]>([]);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);
  /** Что тронули в «Числах модуля»: шлём только это, а не весь список. */
  readonly changed = signal<Record<string, string>>({});

  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');

  /** Сумма весов: ноль значит, что ковка не даст ничего. */
  readonly weightSum = computed(() =>
    this.balance().qualities.reduce(
      (sum, tier) => sum + (this.balance().chances[String(tier.quality)] || 0),
      0,
    ),
  );

  readonly curve = computed(() => {
    const cfg: Record<string, number> = {};
    for (const row of this.settings()) cfg[row.name] = parseInt(row.value, 10) || 0;
    return GAPS.map((gap) => {
      const raw = (cfg['base_chance'] || 75) + gap * (cfg['chance_step'] || 1);
      return { gap, chance: Math.max(cfg['fail_floor'] || 10, Math.min(100, raw)) };
    });
  });

  constructor() {
    this.toast.announce(this.error, 'error');
    this.toast.announce(this.notice);
    void this.load();
  }

  async load(): Promise<void> {
    this.loading.set(true);
    try {
      const meta = await firstValueFrom(this.api.meta());
      this.meta.set(meta);
      if (meta.available) await this.reload();
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось загрузить баланс.'));
    } finally {
      this.loading.set(false);
    }
  }

  private async reload(): Promise<void> {
    const [balance, levels, settings] = await Promise.all([
      firstValueFrom(this.api.balance()),
      firstValueFrom(this.api.ilvlLevels()),
      firstValueFrom(this.api.settings()),
    ]);
    this.balance.set({
      qualities: balance.qualities.map((tier) => ({ ...tier })),
      chances: { ...balance.chances },
    });
    this.levels.set(levels.rows.map((row) => ({ ...row })));
    this.settings.set(settings.settings);
    this.changed.set({});
  }

  // --- качество -------------------------------------------------------------

  setQuality(quality: number, patch: { name_ru?: string; slots?: number }): void {
    this.balance.update((balance) => ({
      ...balance,
      qualities: balance.qualities.map((tier) =>
        tier.quality === quality ? { ...tier, ...patch } : tier,
      ),
    }));
  }

  setWeight(quality: number, weight: number): void {
    this.balance.update((balance) => ({
      ...balance,
      chances: { ...balance.chances, [String(quality)]: Math.max(0, weight) },
    }));
  }

  weight(quality: number): number {
    return this.balance().chances[String(quality)] || 0;
  }

  async saveBalance(): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    this.busy.set(true);
    try {
      await firstValueFrom(this.api.saveBalance(this.balance()));
      this.notice.set('Баланс сохранён.');
    } catch (error) {
      this.error.set(apiError(error, 'Баланс сохранить не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }

  // --- уровни ---------------------------------------------------------------

  setLevel(index: number, patch: Partial<IlvlRow>): void {
    this.levels.update((rows) =>
      rows.map((row, at) => (at === index ? { ...row, ...patch } : row)),
    );
  }

  addLevel(): void {
    this.levels.update((rows) => {
      const last = rows[rows.length - 1];
      return [
        ...rows,
        { ilvl_max: (last?.ilvl_max ?? 0) + 10, req_level: last?.req_level ?? 1 },
      ];
    });
  }

  dropLevel(index: number): void {
    this.levels.update((rows) => rows.filter((_, at) => at !== index));
  }

  async saveLevels(): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    this.busy.set(true);
    try {
      const saved = await firstValueFrom(this.api.saveIlvlLevels(this.levels()));
      this.levels.set(saved.rows.map((row) => ({ ...row })));
      this.notice.set('Уровни сохранены.');
    } catch (error) {
      this.error.set(apiError(error, 'Уровни сохранить не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }

  // --- числа модуля ---------------------------------------------------------

  setSetting(name: string, value: string): void {
    this.changed.update((changed) => ({ ...changed, [name]: value }));
  }

  settingValue(row: SettingRow): string {
    return this.changed()[row.name] ?? row.value;
  }

  async saveSettings(): Promise<void> {
    if (!this.canEdit() || this.busy()) return;
    const values = this.changed();
    if (!Object.keys(values).length) {
      this.notice.set('Числа не менялись.');
      return;
    }
    this.busy.set(true);
    try {
      const saved = await firstValueFrom(this.api.saveSettings(values));
      this.settings.set(saved.settings);
      this.changed.set({});
      this.notice.set('Сохранено.');
    } catch (error) {
      this.error.set(apiError(error, 'Числа сохранить не удалось.'));
    } finally {
      this.busy.set(false);
    }
  }
}
