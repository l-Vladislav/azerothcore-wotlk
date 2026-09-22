import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { IconComponent } from '../../shared/ui/icon.component';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { WeatherOverview, WeatherSetting, WeatherSettings } from './weather.api';
import { WeatherApi } from './weather.api';
import { ToastService } from '../../shared/ui/toast.service';

@Component({
  imports: [FormsModule, ForgeSelectDirective, IconComponent],
  providers: [WeatherApi],
  selector: 'app-weather-settings-page',
  styleUrl: './weather-settings.page.scss',
  templateUrl: './weather-settings.page.html',
})
export class WeatherSettingsPage implements OnInit {
  private readonly toast = inject(ToastService);
  private readonly api = inject(WeatherApi);
  private readonly auth = inject(AuthService);

  readonly overview = signal<WeatherOverview | null>(null);
  readonly settings = signal<WeatherSettings | null>(null);
  readonly loading = signal(true);
  readonly pending = signal<string | null>(null);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);
  readonly canEdit = computed(() => this.auth.actor()?.role !== 'viewer');

  constructor() {
    // Сообщения об удаче и отказе показываются всплывающими
    // плашками: строка наверху страницы сдвигала содержимое и
    // висела до следующего действия.
    this.toast.announce(this.error, 'error');
    this.toast.announce(this.notice);
  }

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  async load(): Promise<void> {
    this.loading.set(true);
    try {
      const [overview, settings] = await Promise.all([
        firstValueFrom(this.api.overview()),
        firstValueFrom(this.api.settings()),
      ]);
      this.overview.set(overview);
      this.settings.set(settings);
      this.error.set(null);
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось получить настройки погоды.'));
    } finally {
      this.loading.set(false);
    }
  }

  rows(group: string): WeatherSetting[] {
    return (this.settings()?.settings ?? []).filter(
      (setting) => setting.group === group && setting.name !== 'enabled',
    );
  }

  formatValue(setting: WeatherSetting, value: number): string {
    if (setting.kind === 'bool') return value ? 'да' : 'нет';
    const option = setting.options?.find((item) => item.value === value);
    if (option) return option.label;
    return setting.unit ? `${value} ${setting.unit}` : String(value);
  }

  async choose(setting: WeatherSetting, next: number): Promise<void> {
    const value = Number(next);
    if (!Number.isFinite(value) || value === setting.value) return;
    await this.write(setting, value);
  }

  async save(setting: WeatherSetting, input: HTMLInputElement): Promise<void> {
    if (!this.canEdit() || this.pending()) return;
    const value = Number(input.value);
    if (!Number.isFinite(value) || value === setting.value) {
      input.value = String(setting.value);
      return;
    }
    if (value < setting.min || value > setting.max) {
      this.error.set(`${setting.label}: допустимо ${setting.min}…${setting.max}.`);
      input.value = String(setting.value);
      return;
    }
    await this.write(setting, value);
  }

  async toggle(setting: WeatherSetting): Promise<void> {
    await this.write(setting, setting.value ? 0 : 1);
  }

  async reset(setting: WeatherSetting): Promise<void> {
    await this.write(setting, null);
  }

  async toggleDirector(): Promise<void> {
    const module = this.overview()?.module;
    if (!module || !this.canEdit() || !module.can_toggle || this.pending()) return;
    this.pending.set('director');
    try {
      const next = await firstValueFrom(this.api.setDirector(!module.enabled));
      this.overview.update((overview) =>
        overview ? { ...overview, module: { ...overview.module, ...next } } : overview,
      );
      this.notice.set(next.enabled ? 'Режиссёр погоды включён.' : 'Режиссёр погоды выключен.');
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось переключить режиссёра.'));
    } finally {
      this.pending.set(null);
    }
  }

  private async write(setting: WeatherSetting, value: number | null): Promise<void> {
    if (!this.canEdit() || this.pending()) return;
    this.pending.set(setting.name);
    this.error.set(null);
    try {
      const saved = await firstValueFrom(this.api.setSetting(setting.name, value));
      this.settings.update((settings) =>
        settings
          ? {
              ...settings,
              settings: settings.settings.map((row) =>
                row.name === setting.name ? { ...row, ...saved } : row,
              ),
            }
          : settings,
      );
      this.notice.set(
        value === null
          ? `${setting.label}: возвращено значение из конфигурации.`
          : `${setting.label}: сохранено.`,
      );
    } catch (error) {
      this.error.set(this.errorText(error, `Не удалось сохранить «${setting.label}».`));
    } finally {
      this.pending.set(null);
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
