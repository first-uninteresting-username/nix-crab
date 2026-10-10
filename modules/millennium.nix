{millennium}: {
  config,
  lib,
  ...
}: {
  options.programs.nix-crab.millennium.enable = lib.mkEnableOption "Enable millennium";

  config = lib.mkIf config.programs.nix-crab.millennium.enable {
    # Not programs.steam.package: slssteam.nix defines that too, and two
    # definitions are an eval error. As an overlay Millennium becomes the base
    # that slssteam's steam.override extends -- its steam.nix merges
    # (extraEnv // millenniumEnv), so LD_AUDIT survives. Use the standalone
    # package set: the upstream overlay calls steam.nix with final.steam,
    # which would recurse once we replace steam with millennium-steam.
    nixpkgs.overlays = [
      (_final: prev: {
        steam = millennium.packages.${prev.stdenv.hostPlatform.system}.millennium-steam;
      })
    ];
  };
}
