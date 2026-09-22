import { NgTemplateOutlet } from '@angular/common';
import { Component, computed, inject, input } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import {
  FeatureNavItem,
  FeatureNavigation,
  groupItems,
} from '../../core/navigation/feature-navigation';
import { IconComponent } from '../ui/icon.component';
import { SidebarService } from '../../core/sidebar/sidebar.service';

@Component({
  imports: [NgTemplateOutlet, RouterLink, RouterLinkActive, IconComponent],
  selector: 'app-site-sidebar',
  styleUrl: './site-sidebar.component.scss',
  host: {
    '[class.collapsed]': 'sidebar.collapsed()',
    '[class.empty]': '!hasContent()',
  },
  template: `
    @if (hasContent()) {
      <aside [class.collapsed]="sidebar.collapsed()">
        <button
          type="button"
          class="forge-collapse-btn toggle"
          (click)="sidebar.toggle()"
          [attr.aria-expanded]="!sidebar.collapsed()"
          [attr.aria-label]="
            sidebar.collapsed() ? 'Развернуть боковую панель' : 'Свернуть боковую панель'
          "
        >
          @if (!sidebar.collapsed()) {
            <span>Свернуть</span>
          }
          <span class="arrow">{{ sidebar.collapsed() ? '»' : '«' }}</span>
        </button>
        @if (!sidebar.collapsed()) {
          <div class="sidebar-body">
            @if (feature(); as activeFeature) {
              <!-- Названия раздела тут нет нарочно: оно уже стоит вкладкой в
                   верхнем меню, и второй раз повторять его незачем. -->
              <nav class="feature-navigation" [attr.aria-label]="activeFeature.label">
                @for (group of groups(); track group.label) {
                  @if (group.label) {
                    <h3 class="module-title">{{ group.label }}</h3>
                  }
                  @for (item of group.items; track item.route) {
                    <a
                      class="forge-nav-item is-compact"
                      routerLinkActive="is-active"
                      [routerLinkActiveOptions]="matchFor(item)"
                      [routerLink]="item.route"
                      >{{ item.label }}</a
                    >
                  }
                }
              </nav>
            }
            @if (homeLinks().length) {
              <nav class="feature-navigation home-navigation" aria-label="Быстрые ссылки">
                @for (item of homeLinks(); track item.route) {
                  <a
                    class="forge-nav-item is-compact home-feature-link"
                    routerLinkActive="is-active"
                    [routerLink]="item.route"
                  >
                    {{ item.label }}
                  </a>
                }
              </nav>
            }
            @if (sidebar.content(); as content) {
              <h2>{{ content.label }}</h2>
              <ng-container [ngTemplateOutlet]="content.template" />
            }
          </div>
        } @else {
          @if (feature(); as activeFeature) {
            <nav class="collapsed-navigation" [attr.aria-label]="activeFeature.label">
              <div class="collapsed-feature-items">
                @for (item of items(); track item.route) {
                  <a
                    class="forge-btn is-icon"
                    routerLinkActive="is-active"
                    [routerLinkActiveOptions]="matchFor(item)"
                    [routerLink]="item.route"
                    [attr.aria-label]="item.label"
                    [title]="(item.group ? item.group + ': ' : '') + item.label"
                  >
                    <app-icon [name]="item.icon ?? 'dot'" />
                  </a>
                }
              </div>
            </nav>
          }
          @if (homeLinks().length) {
            <nav class="collapsed-navigation" aria-label="Быстрые ссылки">
              @for (item of homeLinks(); track item.route) {
                <a
                  class="forge-btn is-icon"
                  routerLinkActive="is-active"
                  [routerLink]="item.route"
                  [attr.aria-label]="item.label"
                  [title]="item.label"
                >
                  <app-icon [name]="item.icon ?? 'dot'" />
                </a>
              }
            </nav>
          }
        }
      </aside>
    }
  `,
})
export class SiteSidebarComponent {
  readonly sidebar = inject(SidebarService);
  readonly feature = input<FeatureNavigation>();
  readonly homeLinks = input<readonly FeatureNavItem[]>([]);
  /**
   * Подсветка пункта - по ТОЧНОМУ совпадению пути. По умолчанию Angular
   * считает пункт активным и когда адрес лишь начинается с него: карточка
   * `/loot/creatures/17` зажигала «Существа», а `/weather/settings` - «Карту
   * и режиссёра». Параметры адреса при этом не в счёт: отбор списка живёт
   * именно в них.
   */
  readonly exact = {
    paths: 'exact',
    queryParams: 'ignored',
    matrixParams: 'ignored',
    fragment: 'ignored',
  } as const;

  readonly items = computed(() => this.feature()?.items ?? []);

  /** Пункты раздела, разложенные по модулям. */
  readonly groups = computed(() => groupItems(this.items()));

  /**
   * Как считать пункт открытым. По умолчанию Angular зажигает пункт, когда
   * адрес лишь НАЧИНАЕТСЯ с его пути, и это ровно то, что нужно странице с
   * подстраницами: карточка `/loot/creatures/17` - всё ещё «Существа».
   *
   * Точное совпадение нужно там, где один пункт - начало другого:
   * `/weather` и `/weather/settings`. Иначе на настройках горели бы оба.
   * Условие считается по самому списку, а не прописано руками, - чтобы не
   * разъехалось при следующей новой странице.
   */
  matchFor(item: FeatureNavItem): {
    paths: 'exact' | 'subset';
    queryParams: 'ignored';
    matrixParams: 'ignored';
    fragment: 'ignored';
  } {
    const nested = this.items().some(
      (other) => other !== item && other.route.startsWith(item.route + '/'),
    );
    return {
      paths: nested ? 'exact' : 'subset',
      queryParams: 'ignored',
      matrixParams: 'ignored',
      fragment: 'ignored',
    };
  }

  /**
   * Есть ли вообще что показывать. Панель кормится из трёх мест: разделы
   * текущей страницы, быстрые ссылки на «Обзоре» и своя врезка страницы
   * (`sidebar.register`). Пусто во всех трёх - панели нет совсем, вместе с
   * кнопкой-стрелкой: сворачивать пустоту незачем, а полоса у края экрана
   * выглядит как поломка.
   */
  readonly hasContent = computed(
    () => !!this.feature() || this.homeLinks().length > 0 || !!this.sidebar.content(),
  );
}
