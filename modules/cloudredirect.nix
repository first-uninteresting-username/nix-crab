{
  cloudredirect,
  cloudredirect-moon,
}: {
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.nix-crab.cloudredirect = {
    enable = lib.mkEnableOption "Enable CloudRedirect";

    moon.enable = lib.mkEnableOption ''
      the cloudredirect-moon hook instead of upstream CloudRedirect. The moon
      fork scans <Steam>/config/stplug-in/*.lua and luaappids.yaml, so it
      recognises games added by the LuaTools stack. Only enable for LuaTools;
      upstream CloudRedirect is the default.
    '';
  };

  config = let
    cfg = config.programs.nix-crab;

    # Stage the hook under the name the loader, the docs and
    # `cloud_redirect --cli` all expect, so a rename in the source input
    # cannot silently break LD_PRELOAD.
    hook =
      if cfg.cloudredirect.moon.enable
      then "${cloudredirect-moon}/cloud_redirect.so"
      else cloudredirect;

    hookStaged = pkgs.runCommand "cloud_redirect.so" {} ''
      mkdir -p "$out"
      cp ${hook} "$out/cloud_redirect.so"
    '';
  in
    lib.mkIf cfg.cloudredirect.enable {
      programs.nix-crab.slssteam.extraEnv.LD_PRELOAD = "${hookStaged}/cloud_redirect.so";
    };
}
