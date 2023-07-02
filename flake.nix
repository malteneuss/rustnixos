{
  description = "my project description";
  inputs = {
#      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#      flake-utils.url = "github:numtide/flake-utils";
       # Rust
      dream2nix.url = "github:nix-community/dream2nix";
  };

  outputs = { self, dream2nix }:
        dream2nix.lib.makeFlakeOutputs {
              systems = ["x86_64-linux"];
              config.projectRoot = ./.;
              source = ./.;
              projects = ./projects.toml;
#              projects."rust-nixos" = { name, ... }: {
#                          inherit name;
#                          subsystem = "rust";
#                          translator = "cargo-lock";
#                          builder = "crane";
#              };
        };
#    flake-utils.lib.eachDefaultSystem (system:
#      let
#        pkgs = nixpkgs.legacyPackages.${system};
#
#        dream2nix.lib.makeFlakeOutputs {
#              systems = ["x86_64-linux"];
#              config.projectRoot = ./.;
#              source = ./.;
#              projects = ./projects.toml;
#        };
#
#        myDevTools = [
#          rustup
#          pkgs.zlib # External C library needed by some Haskell packages
#          pkgs.postgresql # External C library needed by some Haskell package
#          # Documentation
#          pandoc-liveedit
#        ];
#
#        pandoc-liveedit = let scriptName = "pandoc-liveedit";
#        in pkgs.writeShellApplication {
#          name = "pandoc-liveedit";
#          runtimeInputs = [
#            # Create pdf/html out of .md markdown files
#            pkgs.pandoc
#            # Convert diagram code into images
#            pkgs.pandoc-plantuml-filter
#            # Pandoc needs this to convert to pdf with xelatex
#            pkgs.texlive.combined.scheme-small
#            # Update pdfs on file change
#            pkgs.watchexec
#          ];
#          text = builtins.readFile ./tools/pandoc-liveedit.sh;
#        };
#      in {
#        devShells.default = pkgs.mkShell {
#          buildInputs = myDevTools;
#
#          # Make external Nix c libraries like zlib known to GHC, like pkgs.haskell.lib.buildStackProject does
#          # https://github.com/NixOS/nixpkgs/blob/d64780ea0e22b5f61cd6012a456869c702a72f20/pkgs/development/haskell-modules/generic-stack-builder.nix#L38
#          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath myDevTools;
#        };
#      });
}
