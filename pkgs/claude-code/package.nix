{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  autoPatchelfHook,
  procps,
  ripgrep,
  bubblewrap,
  socat,
}:

let
  # version and hash are written by ./update.sh; don't edit them by hand.
  sources = lib.importJSON ./sources.json;
in
stdenv.mkDerivation {
  pname = "claude-code";
  inherit (sources) version;

  # Official native binary, downloaded straight from Anthropic.
  # The hash pins the exact bytes: a different file fails the build.
  src = fetchurl {
    url = "https://downloads.claude.ai/claude-code-releases/${sources.version}/linux-x64/claude";
    inherit (sources) hash;
  };

  dontUnpack = true;
  # Stripping breaks the program embedded in the binary.
  dontStrip = true;

  # autoPatchelfHook makes the prebuilt binary find its libraries on NixOS.
  nativeBuildInputs = [
    makeBinaryWrapper
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/.claude-unwrapped

    # - DISABLE_AUTOUPDATER: the Nix store is read-only, updates go through Nix
    # - DISABLE_INSTALLATION_CHECKS: skip the "installed in an unusual place" check
    # - USE_BUILTIN_RIPGREP=0: use ripgrep from nixpkgs
    # - bubblewrap and socat: used by Claude Code's sandbox on Linux
    makeBinaryWrapper $out/bin/.claude-unwrapped $out/bin/claude \
      --inherit-argv0 \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set USE_BUILTIN_RIPGREP 0 \
      --prefix PATH : ${
        lib.makeBinPath [
          procps
          ripgrep
          bubblewrap
          socat
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Claude Code, Anthropic's agentic coding tool for the terminal";
    homepage = "https://www.anthropic.com/claude-code";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude";
  };
}
