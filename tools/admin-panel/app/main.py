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
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from . import (audit, board, config, dbc, envfx, export, italents, items,
               registry, soap, spelldex, spells, users, weather, worlditems)
from .db import query_one

STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")

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

@app.get("/api/envfx/spells")
def envfx_spells(_: users.Actor = Viewer) -> list[dict]:
    return envfx.spell_catalog()


# --- actions --------------------------------------------------------------

@app.post("/api/reload")
def reload_rules(_: users.Actor = Editor) -> dict:
    try:
        return {"ok": True, "output": soap.reload_config()}
    except soap.SoapError as exc:
        raise HTTPException(502, str(exc)) from exc


@app.post("/api/export")
def export_sql(_: users.Actor = Owner) -> dict:
    try:
        return {"ok": True, **export.write()}
    except OSError as exc:
        raise HTTPException(500, str(exc)) from exc


@app.post("/api/refresh-cache")
def refresh_cache(_: users.Actor = Owner) -> dict:
    dbc.reload_cache()
    spells.reload_cache()
    # Picks up a regenerated Spell_custom.csv / SpellIcon_custom.csv without a
    # container restart. Costs a few seconds on the next catalogue request.
    spelldex.reload_files()
    return {"ok": True, "zones": len(dbc.zone_names()),
            "spells": len(dbc.spell_meta())}


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
               q: str | None = None, _: users.Actor = Viewer) -> list[dict]:
    return spells.list_spells(block=block, module=module, q=q)


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


@app.get("/api/items")
def item_search(q: str = "", block: str | None = None,
                limit: int = Query(60, ge=1, le=200),
                offset: int = Query(0, ge=0),
                _: users.Actor = Viewer) -> dict:
    return items.search(q=q, block=block, limit=limit, offset=offset)


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


@app.get("/api/items/{entry}/client-row")
def item_client_row(entry: int, _: users.Actor = Viewer) -> dict:
    row = items.export_client(entry)
    if not row:
        raise HTTPException(404, "Предмет %d не найден." % entry)
    return row


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
        return {"ok": True, "output": italents.reload_engine()}
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


# --- static UI ------------------------------------------------------------

PAGES = {"": "index.html", "envfx": "envfx.html", "board": "board.html",
         "spells": "spells.html", "dex": "dex.html",
         "italents": "italents.html", "items": "items.html",
         "worlditems": "worlditems.html",
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
