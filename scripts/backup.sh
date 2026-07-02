#!/usr/bin/env bash
# =============================================================================
#  Бэкап Xibo CMS: база данных + библиотека видео + конфиги -> один архив
# =============================================================================
#  Запуск из корня проекта:
#      ./scripts/backup.sh
#  Результат: backups/backup-ГГГГ-ММ-ДД_ЧЧ-ММ.tar.gz
#
#  ВНИМАНИЕ: перед боевым использованием проверьте восстановление на тестовом
#  сервере (restore.sh). Бэкап без проверенного восстановления — не бэкап.
# =============================================================================
set -euo pipefail

# Переходим в корень проекта (на уровень выше scripts/)
cd "$(dirname "$0")/.."

STAMP="$(date +%Y-%m-%d_%H-%M)"
OUT_DIR="backups"
ARCHIVE="${OUT_DIR}/backup-${STAMP}.tar.gz"
TMP_DIR="$(mktemp -d)"

mkdir -p "${OUT_DIR}"

echo "==> Бэкап Xibo CMS  (${STAMP})"

# 1) Свежий дамп БД. Пытаемся снять «горячий» дамп через mysqldump в контейнере.
#    Если не выйдет — берём последний автоматический дамп Xibo из shared/backup.
echo "--> База данных..."
if docker compose ps --status running 2>/dev/null | grep -q cms-db; then
    # Пароль берём из config.env
    DB_PASS="$(grep -E '^MYSQL_PASSWORD=' config.env | cut -d= -f2-)"
    if docker compose exec -T cms-db sh -c "exec mysqldump -ucms -p'${DB_PASS}' cms" \
         > "${TMP_DIR}/cms-db.sql" 2>/dev/null; then
        gzip "${TMP_DIR}/cms-db.sql"
        echo "    снят свежий дамп mysqldump"
    else
        echo "    mysqldump не удался, беру shared/backup/db/latest.sql.gz"
        cp shared/backup/db/latest.sql.gz "${TMP_DIR}/cms-db.sql.gz" 2>/dev/null || \
            echo "    !! автодамп не найден — БД в бэкап не попала"
    fi
else
    echo "    контейнер cms-db не запущен, беру shared/backup/db/latest.sql.gz"
    cp shared/backup/db/latest.sql.gz "${TMP_DIR}/cms-db.sql.gz" 2>/dev/null || \
        echo "    !! автодамп не найден — БД в бэкап не попала"
fi

# 2) Конфиги
echo "--> Конфиги (config.env, *.yml)..."
cp config.env "${TMP_DIR}/" 2>/dev/null || echo "    config.env не найден"
cp ./*.yml "${TMP_DIR}/" 2>/dev/null || true

# 3) Собираем архив: дамп + конфиги + библиотека видео
echo "--> Упаковка (включая библиотеку видео, это может занять время)..."
tar -czf "${ARCHIVE}" \
    -C "${TMP_DIR}" . \
    -C "$(pwd)" shared/cms/library

rm -rf "${TMP_DIR}"

SIZE="$(du -h "${ARCHIVE}" | cut -f1)"
echo "==> Готово: ${ARCHIVE}  (${SIZE})"
echo "    Скопируйте архив на внешнее хранилище (другой сервер / облако)!"
