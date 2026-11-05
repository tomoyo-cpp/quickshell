# Host: the Dell laptop (i5-5300U, Broadwell iGPU, 8 GiB).
#
# Only what is true of this one machine. The desktop is ../../common.nix; the
# disk layout is this machine's own hardware-configuration.nix, which the
# flake reads from /etc/nixos (see flake.nix for why it is not in the repo).
#
# A new machine is a copy of this directory with the hardware lines changed;
# the flake picks up every directory under hosts/ by itself.
{ pkgs, ... }:

{
  imports = [ ../../common.nix ];

  networking.hostName = "nixos";

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
  #
  # On an AMD or NVIDIA machine, drop both of these: Mesa covers AMD as is,
  # and a wrong LIBVA_DRIVER_NAME breaks VA-API rather than falling back.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
  # vainfo, which record.sh asks whether H.264 encode is available.
  environment.systemPackages = [ pkgs.libva-utils ];

  # ── Console ─────────────────────────────────────────────────────────────
  # The default 8x16 font is a postage stamp at 1080p; Terminus 24 gives ly
  # roughly the proportions the lock screen has.
  console.packages = [ pkgs.terminus_font ];
  console.font = "ter-v24n";
  console.earlySetup = true;
  services.displayManager.ly.settings.battery_id = "BAT0";

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

  # The release this machine was first installed with. Never bump it to
  # "upgrade" — it pins stateful defaults (database formats and the like), and
  # each machine keeps the value it was installed with.
  system.stateVersion = "24.11";
}
