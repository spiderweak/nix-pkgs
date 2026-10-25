# nix-pkgs

A Nix flake of packages that are missing from nixpkgs or that should track upstream faster than nixpkgs does. Each package is built from official upstream releases, and a scheduled CI job proposes version bumps as pull requests.

`nix flake show github:spiderweak/nix-pkgs` lists the available packages.

## Using it

In a NixOS flake's inputs:

```nix
nix-pkgs = {
  url = "github:spiderweak/nix-pkgs";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

then add the overlay in a NixOS module:

```nix
nixpkgs.overlays = [ inputs.nix-pkgs.overlays.default ];
```

The packages appear in `pkgs` under their directory names and **replace any nixpkgs package of the same name**. With `follows`, they build against the consumer's nixpkgs; this repository's `flake.lock` only affects its own builds and CI.

Without the overlay, use `inputs.nix-pkgs.packages.<system>.<name>` (built against this repository's pinned nixpkgs), or `nix run github:spiderweak/nix-pkgs#<name>` for a one-off.

Unfree packages still have to be allowed by the consumer (`nixpkgs.config.allowUnfree` or `allowUnfreePredicate`). The `allowUnfree` in this flake applies only to its own package set.

To pick up a merged update: `nix flake update nix-pkgs`, then rebuild.

## Layout

```
pkgs/<name>/
├── package.nix    # build recipe, edited by hand
├── sources.json   # version + hash, written by update.sh
└── update.sh      # finds the latest upstream version and rewrites sources.json
```

Every `pkgs/<name>/package.nix` becomes `packages.<system>.<name>`, `checks.<system>.<name>`, and an attribute of `overlays.default`. Package-specific details (upstream source, wrapper choices, script options) live in those files.

## Working on it

```sh
nix develop -c pkgs/<name>/update.sh   # bump sources.json if upstream has a newer release
nix build .#<name>                     # build one package
nix flake check                        # build everything, as CI does
nix flake update                       # bump this repository's own nixpkgs pin
```

### Adding a package

1. Write `pkgs/<name>/package.nix`, reading `version` and `hash` with `lib.importJSON ./sources.json`.
2. Write an executable `pkgs/<name>/update.sh` that finds the latest version, computes its hash with `nix store prefetch-file --json <url>`, and rewrites `sources.json`. It must leave `sources.json` untouched when already current. It runs inside `nix develop`, which provides `curl` and `jq`; add other tools to the dev shell in `flake.nix`.
3. Run it once, then `nix build .#<name>`.
4. `git add pkgs/<name>`: flakes only see tracked files.

## CI

- **`build.yml`** runs `nix flake check`, which builds every package, on pushes to `main`, on pull requests, and on demand.
- **`update.yml`** runs daily and on demand. For each package whose update script changes `sources.json`, it builds the package, force-pushes the change to the `update/<name>` branch, and opens a pull request or retitles the one already open. A newer release replaces a pending update instead of stacking conflicting PRs, so don't push manual work to `update/*` branches.
- **Dependabot** (`.github/dependabot.yml`) keeps the SHA-pinned actions current.

Things to know:

- The repository setting *Settings → Actions → General → Workflow permissions → Allow GitHub Actions to create and approve pull requests* is enabled on this repo so `update.yml` can push branches and open PRs.
- PRs opened by `update.yml` don't trigger `build.yml`: GitHub doesn't start workflows from events created with a workflow's own token. That's why the update job builds each package before pushing.
- In public repositories, GitHub disables scheduled workflows after 60 days without repository activity. If updates stop, re-enable `update.yml` in the Actions tab.
- There is no binary cache; consumers build locally. For a prebuilt upstream binary, "building" means downloading it, checking the pinned hash, and wrapping it.
