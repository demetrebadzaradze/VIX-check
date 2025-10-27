#!/usr/bin/env bash
# vix_check.sh - Fetch VIX daily high and issue warnings with style
# Requires: curl, jq, awk, date
# Usage: ./vix_check.sh
# Note: Uses ANSI colors and ASCII art for output

# API URL for VIX data (Yahoo Finance)
API_URL="https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX?interval=1d&range=1d"

# Timezone (customizable; fallback to UTC if invalid)
TZ="America/New_York"
LOG_PREFIX=$(TZ=$TZ date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S UTC')"- VIX Check:"

# Colors for output (ANSI escape codes)
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Simple spinner animation during fetch
spinner() {
  local spin='⠏⠇⠦⠴⠼⠹⠙⠋'
  local i=0
  for _ in {1..10}; do
    i=$(( (i+1) % ${#spin} ))
    printf "\r${BLUE}Fetching VIX data... ${spin:$i:1}${NC}"
    sleep 0.1
  done
  printf "\r${BLUE}Fetching VIX data... Done!${NC}\n"
}

# Fetch JSON and capture stderr
echo -e "${BLUE}Fetching VIX data...${NC}"
json=$(curl -sL --max-time 10 -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" "$API_URL" 2>curl_error.log)
curl_exit=$?
spinner

# Check for curl errors
if [ $curl_exit -ne 0 ]; then
  echo -e "${RED}$LOG_PREFIX Failed: Curl error (exit code $curl_exit)${NC}"
  echo -e "${YELLOW}Curl error output:${NC}"
  cat curl_error.log
  echo -e "${YELLOW}Try running: curl -vL --max-time 10 -H 'User-Agent: Mozilla/5.0' '$API_URL'${NC}"
  rm -f curl_error.log
  exit 1
fi
rm -f curl_error.log

# Check if response is empty
if [ -z "$json" ]; then
  echo -e "${RED}$LOG_PREFIX Failed: No response from API (length: ${#json})${NC}"
  echo -e "${YELLOW}Try running: curl -vL --max-time 10 -H 'User-Agent: Mozilla/5.0' '$API_URL'${NC}"
  echo -e "${YELLOW}Check network, SSL certs (sudo apt install ca-certificates), or DNS.${NC}"
  exit 1
fi

# Check if response looks like JSON
if ! echo "$json" | jq empty >/dev/null 2>&1; then
  echo -e "${RED}$LOG_PREFIX Failed: Response is not valid JSON${NC}"
  echo -e "${YELLOW}Response (first 5 lines):${NC}"
  echo "$json" | head -n 5
  exit 2
fi

# Get today's high from meta.regularMarketDayHigh
price=$(echo "$json" | jq -r '.chart.result[0].meta.regularMarketDayHigh // empty')

# Fallback: if meta is missing, get last non-null close from indicators
if [ -z "$price" ] || [ "$price" = "null" ]; then
  price=$(echo "$json" | jq -r '.chart.result[0].indicators.quote[0].close | map(select(. != null)) | .[-1] // empty')
fi

# Validate numeric value
if ! awk -v p="$price" 'BEGIN{exit(!(p+0==p))}' 2>/dev/null; then
  echo -e "${RED}$LOG_PREFIX Could not parse numeric price (raw=$price)${NC}"
  echo -e "${YELLOW}Debug: JSON structure may have changed. Raw result:${NC}"
  echo "$json" | jq '.chart.result[0] // {}' | head -n 10
  echo -e "${YELLOW}Try checking the API at $API_URL in a browser.${NC}"
  exit 3
fi

# Print found price with timestamp
echo -e "${GREEN}$LOG_PREFIX Today high VIX = $price${NC}"

# Enhanced threshold messages with ASCII art
message=$(awk -v p="$price" 'BEGIN{
  if (p >= 100) print "Apocalypse Alert! Markets in Total Chaos – Brace Yourself!";
  else if (p >= 70) print "Severe Turmoil: Investors in Panic – Volatility Spikes!";
  else if (p >= 50) print "Global Shake-Up: Markets Trembling – Fear Index Soars!";
  else if (p >= 30) print "Warning Signs: Trouble Brewing – Volatility Rising!";
  else print "All Calm: VIX in Normal Range – Markets Steady.";
}')
ascii_art=$(awk -v p="$price" 'BEGIN{
  if (p >= 100) print "\n   /\\_/\\\n  ( o.o )\n   > ^ <\n  !! DANGER !!";
  else if (p >= 70) print "\n   /\\_/\\\n  ( >.< )\n   > ^ <\n  HIGH ALERT!";
  else if (p >= 50) print "\n   /\\_/\\\n  ( o.o )\n   > ^ <\n  SHAKE TIME!";
  else if (p >= 30) print "\n   /\\_/\\\n  ( -.- )\n   > ^ <\n  WATCH OUT!";
  else print "\n   /\\_/\\\n  ( ^.^ )\n   > ^ <\n  CHILL MODE";
}')

# Display ASCII art and message with color
if awk -v p="$price" 'BEGIN{exit(!(p>=50))}' 2>/dev/null; then
  color=$RED
elif awk -v p="$price" 'BEGIN{exit(!(p>=30))}' 2>/dev/null; then
  color=$YELLOW
else
  color=$GREEN
fi
echo -e "${color}$ascii_art${NC}"
echo -e "${color}$LOG_PREFIX $message${NC}"

exit 0
