import { Directive, ElementRef, HostListener, OnDestroy, inject, input } from '@angular/core';
import { ItemTooltipService } from './item-tooltip.service';

/**
 * `[appItemTooltip]="entry"` - игровая подсказка предмета при наведении.
 *
 * Сама ничего не рисует: говорит общей подсказке (`app-item-tooltip-host` в
 * каркасе), какой предмет и у какого элемента показать. Ноль - подсказки нет.
 */
@Directive({ selector: '[appItemTooltip]' })
export class ItemTooltipDirective implements OnDestroy {
  private readonly el = inject<ElementRef<HTMLElement>>(ElementRef);
  private readonly tip = inject(ItemTooltipService);

  readonly appItemTooltip = input(0);

  @HostListener('mouseenter')
  onEnter(): void {
    this.tip.show(this.appItemTooltip(), this.el.nativeElement);
  }

  @HostListener('mouseleave')
  onLeave(): void {
    this.tip.hide(this.el.nativeElement);
  }

  ngOnDestroy(): void {
    // Строка ушла из списка под мышью (листание, отбор) - подсказка не должна
    // остаться висеть над пустым местом.
    this.tip.hide(this.el.nativeElement);
  }
}
