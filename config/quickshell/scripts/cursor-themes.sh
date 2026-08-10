#!/bin/sh
# Emits the offered cursor themes as a single JSON array:
#   [{"name":"Bibata-Modern-Ice","label":"Bibata Ice","preview":"/path/to.png"}, ...]
#
# The installed themes are not the offered ones. catppuccin-cursors, Nordzy and
# Simp1e each ship a variant per flavour per accent, which comes to roughly two
# hundred directories under share/icons — a grid of that is not a choice, it is
# a phone book. So the list below is curated, and filtered down to whatever is
# actually installed. Adding a package in configuration.nix plus a line here is
# what puts a theme in the Appearance tab.
#
# Previews are rendered once with xcur2png and cached; regenerating them costs
# about a second per theme, which is why the cache is checked first.

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/cursors"
mkdir -p "$CACHE"

python3 - "$CACHE" <<'PY'
import json, os, subprocess, sys, tempfile, glob, struct

cache = sys.argv[1]

# name -> label. Chosen to suit a dark Catppuccin desktop: a spread of shapes
# rather than fifteen recolours of the same one.
OFFERED = [
    ("Bibata-Modern-Ice",           "Bibata Ice"),
    ("Bibata-Modern-Classic",       "Bibata Classic"),
    ("Bibata-Modern-Amber",         "Bibata Amber"),
    ("Simp1e-Catppuccin-Mocha",     "Simp1e Mocha"),
    ("Simp1e-Catppuccin-Macchiato", "Simp1e Macchiato"),
    ("Nordzy-catppuccin-mocha-dark",  "Nordzy Mocha"),
    ("Nordzy-catppuccin-mocha-mauve", "Nordzy Mauve"),
    ("phinger-cursors-dark",        "Phinger Dark"),
    ("phinger-cursors-light",       "Phinger Light"),
    ("BreezeX-RosePine-Linux",      "Rose Pine"),
    ("graphite-dark",               "Graphite"),
    ("capitaine-cursors",           "Capitaine"),
    ("volantes_cursors",            "Volantes"),
    ("Vimix-cursors",               "Vimix"),
    ("Adwaita",                     "Adwaita"),
]

# Same search order the Xcursor library uses, so a user-installed theme in
# ~/.icons wins over a system one of the same name.
ROOTS = [
    os.path.expanduser("~/.icons"),
    os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "icons"),
    "/run/current-system/sw/share/icons",
    "/usr/share/icons",
]


def theme_dir(name):
    for root in ROOTS:
        d = os.path.join(root, name)
        if os.path.isdir(os.path.join(d, "cursors")):
            return d
    return None


def png_width(path):
    with open(path, "rb") as fh:
        return struct.unpack(">I", fh.read(20)[16:20])[0]


def preview(name, cursors):
    """Render the arrow to a PNG once, at a size worth showing small."""
    out = os.path.join(cache, f"{name}.png")
    if os.path.exists(out):
        return out

    src = next((os.path.join(cursors, c) for c in ("default", "left_ptr", "arrow")
                if os.path.exists(os.path.join(cursors, c))), None)
    if not src:
        return ""

    with tempfile.TemporaryDirectory() as tmp:
        try:
            # cwd=tmp because -d only redirects the PNGs; xcur2png still
            # writes its index .conf into the working directory, which is
            # the shell dir when quickshell spawns this.
            subprocess.run(["xcur2png", "-d", tmp, src],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           check=True, timeout=20, cwd=tmp)
        except Exception:
            return ""
        frames = sorted(glob.glob(os.path.join(tmp, "*.png")))
        if not frames:
            return ""
        # Nearest to 48px: the grid draws these small, and a source that is
        # already small looks mushy when scaled up. Animated cursors repeat a
        # size across frames, so the first match is deliberate — one frame.
        best = min(frames, key=lambda f: abs(png_width(f) - 48))
        with open(best, "rb") as a, open(out, "wb") as b:
            b.write(a.read())
    return out


themes = []
for name, label in OFFERED:
    d = theme_dir(name)
    if not d:
        continue
    themes.append({
        "name": name,
        "label": label,
        "preview": preview(name, os.path.join(d, "cursors")),
    })

print(json.dumps(themes))
PY
