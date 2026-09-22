import { Component, computed, input, signal } from '@angular/core';
import { IconComponent, IconName } from './icon.component';

/**
 * Иконка из игры по имени текстуры.
 *
 * Картинки может не быть по трём причинам сразу: у записи не задана текстура
 * (так у большинства заготовок в своих блоках), каталог иконок не
 * примонтирован или нет сети. Во всех трёх случаях на её месте - красный знак
 * вопроса: пустое место читается как «страница не дорисовалась», а знак
 * вопроса прямо говорит «иконки нет», и её сразу видно в списке.
 */
@Component({
  selector: 'app-game-icon',
  imports: [IconComponent],
  template: `
    @if (src(); as url) {
      <img
        [src]="url"
        [width]="size()"
        [height]="size()"
        alt=""
        loading="lazy"
        (error)="broken.set(true)"
      />
    } @else {
      <span class="missing" [style.width.px]="size()" [style.height.px]="size()">
        <app-icon [name]="fallback()" [size]="size()" />
      </span>
    }
  `,
  styles: `
    :host {
      align-items: center;
      display: inline-flex;
      justify-content: center;
    }
    img {
      border: 1px solid var(--line);
      border-radius: 2px;
      display: block;
      object-fit: cover;
    }
    .missing {
      align-items: center;
      border: 1px solid #7a2b2b;
      border-radius: 2px;
      box-sizing: border-box;
      color: #e04a4a;
      display: inline-flex;
      justify-content: center;
    }
  `,
})
export class GameIconComponent {
  readonly texture = input('');
  readonly base = input('');
  readonly size = input(18);
  readonly fallback = input<IconName>('question');

  readonly broken = signal(false);
  readonly src = computed(() => {
    const texture = this.texture()?.trim();
    if (!texture || !this.base() || this.broken()) return '';
    return `${this.base().replace(/\/$/, '')}/${texture.toLowerCase()}.jpg`;
  });
}
