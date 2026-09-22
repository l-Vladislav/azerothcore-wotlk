import { Component, computed, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { FeatureNavigationRegistry, groupItems } from '../../core/navigation/feature-navigation';
import { IconComponent } from '../../shared/ui/icon.component';

/**
 * Посадочная раздела «Мир» - такая же, как у «Справочников»: список того, что
 * в разделе есть, чтобы не искать страницу в меню на ощупь.
 *
 * Отличие в том, что страницы тут от РАЗНЫХ МОДУЛЕЙ, и лежат они группами по
 * модулю: «Погода» и «Настройки» - одно хозяйство (`mod-advanced-weather`), а
 * «Существа», «Предмет» и «Таблицы» - три взгляда на одну добычу. Список
 * берётся из общей карты панели, поэтому разойтись с меню он не может.
 */
@Component({
  imports: [RouterLink, IconComponent],
  selector: 'app-world-home-page',
  styleUrl: './world-home.page.scss',
  templateUrl: './world-home.page.html',
})
export class WorldHomePage {
  private readonly navigation = inject(FeatureNavigationRegistry);

  /** Группы модулей раздела - тот же список и тот же порядок, что в меню. */
  readonly groups = computed(() => {
    const feature = this.navigation.all().find((section) => section.id === 'modules');
    return groupItems(feature?.items ?? []);
  });
}
