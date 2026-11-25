{
  sls-steam,
  slsteam-moon,
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.nix-crab;

  upstream = sls-steam.packages.${pkgs.stdenv.hostPlatform.system}.sls-steam;

  # slsteam-moon is a fork of SLSsteam with a native Lua manifest importer.
  # It ships no flake, so it is built from source. Like upstream, it now
  # targets the 64-bit (steamrt64) Steam client: a single x86-64 SLSsteam.so
  # loaded through LD_AUDIT, with no separate library-inject.so.
  slsteamMoon = pkgs.stdenv.mkDerivation {
    pname = "slsteam-moon";
    version = "0.0.0";
    src = slsteam-moon;
    # embed-config.sh generates src/config_default.hpp during the build.
    postPatch = ''
      patchShebangs embed-config.sh
    '';
    nativeBuildInputs = with pkgs; [pkg-config];
    # LuaJIT headers come from the system; the static lib is vendored in lib/.
    buildInputs = with pkgs; [openssl curl luajit];
    # pattern-refresh is a pre-launch host helper we don't wire up; only the
    # Steam-loaded audit object is built.
    buildPhase = ''
      runHook preBuild
      make -j"$NIX_BUILD_CORES" bin/SLSsteam.so
      runHook postBuild
    '';
    # -O3 -flto over ~100 translation units; the Makefile only marks `clean`
    # and `rebuild` as .NOTPARALLEL, so the object targets take -j fine.
    enableParallelBuilding = true;
    installPhase = ''
      mkdir -p "$out"
      cp bin/SLSsteam.so "$out/"
    '';
    meta = {
      description = "SLSsteam fork with a Lua manifest importer (slsteam-moon)";
      homepage = "https://github.com/swwayps/slsteam-moon";
      license = lib.licenses.agpl3Only;
      platforms = lib.platforms.linux;
    };
  };

  # Both forks ship the same artefact under the same name, so the choice is
  # one store path, not two branches of wiring.
  slsRaw =
    if cfg.slssteam-moon.enable
    then slsteamMoon
    else upstream;

  # A RUNPATH onto the build's own glibc/libstdc++ makes the loader pull a
  # second libc into Steam's FHS processes, which already have one loaded;
  # the two disagree on the stack canary and processes die with "stack
  # smashing detected". Dropping it makes the loader reuse the loaded libc;
  # the other NEEDED libraries come from the FHS (extraPkgs below).
  sls = pkgs.runCommand "SLSsteam-audit" {
    nativeBuildInputs = [pkgs.patchelf];
  } ''
    mkdir -p "$out"
    cp ${slsRaw}/SLSsteam.so "$out/"
    chmod u+w "$out"/*.so
    patchelf --remove-rpath "$out/SLSsteam.so"
  '';
in {
  options.programs.nix-crab = {
    slssteam.enable = lib.mkEnableOption "SLSsteam (upstream) injection into Steam";

    slssteam.extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables injected into Steam";
    };

    slssteam-moon.enable = lib.mkEnableOption ''
      slsteam-moon (SLSsteam fork with a Lua manifest importer) instead of
      upstream SLSsteam. Takes precedence over slssteam.enable; required by
      the home module's luatools option.
    '';
  };

  config = lib.mkIf (cfg.slssteam.enable || cfg.slssteam-moon.enable) {
    programs.steam = {
      enable = true;
      package = pkgs.steam.override {
        extraEnv =
          {
            LD_AUDIT = "${sls}/SLSsteam.so";
          }
          // cfg.slssteam.extraEnv;
        # The FHS wrapper never binds /sys: bubblewrap starts with a fresh
        # mount namespace where /sys does not exist, and the auto-mount loop
        # cannot bind a mountpoint onto itself. Mesa then cannot resolve
        # /sys/dev/char/226:* or /sys/class/drm, reports "failed to retrieve
        # device information", refuses to load i915/iris and falls back to
        # llvmpipe. Steam's 32-bit vgui2 gets no GLX visual and fatal-asserts
        # with "glXChooseVisual failed". A read-only bind is all it needs.
        #
        extraBwrapArgs = ["--ro-bind /sys /sys"];
        # Upstream SLSsteam.so links libcurl and libdbus. With its RUNPATH
        # stripped they must be in the FHS /usr/lib, which pkgs.steam's
        # default package list does not cover. Both are 64-bit only, like
        # the steamrt64 client that loads the hook.
        extraPkgs = p: [p.curl p.dbus];
      };
    };
  };
}
