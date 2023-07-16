{
  description = "my project description";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    dream2nix.url = "github:nix-community/dream2nix";
    dream2nix.inputs.nixpkgs.follows = "nixpkgs";
    # separate flake
    # Setup vm disks
    disko.url = github:nix-community/disko;
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # Manage secrets
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, dream2nix, disko, sops-nix}@attrs:
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
      nixosModules.caddy = import ./nixos-modules/caddy.nix;

      # Test setup in container
      nixosConfigurations.mycontainer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = attrs // { inherit migrations; };
        modules = [
          self.nixosModules.default
          sops-nix.nixosModules.sops
          self.nixosModules.caddy
          ({ pkgs, config, ... }: {
            # Only allow this to boot as a container
            boot.isContainer = true;
            system.stateVersion = "23.11";
          })
        ];
      };
       #-----------------------------------------------------------
          # The following line names the configuration as hetzner-cloud
          # This name will be referenced when nixos-remote is run
          #-----------------------------------------------------------
          nixosConfigurations.hetzner-cloud = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = attrs // { inherit migrations; };
            modules = [
              ({modulesPath, ... }: {
                imports = [
                  (modulesPath + "/installer/scan/not-detected.nix")
                  (modulesPath + "/profiles/qemu-guest.nix")
                  disko.nixosModules.disko
                  sops-nix.nixosModules.sops
                  self.nixosModules.default
                  self.nixosModules.caddy
                ];
                disko.devices = import ./nixos-modules/disk-config.nix {
                  lib = nixpkgs.lib;
                };
                boot.loader.grub = {
                  devices = [ "/dev/sda" ];
                  efiSupport = true;
                  efiInstallAsRemovable = true;
                };
                services.openssh.enable = true;
                system.stateVersion = "23.11";
                #-------------------------------------------------------
                # Change the line below replacing <insert your key here>
                # with your own ssh public key
                #-------------------------------------------------------
                users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJV/MZW0GP6guibA1rNwPwK6Q0WGg1of6MQRMpeqiUR8 mahene" ];
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
