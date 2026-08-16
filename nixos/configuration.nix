{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ── Bootloader ──────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking ──────────────────────────────────────────────────────────
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # ── Locale / Time ───────────────────────────────────────────────────────
  time.timeZone = "Europe/Tallinn";
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

  # ── Graphics / hardware video encode ────────────────────────────────────
  # Mesa ships VA-API drivers for AMD and Nouveau but not for Intel, so
  # without this there is no `i965_drv_video.so` and everything that could
  # offload H.264 falls back to software. On a two-core Broadwell that means
  # screen recording pegs the CPU.
  #
  # iHD, not the legacy i965: on this libva (1.23) the i965 driver fails to
  # initialise outright, while intel-media-driver 26.1.6 loads on this Gen8
  # part and reports H.264 Main/High with VAEntrypointEncSlice — hardware
  # encode, which is the whole point.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  # libva would otherwise probe and can pick the wrong backend.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # ── Audio (Pipewire) ────────────────────────────────────────────────────
  hardware.pulseaudio.enable = false;
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

  # ── Swap ────────────────────────────────────────────────────────────────
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024; # MiB — matches RAM, so hibernation stays possible
    }
  ];

  # Prefer reclaiming cache over swapping; on a laptop with an SSD this keeps
  # the desktop responsive while still leaving a safety net.
  boot.kernel.sysctl."vm.swappiness" = 10;

  # ── Bluetooth ───────────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ── Power (battery + profile switching for the quickshell bar) ──────────
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  # ── Login manager (greetd + tuigreet) ───────────────────────────────────
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
        user = "greeter";
      };
    };
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

  # ── System packages ─────────────────────────────────────────────────────
  environment.systemPackages =
    with pkgs;
    [
      # Core utils
      git
      curl
      wget
      ripgrep
      fd
      bat
      eza
      fzf
      zoxide
      jq
      unzip
      # Languages
      python3
      nodejs
      # Editors
      vim
      neovim
      vscode
      # ── Cursor themes ───────────────────────────────────────────────────
      # Offered in the bar's Appearance tab, which scans the icon directories
      # rather than carrying a hardcoded list — adding a package here is all it
      # takes for a theme to appear in the grid.
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
      xcur2png # renders the previews the grid shows

      # ── Neovim toolchain ────────────────────────────────────────────────
      gcc
      tree-sitter
      # Language servers
      qt6.qtdeclarative # qmlls — plus qmlformat and qmllint on PATH
      nil # Nix
      lua-language-server # Lua, incl. the Neovim config itself
      bash-language-server # Bash; picks up shellcheck automatically
      basedpyright # Python
      vscode-langservers-extracted # JSON, HTML, CSS
      # Formatters, called by conform.nvim
      stylua
      nixfmt-rfc-style
      shfmt
      ruff
      # Linters
      shellcheck
      # Wayland tooling
      wayland
      wayland-utils
      wl-clipboard
      cliphist
      xwayland
      xdg-utils
      # niri has no built-in X server. xwayland-satellite provides one on
      # demand, and niri spawns and manages it once the config.kdl block is
      # present. Without this, DISPLAY is unset and X11-only programs — which
      # includes Minecraft 1.8.9, since LWJGL 2 has no Wayland backend — cannot
      # start at all.
      xwayland-satellite
      # Niri ecosystem
      waybar
      fuzzel
      mako
      swaylock
      swayidle
      quickshell # QML desktop shell (custom Catppuccin bar)
      wlsunset # night light (dashboard toggle)
      # Terminal
      kitty
      # Visual
      fastfetch
      cbonsai
      cmatrix
      pipes-rs
      asciiquarium
      tty-clock
      peaclock
      nyancat
      sl # steam locomotive, for mistyping ls
      lolcat # rainbow pipe: `fastfetch | lolcat`
      figlet # ascii banners: `figlet hello | lolcat`
      chafa # images as terminal graphics
      cava
      # TUIs
      btop
      gping
      dust
      duf
      glow
      # Programs
      firefox
      librewolf
      spotify
      gimp
      claude-code
      # Spotify theming. spicetify has to rewrite Apps/xpui.spa inside the
      # Spotify install, which is a read-only store path — so ~/.local/bin/
      # spotify-sync builds a writable copy of the app and patches that instead.
      spicetify-cli
      prismlauncher
      temurin-jre-bin-8
      blender
      obs-studio
      wl-screenrec # wlr-screencopy -> VA-API, near-zero CPU vs OBS + x264
      libva-utils
      ffmpeg
      # VPN
      mullvad-vpn
      # File management
      yazi
      thunar
      gvfs
      # Media
      mpv
      imv
      # Screenshot
      grim
      slurp
      satty
      # Wallpaper
      awww
      imagemagick
      # GTK theming
      gtk3
      gtk4
      adwaita-icon-theme
      papirus-icon-theme
      # Fonts
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
      font-awesome
      # Misc
      brightnessctl
      playerctl
      pamixer
      networkmanagerapplet
      libnotify
      # Polkit
      polkit_gnome
      # Additional
      hyprpicker
      starship # prompt
      wlogout # power menu
      # One build per flavour, so the bar's Appearance tab can switch GTK apps
      # to match. A single catppuccin-gtk only ever ships one variant, which is
      # why the default install left gtk-3.0/settings.ini pointing at a theme
      # that was not present. Accent is fixed at mauve: flavour x accent would
      # be 64 builds.
    ]
    ++ (map
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
      ]
    )
    ++ [
      papirus-icon-theme
    ];

  services.mullvad-vpn.enable = true;

  # ── Fonts ────────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
      font-awesome
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

  # Quickshell owns org.freedesktop.Notifications. mako ships a D-Bus-activated
  # user unit, so simply not autostarting it is not enough — the first
  # notification would activate it and it would take the bus name.
  systemd.user.services.mako.enable = false;

  # ── Shell ────────────────────────────────────────────────────────────────
  programs.fish.enable = true;

  system.stateVersion = "24.11";
}
