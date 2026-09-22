# Проверка страницы добычи против ЖИВОЙ панели PTR.
#
#   python tools/admin-panel/scripts/check_loot.py
#
# Заход первый - только чтение, поэтому ничего не заводит и не убирает. Смысл
# проверки в том, что правильность тут НЕ видна из кода: она в данных. Обход
# ссылок вверх, шанс внутри группы, общая на нескольких мобов запись, ссылка в
# никуда, отрицательная ссылка - всё это в базе есть, и стенд ищет именно их.
#
# Адрес и токен - из окружения или из корневого .env (ADMIN_PANEL_BIND,
# ADMIN_PANEL_TOKEN).
import io
import json
import os
import sys
import time
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


BASE = env("ADMIN_PANEL_URL",
           "http://%s:8091" % env("ADMIN_PANEL_BIND", "127.0.0.1"))
TOKEN = env("ADMIN_PANEL_TOKEN")

failures: list[str] = []


LAST_MS = 0.0


def call(path: str):
    global LAST_MS
    req = urllib.request.Request(BASE + path, method="GET")
    req.add_header("X-Admin-Token", TOKEN)
    started = time.time()
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            LAST_MS = (time.time() - started) * 1000
            return resp.status, body
    except urllib.error.HTTPError as exc:
        LAST_MS = (time.time() - started) * 1000
        body = exc.read().decode("utf-8", "replace")
        try:
            return exc.code, json.loads(body)
        except ValueError:
            return exc.code, {"detail": body}


def put(path: str, payload: dict):
    data = json.dumps(payload, ensure_ascii=False).encode()
    req = urllib.request.Request(BASE + path, data=data, method="PUT")
    req.add_header("X-Admin-Token", TOKEN)
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


def why(body: dict):
    """Текст отказа так, как его увидит человек."""
    d = (body or {}).get("detail")
    return (d.get("error") if isinstance(d, dict) else d) or ""


def send(method: str, path: str, payload=None):
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


def post(path: str, payload=None):
    return send("POST", path, payload)


def delete(path: str):
    return send("DELETE", path)


def check(name: str, ok, detail="") -> None:
    print(("ok   " if ok else "FAIL ") + name + ((": " + str(detail)) if detail else ""))
    if not ok:
        failures.append(name)


def main() -> int:
    if not TOKEN:
        print("Нет токена: задайте ADMIN_PANEL_TOKEN в окружении или в .env")
        return 2

    status, meta = call("/api/loot/meta")
    check("справочник таблиц отдаётся", status == 200 and meta.get("tables"),
          meta.get("detail"))
    if status != 200:
        return 1
    by_id = {t["id"]: t for t in meta["tables"]}
    check("все тринадцать таблиц на месте", len(meta["tables"]) == 13,
          len(meta["tables"]))
    check("добыча существ непуста", by_id["creature"]["rows"] > 10000,
          by_id["creature"]["rows"])

    # --- поиск существ ---
    status, found = call("/api/loot/creatures?" + urllib.parse.urlencode(
        {"q": "1050", "limit": 5}))
    check("поиск существа по номеру", status == 200 and found["creatures"],
          found.get("detail"))

    # --- существо, у которого lootid НЕ равен его entry ---
    # 930 таких в базе; если бы страница читала добычу по entry, она показала
    # бы пусто.
    status, data = call("/api/loot/creature/1050")
    check("существо с чужим lootid читается", status == 200 and data.get("loot"),
          data.get("detail"))
    if status == 200 and data.get("loot"):
        part = data["loot"][0]
        check("номер записи добычи отличается от номера существа",
              not part["own_entry"], "%s vs %s" % (part["entry"],
                                                   data["creature"]["entry"]))
        check("в записи есть строки", bool(part["tree"]["rows"]),
              len(part["tree"]["rows"]))

    # --- общая запись добычи: та, что у 36 существ ---
    status, data = call("/api/loot/table/creature/16507")
    check("общая запись читается", status == 200, data.get("detail"))
    if status == 200:
        check("у общей записи много владельцев", len(data["owners"]) > 10,
              len(data["owners"]))

    # --- шанс внутри группы ---
    # Строки группы с нулевым шансом делят остаток поровну. Если бы панель
    # брала Chance как есть, половина боссов выглядела бы не роняющей ничего.
    status, data = call("/api/loot/table/creature/16507")
    grouped = [r for r in data["tree"]["rows"] if r["group"] and not r["raw_chance"]]
    if grouped:
        check("нулевой шанс в группе пересчитан",
              all(r["chance"] > 0 for r in grouped),
              [r["chance"] for r in grouped[:3]])
    else:
        print("--   строк с нулевым шансом в группе тут нет, пропуск")

    # --- обход ВВЕРХ: предмет лежит только в ссылке ---
    # Предмет 11 лежит в 201 разной ссылке - это худший случай, какой есть в
    # базе. Первая версия обхода ходила по одному пути и на нём не отвечала
    # вовсе; поэтому тут не только правильность, но и время.
    status, data = call("/api/loot/item/11")
    check("тяжёлый предмет отвечает быстрее 4 с", LAST_MS < 4000,
          "%.0f мс" % LAST_MS)
    check("предмет из ссылки найден", status == 200 and data.get("paths"),
          data.get("detail"))
    if status == 200 and data.get("paths"):
        deep = [p for p in data["paths"] if len(p["chain"]) > 1]
        check("путь через ссылку раскрыт", bool(deep),
              "цепочек длиннее одной: %d" % len(deep))
        if deep:
            check("шанс по цепочке перемножен",
                  0 < deep[0]["chance"] <= 100, deep[0]["chance"])
            check("у пути есть владелец", bool(deep[0]["owner_entry"]),
                  deep[0]["owner_name"])

    # --- отрицательная ссылка: ядро читает её по модулю ---
    # В базе такая строка одна, Entry 31311, Reference -34377. Без ABS она
    # выглядела бы ссылкой в никуда.
    status, data = call("/api/loot/table/creature/31311")
    check("запись с отрицательной ссылкой читается", status == 200,
          data.get("detail"))
    if status == 200:
        refs = [r for r in data["tree"]["rows"] if r["reference"]]
        check("отрицательная ссылка раскрыта",
              bool(refs) and not refs[0].get("broken")
              and bool(refs[0].get("child", {}).get("rows")),
              refs[0] if refs else "ссылок нет")

    # --- предмет, которого нет нигде ---
    status, data = call("/api/loot/item/999999999")
    check("несуществующий предмет не роняет 500", status == 200,
          data.get("detail"))
    if status == 200:
        check("путей у него нет", not data["paths"], len(data["paths"]))

    # --- сырой доступ ко всем тринадцати ---
    for table in meta["tables"]:
        status, data = call("/api/loot/table/%s?limit=3" % table["id"])
        check("таблица «%s» листается" % table["name"],
              status == 200 and "entries" in data, data.get("detail"))

    status, data = call("/api/loot/table/nosuchtable")
    check("неизвестная таблица отказывает внятно", status == 409,
          data.get("detail"))

    # --- имена записей и групп ---
    # Автоимя должно появляться само, иначе подписывать восемь тысяч записей
    # пришлось бы руками. Своё имя должно перебивать автоимя и переживать
    # перезапрос; пустое - снимать подпись.
    status, data = call("/api/loot/table/creature/31311")
    auto = (data.get("tree", {}).get("label") or {}).get("auto")
    check("автоимя записи посчиталось", bool(auto), auto)

    status, data = call("/api/loot/table/reference/34166")
    auto_ref = (data.get("tree", {}).get("label") or {}).get("auto")
    check("автоимя ссылки взято из комментария ссылающихся", bool(auto_ref),
          auto_ref)
    check("хвост (ReferenceTable) отрезан",
          "ReferenceTable" not in (auto_ref or ""), auto_ref)

    status, body = put("/api/loot/label/creature/31311",
                       {"kind": "entry", "group_id": 0,
                        "name": "Проверка стенда", "note": "временная подпись"})
    check("имя записи сохраняется", status == 200 and body.get("name"),
          body.get("detail") or body)

    status, data = call("/api/loot/table/creature/31311")
    label = data.get("tree", {}).get("label") or {}
    check("своё имя перебивает автоимя", label.get("name") == "Проверка стенда",
          label)

    status, listed = call("/api/loot/labels?" + urllib.parse.urlencode(
        {"q": "Проверка стенда"}))
    check("подписанное находится списком",
          status == 200 and any(r["name"] == "Проверка стенда"
                                for r in listed.get("labels", [])),
          len(listed.get("labels", [])))

    # Имя группы - там автоимени нет вовсе, только своё.
    status, body = put("/api/loot/label/reference/34166",
                       {"kind": "group", "group_id": 1,
                        "name": "Проверка группы", "note": ""})
    check("имя группы сохраняется", status == 200, body.get("detail"))
    status, data = call("/api/loot/table/reference/34166")
    groups = {g["id"]: g for g in data.get("tree", {}).get("groups", [])}
    check("имя группы вернулось в дереве",
          groups.get(1, {}).get("name") == "Проверка группы", groups.get(1))

    # Подпись видна и в цепочке «где падает» - ради этого всё и затевалось.
    status, data = call("/api/loot/item/40431")
    named_hop = [h for p_ in data.get("paths", []) for h in p_["chain"]
                 if (h.get("label") or {}).get("name") == "Проверка стенда"]
    check("подпись видна в цепочке пути", bool(named_hop), len(named_hop))

    # Уборка: пустое имя без пояснения снимает подпись.
    for path, payload in (
            ("/api/loot/label/creature/31311",
             {"kind": "entry", "group_id": 0, "name": "", "note": ""}),
            ("/api/loot/label/reference/34166",
             {"kind": "group", "group_id": 1, "name": "", "note": ""})):
        status, body = put(path, payload)
        check("подпись снимается (%s)" % path.rsplit("/", 2)[-2], status == 200,
              body.get("detail"))
    status, data = call("/api/loot/table/creature/31311")
    check("после снятия осталось автоимя",
          not (data["tree"]["label"]["name"]) and data["tree"]["label"]["auto"],
          data["tree"]["label"])

    status, body = put("/api/loot/label/creature/31311",
                       {"kind": "нетакое", "group_id": 0, "name": "x"})
    check("чужой род подписи отказан", status >= 400, body.get("detail"))


    # --- правка строк ---
    # Пишем в СВОЮ запись: номер, на который не ссылается ни одно существо.
    # Живую добычу стенд не трогает - ошибка здесь стоила бы чужого лута.
    PROBE = 8888888
    status, data = call("/api/loot/table/creature/%d" % PROBE)
    check("пробная запись пуста", status == 200 and not data["tree"]["rows"],
          len(data.get("tree", {}).get("rows", [])))

    def row(**kw):
        base = {"item": 0, "reference": 0, "chance": 50, "quest": False,
                "mode": 1, "group": 0, "min": 1, "max": 1, "comment": "",
                "was_item": -1, "was_reference": -1, "was_group": -1}
        base.update(kw)
        return base

    # Отказы: их проверяем раньше удачных случаев, чтобы кривая строка не
    # завелась и не испортила остальное.
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=2841, reference=34166))
    check("предмет и ссылка разом отказаны", status >= 400, why(body))
    status, body = put("/api/loot/row/creature/%d" % PROBE, row())
    check("пустая строка отказана", status >= 400, why(body))
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=999999999))
    check("несуществующий предмет отказан", status >= 400, why(body))
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(reference=999999999))
    check("ссылка в никуда отказана", status >= 400, why(body))
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=2841, chance=0))
    check("шанс 0 вне группы отказан", status >= 400, why(body))
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=2841, min=3, max=1))
    check("максимум меньше минимума отказан", status >= 400, why(body))

    # Удачные случаи.
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=2841, chance=25, min=1, max=3,
                           comment="стенд"))
    check("строка добавлена", status == 200, why(body))

    status, data = call("/api/loot/table/creature/%d" % PROBE)
    rows = data["tree"]["rows"]
    check("строка видна в дереве", len(rows) == 1, len(rows))
    if rows:
        check("шанс и количество сохранились",
              rows[0]["chance"] == 25 and rows[0]["max"] == 3, rows[0])

    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=2841, chance=25))
    check("дубль ключа отказан", status >= 400, why(body))

    # Правка без смены ключа.
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=2841, chance=60, was_item=2841,
                           was_reference=0, was_group=0))
    check("шанс правится", status == 200, why(body))
    status, data = call("/api/loot/table/creature/%d" % PROBE)
    check("правка не раздвоила строку", len(data["tree"]["rows"]) == 1,
          len(data["tree"]["rows"]))
    check("новый шанс на месте", data["tree"]["rows"][0]["chance"] == 60,
          data["tree"]["rows"][0]["chance"])

    # Смена группы МЕНЯЕТ КЛЮЧ: сервер обязан удалить прежнюю строку, а не
    # оставить рядом вторую.
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=2841, chance=0, group=1, was_item=2841,
                           was_reference=0, was_group=0))
    check("перенос строки в группу", status == 200, why(body))
    status, data = call("/api/loot/table/creature/%d" % PROBE)
    check("смена ключа не раздвоила строку", len(data["tree"]["rows"]) == 1,
          len(data["tree"]["rows"]))
    if data["tree"]["rows"]:
        check("в группе нулевой шанс стал долей",
              data["tree"]["rows"][0]["chance"] == 100,
              data["tree"]["rows"][0]["chance"])

    # Вторая строка в ту же группу - доля должна стать по половине.
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=3859, chance=0, group=1))
    check("вторая строка группы добавлена", status == 200, why(body))
    status, data = call("/api/loot/table/creature/%d" % PROBE)
    shares = sorted(r["chance"] for r in data["tree"]["rows"])
    check("остаток поделён поровну", shares == [50.0, 50.0], shares)

    # Имя группе - и оно должно переехать вместе со строками.
    status, body = put("/api/loot/label/creature/%d" % PROBE,
                       {"kind": "group", "group_id": 1, "name": "Стендовая",
                        "note": ""})
    check("группа названа", status == 200, why(body))

    status, body = post("/api/loot/group/creature/%d?source=1&target=4"
                        % PROBE)
    check("группа перенесена", status == 200 and body.get("moved") == 2,
          why(body) or body)
    status, data = call("/api/loot/table/creature/%d" % PROBE)
    groups = {g["id"]: g for g in data["tree"]["groups"]}
    check("строки в новой группе", set(groups) == {4}, sorted(groups))
    check("имя переехало вместе с ними",
          groups.get(4, {}).get("name") == "Стендовая", groups.get(4))

    status, body = post("/api/loot/group/creature/%d?source=9&target=5" % PROBE)
    check("перенос пустой группы отказан", status >= 400, why(body))

    # --- уборка ---
    for item in (2841, 3859):
        status, body = delete("/api/loot/row/creature/%d?item=%d&reference=0"
                              "&group=4" % (PROBE, item))
        check("строка %d убрана" % item, status == 200, why(body))
    status, body = delete("/api/loot/row/creature/%d?item=2841&reference=0"
                          "&group=4" % PROBE)
    check("удаление несуществующей строки отказано", status >= 400, why(body))
    put("/api/loot/label/creature/%d" % PROBE,
        {"kind": "group", "group_id": 4, "name": "", "note": ""})

    status, data = call("/api/loot/table/creature/%d" % PROBE)
    check("после стенда запись снова пуста", not data["tree"]["rows"],
          len(data["tree"]["rows"]))


    # --- сборка группы ---
    # Группы как таблицы нет: она живёт ровно пока хоть у одной строки стоит её
    # номер. Поэтому «сделать группу» - это собрать в неё строки, а не завести
    # где-то пустую запись.
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=2841, chance=30))
    check("строка A заведена", status == 200, why(body))
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=3859, chance=30))
    check("строка B заведена", status == 200, why(body))
    status, body = put("/api/loot/row/creature/%d" % PROBE,
                       row(item=4470, chance=30))
    check("строка C заведена", status == 200, why(body))

    status, body = call("/api/loot/group/creature/%d/free" % PROBE)
    check("свободный номер группы подбирается",
          status == 200 and body.get("group") == 1, body)

    status, body = post("/api/loot/group/creature/%d/collect" % PROBE, {
        "rows": [{"item": 2841, "reference": 0, "group": 0},
                 {"item": 3859, "reference": 0, "group": 0}],
        "target": 0, "name": "Собранная стендом"})
    check("две строки собраны в новую группу",
          status == 200 and body.get("group") == 1 and body.get("moved") == 2,
          why(body) or body)

    status, data = call("/api/loot/table/creature/%d" % PROBE)
    groups = {g["id"]: g for g in data["tree"]["groups"]}
    check("в записи появилась группа 1 и строка вне групп",
          sorted(groups) == [0, 1], sorted(groups))
    check("новая группа названа при сборке",
          groups.get(1, {}).get("name") == "Собранная стендом", groups.get(1))
    inside = [r for r in data["tree"]["rows"] if r["group"] == 1]
    check("в группе обе строки", len(inside) == 2, len(inside))

    # Пустой набор и занятый ключ - отказы.
    status, body = post("/api/loot/group/creature/%d/collect" % PROBE,
                        {"rows": [], "target": 0})
    check("сборка без выбора отказана", status >= 400, why(body))
    status, body = post("/api/loot/group/creature/%d/collect" % PROBE, {
        "rows": [{"item": 2841, "reference": 0, "group": 0}], "target": 1})
    check("сборка в занятый ключ отказана", status >= 400, why(body))

    # Третью строку - в ту же группу указанным номером.
    status, body = post("/api/loot/group/creature/%d/collect" % PROBE, {
        "rows": [{"item": 4470, "reference": 0, "group": 0}], "target": 1})
    check("строка добавлена в существующую группу",
          status == 200 and body.get("moved") == 1, why(body) or body)

    # Подпись пустой группы должна сниматься сама: номер займут заново, и имя
    # всплыло бы на чужой группе.
    status, body = post("/api/loot/group/creature/%d?source=1&target=2" % PROBE)
    check("группа переехала целиком", status == 200 and body.get("moved") == 3,
          why(body) or body)
    status, data = call("/api/loot/table/creature/%d" % PROBE)
    groups = {g["id"]: g for g in data["tree"]["groups"]}
    check("имя уехало вместе с группой",
          groups.get(2, {}).get("name") == "Собранная стендом", groups.get(2))
    check("подписи у опустевшей группы не осталось", 1 not in groups,
          sorted(groups))

    for item in (2841, 3859, 4470):
        delete("/api/loot/row/creature/%d?item=%d&reference=0&group=2"
               % (PROBE, item))
    status, data = call("/api/loot/table/creature/%d" % PROBE)
    check("после сборки запись снова пуста", not data["tree"]["rows"],
          len(data["tree"]["rows"]))
    status, listed = call("/api/loot/labels?table_id=creature")
    check("подписи опустевших групп прибраны",
          not [r for r in listed.get("labels", [])
               if int(r["entry"]) == PROBE], listed.get("labels"))

    # Мир должен уметь перечитать таблицу: иначе правка ждёт рестарта.
    status, body = post("/api/loot/reload/creature")
    check("мир перечитал таблицу", status == 200, why(body))

    print()
    if failures:
        print("ПРОВАЛОВ: %d" % len(failures))
        return 1
    print("всё зелено")
    return 0


if __name__ == "__main__":
    sys.exit(main())
