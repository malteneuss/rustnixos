{ rustPlatform, ... }:
let
  cargoToml = builtins.fromTOML (builtins.readFile ../Cargo.toml);
  nonRustDeps = [ ];
in rustPlatform.buildRustPackage {
  inherit (cargoToml.package) name version;
  src = ./..;
  cargoLock.lockFile = ../Cargo.lock;
}
