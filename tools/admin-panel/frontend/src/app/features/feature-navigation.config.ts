import { FeatureNavigation } from '../core/navigation/feature-navigation';

/**
 * Карта панели. Разделов ровно четыре, и делятся они по тому, ЧТО человек
 * делает, а не по названиям модулей: правит содержимое мира, ищет запись в
 * базе, ведёт работу, обслуживает сервер.
 *
 * Отсюда же берётся верхнее меню и боковая панель - список один, поэтому
 * «Эффекты» вверху и «Эффекты окружения» сбоку разойтись больше не могут.
 * Порядок пунктов внутри раздела - по тому, как часто открывают.
 */
export const featureNavigation: readonly FeatureNavigation[] = [
  {
    id: 'modules',
    label: 'Мир',
    icon: 'world',
    matches: ['/world', '/loot', '/weather', '/environment', '/item-talents', '/professions'],
    placement: 'sidebar',
    home: '/world',
    items: [
      {
        label: 'Существа',
        route: '/loot/creatures',
        icon: 'loot',
        group: 'Добыча',
        hint: 'Все существа таблицей: отбор по рангу, уровню и наличию добычи.',
      },
      {
        label: 'Предмет',
        route: '/loot/items',
        icon: 'items',
        group: 'Добыча',
        hint: 'Откуда падает предмет: все пути через таблицы и ссылки.',
      },
      {
        label: 'Таблицы',
        route: '/loot/tables',
        icon: 'audit',
        group: 'Добыча',
        hint: 'Тринадцать таблиц добычи: записи, ссылки и группы.',
      },
      {
        label: 'Карта',
        route: '/weather/map',
        icon: 'weather',
        group: 'Погода',
        hint: 'Карта мира: выбрал зону - поставил погоду.',
      },
      {
        label: 'Фронты',
        route: '/weather/fronts',
        icon: 'weather',
        group: 'Погода',
        hint: 'Циклоны на картах: поставить свой, править и убрать.',
      },
      {
        label: 'Зоны',
        route: '/weather/zones',
        icon: 'weather',
        group: 'Погода',
        hint: 'Все зоны мира: климат по сезонам и перенос погоды соседям.',
      },
      {
        label: 'Настройки',
        route: '/weather/settings',
        icon: 'weather-settings',
        group: 'Погода',
        hint: 'Все числа модуля погоды без правки конфига и рестарта.',
      },
      {
        label: 'Правила по зонам',
        route: '/environment',
        icon: 'effects',
        group: 'Эффекты окружения',
        hint: 'Баффы и дебаффы по зонам: погода, время суток, пулы.',
      },
      {
        label: 'Категории и перки',
        route: '/item-talents',
        icon: 'talents',
        group: 'Таланты предметов',
        hint: 'Пробуждение снаряжения: категории, перки, пороги.',
      },
      {
        label: 'Типы предметов',
        route: '/professions/types',
        icon: 'professions',
        group: 'Профессии',
        hint: 'Что вообще можно ковать и из каких частей это собирается.',
      },
      {
        label: 'Материалы',
        route: '/professions/materials',
        icon: 'chest',
        group: 'Профессии',
        hint: 'Что кладут в ячейки схемы и чем украшают готовую вещь.',
      },
      {
        label: 'Рецепты',
        route: '/professions/recipes',
        icon: 'scroll',
        group: 'Профессии',
        hint: 'Набор по ячейкам и изделие на каждую ступень качества.',
      },
      {
        label: 'Именные',
        route: '/professions/named',
        icon: 'talents',
        group: 'Профессии',
        hint: 'Сочетания вставок, дающие основе собственный предмет.',
      },
      {
        label: 'Объединение',
        route: '/professions/merge',
        icon: 'wrench',
        group: 'Профессии',
        hint: 'Стол, где любая вещь плюс пять предметов дают готовый результат.',
      },
      {
        label: 'Связи',
        route: '/professions/relations',
        icon: 'module',
        group: 'Профессии',
        hint: 'Карта: что из чего выходит, включая общую диаграмму.',
      },
      {
        label: 'Справочники',
        route: '/professions/dicts',
        icon: 'tag',
        group: 'Профессии',
        hint: 'Род материала ячейки и тип вставки.',
      },
      {
        label: 'Баланс',
        route: '/professions/balance',
        icon: 'weather-settings',
        group: 'Профессии',
        hint: 'Качество изделия, требуемый уровень, кривая успеха и числа модуля.',
      },
      {
        label: 'Проверка',
        route: '/professions/preview',
        icon: 'search',
        group: 'Профессии',
        hint: 'Что выйдет у верстака с этим набором - без захода в игру.',
      },
      {
        label: 'Пул id',
        route: '/professions/pool',
        icon: 'key',
        group: 'Профессии',
        hint: 'Сколько заготовок осталось и что уже выдано.',
      },
    ],
  },
  {
    id: 'records',
    label: 'Справочники',
    icon: 'records',
    matches: ['/catalog'],
    placement: 'sidebar',
    showOnHome: true,
    home: '/catalog',
    items: [
      {
        label: 'Заклинания',
        route: '/catalog/spells',
        icon: 'spells',
        hint: 'Все заклинания клиента, правка своих, свои пулы id.',
      },
      {
        label: 'Предметы',
        route: '/catalog/items',
        icon: 'items',
        hint: 'item_template: поиск, копии в своих блоках и правка.',
      },
      {
        label: 'Предметы мира',
        route: '/catalog/world-items',
        icon: 'world-items',
        hint: 'Что разложено по карте и кто это забрал.',
      },
    ],
  },
  {
    id: 'workflow',
    label: 'Доска',
    icon: 'board',
    matches: ['/board'],
    items: [
      {
        label: 'Доска задач',
        route: '/board',
        icon: 'board',
        hint: 'Баги, идеи и задачи по модулям.',
      },
    ],
  },
  {
    id: 'settings',
    label: 'Сервер',
    icon: 'server',
    matches: ['/settings'],
    placement: 'sidebar',
    ownerOnly: true,
    items: [
      {
        label: 'Серверный патч',
        route: '/settings/server-patch',
        icon: 'server',
        hint: 'Применение правок в живом мире и миграции репозитория.',
      },
      {
        label: 'Клиентский патч',
        route: '/settings/client-patch',
        icon: 'patch',
        hint: 'Сборка MPQ и выкладка на CDN лаунчера.',
      },
      {
        label: 'Новости лаунчера',
        route: '/settings/cdn',
        icon: 'news',
        hint: 'Витрина лаунчера: лента новостей и подписи окна.',
      },
      {
        label: 'Люди и доступ',
        route: '/settings/users',
        icon: 'users',
        hint: 'Профили, роли и ссылки-приглашения.',
      },
      {
        label: 'Журнал изменений',
        route: '/settings/audit',
        icon: 'audit',
        hint: 'Кто, когда и что менял.',
      },
    ],
  },
];
