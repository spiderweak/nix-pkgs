{
  description = "Personal Nix flake of packages missing from nixpkgs or kept up to date faster than it";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];

      # This repo's own package set, used for `nix build`, the dev shell and CI.
      # allowUnfree only applies here: machines that use the overlay keep
      # their own unfree policy (allowUnfree or allowUnfreePredicate).
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );

      # Every pkgs/<name>/package.nix becomes a package called <name>.
      # The folder is scanned with the flake's own lib, not the package set's:
      # in an overlay, using final.lib here would recurse infinitely.
      mkPackages =
        callPackage:
        nixpkgs.lib.packagesFromDirectoryRecursive {
          inherit callPackage;
          directory = ./pkgs;
        };
    in
    {
      packages = forAllSystems (pkgs: mkPackages pkgs.callPackage);

      overlays.default = final: prev: mkPackages final.callPackage;

      # Tools needed by the update scripts: `nix develop -c pkgs/<name>/update.sh`
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.curl
            pkgs.jq
          ];
        };
      });
    };
}
