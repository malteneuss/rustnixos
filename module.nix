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

    # create a Linux user that will run our migrations
    # and migrations, and that gets access to our (and only)
    # our apps database.
    users.users.${cfg.user} = {
      name = cfg.user;
      group = "rustnixos";
      description = "My app service user";
      isSystemUser = true;
    };

    services = {
      postgresql = {
        enable = true;
        # only local unix sockets
        enableTCPIP = false;
        ensureDatabases = [ cfg.database ];
        # create a DB user/role (not a Linux user!)
        ensureUsers = [
          {
            name = cfg.user;
            ensurePermissions = {
              "DATABASE ${cfg.database}" = "ALL PRIVILEGES";
            };
        }];

          #local all postgres peer map=eroot
          # map=eroot
          # local sameuser all peer
          # host all all ::1/32 trust
          #local ${cfg.database} postgres peer map=${cfg.user}_map
          #local ${cfg.database} ${cfg.user} peer
        authentication = pkgs.lib.mkOverride 10 ''
          local sameuser all peer map=superuser_map
          #local postgres postgres peer map=superuser_map
          #local rustnixos rustnixos peer map=superuser_map
          #local ${cfg.database} ${cfg.user} peer
          #local rustnixos postgres peer map=superuser_map
          #local all postgres peer map=${cfg.database}_map
          #local ${cfg.database} ${cfg.user} peer map=superuser_map
          #host all all ::1/32 trust
        '';

        # map Linux user to DB user
        # we want to login as root Linux user into
        # postgres user, which is superuser/admin.
        # Quirk: We have to say as what DB user we
        # want to login when we are ssh-logged-in as "root" (Linux user)
        # "psql -U postgres" (choose standard DB superuser/admin "postgres")
        # DB will then check with this identMap if our Linux
        # user is allowed to login as such DB user.
        identMap = ''
          # ArbitraryMapName LinuxUser DBUser
          superuser_map      root      postgres
          superuser_map      postgres  postgres
          # Let other names login as themselves
          superuser_map      /^(.*)$   \1
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
#          DATABASE_URL = "postgres://${cfg.user}/${cfg.database}?socket=/var/run/postgresql";
          DATABASE_URL = "postgres://${cfg.user}/${cfg.database}?socket=/var/run/postgresql";
        };

        serviceConfig = {
          User = cfg.user;
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

      rustnixos = {
        wantedBy = [ "multi-user.target" ];
        description = "Start my app server.";
        after = [ "network.target" ];
        requires = [ "db-migration.service" ];

        environment = {
          APP_PORT = toString cfg.port;
#          DATABASE_URL = "postgres:///${cfg.user}";
          DATABASE_URL = "postgres://${cfg.user}/${cfg.database}";
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
