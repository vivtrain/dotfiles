#!/bin/bash
# portal: find a public wifi's captive-portal login page and open it in the browser.
# Works without NetworkManager connectivity checking. Usage: portal [-n]  (-n = print URL, don't open)

PROBE=http://connectivity-check.ubuntu.com/   # returns 204 + empty body when truly online
FALLBACK=http://neverssl.com/                 # plain-HTTP page portals love to hijack
open_it=1; [[ $1 == -n ]] && open_it=0

body=$(mktemp); trap 'rm -f "$body"' EXIT
read -r code loc < <(curl -s -m8 -o "$body" -w '%{http_code} %{redirect_url}\n' "$PROBE")

if [[ $code == 204 && ! -s $body ]]; then
    echo "portal: already online, no captive portal in the way."
    exit 0
fi
if [[ $code == 000 ]]; then
    echo "portal: probe got no response (no DHCP/route yet?). Trying $FALLBACK anyway." >&2
fi

url=$loc                                      # HTTP 30x Location
if [[ -z $url ]]; then                        # JS / meta-refresh redirects in the body
    url=$(grep -oiE "(location(\.href)?|window\.location)[[:space:]]*=[[:space:]]*[\"'][^\"']+" "$body" \
          | head -1 | sed -E "s/.*[\"']//")
    [[ -z $url ]] && url=$(grep -oiE "http-equiv=[\"']?refresh[^>]*url=[^\"'> ]+" "$body" \
          | head -1 | sed -E 's/.*url=//I')
fi
if [[ -z $url ]]; then
    echo "portal: probe intercepted (HTTP $code) but no redirect found; opening $FALLBACK." >&2
    url=$FALLBACK
fi

echo "portal: $url"
(( open_it )) && xdg-open "$url" >/dev/null 2>&1 &
