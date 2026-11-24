#!/bin/bash
set -euo pipefail

readonly API_URL="https://cdn-api.cboe.com/api/global/us_indices/daily_prices/VIX_History.csv"
DATA_FILE="${DATA_FILE:-/data/vix.csv}"
[[ "$DATA_FILE" == */* ]] || DATA_FILE="./$DATA_FILE"
readonly DATA_FILE
readonly RAW_FILE="$(mktemp)"
readonly NORMALIZED_FILE="$(mktemp)"
readonly NEW_ROWS_FILE="$(mktemp)"
trap 'rm -f "$RAW_FILE" "$NORMALIZED_FILE" "$NEW_ROWS_FILE"' EXIT

# cat is gone :(
#printf ' /\\_/\\\\\n( o.o )\n > ^ <\n\n'

if ! curl --fail --silent --show-error --location \
  --connect-timeout 10 --max-time 30 \
  --output "$RAW_FILE" "$API_URL"; then
  printf 'VIX check failed: could not fetch Cboe daily data.\n' >&2
  exit 1
fi

if ! awk -F, '
  { sub(/\r$/, "", $0) }
  NR == 1 {
    if ($1 != "DATE" || $2 != "OPEN" || $3 != "HIGH" || $4 != "LOW" || $5 != "CLOSE") exit 1
    next
  }
  NF != 5 { exit 1 }
  {
    split($1, parts, "/")
    if (length(parts[1]) < 1 || length(parts[1]) > 2 ||
        length(parts[2]) < 1 || length(parts[2]) > 2 ||
        length(parts[3]) != 4 ||
        parts[1] !~ /^[0-9]+$/ || parts[2] !~ /^[0-9]+$/ || parts[3] !~ /^[0-9]+$/ ||
        parts[1] < 1 || parts[1] > 12 || parts[2] < 1 || parts[2] > 31 ||
        $5 !~ /^[0-9]+([.][0-9]+)?$/) exit 1

    date = sprintf("%04d-%02d-%02d", parts[3], parts[1], parts[2])
    if (date <= previous_date) exit 1
    previous_date = date

    close_value = $5
    sub(/0+$/, "", close_value)
    sub(/[.]$/, "", close_value)
    print date "," close_value
  }
  END {
    if (NR < 2) exit 1
  }
' "$RAW_FILE" > "$NORMALIZED_FILE"; then
  printf 'VIX check failed: Cboe returned an unexpected or invalid CSV.\n' >&2
  exit 2
fi

mkdir -p "${DATA_FILE%/*}"
if [[ ! -f "$DATA_FILE" ]]; then
  printf 'date,close\n' > "$DATA_FILE"
fi

if ! IFS= read -r header < "$DATA_FILE" || [[ "$header" != 'date,close' ]]; then
  printf 'VIX check failed: %s has an invalid CSV header.\n' "$DATA_FILE" >&2
  exit 3
fi

if ! last_date=$(awk -F, '
  NR == 1 { next }
  NF != 2 || $1 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ || $2 !~ /^[0-9]+([.][0-9]+)?$/ { exit 1 }
  { date = $1 }
  END { print date }
' "$DATA_FILE"); then
  printf 'VIX check failed: %s contains an invalid data row.\n' "$DATA_FILE" >&2
  exit 3
fi

latest=$(tail -n 1 "$NORMALIZED_FILE")
latest_date=${latest%%,*}
latest_close=${latest#*,}
if [[ -n "$last_date" && "$latest_date" < "$last_date" ]]; then
  printf 'VIX check failed: Cboe data is older than the last recorded session.\n' >&2
  exit 4
fi

if [[ -z "$last_date" ]]; then
  printf '%s\n' "$latest" > "$NEW_ROWS_FILE"
else
  awk -F, -v last_date="$last_date" '$1 > last_date' "$NORMALIZED_FILE" > "$NEW_ROWS_FILE"
fi

if [[ ! -s "$NEW_ROWS_FILE" ]]; then
  printf 'No new VIX session; latest Cboe close is %s (%s).\n' "$latest_close" "$latest_date"
  exit 0
fi

cat "$NEW_ROWS_FILE" >> "$DATA_FILE"
while IFS=, read -r date close; do
  status=$(awk -v value="$close" 'BEGIN {
    if (value >= 100) print "EXTREME PANIC"
    else if (value >= 70) print "SEVERE PANIC"
    else if (value >= 50) print "HIGH FEAR"
    else if (value >= 30) print "ELEVATED"
    else print "CALM"
  }')
  printf '%s | VIX close %s | %s\n' "$date" "$close" "$status"
done < "$NEW_ROWS_FILE"
