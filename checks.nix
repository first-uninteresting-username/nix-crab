{
  self,
  nixpkgs,
  home-manager,
}: let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  steamCheck = name: options: let
    configuration = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        self.nixosModules.default
        {
          nixpkgs.config.allowUnfree = true;
          system.stateVersion = "26.05";
          programs.nix-crab = options // {downgrade.enable = true;};
        }
      ];
    };
  in
    pkgs.linkFarm "nix-crab-${name}" [
      {
        name = "steam";
        path = configuration.config.programs.steam.package;
      }
      {
        name = "downgrade";
        path = configuration.config.programs.nix-crab.downgrade.package;
      }
    ];

  homeCheck = options:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        self.homeModules.default
        {
          home = {
            username = "ci";
            homeDirectory = "/home/ci";
            stateVersion = "26.05";
          };
          programs.nix-crab =
            {
              accela.enable = true;
              steamidra.enable = true;
            }
            // options;
        }
      ];
    }).activationPackage;
in {
  nixos-upstream = steamCheck "upstream" {
    slssteam.enable = true;
    cloudredirect.enable = true;
  };
  nixos-moon = steamCheck "moon" {
    slssteam-moon.enable = true;
    cloudredirect = {
      enable = true;
      moon.enable = true;
    };
  };
  nixos-millennium = steamCheck "millennium" {
    slssteam.enable = true;
    cloudredirect.enable = true;
    millennium.enable = true;
  };
  home-upstream = homeCheck {};
  home-luatools-wrapper = homeCheck {
    luatools.enable = true;
    cloudredirect.moon.enable = true;
  };
  home-luatools-service = homeCheck {
    luatools = {
      enable = true;
      lumenService = true;
    };
    cloudredirect.moon.enable = true;
  };
}
