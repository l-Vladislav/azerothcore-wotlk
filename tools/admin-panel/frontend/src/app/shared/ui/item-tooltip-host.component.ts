import { Component, ElementRef, afterRenderEffect, inject, viewChild } from '@angular/core';
import { ItemTooltipService } from './item-tooltip.service';

/**
 * Общая подсказка предмета. Ставится в каркас один раз, как полоса сообщений.
 *
 * Живёт в ВЕРХНЕМ СЛОЕ браузера (`popover="manual"`), а не просто поверх
 * страницы: предметы бывают внутри модальных окон выбора, и всё, что осталось в
 * обычном слое, рисуется ПОД `<dialog>` - подсказка была бы не видна ровно там,
 * где нужнее всего. Показанный позже поповер ложится над открытым окном.
 *
 * Стоит справа от предмета, как в игре у курсора; не влезает - слева; по
 * высоте прижимается к краю экрана, но не уезжает за него.
 */
@Component({
  selector: 'app-item-tooltip-host',
  template: `
    <div #box popover="manual" class="forge-tooltip is-item" role="tooltip">
      @if (tip.state()?.data; as data) {
        @for (line of data.lines; track $index; let first = $first) {
          <div class="line" [class.title]="first" [class]="'tt-' + line.c">
            <span>{{ line.l }}</span>
            @if (line.r) {
              <span class="right">{{ line.r }}</span>
            }
          </div>
        }
      }
    </div>
  `,
})
export class ItemTooltipHostComponent {
  readonly tip = inject(ItemTooltipService);
  private readonly box = viewChild.required<ElementRef<HTMLElement>>('box');

  constructor() {
    afterRenderEffect(() => {
      const state = this.tip.state();
      const box = this.box().nativeElement;
      if (!state?.data) {
        if (box.matches(':popover-open')) box.hidePopover();
        return;
      }
      // Заново в верхний слой при каждом показе: окно, открытое после
      // прошлого показа, иначе оказалось бы сверху.
      if (box.matches(':popover-open')) box.hidePopover();
      box.showPopover();

      const gap = 10;
      const width = box.offsetWidth;
      const height = box.offsetHeight;
      const a = state.anchor;
      let left = a.right + gap;
      if (left + width > window.innerWidth - gap) left = a.left - gap - width;
      left = Math.max(gap, left);
      let top = a.top;
      if (top + height > window.innerHeight - gap) top = window.innerHeight - gap - height;
      top = Math.max(gap, top);
      box.style.left = `${left}px`;
      box.style.top = `${top}px`;
    });
  }
}
