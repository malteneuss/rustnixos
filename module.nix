{ self, nixpkgs, migration-data, system, config, lib, ... }:

with lib;

let
  webapp = self.packages.${system}.rustnixos;
  cfg = config.services.rustnixos;
  pkgs = nixpkgs.legacyPackages.${system};
in {

  options = {
    services.rustnixos = {
      enable = mkEnableOption "Rust Webservice on NixOS";

      # never change once deployed
      databaseName = mkOption {
        type = types.str;
        default = "rustnixos";
        description = ''
          database name, also a db user and Linux user.
                        Internal since changing this value would lead to breakage while setting up databases'';
        internal = true;
        readOnly = true;
      };

      host = mkOption rec {
        type = types.str;
        default = "127.0.0.1";
        example = default;
        description = "The host/domain name";
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

    # create a Linux user that will run our migrations
    # and migrations, and that gets access to our (and only)
    # our apps database.
    users.users.${cfg.databaseName} = {
      name = cfg.databaseName;
      group = "rustnixos";
      description = "My app service user";
      isSystemUser = true;
    };
    users.groups.${cfg.databaseName} = { };
    services.postgresql = {
      enable = true;
      # only local unix sockets
      enableTCPIP = false;
      # v15 doesn't work yet in NixOS. See https://github.com/NixOS/nixpkgs/issues/216989.
      #        package = pkgs.postgresql_15;
      #        package = pkgs.postgresql_14;
      ensureDatabases = [ cfg.databaseName ];
      # create a DB user/role (not a Linux user!) of the same name
      ensureUsers = [{
        name = cfg.databaseName;
        ensurePermissions = {
          "DATABASE ${cfg.databaseName}" = "ALL PRIVILEGES";
          #              "SCHEMA public" = "ALL PRIVILEGES,CREATE";
        };
      }];

      authentication = pkgs.lib.mkOverride 10 ''
        local sameuser all peer
      '';
    };
    # backup all databases automatically
    services.postgresqlBackup = { enable = true; };

    systemd.services = {

      db-migration = {
        description = "DB migrations script";
        wantedBy = [ "multi-user.target" ];
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];

        environment = {
          DATABASE_URL =
            "postgres:///${cfg.databaseName}?socket=/var/run/postgresql";
        };

        serviceConfig = {
          User = cfg.databaseName;
          Type = "oneshot";
          # oneshot has implictly RemainAfterExit=no
          # which runs this service on every reboot.
          # which is what we want.
          ExecStart =
            # Don' use "dbmate .. up, because it will try to create a database as DB user postgres,
            # but we don't allow this services Linux user to connect as postgres superuser/admin for security.
            "${pkgs.dbmate}/bin/dbmate -d ${migration-data} --no-dump-schema migrate";
        };
      };

      rustnixos = {
        wantedBy = [ "multi-user.target" ];
        description = "Start my app server.";
        after = [ "network.target" ];
        requires = [ "db-migration.service" ];

        environment = {
          APP_PORT = toString cfg.port;
          DATABASE_URL = "postgres:///${cfg.databaseName}";
        };

        serviceConfig = {
          ExecStart = "${webapp}/bin/rust-nixos";
          User = cfg.databaseName;
          Type = "simple";
          Restart = "always";
          KillMode = "process";
        };
      };
    };
  };
}
