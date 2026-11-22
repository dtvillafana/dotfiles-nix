umask 077
log="$(mktemp)"
trap 'kill "${connector:-}" 2>/dev/null || true; rm -f -- "$log"' EXIT

# The origin exposes only the signature-checked POST /github endpoint.
cloudflared tunnel --url "http://127.0.0.1:$BUDDY_PORT" --no-autoupdate >"$log" 2>&1 &
connector=$!

for ((attempt = 0; attempt < 90; attempt++)); do
  kill -0 "$connector"
  url="$(grep -oEm1 'https://[a-z0-9-]+\.trycloudflare\.com' "$log" || true)"
  if [[ -n $url ]] && grep -q 'Registered tunnel connection' "$log" &&
    [[ $(curl -s --max-time 3 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$BUDDY_PORT/github") == 405 ]]; then
    break
  fi
  sleep 1
done

if ((attempt == 90)); then
  echo "Cloudflare connector or local watcher did not become ready." >&2
  exit 1
fi

# Update only our existing hook, preserving its subscriptions and active state.
jq -n --arg url "$url/github" --rawfile secret "$BUDDY_WEBHOOK_SECRET" \
  '{url:$url, secret:($secret | rtrimstr("\n")), content_type:"json", insecure_ssl:"0"}' |
  gh api "$BUDDY_HOOK/config" --method PATCH --input - --silent
printf 'Buddy webhook now points to %s/github\n' "$url"
wait "$connector"
