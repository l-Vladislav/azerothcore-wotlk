"""Клиентский патч: панель просит, собирает ac-patch-builder.

Панель не умеет собирать патч сама и не должна: для этого нужны StormLib и
право писать в `launcher/cdn`, то есть прямо в то, что качают игроки. Рядом
стоит контейнер `tools/patch-builder`, у которого это право есть; здесь -
тонкий клиент к нему и больше ничего.

Ручки сборщика повторены один в один, своей логики тут нет:

    GET  /health      видит ли он build.py, рабочий каталог, cdn и StormLib
    GET  /status      идёт ли сборка, чем кончилась прошлая, хвост лога
    GET  /log         весь лог последней сборки
    POST /build       собрать (--dry-run / --no-publish / --no-manifest)
    POST /bootstrap   заново снять базу DBC с архивов CDN
    GET/PUT /cdn/news новости лаунчера (news.json)
    GET/PUT /cdn/ui   подписи и ссылки окна лаунчера (ui.json)

Витрина лаунчера идёт тем же путём и по той же причине: файлы лежат в
`launcher/cdn`, писать туда панели нельзя. Разница только в скорости - в
манифест эти два файла не входят, поэтому записанное видно игрокам при
следующем запуске лаунчера, без пересборки патча.

Своей очереди у панели нет и быть не должно: «сборка уже идёт» решает
сборщик (409), он же единственный держит рабочий каталог. Две панели в двух
вкладках ничего не сломают - вторая получит отказ.

Чтение и действие разведены нарочно. `state()` ошибку связи ГЛОТАЕТ и
возвращает `reachable: false`: главную страницу опрашивают по таймеру, и
поднятый контейнер не должен быть условием, без которого она перестаёт
рисоваться. `build()` и `bootstrap()` наоборот бросают - на нажатую кнопку
надо ответить вслух.
"""

from typing import Any

import httpx

from . import config

# Сборка стартует мгновенно (сервис отвечает 202 и уходит в поток), поэтому
# долгих таймаутов здесь нет ни у одной ручки.
TIMEOUT = 10.0

HINT = ("Сборщик не отвечает. Поднять: "
        "docker compose --profile ptr up -d ac-patch-builder")


class PatchError(RuntimeError):
    """Отказ сборщика. `status` несёт его код, если он ответил.

    Без кода панель отвечала бы 503 и на «сборщик молчит», и на «дата не
    читается»: человек видел бы «сервис недоступен» там, где надо просто
    поправить поле.
    """

    def __init__(self, message: str, status: int = 0) -> None:
        super().__init__(message)
        self.status = status


def configured() -> bool:
    """Пустой URL = сборщика в этой установке нет, кнопок тоже."""
    return bool(config.PATCH_BUILDER_URL)


def _headers() -> dict[str, str]:
    token = config.PATCH_BUILDER_TOKEN
    return {"X-Builder-Token": token} if token else {}


def _call(method: str, path: str, payload: dict | None = None,
          as_text: bool = False) -> Any:
    if not configured():
        raise PatchError("ADMIN_PATCH_BUILDER_URL не задан - сборщик не "
                         "подключён к этой панели.")
    url = config.PATCH_BUILDER_URL.rstrip("/") + path
    try:
        resp = httpx.request(method, url, headers=_headers(), json=payload,
                             timeout=TIMEOUT)
    except httpx.HTTPError as exc:
        raise PatchError(f"{HINT}\n{url}: {exc}") from exc

    if resp.status_code >= 400:
        detail = resp.text[:400]
        try:
            body = resp.json()
            if isinstance(body, dict) and body.get("detail"):
                detail = str(body["detail"])
        except ValueError:
            pass
        raise PatchError(f"сборщик ответил {resp.status_code}: {detail}",
                         resp.status_code)
    return resp.text if as_text else resp.json()


def state() -> dict:
    """Что показывать на главной. Не бросает: связь - часть ответа.

    Отдаётся одним объектом, потому что страница спрашивает одним запросом:
    `health` без `status` не говорит, чем кончилась сборка, а `status` без
    `health` не скажет, что сборщику забыли примонтировать cdn.
    """
    if not configured():
        return {"configured": False, "reachable": False}
    out: dict = {"configured": True}
    try:
        out.update(_call("GET", "/status"), reachable=True)
        out["health"] = _call("GET", "/health")
    except PatchError as exc:
        out.update(reachable=False, error=str(exc))
    return out


def log(tail: int = 0) -> str:
    return _call("GET", f"/log?tail={int(tail)}", as_text=True)


def build(dry_run: bool = False, no_publish: bool = False,
          no_manifest: bool = False) -> dict:
    return _call("POST", "/build", {"dry_run": dry_run,
                                    "no_publish": no_publish,
                                    "no_manifest": no_manifest})


def bootstrap(force: bool = False) -> dict:
    return _call("POST", "/bootstrap", {"force": force})


# --- витрина лаунчера -----------------------------------------------------

def news() -> dict:
    return _call("GET", "/cdn/news")


def save_news(items: list[dict]) -> dict:
    return _call("PUT", "/cdn/news", {"items": items})


def ui() -> dict:
    return _call("GET", "/cdn/ui")


def save_ui(doc: dict) -> dict:
    return _call("PUT", "/cdn/ui", doc)
