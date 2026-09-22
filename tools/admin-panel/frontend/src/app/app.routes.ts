import { Routes } from '@angular/router';
import { authGuard } from './core/auth.guard';

/**
 * Каждая страница грузится отдельным куском (`loadComponent`), а не всем
 * приложением сразу. Иначе вход в панель тянет и карту погоды, и каталог на
 * четыреста тысяч предметов, и профессии - при том, что открывают обычно одну
 * страницу. Службы страницы (`*Api`) идут её же провайдерами и уезжают в тот
 * же кусок.
 */
export const routes: Routes = [
  {
    path: 'login',
    loadComponent: () => import('./features/login/login.page').then((m) => m.LoginPage),
    title: 'Вход — Панель управления',
  },
  {
    path: 'join',
    loadComponent: () => import('./features/join/join.page').then((m) => m.JoinPage),
    title: 'Приглашение — Панель управления',
  },
  {
    path: '',
    loadComponent: () => import('./layout/shell.component').then((m) => m.ShellComponent),
    canActivate: [authGuard],
    children: [
      {
        path: '',
        loadComponent: () =>
          import('./features/dashboard/dashboard.page').then((m) => m.DashboardPage),
        title: 'Обзор — Панель управления',
      },
      {
        path: 'board',
        loadComponent: () => import('./features/board/board.page').then((m) => m.BoardPage),
        title: 'Доска задач — Панель управления',
      },

      // --- справочники ------------------------------------------------------
      {
        path: 'catalog',
        loadComponent: () =>
          import('./features/records/catalog-home/catalog-home.page').then(
            (m) => m.CatalogHomePage,
          ),
        title: 'Каталог — Панель управления',
      },
      // Каталог и мастерская были двумя страницами про одно и то же -
      // осталась одна: в ней и поиск по всему клиенту, и правка своих.
      {
        path: 'catalog/spells',
        loadComponent: () =>
          import('./features/records/spell-workshop/spell-list.page').then((m) => m.SpellListPage),
        title: 'Заклинания — Панель управления',
      },
      {
        path: 'catalog/spells/:id',
        loadComponent: () =>
          import('./features/records/spell-workshop/spell-card.page').then((m) => m.SpellCardPage),
        title: 'Заклинание — Панель управления',
      },
      {
        path: 'catalog/workshop',
        redirectTo: 'catalog/workshop/spells',
        pathMatch: 'full',
      },
      { path: 'catalog/workshop/spells', redirectTo: 'catalog/spells', pathMatch: 'full' },
      // Мастерская предметов и каталог были одной и той же страницей под
      // двумя адресами - осталась одна. Маршрут живёт ради старых ссылок.
      {
        path: 'catalog/workshop/items',
        redirectTo: 'catalog/items',
        pathMatch: 'full',
      },
      {
        path: 'catalog/items',
        loadComponent: () =>
          import('./features/records/item-catalog/item-list.page').then((m) => m.ItemListPage),
        title: 'Предметы — Панель управления',
      },
      {
        path: 'catalog/items/:entry',
        loadComponent: () =>
          import('./features/records/item-catalog/item-card.page').then((m) => m.ItemCardPage),
        title: 'Предмет — Панель управления',
      },
      {
        path: 'catalog/world-items',
        loadComponent: () =>
          import('./features/records/world-items/world-items.page').then((m) => m.WorldItemsPage),
        title: 'Предметы мира — Панель управления',
      },
      {
        path: 'catalog/world-items/:id',
        loadComponent: () =>
          import('./features/records/world-items/world-item.page').then((m) => m.WorldItemPage),
        title: 'Размещение — Панель управления',
      },

      // --- мир --------------------------------------------------------------
      {
        path: 'world',
        loadComponent: () =>
          import('./features/world-home/world-home.page').then((m) => m.WorldHomePage),
        title: 'Мир — Панель управления',
      },
      { path: 'loot', redirectTo: 'loot/creatures', pathMatch: 'full' },
      {
        path: 'loot/creatures',
        loadComponent: () =>
          import('./features/loot/creature-list.page').then((m) => m.CreatureListPage),
        title: 'Существа — Панель управления',
      },
      {
        path: 'loot/creatures/:entry',
        loadComponent: () =>
          import('./features/loot/creature-loot.page').then((m) => m.CreatureLootPage),
        title: 'Добыча существа — Панель управления',
      },
      {
        path: 'loot/items',
        loadComponent: () => import('./features/loot/item-drops.page').then((m) => m.ItemDropsPage),
        title: 'Добыча · Предмет — Панель управления',
      },
      {
        path: 'loot/tables',
        loadComponent: () =>
          import('./features/loot/loot-tables.page').then((m) => m.LootTablesPage),
        title: 'Добыча · Таблица — Панель управления',
      },
      {
        path: 'weather',
        redirectTo: 'weather/zones',
        pathMatch: 'full',
      },
      {
        path: 'weather/zones',
        loadComponent: () =>
          import('./features/weather/weather-zones.page').then((m) => m.WeatherZonesPage),
        title: 'Зоны — Панель управления',
      },
      {
        path: 'weather/zones/:zone',
        loadComponent: () => import('./features/weather/weather.page').then((m) => m.WeatherPage),
        title: 'Зона — Панель управления',
      },
      {
        path: 'weather/map',
        loadComponent: () =>
          import('./features/weather/weather-map.page').then((m) => m.WeatherMapPage),
        title: 'Карта погоды — Панель управления',
      },
      {
        path: 'weather/fronts',
        loadComponent: () =>
          import('./features/weather/weather-fronts.page').then((m) => m.WeatherFrontsPage),
        title: 'Фронты погоды — Панель управления',
      },
      {
        path: 'weather/settings',
        loadComponent: () =>
          import('./features/weather/weather-settings.page').then((m) => m.WeatherSettingsPage),
        title: 'Настройки погоды — Панель управления',
      },
      {
        path: 'environment',
        loadComponent: () =>
          import('./features/environment/environment-zones.page').then(
            (m) => m.EnvironmentZonesPage,
          ),
        title: 'Эффекты окружения — Панель управления',
      },
      {
        path: 'environment/zones/:zone',
        loadComponent: () =>
          import('./features/environment/environment.page').then((m) => m.EnvironmentPage),
        title: 'Эффекты окружения — Панель управления',
      },
      {
        path: 'item-talents',
        loadComponent: () =>
          import('./features/item-talents/item-talents.page').then((m) => m.ItemTalentsPage),
        title: 'Таланты предметов — Панель управления',
      },
      { path: 'professions', redirectTo: 'professions/types', pathMatch: 'full' },
      {
        path: 'professions/types',
        loadComponent: () =>
          import('./features/professions/types.page').then((m) => m.ProfessionsTypesPage),
        title: 'Типы предметов — Панель управления',
      },
      {
        path: 'professions/materials',
        loadComponent: () =>
          import('./features/professions/materials.page').then((m) => m.ProfessionsMaterialsPage),
        title: 'Материалы — Панель управления',
      },
      {
        path: 'professions/recipes',
        loadComponent: () =>
          import('./features/professions/recipes.page').then((m) => m.ProfessionsRecipesPage),
        title: 'Рецепты — Панель управления',
      },
      {
        path: 'professions/named',
        loadComponent: () =>
          import('./features/professions/named.page').then((m) => m.ProfessionsNamedPage),
        title: 'Именные сочетания — Панель управления',
      },
      {
        path: 'professions/relations',
        loadComponent: () =>
          import('./features/professions/relations.page').then((m) => m.ProfessionsRelationsPage),
        title: 'Связи — Панель управления',
      },
      {
        path: 'professions/merge',
        loadComponent: () =>
          import('./features/professions/merge.page').then((m) => m.ProfessionsMergePage),
        title: 'Объединение — Панель управления',
      },
      {
        path: 'professions/preview',
        loadComponent: () =>
          import('./features/professions/preview.page').then((m) => m.ProfessionsPreviewPage),
        title: 'Проверка набора — Панель управления',
      },
      {
        path: 'professions/balance',
        loadComponent: () =>
          import('./features/professions/balance.page').then((m) => m.ProfessionsBalancePage),
        title: 'Баланс ковки — Панель управления',
      },
      {
        path: 'professions/pool',
        loadComponent: () =>
          import('./features/professions/pool.page').then((m) => m.ProfessionsPoolPage),
        title: 'Пул id — Панель управления',
      },
      {
        path: 'professions/dicts',
        loadComponent: () =>
          import('./features/professions/dicts.page').then((m) => m.ProfessionsDictsPage),
        title: 'Справочники профессий — Панель управления',
      },

      // --- сервер -----------------------------------------------------------
      { path: 'settings', redirectTo: 'settings/server-patch', pathMatch: 'full' },
      {
        path: 'settings/server-patch',
        loadComponent: () =>
          import('./features/settings/deploy/deploy.page').then((m) => m.DeployPage),
        title: 'Серверный патч — Панель управления',
      },
      {
        path: 'settings/client-patch',
        loadComponent: () =>
          import('./features/settings/client-patch/client-patch.page').then(
            (m) => m.ClientPatchPage,
          ),
        title: 'Клиентский патч — Панель управления',
      },
      {
        path: 'settings/cdn',
        loadComponent: () => import('./features/settings/cdn/cdn.page').then((m) => m.CdnPage),
        title: 'Витрина лаунчера — Панель управления',
      },
      {
        path: 'settings/users',
        loadComponent: () =>
          import('./features/settings/users/users.page').then((m) => m.UsersPage),
        title: 'Люди и доступ — Панель управления',
      },
      {
        path: 'settings/audit',
        loadComponent: () =>
          import('./features/settings/audit/audit.page').then((m) => m.AuditPage),
        title: 'Журнал изменений — Панель управления',
      },

      // Витрина набора элементов: смотреть кромки и состояния живьём.
      {
        path: 'style-kit',
        loadComponent: () =>
          import('./features/style-kit/style-kit.page').then((m) => m.StyleKitPage),
        title: 'Кит стайлгайда — Панель управления',
      },

      // --- прежние адреса ---------------------------------------------------
      { path: 'users', redirectTo: 'settings/users', pathMatch: 'full' },
      { path: 'spells', redirectTo: 'catalog/spells', pathMatch: 'full' },
      { path: 'items', redirectTo: 'catalog/items', pathMatch: 'full' },
      { path: 'world-items', redirectTo: 'catalog/world-items', pathMatch: 'full' },
    ],
  },
  { path: '**', redirectTo: '' },
];
