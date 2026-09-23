"""AzerothCore admin panel — the server's control node.

Three things live here: a home page listing what can be managed
(`registry.py`), per-module editors (today only mod-environmental-effects,
`envfx.py`), and a board of bugs / feature ideas (`board.py`).

Module editors write PTR only. Panel data — the board, the people who may
use the panel, and the audit log — lives in its own schema; see
`paneldb.py`. Every request is authorised by role (`users.py`) and every
change is recorded (`audit.py`).
"""

import os

from fastapi import Depends, FastAPI, HTTPException, Query, Request, Response
from fastapi.responses import (FileResponse, JSONResponse, PlainTextResponse,
                               RedirectResponse)
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import (apply as apply_mod, aprof, audit, board, config, dbc, envfx,
               export, italents, items, loot, patch, registry, soap, spelldex,
               spells, tooltip, users, weather, worlditems)
from .db import query_one

STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")

# Новый фронтенд (Angular) - отдельная сборка, которая живёт под /ui/ рядом со
# старыми страницами. В образе она лежит в /app/web (кладёт Dockerfile), при
# локальном запуске берётся из frontend/dist. Нет сборки - нет и страницы:
# старая панель от этого не зависит.
WEB_DIR = os.environ.get("ADMIN_WEB_DIR") or os.path.join(
    os.path.dirname(__file__), "..", "web")
if not os.path.isdir(WEB_DIR):
    WEB_DIR = os.path.join(os.path.dirname(__file__), "..", "frontend",
                           "dist", "admin-panel-web", "browser")
WEB_DIR = os.path.abspath(WEB_DIR)

app = FastAPI(title="AzerothCore Admin", docs_url="/api/docs", redoc_url=None)


# --- auth -----------------------------------------------------------------
# Two ways in, in this order:
#   1. a session cookie, i.e. a real profile with a real role (`users.py`);
#   2. the shared ADMIN_TOKEN, which acts as `users.ROOT` (owner).
# The token stays because it is the bootstrap — somebody has to mint the first
# invite — and the break-glass if the session tables ever go wrong. It is not
# the everyday path any more.


def _caller(request: Request) -> users.Actor | None:
    session = request.cookies.get(users.SESSION_COOKIE, "")
    if session:
        actor = users.actor_for_session(session)
        if actor:
            return actor
    supplied = (request.headers.get("X-Admin-Token")
                or request.query_params.get("token", ""))
    if config.ADMIN_TOKEN and supplied == config.ADMIN_TOKEN:
        return users.ROOT
    return None


def _role_dep(need: users.Role):
    def dependency(request: Request) -> users.Actor:
        actor = _caller(request)
        if actor is None:
            raise HTTPException(401, "Нужен вход в панель.")
        # Stashed on the ASGI scope, not on a local: the audit middleware runs
        # around this call and reads the caller from there. Set before the role
        # check so a refused attempt is logged with a name on it.
        request.scope["actor"] = actor
        if not actor.can(need):
            raise HTTPException(
                403, f"Нужна роль «{users.ROLE_LABEL[need]}» или выше; "
                     f"у тебя «{users.ROLE_LABEL[actor.role]}».")
        return actor
    return dependency


Viewer = Depends(_role_dep("viewer"))
Editor = Depends(_role_dep("editor"))
Owner = Depends(_role_dep("owner"))


@app.exception_handler(users.UserError)
async def _user_error(_: Request, exc: users.UserError) -> JSONResponse:
    return JSONResponse(status_code=400, content={"detail": str(exc)})


# --- caching --------------------------------------------------------------

@app.middleware("http")
async def revalidate_static(request: Request, call_next):
    """Make the browser re-check every page and script.

    Without this the panel's own files are cached heuristically, and a rebuild
    leaves the browser mixing a new page script with an old common.js — which
    fails as "helpBadge is not defined" rather than as anything obvious. The
    ETag still answers with 304, so revalidation costs nothing on a local tool.
    """
    response = await call_next(request)
    path = request.url.path
    if path.startswith("/static/") or path.endswith(".html") or path == "/":
        response.headers["Cache-Control"] = "no-cache"
    return response


@app.middleware("http")
async def audit_changes(request: Request, call_next):
    """Record every mutating API call, whoever made it.

    Deliberately blanket rather than per-endpoint: a log that each endpoint has
    to remember to write is a log with holes in it. `audit.describe()` turns
    the method and path into a readable line, and unknown paths still get a
    terse row instead of silence.

    The body is read here and replayed downstream — Starlette caches it on the
    request for exactly this case, so the endpoint still sees its payload.
    """
    if request.method == "GET" or not request.url.path.startswith("/api/"):
        return await call_next(request)
    body = await request.body()
    response = await call_next(request)
    audit.record(actor=request.scope.get("actor"), method=request.method,
                 path=request.url.path, status=response.status_code,
                 raw_body=body)
    # Та же прослойка ведёт реестр «мир ещё не в курсе»: см. apply.py. Здесь,
    # а не в обработчиках, ровно по той же причине, что и журнал.
    apply_mod.mark(actor=request.scope.get("actor"), method=request.method,
                   path=request.url.path, status=response.status_code)
    return response


@app.exception_handler(config.ConfigError)
async def _config_error(_: Request, exc: config.ConfigError) -> JSONResponse:
    return JSONResponse(status_code=500, content={"detail": str(exc)})


# --- meta -----------------------------------------------------------------

@app.get("/api/health")
def health(_: users.Actor = Viewer) -> dict:
    out: dict = {"schema": config.DB_NAME, "ptr_guard": not config.ALLOW_NON_PTR}
    try:
        row = query_one("SELECT COUNT(*) AS n FROM `%s`" % envfx.TABLE)
        out["db"] = {"ok": True, "rules": int(row["n"]) if row else 0}
    except Exception as exc:
        out["db"] = {"ok": False, "error": str(exc)}

    try:
        out["board"] = {"ok": True, **board.stats()}
    except Exception as exc:
        out["board"] = {"ok": False, "error": str(exc)}

    # spell_dbc is only read at worldserver startup, so a saved spell is not
    # live until PTR restarts — say so on the home page rather than let it
    # look applied.
    try:
        out["spells"] = spells.pending_restart()
    except Exception as exc:
        out["spells"] = {"known": False, "count": 0, "reason": str(exc)}

    # Only checks that the DBC volume is readable — building the catalogue
    # index takes seconds and has no business running on a health poll.
    out["dex"] = {"ok": spelldex.available(), "dir": config.DBC_DIR}

    if not soap.configured():
        out["soap"] = {"ok": False, "error": "credentials not configured"}
    else:
        try:
            soap.ping()
            out["soap"] = {"ok": True, "host": f"{config.SOAP_HOST}:{config.SOAP_PORT}"}
        except soap.SoapError as exc:
            out["soap"] = {"ok": False, "error": str(exc)}

    out["export_path"] = config.SEED_SQL
    out["export_writable"] = os.path.isdir(os.path.dirname(config.SEED_SQL))
    out["zones_known"] = len(dbc.zone_names())
    out["spells_known"] = len(dbc.spell_meta())
    out["icon_base_url"] = config.ICON_BASE_URL

    # Reference files degrade silently when a mount is wrong (no zone names, no
    # spell metadata, no export) — so report them explicitly instead of leaving
    # a bare zero to be interpreted.
    problems = []
    if not os.path.isfile(config.AREATABLE_CSV):
        problems.append(f"AreaTable.csv не найден: {config.AREATABLE_CSV} — "
                        f"имена зон недоступны")
    if not os.path.isfile(config.MANIFEST_CSV):
        problems.append(f"client_manifest.csv не найден: {config.MANIFEST_CSV} — "
                        f"имена и иконки спеллов недоступны")
    if not out["export_writable"]:
        problems.append(f"каталог миграций не примонтирован: "
                        f"{os.path.dirname(config.SEED_SQL)} — экспорт не сработает")
    out["files_ok"] = not problems
    out["file_problems"] = problems
    return out


# --- zones ----------------------------------------------------------------

@app.get("/api/zones")
def list_zones(_: users.Actor = Viewer) -> list[dict]:
    return envfx.zone_summaries()


@app.get("/api/zones/search")
def search_zones(q: str = Query(min_length=1),
                 _: users.Actor = Viewer) -> list[dict]:
    needle = q.strip().lower()
    hits = []
    for zone_id, name in dbc.zone_names().items():
        if needle in name.lower() or needle == str(zone_id):
            hits.append({"zone_id": zone_id, "name": name})
    hits.sort(key=lambda z: (not z["name"].lower().startswith(needle), z["name"]))
    return hits[:40]


@app.get("/api/zones/{zone_id}")
def get_zone(zone_id: int, _: users.Actor = Viewer) -> dict:
    return envfx.zone_rules(zone_id)


class SaveResult(BaseModel):
    saved: int
    problems: list[envfx.ValidationProblem]
    reloaded: bool
    reload_output: str | None = None


@app.put("/api/zones/{zone_id}")
def put_zone(zone_id: int, payload: envfx.ZoneRules,
             reload: bool = Query(True),
             force: bool = Query(False),
             _: users.Actor = Editor) -> SaveResult:
    problems = envfx.validate(zone_id, payload)
    errors = [p for p in problems if p.level == "error"]
    if errors and not force:
        raise HTTPException(422, {
            "detail": "Правила не сохранены: есть ошибки.",
            "problems": [p.model_dump() for p in problems],
        })

    saved = envfx.save_zone(zone_id, payload)

    reloaded, output = False, None
    if reload:
        try:
            output = soap.reload_config()
            reloaded = True
            apply_mod.clear("envfx")
        except soap.SoapError as exc:
            output = f"SOAP: {exc}"

    return SaveResult(saved=saved, problems=problems,
                      reloaded=reloaded, reload_output=output)


@app.delete("/api/zones/{zone_id}")
def del_zone(zone_id: int, _: users.Actor = Editor) -> dict:
    return {"deleted": envfx.delete_zone(zone_id)}


# --- env-effects spell picker ---------------------------------------------
# Named for its module: /api/spells belongs to the workshop below, and a
# function called `spells` here would shadow the imported module.

@app.get("/api/envfx/meta")
def envfx_meta(_: users.Actor = Viewer) -> dict:
    """Адрес каталога иконок. Отдельной ручкой, а не из `/api/health`: тот
    ходит в базу и по SOAP, а странице правил нужна одна строка."""
    return {"icon_base_url": config.ICON_BASE_URL}


@app.get("/api/envfx/spells")
def envfx_spells(_: users.Actor = Viewer) -> list[dict]:
    return envfx.spell_catalog()


# --- actions --------------------------------------------------------------

@app.post("/api/reload")
def reload_rules(_: users.Actor = Editor) -> dict:
    try:
        output = soap.reload_config()
        apply_mod.clear("envfx")
        return {"ok": True, "output": output}
    except soap.SoapError as exc:
        raise HTTPException(502, str(exc)) from exc


@app.post("/api/export")
def export_sql(_: users.Actor = Owner) -> dict:
    try:
        return {"ok": True, **export.write()}
    except OSError as exc:
        raise HTTPException(500, str(exc)) from exc


@app.get("/api/apply")
def apply_state(_: users.Actor = Viewer) -> dict:
    """Что из сохранённого ещё не доехало до живого мира."""
    return apply_mod.state()


@app.get("/api/exports")
def apply_exports(kind: str = Query("", pattern="^(sql|client)?$"),
                  _: users.Actor = Viewer) -> dict:
    """Выгрузки на диск: куда пишем, когда писали и что с тех пор изменилось.

    `kind` не для удобства, а ради цены: сверка клиентского CSV разбирает
    восьмимегабайтный файл, и страница миграций не должна за это платить.
    """
    return {"artefacts": apply_mod.artefacts(kind)}


@app.post("/api/apply")
def apply_run(target: str = Query("", max_length=24),
              actor: users.Actor = Editor) -> dict:
    """Перечитать мир по всем ждущим модулям (или по одному).

    Роль проверяется по модулю, а не по обработчику: добычу и профессии
    перечитывает владелец, остальное - редактор. «Применить всё» редактором
    поэтому не молчит про чужое, а честно отказывает целиком.
    """
    if target in apply_mod.MANUAL:
        need = apply_mod.MANUAL[target]
        if not actor.can(need.role):
            raise HTTPException(403, "«%s» применяет %s или выше." % (
                need.label, users.ROLE_LABEL[need.role]))
        return apply_mod.run(target)

    for entry in apply_mod.state()["waiting"]:
        if target and entry["key"] != target:
            continue
        if not actor.can(entry["role"]):
            raise HTTPException(
                403, "«%s» применяет %s или выше." % (
                    entry["label"], users.ROLE_LABEL[entry["role"]]))
    return apply_mod.run(target)


@app.post("/api/refresh-cache")
def refresh_cache(_: users.Actor = Owner) -> dict:
    dbc.reload_cache()
    spells.reload_cache()
    # Picks up a regenerated Spell_custom.csv / SpellIcon_custom.csv without a
    # container restart. Costs a few seconds on the next catalogue request.
    spelldex.reload_files()
    return {"ok": True, "zones": len(dbc.zone_names()),
            "spells": len(dbc.spell_meta())}


# --- клиентский патч ------------------------------------------------------
# Патч собирает не панель, а ac-patch-builder (см. `patch.py`): у него есть
# StormLib и право писать в launcher/cdn. Здесь только «нажали кнопку -
# передали дальше и показали, что он ответил».

@app.get("/api/patch/status")
def patch_status(_: users.Actor = Viewer) -> dict:
    """Состояние сборщика. Отвечает 200 и когда сборщик молчит - главную
    страницу опрашивают по таймеру, и мёртвый контейнер не повод её ломать."""
    return patch.state()


@app.get("/api/patch/log", response_class=PlainTextResponse)
def patch_log(tail: int = Query(0, ge=0, le=5000),
              _: users.Actor = Viewer) -> str:
    try:
        return patch.log(tail)
    except patch.PatchError as exc:
        raise HTTPException(503, str(exc)) from exc


class PatchBuild(BaseModel):
    # Ровно те три флага, что понимает build.py в командной строке.
    dry_run: bool = False
    no_publish: bool = False
    no_manifest: bool = False


@app.post("/api/patch/build")
def patch_build(payload: PatchBuild, _: users.Actor = Owner) -> dict:
    """Собрать патч.

    Владелец даже на `--dry-run`: сборщик один на всех и занят целиком, так
    что безобидная проверка отнимает его у настоящей сборки.
    """
    try:
        return {"ok": True, **patch.build(payload.dry_run, payload.no_publish,
                                          payload.no_manifest)}
    except patch.PatchError as exc:
        raise HTTPException(503, str(exc)) from exc


class PatchBootstrap(BaseModel):
    force: bool = False


@app.post("/api/patch/bootstrap")
def patch_bootstrap(payload: PatchBootstrap, _: users.Actor = Owner) -> dict:
    """Снять базу DBC заново с архивов CDN - после смены самого клиента."""
    try:
        return {"ok": True, **patch.bootstrap(payload.force)}
    except patch.PatchError as exc:
        raise HTTPException(503, str(exc)) from exc


# --- витрина лаунчера -----------------------------------------------------
#
# Новости и подписи окна лежат на CDN (`launcher/cdn/news.json` и `ui.json`).
# Панель их только правит, пишет - сборщик: право писать в то, что качают
# игроки, живёт в одном месте. Зато и ждать нечего - в манифест эти файлы не
# входят, лаунчер читает их при каждом запуске.

class CdnNewsItem(BaseModel):
    date: str = ""
    title: str = Field(min_length=1, max_length=120)
    body: str = Field(default="", max_length=800)
    url: str = Field(default="", max_length=400)


class CdnNews(BaseModel):
    items: list[CdnNewsItem] = Field(default_factory=list, max_length=50)


@app.get("/api/cdn/news")
def cdn_news(_: users.Actor = Editor) -> dict:
    try:
        return patch.news()
    except patch.PatchError as exc:
        raise HTTPException(503, str(exc)) from exc


@app.put("/api/cdn/news")
def cdn_put_news(payload: CdnNews, _: users.Actor = Owner) -> dict:
    """Владелец: это видят все игроки при следующем запуске лаунчера."""
    try:
        return {"ok": True, **patch.save_news(
            [item.model_dump() for item in payload.items])}
    except patch.PatchError as exc:
        raise HTTPException(_relay(exc), str(exc)) from exc


@app.get("/api/cdn/ui")
def cdn_ui(_: users.Actor = Editor) -> dict:
    try:
        return patch.ui()
    except patch.PatchError as exc:
        raise HTTPException(503, str(exc)) from exc


@app.put("/api/cdn/ui")
def cdn_put_ui(payload: dict, _: users.Actor = Owner) -> dict:
    """Схему проверяет сборщик - он же и пишет; лишний разбор тут был бы
    вторым описанием того же самого, которое разойдётся с первым."""
    try:
        return {"ok": True, **patch.save_ui(payload)}
    except patch.PatchError as exc:
        raise HTTPException(_relay(exc), str(exc)) from exc


def _relay(exc: patch.PatchError) -> int:
    """Отказ проверки - это 4xx и вина поля, а не связи."""
    return exc.status if 400 <= exc.status < 500 else 503


# --- modules --------------------------------------------------------------

@app.get("/api/modules")
def modules(_: users.Actor = Viewer) -> list[dict]:
    """What the home page shows. Counts come from the board, so a module with
    open bugs says so on its tile."""
    try:
        open_by_module = board.stats()["by_module"]
    except Exception:
        open_by_module = {}
    return [dict(m.model_dump(), open_cards=open_by_module.get(m.id, 0))
            for m in registry.MODULES]


# --- board ----------------------------------------------------------------

@app.get("/api/board/meta")
def board_meta(_: users.Actor = Viewer) -> dict:
    return {
        "kinds": list(board.KINDS),
        "statuses": list(board.STATUSES),
        "modules": [{"id": m.id, "name": m.name} for m in registry.MODULES],
    }


@app.get("/api/board/cards")
def board_cards(status: str | None = None, module: str | None = None,
                kind: str | None = None, q: str | None = None,
                archived: bool = False, _: users.Actor = Viewer) -> list[dict]:
    return board.list_cards(status=status, module=module, kind=kind, q=q,
                            archived=archived)


@app.post("/api/board/cards", status_code=201)
def board_create(payload: board.CardIn, me: users.Actor = Viewer) -> dict:
    # The author is who is signed in, not whatever the form said: the field
    # was free text back when the panel had exactly one operator.
    payload.author = me.name
    return board.create_card(payload)


@app.get("/api/board/cards/{card_id}")
def board_card(card_id: int, _: users.Actor = Viewer) -> dict:
    card = board.get_card(card_id)
    if not card:
        raise HTTPException(404, "Карточка не найдена.")
    return card


@app.patch("/api/board/cards/{card_id}")
def board_patch(card_id: int, payload: board.CardPatch,
                _: users.Actor = Viewer) -> dict:
    card = board.update_card(card_id, payload)
    if not card:
        raise HTTPException(404, "Карточка не найдена.")
    return card


@app.post("/api/board/cards/{card_id}/move")
def board_move(card_id: int, payload: board.Move,
               _: users.Actor = Viewer) -> list[dict]:
    cards = board.move_card(card_id, payload)
    if not cards:
        raise HTTPException(404, "Карточка не найдена.")
    return cards


@app.post("/api/board/cards/{card_id}/restore")
def board_restore(card_id: int, _: users.Actor = Viewer) -> dict:
    card = board.restore_card(card_id)
    if not card:
        raise HTTPException(404, "Карточка не найдена.")
    return card


@app.delete("/api/board/cards/{card_id}")
def board_delete(card_id: int, hard: bool = Query(False),
                 _: users.Actor = Viewer) -> dict:
    if not board.delete_card(card_id, hard=hard):
        raise HTTPException(404, "Карточка не найдена.")
    return {"ok": True, "hard": hard}


@app.post("/api/board/cards/{card_id}/comments")
def board_comment(card_id: int, payload: board.CommentIn,
                  me: users.Actor = Viewer) -> dict:
    payload.author = me.name
    card = board.add_comment(card_id, payload)
    if not card:
        raise HTTPException(404, "Карточка не найдена.")
    return card


@app.get("/api/board/stats")
def board_stats(_: users.Actor = Viewer) -> dict:
    return board.stats()


# --- spell workshop -------------------------------------------------------
# Specific paths are declared before /api/spells/{spell_id} so a literal like
# "catalog" is never parsed as an id.

@app.get("/api/spells/catalog")
def spell_catalog_all(_: users.Actor = Viewer) -> dict:
    return spells.catalog()


@app.get("/api/spells/next-id")
def spell_next_id(block: str = Query(...), _: users.Actor = Viewer) -> dict:
    """The id a new spell would get in `block`, plus that block's occupancy.

    `id` is the first free id of the pool — the editor shows it the moment the
    operator picks a module, before anything is written.
    """
    status = spells.block_status(block)
    if status is None:
        raise HTTPException(404, "Неизвестный блок ID: %s" % block)
    if status["next_free"] is None:
        raise HTTPException(409, "В блоке «%s» не осталось свободных ID."
                            % status["name"])
    return {"block": block, "id": status["next_free"],
            "name": status["name"], "module": status["module"],
            "lo": status["lo"], "hi": status["hi"],
            "used": status["used"], "size": status["size"]}


@app.get("/api/spells/pending-restart")
def spell_pending(_: users.Actor = Viewer) -> dict:
    return spells.pending_restart()


@app.get("/api/spells/clone/{source_id}")
def spell_clone(source_id: int, block: str = Query("workshop"),
                _: users.Actor = Viewer) -> dict:
    """A copy of any spell — ours, stock, or overridden — as an unsaved draft.

    Nothing is written here: the draft goes back to the editor and the normal
    POST /api/spells does the saving, so a copy passes exactly the same
    validation as a spell filled in by hand.
    """
    try:
        return spells.clone_draft(source_id, block)
    except LookupError as exc:
        raise HTTPException(404, str(exc))
    except ValueError as exc:
        raise HTTPException(409, str(exc))


@app.get("/api/spells")
def spell_list(block: str | None = None, module: str | None = None,
               q: str | None = None, school: int | None = None,
               effect: int | None = None, aura: int | None = None,
               proc_min: int | None = None, proc_max: int | None = None,
               _: users.Actor = Viewer) -> list[dict]:
    return spells.list_spells(block=block, module=module, q=q, school=school,
                              effect=effect, aura=aura, proc_min=proc_min,
                              proc_max=proc_max)


@app.get("/api/spells/page")
def spell_page(block: str | None = None, module: str | None = None,
               q: str | None = None, school: int | None = None,
               effect: int | None = None, aura: int | None = None,
               proc_min: int | None = None, proc_max: int | None = None,
               offset: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=200),
               _: users.Actor = Viewer) -> dict:
    """Paginated workshop list; `/api/spells` remains for the legacy page."""
    return spells.search_spells(
        block=block, module=module, q=q, school=school, effect=effect,
        aura=aura, proc_min=proc_min, proc_max=proc_max, offset=offset,
        limit=limit)


@app.get("/api/spells/{spell_id}")
def spell_get(spell_id: int, _: users.Actor = Viewer) -> dict:
    spell = spells.get_spell(spell_id)
    if not spell:
        raise HTTPException(404, "Спелл не найден.")
    return spell


class SpellSaved(BaseModel):
    id: int
    problems: list[spells.ValidationProblem]
    restart_required: bool = True


def _save_spell(payload: spells.SpellIn, creating: bool,
                force: bool) -> SpellSaved:
    if payload.id is None:
        if not payload.block:
            raise HTTPException(422, "Нужен ID или блок для его выдачи.")
        allocated = spells.next_free_id(payload.block)
        if allocated is None:
            raise HTTPException(409, "В блоке нет свободных ID.")
        payload.id = allocated

    fields = spells._clean_fields(payload.fields)
    problems = spells.validate(payload.id, fields, payload.icon_texture,
                               creating)
    if any(p.level == "error" for p in problems) and not force:
        raise HTTPException(422, {
            "detail": "Спелл не сохранён: есть ошибки.",
            "problems": [p.model_dump() for p in problems],
        })
    spell_id = spells.save_spell(payload, creating)
    # The catalogue caches the DBC + spell_dbc merge; a write here is the only
    # thing that can make it stale.
    spelldex.invalidate()
    return SpellSaved(id=spell_id, problems=problems)


@app.post("/api/spells", status_code=201)
def spell_create(payload: spells.SpellIn, force: bool = Query(False),
                 _: users.Actor = Owner) -> SpellSaved:
    return _save_spell(payload, creating=True, force=force)


@app.put("/api/spells/{spell_id}")
def spell_update(spell_id: int, payload: spells.SpellIn,
                 force: bool = Query(False),
                 _: users.Actor = Owner) -> SpellSaved:
    payload.id = spell_id
    if not spells.get_spell(spell_id):
        raise HTTPException(404, "Спелл не найден.")
    return _save_spell(payload, creating=False, force=force)


@app.delete("/api/spells/{spell_id}")
def spell_delete(spell_id: int, _: users.Actor = Owner) -> dict:
    if not spells.delete_spell(spell_id):
        raise HTTPException(404, "Спелл не найден.")
    spelldex.invalidate()
    return {"ok": True}


@app.post("/api/spells/export/sql")
def spell_export_sql(block: str | None = None, _: users.Actor = Owner) -> dict:
    try:
        return {"ok": True, **spells.export_sql(block)}
    except OSError as exc:
        raise HTTPException(500, str(exc)) from exc


@app.post("/api/spells/export/client")
def spell_export_client(_: users.Actor = Owner) -> dict:
    try:
        return {"ok": True, **spells.export_client()}
    except (OSError, ValueError) as exc:
        raise HTTPException(500, str(exc)) from exc


# --- item catalogue -------------------------------------------------------
# Search spans all 277 290 rows of item_template; editing is confined to the
# panel's own id blocks. Stock items are read-only on purpose — see
# `items._guard` for why.

@app.get("/api/items/meta")
def item_meta(_: users.Actor = Viewer) -> dict:
    """Everything the editor needs to render itself: blocks, fields, enums."""
    return {
        "blocks": items.block_status(),
        "groups": items.field_catalogue(),
        "enums": items.enums(),
        "icons_available": items.available(),
        "icon_base_url": config.ICON_BASE_URL,
    }


@app.get("/api/items/enums")
def item_enums(_: users.Actor = Viewer) -> dict:
    """Только справочники - для окон выбора, которым весь meta ни к чему."""
    return {"enums": items.enums(), "icon_base_url": config.ICON_BASE_URL}


@app.get("/api/items")
def item_search(q: str = "", block: str | None = None,
                quality: int | None = None, item_class: int | None = None,
                inventory_type: int | None = None, item_subclass: int | None = None,
                item_level_min: int | None = None, item_level_max: int | None = None,
                required_level_min: int | None = None, required_level_max: int | None = None,
                limit: int = Query(60, ge=1, le=200),
                offset: int = Query(0, ge=0),
                _: users.Actor = Viewer) -> dict:
    return items.search(q=q, block=block, quality=quality, item_class=item_class,
                        inventory_type=inventory_type, item_subclass=item_subclass,
                        item_level_min=item_level_min,
                        item_level_max=item_level_max, required_level_min=required_level_min,
                        required_level_max=required_level_max, limit=limit, offset=offset)


@app.get("/api/items/clone/{source_id}")
def item_clone(source_id: int, block: str = Query("workshop"),
               _: users.Actor = Viewer) -> dict:
    """A copy of any item as an unsaved draft.

    Nothing is written here: the draft goes back to the editor and the normal
    PUT does the saving, so a copy passes the same checks as a hand-filled one.
    """
    try:
        draft = items.clone_draft(source_id, block)
    except ValueError as exc:
        raise HTTPException(409, str(exc)) from exc
    if not draft:
        raise HTTPException(404, "Предмет %d не найден." % source_id)
    return draft


@app.get("/api/items/{entry}")
def item_get(entry: int, _: users.Actor = Viewer) -> dict:
    row = items.get(entry)
    if not row:
        raise HTTPException(404, "Предмет %d не найден." % entry)
    return row


class ItemIn(BaseModel):
    fields: dict


@app.put("/api/items/{entry}")
def item_save(entry: int, payload: ItemIn, _: users.Actor = Owner) -> dict:
    try:
        return items.save(entry, dict(payload.fields))
    except ValueError as exc:
        raise HTTPException(409, str(exc)) from exc


@app.delete("/api/items/{entry}")
def item_delete(entry: int, _: users.Actor = Owner) -> dict:
    if not items.get(entry):
        raise HTTPException(404, "Предмет %d не найден." % entry)
    try:
        items.delete(entry)
    except ValueError as exc:
        raise HTTPException(409, str(exc)) from exc
    return {"ok": True}


@app.get("/api/items/{entry}/tooltip")
def item_tooltip(entry: int, _: users.Actor = Viewer) -> dict:
    """Подсказка «как в игре»: строки и их цвета (см. `tooltip.py`)."""
    data = tooltip.build(entry)
    if not data:
        raise HTTPException(404, "Предмет %d не найден." % entry)
    return data


@app.get("/api/items/{entry}/client-row")
def item_client_row(entry: int, _: users.Actor = Viewer) -> dict:
    row = items.export_client(entry)
    if not row:
        raise HTTPException(404, "Предмет %d не найден." % entry)
    return row


@app.post("/api/items/export/client")
def item_export_client(_: users.Actor = Owner) -> dict:
    try:
        return {"ok": True, **items.export_client_csv()}
    except (OSError, ValueError) as exc:
        raise HTTPException(500, str(exc)) from exc


@app.post("/api/items/export/sql")
def item_export_sql(_: users.Actor = Owner) -> dict:
    try:
        return {"ok": True, **items.export_sql()}
    except OSError as exc:
        raise HTTPException(500, str(exc)) from exc


# --- world items ----------------------------------------------------------
# Placements are created in game, by the addon: a point cannot be picked on a
# browser map — there is no height there and no room geometry, and the object
# has to be sat on the ground and turned. The panel owns everything else.

@app.get("/api/worlditems/meta")
def world_item_meta(_: users.Actor = Viewer) -> dict:
    return {"available": worlditems.available(),
            "icon_base_url": config.ICON_BASE_URL}


@app.get("/api/worlditems")
def world_item_list(only_enabled: bool = False,
                    _: users.Actor = Viewer) -> dict:
    if not worlditems.available():
        raise HTTPException(503, "Таблицы mod_world_items нет — примените "
                                 "миграцию и пересоберите worldserver.")
    return {"items": worlditems.list_all(only_enabled=only_enabled)}


class WorldItemIn(BaseModel):
    fields: dict


@app.patch("/api/worlditems/{placement_id}")
def world_item_update(placement_id: int, payload: WorldItemIn,
                      _: users.Actor = Owner) -> dict:
    try:
        row = worlditems.update(placement_id, dict(payload.fields))
    except ValueError as exc:
        raise HTTPException(409, str(exc)) from exc
    if not row:
        raise HTTPException(404, "Размещение %d не найдено." % placement_id)
    return row


@app.delete("/api/worlditems/{placement_id}")
def world_item_delete(placement_id: int, _: users.Actor = Owner) -> dict:
    if not worlditems.delete(placement_id):
        raise HTTPException(404, "Размещение %d не найдено." % placement_id)
    return {"ok": True}


@app.post("/api/worlditems/{placement_id}/reset-loot")
def world_item_reset(placement_id: int, _: users.Actor = Owner) -> dict:
    """Forget who picked this up, so it becomes visible to them again.

    Needed after re-pointing a placement at a different item: everyone who
    already looted the old one would otherwise never see the new one.
    """
    return {"ok": True, "forgotten": worlditems.reset_loot(placement_id)}


# --- advanced professions -------------------------------------------------
# Числовая часть крафта целиком в базе: материалы, основы, синергии и веса
# качества. Добавить камень должно быть правкой строки, а не пересборкой
# worldserver — поэтому редактор здесь, а не в .conf.

@app.get("/api/aprof/meta")
def aprof_meta(_: users.Actor = Viewer) -> dict:
    return aprof.meta()


def _aprof(fn):
    """Отказы модуля — это сообщения человеку, а не 500-я."""
    try:
        return fn()
    except aprof.ApError as exc:
        raise HTTPException(409, str(exc)) from exc


@app.get("/api/aprof/materials")
def aprof_materials(_: users.Actor = Viewer) -> dict:
    return {"materials": _aprof(aprof.materials)}


@app.put("/api/aprof/materials")
def aprof_put_material(payload: aprof.Material, _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.save_material(payload))


@app.delete("/api/aprof/materials/{entry}")
def aprof_del_material(entry: int, _: users.Actor = Owner) -> dict:
    _aprof(lambda: aprof.delete_material(entry))
    return {"ok": True}


# Справочники рода и типа вставки. Ручки раздельные, а не одна с параметром:
# так и права, и адреса читаются без оговорок, а тела у них всё равно одной
# формы (DESIGN §2.5).
@app.get("/api/aprof/part-kinds")
def aprof_part_kinds(_: users.Actor = Viewer) -> dict:
    return {"rows": _aprof(aprof.part_kinds)}


@app.put("/api/aprof/part-kinds")
def aprof_put_part_kind(payload: aprof.DictRow, _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.save_dict_row(aprof.T_PART_KIND, payload))


@app.delete("/api/aprof/part-kinds/{row_id}")
def aprof_del_part_kind(row_id: int, _: users.Actor = Owner) -> dict:
    _aprof(lambda: aprof.delete_dict_row(aprof.T_PART_KIND, row_id))
    return {"ok": True}


@app.get("/api/aprof/insert-types")
def aprof_insert_types(_: users.Actor = Viewer) -> dict:
    return {"rows": _aprof(aprof.insert_types)}


@app.put("/api/aprof/insert-types")
def aprof_put_insert_type(payload: aprof.DictRow, _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.save_dict_row(aprof.T_INSERT_TYPE, payload))


@app.delete("/api/aprof/insert-types/{row_id}")
def aprof_del_insert_type(row_id: int, _: users.Actor = Owner) -> dict:
    _aprof(lambda: aprof.delete_dict_row(aprof.T_INSERT_TYPE, row_id))
    return {"ok": True}


@app.get("/api/aprof/types")
def aprof_types(_: users.Actor = Viewer) -> dict:
    """Типы предметов — то, что игрок выбирает в левом списке верстака."""
    return {"types": _aprof(aprof.types)}


@app.put("/api/aprof/types")
def aprof_put_type(payload: aprof.ItemType, _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.save_type(payload))


@app.delete("/api/aprof/types/{type_id}")
def aprof_del_type(type_id: int, _: users.Actor = Owner) -> dict:
    _aprof(lambda: aprof.delete_type(type_id))
    return {"ok": True}


@app.get("/api/aprof/types/{type_id}/parts")
def aprof_type_parts(type_id: int, _: users.Actor = Viewer) -> dict:
    """Части типа — из чего он собирается."""
    return {"parts": _aprof(lambda: aprof.parts(type_id))}


@app.put("/api/aprof/types/{type_id}/parts")
def aprof_put_type_part(type_id: int, payload: aprof.Part,
                        _: users.Actor = Owner) -> dict:
    if payload.type_id != type_id:
        raise HTTPException(409, "Часть заявлена для другого типа.")
    return _aprof(lambda: aprof.save_part(payload))


@app.delete("/api/aprof/types/{type_id}/parts/{idx}")
def aprof_del_type_part(type_id: int, idx: int, _: users.Actor = Owner) -> dict:
    _aprof(lambda: aprof.delete_part(type_id, idx))
    return {"ok": True}


@app.get("/api/aprof/recipes")
def aprof_recipes(_: users.Actor = Viewer) -> dict:
    return {"recipes": _aprof(aprof.recipes)}


@app.put("/api/aprof/recipes")
def aprof_put_recipe(payload: aprof.Recipe, _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.save_recipe(payload))


@app.delete("/api/aprof/recipes/{recipe_id}")
def aprof_del_recipe(recipe_id: int, _: users.Actor = Owner) -> dict:
    _aprof(lambda: aprof.delete_recipe(recipe_id))
    return {"ok": True}


@app.get("/api/aprof/recipes/{recipe_id}/cells")
def aprof_recipe_cells(recipe_id: int, _: users.Actor = Viewer) -> dict:
    return _aprof(lambda: aprof.recipe_cells(recipe_id))


@app.put("/api/aprof/recipes/{recipe_id}/cells")
def aprof_put_recipe_cell(recipe_id: int, payload: aprof.RecipeCell,
                          _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.save_recipe_cell(recipe_id, payload))


@app.put("/api/aprof/recipes/{recipe_id}/filters")
def aprof_put_recipe_filters(recipe_id: int, payload: aprof.RecipeFilters,
                             _: users.Actor = Owner) -> dict:
    """Чем основе дают себя украшать: набор типов вставки либо список камней."""
    return _aprof(lambda: aprof.save_recipe_filters(recipe_id, payload))


@app.put("/api/aprof/recipes/{recipe_id}/results")
def aprof_put_recipe_result(recipe_id: int, payload: aprof.RecipeResult,
                            _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.save_recipe_result(recipe_id, payload))


class AprofSample(BaseModel):
    """Образец, с которого снимается копия строки item_template."""
    sample_entry: int


@app.post("/api/aprof/recipes/{recipe_id}/results/generate")
def aprof_gen_results(recipe_id: int, payload: AprofSample,
                      _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.generate_results(recipe_id,
                                                 payload.sample_entry))


@app.post("/api/aprof/recipes/{recipe_id}/results/{quality}/slice")
def aprof_reseed_slice(recipe_id: int, quality: int,
                       _: users.Actor = Owner) -> dict:
    """Нарезать слайс пула ступени и засеять его по виду изделия."""
    return _aprof(lambda: aprof.reseed_slice(recipe_id, quality))


@app.post("/api/aprof/types/{type_id}/fail-item")
def aprof_gen_fail_item(type_id: int, payload: AprofSample,
                        _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.generate_fail_item(type_id,
                                                   payload.sample_entry))


@app.post("/api/aprof/synergies/{syn_id}/named-item")
def aprof_gen_named_item(syn_id: int, payload: AprofSample,
                         _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.generate_named_item(syn_id,
                                                    payload.sample_entry))


@app.get("/api/aprof/synergies")
def aprof_synergies(_: users.Actor = Viewer) -> dict:
    return {"synergies": _aprof(aprof.synergies)}


@app.put("/api/aprof/synergies")
def aprof_put_synergy(payload: aprof.Synergy, _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.save_synergy(payload))


@app.delete("/api/aprof/synergies/{syn_id}")
def aprof_del_synergy(syn_id: int, _: users.Actor = Owner) -> dict:
    _aprof(lambda: aprof.delete_synergy(syn_id))
    return {"ok": True}


@app.post("/api/aprof/merges/{merge_id}/result-item")
def aprof_gen_merge_item(merge_id: int, payload: AprofSample,
                         _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.generate_merge_item(merge_id,
                                                    payload.sample_entry))


@app.get("/api/aprof/merges")
def aprof_merges(_: users.Actor = Viewer) -> dict:
    return {"merges": _aprof(aprof.merges)}


@app.put("/api/aprof/merges")
def aprof_put_merge(payload: aprof.Merge, _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.save_merge(payload))


@app.delete("/api/aprof/merges/{merge_id}")
def aprof_del_merge(merge_id: int, _: users.Actor = Owner) -> dict:
    _aprof(lambda: aprof.delete_merge(merge_id))
    return {"ok": True}


@app.get("/api/aprof/balance")
def aprof_balance(_: users.Actor = Viewer) -> dict:
    return _aprof(aprof.balance)


@app.put("/api/aprof/balance")
def aprof_put_balance(payload: aprof.Balance, _: users.Actor = Owner) -> dict:
    return _aprof(lambda: aprof.save_balance(payload))


@app.get("/api/aprof/ilvl-levels")
def aprof_ilvl_levels(_: users.Actor = Viewer) -> dict:
    """Уровень предмета -> требуемый уровень персонажа (DESIGN §5.5)."""
    return {"rows": _aprof(aprof.ilvl_levels)}


@app.put("/api/aprof/ilvl-levels")
def aprof_put_ilvl_levels(payload: list[aprof.IlvlRow],
                          _: users.Actor = Owner) -> dict:
    return {"rows": _aprof(lambda: aprof.save_ilvl_levels(payload))}


@app.get("/api/aprof/settings")
def aprof_settings(_: users.Actor = Viewer) -> dict:
    return {"settings": _aprof(aprof.settings)}


@app.put("/api/aprof/settings")
def aprof_put_settings(payload: dict[str, str], _: users.Actor = Owner) -> dict:
    return {"settings": _aprof(lambda: aprof.save_settings(payload))}


class AprofMatch(BaseModel):
    """Набор в ячейках схемы: что положили и сколько."""
    type_id: int
    # Вставки в слоты доводки - для суммы статов и проверки сочетания.
    mats: list[int] = []
    skill: int = 1
    # Предметы и их количество по порядку ячеек схемы. Количество - часть
    # набора, а не настройка ячейки (DESIGN §5.4.2).
    part_mats: list[int] = []
    part_counts: list[int] = []


@app.post("/api/aprof/match")
def aprof_match(payload: AprofMatch, _: users.Actor = Viewer) -> dict:
    return _aprof(lambda: aprof.match(payload.type_id, payload.part_mats,
                                      payload.part_counts, payload.skill,
                                      payload.mats))


class AprofMatchNamed(BaseModel):
    # Основа выбрана прямо: для проверки именного её набор ячеек не нужен.
    recipe_id: int
    # Вставки в слоты доводки по порядку.
    mats: list[int] = []


@app.post("/api/aprof/match-named")
def aprof_match_named(payload: AprofMatchNamed, _: users.Actor = Viewer) -> dict:
    return _aprof(lambda: aprof.match_named(payload.recipe_id, payload.mats))


@app.get("/api/aprof/displays")
def aprof_displays(q: str = "", item_class: int = -1, item_subclass: int = -1,
                   limit: int = Query(60, ge=1, le=200),
                   offset: int = Query(0, ge=0),
                   _: users.Actor = Viewer) -> dict:
    return _aprof(lambda: aprof.displays(q, item_class, item_subclass,
                                         limit, offset))


@app.post("/api/aprof/reload")
def aprof_reload(_: users.Actor = Owner) -> dict:
    """Перечитать справочники на живом сервере.

    Панель пишет в базу, а модуль держит справочники в памяти: без этого
    вызова новый камень появится только после рестарта мира.
    """
    try:
        output = soap.execute("aprof reload")
    except soap.SoapError as exc:
        raise HTTPException(503, str(exc)) from exc
    apply_mod.clear("aprof")
    return {"ok": True, "output": output.strip()}


@app.get("/api/aprof/generated")
def aprof_generated(limit: int = Query(200, ge=1, le=1000),
                    _: users.Actor = Viewer) -> dict:
    return _aprof(lambda: aprof.generated(limit))


# --- spell catalogue ------------------------------------------------------
# Read-only, and deliberately separate from the workshop above: this one spans
# all ~55 000 spells the server knows, the workshop only the ones we author.

@app.get("/api/dex/meta")
def dex_meta(_: users.Actor = Viewer) -> dict:
    return spelldex.meta()


@app.get("/api/dex/search")
def dex_search(q: str = "", school: int | None = None,
               family: int | None = None, effect: int | None = None,
               aura: int | None = None, source: str | None = None,
               level_min: int | None = None, level_max: int | None = None,
               block: str | None = None, module: str | None = None,
               unnamed: bool = False, offset: int = Query(0, ge=0),
               limit: int = Query(100, ge=1, le=500),
               _: users.Actor = Viewer) -> dict:
    """`block`/`module` narrow by the workshop's id ranges — `block=*` is all
    of them, i.e. everything we authored ourselves."""
    if not spelldex.available():
        raise HTTPException(503, "Каталог недоступен: не примонтирован %s."
                            % config.DBC_DIR)
    if block and block != spelldex.ANY_BLOCK \
            and block not in spells.BLOCK_BY_ID:
        raise HTTPException(404, "Неизвестный блок ID: %s" % block)
    return spelldex.search(q=q, school=school, family=family, effect=effect,
                           aura=aura, source=source, level_min=level_min,
                           level_max=level_max, block=block, module=module,
                           unnamed=unnamed, offset=offset, limit=limit)


@app.get("/api/icons")
def icon_catalog(q: str = "", limit: int = Query(4000, ge=1, le=10000),
                 _: users.Actor = Viewer) -> dict:
    """Icon textures for the workshop's picker. Shared with the catalogue's
    icon resolution, so both pages name icons the same way."""
    if not spelldex.available():
        raise HTTPException(503, "Иконки недоступны: не примонтирован %s."
                            % config.DBC_DIR)
    found = spelldex.icon_list(q)
    return {"total": len(found), "items": found[:limit],
            "icon_base_url": config.ICON_BASE_URL}


@app.get("/api/dex/spells/{spell_id}")
def dex_spell(spell_id: int, _: users.Actor = Viewer) -> dict:
    spell = spelldex.detail(spell_id)
    if not spell:
        raise HTTPException(404, "Спелла %d нет ни в DBC, ни в spell_dbc."
                            % spell_id)
    return spell


# --- item talents ---------------------------------------------------------
# Редактор «Пробуждения снаряжения»: категории неэпических предметов,
# персональные пулы эпиков и пороги убийств. Всё пишется в acore_world_ptr,
# применяется на живом PTR через `.itemtalent reload` по SOAP — как у погоды.

class ITalentSave(BaseModel):
    saved: dict
    problems: list[italents.Problem]
    reloaded: bool = False
    reload_output: str | None = None


def _italents_save(validate, save, reload_engine: bool, force: bool) -> ITalentSave:
    problems = validate()
    if [p for p in problems if p.level == "error"] and not force:
        raise HTTPException(422, {
            "detail": "Не сохранено: есть ошибки.",
            "problems": [p.model_dump() for p in problems],
        })

    saved = save()

    reloaded, output = False, None
    if reload_engine:
        try:
            output = italents.reload_engine()
            reloaded = True
            apply_mod.clear("italents")
        except soap.SoapError as exc:
            output = f"SOAP: {exc}"

    return ITalentSave(saved=saved, problems=problems, reloaded=reloaded,
                       reload_output=output)


@app.get("/api/italents/meta")
def italents_meta(_: users.Actor = Viewer) -> dict:
    return italents.meta()


@app.get("/api/italents/categories")
def italents_categories(_: users.Actor = Viewer) -> dict:
    return {"categories": italents.categories(), "rules": italents.rules()}


class CategoriesPayload(BaseModel):
    categories: list[italents.Category]
    rules: list[italents.Rule]


@app.put("/api/italents/categories")
def italents_put_categories(payload: CategoriesPayload,
                            reload: bool = Query(True),
                            force: bool = Query(False),
                            _: users.Actor = Editor) -> ITalentSave:
    return _italents_save(
        lambda: italents.validate_categories(payload.categories, payload.rules),
        lambda: italents.save_categories(payload.categories, payload.rules),
        reload, force)


@app.get("/api/italents/categories/{code}/rows")
def italents_category_rows(code: str, _: users.Actor = Viewer) -> list[dict]:
    return italents.category_rows(code)


@app.put("/api/italents/categories/{code}/rows/{row}")
def italents_put_category_row(code: str, row: int, payload: italents.RowPayload,
                              reload: bool = Query(True),
                              force: bool = Query(False),
                              _: users.Actor = Editor) -> ITalentSave:
    if payload.row != row:
        raise HTTPException(400, "Номер ряда в теле и в пути не совпадает.")
    return _italents_save(
        lambda: italents.validate_category_row(code, payload),
        lambda: italents.save_category_row(code, payload), reload, force)


@app.get("/api/italents/items")
def italents_items(q: str = Query("", alias="q"),
                   quality_min: int = Query(4, ge=0, le=7),
                   item_class: int = Query(-1),
                   only_custom: bool = Query(False),
                   limit: int = Query(200, ge=1, le=1000),
                   _: users.Actor = Viewer) -> list[dict]:
    return italents.item_search(q, quality_min, item_class, only_custom, limit)


@app.get("/api/italents/items/{entry}")
def italents_item(entry: int, _: users.Actor = Viewer) -> dict:
    item = italents.item_detail(entry)
    if not item:
        raise HTTPException(404, f"Предмета {entry} нет в item_template.")
    return item


@app.put("/api/italents/items/{entry}/rows/{row}")
def italents_put_item_row(entry: int, row: int, payload: italents.RowPayload,
                          reload: bool = Query(True),
                          force: bool = Query(False),
                          _: users.Actor = Editor) -> ITalentSave:
    if payload.row != row:
        raise HTTPException(400, "Номер ряда в теле и в пути не совпадает.")
    return _italents_save(
        lambda: italents.validate_item_row(entry, payload),
        lambda: italents.save_item_row(entry, payload), reload, force)


@app.get("/api/italents/procs")
def italents_procs(_: users.Actor = Viewer) -> dict:
    return {"procs": italents.procs(), "spells": italents.free_proc_spells()}


@app.put("/api/italents/procs")
def italents_put_procs(rows: list[italents.Proc],
                       reload: bool = Query(True),
                       force: bool = Query(False),
                       _: users.Actor = Editor) -> ITalentSave:
    return _italents_save(lambda: italents.validate_procs(rows),
                          lambda: italents.save_procs(rows), reload, force)


@app.get("/api/italents/curves")
def italents_curves(_: users.Actor = Viewer) -> list[dict]:
    return italents.curves()


@app.put("/api/italents/curves")
def italents_put_curves(rows: list[italents.Curve],
                        reload: bool = Query(True),
                        force: bool = Query(False),
                        _: users.Actor = Editor) -> ITalentSave:
    return _italents_save(lambda: italents.validate_curves(rows),
                          lambda: italents.save_curves(rows), reload, force)


@app.get("/api/italents/library")
def italents_library(_: users.Actor = Viewer) -> list[dict]:
    return italents.library()


@app.put("/api/italents/library")
def italents_put_library(rows: list[italents.Perk],
                         _: users.Actor = Editor) -> dict:
    return italents.save_library(rows)


@app.post("/api/italents/reload")
def italents_reload(_: users.Actor = Editor) -> dict:
    try:
        output = italents.reload_engine()
        apply_mod.clear("italents")
        return {"ok": True, "output": output}
    except soap.SoapError as exc:
        raise HTTPException(502, str(exc)) from exc


# --- advanced weather -----------------------------------------------------
# Погода живёт в памяти worldserver'а, и панель разговаривает с ним по SOAP
# командами ".aw". Поэтому и SOAP-ошибка здесь не 500, а 502 — сервер
# недоступен, не панель. Исключение одно: связи зон это настройка, а не живое
# состояние, они лежат в таблице, и панель пишет её напрямую, а серверу лишь
# говорит перечитать.

def _weather_call(fn):
    try:
        return fn()
    except weather.WeatherError as exc:
        raise HTTPException(409, str(exc)) from exc
    except soap.SoapError as exc:
        raise HTTPException(502, f"SOAP: {exc}") from exc


@app.get("/api/weather")
def weather_overview(_: users.Actor = Viewer) -> dict:
    return _weather_call(weather.overview)


@app.put("/api/weather/director")
def weather_director(payload: weather.DirectorPayload,
                     _: users.Actor = Editor) -> dict:
    """Переключатель режиссёра. Пишется в таблицу модуля, переживает рестарт."""
    return _weather_call(lambda: weather.set_director(payload.enabled))


@app.get("/api/weather/settings")
def weather_settings(_: users.Actor = Viewer) -> dict:
    """Реестр настроек модуля: он живёт в C++, панель его только показывает."""
    return _weather_call(weather.settings)


@app.put("/api/weather/settings/{name}")
def weather_setting_set(name: str, payload: weather.SettingPayload,
                        _: users.Actor = Editor) -> dict:
    return _weather_call(lambda: weather.set_setting(name, payload.value))


@app.get("/api/weather/cyclones")
def weather_cyclones(_: users.Actor = Viewer) -> dict:
    return {"cyclones": _weather_call(weather.cyclones)}


@app.post("/api/weather/cyclones/reset")
def weather_cyclones_reset(_: users.Actor = Editor) -> dict:
    """Смести фронты и запустить новые — не дожидаясь, пока доедут прежние."""
    return {"cyclones": _weather_call(weather.reset_cyclones)}


@app.get("/api/weather/zones/{zone_id}")
def weather_zone(zone_id: int, _: users.Actor = Viewer) -> dict:
    return _weather_call(lambda: weather.zone(zone_id))


@app.put("/api/weather/zones/{zone_id}")
def weather_set(zone_id: int, payload: weather.SetPayload,
                _: users.Actor = Editor) -> dict:
    return _weather_call(lambda: weather.set_weather(zone_id, payload))


@app.post("/api/weather/zones/{zone_id}/pin")
def weather_pin(zone_id: int, _: users.Actor = Editor) -> dict:
    return _weather_call(lambda: weather.pin(zone_id))


@app.post("/api/weather/zones/{zone_id}/release")
def weather_release(zone_id: int, _: users.Actor = Editor) -> dict:
    return _weather_call(lambda: weather.release(zone_id))


@app.post("/api/weather/release")
def weather_release_all(_: users.Actor = Editor) -> dict:
    return _weather_call(weather.release_all)


@app.get("/api/weather/zones/{zone_id}/links")
def weather_links(zone_id: int, _: users.Actor = Viewer) -> dict:
    return _weather_call(lambda: weather.links(zone_id))


@app.put("/api/weather/zones/{zone_id}/links")
def weather_links_set(zone_id: int, payload: weather.LinksPayload,
                      _: users.Actor = Editor) -> dict:
    return _weather_call(lambda: weather.set_links(zone_id, payload))


@app.get("/api/weather/links")
def weather_links_live(_: users.Actor = Viewer) -> dict:
    """Связи, которыми worldserver руководствуется прямо сейчас."""
    return {"links": _weather_call(weather.server_links)}


@app.get("/api/weather/zones/{zone_id}/climate")
def weather_climate(zone_id: int, _: users.Actor = Viewer) -> dict:
    """Шансы осадков зоны по сезонам - ядровая таблица `game_weather`."""
    return _weather_call(lambda: weather.climate(zone_id))


@app.put("/api/weather/zones/{zone_id}/climate")
def weather_climate_set(zone_id: int, payload: weather.ClimatePayload,
                        _: users.Actor = Editor) -> dict:
    """Записать шансы. В игре они заработают после перезапуска мира.

    Живой перечитки тут быть не может: ядро держит эти строки в контейнере, на
    который ссылаются живые объекты `Weather` - перезагрузка на ходу оставила
    бы висячие указатели. Панель об этом говорит прямо на странице.
    """
    return _weather_call(lambda: weather.save_climate(zone_id, payload))


# --- очередь фронтов ------------------------------------------------------
# Таблицу правит панель, а мир перечитывает её по команде - тем же порядком,
# что и связи зон.

@app.get("/api/weather/queue")
def weather_queue(_: users.Actor = Viewer) -> dict:
    return _weather_call(weather.queue)


@app.post("/api/weather/queue", status_code=201)
def weather_queue_add(payload: weather.QueuePayload,
                      _: users.Actor = Editor) -> dict:
    return _weather_call(lambda: weather.queue_add(payload))


@app.put("/api/weather/queue/{entry_id}")
def weather_queue_save(entry_id: int, payload: weather.QueuePayload,
                       _: users.Actor = Editor) -> dict:
    return _weather_call(lambda: weather.queue_save(entry_id, payload))


@app.delete("/api/weather/queue/{entry_id}")
def weather_queue_delete(entry_id: int, _: users.Actor = Editor) -> dict:
    return _weather_call(lambda: weather.queue_delete(entry_id))


# --- свои фронты ----------------------------------------------------------
# Фронт, поставленный руками, переживает и «перезапустить фронты», и правку
# настроек: модуль бережёт помеченные `manual`. Живёт он всё равно в памяти -
# рестарт мира его не переживёт, и это честно написано на странице.

@app.post("/api/weather/cyclones", status_code=201)
def weather_cyclone_add(payload: weather.CyclonePayload,
                        _: users.Actor = Editor) -> dict:
    return _weather_call(lambda: weather.add_cyclone(payload))


@app.put("/api/weather/cyclones/{cyclone_id}")
def weather_cyclone_set(cyclone_id: int, field: str = Query(..., max_length=16),
                        value: int = Query(...),
                        _: users.Actor = Editor) -> dict:
    return _weather_call(
        lambda: weather.set_cyclone(cyclone_id, field, value))


@app.delete("/api/weather/cyclones/{cyclone_id}")
def weather_cyclone_del(cyclone_id: int, _: users.Actor = Editor) -> dict:
    return _weather_call(lambda: weather.remove_cyclone(cyclone_id))


@app.post("/api/weather/links/reload")
def weather_links_reload(_: users.Actor = Editor) -> dict:
    return {"ok": True, "loaded": _weather_call(weather.reload_links)}


@app.post("/api/weather/reload")
def weather_reload(_: users.Actor = Editor) -> dict:
    return {"ok": True, "output": _weather_call(weather.reload_module)}


# --- who you are ----------------------------------------------------------
# These four are the only endpoints without a role gate: they are how you get
# a role in the first place.


def _set_session(response: Response, token: str) -> None:
    # HttpOnly so a bug in any panel script cannot read the session; Lax so the
    # cookie still rides an ordinary link into the panel. Not Secure: the panel
    # is served over plain HTTP on the tailnet, and a Secure cookie would
    # simply never be stored. Put it behind `tailscale serve` and this should
    # gain `secure=True`.
    response.set_cookie(
        users.SESSION_COOKIE, token, httponly=True, samesite="lax",
        max_age=users.SESSION_DAYS * 24 * 3600, path="/")


class LoginIn(BaseModel):
    login: str
    password: str


@app.get("/api/auth/state")
def auth_state(request: Request) -> dict:
    """Whether anyone is signed in — drives the login page and the user chip."""
    actor = _caller(request)
    return {
        "signed_in": actor is not None,
        "actor": actor.model_dump() if actor else None,
        # With no profiles yet, the login page explains the shared token rather
        # than showing a form nobody can satisfy.
        "bootstrap": users.bootstrap_needed(),
        "roles": [{"id": r, "label": users.ROLE_LABEL[r]} for r in users.ROLES],
    }


@app.post("/api/auth/login")
def auth_login(payload: LoginIn, request: Request, response: Response) -> dict:
    actor, token = users.sign_in(payload.login, payload.password,
                                 request.headers.get("user-agent", ""))
    _set_session(response, token)
    return {"actor": actor.model_dump()}


@app.post("/api/auth/logout")
def auth_logout(request: Request, response: Response) -> dict:
    users.close_session(request.cookies.get(users.SESSION_COOKIE, ""))
    response.delete_cookie(users.SESSION_COOKIE, path="/")
    return {"ok": True}


@app.get("/api/auth/invite")
def auth_invite_peek(token: str = Query(min_length=1)) -> dict:
    """What role a link grants, shown before anyone fills the form in."""
    return users.peek_invite(token)


@app.post("/api/auth/join", status_code=201)
def auth_join(payload: users.JoinIn, request: Request,
              response: Response) -> dict:
    actor, token = users.redeem_invite(
        payload, request.headers.get("user-agent", ""))
    # Nobody was signed in when this request started, so the audit middleware
    # has no caller yet. Hand it the profile that was just created — otherwise
    # the one row that records a new person joining is the one row with no
    # name on it.
    request.scope["actor"] = actor
    _set_session(response, token)
    return {"actor": actor.model_dump()}


@app.post("/api/auth/password")
def auth_password(payload: users.PasswordIn, response: Response,
                  me: users.Actor = Viewer) -> dict:
    if me.source == "token":
        raise HTTPException(
            400, "Общий токен — это не профиль, менять ему пароль нечему.")
    users.set_password(me.id, payload, verify_current=True)
    # set_password closes every session, this one included; hand out a fresh
    # one so changing your password does not read as being kicked out.
    _set_session(response, users.open_session(
        me.id, "password change"))
    return {"ok": True}


# --- people ---------------------------------------------------------------

@app.get("/api/users")
def users_list(_: users.Actor = Owner) -> list[dict]:
    return users.list_users()


@app.patch("/api/users/{user_id}")
def users_patch(user_id: int, payload: users.UserPatch,
                me: users.Actor = Owner) -> dict:
    demoting_self = (user_id == me.id and payload.role is not None
                     and payload.role != "owner")
    if demoting_self:
        raise HTTPException(400, "Себя понижать нельзя — попроси другого "
                                 "владельца.")
    return users.patch_user(user_id, payload)


@app.delete("/api/users/{user_id}")
def users_delete(user_id: int, me: users.Actor = Owner) -> dict:
    if user_id == me.id:
        raise HTTPException(400, "Себя удалять нельзя.")
    return users.delete_user(user_id)


@app.post("/api/users/{user_id}/sessions/close")
def users_close_sessions(user_id: int, _: users.Actor = Owner) -> dict:
    return {"closed": users.close_all_sessions(user_id)}


@app.get("/api/invites")
def invites_list(_: users.Actor = Owner) -> list[dict]:
    return users.list_invites()


@app.post("/api/invites", status_code=201)
def invites_create(payload: users.InviteIn, request: Request,
                   me: users.Actor = Owner) -> dict:
    invite = users.create_invite(payload, me.login)
    # The panel does not know its own public address, so the link is built from
    # whatever host the owner is looking at it through — which is the address
    # their friends can reach too.
    base = str(request.base_url).rstrip("/")
    invite["url"] = f"{base}/join.html#{invite.pop('token')}"
    return invite


@app.post("/api/invites/{invite_id}/revoke")
def invites_revoke(invite_id: int, _: users.Actor = Owner) -> dict:
    users.revoke_invite(invite_id)
    return {"ok": True}


# --- audit log ------------------------------------------------------------

@app.get("/api/audit")
def audit_list(area: str = "", actor: str = "", q: str = "",
               failures: bool = False, limit: int = Query(100, ge=1, le=500),
               before_id: int = 0, _: users.Actor = Owner) -> list[dict]:
    return audit.entries(area=area, actor=actor, q=q, failures_only=failures,
                         limit=limit, before_id=before_id)


@app.get("/api/audit/meta")
def audit_meta(_: users.Actor = Owner) -> dict:
    return {
        "areas": [{"id": k, "label": v} for k, v in audit.AREA_LABEL.items()],
        "actors": audit.actors(),
        "stats": audit.stats(),
    }


# --- добыча ---------------------------------------------------------------
# Заход первый - только чтение (DESIGN страницы: tools/admin-panel/README.md).
# Ручки отвечают на два вопроса: что роняет вот этот моб и где падает вот этот
# предмет. Писать сюда пока нечем, поэтому все они под Viewer.

def _loot(fn):
    """Отказы модуля добычи - сообщения человеку, а не 500-я."""
    try:
        return fn()
    except loot.LootError as exc:
        raise HTTPException(409, str(exc)) from exc


@app.get("/api/loot/meta")
def loot_meta(_: users.Actor = Viewer) -> dict:
    if not loot.available():
        raise HTTPException(409, "Таблиц добычи нет в этой базе.")
    out = _loot(loot.meta)
    # Иконки предметов приходят не из базы, а из того же конвейера, что у
    # каталога: странице нужен только корень адреса.
    out["icon_base_url"] = config.ICON_BASE_URL
    return out


@app.get("/api/loot/creatures")
def loot_creatures(q: str = "", only_loot: bool = True, limit: int = 60,
                   rank: int = -1, level_min: int = 0, level_max: int = 0,
                   offset: int = 0, _: users.Actor = Viewer) -> dict:
    # `creatures` остаётся списком строк, каким был: на него смотрит и старая
    # страница (app/static/loot.js). Рядом добавились `total` и `offset` - их
    # читает новая таблица, чтобы листать по-настоящему.
    found = _loot(
        lambda: loot.creatures(q=q, only_loot=only_loot, limit=limit,
                               rank=rank, level_min=level_min,
                               level_max=level_max, offset=offset))
    return {"creatures": found["rows"], "total": found["total"],
            "offset": max(0, int(offset))}


@app.get("/api/loot/creature/{entry}")
def loot_creature(entry: int, _: users.Actor = Viewer) -> dict:
    return _loot(lambda: loot.creature(entry))


@app.get("/api/loot/item/{entry}")
def loot_item(entry: int, _: users.Actor = Viewer) -> dict:
    return _loot(lambda: loot.where_drops(entry))


@app.get("/api/loot/table/{table_id}")
def loot_table(table_id: str, q: str = "", limit: int = 100,
               _: users.Actor = Viewer) -> dict:
    return _loot(lambda: loot.table_entries(table_id, q=q, limit=limit))


class LootLabel(BaseModel):
    """Подпись записи или группы. Пустая пара «имя + пояснение» её снимает."""

    kind: str = "entry"
    group_id: int = 0
    name: str = ""
    note: str = ""


@app.get("/api/loot/labels")
def loot_labels(table_id: str = "", q: str = "", limit: int = 200,
                _: users.Actor = Viewer) -> dict:
    return {"labels": _loot(
        lambda: loot.named(table_id=table_id, q=q, limit=limit))}


@app.put("/api/loot/label/{table_id}/{entry}")
def loot_put_label(table_id: str, entry: int, payload: LootLabel,
                   actor: users.Actor = Editor) -> dict:
    # Имена живут в схеме панели, а не в игровой базе: это подписи для людей,
    # ядро о них не знает. Поэтому правка тут - Editor, а не Owner.
    return _loot(lambda: loot.save_label(
        table_id, entry, payload.kind, payload.group_id,
        payload.name, payload.note, getattr(actor, "login", "") or ""))


@app.put("/api/loot/row/{table_id}/{entry}")
def loot_put_row(table_id: str, entry: int, payload: loot.Row,
                 _: users.Actor = Owner) -> dict:
    # Правка игровой таблицы, а не подписи, - поэтому Owner. Писать некуда,
    # кроме PTR: соединение отказывается открывать базу без суффикса `_ptr`.
    return _loot(lambda: loot.save_row(table_id, entry, payload))


@app.delete("/api/loot/row/{table_id}/{entry}")
def loot_del_row(table_id: str, entry: int, item: int = 0, reference: int = 0,
                 group: int = 0, _: users.Actor = Owner) -> dict:
    return _loot(lambda: loot.delete_row(table_id, entry, item, reference,
                                         group))


class LootCollect(BaseModel):
    """Собрать строки в группу. Ноль в target - взять первый свободный номер."""

    rows: list[loot.RowKey] = []
    target: int = 0
    name: str = ""


@app.get("/api/loot/group/{table_id}/{entry}/free")
def loot_free_group(table_id: str, entry: int,
                    _: users.Actor = Viewer) -> dict:
    return {"group": _loot(lambda: loot.free_group(table_id, entry))}


@app.post("/api/loot/group/{table_id}/{entry}/collect")
def loot_collect(table_id: str, entry: int, payload: LootCollect,
                 actor: users.Actor = Owner) -> dict:
    return _loot(lambda: loot.collect_rows(
        table_id, entry, payload.rows, payload.target, payload.name,
        getattr(actor, "login", "") or ""))


@app.post("/api/loot/group/{table_id}/{entry}")
def loot_move_group(table_id: str, entry: int, source: int, target: int,
                    _: users.Actor = Owner) -> dict:
    return _loot(lambda: loot.move_group(table_id, entry, source, target))


@app.post("/api/loot/reload/{table_id}")
def loot_reload(table_id: str, _: users.Actor = Owner) -> dict:
    # Мир держит таблицы добычи в памяти: без этого правка ждёт рестарта.
    try:
        output = _loot(lambda: loot.reload_table(table_id))
        apply_mod.clear("loot", table_id + "_loot_template")
        return {"ok": True, "output": output}
    except soap.SoapError as exc:
        raise HTTPException(502, str(exc)) from exc


@app.get("/api/loot/table/{table_id}/{entry}")
def loot_table_entry(table_id: str, entry: int,
                     _: users.Actor = Viewer) -> dict:
    return _loot(lambda: {
        "tree": loot.entry_tree(table_id, entry),
        "owners": loot.owners_of(table_id, entry),
    })


# --- static UI ------------------------------------------------------------

PAGES = {"": "index.html", "envfx": "envfx.html", "board": "board.html",
         "aprof": "aprof.html",
         "spells": "spells.html", "dex": "dex.html",
         "italents": "italents.html", "items": "items.html",
         "worlditems": "worlditems.html",
         "loot": "loot.html",
         "weather": "weather.html",
         "weather-settings": "weather-settings.html",
         # Reachable signed-out by design: they are the way in.
         "login": "login.html", "join": "join.html",
         "users": "users.html", "audit": "audit.html"}


@app.get("/")
def index() -> FileResponse:
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))


@app.get("/{page}.html")
def page(page: str) -> FileResponse:
    """Whitelisted so a path cannot walk out of STATIC_DIR."""
    name = PAGES.get(page)
    if not name:
        raise HTTPException(404, "Нет такой страницы.")
    return FileResponse(os.path.join(STATIC_DIR, name))


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


# Свои файлы фронтенда (текстуры, знак, карты) он просит ОТ КОРНЯ: в CSS
# путь обязан быть корневым, иначе сборщик Angular пытается разрешить его на
# этапе сборки и падает. Поэтому отдаём эти папки и с корня тоже - со старой
# панелью они не пересекаются, у неё всё лежит под /static.
for _folder in ("textures", "brand", "maps"):
    _dir = os.path.join(WEB_DIR, _folder)
    if os.path.isdir(_dir):
        app.mount("/" + _folder, StaticFiles(directory=_dir), name="web-" + _folder)


@app.get("/cyclone.png")
def web_cyclone() -> FileResponse:
    path = os.path.join(WEB_DIR, "cyclone.png")
    if not os.path.isfile(path):
        raise HTTPException(404, "Нет такой картинки.")
    return FileResponse(path)


@app.get("/ui")
def web_root() -> RedirectResponse:
    return RedirectResponse("/ui/")


@app.get("/ui/{path:path}")
def web(path: str) -> FileResponse:
    """Новый фронтенд: файл, если он есть, иначе index.html.

    Маршрутизация у приложения своя, поэтому любой неизвестный путь - это не
    404, а точка входа: адрес вроде /ui/loot/creatures на сервере не файл.
    """
    if not os.path.isdir(WEB_DIR):
        raise HTTPException(
            503, "Фронтенд не собран: `cd tools/admin-panel/frontend && "
                 "npm run build`.")
    target = os.path.abspath(os.path.join(WEB_DIR, path))
    inside = target == WEB_DIR or target.startswith(WEB_DIR + os.sep)
    if path and inside and os.path.isfile(target):
        return FileResponse(target)
    # Картинки набора (`styles/forge.scss`) просятся от корня - /ui/frames/
    # panel-thin.png, - потому что корневой путь единственный, который сборщик
    # Angular не пытается разрешить у себя (см. комментарий к mount выше). Но
    # под /ui/ живёт и само приложение, поэтому в СОБРАННОЙ панели тот же
    # адрес указывает внутрь сборки: файл лежит в web/ui/frames/panel-thin.png
    # (папка public/ui целиком уезжает в корень сборки). Без этой добавки
    # такой адрес попадал бы в ветку ниже и возвращал index.html - картинка
    # молча не рисовалась бы, а страница осталась бы без рамок и кнопок.
    nested_root = os.path.join(WEB_DIR, "ui")
    nested = os.path.abspath(os.path.join(nested_root, path))
    if (path and nested.startswith(nested_root + os.sep)
            and os.path.isfile(nested)):
        return FileResponse(nested)
    return FileResponse(os.path.join(WEB_DIR, "index.html"))
