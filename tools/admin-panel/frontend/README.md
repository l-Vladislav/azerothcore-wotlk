# Admin panel web

Новый Angular-фронтенд для `tools/admin-panel`. FastAPI остаётся единственным
бэкендом: приложение использует существующие `/api/*` и сессионные cookie.
Старые страницы и новый фронтенд могут работать параллельно.

## Development server

To start a local development server, run:

```bash
npm start
```

Откройте `http://localhost:4200/`. Запросы `/api` передаются FastAPI через
`proxy.conf.json`; по умолчанию он ожидается на `127.0.0.1:8091`.

## Состояние переноса

- Уже на Angular: вход, приглашения, смена пароля, общий каркас, обзор, доска,
  каталог заклинаний и предметов, мастерская заклинаний (с выбором иконки и
  подписью «ждут рестарта»), предметы мира, клиентский патч, пользователи и
  журнал изменений, погода с настройками модуля, эффекты окружения, таланты
  предметов, **добыча** (три страницы: моб, предмет, таблица) и
  **продвинутые профессии** - все десять разделов.
- Профессии разъехались из десяти вкладок одного файла в десять адресов:
  `/professions/types`, `/materials`, `/recipes`, `/named`, `/merge`,
  `/relations`, `/dicts`, `/balance`, `/preview`, `/pool`. Старая страница
  `/aprof.html` при этом осталась на месте - два фронта живут рядом.
- Карта связей (`/professions/relations`) держит три вида: две стороны одной
  связи карточками и общую **диаграмму на canvas** (четыре тысячи узлов, свой
  отбор, масштаб и раскрытие узла на месте). Разметкой её рисовать нельзя -
  вкладка «Именные» уже показывала, чем это кончается.

## Проверка страниц

```bash
npm run build
node ../scripts/check_spa.js
```

Скрипт поднимает сборку рядом с ЖИВОЙ панелью PTR (dist отдаётся локально,
`/api` проксируется) и открывает страницы в headless-браузере: рисуются ли они,
работают ли переходы, нет ли ошибок в консоли. jsdom для этого не годится - он
не исполняет `<script type="module">`.

## Code scaffolding

Angular CLI includes powerful code scaffolding tools. To generate a new component, run:

```bash
ng generate component component-name
```

For a complete list of available schematics (such as `components`, `directives`, or `pipes`), run:

```bash
ng generate --help
```

## Building

To build the project run:

```bash
ng build
```

This will compile your project and store the build artifacts in the `dist/` directory. By default, the production build optimizes your application for performance and speed.

## Running unit tests

To execute unit tests with the [Vitest](https://vitest.dev/) test runner, use the following command:

```bash
ng test
```

## Running end-to-end tests

For end-to-end (e2e) testing, run:

```bash
ng e2e
```

Angular CLI does not come with an end-to-end testing framework by default. You can choose one that suits your needs.

## Additional Resources

For more information on using the Angular CLI, including detailed command references, visit the [Angular CLI Overview and Command Reference](https://angular.dev/tools/cli) page.
