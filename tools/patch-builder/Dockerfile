# Сборщик клиентского патча: собирает patch-ruRU-X.MPQ и обновляет манифест
# CDN по HTTP-запросу из админ-панели.
#
# Почему отдельный контейнер, а не код внутри панели: писать в launcher/cdn -
# это писать в то, что качают игроки, и у панели такого права быть не должно.
# Здесь оно есть, но снаружи контейнер не опубликован: до него дотягивается
# только то, что сидит в ac-network.

# --- сборка StormLib ------------------------------------------------------
# Версия закреплена коммитом, и это не педантизм. Лаунчер на Windows
# пересобирает архив у себя своей StormLib.dll и сверяет sha256 с манифестом;
# если здесь соберётся хоть чуть иначе, дельты перестанут применяться МОЛЧА -
# игроки просто начнут качать по 24 МБ.
#
# Проверено на этом коммите: дерево из 14 файлов дало один и тот же архив
# (24 980 002 байта, sha 7e134297c5f3bd2a...) при сборке StormLib.dll v9.00
# на Windows и libstorm.so v9.40 здесь - несмотря на разные версии StormLib
# и разную zlib (1.2.5 внутри DLL против системной 1.3.1).
FROM python:3.12-slim AS storm

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates pkg-config \
      zlib1g-dev libbz2-dev libtommath-dev libtomcrypt-dev \
 && rm -rf /var/lib/apt/lists/*

ARG STORM_COMMIT=c430a0c7ffc13b5d8fdaf0d7574be9e826a890af
RUN git clone https://github.com/ladislav-zezula/StormLib.git /src \
 && git -C /src checkout --detach ${STORM_COMMIT}

WORKDIR /src/build
RUN cmake .. -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release \
 && make -j"$(nproc)" \
 && make install

# --- сам сервис -----------------------------------------------------------
FROM python:3.12-slim

# Только runtime-библиотеки: компилятор в готовом образе не нужен.
RUN apt-get update && apt-get install -y --no-install-recommends \
      libtommath1 libtomcrypt1 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=storm /usr/local/lib/libstorm.so* /usr/local/lib/
RUN ldconfig

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/

EXPOSE 8092
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8092"]
