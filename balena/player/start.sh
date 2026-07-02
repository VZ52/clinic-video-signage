#!/usr/bin/env bash
# =============================================================================
#  Запуск плеера Arexibo под X на Raspberry Pi (внутри balena-контейнера)
# =============================================================================
#  Что делает:
#    1. Проверяет обязательные переменные CMS_HOST и CMS_KEY.
#    2. Поднимает X-сервер на экране устройства.
#    3. Отключает гашение экрана и заставку.
#    4. Первый запуск: регистрирует плеер в CMS (--host/--key).
#       Последующие: запускает Arexibo с уже сохранённой конфигурацией.
#
#  ⚠️ ЧЕРНОВИК. Логика запуска X может потребовать правок под конкретное
#     устройство/драйвер. См. balena/README.md, «Что проверить».
# =============================================================================
set -euo pipefail

# --- 1. Обязательные переменные ---
: "${CMS_HOST:?CMS_HOST не задан. Укажите адрес CMS (например https://cms.example.org/) в переменных balenaCloud}"
: "${CMS_KEY:?CMS_KEY не задан. Укажите CMS Secret Key из Xibo в переменных balenaCloud}"

# Каталог данных Arexibo (том arexibo-data, персистентный)
DATA_DIR="/data/arexibo"
mkdir -p "${DATA_DIR}"

export DISPLAY=":0"

# --- 2. Поднять X-сервер, если ещё не запущен ---
if ! xset q >/dev/null 2>&1; then
  echo "[start] Запускаю X-сервер..."
  # Xorg на TTY1. TODO(verify): на части устройств может понадобиться
  # указать драйвер (modesetting/fbdev) или запуск через startx.
  Xorg :0 -nolisten tcp vt1 >/var/log/xorg.log 2>&1 &
  # Ждём готовности X (до 30 сек)
  for _ in $(seq 1 30); do
    xset q >/dev/null 2>&1 && break
    sleep 1
  done
fi

if ! xset q >/dev/null 2>&1; then
  echo "[start] ОШИБКА: X-сервер не поднялся. Смотрите /var/log/xorg.log" >&2
  exit 1
fi

# --- 3. Отключить гашение экрана и заставку ---
xset -dpms   || true
xset s off   || true
xset s noblank || true

# --- 4. Запуск Arexibo ---
# Первый запуск регистрирует плеер в CMS и кэширует конфигурацию в DATA_DIR.
# Признак «уже зарегистрирован» — служебный файл-маркер.
if [ ! -f "${DATA_DIR}/.provisioned" ]; then
  echo "[start] Первый запуск: регистрация в CMS ${CMS_HOST}"
  echo "[start] После старта авторизуйте экран в панели Xibo: Displays → Authorise."
  touch "${DATA_DIR}/.provisioned"
  exec arexibo --host "${CMS_HOST}" --key "${CMS_KEY}" \
       ${DISPLAY_ID:+--display-id "${DISPLAY_ID}"} \
       "${DATA_DIR}"
else
  echo "[start] Запуск с сохранённой конфигурацией"
  exec arexibo "${DATA_DIR}"
fi
