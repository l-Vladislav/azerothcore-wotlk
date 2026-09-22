"""Сборка клиентского патча: оверлеи -> DBC -> MPQ -> CDN.

Заменяет ручной цикл «WDBX импортирует CSV в .dbc -> MPQ Editor кладёт .dbc
в архив -> копирование архива в cdn -> gen-manifest». Одна команда:

    python tools/client-patch/build.py build

Как устроено. Есть база - снимок тех DBC, что уже лежат в текущем патче
(команда bootstrap достаёт их прямо из patch-ruRU-X.MPQ, так что база
гарантированно равна тому, что сейчас у игроков). Поверх базы ложатся
оверлеи - CSV со строками, которые надо добавить или поправить. Результат
пакуется в свежий архив.

Почему свежий, а не правка существующего: MPQ Editor дописывает новую
версию файла в конец и не выбрасывает старую. Из-за этого нынешний
patch-ruRU-X.MPQ весит 1021 МБ при 24 МБ реальных данных. Сборка с нуля
избавляет от мусора автоматически.

Оверлей - обычный CSV в формате экспорта WDBX: первая строка - имена
колонок, дальше строки записей. Колонок может быть сколько угодно: ID
обязателен, остальные перекрывают соответствующие поля, а незаданные
берутся из базовой записи. То есть «поменять иконку у спелла» - это файл
из двух колонок и одной строки.
"""

import argparse
import csv
import hashlib
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import dbcdef            # noqa: E402
import dbcfile           # noqa: E402
import dbcpatch          # noqa: E402
import manifest          # noqa: E402
import stormlib          # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CONFIG_PATH = os.path.join(HERE, "config.json")

# Куда постучаться после публикации, чтобы убедиться, что CDN отдаёт новые
# файлы, а не закешированные атрибуты. На хосте это localhost:8090, в
# контейнере-сборщике - сам контейнер nginx по имени в docker-сети.
CDN_URL = os.environ.get("CLIENT_PATCH_CDN_URL", "http://localhost:8090/")

csv.field_size_limit(10 ** 9)


def load_config(path=None):
    with open(path or CONFIG_PATH, encoding="utf-8") as handle:
        cfg = json.load(handle)
    cfg["workdir_abs"] = os.path.join(REPO, cfg["workdir"])
    return cfg


def repo_path(rel):
    return os.path.join(REPO, rel.replace("/", os.sep))


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def short(path):
    """Путь покороче для вывода. На другом диске relpath падает."""
    try:
        return os.path.relpath(path, REPO)
    except ValueError:
        return path


def mb(size):
    return "%.1f МБ" % (size / 1048576.0)


def write_if_changed(path, blob):
    """Пишет файл, только если содержимое отличается. Возвращает True.

    Экономит не время, а mtime: неизменившийся файл не должен «дрожать»,
    иначе gen-manifest перехеширует его без нужды.
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.isfile(path) and os.path.getsize(path) == len(blob):
        with open(path, "rb") as handle:
            if handle.read() == blob:
                return False
    with open(path, "wb") as handle:
        handle.write(blob)
    return True


def _walk(root):
    for cur, _dirs, files in os.walk(root):
        for name in files:
            yield os.path.relpath(os.path.join(cur, name), root)


# --- bootstrap ------------------------------------------------------------

def cmd_bootstrap(cfg, args):
    """Достать базу и отличия вариантов из текущих архивов на CDN."""
    work = cfg["workdir_abs"]
    base_dir = os.path.join(work, "base")
    base_name = next(n for n, v in cfg["variants"].items() if v.get("base"))

    if os.path.isdir(base_dir) and not args.force:
        sys.exit("база уже есть: %s (перезаписать: --force)" % base_dir)

    src = repo_path(cfg["variants"][base_name]["bootstrap"])
    print("база <- %s" % src)
    shutil.rmtree(base_dir, ignore_errors=True)
    names = _extract_all(src, base_dir)
    print("   файлов: %d" % len(names))

    for name, variant in sorted(cfg["variants"].items()):
        if variant.get("base"):
            continue
        src = repo_path(variant["bootstrap"])
        tmp = os.path.join(work, "_tmp_" + name)
        shutil.rmtree(tmp, ignore_errors=True)
        _extract_all(src, tmp)
        out = os.path.join(work, "variants", name)
        shutil.rmtree(out, ignore_errors=True)
        kept = []
        for rel in _walk(tmp):
            here = os.path.join(tmp, rel)
            there = os.path.join(base_dir, rel)
            same = (os.path.isfile(there)
                    and os.path.getsize(here) == os.path.getsize(there)
                    and sha256(here) == sha256(there))
            if same:
                continue
            dest = os.path.join(out, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copy2(here, dest)
            kept.append(rel)
        shutil.rmtree(tmp, ignore_errors=True)
        print("вариант %s <- %s" % (name, src))
        for rel in kept:
            print("   отличается: %s" % rel)
        if not kept:
            print("   отличий от базы нет")

    for sub in ("overlay", "build", "dist"):
        os.makedirs(os.path.join(work, sub), exist_ok=True)
    print("")
    print("готово. база: %s" % base_dir)


def _extract_all(mpq_path, dest):
    names = []
    with stormlib.Archive(mpq_path) as archive:
        for name, size, comp in archive.list():
            if name.startswith("("):        # (listfile), (attributes)
                continue
            target = os.path.join(dest, name.replace("\\", os.sep))
            archive.extract(name, target)
            names.append(name)
    return names


# --- оверлеи --------------------------------------------------------------

class Overlay:
    def __init__(self, table, path, label):
        self.table = table
        self.path = path
        self.label = label


def collect_overlays(cfg):
    """Явные источники из config.json плюс найденные в overlay/."""
    out = []
    for entry in cfg.get("sources", []):
        if entry.get("enabled") is False:
            continue
        path = repo_path(entry["csv"])
        if not os.path.isfile(path):
            print("   ! нет файла, пропуск: %s" % entry["csv"])
            continue
        out.append(Overlay(entry["table"], path, entry["csv"]))

    overlay_dir = os.path.join(cfg["workdir_abs"], "overlay")
    if os.path.isdir(overlay_dir):
        for table_name in sorted(os.listdir(overlay_dir)):
            sub = os.path.join(overlay_dir, table_name)
            if not os.path.isdir(sub):
                continue
            for name in sorted(os.listdir(sub)):
                if not name.lower().endswith(".csv"):
                    continue
                out.append(Overlay(table_name, os.path.join(sub, name),
                                   "overlay/%s/%s" % (table_name, name)))
    return out


def _clean_header(raw):
    """Имя колонки из заголовка CSV.

    Экспорт панели пишет первую ячейку как '"﻿ID"' - BOM попал внутрь
    поля, и csv видит его как часть имени. Кавычки WDBX ставит вокруг всех
    имён. Снимаем и то и другое, иначе колонка ID не находится и оверлей
    молча не применяется.
    """
    name = (raw or "").strip().replace("﻿", "")
    return name.strip().strip('"').strip()


def read_overlay(overlay, table):
    """CSV -> (список {колонка: значение}, список неизвестных колонок)."""
    with open(overlay.path, encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle)
        header = next(reader, None)
        if not header:
            return [], []
        known = {c.name.lower(): c.name for c in table.columns}
        mapped, unknown = [], []
        for raw in header:
            name = _clean_header(raw)
            real = known.get(name.lower())
            if real is None:
                unknown.append(name)
            mapped.append(real)
        rows = []
        for line in reader:
            if not line or not any(cell.strip() for cell in line):
                continue
            values = {}
            for index, real in enumerate(mapped):
                if real is None or index >= len(line):
                    continue
                values[real] = line[index]
            rows.append(values)
    return rows, unknown


def apply_overlay(dbc, rows, table):
    """Вернёт (новых, изменённых, без изменений, [(id, [колонки])])."""
    index_col = next((c.name for c in table.columns if c.is_index),
                     table.columns[0].name)
    added = updated = same = 0
    changes = []
    for values in rows:
        raw_id = (values.get(index_col) or "").strip()
        if not raw_id:
            continue
        entry_id = int(float(raw_id))
        row = dbc.row_of(entry_id)
        if row is None:
            dbc.append_record(dbcfile.pack_record(dbc, values))
            added += 1
            continue
        before = dbc.record(row)
        after = dbcfile.pack_record(dbc, values, base=before)
        if after == before:
            same += 1
            continue
        dbc.set_record(row, after)
        updated += 1
        if len(changes) < 20:
            was = dbcfile.describe_record(dbc, before)
            now = dbcfile.describe_record(dbc, after)
            changed_cols = [k for k in now if now[k] != was[k]]
            changes.append((entry_id, changed_cols))
    return added, updated, same, changes


# --- сборка ---------------------------------------------------------------

def cmd_build(cfg, args):
    work = cfg["workdir_abs"]
    base_dir = os.path.join(work, "base")
    if not os.path.isdir(base_dir):
        sys.exit("нет базы - сначала: python tools/client-patch/build.py "
                 "bootstrap")

    overlays = collect_overlays(cfg)
    print("оверлеев: %d" % len(overlays))

    results = {}
    for variant_name, variant in sorted(cfg["variants"].items()):
        print("")
        print("=== вариант %s ===" % variant_name)
        tree = _compose_tree(cfg, variant_name, base_dir, overlays,
                             dry_run=args.dry_run)
        archive = os.path.join(work, "dist", variant_name, cfg["archive"])
        if args.dry_run:
            print("   --dry-run: архив не собирается")
            continue
        entries = sorted(
            ((os.path.join(tree, rel), rel.replace(os.sep, "\\"))
             for rel in _walk(tree)),
            key=lambda pair: pair[1].lower())
        stormlib.create(archive, entries)
        digest = sha256(archive)
        print("   архив: %s  %s  sha %s"
              % (short(archive), mb(os.path.getsize(archive)), digest[:16]))
        _verify_archive(archive, tree)
        results[variant_name] = {"archive": archive, "sha": digest,
                                 "tree": tree, "entries": entries}

    if args.dry_run or not results:
        return
    if args.no_publish:
        print("")
        print("--no-publish: на CDN ничего не копируется")
        return
    _publish(cfg, results, args)


def _compose_tree(cfg, variant_name, base_dir, overlays, dry_run=False):
    """Собрать дерево файлов варианта: база + файлы варианта + оверлеи.

    При dry_run считает и печатает всё то же самое, но ничего не пишет:
    отчёт об изменениях не должен трогать дерево прошлой сборки.
    """
    work = cfg["workdir_abs"]
    tree = os.path.join(work, "build", variant_name)

    sources = {}
    for rel in _walk(base_dir):
        sources[rel] = os.path.join(base_dir, rel)
    variant_dir = os.path.join(work, "variants", variant_name)
    if os.path.isdir(variant_dir):
        for rel in _walk(variant_dir):
            sources[rel] = os.path.join(variant_dir, rel)

    by_table = {}
    for overlay in overlays:
        by_table.setdefault(overlay.table.lower(), []).append(overlay)

    written = 0
    for rel in sorted(sources):
        src = sources[rel]
        dest = os.path.join(tree, rel)
        name = os.path.basename(rel)
        table_name = name[:-4] if name.lower().endswith(".dbc") else None
        applicable = by_table.get((table_name or "").lower(), [])
        if not applicable:
            if dry_run:
                continue
            with open(src, "rb") as handle:
                if write_if_changed(dest, handle.read()):
                    written += 1
            continue

        table = dbcdef.table(table_name)
        dbc = dbcfile.Dbc.load(src, table)
        before_count = dbc.count
        for overlay in applicable:
            rows, unknown = read_overlay(overlay, table)
            if unknown:
                print("   ! %s: колонки не из %s, пропущены: %s"
                      % (overlay.label, table.name, ", ".join(unknown[:8])))
            added, updated, same, changes = apply_overlay(dbc, rows, table)
            print("   %s <- %s" % (table.name, overlay.label))
            print("      строк %d: новых %d, изменённых %d, без изменений %d"
                  % (len(rows), added, updated, same))
            for entry_id, cols in changes:
                print("        %d: %s" % (entry_id, ", ".join(cols[:6])))
        blob = dbc.to_bytes()
        if not dry_run and write_if_changed(dest, blob):
            written += 1
        print("      %s: записей %d -> %d, %s"
              % (name, before_count, dbc.count, mb(len(blob))))

    if dry_run:
        print("   дерево: %d файл(ов), ничего не записано" % len(sources))
        return tree

    # Файлы, оставшиеся от прошлых сборок, в архив попадать не должны.
    for rel in list(_walk(tree)):
        if rel not in sources:
            os.remove(os.path.join(tree, rel))
            print("   лишний файл удалён: %s" % rel)
    print("   дерево: %d файл(ов), перезаписано %d" % (len(sources), written))
    return tree


def _verify_archive(archive, tree):
    """Прочитать собранный архив и сверить содержимое с деревом."""
    with stormlib.Archive(archive) as opened:
        inside = {name.replace("\\", os.sep): size
                  for name, size, comp in opened.list()
                  if not name.startswith("(")}
    problems = []
    for rel in _walk(tree):
        real = os.path.getsize(os.path.join(tree, rel))
        if inside.get(rel) != real:
            problems.append("%s: в архиве %s, на диске %d"
                            % (rel, inside.get(rel), real))
    if problems:
        raise SystemExit("архив не сошёлся с деревом:\n  "
                         + "\n  ".join(problems))
    print("   проверка: %d файл(ов), размеры совпали" % len(inside))


def _publish(cfg, results, args):
    print("")
    print("=== публикация ===")
    touched = 0
    for variant_name, info in sorted(results.items()):
        dest_dir = repo_path(cfg["variants"][variant_name]["cdn"])
        dest = os.path.join(dest_dir, cfg["archive"])
        if os.path.isfile(dest) and sha256(dest) == info["sha"]:
            print("   %s: уже актуален" % variant_name)
            continue
        os.makedirs(dest_dir, exist_ok=True)
        was = mb(os.path.getsize(dest)) if os.path.isfile(dest) else "-"
        shutil.copy2(info["archive"], dest)
        print("   %s: было %s, стало %s"
              % (variant_name, was, mb(os.path.getsize(dest))))
        touched += 1

    if (cfg.get("patch") or {}).get("enabled"):
        touched += _publish_patches(cfg, results)

    if not touched:
        print("   на CDN ничего не изменилось, манифест не трогаем")
        return
    if args.no_manifest:
        print("   --no-manifest: манифест не пересобирается")
        return
    # Раньше здесь запускался gen-manifest.ps1. Теперь то же самое делает
    # manifest.py: в контейнере-сборщике PowerShell нет, а манифест обязан
    # обновиться в той же операции, что и архив, - иначе на CDN лежит новый
    # файл со старой контрольной суммой, и лаунчер откажется его ставить.
    print("   пересобираю манифест")
    try:
        manifest.generate(repo_path("launcher"), cdn_url=CDN_URL)
    except Exception as exc:                       # noqa: BLE001
        print("   ! манифест не обновлён: %s" % exc)


# --- дельты для лаунчера --------------------------------------------------
#
# Лаунчеру не нужны сами файлы патча: прошлое состояние у него уже есть -
# это установленный patch-ruRU-X.MPQ. Достаточно дать ему дельту «от такого
# sha к такому», и он пересоберёт архив у себя. Поэтому на CDN уезжают
# только .dbcp размером в килобайты, а полный архив остаётся для первой
# установки и как запасной путь.
#
# Чтобы посчитать дельту, нужна прошлая версия файла. Она лежит в складе
# client-patch/history/<файл>/<sha>.gz - по одной записи на каждую
# опубликованную версию, свежие keep штук. Игрок, отставший сильнее, просто
# скачает архив целиком.

def _safe_name(entry_name):
    return entry_name.replace("\\", "__").replace("/", "__")


def _history_dir(cfg, safe):
    return os.path.join(cfg["workdir_abs"], "history", safe)


def _history_versions(cfg, safe):
    """[(sha, байты)] прошлых версий файла, свежие первыми.

    sha считается по содержимому, а не берётся из имени файла: имя
    укорочено (полный sha в 64 символа плюс длинный путь до склада упирался
    в лимит пути Windows), да и пересчитать надёжнее, чем поверить имени.
    """
    import gzip
    folder = _history_dir(cfg, safe)
    if not os.path.isdir(folder):
        return []
    names = [n for n in os.listdir(folder) if n.endswith(".gz")]
    names.sort(key=lambda n: os.path.getmtime(os.path.join(folder, n)),
               reverse=True)
    out = []
    for name in names:
        with gzip.open(os.path.join(folder, name), "rb") as handle:
            blob = handle.read()
        out.append((hashlib.sha256(blob).hexdigest(), blob))
    return out


def _history_remember(cfg, safe, digest, blob, keep):
    import gzip
    folder = _history_dir(cfg, safe)
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, digest[:16] + ".gz")
    if not os.path.isfile(path):
        with gzip.open(path, "wb", compresslevel=6) as handle:
            handle.write(blob)
    else:
        os.utime(path, None)
    names = sorted(os.listdir(folder),
                   key=lambda n: os.path.getmtime(os.path.join(folder, n)),
                   reverse=True)
    for stale in names[keep:]:
        os.remove(os.path.join(folder, stale))


def _publish_patches(cfg, results):
    """Разложить дельты по CDN и записать фрагмент манифеста."""
    patch_cfg = cfg["patch"]
    out_dir = repo_path(patch_cfg["dir"])
    # URL внутри CDN - это путь после последнего "cdn/": лаунчер добавит его
    # к cdnBaseUrl.
    url_base = patch_cfg["dir"].replace("\\", "/").rsplit("cdn/", 1)[-1]
    # Варианты отличаются друг от друга парой файлов, а склад общий: держим
    # запас на каждый вариант, иначе версии вытесняли бы друг друга.
    keep = int(patch_cfg.get("keep", 3)) + len(cfg["variants"]) - 1

    fragment = {}
    alive = set()
    made = 0
    for variant_name, info in sorted(results.items()):
        parts = []
        archive_size = os.path.getsize(info["archive"])
        for src_path, entry_name in info["entries"]:
            with open(src_path, "rb") as handle:
                blob = handle.read()
            digest = hashlib.sha256(blob).hexdigest()
            safe = _safe_name(entry_name)
            deltas = []
            if entry_name.lower().endswith(".dbc"):
                for old_sha, old_blob in _history_versions(cfg, safe):
                    if old_sha == digest:
                        continue
                    try:
                        delta = dbcpatch.make(old_blob, blob)
                    except dbcpatch.PatchError:
                        delta = None
                    if delta is None:
                        continue
                    # Дельта имеет смысл, только пока она меньше и файла, и
                    # всего архива - иначе игроку дешевле скачать архив.
                    # Так отсеиваются, например, дельты между обычным и HD
                    # вариантом CreatureDisplayInfo: там различий больше,
                    # чем совпадений.
                    if len(delta) >= min(len(blob), archive_size):
                        continue
                    rel = "%s/%s/%s-%s.dbcp" % (url_base, safe,
                                                old_sha[:12], digest[:12])
                    path = os.path.join(out_dir, safe,
                                        "%s-%s.dbcp" % (old_sha[:12],
                                                        digest[:12]))
                    if write_if_changed(path, delta):
                        made += 1
                        print("   дельта %s: %s -> %s, %d байт"
                              % (entry_name, old_sha[:8], digest[:8],
                                 len(delta)))
                    alive.add(os.path.normcase(os.path.abspath(path)))
                    deltas.append({"from": old_sha, "url": rel,
                                   "sha256": hashlib.sha256(delta).hexdigest(),
                                   "size": len(delta)})
                _history_remember(cfg, safe, digest, blob, keep)
            parts.append({"name": entry_name, "sha256": digest,
                          "size": len(blob), "deltas": deltas})
        fragment[variant_name] = {
            "archive": cfg["archive"],
            "sha256": info["sha"],
            "parts": parts,
        }

    # Дельты, ведущие к прошлым версиям архива, больше никому не нужны.
    if os.path.isdir(out_dir):
        for rel in list(_walk(out_dir)):
            path = os.path.join(out_dir, rel)
            if os.path.normcase(os.path.abspath(path)) not in alive:
                os.remove(path)
                print("   устаревшая дельта удалена: %s" % rel)

    fragment_path = repo_path(patch_cfg["fragment"])
    blob = json.dumps(fragment, ensure_ascii=False,
                      indent=2).encode("utf-8") + b"\n"
    changed = write_if_changed(fragment_path, blob)
    print("   дельт создано: %d, фрагмент манифеста: %s"
          % (made, "обновлён" if changed else "без изменений"))
    return 1 if (made or changed) else 0


# --- статус ---------------------------------------------------------------

def cmd_status(cfg, args):
    work = cfg["workdir_abs"]
    base_dir = os.path.join(work, "base")
    print("рабочая папка: %s" % work)
    if not os.path.isdir(base_dir):
        print("базы нет - нужен bootstrap")
        return
    print("")
    print("база:")
    for rel in sorted(_walk(base_dir)):
        path = os.path.join(base_dir, rel)
        extra = ""
        if rel.lower().endswith(".dbc"):
            try:
                dbc = dbcfile.Dbc.load(path)
                extra = "записей %d" % dbc.count
            except dbcfile.DbcError as err:
                extra = "ошибка: %s" % err
        print("   %-46s %10s  %s" % (rel, mb(os.path.getsize(path)), extra))
    variants_dir = os.path.join(work, "variants")
    if os.path.isdir(variants_dir):
        for name in sorted(os.listdir(variants_dir)):
            print("")
            print("вариант %s перекрывает:" % name)
            for rel in sorted(_walk(os.path.join(variants_dir, name))):
                print("   %s" % rel)
    overlays = collect_overlays(cfg)
    print("")
    print("оверлеи: %d" % len(overlays))
    for overlay in overlays:
        print("   %-22s %s" % (overlay.table, overlay.label))


def main():
    parser = argparse.ArgumentParser(
        description="Сборка клиентского патча из оверлеев")
    parser.add_argument("--config", default=None,
                        help="другой config.json (например, для проверки "
                             "на копии CDN)")
    sub = parser.add_subparsers(dest="command", required=True)

    boot = sub.add_parser("bootstrap", help="достать базу из текущих архивов")
    boot.add_argument("--force", action="store_true",
                      help="перезаписать существующую базу")
    boot.set_defaults(func=cmd_bootstrap)

    build = sub.add_parser("build", help="собрать патч и выложить на CDN")
    build.add_argument("--dry-run", action="store_true",
                       help="только отчёт об изменениях, без архива")
    build.add_argument("--no-publish", action="store_true",
                       help="не копировать на CDN")
    build.add_argument("--no-manifest", action="store_true",
                       help="не запускать gen-manifest.ps1")
    build.set_defaults(func=cmd_build)

    status = sub.add_parser("status", help="что в базе и какие есть оверлеи")
    status.set_defaults(func=cmd_status)

    args = parser.parse_args()
    args.func(load_config(args.config), args)


if __name__ == "__main__":
    main()
