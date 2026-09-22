import { Injectable, Injector, Signal, effect, inject, signal } from '@angular/core';

export type ToastKind = 'ok' | 'error';

export interface Toast {
  id: number;
  text: string;
  kind: ToastKind;
  /** Пока true - плашка растворяется и вот-вот исчезнет. */
  fading: boolean;
}

/** Сколько плашка висит в полную силу. */
const holdMs = 2600;
/** Растворение; столько же длится анимация в toast-host.component.scss. */
const fadeMs = 400;
/** Больше трёх строк внизу экрана - это уже не подсказка, а журнал. */
const maxVisible = 3;

/**
 * Всплывающие сообщения внизу по центру - то же, что снек-бар в Material.
 * Своё, а не оттуда: Material в панели не подключён, и тянуть библиотеку с
 * чужой темой ради одной плашки дороже, чем написать плашку.
 *
 * Служба одна на приложение, рисует её `app-toast-host` в каркасе - странице
 * достаточно вызвать `show`.
 */
@Injectable({ providedIn: 'root' })
export class ToastService {
  readonly toasts = signal<readonly Toast[]>([]);
  private nextId = 0;

  private readonly injector = inject(Injector);

  /**
   * Показывать всплывающей плашкой всё, что кладут в сигнал.
   *
   * Страницы держат `error()` и `notice()` сигналами - они нужны им и для
   * логики, - а показывать их на самой странице больше не надо: сообщение об
   * удаче или отказе живёт секунды, и ряд плашек наверху только сдвигал
   * содержимое. Страница вызывает это один раз при создании, вместо того
   * чтобы звать `show` в каждом обработчике.
   */
  announce(source: Signal<string | null>, kind: ToastKind = 'ok'): void {
    let shown: string | null = null;
    effect(
      () => {
        const text = source();
        // Одно и то же сообщение подряд не повторяем: сигнал может
        // перезаписаться тем же значением при следующем неудачном заходе.
        if (text && text !== shown) this.show(text, kind);
        shown = text;
      },
      { injector: this.injector },
    );
  }

  show(text: string, kind: ToastKind = 'ok'): void {
    const id = (this.nextId += 1);
    this.toasts.update((list) => [
      ...list.slice(-(maxVisible - 1)),
      { id, text, kind, fading: false },
    ]);
    setTimeout(() => this.fade(id), holdMs);
  }

  /** Клик по плашке убирает её сразу - ждать растворения незачем. */
  dismiss(id: number): void {
    this.fade(id);
  }

  private fade(id: number): void {
    let found = false;
    this.toasts.update((list) =>
      list.map((toast) => {
        if (toast.id !== id || toast.fading) return toast;
        found = true;
        return { ...toast, fading: true };
      }),
    );
    // Второй раз запускать снятие незачем: плашку уже убирают.
    if (found) setTimeout(() => this.drop(id), fadeMs);
  }

  private drop(id: number): void {
    this.toasts.update((list) => list.filter((toast) => toast.id !== id));
  }
}
