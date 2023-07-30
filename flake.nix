{
  description = "my project description";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    dream2nix.url = "github:nix-community/dream2nix";
    dream2nix.inputs.nixpkgs.follows = "nixpkgs";
    # separate flake
    # Setup vm disks
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # Manage secrets
    #    sops-nix.url = "github:Mic92/sops-nix";
    #    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    # optionally choose not to download darwin deps (saves some resources on Linux)
    agenix.inputs.darwin.follows = "";
  };

  outputs = { self, nixpkgs, dream2nix, disko, agenix }@attrs:
    let
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      lib = nixpkgs.lib // builtins;

      systems = [ "x86_64-linux" ];
      system = "x86_64-linux";
      forAllSystems = f:
        lib.genAttrs systems
        (system: f system (nixpkgs.legacyPackages.${system}));
    in {
      packages."x86_64-linux".rustnixos =
        pkgs.callPackage ./nix/rustnixos.package.nix { };
      packages."x86_64-linux".migration-data =
        pkgs.callPackage ./nix/migration-data.package.nix { };

      nixosModules.rustnixos = import ./module.nix;
      nixosModules.default = import ./module.nix;
      nixosModules.caddy = import ./nix/caddy.module.nix;
      nixosModules.db-dev = import ./nix/postgresql-dev.nix;

      # Run database+migration only in container for dev
      nixosConfigurations.db-dev = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = attrs // {
          inherit (self.packages.${system}) migration-data;
          inherit system;
        };

        modules = [
          self.nixosModules.db-dev
          ({ pkgs, config, ... }: {
            boot.isContainer = true;
            system.stateVersion = "23.11";
            # firewall seem to be enabled by default
            networking.firewall.enable = false;
          })
        ];
      };

      # Run whole setup in container
      nixosConfigurations.all = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = attrs // {
          inherit (self.packages.${system}) migration-data;
          inherit system;
        };
        modules = [
          self.nixosModules.rustnixos
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
        inherit system;
        specialArgs = attrs // {
          inherit (self.packages.${system}) migration-data;
          inherit system;
        };
        modules = [
          ({ modulesPath, ... }: {
            imports = [
              (modulesPath + "/installer/scan/not-detected.nix")
              (modulesPath + "/profiles/qemu-guest.nix")
              disko.nixosModules.disko
              agenix.nixosModules.default
              self.nixosModules.rustnixos
              self.nixosModules.caddy
            ];
            disko.devices =
              import ./nix/disk-config.disko.nix { lib = nixpkgs.lib; };
            age.secrets.secret1.file = ./secrets/secret1.age;
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
            users.users.root.openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJV/MZW0GP6guibA1rNwPwK6Q0WGg1of6MQRMpeqiUR8 mahene"
            ];
          })
        ];
      };
    };
  #     // dream2nix.lib.makeFlakeOutputs {
  #      inherit systems;
  #      config.projectRoot = ./.;
  #      source =
  #        lib.sourceFilesBySuffices ./. [ ".rs" "Cargo.toml" "Cargo.lock" ];
  #      projects."rust-nixos" = {
  #        name = "2rust-nixos";
  #        translator = "cargo-lock";
  #      };
  #    };
}
