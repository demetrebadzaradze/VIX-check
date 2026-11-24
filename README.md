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

The container checks at 22:30 UTC, Monday through Friday. The schedule uses UTC to avoid daylight-saving and timezone ambiguity. Market holidays may have no new VIX session; in that case, the script prints a short “No new VIX session” message and does not add a duplicate data row.

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
