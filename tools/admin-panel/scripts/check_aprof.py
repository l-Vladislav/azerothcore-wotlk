# Сквозная проверка вкладок «Рецепты» и «Именные» против ЖИВОЙ панели PTR.
#
#   python tools/admin-panel/scripts/check_aprof.py
#
# Проверяет то, чего не видно из кода: можно ли завести основу руками от начала
# до конца - книгу копией в блок «Книги рецептов», рецепт с этой книгой,
# дроп-основу без неё, именное сочетание со своей книгой, - и отказывает ли
# панель там, где должна: вторая основа на ту же книгу, книга основы у
# сочетания, дроп-основа с требуемым навыком, удаление занятого предмета.
#
# Всё заведённое убирается за собой. База берётся PTR-овская: панель сама
# отказывается работать с не-*_ptr схемой.
#
# Адрес и токен - из окружения или из корневого .env (ADMIN_PANEL_BIND,
# ADMIN_PANEL_TOKEN). В файл их не вписывать: .env не в репозитории.
import io
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def env(name: str, fallback: str = "") -> str:
    if os.environ.get(name):
        return os.environ[name]
    path = os.path.join(ROOT, ".env")
    if os.path.exists(path):
        for line in io.open(path, encoding="utf-8"):
            line = line.strip()
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip()
    return fallback


HOST = env("ADMIN_PANEL_BIND", "127.0.0.1")
BASE = env("ADMIN_PANEL_URL", "http://%s:8091" % HOST)
TOKEN = env("ADMIN_PANEL_TOKEN")

made: dict[str, list[int]] = {"items": [], "recipes": [], "synergies": []}
failures: list[str] = []


def call(method: str, path: str, payload=None):
    data = (json.dumps(payload, ensure_ascii=False).encode()
            if payload is not None else None)
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("X-Admin-Token", TOKEN)
    if data:
        req.add_header("Content-Type", "application/json; charset=utf-8")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode("utf-8")
            return resp.status, json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        try:
            return exc.code, json.loads(body)
        except ValueError:
            return exc.code, {"detail": body}


def check(name: str, ok, detail="") -> None:
    print(("ok   " if ok else "FAIL ") + name + ((": " + str(detail)) if detail else ""))
    if not ok:
        failures.append(name)


def why(body: dict):
    d = body.get("detail")
    return (d.get("error") if isinstance(d, dict) else d) or ""


def make_book(sample: int, title: str):
    """Книга - обычная копия предмета в блок 190000-199999."""
    status, draft = call("GET", "/api/items/clone/%d?block=books" % sample)
    if status != 200 or not draft.get("entry"):
        return None, why(draft)
    entry = int(draft["entry"])
    fields = dict(draft["fields"])
    fields["name"] = "Panel check book %d" % entry
    fields["name_ru"] = title
    status, body = call("PUT", "/api/items/%d" % entry, {"fields": fields})
    if status != 200:
        return None, why(body)
    made["items"].append(entry)
    return entry, ""


def main() -> int:
    if not TOKEN:
        print("Нет токена: задайте ADMIN_PANEL_TOKEN в окружении или в .env")
        return 2

    # Донор для книги: любой предмет игры, лишь бы строка существовала.
    query = urllib.parse.urlencode({"q": "Чертёж", "limit": "1"})
    status, found = call("GET", "/api/items?" + query)
    sample = (found["items"][0]["entry"]
              if status == 200 and found.get("items") else 4335)

    book, err = make_book(sample, "Чертёж проверки панели")
    check("книга заведена копией", bool(book), err or book)
    if not book:
        return 1
    book2, err = make_book(sample, "Чертёж проверки панели 2")
    check("вторая книга заведена", bool(book2), err or book2)

    status, rtypes = call("GET", "/api/aprof/types")
    check("типы предметов есть", status == 200 and rtypes.get("types"))
    if not rtypes.get("types"):
        return 1
    type_id = rtypes["types"][0]["id"]

    # --- ковочная основа с книгой ---
    recipe = {"id": 0, "type_id": type_id, "name_ru": "Проверка панели ковка",
              "req_skill": 1, "teach_item": book, "quality_min": 1,
              "quality_max": 2, "acquire": "forge", "enabled": False}
    status, body = call("PUT", "/api/aprof/recipes", recipe)
    check("основа с книгой заводится", status == 200 and body.get("id"),
          why(body) or body)
    if body.get("id"):
        made["recipes"].append(int(body["id"]))

    # --- дроп-основа: у неё нет ни книги, ни требуемого навыка ---
    drop = {"id": 0, "type_id": type_id, "name_ru": "Проверка панели добыча",
            "req_skill": 0, "teach_item": 0, "quality_min": 3,
            "quality_max": 3, "acquire": "drop", "enabled": False}
    status, body = call("PUT", "/api/aprof/recipes", drop)
    check("дроп-основа заводится", status == 200 and body.get("id"),
          why(body) or body)
    if body.get("id"):
        made["recipes"].append(int(body["id"]))

    status, body = call("PUT", "/api/aprof/recipes", dict(drop, req_skill=1))
    check("дроп-основа с навыком отказана", status >= 400, why(body))
    status, body = call("PUT", "/api/aprof/recipes", dict(drop, teach_item=book2))
    check("дроп-основа с книгой отказана", status >= 400, why(body))

    # --- одна книга учит одному ---
    status, body = call("PUT", "/api/aprof/recipes",
                        dict(recipe, name_ru="Проверка панели двойник"))
    check("вторая основа на ту же книгу отказана", status >= 400, why(body))

    # --- именное сочетание со своей книгой ---
    status, mats = call("GET", "/api/aprof/materials")
    gems = [m["entry"] for m in mats.get("materials", [])
            if m["role"] == "insert"]
    check("вставки в справочнике есть", bool(gems), gems[:3])

    # Основа под сочетание - ЛЮБАЯ с изделиями, ковочная или дроповая: именные
    # эскизы принадлежат основе, а не способу её получения (DESIGN §2.5).
    # Требовать тут forge значило бы падать всякий раз, когда владелец
    # переключил свои основы на добычу.
    status, recs = call("GET", "/api/aprof/recipes")
    owner = next((r for r in recs.get("recipes", []) if r.get("inlay")), None)
    check("основа под сочетание нашлась", owner is not None,
          owner and owner["name_ru"])
    if owner and gems:
        syn = {"id": 0, "name_ru": "Проверка панели именной",
               "recipe_id": owner["id"], "mats": gems[:1], "result_entry": 0,
               "teach_item": book2, "order_matters": False, "enabled": False}
        status, body = call("PUT", "/api/aprof/synergies", syn)
        check("сочетание с книгой заводится", status == 200 and body.get("id"),
              why(body) or body)
        if body.get("id"):
            made["synergies"].append(int(body["id"]))

        status, body = call("PUT", "/api/aprof/synergies",
                            dict(syn, name_ru="Проверка панели чужая книга",
                                 teach_item=book))
        check("сочетание на книгу основы отказано", status >= 400, why(body))

    # --- включение проверяется на ПЕРЕХОДЕ, а не на каждой правке ---
    # Ловушка, которую это ловит: у включённого рецепта появляется замечание
    # (скажем, камни его качества убрали с другой вкладки), и после этого любая
    # правка строки - имя, книга, тип - отвечает «пока нельзя включить», хотя
    # никто ничего не включал. Чинить рецепт правкой становилось нельзя.
    #
    # Ступень берём ту, у которой есть подходящие камни: иначе замечание будет
    # у любого рецепта и включить не выйдет ни один.
    status, recs = call("GET", "/api/aprof/recipes")
    good_step = 0
    for row in recs.get("recipes", []):
        for step in row.get("inlay", []):
            if step.get("slots") and step.get("gems"):
                good_step = int(step["quality"])
                break
        if good_step:
            break
    check("ступень с подходящими камнями нашлась", bool(good_step), good_step)

    query = urllib.parse.urlencode({"q": "Меч", "limit": "1"})
    status, found = call("GET", "/api/items?" + query)
    weapon = found["items"][0]["entry"] if found.get("items") else 25

    if good_step:
        whole = {"id": 0, "type_id": type_id, "name_ru": "Проверка панели целая",
                 "req_skill": 0, "teach_item": 0, "quality_min": good_step,
                 "quality_max": good_step, "acquire": "drop", "enabled": False}
        status, body = call("PUT", "/api/aprof/recipes", whole)
        rid = body.get("id")
        check("основа без замечаний заведена", status == 200 and rid,
              why(body) or body)
        if rid:
            made["recipes"].append(int(rid))
            status, body = call(
                "POST", "/api/aprof/recipes/%d/results/generate" % rid,
                {"sample_entry": weapon})
            check("изделия и слайс созданы",
                  status == 200 and body.get("created"), why(body) or body)
            # Изделия - настоящие строки item_template, и удаление рецепта их
            # НЕ трогает (они могут быть у игроков в сумках). Свои прибираем
            # сами, иначе каждый прогон стенда оставляет мусор в каталоге.
            for row in body.get("created", []):
                made["items"].append(int(row["entry"]))

            status, body = call("PUT", "/api/aprof/recipes",
                                dict(whole, id=rid, enabled=True))
            check("целая основа включается", status == 200, why(body))

            # Правка ВКЛЮЧЁННОЙ строки - то, на чём ловушка и срабатывала.
            status, body = call(
                "PUT", "/api/aprof/recipes",
                dict(whole, id=rid, enabled=True,
                     name_ru="Проверка панели целая 2"))
            check("включённая основа правится", status == 200, why(body))

    # Включить рецепт с замечанием по-прежнему нельзя.
    flawed = next((r for r in recs.get("recipes", [])
                   if r.get("issues") and not r["enabled"]), None)
    if flawed:
        row = {"id": flawed["id"], "type_id": flawed["type_id"],
               "name_ru": flawed["name_ru"], "req_skill": flawed["req_skill"],
               "teach_item": flawed["teach_item"],
               "quality_min": flawed["quality_min"],
               "quality_max": flawed["quality_max"],
               "acquire": flawed.get("acquire", "forge"), "enabled": True}
        status, body = call("PUT", "/api/aprof/recipes", row)
        check("рецепт с замечанием включить нельзя", status >= 400, why(body))
        status, body = call("PUT", "/api/aprof/recipes", dict(row, enabled=False))
        check("он же правится, пока выключен", status == 200, why(body))

    # --- предмет, на котором держится рецепт, не удаляется ---
    status, body = call("DELETE", "/api/items/%d" % book)
    check("книгу занятого рецепта удалить нельзя", status >= 400, why(body))

    # --- уборка ---
    # Порядок важен: сперва ссылки (сочетания, рецепты), потом предметы -
    # панель не даёт удалить предмет, на котором кто-то держится, и правильно
    # делает.
    for syn_id in made["synergies"]:
        call("DELETE", "/api/aprof/synergies/%d" % syn_id)
    for rec_id in made["recipes"]:
        call("DELETE", "/api/aprof/recipes/%d" % rec_id)
    for entry in made["items"]:
        status, body = call("DELETE", "/api/items/%d" % entry)
        check("убран предмет %d" % entry, status == 200, why(body))

    status, recs = call("GET", "/api/aprof/recipes")
    left = [r["name_ru"] for r in recs.get("recipes", [])
            if "Проверка панели" in r["name_ru"]]
    check("следов не осталось", not left, left)

    print()
    if failures:
        print("ПРОВАЛОВ: %d" % len(failures))
        return 1
    print("всё зелено")
    return 0


if __name__ == "__main__":
    sys.exit(main())
