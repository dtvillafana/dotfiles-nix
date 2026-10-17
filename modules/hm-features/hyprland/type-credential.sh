# Shared by the gopass and KeePass credential shortcuts.
type_credential() (
  # Let the shortcut modifiers be released before injecting stdin.
  sleep 0.2
  local delay value clipboard_pid
  case "$1" in
  *[Rr]emmina* | *virt-manager* | *virt-viewer* | *remote-viewer*) delay=20 ;;
  *[Bb]rave* | *[Cc]hromium* | *[Cc]hrome* | *[Ff]irefox* | *qutebrowser*) delay=10 ;;
  *)
    wtype -
    return
    ;;
  esac

  # Read without trimming trailing newlines or putting credentials in argv.
  IFS= read -r -d '' value || true
  if (
    export LC_ALL=C
    [[ "$value" == *[![:print:]]* ]]
  ); then
    # ydotool maps bytes to US keycodes, not Unicode. Paste the whole value
    # instead; --paste-once is unreliable with XWayland's extra selection reads.
    # Foreground ownership expires after five seconds, even if paste is blocked.
    printf '%s' "$value" | timeout 5s wl-copy --foreground --type 'text/plain;charset=utf-8' &
    clipboard_pid=$!
    trap 'kill "$clipboard_pid" 2>/dev/null || true; wait "$clipboard_pid" 2>/dev/null || true' EXIT
    sleep 0.2
    if ! kill -0 "$clipboard_pid" 2>/dev/null; then
      notify-send --urgency=critical 'Credential paste failed' 'Could not acquire the clipboard.'
      return 1
    fi
    # Linux input keycodes: left Ctrl and V. No credential text in arguments.
    ydotool key --key-delay="$delay" 29:1 47:1 47:0 29:0
    wait "$clipboard_pid" || [[ "$?" == 124 ]]
  else
    printf '%s' "$value" | ydotool type --key-delay="$delay" --key-hold="$delay" --file=-
  fi
)
