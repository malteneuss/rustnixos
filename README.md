# (Rust) Web app on NixOS for self-hosting.
Package and deploy a (Rust) web app that needs a database
with Nix(OS).

# Deployment
- The NixOS Server is setup to infect and run on a cheap [Hetzner Virtualmachine](https://www.hetzner.com/de/cloud)
- You have to create such a server with e.g. Ubuntu first to get a static IP address for it.
- Run `nix run github:numtide/nixos-anywhere -- --flake .#hetzner-cloud root@<vm-ip>` to infect and replace
  the VM operating system completely with NixOS (careful: deletes everything on server!).
  - It formats the VM disks automatically using the Nix library [disko](https://github.com/nix-community/disko)
  - The `nixosConfiguration` for the server is in `flake.nix` and called `hetzner-cloud`.
- Any subsequent redeploy must use `nixos-rebuild switch --flake .#hetzner-cloud --target-host root@<vm-ip>`!
  See `flake.nix` and `nixos-modules` for configs.

# Running software on NixOS

- NixOS runs all apps (web app, database, migration app, reverse-proxy) as declarative systemd services, easy
  and concise to setup.
- The configured database is [Postgresql](https://nixos.wiki/wiki/PostgreSQL).
  - NixOS makes really easy to setup DBs without overhead and unrealibility of Docker containers.
  - Migrations are managed by [dbmate](https://github.com/amacneil/dbmate).
  - Systemd allows us to run migrations on every web app upgrade.
- The configured reverse-proxy that secures the web app behind a smaller attack surface and
  enables automatic, browser-trusted web encryption is [Caddy](https://nixos.wiki/wiki/Caddy).
- Secrets are managed by [agenix](https://github.com/ryantm/agenix).
  - `nixos-rebuild` can only copy data from the nix-store, which is open for everyone to see.
  - So data to pass to the server must be encrypted on the way.
  - You encrypt your secret into a secure `secret.age` file, which is put into the store.
    Agenix uses [age](https://github.com/FiloSottile/age) for encryption) 
    - NixOS on the server creates a public/private key combination.
    - On the server you get its public key (that works with agenix) with
      `[root@nixos:~]# cat /etc/ssh/ssh_host_ed25519_key.pub`
    - On you local computer you encrypt with the servers public key.
    - The agenix on the server decrypts the `secret.age` file with the servers private key.
    - The key is then readable on the server at `/run/agenix/secret`.

# Packaging Rust
- Packaging the Rust app is done with [nix-community/dream2nix](https://github.com/nix-community/dream2nix) framework
  to create a Nix package that is exposed as a modular [Nix flake](https://nixos.wiki/wiki/Flakes)
  so that servers can download and run this app wherever.


# Test

```bash
sudo nixos-container create db-dev --flake .#db-dev
sudo nixos-container start db-dev --flake .#db-dev
curl --connect-to localhost:80:all:80 --connect-to localhost:443:all:443 http://localhost -k -L
sudo nixos-container update db-dev --flake .#db-dev
sudo nixos-container root-login db-dev --flake .#db-dev
```