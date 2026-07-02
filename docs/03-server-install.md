# 03. Установка сервера Xibo CMS (Linux + Docker)

Здесь — полное развёртывание «мозга» системы. Делается один раз. После этого
сервер работает сам, а вы только заходите в веб-панель.

> Все команды выполняются в терминале сервера под пользователем с правами `sudo`.
> Примеры даны для Ubuntu 22.04/24.04. Для Debian команды почти те же.

---

## Шаг 0. Что понадобится

- Сервер с Linux (VPS у хостера или свой физический/виртуальный сервер).
- Публичный IP-адрес или доменное имя, по которому плееры будут ходить на сервер.
- Открытые порты **80** (веб-панель) и **9505** (XMR, мгновенные команды).
  Если планируете HTTPS — ещё **443**.

---

## Шаг 1. Установить Docker

```bash
# обновляем систему
sudo apt update && sudo apt upgrade -y

# ставим Docker Engine + Docker Compose (официальный скрипт Docker)
curl -fsSL https://get.docker.com | sudo sh

# чтобы запускать docker без sudo (перелогиньтесь после этой команды)
sudo usermod -aG docker $USER
```

Проверка:

```bash
docker --version
docker compose version
```

Обе команды должны показать номера версий без ошибок.

---

## Шаг 2. Скачать этот проект

```bash
cd /opt                      # ставим в /opt — стандартное место для служб
sudo git clone https://github.com/VZ52/clinic-video-signage.git
sudo chown -R $USER:$USER clinic-video-signage
cd clinic-video-signage
```

В папке уже лежат готовые `docker-compose.yml` и `config.env.template`.

---

## Шаг 3. Настроить config.env

```bash
cp config.env.template config.env
nano config.env
```

Обязательно задайте **MYSQL_PASSWORD** — случайный пароль из 16 символов
(только латинские буквы и цифры, без пробелов и спецсимволов). Сгенерировать:

```bash
# удобная команда, чтобы получить случайный пароль
tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16; echo
```

Скопируйте результат в строку `MYSQL_PASSWORD=`.

По желанию сразу впишите `CMS_SERVER_NAME=` (ваш домен или IP) и настройки почты
`CMS_SMTP_*`. Их можно поменять и позже. Сохраните файл (`Ctrl+O`, `Enter`,
`Ctrl+X`).

> ⚠️ Файл `config.env` содержит пароли и **не должен** попадать в git — он уже
> внесён в `.gitignore`.

---

## Шаг 4. Запустить

```bash
docker compose up -d
```

Первый запуск скачивает образы и инициализирует базу — это занимает **3–5 минут**
(иногда дольше). Следить за процессом:

```bash
docker compose logs -f cms-web
```

Дождитесь строк о том, что установка/миграция БД завершена и веб-сервер запущен.
Выйти из просмотра логов — `Ctrl+C` (контейнеры продолжат работать).

Проверить, что все контейнеры подняты:

```bash
docker compose ps
```

Должны быть в состоянии `Up`: `cms-web`, `cms-db`, `cms-xmr`, `cms-memcached`,
`cms-quickchart`.

---

## Шаг 5. Первый вход в панель

Откройте в браузере:

```
http://IP-адрес-или-домен-сервера
```

Данные для входа по умолчанию:

| Логин | Пароль |
|-------|--------|
| `xibo_admin` | `password` |

### ⚠️ Сразу после входа:

1. **Смените пароль администратора.**
   Правый верхний угол → имя пользователя → *Edit Profile* → новый пароль.
2. Проверьте раздел **Administration → Settings → Displays / Network**: там
   указан адрес CMS, который получат плееры. Он должен совпадать с тем, по
   которому плееры реально могут достучаться (домен/IP).

---

## Шаг 6. Задать «ключ регистрации» плееров (CMS Secret Key)

Чтобы плееры могли зарегистрироваться, у CMS есть секретный ключ.

**Administration → Settings → вкладка Displays → «CMS Secret Key»** — придумайте и
сохраните значение (например, случайную строку). Этот ключ вы будете вводить на
каждом плеере при первом подключении (см.
[04-players-smart-tv.md](04-players-smart-tv.md)).

---

## Шаг 7. (Рекомендуется) HTTPS

По HTTP пароли и трафик идут в открытом виде. Для «боевой» эксплуатации включите
HTTPS. Самый простой путь — поставить перед Xibo обратный прокси с бесплатным
сертификатом Let's Encrypt.

Кратко (через Caddy — он сам получает сертификат):

```bash
# на сервере ставим Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy
```

Файл `/etc/caddy/Caddyfile`:

```
cms.вашдомен.ru {
    reverse_proxy localhost:80
}
```

```bash
sudo systemctl reload caddy
```

После этого панель доступна по `https://cms.вашдомен.ru`, а в
**Settings → Displays** пропишите этот же https-адрес как адрес CMS, чтобы плееры
ходили по защищённому каналу.

> Подробнее об HTTPS и вариантах прокси — в официальном руководстве Xibo:
> https://xibosignage.com/manual

---

## Шаг 8. Проверка «сервер жив»

- Панель открывается, вход выполнен, пароль сменён — ✅
- `docker compose ps` показывает все контейнеры `Up` — ✅
- Готовы регистрировать первый плеер — переходите к
  [04-players-smart-tv.md](04-players-smart-tv.md).

---

## Полезные команды обслуживания

```bash
cd /opt/clinic-video-signage

docker compose ps              # статус контейнеров
docker compose logs -f cms-web # смотреть логи панели
docker compose restart         # перезапустить всё
docker compose down            # остановить (данные в shared/ сохраняются)
docker compose up -d           # снова запустить
```

Обновление Xibo на новую версию и бэкапы — отдельный документ
[10-maintenance-backup.md](10-maintenance-backup.md).
