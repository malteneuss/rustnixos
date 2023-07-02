{ self, nixpkgs, migrations, config, lib, ... }:

with lib;

let
  system = "x86_64-linux";
  webapp = self.packages.${system}.default;
  cfg = config.services.rustnixos;
  pkgs = nixpkgs.legacyPackages.${system};
in {

  options = {
    services.rustnixos = {
      enable = mkEnableOption "Rust Webservice on NixOS";

      user = mkOption {
        type = types.str;
        default = "rustnixos";
        description = "User account under which app runs.";
      };

      host = mkOption rec {
        type = types.str;
        default = "127.0.0.1";
        example = default;
        description = "The host/domain name";
      };

      # never change
#      database = mkDefault "";
      database = mkOption {
              type = types.str;
              default = "rustnixos";
              description = "database name";
      };

      port = mkOption {
        type = types.port;
        default = 3000;
        example = 8080;
        description = ''
          The port to bind app server to.
        '';
      };

    };
  };

  config = mkIf cfg.enable {
    system.stateVersion = "23.11";

    users.users.${cfg.user} = {
      name = cfg.user;
      group = "myapp";
      description = "My app service user";
      isSystemUser = true;
    };

    services = {
      postgresql = {

        enable = true;
        # only localhost and unix sockets
        enableTCPIP = false;
        ensureDatabases = [ cfg.database ];
        ensureUsers = [{
          name = cfg.user;
          ensurePermissions = {
            "DATABASE ${cfg.database}" = "ALL PRIVILEGES";
          };
        }];

        authentication = pkgs.lib.mkOverride 10 ''
          local sameuser all peer
          host sameuser all ::1/32 trust
        '';
      };
    };

    systemd.services = {

      db-migration = {
        description = "DB migrations script";
        wantedBy = [ "multi-user.target" ];
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];

        environment = {
          DATABASE_URL =
            "postgres://${cfg.user}@localhost:5432/${cfg.database}?sslmode=disable";
        };

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          ExecStart =
            "${pkgs.dbmate}/bin/dbmate -d ${migrations} --no-dump-schema up";
        };
      };

      rustnixos = {
        wantedBy = [ "multi-user.target" ];
        description = "Start my app server.";
        after = [ "network.target" ];
        requires = [ "db-migration.service" ];

        environment = {
          APP_PORT = toString cfg.port;
          DATABASE_URL = "postgres:///${cfg.user}";
        };

        serviceConfig = {
          ExecStart = "${webapp}/bin/rust-nixos";
          User = cfg.user;
          Type = "simple";
          Restart = "always";
          KillMode = "process";
        };
      };
    };
  };
}
