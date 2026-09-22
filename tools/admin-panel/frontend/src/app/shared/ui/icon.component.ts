import { Component, computed, input } from '@angular/core';

export type IconName =
  | 'world'
  | 'records'
  | 'board'
  | 'server'
  | 'loot'
  | 'weather'
  | 'weather-settings'
  | 'effects'
  | 'talents'
  | 'professions'
  | 'spells'
  | 'spell-workshop'
  | 'items'
  | 'world-items'
  | 'patch'
  | 'news'
  | 'users'
  | 'audit'
  | 'search'
  | 'lock'
  | 'unlock'
  | 'question'
  | 'bug'
  | 'idea'
  | 'task'
  | 'plus'
  | 'close'
  | 'check'
  | 'arrow-up'
  | 'arrow-down'
  | 'sort'
  | 'caret'
  | 'caret-up'
  | 'caret-right'
  | 'refresh'
  | 'filter'
  | 'archive'
  | 'tag'
  | 'edit'
  | 'trash'
  | 'calendar'
  | 'module'
  | 'external'
  | 'bell'
  | 'wrench'
  | 'chest'
  | 'scroll'
  | 'key'
  | 'dot';

/** Своё число у каждого значка: иначе все они возьмут первый градиент. */
let counter = 0;

/**
 * Синонимы: разные имена с одним рисунком. Заведены не для красоты - Angular
 * не умеет проваливаться сквозь несколько `@case`, а рисунок у «Предметов» и
 * «Сундука» один и тот же.
 */
const aliases: Record<string, string> = {
  chest: 'items',
  key: 'unlock',
  scroll: 'audit',
  'spell-workshop': 'spells',
};

/**
 * Свой набор значков вместо юникодных глифов.
 *
 * Глифы вроде «☠ ☁ ⚘ ⌖» рисует шрифт, а не мы: часть системных шрифтов
 * подставляет им цветные эмодзи, часть - контурные символы другого веса и
 * размера, и ряд значков выглядит собранным с миру по нитке. Здесь всё одной
 * рукой, на сетке 24.
 *
 * ЗНАЧКИ ЗОЛОТЫЕ И ЗАЛИТЫЕ - как на листах стайлгайда (лист 10, «Icon Tiles»
 * и «Compact Emblems»). Числа замерены с самих плиток: блик #ffe483..#ffec81,
 * тело #b98121..#c68818, тень #3e2303..#4b300a. Отсюда градиент сверху вниз и
 * тёмный кант; кант рисуется ПОД заливкой (`paint-order="stroke"`), поэтому
 * съедает не рисунок, а только полпикселя снаружи - в 15 пикселях на карточке
 * доски значок от этого не заплывает.
 *
 * Прежний набор был контурным и красился в цвет текста (`currentColor`). На
 * листах пиктограмма всегда золотая, поэтому цвет текста тут больше не при
 * чём; там, где значок обязан быть в цвет соседней подписи (красная кнопка,
 * приглушённая строка), ставится `tone="plain"` - тогда он снова плоский и
 * берёт `currentColor`.
 */
@Component({
  selector: 'app-icon',
  template: `
    <svg
      [attr.width]="size()"
      [attr.height]="size()"
      viewBox="0 0 24 24"
      aria-hidden="true"
      focusable="false"
    >
      @if (tone() === 'gold') {
        <defs>
          <linearGradient [attr.id]="gradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stop-color="#ffe98c" />
            <stop offset="0.45" stop-color="#e9b73d" />
            <stop offset="1" stop-color="#c8891a" />
          </linearGradient>
        </defs>
      }
      <g
        [attr.fill]="tone() === 'gold' ? 'url(#' + gradient + ')' : 'currentColor'"
        [attr.stroke]="tone() === 'gold' ? '#2e1b04' : 'none'"
        stroke-width="1.1"
        stroke-linejoin="round"
        paint-order="stroke"
      >
        @switch (glyph()) {
          @case ('world') {
            <circle cx="12" cy="12" r="9" />
            <g fill="none" stroke="#2e1b04" stroke-width="1.2" stroke-linecap="round">
              <path
                d="M3.3 12h17.4M12 3.2c3.1 3.4 3.1 14.2 0 17.6M12 3.2c-3.1 3.4-3.1 14.2 0 17.6"
              />
            </g>
          }
          @case ('records') {
            <path d="M11.3 6.6C9.6 5 7.4 4.2 4.6 4.2v12.9c2.8 0 5 .8 6.7 2.4Z" />
            <path d="M12.7 6.6c1.7-1.6 3.9-2.4 6.7-2.4v12.9c-2.8 0-5 .8-6.7 2.4Z" />
          }
          @case ('board') {
            <rect x="3" y="4.4" width="5" height="15.2" rx="1.1" />
            <rect x="9.5" y="4.4" width="5" height="10.2" rx="1.1" />
            <rect x="16" y="4.4" width="5" height="13" rx="1.1" />
          }
          @case ('server') {
            <circle cx="12" cy="12" r="7.2" />
            <g fill="#2e1b04" stroke="none">
              <circle cx="12" cy="12" r="2.6" />
              <rect x="11.1" y="2.6" width="1.8" height="3.4" rx="0.7" />
              <rect x="11.1" y="18" width="1.8" height="3.4" rx="0.7" />
              <rect x="2.6" y="11.1" width="3.4" height="1.8" rx="0.7" />
              <rect x="18" y="11.1" width="3.4" height="1.8" rx="0.7" />
            </g>
          }
          @case ('loot') {
            <path
              d="M12 3.2c-4.4 0-7.3 2.9-7.3 6.8 0 2.3 1.1 3.9 2.6 5v2.3h9.4v-2.3c1.5-1.1 2.6-2.7 2.6-5 0-3.9-2.9-6.8-7.3-6.8Z"
            />
            <rect x="8.6" y="18.2" width="1.8" height="2.6" rx="0.6" />
            <rect x="11.1" y="18.2" width="1.8" height="2.6" rx="0.6" />
            <rect x="13.6" y="18.2" width="1.8" height="2.6" rx="0.6" />
            <g fill="#2e1b04" stroke="none">
              <ellipse cx="9.2" cy="10.2" rx="1.7" ry="1.9" />
              <ellipse cx="14.8" cy="10.2" rx="1.7" ry="1.9" />
              <path d="M12 12.4l1.3 2.4h-2.6Z" />
            </g>
          }
          @case ('weather') {
            <path
              d="M7.4 18.4h9.4a4.2 4.2 0 0 0 .5-8.4 5.9 5.9 0 0 0-11.2-1 4.2 4.2 0 0 0 1.3 9.4Z"
            />
          }
          @case ('weather-settings') {
            <path d="M7 15h8.9a3.7 3.7 0 0 0 .4-7.4 5.2 5.2 0 0 0-9.9-.9A3.7 3.7 0 0 0 7 15Z" />
            <path d="M8.4 17.2 6.8 21l3-2.1Z" />
            <path d="M12.6 17.2 11 21l3-2.1Z" />
            <path d="M16.8 17.2 15.2 21l3-2.1Z" />
          }
          @case ('effects') {
            <path d="M12 2.4l2 6.6 6.6 2-6.6 2-2 6.6-2-6.6-6.6-2 6.6-2Z" />
            <path d="M19 15.8l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8Z" />
          }
          @case ('talents') {
            <rect x="11.2" y="6" width="1.6" height="7" />
            <path d="M11.4 11.2 7.2 15.6l1.4 1.4 4.2-4.4Z" />
            <path d="M12.6 11.2l4.2 4.4-1.4 1.4-4.2-4.4Z" />
            <circle cx="12" cy="4.6" r="2.8" />
            <circle cx="6.2" cy="18.4" r="2.8" />
            <circle cx="17.8" cy="18.4" r="2.8" />
          }
          @case ('professions') {
            <!-- Молот: рукоять по диагонали, боёк поперёк неё. Собран из двух
                 повёрнутых прямоугольников - так он остаётся узнаваемым в
                 пятнадцати пикселях, а не превращается в косую чёрточку. -->
            <rect
              x="2.4"
              y="14.2"
              width="13"
              height="2.9"
              rx="1.4"
              transform="rotate(-45 8.9 15.6)"
            />
            <rect
              x="11.1"
              y="5.9"
              width="9.4"
              height="5.6"
              rx="1.2"
              transform="rotate(45 15.8 8.7)"
            />
          }
          @case ('spells') {
            <path d="M3.4 19.2 12.4 10.2l1.6 1.6-9 9a1.15 1.15 0 0 1-1.6-1.6Z" />
            <path d="M15.4 2.6l1.5 3.5 3.5 1.5-3.5 1.5-1.5 3.5-1.5-3.5L10.4 7.6l3.5-1.5Z" />
            <path d="M6.6 3.4l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8Z" />
          }
          @case ('items') {
            <path d="M4 10.6a8 8 0 0 1 16 0v1.2H4Z" />
            <rect x="3.4" y="12.4" width="17.2" height="7.6" rx="1.4" />
            <g fill="#2e1b04" stroke="none">
              <rect x="10.6" y="9.8" width="2.8" height="5.4" rx="0.8" />
            </g>
          }
          @case ('world-items') {
            <path d="M12 21.2c0-.1 7-6.6 7-11.1a7 7 0 1 0-14 0c0 4.5 7 11 7 11.1Z" />
            <circle cx="12" cy="9.8" r="2.6" fill="#2e1b04" stroke="none" />
          }
          @case ('patch') {
            <path d="M10.2 3.4h3.6v6.4h3.6L12 16.2 6.6 9.8h3.6Z" />
            <path d="M4 17h16a1 1 0 0 1 1 1v1.6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V18a1 1 0 0 1 1-1Z" />
          }
          @case ('news') {
            <path
              d="M4 5.4h16a1.4 1.4 0 0 1 1.4 1.4v10.4a1.4 1.4 0 0 1-1.4 1.4H4a1.4 1.4 0 0 1-1.4-1.4V6.8A1.4 1.4 0 0 1 4 5.4Z"
            />
            <path
              d="M3.2 6.6 12 12.6l8.8-6"
              fill="none"
              stroke="#2e1b04"
              stroke-width="1.5"
              stroke-linecap="round"
            />
          }
          @case ('users') {
            <circle cx="11.6" cy="8.4" r="3.8" />
            <path d="M4.6 20.4c0-3.8 3.1-6.2 7-6.2s7 2.4 7 6.2Z" />
            <circle cx="4.6" cy="9.6" r="2.6" />
            <path d="M1 18.4c0-2.6 1.6-4.2 3.6-4.2h1.2A9 9 0 0 0 3 18.4Z" />
            <circle cx="19.4" cy="9.6" r="2.6" />
            <path d="M23 18.4c0-2.6-1.6-4.2-3.6-4.2h-1.2a9 9 0 0 1 2.8 4.2Z" />
          }
          @case ('audit') {
            <path d="M5.6 3.2h9.2l4.6 4.6v13a1 1 0 0 1-1 1H5.6a1 1 0 0 1-1-1V4.2a1 1 0 0 1 1-1Z" />
            <path d="M14.4 3.4v4.8h4.8" fill="#2e1b04" stroke="none" />
            <g fill="none" stroke="#2e1b04" stroke-width="1.4" stroke-linecap="round">
              <path d="M8 11.6h8M8 14.6h8M8 17.6h4.6" />
            </g>
          }
          @case ('search') {
            <path
              d="M10.6 3.6a7 7 0 1 0 0 14 7 7 0 0 0 0-14Zm0 2.6a4.4 4.4 0 1 1 0 8.8 4.4 4.4 0 0 1 0-8.8Z"
            />
            <path d="M15.4 16.6 17.2 14.8l4 4a1.3 1.3 0 0 1-1.8 1.8Z" />
          }
          @case ('lock') {
            <path d="M7.4 10.4V7.8a4.6 4.6 0 0 1 9.2 0v2.6h-2.4V7.8a2.2 2.2 0 0 0-4.4 0v2.6Z" />
            <rect x="4.6" y="10.2" width="14.8" height="10" rx="1.6" />
            <g fill="#2e1b04" stroke="none">
              <circle cx="12" cy="14.2" r="1.5" />
              <rect x="11.2" y="14.6" width="1.6" height="3.4" rx="0.6" />
            </g>
          }
          @case ('unlock') {
            <path d="M9.4 10.4V7.8a4.6 4.6 0 0 1 8.8-1.8l-2.2.9a2.2 2.2 0 0 0-4.2.9v2.6Z" />
            <rect x="4.6" y="10.2" width="12.6" height="10" rx="1.6" />
            <g fill="#2e1b04" stroke="none">
              <circle cx="10.9" cy="14.2" r="1.5" />
              <rect x="10.1" y="14.6" width="1.6" height="3.4" rx="0.6" />
            </g>
          }
          @case ('question') {
            <circle cx="12" cy="12" r="9" />
            <g fill="none" stroke="#2e1b04" stroke-width="2.1" stroke-linecap="round">
              <path d="M9.4 9.6a2.7 2.7 0 1 1 3.4 2.7c-.7.3-1 .9-1 1.6v.4" />
            </g>
            <circle cx="12" cy="17.2" r="1.2" fill="#2e1b04" stroke="none" />
          }
          @case ('bug') {
            <!-- Лапки и усики - золотые прямоугольники, а не тёмные штрихи:
                 тёмным по тёмному фону их не видно, и жук читался пилюлей. -->
            <rect
              x="2.8"
              y="9.4"
              width="5.6"
              height="1.7"
              rx="0.8"
              transform="rotate(-18 5.6 10.2)"
            />
            <rect x="2.6" y="13.3" width="5.6" height="1.7" rx="0.8" />
            <rect
              x="2.8"
              y="16.8"
              width="5.6"
              height="1.7"
              rx="0.8"
              transform="rotate(18 5.6 17.6)"
            />
            <rect
              x="15.6"
              y="9.4"
              width="5.6"
              height="1.7"
              rx="0.8"
              transform="rotate(18 18.4 10.2)"
            />
            <rect x="15.8" y="13.3" width="5.6" height="1.7" rx="0.8" />
            <rect
              x="15.6"
              y="16.8"
              width="5.6"
              height="1.7"
              rx="0.8"
              transform="rotate(-18 18.4 17.6)"
            />
            <rect
              x="7.6"
              y="2.6"
              width="4.6"
              height="1.5"
              rx="0.7"
              transform="rotate(35 9.9 3.3)"
            />
            <rect
              x="11.8"
              y="2.6"
              width="4.6"
              height="1.5"
              rx="0.7"
              transform="rotate(-35 14.1 3.3)"
            />
            <circle cx="12" cy="7" r="2.9" />
            <ellipse cx="12" cy="14.4" rx="4.9" ry="6.2" />
            <path d="M12 9v10.6" fill="none" stroke="#2e1b04" stroke-width="1.3" />
          }
          @case ('idea') {
            <path d="M8.6 15.6a5.8 5.8 0 1 1 6.8 0v2.2H8.6Z" />
            <rect x="8.8" y="18.4" width="6.4" height="1.8" rx="0.9" />
            <rect x="9.8" y="20.6" width="4.4" height="1.6" rx="0.8" />
          }
          @case ('task') {
            <rect x="3.6" y="3.6" width="16.8" height="16.8" rx="2.2" />
            <path
              d="m8 12.2 2.8 2.9 5.4-6"
              fill="none"
              stroke="#2e1b04"
              stroke-width="2.4"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          }
          @case ('plus') {
            <path d="M10.4 3.6h3.2v6.8h6.8v3.2h-6.8v6.8h-3.2v-6.8H3.6v-3.2h6.8Z" />
          }
          @case ('close') {
            <path
              d="M6.2 4 12 9.8 17.8 4 20 6.2 14.2 12 20 17.8 17.8 20 12 14.2 6.2 20 4 17.8 9.8 12 4 6.2Z"
            />
          }
          @case ('check') {
            <path d="M9.8 18.6 3.4 12.2l2.4-2.4 4 4 8.4-8.4 2.4 2.4Z" />
          }
          @case ('arrow-up') {
            <path d="M12 2.8 20 11h-4.6v10.2H8.6V11H4Z" />
          }
          @case ('arrow-down') {
            <path d="M12 21.2 4 13h4.6V2.8h6.8V13H20Z" />
          }
          @case ('sort') {
            <path d="M12 2.6 17 9H7Z" />
            <path d="M12 21.4 7 15h10Z" />
          }
          @case ('caret') {
            <path d="M12 16.6 5 8.4h14Z" />
          }
          @case ('caret-up') {
            <path d="M12 7.4 19 15.6H5Z" />
          }
          @case ('caret-right') {
            <path d="M16.6 12 8.4 19V5Z" />
          }
          @case ('refresh') {
            <path d="M12 4.4a7.6 7.6 0 1 1-7.3 9.8l2.8-.9A4.7 4.7 0 1 0 12 7.2Z" />
            <path d="M13.2 2 8 4.9l5.2 3Z" />
          }
          @case ('filter') {
            <path d="M3.2 4.4h17.6l-6.8 8.2v8.2l-4-2.6v-5.6Z" />
          }
          @case ('archive') {
            <path
              d="M3 4.2h18a1 1 0 0 1 1 1v2.6a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V5.2a1 1 0 0 1 1-1Z"
            />
            <path d="M4.2 10.2h15.6v9.4a1.2 1.2 0 0 1-1.2 1.2H5.4a1.2 1.2 0 0 1-1.2-1.2Z" />
            <rect x="9.2" y="13" width="5.6" height="1.9" rx="0.9" fill="#2e1b04" stroke="none" />
          }
          @case ('tag') {
            <path d="M11.4 2.8H21v9.6l-9.2 9.2a1.4 1.4 0 0 1-2 0l-7.6-7.6a1.4 1.4 0 0 1 0-2Z" />
            <circle cx="17" cy="7" r="1.9" fill="#2e1b04" stroke="none" />
          }
          @case ('edit') {
            <path d="M3.4 16.6 15.2 4.8l4 4L7.4 20.6l-4.8.8Z" />
            <path d="M16.6 3.4 18 2a1.4 1.4 0 0 1 2 0l2 2a1.4 1.4 0 0 1 0 2l-1.4 1.4Z" />
          }
          @case ('trash') {
            <path d="M9 2.6h6a1 1 0 0 1 1 1v1.6H8V3.6a1 1 0 0 1 1-1Z" />
            <rect x="2.8" y="5" width="18.4" height="2.8" rx="1.1" />
            <path d="M5 8.6h14l-1 11a1.6 1.6 0 0 1-1.6 1.5H7.6A1.6 1.6 0 0 1 6 19.6Z" />
            <g fill="#2e1b04" stroke="none">
              <rect x="8.8" y="11" width="1.6" height="7.4" rx="0.8" />
              <rect x="13.6" y="11" width="1.6" height="7.4" rx="0.8" />
            </g>
          }
          @case ('calendar') {
            <rect x="2.8" y="4.6" width="18.4" height="16.4" rx="1.8" />
            <rect x="6.4" y="1.8" width="2.4" height="4.6" rx="1.2" />
            <rect x="15.2" y="1.8" width="2.4" height="4.6" rx="1.2" />
            <g fill="#2e1b04" stroke="none">
              <rect x="2.8" y="8.6" width="18.4" height="1.8" />
              <rect x="6" y="12.4" width="3" height="2.6" rx="0.6" />
              <rect x="10.5" y="12.4" width="3" height="2.6" rx="0.6" />
              <rect x="15" y="12.4" width="3" height="2.6" rx="0.6" />
              <rect x="6" y="16.4" width="3" height="2.6" rx="0.6" />
              <rect x="10.5" y="16.4" width="3" height="2.6" rx="0.6" />
            </g>
          }
          @case ('module') {
            <path d="M12 2.4 21.4 7.6 12 12.8 2.6 7.6Z" />
            <path d="M2.6 9.2 11.2 14v7.6L2.6 16.8Z" />
            <path d="M21.4 9.2 12.8 14v7.6l8.6-4.8Z" />
          }
          @case ('external') {
            <path d="M3.4 5.4h8v2.8H6.2v9.6h9.6v-5.2h2.8v8H3.4Z" />
            <path d="M13.4 2.6h8v8l-2.9-2.9-4.6 4.6-2.2-2.2 4.6-4.6Z" />
          }
          @case ('wrench') {
            <path
              d="M20.4 4.6 17 8l-1-1 3.4-3.4a5.6 5.6 0 0 0-7.3 6.8L3.6 18.9a1.6 1.6 0 0 0 2.3 2.3l8.5-8.5a5.6 5.6 0 0 0 6.8-7.3l-3.3 3.3-1-1Z"
            />
          }
          @case ('bell') {
            <path
              d="M12 2.4a6.4 6.4 0 0 1 6.4 6.4c0 4.4 1.6 5.6 2.4 6.8H3.2c.8-1.2 2.4-2.4 2.4-6.8A6.4 6.4 0 0 1 12 2.4Z"
            />
            <path d="M9.4 17.2h5.2a2.6 2.6 0 0 1-5.2 0Z" />
          }
          @default {
            <circle cx="12" cy="12" r="3.2" />
          }
        }
      </g>
    </svg>
  `,
  styles: `
    :host {
      align-items: center;
      display: inline-flex;
      justify-content: center;
    }
    svg {
      display: block;
    }
  `,
})
export class IconComponent {
  readonly name = input<IconName | string>('dot');
  readonly size = input(18);
  /** `gold` - золото листов, `plain` - плоский, в цвет текста. */
  readonly tone = input<'gold' | 'plain'>('gold');
  protected readonly gradient = `icon-gold-${++counter}`;
  protected readonly glyph = computed(() => aliases[this.name()] ?? this.name());
}
