"""Обёртка над StormLib: чтение и сборка MPQ-архивов.

Работает на обеих платформах:

  * Windows - lib/StormLib.dll рядом с этим файлом, x64-сборка из WDBX
    Editor (StormLib v9.00, внутри своя zlib 1.2.5). Её же вшивает в себя
    лаунчер, см. launcher/app/Services/Storm.cs;
  * Linux - системная libstorm.so, которую собирает контейнер-сборщик
    (tools/patch-builder).

Питон дёргает библиотеку через ctypes, поэтому для сборки патча не нужен ни
MPQ Editor, ни какой-либо GUI.

Проверено: архив, собранный дважды из одних и тех же файлов, побайтово
одинаков, если не просить StormLib писать блок (attributes) - он хранит
времена файлов, и sha256 менялся бы на каждой сборке. Детерминизм важен:
лаунчер сравнивает файлы по sha256, и «дрожащий» архив заставлял бы игроков
качать патч заново после каждой пересборки.

Проверено и то, что детерминизм переживает смену платформы: одно и то же
дерево из 14 файлов, упакованное StormLib.dll на Windows и libstorm.so.9 на
Linux, дало один и тот же sha256 (7e134297c5f3bd2a..., 24 980 002 байта) -
при разных версиях StormLib (9.00 против master) и разной zlib (1.2.5
внутри DLL против системной 1.3.1). Без этого сборка в контейнере ломала бы
дельты: лаунчер собирает архив у себя и сверяет sha256 с манифестом.
"""

import ctypes
import ctypes.util
import os

IS_WINDOWS = os.name == "nt"

_DLL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "lib", "StormLib.dll")

# Тип строк в API. Сборка под Windows юникодная (TCHAR = wchar_t), под Linux
# TCHAR = char - разница видна и в argtypes, и в том, что скармливать.
_PathArg = ctypes.c_wchar_p if IS_WINDOWS else ctypes.c_char_p

# Кодировка имён ВНУТРИ архива. Это часть формата MPQ, всегда однобайтовая;
# на Linux кодека mbcs нет, а latin-1 даёт те же байты для ASCII-имён.
_ANSI = "mbcs" if IS_WINDOWS else "latin-1"


def _path(value):
    """Путь на диске в том виде, какого ждёт argtypes текущей платформы."""
    value = os.path.abspath(value)
    return value if IS_WINDOWS else value.encode("utf-8")


def _name(value):
    """Имя внутри архива - всегда байты."""
    return value.encode(_ANSI)

# --- флаги StormLib -------------------------------------------------------
MPQ_CREATE_ARCHIVE_V1 = 0x00000000
MPQ_CREATE_LISTFILE = 0x00100000
MPQ_CREATE_ATTRIBUTES = 0x00200000

MPQ_FILE_IMPLODE = 0x00000100
MPQ_FILE_COMPRESS = 0x00000200
MPQ_FILE_REPLACEEXISTING = 0x80000000

MPQ_COMPRESSION_ZLIB = 0x02

STREAM_FLAG_READ_ONLY = 0x00000100

# Длина cFileName в SFILE_FIND_DATA. Разная на разных платформах: Windows
# берёт свой MAX_PATH (260), а StormPort.h под Linux определяет 1024. Ошибиться
# тут - значит читать все поля ПОСЛЕ имени со сдвигом: имена файлов выглядят
# правильно, а размеры приходят нулями, и сверка архива с деревом падает на
# ровном месте. Именно так это и всплыло при первой сборке в контейнере.
MAX_PATH = 260 if IS_WINDOWS else 1024


class SFileFindData(ctypes.Structure):
    _fields_ = [
        ("cFileName", ctypes.c_char * MAX_PATH),
        ("szPlainName", ctypes.c_char_p),
        ("dwHashIndex", ctypes.c_uint32),
        ("dwBlockIndex", ctypes.c_uint32),
        ("dwFileSize", ctypes.c_uint32),
        ("dwFileFlags", ctypes.c_uint32),
        ("dwCompSize", ctypes.c_uint32),
        ("dwFileTimeLo", ctypes.c_uint32),
        ("dwFileTimeHi", ctypes.c_uint32),
        ("lcLocale", ctypes.c_uint32),
    ]


class MpqError(RuntimeError):
    pass


def _open_library():
    if IS_WINDOWS:
        if not os.path.isfile(_DLL_PATH):
            raise MpqError("нет %s - положи рядом x64-сборку StormLib"
                           % _DLL_PATH)
        return ctypes.WinDLL(_DLL_PATH)
    # Имя с версией идёт первым: пакет с заголовками (libstorm-dev) ставят не
    # везде, а без него find_library не находит голый libstorm.so.
    for name in ("libstorm.so.9", ctypes.util.find_library("storm"),
                 "libstorm.so"):
        if not name:
            continue
        try:
            return ctypes.CDLL(name)
        except OSError:
            continue
    raise MpqError("не нашлась libstorm.so - собери StormLib "
                   "(см. tools/patch-builder/Dockerfile)")


def _load():
    s = _open_library()
    # Пути на диске - wchar_t* на Windows и char* на Linux (_PathArg). Имена
    # внутри архива всегда ANSI, это часть формата MPQ.
    s.SFileOpenArchive.restype = ctypes.c_bool
    s.SFileOpenArchive.argtypes = [
        _PathArg, ctypes.c_uint32, ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_void_p)]
    s.SFileCreateArchive.restype = ctypes.c_bool
    s.SFileCreateArchive.argtypes = [
        _PathArg, ctypes.c_uint32, ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_void_p)]
    s.SFileCloseArchive.restype = ctypes.c_bool
    s.SFileCloseArchive.argtypes = [ctypes.c_void_p]
    s.SFileAddFileEx.restype = ctypes.c_bool
    s.SFileAddFileEx.argtypes = [
        ctypes.c_void_p, _PathArg, ctypes.c_char_p,
        ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32]
    s.SFileExtractFile.restype = ctypes.c_bool
    s.SFileExtractFile.argtypes = [
        ctypes.c_void_p, ctypes.c_char_p, _PathArg, ctypes.c_uint32]
    s.SFileHasFile.restype = ctypes.c_bool
    s.SFileHasFile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    s.SFileFindFirstFile.restype = ctypes.c_void_p
    s.SFileFindFirstFile.argtypes = [
        ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(SFileFindData),
        ctypes.c_char_p]
    s.SFileFindNextFile.restype = ctypes.c_bool
    s.SFileFindNextFile.argtypes = [
        ctypes.c_void_p, ctypes.POINTER(SFileFindData)]
    s.SFileFindClose.restype = ctypes.c_bool
    s.SFileFindClose.argtypes = [ctypes.c_void_p]
    s.SFileSetMaxFileCount.restype = ctypes.c_bool
    s.SFileSetMaxFileCount.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    return s


_storm = None


def storm():
    global _storm
    if _storm is None:
        _storm = _load()
    return _storm


def _last_error():
    """Код последней ошибки - только для текста исключения.

    На Linux StormLib держит свой счётчик вместо Win32-функции; если сборка
    его не экспортирует, диагностика не должна из-за этого падать.
    """
    if IS_WINDOWS:
        return ctypes.windll.kernel32.GetLastError()
    try:
        return storm().GetLastError()
    except AttributeError:
        return 0


class Archive:
    """Открытый на чтение MPQ."""

    def __init__(self, path):
        self.path = os.path.abspath(path)
        self._handle = ctypes.c_void_p()
        ok = storm().SFileOpenArchive(
            _path(self.path), 0, STREAM_FLAG_READ_ONLY,
            ctypes.byref(self._handle))
        if not ok:
            raise MpqError("не открылся %s (код %d)"
                           % (self.path, _last_error()))

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def list(self):
        """[(имя в архиве, размер, размер в архиве)] - по (listfile)."""
        data = SFileFindData()
        find = storm().SFileFindFirstFile(
            self._handle, b"*", ctypes.byref(data), None)
        if not find:
            return []
        out = []
        try:
            while True:
                out.append((data.cFileName.decode(_ANSI, "replace"),
                            data.dwFileSize, data.dwCompSize))
                if not storm().SFileFindNextFile(find, ctypes.byref(data)):
                    break
        finally:
            storm().SFileFindClose(find)
        return out

    def extract(self, archive_name, dest_path):
        os.makedirs(os.path.dirname(os.path.abspath(dest_path)), exist_ok=True)
        ok = storm().SFileExtractFile(
            self._handle, _name(archive_name), _path(dest_path), 0)
        if not ok:
            raise MpqError("не извлёкся %s (код %d)"
                           % (archive_name, _last_error()))

    def close(self):
        if self._handle:
            storm().SFileCloseArchive(self._handle)
            self._handle = ctypes.c_void_p()


def create(path, entries):
    """Собрать архив с нуля. entries = [(путь на диске, имя в архиве)].

    Порядок entries важен: он попадает в архив как есть, а от него зависит
    sha256. Вызывающий передаёт отсортированный список - тогда одинаковый
    вход даёт побайтово одинаковый архив.

    Блок (attributes) не пишется намеренно: в нём лежат времена файлов, и
    архив менял бы sha256 после каждой пересборки.
    """
    path = os.path.abspath(path)
    if os.path.exists(path):
        os.remove(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)

    # Ёмкость хеш-таблицы: степень двойки, с запасом от числа файлов.
    capacity = 16
    while capacity < max(16, len(entries) * 2):
        capacity *= 2

    handle = ctypes.c_void_p()
    flags = MPQ_CREATE_ARCHIVE_V1 | MPQ_CREATE_LISTFILE
    if not storm().SFileCreateArchive(_path(path), flags, capacity,
                                      ctypes.byref(handle)):
        raise MpqError("не создался %s (код %d)" % (path, _last_error()))
    try:
        for src, name in entries:
            ok = storm().SFileAddFileEx(
                handle, _path(src), _name(name),
                MPQ_FILE_COMPRESS | MPQ_FILE_REPLACEEXISTING,
                MPQ_COMPRESSION_ZLIB, MPQ_COMPRESSION_ZLIB)
            if not ok:
                raise MpqError("не добавился %s (код %d)"
                               % (name, _last_error()))
    finally:
        storm().SFileCloseArchive(handle)
    return path
