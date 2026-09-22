import {
  EnvironmentProviders,
  Injectable,
  InjectionToken,
  inject,
  makeEnvironmentProviders,
} from '@angular/core';

export interface FeatureNavItem {
  label: string;
  route: string;
  icon?: string;
  /** Строка для карты на «Обзоре»: чем эта страница занимается. */
  hint?: string;
  /**
   * Модуль, которому страница принадлежит («Добыча», «Погода», …). Пункты с
   * одним именем идут в меню и на посадочной одной группой - иначе шесть
   * страниц от пяти разных модулей лежат плоским списком, и по нему не
   * видно, что «Погода» и «Настройки погоды» - одно хозяйство.
   */
  group?: string;
}

/** Группа пунктов одного модуля - так их отдаёт `groupItems`. */
export interface FeatureNavGroup {
  label: string;
  items: readonly FeatureNavItem[];
}

/**
 * Раскладывает пункты раздела по модулям, сохраняя порядок. Пункты без
 * `group` собираются в группу без заголовка в самом начале.
 */
export function groupItems(items: readonly FeatureNavItem[]): readonly FeatureNavGroup[] {
  const out: FeatureNavGroup[] = [];
  for (const item of items) {
    const label = item.group ?? '';
    const last = out[out.length - 1];
    if (last && last.label === label) {
      (last.items as FeatureNavItem[]).push(item);
    } else {
      out.push({ label, items: [item] });
    }
  }
  return out;
}

export interface FeatureNavigation {
  id: string;
  label: string;
  icon?: string;
  matches: readonly string[];
  items: readonly FeatureNavItem[];
  placement?: 'header' | 'sidebar';
  showOnHome?: boolean;
  /** Раздел для владельца: остальным его не показываем и не дразним. */
  ownerOnly?: boolean;
  /** Куда ведёт пункт верхнего меню. По умолчанию - первая страница раздела. */
  home?: string;
}

export const FEATURE_NAVIGATION = new InjectionToken<FeatureNavigation>('FEATURE_NAVIGATION');

export function provideFeatureNavigation(
  ...features: readonly FeatureNavigation[]
): EnvironmentProviders {
  return makeEnvironmentProviders(
    features.map((feature) => ({
      multi: true,
      provide: FEATURE_NAVIGATION,
      useValue: feature,
    })),
  );
}

@Injectable({ providedIn: 'root' })
export class FeatureNavigationRegistry {
  private readonly features = (inject(FEATURE_NAVIGATION, { optional: true }) ?? []) as
    readonly FeatureNavigation[] | readonly [];

  /** Все разделы по порядку: верхнее меню и карта на «Обзоре» берут их отсюда. */
  all(): readonly FeatureNavigation[] {
    return this.features;
  }

  findForUrl(url: string): FeatureNavigation | undefined {
    return (
      this.features.find((feature) => feature.matches.some((match) => url.startsWith(match))) ??
      (url === '/' ? this.features.find((feature) => feature.showOnHome) : undefined)
    );
  }
}
