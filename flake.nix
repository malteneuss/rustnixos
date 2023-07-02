{
  description = "my project description";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    dream2nix.url = "github:nix-community/dream2nix";
    dream2nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, dream2nix }@attrs:
    let
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      lib = nixpkgs.lib // builtins;

      systems = [ "x86_64-linux" ];
      forAllSystems = f:
        lib.genAttrs systems
        (system: f system (nixpkgs.legacyPackages.${system}));
      migrations = pkgs.runCommand "mkMigrations" { } ''
        mkdir $out
        cp -r ${./db/migrations}/*.sql $out
      '';
    in {
      packages."x86_64-linux".migrations = pkgs.runCommand "mkMigrations" { } ''
        mkdir $out
        cp -r ${./db/migrations}/*.sql $out
      '';
      nixosModules.default = import ./module.nix;

      # Test setup in container
      nixosConfigurations.mycontainer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = attrs // { inherit migrations; };
        modules = [
          self.nixosModules.default
          ({ pkgs, config, ... }: {
            # Only allow this to boot as a container
            boot.isContainer = true;
            networking.firewall.allowedTCPPorts = [ 80 443 ];
            services.rustnixos.enable = true;

            services = {
              caddy = {
                enable = true;
                acmeCA =
                  "https://acme-staging-v02.api.letsencrypt.org/directory";
                globalConfig = ''
                                          debug
                  #                         auto_https disable_certs
                                          skip_install_trust
                  #                         http_port 8080
                  #                         https_port 8090

                '';
                # Test with curl
                # curl --connect-to localhost:80:mycontainer:80 --connect-to localhost:443:mycontainer:443 http://localhost -k -L
                virtualHosts = {
                  "localhost".extraConfig = ''
                    #           respond "Hello, world34!"
                                reverse_proxy http://127.0.0.1:${toString config.services.rustnixos.port}
                  '';
                };
              };
            };
          })
        ];
      };
    } // dream2nix.lib.makeFlakeOutputs {
      inherit systems;
      config.projectRoot = ./.;
      source =
        lib.sourceFilesBySuffices ./. [ ".rs" "Cargo.toml" "Cargo.lock" ];
      projects."rust-nixos" = {
        name = "2rust-nixos";
        translator = "cargo-lock";
      };
    };
}
