# (Rust) Web app on NixOS for self-hosting.
Package and deploy a (Rust) web app that needs a database
with Nix(OS).

- Packaging the Rust app is done with [nix-community/dream2nix](https://github.com/nix-community/dream2nix) framework
  to create a Nix package that is exposed as a modular [Nix flake](https://nixos.wiki/wiki/Flakes)
  so that servers can download and run this app wherever.
- The NixOS Server is setup to infect and run on a cheap [Hetzner Virtualmachine](https://www.hetzner.com/de/cloud)
  - See `flake.nix` and `nixos-modules` for configs.
  - The `nixosConfiguration` for the server is in `flake.nix` and called `hetzner-cloud`.
  - Run `nix run github:numtide/nixos-anywhere -- --flake .#hetzner-cloud root@<vm-ip>` to infect and replace
    the VM operating system with NixOS (careful: deletes everything on server!).
  - It formats the VM disks automatically using the Nix library [disko](https://github.com/nix-community/disko)
  - NixOS runs all apps (web app, database, migration app, reverse-proxy) as declarative systemd services, easy
    and concise to setup.
  - The configured database is [Postgresql](https://nixos.wiki/wiki/PostgreSQL).
    - NixOS makes really easy to setup without overhead and unrealibility of Docker containers.
    - Migrations are managed by [dbmate](https://github.com/amacneil/dbmate).
    - Systemd allows us to run migrations on every web app upgrade.
  - The configured reverse-proxy that secures the web app behind a smaller attack surface and
    enables automatic, browser-trusted web encryption is [Caddy](https://nixos.wiki/wiki/Caddy).