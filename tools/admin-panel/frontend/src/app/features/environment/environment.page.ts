import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth.service';
import {
  EffectRule,
  EffectSpell,
  EnvironmentApi,
  ValidationProblem,
  ZoneRules,
  ZoneSummary,
} from './environment.api';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { GameIconComponent } from '../../shared/ui/game-icon.component';
import { IconComponent } from '../../shared/ui/icon.component';
import { ToastService } from '../../shared/ui/toast.service';

const triggers = [
  'Всегда',
  'Дождь',
  'Снег',
  'Песчаная буря',
  'Туман',
  'Гроза',
  'Чёрный дождь',
  'Чёрный снег',
];
const times = ['Любое время', 'Только днём', 'Только ночью'];

type Pool = 'buffs' | 'debuffs';

@Component({
  imports: [FormsModule, ForgeSelectDirective, GameIconComponent, IconComponent, RouterLink],
  providers: [EnvironmentApi],
  selector: 'app-environment-page',
  styleUrl: './environment.page.scss',
  templateUrl: './environment.page.html',
})
export class EnvironmentPage implements OnInit {
  private readonly toast = inject(ToastService);
  private readonly api = inject(EnvironmentApi);
  private readonly route = inject(ActivatedRoute);
  readonly auth = inject(AuthService);

  readonly current = signal<ZoneRules | null>(null);
  readonly spells = signal<readonly EffectSpell[]>([]);
  /** Каталог иконок: пустая строка - значков не будет, и это честно видно. */
  readonly iconBase = signal('');
  readonly picker = signal<{ pool: Pool; index: number | null } | null>(null);
  readonly pickerQuery = signal('');
  readonly dirty = signal(false);
  readonly loading = signal(true);
  readonly pending = signal<string | null>(null);
  readonly problems = signal<readonly ValidationProblem[]>([]);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);
  readonly canEdit = computed(() => this.auth.actor()?.role !== 'viewer');
  readonly pools: readonly Pool[] = ['buffs', 'debuffs'];
  readonly filteredSpells = computed(() => {
    const picker = this.picker();
    if (!picker) return [];
    const needle = this.pickerQuery().trim().toLocaleLowerCase();
    const kind = picker.pool === 'buffs' ? 0 : 1;
    return this.spells()
      .filter(
        (spell) =>
          spell.kind === kind &&
          (!needle ||
            spell.name_ru.toLocaleLowerCase().includes(needle) ||
            spell.description_ru.toLocaleLowerCase().includes(needle) ||
            String(spell.spell_id).includes(needle)),
      )
      .slice(0, 300);
  });

  constructor() {
    // Сообщения об удаче и отказе показываются всплывающими
    // плашками: строка наверху страницы сдвигала содержимое и
    // висела до следующего действия.
    this.toast.announce(this.error, 'error');
    this.toast.announce(this.notice);
  }

  async ngOnInit(): Promise<void> {
    // Зона - из адреса: страница больше не зависит от чужого выбора и
    // переживает обновление и приход по ссылке.
    this.route.paramMap.subscribe((params) => {
      // Ноль - НАСТОЯЩИЙ номер: под ним живут общемировые правила. Проверка
      // «больше нуля» молча выбрасывала именно их, и страница оставалась
      // пустой.
      const id = Number(params.get('zone'));
      if (Number.isFinite(id) && id >= 0) void this.openZone(id);
    });
    void this.loadIconBase();
    this.loading.set(false);
  }

  async openZone(id: number): Promise<void> {
    if (this.dirty() && !confirm('Несохранённые изменения будут потеряны. Продолжить?')) return;
    this.pending.set('zone');
    try {
      this.current.set(await firstValueFrom(this.api.zone(id)));
      this.dirty.set(false);
      this.problems.set([]);
      this.error.set(null);
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось открыть правила зоны.'));
    } finally {
      this.pending.set(null);
    }
  }

  addRule(pool: Pool): void {
    this.picker.set({ pool, index: null });
    this.pickerQuery.set('');
    void this.loadSpells();
  }

  replaceRule(pool: Pool, index: number): void {
    this.picker.set({ pool, index });
    this.pickerQuery.set('');
    void this.loadSpells();
  }

  chooseSpell(spell: EffectSpell): void {
    const picker = this.picker();
    const current = this.current();
    if (!picker || !current) return;
    const rule: EffectRule = {
      spell_id: spell.spell_id,
      trigger_type: 0,
      time_flag: 0,
      enabled: true,
      spell,
    };
    const rows = [...current[picker.pool]];
    if (picker.index === null) rows.push(rule);
    else rows[picker.index] = { ...rows[picker.index], spell_id: spell.spell_id, spell };
    this.updatePool(picker.pool, rows);
    this.picker.set(null);
  }

  removeRule(pool: Pool, index: number): void {
    const current = this.current();
    if (!current) return;
    this.updatePool(
      pool,
      current[pool].filter((_, rowIndex) => rowIndex !== index),
    );
  }

  updateRule(pool: Pool, index: number, fields: Partial<EffectRule>): void {
    const current = this.current();
    if (!current) return;
    this.updatePool(
      pool,
      current[pool].map((rule, rowIndex) => (rowIndex === index ? { ...rule, ...fields } : rule)),
    );
  }

  triggerLabel(value: number): string {
    return triggers[value] ?? `Триггер ${value}`;
  }

  timeLabel(value: number): string {
    return times[value] ?? `Время ${value}`;
  }

  async save(force = false): Promise<void> {
    const current = this.current();
    if (!current || !this.canEdit() || this.pending()) return;
    this.pending.set('save');
    this.error.set(null);
    try {
      const result = await firstValueFrom(this.api.save(current.zone_id, current, force));
      this.problems.set(result.problems);
      this.dirty.set(false);
      this.current.set(await firstValueFrom(this.api.zone(current.zone_id)));
      this.notice.set(
        result.reloaded
          ? `Сохранено правил: ${result.saved}; PTR обновлён.`
          : `Сохранено правил: ${result.saved}; PTR не обновился.`,
      );
    } catch (error) {
      const details = this.problemDetails(error);
      if (details.length) {
        this.problems.set(details);
        if (
          confirm(
            `Найдено ошибок: ${details.filter((problem) => problem.level === 'error').length}. Сохранить всё равно?`,
          )
        ) {
          this.pending.set(null);
          await this.save(true);
          return;
        }
      } else {
        this.error.set(this.errorText(error, 'Не удалось сохранить правила зоны.'));
      }
    } finally {
      this.pending.set(null);
    }
  }

  async removeAll(): Promise<void> {
    const current = this.current();
    if (!current || !this.canEdit() || this.pending()) return;
    if (!confirm(`Удалить все правила: ${current.name}?`)) return;
    this.pending.set('delete');
    try {
      await firstValueFrom(this.api.delete(current.zone_id));
      await firstValueFrom(this.api.reload());
      this.current.set(null);
      this.dirty.set(false);
      this.notice.set('Правила удалены, PTR обновлён.');
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось удалить правила.'));
    } finally {
      this.pending.set(null);
    }
  }

  private async loadIconBase(): Promise<void> {
    try {
      const meta = await firstValueFrom(this.api.meta());
      this.iconBase.set(meta.icon_base_url ?? '');
    } catch {
      this.iconBase.set('');
    }
  }

  private async loadSpells(): Promise<void> {
    if (this.spells().length) return;
    try {
      this.spells.set(await firstValueFrom(this.api.spells()));
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось загрузить каталог эффектов.'));
      this.picker.set(null);
    }
  }

  private updatePool(pool: Pool, rows: EffectRule[]): void {
    this.current.update((current) => (current ? { ...current, [pool]: rows } : current));
    this.dirty.set(true);
    this.problems.set([]);
  }

  private problemDetails(error: unknown): ValidationProblem[] {
    if (typeof error !== 'object' || !error || !('error' in error)) return [];
    const body = (error as { error?: unknown }).error;
    if (typeof body !== 'object' || !body || !('detail' in body)) return [];
    const detail = (body as { detail?: unknown }).detail;
    if (typeof detail !== 'object' || !detail || !('problems' in detail)) return [];
    const problems = (detail as { problems?: unknown }).problems;
    return Array.isArray(problems) ? (problems as ValidationProblem[]) : [];
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
