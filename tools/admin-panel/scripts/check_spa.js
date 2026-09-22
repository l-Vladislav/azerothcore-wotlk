// Прогон страниц нового фронтенда панели против ЖИВОЙ панели PTR.
//
//   cd tools/admin-panel/frontend && npm run build
//   node tools/admin-panel/scripts/check_spa.js
//
// Проверяется собранное приложение, а не исходники: маленький сервер отдаёт
// dist и проксирует /api на панель, а страницу открывает headless-браузер.
// jsdom тут не годится - он не исполняет `<script type="module">`, а Angular
// собирается только в модули; поэтому берём Edge или Chrome, который на
// машине уже есть, и правим им по CDP (у Node с 21-й версии свой WebSocket,
// сторонних модулей не нужно).
//
// Ошибка в консоли страницы - это провал: в браузере она выглядит пустым
// местом, а не сообщением.
//
// Адрес и токен - из окружения или из корневого .env (ADMIN_PANEL_BIND,
// ADMIN_PANEL_TOKEN). В файл их не вписывать: .env не в репозитории.
const { spawn } = require("child_process");
const fs = require("fs");
const http = require("http");
const os = require("os");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..", "..");
const DIST = path.join(__dirname, "..", "frontend", "dist", "admin-panel-web", "browser");

const BROWSERS = [
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
];

function env(name, fallback) {
  if (process.env[name]) return process.env[name];
  const file = path.join(ROOT, ".env");
  if (fs.existsSync(file)) {
    for (const line of fs.readFileSync(file, "utf8").split("\n")) {
      if (line.trim().startsWith(name + "=")) return line.split("=")[1].trim();
    }
  }
  return fallback;
}

const PANEL_HOST = env("ADMIN_PANEL_BIND", "127.0.0.1");
const TOKEN = env("ADMIN_PANEL_TOKEN", "");

const failures = [];
function check(name, ok, detail) {
  console.log((ok ? "ok   " : "FAIL ") + name + (detail ? ": " + detail : ""));
  if (!ok) failures.push(name);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const TYPES = {
  ".js": "text/javascript",
  ".css": "text/css",
  ".html": "text/html",
  ".ico": "image/x-icon",
  ".png": "image/png",
  ".json": "application/json",
};

// Статика из dist плюс /api на панель. Любой неизвестный путь - index.html:
// маршрутизацией занимается само приложение.
function serve() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      if (req.url.startsWith("/api/")) {
        // Токен берём У СТРАНИЦЫ, когда она его прислала: подставляя свой
        // поверх, стенд чинил бы за приложение любую потерянную сессию - и
        // проверка «401 возвращает на вход» мерила бы прокси, а не панель.
        const proxy = http.request(
          {
            host: PANEL_HOST,
            port: 8091,
            path: req.url,
            method: req.method,
            headers: {
              "X-Admin-Token": req.headers["x-admin-token"] || TOKEN,
              "content-type": "application/json",
            },
          },
          (answer) => {
            res.writeHead(answer.statusCode, answer.headers);
            answer.pipe(res);
          },
        );
        proxy.on("error", (error) => {
          res.writeHead(502, { "content-type": "application/json" });
          res.end(JSON.stringify({ detail: "панель недоступна: " + error.message }));
        });
        req.pipe(proxy);
        return;
      }
      const name = req.url.split("?")[0];
      let file = path.join(DIST, name);
      if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
        file = path.join(DIST, "index.html");
      }
      res.writeHead(200, {
        "content-type": TYPES[path.extname(file)] || "application/octet-stream",
      });
      res.end(fs.readFileSync(file));
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function json(url) {
  return new Promise((resolve, reject) => {
    http
      .get(url, (res) => {
        let body = "";
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(body));
          } catch (error) {
            reject(error);
          }
        });
      })
      .on("error", reject);
  });
}

async function browser() {
  const exe = BROWSERS.find((candidate) => fs.existsSync(candidate));
  if (!exe) throw new Error("не нашли ни Edge, ни Chrome - проверять нечем");
  const port = 9200 + Math.floor(Math.random() * 300);
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), "loot-check-"));
  const child = spawn(exe, [
    "--headless=new",
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
    "--remote-debugging-port=" + port,
    "--user-data-dir=" + profile,
    "about:blank",
  ]);
  child.on("error", () => {});
  for (let attempt = 0; attempt < 60; attempt += 1) {
    try {
      const version = await json(`http://127.0.0.1:${port}/json/version`);
      return { child, port, exe, version, profile };
    } catch {
      await sleep(250);
    }
  }
  child.kill();
  throw new Error("браузер не поднял отладочный порт");
}

async function connect(wsUrl) {
  const socket = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => {
    socket.onopen = resolve;
    socket.onerror = () => reject(new Error("не подключились к " + wsUrl));
  });
  let id = 0;
  const pending = new Map();
  const watchers = [];
  socket.onmessage = (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      pending.get(message.id)(message);
      pending.delete(message.id);
    } else {
      watchers.forEach((watch) => watch(message));
    }
  };
  return {
    send(method, params = {}) {
      const mine = (id += 1);
      socket.send(JSON.stringify({ id: mine, method, params }));
      return new Promise((resolve, reject) => {
        pending.set(mine, (message) =>
          message.error ? reject(new Error(method + ": " + message.error.message)) : resolve(message.result),
        );
      });
    },
    on(watch) {
      watchers.push(watch);
    },
    close() {
      socket.close();
    },
  };
}

// Одна вкладка на маршрут: собственная консоль и чистое состояние приложения.
async function page(debugPort, url) {
  const target = await json(`http://127.0.0.1:${debugPort}/json/new?${encodeURIComponent("about:blank")}`).catch(
    async () => {
      // У свежих сборок /json/new открывается только через PUT.
      const answer = await new Promise((resolve, reject) => {
        const request = http.request(
          {
            host: "127.0.0.1",
            port: debugPort,
            path: "/json/new?" + encodeURIComponent("about:blank"),
            method: "PUT",
          },
          (res) => {
            let body = "";
            res.on("data", (chunk) => (body += chunk));
            res.on("end", () => resolve(JSON.parse(body)));
          },
        );
        request.on("error", reject);
        request.end();
      });
      return answer;
    },
  );

  const client = await connect(target.webSocketDebuggerUrl);
  const errors = [];
  client.on((message) => {
    if (message.method === "Runtime.exceptionThrown") {
      const details = message.params.exceptionDetails;
      errors.push(details.exception?.description || details.text);
    }
    if (message.method === "Runtime.consoleAPICalled" && message.params.type === "error") {
      errors.push(message.params.args.map((arg) => arg.value ?? arg.description).join(" "));
    }
  });
  await client.send("Runtime.enable");
  await client.send("Page.enable");
  await client.send("Page.addScriptToEvaluateOnNewDocument", {
    source: `localStorage.setItem('adminToken', ${JSON.stringify(TOKEN)});`,
  });
  await client.send("Page.navigate", { url });

  const evaluate = async (expression) => {
    const result = await client.send("Runtime.evaluate", {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.exception?.description || "ошибка в выражении");
    }
    return result.result.value;
  };

  // Сорок секунд, а не двадцать пять: база у панели общая с PTR-сервером, и
  // под нагрузкой страница иногда открывается дольше - это повод подождать, а
  // не повод объявить поломку.
  const until = async (expression, what, timeout = 40000) => {
    const started = Date.now();
    for (;;) {
      const value = await evaluate(expression);
      if (value) return value;
      if (Date.now() - started > timeout) throw new Error("не дождались: " + what);
      await sleep(150);
    }
  };

  return {
    evaluate,
    until,
    errors,
    async close() {
      client.close();
      await json(`http://127.0.0.1:${debugPort}/json/close/${target.id}`).catch(() => {});
    },
  };
}

const textOf = (selector) =>
  `(() => { const node = document.querySelector(${JSON.stringify(selector)});
            return node ? node.textContent.replace(/\\s+/g, ' ').trim() : null; })()`;
const countOf = (selector) => `document.querySelectorAll(${JSON.stringify(selector)}).length`;
/** Свойство из вычисленного стиля первого совпавшего узла - цвет, гарнитура. */
const style = (selector, prop) =>
  `(() => { const node = document.querySelector(${JSON.stringify(selector)});
            return node ? getComputedStyle(node)[${JSON.stringify(prop)}] : null; })()`;
const clickNth = (selector, index) =>
  `(() => { const nodes = document.querySelectorAll(${JSON.stringify(selector)});
            if (!nodes[${index}]) return false; nodes[${index}].click(); return true; })()`;

async function main() {
  if (!fs.existsSync(DIST)) {
    console.error("Сборки нет: сперва `cd tools/admin-panel/frontend && npm run build`.");
    process.exit(2);
  }
  const server = await serve();
  const port = server.address().port;
  const engine = await browser();
  const base = `http://127.0.0.1:${port}`;
  console.log(`панель: ${PANEL_HOST}:8091 · стенд: ${base}`);
  console.log(`браузер: ${engine.version["User-Agent"] || engine.exe}\n`);

  try {
    // --- Добыча: список существ ----------------------------------------------
    //
    // Список и карточка - ДВЕ РАЗНЫЕ СТРАНИЦЫ. Выбор строки уходит в адрес
    // (`/loot/creatures/16379`), а не в параметр, поэтому и проверяем адрес:
    // ссылка на существо должна открывать существо.
    {
      const tab = await page(engine.port, `${base}/loot/creatures`);
      await tab.until(countOf("app-creature-list-page"), "страница «Существа»");
      check(
        "Существа: имя страницы во вкладке браузера",
        (await tab.evaluate("document.title")).startsWith("Существа"),
        await tab.evaluate("document.title"),
      );
      check("Существа: заголовка-дубля нет", (await tab.evaluate(countOf("app-creature-list-page h1"))) === 0);

      const rows = await tab.until(countOf("tbody tr"), "таблица существ");
      check("Существа: таблица", rows > 0, rows + " строк");
      const foot = await tab.evaluate(textOf(".table-foot .summary"));
      check("Существа: подвал считает всех", /из \d{3,}/.test(foot ?? ""), foot);
      check("Существа: колонка видов добычи", (await tab.evaluate(countOf("td.kinds"))) === rows);

      await tab.evaluate(clickNth("tbody tr", 0));
      const at = await tab.until(
        `/\\/loot\\/creatures\\/\\d+/.test(location.pathname) ? location.pathname : 0`,
        "переход на карточку существа",
      );
      check("Существа: строка ведёт на карточку", !!at, at);
      check("Существа: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Добыча: карточка существа -------------------------------------------
    {
      const tab = await page(engine.port, `${base}/loot/creatures/16379`);
      await tab.until(countOf("app-loot-tree .lootrow"), "дерево добычи");
      check("Существо: дерево добычи рисуется", true, (await tab.evaluate(textOf(".lootrow"))).slice(0, 70));
      check("Существо: шанс с полоской", (await tab.evaluate(countOf(".chance .bar i"))) > 0);
      check("Существо: правка доступна владельцу", (await tab.evaluate(countOf(".tools .link"))) > 0);
      check("Существо: есть возврат к списку", (await tab.evaluate(countOf(".back"))) > 0);
      // Своего пункта у карточки в меню НЕТ - открытой считается страница
      // списка: карточка её подстраница, а не сосед.
      const menu = await tab.evaluate(
        `[...document.querySelectorAll('app-site-sidebar a.is-active')]
           .map((a) => a.getAttribute('title') || a.textContent.trim()).join(', ')`,
      );
      check("Существо: в меню открыты «Существа»", menu === "Добыча: Существа", menu);
      check("Существо: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Мир: посадочная по модулям ------------------------------------------
    {
      const tab = await page(engine.port, `${base}/world`);
      await tab.until(countOf(".module"), "модули раздела «Мир»");
      const modules = await tab.evaluate(countOf(".module"));
      check("Мир: посадочная по модулям", modules >= 5, modules + " модулей");
      check("Мир: заголовка-дубля нет", (await tab.evaluate(countOf("app-world-home-page h1"))) === 0);
      check(
        "Мир: у модуля есть заголовок",
        (await tab.evaluate(textOf(".module .forge-panel-title"))) === "Добыча",
        await tab.evaluate(textOf(".module .forge-panel-title")),
      );
      check("Мир: страницы модуля со значками", (await tab.evaluate(countOf(".module .forge-icon-tile svg"))) >= 8);
      check("Мир: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Предмет -----------------------------------------------------------
    {
      const tab = await page(engine.port, `${base}/loot/items?item=2589`);
      await tab.until(countOf("app-item-drops-page"), "страница «Предмет»");
      await tab.until(`${countOf(".table-wrap tbody tr")} || ${countOf(".empty.big")}`, "пути предмета");
      const paths = await tab.evaluate(countOf(".table-wrap tbody tr"));
      check("Предмет: пути найдены", paths > 0, paths + " путей");
      if (paths) {
        check("Предмет: цепочка шагов видна", (await tab.evaluate(countOf("td.chain b"))) > 0);
        check("Предмет: полоса отбора", (await tab.evaluate(countOf(".filters-bar select"))) > 0);
      }
      check("Предмет: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Таблица -----------------------------------------------------------
    {
      const tab = await page(engine.port, `${base}/loot/tables`);
      await tab.until(countOf("app-loot-tables-page"), "страница «Таблица»");
      const tabs = await tab.until(countOf(".table-tabs button"), "вкладки таблиц");
      check("Таблица: все тринадцать таблиц", tabs === 13, String(tabs));

      await tab.until(countOf(".listrow"), "список записей");
      await tab.evaluate(clickNth(".listrow", 0));
      await tab.until(countOf("app-loot-tree"), "запись");
      check("Таблица: запись открывается", true);
      check(
        "Таблица: выбор ушёл в адрес",
        (await tab.evaluate("location.search")).includes("entry="),
        await tab.evaluate("location.search"),
      );
      check("Таблица: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }
    // --- Заклинания: таблица и карточка -------------------------------------
    {
      const tab = await page(engine.port, `${base}/catalog/workshop/spells`);
      await tab.until(countOf("app-spell-list-page tbody tr"), "таблица заклинаний");
      check(
        "Заклинания: прежний адрес мастерской ведёт на общую страницу",
        (await tab.evaluate("location.pathname")).endsWith("/catalog/spells"),
        await tab.evaluate("location.pathname"),
      );
      check(
        "Заклинания: отбор сверху",
        (await tab.evaluate(countOf("app-spell-list-page .filter-bar .forge-field"))) >= 5,
      );
      // Подпись приходит отдельным запросом к SOAP - её надо дождаться, иначе
      // проверка меряет не страницу, а скорость PTR.
      const restart = await tab.until(textOf(".restart-state"), "подпись о рестарте");
      check("Заклинания: видно, ждут ли спеллы рестарта", !!restart, restart);
      // Строка - ссылка на карточку, а не выбор в списке.
      await tab.evaluate(clickNth("app-spell-list-page tbody tr", 0));
      await tab.until(countOf("app-spell-card-page .icon-field"), "карточка своего заклинания");
      check(
        "Заклинания: карточка живёт в адресе",
        /\/catalog\/spells\/\d+$/.test(await tab.evaluate("location.pathname")),
        await tab.evaluate("location.pathname"),
      );
      await tab.evaluate(clickNth(".icon-field button", 0));
      const icons = await tab.until(countOf("app-icon-picker .icon-cell"), "иконки в окне");
      check("Заклинания: выбор иконки открывается", icons > 0, icons + " иконок");
      check("Заклинания: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Заклинания: клиентское только читается ------------------------------
    {
      const tab = await page(engine.port, `${base}/catalog/spells?scope=all`);
      await tab.until(countOf("app-spell-list-page tbody tr"), "список клиента");
      // У своих и у клиентских разные источники, и знают они о строке разное:
      // две последние колонки должны меняться вместе с охватом.
      check(
        "Заклинания: у клиентских своя пара колонок",
        (await tab.evaluate(
          `document.querySelector('app-spell-list-page thead').innerText.includes('Школа')`,
        )) === true,
      );
      // Иконки приходят картинками с CDN: считаем не теги, а те, что реально
      // нарисовались - пустая рамка выглядела бы так же, как живая.
      const drawn = await tab.until(
        `[...document.querySelectorAll('app-spell-list-page tbody img')]` +
          `.filter((img) => img.naturalWidth > 0).length`,
        "иконки заклинаний",
      );
      check("Заклинания: иконки рисуются картинками", drawn > 3, drawn + " из таблицы");
      await tab.evaluate(clickNth("app-spell-list-page tbody tr", 0));
      await tab.until(countOf("app-spell-card-page .read-only"), "карточка клиентского заклинания");
      check(
        "Заклинания: у клиентского видно сводку",
        (await tab.evaluate(countOf("app-spell-card-page .facts > div"))) > 0,
      );
      check(
        "Заклинания: клиентское не предлагает «Сохранить»",
        (await tab.evaluate(`document.body.innerText.includes('Сохранить')`)) === false,
      );
      check(
        "Заклинания: клиентское предлагает копию",
        (await tab.evaluate(`document.body.innerText.includes('Создать копию')`)) === true,
      );
      check("Заклинания: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Замок на карточке ---------------------------------------------------
    {
      const tab = await page(engine.port, `${base}/catalog/items/175000`);
      await tab.until(countOf(".edit-lock"), "замок на карточке");
      const locked = await tab.evaluate(countOf("app-item-card-page .editor-groups input[disabled]"));
      check("Замок: заперт по умолчанию, поля не тронуть", locked > 10, locked + " полей");
      check(
        "Замок: под замком нет «Сохранить»",
        (await tab.evaluate(`document.body.innerText.includes('Сохранить')`)) === false,
      );
      await tab.evaluate(clickNth(".edit-lock", 0));
      await sleep(400);
      const open = await tab.evaluate(
        countOf("app-item-card-page .editor-groups input:not([disabled])"),
      );
      check("Замок: открывается и отпирает поля", open > 10, open + " полей");
      await tab.close();
    }

    // Стоковый предмет панель не правит вовсе - замку там нечего отпирать.
    {
      const tab = await page(engine.port, `${base}/catalog/items/17`);
      await tab.until(countOf("app-item-card-page .read-only"), "карточка стокового предмета");
      check("Замок: у стокового предмета его нет", (await tab.evaluate(countOf(".edit-lock"))) === 0);
      await tab.close();
    }

    // --- Предметы: таблица и карточка ---------------------------------------
    {
      const tab = await page(engine.port, `${base}/catalog/items`);
      const rows = await tab.until(countOf("app-item-list-page tbody tr"), "таблица предметов");
      check("Предметы: страница по десять строк", rows === 10, rows + " строк");
      check(
        "Предметы: отбор сверху",
        (await tab.evaluate(countOf("app-item-list-page .filter-bar .forge-field"))) >= 5,
      );
      // Качество, класс и слот - те самые признаки, по которым предмет ищут:
      // отбор по ним был и раньше, а в списке их видно не было.
      check(
        "Предметы: в таблице видно качество и слот",
        (await tab.evaluate(
          `document.querySelector('app-item-list-page thead').innerText.includes('Слот')`,
        )) === true,
      );
      await tab.evaluate(clickNth("app-item-list-page tbody tr", 0));
      await tab.until(countOf("app-item-card-page .actions button"), "карточка предмета");
      await tab.evaluate(clickNth("app-item-card-page .actions button", 0));
      const row = await tab.until(textOf(".client-row pre"), "клиентская строка");
      check("Предметы: клиентская строка показывается", row.includes(","), row.slice(0, 50));
      check("Предметы: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Предметы мира ------------------------------------------------------
    {
      const tab = await page(engine.port, `${base}/catalog/world-items`);
      await tab.until(
        `document.querySelectorAll('app-world-items-page tbody tr').length ||` +
          `(document.querySelector('app-world-items-page .empty') ? 1 : 0)`,
        "таблица размещений",
      );
      check(
        "Предметы мира: отбор сверху",
        (await tab.evaluate(countOf("app-world-items-page .filter-bar .forge-field"))) >= 1,
      );
      const placements = await tab.evaluate(countOf("app-world-items-page tbody tr"));
      if (placements) {
        await tab.evaluate(clickNth("app-world-items-page tbody tr", 0));
        const editor = await tab.until(countOf("app-world-item-page .editor"), "карточка размещения");
        check("Предметы мира: строка открывает карточку", editor === 1);
      } else {
        check(
          "Предметы мира: честная пустота",
          (await tab.evaluate(countOf("app-world-items-page .empty"))) > 0,
        );
      }
      check("Предметы мира: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Протухшая сессия ---------------------------------------------------
    {
      const tab = await page(engine.port, `${base}/loot/creatures`);
      await tab.until(countOf("tbody tr"), "таблица существ");
      // Сессия кончилась уже в открытой вкладке: страж её не сторожит, это
      // случай перехватчика.
      // Токен латиницей нарочно: значение заголовка с кириллицей браузер
      // отвергает сам, и до сервера запрос не доходит вовсе - проверка мерила
      // бы не то.
      await tab.evaluate(`localStorage.setItem('adminToken', 'stale-token'); 1`);
      await tab.evaluate(clickNth("tbody tr", 0));
      const at = await tab.until(`location.pathname.endsWith('/login') ? location.pathname : 0`, "возврат на вход");
      check("Сессия: 401 возвращает на вход, а не ломает страницу", !!at, at);
      await tab.close();
    }

    // --- Поиск по панели ----------------------------------------------------
    {
      const tab = await page(engine.port, `${base}/`);
      await tab.until(countOf(".find"), "кнопка поиска");
      await tab.evaluate(clickNth(".find", 0));
      await tab.until(`document.querySelector('app-quick-search dialog')?.open ? 1 : 0`, "окно поиска");
      const all = await tab.evaluate(countOf("app-quick-search li"));
      check("Поиск: видны все страницы", all >= 10, all + " строк");
      // Ищем по подписи, а не по названию: «падает» есть только в ней - и
      // только у одной страницы.
      await tab.evaluate(
        `(() => { const input = document.querySelector('app-quick-search input');
                  const setter = Object.getOwnPropertyDescriptor(
                    window.HTMLInputElement.prototype, 'value').set;
                  setter.call(input, 'падает');
                  input.dispatchEvent(new Event('input', { bubbles: true })); })()`,
      );
      await sleep(400);
      const hit = await tab.evaluate(textOf("app-quick-search li .name b"));
      check("Поиск: ищет по подписи страницы", hit === "Предмет", hit);
      check("Поиск: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Витрина лаунчера ---------------------------------------------------
    {
      const tab = await page(engine.port, `${base}/settings/cdn`);
      await tab.until(countOf("app-cdn-page .block"), "разделы витрины");
      // Предпросмотр «как это встанет в окно» убран по просьбе владельца:
      // лента и так видна в полях, а вторая её копия занимала пол-экрана.
      // Поэтому читаемость проверяем по самому полю заголовка.
      const first = await tab.until(
        `(() => { const node = document.querySelector('app-cdn-page .item .grow input');
                  return node ? node.value : null; })()`,
        "заголовок первой новости",
      );
      check("Витрина: новости читаются с CDN", !!first, first);
      check("Витрина: предпросмотра ленты больше нет", (await tab.evaluate(countOf(".preview-row"))) === 0);
      check("Витрина: правка доступна владельцу", (await tab.evaluate(countOf(".item-tools .link"))) > 0);
      check(
        "Витрина: подписи окна на месте",
        (await tab.evaluate(countOf(".grid input"))) >= 6,
        await tab.evaluate(countOf(".grid input")),
      );
      check("Витрина: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Раздел «Сервер» ----------------------------------------------------
    //
    // Четыре страницы раздела переведены на набор (styles/forge.scss), и
    // ломается это молча: страница остаётся рабочей, но кнопка снова
    // становится красной плашкой, а поле - чёрной прорезью. Поэтому тут
    // считаем не вид, а КЛАССЫ: кнопка без `forge-btn` и поле без
    // `forge-field` - это отставшая страница.
    {
      const pages = [
        ["Патч", "client-patch", "app-client-patch-page"],
        ["Люди", "users", "app-users-page"],
        ["Журнал", "audit", "app-audit-page"],
        ["Витрина", "cdn", "app-cdn-page"],
      ];
      for (const [label, route, host] of pages) {
        const tab = await page(engine.port, `${base}/settings/${route}`);
        await tab.until(countOf(host), `страница «${label}»`);
        // `.link` - плоская текстовая кнопка, `.sort` - заголовок колонки,
        // который сортирует; обе нарочно вне набора: эмаль кнопки в строке
        // текста и в шапке таблицы не к месту.
        const strays = await tab.evaluate(countOf(`${host} button:not(.forge-btn):not(.link):not(.sort)`));
        check(`${label}: кнопки из набора`, strays === 0, strays + " мимо набора");
        const fields = await tab.evaluate(
          countOf(
            `${host} input:not(.forge-field), ${host} select:not(.forge-field), ${host} textarea:not(.forge-field)`,
          ),
        );
        check(`${label}: поля из набора`, fields === 0, fields + " мимо набора");
        check(`${label}: подписи-надзаголовка нет`, (await tab.evaluate(countOf(`${host} .page-head .eyebrow`))) === 0);
        check(`${label}: без ошибок в консоли`, tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
        await tab.close();
      }
    }

    // Лог сборки закрыт, пока сборка не идёт: сотни строк не должны занимать
    // страницу, ради которой сюда заходят. И журнал показывает ровно пять
    // последних записей, остальное - по кнопке.
    {
      const tab = await page(engine.port, `${base}/settings/client-patch`);
      await tab.until(countOf("app-client-patch-page .status"), "страница «Клиентский патч»");
      const state = (await tab.evaluate(textOf("app-client-patch-page .state strong"))) ?? "";
      const open = await tab.evaluate(`document.querySelector('app-client-patch-page details')?.open ?? null`);
      if (state.includes("Идёт сборка")) {
        check("Патч: лог раскрыт, пока идёт сборка", open === true, state);
      } else {
        check("Патч: лог свёрнут", open === false, "open=" + open + " · " + state);
      }
      await tab.close();
    }
    {
      const tab = await page(engine.port, `${base}/settings/audit`);
      // Лента журнала переехала в таблицу набора - строки считаем по ней.
      await tab.until(countOf("app-audit-page tbody tr"), "строки журнала");
      const rows = await tab.evaluate(countOf("app-audit-page tbody tr"));
      check("Журнал: сразу видно пять записей", rows === 5, rows + " строк");
      check("Журнал: есть чем раскрыть", (await tab.evaluate(countOf(".more .forge-btn"))) === 1);
      await tab.evaluate(clickNth(".more .forge-btn", 0));
      const grown = await tab.until(
        `${countOf("app-audit-page tbody tr")} > 5 ? ${countOf("app-audit-page tbody tr")} : 0`,
        "журнал прирос",
      );
      check("Журнал: «Показать ещё» добавляет записи", grown > 5, grown + " строк");
      await tab.close();
    }

    // «Люди и доступ»: таблицы ведут себя как таблица кита - заголовок
    // сортирует, подвал считает строки.
    {
      const tab = await page(engine.port, `${base}/settings/users`);
      await tab.until(countOf("app-users-page tbody tr"), "таблица профилей");
      check(
        "Люди: заголовки сортируют",
        (await tab.evaluate(countOf("app-users-page thead .sort"))) >= 6,
        (await tab.evaluate(countOf("app-users-page thead .sort"))) + " заголовков",
      );
      const summary = await tab.evaluate(textOf("app-users-page .table-foot .summary"));
      check("Люди: подвал считает строки", /из \d+/.test(summary ?? ""), summary);
      await tab.evaluate(clickNth("app-users-page thead .sort", 0));
      // Помеченных заголовков на странице ДВА - по одному на таблицу, поэтому
      // смотрим на сам нажатый, а не считаем их все.
      check(
        "Люди: сортировка помечает заголовок",
        await tab.evaluate(`document.querySelectorAll('app-users-page thead .sort')[0].classList.contains('is-on')`),
      );
      // Заголовок колонки на листе БЕЛЫЙ. Он кнопка, а кнопки в панели красит
      // общий скин (золотом) - и красил, пока `.sort` не попал в его список
      // исключений. Голубым он тоже быть не должен: голубое значит ссылку.
      check(
        "Люди: заголовок колонки белый",
        (await tab.evaluate(`getComputedStyle(document.querySelector('app-users-page .sort')).color`)) ===
          "rgb(255, 255, 255)",
        await tab.evaluate(`getComputedStyle(document.querySelector('app-users-page .sort')).color`),
      );
      // Ячейка с кнопками должна остаться ЯЧЕЙКОЙ: `display: flex` на `<td>`
      // выбивает её из табличной модели, и колонка разъезжается - линии строк
      // обрываются на последнем столбце. Ломается молча, поэтому проверяем.
      check(
        "Люди: колонка действий - настоящая ячейка",
        (await tab.evaluate(`getComputedStyle(document.querySelector('app-users-page td.tools')).display`)) ===
          "table-cell",
      );
      check("Люди: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // Витрина кита: таблица с листа 8 - шапка с сортировкой, огоньки, подвал.
    {
      const tab = await page(engine.port, `${base}/style-kit`);
      await tab.until(countOf(".table-demo tbody tr"), "таблица витрины");
      check("Кит: таблица нарисована", (await tab.evaluate(countOf(".table-demo tbody tr"))) === 5);
      check("Кит: колонок пять", (await tab.evaluate(countOf(".table-demo thead th"))) === 5);
      const firstBefore = await tab.evaluate(textOf(".table-demo tbody tr td"));
      await tab.evaluate(clickNth(".table-demo .sort", 0));
      const firstAfter = await tab.until(
        `(() => { const cell = document.querySelector('.table-demo tbody tr td');
                  return cell && cell.textContent.trim() !== ${JSON.stringify("")} ? cell.textContent.trim() : null; })()`,
        "строки после сортировки",
      );
      check("Кит: заголовок сортирует", firstAfter !== firstBefore, firstBefore + " -> " + firstAfter);
      check("Кит: подвал с листалкой", (await tab.evaluate(countOf(".table-foot .forge-page-btn"))) > 0);
      // Цвета: шесть групп образцов, и значения переменных темы страница
      // ЧИТАЕТ, а не переписывает - если чтение отвалится, под токеном
      // останется пусто.
      check(
        "Кит: раздел цветов на месте",
        (await tab.evaluate(countOf(".palette"))) >= 7,
        (await tab.evaluate(countOf(".palette"))) + " групп",
      );
      check("Кит: образцов цвета", (await tab.evaluate(countOf(".swatches figure"))) >= 25);
      check(
        "Кит: значения токенов прочитаны",
        (await tab.evaluate(textOf(".palette .swatches small"))) === "#ffd100",
        await tab.evaluate(textOf(".palette .swatches small")),
      );
      // Приоритет красит САМУ КРОМКУ - перекрашенной копией ассета. Проверяем
      // не цвет тени, а то, что у критичного подставлена своя картинка.
      const criticalFrame = await tab.evaluate(
        `getComputedStyle(document.querySelector('.prio.p3'), '::after').borderImageSource`,
      );
      check("Кит: у критичного своя кромка", criticalFrame.includes("panel-subtle-critical"), criticalFrame);
      // Шрифты: три гарнитуры с живыми образцами и таблица кеглей. Заодно
      // ловим возврат заголовков к системному шрифту - гарнитуру им задаёт
      // общее правило, и потерять её легко.
      // Значки: набор ОДИН и рисуется нами. Ловим и пропажу раздела, и возврат
      // к символам шрифта - каждый значок обязан быть svg, а не глифом.
      const icons = await tab.evaluate(countOf(".icon-grid figure"));
      check("Кит: раздел значков", icons >= 40, String(icons));
      check(
        "Кит: у значка есть вид в рамке",
        (await tab.evaluate(countOf(".icon-grid figure .forge-icon-tile app-icon svg"))) === icons,
      );
      const tileFrame = await tab.evaluate(style(".forge-icon-tile", "borderImageSource"));
      check("Кит: рамка значка - с листа", tileFrame.includes("frames/icon-tile"), tileFrame);
      check("Кит: раздел шрифтов на месте", (await tab.evaluate(countOf(".fonts .face"))) === 3);
      check("Кит: таблица кеглей", (await tab.evaluate(countOf(".sizes tbody tr"))) >= 8);
      check(
        "Кит: заголовок засечный",
        (await tab.evaluate(`getComputedStyle(document.querySelector('app-style-kit-page h1')).fontFamily`)).includes(
          "Palatino",
        ),
      );
      check("Кит: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Обзор ---------------------------------------------------------------
    //
    // Карточка показателя набрана по листу 6: плитка со значком, ЗОЛОТАЯ
    // подпись, БЕЛОЕ значение, тихая строка снизу. Порядок цветов и ловим:
    // наоборот получается «жёлтое число», какого на листах нет.
    {
      const tab = await page(engine.port, `${base}/`);
      await tab.until(countOf("app-dashboard-page .forge-stat"), "показатели «Обзора»");

      const cards = await tab.until(countOf(".forge-stat"), "карточки показателей");
      check("Обзор: четыре показателя", cards === 4, String(cards));
      check("Обзор: плитка под значком", (await tab.evaluate(countOf(".forge-stat .forge-icon-tile"))) === 4);
      const label = await tab.evaluate(style(".forge-stat .label", "color"));
      check("Обзор: подпись показателя золотая", label === "rgb(255, 209, 0)", label);
      const value = await tab.evaluate(style(".forge-stat .value", "color"));
      check("Обзор: значение белое", value === "rgb(255, 255, 255)", value);
      const face = await tab.evaluate(style(".forge-stat .value", "fontFamily"));
      check("Обзор: значение засечное", face.includes("Palatino"), face);

      // Плашки берутся из набора: своя копия `.notice` уже была и разъехалась
      // с китом по цвету текста.
      check("Обзор: плашки из набора", (await tab.evaluate(countOf("app-dashboard-page .notice"))) === 0);

      // Ссылки карты - голубые (хлебные крошки листа 10), а не золотые.
      const link = await tab.evaluate(style(".map-section a", "color"));
      check("Обзор: ссылки карты голубые", link === "rgb(33, 220, 255)", link);
      // Нить под заголовком панели - СТАЛЬНАЯ: синего в ней больше красного.
      const rule = await tab.evaluate(style(".map-section .forge-panel-title", "borderBottomColor"));
      const rgb = rule.match(/\d+/g).map(Number);
      check("Обзор: нить под заголовком холодная", rgb[2] > rgb[0] + 20, rule);

      // Значок, а не символ шрифта: у быстрой ссылки в свёрнутой панели стояло
      // «▤», и его рисовал системный шрифт.
      check(
        "Обзор: быстрая ссылка со значком",
        (await tab.evaluate(countOf("app-site-sidebar .collapsed-navigation a svg"))) > 0,
      );

      check("Обзор: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Окна: контролы и раскрывающийся список -------------------------------
    //
    // Окна живут в ВЕРХНЕМ СЛОЕ браузера, и всё, что осталось в `<body>`,
    // рисуется под ними. Своё меню списка раньше клали в `<body>` - в окне
    // оно открывалось невидимым, и со стороны это выглядело как «список не
    // раскрывается». Проверяем и вид контролов, и то, что меню село в окно.
    {
      const tab = await page(engine.port, `${base}/loot/items`);
      await tab.until(countOf("app-item-drops-page"), "страница «Предмет»");
      await tab.evaluate(
        `(() => { const b = [...document.querySelectorAll('button')].find((x) => x.textContent.includes('Найти по имени'));
                  b && b.click(); return !!b; })()`,
      );
      await tab.until(countOf("app-item-picker dialog[open]"), "окно выбора предмета");
      check(
        "Окно: поле и список из набора",
        (await tab.evaluate(countOf("app-item-picker .forge-field"))) === 2,
        String(await tab.evaluate(countOf("app-item-picker .forge-field"))),
      );
      check(
        "Окно: ничего мимо набора",
        (await tab.evaluate(
          `[...document.querySelectorAll('dialog button, dialog input, dialog select')]
             .filter((el) => !String(el.className).includes('forge-') && !el.classList.contains('item-row')).length`,
        )) === 0,
      );
      await tab.evaluate(
        `(() => { const s = document.querySelector('app-item-picker select.forge-field');
                  s && s.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true })); return !!s; })()`,
      );
      const where = await tab.until(
        `(() => { const menu = document.querySelector('.menu[role="listbox"]');
                  return menu ? (menu.closest('dialog') ? 'в окне' : 'в body') : 0; })()`,
        "раскрытый список в окне",
      );
      check("Окно: список раскрывается внутри окна", where === "в окне", where);
      check("Окно: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Ничего мимо набора --------------------------------------------------
    //
    // Главная проверка стайлгайда: на странице не должно быть СВОИХ кнопок,
    // полей и списков - всё носит классы набора (`forge-*`), а вид ему задают
    // ассеты, нарезанные с листов. Нарочные исключения перечислены в `flat`:
    // это плоские элементы (строка списка, текстовая ссылка, заголовок
    // колонки, ячейка значка), которым эмаль кнопки не к месту.
    //
    // Проверка нужна потому, что общий скин из `warcraft.scss` убран: кнопка
    // без класса теперь не «выглядит игровой сама собой», а остаётся голой.
    {
      const flat =
        "[\'link\',\'listrow\',\'item-row\',\'spell-row\',\'icon-cell\',\'fold\',\'toggle\',\'sort\'," +
        "\'edit-lock\',\'ghost\',\'section-head\',\'zone-row\',\'feature-toggle\',\'collapsed-feature-toggle\']";
      const strayExpr = `(() => {
        const skip = ${flat};
        const own = (el) => !String(el.className).includes('forge-') && !skip.some((c) => el.classList.contains(c));
        const btn = [...document.querySelectorAll('app-shell main button')].filter(own);
        const fld = [...document.querySelectorAll('app-shell main input, app-shell main select, app-shell main textarea')]
          .filter((f) => own(f) && f.type !== 'checkbox' && f.type !== 'radio');
        return btn.length + fld.length
          ? [...btn, ...fld].slice(0, 4).map((e) => e.tagName.toLowerCase() + '.' + (e.className || '?')).join(', ')
          : '';
      })()`;
      const routes = [
        ["Обзор", "/"],
        ["Доска", "/board"],
        ["Мир", "/world"],
        ["Существа", "/loot/creatures"],
        ["Существо", "/loot/creatures/16379"],
        ["Предмет", "/loot/items"],
        ["Таблица", "/loot/tables"],
        ["Погода", "/weather"],
        ["Карта погоды", "/weather/map"],
        ["Зоны", "/weather/zones"],
        ["Фронты", "/weather/fronts"],
        ["Настройки погоды", "/weather/settings"],
        ["Эффекты", "/environment"],
        ["Правила зоны", "/environment/zones/33"],
        ["Таланты", "/item-talents"],
        ["Профессии", "/professions/materials"],
        ["Каталог", "/catalog"],
        ["Заклинания", "/catalog/spells"],
        ["Предметы", "/catalog/items"],
        ["Предметы мира", "/catalog/world-items"],
        ["Серверный патч", "/settings/server-patch"],
      ];
      for (const [label, route] of routes) {
        const tab = await page(engine.port, `${base}${route}`);
        await tab.until(countOf("app-shell main *"), `страница ${label}`);
        const strays = await tab.evaluate(strayExpr);
        check(`${label}: ничего мимо набора`, strays === "", strays);
        await tab.close();
      }
    }

    // --- Погода: карта отдельно от связей ----------------------------------
    //
    // Пульт погоды (значки состояний, сила, удержание) живёт ТОЛЬКО на карте.
    // Пока он был и там, и на странице рядом, два поля правили один черновик
    // и расходились: где нажал - то и применилось.
    {
      const tab = await page(engine.port, `${base}/weather/map`);
      await tab.until(countOf("app-weather-map-page .map-frame"), "карта погоды");
      check(
        "Карта: список зон в боковой панели",
        (await tab.evaluate(countOf("app-site-sidebar app-weather-zone-list .zone-row"))) > 0,
      );
      check(
        "Карта: сводка по миру на карте",
        (await tab.evaluate(countOf("app-weather-map-page .map-stats .forge-stat"))) === 4,
      );
      check(
        "Карта: редактора связей тут нет",
        (await tab.evaluate(countOf("app-weather-map-page .link-editor"))) === 0,
      );
      check("Карта: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // Эффекты окружения: тот же расклад, что у добычи и зон погоды -
    // таблица со списком, правила на подстранице с номером зоны в адресе.
    {
      const tab = await page(engine.port, `${base}/environment`);
      await tab.until(countOf("app-environment-zones-page tbody tr"), "таблица зон эффектов");
      const rows = await tab.evaluate(countOf("app-environment-zones-page tbody tr"));
      check("Эффекты: страница по десять строк", rows === 10, rows + " строк");
      check(
        "Эффекты: общемировые правила в списке",
        (await tab.evaluate(textOf("app-environment-zones-page tbody tr td"))).length > 0,
        await tab.evaluate(textOf("app-environment-zones-page tbody tr td")),
      );
      check("Эффекты: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    {
      const tab = await page(engine.port, `${base}/environment/zones/33`);
      // Ждём ИМЯ зоны, а не `.editor`: коробка редактора стоит на странице
      // всегда, и проверка успевала сработать до того, как правила приехали.
      await tab.until(textOf("app-environment-page .editor-head h2"), "правила зоны");
      check(
        "Эффекты: зона взята из адреса",
        (await tab.evaluate(textOf("app-environment-page .editor-head h2"))).length > 0,
        await tab.evaluate(textOf("app-environment-page .editor-head h2")),
      );
      check(
        "Эффекты: колонки зон на подстранице нет",
        (await tab.evaluate(countOf("app-environment-page .zones"))) === 0,
      );
      check("Эффекты: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // Общемировые правила живут под номером НОЛЬ, и проверка «номер больше
    // нуля» однажды уже выбросила именно их: страница открывалась пустой.
    {
      const tab = await page(engine.port, `${base}/environment/zones/0`);
      await tab.until(textOf("app-environment-page .editor-head h2"), "общемировые правила");
      check(
        "Эффекты: общемировые правила открываются",
        (await tab.evaluate(textOf("app-environment-page .editor-head h2"))).length > 0,
        await tab.evaluate(textOf("app-environment-page .editor-head h2")),
      );
      check("Эффекты: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // Фронты: карта, список и постановка своего фронта. Своя кнопка есть
    // только у редактора, поэтому проверяем список и карту, а не её.
    {
      const tab = await page(engine.port, `${base}/weather/fronts`);
      await tab.until(countOf("app-weather-fronts-page app-weather-map"), "страница фронтов");
      check(
        "Фронты: список слева на карте",
        (await tab.evaluate(countOf("app-weather-fronts-page .front-list"))) === 1,
      );
      check(
        "Фронты: строки или честная пустота",
        (await tab.evaluate(countOf("app-weather-fronts-page .front-row"))) > 0 ||
          (await tab.evaluate(textOf("app-weather-fronts-page .front-list .hint"))).includes(
            "Фронтов нет",
          ),
      );
      check(
        "Фронты: очередь под картой",
        (await tab.evaluate(countOf("app-weather-fronts-page .queue"))) === 1,
      );
      check(
        "Фронты: очередь читается или честно говорит, что её нет",
        (await tab.evaluate(countOf("app-weather-fronts-page .queue tbody tr"))) > 0 ||
          (await tab.evaluate(countOf("app-weather-fronts-page .queue .queue-empty"))) > 0 ||
          (await tab.evaluate(countOf("app-weather-fronts-page .queue .forge-alert"))) > 0,
      );
      // Очередь у каждого континента своя. Пока она была одна на мир, голова
      // очереди держала небо одной карты, а остальные стояли ясными.
      check(
        "Фронты: очередь разбита по континентам",
        (await tab.evaluate(countOf("app-weather-fronts-page .queue tbody tr.group"))) > 0 ||
          (await tab.evaluate(countOf("app-weather-fronts-page .queue .forge-alert"))) > 0,
      );
      // Заголовок говорит, чем очередь держится: запас и пауза - это две
      // настройки, и без них таблица выглядит списком без правил.
      check(
        "Фронты: у очереди сказан запас",
        (await tab.evaluate(textOf("app-weather-fronts-page .queue .forge-panel-title small")))
          .includes("континент") ||
          (await tab.evaluate(countOf("app-weather-fronts-page .queue .forge-alert"))) > 0,
        await tab.evaluate(textOf("app-weather-fronts-page .queue .forge-panel-title small")),
      );
      check("Фронты: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // Связи: список зон таблицей, правка - на подстранице с номером в адресе.
    // Прежде зона бралась из выбора НА КАРТЕ: по ссылке открывалось неизвестно
    // что, а обновление страницы теряло зону.
    {
      const tab = await page(engine.port, `${base}/weather/zones`);
      await tab.until(countOf("app-weather-zones-page tbody tr"), "таблица зон");
      const rows = await tab.evaluate(countOf("app-weather-zones-page tbody tr"));
      check("Зоны: страница по десять строк", rows === 10, rows + " строк");
      check(
        "Зоны: отбор сверху",
        (await tab.evaluate(countOf("app-weather-zones-page .filter-bar .forge-field"))) >= 2,
      );
      check(
        "Зоны: списка зон в боковой панели нет",
        (await tab.evaluate(countOf("app-site-sidebar app-weather-zone-list"))) === 0,
      );
      check("Зоны: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    {
      const tab = await page(engine.port, `${base}/weather/zones/36`);
      await tab.until(countOf("app-weather-page .link-editor"), "редактор связей");
      check(
        "Связи: зона взята из адреса",
        (await tab.evaluate(textOf("app-weather-page .zone-head h2"))) === "Альтеракские горы",
        await tab.evaluate(textOf("app-weather-page .zone-head h2")),
      );
      check(
        "Связи: переключателя режиссёра тут нет",
        (await tab.evaluate(countOf("app-weather-page .module-state"))) === 0,
      );
      check(
        "Связи: карты и сводки тут больше нет",
        (await tab.evaluate(countOf("app-weather-page app-weather-map"))) === 0 &&
          (await tab.evaluate(countOf("app-weather-page .forge-stat"))) === 0,
      );
      check("Связи: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Серверный патч -----------------------------------------------------------
    //
    // Раньше «Применить на сервере», «Перечитать PTR/модуль/конфиг» и
    // «Выгрузить SQL» стояли кнопками на девяти страницах: пять надписей на
    // одно дело, причём в добыче и профессиях не нажать было равно потерять
    // правку. Теперь состояние считает сервер (`app/apply.py`), а страница
    // показывает его в одном месте.
    {
      const tab = await page(engine.port, `${base}/settings/server-patch`);
      await tab.until(countOf("app-deploy-page .forge-panel"), "страница «Серверный патч»");
      const panels = await tab.evaluate(countOf("app-deploy-page .forge-panel"));
      check("Серверный патч: два раздела", panels >= 2, panels + " панелей");
      check(
        "Серверный патч: живой сервер первым",
        (await tab.evaluate(textOf("app-deploy-page .forge-panel-title"))).includes("Живой сервер"),
        await tab.evaluate(textOf("app-deploy-page .forge-panel-title")),
      );
      check(
        "Серверный патч: миграции с путями файлов",
        (await tab.evaluate(countOf("app-deploy-page .exports .detail"))) >= 3,
      );
      check(
        "Серверный патч: клиентских файлов тут нет",
        (await tab.evaluate(`document.body.innerText.includes('Item_custom.csv')`)) === false,
      );
      check("Серверный патч: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Клиентский патч: сырьё рядом со сборкой ---------------------------
    //
    // CSV и сборщик MPQ - один шаг конвейера, и собранный из устаревших файлов
    // патч выглядит удачным, хотя у игрока всё по-старому. Поэтому список
    // файлов стоит ПЕРЕД кнопками сборки, а не на соседней странице.
    {
      const tab = await page(engine.port, `${base}/settings/client-patch`);
      await tab.until(countOf("app-client-patch-page .sources .row"), "файлы клиента");
      const rows = await tab.evaluate(countOf("app-client-patch-page .sources .row"));
      check("Патч: файлы клиента на месте", rows === 2, rows + " строк");
      check(
        "Патч: видно, когда выгружали",
        (await tab.evaluate(textOf("app-client-patch-page .sources .who"))).includes("выгружено"),
        await tab.evaluate(textOf("app-client-patch-page .sources .who")),
      );
      check(
        "Патч: сырьё выше кнопок сборки",
        await tab.evaluate(`(() => {
          const src = document.querySelector('app-client-patch-page .sources');
          const act = document.querySelector('app-client-patch-page .actions');
          return !src || !act ? true : src.compareDocumentPosition(act) === 4;
        })()`),
      );
      check("Патч: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }

    // --- Профессии: десять страниц вместо десяти вкладок --------------------
    //
    // Старая страница `/aprof.html` держала всё в одном файле с переключателем
    // вкладок; здесь у каждой свой адрес, поэтому и проверяем адресами. Общий
    // сторож у всех один - пустой `errors`: страница, которая нарисовалась, но
    // уронила запрос, выглядит рабочей ровно до первой правки.
    {
      const pages = [
        ["Типы предметов", "/professions/types", "app-professions-types-page"],
        ["Материалы", "/professions/materials", "app-professions-materials-page"],
        ["Рецепты", "/professions/recipes", "app-professions-recipes-page"],
        ["Именные", "/professions/named", "app-professions-named-page"],
        ["Объединение", "/professions/merge", "app-professions-merge-page"],
        ["Справочники", "/professions/dicts", "app-professions-dicts-page"],
        ["Баланс", "/professions/balance", "app-professions-balance-page"],
        ["Проверка", "/professions/preview", "app-professions-preview-page"],
        ["Пул id", "/professions/pool", "app-professions-pool-page"],
        ["Связи", "/professions/relations", "app-professions-relations-page"],
      ];
      for (const [label, route, selector] of pages) {
        const tab = await page(engine.port, `${base}${route}`);
        await tab.until(countOf(`${selector} h1`), `страница «${label}»`);
        check(
          `Профессии · ${label}: заголовок`,
          (await tab.evaluate(textOf(`${selector} h1`))) === label,
          await tab.evaluate(textOf(`${selector} h1`)),
        );
        // Содержимое приезжает запросом, поэтому его ЖДЁМ: заголовок рисуется
        // сразу, и проверка сразу после него мерила бы скорость сети, а не
        // страницу. Таблиц модуля может не быть вовсе - тогда страница честно
        // говорит об этом плашкой, и пустой лист не провал.
        const body = `${selector} table, ${selector} .card, ${selector} canvas, ${selector} .forge-alert.is-warning`;
        let drawn = 0;
        try {
          drawn = await tab.until(countOf(body), `содержимое страницы «${label}»`);
        } catch (error) {
          drawn = 0;
        }
        const missing = await tab.evaluate(countOf(`${selector} .forge-alert.is-warning`));
        check(
          `Профессии · ${label}: содержимое нарисовано`,
          drawn > 0,
          missing ? "таблиц модуля нет" : undefined,
        );
        check(
          `Профессии · ${label}: без ошибок в консоли`,
          tab.errors.length === 0,
          tab.errors.slice(0, 2).join(" | "),
        );
        await tab.close();
      }
    }

    // --- Профессии: лист, отбор и окна --------------------------------------
    //
    // Отбор и листалка - на стороне страницы, а не сервера: справочники тут
    // невелики. Проверяем ровно это: полоса отбора сужает лист, а кнопка в
    // строке открывает окно, а не уводит на другой адрес.
    {
      const tab = await page(engine.port, `${base}/professions/types`);
      await tab.until(countOf("app-professions-types-page tbody tr"), "лист типов");
      const rows = await tab.evaluate(countOf("app-professions-types-page tbody tr"));
      check("Профессии · Типы: лист не пуст", rows > 0, rows + " строк");
      check(
        "Профессии · Типы: полоса отбора на месте",
        (await tab.evaluate(countOf("app-prof-filters select"))) >= 3,
      );
      check(
        "Профессии · Типы: колонки сортируются",
        (await tab.evaluate(countOf("th.sortable"))) >= 5,
      );
      await tab.evaluate(clickNth("app-professions-types-page td.act button", 0));
      const parts = await tab.until(
        `document.querySelector('app-parts-dialog dialog')?.open ? 1 : 0`,
        "окно схемы частей",
      );
      check("Профессии · Типы: схема частей открывается окном", !!parts);
      check(
        "Профессии · Типы: без ошибок в консоли",
        tab.errors.length === 0,
        tab.errors.slice(0, 2).join(" | "),
      );
      await tab.close();
    }

    // --- Профессии: диаграмма связей ---------------------------------------
    //
    // Диаграмма рисует CANVAS, а не разметку, поэтому проверяем не узлы в DOM
    // (их там нет вовсе), а что полотно появилось и что счётчик узлов не ноль.
    {
      const tab = await page(engine.port, `${base}/professions/relations?view=graph`);
      await tab.until(countOf("app-relations-graph canvas"), "полотно диаграммы");
      const counter = await tab.evaluate(textOf("app-relations-graph .bar .muted"));
      check("Профессии · Связи: диаграмма считает узлы", /узлов \d+/.test(counter ?? ""), counter);
      check(
        "Профессии · Связи: отбор по типам нарисован",
        (await tab.evaluate(countOf("app-relations-graph .filters .chip"))) > 1,
      );
      check(
        "Профессии · Связи: без ошибок в консоли",
        tab.errors.length === 0,
        tab.errors.slice(0, 2).join(" | "),
      );
      await tab.close();
    }

    // --- Кнопок применения на страницах больше нет -------------------------
    //
    // Сторож против возврата: одна забытая кнопка «Применить на сервере» на
    // странице снова разведёт два источника правды о том, что доехало до мира.
    {
      const strayApply = `(() => {
        const words = ['Применить на сервере', 'Перечитать PTR', 'Перечитать модуль',
                       'Перечитать конфиг', 'Выгрузить SQL', 'Выгрузить в SQL',
                       'Выгрузить клиент', 'Выгрузить в клиент'];
        const hit = [...document.querySelectorAll('app-shell main button')]
          .map((b) => b.textContent.trim())
          .filter((t) => words.some((w) => t === w));
        return hit.join(', ');
      })()`;
      for (const [label, route] of [
        ["Эффекты", "/environment"],
        ["Погода", "/weather"],
        ["Настройки погоды", "/weather/settings"],
        ["Профессии", "/professions/materials"],
        ["Таланты", "/item-talents"],
        ["Таблица", "/loot/tables"],
        ["Существо", "/loot/creatures/16379"],
        ["Предметы", "/catalog/items"],
        ["Заклинания", "/catalog/spells"],
      ]) {
        const tab = await page(engine.port, `${base}${route}`);
        await tab.until(countOf("app-shell main *"), `страница ${label}`);
        const strays = await tab.evaluate(strayApply);
        check(`${label}: применение не на странице`, strays === "", strays);
        await tab.close();
      }
    }

    // --- Пункт «Серверный патч» в меню -------------------------------------
    {
      const tab = await page(engine.port, `${base}/`);
      await tab.until(countOf(".settings-menu summary"), "меню пользователя");
      await tab.evaluate(clickNth(".settings-menu summary", 0));
      await tab.until(countOf(".settings-menu .deploy-link"), "пункт «Серверный патч»");
      check(
        "Меню: пункт «Серверный патч» есть",
        (await tab.evaluate(textOf(".settings-menu .deploy-link"))).startsWith("Серверный патч"),
        await tab.evaluate(textOf(".settings-menu .deploy-link")),
      );
      await tab.close();
    }

    // --- Смена пароля ------------------------------------------------------
    {
      const tab = await page(engine.port, `${base}/`);
      await tab.until(countOf(".settings-menu summary"), "меню пользователя");
      await tab.evaluate(clickNth(".settings-menu summary", 0));
      await tab.until(countOf(".menu-action"), "пункт смены пароля");
      await tab.evaluate(clickNth(".menu-action", 0));
      const open = await tab.until(
        `document.querySelector('app-change-password dialog')?.open ? 1 : 0`,
        "окно смены пароля",
      );
      check("Меню: смена пароля открывается", !!open);
      check("Обзор: без ошибок в консоли", tab.errors.length === 0, tab.errors.slice(0, 2).join(" | "));
      await tab.close();
    }
  } finally {
    engine.child.kill();
    server.close();
  }

  console.log(
    "\nИТОГО: " +
      (failures.length ? "провалов " + failures.length + " - " + failures.join(", ") : "все проверки прошли"),
  );
  process.exit(failures.length ? 1 : 0);
}

main().catch((error) => {
  console.error("\nсорвалось: " + error.message);
  process.exit(2);
});
