# wl-uinput-proxy — https://github.com/pgaskin/wl-uinput-proxy
#
# Not in nixpkgs, so it is pinned and built here rather than fetched by a
# script at runtime: the version is fixed by commit, the hashes are checked,
# and a rebuild reproduces exactly this binary.
#
# Why it is needed: niri does not run keybindings on zwp_virtual_keyboard
# input. Keys injected by wayvnc reach the focused application but never fire
# Mod+D and friends. This proxies the virtual keyboard and pointer protocols
# onto /dev/uinput, so the compositor sees ordinary kernel input events and
# treats them exactly like the laptop's own keyboard.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  libxkbcommon,
}:

rustPlatform.buildRustPackage rec {
  pname = "wl-uinput-proxy";
  version = "0.0.4";

  src = fetchFromGitHub {
    owner = "pgaskin";
    repo = "wl-uinput-proxy";
    rev = "c24cdf3bc9d0b3b20f6f3b913999d87c333e40af";
    hash = "sha256-coJrAYecrRE25Ao+/NFTwuE6yRLlYCbloJ5WJJq/GJk=";
  };

  cargoHash = "sha256-Gtxz99gotvz9LI0mt3L7VUF4W/l6LPs6bvtta4Fs8CY=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libxkbcommon ];

  meta = {
    description = "Wayland proxy implementing virtual keyboard/pointer via uinput";
    homepage = "https://github.com/pgaskin/wl-uinput-proxy";
    license = lib.licenses.mit;
    mainProgram = "wl-uinput-proxy";
    platforms = lib.platforms.linux;
  };
}
