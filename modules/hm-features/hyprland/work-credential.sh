# The wrapper supplies runtime paths, never the database password itself.
database="${database:?}"
password_file="${password_file:?}"

case "${1:-}" in
  password | username)
    attribute="$1"
    show_options=(--attributes "$attribute")
    ;;
  otp)
    attribute=otp
    show_options=(--totp)
    ;;
  *)
    echo 'Expected password, username, or otp' >&2
    exit 1
    ;;
esac

fail() {
  notify-send --urgency=critical 'Work credentials unavailable' "$1"
  exit 1
}

[ -r "$database" ] || fail 'The KeePass database is missing or unreadable.'
[ -r "$password_file" ] || fail 'The SOPS master-password file is unavailable.'

# Remember the target before Fuzzel takes focus, as with the gopass bindings.
target_class="$(hyprctl -j activewindow | jq -r '.class // ""')"
if ! entries="$(keepassxc-cli ls --quiet --recursive --flatten "$database" <"$password_file" 2>/dev/null)"; then
  fail 'Could not unlock or list the KeePass database.'
fi

# Flattened listings include groups ending in '/'; only offer entry paths.
entry="$(
  while IFS= read -r path; do
    if [[ -n "$path" && "$path" != */ ]]; then
      printf '%s\n' "$path"
    fi
  done <<<"$entries" |
    sort |
    hypr-desktop-action menu work-credentials --only-match --prompt 'Select work credential… '
)" || exit 0
[ -n "$entry" ] || exit 0

# Redirect the SOPS file to stdin: no master password in argv, env, or logs.
if ! value="$(keepassxc-cli show --quiet "${show_options[@]}" "$database" "$entry" <"$password_file" 2>/dev/null)"; then
  fail 'Could not read the selected credential.'
fi
if [ "$attribute" = username ] && [ -z "$value" ]; then
  # Migrated gopass entries use the last path component as their username.
  value="${entry##*/}"
fi
[ -n "$value" ] || fail 'The selected credential field is empty.'

printf '%s' "$value" | hypr-desktop-action type-credential "$target_class"
