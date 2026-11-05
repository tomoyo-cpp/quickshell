# The desktop itself: everything that should be identical on every machine
# this rice is deployed to. Anything tied to one machine's hardware — its
# GPU, disk, swap size, hostname, stateVersion — belongs in hosts/<name>/,
# and the disk layout in that machine's hardware-configuration.nix.
{ lib, pkgs, ... }:

let
  # Both browsers. KeePassXC is the password manager: its browser extension
  # installs itself on the first start, and the browser stops offering to
  # save logins of its own. Logins saved before stay where they are, so they
  # can still be exported (about:logins) and imported into KeePassXC
  # (Database > Import > CSV).
  browserPolicies = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    OfferToSaveLogins = false;
    # Zen is the default, set system-wide below. Without this each browser
    # asks on start, and Zen's "make default" writes its own launcher into
    # ~/.local/share/applications that points at one store path and breaks
    # after the next update.
    DontCheckDefaultBrowser = true;
    # Installed once, then an ordinary extension: it can be removed, moved
    # and pinned like any other, and is not put back on the next start.
    # (ExtensionSettings' "normal_installed" would lock it in place: no
    # remove button.) Runs again only if this list changes.
    Extensions.Install = [
      "https://addons.mozilla.org/firefox/downloads/latest/keepassxc-browser/latest.xpi"
    ];
    # Bitwarden, from before KeePassXC. Also runs once.
    Extensions.Uninstall = [ "{446900e4-71c2-419f-a6a7-df9c091e268b}" ];
  };

  # Zen hides the extensions (puzzle) button by default, and with it the
  # only "Pin to toolbar" entry. Shipped as a default, so it can still be
  # changed in about:config.
  zenPrefs = {
    "zen.theme.hide-unified-extensions-button" = false;
  };
in
{
  # ── Bootloader ──────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking ──────────────────────────────────────────────────────────
  networking.networkmanager = {
    enable = true;
    # A different MAC on every network, kept stable on each one: unlinkable
    # between networks, without a home router or portal seeing a new device
    # at every reconnect. Scans are randomised by default already.
    wifi.macAddress = "stable";
    ethernet.macAddress = "stable";
    # DNS comes from resolved below, never from DHCP — the network's resolver
    # (usually the ISP's) does not get to see or rewrite lookups.
    dns = lib.mkForce "none";
    settings.connection = {
      # Do not announce the hostname to every DHCP server.
      "ipv4.dhcp-send-hostname" = false;
      "ipv6.dhcp-send-hostname" = false;
      # Temporary IPv6 addresses, preferred, so the address is not a
      # long-lived identifier derived from the hardware.
      "ipv6.ip6-privacy" = 2;
    };
  };

  # Encrypted DNS when the VPN is off. Mullvad's public resolver with its ad,
  # tracker and malware blocklists, over DNS-over-TLS; Quad9 as fallback.
  # "opportunistic" rather than strict: inside the Mullvad tunnel the daemon
  # points resolved at its own in-tunnel resolver, which does not speak TLS,
  # and strict mode would break DNS exactly while the VPN is up. Captive
  # portals: connect the VPN after logging in, or `resolvectl dns <iface>
  # <portal-ip>` for the one session.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [
        "194.242.2.4#base.dns.mullvad.net"
        "2a07:e340::4#base.dns.mullvad.net"
      ];
      FallbackDNS = [
        "9.9.9.9#dns.quad9.net"
        "2620:fe::fe#dns.quad9.net"
      ];
      DNSOverTLS = "opportunistic";
      Domains = [ "~." ];
    };
  };

  # Nothing listens to the network. Explicit, because it is the default and a
  # default can change.
  networking.firewall.enable = true;

  # ── Locale / Time ───────────────────────────────────────────────────────
  time.timeZone = "EET";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── NixOS Build Auto-Delete ─────────────────────────────────────────────
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ── Nix settings ────────────────────────────────────────────────────────
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  # ── Wayland / Niri ──────────────────────────────────────────────────────
  programs.niri.enable = true;

  # XDG portals (needed for screen sharing, file pickers, etc.)
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # ── Audio (Pipewire) ────────────────────────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ── Equalizer ────────────────────────────────────────────────────────────
  # A virtual sink that runs audio through ten peaking biquads before handing
  # it to the real output. Each band exposes a control port, so the bar's EQ
  # panel can set gains at runtime with pw-cli.
  #
  # Not made the default sink here — switching that is done at runtime, so a
  # bad curve never leaves the machine silent after a reboot.
  services.pipewire.extraConfig.pipewire."99-equalizer" = {
    "context.modules" = [
      {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = "Equalized Output";
          "media.name" = "Equalized Output";
          "filter.graph" = {
            nodes = builtins.genList (
              i:
              let
                freqs = [
                  31
                  63
                  125
                  250
                  500
                  1000
                  2000
                  4000
                  8000
                  16000
                ];
                f = builtins.elemAt freqs i;
              in
              {
                type = "builtin";
                name = "eq_band_${toString (i + 1)}";
                label = "bq_peaking";
                control = {
                  "Freq" = f;
                  "Q" = 1.2;
                  "Gain" = 0.0;
                };
              }
            ) 10;
            links = builtins.genList (i: {
              output = "eq_band_${toString (i + 1)}:Out";
              input = "eq_band_${toString (i + 2)}:In";
            }) 9;
          };
          "audio.channels" = 2;
          "audio.position" = [
            "FL"
            "FR"
          ];
          "capture.props" = {
            "node.name" = "effect_input.eq10";
            "media.class" = "Audio/Sink";
          };
          "playback.props" = {
            "node.name" = "effect_output.eq10";
            "node.passive" = true;
          };
        };
      }
    ];
  };

  # ── Bluetooth ───────────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ── Power (battery + profile switching for the quickshell bar) ──────────
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  # ── Login: ly ─────────────────────────────────────────────────────────
  # A plain white-on-black login box on tty1. The lock screen
  # (quickshell/components/LockView.qml) draws the same box, so logging in
  # and unlocking look like one screen — unlocking just returns to the
  # session as it was.
  services.displayManager.ly = {
    enable = true;
    x11Support = false; # niri is Wayland; X11 apps get xwayland-satellite
    settings = {
      animation = "none";
      clock = "%a %d %b  %l:%M %p"; # top right, as on the lock screen
      asterisk = "*";
      clear_password = true;
      allow_empty_password = false;
      hide_version_string = true;
    };
  };

  # ── Lid ─────────────────────────────────────────────────────────────────
  # Closing the lid suspends, on battery or on power; docked, it does nothing.
  # swayidle's before-sleep hook locks first and holds the suspend until the
  # lock screen is up, so opening the lid shows the lock, never the desktop.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  # ── User ────────────────────────────────────────────────────────────────
  users.users.tomoyo = {
    isNormalUser = true;
    description = "Tomoyo Sakagami";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "audio"
      "input"
    ];
    shell = pkgs.fish;
  };
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # add common libs here if the binary needs more than the defaults, e.g.:
    # stdenv.cc.cc.lib
    # zlib
    # openssl
  ];
  # ~/.local/bin on PATH, for the spotify-sync / spotify-theme helpers.
  environment.localBinInPath = true;

  # ── Steam ───────────────────────────────────────────────────────────────
  # The module rather than the bare package: it turns on 32-bit graphics
  # (hardware.graphics.enable32Bit) and the controller udev rules
  # (hardware.steam-hardware), neither of which the package alone provides,
  # and both of which Steam is broken without.
  programs.steam.enable = true;

  # ── System packages ─────────────────────────────────────────────────────
  # Only what the rice uses or is used daily. Anything occasional is one
  # command away instead, from the same pinned nixpkgs:
  #     nix shell nixpkgs#cbonsai        nix run nixpkgs#blender
  environment.systemPackages =
    with pkgs;
    [
      # ── CLI ─────────────────────────────────────────────────────────────
      git
      curl
      ripgrep
      fd
      bat
      eza
      fzf
      zoxide
      jq
      unzip
      python3 # the shell's helper scripts
      nodejs
      btop
      yazi
      fastfetch

      # ── Editor ──────────────────────────────────────────────────────────
      neovim
      vscode
      gcc # nvim-treesitter compiles its parsers
      tree-sitter
      # Language servers. Mason fetches dynamically linked binaries, which
      # cannot run here, so they come from nixpkgs.
      qt6.qtdeclarative # qmlls, qmlformat, qmllint
      nil
      lua-language-server
      bash-language-server
      basedpyright
      vscode-langservers-extracted
      # Formatters and linters, called by conform.nvim
      stylua
      nixfmt
      shfmt
      ruff
      shellcheck

      # ── Desktop ─────────────────────────────────────────────────────────
      quickshell
      kitty
      starship
      # niri has no built-in X server: xwayland-satellite provides one on
      # demand (and needs Xwayland itself), which X11-only programs —
      # Minecraft 1.8.9's LWJGL 2 among them — cannot start without.
      xwayland
      xwayland-satellite
      wl-clipboard
      cliphist
      xdg-utils
      libnotify
      glib # gsettings, which GtkTheme.qml and set-cursor.sh call
      wlsunset # night light
      imagemagick # wallpaper thumbnails
      grim # screenshots
      slurp
      satty
      wl-screenrec # recording on the GPU via VA-API
      hyprpicker # colour picker
      brightnessctl
      playerctl
      cava # the bar's visualiser
      xcur2png # cursor previews in the Appearance tab
      # Cursor themes. The Appearance tab scans the icon directories, so a
      # package here is all it takes for a theme to appear in the grid.
      catppuccin-cursors
      bibata-cursors
      phinger-cursors
      capitaine-cursors
      nordzy-cursor-theme
      rose-pine-cursor
      simp1e-cursors
      volantes-cursors
      graphite-cursors
      vimix-cursors
      adwaita-icon-theme
      papirus-icon-theme

      # ── Privacy ─────────────────────────────────────────────────────────
      mullvad-vpn # CLI for the daemon below; the bar's VPN tab drives it
      # Passwords: one encrypted .kdbx file, kept in ~/Vault and synced by
      # Syncthing (below). KeePassXC fills browsers through its extension
      # (Auto-Type does not work on Wayland; copy instead).
      keepassxc
      tor-browser
      # Zen is not in nixpkgs; pkgs/zen-browser.nix pins the upstream release
      # and patches it for the store.
      (pkgs.callPackage ./pkgs/zen-browser.nix {
        policies = browserPolicies;
        prefs = zenPrefs;
      })
      (librewolf.override { extraPolicies = browserPolicies; })

      # ── Apps ────────────────────────────────────────────────────────────
      thunar
      mpv
      imv
      gimp
      # spicetify has to rewrite Apps/xpui.spa inside the Spotify install,
      # a read-only store path — so spotify-sync builds a writable copy and
      # patches that instead.
      spotify
      spicetify-cli
      claude-code
      prismlauncher
      temurin-jre-bin-8
    ]
    # One build per flavour, so the Appearance tab can switch GTK apps to
    # match. Accent fixed at mauve: flavour x accent would be 64 builds.
    ++
      map
        (
          v:
          pkgs.catppuccin-gtk.override {
            accents = [ "mauve" ];
            variant = v;
            size = "standard";
          }
        )
        [
          "mocha"
          "macchiato"
          "frappe"
          "latte"
        ];

  # Trash, mounts and remote locations in Thunar. The gvfs package alone
  # ships the binaries but not the running daemon.
  services.gvfs.enable = true;

  # ── Privacy ─────────────────────────────────────────────────────────────
  # Mullvad: WireGuard VPN, no account details beyond a number. For it to be
  # the only way out, once per machine:
  #     mullvad auto-connect set on
  #     mullvad lockdown-mode set on      # block everything outside the tunnel
  # `rice status` checks both.
  services.mullvad-vpn.enable = true;

  # Tor client: SOCKS on 127.0.0.1:9050 for `torsocks <command>`, e.g.
  # `torsocks curl …` or `torsocks git clone …`. Tor Browser brings its own
  # tor and does not need this.
  services.tor = {
    enable = true;
    client.enable = true;
    torsocks.enable = true;
  };

  # Opt out of the telemetry that honours the convention.
  # Syncthing: keeps ~/Vault (the KeePassXC database) the same on every
  # device, directly between them over TLS — no cloud copy. Its web page is
  # http://127.0.0.1:8384, reachable from this machine only. Paired devices
  # and shared folders are made there and kept in its own state, not here:
  # device IDs are per person, and declaring a folder would reset its
  # sharing on every rebuild. The ports are for finding and reaching devices
  # on the same network; elsewhere it goes through discovery and relays.
  services.syncthing = {
    enable = true;
    user = "tomoyo";
    group = "users";
    dataDir = "/home/tomoyo";
    configDir = "/home/tomoyo/.local/state/syncthing";
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = false;
    settings.options.urAccepted = -1; # no usage reports
  };

  environment.sessionVariables = {
    DO_NOT_TRACK = "1";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    # For programs that read $BROWSER instead of the MIME defaults below,
    # whether started from a terminal or from niri.
    BROWSER = "zen";
  };

  # ── Default applications ────────────────────────────────────────────────
  # System-wide, so no application can rewrite them into the repo. A user's
  # own ~/.config/mimeapps.list still wins over these.
  xdg.mime.defaultApplications = {
    "text/html" = "zen-browser.desktop";
    "application/xhtml+xml" = "zen-browser.desktop";
    "x-scheme-handler/http" = "zen-browser.desktop";
    "x-scheme-handler/https" = "zen-browser.desktop";
    "x-scheme-handler/about" = "zen-browser.desktop";
    "x-scheme-handler/unknown" = "zen-browser.desktop";
    "application/pdf" = "zen-browser.desktop";
    "inode/directory" = "thunar.desktop";
    "image/png" = "imv.desktop";
    "image/jpeg" = "imv.desktop";
    "image/webp" = "imv.desktop";
    "image/gif" = "imv.desktop";
    "video/mp4" = "mpv.desktop";
    "video/webm" = "mpv.desktop";
    "video/x-matroska" = "mpv.desktop";
    "audio/mpeg" = "mpv.desktop";
    "audio/flac" = "mpv.desktop";
  };

  # ── Fonts ────────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
      font-awesome # SysMonWidget's icons
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
    };
  };

  # ── Polkit ───────────────────────────────────────────────────────────────
  security.polkit.enable = true;
  systemd.user.services.polkit-gnome-authentication-agent = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  # ── Quickshell bar ───────────────────────────────────────────────────────
  # Run as a user unit rather than niri's spawn-at-startup so it restarts by
  # itself if it ever dies, and so its output lands in the journal.
  systemd.user.services.quickshell = {
    description = "Quickshell desktop shell";
    wantedBy = [ "niri.service" ];
    after = [ "niri.service" ];
    partOf = [ "niri.service" ];

    # A user unit does not inherit the login shell's PATH, so the shell would
    # fail to spawn niri, brightnessctl, cliphist, grim and friends.
    path = [ "/run/current-system/sw" ];
    # WebP (and TIFF, TGA, …) for Qt, which ships only PNG, JPEG and GIF: the
    # wallpapers are drawn by the shell, and some are WebP.
    environment.QT_PLUGIN_PATH = "${pkgs.qt6.qtimageformats}/lib/qt-6/plugins";

    serviceConfig = {
      Type = "simple";
      # Pull in the graphical session's environment first — without
      # XDG_DATA_DIRS the shell finds no .desktop files or icon themes, so
      # every workspace app falls back to a lettered chip.
      ExecStart = "${pkgs.bash}/bin/bash -lc 'exec ${pkgs.quickshell}/bin/qs'";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "session.slice";
    };
  };

  # ── Auto-lock ───────────────────────────────────────────────────────────
  # Lock after 10 minutes idle, before every suspend (lid close included) and
  # on `loginctl lock-session`; screens off after 15. Idle never suspends,
  # so a long download survives a walk away from the desk. Anything playing video holds an idle inhibitor, so a film does not
  # lock. lock.sh puts up the shell's lock screen (surfaces/Lock.qml), which
  # checks the password against the `login` PAM service.
  systemd.user.services.swayidle = {
    description = "Lock the screen when idle";
    wantedBy = [ "niri.service" ];
    after = [ "niri.service" ];
    partOf = [ "niri.service" ];
    path = [ "/run/current-system/sw" ];
    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.swayidle}/bin/swayidle -w"
        "timeout 600 '%h/.config/quickshell/scripts/lock.sh'"
        "timeout 900 'niri msg action power-off-monitors'"
        "before-sleep '%h/.config/quickshell/scripts/lock.sh'"
        "lock '%h/.config/quickshell/scripts/lock.sh'"
      ];
      Restart = "on-failure";
      Slice = "session.slice";
    };
  };

  # ── Shell ────────────────────────────────────────────────────────────────
  programs.fish.enable = true;
}
