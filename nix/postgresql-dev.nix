{ self, nixpkgs, migrations, config, lib, ... }:

with lib;

let
  system = "x86_64-linux";
  cfg = config.services.rustnixos;
  pkgs = nixpkgs.legacyPackages.${system};
in {

  options = {
    services.rustnixos = {
      # never change once deployed
      databaseName = mkOption {
              type = types.str;
              default = "rustnixos";
              description = ''database name, also a db user and Linux user.
              Internal since changing this value would lead to breakage while setting up databases'';
              internal = true;
              readOnly = true;
      };
    };
  };

  config = {
    services.postgresql = {
        enable = true;
        enableTCPIP = true;
        ensureDatabases = [ cfg.databaseName ];
#        # create a DB user/role (not a Linux user!) of the same name
#        ensureUsers = [
#          {
#            name = cfg.databaseName;
#            ensurePermissions = {
#              "DATABASE ${cfg.databaseName}" = "ALL PRIVILEGES";
##              "SCHEMA public" = "ALL PRIVILEGES,CREATE";
#            };
#        }];

        authentication = pkgs.lib.mkOverride 10 ''
          local all all trust
        '';
      };

    systemd.services = {

      db-migration = {
        description = "DB migrations script";
        wantedBy = [ "multi-user.target" ];
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];

        environment = {
          DATABASE_URL = "postgres:///${cfg.databaseName}?socket=/var/run/postgresql";
        };

        serviceConfig = {
          Type = "oneshot";
          # oneshot has implictly RemainAfterExit=no
          # which runs this service on every reboot.
          # which is what we want.
          ExecStart =
          # Don' use "dbmate .. up, because it will try to create a database as DB user postgres,
          # but we don't allow this services Linux user to connect as postgres superuser/admin for security.
            "${pkgs.dbmate}/bin/dbmate -d ${migrations} --no-dump-schema migrate";
        };
      };
    };
  };
}