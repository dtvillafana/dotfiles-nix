def modifiers:
  . as $mask |
  [
    { bit: 64, name: "Super" },
    { bit: 4, name: "Ctrl" },
    { bit: 8, name: "Alt" },
    { bit: 1, name: "Shift" },
    { bit: 32, name: "Mod3" },
    { bit: 128, name: "Mod5" }
  ] | map(select(($mask / .bit | floor % 2) == 1) | .name);

[
  .[] |
  select(.has_description and .description != "") |
  select(.dispatcher == "__lua" and (.arg | test("^[0-9]+$"))) |
  select(.non_consuming != true and .mouse != true) |
  select((.key | startswith("mouse:")) | not) |
  select(.description != "Open command palette") |
  select((.description | startswith("Exit ")) | not) |
  . + {
    label: (
      .description + "  [" +
      (if .submap == "" then "" else .submap + " → " end) +
      ((.modmask | modifiers) + [.key] | join("+")) + "]"
    )
  }
] | unique_by(.label) | sort_by(.label | ascii_downcase)
