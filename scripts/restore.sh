#!/usr/bin/env bash
# =============================================================================
#  Восстановление Xibo CMS из архива, созданного backup.sh
# =============================================================================
#  Запуск из корня проекта:
#      ./scripts/restore.sh backups/backup-2026-07-02_03-00.tar.gz
#
#  Что делает:
#    1. Распаковывает архив.
#    2. Восстанавливает библиотеку видео (shared/cms/library).
#    3. Восстанавливает config.env и *.yml (если их нет).
#    4. Заливает дамп БД в контейнер cms-db.
#
#  ВНИМАНИЕ: операция перезаписывает данные. Делайте только на новом/тестовом
#  сервере или полностью осознанно. Сначала проверьте на тесте!
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

ARCHIVE="${1:-}"
if [[ -z "${ARCHIVE}" || ! -f "${ARCHIVE}" ]]; then
    echo "Использование: ./scripts/restore.sh <путь-к-архиву.tar.gz>"
    exit 1
fi

echo "==> Восстановление из ${ARCHIVE}"
read -r -p "Это перезапишет текущие данные. Продолжить? (yes/no) " ANSWER
[[ "${ANSWER}" == "yes" ]] || { echo "Отменено."; exit 1; }

TMP_DIR="$(mktemp -d)"
tar -xzf "${ARCHIVE}" -C "${TMP_DIR}"

# 1) Библиотека видео
echo "--> Восстанавливаю библиотеку видео..."
mkdir -p shared/cms/library
if [[ -d "${TMP_DIR}/shared/cms/library" ]]; then
    cp -a "${TMP_DIR}/shared/cms/library/." shared/cms/library/
fi

# 2) Конфиги (не перезаписываем существующие без нужды)
if [[ ! -f config.env && -f "${TMP_DIR}/config.env" ]]; then
    echo "--> Восстанавливаю config.env..."
    cp "${TMP_DIR}/config.env" config.env
fi
for f in "${TMP_DIR}"/*.yml; do
    [[ -e "$f" && ! -e "$(basename "$f")" ]] && cp "$f" .
done

# 3) Поднимаем контейнеры (нужен работающий cms-db для заливки БД)
echo "--> Запускаю контейнеры..."
docker compose up -d
echo "    ждём готовности базы (20 сек)..."
sleep 20

# 4) Заливаем дамп БД
echo "--> Восстанавливаю базу данных..."
DB_PASS="$(grep -E '^MYSQL_PASSWORD=' config.env | cut -d= -f2-)"
DUMP=""
[[ -f "${TMP_DIR}/cms-db.sql.gz" ]] && DUMP="${TMP_DIR}/cms-db.sql.gz"
[[ -f "${TMP_DIR}/cms-db.sql"    ]] && DUMP="${TMP_DIR}/cms-db.sql"

if [[ -n "${DUMP}" ]]; then
    if [[ "${DUMP}" == *.gz ]]; then
        gunzip -c "${DUMP}" | docker compose exec -T cms-db sh -c "exec mysql -ucms -p'${DB_PASS}' cms"
    else
        docker compose exec -T cms-db sh -c "exec mysql -ucms -p'${DB_PASS}' cms" < "${DUMP}"
    fi
    echo "    база восстановлена"
else
    echo "    !! дамп БД в архиве не найден — восстановлена только библиотека"
fi

rm -rf "${TMP_DIR}"

echo "==> Готово. Перезапускаю CMS..."
docker compose restart cms-web
echo "    Проверьте панель и адрес CMS в Settings → Displays."
