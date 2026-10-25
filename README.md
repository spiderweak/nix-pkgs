# nix-pkgs

Personal Nix flake of packages missing from nixpkgs or kept up to date faster than it, built from official upstream releases and updated automatically.

## Packages

| Package       | Source                                       |
| ------------- | -------------------------------------------- |
| `claude-code` | Anthropic's official native binary (unfree)  |

## Layout

```
pkgs/<name>/
├── package.nix    # the build recipe, edited by hand
├── sources.json   # version + hash, written by update.sh
└── update.sh      # finds the latest version and rewrites sources.json
```

Every `pkgs/<name>/package.nix` is picked up automatically and exposed as `packages.<system>.<name>` and in `overlays.default`.

## Using it from a NixOS / Home Manager config

In your config's `flake.nix`:

```nix
inputs.nix-pkgs = {
  url = "github:<you>/nix-pkgs";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then, in a NixOS module (pass `inputs` through `specialArgs`):

```nix
nixpkgs.overlays = [ inputs.nix-pkgs.overlays.default ];
```

and use the packages as usual, e.g. `home.packages = [ pkgs.claude-code ];`.

Unfree packages still need to be allowed on the consuming machine, for example:

```nix
nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getName pkg) [ "claude-code" ];
```

To pick up a merged update: `nix flake update nix-pkgs`, then rebuild.

## Updating by hand

```sh
nix develop -c pkgs/claude-code/update.sh           # only if a new version exists
nix develop -c pkgs/claude-code/update.sh --force   # recompute the hash anyway
nix build .#claude-code
```

## Adding a package

1. Create `pkgs/<name>/package.nix`, reading `version` and `hash` from `sources.json` with `lib.importJSON ./sources.json`.
2. Create `pkgs/<name>/update.sh` that finds the latest version, computes the hash with `nix store prefetch-file --json <url>`, and rewrites `sources.json`. Make it executable.
3. Run it once, then `nix build .#<name>`.
4. `git add` everything (flakes only see tracked files).

## CI

- **`update.yml`** runs daily (or manually). It runs every `pkgs/*/update.sh`, builds each package that changed, and opens one pull request per package. Each PR only touches that package's `sources.json`.
- **`build.yml`** builds every package on pushes to `main`, on pull requests and on demand.

### One-time GitHub setup

1. **Allow Actions to open PRs**: Settings → Actions → General → Workflow permissions → tick *Allow GitHub Actions to create and approve pull requests*.
2. **Pin the actions to commit SHAs.** The workflows use `actions/checkout@v5` and `cachix/install-nix-action@v31`. Replace each tag with the full commit SHA of that release (keep the tag as a comment), so a moved or compromised tag can't change what runs:
   ```yaml
   - uses: actions/checkout@<full-sha> # v5
   ```
   Tools like `pinact` can do this automatically.
3. **Commit `flake.lock`**: run `nix flake lock` once and commit it.

### Notes

- PRs opened by the update workflow don't trigger `build.yml` (GitHub doesn't start workflows from events created with the workflow token). That's why the update job builds each package before opening its PR.
- On public repos, GitHub pauses scheduled workflows after 60 days without repository activity. If updates stop, re-enable the workflow in the Actions tab.
- There is no binary cache: consumers build locally. For prebuilt binaries like `claude-code`, "building" is just downloading from upstream, verifying the hash and wrapping.
