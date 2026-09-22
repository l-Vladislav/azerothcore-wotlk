import { Component, ElementRef, computed, inject, viewChild } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter, map, startWith } from 'rxjs';
import { AuthService } from '../core/auth.service';
import { DeployService } from '../core/deploy.service';
import {
  FeatureNavigation,
  FeatureNavigationRegistry,
} from '../core/navigation/feature-navigation';
import { SiteSidebarComponent } from '../shared/layout/site-sidebar.component';
import { ChangePasswordComponent } from '../shared/ui/change-password.component';
import { IconComponent } from '../shared/ui/icon.component';
import { QuickSearchComponent } from '../shared/ui/quick-search.component';
import { ToastHostComponent } from '../shared/ui/toast-host.component';

@Component({
  imports: [
    RouterLink,
    RouterLinkActive,
    RouterOutlet,
    SiteSidebarComponent,
    ChangePasswordComponent,
    QuickSearchComponent,
    ToastHostComponent,
    IconComponent,
  ],
  selector: 'app-shell',
  styleUrl: './shell.component.scss',
  templateUrl: './shell.component.html',
  host: {
    '(document:pointerdown)': 'dismissAccountMenu($event)',
    '(document:keydown.escape)': 'closeAccountMenu(true)',
  },
})
export class ShellComponent {
  private readonly accountMenu = viewChild<ElementRef<HTMLDetailsElement>>('accountMenu');

  dismissAccountMenu(event: PointerEvent): void {
    const menu = this.accountMenu()?.nativeElement;
    if (menu?.open && event.target instanceof Node && !menu.contains(event.target)) {
      this.closeAccountMenu();
    }
  }

  closeAccountMenu(restoreFocus = false): void {
    const menu = this.accountMenu()?.nativeElement;
    if (!menu?.open) return;
    menu.open = false;
    if (restoreFocus) menu.querySelector('summary')?.focus();
  }

  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly navigation = inject(FeatureNavigationRegistry);
  // Адрес нужен и боковой панели: по нему она показывает страницу второго
  // уровня (карточку существа), поэтому он не private.
  readonly currentUrl = toSignal(
    this.router.events.pipe(
      filter((event): event is NavigationEnd => event instanceof NavigationEnd),
      map((event) => event.urlAfterRedirects),
      startWith(this.router.url),
    ),
    { initialValue: this.router.url },
  );
  readonly feature = computed(() => this.navigation.findForUrl(this.currentUrl()));
  /** Разделы верхнего меню: список тот же, что у боковой панели и карты. */
  readonly sections = computed(() =>
    this.navigation.all().filter((section) => !section.ownerOnly || this.isOwner()),
  );
  /**
   * Раздел, который подсвечивается в верхнем меню. На «Обзоре» - никакой:
   * `findForUrl` там нарочно возвращает раздел с `showOnHome`, чтобы боковой
   * панели было что показать, и из-за этого вкладка «Справочники» горела
   * вместе с «Обзором».
   */
  readonly activeSection = computed(() =>
    this.currentUrl().split(/[?#]/, 1)[0] === '/' ? undefined : this.feature(),
  );

  sectionRoute(section: FeatureNavigation): string {
    return section.home ?? section.items[0]?.route ?? '/';
  }
  // Считается от `activeSection`, а не от `feature`: на «Обзоре» разделу
  // взяться неоткуда, и запасной вариант с `showOnHome` подсовывал в панель
  // «Справочники» - раздел, на котором мы не находимся. Там остаются только
  // быстрые ссылки.
  readonly sidebarFeature = computed(() => {
    const feature = this.activeSection();
    return feature?.placement === 'sidebar' || (feature?.items.length ?? 0) > 1
      ? feature
      : undefined;
  });
  readonly homeLinks = computed(() =>
    this.currentUrl().split(/[?#]/, 1)[0] === '/'
      ? [{ label: 'Доска', route: '/board', icon: 'board' }]
      : [],
  );
  readonly isOwner = computed(() => this.auth.actor()?.role === 'owner');

  // Сколько правок ждёт живого мира. Перехватчик пересчитывает счёт после
  // каждой правки, здесь - только первый вопрос при запуске панели.
  private readonly deploy = inject(DeployService);
  readonly waiting = this.deploy.waiting;

  constructor() {
    void this.deploy.refresh();
  }

  async logout(): Promise<void> {
    await this.auth.logout();
    await this.router.navigateByUrl('/login');
  }
}
