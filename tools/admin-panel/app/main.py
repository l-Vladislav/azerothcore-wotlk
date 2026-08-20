"""AzerothCore admin panel — the server's control node.

Three things live here: a home page listing what can be managed
(`registry.py`), per-module editors (today only mod-environmental-effects,
`envfx.py`), and a board of bugs / feature ideas (`board.py`).

Module editors write PTR only. The board is panel data and lives in its own
schema — see the note at the top of `board.py`. The auth dependency is the seam
where per-user roles will be added later.
"""

import os

from fastapi import Depends, FastAPI, HTTPException, Query, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from . import (board, config, dbc, envfx, export, italents, registry, soap,
               spelldex, spells, weather)
from .db import query_one

STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")

app = FastAPI(title="AzerothCore Admin", docs_url="/api/docs", redoc_url=None)


# --- auth -----------------------------------------------------------------

def require_admin(request: Request) -> str:
    """Single shared token today; returns the caller identity for future roles."""
    if not config.ADMIN_TOKEN:
        raise HTTPException(
            503, "ADMIN_TOKEN is not configured — the panel refuses to serve "
                 "an unauthenticated API.")
    supplied = (request.headers.get("X-Admin-Token")
                or request.query_params.get("token", ""))
    if supplied != config.ADMIN_TOKEN:
        raise HTTPException(401, "Invalid or missing admin token.")
    return "admin"


Admin = Depends(require_admin)


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


@app.exception_handler(config.ConfigError)
async def _config_error(_: Request, exc: config.ConfigError) -> JSONResponse:
    return JSONResponse(status_code=500, content={"detail": str(exc)})


# --- meta -----------------------------------------------------------------

@app.get("/api/health")
def health() -> dict:
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
def list_zones(_: str = Admin) -> list[dict]:
    return envfx.zone_summaries()


@app.get("/api/zones/search")
def search_zones(q: str = Query(min_length=1), _: str = Admin) -> list[dict]:
    needle = q.strip().lower()
    hits = []
    for zone_id, name in dbc.zone_names().items():
        if needle in name.lower() or needle == str(zone_id):
            hits.append({"zone_id": zone_id, "name": name})
    hits.sort(key=lambda z: (not z["name"].lower().startswith(needle), z["name"]))
    return hits[:40]


@app.get("/api/zones/{zone_id}")
def get_zone(zone_id: int, _: str = Admin) -> dict:
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
             _: str = Admin) -> SaveResult:
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
        except soap.SoapError as exc:
            output = f"SOAP: {exc}"

    return SaveResult(saved=saved, problems=problems,
                      reloaded=reloaded, reload_output=output)


@app.delete("/api/zones/{zone_id}")
def del_zone(zone_id: int, _: str = Admin) -> dict:
    return {"deleted": envfx.delete_zone(zone_id)}


# --- env-effects spell picker ---------------------------------------------
# Named for its module: /api/spells belongs to the workshop below, and a
# function called `spells` here would shadow the imported module.

@app.get("/api/envfx/spells")
def envfx_spells(_: str = Admin) -> list[dict]:
    return envfx.spell_catalog()


# --- actions --------------------------------------------------------------

@app.post("/api/reload")
def reload_rules(_: str = Admin) -> dict:
    try:
        return {"ok": True, "output": soap.reload_config()}
    except soap.SoapError as exc:
        raise HTTPException(502, str(exc)) from exc


@app.post("/api/export")
def export_sql(_: str = Admin) -> dict:
    try:
        return {"ok": True, **export.write()}
    except OSError as exc:
        raise HTTPException(500, str(exc)) from exc


@app.post("/api/refresh-cache")
def refresh_cache(_: str = Admin) -> dict:
    dbc.reload_cache()
    spells.reload_cache()
    # Picks up a regenerated Spell_custom.csv / SpellIcon_custom.csv without a
    # container restart. Costs a few seconds on the next catalogue request.
    spelldex.reload_files()
    return {"ok": True, "zones": len(dbc.zone_names()),
            "spells": len(dbc.spell_meta())}


# --- modules --------------------------------------------------------------

@app.get("/api/modules")
def modules(_: str = Admin) -> list[dict]:
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
def board_meta(_: str = Admin) -> dict:
    return {
        "kinds": list(board.KINDS),
        "statuses": list(board.STATUSES),
        "modules": [{"id": m.id, "name": m.name} for m in registry.MODULES],
    }


@app.get("/api/board/cards")
def board_cards(status: str | None = None, module: str | None = None,
                kind: str | None = None, q: str | None = None,
                archived: bool = False, _: str = Admin) -> list[dict]:
    return board.list_cards(status=status, module=module, kind=kind, q=q,
                            archived=archived)


@app.post("/api/board/cards", status_code=201)
def board_create(payload: board.CardIn, _: str = Admin) -> dict:
    return board.create_card(payload)


@app.get("/api/board/cards/{card_id}")
def board_card(card_id: int, _: str = Admin) -> dict:
    card = board.get_card(card_id)
    if not card:
        raise HTTPException(404, "Карточка не найдена.")
    return card


@app.patch("/api/board/cards/{card_id}")
def board_patch(card_id: int, payload: board.CardPatch,
                _: str = Admin) -> dict:
    card = board.update_card(card_id, payload)
    if not card:
        raise HTTPException(404, "Карточка не найдена.")
    return card


@app.post("/api/board/cards/{card_id}/move")
def board_move(card_id: int, payload: board.Move, _: str = Admin) -> list[dict]:
    cards = board.move_card(card_id, payload)
    if not cards:
        raise HTTPException(404, "Карточка не найдена.")
    return cards


@app.post("/api/board/cards/{card_id}/restore")
def board_restore(card_id: int, _: str = Admin) -> dict:
    card = board.restore_card(card_id)
    if not card:
        raise HTTPException(404, "Карточка не найдена.")
    return card


@app.delete("/api/board/cards/{card_id}")
def board_delete(card_id: int, hard: bool = Query(False),
                 _: str = Admin) -> dict:
    if not board.delete_card(card_id, hard=hard):
        raise HTTPException(404, "Карточка не найдена.")
    return {"ok": True, "hard": hard}


@app.post("/api/board/cards/{card_id}/comments")
def board_comment(card_id: int, payload: board.CommentIn,
                  _: str = Admin) -> dict:
    card = board.add_comment(card_id, payload)
    if not card:
        raise HTTPException(404, "Карточка не найдена.")
    return card


@app.get("/api/board/stats")
def board_stats(_: str = Admin) -> dict:
    return board.stats()


# --- spell workshop -------------------------------------------------------
# Specific paths are declared before /api/spells/{spell_id} so a literal like
# "catalog" is never parsed as an id.

@app.get("/api/spells/catalog")
def spell_catalog_all(_: str = Admin) -> dict:
    return spells.catalog()


@app.get("/api/spells/next-id")
def spell_next_id(block: str = Query(...), _: str = Admin) -> dict:
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
def spell_pending(_: str = Admin) -> dict:
    return spells.pending_restart()


@app.get("/api/spells/clone/{source_id}")
def spell_clone(source_id: int, block: str = Query("workshop"),
                _: str = Admin) -> dict:
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
               q: str | None = None, _: str = Admin) -> list[dict]:
    return spells.list_spells(block=block, module=module, q=q)


@app.get("/api/spells/{spell_id}")
def spell_get(spell_id: int, _: str = Admin) -> dict:
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
                 _: str = Admin) -> SpellSaved:
    return _save_spell(payload, creating=True, force=force)


@app.put("/api/spells/{spell_id}")
def spell_update(spell_id: int, payload: spells.SpellIn,
                 force: bool = Query(False), _: str = Admin) -> SpellSaved:
    payload.id = spell_id
    if not spells.get_spell(spell_id):
        raise HTTPException(404, "Спелл не найден.")
    return _save_spell(payload, creating=False, force=force)


@app.delete("/api/spells/{spell_id}")
def spell_delete(spell_id: int, _: str = Admin) -> dict:
    if not spells.delete_spell(spell_id):
        raise HTTPException(404, "Спелл не найден.")
    spelldex.invalidate()
    return {"ok": True}


@app.post("/api/spells/export/sql")
def spell_export_sql(block: str | None = None, _: str = Admin) -> dict:
    try:
        return {"ok": True, **spells.export_sql(block)}
    except OSError as exc:
        raise HTTPException(500, str(exc)) from exc


@app.post("/api/spells/export/client")
def spell_export_client(_: str = Admin) -> dict:
    try:
        return {"ok": True, **spells.export_client()}
    except (OSError, ValueError) as exc:
        raise HTTPException(500, str(exc)) from exc


# --- spell catalogue ------------------------------------------------------
# Read-only, and deliberately separate from the workshop above: this one spans
# all ~55 000 spells the server knows, the workshop only the ones we author.

@app.get("/api/dex/meta")
def dex_meta(_: str = Admin) -> dict:
    return spelldex.meta()


@app.get("/api/dex/search")
def dex_search(q: str = "", school: int | None = None,
               family: int | None = None, effect: int | None = None,
               aura: int | None = None, source: str | None = None,
               level_min: int | None = None, level_max: int | None = None,
               block: str | None = None, module: str | None = None,
               unnamed: bool = False, offset: int = Query(0, ge=0),
               limit: int = Query(100, ge=1, le=500),
               _: str = Admin) -> dict:
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
                 _: str = Admin) -> dict:
    """Icon textures for the workshop's picker. Shared with the catalogue's
    icon resolution, so both pages name icons the same way."""
    if not spelldex.available():
        raise HTTPException(503, "Иконки недоступны: не примонтирован %s."
                            % config.DBC_DIR)
    found = spelldex.icon_list(q)
    return {"total": len(found), "items": found[:limit],
            "icon_base_url": config.ICON_BASE_URL}


@app.get("/api/dex/spells/{spell_id}")
def dex_spell(spell_id: int, _: str = Admin) -> dict:
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
        except soap.SoapError as exc:
            output = f"SOAP: {exc}"

    return ITalentSave(saved=saved, problems=problems, reloaded=reloaded,
                       reload_output=output)


@app.get("/api/italents/meta")
def italents_meta(_: str = Admin) -> dict:
    return italents.meta()


@app.get("/api/italents/categories")
def italents_categories(_: str = Admin) -> dict:
    return {"categories": italents.categories(), "rules": italents.rules()}


class CategoriesPayload(BaseModel):
    categories: list[italents.Category]
    rules: list[italents.Rule]


@app.put("/api/italents/categories")
def italents_put_categories(payload: CategoriesPayload,
                            reload: bool = Query(True),
                            force: bool = Query(False),
                            _: str = Admin) -> ITalentSave:
    return _italents_save(
        lambda: italents.validate_categories(payload.categories, payload.rules),
        lambda: italents.save_categories(payload.categories, payload.rules),
        reload, force)


@app.get("/api/italents/categories/{code}/rows")
def italents_category_rows(code: str, _: str = Admin) -> list[dict]:
    return italents.category_rows(code)


@app.put("/api/italents/categories/{code}/rows/{row}")
def italents_put_category_row(code: str, row: int, payload: italents.RowPayload,
                              reload: bool = Query(True),
                              force: bool = Query(False),
                              _: str = Admin) -> ITalentSave:
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
                   _: str = Admin) -> list[dict]:
    return italents.item_search(q, quality_min, item_class, only_custom, limit)


@app.get("/api/italents/items/{entry}")
def italents_item(entry: int, _: str = Admin) -> dict:
    item = italents.item_detail(entry)
    if not item:
        raise HTTPException(404, f"Предмета {entry} нет в item_template.")
    return item


@app.put("/api/italents/items/{entry}/rows/{row}")
def italents_put_item_row(entry: int, row: int, payload: italents.RowPayload,
                          reload: bool = Query(True),
                          force: bool = Query(False),
                          _: str = Admin) -> ITalentSave:
    if payload.row != row:
        raise HTTPException(400, "Номер ряда в теле и в пути не совпадает.")
    return _italents_save(
        lambda: italents.validate_item_row(entry, payload),
        lambda: italents.save_item_row(entry, payload), reload, force)


@app.get("/api/italents/procs")
def italents_procs(_: str = Admin) -> dict:
    return {"procs": italents.procs(), "spells": italents.free_proc_spells()}


@app.put("/api/italents/procs")
def italents_put_procs(rows: list[italents.Proc],
                       reload: bool = Query(True),
                       force: bool = Query(False),
                       _: str = Admin) -> ITalentSave:
    return _italents_save(lambda: italents.validate_procs(rows),
                          lambda: italents.save_procs(rows), reload, force)


@app.get("/api/italents/curves")
def italents_curves(_: str = Admin) -> list[dict]:
    return italents.curves()


@app.put("/api/italents/curves")
def italents_put_curves(rows: list[italents.Curve],
                        reload: bool = Query(True),
                        force: bool = Query(False),
                        _: str = Admin) -> ITalentSave:
    return _italents_save(lambda: italents.validate_curves(rows),
                          lambda: italents.save_curves(rows), reload, force)


@app.get("/api/italents/library")
def italents_library(_: str = Admin) -> list[dict]:
    return italents.library()


@app.put("/api/italents/library")
def italents_put_library(rows: list[italents.Perk], _: str = Admin) -> dict:
    return italents.save_library(rows)


@app.post("/api/italents/reload")
def italents_reload(_: str = Admin) -> dict:
    try:
        return {"ok": True, "output": italents.reload_engine()}
    except soap.SoapError as exc:
        raise HTTPException(502, str(exc)) from exc


# --- advanced weather -----------------------------------------------------
# Единственный редактор, который ничего не пишет в БД: погода живёт в памяти
# worldserver'а, и панель разговаривает с ним по SOAP командами ".aw".
# Поэтому и SOAP-ошибка здесь не 500, а 502 — сервер недоступен, не панель.

def _weather_call(fn):
    try:
        return fn()
    except weather.WeatherError as exc:
        raise HTTPException(409, str(exc)) from exc
    except soap.SoapError as exc:
        raise HTTPException(502, f"SOAP: {exc}") from exc


@app.get("/api/weather")
def weather_overview(_: str = Admin) -> dict:
    return _weather_call(weather.overview)


@app.get("/api/weather/zones/{zone_id}")
def weather_zone(zone_id: int, _: str = Admin) -> dict:
    return _weather_call(lambda: weather.zone(zone_id))


@app.put("/api/weather/zones/{zone_id}")
def weather_set(zone_id: int, payload: weather.SetPayload,
                _: str = Admin) -> dict:
    return _weather_call(lambda: weather.set_weather(zone_id, payload))


@app.post("/api/weather/zones/{zone_id}/pin")
def weather_pin(zone_id: int, _: str = Admin) -> dict:
    return _weather_call(lambda: weather.pin(zone_id))


@app.post("/api/weather/zones/{zone_id}/release")
def weather_release(zone_id: int, _: str = Admin) -> dict:
    return _weather_call(lambda: weather.release(zone_id))


@app.post("/api/weather/reload")
def weather_reload(_: str = Admin) -> dict:
    return {"ok": True, "output": _weather_call(weather.reload_module)}


# --- static UI ------------------------------------------------------------

PAGES = {"": "index.html", "envfx": "envfx.html", "board": "board.html",
         "spells": "spells.html", "dex": "dex.html",
         "italents": "italents.html", "weather": "weather.html"}


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
