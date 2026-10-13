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
  libpulseaudio,
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

  # These are all dlopen'd at runtime rather than linked, so buildInputs does
  # not reach them — autoPatchelf only fixes libraries a binary actually
  # declares. They have to be on LD_LIBRARY_PATH or the lookup fails silently:
  #
  #   libpulse / libasound  cubeb's audio backends. Missing either means the
  #                         browser starts fine and plays nothing at all, with
  #                         no error — which is exactly how this was found.
  #   libpipewire           WebRTC screen sharing through the portal; without
  #                         it the share dialog offers no sources.
  #   libva                 VA-API video decode on the iGPU.
  # MOZ_LEGACY_PROFILES stops the browser tying its default profile to a hash
  # of the install path. On NixOS that path changes on every rebuild of this
  # derivation, so without it each rebuild looks like a brand-new install and
  # the browser silently starts on an empty profile — history, logins and
  # extensions apparently gone, while the real profile sits untouched beside
  # it. MOZ_ALLOW_DOWNGRADE stops the same thing happening in reverse if a
  # profile is ever opened by an older build.
  preFixup = ''
    gappsWrapperArgs+=(
      --set MOZ_LEGACY_PROFILES 1
      --set MOZ_ALLOW_DOWNGRADE 1
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
        libpulseaudio
        alsa-lib
        pipewire
        libva
      ]}"
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
