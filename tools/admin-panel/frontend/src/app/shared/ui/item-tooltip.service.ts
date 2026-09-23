import { Injectable, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { ApiService } from '../../core/api.service';

/** Строка подсказки: левый текст, правый (скорость, тип брони) и цвет. */
export interface TooltipLine {
  l: string;
  r: string;
  /** `q0`..`q7`, `white`, `green`, `yellow`, `gray`, `red` - раскраску держит кит. */
  c: string;
}

export interface ItemTooltip {
  entry: number;
  quality: number;
  icon: string;
  lines: TooltipLine[];
}

/** Что показывать и где: предмет, его строки и прямоугольник, у которого стоять. */
export interface TooltipState {
  entry: number;
  anchor: DOMRect;
  data: ItemTooltip | null;
}

/**
 * Подсказка предмета «как в игре» - одна на всё приложение.
 *
 * Строки собирает сервер (`/api/items/{entry}/tooltip`): половина подсказки -
 * описания заклинаний из клиентского Spell.dbc с подставленными `$s1`, и
 * браузеру их взять неоткуда. Ответы кэшируются на всё время жизни вкладки:
 * предмет в игре не меняется от наведения к наведению, а повторное наведение
 * обязано быть мгновенным.
 *
 * Показ - с задержкой в полтора кадра зрения (150 мс): мышь, пролетающая над
 * списком, не должна мигать подсказками.
 */
@Injectable({ providedIn: 'root' })
export class ItemTooltipService {
  private readonly api = inject(ApiService);
  private readonly cache = new Map<number, Promise<ItemTooltip | null>>();
  private timer: ReturnType<typeof setTimeout> | null = null;
  private token = 0;
  /** Элемент, над которым сейчас мышь: прятать подсказку вправе только он. */
  private owner: Element | null = null;

  readonly state = signal<TooltipState | null>(null);

  show(entry: number, anchor: Element | null): void {
    this.cancel();
    this.owner = anchor;
    if (!entry || !anchor) {
      this.state.set(null);
      return;
    }
    const mine = ++this.token;
    this.timer = setTimeout(() => {
      this.timer = null;
      void this.load(entry).then((data) => {
        // Мышь успела уйти или перейти на другой предмет - ответ опоздал.
        if (mine !== this.token || !data) return;
        this.state.set({ entry, anchor: anchor.getBoundingClientRect(), data });
      });
    }, 150);
  }

  /** Спрятать - если просит тот, чья подсказка (или без хозяина). */
  hide(from?: Element): void {
    if (from && from !== this.owner) return;
    this.owner = null;
    this.cancel();
    this.token++;
    this.state.set(null);
  }

  private cancel(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
  }

  private load(entry: number): Promise<ItemTooltip | null> {
    let hit = this.cache.get(entry);
    if (!hit) {
      hit = firstValueFrom(this.api.get<ItemTooltip>(`/items/${entry}/tooltip`)).catch(() => {
        // Не нашёлся или сервер не ответил - в следующий раз спросим снова.
        this.cache.delete(entry);
        return null;
      });
      this.cache.set(entry, hit);
    }
    return hit;
  }
}
