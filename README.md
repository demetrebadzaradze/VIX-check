# VIX Check

A small Bash script that records the official Cboe VIX daily close and prints a concise status line to the Docker log.

## Data source

The script downloads Cboe's daily VIX history CSV:

- [Cboe VIX historical-data documentation](https://www.cboe.com/tradable-products/vix/vix-historical-data/)
- [Official CSV endpoint](https://cdn-api.cboe.com/api/global/us_indices/daily_prices/VIX_History.csv)

Cboe describes the file as daily closing values, updated daily. It is historical daily data, not a real-time quote. Cboe also notes that the data is provided for convenience and its accuracy is not guaranteed.

## Run with Docker Compose

```sh
docker compose up --build -d
docker compose logs -f fearmeter
```

The container checks Cboe every five minutes. The source contains daily closing values, not real-time quotes, so this is not an intraday alert when VIX crosses a threshold. Market holidays may have no new VIX session; in that case, the script prints a short “No new VIX session” message and does not add a duplicate data row.

## Telegram alerts

The script can send a Telegram alert when the latest available VIX close is strictly above 40. It sends at most once per session to every configured recipient, with a message that includes the close and session date. The first run with Telegram configured also checks the latest available close. If several sessions were missed, it evaluates only the latest close rather than sending stale alerts for each missed session. Failed sends are retried on later checks; successful recipients are not sent the same alert again.

1. Create a bot with [@BotFather](https://t.me/BotFather) and copy its bot token.
2. For a private chat, open the bot and send `/start`. For a Telegram channel, add the bot to the channel and give it permission to post.
3. Find each recipient's chat ID. For private chats, after sending `/start`, call the bot's `getUpdates` API and use `message.chat.id`. Channel chat IDs are commonly negative numbers; a public channel username such as `@my_channel` can also be used.
4. Copy `.env.example` to `.env` and configure the bot token and comma-separated recipient IDs:

   ```dotenv
   TELEGRAM_BOT_TOKEN=your_bot_token
   TELEGRAM_CHAT_IDS=123456789,-1001234567890
   ```

   `.env` is ignored by Git and is not copied into the Docker image. Keep the bot token private.

5. Recreate the service so Compose passes the values into the container:

   ```sh
   docker compose up --build -d
   ```

Leave both values empty or unset to run without Telegram notifications. When running the script directly, load `.env` into the shell first (for example, with `set -a; . ./.env; set +a`). Telegram alert progress is stored alongside the CSV in the persistent `/data` volume.

The human-readable Docker log starts with a small cat mascot. Each new session is logged on one concise line, for example:

```text
2026-11-24 | VIX close 18.42 | CALM
```

## CSV data

Session records are kept separately in `/data/vix.csv`, persisted in the Compose `vix-data` volume. The file contains only CSV data—no log text or mascot:

```csv
date,close
2026-11-24,18.42
```

The initial run records only the latest available session. Later runs add any newer sessions in the Cboe file, without duplicating dates. Removing the volume (for example, with `docker compose down -v`) deletes the stored CSV.

To run the script directly instead of using Docker, install Bash, `curl`, and `awk`, then choose a writable CSV path:

```sh
DATA_FILE=./vix.csv ./vix_check.sh
```
