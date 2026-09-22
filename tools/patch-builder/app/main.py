"""HTTP-обёртка над tools/client-patch/build.py.

Панель не умеет и не должна собирать патч сама: у неё нет ни StormLib, ни
права писать в launcher/cdn. Она дёргает этот сервис, а он запускает ровно ту
же команду, что человек набрал бы руками, и отдаёт её вывод.

Устройство нарочно скучное:

  * сборка идёт ОДНА за раз. Две параллельные писали бы в один и тот же
    рабочий каталог и в один и тот же cdn - получился бы архив, которого
    никто не собирал;
  * вывод пишется в файл в рабочем каталоге, а не копится в памяти: сборка
    длится минуты, панель за это время успевает перезагрузиться, а лог
    должен пережить и это, и перезапуск контейнера;
  * сервис ничего не решает сам. Он не чинит, не повторяет и не публикует
    «на всякий случай» - что попросили, то и запустил.

Наружу порт не опубликован: до сервиса дотягивается только то, что сидит в
ac-network. Токен (PATCH_BUILDER_TOKEN) - вторая линия, на случай если в эту
сеть попадёт что-то ещё.
"""

import asyncio
import datetime as dt
import json
import os
import re
import subprocess
import threading
from typing import Literal

from fastapi import FastAPI, Header, HTTPException
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, ConfigDict, Field

REPO = os.environ.get("BUILDER_REPO_ROOT", "/repo")
BUILD_PY = os.path.join(REPO, "tools", "client-patch", "build.py")
WORKDIR = os.path.join(REPO, "client-patch")
LOG_PATH = os.path.join(WORKDIR, "build.log")
# Витрина лаунчера: новости и подписи окна. В манифест они не входят - лаунчер
# тянет их с CDN напрямую при каждом запуске, поэтому записанный файл виден
# игрокам сразу, без пересборки патча и без пересчёта хешей.
CDN_DIR = os.path.join(REPO, "launcher", "cdn")
NEWS_PATH = os.path.join(CDN_DIR, "news.json")
UI_PATH = os.path.join(CDN_DIR, "ui.json")
TOKEN = os.environ.get("PATCH_BUILDER_TOKEN", "").strip()

app = FastAPI(title="Сборщик клиентского патча")

_lock = threading.Lock()
_state: dict = {
    "running": False,
    "command": None,
    "started": None,
    "finished": None,
    "code": None,
}


def _check(token: str | None) -> None:
    if TOKEN and (token or "") != TOKEN:
        raise HTTPException(401, "Нужен заголовок X-Builder-Token.")


def _stamp() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def _run(argv: list[str]) -> None:
    """Запустить build.py, сложив весь вывод в лог. Блокирующая часть."""
    os.makedirs(WORKDIR, exist_ok=True)
    env = dict(os.environ)
    # -u: иначе питон буферизует вывод и лог наполняется рывками, а панель
    # показывает пустоту всю сборку.
    env["PYTHONUNBUFFERED"] = "1"
    env["PYTHONIOENCODING"] = "utf-8"
    with open(LOG_PATH, "w", encoding="utf-8", newline="\n") as log:
        log.write("$ %s\n" % " ".join(argv))
        log.write("начато %s\n\n" % _stamp())
        log.flush()
        code = subprocess.call(argv, stdout=log, stderr=subprocess.STDOUT,
                               cwd=os.path.dirname(BUILD_PY), env=env)
        log.write("\nкод возврата %d, завершено %s\n" % (code, _stamp()))
    with _lock:
        _state.update(running=False, finished=_stamp(), code=code)


def _start(args: list[str]) -> dict:
    argv = ["python", "-u", BUILD_PY] + args
    with _lock:
        if _state["running"]:
            raise HTTPException(409, "Сборка уже идёт - дождись её конца.")
        _state.update(running=True, command=" ".join(args),
                      started=_stamp(), finished=None, code=None)
    threading.Thread(target=_run, args=(argv,), daemon=True).start()
    return dict(_state)


# --- модели ---------------------------------------------------------------

class BuildIn(BaseModel):
    dry_run: bool = False
    no_publish: bool = False
    no_manifest: bool = False


class BootstrapIn(BaseModel):
    force: bool = False


# Витрина. Ключи в файлах - camelCase: их читает C#-лаунчер, у которого
# сопоставление имён нечувствительно к регистру, но не к подчёркиваниям.

class NewsItemIn(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    date: str = ""
    title: str = Field(min_length=1, max_length=120)
    body: str = Field(default="", max_length=800)
    url: str = Field(default="", max_length=400)


class NewsIn(BaseModel):
    items: list[NewsItemIn] = Field(default_factory=list, max_length=50)


class UiLinkIn(BaseModel):
    text: str = Field(default="", max_length=60)
    url: str = Field(default="", max_length=400)


class UiFeedIn(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    title: str = Field(default="", max_length=60)
    more_text: str = Field(default="", alias="moreText", max_length=60)
    more_url: str = Field(default="", alias="moreUrl", max_length=400)
    items: list[NewsItemIn] = Field(default_factory=list, max_length=20)


class UiPlayIn(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    text: str = Field(default="", max_length=30)
    update_text: str = Field(default="", alias="updateText", max_length=30)


class UiIn(BaseModel):
    header: UiLinkIn | None = None
    links: list[UiLinkIn] = Field(default_factory=list, max_length=8)
    news: UiFeedIn | None = None
    community: UiFeedIn | None = None
    play: UiPlayIn | None = None


# --- ручки ----------------------------------------------------------------

@app.get("/health")
def health() -> dict:
    """Жив ли сервис и видит ли он то, что ему смонтировали."""
    import ctypes.util
    return {
        "ok": True,
        "build_py": os.path.isfile(BUILD_PY),
        "workdir": os.path.isdir(WORKDIR),
        "base_ready": os.path.isdir(os.path.join(WORKDIR, "base")),
        "cdn": os.path.isdir(os.path.join(REPO, "launcher", "cdn")),
        "stormlib": bool(ctypes.util.find_library("storm")
                         or os.path.exists("/usr/local/lib/libstorm.so.9")),
    }


@app.get("/status")
def status() -> dict:
    with _lock:
        out = dict(_state)
    out["log_tail"] = _tail(40)
    return out


@app.get("/log", response_class=PlainTextResponse)
def log(tail: int = 0) -> str:
    return _tail(tail) if tail else _read_log()


@app.post("/build", status_code=202)
def build(payload: BuildIn,
          x_builder_token: str | None = Header(default=None)) -> dict:
    _check(x_builder_token)
    args = ["build"]
    if payload.dry_run:
        args.append("--dry-run")
    if payload.no_publish:
        args.append("--no-publish")
    if payload.no_manifest:
        args.append("--no-manifest")
    return _start(args)


@app.post("/bootstrap", status_code=202)
def bootstrap(payload: BootstrapIn,
              x_builder_token: str | None = Header(default=None)) -> dict:
    _check(x_builder_token)
    args = ["bootstrap"]
    if payload.force:
        args.append("--force")
    return _start(args)


# --- витрина лаунчера -----------------------------------------------------
#
# Правит её панель, но пишет сюда только этот сервис: право писать в
# launcher/cdn - то есть в то, что качают игроки, - живёт в одном месте.

DATE_FORMS = (re.compile(r"^\d{4}-\d{2}-\d{2}$"),
              re.compile(r"^\d{2}\.\d{2}\.\d{4}$"))


def _check_item(item: NewsItemIn, where: str) -> None:
    """Дата и ссылка - ровно то, что лаунчер умеет прочесть, и ничего сверх."""
    if item.date and not any(form.match(item.date) for form in DATE_FORMS):
        raise HTTPException(
            422, "%s: дата «%s» не читается. Нужно 2026-09-17 или 17.09.2026."
                 % (where, item.date))
    if item.url and not item.url.startswith(("http://", "https://")):
        raise HTTPException(422, "%s: ссылка должна начинаться с http:// или "
                                 "https://." % where)


def _read_json(path: str, empty: dict) -> dict:
    if not os.path.isfile(path):
        return empty
    try:
        with open(path, encoding="utf-8") as src:
            return json.load(src)
    except (OSError, ValueError) as exc:
        raise HTTPException(500, "%s не читается: %s"
                            % (os.path.basename(path), exc)) from exc


def _prune(value):
    """Выбрасывает пустое: файл на CDN правят и руками, лишние \"\" мешают.

    Лаунчер необязательные поля и так подставляет сам (UiDoc.Normalized),
    поэтому пустая строка в файле не значит ничего, кроме шума.
    """
    if isinstance(value, dict):
        cleaned = {k: _prune(v) for k, v in value.items()}
        return {k: v for k, v in cleaned.items()
                if v not in ("", None, [], {})}
    if isinstance(value, list):
        return [_prune(v) for v in value]
    return value


def _write_json(path: str, payload: dict) -> dict:
    """Пишем через временный файл и оставляем прежний рядом как .bak.

    Лаунчер тянет файл в момент запуска, и застать его наполовину записанным -
    значит показать игроку пустую ленту. Переименование атомарно, поэтому
    такого окна нет вовсе.
    """
    if not os.path.isdir(CDN_DIR):
        raise HTTPException(503, "Каталог CDN не примонтирован: " + CDN_DIR)
    body = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as dst:
        dst.write(body)
    if os.path.isfile(path):
        try:
            os.replace(path, path + ".bak")
        except OSError:
            pass
    os.replace(tmp, path)
    return {"ok": True, "path": os.path.basename(path), "bytes": len(body)}


@app.get("/cdn/news")
def cdn_news() -> dict:
    return _read_json(NEWS_PATH, {"items": []})


@app.put("/cdn/news")
def cdn_put_news(payload: NewsIn,
                 x_builder_token: str | None = Header(default=None)) -> dict:
    _check(x_builder_token)
    for index, item in enumerate(payload.items, 1):
        _check_item(item, "новость %d" % index)
    body = _prune(payload.model_dump(by_alias=True, exclude_none=True))
    # items обязателен даже пустой: без него лаунчер не отличит «новостей нет»
    # от «файл побился».
    body.setdefault("items", [])
    return _write_json(NEWS_PATH, body)


@app.get("/cdn/ui")
def cdn_ui() -> dict:
    return _read_json(UI_PATH, {})


@app.put("/cdn/ui")
def cdn_put_ui(payload: UiIn,
               x_builder_token: str | None = Header(default=None)) -> dict:
    _check(x_builder_token)
    for feed, label in ((payload.news, "новости"),
                        (payload.community, "сообщество")):
        for index, item in enumerate(feed.items if feed else [], 1):
            _check_item(item, "%s: строка %d" % (label, index))
    for index, link in enumerate(payload.links, 1):
        if link.url and not link.url.startswith(("http://", "https://")):
            raise HTTPException(422, "кнопка %d: ссылка должна начинаться с "
                                     "http:// или https://." % index)
    return _write_json(UI_PATH, _prune(payload.model_dump(by_alias=True,
                                                          exclude_none=True)))


@app.post("/status/refresh")
def refresh(x_builder_token: str | None = Header(default=None)) -> dict:
    """`status` без сборки - для страницы, которая только смотрит."""
    _check(x_builder_token)
    return status()


def _read_log() -> str:
    if not os.path.isfile(LOG_PATH):
        return "(лога ещё нет - сборка ни разу не запускалась)"
    with open(LOG_PATH, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def _tail(lines: int) -> str:
    text = _read_log()
    parts = text.splitlines()
    return "\n".join(parts[-lines:]) if lines else text
