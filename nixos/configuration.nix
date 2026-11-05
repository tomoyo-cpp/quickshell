# Legacy entry point, for a plain `nixos-rebuild switch` without --flake.
#
# The real way in is the flake (`rice switch`), which pins nixpkgs in
# flake.lock. This file only exists so that /etc/nixos/configuration.nix,
# which is a symlink here on machines set up before the flake, still builds
# the same system. It uses whatever the root channel provides instead of the
# pinned nixpkgs, so the two can drift — prefer the flake.
{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./hosts/nixos
  ];
}
