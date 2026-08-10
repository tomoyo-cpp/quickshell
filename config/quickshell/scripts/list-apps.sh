#!/bin/sh
# Emits the installed applications as a single JSON array:
#   [{"name":"Firefox","icon":"firefox","exec":"firefox","id":"firefox"}, ...]
#
# Quickshell's own DesktopEntries service reports zero applications in this
# build, so the .desktop files are parsed here instead.

python3 - "$XDG_DATA_DIRS" <<'PY'
import json, os, sys, glob

# XDG_DATA_HOME first, then XDG_DATA_DIRS. Order matters and it was the wrong
# way round: since the first match wins, appending the home directory meant a
# system entry always beat a user override of the same name. That is the whole
# point of ~/.local/share/applications — dropping spotify.desktop there to
# launch a patched build did nothing, because /run/current-system won.
dirs = [os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")]
dirs += [d for d in (sys.argv[1] or "").split(":") if d]

seen = {}
for base in dirs:
    for path in glob.glob(os.path.join(base, "applications", "*.desktop")):
        entry_id = os.path.basename(path)[:-len(".desktop")]
        # First directory wins, matching XDG lookup order.
        if entry_id in seen:
            continue

        name = icon = execline = ""
        in_entry = False
        hidden = False
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    line = line.rstrip("\n")
                    if line.startswith("["):
                        # Only the main section; skip trailing action groups.
                        in_entry = line == "[Desktop Entry]"
                        continue
                    if not in_entry or "=" not in line:
                        continue
                    key, _, value = line.partition("=")
                    if key == "Name" and not name:
                        name = value
                    elif key == "Icon" and not icon:
                        icon = value
                    elif key == "Exec" and not execline:
                        execline = value
                    elif key in ("NoDisplay", "Hidden") and value.strip().lower() == "true":
                        hidden = True
        except OSError:
            continue

        if hidden or not name or not execline:
            continue

        # Strip the field codes (%u %U %f %F %i %c %k) launchers must not pass.
        parts = [p for p in execline.split() if not (len(p) == 2 and p[0] == "%")]

        seen[entry_id] = {
            "id": entry_id,
            "name": name,
            "icon": icon,
            "exec": " ".join(parts),
        }

apps = sorted(seen.values(), key=lambda a: a["name"].lower())
print(json.dumps(apps, ensure_ascii=False))
PY
