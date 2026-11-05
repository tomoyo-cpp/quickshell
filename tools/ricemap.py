#!/usr/bin/env python3
"""Render the whole rice as one browsable page.

    ricemap.py <dotfiles> <outdir>

Writes <outdir>/index.html, plus the screenshot it shows under
<outdir>/assets/. Everything on the page is read from the repo at the moment
it runs — file list, descriptions (each file's own header comment), keybinds
from config.kdl, packages and modules from the NixOS config, the theming
targets from the README, the colours from Theme.qml in the flavour and accent
the shell is set to — so it never needs editing by hand. The one live part is
"Outside the repo", which looks at this machine's ~/.config.

`rice map` runs this and opens the result.
"""

import html
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2])
HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")

BINARY = {".png", ".jpg", ".jpeg", ".webp", ".gz", ".ico"}
# Shown in the list but not embedded: noise, or not worth reading.
NO_BODY = {"config/nvim/lazy-lock.json", "flake.lock"}


def sh(*cmd: str) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return ""


def esc(s: str) -> str:
    return html.escape(str(s), quote=True)


# ── Files ────────────────────────────────────────────────────────────────
files = sorted(
    p
    for p in sh("git", "-C", str(ROOT), "ls-files", "-co", "--exclude-standard").splitlines()
    if (ROOT / p).is_file()
)

COMMENT = re.compile(r"^\s*(#|//|--|;)\s?")
SKIP = re.compile(r"^\s*(#!|pragma |import |\{|$|\[Desktop Entry\])")


def describe(path: str, text: str) -> str:
    """The file's own first comment paragraph — the codebase documents itself
    that way almost everywhere, so this is better than anything hand-written."""
    lines = text.splitlines()[:80]
    para: list[str] = []
    started = False
    for line in lines:
        if COMMENT.match(line) and not line.lstrip().startswith("#!"):
            body = COMMENT.sub("", line, count=1).strip()
            if body.startswith("@"):  # quickshell's //@ pragma lines
                continue
            if body.startswith("──") or set(body) <= set("─-= "):
                if started:
                    break
                continue
            if not body:
                if started:
                    break
                continue
            started = True
            para.append(body)
        elif started:
            break
        elif not SKIP.match(line) and not line.strip().startswith(("Singleton", "id:")):
            # Code before any comment: keep looking a little further, since
            # QML often opens with imports and a root element.
            continue
    if path.endswith(".desktop"):
        name = re.search(r"^Name=(.*)$", text, re.M)
        comment = re.search(r"^Comment=(.*)$", text, re.M)
        if not para:
            para = [f"Launcher entry: {name.group(1) if name else path}" + (f" — {comment.group(1)}" if comment else "")]
    s = " ".join(para)
    s = re.sub(r"\s+", " ", s)
    if len(s) > 260:
        s = s[:257].rsplit(" ", 1)[0] + "…"
    return s


MANUAL = {
    "flake.lock": "Pins nixpkgs to one revision for every machine. Moved forward only by `rice update`.",
    "state/quickshell/settings.json": "The shell's look and layout — accent, flavour, opacities, bar contents. Seeded into a new machine by `rice apply`, saved back by `rice save`.",
    "state/quickshell/theme-presets.json": "Saved theme presets from the Appearance tab.",
    "state/quickshell/equalizer.json": "The 10-band EQ curve and preset name.",
    "config/nvim/lazy-lock.json": "lazy.nvim plugin lockfile.",
    "config/fastfetch/config.jsonc": "fastfetch layout.",
    "config/starship.toml": "Prompt.",
    "config/quickshell/qmldir": "Registers the singletons and components so every file can import them by name.",
    "README.md": "The tour: screenshots, keybinds, theming, notes for borrowers.",
    "tools/ricemap.py": "Generates this page from the repo: file list, header comments, keybinds, packages, palette. Run by `rice map`.",
    ".gitignore": "Secrets, generated files, application state and machine fingerprints that stay out of the repo — each with its reason.",
}


def area(path: str) -> tuple[str, str]:
    """(group, subgroup) for the file browser."""
    parts = path.split("/")
    if path in ("flake.nix", "flake.lock", "install.sh", "local/bin/rice", ".gitignore", "README.md") or parts[0] == "tools":
        return ("Deploy", "")
    if parts[0] == "nixos":
        return ("NixOS", "/".join(parts[1:-1]))
    if parts[0] == "state":
        return ("Shell state", "")
    if parts[0] == "assets":
        return ("Screenshots", "")
    if parts[:2] == ["config", "quickshell"]:
        return ("Quickshell", parts[2] if len(parts) > 3 else "")
    if parts[:2] == ["local", "bin"]:
        return ("Scripts", "")
    if parts[:3] == ["local", "share", "applications"]:
        return ("Desktop entries", "")
    if parts[0] == "config":
        return ("Config", parts[1] if len(parts) > 2 else "")
    return ("Other", "")


def destination(path: str) -> tuple[str, str]:
    """(how it reaches the machine, where it lands)."""
    parts = path.split("/")
    if parts[0] == "nixos" or path in ("flake.nix", "flake.lock"):
        return ("flake", "built into the system by rice apply")
    if parts[0] == "state":
        return ("seed", "~/.local/state/quickshell/by-shell/<hash>/" + parts[-1])
    if parts[0] == "config":
        return ("link", "~/.config/" + "/".join(parts[1:]))
    if parts[0] == "local":
        return ("link", "~/.local/" + "/".join(parts[1:]))
    return ("repo", "stays in the repo")


entries = []
total_lines = 0
for p in files:
    full = ROOT / p
    ext = full.suffix.lower()
    group, sub = area(p)
    how, dest = destination(p)
    e = {"path": p, "group": group, "sub": sub, "how": how, "dest": dest, "size": full.stat().st_size}
    if ext in BINARY:
        e.update(lines=0, desc="Image." if ext != ".gz" else "Compressed log.", body=None)
    else:
        try:
            text = full.read_text()
        except UnicodeDecodeError:
            text = ""
        n = text.count("\n") + (0 if text.endswith("\n") or not text else 1)
        total_lines += n
        e.update(
            lines=n,
            desc=MANUAL.get(p) or describe(p, text),
            body=None if p in NO_BODY or "obs-studio" in p else text,
            exec=os.access(full, os.X_OK),
        )
    entries.append(e)

GROUP_ORDER = ["Deploy", "NixOS", "Quickshell", "Config", "Scripts", "Desktop entries", "Shell state", "Screenshots", "Other"]
SUB_ORDER = {"Quickshell": ["", "surfaces", "widgets", "components", "services", "scripts"]}


def sort_key(e):
    g = GROUP_ORDER.index(e["group"])
    subs = SUB_ORDER.get(e["group"])
    s = subs.index(e["sub"]) if subs and e["sub"] in subs else 99
    return (g, s, e["sub"], e["path"])


entries.sort(key=sort_key)

qml = [e for e in entries if e["path"].endswith(".qml")]
scripts = [e for e in entries if e.get("exec") and e["body"] is not None]

# ── Theme, from the shell's own palette and settings ─────────────────────
theme_src = (ROOT / "config/quickshell/services/Theme.qml").read_text()
palettes = {}
for name, block in re.findall(r"(\w+): \{([^{}]*)\}", theme_src):
    cols = dict(re.findall(r'(\w+): "(#[0-9a-fA-F]{6})"', block))
    if "base" in cols and "text" in cols:
        palettes[name] = cols
try:
    settings = json.loads((ROOT / "state/quickshell/settings.json").read_text())
except (OSError, ValueError):
    settings = {}
flavour = settings.get("flavour", "mocha")
accent = settings.get("accent", "mauve")
dark = palettes.get(flavour) or palettes.get("mocha")
if dark is palettes.get("latte"):
    dark = palettes.get("mocha")
light = palettes.get("latte")


def tokens(pal: dict) -> str:
    acc = pal.get(accent, pal.get("mauve"))
    return (
        f"--bg:{pal['base']};--panel:{pal['mantle']};--sunk:{pal['crust']};"
        f"--line:{pal['surface0']};--line2:{pal['surface1']};--muted:{pal['overlay1']};"
        f"--sub:{pal['subtext0']};--ink:{pal['text']};--accent:{acc};"
        f"--ok:{pal['green']};--warn:{pal['peach']};--bad:{pal['red']};"
        f"--c-link:{pal['blue']};--c-flake:{pal['mauve']};--c-seed:{pal['teal']};"
        f"--c-post:{pal['yellow']};--c-repo:{pal['overlay1']};--c-gen:{pal['peach']};"
    )


# ── Keybinds, from config.kdl ────────────────────────────────────────────
kdl = (ROOT / "config/niri/config.kdl").read_text()
m = re.search(r"^binds \{\n(.*?)^\}", kdl, re.S | re.M)
binds = []
for line in (m.group(1) if m else "").splitlines():
    s = line.strip()
    if not s or s.startswith("//"):
        continue
    bm = re.match(r"([^\s{]+)((?:\s+[\w-]+=(?:\"[^\"]*\"|\S+))*)\s*\{\s*(.*?);?\s*\}\s*(//.*)?$", s)
    if not bm:
        continue
    key, props, action, tail = bm.groups()
    title = re.search(r'hotkey-overlay-title="([^"]*)"', props or "")
    act = action.strip().rstrip(";")
    q = re.match(r'spawn(?:-sh)? "qs ipc call bar (\w+) (\w+)"', act) or re.match(
        r'spawn "qs" "ipc" "call" "bar" "(\w+)" "(\w+)"', act
    )
    if q:
        cat, label = "Shell", f"{q.group(2)} {'panel' if q.group(1) == 'toggle' else 'tab'}"
    elif act.startswith("spawn"):
        args = re.findall(r'"([^"]*)"', act)
        cat, label = ("Media & hardware" if key.startswith("XF86") or key == "Print" else "Apps"), " ".join(args)
    elif "power-off" in act:
        cat, label = "Session", act.replace("-", " ")
    elif "workspace" in act or "monitor" in act:
        cat, label = "Workspaces & monitors", act.replace("-", " ")
    elif any(w in act for w in ("column", "window", "focus", "move", "consume", "expel", "fullscreen", "maximize", "floating", "tabbed", "width", "height")):
        cat, label = "Windows & columns", act.replace("-", " ")
    else:
        cat, label = "Session", act.replace("-", " ")
    if title:
        label = title.group(1)
    binds.append({"key": key, "cat": cat, "label": label, "custom": bool(tail and "qs-custom" in tail), "raw": act})
# Arrow keys and hjkl, wheel and keys, often do the same thing: one row each.
merged: dict[tuple, dict] = {}
for b in binds:
    k = (b["cat"], b["label"])
    if k in merged:
        merged[k]["keys"].append(b["key"])
        merged[k]["custom"] |= b["custom"]
    else:
        merged[k] = dict(b, keys=[b["key"]])
n_binds = len(binds)
binds = list(merged.values())
BIND_ORDER = ["Shell", "Apps", "Windows & columns", "Workspaces & monitors", "Media & hardware", "Session"]

# ── NixOS: modules and packages ──────────────────────────────────────────
common = (ROOT / "nixos/common.nix").read_text()


def nix_sections(text: str) -> list[tuple[str, str]]:
    out = []
    lines = text.splitlines()
    for i, line in enumerate(lines):
        hm = re.match(r"\s*# ── (.+?) ─+\s*$", line)
        if not hm:
            continue
        para = []
        for nxt in lines[i + 1 : i + 12]:
            cm = re.match(r"\s*#\s?(.*)$", nxt)
            if not cm or not cm.group(1).strip():
                break
            para.append(cm.group(1).strip())
        d = " ".join(para)
        if len(d) > 180:
            d = d[:177].rsplit(" ", 1)[0] + "…"
        out.append((hm.group(1), d))
    return out


sections_common = nix_sections(common)
host_dirs = sorted(p.name for p in (ROOT / "nixos/hosts").iterdir() if p.is_dir())
sections_hosts = {h: nix_sections((ROOT / "nixos/hosts" / h / "default.nix").read_text()) for h in host_dirs}

pk = re.search(r"environment\.systemPackages =.*?\[(.*?)\n    \]", common, re.S)
pkg_groups: list[tuple[str, list[str]]] = [("Core", [])]
for line in (pk.group(1) if pk else "").splitlines():
    s = line.strip()
    cm = re.match(r"# (?:── )?([A-Z][^:;]{1,34}?)(?: ─+)?$", s)
    if cm and "," not in cm.group(1)[:3]:
        pkg_groups.append((cm.group(1).strip(), []))
        continue
    if s.startswith("#") or not s:
        continue
    cp = re.search(r"callPackage \./pkgs/([\w-]+)\.nix", s)
    if cp:
        pkg_groups[-1][1].append(cp.group(1) + " ★")
        continue
    im = re.match(r"([A-Za-z][\w.+-]*)\s*(#.*)?$", s)
    if im and im.group(1) not in ("with", "pkgs"):
        pkg_groups[-1][1].append(im.group(1))
pkg_groups = [(g, ps) for g, ps in pkg_groups if ps]
n_pkgs = sum(len(ps) for _, ps in pkg_groups)

# ── Theming targets, from the README ─────────────────────────────────────
readme = (ROOT / "README.md").read_text()
tm = re.search(r"\| Target \| How \|\n\|---\|---\|\n((?:\|.*\|\n)+)", readme)
targets = []
for row in (tm.group(1) if tm else "").strip().splitlines():
    cells = [c.strip() for c in row.strip("|").split("|")]
    if len(cells) == 2:
        targets.append(cells)

# ── Privacy, from the README ─────────────────────────────────────────────
pm = re.search(r"## Privacy\n\n.*?\n\| \| \|\n\|---\|---\|\n((?:\|.*\|\n)+)", readme, re.S)
privacy = []
for row in (pm.group(1) if pm else "").strip().splitlines():
    cells = [c.strip() for c in row.strip("|").split("|")]
    if len(cells) == 2:
        privacy.append(cells)

# ── Outside the repo: what this machine has that the repo does not ───────
KNOWN = {
    "gtk-3.0": ("gen", "written by GtkTheme.qml"),
    "gtk-4.0": ("gen", "written by GtkTheme.qml"),
    "spicetify": ("post", "configured by spotify-sync / spotify-theme"),
    "spotify": ("app", "Spotify's own prefs"),
    "waybar": ("old", "pre-Quickshell; waybar is no longer installed"),
    "fuzzel": ("old", "pre-Quickshell; fuzzel is no longer installed"),
    "git": ("small", "global gitignore"),
    "mpv": ("small", "empty"),
    "kitty": ("gen", "colors.conf, written by KittyTheme.qml; kitty.conf is linked"),
    "fish": ("app", "fish_variables; config.fish is linked"),
    "fastfetch": ("small", "config.jsonc is linked"),
}
APP_STATE = {"Code", "discord", "chromium", "mozilla", "zen", "librewolf", "GIMP", "blender", "Mullvad VPN",
             "dconf", "pulse", "configstore", "nautilus", "jgit", "obs-studio", "Thunar", "btop", "mimeapps.list"}
outside = []
if CONFIG.is_dir():
    for p in sorted(CONFIG.iterdir(), key=lambda x: x.name.lower()):
        if p.is_symlink() and str(os.readlink(p)).startswith(str(ROOT)):
            continue
        name = p.name
        if name in KNOWN:
            kind, note = KNOWN[name]
        elif name in APP_STATE or name.startswith("shopify-cli"):
            kind, note = "app", "application state, not configuration"
        else:
            kind, note = "small", "not tracked"
        size = sh("du", "-sh", str(p)).split("\t")[0] if p.exists() else ""
        outside.append({"name": name, "kind": kind, "note": note, "size": size})
shopify = [o for o in outside if o["name"].startswith("shopify-cli")]
if len(shopify) > 1:
    outside = [o for o in outside if not o["name"].startswith("shopify-cli")]
    outside.append({"name": f"shopify-cli-* ({len(shopify)})", "kind": "app", "note": "application state, not configuration", "size": ""})
    outside.sort(key=lambda o: o["name"].lower())
extra_outside = []
wp = HOME / "Pictures/Wallpapers"
if wp.is_dir():
    n = len([x for x in wp.iterdir() if x.is_file()])
    extra_outside.append({"name": "~/Pictures/Wallpapers", "kind": "copy", "note": f"{n} images, read by the Wallpaper tab — copy them to a new machine by hand", "size": sh("du", "-sh", str(wp)).split("\t")[0]})
extra_outside.append({"name": "~/.local/state/rice/wallpaper", "kind": "gen", "note": "which wallpaper is picked (set-wallpaper.sh)", "size": ""})
extra_outside.append({"name": "~/.icons/default", "kind": "gen", "note": "written by set-cursor.sh", "size": ""})
extra_outside.append({"name": "/etc/nixos/hardware-configuration.nix", "kind": "machine", "note": "this machine's disks — generated per machine, kept out of a public repo", "size": ""})

# ── Repo facts ───────────────────────────────────────────────────────────
rev = sh("git", "-C", str(ROOT), "rev-parse", "--short", "HEAD").strip()
dirty = len(sh("git", "-C", str(ROOT), "status", "--porcelain").splitlines())
remote = sh("git", "-C", str(ROOT), "remote", "get-url", "origin").strip()
clone = remote
gm = re.match(r"git@github\.com:(.+?)(?:\.git)?$", remote)
if gm:
    clone = f"https://github.com/{gm.group(1)}"
lock = json.loads((ROOT / "flake.lock").read_text())
nixrev = lock["nodes"]["nixpkgs"]["locked"]["rev"][:12]
nixref = lock["nodes"]["nixpkgs"]["original"].get("ref", "")

# ── Page ─────────────────────────────────────────────────────────────────
HOW_LABEL = {"link": "symlink", "flake": "flake", "seed": "seeded", "repo": "repo only"}
KIND_LABEL = {"gen": "generated", "app": "app state", "old": "leftover", "small": "untracked", "post": "script-built", "copy": "copy by hand", "machine": "per machine"}

map_rows = [
    ("config/{quickshell,niri,nvim}/", "~/.config/…", "link", "linked whole — the rice's own; the shell rewrites config.kdl in place"),
    ("config/<app>/<file>", "~/.config/<app>/<file>", "link", "file by file, tracked files only — apps can't write into the repo"),
    ("local/bin/*", "~/.local/bin/", "link", "rice, volume, spotify-sync, spotify-theme, spotify-cdp"),
    ("local/share/applications/*", "~/.local/share/applications/", "link", "spotify.desktop, launching the patched copy"),
    ("flake.nix · nixos/", "the system", "flake", "rice apply → nixos-rebuild --flake --impure --sudo"),
    ("state/quickshell/", "~/.local/state/quickshell/…", "seed", "copied once if absent; rice save saves it back"),
    ("generated files", "kitty colours, GTK, cursor", "gen", "rewritten by the shell's theme services on first run"),
]

commands = [
    ("New machine", "Fresh NixOS install, logged in as tomoyo", [
        f"nix-shell -p git --run 'git clone {clone} ~/dotfiles'",
        "~/dotfiles/local/bin/rice install",
    ], "Links everything, rebuilds NixOS from the pinned flake, then builds the patched Spotify. A different machine: rice new-host <name> first."),
    ("Every day", "After editing anything under nixos/", [
        "rice           # is everything ok?",
        "rice apply     # after any change",
    ], "Dotfiles need no deploy step at all: they are symlinks, so an edit is live as soon as it is saved."),
    ("Keep it portable", "Before committing", [
        "rice save      # shell settings → repo",
    ], "Then git commit. rice update moves nixpkgs forward on purpose, and only then."),
]

data_json = json.dumps(entries, ensure_ascii=False).replace("</", "<\\/")

shot = ROOT / "assets/desktop.png"
OUT.mkdir(parents=True, exist_ok=True)
if shot.exists():
    (OUT / "assets").mkdir(exist_ok=True)
    shutil.copyfile(shot, OUT / "assets/desktop.png")


def chip(kind: str, label: str) -> str:
    return f'<span class="chip c-{esc(kind)}">{esc(label)}</span>'


def md_inline(s: str) -> str:
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", esc(s))


parts = []
w = parts.append

w(f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Rice map</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;800&family=Noto+Sans:wght@400;500;700&display=swap" rel="stylesheet">
<style>
/* Catppuccin, read from Theme.qml: latte for light, the shell's own flavour
   ({esc(flavour)}) for dark, accent "{esc(accent)}" as set in the dashboard.
   Layout: a summary band, then reference sections, then a two-pane file browser. */
:root {{ {tokens(light)} --mono:"JetBrains Mono",ui-monospace,"DejaVu Sans Mono",monospace; --sans:"Noto Sans",system-ui,sans-serif; color-scheme: light; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ {tokens(dark)} color-scheme: dark; }} }}
:root[data-theme="dark"] {{ {tokens(dark)} color-scheme: dark; }}
* {{ box-sizing: border-box; }}
html, body {{ margin: 0; }}
body {{ background: var(--bg); color: var(--ink); font: 15px/1.55 var(--sans); }}
a {{ color: var(--accent); }}
code, pre, .mono {{ font-family: var(--mono); }}
code {{ font-size: .88em; background: var(--sunk); padding: .1em .35em; border-radius: 4px; }}
.wrap {{ max-width: 1240px; margin: 0 auto; padding: 0 20px; }}
header.top {{ border-bottom: 1px solid var(--line); background: var(--panel); }}
.hero {{ display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 520px); gap: 32px; align-items: center; padding: 32px 0 28px; }}
.hero h1 {{ font: 800 40px/1.05 var(--mono); margin: 0 0 6px; letter-spacing: -.02em; text-wrap: balance; }}
.hero h1 span {{ color: var(--accent); }}
.hero p.lede {{ margin: 0 0 18px; color: var(--sub); max-width: 56ch; }}
.hero img {{ width: 100%; border-radius: 8px; border: 1px solid var(--line2); display: block; }}
.stats {{ display: flex; flex-wrap: wrap; gap: 8px 22px; font-family: var(--mono); font-variant-numeric: tabular-nums; }}
.stats div {{ display: flex; flex-direction: column; }}
.stats b {{ font-size: 22px; font-weight: 800; }}
.stats small {{ color: var(--muted); font-size: 12px; }}
.meta {{ margin-top: 14px; font: 12px var(--mono); color: var(--muted); }}
nav.toc {{ position: sticky; top: 0; z-index: 5; background: color-mix(in srgb, var(--bg) 92%, transparent); backdrop-filter: blur(6px); border-bottom: 1px solid var(--line); }}
nav.toc .wrap {{ display: flex; gap: 4px; overflow-x: auto; padding-top: 6px; padding-bottom: 6px; }}
nav.toc a {{ font: 600 13px var(--mono); color: var(--sub); text-decoration: none; padding: 6px 10px; border-radius: 6px; white-space: nowrap; }}
nav.toc a:hover, nav.toc a:focus-visible {{ background: var(--line); color: var(--ink); outline: none; }}
section {{ padding: 34px 0 6px; }}
h2 {{ font: 800 22px var(--mono); margin: 0 0 4px; text-wrap: balance; }}
h2 + p.note {{ margin: 0 0 18px; color: var(--sub); max-width: 70ch; }}
h3 {{ font: 700 14px var(--mono); margin: 0 0 8px; color: var(--ink); }}
.grid3 {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 14px; }}
.card {{ background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 16px; display: flex; flex-direction: column; gap: 10px; }}
.card .when {{ font-size: 13px; color: var(--muted); margin-top: -6px; }}
.card p {{ margin: 0; font-size: 14px; color: var(--sub); }}
.cmd {{ position: relative; background: var(--sunk); border: 1px solid var(--line); border-radius: 6px; padding: 10px 64px 10px 12px; font: 13px/1.6 var(--mono); white-space: pre; overflow-x: auto; }}
.cmd button {{ position: absolute; top: 6px; right: 6px; font: 600 11px var(--mono); background: var(--line); color: var(--ink); border: 0; border-radius: 4px; padding: 3px 7px; cursor: pointer; }}
.cmd button:hover, .cmd button:focus-visible {{ background: var(--accent); color: var(--bg); outline: none; }}
table {{ width: 100%; border-collapse: collapse; font-size: 14px; }}
th {{ text-align: left; font: 600 12px var(--mono); color: var(--muted); text-transform: uppercase; letter-spacing: .05em; padding: 6px 10px; border-bottom: 1px solid var(--line2); }}
td {{ padding: 8px 10px; border-bottom: 1px solid var(--line); vertical-align: top; }}
td.p {{ font: 13px var(--mono); white-space: nowrap; }}
.scroll {{ overflow-x: auto; }}
.chip {{ display: inline-block; font: 600 11px/1 var(--mono); padding: 4px 7px; border-radius: 99px; border: 1px solid currentColor; white-space: nowrap; }}
.c-link {{ color: var(--c-link); }} .c-flake {{ color: var(--c-flake); }} .c-seed {{ color: var(--c-seed); }}
.c-post {{ color: var(--c-post); }} .c-repo {{ color: var(--c-repo); }} .c-gen {{ color: var(--c-gen); }}
.c-app {{ color: var(--muted); }} .c-old {{ color: var(--bad); }} .c-small {{ color: var(--sub); }}
.c-copy {{ color: var(--warn); }} .c-machine {{ color: var(--c-flake); }}
.fan {{ display: grid; grid-template-columns: 180px minmax(0, 1fr); gap: 0 18px; align-items: stretch; }}
.fan .src {{ display: flex; align-items: center; justify-content: center; text-align: center; background: var(--panel); border: 1px solid var(--accent); border-radius: 8px; padding: 14px; font: 700 13px var(--mono); }}
.fan .src i {{ display: block; width: 28px; height: 28px; border-radius: 50%; background: var(--accent); margin: 0 auto 8px; }}
.fan ul {{ list-style: none; margin: 0; padding: 0 0 0 18px; border-left: 2px solid var(--accent); display: flex; flex-direction: column; gap: 6px; }}
.fan li {{ position: relative; background: var(--panel); border: 1px solid var(--line); border-radius: 6px; padding: 8px 12px; font-size: 14px; }}
.fan li::before {{ content: ""; position: absolute; left: -19px; top: 50%; width: 18px; border-top: 2px solid var(--accent); }}
.fan li b {{ font-family: var(--mono); font-size: 13px; }}
.binds {{ columns: 3 300px; column-gap: 18px; }}
.binds .grp {{ break-inside: avoid; margin-bottom: 16px; }}
.bind {{ display: flex; justify-content: space-between; gap: 10px; padding: 4px 0; border-bottom: 1px dashed var(--line); font-size: 13px; }}
.bind .keys {{ display: flex; flex-wrap: wrap; gap: 3px; color: inherit; text-align: left; }}
.bind kbd {{ font: 600 12px var(--mono); background: var(--sunk); border: 1px solid var(--line2); border-bottom-width: 2px; border-radius: 4px; padding: 1px 6px; white-space: nowrap; }}
.bind > span:last-child {{ color: var(--sub); text-align: right; }}
.bind > span.mine {{ color: var(--accent); }}
.mods {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 6px 18px; margin-bottom: 20px; }}
.mod {{ font-size: 13px; padding: 6px 0; border-bottom: 1px solid var(--line); }}
.mod b {{ font-family: var(--mono); font-size: 13px; display: block; }}
.mod span {{ color: var(--muted); }}
.pk {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(270px, 1fr)); gap: 12px; }}
.pk div {{ background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 12px; }}
.pk h3 {{ display: flex; justify-content: space-between; }}
.pk h3 small {{ color: var(--muted); font-weight: 400; }}
.pk p {{ margin: 0; font: 12.5px/1.9 var(--mono); color: var(--sub); }}
.browser {{ display: grid; grid-template-columns: minmax(0, 420px) minmax(0, 1fr); gap: 0; border: 1px solid var(--line2); border-radius: 8px; overflow: hidden; height: min(82vh, 900px); background: var(--panel); }}
.list {{ border-right: 1px solid var(--line2); display: flex; flex-direction: column; min-height: 0; }}
.list .bar {{ padding: 10px; border-bottom: 1px solid var(--line); display: flex; gap: 8px; align-items: center; }}
.list input {{ flex: 1; min-width: 0; font: 13px var(--mono); background: var(--sunk); color: var(--ink); border: 1px solid var(--line2); border-radius: 6px; padding: 7px 9px; }}
.list input:focus-visible {{ outline: 2px solid var(--accent); outline-offset: 1px; }}
.list .count {{ font: 12px var(--mono); color: var(--muted); white-space: nowrap; }}
.items {{ overflow-y: auto; flex: 1; }}
.items .g {{ position: sticky; top: 0; background: var(--line); font: 700 12px var(--mono); padding: 5px 10px; display: flex; justify-content: space-between; }}
.items .g small {{ color: var(--muted); font-weight: 400; }}
.items .s {{ font: 600 11px var(--mono); color: var(--muted); padding: 8px 10px 2px; text-transform: uppercase; letter-spacing: .05em; }}
.items button {{ all: unset; box-sizing: border-box; display: block; width: 100%; padding: 6px 10px 7px; cursor: pointer; border-left: 3px solid transparent; }}
.items button:hover {{ background: var(--sunk); }}
.items button:focus-visible {{ outline: 2px solid var(--accent); outline-offset: -2px; }}
.items button[aria-current="true"] {{ background: var(--sunk); border-left-color: var(--accent); }}
.items .n {{ display: flex; justify-content: space-between; gap: 8px; font: 13px var(--mono); }}
.items .n em {{ font-style: normal; color: var(--muted); font-size: 11px; font-variant-numeric: tabular-nums; }}
.items .d {{ display: block; font-size: 12px; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
.view {{ display: flex; flex-direction: column; min-height: 0; min-width: 0; }}
.view .hd {{ padding: 12px 16px; border-bottom: 1px solid var(--line); display: flex; flex-direction: column; gap: 6px; }}
.view .hd .path {{ font: 700 15px var(--mono); word-break: break-all; }}
.view .hd .row {{ display: flex; flex-wrap: wrap; gap: 8px 14px; align-items: center; font: 12px var(--mono); color: var(--muted); }}
.view .hd p {{ margin: 0; font-size: 14px; color: var(--sub); max-width: 80ch; }}
.view pre {{ margin: 0; padding: 12px 0; overflow: auto; flex: 1; font-size: 12.5px; line-height: 1.55; background: var(--sunk); counter-reset: ln; tab-size: 4; }}
.view pre span {{ display: block; padding: 0 16px 0 0; white-space: pre; }}
.view pre span::before {{ counter-increment: ln; content: counter(ln); display: inline-block; width: 4.2em; padding-right: 1.2em; text-align: right; color: var(--line2); user-select: none; }}
.view .empty {{ padding: 24px 16px; color: var(--muted); }}
.legend {{ display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 12px; }}
footer {{ padding: 40px 0 50px; color: var(--muted); font: 12px var(--mono); }}
@media (max-width: 900px) {{
  .hero {{ grid-template-columns: 1fr; }}
  .browser {{ grid-template-columns: 1fr; height: auto; }}
  .list {{ border-right: 0; border-bottom: 1px solid var(--line2); max-height: 50vh; }}
  .view pre {{ max-height: 70vh; }}
  .fan {{ grid-template-columns: 1fr; gap: 12px; }}
}}
@media (prefers-reduced-motion: reduce) {{ * {{ scroll-behavior: auto !important; }} }}
html {{ scroll-behavior: smooth; }}
</style>
</head>
<body>
<header class="top"><div class="wrap hero">
<div>
<h1>rice<span>.</span>map</h1>
<p class="lede">Everything that makes up this desktop — NixOS, niri and a Quickshell shell written from scratch — where each piece lives, how it reaches a machine, and the source of every file.</p>
<div class="stats">
<div><b>{len(entries)}</b><small>files</small></div>
<div><b>{total_lines:,}</b><small>lines</small></div>
<div><b>{len(qml)}</b><small>QML files</small></div>
<div><b>{len(scripts)}</b><small>scripts</small></div>
<div><b>{n_pkgs}</b><small>packages</small></div>
<div><b>{n_binds}</b><small>keybinds</small></div>
</div>
<div class="meta">{esc(remote)} · {esc(rev)}{' · ' + str(dirty) + ' uncommitted' if dirty else ''} · nixpkgs {esc(nixref)} @ {esc(nixrev)} · generated {date.today().isoformat()}</div>
</div>
{'<img src="assets/desktop.png" alt="The desktop: the Quickshell bar across the top, niri columns below.">' if shot.exists() else ''}
</div></header>
<nav class="toc" aria-label="Sections"><div class="wrap">
<a href="#deploy">deploy</a><a href="#layout">where it goes</a><a href="#theming">theming</a><a href="#keybinds">keybinds</a><a href="#privacy">privacy</a><a href="#nixos">nixos</a><a href="#files">files</a><a href="#outside">outside the repo</a>
</div></nav>
<main class="wrap">
""")

# Deploy
w('<section id="deploy"><h2>Deploy</h2><p class="note">One command, <code>rice</code>, in <code>local/bin</code>. It is on PATH once linked; on a fresh machine run it from the clone.</p><div class="grid3">')
for title, when, cmds, note in commands:
    block = "\n".join(cmds)
    w(f'<div class="card"><h3>{esc(title)}</h3><div class="when">{esc(when)}</div>'
      f'<div class="cmd"><button type="button" data-copy="{esc(block)}">copy</button>{esc(block)}</div><p>{esc(note)}</p></div>')
w("</div></section>")

# Layout
w('<section id="layout"><h2>Where it all goes</h2><p class="note">Four ways a file reaches a machine. Symlinks make the repo the live config, so nothing needs re-applying after an edit.</p><div class="scroll"><table><thead><tr><th>In the repo</th><th>Lands at</th><th>How</th><th></th></tr></thead><tbody>')
for src, dst, how, note in map_rows:
    w(f'<tr><td class="p">{esc(src)}</td><td class="p">{esc(dst)}</td><td>{chip(how, HOW_LABEL.get(how, "generated"))}</td><td>{esc(note)}</td></tr>')
w("</tbody></table></div></section>")

# Theming
w('<section id="theming"><h2>One accent, everywhere</h2><p class="note">Pick an accent in the dashboard\'s Appearance tab and each of these follows live. This page uses the same palette, read from <code>Theme.qml</code>.</p><div class="fan">')
w(f'<div class="src"><div><i></i>Settings.accent<br><span style="color:var(--muted);font-weight:400">{esc(flavour)} · {esc(accent)}</span></div></div><ul>')
for t, how in targets:
    w(f"<li><b>{esc(t)}</b> — {md_inline(how)}</li>")
w("</ul></div></section>")

# Keybinds
w(f'<section id="keybinds"><h2>Keybinds</h2><p class="note">Read from <code>config/niri/config.kdl</code>. Mod is Super. Entries in the accent colour were added from the dashboard\'s keybind editor.</p><div class="binds">')
for cat in BIND_ORDER:
    rows = [b for b in binds if b["cat"] == cat]
    if not rows:
        continue
    w(f'<div class="grp"><h3>{esc(cat)} <small style="color:var(--muted);font-weight:400">{len(rows)}</small></h3>')
    for b in rows:
        w(f'<div class="bind" title="{esc(b["raw"])}"><span class="keys">{"".join(f"<kbd>{esc(k)}</kbd>" for k in b["keys"])}</span><span class="{"mine" if b["custom"] else ""}">{esc(b["label"])}</span></div>')
    w("</div>")
w("</div></section>")

# Privacy
w('<section id="privacy"><h2>Privacy</h2><p class="note">On by default on every machine the flake builds. <code>rice status</code> checks the runtime half: VPN connected, auto-connect, lockdown mode, DNS, Tor, auto-lock. Remote desktop is a separate flake, not part of the rice.</p><div class="scroll"><table><tbody>')
for k, v in privacy:
    w(f'<tr><td class="p">{esc(k)}</td><td>{md_inline(v)}</td></tr>')
w("</tbody></table></div></section>")

# NixOS
w(f'<section id="nixos"><h2>NixOS</h2><p class="note">A flake with one pinned nixpkgs ({esc(nixref)} @ <code>{esc(nixrev)}</code>). <code>common.nix</code> is the desktop and is the same everywhere; <code>hosts/&lt;name&gt;/</code> holds what belongs to one machine; the disk layout stays in that machine\'s <code>/etc/nixos</code>. ★ marks packages built from <code>nixos/pkgs/</code>.</p>')
w('<h3>common.nix</h3><div class="mods">')
for title, d in sections_common:
    w(f'<div class="mod"><b>{esc(title)}</b><span>{esc(d)}</span></div>')
w("</div>")
for h, secs in sections_hosts.items():
    w(f'<h3>hosts/{esc(h)}</h3><div class="mods">')
    for title, d in secs:
        w(f'<div class="mod"><b>{esc(title)}</b><span>{esc(d)}</span></div>')
    w("</div>")
w(f'<h3>Packages <small style="color:var(--muted);font-weight:400">{n_pkgs}</small></h3><div class="pk">')
for g, ps in pkg_groups:
    w(f'<div><h3>{esc(g)}<small>{len(ps)}</small></h3><p>{esc("  ".join(ps))}</p></div>')
w("</div></section>")

# Files
w(f'<section id="files"><h2>Every file</h2><p class="note">All {len(entries)} files in the repo, with each one\'s own header comment as its description. Pick one to read it.</p>')
w('<div class="legend">' + "".join(chip(k, v) for k, v in HOW_LABEL.items()) + "</div>")
w('<div class="browser"><div class="list"><div class="bar"><label for="q" class="count" style="position:absolute;left:-9999px">Filter files</label>'
  '<input id="q" type="search" placeholder="filter: path or description" autocomplete="off"><span class="count" id="count"></span></div>'
  '<div class="items" id="items"></div></div><div class="view" id="view"></div></div></section>')

# Outside
w('<section id="outside"><h2>Outside the repo</h2><p class="note">What this machine has that a clone would not, from a scan of <code>~/.config</code> when the page was generated. Generated and app-state entries are fine to leave; leftovers are candidates for deletion.</p><div class="scroll"><table><thead><tr><th>Path</th><th>Kind</th><th>Size</th><th>Notes</th></tr></thead><tbody>')
for o in extra_outside + [dict(o, name="~/.config/" + o["name"]) for o in outside]:
    w(f'<tr><td class="p">{esc(o["name"])}</td><td>{chip(o["kind"], KIND_LABEL[o["kind"]])}</td><td class="p">{esc(o["size"])}</td><td>{esc(o["note"])}</td></tr>')
w("</tbody></table></div></section>")

w(f"""</main>
<footer class="wrap">Generated by tools/ricemap.py — rerun with <code>rice map</code>.</footer>
<script type="application/json" id="data">{data_json}</script>
<script>
(() => {{
  const files = JSON.parse(document.getElementById("data").textContent);
  const HOW = {json.dumps(HOW_LABEL)};
  const items = document.getElementById("items");
  const view = document.getElementById("view");
  const q = document.getElementById("q");
  const count = document.getElementById("count");
  const el = (tag, cls, text) => {{ const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }};
  let current = null;
  const buttons = new Map();

  function show(f) {{
    current = f.path;
    for (const [p, b] of buttons) b.setAttribute("aria-current", p === f.path ? "true" : "false");
    view.replaceChildren();
    const hd = el("div", "hd");
    hd.append(el("div", "path", f.path));
    const row = el("div", "row");
    const c = el("span", "chip c-" + f.how, HOW[f.how] || f.how);
    row.append(c, el("span", "", "→ " + f.dest));
    if (f.lines) row.append(el("span", "", f.lines.toLocaleString() + " lines"));
    if (f.exec) row.append(el("span", "", "executable"));
    hd.append(row);
    if (f.desc) hd.append(el("p", "", f.desc));
    view.append(hd);
    if (f.body == null) {{
      view.append(el("div", "empty", f.lines ? "Not embedded: generated or not worth reading here. It is in the repo." : "Binary file."));
    }} else {{
      const pre = el("pre", "mono");
      const lines = f.body.replace(/\\n$/, "").split("\\n");
      const frag = document.createDocumentFragment();
      for (const l of lines) frag.append(el("span", "", l || " "));
      pre.append(frag);
      view.append(pre);
    }}
  }}

  function render() {{
    const term = q.value.trim().toLowerCase();
    items.replaceChildren();
    buttons.clear();
    let shown = 0, lastG = null, lastS = null;
    const groups = {{}};
    for (const f of files) (groups[f.group] ||= []).push(f);
    for (const f of files) {{
      if (term && !(f.path.toLowerCase().includes(term) || (f.desc || "").toLowerCase().includes(term))) continue;
      if (f.group !== lastG) {{
        const g = el("div", "g", f.group);
        g.append(el("small", "", groups[f.group].length));
        items.append(g); lastG = f.group; lastS = null;
      }}
      if (f.sub && f.sub !== lastS) {{ items.append(el("div", "s", f.sub)); lastS = f.sub; }}
      const b = el("button");
      b.type = "button";
      const n = el("span", "n");
      n.append(el("span", "", f.path.split("/").pop()), el("em", "", f.lines ? f.lines : ""));
      b.append(n);
      b.append(el("span", "d", f.desc || f.path));
      b.title = f.path;
      b.addEventListener("click", () => show(f));
      buttons.set(f.path, b);
      items.append(b);
      shown++;
    }}
    count.textContent = shown + " / " + files.length;
    if (current && buttons.has(current)) buttons.get(current).setAttribute("aria-current", "true");
  }}

  q.addEventListener("input", render);
  render();
  show(files.find(f => f.path === "local/bin/rice") || files[0]);

  document.querySelectorAll("[data-copy]").forEach(b => b.addEventListener("click", async () => {{
    try {{ await navigator.clipboard.writeText(b.dataset.copy); b.textContent = "copied"; }}
    catch {{ b.textContent = "select + copy"; }}
    setTimeout(() => b.textContent = "copy", 1500);
  }}));
}})();
</script>
</body>
</html>
""")

(OUT / "index.html").write_text("".join(parts))
