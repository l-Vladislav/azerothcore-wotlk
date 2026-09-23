import { Component } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { featureNavigation } from '../feature-navigation.config';

/** Страницы профессий в том порядке, в каком их показывает боковая панель. */
const PAGES = featureNavigation
  .flatMap((feature) => feature.items)
  .filter((item) => item.group === 'Профессии');

/**
 * Вкладки страниц профессий - вместо заголовка страницы. Какая страница
 * открыта, видно по выбранной вкладке, и заголовок рядом повторял бы её.
 *
 * Список не свой, а из карты панели (`feature-navigation.config.ts`): оттуда
 * же строится боковая панель, и подписи в двух местах разойтись не могут.
 */
@Component({
  selector: 'app-professions-tabs',
  imports: [RouterLink, RouterLinkActive],
  template: `
    <nav class="forge-tabbar" aria-label="Страницы профессий">
      @for (page of pages; track page.route) {
        <a
          class="forge-tab is-compact"
          routerLinkActive="is-active"
          ariaCurrentWhenActive="page"
          [routerLink]="page.route"
          [title]="page.hint ?? ''"
          >{{ page.label }}</a
        >
      }
    </nav>
  `,
  styles: `
    :host {
      display: block;
      min-width: 0;
    }
  `,
})
export class ProfessionsTabsComponent {
  protected readonly pages = PAGES;
}
