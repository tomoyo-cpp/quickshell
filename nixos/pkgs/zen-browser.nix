# Zen Browser — https://zen-browser.app
#
# Not in nixpkgs, so the upstream binary release is pinned and wrapped here:
# fixed version, checked hash, built by the same rebuild as everything else.
# Same approach as pkgs/wl-uinput-proxy.nix — declarative and reproducible,
# rather than a script that downloads something different next week.
#
# It is a Firefox fork shipped as a prebuilt tarball, so the work is patching
# the interpreter and RPATH onto binaries built for a normal FHS distro, which
# autoPatchelfHook does given the right libraries.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook3,
  makeDesktopItem,
  copyDesktopItems,
  alsa-lib,
  curl,
  dbus-glib,
  gtk3,
  libXtst,
  libva,
  pciutils,
  pipewire,
  xorg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "zen-browser";
  version = "1.22.2b";

  src = fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/download/${finalAttrs.version}/zen.linux-x86_64.tar.xz";
    hash = "sha256-Fjgjz1awaOgbuKSNk8nb2jmT9U8D+NN+aE44C/wRuJI=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    alsa-lib
    curl
    dbus-glib
    gtk3
    libXtst
    libva          # VA-API, so video decode can reach the iGPU
    pciutils
    stdenv.cc.cc.lib
    xorg.libXt
  ];

  # The updater and crash reporter are stripped of their libraries upstream;
  # neither is usable on NixOS anyway, since the store path is read-only.
  autoPatchelfIgnoreMissingDeps = [
    "libmozsandbox.so"
    "libxul.so"
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/opt/zen $out/bin
    cp -r ./* $out/opt/zen/
    ln -s $out/opt/zen/zen $out/bin/zen
    install -Dm644 $out/opt/zen/browser/chrome/icons/default/default128.png \
      $out/share/icons/hicolor/128x128/apps/zen.png || true
    runHook postInstall
  '';

  # PipeWire on the library path is what lets WebRTC screen sharing work
  # through the portal; without it the browser simply offers no sources.
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pipewire libva ]}"
    )
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "zen-browser";
      exec = "zen %U";
      icon = "zen";
      desktopName = "Zen Browser";
      genericName = "Web Browser";
      categories = [ "Network" "WebBrowser" ];
      mimeTypes = [ "text/html" "x-scheme-handler/http" "x-scheme-handler/https" ];
    })
  ];

  meta = {
    description = "Firefox-based browser with a focus on a calmer, customisable interface";
    homepage = "https://zen-browser.app";
    license = lib.licenses.mpl20;
    mainProgram = "zen";
    platforms = [ "x86_64-linux" ];
  };
})
