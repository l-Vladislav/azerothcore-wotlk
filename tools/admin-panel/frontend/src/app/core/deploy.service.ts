import { Injectable, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { ApiService } from './api.service';
import { DeployState } from '../features/settings/deploy/deploy.api';

/**
 * Сколько правок ждёт живого мира - на весь фронт одно знание.
 *
 * Панель пишет в базу PTR, а модули мира держат справочники в памяти; между
 * «сохранил» и «видно в игре» стоит перечитка. Раньше её просила кнопка на
 * каждой странице, и кто её не нажал, у того правка тихо оставалась в базе.
 * Теперь счёт ведёт сервер (`app/apply.py`), а здесь - его отражение: метка на
 * кнопке меню и страница «Серверный патч».
 *
 * Обновляется само, из перехватчика запросов: страницам об этом знать незачем,
 * ровно как и обработчикам на сервере знать о реестре.
 */
@Injectable({ providedIn: 'root' })
export class DeployService {
  private readonly api = inject(ApiService);
  private timer: ReturnType<typeof setTimeout> | undefined;
  private inFlight = false;

  readonly state = signal<DeployState | null>(null);
  readonly waiting = computed(() => this.state()?.waiting.length ?? 0);

  /** Отложенно и по одному: правка формы - это десяток запросов подряд. */
  schedule(delay = 400): void {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => void this.refresh(), delay);
  }

  async refresh(): Promise<void> {
    if (this.inFlight) return;
    this.inFlight = true;
    try {
      this.state.set(await firstValueFrom(this.api.get<DeployState>('/apply')));
    } catch {
      // Молча: метка - подсказка, а не работа. Ошибку покажет сама страница.
    } finally {
      this.inFlight = false;
    }
  }

  set(state: DeployState): void {
    this.state.set(state);
  }
}
