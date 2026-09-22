"""Манифест CDN и упаковка аддонов - то, что раньше делали два .ps1.

Порт `launcher/tools/gen-manifest.ps1` и `launcher/tools/pack-addons.ps1` на
Python. Понадобился потому, что сборку патча увёз в контейнер
(`tools/patch-builder`), а PowerShell в нём нет.

ВРЕМЕННО их две. Оба .ps1 пока живы и делают то же самое - лаунчер
перерабатывается, а он в отдельном репозитории, и трогать его сейчас нельзя.
Как только он устоится, .ps1 надо свести к вызову этого модуля: манифесту
доверяет каждый лаунчер, и две реализации однажды разойдутся. Пока этого не
сделано, помни, что запуск .ps1 и запуск сборщика дают чуть разный
`manifest.json` по форме (отступы, экранирование кириллицы) при одинаковом
содержимом.

Что здесь важно не сломать:

  * `manifest.json` публикуется атомарно (временный файл + подмена), иначе
    nginx однажды отдаст игроку недописанный манифест;
  * sha256 считается с защитой от параллельного ПИСАТЕЛЯ: файл открывается,
    хешируется, и потом сверяются размер и mtime. Изменились - считаем
    заново. Иначе можно захешировать наполовину скопированный MPQ и разослать
    игрокам заведомо битую контрольную сумму;
  * аддоны переупаковываются ТОЛЬКО когда исходная папка новее zip. Это не
    оптимизация: у неизменного zip остаётся прежний sha256, и игроки не
    качают его заново. Заодно это бережёт zip-архивы, собранные ещё
    PowerShell: их байты отличаются от питоновских, и поголовная
    переупаковка заставила бы всех разом скачать все аддоны.
"""

import hashlib
import json
import os
import time
import zipfile
from datetime import datetime, timezone
from urllib.error import URLError
from urllib.request import Request, urlopen

# Что не кладём в аддон: документация, мусор VCS, скриншоты. Только верхний
# уровень папки аддона, ровно как в pack-addons.ps1.
EXCLUDE = {
    ".git", ".github", ".vscode", "screenshots",
    "README.md", "MANUAL.md", "INSTALL.md", "CHANGELOG.md",
    ".gitignore", ".gitattributes",
}

ADDON_TARGET = "Interface\\AddOns"


# --- хеширование ----------------------------------------------------------

def sha256_stable(path, tries=6, pause=5.0):
    """sha256 файла, который прямо сейчас может кто-то переписывать."""
    last = None
    for attempt in range(1, tries + 1):
        before = os.stat(path)
        digest = hashlib.sha256()
        try:
            with open(path, "rb") as handle:
                for chunk in iter(lambda: handle.read(1 << 20), b""):
                    digest.update(chunk)
        except OSError as exc:
            last = exc
            if attempt == tries:
                raise
            time.sleep(pause)
            continue
        after = os.stat(path)
        if (after.st_size == before.st_size
                and after.st_mtime_ns == before.st_mtime_ns):
            return digest.hexdigest()
        if attempt == tries:
            raise OSError("файл менялся всё время, пока считался хеш: %s"
                          % path)
        time.sleep(pause)
    raise last or OSError(path)


# --- аддоны ---------------------------------------------------------------

def _newest_mtime(folder):
    newest = os.stat(folder).st_mtime
    for dirpath, dirnames, filenames in os.walk(folder):
        for name in dirnames + filenames:
            try:
                newest = max(newest, os.stat(os.path.join(dirpath, name),
                                             follow_symlinks=False).st_mtime)
            except OSError:
                continue
    return newest


def _addon_name(folder):
    """Имя аддона берём из .toc, а не из папки.

    В репозитории папка может называться `wow-addon-playerbots`, а клиент
    ждёт `Interface\\AddOns\\PlayerbotsUI`. Правду знает только .toc.
    """
    tocs = sorted(n for n in os.listdir(folder)
                  if n.lower().endswith(".toc")
                  and os.path.isfile(os.path.join(folder, n)))
    if not tocs:
        return None
    own = os.path.basename(folder) + ".toc"
    for name in tocs:
        if name.lower() == own.lower():
            return name[:-4]
    return tocs[0][:-4]


def _zip_addon(folder, addon_name, dest):
    tmp = dest + ".tmp"
    if os.path.exists(tmp):
        os.remove(tmp)
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as archive:
        for item in sorted(os.listdir(folder)):
            if item in EXCLUDE:
                continue
            full = os.path.join(folder, item)
            if os.path.isfile(full):
                archive.write(full, addon_name + "/" + item)
                continue
            for dirpath, dirnames, filenames in os.walk(full):
                dirnames.sort()
                for name in sorted(filenames):
                    disk = os.path.join(dirpath, name)
                    rel = os.path.relpath(disk, folder).replace(os.sep, "/")
                    archive.write(disk, addon_name + "/" + rel)
    os.replace(tmp, dest)


def pack_addons(launcher_dir, force=False, log=print):
    """Папки в cdn/files/common/addons/ -> _dist/<Имя>.zip."""
    addons_dir = os.path.join(launcher_dir, "cdn", "files", "common", "addons")
    dist_dir = os.path.join(addons_dir, "_dist")
    if not os.path.isdir(addons_dir):
        raise FileNotFoundError(addons_dir)
    os.makedirs(dist_dir, exist_ok=True)

    packed = skipped = 0
    valid = set()
    for item in sorted(os.listdir(addons_dir)):
        folder = os.path.join(addons_dir, item)
        if item == "_dist" or not os.path.isdir(folder):
            continue
        addon_name = _addon_name(folder)
        if not addon_name:
            log("   ПРОПУСК %s: нет .toc на верхнем уровне" % item)
            continue
        zip_path = os.path.join(dist_dir, addon_name + ".zip")
        valid.add(addon_name + ".zip")

        if not force and os.path.isfile(zip_path):
            if os.stat(zip_path).st_mtime > _newest_mtime(folder):
                skipped += 1
                continue
        _zip_addon(folder, addon_name, zip_path)
        size_kb = os.path.getsize(zip_path) / 1024.0
        renamed = "" if addon_name == item else " (папка %s)" % item
        log("   упакован %-22s -> %s.zip  %.1f КБ%s"
            % (item, addon_name, size_kb, renamed))
        packed += 1

    for name in sorted(os.listdir(dist_dir)):
        if name.endswith(".zip") and name not in valid:
            os.remove(os.path.join(dist_dir, name))
            log("   удалён осиротевший %s" % name)

    log("   аддоны: упаковано %d, без изменений %d" % (packed, skipped))
    return {"packed": packed, "skipped": skipped}


# --- манифест -------------------------------------------------------------

def _entry(cdn_dir, rel_url, target, unzip, name=None, log=print):
    full = os.path.join(cdn_dir, rel_url.replace("/", os.sep))
    sha, size = "", 0
    if os.path.isfile(full):
        sha = sha256_stable(full)
        size = os.path.getsize(full)
    else:
        log("   ! НЕТ ФАЙЛА (запись пустая): %s" % full)
    return {
        "name": name or os.path.basename(target.replace("\\", "/")),
        "url": rel_url.replace("\\", "/"),
        "sha256": sha,
        "size": size,
        "target": target,
        "unzip": unzip,
    }


def _verify_cdn(entries, base_url, log=print):
    """Отдаёт ли CDN те размеры, что мы только что записали в манифест.

    Docker Desktop умеет какое-то время показывать старые атрибуты файла
    после подмены большого архива. Игрок в этот момент получит файл, не
    сходящийся с sha256 из манифеста, и застрянет. Лечится
    `docker restart ac-launcher-cdn`.
    """
    if not base_url:
        return 0
    stale = 0
    for entry in entries:
        if not entry["sha256"]:
            continue
        url = base_url.rstrip("/") + "/" + entry["url"]
        try:
            request = Request(url, method="HEAD")
            with urlopen(request, timeout=5) as response:
                served = int(response.headers.get("Content-Length", -1))
        except (URLError, OSError, ValueError) as exc:
            log("   проверка CDN пропущена (%s): %s" % (entry["url"], exc))
            return 0
        if served != entry["size"]:
            log("   ! CDN отдаёт СТАРЫЙ размер %s: %d вместо %d"
                % (entry["url"], served, entry["size"]))
            stale += 1
    if stale:
        log("   ! УСТАРЕВШИЕ ФАЙЛЫ НА CDN (%d). Выполни: "
            "docker restart ac-launcher-cdn" % stale)
    else:
        log("   проверка CDN: все размеры совпали с манифестом")
    return stale


def generate(launcher_dir, cdn_url=None, pack=True, log=print):
    """Пересобрать cdn/manifest.json. Возвращает сам манифест."""
    config_path = os.path.join(launcher_dir, "content.config.json")
    cdn_dir = os.path.join(launcher_dir, "cdn")
    if not os.path.isfile(config_path):
        raise FileNotFoundError(config_path)
    with open(config_path, encoding="utf-8") as handle:
        config = json.load(handle)

    if pack:
        pack_addons(launcher_dir, log=log)

    common = []
    dist_dir = os.path.join(cdn_dir, "files", "common", "addons", "_dist")
    if os.path.isdir(dist_dir):
        for name in sorted(n for n in os.listdir(dist_dir)
                           if n.endswith(".zip")):
            common.append(_entry(
                cdn_dir, "files/common/addons/_dist/" + name,
                ADDON_TARGET, True, name=name[:-4], log=log))
    else:
        log("   аддонов ещё нет: %s" % dist_dir)

    variants = {}
    for vname, variant in config.get("variants", {}).items():
        files = [_entry(cdn_dir, "files/" + m["file"].replace("\\", "/"),
                        m["target"], False, log=log)
                 for m in variant.get("mpq", [])]
        variants[vname] = {"label": variant.get("label", vname),
                           "files": files}

    # Дельты клиентского патча: build.py пишет patch-parts.json, здесь он
    # вклеивается в манифест. Лаунчер 1.1.0+ по нему пересобирает архив
    # локально, 1.0.x поля не видит и качает MPQ целиком.
    parts_path = os.path.join(cdn_dir, "patch-parts.json")
    if os.path.isfile(parts_path):
        with open(parts_path, encoding="utf-8") as handle:
            parts = json.load(handle)
        attached = 0
        for vname in variants:
            if vname in parts:
                variants[vname]["patch"] = parts[vname]
                attached += 1
        log("   дельты патча: приклеены к %d варианту(ам)" % attached)
    else:
        log("   дельты патча: нет (сборщик их ещё не публиковал)")

    version_path = os.path.join(cdn_dir, "launcher", "launcher-version.json")
    launcher_version = "1.0.0"
    if os.path.isfile(version_path):
        with open(version_path, encoding="utf-8") as handle:
            launcher_version = json.load(handle).get("version",
                                                     launcher_version)
    exe_path = os.path.join(cdn_dir, "launcher", "Launcher.exe")
    exe_sha, exe_size = "", 0
    if os.path.isfile(exe_path):
        exe_sha = sha256_stable(exe_path)
        exe_size = os.path.getsize(exe_path)
    else:
        log("   ! Launcher.exe не выложен - самообновление не работает")

    manifest = {
        "manifestVersion": 1,
        "serverName": config.get("serverName", ""),
        "realmlist": config.get("realmlist", ""),
        "generatedUtc": datetime.now(timezone.utc).isoformat(
            timespec="seconds").replace("+00:00", "Z"),
        "launcher": {
            "version": launcher_version,
            "url": "launcher/Launcher.exe",
            "sha256": exe_sha,
            "size": exe_size,
        },
        "common": common,
        "variants": variants,
    }

    out = os.path.join(cdn_dir, "manifest.json")
    tmp = out + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    os.replace(tmp, out)

    log("   записан %s" % out)
    log("   аддонов: %d" % len(common))
    for vname, variant in variants.items():
        log("   вариант %-8s: файлов %d%s"
            % (vname, len(variant["files"]),
               ", дельты есть" if "patch" in variant else ""))

    every = list(common)
    for variant in variants.values():
        every.extend(variant["files"])
    _verify_cdn(every, cdn_url, log=log)
    return manifest
