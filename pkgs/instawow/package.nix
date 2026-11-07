{
  lib,
  python3Packages,
  fetchurl,
  fetchFromGitHub,
  versionCheckHook,
}:

let
  # version and hash are written by ./update.sh; don't edit them by hand.
  sources = lib.importJSON ./sources.json;

  # instawow needs click >= 8.4.1: on 8.3 it fails at startup with
  # "TypeError: type 'CompositeParamType' is not subscriptable". nixos-26.05
  # ships click 8.3.1, so there instawow alone gets 8.4.2. Unused once the
  # consumer's nixpkgs has click >= 8.4.1; delete it then.
  click =
    if lib.versionAtLeast python3Packages.click.version "8.4.1" then
      python3Packages.click
    else
      python3Packages.click.overridePythonAttrs {
        version = "8.4.2";
        src = fetchFromGitHub {
          owner = "pallets";
          repo = "click";
          tag = "8.4.2";
          hash = "sha256-66JFGGwPXeCU7Fbqsrsq3giv6qsea1ZKGmZYPu9rcog=";
        };
      };
in
python3Packages.buildPythonApplication {
  pname = "instawow";
  inherit (sources) version;
  pyproject = true;

  # The PyPI sdist, not a GitHub tarball: versioningit reads the version from
  # git metadata, which a tarball lacks, while the sdist records it in PKG-INFO.
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/source/i/instawow/instawow-${sources.version}.tar.gz";
    inherit (sources) hash;
  };

  build-system = with python3Packages; [
    hatchling
    versioningit
  ];

  # Copied by hand from [project] dependencies in upstream's pyproject.toml
  # (the GUI extra is left out). update.sh only bumps version and hash: when a
  # release adds a dependency, the runtime dependency check fails the build.
  dependencies = [
    click
  ]
  ++ (with python3Packages; [
    aiohttp
    aiohttp-client-cache
    attrs
    cattrs
    diskcache
    loguru
    packaging
    pluggy
    prompt-toolkit
    rapidfuzz
    truststore
    typing-extensions
    wcwidth
    yarl
  ]);

  # Upstream raises these lower bounds to the newest upstream releases, ahead
  # of nixpkgs. On nixos-26.05 (aiohttp 3.13.5, rapidfuzz 3.14.5, yarl 1.23.0)
  # search, install, update and remove all worked with 7.3.0. Relaxed only by
  # name, so a new bound on any other dependency still fails the build.
  pythonRelaxDeps = [
    "aiohttp"
    "rapidfuzz"
    "yarl"
  ];

  # Nix delivers updates, so skip the PyPI version check that instawow runs
  # after every install or update.
  makeWrapperArgs = [
    "--set-default"
    "INSTAWOW_AUTO_UPDATE_CHECK"
    "0"
  ];

  pythonImportsCheck = [ "instawow" ];
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "World of Warcraft add-on manager";
    homepage = "https://github.com/layday/instawow";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "instawow";
  };
}
