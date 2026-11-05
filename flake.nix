{
  description = "NixOS · niri · a Quickshell desktop shell written from scratch";

  # One pinned nixpkgs for every machine. `rice update` moves it forward;
  # nothing else does, so two machines built from the same commit get the
  # same versions of everything.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      # Where a host's disk layout comes from.
      #
      # hosts/<name>/hardware-configuration.nix wins if it is committed. It is
      # not, for this laptop, on purpose: it is nothing but filesystem UUIDs,
      # a stable fingerprint of the hardware if published. So by default the
      # machine's own /etc/nixos/hardware-configuration.nix is read, which is
      # where nixos-generate-config puts it — and reading outside the repo is
      # why the build runs with --impure. `rice` passes it; plain
      # `nixos-rebuild --flake` needs it added by hand.
      hardwareFor =
        name:
        let
          committed = ./nixos/hosts/${name}/hardware-configuration.nix;
        in
        if builtins.pathExists committed then
          committed
        else if builtins ? currentSystem then
          /etc/nixos/hardware-configuration.nix
        else
          throw ''
            host '${name}': no hardware-configuration.nix.
            Either build with --impure (`rice switch` does) so the machine's own
            /etc/nixos/hardware-configuration.nix is read, or commit one at
            nixos/hosts/${name}/hardware-configuration.nix.
          '';

      host =
        name:
        nixpkgs.lib.nixosSystem {
          modules = [
            ./nixos/hosts/${name}
            (hardwareFor name)
          ];
        };
    in
    {
      # One configuration per directory in nixos/hosts/, named after it. The
      # name is the hostname: `nixos-rebuild --flake .` picks the entry
      # matching `uname -n`. A new machine is a new directory and nothing
      # else — `rice new-host <name>` makes one.
      nixosConfigurations = builtins.mapAttrs (name: _: host name) (
        nixpkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./nixos/hosts)
      );

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    };
}
